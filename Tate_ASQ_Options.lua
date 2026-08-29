if _G.EUI_CLIENT_BLOCKED then return end -- pre-12.1 client failsafe (set by EllesmereUI when present)

-------------------------------------------------------------------------------
--  Tate_ASQ_Options.lua
--  Standalone settings window + movable status bar. Does not depend on other addons.
-------------------------------------------------------------------------------
local Addon = _G.Tate_ASQ
if not Addon then return end

local L = Addon.L

---------------------------------------------------------------------------
--  Visual constants (dark panel + teal accent)
---------------------------------------------------------------------------
local ACCENT_R, ACCENT_G, ACCENT_B = 12/255, 210/255, 157/255
local BG_R, BG_G, BG_B, BG_A = 0.05, 0.07, 0.09, 0.97
local ROW_R, ROW_G, ROW_B, ROW_A = 1, 1, 1, 0.05
local TEXT_R, TEXT_G, TEXT_B = 1, 1, 1
local DIM_R, DIM_G, DIM_B, DIM_A = 1, 1, 1, 0.55

local Options = {}
_G.Tate_ASQOptions = Options

---------------------------------------------------------------------------
--  Helpers
---------------------------------------------------------------------------
local function Clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function Round(v)
    return math.floor(v + 0.5)
end

local function SetColor(tex, r, g, b, a)
    tex:SetColorTexture(r, g, b, a or 1)
end

local function CreateTexture(frame, layer)
    local tex = frame:CreateTexture(nil, layer or "BACKGROUND")
    tex:SetAllPoints()
    return tex
end

local function AddBorder(frame, r, g, b, a)
    local top = frame:CreateTexture(nil, "BORDER")
    top:SetPoint("TOPLEFT")
    top:SetPoint("TOPRIGHT")
    top:SetHeight(1)
    SetColor(top, r, g, b, a or 0.9)

    local bottom = frame:CreateTexture(nil, "BORDER")
    bottom:SetPoint("BOTTOMLEFT")
    bottom:SetPoint("BOTTOMRIGHT")
    bottom:SetHeight(1)
    SetColor(bottom, r, g, b, a or 0.9)

    local left = frame:CreateTexture(nil, "BORDER")
    left:SetPoint("TOPLEFT")
    left:SetPoint("BOTTOMLEFT")
    left:SetWidth(1)
    SetColor(left, r, g, b, a or 0.9)

    local right = frame:CreateTexture(nil, "BORDER")
    right:SetPoint("TOPRIGHT")
    right:SetPoint("BOTTOMRIGHT")
    right:SetWidth(1)
    SetColor(right, r, g, b, a or 0.9)
end

local function CreateText(parent, layer)
    return parent:CreateFontString(nil, layer or "OVERLAY")
end

local function SetLabel(fs, text, r, g, b, a)
    fs:SetText(text or "")
    fs:SetTextColor(r or TEXT_R, g or TEXT_G, b or TEXT_B, a or 1)
end

---------------------------------------------------------------------------
--  Settings window
---------------------------------------------------------------------------
local settingsFrame
local rowUpdaters = {}

local function UpdateRows()
    for _, fn in ipairs(rowUpdaters) do fn() end
end

local function AddRowUpdater(fn)
    table.insert(rowUpdaters, fn)
end

local function CreatePanelFrame()
    local frame = CreateFrame("Frame", "Tate_ASQ_Settings", UIParent)
    frame:SetSize(460, 540)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)

    local bg = CreateTexture(frame)
    SetColor(bg, BG_R, BG_G, BG_B, BG_A)
    AddBorder(frame, ACCENT_R, ACCENT_G, ACCENT_B, 0.85)

    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    tinsert(UISpecialFrames, frame:GetName())
    frame:Hide()
    return frame
end

local function CreateTitleBar(frame)
    local title = CreateText(frame)
    title:SetPoint("TOPLEFT", 18, -16)
    title:SetFontObject(GameFontNormalLarge)
    SetLabel(title, L("Spell Queue"))

    local close = CreateFrame("Button", nil, frame)
    close:SetSize(28, 28)
    close:SetPoint("TOPRIGHT", -12, -10)
    local closeBg = CreateTexture(close)
    SetColor(closeBg, 1, 1, 1, 0.06)
    local closeText = CreateText(close)
    closeText:SetPoint("CENTER")
    closeText:SetFontObject(GameFontNormal)
    SetLabel(closeText, "X")
    close:SetScript("OnEnter", function() closeBg:SetColorTexture(ACCENT_R, ACCENT_G, ACCENT_B, 0.5) end)
    close:SetScript("OnLeave", function() closeBg:SetColorTexture(1, 1, 1, 0.06) end)
    close:SetScript("OnClick", function() frame:Hide() end)
end

local function AddRow(frame, y, labelText)
    local row = CreateFrame("Frame", nil, frame)
    row:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, y)
    row:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, y)
    row:SetHeight(44)

    local bg = CreateTexture(row)
    SetColor(bg, ROW_R, ROW_G, ROW_B, ROW_A)

    local label = CreateText(row)
    label:SetPoint("LEFT", 14, 0)
    label:SetFontObject(GameFontNormal)
    SetLabel(label, labelText)

    return row, label
end

local function CreateActionButton(parent, width, height)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(width, height)
    local bg = CreateTexture(btn)
    SetColor(bg, 0.10, 0.13, 0.16, 0.9)
    AddBorder(btn, 1, 1, 1, 0.16)
    local text = CreateText(btn)
    text:SetPoint("CENTER")
    text:SetFontObject(GameFontNormal)
    btn._bg = bg
    btn._text = text
    btn:SetScript("OnEnter", function() btn._bg:SetColorTexture(ACCENT_R, ACCENT_G, ACCENT_B, 0.25) end)
    btn:SetScript("OnLeave", function() btn._bg:SetColorTexture(0.10, 0.13, 0.16, 0.9) end)
    return btn
end

---------------------------------------------------------------------------
--  Font helpers
---------------------------------------------------------------------------
local function ResolveFontPath(value)
    if type(value) == "string" then
        local v = value:lower()
        if v:match("^fonts\\") or v:match("^interface\\") then
            return value
        end
        local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
        if LSM then
            local path = LSM:Fetch("font", value)
            if path then return path end
        end
    end
    return "Fonts\\FRIZQT__.TTF"
end

local function GetFontList()
    local list = {
        { value = "Fonts\\FRIZQT__.TTF",    label = "Friz Quadrata (Default)" },
        { value = "Fonts\\ARIALN.TTF",       label = "Arial Narrow" },
        { value = "Fonts\\MORPHEUS.TTF",     label = "Morpheus" },
        { value = "Fonts\\skurri.ttf",       label = "Skurri" },
    }
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM then
        local names = LSM:List("font")
        for _, name in ipairs(names) do
            local path = LSM:Fetch("font", name)
            if path then
                table.insert(list, { value = name, label = name })
            end
        end
    end
    return list
end

---------------------------------------------------------------------------
--  Row widgets
---------------------------------------------------------------------------
local function AddToggleRow(frame, y, labelText, get, set)
    local row = AddRow(frame, y, labelText)
    local btn = CreateActionButton(row, 90, 26)
    btn:SetPoint("RIGHT", -14, 0)

    local function Update()
        local v = get()
        btn._text:SetText(v and L("On") or L("Off"))
        btn._text:SetTextColor(v and 0 or TEXT_R, v and 0 or TEXT_G, v and 0 or TEXT_B, 1)
        btn._bg:SetColorTexture(v and ACCENT_R or 0.10, v and ACCENT_G or 0.13, v and ACCENT_B or 0.16, 0.9)
    end
    btn:SetScript("OnClick", function()
        set(not get())
        Update()
        UpdateRows()
    end)
    AddRowUpdater(Update)
    Update()
    return row
end

local function AddStepperRow(frame, y, labelText, minV, maxV, stepV, get, set, unit)
    local row = AddRow(frame, y, labelText)

    local minus = CreateActionButton(row, 28, 24)
    minus:SetPoint("RIGHT", -120, 0)
    minus._text:SetText("-")

    local value = CreateText(row)
    value:SetPoint("RIGHT", minus, "LEFT", -10, 0)
    value:SetFontObject(GameFontNormal)

    local plus = CreateActionButton(row, 28, 24)
    plus:SetPoint("RIGHT", -14, 0)
    plus._text:SetText("+")

    local function Update()
        local v = get()
        value:SetText((unit and ("%d " .. unit) or "%d"):format(v))
        value:SetTextColor(TEXT_R, TEXT_G, TEXT_B, 1)
    end

    minus:SetScript("OnClick", function()
        set(Clamp(get() - stepV, minV, maxV))
        Update()
        UpdateRows()
    end)
    plus:SetScript("OnClick", function()
        set(Clamp(get() + stepV, minV, maxV))
        Update()
        UpdateRows()
    end)
    AddRowUpdater(Update)
    Update()
    return row
end

-- entries: { { value = "max", label = "Max" }, ... }
local function AddCycleRow(frame, y, labelText, entries, get, set)
    local row = AddRow(frame, y, labelText)
    local btn = CreateActionButton(row, 180, 26)
    btn:SetPoint("RIGHT", -14, 0)

    local function EntryText(e)
        return type(e) == "table" and L(e.label) or L(tostring(e))
    end

    local function Update()
        btn._text:SetText(EntryText(get()))
    end
    btn:SetScript("OnClick", function()
        local current = get()
        local idx = 1
        for i, e in ipairs(entries) do
            local value = type(e) == "table" and e.value or e
            if value == current then idx = i break end
        end
        idx = idx % #entries + 1
        local nextEntry = entries[idx]
        set(type(nextEntry) == "table" and nextEntry.value or nextEntry)
        Update()
        UpdateRows()
    end)
    AddRowUpdater(Update)
    Update()
    return row
end

---------------------------------------------------------------------------
--  Font dropdown row (UIDropDownMenu)
---------------------------------------------------------------------------
local function AddFontDropdownRow(frame, y, labelText, get, set)
    local row = AddRow(frame, y, labelText)

    local dd = CreateFrame("Frame", nil, row, "UIDropDownMenuTemplate")
    dd:SetPoint("RIGHT", -14, 0)
    UIDropDownMenu_SetWidth(dd, 200)

    local function FontName(value)
        for _, e in ipairs(GetFontList()) do
            if e.value == value then return e.label end
        end
        return value or ""
    end

    local function Refresh()
        UIDropDownMenu_SetText(dd, FontName(get()))
    end

    UIDropDownMenu_Initialize(dd, function(self, level)
        local info = UIDropDownMenu_CreateInfo()
        for _, e in ipairs(GetFontList()) do
            local fontValue = e.value
            local fontLabel = e.label
            info.text = fontLabel
            info.value = fontValue
            info.func = function()
                set(fontValue)
                Refresh()
                Options.ApplyStatusBarStyle()
                CloseDropDownMenus()
            end
            info.checked = (fontValue == get())
            UIDropDownMenu_AddButton(info)
        end
    end)

    AddRowUpdater(Refresh)
    Refresh()
    return row
end

---------------------------------------------------------------------------
--  Window content
---------------------------------------------------------------------------
local function BuildSettings(frame, showTitle)
    if showTitle then
        CreateTitleBar(frame)
    end

    local y = showTitle and -54 or -16
    local rowH = 44

    -- Status block ----------------------------------------------------------
    local status = CreateFrame("Frame", nil, frame)
    status:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, y)
    status:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -18, y)
    status:SetHeight(130)
    local statusBg = CreateTexture(status)
    SetColor(statusBg, 0, 0, 0, 0.28)
    AddBorder(status, 1, 1, 1, 0.08)

    local function AddStatusLine(i, labelText)
        local line = CreateFrame("Frame", nil, status)
        line:SetPoint("TOPLEFT", status, "TOPLEFT", 14, -10 - i * 24)
        line:SetPoint("TOPRIGHT", status, "TOPRIGHT", -14, 0)
        line:SetHeight(20)
        local label = CreateText(line)
        label:SetPoint("LEFT")
        label:SetFontObject(GameFontNormal)
        SetLabel(label, labelText, DIM_R, DIM_G, DIM_B, DIM_A)
        local value = CreateText(line)
        value:SetPoint("RIGHT")
        value:SetFontObject(GameFontNormal)
        SetLabel(value, "--")
        return value
    end

    local lineSpec = AddStatusLine(0, L("Role") .. " / " .. L("Spec"))
    local lineBase = AddStatusLine(1, L("Base Value"))
    local lineLat = AddStatusLine(2, L("Current Latency"))
    local lineCur = AddStatusLine(3, L("Current SpellQueueWindow"))
    local lineTarget = AddStatusLine(4, L("Last Target"))

    local function UpdateStatus()
        local state = Addon.last or {}
        local role = state.role and L(state.role) or L("Unknown")
        local specID = state.specID or 0
        lineSpec:SetText(role .. " / " .. specID)

        if state.base then
            lineBase:SetText(state.base .. " ms")
        else
            lineBase:SetText("--")
        end

        local cur, home, world = Addon.GetLiveStatus()
        lineLat:SetText(L("Home") .. " " .. Round(home or 0) .. " / " .. L("World") .. " " .. Round(world or 0) .. " ms")
        lineCur:SetText(cur .. " ms")

        if state.target then
            local pending = state.pending and ("  [" .. L("Pending (combat)") .. "]") or ""
            lineTarget:SetText(state.target .. " ms" .. pending)
        else
            lineTarget:SetText("--")
        end
    end
    AddRowUpdater(UpdateStatus)
    UpdateStatus()

    y = y - 140

    -- Settings rows ---------------------------------------------------------
    local function EnabledGet() return Addon.GetConfig().enabled end
    local function EnabledSet(v) Addon.SetEnabled(v) end
    AddToggleRow(frame, y, L("Enabled"), EnabledGet, EnabledSet); y = y - rowH

    local modeEntries = {
        { value = "auto",   label = "Auto (per class/spec)" },
        { value = "manual", label = "Manual" },
    }
    local function ModeGet() return Addon.GetConfig().baseMode end
    local function ModeSet(v) Addon.SetConfig("baseMode", v) end
    AddCycleRow(frame, y, L("Base Value Mode"), modeEntries, ModeGet, ModeSet); y = y - rowH

    local function ManualGet() return Addon.GetConfig().manualBase end
    local function ManualSet(v) Addon.SetConfig("manualBase", v) end
    local manualRow = AddStepperRow(frame, y, L("Manual Base"), 50, 400, 5, ManualGet, ManualSet, "ms"); y = y - rowH

    local function AdaptiveGet() return Addon.GetConfig().adaptive ~= false end
    local function AdaptiveSet(v) Addon.SetConfig("adaptive", v) end
    AddToggleRow(frame, y, L("Adaptive by latency"), AdaptiveGet, AdaptiveSet); y = y - rowH

    local function FontGet() return Addon.GetConfig().statusFont end
    local function FontSet(v)
        Addon.SetConfig("statusFont", v, true)
        Options.ApplyStatusBarStyle()
    end
    AddFontDropdownRow(frame, y, L("Status Bar Font"), FontGet, FontSet); y = y - rowH

    local function FontSizeGet() return Addon.GetConfig().statusFontSize end
    local function FontSizeSet(v)
        Addon.SetConfig("statusFontSize", v, true)
        Options.ApplyStatusBarStyle()
    end
    AddStepperRow(frame, y, L("Status Bar Font Size"), 10, 20, 1, FontSizeGet, FontSizeSet); y = y - rowH

    -- Manual base row visibility -------------------------------------------
    AddRowUpdater(function()
        local show = Addon.GetConfig().baseMode == "manual"
        manualRow:SetShown(show)
    end)

    -- Note ------------------------------------------------------------------
    local note = CreateText(frame)
    note:SetPoint("BOTTOMLEFT", 18, 16)
    note:SetPoint("BOTTOMRIGHT", -18, 16)
    note:SetFontObject(GameFontNormalSmall)
    note:SetJustifyH("CENTER")
    AddRowUpdater(function()
        note:SetText("|cff0cd29d" .. L("Auto SpellQueue") .. "|r  " .. L("Enabled") .. ": " .. (Addon.GetConfig().enabled and L("On") or L("Off")))
    end)
end

---------------------------------------------------------------------------
--  Status bar (small always-on display)
---------------------------------------------------------------------------
local statusBar

local function CreateStatusBar()
    local bar = CreateFrame("Frame", "Tate_ASQ_StatusBar", UIParent)
    bar:SetSize(90, 26)
    bar:SetPoint("TOP", UIParent, "TOP", 0, -120)
    bar:SetFrameStrata("MEDIUM")
    bar:EnableMouse(true)
    bar:SetMovable(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetClampedToScreen(true)

    local bg = CreateTexture(bar)
    SetColor(bg, 0.02, 0.03, 0.04, 0.86)
    AddBorder(bar, ACCENT_R, ACCENT_G, ACCENT_B, 0.6)

    local text = CreateText(bar)
    text:SetPoint("CENTER", 0, 0)
    text:SetFontObject(GameFontNormalSmall)
    SetLabel(text, "-- ms")

    bar._text = text
    bar._dragging = false

    bar:SetScript("OnMouseDown", function(self) self._dragging = false end)
    bar:SetScript("OnDragStart", function(self) self._dragging = true; self:StartMoving() end)
    bar:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    bar:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and not self._dragging then
            Options.Toggle()
        end
        self._dragging = false
    end)

    return bar
end

function Options.ApplyStatusBarStyle()
    if not statusBar or not statusBar._text then return end
    local cfg = Addon.GetConfig()
    local fontPath = ResolveFontPath(cfg.statusFont)
    local size = cfg.statusFontSize or 12
    statusBar._text:SetFont(fontPath, size, "")
    local cur = select(1, Addon.GetLiveStatus())
    statusBar._text:SetText(("%d ms"):format(cur))
    local w = statusBar._text:GetStringWidth() + 28
    local h = math.max(24, size + 14)
    statusBar:SetSize(w, h)
end

function Options.UpdateStatusBar()
    local cfg = Addon.GetConfig()
    if cfg.showStatus then
        if not statusBar then statusBar = CreateStatusBar() end
        Options.ApplyStatusBarStyle()
        statusBar:Show()
    elseif statusBar then
        statusBar:Hide()
    end
end

local function UpdateStatusBarText()
    if not statusBar then return end
    local cfg = Addon.GetConfig()
    local cur, home, world = Addon.GetLiveStatus()
    statusBar._text:SetText(("%d ms"):format(cur))
    local w = statusBar._text:GetStringWidth() + 28
    local h = math.max(24, (cfg.statusFontSize or 12) + 14)
    statusBar:SetSize(w, h)
end

---------------------------------------------------------------------------
--  Show / hide
---------------------------------------------------------------------------
local elapsedAccum = 0

function Options.Toggle()
    if not settingsFrame then
        settingsFrame = CreatePanelFrame()
        BuildSettings(settingsFrame, true)
    end
    if settingsFrame:IsShown() then
        settingsFrame:Hide()
    else
        settingsFrame:Show()
        UpdateRows()
    end
end

function Options.RefreshStatus()
    UpdateRows()
    UpdateStatusBarText()
end

---------------------------------------------------------------------------
--  Status bar display updates (display only -- never writes the CVar)
---------------------------------------------------------------------------
local statusUpdateFrame = CreateFrame("Frame")
statusUpdateFrame:SetScript("OnUpdate", function(self, elapsed)
    elapsedAccum = elapsedAccum + elapsed
    if elapsedAccum < 1 then return end
    elapsedAccum = 0

    if statusBar and statusBar:IsShown() then
        UpdateStatusBarText()
    end
    if settingsFrame and settingsFrame:IsShown() then
        UpdateRows()
    end
end)

---------------------------------------------------------------------------
--  Minimap button (direct, reliable fallback in addition to AddonCompartment)
---------------------------------------------------------------------------
local minimapButton

local function CreateMinimapButton()
    if minimapButton then return minimapButton end

    local parent = Minimap or UIParent
    minimapButton = CreateActionButton(parent, 28, 28)
    if Minimap then
        minimapButton:SetPoint("BOTTOMLEFT", Minimap, "BOTTOMLEFT", 4, 4)
    else
        minimapButton:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -220, -30)
    end
    minimapButton:SetFrameStrata("MEDIUM")
    minimapButton._text:SetText("SQ")
    minimapButton._text:SetFontObject(GameFontNormalSmall)
    minimapButton:SetScript("OnClick", function() Options.Toggle() end)
    minimapButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L("Spell Queue"), 1, 1, 1)
        GameTooltip:AddLine(L("Open Settings"), 1, 1, 1, true)
        GameTooltip:Show()
    end)
    minimapButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

    return minimapButton
end

---------------------------------------------------------------------------
--  Standard Interface Options entry (Options -> AddOns)
---------------------------------------------------------------------------
local function CreateInterfaceOptionsPanel()
    local panel = CreateFrame("Frame", "Tate_ASQ_InterfaceOptions", UIParent)
    panel.name = L("Spell Queue")
    panel:SetSize(520, 540)

    BuildSettings(panel, false)

    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name, panel.name)
        category.ID = panel.name
        Settings.RegisterAddOnCategory(category)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end

---------------------------------------------------------------------------
--  Init
---------------------------------------------------------------------------
do
    local init = CreateFrame("Frame")
    init:RegisterEvent("PLAYER_LOGIN")
    init:SetScript("OnEvent", function(self)
        self:UnregisterEvent("PLAYER_LOGIN")
        if not Addon.loaded then return end
        Options.UpdateStatusBar()
        CreateMinimapButton()
        CreateInterfaceOptionsPanel()
    end)
end
