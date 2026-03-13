---@diagnostic disable: undefined-global

local addonName, ns = ...
if type(ns) ~= "table" then
    ns = {}
end

local didInit = false
local didRegister = false
local applyTimer = nil
local pendingReason = nil
local pendingAfterCombat = false
local pendingSlotAfterCombat = nil
local pendingForceAfterCombat = false
local didEnsureRememberedMacros = false
local lastApplySeq = 0

-- Startup stabilization: on login/reload, Blizzard and bar addons can still be syncing.
-- Applying during that window often gets overwritten, creating “drift” and extra work.
-- We therefore do ONE delayed apply after PLAYER_ENTERING_WORLD and ignore chatty events
-- until that apply is done.
local STARTUP_APPLY_DELAY_SECONDS = 12.0
local STARTUP_IGNORE_EVENTS_SECONDS = 22.0
local startupPendingEnterWorld = false
local startupIgnoreEventsUntil = 0

-- Remember the most recent desired state so we can detect external drift and self-heal.
local lastDesiredBySlot = nil
local lastDesiredBuildAt = 0
local lastSlotDriftQueuedAt = 0
local lastSlotDriftQueuedAtBySlot = {}

-- When leveling or changing specs/talents, multiple events can fire in a burst.
-- Applying action bar layouts immediately can coincide with Blizzard/addon sync and cause hitching.
local LEVEL_UP_APPLY_DELAY_SECONDS = 2.00
local SPEC_CHANGE_APPLY_DELAY_SECONDS = 1.25

-- Forward-declare helpers that are defined later but referenced by earlier functions.
local GetSpellNameSafe
local PlayerKnowsSpell

local function SafeGetNumMacros()
    if not GetNumMacros then
        return nil, nil
    end
    local ok, acc, char = pcall(GetNumMacros)
    if not ok then
        return nil, nil
    end
    acc = tonumber(acc)
    char = tonumber(char)
    return acc, char
end

local function InitSV()
    if ns and type(ns._InitSV) == "function" then
        ns._InitSV()
    end
end

local function GetSettings()
    InitSV()
    local s = rawget(_G, "AutoGame_Settings") or rawget(_G, "AutoGossip_Settings")
    if type(s) ~= "table" then
        return nil
    end
    return s
end

local function GetCharSettings()
    InitSV()
    local s = rawget(_G, "AutoGame_CharSettings") or rawget(_G, "AutoGossip_CharSettings")
    if type(s) ~= "table" then
        return nil
    end
    return s
end

local function GetActiveSpecID()
    if not (GetSpecialization and GetSpecializationInfo) then
        return nil
    end
    local specIndex = GetSpecialization()
    if not specIndex then
        return nil
    end
    local ok, specID = pcall(GetSpecializationInfo, specIndex)
    if not ok or type(specID) ~= "number" then
        return nil
    end
    return specID
end

local function GetPlayerClassTag()
    if not UnitClass then
        return nil
    end
    local ok, _, classTag = pcall(UnitClass, "player")
    if not ok then
        return nil
    end
    if type(classTag) ~= "string" or classTag == "" then
        return nil
    end
    return classTag
end

PlayerKnowsSpell = function(spellID)
    local sid = tonumber(spellID)
    if not sid or sid <= 0 then
        return false
    end

    local hasApi = false

    if C_Spell and type(C_Spell.IsSpellKnown) == "function" then
        hasApi = true
        local ok, known = pcall(C_Spell.IsSpellKnown, sid)
        if ok and known then
            return true
        end
    end

    if IsSpellKnown then
        hasApi = true
        local ok, known = pcall(IsSpellKnown, sid)
        if ok and known then
            return true
        end
    end

    if IsPlayerSpell then
        hasApi = true
        local ok, known = pcall(IsPlayerSpell, sid)
        if ok and known then
            return true
        end
    end

    -- If we have no API to check, don't block placement.
    if not hasApi then
        return true
    end

    return false
end

local function Trim(s)
    if type(s) ~= "string" then
        return ""
    end
    return s:gsub("^%s+", ""):gsub("%s+$", "")
end

local function GetCurrentExpansionKeyForPlayer()
    if not (C_Map and type(C_Map.GetBestMapForUnit) == "function") then
        return nil
    end

    local ok, mapID = pcall(C_Map.GetBestMapForUnit, "player")
    if not ok or type(mapID) ~= "number" or mapID <= 0 then
        return nil
    end

    -- Walk up to the Continent (landmass) and use its name as the expansion key.
    if C_Map.GetMapInfo and Enum and Enum.UIMapType then
        local cur = mapID
        for _ = 1, 12 do
            local okInfo, info = pcall(C_Map.GetMapInfo, cur)
            if not okInfo or type(info) ~= "table" then
                break
            end

            local mapType = info.mapType
            local parent = tonumber(info.parentMapID) or 0

            if mapType == Enum.UIMapType.Continent then
                local name = tostring(info.name or "")
                local low = name:lower()
                if low:find("eastern kingdoms", 1, true) then
                    return "easternkingdoms"
                end
                if low:find("kalimdor", 1, true) then
                    return "kalimdor"
                end
                if low:find("outland", 1, true) then
                    return "outland"
                end
                if low:find("northrend", 1, true) then
                    return "northrend"
                end
                if low:find("pandaria", 1, true) then
                    return "pandaria"
                end
                if low:find("draenor", 1, true) then
                    return "draenor"
                end
                if low:find("broken isles", 1, true) then
                    return "brokenisles"
                end
                if low:find("kul tiras", 1, true) then
                    return "kultiras"
                end
                if low:find("zandalar", 1, true) then
                    return "zandalar"
                end
                if low:find("shadowlands", 1, true) then
                    return "shadowlands"
                end
                if low:find("dragon isles", 1, true) then
                    return "dragonisles"
                end
                if low:find("khaz algar", 1, true) then
                    return "khazalgar"
                end
                if low:find("midnight", 1, true) then
                    return "midnight"
                end
                return nil
            end

            if not parent or parent <= 0 then
                break
            end

            cur = parent
        end

        return nil
    end

    return nil
end

local function GetActiveLayout()
    local s = GetSettings()
    if type(s) ~= "table" then
        return nil
    end

    local function ScopeRank(scope)
        if scope == "account" then
            return 1
        end
        if scope == "class" then
            return 2
        end
        if scope == "spec" then
            return 3
        end
        return 0
    end

    local function NormalizeSlot180(slot)
        slot = tonumber(slot)
        if not slot then
            return nil
        end
        slot = math.floor(slot)
        if slot < 1 or slot > 180 then
            return nil
        end
        return slot
    end

    local function GetSharedLayoutForAccount()
        local t = rawget(s, "actionBarLayoutSharedAcc")
        if type(t) ~= "table" then
            return nil
        end
        return t
    end

    local function GetSharedLayoutForExpansion(expansionKey)
        if not expansionKey then
            return nil
        end
        local byExp = rawget(s, "actionBarLayoutByExpansionAcc")
        if type(byExp) ~= "table" then
            return nil
        end
        local t = byExp[expansionKey]
        if type(t) ~= "table" then
            return nil
        end
        return t
    end

    local function SpellKnownAny(list)
        if type(list) ~= "table" then
            return false
        end
        for i = 1, #list do
            local sid = tonumber(list[i])
            if sid and sid > 0 then
                if IsSpellKnown then
                    local ok, known = pcall(IsSpellKnown, sid)
                    if ok and known then
                        return true
                    end
                end
                if IsPlayerSpell then
                    local ok, known = pcall(IsPlayerSpell, sid)
                    if ok and known then
                        return true
                    end
                end
            end
        end
        return false
    end

    local PROF_SPELLS = {
        Mining = { 2575, 265757, 265840, 265841, 265843, 265844, 265845, 265846, 265847, 265848, 265849, 309325, 374627, 433321, 471013 },
        Herbalism = { 2366, 265825, 265756, 265819, 265820, 265821, 265822, 265823, 265824, 265826, 309312, 374626, 433320, 471012 },
        Skinning = { 8613, 265861, 265761, 265869, 265870, 265871, 265872, 265873, 265874, 265875, 265876, 309318, 374633, 433327, 471019 },
    }

    local SKILLLINE_TO_PROFKEY = {
        [171] = "Alchemy",
        [164] = "Blacksmithing",
        [333] = "Enchanting",
        [202] = "Engineering",
        [182] = "Herbalism",
        [773] = "Inscription",
        [755] = "Jewelcrafting",
        [165] = "Leatherworking",
        [186] = "Mining",
        [393] = "Skinning",
        [197] = "Tailoring",
    }

    local function AddUniqueKey(out, key)
        key = Trim(tostring(key or ""))
        if key == "" then
            return
        end
        for i = 1, #out do
            if out[i] == key then
                return
            end
        end
        out[#out + 1] = key
    end

    local function GetKnownProfessionKeys()
        -- Prefer the shared cached set (keeps Situate consistent with gossip hints and
        -- handles up to 5 professions / archaeology / locale-safe keys).
        if ns and ns.Profs then
            if type(ns.Profs.RefreshKnownProfessionKeys) == "function" then
                pcall(ns.Profs.RefreshKnownProfessionKeys, false)
            end
            if type(ns.Profs.ListCachedProfessionKeys) == "function" then
                local ok, list = pcall(ns.Profs.ListCachedProfessionKeys)
                if ok and type(list) == "table" then
                    return list
                end
            end
        end

        -- Fallback: probe live profession APIs (older codepath).
        local out = {}

        if type(GetProfessions) == "function" and type(GetProfessionInfo) == "function" then
            local p1, p2, p3, p4, p5 = GetProfessions()
            local indices = { p1, p2, p3, p4, p5 }
            for i = 1, #indices do
                local idx = indices[i]
                if idx then
                    local ok, name, _, _, _, _, skillLine = pcall(GetProfessionInfo, idx)
                    if ok then
                        local key = SKILLLINE_TO_PROFKEY[tonumber(skillLine or 0)] or Trim(tostring(name or ""))
                        AddUniqueKey(out, key)
                    end
                end
            end

            if #out > 1 then
                table.sort(out, function(a, b) return tostring(a):lower() < tostring(b):lower() end)
            end
            if #out > 0 then
                return out
            end
        end

        if SpellKnownAny(PROF_SPELLS.Mining) then AddUniqueKey(out, "Mining") end
        if SpellKnownAny(PROF_SPELLS.Herbalism) then AddUniqueKey(out, "Herbalism") end
        if SpellKnownAny(PROF_SPELLS.Skinning) then AddUniqueKey(out, "Skinning") end
        return out
    end

    local function GetSharedLayoutForExpansionProfession(expansionKey, professionKey)
        if not (expansionKey and professionKey) then
            return nil
        end
        local byExp = rawget(s, "actionBarLayoutByExpansionProfessionAcc")
        if type(byExp) ~= "table" then
            return nil
        end
        local byProf = byExp[expansionKey]
        if type(byProf) ~= "table" then
            return nil
        end
        local t = byProf[professionKey]
        if type(t) ~= "table" then
            return nil
        end
        return t
    end

    local function GetSharedLayoutForClass(classTag)
        if not classTag then
            return nil
        end
        local byClass = rawget(s, "actionBarLayoutByClassAcc")
        if type(byClass) ~= "table" then
            return nil
        end
        local t = byClass[classTag]
        if type(t) ~= "table" then
            return nil
        end
        return t
    end

    local function Combine3(sharedAccount, sharedAccountOriginBySlot, sharedClass, classTag, spec, specID)
        if type(sharedAccount) ~= "table" and type(sharedClass) ~= "table" and type(spec) ~= "table" then
            return nil
        end
        local out = {}
        local specSlots, classSlots = {}, {}

        local function DetailFor(scope, slot)
            if scope == "account" then
                if slot and type(sharedAccountOriginBySlot) == "table" then
                    return sharedAccountOriginBySlot[slot] or "account:shared"
                end
                return "account:unslotted"
            end
            if scope == "class" then
                return "class:" .. tostring(classTag or "?")
            end
            if scope == "spec" then
                return "spec:" .. tostring(specID or "?")
            end
            return tostring(scope or "?")
        end

        if type(spec) == "table" then
            for _, e in ipairs(spec) do
                local slot = NormalizeSlot180(e and e.slot)
                if slot then
                    specSlots[slot] = true
                end
            end
        end

        if type(sharedClass) == "table" then
            for _, e in ipairs(sharedClass) do
                local slot = NormalizeSlot180(e and e.slot)
                if slot then
                    classSlots[slot] = true
                end
            end
        end

        if type(sharedAccount) == "table" then
            for _, e in ipairs(sharedAccount) do
                local slot = NormalizeSlot180(e and e.slot)
                if not slot or (not classSlots[slot] and not specSlots[slot]) then
                    out[#out + 1] = { entry = e, scope = "account", scopeDetail = DetailFor("account", slot) }
                end
            end
        end

        if type(sharedClass) == "table" then
            for _, e in ipairs(sharedClass) do
                local slot = NormalizeSlot180(e and e.slot)
                if not slot or (not specSlots[slot]) then
                    out[#out + 1] = { entry = e, scope = "class", scopeDetail = DetailFor("class", slot) }
                end
            end
        end

        if type(spec) == "table" then
            for _, e in ipairs(spec) do
                local slot = NormalizeSlot180(e and e.slot)
                out[#out + 1] = { entry = e, scope = "spec", scopeDetail = DetailFor("spec", slot) }
            end
        end

        return out
    end

    local function BuildAccountMerged(sharedAccountAll, sharedAccountExpansion, sharedAccountProfession)
        if type(sharedAccountAll) ~= "table" and type(sharedAccountExpansion) ~= "table" and type(sharedAccountProfession) ~= "table" then
            return nil
        end

        local bySlot = {}
        local bySlotOrigin = {}
        local unslotted = {}

        local function consider(t, origin)
            if type(t) ~= "table" then
                return
            end
            for _, e in ipairs(t) do
                local slot = NormalizeSlot180(e and e.slot)
                if slot then
                    bySlot[slot] = e
                    bySlotOrigin[slot] = origin
                else
                    unslotted[#unslotted + 1] = e
                end
            end
        end

        -- lowest -> highest precedence within Account
        consider(sharedAccountAll, "account:shared")
        consider(sharedAccountExpansion, "account:expansion")
        consider(sharedAccountProfession, "account:profession")

        local out = {}
        for slot = 1, 180 do
            local e = bySlot[slot]
            if e then
                out[#out + 1] = e
            end
        end
        for i = 1, #unslotted do
            out[#out + 1] = unslotted[i]
        end
        return ((#out > 0) and out or nil), bySlotOrigin
    end

    local specID = GetActiveSpecID()
    local bySpec = rawget(s, "actionBarLayoutBySpecAcc")
    local classTag = GetPlayerClassTag()
    local sharedAccountAll = GetSharedLayoutForAccount()
    local expKey = GetCurrentExpansionKeyForPlayer()
    local sharedAccountExpansion = GetSharedLayoutForExpansion(expKey)

    local sharedAccountProfession = nil
    if expKey then
        local profs = GetKnownProfessionKeys()
        if #profs > 0 then
            local bySlot = {}
            local unslotted = {}
            for _, pk in ipairs(profs) do
                local t = GetSharedLayoutForExpansionProfession(expKey, pk)
                if type(t) == "table" then
                    for _, e in ipairs(t) do
                        local slot = NormalizeSlot180(e and e.slot)
                        if slot then
                            bySlot[slot] = e
                        else
                            unslotted[#unslotted + 1] = e
                        end
                    end
                end
            end
            local merged = {}
            for slot = 1, 180 do
                local e = bySlot[slot]
                if e then
                    merged[#merged + 1] = e
                end
            end
            for i = 1, #unslotted do
                merged[#merged + 1] = unslotted[i]
            end
            if #merged > 0 then
                sharedAccountProfession = merged
            end
        end
    end

    local sharedAccount, sharedAccountOriginBySlot = BuildAccountMerged(sharedAccountAll, sharedAccountExpansion, sharedAccountProfession)
    local sharedClass = GetSharedLayoutForClass(classTag)

    local highestScopeRankBySlot = {}

    local function ConsiderHighest(list, scope)
        if type(list) ~= "table" then
            return
        end
        local r = ScopeRank(scope)
        for _, e in ipairs(list) do
            local slot = NormalizeSlot180(e and e.slot)
            if slot then
                local prev = highestScopeRankBySlot[slot] or 0
                if r > prev then
                    highestScopeRankBySlot[slot] = r
                end
            end
        end
    end

    ConsiderHighest(sharedAccount, "account")
    ConsiderHighest(sharedClass, "class")
    if type(bySpec) == "table" and specID and type(bySpec[specID]) == "table" then
        ConsiderHighest(bySpec[specID], "spec")
    end

    if type(bySpec) == "table" and specID and type(bySpec[specID]) == "table" then
        return Combine3(sharedAccount, sharedAccountOriginBySlot, sharedClass, classTag, bySpec[specID], specID), specID, highestScopeRankBySlot
    end

    local legacy = rawget(s, "actionBarLayoutAcc")
    if type(legacy) == "table" then
        ConsiderHighest(legacy, "spec")
        return Combine3(sharedAccount, sharedAccountOriginBySlot, sharedClass, classTag, legacy, nil), nil, highestScopeRankBySlot
    end

    return nil
end

local function GetBoolSetting(key, defaultValue)
    local s = GetSettings()
    if not s then
        return defaultValue and true or false
    end
    local v = s[key]
    if type(v) ~= "boolean" then
        return defaultValue and true or false
    end
    return v
end

local function GetTableSetting(key)
    local s = GetSettings()
    if not s then
        return nil
    end
    local v = s[key]
    if type(v) ~= "table" then
        return nil
    end
    return v
end

local function GetDriftEnabled()
    local cs = GetCharSettings()
    if cs and type(cs.actionBarDriftChar) == "boolean" then
        return cs.actionBarDriftChar
    end

    -- One-time migration from legacy account setting (if present).
    local s = GetSettings()
    if type(s) == "table" and type(s.actionBarDriftAcc) == "boolean" then
        local v = s.actionBarDriftAcc and true or false
        if cs then
            cs.actionBarDriftChar = v
        end
        s.actionBarDriftAcc = nil
        return v
    end

    -- Default: enabled.
    return true
end

local debugStatusSink = nil
local lastDebugStatus = ""
local DebugPrint

local didInstallWriteTrace = false
local internalWriteDepth = 0
local lastWriteBySlot = {}
local startupSyncUntil = 0

-- During login / reload, Blizzard and bar addons can still be syncing action bars.
-- If we apply too early, slots can "drift" back shortly after. We do a bounded
-- delayed repair pass during the startup sync window.
local POSTCHECK_REPAIR_MAX = 0
local postCheckRepairAttempts = 0

-- Outside the startup sync window, we still sometimes see "drift" right after applies
-- during macro/talent/spec churn. If it looks like internal timing (no Lua writer observed),
-- do one delayed repair pass with a global throttle to avoid loops.
local POSTCHECK_LATE_REPAIR_THROTTLE_SECONDS = 15.0
local lastPostCheckLateRepairAt = 0
local POSTCHECK_LATE_REPAIR_DELAY1_SECONDS = 2.75
local POSTCHECK_LATE_REPAIR_DELAY2_SECONDS = 6.50

local function InStartupSyncWindow()
    if type(GetTime) ~= "function" then
        return false
    end
    local ok, now = pcall(GetTime)
    if not ok or type(now) ~= "number" then
        return false
    end
    return now <= ((startupSyncUntil or 0) + 8.0)
end

local function InStartupIgnoreWindow()
    if type(GetTime) ~= "function" then
        return false
    end
    local ok, now = pcall(GetTime)
    if not ok or type(now) ~= "number" then
        return false
    end
    return now <= (tonumber(startupIgnoreEventsUntil or 0) or 0)
end

local function BeginInternalWrite()
    internalWriteDepth = (internalWriteDepth or 0) + 1
end

local function EndInternalWrite()
    internalWriteDepth = (internalWriteDepth or 0) - 1
    if internalWriteDepth < 0 then
        internalWriteDepth = 0
    end
end

local function NormalizeOneLine(s)
    s = tostring(s or "")
    s = s:gsub("\r", " "):gsub("\n", " | ")
    s = s:gsub("%s+", " ")
    return s
end

local function GetShortStack()
    if type(debugstack) ~= "function" then
        return nil
    end
    -- Try to skip a couple frames; fall back if signature differs.
    local ok, st = pcall(debugstack, 3)
    if not ok then
        ok, st = pcall(debugstack)
    end
    if not ok then
        return nil
    end
    st = NormalizeOneLine(st)
    if #st > 240 then
        st = st:sub(1, 240) .. "…"
    end
    return st
end

local function RecordSlotWrite(slot, op)
    slot = tonumber(slot)
    if not slot then
        return
    end
    if (internalWriteDepth or 0) > 0 then
        return
    end
    if not GetBoolSetting("actionBarDebugAcc", false) then
        return
    end
    local now = nil
    if type(GetTime) == "function" then
        local ok, t = pcall(GetTime)
        if ok and type(t) == "number" then
            now = t
        end
    end
    local st = GetShortStack()
    local culprit = st and (st:match("Interface/AddOns/([^/]+)/") or st:match("Interface/AddOns/([^/]+)/")) or nil
    lastWriteBySlot[slot] = {
        at = now,
        op = tostring(op or "?") ,
        culprit = culprit,
        stack = st,
    }
end

local function EnsureWriteTraceHooks()
    if didInstallWriteTrace then
        return
    end
    didInstallWriteTrace = true

    if type(hooksecurefunc) ~= "function" then
        return
    end
    if type(PlaceAction) == "function" then
        pcall(hooksecurefunc, "PlaceAction", function(slot)
            RecordSlotWrite(slot, "PlaceAction")
        end)
    end
    if type(PickupAction) == "function" then
        pcall(hooksecurefunc, "PickupAction", function(slot)
            RecordSlotWrite(slot, "PickupAction")
        end)
    end
end

function ns.ActionBar_SetDebugStatusSink(fn)
    if type(fn) == "function" then
        debugStatusSink = fn
    else
        debugStatusSink = nil
    end
end

function ns.ActionBar_GetLastDebugStatus()
    return lastDebugStatus
end

local function DebugStatus(msg)
    lastDebugStatus = tostring(msg or "")
    if type(debugStatusSink) == "function" then
        pcall(debugStatusSink, lastDebugStatus)
    end
    if type(DebugPrint) == "function" then
        DebugPrint(lastDebugStatus)
    end
end

DebugPrint = function(msg)
    if not GetBoolSetting("actionBarDebugAcc", false) then
        return
    end
    print("|cff00ccff[FGO]|r Situate: " .. tostring(msg))
end

local allowOverwriteThisApply = false

local function SyncGlobals()
    local s = GetSettings()
    local isMain = (type(s) == "table" and s.actionBarMainAcc) and true or false
    _G.FGO_AB_MAIN = isMain
end

ns.ActionBar_SyncGlobals = SyncGlobals

local function InCombat()
    if InCombatLockdown and InCombatLockdown() then
        return true
    end
    if UnitAffectingCombat then
        return UnitAffectingCombat("player") and true or false
    end
    return false
end

local function SafeGetMacroIndexByName(name)
    if type(name) ~= "string" or name == "" then
        return 0
    end
    if not GetMacroIndexByName then
        return 0
    end
    local ok, idx = pcall(GetMacroIndexByName, name)
    if not ok then
        return 0
    end
    if type(idx) ~= "number" then
        return 0
    end
    return idx
end

local function NormalizeMacroNameForLookup(name)
    if type(name) ~= "string" then
        return ""
    end

    -- Remove control chars (including NUL) that can make visible names fail exact matching.
    name = name:gsub("[%z\1-\31\127]", "")

    -- Replace non-breaking space (UTF-8 C2 A0) with a normal space.
    name = name:gsub("\194\160", " ")

    -- Normalize whitespace.
    name = Trim(name)
    name = name:gsub("%s+", " ")
    return name
end

local function FindMacroByNormalizedName(name)
    if type(name) ~= "string" or name == "" then
        return 0
    end
    if not (GetMacroInfo) then
        return 0
    end

    local want = NormalizeMacroNameForLookup(name)
    if want == "" then
        return 0
    end

    local maxAcc = tonumber(rawget(_G, "MAX_ACCOUNT_MACROS")) or 120
    local maxChar = tonumber(rawget(_G, "MAX_CHARACTER_MACROS")) or 18
    local bestAcc = 0
    local bestChar = 0
    for i = 1, (maxAcc + maxChar) do
        local ok, n = pcall(GetMacroInfo, i)
        if ok and type(n) == "string" and n ~= "" then
            if NormalizeMacroNameForLookup(n) == want then
                if i > maxAcc then
                    bestChar = i
                else
                    bestAcc = i
                end
            end
        end
    end
    -- Prefer character macro if present.
    if bestChar > 0 then
        return bestChar
    end
    return bestAcc
end

local function SafeGetMacroIndexByNameLoose(name)
    name = NormalizeMacroNameForLookup(name)
    if name == "" then
        return 0
    end

    local idx = SafeGetMacroIndexByName(name)
    if idx and idx > 0 then
        return idx
    end

    -- Fallback: scan all macros by normalized name. This handles invisible chars / NBSP.
    return FindMacroByNormalizedName(name)
end

local function NormalizeMacroBody(body)
    if type(body) ~= "string" then
        return ""
    end
    -- Macro bodies are sensitive; keep comparison mostly exact but normalize CRLF.
    body = body:gsub("\r\n", "\n")
    return body
end

local function GetMacroLimits()
    local maxAcc = tonumber(rawget(_G, "MAX_ACCOUNT_MACROS")) or 120
    local maxChar = tonumber(rawget(_G, "MAX_CHARACTER_MACROS")) or 18
    return maxAcc, maxChar
end

local function FindMacroVersionsByName(name)
    if type(name) ~= "string" or name == "" then
        return nil, nil
    end
    if not (GetMacroInfo and GetNumMacros) then
        return nil, nil
    end

    local maxAcc, maxChar = GetMacroLimits()
    local acc, char = nil, nil

    for i = 1, (maxAcc + maxChar) do
        local ok, n, icon, body = pcall(GetMacroInfo, i)
        if ok and n == name then
            local info = {
                index = i,
                icon = icon,
                body = NormalizeMacroBody(body),
            }
            if i > maxAcc then
                char = info
            else
                acc = info
            end
        end
    end

    return acc, char
end

local macroConflictQueue = {}
local macroConflictSeen = {}
local macroConflictPopup = nil

local function EnsureMacroConflictPopup()
    if macroConflictPopup and macroConflictPopup.Show then
        return macroConflictPopup
    end

    if not (CreateFrame and UIParent) then
        return nil
    end

    local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    f:SetSize(760, 520)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(200)
    f:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        tile = true,
        tileSize = 16,
    })
    f:SetBackdropColor(0, 0, 0, 0.92)
    f:Hide()

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -10)
    title:SetJustifyH("LEFT")
    title:SetText("Macro Conflict")
    f._title = title

    local leftLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    leftLabel:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    leftLabel:SetText("Saved (Account SV)")

    local rightLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rightLabel:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -44)
    rightLabel:SetText("Current (In-Game)")
    rightLabel:SetJustifyH("RIGHT")

    local boxW = 360
    local boxH = 380
    local topY = -66

    local function BuildScrollBox(anchorPoint, xOff)
        local sf = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        sf:SetPoint("TOPLEFT", f, "TOPLEFT", xOff, topY)
        sf:SetSize(boxW, boxH)

        local eb = CreateFrame("EditBox", nil, sf)
        eb:SetMultiLine(true)
        eb:SetAutoFocus(false)
        eb:SetFontObject(ChatFontNormal)
        eb:SetWidth(boxW - 28)
        eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        eb:EnableMouse(true)
        eb:SetText("")
        eb:HighlightText(0, 0)

        sf:SetScrollChild(eb)
        return sf, eb
    end

    local leftSF, leftEB = BuildScrollBox("TOPLEFT", 10)
    local rightSF, rightEB = BuildScrollBox("TOPLEFT", 390)
    f._leftEB = leftEB
    f._rightEB = rightEB

    local info = f:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    info:SetPoint("TOPLEFT", leftSF, "BOTTOMLEFT", 0, -8)
    info:SetPoint("TOPRIGHT", rightSF, "BOTTOMRIGHT", 0, -8)
    info:SetJustifyH("LEFT")
    info:SetText("Choose which one to keep. The kept version updates the character macro and the Account SV.")
    info:SetWordWrap(true)

    local btnKeepSaved = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    btnKeepSaved:SetSize(170, 22)
    btnKeepSaved:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 10)
    btnKeepSaved:SetText("Keep Saved")
    f._btnKeepSaved = btnKeepSaved

    local btnKeepCurrent = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    btnKeepCurrent:SetSize(170, 22)
    btnKeepCurrent:SetPoint("LEFT", btnKeepSaved, "RIGHT", 10, 0)
    btnKeepCurrent:SetText("Keep Current")
    f._btnKeepCurrent = btnKeepCurrent

    macroConflictPopup = f
    return f
end

local function ApplyMacroBodyToIndex(index, name, icon, body)
    if not (EditMacro and index and name) then
        return false
    end
    body = NormalizeMacroBody(body)
    local ok = pcall(EditMacro, index, name, icon, body)
    return ok and true or false
end

local TryCreateRememberedCharacterMacro

local function ResolveMacroConflict(conflict, keepWhich)
    if type(conflict) ~= "table" then
        return
    end
    local name = conflict.name
    if type(name) ~= "string" or name == "" then
        return
    end

    local chooseSaved = (keepWhich == "saved")
    local chosenIcon = chooseSaved and conflict.savedIcon or conflict.currentIcon
    local chosenBody = chooseSaved and conflict.savedBody or conflict.currentBody
    chosenBody = NormalizeMacroBody(chosenBody)

    local s = GetSettings()
    if type(s) ~= "table" then
        return
    end
    local t = rawget(s, "actionBarRememberMacrosAcc")
    if type(t) ~= "table" then
        t = {}
        s.actionBarRememberMacrosAcc = t
    end
    t[name] = { icon = chosenIcon, body = chosenBody }

    -- If the user chose to keep the current in-game macro, do not touch it.
    -- We only update the Account SV so the mismatch is resolved for future startups.
    if keepWhich == "current" then
        return
    end

    -- Sync in-game macro: update character macro; create it if missing.
    local _, char = FindMacroVersionsByName(name)
    local charIndex = char and char.index
    if not charIndex then
        local okCreate = TryCreateRememberedCharacterMacro(name)
        if okCreate then
            _, char = FindMacroVersionsByName(name)
            charIndex = char and char.index
        end
    end
    if charIndex then
        ApplyMacroBodyToIndex(charIndex, name, chosenIcon, chosenBody)
    end
end

local function ShowNextMacroConflict()
    if InCombat() then
        return
    end

    local conflict = macroConflictQueue[1]
    if not conflict then
        return
    end

    local f = EnsureMacroConflictPopup()
    if not f then
        return
    end

    f._title:SetText("Macro Conflict: " .. tostring(conflict.name or "?"))
    if f._leftEB and f._leftEB.SetText then
        f._leftEB:SetText(tostring(conflict.savedBody or ""))
        if f._leftEB.SetCursorPosition then
            f._leftEB:SetCursorPosition(0)
        end
    end
    if f._rightEB and f._rightEB.SetText then
        f._rightEB:SetText(tostring(conflict.currentBody or ""))
        if f._rightEB.SetCursorPosition then
            f._rightEB:SetCursorPosition(0)
        end
    end

    f._btnKeepSaved:SetScript("OnClick", function()
        ResolveMacroConflict(conflict, "saved")
        table.remove(macroConflictQueue, 1)
        f:Hide()
        if C_Timer and C_Timer.After then
            C_Timer.After(0, ShowNextMacroConflict)
        else
            ShowNextMacroConflict()
        end
    end)

    f._btnKeepCurrent:SetScript("OnClick", function()
        ResolveMacroConflict(conflict, "current")
        table.remove(macroConflictQueue, 1)
        f:Hide()
        if C_Timer and C_Timer.After then
            C_Timer.After(0, ShowNextMacroConflict)
        else
            ShowNextMacroConflict()
        end
    end)

    f:Show()
end

local function QueueMacroConflict(name, savedIcon, savedBody, currentIcon, currentBody)
    if type(name) ~= "string" or name == "" then
        return
    end
    local key = name .. ":" .. tostring(savedBody or "") .. ":" .. tostring(currentBody or "")
    if macroConflictSeen[key] then
        return
    end
    macroConflictSeen[key] = true

    macroConflictQueue[#macroConflictQueue + 1] = {
        name = name,
        savedIcon = savedIcon,
        savedBody = NormalizeMacroBody(savedBody),
        currentIcon = currentIcon,
        currentBody = NormalizeMacroBody(currentBody),
    }

    if C_Timer and C_Timer.After then
        C_Timer.After(0, ShowNextMacroConflict)
    end
end

TryCreateRememberedCharacterMacro = function(name)
    if type(name) ~= "string" or name == "" then
        return false, "bad-name"
    end
    if not CreateMacro then
        return false, "no-create-macro"
    end

    local s = GetSettings()
    if type(s) ~= "table" then
        return false, "no-settings"
    end

    local t = rawget(s, "actionBarRememberMacrosAcc")
    if type(t) ~= "table" then
        return false, "no-remember-table"
    end

    local info = t[name]
    if type(info) ~= "table" then
        return false, "not-remembered"
    end

    local body = rawget(info, "body")
    if type(body) ~= "string" then
        body = ""
    end

    local icon = rawget(info, "icon")
    if type(icon) ~= "number" and type(icon) ~= "string" then
        icon = "INV_MISC_QUESTIONMARK"
    end

    -- Create as character macro (not account).
    local ok, idx = pcall(CreateMacro, name, icon, NormalizeMacroBody(body), true)
    if not ok or not idx then
        return false, "create-failed"
    end
    return true, "created"
end

local function EnsureRememberedAccountMacrosOnce(reason)
    if didEnsureRememberedMacros then
        return
    end

    -- Only on login/reload style startup.
    if not (reason == "enable" or reason == "PLAYER_ENTERING_WORLD" or reason == "PLAYER_LOGIN" or reason == "VARIABLES_LOADED") then
        return
    end

    didEnsureRememberedMacros = true

    local s = GetSettings()
    if type(s) ~= "table" then
        return
    end

    local t = rawget(s, "actionBarRememberMacrosAcc")
    if type(t) ~= "table" then
        return
    end

    for name, info in pairs(t) do
        if type(name) == "string" and name ~= "" and type(info) == "table" then
            local savedBody = NormalizeMacroBody(rawget(info, "body"))
            local savedIcon = rawget(info, "icon")

            local _, char = FindMacroVersionsByName(name)
            if not (char and char.index) then
                TryCreateRememberedCharacterMacro(name)
                _, char = FindMacroVersionsByName(name)
            end

            -- Compare remembered (SV) vs current in-game CHARACTER macro only.
            if char and NormalizeMacroBody(char.body) ~= savedBody then
                QueueMacroConflict(name, savedIcon, savedBody, char.icon, char.body)
            end
        end
    end
end

local function GetEntryKind(entry)
    local k = entry and entry.kind
    if k == "spell" or k == "macro" or k == "item" then
        return k
    end
    return "macro" -- legacy entries
end

local function ResolveItemID(entry)
    if type(entry) ~= "table" then
        return nil
    end

    local itemID = tonumber(entry.itemID)
    if itemID then
        itemID = math.floor(itemID)
        if itemID > 0 then
            return itemID
        end
    end

    local item = entry.item
    if type(item) == "number" then
        itemID = math.floor(item)
        if itemID > 0 then
            return itemID
        end
    end

    local v = entry.value or entry.name
    if type(v) == "number" then
        itemID = math.floor(v)
        if itemID > 0 then
            return itemID
        end
    end
    if type(v) == "string" then
        local trimmed = v:gsub("^%s+", ""):gsub("%s+$", "")
        local idNum = tonumber(trimmed)
        if idNum and idNum > 0 then
            return math.floor(idNum)
        end
    end

    return nil
end

local function PlayerOwnsItemForSituate(itemID)
    itemID = tonumber(itemID)
    if not itemID or itemID <= 0 then
        return false
    end

    -- Bags only.
    if type(GetItemCount) == "function" then
        local ok, count = pcall(GetItemCount, itemID, false, false)
        if ok and tonumber(count) and tonumber(count) > 0 then
            return true
        end
    end

    -- Learned toys count as owned even if not in bags.
    if type(PlayerHasToy) == "function" then
        local ok, hasToy = pcall(PlayerHasToy, itemID)
        if ok and hasToy then
            return true
        end
    end

    return false
end

local function ResolveSpellID(entry)
    if type(entry) ~= "table" then
        return nil
    end

    local spellID = tonumber(entry.spellID)
    if spellID then
        spellID = math.floor(spellID)
        if spellID > 0 then
            return spellID
        end
    end

    local spell = entry.spell
    if type(spell) == "number" then
        spellID = math.floor(spell)
        if spellID > 0 then
            return spellID
        end
    end
    if type(spell) == "string" then
        local name = spell:gsub("^%s+", ""):gsub("%s+$", "")
        if name ~= "" and GetSpellInfo then
            local ok, _, _, _, _, _, id = pcall(GetSpellInfo, name)
            if ok and type(id) == "number" and id > 0 then
                return id
            end
        end
    end

    local name = entry.name
    if type(name) == "string" then
        local trimmed = name:gsub("^%s+", ""):gsub("%s+$", "")
        local idNum = tonumber(trimmed)
        if idNum and idNum > 0 then
            return math.floor(idNum)
        end
        if trimmed ~= "" and GetSpellInfo then
            local ok, _, _, _, _, _, id = pcall(GetSpellInfo, trimmed)
            if ok and type(id) == "number" and id > 0 then
                return id
            end
        end
    end

    return nil
end

local function NormalizeSlot(slot)
    slot = tonumber(slot)
    if not slot then
        return nil
    end
    slot = math.floor(slot)
    if slot < 1 or slot > 180 then
        return nil
    end
    return slot
end

local function GetActionBarStateDebug()
    local parts = {}

    -- Addon presence (helps interpret button mappings)
    do
        local bt4 = nil
        if C_AddOns and type(C_AddOns.IsAddOnLoaded) == "function" then
            local ok, loaded = pcall(C_AddOns.IsAddOnLoaded, "Bartender4")
            if ok then
                bt4 = loaded and true or false
            end
        elseif type(IsAddOnLoaded) == "function" then
            local ok, loaded = pcall(IsAddOnLoaded, "Bartender4")
            if ok then
                bt4 = loaded and true or false
            end
        end
        if bt4 ~= nil then
            parts[#parts + 1] = "bt4Loaded=" .. tostring(bt4)
        end
    end

    if type(GetActionBarPage) == "function" then
        local ok, page = pcall(GetActionBarPage)
        if ok and page then
            parts[#parts + 1] = "page=" .. tostring(page)
        end
    end
    if type(GetBonusBarOffset) == "function" then
        local ok, off = pcall(GetBonusBarOffset)
        if ok and off then
            parts[#parts + 1] = "bonusOff=" .. tostring(off)
        end
    end
    if type(HasOverrideActionBar) == "function" then
        local ok, has = pcall(HasOverrideActionBar)
        if ok then
            parts[#parts + 1] = "override=" .. tostring(has and true or false)
        end
    end
    if type(HasVehicleActionBar) == "function" then
        local ok, has = pcall(HasVehicleActionBar)
        if ok then
            parts[#parts + 1] = "vehicle=" .. tostring(has and true or false)
        end
    end

    if type(GetCVarBool) == "function" then
        local ok, locked = pcall(GetCVarBool, "lockActionBars")
        if ok then
            parts[#parts + 1] = "locked=" .. tostring(locked and true or false)
        end
    end

    if #parts == 0 then
        return nil
    end
    return table.concat(parts, " ")
end

local function GetLockActionBars()
    if type(GetCVarBool) ~= "function" then
        return nil
    end
    local ok, locked = pcall(GetCVarBool, "lockActionBars")
    if not ok then
        return nil
    end
    return locked and true or false
end

local function SetLockActionBars(on)
    if type(SetCVar) ~= "function" then
        return false
    end
    local v = (on and "1") or "0"
    local ok = pcall(SetCVar, "lockActionBars", v)
    return ok and true or false
end

local function GetDefaultButtonsForActionSlot(slot)
    slot = tonumber(slot)
    if not slot then
        return "none"
    end

    local out = {}

    local function GetCalculatedActionID(btn)
        if not btn then
            return nil
        end
        -- Retail/Classic variants
        local calc = rawget(_G, "ActionButton_CalculateAction")
        if type(calc) == "function" then
            local ok, id = pcall(calc, btn)
            if ok and tonumber(id) then
                return tonumber(id)
            end
        end
        local paged = rawget(_G, "ActionButton_GetPagedID")
        if type(paged) == "function" then
            local ok, id = pcall(paged, btn)
            if ok and tonumber(id) then
                return tonumber(id)
            end
        end
        return nil
    end

    local function ButtonHasAction(btn)
        if not btn then
            return false
        end

        -- First: try calculated/paged ID (main bar paging support)
        local calcId = GetCalculatedActionID(btn)
        if tonumber(calcId) == slot then
            return true
        end

        local a = nil
        local okA, valA = pcall(function() return btn.action end)
        if okA then
            a = valA
        end
        if tonumber(a) == slot then
            return true
        end
        if type(btn.GetAttribute) == "function" then
            local ok, attr = pcall(btn.GetAttribute, btn, "action")
            if ok and tonumber(attr) == slot then
                return true
            end
        end
        return false
    end

    local function Consider(prefix, count)
        for i = 1, count do
            local name = prefix .. tostring(i)
            local btn = rawget(_G, name)
            if btn and ButtonHasAction(btn) then
                out[#out + 1] = name
            end
        end
    end

    -- Default Blizzard action buttons (won't include Bartender/Dominos custom frames)
    Consider("ActionButton", 12)
    Consider("MultiBarBottomLeftButton", 12)
    Consider("MultiBarBottomRightButton", 12)
    Consider("MultiBarRightButton", 12)
    Consider("MultiBarLeftButton", 12)

    -- Bartender4 commonly uses BT4Button1..BT4Button120 (or higher). Scan a safe range.
    -- This is debug-only and runs only when we log a placement line.
    Consider("BT4Button", 240)

    if #out == 0 then
        return "none"
    end

    local show = 3
    if #out <= show then
        return table.concat(out, ",")
    end
    local head = {}
    for i = 1, show do
        head[#head + 1] = out[i]
    end
    return table.concat(head, ",") .. string.format("(+%d)", (#out - show))
end

local GetMacroNameSafe

-- Some action slot types (notably macros with a non-nil `subType`) can report a value via
-- GetActionInfo that isn't a stable macro index. MySlot works around this by temporarily
-- picking up the action and reading `GetCursorInfo()`.
local function GetActionInfoStable(slot)
    if not (GetActionInfo and type(slot) == "number") then
        return nil, nil, nil
    end

    local t, id, subType = GetActionInfo(slot)
    if not t then
        return nil, nil, nil
    end

    -- Macro actions with `subType` can produce confusing IDs; re-read macro id via cursor.
    -- IMPORTANT: Avoid PickupAction/PlaceAction in combat lockdown (can cause blocked-action spam/taint).
    if t == "macro" and subType then
        if GetCursorInfo and PickupAction and PlaceAction then
            if InCombatLockdown and InCombatLockdown() then
                return t, id, subType
            end

            -- Avoid disturbing the user's cursor if they are already dragging something.
            local curType = GetCursorInfo()
            if not curType then
                BeginInternalWrite()
                local okPick = pcall(PickupAction, slot)
                if okPick then
                    local ctype, cid = GetCursorInfo()
                    pcall(PlaceAction, slot)
                    if ctype == "macro" and tonumber(cid) then
                        id = tonumber(cid)
                    end
                end
                if ClearCursor then
                    pcall(ClearCursor)
                end
                EndInternalWrite()
            end
        end
    elseif t == "spell" and subType == "assistedcombat" then
        if C_AssistedCombat and type(C_AssistedCombat.GetActionSpell) == "function" then
            local ok, sid = pcall(C_AssistedCombat.GetActionSpell)
            if ok and tonumber(sid) then
                id = tonumber(sid)
            end
        end
    end

    return t, id, subType
end

local function DebugSlot12Snapshot(tag)
    if not GetBoolSetting("actionBarDebugAcc", false) then
        return
    end
    if not GetActionInfo then
        return
    end

    local slot = 12
    local t, id = GetActionInfoStable(slot)
    local extra = ""
    if t == "macro" then
        extra = " name='" .. tostring(GetMacroNameSafe(id) or "?") .. "'"
    elseif t == "spell" then
        extra = " spell='" .. tostring(GetSpellNameSafe(id) or "?") .. "'"
    end

    local function GetCalculatedActionID(btn)
        if not btn then
            return nil
        end
        local calc = rawget(_G, "ActionButton_CalculateAction")
        if type(calc) == "function" then
            local ok, id = pcall(calc, btn)
            if ok and tonumber(id) then
                return tonumber(id)
            end
        end
        local paged = rawget(_G, "ActionButton_GetPagedID")
        if type(paged) == "function" then
            local ok, id = pcall(paged, btn)
            if ok and tonumber(id) then
                return tonumber(id)
            end
        end
        return nil
    end

    local btn = rawget(_G, "ActionButton12")
    local btnAction = nil
    local btnAttrAction = nil
    local btnCalc = nil
    local calcInfo = ""
    if btn then
        local okA, a = pcall(function() return btn.action end)
        if okA then
            btnAction = a
        end
        if type(btn.GetAttribute) == "function" then
            local okAttr, av = pcall(btn.GetAttribute, btn, "action")
            if okAttr then
                btnAttrAction = av
            end
        end

        btnCalc = GetCalculatedActionID(btn)
        if btnCalc and GetActionInfo then
            local ct, cid = GetActionInfoStable(btnCalc)
            local cextra = ""
            if ct == "macro" then
                cextra = " name='" .. tostring(GetMacroNameSafe(cid) or "?") .. "'"
            elseif ct == "spell" then
                cextra = " spell='" .. tostring(GetSpellNameSafe(cid) or "?") .. "'"
            end
            calcInfo = string.format(" ; calcAction=%s calcInfo=%s:%s%s", tostring(btnCalc), tostring(ct or "nil"), tostring(cid or "nil"), tostring(cextra or ""))
        end
    end

    DebugPrint(string.format(
        "Slot12 snapshot (%s): GetActionInfo(12)=%s:%s%s ; ActionButton12.action=%s attr(action)=%s%s",
        tostring(tag or "?"),
        tostring(t or "nil"),
        tostring(id or "nil"),
        tostring(extra or ""),
        tostring(btnAction or "nil"),
        tostring(btnAttrAction or "nil"),
        tostring(calcInfo or "")
    ))
end

local function CanPlaceIntoSlot(slot, desiredKind, desiredId, entryAlwaysOverwrite, entryScopeRank, highestScopeRankForSlot, desiredMacroName)
    if not (GetActionInfo and type(slot) == "number") then
        return false, "no-api"
    end

    local actionType, id = GetActionInfoStable(slot)

    if not actionType then
        return true, "empty"
    end

    if desiredKind == "macro" and actionType == "macro" then
        if tonumber(id) == tonumber(desiredId) then
            return true, "already"
        end

        -- Macro indices can shift after UPDATE_MACROS; treat “same macro by name” as already.
        if type(desiredMacroName) == "string" and desiredMacroName ~= "" then
            local haveName = GetMacroNameSafe(id)
            if type(haveName) == "string" and haveName ~= "" then
                local a = NormalizeMacroNameForLookup(haveName)
                local b = NormalizeMacroNameForLookup(desiredMacroName)
                if a ~= "" and a == b then
                    return true, "already"
                end
            end
        end
    end
    if desiredKind == "spell" and actionType == "spell" and tonumber(id) == tonumber(desiredId) then
        return true, "already"
    end
    if desiredKind == "item" and actionType == "item" and tonumber(id) == tonumber(desiredId) then
        return true, "already"
    end

    if allowOverwriteThisApply or GetBoolSetting("actionBarOverwriteAcc", false) then
        return true, "overwrite"
    end

    if entryAlwaysOverwrite then
        local highest = tonumber(highestScopeRankForSlot) or 0
        local mine = tonumber(entryScopeRank) or 0
        if highest > mine then
            return false, "protected"
        end
        return true, "always"
    end

    return false, "occupied"
end

local function GetSlotActionDebug(slot)
    if not (GetActionInfo and type(slot) == "number") then
        return "?"
    end
    local t, id = GetActionInfoStable(slot)
    if not t then
        return "empty"
    end
    return tostring(t) .. ":" .. tostring(id)
end

GetMacroNameSafe = function(index)
    index = tonumber(index)
    if not index or index <= 0 then
        return nil
    end
    if type(GetMacroInfo) ~= "function" then
        return nil
    end
    local ok, name = pcall(GetMacroInfo, index)
    if ok and type(name) == "string" and name ~= "" then
        return name
    end
    return nil
end

GetSpellNameSafe = function(spellID)
    spellID = tonumber(spellID)
    if not spellID or spellID <= 0 then
        return nil
    end

    if C_Spell and type(C_Spell.GetSpellName) == "function" then
        local ok, name = pcall(C_Spell.GetSpellName, spellID)
        if ok and type(name) == "string" and name ~= "" then
            return name
        end
    end

    if type(GetSpellInfo) == "function" then
        local ok, name = pcall(GetSpellInfo, spellID)
        if ok and type(name) == "string" and name ~= "" then
            return name
        end
    end

    return nil
end

local function GetSpecKeyForSV(specID)
    specID = tonumber(specID)
    if not specID then
        return "0"
    end
    specID = math.floor(specID)
    if specID < 0 then
        specID = 0
    end
    return tostring(specID)
end

local function ShouldUseOneTimeOverwrite(specID)
    if GetBoolSetting("actionBarOverwriteAcc", false) then
        return false
    end

    local cs = GetCharSettings()
    if not cs then
        return false
    end

    if type(cs.actionBarDidInitialApplyBySpec) ~= "table" then
        cs.actionBarDidInitialApplyBySpec = {}
    end

    local k = GetSpecKeyForSV(specID)
    return not (cs.actionBarDidInitialApplyBySpec[k] and true or false)
end

local function MarkInitialApplyDone(specID)
    local cs = GetCharSettings()
    if not cs then
        return
    end
    if type(cs.actionBarDidInitialApplyBySpec) ~= "table" then
        cs.actionBarDidInitialApplyBySpec = {}
    end
    local k = GetSpecKeyForSV(specID)
    cs.actionBarDidInitialApplyBySpec[k] = true
end

local function GetForceOverwriteFlag(specID)
    local cs = GetCharSettings()
    if not cs then
        return false
    end

    if cs.actionBarForceOverwriteNextApply then
        return true
    end

    local t = rawget(cs, "actionBarForceOverwriteNextApplyBySpec")
    if type(t) ~= "table" then
        return false
    end
    local k = GetSpecKeyForSV(specID)
    return (t[k] and true or false)
end

local function ClearForceOverwriteFlag(specID)
    local cs = GetCharSettings()
    if not cs then
        return
    end

    cs.actionBarForceOverwriteNextApply = false

    local t = rawget(cs, "actionBarForceOverwriteNextApplyBySpec")
    if type(t) ~= "table" then
        return
    end
    local k = GetSpecKeyForSV(specID)
    t[k] = nil
end

local function PickupExisting(kind, id)
    if kind == "macro" then
        if not PickupMacro then
            return false, "no-pickup-macro"
        end
        local ok = pcall(PickupMacro, id)
        if not ok then
            return false, "pickup-macro-failed"
        end
        return true, "picked"
    end

    if kind == "spell" then
        if C_Spell and C_Spell.PickupSpell then
            local ok = pcall(C_Spell.PickupSpell, id)
            if not ok then
                return false, "pickup-spell-failed"
            end
            return true, "picked"
        end
        if PickupSpell then
            local ok = pcall(PickupSpell, id)
            if not ok then
                return false, "pickup-spell-failed"
            end
            return true, "picked"
        end
        return false, "no-pickup-spell"
    end

    if kind == "item" then
        if not (GetCursorInfo and ClearCursor) then
            return false, "no-cursor"
        end

        local function CursorHasSomething()
            local cType = GetCursorInfo()
            return cType ~= nil
        end

        if PickupItem then
            local ok = pcall(PickupItem, id)
            if ok and CursorHasSomething() then
                return true, "picked"
            end
            ClearCursor()
        end

        if C_ToyBox and type(C_ToyBox.PickupToyBoxItem) == "function" then
            local ok = pcall(C_ToyBox.PickupToyBoxItem, id)
            if ok and CursorHasSomething() then
                return true, "picked"
            end
            ClearCursor()
        end

        return false, "no-pickup-item"
    end

    return false, "unknown-kind"
end

local function SpellIdsEquivalent(desiredId, actualId)
    desiredId = tonumber(desiredId)
    actualId = tonumber(actualId)
    if not desiredId or not actualId then
        return false
    end
    if desiredId == actualId then
        return true
    end
    local wantName = GetSpellNameSafe(desiredId)
    local gotName = GetSpellNameSafe(actualId)
    if not (type(wantName) == "string" and wantName ~= "" and type(gotName) == "string" and gotName ~= "") then
        return false
    end
    return Trim(wantName):lower() == Trim(gotName):lower()
end

local function SlotMatchesDesiredAction(slot, desired)
    if not (GetActionInfo and slot and desired) then
        return false
    end
    slot = tonumber(slot)
    if not slot then
        return false
    end

    local t, id = GetActionInfoStable(slot)
    if desired.kind == "spell" then
        return (t == "spell") and SpellIdsEquivalent(desired.id, id)
    end
    if desired.kind == "macro" then
        if t ~= "macro" then
            return false
        end
        local curName = GetMacroNameSafe(id)
        if not curName then
            return false
        end
        return NormalizeMacroNameForLookup(curName) == tostring(desired.name or "")
    end
    if desired.kind == "item" then
        return (t == "item") and (tonumber(id) == tonumber(desired.id))
    end
    return false
end

local function PlaceIntoSlot(kind, id, slot)
    if not (id and tonumber(id) and slot) then
        return false, "invalid"
    end
    if not (PlaceAction and ClearCursor) then
        return false, "no-api"
    end

    BeginInternalWrite()
    local okPick, pickWhy = PickupExisting(kind, id)
    if not okPick then
        if ClearCursor then
            ClearCursor()
        end
        EndInternalWrite()
        return false, pickWhy
    end

    local okPlace = pcall(PlaceAction, slot)
    ClearCursor()

    EndInternalWrite()

    if not okPlace then
        return false, "place-failed"
    end

    -- Verify the slot actually changed to what we intended.
    if GetActionInfo then
        local t, curId = GetActionInfoStable(slot)
        if kind == "macro" then
            if t == "macro" and tonumber(curId) == tonumber(id) then
                return true, "placed"
            end
            return false, "place-verify-failed(now " .. tostring(t) .. ":" .. tostring(curId) .. ")"
        end
        if kind == "spell" then
            if t == "spell" and SpellIdsEquivalent(id, curId) then
                return true, "placed"
            end
            return false, "place-verify-failed(now " .. tostring(t) .. ":" .. tostring(curId) .. ")"
        end
        if kind == "item" then
            if t == "item" and tonumber(curId) == tonumber(id) then
                return true, "placed"
            end
            return false, "place-verify-failed(now " .. tostring(t) .. ":" .. tostring(curId) .. ")"
        end
    end

    return true, "placed"
end

local function ClearSlot(slot)
    if not (PickupAction and ClearCursor) then
        return false
    end
    BeginInternalWrite()
    local ok = pcall(PickupAction, slot)
    ClearCursor()
    EndInternalWrite()
    return ok and true or false
end

local function ClearOtherSlotsForAction(desiredKind, desiredId, keepSlot)
    if not (GetActionInfo and desiredKind and desiredId and keepSlot) then
        return 0
    end
    desiredId = tonumber(desiredId)
    if not desiredId then
        return 0
    end
    keepSlot = tonumber(keepSlot)
    if not keepSlot then
        return 0
    end

    local cleared = 0
    for slot = 1, 180 do
        if slot ~= keepSlot then
            local t, id = GetActionInfo(slot)
            if t == desiredKind and tonumber(id) == desiredId then
                if ClearSlot(slot) then
                    cleared = cleared + 1
                end
            end
        end
    end
    return cleared
end

local function ApplyLayout(reason, onlySlot, forceOverwriteOverride)
    InitSV()

    onlySlot = NormalizeSlot(onlySlot)
    forceOverwriteOverride = forceOverwriteOverride and true or false

    -- Install write-trace hooks lazily (debug only). These help identify who overwrites action slots.
    if GetBoolSetting("actionBarDebugAcc", false) then
        EnsureWriteTraceHooks()
    end

    lastApplySeq = (lastApplySeq or 0) + 1
    local applySeq = lastApplySeq

    DebugStatus("Apply start: " .. tostring(reason or "manual"))
    if GetBoolSetting("actionBarDebugAcc", false) then
        local st = GetActionBarStateDebug()
        if st then
            DebugPrint("BarState: " .. st)
        end
    end

    if not GetBoolSetting("actionBarEnabledAcc", false) then
        DebugStatus("Apply skipped (disabled): " .. tostring(reason or "manual"))
        return
    end

    local inCombat = InCombat() and true or false
    if inCombat and (not onlySlot) then
        pendingAfterCombat = true
        pendingSlotAfterCombat = nil
        pendingForceAfterCombat = false
        DebugPrint("Blocked by combat; will retry")
        DebugStatus("Blocked by combat; pending apply (" .. tostring(reason or "manual") .. ")")
        return
    end

    pendingAfterCombat = false
    pendingSlotAfterCombat = nil
    pendingForceAfterCombat = false

    -- Optional: mute SFX during the apply so action placement doesn't spam sounds.
    -- Default is muted; set actionBarMuteAcc=false in SavedVariables to disable.
    local didMuteSFX = false
    local prevSFX = nil
    local function SetCVarLocal(key, value)
        if SetCVar then
            pcall(SetCVar, tostring(key or ""), tostring(value))
            return
        end
        if C_CVar and C_CVar.SetCVar then
            pcall(C_CVar.SetCVar, tostring(key or ""), tostring(value))
            return
        end
    end
    if GetBoolSetting("actionBarMuteAcc", true) then
        if GetCVar and (SetCVar or (C_CVar and C_CVar.SetCVar)) then
            local ok, v = pcall(GetCVar, "Sound_EnableSFX")
            if ok and v ~= nil then
                prevSFX = v
                SetCVarLocal("Sound_EnableSFX", "0")
                didMuteSFX = true
            end
        end
    end

    -- Temporarily unlock action bars for the duration of the apply.
    -- If bars are locked, PlaceAction can silently fail (no slot changes), which matches your logs.
    local prevLocked = (not inCombat) and GetLockActionBars() or nil
    local didTempUnlock = false
    if (not inCombat) and prevLocked == true then
        if SetLockActionBars(false) then
            didTempUnlock = true
            if GetBoolSetting("actionBarDebugAcc", false) then
                DebugPrint("Temporarily unlocked action bars for apply")
            end
        end
    end

    local function FinishApplyCleanup()
        allowOverwriteThisApply = false

        if didMuteSFX and prevSFX ~= nil then
            SetCVarLocal("Sound_EnableSFX", prevSFX)
        end

        if didTempUnlock and prevLocked == true then
            SetLockActionBars(true)
            if GetBoolSetting("actionBarDebugAcc", false) then
                DebugPrint("Restored action bar lock after apply")
            end
        end
    end

    local specID = GetActiveSpecID()
    local forceFlag = GetForceOverwriteFlag(specID)
    local oneTimeOverwrite = forceFlag or ShouldUseOneTimeOverwrite(specID)
    allowOverwriteThisApply = forceOverwriteOverride or oneTimeOverwrite or GetBoolSetting("actionBarOverwriteAcc", false)

    local stats = {
        placed = 0,
        skipped = 0,
        already = 0,
        missing = 0,
        occupied = 0,
        protected = 0,
        overwrite = 0,
        always = 0,
        empty = 0,
        no_api = 0,
        other = 0,
    }

    local missingMacros = {}
    local missingSpells = {}
    local missingItems = {}

    local function Inc(key)
        if not key then
            stats.other = (stats.other or 0) + 1
            return
        end
        stats[key] = (stats[key] or 0) + 1
    end

    local function NoteMissingMacro(name)
        name = Trim(name)
        if name ~= "" then
            missingMacros[name] = true
        end
    end

    local function NoteMissingSpell(label)
        label = Trim(tostring(label or ""))
        if label ~= "" then
            missingSpells[label] = true
        end
    end

    local function NoteMissingItem(label)
        label = Trim(tostring(label or ""))
        if label ~= "" then
            missingItems[label] = true
        end
    end

    -- Remembered character macros: ensure character macros exist on initial login/reload only.
    EnsureRememberedAccountMacrosOnce(reason)

    local layout, _, highestScopeRankBySlot = GetActiveLayout()
    local hadLayout = layout ~= nil
    if type(layout) ~= "table" then
        layout = {}
    end

    local currentExpansionKey = GetCurrentExpansionKeyForPlayer()
    local desiredBySlot = {}
    for _, row in ipairs(layout) do
        local entry = row and row.entry or nil
        local slot = NormalizeSlot(entry and entry.slot)
        if slot then
            local kind = GetEntryKind(entry)
            if kind == "spell" then
                local sid = ResolveSpellID(entry)
                if sid then
                    desiredBySlot[slot] = { kind = "spell", id = tonumber(sid) }
                end
            elseif kind == "item" then
                local itemID = ResolveItemID(entry)
                if itemID then
                    desiredBySlot[slot] = { kind = "item", id = tonumber(itemID) }
                end
            else
                local name = entry and (entry.name or entry.value)
                name = Trim(tostring(name or ""))
                if name ~= "" then
                    desiredBySlot[slot] = { kind = "macro", name = NormalizeMacroNameForLookup(name) }
                end
            end
        end
    end

    -- Track desired state for drift detection (ACTIONBAR_SLOT_CHANGED).
    lastDesiredBySlot = desiredBySlot
    if type(GetTime) == "function" then
        local ok, now = pcall(GetTime)
        if ok and type(now) == "number" then
            lastDesiredBuildAt = now
        end
    end

    if GetBoolSetting("actionBarDebugAcc", false) then
        DebugPrint(string.format(
            "Overwrite: allowThisApply=%s (forceFlag=%s forceOverride=%s oneTime=%s setting=%s)",
            tostring(allowOverwriteThisApply and true or false),
            tostring(forceFlag and true or false),
            tostring(forceOverwriteOverride and true or false),
            tostring(oneTimeOverwrite and true or false),
            tostring(GetBoolSetting("actionBarOverwriteAcc", false) and true or false)
        ))
    end

    local placed = 0
    local skipped = 0
    local touched = nil
    local removed = 0
    local retrySlotAfterCombat = false

    local function SlotMatchesEntryForRemoval(slot, entry)
        local kind = GetEntryKind(entry)
        local t, id = GetActionInfoStable(slot)
        if kind == "spell" then
            local sid = ResolveSpellID(entry)
            return sid and (t == "spell") and (tonumber(id) == tonumber(sid))
        end
        if kind == "item" then
            local itemID = ResolveItemID(entry)
            return itemID and (t == "item") and (tonumber(id) == tonumber(itemID))
        end
        if kind == "macro" then
            if t ~= "macro" then
                return false
            end
            local wantName = entry and (entry.name or entry.value)
            wantName = Trim(tostring(wantName or ""))
            if wantName == "" then
                return false
            end
            local curName = GetMacroNameSafe(id)
            if not curName then
                return false
            end
            return NormalizeMacroNameForLookup(curName) == NormalizeMacroNameForLookup(wantName)
        end
        return false
    end

    local function ApplyRemoveOutsideExpansionPass()
        local s = GetSettings()
        if type(s) ~= "table" then
            return
        end

        local function considerList(expansionKey, list)
            if not (expansionKey and expansionKey ~= "" and expansionKey ~= currentExpansionKey) then
                return
            end
            if type(list) ~= "table" then
                return
            end
            for _, entry in ipairs(list) do
                if type(entry) == "table" and entry.removeOutsideExpansion then
                    local slot = NormalizeSlot(entry.slot)
                    if slot then
                        local desired = desiredBySlot[slot]
                        if desired and SlotMatchesDesiredAction(slot, desired) then
                            -- Slot already matches the current desired action; don't clear.
                        else
                            if SlotMatchesEntryForRemoval(slot, entry) then
                                if ClearSlot(slot) then
                                    removed = removed + 1
                                    if GetBoolSetting("actionBarDebugAcc", false) then
                                        DebugPrint(string.format(
                                            "Slot %d [remove:%s]: cleared (outside expansion)",
                                            slot,
                                            tostring(expansionKey)
                                        ))
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end

        local byExp = rawget(s, "actionBarLayoutByExpansionAcc")
        if type(byExp) == "table" then
            for expansionKey, list in pairs(byExp) do
                considerList(tostring(expansionKey or ""), list)
            end
        end

        local byExpProf = rawget(s, "actionBarLayoutByExpansionProfessionAcc")
        if type(byExpProf) == "table" then
            for expansionKey, byProf in pairs(byExpProf) do
                if type(byProf) == "table" then
                    for _, list in pairs(byProf) do
                        considerList(tostring(expansionKey or ""), list)
                    end
                end
            end
        end
    end

    if not onlySlot then
        ApplyRemoveOutsideExpansionPass()
    end

    if (not hadLayout) and removed == 0 then
        DebugStatus("Apply skipped (no layout): " .. tostring(reason or "manual"))
        FinishApplyCleanup()
        return
    end

    if onlySlot and not desiredBySlot[onlySlot] then
        DebugStatus("Apply skipped (no entry for slot " .. tostring(onlySlot) .. "): " .. tostring(reason or "manual"))
        FinishApplyCleanup()
        return
    end

    if inCombat and onlySlot then
        local d = desiredBySlot[onlySlot]
        if d and d.kind == "spell" then
            -- Spells: attempt placement even in combat (will likely be blocked), but this lets
            -- the user "try now" via slash command. We'll optionally retry after combat.
            retrySlotAfterCombat = true
        else
            -- Macros (and anything else): action-bar writes are protected in combat.
            pendingAfterCombat = true
            pendingSlotAfterCombat = onlySlot
            pendingForceAfterCombat = forceOverwriteOverride
            DebugPrint("Blocked by combat; will retry (slot " .. tostring(onlySlot) .. ")")
            DebugStatus("Blocked by combat; pending slot apply (" .. tostring(onlySlot) .. ")")
            FinishApplyCleanup()
            return
        end
    end

    local function ScopeRankForRow(row)
        if not row then
            return 0
        end
        local scope = row.scope
        if scope == "account" then
            return 1
        end
        if scope == "class" then
            return 2
        end
        if scope == "spec" then
            return 3
        end
        return 0
    end

    for _, row in ipairs(layout) do
        local entry = row and row.entry or nil
        local slot = NormalizeSlot(entry and entry.slot)
        if slot then
            if onlySlot and slot ~= onlySlot then
                -- Slot-specific apply: ignore other entries.
            else
            local src = (type(row) == "table" and (row.scopeDetail or row.scope)) or "?"
            local kind = GetEntryKind(entry)
            local entryAlways = (entry and entry.alwaysOverwrite and true or false)
            local entryRank = ScopeRankForRow(row)
            local highestRankForSlot = (type(highestScopeRankBySlot) == "table") and highestScopeRankBySlot[slot] or nil

            local desiredId = nil
            local desiredLabel = nil
            if kind == "spell" then
                desiredId = ResolveSpellID(entry)
                desiredLabel = tostring(entry and (entry.spell or entry.spellID or entry.name) or "?")
                if not desiredId then
                    skipped = skipped + 1
                    Inc("missing")
                    NoteMissingSpell(desiredLabel)
                    DebugPrint(string.format("Slot %d [%s]: spell '%s' (missing)", slot, tostring(src), desiredLabel))
                else
                    if not PlayerKnowsSpell(desiredId) then
                        skipped = skipped + 1
                        Inc("missing")
                        local spellName = GetSpellNameSafe(desiredId)
                        NoteMissingSpell(spellName or desiredLabel)
                        if spellName then
                            DebugPrint(string.format("Slot %d [%s]: spell %s (%s) (not known)", slot, tostring(src), tostring(desiredId), tostring(spellName)))
                        else
                            DebugPrint(string.format("Slot %d [%s]: spell %s (not known)", slot, tostring(src), tostring(desiredId)))
                        end
                    else
                    local okSlot, why = CanPlaceIntoSlot(slot, "spell", desiredId, entryAlways, entryRank, highestRankForSlot)
                    if okSlot then
                        local placedOrAlready = false
                        if why == "already" then
                            skipped = skipped + 1
                            Inc("already")
                            placedOrAlready = true
                        else
                            local before = GetSlotActionDebug(slot)
                            local okPlace, placeWhy = PlaceIntoSlot("spell", desiredId, slot)
                            if okPlace then
                                placed = placed + 1
                                Inc("placed")
                                placedOrAlready = true
                                if not touched then
                                    touched = {}
                                end
                                touched[slot] = { kind = "spell", id = tonumber(desiredId), label = GetSpellNameSafe(desiredId) or tostring(desiredId) }
                                local spellName = GetSpellNameSafe(desiredId)
                                local btns = GetDefaultButtonsForActionSlot(slot)
                                if spellName then
                                    DebugPrint(string.format("Slot %d [%s] (btn=%s): place spell %s (%s) (was %s; allow=%s)", slot, tostring(src), tostring(btns), tostring(desiredId), tostring(spellName), tostring(before), tostring(why)))
                                else
                                    DebugPrint(string.format("Slot %d [%s] (btn=%s): place spell %s (was %s; allow=%s)", slot, tostring(src), tostring(btns), tostring(desiredId), tostring(before), tostring(why)))
                                end
                            else
                                skipped = skipped + 1
                                Inc("other")
                                local spellName = GetSpellNameSafe(desiredId)
                                if spellName then
                                    DebugPrint(string.format("Slot %d [%s]: spell %s (%s) (%s)", slot, tostring(src), tostring(desiredId), tostring(spellName), placeWhy))
                                else
                                    DebugPrint(string.format("Slot %d [%s]: spell %s (%s)", slot, tostring(src), tostring(desiredId), placeWhy))
                                end
                            end
                        end

                        if placedOrAlready and (entry and entry.clearElsewhere and true or false) and GetBoolSetting("actionBarClearElsewhereAcc", false) then
                            local t, id = GetActionInfoStable(slot)
                            if t == "spell" and tonumber(id) == tonumber(desiredId) then
                                ClearOtherSlotsForAction("spell", desiredId, slot)
                            end
                        end
                    else
                        skipped = skipped + 1
                        if why == "occupied" then
                            Inc("occupied")
                        elseif why == "protected" then
                            Inc("protected")
                        elseif why == "no-api" then
                            Inc("no_api")
                        else
                            Inc(why)
                        end
                        DebugPrint(string.format("Slot %d [%s]: skip (%s)", slot, tostring(src), why))
                    end
                    end
                end
            elseif kind == "item" then
                desiredId = ResolveItemID(entry)
                desiredLabel = tostring(entry and (entry.value or entry.itemID or entry.itemId or entry.name) or "?")
                if not desiredId then
                    skipped = skipped + 1
                    Inc("missing")
                    NoteMissingItem(desiredLabel)
                    DebugPrint(string.format("Slot %d [%s]: item '%s' (missing)", slot, tostring(src), desiredLabel))
                else
                    if not PlayerOwnsItemForSituate(desiredId) then
                        skipped = skipped + 1
                        Inc("missing")
                        NoteMissingItem(tostring(desiredId))
                        DebugPrint(string.format("Slot %d [%s]: item %s (not owned: bags/toybox)", slot, tostring(src), tostring(desiredId)))
                    else
                        local okSlot, why = CanPlaceIntoSlot(slot, "item", desiredId, entryAlways, entryRank, highestRankForSlot)
                        if okSlot then
                            local placedOrAlready = false
                            if why == "already" then
                                skipped = skipped + 1
                                Inc("already")
                                placedOrAlready = true
                            else
                                local before = GetSlotActionDebug(slot)
                                local okPlace, placeWhy = PlaceIntoSlot("item", desiredId, slot)
                                if okPlace then
                                    placed = placed + 1
                                    Inc("placed")
                                    placedOrAlready = true
                                    if not touched then
                                        touched = {}
                                    end
                                    touched[slot] = { kind = "item", id = tonumber(desiredId), label = tostring(desiredId) }
                                    local btns = GetDefaultButtonsForActionSlot(slot)
                                    DebugPrint(string.format("Slot %d [%s] (btn=%s): place item %s (was %s; allow=%s)", slot, tostring(src), tostring(btns), tostring(desiredId), tostring(before), tostring(why)))
                                else
                                    skipped = skipped + 1
                                    Inc("other")
                                    DebugPrint(string.format("Slot %d [%s]: item %s (%s)", slot, tostring(src), tostring(desiredId), placeWhy))
                                end
                            end

                            if placedOrAlready and (entry and entry.clearElsewhere and true or false) and GetBoolSetting("actionBarClearElsewhereAcc", false) then
                                local t, id = GetActionInfoStable(slot)
                                if t == "item" and tonumber(id) == tonumber(desiredId) then
                                    ClearOtherSlotsForAction("item", desiredId, slot)
                                end
                            end
                        else
                            skipped = skipped + 1
                            if why == "occupied" then
                                Inc("occupied")
                            elseif why == "protected" then
                                Inc("protected")
                            elseif why == "no-api" then
                                Inc("no_api")
                            else
                                Inc(why)
                            end
                            DebugPrint(string.format("Slot %d [%s]: skip (%s)", slot, tostring(src), why))
                        end
                    end
                end
            else
                local name = entry and entry.name
                local trimmedName = nil
                if type(name) == "string" then
                    trimmedName = name:gsub("^%s+", ""):gsub("%s+$", "")
                end
                desiredLabel = tostring(trimmedName)

                local macroIndex = (type(trimmedName) == "string" and trimmedName ~= "") and SafeGetMacroIndexByName(trimmedName) or 0
                if not (macroIndex and macroIndex > 0) and type(trimmedName) == "string" and trimmedName ~= "" then
                    macroIndex = SafeGetMacroIndexByNameLoose(trimmedName)
                end

                -- Occasionally the macro list is not ready (or the API lies briefly).
                -- If Debug is enabled, double-check by scanning to help diagnose “missing” reports.
                local foundAcc, foundChar = nil, nil
                if not (macroIndex and macroIndex > 0) and type(trimmedName) == "string" and trimmedName ~= "" then
                    foundAcc, foundChar = FindMacroVersionsByName(trimmedName)
                    local alt = (foundChar and foundChar.index) or (foundAcc and foundAcc.index) or 0
                    if alt and alt > 0 then
                        macroIndex = alt
                    end
                end

                if not (macroIndex and macroIndex > 0) then
                    skipped = skipped + 1
                    Inc("missing")
                    NoteMissingMacro(trimmedName)
                    if type(trimmedName) == "string" and trimmedName ~= "" then
                        if foundAcc == nil and foundChar == nil then
                            foundAcc, foundChar = FindMacroVersionsByName(trimmedName)
                        end
                        local accIdx = foundAcc and foundAcc.index or 0
                        local charIdx = foundChar and foundChar.index or 0
                        local accCount, charCount = SafeGetNumMacros()

                        local curT, curId = GetActionInfoStable(slot)
                        local curName = nil
                        if curT == "macro" then
                            curName = GetMacroNameSafe(curId)
                        end
                        DebugPrint(string.format(
                            "Slot %d [%s]: macro '%s' (missing right now; reason=%s; scan acc=%s char=%s; numMacros acc=%s char=%s; slotNow=%s%s)",
                            slot,
                            tostring(src),
                            trimmedName,
                            tostring(reason or "?"),
                            (accIdx > 0) and tostring(accIdx) or "none",
                            (charIdx > 0) and tostring(charIdx) or "none",
                            (type(accCount) == "number") and tostring(accCount) or "?",
                            (type(charCount) == "number") and tostring(charCount) or "?",
                            tostring(curT or "nil") .. ":" .. tostring(curId or "nil"),
                            curName and (" name='" .. tostring(curName) .. "'") or ""
                        ))
                    else
                        DebugPrint(string.format("Slot %d [%s]: macro '%s' (missing right now; reason=%s)", slot, tostring(src), desiredLabel, tostring(reason or "?")))
                    end
                else
                    local okSlot, why = CanPlaceIntoSlot(slot, "macro", macroIndex, entryAlways, entryRank, highestRankForSlot, trimmedName)
                    if okSlot then
                        local placedOrAlready = false
                        if why == "already" then
                            skipped = skipped + 1
                            Inc("already")
                            placedOrAlready = true
                        else
                            if slot == 12 then
                                DebugSlot12Snapshot("before-place")
                            end
                            local before = GetSlotActionDebug(slot)
                            local beforeName = nil
                            if GetActionInfo then
                                local bt, bid = GetActionInfoStable(slot)
                                if bt == "macro" then
                                    beforeName = GetMacroNameSafe(bid)
                                end
                            end
                            local okPlace, placeWhy = PlaceIntoSlot("macro", macroIndex, slot)
                            if okPlace then
                                placed = placed + 1
                                Inc("placed")
                                placedOrAlready = true
                                if not touched then
                                    touched = {}
                                end
                                touched[slot] = { kind = "macro", name = trimmedName or (GetMacroNameSafe(macroIndex) or tostring(desiredLabel or "")), id = tonumber(macroIndex) }
                                local desiredName = GetMacroNameSafe(macroIndex) or trimmedName or desiredLabel
                                local btns = GetDefaultButtonsForActionSlot(slot)
                                if beforeName then
                                    DebugPrint(string.format(
                                        "Slot %d [%s] (btn=%s): place macro %s ('%s') (was %s '%s'; allow=%s)",
                                        slot,
                                        tostring(src),
                                        tostring(btns),
                                        tostring(macroIndex),
                                        tostring(desiredName),
                                        tostring(before),
                                        tostring(beforeName),
                                        tostring(why)
                                    ))
                                else
                                    DebugPrint(string.format(
                                        "Slot %d [%s] (btn=%s): place macro %s ('%s') (was %s; allow=%s)",
                                        slot,
                                        tostring(src),
                                        tostring(btns),
                                        tostring(macroIndex),
                                        tostring(desiredName),
                                        tostring(before),
                                        tostring(why)
                                    ))
                                end

                                if slot == 12 then
                                    DebugSlot12Snapshot("after-place")
                                end
                            else
                                skipped = skipped + 1
                                Inc("other")
                                DebugPrint(string.format("Slot %d [%s]: %s (%s)", slot, tostring(src), desiredLabel or "?", placeWhy))
                                if slot == 12 then
                                    DebugSlot12Snapshot("place-failed")
                                end
                            end
                        end

                        if placedOrAlready and (entry and entry.clearElsewhere and true or false) and GetBoolSetting("actionBarClearElsewhereAcc", false) then
                            local t, id = GetActionInfoStable(slot)
                            if t == "macro" and tonumber(id) == tonumber(macroIndex) then
                                ClearOtherSlotsForAction("macro", macroIndex, slot)
                            end
                        end
                    else
                        skipped = skipped + 1
                        if why == "occupied" then
                            Inc("occupied")
                        elseif why == "protected" then
                            Inc("protected")
                        elseif why == "no-api" then
                            Inc("no_api")
                        else
                            Inc(why)
                        end
                        DebugPrint(string.format("Slot %d [%s]: skip (%s)", slot, tostring(src), why))
                    end
                end
            end
            end
        end
    end

    -- If we attempted a slot-specific spell apply in combat and didn't place anything,
    -- queue a retry for immediately after combat ends.
    if retrySlotAfterCombat and placed == 0 and (tonumber(stats.already) or 0) == 0 then
        pendingAfterCombat = true
        pendingSlotAfterCombat = onlySlot
        pendingForceAfterCombat = forceOverwriteOverride
    end

    if oneTimeOverwrite and placed > 0 then
        MarkInitialApplyDone(specID)
        if forceFlag then
            ClearForceOverwriteFlag(specID)
            DebugPrint("Forced apply complete; force flag cleared")
        else
            DebugPrint("Initial apply complete; one-time overwrite disabled for this spec")
        end
    end

    FinishApplyCleanup()

    if GetBoolSetting("actionBarDebugAcc", false) then
        DebugPrint(string.format(
            "Apply (%s): placed=%d skipped=%d (already=%d missing=%d occupied=%d protected=%d)",
            tostring(reason or "manual"),
            placed,
            skipped,
            tonumber(stats.already) or 0,
            tonumber(stats.missing) or 0,
            tonumber(stats.occupied) or 0,
            tonumber(stats.protected) or 0
        ))

        local function SummarizeSet(set)
            local list = {}
            local n = 0
            for k in pairs(set or {}) do
                n = n + 1
                if #list < 10 then
                    list[#list + 1] = tostring(k)
                end
            end
            table.sort(list)
            if n == 0 then
                return nil
            end
            if n <= #list then
                return table.concat(list, ", ")
            end
            return table.concat(list, ", ") .. string.format(" (+%d)", (n - #list))
        end

        local mm = SummarizeSet(missingMacros)
        if mm then
            DebugPrint("Missing macros: " .. mm)
        end
        local ms = SummarizeSet(missingSpells)
        if ms then
            DebugPrint("Missing spells: " .. ms)
        end

        local mi = SummarizeSet(missingItems)
        if mi then
            DebugPrint("Missing items: " .. mi)
        end
    end

    DebugStatus(string.format("Apply done (%s): placed=%d skipped=%d", tostring(reason or "manual"), placed, skipped))

    -- Post-check: verify that slots we touched didn't immediately get changed by something else.
    -- In addition to debugging, we also use this during the startup sync window to do a bounded
    -- repair apply when drift looks like internal timing (no Lua writer observed).
    local driftEnabled = GetDriftEnabled()
    local dbgPostCheck = driftEnabled and GetBoolSetting("actionBarDebugAcc", false) or false
    local allowAutoRepair = driftEnabled and ((tonumber(POSTCHECK_REPAIR_MAX) or 0) > 0) or false
    if driftEnabled and touched and C_Timer and C_Timer.After and (dbgPostCheck or (allowAutoRepair and InStartupSyncWindow())) then
        C_Timer.After(0.60, function()
            -- If a newer Apply happened, skip this verification.
            if (lastApplySeq or 0) ~= applySeq then
                return
            end

            local driftCount = 0
            local sawLuaWriter = false
            local drifted = nil
            for slot, want in pairs(touched) do
                local t, id = nil, nil
                if GetActionInfo then
                    t, id = GetActionInfoStable(slot)
                end

                if want.kind == "spell" then
                    if t ~= "spell" or not SpellIdsEquivalent(want.id, id) then
                        driftCount = driftCount + 1
                        if not drifted then
                            drifted = {}
                        end
                        drifted[slot] = want
                        local btns = GetDefaultButtonsForActionSlot(slot)
                        if GetBoolSetting("actionBarDebugAcc", false) then
                            DebugPrint(string.format(
                                "Post-check: Slot %d (btn=%s) drifted (expected spell %s; now %s)",
                                tonumber(slot) or 0,
                                tostring(btns),
                                tostring(want.label or want.id or "?"),
                                tostring(GetSlotActionDebug(slot))
                            ))
                        end

                        local wr = lastWriteBySlot[slot]
                        if wr and wr.stack then
                            sawLuaWriter = true
                            if GetBoolSetting("actionBarDebugAcc", false) then
                                DebugPrint(string.format(
                                    "Post-check: Slot %d last write: op=%s by=%s stack=%s",
                                    tonumber(slot) or 0,
                                    tostring(wr.op or "?"),
                                    tostring(wr.culprit or "?"),
                                    tostring(wr.stack)
                                ))
                            end
                        end
                    end
                elseif want.kind == "macro" then
                    local nowName = nil
                    if t == "macro" then
                        nowName = GetMacroNameSafe(id)
                    end
                    -- Compare by name if we can, because macro indices can shift.
                    local expectedName = Trim(want.name or "")
                    local okName = (expectedName ~= "") and (type(nowName) == "string") and (Trim(nowName) == expectedName)

                    if not okName then
                        driftCount = driftCount + 1
                        if not drifted then
                            drifted = {}
                        end
                        drifted[slot] = want
                        local btns = GetDefaultButtonsForActionSlot(slot)
                        if GetBoolSetting("actionBarDebugAcc", false) then
                            DebugPrint(string.format(
                                "Post-check: Slot %d (btn=%s) drifted (expected macro '%s'; now %s)",
                                tonumber(slot) or 0,
                                tostring(btns),
                                tostring(expectedName ~= "" and expectedName or (want.name or "?")),
                                tostring(GetSlotActionDebug(slot))
                            ))
                        end

                        if tonumber(slot) == 12 then
                            DebugSlot12Snapshot("post-check")
                        end

                        local wr = lastWriteBySlot[slot]
                        if wr and wr.stack then
                            sawLuaWriter = true
                            if GetBoolSetting("actionBarDebugAcc", false) then
                                DebugPrint(string.format(
                                    "Post-check: Slot %d last write: op=%s by=%s stack=%s",
                                    tonumber(slot) or 0,
                                    tostring(wr.op or "?"),
                                    tostring(wr.culprit or "?"),
                                    tostring(wr.stack)
                                ))
                            end
                        end
                    end
                elseif want.kind == "item" then
                    if t ~= "item" or tonumber(id) ~= tonumber(want.id) then
                        driftCount = driftCount + 1
                        if not drifted then
                            drifted = {}
                        end
                        drifted[slot] = want
                        local btns = GetDefaultButtonsForActionSlot(slot)
                        if GetBoolSetting("actionBarDebugAcc", false) then
                            DebugPrint(string.format(
                                "Post-check: Slot %d (btn=%s) drifted (expected item %s; now %s)",
                                tonumber(slot) or 0,
                                tostring(btns),
                                tostring(want.label or want.id or "?"),
                                tostring(GetSlotActionDebug(slot))
                            ))
                        end

                        local wr = lastWriteBySlot[slot]
                        if wr and wr.stack then
                            sawLuaWriter = true
                            if GetBoolSetting("actionBarDebugAcc", false) then
                                DebugPrint(string.format(
                                    "Post-check: Slot %d last write: op=%s by=%s stack=%s",
                                    tonumber(slot) or 0,
                                    tostring(wr.op or "?"),
                                    tostring(wr.culprit or "?"),
                                    tostring(wr.stack)
                                ))
                            end
                        end
                    end
                end
            end

            if driftCount > 0 then
                if GetBoolSetting("actionBarDebugAcc", false) then
                    DebugPrint(string.format(
                        "Post-check: detected drift in %d slot(s) after apply (%s). Another addon or profile system is likely overwriting action bars.",
                        driftCount,
                        tostring(reason or "manual")
                    ))

                    if not sawLuaWriter then
                        DebugPrint("Post-check: no Lua PlaceAction/PickupAction writer observed for drifted slots (likely internal WoW action bar/macro sync timing).")
                    end
                end

                -- Startup self-heal: if drift happens with no observed Lua writer, do a bounded delayed
                -- re-apply to catch the state after Blizzard/Bartender finishes syncing.
                if allowAutoRepair and InStartupSyncWindow() and (not sawLuaWriter) and postCheckRepairAttempts < POSTCHECK_REPAIR_MAX then
                    postCheckRepairAttempts = postCheckRepairAttempts + 1
                    local thisAttempt = postCheckRepairAttempts
                    if GetBoolSetting("actionBarDebugAcc", false) then
                        DebugPrint(string.format(
                            "Post-check: scheduling startup repair apply (attempt %d/%d)",
                            tonumber(thisAttempt) or 0,
                            tonumber(POSTCHECK_REPAIR_MAX) or 0
                        ))
                    end
                    C_Timer.After(1.25 + (thisAttempt - 1) * 0.75, function()
                        -- Only repair if nothing else applied since.
                        if (lastApplySeq or 0) ~= applySeq then
                            return
                        end
                        ApplyLayout("post-check-repair")
                    end)
                elseif allowAutoRepair and (not InStartupSyncWindow()) and (not sawLuaWriter) then
                    -- Non-startup repair: one delayed apply for bursty events (macros/talents/spec/level).
                    local r = tostring(reason or "")
                    local allow = (r == "UPDATE_MACROS" or r == "spec-change" or r == "level-up")
                    if allow and type(GetTime) == "function" then
                        local okNow, now = pcall(GetTime)
                        if okNow and type(now) == "number" then
                            if (now - (lastPostCheckLateRepairAt or 0)) >= POSTCHECK_LATE_REPAIR_THROTTLE_SECONDS then
                                lastPostCheckLateRepairAt = now
                                if GetBoolSetting("actionBarDebugAcc", false) then
                                    DebugPrint("Post-check: scheduling late repair apply (non-startup)")
                                end
                                local driftedSnapshot = drifted
                                local function StillDrifted()
                                    if type(driftedSnapshot) ~= "table" then
                                        return true
                                    end
                                    for slot, want in pairs(driftedSnapshot) do
                                        local t, id = GetActionInfoStable(slot)
                                        if want.kind == "spell" then
                                            if t ~= "spell" or not SpellIdsEquivalent(want.id, id) then
                                                return true
                                            end
                                        elseif want.kind == "macro" then
                                            local nowName = nil
                                            if t == "macro" then
                                                nowName = GetMacroNameSafe(id)
                                            end
                                            local expectedName = Trim(want.name or "")
                                            local okName = (expectedName ~= "") and (type(nowName) == "string") and (Trim(nowName) == expectedName)
                                            if not okName then
                                                return true
                                            end
                                        elseif want.kind == "item" then
                                            if t ~= "item" or tonumber(id) ~= tonumber(want.id) then
                                                return true
                                            end
                                        else
                                            return true
                                        end
                                    end
                                    return false
                                end

                                C_Timer.After(POSTCHECK_LATE_REPAIR_DELAY1_SECONDS, function()
                                    if (lastApplySeq or 0) ~= applySeq then
                                        return
                                    end
                                    ApplyLayout("post-check-late-repair")
                                end)

                                C_Timer.After(POSTCHECK_LATE_REPAIR_DELAY2_SECONDS, function()
                                    if (lastApplySeq or 0) ~= applySeq then
                                        return
                                    end
                                    if StillDrifted() then
                                        ApplyLayout("post-check-late-repair2")
                                    end
                                end)
                            end
                        end
                    end
                end
            end
        end)
    end
end

local function QueueApply(reason)
    local newReason = reason or "queued"

    -- If we already have the exact same reason pending, don't churn timers.
    if applyTimer and pendingReason == newReason then
        DebugStatus("Queue: already pending (" .. tostring(pendingReason) .. ")")
        return
    end

    pendingReason = newReason

    DebugStatus("Queue: " .. tostring(pendingReason))

    if applyTimer and applyTimer.Cancel then
        applyTimer:Cancel()
        applyTimer = nil
    end

    local function GetApplyDelaySeconds(r)
        -- WoW can still be syncing action bars/macros right after enable/login.
        -- Applying too early gets overwritten and looks like “drift” even with no other addons.
        local now = nil
        if type(GetTime) == "function" then
            local ok, t = pcall(GetTime)
            if ok and type(t) == "number" then
                now = t
            end
        end

        if r == "startup" then
            if now then
                startupSyncUntil = now + (STARTUP_IGNORE_EVENTS_SECONDS or 0)
                startupIgnoreEventsUntil = now + (STARTUP_IGNORE_EVENTS_SECONDS or 0)
            end
            postCheckRepairAttempts = 0
            return STARTUP_APPLY_DELAY_SECONDS
        end

        if r == "enable" or r == "PLAYER_ENTERING_WORLD" or r == "PLAYER_LOGIN" or r == "VARIABLES_LOADED" then
            if now then
                startupSyncUntil = now + 4.0
            end
            postCheckRepairAttempts = 0
            return 2.50
        end

        if r == "UPDATE_MACROS" then
            if now and (startupSyncUntil or 0) > now then
                -- Coalesce macro updates during startup; apply once near the end.
                local wait = (startupSyncUntil - now) + 0.25
                if wait < 0.75 then
                    wait = 0.75
                end
                return wait
            end
            return 1.00
        end

        if r == "level-up" or r == "PLAYER_LEVEL_UP" then
            return LEVEL_UP_APPLY_DELAY_SECONDS
        end

        if r == "spec-change" then
            return SPEC_CHANGE_APPLY_DELAY_SECONDS
        end

        return 0.35
    end

    if C_Timer and C_Timer.NewTimer then
        applyTimer = C_Timer.NewTimer(GetApplyDelaySeconds(pendingReason), function()
            applyTimer = nil
            local r = pendingReason
            pendingReason = nil
            ApplyLayout(r)
        end)
    else
        ApplyLayout(pendingReason)
        pendingReason = nil
    end
end

local eventFrame = CreateFrame("Frame")

-- Zone change events can be very chatty (especially while flying). We only want to react
-- when it’s likely to matter, so we ignore the sub-zone events and throttle NEW_AREA.
local lastZoneApplyAt = 0
local ZONE_APPLY_THROTTLE_SECONDS = 5.0
local lastZoneExpansionKey = nil

local function HasExpansionLayoutsConfigured()
    local s = GetSettings()
    if type(s) ~= "table" then
        return false
    end

    local byExp = rawget(s, "actionBarLayoutByExpansionAcc")
    if type(byExp) == "table" and next(byExp) ~= nil then
        return true
    end

    local byExpProf = rawget(s, "actionBarLayoutByExpansionProfessionAcc")
    if type(byExpProf) == "table" and next(byExpProf) ~= nil then
        return true
    end

    return false
end

local function OnEvent(self, event, ...)
    -- During startup stabilization we ignore chatty events that tend to cause extra applies.
    -- PLAYER_ENTERING_WORLD is used as our anchor to schedule the one-time startup apply.
    if InStartupIgnoreWindow() and event == "PLAYER_ENTERING_WORLD" and (not startupPendingEnterWorld) then
        return
    end
    if (startupPendingEnterWorld or InStartupIgnoreWindow()) and event ~= "PLAYER_ENTERING_WORLD" and event ~= "PLAYER_REGEN_ENABLED" then
        if event == "UPDATE_MACROS" or event == "UPDATE_BINDINGS" or event == "ACTIONBAR_SLOT_CHANGED" or event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_LEVEL_UP" then
            return
        end
    end

    if event == "PLAYER_ENTERING_WORLD" then
        if startupPendingEnterWorld then
            startupPendingEnterWorld = false
            QueueApply("startup")
            return
        end
        -- Continue handling any other PEW logic below (if any in the future).
    end

    if event == "ACTIONBAR_SLOT_CHANGED" then
        if not GetDriftEnabled() then
            return
        end
        -- If a managed slot is changed by something else (addon/profile/Blizzard sync), self-heal.
        -- We keep this conservative: only react for slots in the current desired layout.
        if (internalWriteDepth or 0) > 0 then
            return
        end

        local slot = ...
        slot = tonumber(slot)

        if type(lastDesiredBySlot) ~= "table" then
            return
        end

        -- Nil/0 means "something changed"; fall back to a normal apply.
        if not slot or slot <= 0 then
            QueueApply("actionbar-change")
            return
        end

        local desired = lastDesiredBySlot[slot]
        if not desired then
            return
        end

        if SlotMatchesDesiredAction(slot, desired) then
            return
        end

        local now = nil
        if type(GetTime) == "function" then
            local ok, t = pcall(GetTime)
            if ok and type(t) == "number" then
                now = t
            end
        end

        if now then
            -- Per-slot throttle + global throttle to avoid tug-of-war loops.
            local lastSlot = tonumber(lastSlotDriftQueuedAtBySlot[slot] or 0) or 0
            if (now - lastSlot) < 2.0 then
                return
            end
            if (now - (lastSlotDriftQueuedAt or 0)) < 0.75 then
                return
            end
            lastSlotDriftQueuedAtBySlot[slot] = now
            lastSlotDriftQueuedAt = now
        end

        QueueApply("slot-drift")
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        if pendingSlotAfterCombat then
            local slot = pendingSlotAfterCombat
            local force = pendingForceAfterCombat
            pendingSlotAfterCombat = nil
            pendingForceAfterCombat = false
            pendingAfterCombat = false
            ApplyLayout("regen", slot, force)
        elseif pendingAfterCombat then
            QueueApply("regen")
        end
        -- If we queued macro conflict popups during combat, show them now.
        if C_Timer and C_Timer.After then
            C_Timer.After(0, function()
                if type(ShowNextMacroConflict) == "function" then
                    ShowNextMacroConflict()
                end
            end)
        end
        return
    end

    if event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" then
        return
    end

    if event == "ZONE_CHANGED_NEW_AREA" then
        if not HasExpansionLayoutsConfigured() then
            DebugStatus("Queue skipped (no expansion layouts): " .. tostring(event))
            return
        end

        local expKey = GetCurrentExpansionKeyForPlayer()
        if expKey == lastZoneExpansionKey then
            DebugStatus("Queue skipped (same expansion): " .. tostring(expKey))
            return
        end
        lastZoneExpansionKey = expKey

        if not GetTime then
            return
        end

        local now = GetTime()
        if type(now) == "number" and now > 0 then
            if (now - (lastZoneApplyAt or 0)) < ZONE_APPLY_THROTTLE_SECONDS then
                DebugStatus("Queue skipped (zone throttle): " .. tostring(event))
                return
            end
            lastZoneApplyAt = now
        end
    end

    -- UPDATE_MACROS can fire very frequently due to other addons/UI refreshes.
    -- If all desired macro slots already match our desired state, we don't need to re-apply.
    -- This avoids constant no-op applies (and chat spam when debug is enabled).
    if event == "UPDATE_MACROS" then
        if type(lastDesiredBySlot) == "table" and next(lastDesiredBySlot) ~= nil then
            local needsMacroFix = false
            for slot, desired in pairs(lastDesiredBySlot) do
                if type(desired) == "table" and desired.kind == "macro" then
                    if not SlotMatchesDesiredAction(slot, desired) then
                        needsMacroFix = true
                        break
                    end
                end
            end
            if not needsMacroFix then
                return
            end
        end
    end

    -- Coalesce very chatty/bursty events into stable reasons.
    local reason = event
    if event == "PLAYER_SPECIALIZATION_CHANGED" then
        reason = "spec-change"
    elseif event == "PLAYER_LEVEL_UP" then
        reason = "level-up"
    end

    QueueApply(reason)
end

eventFrame:SetScript("OnEvent", OnEvent)

function ns.ActionBar_ApplyNow(reason)
    QueueApply(reason or "manual")
end

function ns.ActionBar_ApplySlotNow(slot, forceOverwrite)
    slot = NormalizeSlot(slot)
    if not slot then
        return false
    end
    ApplyLayout("slot-" .. tostring(slot), slot, forceOverwrite and true or false)
    return true
end

function ns.ApplyActionBarSetting(force)
    if not force and didInit then
        return
    end
    didInit = true

    InitSV()

    SyncGlobals()

    local enabled = GetBoolSetting("actionBarEnabledAcc", false)

    if enabled and not didRegister then
        didRegister = true
        eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
        eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
        eventFrame:RegisterEvent("UPDATE_MACROS")
        eventFrame:RegisterEvent("UPDATE_BINDINGS")
        eventFrame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
        eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
        -- Defer the first apply until PLAYER_ENTERING_WORLD and a generous delay.
        -- This avoids doing multiple applies while bars/macros are still syncing.
        startupPendingEnterWorld = true
        if type(GetTime) == "function" then
            local ok, now = pcall(GetTime)
            if ok and type(now) == "number" then
                startupIgnoreEventsUntil = now + (STARTUP_IGNORE_EVENTS_SECONDS or 0)
                startupSyncUntil = now + (STARTUP_IGNORE_EVENTS_SECONDS or 0)
            end
        end

        -- If Situate is enabled mid-session (or PEW doesn't fire for some reason), still apply.
        if C_Timer and C_Timer.After then
            C_Timer.After(1.0, function()
                if startupPendingEnterWorld then
                    startupPendingEnterWorld = false
                    QueueApply("startup")
                end
            end)
        end
        return
    end

    if (not enabled) and didRegister then
        didRegister = false
        eventFrame:UnregisterAllEvents()
        pendingAfterCombat = false
        startupPendingEnterWorld = false
        startupIgnoreEventsUntil = 0
    end
end

-- Kick once on load so enabling via SavedVariables works.
if C_Timer and C_Timer.After then
    C_Timer.After(0, function()
        SyncGlobals()
        ns.ApplyActionBarSetting(true)
    end)
end
