if _G.EUI_CLIENT_BLOCKED then return end -- pre-12.1 client failsafe (set by EllesmereUI when present)

-------------------------------------------------------------------------------
--  Tate_ASQ_Formula.lua
--  Pure calculation module. No frames, no events, no CVar writes, no UI.
--  Everything that decides "what value should SpellQueueWindow have" lives here.
-------------------------------------------------------------------------------
local ADDON_NAME, ns = ...

local Formula = {}
_G.Tate_ASQFormula = Formula

---------------------------------------------------------------------------
--  Role classification tables
---------------------------------------------------------------------------

local MELEE_SPECS = {
    -- Death Knight
    [250] = true, -- Blood
    [251] = true, -- Frost
    [252] = true, -- Unholy
    -- Demon Hunter
    [577] = true, -- Havoc
    [581] = true, -- Vengeance
    [1480] = true, -- Devourer (hero spec)
    -- Druid
    [103] = true, -- Feral
    [104] = true, -- Guardian
    -- Hunter
    [255] = true, -- Survival
    -- Monk
    [268] = true, -- Brewmaster
    [269] = true, -- Windwalker
    [270] = true, -- Mistweaver (melee healer)
    -- Paladin
    [66] = true, -- Protection
    [70] = true, -- Retribution
    -- Rogue
    [259] = true, -- Assassination
    [260] = true, -- Outlaw
    [261] = true, -- Subtlety
    -- Shaman
    [263] = true, -- Enhancement
    -- Warrior
    [71] = true, -- Arms
    [72] = true, -- Fury
    [73] = true, -- Protection
}

local RANGED_SPECS = {
    -- Druid
    [102] = true, -- Balance
    [105] = true, -- Restoration
    -- Evoker
    [1467] = true, -- Devastation
    [1468] = true, -- Preservation
    [1473] = true, -- Augmentation
    -- Hunter
    [253] = true, -- Beast Mastery
    [254] = true, -- Marksmanship
    -- Mage
    [62] = true, -- Arcane
    [63] = true, -- Fire
    [64] = true, -- Frost
    -- Paladin
    [65] = true, -- Holy
    -- Priest
    [256] = true, -- Discipline
    [257] = true, -- Holy
    [258] = true, -- Shadow
    -- Shaman
    [262] = true, -- Elemental
    [264] = true, -- Restoration
    -- Warlock
    [265] = true, -- Affliction
    [266] = true, -- Demonology
    [267] = true, -- Destruction
}

local MELEE_CLASSES = {
    DEATHKNIGHT = true,
    DEMONHUNTER = true,
    MONK = true,
    ROGUE = true,
    WARRIOR = true,
}

---------------------------------------------------------------------------
--  Per-class base values (ms). Draft values, tuned for feel in-game.
---------------------------------------------------------------------------
local CLASS_BASE = {
    DEATHKNIGHT = { melee = 150 },
    DEMONHUNTER = { melee = 145 },
    DRUID       = { melee = 145, ranged = 225 },
    EVOKER      = { ranged = 230 },
    HUNTER      = { melee = 160, ranged = 200 },
    MAGE        = { ranged = 240 },
    MONK        = { melee = 140 },
    PALADIN     = { melee = 150, ranged = 230 },
    PRIEST      = { ranged = 225 },
    ROGUE       = { melee = 140 },
    SHAMAN      = { melee = 150, ranged = 220 },
    WARLOCK     = { ranged = 240 },
    WARRIOR     = { melee = 150 },
}

---------------------------------------------------------------------------
--  Per-spec overrides. Same class, different feel / mixed roles.
---------------------------------------------------------------------------
local SPEC_BASE = {
    -- Death Knight (tank slightly higher for mitigation queuing)
    [250] = 160, [251] = 150, [252] = 150,
    -- Demon Hunter
    [577] = 145, [581] = 160, [1480] = 145,
    -- Druid
    [102] = 230, [103] = 145, [104] = 150, [105] = 220,
    -- Evoker
    [1467] = 230, [1468] = 220, [1473] = 235,
    -- Hunter (BM instant -> low, MM casted -> higher, SV melee)
    [253] = 190, [254] = 210, [255] = 160,
    -- Mage
    [62] = 235, [63] = 245, [64] = 240,
    -- Monk
    [268] = 150, [269] = 140, [270] = 180,
    -- Paladin
    [65] = 230, [66] = 150, [70] = 150,
    -- Priest
    [256] = 220, [257] = 220, [258] = 225,
    -- Rogue (energy/combo -> low, avoid wrong finishers)
    [259] = 140, [260] = 145, [261] = 140,
    -- Shaman
    [262] = 220, [263] = 150, [264] = 220,
    -- Warlock
    [265] = 240, [266] = 240, [267] = 245,
    -- Warrior (protection slightly higher)
    [71] = 150, [72] = 150, [73] = 160,
}

local FALLBACK = { melee = 150, ranged = 220 }

---------------------------------------------------------------------------
--  Helpers
---------------------------------------------------------------------------
local function Clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function SafeNumber(v)
    if type(v) == "number" then return v end
    return tonumber(v) or 0
end

---------------------------------------------------------------------------
--  API
---------------------------------------------------------------------------

--- Returns "melee" or "ranged".
function Formula.Classify(specID, classFile)
    if MELEE_SPECS[specID] then return "melee" end
    if RANGED_SPECS[specID] then return "ranged" end
    -- Unknown spec (low-level initial spec, future spec, etc.): class fallback.
    if classFile and MELEE_CLASSES[classFile] then return "melee" end
    return "ranged"
end

--- Returns the base value (ms) before latency adjustment.
function Formula.GetBase(cfg, specID, classFile)
    if cfg.baseMode == "manual" then
        return SafeNumber(cfg.manualBase) > 0 and SafeNumber(cfg.manualBase) or FALLBACK.ranged
    end
    if specID and SPEC_BASE[specID] then
        return SPEC_BASE[specID]
    end
    local role = Formula.Classify(specID, classFile)
    local classEntry = classFile and CLASS_BASE[classFile]
    if classEntry and classEntry[role] then
        return classEntry[role]
    end
    return FALLBACK[role]
end

--- Selects one latency number from home/world according to the configured source.
function Formula.PickLatency(source, home, world)
    home = SafeNumber(home)
    world = SafeNumber(world)
    if source == "world" then
        return world
    elseif source == "home" then
        return home
    elseif source == "avg" then
        return (home + world) / 2
    end
    -- default: max
    return math.max(home, world)
end

--- Computes the final SpellQueueWindow target.
-- Returns: target, role, base, latency
function Formula.ComputeTarget(cfg, specID, classFile, home, world)
    local role = Formula.Classify(specID, classFile)
    local base = Formula.GetBase(cfg, specID, classFile)
    local latency = Formula.PickLatency(cfg.latencySource, home, world)

    local target
    if cfg.adaptive ~= false then
        target = math.max(base, latency + SafeNumber(cfg.margin))
    else
        target = base
    end

    target = Clamp(math.floor(target + 0.5), SafeNumber(cfg.minWindow), SafeNumber(cfg.maxWindow))
    return target, role, base, latency
end
