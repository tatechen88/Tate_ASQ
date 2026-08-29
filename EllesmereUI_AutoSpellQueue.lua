if _G.EUI_CLIENT_BLOCKED then return end -- pre-12.1 client failsafe (EllesmereUI_ClientGate.lua)

-------------------------------------------------------------------------------
--  EllesmereUI_AutoSpellQueue.lua
--  Runtime: reads config, watches login/spec events, applies SpellQueueWindow.
--  No periodic sampling by design -- evaluation only happens on:
--    PLAYER_ENTERING_WORLD
--    PLAYER_SPECIALIZATION_CHANGED
--  plus explicit user actions from the options window.
-------------------------------------------------------------------------------
local ADDON_NAME, ns = ...

local Addon = _G.EllesmereUI_AutoSpellQueue or {}
_G.EllesmereUI_AutoSpellQueue = Addon

local Formula = _G.EllesmereUI_AutoSpellQueueFormula

---------------------------------------------------------------------------
--  Localisation (self-contained; does not modify EllesmereUI locale files)
---------------------------------------------------------------------------
local L = function(key)
    return key
end

local LOCALES = {
    zhCN = {
        ["Enabled"] = "启用",
        ["On"] = "开",
        ["Off"] = "关",
        ["Melee"] = "近战",
        ["Ranged"] = "远程",
        ["Unknown"] = "未知",
        ["Home"] = "本地",
        ["World"] = "世界",
        ["Average"] = "平均",
        ["Max"] = "最大",
        ["Manual"] = "手动",
        ["Auto (per class/spec)"] = "自动（按职业/专精）",
        ["Current Latency"] = "当前延迟",
        ["Current SpellQueueWindow"] = "当前法术队列窗口",
        ["Last Target"] = "上次计算值",
        ["Base Value"] = "基础值",
        ["Role"] = "定位",
        ["Spec"] = "专精",
        ["Latency Source"] = "延迟来源",
        ["Latency Margin"] = "延迟余量",
        ["Min Window"] = "下限",
        ["Max Window"] = "上限",
        ["Hysteresis"] = "写入迟滞",
        ["Base Value Mode"] = "基础值模式",
        ["Manual Base"] = "手动基础值",
        ["Adaptive by latency"] = "依延迟自动调整",
        ["Show Status Bar"] = "显示状态条",
        ["Spell Queue"] = "施法容错",
        ["Auto SpellQueue"] = "自动施法容错",
        ["Pending (combat)"] = "等待脱战",
        ["Open Settings"] = "打开设置",
        ["Close"] = "关闭",
    },
    zhTW = {
        ["Enabled"] = "啟用",
        ["On"] = "開",
        ["Off"] = "關",
        ["Melee"] = "近戰",
        ["Ranged"] = "遠程",
        ["Unknown"] = "未知",
        ["Home"] = "本地",
        ["World"] = "世界",
        ["Average"] = "平均",
        ["Max"] = "最大",
        ["Manual"] = "手動",
        ["Auto (per class/spec)"] = "自動（按職業/專精）",
        ["Current Latency"] = "目前延遲",
        ["Current SpellQueueWindow"] = "目前施法佇列視窗",
        ["Last Target"] = "上次計算值",
        ["Base Value"] = "基礎值",
        ["Role"] = "定位",
        ["Spec"] = "專精",
        ["Latency Source"] = "延遲來源",
        ["Latency Margin"] = "延遲餘量",
        ["Min Window"] = "下限",
        ["Max Window"] = "上限",
        ["Hysteresis"] = "寫入遲滯",
        ["Base Value Mode"] = "基礎值模式",
        ["Manual Base"] = "手動基礎值",
        ["Adaptive by latency"] = "依延遲自動調整",
        ["Show Status Bar"] = "顯示狀態列",
        ["Spell Queue"] = "施法容錯",
        ["Auto SpellQueue"] = "自動施法容錯",
        ["Pending (combat)"] = "等待脫戰",
        ["Open Settings"] = "開啟設定",
        ["Close"] = "關閉",
    },
}

local function InitLocale()
    local locale = GetLocale()
    local tbl = LOCALES[locale]
    if tbl then
        L = function(key)
            return tbl[key] or key
        end
    end
end
Addon.L = function(key) return L(key) end

---------------------------------------------------------------------------
--  Defaults
---------------------------------------------------------------------------
local DEFAULTS = {
    enabled       = true,
    baseMode      = "auto",     -- "auto" | "manual"
    manualBase    = 200,
    adaptive      = true,
    latencySource = "max",      -- "world" | "home" | "avg" | "max"
    margin        = 50,
    minWindow     = 50,
    maxWindow     = 400,
    hysteresis    = 10,
    showStatus    = true,
}

local function GetConfig()
    local db = _G.EllesmereUI_AutoSpellQueueDB
    if type(db) ~= "table" then
        db = {}
        _G.EllesmereUI_AutoSpellQueueDB = db
    end
    for k, v in pairs(DEFAULTS) do
        if db[k] == nil then db[k] = v end
    end
    return db
end

function Addon.GetConfig() return GetConfig() end

---------------------------------------------------------------------------
--  CVar helpers
---------------------------------------------------------------------------
local function GetCurrentWindow()
    if GetCVarNum then
        return GetCVarNum("SpellQueueWindow") or 400
    end
    local v = GetCVar and tonumber(GetCVar("SpellQueueWindow"))
    return v or 400
end

local function SetCVarValue(value)
    local text = tostring(value)
    if C_CVar and C_CVar.SetCVar then
        local ok = pcall(C_CVar.SetCVar, "SpellQueueWindow", text)
        if ok then return true end
    end
    if SetCVar then
        local ok = pcall(SetCVar, "SpellQueueWindow", text)
        if ok then return true end
    end
    return false
end

---------------------------------------------------------------------------
--  Player info
---------------------------------------------------------------------------
local function GetSpecID()
    if C_SpecializationInfo and C_SpecializationInfo.GetSpecialization then
        local spec = C_SpecializationInfo.GetSpecialization()
        if spec then
            local specID = C_SpecializationInfo.GetSpecializationInfo(spec)
            if type(specID) == "number" and specID > 0 then return specID end
        end
    end
    if GetSpecialization and GetSpecializationInfo then
        local spec = GetSpecialization()
        if spec then
            local specID = GetSpecializationInfo(spec)
            if type(specID) == "number" and specID > 0 then return specID end
        end
    end
    return 0
end

local function GetPlayerInfo()
    local specID = GetSpecID()
    local _, classFile = UnitClass("player")
    return specID, classFile or "UNKNOWN"
end

---------------------------------------------------------------------------
--  Apply / restore logic
---------------------------------------------------------------------------
function Addon.ApplyTarget(target)
    local old = GetCurrentWindow()
    if Addon.originalWindow == nil then
        Addon.originalWindow = old
    end
    if SetCVarValue(target) then
        Addon.lastApplied = target
        Addon.pendingTarget = nil
        Addon.last = Addon.last or {}
        Addon.last.applied = target
        Addon.last.pending = false
        return true
    end
    return false
end

function Addon.Evaluate(force)
    if not Formula then return end
    local cfg = GetConfig()
    if not cfg.enabled then return end

    local specID, classFile = GetPlayerInfo()
    local _, _, home, world = GetNetStats()
    local target, role, base, latency = Formula.ComputeTarget(cfg, specID, classFile, home, world)

    Addon.last = Addon.last or {}
    Addon.last.specID = specID
    Addon.last.classFile = classFile
    Addon.last.role = role
    Addon.last.base = base
    Addon.last.latency = latency
    Addon.last.home = home
    Addon.last.world = world
    Addon.last.target = target
    Addon.last.pending = false

    local current = GetCurrentWindow()
    if not force and (math.abs(target - current) < (cfg.hysteresis or 0)) then
        Addon.last.applied = current
        return
    end

    if InCombatLockdown() then
        Addon.last.pending = true
        Addon.pendingTarget = target
        return
    end

    Addon.ApplyTarget(target)
end

function Addon.Recalc()
    Addon.Evaluate(true)
end

function Addon.RestoreIfOwned()
    if Addon.pendingRestore then return end
    local current = GetCurrentWindow()
    if Addon.lastApplied and current == Addon.lastApplied and Addon.originalWindow ~= nil then
        if InCombatLockdown() then
            Addon.pendingRestore = true
            return
        end
        SetCVarValue(Addon.originalWindow)
    end
    Addon.lastApplied = nil
    Addon.originalWindow = nil
    Addon.pendingTarget = nil
    Addon.pendingRestore = nil
end

function Addon.SetEnabled(v)
    local cfg = GetConfig()
    cfg.enabled = v and true or false
    if cfg.enabled then
        Addon.originalWindow = nil
        Addon.Evaluate(true)
    else
        Addon.RestoreIfOwned()
    end
end

function Addon.SetConfig(key, value)
    local cfg = GetConfig()
    cfg[key] = value
    if cfg.enabled then
        Addon.Evaluate(true)
    end
end

---------------------------------------------------------------------------
--  Live status for the options window / status bar
---------------------------------------------------------------------------
function Addon.GetLiveStatus()
    local _, _, home, world = GetNetStats()
    return GetCurrentWindow(), home, world
end

---------------------------------------------------------------------------
--  Events
---------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON_NAME then
            InitLocale()
            Addon.loaded = true
            GetConfig()
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        if Addon.loaded then Addon.Evaluate(false) end
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        if Addon.loaded then Addon.Evaluate(false) end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if Addon.pendingTarget then
            Addon.ApplyTarget(Addon.pendingTarget)
        end
        if Addon.pendingRestore then
            Addon.pendingRestore = nil
            Addon.RestoreIfOwned()
        end
    end
end)

---------------------------------------------------------------------------
--  Addon compartment entry points (declared in the TOC)
---------------------------------------------------------------------------
function EllesmereUI_AutoSpellQueue_OnCompartmentClick(addonName, buttonName)
    if _G.EllesmereUI_AutoSpellQueueOptions then
        _G.EllesmereUI_AutoSpellQueueOptions.Toggle()
    end
end

function EllesmereUI_AutoSpellQueue_OnCompartmentEnter(addonName, button)
    if button and MenuUtil and MenuUtil.ShowTooltip then
        MenuUtil.ShowTooltip(button, function(tooltip)
            tooltip:SetText(L("Spell Queue"))
            tooltip:AddLine(L("Open Settings"), 1, 1, 1, true)
        end)
    end
end

function EllesmereUI_AutoSpellQueue_OnCompartmentLeave(addonName, button)
    if button and MenuUtil and MenuUtil.HideTooltip then
        MenuUtil.HideTooltip(button)
    end
end
