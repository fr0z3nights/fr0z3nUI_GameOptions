local _, ns = ...
ns = ns or {}

ns.SwitchesMU = ns.SwitchesMU or {}
local MU = ns.SwitchesMU

local function InitSV()
    if ns and type(ns._InitSV) == "function" then
        ns._InitSV()
    end
end

local function IsEnabled()
    InitSV()
    if not (AutoGossip_Settings and AutoGossip_CharSettings) then
        return false
    end
    if not (AutoGossip_Settings.mountUpEnabledAcc and true or false) then
        return false
    end
    if not (AutoGossip_CharSettings.mountUpEnabledChar and true or false) then
        return false
    end
    return true
end

local function GetDelay()
    InitSV()
    local d = tonumber(AutoGossip_Settings and AutoGossip_Settings.mountUpDelayAcc)
    if type(d) ~= "number" then
        return 1.0
    end
    if d < 0 then
        return 0
    end
    if d > 9.9 then
        return 9.9
    end
    return d
end

local function IsDelayUsedForReapRetry()
    InitSV()
    return (AutoGossip_Settings and AutoGossip_Settings.mountUpDelayUseReapAcc) and true or false
end

local function IsDelayUsedForCastRetry()
    InitSV()
    return (AutoGossip_Settings and AutoGossip_Settings.mountUpDelayUseCastAcc) and true or false
end

local function IsDelayUsedForLootRetry()
    InitSV()
    return (AutoGossip_Settings and AutoGossip_Settings.mountUpDelayUseLootAcc) and true or false
end

local function IsForceGroundEnabled()
    InitSV()
    if type(AutoGossip_CharSettings) ~= "table" then
        return false
    end
    return (AutoGossip_CharSettings.mountUpForceGroundChar and true or false)
end

local function SetForceGroundEnabled(v)
    InitSV()
    if type(AutoGossip_CharSettings) ~= "table" then
        return
    end
    AutoGossip_CharSettings.mountUpForceGroundChar = (v and true or false)
end

local GATHER_SPELL_IDS = {
    -- Gathering / harvesting (retail/common IDs)
    [2366] = true, -- Herbalism
    [2575] = true, -- Mining
    [8613] = true, -- Skinning
    [7620] = true, -- Fishing
}

local function IsGatherSpellID(spellID)
    spellID = tonumber(spellID)
    if type(spellID) ~= "number" then
        return false
    end
    return (GATHER_SPELL_IDS[spellID] and true or false)
end

local function GetRetryDelayForCast(spellID)
    if IsGatherSpellID(spellID) then
        return IsDelayUsedForReapRetry() and GetDelay() or 0.20
    end
    return IsDelayUsedForCastRetry() and GetDelay() or 0.20
end

local function GetRetryDelayForLoot()
    return IsDelayUsedForLootRetry() and GetDelay() or 0.20
end

local function NormalizePreferredSituation(situation)
    situation = tostring(situation or ""):lower()
    if situation == "flying" then
        return "flying"
    end
    if situation == "aquatic" or situation == "water" then
        return "aquatic"
    end
    return "ground"
end

local function NormalizePreferredProfileScope(scope)
    scope = tostring(scope or ""):lower()
    if scope == "faction" then return "faction" end
    if scope == "guild" then return "guild" end
    if scope == "class" then return "class" end
    if scope == "race" then return "race" end
    if scope == "char" or scope == "character" then return "character" end
    return "character"
end

local function GetLegacyPreferredMountID(situation)
    InitSV()
    situation = NormalizePreferredSituation(situation)

    local k
    if situation == "flying" then
        k = "mountUpPreferredMountIDFlyingAcc"
    elseif situation == "aquatic" then
        k = "mountUpPreferredMountIDAquaticAcc"
    else
        k = "mountUpPreferredMountIDGroundAcc"
    end
    return tonumber(AutoGossip_Settings and AutoGossip_Settings[k]) or 0
end

local function GetCurrentPreferredProfileScope()
    InitSV()
    local s = (AutoGossip_CharSettings and AutoGossip_CharSettings.mountUpPreferredScope) or "character"
    return NormalizePreferredProfileScope(s)
end

local function SetCurrentPreferredProfileScope(scope)
    InitSV()
    if type(AutoGossip_CharSettings) ~= "table" then
        return
    end
    AutoGossip_CharSettings.mountUpPreferredScope = NormalizePreferredProfileScope(scope)
end

local function GetCurrentFactionKey()
    if type(UnitFactionGroup) ~= "function" then
        return nil
    end
    local ok, faction = pcall(UnitFactionGroup, "player")
    if ok and type(faction) == "string" and faction ~= "" then
        return faction
    end
    return nil
end

local function GetCurrentGuildKey()
    local realm = (type(GetRealmName) == "function") and GetRealmName() or nil
    if type(realm) ~= "string" or realm == "" then
        realm = "UnknownRealm"
    end

    if type(IsInGuild) == "function" then
        local ok, inGuild = pcall(IsInGuild)
        if ok and inGuild ~= true then
            return nil
        end
    end

    if type(GetGuildInfo) ~= "function" then
        return nil
    end
    local ok, guildName = pcall(GetGuildInfo, "player")
    guildName = ok and guildName or nil
    if type(guildName) ~= "string" or guildName == "" then
        return nil
    end

    return realm .. "::" .. guildName
end

local function GetCurrentClassKey()
    if type(UnitClass) ~= "function" then
        return nil
    end
    local ok, _, classFile = pcall(UnitClass, "player")
    if ok and type(classFile) == "string" and classFile ~= "" then
        return classFile
    end
    return nil
end

local function GetCurrentRaceKey()
    if type(UnitRace) ~= "function" then
        return nil
    end
    local ok, _, raceFile = pcall(UnitRace, "player")
    if ok and type(raceFile) == "string" and raceFile ~= "" then
        return raceFile
    end
    return nil
end

local function EnsureCharPreferredMountStore()
    if type(AutoGossip_CharSettings) ~= "table" then
        return nil
    end
    AutoGossip_CharSettings.mountUpPreferredMountIDsChar = (type(AutoGossip_CharSettings.mountUpPreferredMountIDsChar) == "table")
            and AutoGossip_CharSettings.mountUpPreferredMountIDsChar
        or {}
    local t = AutoGossip_CharSettings.mountUpPreferredMountIDsChar
    if type(t.flying) ~= "number" then t.flying = 0 end
    if type(t.ground) ~= "number" then t.ground = 0 end
    if type(t.aquatic) ~= "number" then t.aquatic = 0 end
    return t
end

local function EnsureCharPreferredMountTouchedStore()
    if type(AutoGossip_CharSettings) ~= "table" then
        return nil
    end
    AutoGossip_CharSettings.mountUpPreferredMountTouchedChar = (type(AutoGossip_CharSettings.mountUpPreferredMountTouchedChar) == "table")
            and AutoGossip_CharSettings.mountUpPreferredMountTouchedChar
        or {}
    local t = AutoGossip_CharSettings.mountUpPreferredMountTouchedChar
    if type(t.flying) ~= "boolean" then t.flying = false end
    if type(t.ground) ~= "boolean" then t.ground = false end
    if type(t.aquatic) ~= "boolean" then t.aquatic = false end
    return t
end

local function EnsureAccPreferredMountStore()
    if type(AutoGossip_Settings) ~= "table" then
        return nil
    end
    AutoGossip_Settings.mountUpPreferredMountIDsScopes = (type(AutoGossip_Settings.mountUpPreferredMountIDsScopes) == "table")
            and AutoGossip_Settings.mountUpPreferredMountIDsScopes
        or {}
    local t = AutoGossip_Settings.mountUpPreferredMountIDsScopes
    t.faction = (type(t.faction) == "table") and t.faction or {}
    t.guild = (type(t.guild) == "table") and t.guild or {}
    t.class = (type(t.class) == "table") and t.class or {}
    t.race = (type(t.race) == "table") and t.race or {}
    return t
end

local function EnsureAccPreferredMountTouchedStore()
    if type(AutoGossip_Settings) ~= "table" then
        return nil
    end
    AutoGossip_Settings.mountUpPreferredMountTouchedScopes = (type(AutoGossip_Settings.mountUpPreferredMountTouchedScopes) == "table")
            and AutoGossip_Settings.mountUpPreferredMountTouchedScopes
        or {}
    local t = AutoGossip_Settings.mountUpPreferredMountTouchedScopes
    t.faction = (type(t.faction) == "table") and t.faction or {}
    t.guild = (type(t.guild) == "table") and t.guild or {}
    t.class = (type(t.class) == "table") and t.class or {}
    t.race = (type(t.race) == "table") and t.race or {}
    return t
end

local function MarkPreferredMountTouched(profileScope, situation)
    profileScope = NormalizePreferredProfileScope(profileScope)
    situation = NormalizePreferredSituation(situation)

    if profileScope == "character" then
        local t = EnsureCharPreferredMountTouchedStore()
        if t then
            t[situation] = true
        end
        return
    end

    local store = EnsureAccPreferredMountTouchedStore()
    if not store then
        return
    end

    local key
    if profileScope == "faction" then
        key = GetCurrentFactionKey()
    elseif profileScope == "guild" then
        key = GetCurrentGuildKey()
    elseif profileScope == "class" then
        key = GetCurrentClassKey()
    elseif profileScope == "race" then
        key = GetCurrentRaceKey()
    end

    if type(key) ~= "string" or key == "" then
        return
    end

    local bucket = store[profileScope]
    bucket[key] = (type(bucket[key]) == "table") and bucket[key] or {}
    local t = bucket[key]
    t[situation] = true
end

local function WasPreferredMountTouched(profileScope, situation)
    profileScope = NormalizePreferredProfileScope(profileScope)
    situation = NormalizePreferredSituation(situation)

    if profileScope == "character" then
        local t = EnsureCharPreferredMountTouchedStore()
        return (t and t[situation]) and true or false
    end

    local store = EnsureAccPreferredMountTouchedStore()
    if not store then
        return false
    end

    local key
    if profileScope == "faction" then
        key = GetCurrentFactionKey()
    elseif profileScope == "guild" then
        key = GetCurrentGuildKey()
    elseif profileScope == "class" then
        key = GetCurrentClassKey()
    elseif profileScope == "race" then
        key = GetCurrentRaceKey()
    end

    if type(key) ~= "string" or key == "" then
        return false
    end

    local bucket = store[profileScope]
    local t = bucket and bucket[key]
    return (type(t) == "table" and t[situation]) and true or false
end

local function GetScopedPreferredMountID_NoLegacy(profileScope, situation)
    InitSV()

    profileScope = NormalizePreferredProfileScope(profileScope)
    situation = NormalizePreferredSituation(situation)

    if profileScope == "character" then
        local t = EnsureCharPreferredMountStore()
        local v = tonumber(t and t[situation]) or 0
        return (v > 0) and v or 0
    end

    local store = EnsureAccPreferredMountStore()
    if not store then
        return 0
    end

    local key
    if profileScope == "faction" then
        key = GetCurrentFactionKey()
    elseif profileScope == "guild" then
        key = GetCurrentGuildKey()
    elseif profileScope == "class" then
        key = GetCurrentClassKey()
    elseif profileScope == "race" then
        key = GetCurrentRaceKey()
    end

    if type(key) ~= "string" or key == "" then
        return 0
    end

    local bucket = store[profileScope]
    local t = bucket and bucket[key]
    local v = tonumber(type(t) == "table" and t[situation]) or 0
    return (v > 0) and v or 0
end

local SetPreferredMountID

local function SeedPreferredMountFromLegacyIfNeeded(profileScope, situation)
    InitSV()

    profileScope = NormalizePreferredProfileScope(profileScope)
    situation = NormalizePreferredSituation(situation)

    -- Don't overwrite intentional user choices (including "Random" clears).
    if WasPreferredMountTouched(profileScope, situation) then
        return
    end

    local legacy = GetLegacyPreferredMountID(situation)
    if legacy <= 0 then
        return
    end

    local cur = GetScopedPreferredMountID_NoLegacy(profileScope, situation)
    if cur > 0 then
        return
    end

    SetPreferredMountID(profileScope, situation, legacy)
end

local function GetPreferredMountID(profileScope, situation)
    InitSV()

    profileScope = NormalizePreferredProfileScope(profileScope)
    situation = NormalizePreferredSituation(situation)

    local touched = WasPreferredMountTouched(profileScope, situation)

    -- One-time migration helper: if you still have legacy preferred mountIDs and
    -- this scope has nothing set yet, automatically seed the scope from legacy.
    SeedPreferredMountFromLegacyIfNeeded(profileScope, situation)

    if profileScope == "character" then
        local t = EnsureCharPreferredMountStore()
        local v = tonumber(t and t[situation]) or 0
        if v > 0 then
            return v
        end
        if touched then
            return 0
        end
        return GetLegacyPreferredMountID(situation)
    end

    local store = EnsureAccPreferredMountStore()
    if not store then
        return 0
    end

    local key
    if profileScope == "faction" then
        key = GetCurrentFactionKey()
    elseif profileScope == "guild" then
        key = GetCurrentGuildKey()
    elseif profileScope == "class" then
        key = GetCurrentClassKey()
    elseif profileScope == "race" then
        key = GetCurrentRaceKey()
    end

    if type(key) ~= "string" or key == "" then
        return 0
    end

    local bucket = store[profileScope]
    bucket[key] = (type(bucket[key]) == "table") and bucket[key] or {}
    local t = bucket[key]

    if type(t.flying) ~= "number" then t.flying = 0 end
    if type(t.ground) ~= "number" then t.ground = 0 end
    if type(t.aquatic) ~= "number" then t.aquatic = 0 end

    local v = tonumber(t[situation]) or 0
    if v > 0 then
        return v
    end

    -- If the user explicitly cleared this scope+slot, treat 0 as authoritative.
    if touched then
        return 0
    end

    return GetLegacyPreferredMountID(situation)
end

SetPreferredMountID = function(profileScope, situation, mountID)
    InitSV()

    profileScope = NormalizePreferredProfileScope(profileScope)
    situation = NormalizePreferredSituation(situation)
    mountID = tonumber(mountID) or 0
    if mountID < 0 then mountID = 0 end

    -- Mark as user-touched so we won't re-seed from legacy later.
    MarkPreferredMountTouched(profileScope, situation)

    if profileScope == "character" then
        local t = EnsureCharPreferredMountStore()
        if not t then
            return
        end
        t[situation] = mountID
        return
    end

    local store = EnsureAccPreferredMountStore()
    if not store then
        return
    end

    local key
    if profileScope == "faction" then
        key = GetCurrentFactionKey()
    elseif profileScope == "guild" then
        key = GetCurrentGuildKey()
    elseif profileScope == "class" then
        key = GetCurrentClassKey()
    elseif profileScope == "race" then
        key = GetCurrentRaceKey()
    end

    if type(key) ~= "string" or key == "" then
        return
    end

    local bucket = store[profileScope]
    bucket[key] = (type(bucket[key]) == "table") and bucket[key] or {}
    local t = bucket[key]

    t[situation] = mountID
end

local function CanUsePreferredProfileScope(profileScope)
    profileScope = NormalizePreferredProfileScope(profileScope)
    if profileScope == "guild" then
        return (GetCurrentGuildKey() ~= nil)
    end
    return true
end

local function GetActivePreferredMountIDForSituation(situation)
    local ps = GetCurrentPreferredProfileScope()
    return GetPreferredMountID(ps, situation)
end

local function SetActivePreferredMountIDForSituation(situation, mountID)
    local ps = GetCurrentPreferredProfileScope()
    SetPreferredMountID(ps, situation, mountID)
end

-- Floating Mount Up button position: Account-wide (default) or per Preferred Scope.
local function IsFloatPosAccountWideOutsideScope()
    InitSV()
    local ui = rawget(_G, "AutoGame_UI") or rawget(_G, "AutoGossip_UI")
    if type(ui) ~= "table" then
        return true
    end
    if ui.mountUpFloatPosAccOutsideScope == false then
        return false
    end
    return true
end

local function EnsurePosTbl(t)
    if type(t) ~= "table" then
        t = {}
    end
    if type(t.point) ~= "string" then t.point = "TOP" end
    if type(t.relativePoint) ~= "string" then t.relativePoint = "TOP" end
    if type(t.x) ~= "number" then t.x = 0 end
    if type(t.y) ~= "number" then t.y = -140 end
    return t
end

local function GetCurrentPreferredScopeKey(profileScope)
    profileScope = NormalizePreferredProfileScope(profileScope)
    if profileScope == "faction" then
        return GetCurrentFactionKey()
    elseif profileScope == "guild" then
        return GetCurrentGuildKey()
    elseif profileScope == "class" then
        return GetCurrentClassKey()
    elseif profileScope == "race" then
        return GetCurrentRaceKey()
    end
    return nil
end

local function EnsureAccFloatPosStore(ui)
    if type(ui) ~= "table" then
        return nil
    end
    ui.mountUpFloatPos = EnsurePosTbl(ui.mountUpFloatPos)
    return ui.mountUpFloatPos
end

local function EnsureAccFloatPosScopedStore(ui)
    if type(ui) ~= "table" then
        return nil
    end
    ui.mountUpFloatPosScopes = (type(ui.mountUpFloatPosScopes) == "table") and ui.mountUpFloatPosScopes or {}
    local s = ui.mountUpFloatPosScopes
    s.faction = (type(s.faction) == "table") and s.faction or {}
    s.guild = (type(s.guild) == "table") and s.guild or {}
    s.class = (type(s.class) == "table") and s.class or {}
    s.race = (type(s.race) == "table") and s.race or {}
    return s
end

local function CopyPosTbl(src)
    src = EnsurePosTbl(src)
    return { point = src.point, relativePoint = src.relativePoint, x = src.x, y = src.y }
end

local function EnsureCharFloatPosStore(fallbackPos)
    if type(AutoGossip_CharSettings) ~= "table" then
        return nil
    end

    if type(AutoGossip_CharSettings.mountUpFloatPosChar) ~= "table" then
        AutoGossip_CharSettings.mountUpFloatPosChar = CopyPosTbl(fallbackPos)
    else
        -- If this table exists but isn't initialized yet, seed from fallback.
        local t = AutoGossip_CharSettings.mountUpFloatPosChar
        if t.point == nil and t.relativePoint == nil and t.x == nil and t.y == nil then
            AutoGossip_CharSettings.mountUpFloatPosChar = CopyPosTbl(fallbackPos)
        end
    end
    AutoGossip_CharSettings.mountUpFloatPosChar = EnsurePosTbl(AutoGossip_CharSettings.mountUpFloatPosChar)
    return AutoGossip_CharSettings.mountUpFloatPosChar
end

local function GetActiveFloatPosStore()
    InitSV()
    local ui = rawget(_G, "AutoGame_UI") or rawget(_G, "AutoGossip_UI")
    if type(ui) ~= "table" then
        return nil
    end

    if IsFloatPosAccountWideOutsideScope() then
        return EnsureAccFloatPosStore(ui)
    end

    -- Scoped positioning: if the scope has no saved position yet, seed it from the
    -- current account-wide position so switching XY off feels consistent.
    local accPos = EnsureAccFloatPosStore(ui)

    local ps = GetCurrentPreferredProfileScope()
    if ps == "character" then
        return EnsureCharFloatPosStore(accPos)
    end

    local scopes = EnsureAccFloatPosScopedStore(ui)
    if not scopes then
        return nil
    end

    local key = GetCurrentPreferredScopeKey(ps)
    if type(key) ~= "string" or key == "" then
        return nil
    end

    local cur = scopes[ps][key]
    if type(cur) ~= "table" then
        scopes[ps][key] = CopyPosTbl(accPos)
    else
        if cur.point == nil and cur.relativePoint == nil and cur.x == nil and cur.y == nil then
            scopes[ps][key] = CopyPosTbl(accPos)
        end
    end
    scopes[ps][key] = EnsurePosTbl(scopes[ps][key])
    return scopes[ps][key]
end

local function SetActiveFloatPos(point, relativePoint, x, y)
    local t = GetActiveFloatPosStore()
    if type(t) ~= "table" then
        return
    end
    t.point = point
    t.relativePoint = relativePoint
    t.x = x
    t.y = y
end

local function SafeCall(func, ...)
    if type(func) ~= "function" then
        return nil
    end
    local ok, a, b, c, d = pcall(func, ...)
    if not ok then
        return nil
    end
    return a, b, c, d
end

local function IsInPetBattle()
    local fn = C_PetBattles and C_PetBattles.IsInBattle
    if type(fn) ~= "function" then
        return false
    end
    local ok, v = pcall(fn)
    if not ok then
        return false
    end
    return v and true or false
end

local function IsMoving()
    if not GetUnitSpeed then
        return false
    end
    local speed = GetUnitSpeed("player") or 0
    if issecretvalue and issecretvalue(speed) then
        return false
    end
    return (speed > 0) and true or false
end

local function IsCastingOrChanneling()
    if UnitCastingInfo and UnitCastingInfo("player") then
        return true
    end
    if UnitChannelInfo and UnitChannelInfo("player") then
        return true
    end
    return false
end

local function _DbgNow()
    if type(GetTime) == "function" then
        return tonumber(GetTime()) or 0
    end
    if type(time) == "function" then
        return tonumber(time()) or 0
    end
    return 0
end

local function _IsEatDbgEnabled()
    InitSV()
    return (AutoGossip_Settings and AutoGossip_Settings.mountUpDebugAcc) and true or false
end

local function _DbgEnsure()
    if not _IsEatDbgEnabled() then
        return nil
    end
    MU._eatdbg = MU._eatdbg or {}
    local d = MU._eatdbg
    d.history = d.history or {}
    return d
end

local function _DbgPush(kind, data)
    local d = _DbgEnsure()
    if not d then
        return nil
    end
    local ev = { t = _DbgNow(), kind = tostring(kind or "") }
    if type(data) == "table" then
        for k, v in pairs(data) do
            ev[k] = v
        end
    end
    local h = d.history
    h[#h + 1] = ev
    while #h > 30 do
        table.remove(h, 1)
    end
    d.lastEvent = ev
    return ev
end

local EAT_DRINK_IDS = {
    430, 431, 432, 433, -- legacy Food/Drink/Food&Drink
    167152, -- Conjured Refreshment
    452389, -- observed newer Food & Drink
    -- Expansion/patch-specific restoration auras
    1291946, 1269916, -- Food & Drink (variants)
    1269922, 1291842, 1291849, -- Food
    1269919, 1291954, -- Drink (variants)
    1291858, -- Mage food / conjured
    1277461, 1291831, -- Restoring Mana (specific)
    1291952, -- Restoring Health (specific)
    1291955, -- Tea consumption
    124036, -- Fishing Craft
}

local EAT_DRINK_IDSET = {}
for _, id in ipairs(EAT_DRINK_IDS) do
    EAT_DRINK_IDSET[id] = true
end

local EAT_DRINK_AURA_FILTERS = { "HELPFUL", "HELPFUL|PLAYER" }

local function SafeToNumber(v)
    local ok, n = pcall(tonumber, v)
    if ok and type(n) == "number" then
        return n
    end
    return nil
end

local function SafeEqToID(v, id)
    -- v can be a restricted/"secret" value; comparisons can throw.
    local n = SafeToNumber(v)
    if type(n) ~= "number" then
        return false
    end
    local ok, eq = pcall(function()
        return n == id
    end)
    return ok and eq or false
end

local function IsEatDrinkSpellID(spellID)
    -- IMPORTANT: spellID can be a restricted/"secret" value.
    -- Never use it as a table key (that can throw "table index is secret").
    -- Never directly compare secret numbers either; coerce+compare under pcall.
    if spellID == nil then
        return false
    end

    for _, id in ipairs(EAT_DRINK_IDS) do
        if SafeEqToID(spellID, id) then
            return true
        end
    end
    return false
end

local function IsEatingOrDrinking()
    -- NOTE: Some aura fields (including spellId/name) can be returned as restricted
    -- "secret" values. Direct comparisons (even after lowercasing) can taint and
    -- explode. So we ONLY use Blizzard helpers to do matching.

    -- Some clients don't reliably surface the aura immediately, but the cast/channel
    -- spell ID can be available right away.
    local snap = {
        t = _DbgNow(),
        found = false,
        method = nil,
        id = nil,
        filter = nil,
        auraIndex = nil,
        castSpellID = nil,
        channelSpellID = nil,
    }

    do
        local spellID
        if UnitChannelInfo then
            local _, _, _, _, _, _, _, id = UnitChannelInfo("player")
            spellID = id
            snap.channelSpellID = SafeToNumber(id)
        end
        if type(spellID) ~= "number" and UnitCastingInfo then
            local _, _, _, _, _, _, _, _, id = UnitCastingInfo("player")
            spellID = id
            snap.castSpellID = SafeToNumber(id)
        end
        if IsEatDrinkSpellID(spellID) then
            snap.found = true
            snap.method = "cast/channel"
            snap.id = SafeToNumber(spellID)
            do
                local d = _DbgEnsure()
                if d then d.eatLast = snap end
            end
            return true
        end
    end

    -- Modern API: scan player buffs by numeric spellId. This avoids name comparisons
    -- and catches cases where AuraUtil helpers don't find the aura quickly.
    do
        local unpackAura = AuraUtil and AuraUtil.UnpackAuraData
        if C_UnitAuras and type(C_UnitAuras.GetBuffDataByIndex) == "function" then
            for i = 1, 40 do
                local data = C_UnitAuras.GetBuffDataByIndex("player", i)
                if not data then
                    break
                end

                local spellID
                if type(data) == "table" then
                    spellID = data.spellId or data.spellID
                end
                if not spellID and type(unpackAura) == "function" then
                    spellID = select(10, unpackAura(data))
                end

                local sid = spellID
                if IsEatDrinkSpellID(sid) then
                    snap.found = true
                    snap.method = "C_UnitAuras"
                    snap.id = SafeToNumber(sid)
                    snap.auraIndex = i
                    do
                        local d = _DbgEnsure()
                        if d then d.eatLast = snap end
                    end
                    return true
                end
            end
        end
    end

    if AuraUtil and type(AuraUtil.FindAuraBySpellID) == "function" then
        for _, id in ipairs(EAT_DRINK_IDS) do
            for _, filter in ipairs(EAT_DRINK_AURA_FILTERS) do
                local ok, found = pcall(AuraUtil.FindAuraBySpellID, id, "player", filter)
                if ok and found then
                    snap.found = true
                    snap.method = "AuraUtil.FindAuraBySpellID"
                    snap.id = id
                    snap.filter = filter
                    do
                        local d = _DbgEnsure()
                        if d then d.eatLast = snap end
                    end
                    return true
                end
            end
        end
    end

    -- Secondary: name-based search using localized spell names.
    if AuraUtil and type(AuraUtil.FindAuraByName) == "function" and type(GetSpellInfo) == "function" then
        for _, id in ipairs(EAT_DRINK_IDS) do
            local ok, name = pcall(GetSpellInfo, id)
            if ok and type(name) == "string" and name ~= "" then
                for _, filter in ipairs(EAT_DRINK_AURA_FILTERS) do
                    local ok2, found = pcall(AuraUtil.FindAuraByName, name, "player", filter)
                    if ok2 and found then
                        snap.found = true
                        snap.method = "AuraUtil.FindAuraByName"
                        snap.id = id
                        snap.filter = filter
                        do
                            local d = _DbgEnsure()
                            if d then d.eatLast = snap end
                        end
                        return true
                    end
                end
            end
        end
    end

    do
        local d = _DbgEnsure()
        if d then d.eatLast = snap end
    end
    return false
end

local function CanMountNow()
    if not IsEnabled() then
        return false
    end

    if not (C_MountJournal and type(C_MountJournal.GetMountIDs) == "function" and type(C_MountJournal.SummonByID) == "function") then
        return false
    end

    if IsMounted and IsMounted() then
        return false
    end

    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then
        return false
    end

    if UnitOnTaxi and UnitOnTaxi("player") then
        return false
    end

    if UnitInVehicle and UnitInVehicle("player") then
        return false
    end

    if UnitUsingVehicle and UnitUsingVehicle("player") then
        return false
    end

    if IsEatingOrDrinking() then
        return false
    end

    if IsInPetBattle() then
        return false
    end

    if UnitAffectingCombat and UnitAffectingCombat("player") then
        return false
    end

    if InCombatLockdown and InCombatLockdown() then
        return false
    end

    if IsFalling and IsFalling() then
        return false
    end

    if IsFlying and IsFlying() then
        return false
    end

    if IsIndoors and IsIndoors() then
        return false
    end

    if IsMoving() then
        return false
    end

    if IsCastingOrChanneling() then
        return false
    end

    return true
end

local function GetMountedMountID()
    -- Prefer Mount Journal's active flag; aura scanning can fail for some mounts.
    if C_MountJournal and type(C_MountJournal.GetMountIDs) == "function" and type(C_MountJournal.GetMountInfoByID) == "function" then
        local ok, ids = pcall(C_MountJournal.GetMountIDs)
        if ok and type(ids) == "table" then
            for _, mountID in ipairs(ids) do
                local ok2, _, _, _, isActive = pcall(C_MountJournal.GetMountInfoByID, mountID)
                if ok2 and isActive then
                    return mountID
                end
            end
        end
    end

    if not (C_MountJournal and type(C_MountJournal.GetMountFromSpell) == "function") then
        return nil
    end

    local unpackAura = AuraUtil and AuraUtil.UnpackAuraData

    if C_UnitAuras and C_UnitAuras.GetBuffDataByIndex then
        for i = 1, 40 do
            local data = C_UnitAuras.GetBuffDataByIndex("player", i)
            if not data then
                break
            end

            local spellID
            if type(data) == "table" then
                spellID = data.spellId or data.spellID
            end
            if not spellID and type(unpackAura) == "function" then
                spellID = select(10, unpackAura(data))
            end

            if spellID then
                local mountID = SafeCall(C_MountJournal.GetMountFromSpell, spellID)
                if type(mountID) == "number" and mountID > 0 then
                    return mountID
                end
            end
        end
    end

    return nil
end

local function GetNamedMountType(mountTypeID)
    -- Use the same simple hard-mapping Dugi uses.
    -- We intentionally do NOT "guess": unknown IDs remain "other".
    if mountTypeID == 230 then
        return "ground"
    end

    -- Observed on your Retail client:
    -- - 284: Chauffeured Mekgineer's Chopper (ground)
    if mountTypeID == 284 then
        return "ground"
    end

    if mountTypeID == 248 then
        return "flying"
    end

    if mountTypeID == 402 then
        -- Advanced flying / skyriding: treat as flying for situation selection.
        return "flying"
    end

    -- Observed on your Retail client:
    -- - 424: Golden Gryphon / Startouched Furline (flying)
    -- - 437: Red Flying Cloud (flying)
    if mountTypeID == 424 or mountTypeID == 437 then
        return "flying"
    end

    if mountTypeID == 254 or mountTypeID == 231 or mountTypeID == 232 then
        return "aquatic"
    end
    return "other"
end

local function GetDesiredType()
    local isInWater = (IsSubmerged and IsSubmerged()) or (IsSwimming and IsSwimming())
    if isInWater then
        return "aquatic"
    end

    -- Ground override: never choose a flying mount in flyable zones.
    if IsForceGroundEnabled() then
        return "ground"
    end

    local flyableArea = (IsAdvancedFlyableArea and IsAdvancedFlyableArea()) or (IsFlyableArea and IsFlyableArea())
    if flyableArea then
        return "flying"
    end
    return "ground"
end

local function IsMountUsable(mountID)
    if not (C_MountJournal and type(C_MountJournal.GetMountInfoByID) == "function") then
        return false
    end

    local ok, _, _, _, _, isUsable, _, _, _, _, _, isCollected = pcall(C_MountJournal.GetMountInfoByID, mountID)
    if not ok then
        return false
    end

    return (isUsable and true or false) and (isCollected and true or false)
end

local function GetMountUsabilityReason(mountID)
    mountID = tonumber(mountID) or 0
    if mountID <= 0 then
        return false, "Invalid mountID"
    end

    if not (C_MountJournal and type(C_MountJournal.GetMountInfoByID) == "function") then
        return false, "Mount Journal unavailable"
    end

    local ok, _, _, _, _, isUsable, _, _, _, _, _, isCollected = pcall(C_MountJournal.GetMountInfoByID, mountID)
    if not ok then
        return false, "Invalid mountID"
    end

    if not (isCollected and true or false) then
        return false, "Not collected"
    end
    if not (isUsable and true or false) then
        return false, "Not usable"
    end

    return true, nil
end

local function PickMount()
    if not (C_MountJournal and C_MountJournal.GetMountIDs and C_MountJournal.GetMountInfoByID and C_MountJournal.GetMountInfoExtraByID) then
        return nil
    end

    InitSV()

    local forceGround = IsForceGroundEnabled()

    local function PickForDesired(desired)
        local function IsNamedTypeAllowed(named)
            if named == desired then
                return true
            end
            return false
        end

        -- Per-scope preferred mount override.
        -- Strict picker rule: random selection is strict by situation type.
        -- Exception: while grounded, allow a preferred flying mount if the user explicitly
        -- set it as the Ground preferred mount.
        local preferredID = GetActivePreferredMountIDForSituation(desired)
        if preferredID > 0 and IsMountUsable(preferredID) then
            local ok2, _, _, _, _, mountTypeID = pcall(C_MountJournal.GetMountInfoExtraByID, preferredID)
            if ok2 then
                local named = GetNamedMountType(mountTypeID)
                if IsNamedTypeAllowed(named) or ((not forceGround) and desired == "ground" and named == "flying") then
                    return preferredID
                end
            end
        end

        local function FindBest(favoritesOnly)
            local bestScore
            local best = {}

            for _, mountID in pairs(C_MountJournal.GetMountIDs()) do
                local ok, _, _, _, _, isUsable, _, isFavorite, _, _, _, isCollected = pcall(C_MountJournal.GetMountInfoByID, mountID)
                if ok and isUsable and isCollected then
                    if (not favoritesOnly) or (isFavorite and true or false) then
                        local ok2, _, _, _, _, mountTypeID = pcall(C_MountJournal.GetMountInfoExtraByID, mountID)
                        if ok2 then
                            local named = GetNamedMountType(mountTypeID)

                            -- Strict candidate filter by situation type.
                            -- Note: we intentionally do NOT include flying mounts in the grounded
                            -- random pool; those are only allowed via the preferred override above.
                            if IsNamedTypeAllowed(named) then
                                local score = 1
                                if isFavorite then
                                    score = score + 0.1
                                end

                                if bestScore == nil or score >= bestScore then
                                    if bestScore and score > bestScore then
                                        best = {}
                                    end
                                    best[#best + 1] = mountID
                                    bestScore = score
                                end
                            end
                        end
                    end
                end
            end

            if #best > 0 then
                local idx = math.random(1, #best)
                return best[idx]
            end
            return nil
        end

        -- Default behavior: favorites first (dugi-style), then fall back to any usable mount.
        local pick = FindBest(true)
        if pick then
            return pick
        end
        return FindBest(false)
    end

    local desired = GetDesiredType()
    local pick = PickForDesired(desired)
    if pick then
        return pick
    end

    -- Dugi-like fallback: if the area is flyable but we can't find a usable flying mount,
    -- fall back to ground instead of doing nothing.
    if desired == "flying" then
        return PickForDesired("ground")
    end

    return nil
end

local function TryMount(reason)
    if not CanMountNow() then
        local d = _DbgEnsure()
        if d then
            d.lastTry = _DbgPush("try", { reason = tostring(reason or ""), ok = false, stage = "CanMountNow" })
        end
        return false
    end

    -- Re-check here because Mount Up can be delayed.
    if IsEatingOrDrinking() then
        local d = _DbgEnsure()
        if d then
            local eat = d.eatLast
            d.lastTry = _DbgPush("try", {
                reason = tostring(reason or ""),
                ok = false,
                stage = "eating",
                eatFound = eat and eat.found or nil,
                eatMethod = eat and eat.method or nil,
                eatID = eat and eat.id or nil,
            })
        end
        return false
    end

    local mountID = PickMount()
    if type(mountID) ~= "number" or mountID <= 0 then
        local d = _DbgEnsure()
        if d then
            d.lastTry = _DbgPush("try", { reason = tostring(reason or ""), ok = false, stage = "PickMount" })
        end
        return false
    end

    SafeCall(C_MountJournal.SummonByID, mountID)
    local d = _DbgEnsure()
    if d then
        d.lastTry = _DbgPush("try", { reason = tostring(reason or ""), ok = true, stage = "Summon", mountID = mountID })
    end
    return true
end

function MU.DebugDumpMountTypes()
    if not (C_MountJournal and C_MountJournal.GetMountIDs and C_MountJournal.GetMountInfoByID and C_MountJournal.GetMountInfoExtraByID) then
        print("|cff00ccff[FGO]|r MU types: Mount Journal API not available")
        return
    end

    local flyable = (IsAdvancedFlyableArea and IsAdvancedFlyableArea()) or (IsFlyableArea and IsFlyableArea())
    local swim = (IsSwimming and IsSwimming()) or false
    local sub = (IsSubmerged and IsSubmerged()) or false

    local enum = Enum and Enum.MountType
    local eGround = enum and enum.Ground
    local eFlying = enum and enum.Flying
    local eUnder = enum and enum.Underwater
    local eDragon = enum and enum.Dragonriding

    local counts = { flying = 0, ground = 0, aquatic = 0, other = 0 }
    local otherIDs = {}

    for _, mountID in ipairs(C_MountJournal.GetMountIDs()) do
        local ok, name, _, _, _, isUsable, _, _, _, _, _, isCollected = pcall(C_MountJournal.GetMountInfoByID, mountID)
        if ok and isUsable and isCollected then
            local ok2, _, _, _, _, mountTypeID = pcall(C_MountJournal.GetMountInfoExtraByID, mountID)
            if ok2 then
                local named = GetNamedMountType(mountTypeID)
                counts[named] = (counts[named] or 0) + 1
                if named == "other" then
                    local entry = otherIDs[mountTypeID]
                    if not entry then
                        entry = { n = 0, example = name }
                        otherIDs[mountTypeID] = entry
                    end
                    entry.n = entry.n + 1
                    if (not entry.example or entry.example == "") and type(name) == "string" then
                        entry.example = name
                    end
                end
            end
        end
    end

    print(string.format("|cff00ccff[FGO]|r MU types: flyable=%s swim=%s sub=%s", tostring(flyable), tostring(swim), tostring(sub)))
    print(string.format("|cff00ccff[FGO]|r Enum.MountType: Ground=%s Flying=%s Underwater=%s Dragonriding=%s", tostring(eGround), tostring(eFlying), tostring(eUnder), tostring(eDragon)))
    print(string.format("|cff00ccff[FGO]|r usable+collected counts: flying=%d ground=%d aquatic=%d other=%d", counts.flying or 0, counts.ground or 0, counts.aquatic or 0, counts.other or 0))

    local keys = {}
    for k in pairs(otherIDs) do
        keys[#keys + 1] = k
    end
    table.sort(keys)

    for _, k in ipairs(keys) do
        local entry = otherIDs[k]
        print(string.format("|cff00ccff[FGO]|r other mountTypeID=%s count=%d example=%s", tostring(k), entry.n or 0, tostring(entry.example or "")))
    end
end

function MU.DebugPrintMountedMountType()
    if not (C_MountJournal and C_MountJournal.GetMountInfoByID and C_MountJournal.GetMountInfoExtraByID) then
        print("|cff00ccff[FGO]|r MU mounted: Mount Journal API not available")
        return
    end
    local mountID = GetMountedMountID()
    if type(mountID) ~= "number" or mountID <= 0 then
        print("|cff00ccff[FGO]|r MU mounted: not mounted")
        return
    end
    local ok, name = pcall(C_MountJournal.GetMountInfoByID, mountID)
    local ok2, _, _, _, _, mountTypeID = pcall(C_MountJournal.GetMountInfoExtraByID, mountID)
    local named = ok2 and GetNamedMountType(mountTypeID) or "?"
    print(string.format("|cff00ccff[FGO]|r MU mounted: %s (mountID=%s mountTypeID=%s named=%s)", tostring(ok and name or "?"), tostring(mountID), tostring(ok2 and mountTypeID or "?"), tostring(named)))
end

function MU.DebugPrintPreferredMounts()
    InitSV()

    local ps = GetCurrentPreferredProfileScope()
    local key = GetCurrentPreferredScopeKey(ps)
    local target = (type(key) == "string" and key ~= "") and key or "(no target)"

    print(string.format("|cff00ccff[FGO]|r MU preferred: scope=%s target=%s", tostring(string.upper(ps)), tostring(target)))

    local function GetMountNameSafe(mountID)
        if mountID <= 0 then
            return "Random/Favorite"
        end
        if C_MountJournal and C_MountJournal.GetMountInfoByID then
            local ok, name = pcall(C_MountJournal.GetMountInfoByID, mountID)
            if ok and type(name) == "string" and name ~= "" then
                return name
            end
        end
        return "(set)"
    end

    local function PrintSituation(situation)
        local id = GetPreferredMountID(ps, situation)
        local name = GetMountNameSafe(id)
        if id <= 0 then
            print(string.format("|cff00ccff[FGO]|r  %s: %s (%s)", tostring(situation), tostring(id), tostring(name)))
            return
        end
        local usable, reason = GetMountUsabilityReason(id)
        if usable then
            print(string.format("|cff00ccff[FGO]|r  %s: %s (%s)", tostring(situation), tostring(id), tostring(name)))
        else
            print(string.format("|cff00ccff[FGO]|r  %s: %s (%s) [NOT usable: %s]", tostring(situation), tostring(id), tostring(name), tostring(reason or "Unknown")))
        end
    end

    PrintSituation("flying")
    PrintSituation("ground")
    PrintSituation("aquatic")
end

local pendingTimer
local lastArmAt = 0
local lastArmReason

local RECUPERATE_SPELL_ID = 1231411
local recuperateBlockUntil = 0

local function GetRecuperateBlockRemaining()
    if type(GetTime) ~= "function" then
        return 0
    end
    local now = GetTime() or 0
    local rem = (tonumber(recuperateBlockUntil) or 0) - now
    if rem < 0 then rem = 0 end
    return rem
end

local function ArmWindow(reason)
    if type(GetTime) ~= "function" then
        lastArmAt = 0
        lastArmReason = reason
        return
    end
    lastArmAt = GetTime() or 0
    lastArmReason = reason
end

local function IsWithinArmWindow(seconds)
    seconds = tonumber(seconds) or 8.0
    if seconds < 0 then
        seconds = 0
    end
    if type(GetTime) ~= "function" then
        return true
    end
    local now = GetTime() or 0
    return (now - (tonumber(lastArmAt) or 0)) <= seconds
end

local function CancelPending()
    if pendingTimer and pendingTimer.Cancel then
        pendingTimer:Cancel()
    end
    pendingTimer = nil
end

local function ScheduleMount(reason, delay)
    if not IsEnabled() then
        CancelPending()
        return
    end

    ArmWindow(reason)

    delay = tonumber(delay)
    if type(delay) ~= "number" then
        delay = GetDelay()
    end
    if delay < 0 then
        delay = 0
    end

    -- If Recuperate was just cast, don't mount until it has had time to apply.
    do
        local rem = GetRecuperateBlockRemaining()
        if rem > 0 and rem > delay then
            delay = rem
        end
    end

    CancelPending()

    do
        local d = _DbgEnsure()
        if d then
            d.lastSchedule = _DbgPush("schedule", { reason = tostring(reason or ""), delay = delay })
        end
    end

    if not (C_Timer and C_Timer.NewTimer) then
        TryMount(reason)
        return
    end

    pendingTimer = C_Timer.NewTimer(delay, function()
        pendingTimer = nil
        TryMount(reason)
    end)
end

function MU.DebugPrintEatDrink()
    if not _IsEatDbgEnabled() then
        print("|cff00ccff[FGO]|r MU eat/drink debug: DBG is OFF (enable MU DBG)")
        return
    end
    local d = MU._eatdbg
    print("|cff00ccff[FGO]|r MU eat/drink debug")

    local e = d and d.eatLast
    if e then
        print(string.format("|cff00ccff[FGO]|r  lastCheck: t=%.2f found=%s method=%s id=%s filter=%s auraIndex=%s cast=%s channel=%s",
            tonumber(e.t) or 0,
            tostring(e.found and true or false),
            tostring(e.method or ""),
            tostring(e.id or ""),
            tostring(e.filter or ""),
            tostring(e.auraIndex or ""),
            tostring(e.castSpellID or ""),
            tostring(e.channelSpellID or "")))
    else
        print("|cff00ccff[FGO]|r  lastCheck: (none yet)")
    end

    local s = d and d.lastSchedule
    if s then
        print(string.format("|cff00ccff[FGO]|r  lastSchedule: t=%.2f reason=%s delay=%s",
            tonumber(s.t) or 0, tostring(s.reason or ""), tostring(s.delay or "")))
    else
        print("|cff00ccff[FGO]|r  lastSchedule: (none yet)")
    end

    local t = d and d.lastTry
    if t then
        print(string.format("|cff00ccff[FGO]|r  lastTry: t=%.2f reason=%s ok=%s stage=%s mountID=%s eatFound=%s eatMethod=%s eatID=%s",
            tonumber(t.t) or 0,
            tostring(t.reason or ""),
            tostring(t.ok and true or false),
            tostring(t.stage or ""),
            tostring(t.mountID or ""),
            tostring(t.eatFound or ""),
            tostring(t.eatMethod or ""),
            tostring(t.eatID or "")))
    else
        print("|cff00ccff[FGO]|r  lastTry: (none yet)")
    end

    local h = d and d.history
    if type(h) == "table" and #h > 0 then
        local n = #h
        local first = n - 4
        if first < 1 then first = 1 end
        for i = first, n do
            local ev = h[i]
            if type(ev) == "table" then
                print(string.format("|cff00ccff[FGO]|r  hist[%d]: t=%.2f kind=%s reason=%s stage=%s ok=%s delay=%s id=%s",
                    i,
                    tonumber(ev.t) or 0,
                    tostring(ev.kind or ""),
                    tostring(ev.reason or ""),
                    tostring(ev.stage or ""),
                    tostring(ev.ok or ""),
                    tostring(ev.delay or ""),
                    tostring(ev.eatID or ev.id or "")))
            end
        end
    end
end

function MU.OnSettingsChanged()
    if not IsEnabled() then
        CancelPending()
        if MU.UpdateMountUpFloatButton then
            MU.UpdateMountUpFloatButton()
        end
        return
    end
    ScheduleMount("settings", 0.15)
    if MU.UpdateMountUpFloatButton then
        MU.UpdateMountUpFloatButton()
    end
end

-- ============================================================================
-- Floating Mount Up button (text-only, draggable; styled like Reload UI float)
-- ============================================================================

do
    local btn
    local lastLabelUpdateAt = 0
    local movingTicker

    local function CanMountHereNow()
        if not IsEnabled() then
            return false
        end

        if not (C_MountJournal and type(C_MountJournal.GetMountIDs) == "function" and type(C_MountJournal.SummonByID) == "function") then
            return false
        end

        -- Area-only indicator (logic):
        -- Indoors is a pure location restriction.
        if IsIndoors and IsIndoors() then
            return false
        end

        -- If we can't find any usable mount right now, treat it as a no-mount area.
        -- (Note: this is still best-effort; WoW doesn't expose a perfect "mount allowed here" API.)
        local pick = PickMount()
        return (type(pick) == "number" and pick > 0) and true or false

    end

    local function Tooltip_ApplyFontDelta(tt, delta, stashKey)
        if not (tt and tt.GetName and tt.NumLines) then
            return
        end
        local name = tt:GetName()
        if type(name) ~= "string" or name == "" then
            return
        end

        tt._fgoFontBackup = tt._fgoFontBackup or {}
        local stash = {}

        local n = tt:NumLines() or 0
        for i = 1, n do
            for _, side in ipairs({ "Left", "Right" }) do
                local fs = _G and _G[name .. "Text" .. side .. i]
                if fs and fs.GetFont and fs.SetFont then
                    local fontPath, fontSize, fontFlags = fs:GetFont()
                    if fontPath and type(fontSize) == "number" then
                        stash[#stash + 1] = { fs = fs, path = fontPath, size = fontSize, flags = fontFlags }
                        local newSize = fontSize + (tonumber(delta) or 0)
                        if newSize < 1 then newSize = 1 end
                        fs:SetFont(fontPath, newSize, fontFlags)
                    end
                end
            end
        end

        tt._fgoFontBackup[stashKey] = stash
    end

    local function Tooltip_RestoreFonts(tt, stashKey)
        local backup = tt and tt._fgoFontBackup and tt._fgoFontBackup[stashKey]
        if type(backup) ~= "table" then
            return
        end
        for _, rec in ipairs(backup) do
            if rec and rec.fs and rec.fs.SetFont then
                rec.fs:SetFont(rec.path, rec.size, rec.flags)
            end
        end
        tt._fgoFontBackup[stashKey] = nil
    end

    local function GetUI()
        InitSV()
        return rawget(_G, "AutoGame_UI") or rawget(_G, "AutoGossip_UI")
    end

    local function IsFloatEnabled()
        local ui = GetUI()
        if not ui then
            return false
        end
        return (ui.mountUpFloatEnabled and true or false)
    end

    local function IsLocked()
        local ui = GetUI()
        if not ui then
            return false
        end
        return (ui.mountUpFloatLocked and true or false)
    end

    local function ApplySavedPosition(frame)
        local ui = GetUI()
        if not (ui and frame and frame.SetPoint) then
            return
        end

        local p = GetActiveFloatPosStore() or ui.mountUpFloatPos
        if type(p) ~= "table" then
            return
        end
        local point = type(p.point) == "string" and p.point or "TOP"
        local relPoint = type(p.relativePoint) == "string" and p.relativePoint or point
        local x = tonumber(p.x) or 0
        local y = tonumber(p.y) or -140

        frame:ClearAllPoints()
        frame:SetPoint(point, UIParent, relPoint, x, y)
    end

    local function GetStateColor()
        InitSV()
        -- Red: account disabled (Button 1)
        if not (AutoGossip_Settings and AutoGossip_Settings.mountUpEnabledAcc and true or false) then
            return "ffff0000", "acc-off"
        end
        -- Green: char enabled (Button 2)
        if (AutoGossip_CharSettings and AutoGossip_CharSettings.mountUpEnabledChar and true or false) then
            if CanMountHereNow() then
                return "ff00ff00", "char-on"
            end
            -- Grey: enabled but this location blocks mounting (indoors/vehicle/taxi/etc)
            return "ff808080", "blocked"
        end
        -- Orange: char disabled (Button 2)
        return "ffff8000", "char-off"
    end

    local UpdateLabel

    local function UpdateLabelThrottled(force)
        if not (btn and btn._label and btn._label.SetText) then
            return
        end
        if btn.IsShown and not btn:IsShown() then
            return
        end

        local now = (type(GetTime) == "function" and (GetTime() or 0)) or 0
        if not force then
            local delta = now - (tonumber(lastLabelUpdateAt) or 0)
            if delta < 0.20 then
                return
            end
        end
        lastLabelUpdateAt = now
        UpdateLabel()
    end

    local function StopMovingTicker()
        if movingTicker and movingTicker.Cancel then
            movingTicker:Cancel()
        end
        movingTicker = nil
    end

    local function StartMovingTicker()
        StopMovingTicker()
        if not (C_Timer and C_Timer.NewTicker) then
            return
        end
        -- While moving, poll at a low rate so grey/green can flip
        -- as you cross into/out of mount-allowed space.
        movingTicker = C_Timer.NewTicker(0.25, function()
            UpdateLabelThrottled(false)
        end)
    end

    UpdateLabel = function()
        if not (btn and btn._label and btn._label.SetText) then
            return
        end
        local color, _ = GetStateColor()
        btn._label:SetText("|c" .. color .. "Mount Up|r")
    end

    local function ApplyTextSize()
        if not (btn and btn._label and btn._label.SetFont) then
            return
        end
        local ui = GetUI()
        local want = ui and tonumber(ui.mountUpFloatTextSize)
        if type(want) ~= "number" then
            return
        end
        if want < 8 then want = 8 end
        if want > 24 then want = 24 end
        local fontPath, _, fontFlags = btn._label:GetFont()
        if fontPath then
            btn._label:SetFont(fontPath, want, fontFlags)
        end
    end

    function MU.EnsureMountUpFloatButton()
        if btn and btn.SetText then
            return btn
        end
        if not (CreateFrame and UIParent) then
            return nil
        end

        btn = CreateFrame("Button", "FGO_FloatingMountUpButton", UIParent)
        btn:SetSize(90, 18)
        btn:SetClampedToScreen(true)
        btn:SetFrameStrata("DIALOG")
        btn:EnableMouse(true)
        btn:SetMovable(true)
        btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        btn:RegisterForDrag("RightButton")

        local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetAllPoints(btn)
        fs:SetJustifyH("CENTER")
        fs:SetJustifyV("MIDDLE")
        btn._label = fs

        ApplyTextSize()

        ApplySavedPosition(btn)
        UpdateLabel()

        btn:SetScript("OnClick", function(_, mouseButton)
            if mouseButton == "RightButton" then
                if IsLocked() and type(DoEmote) == "function" then
                    DoEmote("MOUNTSPECIAL")
                end
                return
            end

            if mouseButton ~= "LeftButton" then
                return
            end

            InitSV()
            if not (AutoGossip_Settings and AutoGossip_Settings.mountUpEnabledAcc and true or false) then
                return
            end
            AutoGossip_CharSettings.mountUpEnabledChar = not (AutoGossip_CharSettings.mountUpEnabledChar and true or false)
            UpdateLabel()
            MU.OnSettingsChanged()
        end)

        btn:SetScript("OnDragStart", function(self)
            if IsLocked() then
                return
            end
            if self and self.StartMoving then
                self:StartMoving()
            end
        end)
        btn:SetScript("OnDragStop", function(self)
            if self and self.StopMovingOrSizing then
                self:StopMovingOrSizing()
            end

            if IsLocked() then
                ApplySavedPosition(self)
                return
            end

            local ui = GetUI()
            if not ui then
                return
            end
            local point, _, relPoint, x, y = self:GetPoint(1)
            SetActiveFloatPos(point, relPoint, x, y)
        end)

        btn:SetScript("OnEnter", function(self)
            if not GameTooltip then
                return
            end
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText("|cff00ccff[FGO]|r Mount Up")

            local _, state = GetStateColor()
            if state == "acc-off" then
                GameTooltip:AddLine("Account is OFF.", 1, 1, 1, true)
                GameTooltip:AddLine("/fgo mu acc", 1, 1, 1, true)
            else
                local onChar = (AutoGossip_CharSettings and AutoGossip_CharSettings.mountUpEnabledChar and true or false)
                GameTooltip:AddLine("Left-click: " .. (onChar and "disable" or "enable"), 1, 1, 1, true)
            end

            if IsLocked() then
                GameTooltip:AddLine("Right-click: mount special", 1, 1, 1, true)
            else
                GameTooltip:AddLine("Right-drag: move", 1, 1, 1, true)
            end

            Tooltip_ApplyFontDelta(GameTooltip, -1, "FGO_MountUpFloat")
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function()
            if GameTooltip then
                Tooltip_RestoreFonts(GameTooltip, "FGO_MountUpFloat")
                GameTooltip:Hide()
            end
        end)

        return btn
    end

    function MU.UpdateMountUpFloatButton()
        InitSV()
        if IsFloatEnabled() then
            local b = MU.EnsureMountUpFloatButton()
            if b and b.Show then
                ApplySavedPosition(b)
                ApplyTextSize()
                UpdateLabelThrottled(true)
                b:Show()
            end
        else
            if btn and btn.Hide then
                btn:Hide()
            end
        end
    end

    local function OnEvent(_, event, ...)
        if event == "PLAYER_LOGIN" or event == "VARIABLES_LOADED" then
            MU.UpdateMountUpFloatButton()
            UpdateLabelThrottled(true)
            if IsMoving and IsMoving() then
                StartMovingTicker()
            else
                StopMovingTicker()
            end
            return
        end

        if event == "PLAYER_STARTED_MOVING" then
            StartMovingTicker()
        elseif event == "PLAYER_STOPPED_MOVING" then
            StopMovingTicker()
            UpdateLabelThrottled(true)
            return
        end

        UpdateLabelThrottled(false)
    end

    local f = _G.CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:RegisterEvent("VARIABLES_LOADED")

    -- State refresh events (label only; does not mount)
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    f:RegisterEvent("ZONE_CHANGED_INDOORS")
    f:RegisterEvent("PLAYER_CONTROL_GAINED")
    f:RegisterEvent("PLAYER_CONTROL_LOST")
    f:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
    f:RegisterEvent("PLAYER_STARTED_MOVING")
    f:RegisterEvent("PLAYER_STOPPED_MOVING")

    f:SetScript("OnEvent", OnEvent)
end

-- ============================================================================
-- Config popout (same strategy as Pet Walk)
-- ============================================================================

local configPopup

local function EnsureConfigPopup()
    if configPopup or not UIParent or not CreateFrame then
        return configPopup
    end

    local p = CreateFrame("Frame", "FGO_MountUpConfigPopup", UIParent, "BackdropTemplate")
    p:SetSize(360, 260)
    do
        local main = _G and rawget(_G, "AutoGameOptions")
        if main and main.IsShown and main:IsShown() then
            -- Overlap by 8px to remove the visible gap caused by 4px backdrop insets on both frames.
            p:SetPoint("TOPLEFT", main, "TOPRIGHT", -8, 0)
        else
            p:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end
    end
    p:SetFrameStrata("DIALOG")
    p:SetClampedToScreen(true)
    p:Hide()

    do
        local key = "mountUpCfg"
        local reg = _G and rawget(_G, "FGO_RegisterPopout")
        if type(reg) == "function" then
            reg(key, function()
                if p and p.Hide then
                    p:Hide()
                end
            end)
        end
        local prev = p.GetScript and p:GetScript("OnShow")
        p:SetScript("OnShow", function(self, ...)
            local closeAll = _G and rawget(_G, "FGO_CloseAllPopouts")
            if type(closeAll) == "function" then
                closeAll(key)
            end
            if type(prev) == "function" then
                prev(self, ...)
            end
        end)
    end

    p:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        tile = true,
        tileSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    p:SetBackdropColor(0, 0, 0, 0.85)

    do
        local closeBtn = CreateFrame("Button", nil, p, "UIPanelCloseButton")
        closeBtn:SetPoint("TOPRIGHT", p, "TOPRIGHT", -6, -6)
        if closeBtn.SetFrameLevel then
            closeBtn:SetFrameLevel((p.GetFrameLevel and p:GetFrameLevel() or 0) + 20)
        end
        closeBtn:SetScript("OnClick", function() if p and p.Hide then p:Hide() end end)
        p._closeBtn = closeBtn
    end

    p.title = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    p.title:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -6)
    p.title:SetText("Mount Up Config")
    do
        local fontPath, fontSize, fontFlags = p.title:GetFont()
        if fontPath and fontSize then
            p.title:SetFont(fontPath, fontSize + 2, fontFlags)
        end
    end

    do
        local tabBarBG = CreateFrame("Frame", nil, p, "BackdropTemplate")
        tabBarBG:SetPoint("TOPLEFT", p, "TOPLEFT", 4, -4)
        tabBarBG:SetPoint("TOPRIGHT", p, "TOPRIGHT", -4, -4)
        tabBarBG:SetHeight(26)
        tabBarBG:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            tile = true,
            tileSize = 16,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
        tabBarBG:SetBackdropColor(0, 0, 0, 0.92)
        tabBarBG:SetFrameLevel((p.GetFrameLevel and p:GetFrameLevel() or 0) + 1)
        p._tabBarBG = tabBarBG

        -- Keep the title above the bar background.
        if p.title and p.title.SetParent then
            p.title:SetParent(tabBarBG)
            p.title:ClearAllPoints()
            p.title:SetPoint("LEFT", tabBarBG, "LEFT", 8, 0)
        end
    end

    local BTN_H = 22
    -- OSD/Lock split button: match the floating Reload UI button size.
    local SPLIT_W, SPLIT_H = 90, 18

    local function SetSegGreenGreyFS(fs, label, enabled)
        if not (fs and fs.SetText) then
            return
        end
        if enabled then
            fs:SetText("|cff00ff00" .. label .. "|r")
        else
            fs:SetText("|cff888888" .. label .. "|r")
        end
    end

    local function GetFontColorRGB(colorObj, fallbackR, fallbackG, fallbackB)
        if colorObj and type(colorObj.GetRGB) == "function" then
            local r, g, b = colorObj:GetRGB()
            if type(r) == "number" and type(g) == "number" and type(b) == "number" then
                return r, g, b
            end
        end
        if type(colorObj) == "table" and type(colorObj.r) == "number" and type(colorObj.g) == "number" and type(colorObj.b) == "number" then
            return colorObj.r, colorObj.g, colorObj.b
        end
        return fallbackR, fallbackG, fallbackB
    end

    local function CreateTextToggleButton(parent, width, height)
        local b = CreateFrame("Button", nil, parent)
        b:SetSize(width, height)
        b:EnableMouse(true)
        if parent and parent.GetFrameLevel and b.SetFrameLevel then
            -- Keep this clickable even with custom backdrops.
            b:SetFrameLevel((parent:GetFrameLevel() or 0) + 10)
        end
        local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("CENTER", b, "CENTER", 0, 0)
        b._fs = fs
        return b
    end

    local function SetScopeText(btn, label, hasPreferred)
        if not (btn and btn._fs and btn._fs.SetText and btn._fs.SetTextColor) then
            return
        end
        btn._fs:SetText(label)
        if hasPreferred then
            local r, g, b = GetFontColorRGB(rawget(_G, "GREEN_FONT_COLOR"), 0.20, 1.00, 0.20)
            btn._fs:SetTextColor(r, g, b, 1)
        else
            local r, g, b = GetFontColorRGB(rawget(_G, "YELLOW_FONT_COLOR"), 1.00, 1.00, 0.00)
            btn._fs:SetTextColor(r, g, b, 1)
        end
    end

    local function CreateBorderlessHoverLabelBox(parent, height)
        local host = CreateFrame("Frame", nil, parent)
        host:SetHeight(height)
        if parent and parent.GetFrameLevel and host.SetFrameLevel then
            host:SetFrameLevel((parent:GetFrameLevel() or 0) + 5)
        end

        host:EnableMouse(true)

        local bg = CreateFrame("Frame", nil, host, "BackdropTemplate")
        bg:SetAllPoints(host)
        bg:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            tile = true,
            tileSize = 16,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        bg:SetBackdropColor(1, 1, 1, 0.0)
        host._bg = bg
        if host.GetFrameLevel and bg.SetFrameLevel then
            bg:SetFrameLevel(host:GetFrameLevel() or 0)
        end

        local fs = host:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("CENTER", host, "CENTER", 0, 0)
        fs:SetJustifyH("CENTER")
        host._fs = fs

        do
            local fontPath, fontSize, fontFlags = fs:GetFont()
            if fontPath and fontSize then
                fs:SetFont(fontPath, fontSize + 2, fontFlags)
            end
        end

        host:SetScript("OnEnter", function(self)
            local reason = rawget(self, "_reason")
            if type(reason) ~= "string" or reason == "" then
                return
            end
            if not (GameTooltip and GameTooltip.SetOwner and GameTooltip.SetText) then
                return
            end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("|cff00ccff[FGO]|r Preferred mount")
            GameTooltip:AddLine(reason, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        host:SetScript("OnLeave", function()
            if GameTooltip and GameTooltip.Hide then
                GameTooltip:Hide()
            end
        end)

        return host
    end

    local function MakeBorderlessHoverBox(parent, width, height)
        local host = CreateFrame("Frame", nil, parent)
        host:SetSize(width, height)

        local bg = CreateFrame("Frame", nil, host, "BackdropTemplate")
        bg:SetAllPoints(host)
        bg:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            tile = true,
            tileSize = 16,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        bg:SetBackdropColor(1, 1, 1, 0.0)
        host._bg = bg

        local eb = CreateFrame("EditBox", nil, host)
        eb:SetAllPoints(host)
        eb:SetFontObject("GameFontHighlightSmall")
        eb:SetAutoFocus(false)
        eb:SetJustifyH("CENTER")
        eb:SetJustifyV("MIDDLE")
        eb:EnableMouse(true)
        eb:SetTextInsets(2, 2, 1, 1)
        host.eb = eb

        host:SetScript("OnEnter", function()
            if host._bg and host._bg.SetBackdropColor then
                host._bg:SetBackdropColor(1, 1, 1, 0.12)
            end
        end)
        host:SetScript("OnLeave", function()
            if host._bg and host._bg.SetBackdropColor then
                host._bg:SetBackdropColor(1, 1, 1, 0.0)
            end
        end)

        eb:SetScript("OnEnter", function()
            if host._bg and host._bg.SetBackdropColor then
                host._bg:SetBackdropColor(1, 1, 1, 0.12)
            end
        end)
        eb:SetScript("OnLeave", function()
            if host._bg and host._bg.SetBackdropColor then
                host._bg:SetBackdropColor(1, 1, 1, 0.0)
            end
        end)

        return host
    end

    -- Preferred scope button (FACTION / GUILD / CLASS / RACE / CHARACTER)
    local preferredScopeBtn = CreateFrame("Button", nil, p)
    preferredScopeBtn:SetSize(240, 28)
    preferredScopeBtn:SetPoint("TOP", p._tabBarBG, "BOTTOM", 0, -12)

    local preferredScopeBtnHL = preferredScopeBtn:CreateTexture(nil, "BACKGROUND")
    preferredScopeBtnHL:SetAllPoints(preferredScopeBtn)
    preferredScopeBtnHL:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight2")
    preferredScopeBtnHL:SetBlendMode("ADD")
    preferredScopeBtnHL:SetVertexColor(0.55, 0.25, 0.85, 0.45)
    preferredScopeBtnHL:Hide()

    local preferredScopeBtnText = preferredScopeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    preferredScopeBtnText:SetPoint("CENTER", preferredScopeBtn, "CENTER", 0, 0)
    do
        local fontPath, _, fontFlags = preferredScopeBtnText:GetFont()
        if type(fontPath) ~= "string" or fontPath == "" then
            fontPath = "Fonts\\FRIZQT__.TTF"
        end
        preferredScopeBtnText:SetFont(fontPath, 16, fontFlags)
        preferredScopeBtnText:SetTextColor(1.0, 0.82, 0.0, 1)
    end

    local preferredScopeTargetText = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    preferredScopeTargetText:SetPoint("TOP", preferredScopeBtn, "BOTTOM", 0, -2)
    preferredScopeTargetText:SetJustifyH("CENTER")
    p.preferredScopeTargetText = preferredScopeTargetText

    local function GetPreferredScopeTargetLabel(profileScope)
        profileScope = NormalizePreferredProfileScope(profileScope)
        if profileScope == "faction" then
            if type(UnitFactionGroup) == "function" then
                local ok, localizedFaction = pcall(UnitFactionGroup, "player")
                if ok and type(localizedFaction) == "string" and localizedFaction ~= "" then
                    return localizedFaction, true
                end
            end
            local k = GetCurrentFactionKey()
            if k then
                return tostring(k), true
            end
            return "(unknown)", false
        elseif profileScope == "guild" then
            if type(GetGuildInfo) == "function" then
                local ok, guildName = pcall(GetGuildInfo, "player")
                if ok and type(guildName) == "string" and guildName ~= "" then
                    return guildName, true
                end
            end
            return "(no guild)", false
        elseif profileScope == "class" then
            if type(UnitClass) == "function" then
                local ok, localizedClass = pcall(UnitClass, "player")
                if ok and type(localizedClass) == "string" and localizedClass ~= "" then
                    return localizedClass, true
                end
            end
            local k = GetCurrentClassKey()
            if k then
                return tostring(k), true
            end
            return "(unknown)", false
        elseif profileScope == "race" then
            if type(UnitRace) == "function" then
                local ok, localizedRace = pcall(UnitRace, "player")
                if ok and type(localizedRace) == "string" and localizedRace ~= "" then
                    return localizedRace, true
                end
            end
            local k = GetCurrentRaceKey()
            if k then
                return tostring(k), true
            end
            return "(unknown)", false
        end

        if type(UnitName) == "function" then
            local ok, name = pcall(UnitName, "player")
            if ok and type(name) == "string" and name ~= "" then
                return name, true
            end
        end
        return "(unknown)", false
    end

    local function GetNextPreferredProfileScope(cur)
        cur = NormalizePreferredProfileScope(cur)
        if cur == "faction" then return "guild" end
        if cur == "guild" then return "class" end
        if cur == "class" then return "race" end
        if cur == "race" then return "character" end
        return "faction"
    end

    local function RefreshPreferredScopeBtn()
        local cur = GetCurrentPreferredProfileScope()
        preferredScopeBtnText:SetText(string.upper(cur))

        if preferredScopeTargetText and preferredScopeTargetText.SetText and preferredScopeTargetText.SetTextColor then
            local label, hasTarget = GetPreferredScopeTargetLabel(cur)
            preferredScopeTargetText:SetText(label)
            if hasTarget then
                preferredScopeTargetText:SetTextColor(1, 1, 1, 1)
            else
                preferredScopeTargetText:SetTextColor(0.65, 0.65, 0.65, 1)
            end
        end
    end

    preferredScopeBtn:RegisterForClicks("LeftButtonUp")
    preferredScopeBtn:SetScript("OnClick", function()
        local cur = GetCurrentPreferredProfileScope()
        local nextScope = GetNextPreferredProfileScope(cur)
        SetCurrentPreferredProfileScope(nextScope)
        if p and p.RefreshFromSV then
            p:RefreshFromSV()
        end
    end)
    preferredScopeBtn:SetScript("OnEnter", function(self)
        if preferredScopeBtnHL then preferredScopeBtnHL:Show() end
        if not (GameTooltip and GameTooltip.SetOwner and GameTooltip.SetText) then
            return
        end
        local cur = GetCurrentPreferredProfileScope()
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if cur == "faction" then
            GameTooltip:SetText("Scope: FACTION\nEdits preferred mounts shared by your faction (account-wide).")
        elseif cur == "guild" then
            GameTooltip:SetText("Scope: GUILD\nEdits preferred mounts shared by your guild (account-wide).\nIf you are not in a guild, this scope has no target.")
        elseif cur == "class" then
            GameTooltip:SetText("Scope: CLASS\nEdits preferred mounts shared by your class (account-wide).")
        elseif cur == "race" then
            GameTooltip:SetText("Scope: RACE\nEdits preferred mounts shared by your race (account-wide).")
        else
            GameTooltip:SetText("Scope: CHARACTER\nEdits preferred mounts for this character only.")
        end
        GameTooltip:Show()
    end)
    preferredScopeBtn:SetScript("OnLeave", function()
        if preferredScopeBtnHL then preferredScopeBtnHL:Hide() end
        if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end
    end)

    -- Three fixed situation rows: Flying / Ground / Aquatic (values follow the selected preferred scope)
    local ROW_GAP_Y = 8
    local SCOPE_W = 60
    local LABEL_GAP_X = 0

    local rowsHost = CreateFrame("Frame", nil, p)
    do
        local rowsH = (BTN_H * 3) + (ROW_GAP_Y * 2)
        rowsHost:SetSize((p.GetWidth and p:GetWidth()) or 360, rowsH)
        -- Keep rows clickable even if header elements overlap (Flying row is closest).
        if p.GetFrameLevel and rowsHost.SetFrameLevel then
            rowsHost:SetFrameLevel((p:GetFrameLevel() or 0) + 30)
        end
        -- Move down slightly to make room for the scope target label under the scope button.
        rowsHost:SetPoint("CENTER", p, "CENTER", 0, -8)
    end

    local function CreateScopeRow(scope, label, anchorTo)
        local btn = CreateTextToggleButton(rowsHost, SCOPE_W, BTN_H)
        if anchorTo then
            btn:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, -ROW_GAP_Y)
        else
            btn:SetPoint("TOPLEFT", rowsHost, "TOPLEFT", 12, 0)
        end

        do
            local hl = btn:CreateTexture(nil, "BACKGROUND")
            hl:SetAllPoints(btn)
            hl:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight2")
            hl:SetBlendMode("ADD")
            hl:SetVertexColor(1, 1, 1, 0.18)
            hl:Hide()
            btn._hoverHL = hl
            btn:SetScript("OnEnter", function(self)
                if self._hoverHL then self._hoverHL:Show() end
            end)
            btn:SetScript("OnLeave", function(self)
                if self._hoverHL then self._hoverHL:Hide() end
            end)
        end

        btn._dbgScope = scope

        local box = CreateBorderlessHoverLabelBox(rowsHost, BTN_H)
        box:SetPoint("LEFT", btn, "RIGHT", LABEL_GAP_X, 0)
        box:SetPoint("RIGHT", rowsHost, "RIGHT", -12, 0)

        return btn, box
    end

    local btnFlying, boxFlying = CreateScopeRow("flying", "Flying", nil)
    p.btnFlying = btnFlying
    p.boxFlying = boxFlying

    local btnGround, boxGround = CreateScopeRow("ground", "Ground", btnFlying)
    p.btnGround = btnGround
    p.boxGround = boxGround

    local btnAquatic, boxAquatic = CreateScopeRow("aquatic", "Aquatic", btnGround)
    p.btnAquatic = btnAquatic
    p.boxAquatic = boxAquatic

    local delayLabel = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    delayLabel:SetJustifyH("LEFT")
    delayLabel:SetText("Delay")
    p.delayLabel = delayLabel

    local delayBox = MakeBorderlessHoverBox(p, 60, 18)
    p.delayBox = delayBox

    local osdRow = CreateFrame("Frame", nil, p)
    osdRow:SetSize(SPLIT_W, SPLIT_H)
    osdRow:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 12, 12)
    p.osdRow = osdRow

    -- Delay row (above OSD/Lock)
    local delayRowY = 12 + SPLIT_H + 6
    delayLabel:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 12, delayRowY)
    delayBox:SetPoint("BOTTOMRIGHT", p, "BOTTOMLEFT", (12 + SPLIT_W), delayRowY)

    local reapBtn = CreateTextToggleButton(p, 44, 18)
    reapBtn:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", (12 + SPLIT_W + 6), delayRowY)
    p.reapBtn = reapBtn

    local castBtn = CreateTextToggleButton(p, 44, 18)
    castBtn:SetPoint("LEFT", reapBtn, "RIGHT", 6, 0)
    p.castBtn = castBtn

    local lootBtn = CreateTextToggleButton(p, 44, 18)
    lootBtn:SetPoint("LEFT", castBtn, "RIGHT", 6, 0)
    p.lootBtn = lootBtn

    local splitOSDLock = CreateFrame("Button", nil, osdRow, "UIPanelButtonTemplate")
    splitOSDLock:SetSize(SPLIT_W, SPLIT_H)
    splitOSDLock:SetPoint("LEFT", osdRow, "LEFT", 0, 0)
    splitOSDLock:SetText("")
    p.splitOSDLock = splitOSDLock

    local fsOSD = splitOSDLock:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fsOSD:SetPoint("CENTER", splitOSDLock, "LEFT", math.floor(SPLIT_W / 4), 0)
    fsOSD:SetJustifyH("CENTER")
    p.fsOSD = fsOSD

    local fsLock = splitOSDLock:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fsLock:SetPoint("CENTER", splitOSDLock, "RIGHT", -math.floor(SPLIT_W / 4), 0)
    fsLock:SetJustifyH("CENTER")
    p.fsLock = fsLock

    local sizeBox = MakeBorderlessHoverBox(p, 25, 18)
    sizeBox:SetPoint("LEFT", osdRow, "RIGHT", 6, 0)
    p.sizeBox = sizeBox

    local xyBtn = CreateTextToggleButton(p, 26, 18)
    xyBtn:SetPoint("LEFT", sizeBox, "RIGHT", 6, 0)
    p.xyBtn = xyBtn

    local dbgBtn = CreateTextToggleButton(p, 34, 18)
    p.dbgBtn = dbgBtn

    local groundOnlyBtn = CreateTextToggleButton(p, 60, 18)
    groundOnlyBtn:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -12, 12)
    p.groundOnlyBtn = groundOnlyBtn

    local function IsReapDelayEnabled()
        return IsDelayUsedForReapRetry()
    end

    local function IsCastDelayEnabled()
        return IsDelayUsedForCastRetry()
    end

    local function IsLootDelayEnabled()
        return IsDelayUsedForLootRetry()
    end

    local function SetReapDelayEnabled(v)
        InitSV()
        if type(AutoGossip_Settings) ~= "table" then
            return
        end
        AutoGossip_Settings.mountUpDelayUseReapAcc = (v and true or false)
    end

    local function SetCastDelayEnabled(v)
        InitSV()
        if type(AutoGossip_Settings) ~= "table" then
            return
        end
        AutoGossip_Settings.mountUpDelayUseCastAcc = (v and true or false)
    end

    local function SetLootDelayEnabled(v)
        InitSV()
        if type(AutoGossip_Settings) ~= "table" then
            return
        end
        AutoGossip_Settings.mountUpDelayUseLootAcc = (v and true or false)
    end

    local function IsDebugEnabled()
        InitSV()
        return (AutoGossip_Settings and AutoGossip_Settings.mountUpDebugAcc) and true or false
    end

    local function SetDebugEnabled(v)
        InitSV()
        if type(AutoGossip_Settings) ~= "table" then
            return
        end
        AutoGossip_Settings.mountUpDebugAcc = (v and true or false)
    end

    local function DebugPrint(msg)
        if not IsDebugEnabled() then
            return
        end
        print("|cff00ccff[FGO]|r MU DBG: " .. tostring(msg))
    end

    local function InstallDelayToggle(btn, label, tooltipTitle, tooltipBody, isOnFn, setOnFn)
        if not (btn and btn.RegisterForClicks and btn.SetScript) then
            return
        end
        btn:RegisterForClicks("LeftButtonUp")
        btn:SetScript("OnClick", function()
            local on = not (isOnFn() and true or false)
            setOnFn(on)
            if p and p.RefreshFromSV then
                p:RefreshFromSV()
            end
            MU.OnSettingsChanged()
        end)
        btn:SetScript("OnEnter", function(self)
            if not (GameTooltip and GameTooltip.SetOwner and GameTooltip.SetText) then
                return
            end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(tooltipTitle)
            if type(tooltipBody) == "string" and tooltipBody ~= "" then
                GameTooltip:AddLine(tooltipBody, 1, 1, 1, true)
            end
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function()
            if GameTooltip and GameTooltip.Hide then
                GameTooltip:Hide()
            end
        end)
        if btn._fs and btn._fs.SetText then
            btn._fs:SetText(label)
        end
    end

    local function DebugDumpButtonsState()
        if not IsDebugEnabled() then
            return
        end

        local ps = GetCurrentPreferredProfileScope()
        local target = GetCurrentPreferredScopeKey(ps)
        DebugPrint("scope=" .. tostring(ps) .. " target=" .. tostring(target or "(none)"))

        local function DumpBtn(b, label)
            if not b then
                DebugPrint(label .. ": (nil)")
                return
            end
            local name = b.GetName and b:GetName() or nil
            local en = (b.IsEnabled and b:IsEnabled()) and true or false
            local mouse = (b.IsMouseEnabled and b:IsMouseEnabled()) and true or false
            local alpha = (b.GetEffectiveAlpha and b:GetEffectiveAlpha()) or (b.GetAlpha and b:GetAlpha()) or 1
            local strata = (b.GetFrameStrata and b:GetFrameStrata()) or "?"
            local lvl = (b.GetFrameLevel and b:GetFrameLevel()) or -1
            DebugPrint(label .. ": enabled=" .. tostring(en) .. " mouse=" .. tostring(mouse) .. " alpha=" .. string.format("%.2f", tonumber(alpha) or 1) .. " strata=" .. tostring(strata) .. " level=" .. tostring(lvl) .. " name=" .. tostring(name or ""))
        end

        DumpBtn(btnFlying, "FlyingBtn")
        DumpBtn(btnGround, "GroundBtn")
        DumpBtn(btnAquatic, "AquaticBtn")

        if type(GetMouseFocus) == "function" then
            local f = GetMouseFocus()
            local nm = f and f.GetName and f:GetName() or nil
            DebugPrint("mouseFocus=" .. tostring(nm or f or "nil"))
        end
    end

    local function GetPreferredMountName(profileScope, situation)
        InitSV()
        local preferredID = GetPreferredMountID(profileScope, situation)
        if preferredID <= 0 then
            return nil
        end
        if C_MountJournal and C_MountJournal.GetMountInfoByID then
            local ok, name = pcall(C_MountJournal.GetMountInfoByID, preferredID)
            if ok and type(name) == "string" and name ~= "" then
                return name
            end
        end
        return "(set)"
    end

    local function SanitizeDigits(text)
        text = tostring(text or "")
        text = text:gsub("%D+", "")
        if #text > 2 then
            text = text:sub(1, 2)
        end
        return text
    end

    local function SanitizeNumberDot(text)
        text = tostring(text or "")
        text = text:gsub("[^0-9.]", "")
        local firstDot = text:find("%.")
        if firstDot then
            local before = text:sub(1, firstDot)
            local after = text:sub(firstDot + 1):gsub("%.", "")
            text = before .. after
        end
        if #text > 4 then
            text = text:sub(1, 4)
        end
        return text
    end

    local function RefreshXYBtn()
        InitSV()
        local ui = rawget(_G, "AutoGame_UI") or rawget(_G, "AutoGossip_UI")
        if type(ui) == "table" and ui.mountUpFloatPosAccOutsideScope == nil then
            ui.mountUpFloatPosAccOutsideScope = true
        end

        local acc = IsFloatPosAccountWideOutsideScope()
        if xyBtn and xyBtn._fs and xyBtn._fs.SetText and xyBtn._fs.SetTextColor then
            xyBtn._fs:SetText("XY")
            if acc then
                local r, g, b = GetFontColorRGB(rawget(_G, "GREEN_FONT_COLOR"), 0.20, 1.00, 0.20)
                xyBtn._fs:SetTextColor(r, g, b, 1)
            else
                xyBtn._fs:SetTextColor(0.70, 0.70, 0.70, 1)
            end
        end
    end

    local function RefreshDbgBtn()
        if not (dbgBtn and dbgBtn._fs and dbgBtn._fs.SetText and dbgBtn._fs.SetTextColor) then
            return
        end
        dbgBtn._fs:SetText("DBG")
        if IsDebugEnabled() then
            local r, g, b = GetFontColorRGB(rawget(_G, "GREEN_FONT_COLOR"), 0.20, 1.00, 0.20)
            dbgBtn._fs:SetTextColor(r, g, b, 1)
        else
            dbgBtn._fs:SetTextColor(0.70, 0.70, 0.70, 1)
        end
    end

    local function RefreshFromSV()
        InitSV()

        RefreshPreferredScopeBtn()
        local ps = GetCurrentPreferredProfileScope()
        local psUsable = CanUsePreferredProfileScope(ps)

        local function RefreshRow(scope, btn, box, label)
            local preferredID = GetPreferredMountID(ps, scope)
            local hasPreferred = (type(preferredID) == "number" and preferredID > 0)
            local preferredOk, preferredReason
            if hasPreferred then
                preferredOk, preferredReason = GetMountUsabilityReason(preferredID)
                if not preferredOk then
                    preferredReason = "Preferred mount is currently not usable for this character.\nReason: " .. tostring(preferredReason or "Unknown") .. "\n\nMount Up will fall back to Random/Favorite until this clears."
                end
            end

            if btn and btn.EnableMouse then
                btn:EnableMouse(psUsable)
            end
            if btn and btn.SetEnabled then
                btn:SetEnabled(psUsable)
            end

            if psUsable then
                SetScopeText(btn, label, hasPreferred)
            else
                if btn and btn._fs and btn._fs.SetText and btn._fs.SetTextColor then
                    btn._fs:SetText(label)
                    btn._fs:SetTextColor(0.55, 0.55, 0.55, 1)
                end
            end

            local text
            if not psUsable then
                text = "N/A"
            else
                if hasPreferred then
                    text = GetPreferredMountName(ps, scope)
                    if type(text) ~= "string" or text == "" then
                        text = "(set)"
                    end
                else
                    text = "Random/Favorite"
                end
            end

            if box and box._fs and box._fs.SetText then
                box._fs:SetText(text)
            end

            if box and box._fs and box._fs.SetTextColor then
                if not psUsable then
                    box._fs:SetTextColor(0.65, 0.65, 0.65, 1)
                elseif hasPreferred and (preferredOk == false) then
                    -- Orange warning (user requested orange, not red).
                    local r, g, b = GetFontColorRGB(rawget(_G, "ORANGE_FONT_COLOR"), 1.00, 0.55, 0.00)
                    box._fs:SetTextColor(r, g, b, 1)
                else
                    box._fs:SetTextColor(1, 1, 1, 1)
                end
            end
            if box then
                box._reason = (psUsable and hasPreferred and (preferredOk == false)) and preferredReason or nil
            end
        end

        RefreshRow("flying", btnFlying, boxFlying, "Flying")
        RefreshRow("ground", btnGround, boxGround, "Ground")
        RefreshRow("aquatic", btnAquatic, boxAquatic, "Aquatic")

        local ui = rawget(_G, "AutoGame_UI") or rawget(_G, "AutoGossip_UI")
        local floatOn = (ui and ui.mountUpFloatEnabled) and true or false
        local locked = (ui and ui.mountUpFloatLocked) and true or false
        local size = (ui and tonumber(ui.mountUpFloatTextSize)) or 12

        SetSegGreenGreyFS(fsOSD, "OSD", floatOn)
        SetSegGreenGreyFS(fsLock, "Lock", locked)

        if reapBtn and reapBtn._fs then
            SetSegGreenGreyFS(reapBtn._fs, "Reap", IsReapDelayEnabled())
        end
        if castBtn and castBtn._fs then
            SetSegGreenGreyFS(castBtn._fs, "Cast", IsCastDelayEnabled())
        end
        if lootBtn and lootBtn._fs then
            SetSegGreenGreyFS(lootBtn._fs, "Loot", IsLootDelayEnabled())
        end

        if groundOnlyBtn and groundOnlyBtn._fs then
            SetSegGreenGreyFS(groundOnlyBtn._fs, "Ground", IsForceGroundEnabled())
        end

        if sizeBox and sizeBox.eb then
            sizeBox.eb:SetText(string.format("%02d", math.floor(size + 0.5)))
        end

        if delayBox and delayBox.eb and not delayBox.eb:HasFocus() then
            delayBox.eb:SetText(string.format("%.1fs", GetDelay()))
        end

        RefreshXYBtn()
        RefreshDbgBtn()
    end

    p.RefreshFromSV = RefreshFromSV

    xyBtn:RegisterForClicks("LeftButtonUp")
    xyBtn:SetScript("OnClick", function()
        InitSV()
        local ui = rawget(_G, "AutoGame_UI") or rawget(_G, "AutoGossip_UI")
        if type(ui) ~= "table" then
            return
        end
        if ui.mountUpFloatPosAccOutsideScope == nil then
            ui.mountUpFloatPosAccOutsideScope = true
        end
        ui.mountUpFloatPosAccOutsideScope = not (ui.mountUpFloatPosAccOutsideScope and true or false)
        RefreshFromSV()
        if MU and MU.UpdateMountUpFloatButton then
            MU.UpdateMountUpFloatButton()
        end
    end)
    xyBtn:SetScript("OnEnter", function(self)
        if not (GameTooltip and GameTooltip.SetOwner and GameTooltip.SetText) then
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if IsFloatPosAccountWideOutsideScope() then
            GameTooltip:SetText("XY: Account\nOSD position is saved account-wide (outside Preferred Scope).\nClick to switch to per-scope positioning.")
        else
            local ps = GetCurrentPreferredProfileScope()
            local usable = CanUsePreferredProfileScope(ps)
            if usable then
                GameTooltip:SetText("XY: Scoped\nOSD position is saved per Preferred Scope (" .. string.upper(ps) .. ").\nClick to switch to account-wide positioning.")
            else
                GameTooltip:SetText("XY: Scoped\nOSD position is saved per Preferred Scope (" .. string.upper(ps) .. ").\nCurrent scope has no target (ex: no guild), so XY falls back to Account position.\nClick to switch to account-wide positioning.")
            end
        end
        GameTooltip:Show()
    end)
    xyBtn:SetScript("OnLeave", function()
        if GameTooltip and GameTooltip.Hide then
            GameTooltip:Hide()
        end
    end)

    -- Keep DBG on the OSD/Lock row (it should not move with Delay).
    dbgBtn:SetPoint("LEFT", xyBtn, "RIGHT", 6, 0)

    dbgBtn:RegisterForClicks("LeftButtonUp")
    dbgBtn:SetScript("OnClick", function()
        local on = not IsDebugEnabled()
        SetDebugEnabled(on)
        RefreshDbgBtn()
        if on then
            DebugPrint("enabled")
            DebugDumpButtonsState()
        else
            print("|cff00ccff[FGO]|r MU DBG: disabled")
        end
    end)
    dbgBtn:SetScript("OnEnter", function(self)
        if not (GameTooltip and GameTooltip.SetOwner and GameTooltip.SetText) then
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("MU Debug")
        GameTooltip:AddLine("Toggles click logging for the Flying/Ground/Aquatic buttons.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    dbgBtn:SetScript("OnLeave", function()
        if GameTooltip and GameTooltip.Hide then
            GameTooltip:Hide()
        end
    end)

    groundOnlyBtn:RegisterForClicks("LeftButtonUp")
    groundOnlyBtn:SetScript("OnClick", function()
        SetForceGroundEnabled(not IsForceGroundEnabled())
        RefreshFromSV()
        if MU and MU.OnSettingsChanged then
            MU.OnSettingsChanged()
        end
    end)
    groundOnlyBtn:SetScript("OnEnter", function(self)
        if not (GameTooltip and GameTooltip.SetOwner and GameTooltip.SetText) then
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Ground")
        GameTooltip:AddLine("When enabled, Mount Up will never use flying mounts, even in flyable zones.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    groundOnlyBtn:SetScript("OnLeave", function()
        if GameTooltip and GameTooltip.Hide then
            GameTooltip:Hide()
        end
    end)

    InstallDelayToggle(
        reapBtn,
        "Reap",
        "Reap (Gather)",
        "When enabled, gathering casts (Mining/Herbalism/Skinning/Fishing) use your Delay instead of a quick 0.2s retry.",
        IsReapDelayEnabled,
        SetReapDelayEnabled
    )

    InstallDelayToggle(
        castBtn,
        "Cast",
        "Cast",
        "When enabled, the post-cast retry uses your Delay instead of a quick 0.2s retry.",
        IsCastDelayEnabled,
        SetCastDelayEnabled
    )

    InstallDelayToggle(
        lootBtn,
        "Loot",
        "Loot",
        "When enabled, the post-loot-close retry uses your Delay instead of a quick 0.2s retry.",
        IsLootDelayEnabled,
        SetLootDelayEnabled
    )

    local function SetScopeFromClick(scope, mouseButton)
        InitSV()
        local ps = GetCurrentPreferredProfileScope()
        DebugPrint("OnClick scope=" .. tostring(scope) .. " mouse=" .. tostring(mouseButton) .. " ps=" .. tostring(ps))
        if mouseButton == "RightButton" then
            SetActivePreferredMountIDForSituation(scope, 0)
            RefreshFromSV()
            MU.OnSettingsChanged()
            do
                local v = GetPreferredMountID(ps, scope)
                DebugPrint("cleared -> 0 (readback=" .. tostring(v) .. ")")
            end
            return
        end

        if not CanUsePreferredProfileScope(ps) then
            DebugPrint("blocked: scope has no target")
            return
        end

        local mountID = GetMountedMountID()
        if type(mountID) ~= "number" or mountID <= 0 then
            DebugPrint("blocked: no mounted mountID")
            return
        end

        DebugPrint("mounted mountID=" .. tostring(mountID))

        -- Prevent mis-setting a preferred slot with the wrong mount type.
        if C_MountJournal and C_MountJournal.GetMountInfoExtraByID then
            local ok2, _, _, _, _, mountTypeID = pcall(C_MountJournal.GetMountInfoExtraByID, mountID)
            if ok2 then
                local named = GetNamedMountType(mountTypeID)
                DebugPrint("mountTypeID=" .. tostring(mountTypeID) .. " named=" .. tostring(named))
                local allow = (named == scope)
                if scope == "ground" and named == "flying" then
                    -- Strict picker exception: allow a flying mount in Ground preferred.
                    allow = true
                end
                if not allow then
                    DebugPrint("blocked: type mismatch")
                    return
                end
            end
        end
        SetActivePreferredMountIDForSituation(scope, mountID)
        RefreshFromSV()
        MU.OnSettingsChanged()
        do
            local v = GetPreferredMountID(ps, scope)
            DebugPrint("set preferred -> " .. tostring(mountID) .. " (readback=" .. tostring(v) .. ")")
        end
    end

    local function InstallDebugMouseHooks(btn)
        if not (btn and btn.SetScript) then
            return
        end
        btn:SetScript("OnMouseDown", function(self, mouseButton)
            if not IsDebugEnabled() then
                return
            end
            local focus = (type(GetMouseFocus) == "function") and GetMouseFocus() or nil
            local focusName = focus and focus.GetName and focus:GetName() or nil
            DebugPrint("OnMouseDown scope=" .. tostring(self._dbgScope) .. " mouse=" .. tostring(mouseButton) .. " focus=" .. tostring(focusName or focus or "nil"))
        end)
        btn:SetScript("OnMouseUp", function(self, mouseButton)
            if not IsDebugEnabled() then
                return
            end
            local focus = (type(GetMouseFocus) == "function") and GetMouseFocus() or nil
            local focusName = focus and focus.GetName and focus:GetName() or nil
            DebugPrint("OnMouseUp scope=" .. tostring(self._dbgScope) .. " mouse=" .. tostring(mouseButton) .. " focus=" .. tostring(focusName or focus or "nil"))
        end)
    end

    btnFlying:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btnFlying:SetScript("OnClick", function(_, mouseButton)
        SetScopeFromClick("flying", mouseButton)
    end)
    InstallDebugMouseHooks(btnFlying)

    btnGround:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btnGround:SetScript("OnClick", function(_, mouseButton)
        SetScopeFromClick("ground", mouseButton)
    end)
    InstallDebugMouseHooks(btnGround)

    btnAquatic:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btnAquatic:SetScript("OnClick", function(_, mouseButton)
        SetScopeFromClick("aquatic", mouseButton)
    end)
    InstallDebugMouseHooks(btnAquatic)

    splitOSDLock:RegisterForClicks("LeftButtonUp")
    splitOSDLock:SetScript("OnClick", function(self)
        InitSV()
        local ui = rawget(_G, "AutoGame_UI") or rawget(_G, "AutoGossip_UI")
        if not ui then
            return
        end

        local clickLeft = true
        if GetCursorPosition and self and self.GetLeft and self.GetEffectiveScale and self.GetWidth then
            local x = GetCursorPosition()
            local scale = self:GetEffectiveScale() or 1
            x = x / scale
            local left = self:GetLeft() or 0
            local relX = x - left
            clickLeft = (relX <= (self:GetWidth() / 2))
        end

        if clickLeft then
            ui.mountUpFloatEnabled = not (ui.mountUpFloatEnabled and true or false)
        else
            ui.mountUpFloatLocked = not (ui.mountUpFloatLocked and true or false)
        end

        RefreshFromSV()
        if MU.UpdateMountUpFloatButton then
            MU.UpdateMountUpFloatButton()
        end
    end)

    sizeBox.eb:SetMaxLetters(2)
    sizeBox.eb:SetScript("OnTextChanged", function(self)
        if not self:HasFocus() then
            return
        end
        local t = SanitizeDigits(self:GetText())
        if t ~= self:GetText() then
            self:SetText(t)
            self:SetCursorPosition(#t)
        end
    end)
    sizeBox.eb:SetScript("OnEditFocusLost", function(self)
        InitSV()
        local ui = rawget(_G, "AutoGame_UI") or rawget(_G, "AutoGossip_UI")
        if not ui then
            return
        end
        local n = tonumber(SanitizeDigits(self:GetText()))
        if type(n) ~= "number" then
            n = tonumber(ui.mountUpFloatTextSize) or 12
        end
        if n < 8 then n = 8 end
        if n > 24 then n = 24 end
        ui.mountUpFloatTextSize = n
        RefreshFromSV()
        if MU.UpdateMountUpFloatButton then
            MU.UpdateMountUpFloatButton()
        end
    end)

    local function DelaySetDisplayInactive()
        if delayBox and delayBox.eb and not delayBox.eb:HasFocus() then
            delayBox.eb:SetText(string.format("%.1fs", GetDelay()))
        end
    end

    delayBox.eb:SetMaxLetters(4)
    delayBox.eb:SetScript("OnEditFocusGained", function(self)
        local t = tostring(self:GetText() or "")
        t = t:gsub("s$", "")
        self:SetText(t)
        self:SetCursorPosition(#t)
    end)
    delayBox.eb:SetScript("OnTextChanged", function(self)
        if not self:HasFocus() then
            return
        end
        local t = SanitizeNumberDot(self:GetText())
        if t ~= self:GetText() then
            self:SetText(t)
            self:SetCursorPosition(#t)
        end
    end)
    local function ApplyDelayFromEditBox(self)
        InitSV()
        local t = SanitizeNumberDot(self:GetText())
        local n = tonumber(t)
        if type(n) ~= "number" then
            n = GetDelay()
        end
        if n < 0 then n = 0 end
        if n > 9.9 then n = 9.9 end
        AutoGossip_Settings.mountUpDelayAcc = n
        DelaySetDisplayInactive()
        MU.OnSettingsChanged()
    end

    delayBox.eb:SetScript("OnEditFocusLost", function(self)
        ApplyDelayFromEditBox(self)
    end)

    delayBox.eb:SetScript("OnEnterPressed", function(self)
        ApplyDelayFromEditBox(self)
        if self and self.ClearFocus then
            self:ClearFocus()
        end
    end)

    p:SetScript("OnShow", function()
        local function HideOther(name)
            local f = _G and rawget(_G, name)
            if f and f.IsShown and f:IsShown() and f.Hide then
                f:Hide()
            end
        end

        -- Enforce: only one config popout open at a time.
        HideOther("FGO_PetWalkConfigPopup")
        HideOther("FGO_ChromieConfigPopup")

        if p.RefreshFromSV then
            p.RefreshFromSV()
        end
    end)

    configPopup = p
    return configPopup
end

function MU.OpenMountUpConfigPopup()
    local p = EnsureConfigPopup()
    if not p then
        return
    end

    p:SetClampedToScreen(true)
    p:ClearAllPoints()

    local anchor = _G and rawget(_G, "AutoGossipOptions")
    if anchor and anchor.GetCenter and anchor.IsShown and anchor:IsShown() then
        local cx = anchor:GetCenter()
        local w = (UIParent and UIParent.GetWidth and UIParent:GetWidth()) or 0
        if type(cx) == "number" and type(w) == "number" and w > 0 then
            if cx < (w / 2) then
                p:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 8, 0)
            else
                p:SetPoint("TOPRIGHT", anchor, "TOPLEFT", -8, 0)
            end
        else
            p:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 8, 0)
        end
    else
        p:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end

    p:Show()
    p:Raise()
end

MU.GetMountUpConfigPopupFrame = function()
    return configPopup or (_G and rawget(_G, "FGO_MountUpConfigPopup"))
end

-- ============================================================================
-- Runtime (event-driven)
-- ============================================================================

do
    local f = CreateFrame("Frame")
    local wasEatingOrDrinking = false
    local armedWhileEating = false
    local eatFinishTimer

    local function CancelEatFinishTimer()
        if eatFinishTimer and eatFinishTimer.Cancel then
            eatFinishTimer:Cancel()
        end
        eatFinishTimer = nil
    end

    local function OnEvent(_, event, ...)
        if event == "PLAYER_LOGIN" or event == "VARIABLES_LOADED" then
            InitSV()
            wasEatingOrDrinking = IsEatingOrDrinking() and true or false
            armedWhileEating = false
            CancelEatFinishTimer()
            return
        end

        if not IsEnabled() then
            CancelPending()
            wasEatingOrDrinking = false
            armedWhileEating = false
            CancelEatFinishTimer()
            return
        end

        if event == "UNIT_AURA" then
            local unit = ...
            if unit ~= "player" then
                return
            end

            local nowEating = IsEatingOrDrinking() and true or false

            -- While consuming: never allow a queued delayed mount to fire.
            if nowEating then
                -- If Mount Up was armed (or had a pending timer) when consumption started,
                -- schedule a one-shot retry for when the typical ~20s channel ends.
                if pendingTimer or IsWithinArmWindow(8.0) then
                    armedWhileEating = true
                end
                wasEatingOrDrinking = true
                CancelPending()

                CancelEatFinishTimer()
                if armedWhileEating and (C_Timer and C_Timer.NewTimer) then
                    eatFinishTimer = C_Timer.NewTimer(20.0, function()
                        eatFinishTimer = nil

                        if not armedWhileEating then
                            return
                        end
                        if IsMoving() then
                            armedWhileEating = false
                            return
                        end
                        if IsEatingOrDrinking() then
                            -- Still consuming (or still detected). Don't spam retries.
                            return
                        end

                        ScheduleMount("eat-finish", 0.20)
                        armedWhileEating = false
                    end)
                end
                return
            end

            -- Transition: eating/drinking ended. If we recently armed Mount Up
            -- (e.g. stop-moving fired when you sat down), retry shortly.
            if wasEatingOrDrinking then
                wasEatingOrDrinking = false
                CancelEatFinishTimer()
                if armedWhileEating and not IsMoving() then
                    ScheduleMount(event, 0.20)
                end
                armedWhileEating = false
            end
            return
        end

        if event == "PLAYER_STARTED_MOVING" then
            CancelPending()
            armedWhileEating = false
            CancelEatFinishTimer()
            return
        end

        if event == "PLAYER_STOPPED_MOVING" then
            ScheduleMount(event, GetDelay())
            return
        end

        if event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_CHANNEL_STOP" or event == "UNIT_SPELLCAST_SUCCEEDED" then
            local unit, _, spellID = ...
            if unit ~= "player" then
                return
            end

            if event == "UNIT_SPELLCAST_SUCCEEDED" and tonumber(spellID) == RECUPERATE_SPELL_ID then
                if type(GetTime) == "function" then
                    recuperateBlockUntil = (GetTime() or 0) + 10.0
                else
                    recuperateBlockUntil = 0
                end

                -- If a mount was already queued (e.g. stop-moving), push it out.
                if not IsMoving() then
                    ScheduleMount("recuperate", 10.0)
                else
                    CancelPending()
                end
                return
            end

            -- If we recently tried/armed MountUp (e.g. stop-moving fired while gathering),
            -- re-attempt shortly after the cast/channel completes.
            if IsWithinArmWindow(8.0) and not IsMoving() then
                ScheduleMount(event, GetRetryDelayForCast(spellID))
            end
            return
        end

        if event == "LOOT_CLOSED" then
            -- Common after gathering: cast ends -> loot -> close; allow a quick retry.
            if IsWithinArmWindow(8.0) and not IsMoving() then
                ScheduleMount(event, GetRetryDelayForLoot())
            end
            return
        end

        if event == "PLAYER_REGEN_DISABLED" then
            CancelPending()
            return
        end

        if event == "PLAYER_REGEN_ENABLED" then
            ScheduleMount(event, GetDelay())
            return
        end

        if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_CONTROL_GAINED" then
            ScheduleMount(event, 2.0)
            return
        end

        if event == "PLAYER_MOUNT_DISPLAY_CHANGED" then
            -- If we just dismounted and are stationary, re-arm.
            if not (IsMounted and IsMounted()) and not IsMoving() then
                ScheduleMount(event, GetDelay())
            end
            return
        end
    end

    f:RegisterEvent("PLAYER_LOGIN")
    f:RegisterEvent("VARIABLES_LOADED")
    f:RegisterEvent("PLAYER_STARTED_MOVING")
    f:RegisterEvent("PLAYER_STOPPED_MOVING")
    f:RegisterEvent("PLAYER_REGEN_DISABLED")
    f:RegisterEvent("PLAYER_REGEN_ENABLED")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    f:RegisterEvent("PLAYER_CONTROL_GAINED")
    f:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")

    f:RegisterEvent("UNIT_AURA")

    f:RegisterEvent("UNIT_SPELLCAST_STOP")
    f:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
    f:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    f:RegisterEvent("LOOT_CLOSED")

    f:SetScript("OnEvent", OnEvent)
end
