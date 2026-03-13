local addonName, ns = ...
ns = ns or {}

-- Professions/skill-tier cache (per character)
-- Used by Talk DB packs to make decisions even when C_TradeSkillUI APIs are not ready during a gossip frame.
ns.Profs = ns.Profs or {}

local Profs = ns.Profs

local issecretvalue = issecretvalue

-- Breadcrumbs: Profession tier categoryIDs (Retail)
--
-- Where we source categoryIDs:
-- - Read-only source: z Library/ZygorGuidesViewer/Code-Retail/Profession.lua (ZGVP.tradeskills[*].subs keys)
-- - Local copy for our addon work: Reference/Profession CategoryIDs - Full (from Zygor).md
--
-- We keep the addon itself lightweight (no huge hardcoded tables here). When you need a new
-- trainer/gossip rule, grab the categoryID from the Reference file and use Profs.KnowsTier(categoryID).

Profs.TRACKED_TIERS = Profs.TRACKED_TIERS or { 1100, 2159, 2156 } -- Fishing (Classic), Fishing (Midnight), Cooking (Midnight)
Profs._lastRefreshAt = Profs._lastRefreshAt or 0
Profs._lastProfKeyRefreshAt = Profs._lastProfKeyRefreshAt or 0

-- Stable profession keys (avoid localized names).
local SKILLLINE_TO_PROFKEY = {
    [164] = "Blacksmithing",
    [165] = "Leatherworking",
    [171] = "Alchemy",
    [182] = "Herbalism",
    [185] = "Cooking",
    [186] = "Mining",
    [197] = "Tailoring",
    [202] = "Engineering",
    [333] = "Enchanting",
    [356] = "Fishing",
    [393] = "Skinning",
    [755] = "Jewelcrafting",
    [762] = "Riding",
    [773] = "Inscription",
    [794] = "Archaeology",
}

-- CategoryIDs to track per profession key.
-- Source: Reference/Profession CategoryIDs - Full (from Zygor).md
Profs.TIERS_BY_PROFKEY = Profs.TIERS_BY_PROFKEY or {
    -- Crafting
    Alchemy = { 332, 433, 592, 596, 598, 600, 602, 604, 1294, 1582, 1898, 2154 },
    Blacksmithing = { 389, 426, 542, 553, 569, 577, 584, 590, 1311, 1566, 1900, 2155 },
    Enchanting = { 348, 443, 647, 656, 661, 663, 665, 667, 1364, 1588, 1904, 2157 },
    Engineering = { 347, 419, 469, 709, 713, 715, 717, 719, 1381, 1595, 1906, 2158 },
    Inscription = { 410, 415, 450, 759, 763, 765, 767, 769, 1406, 1592, 1912, 2161 },
    Jewelcrafting = { 372, 373, 464, 805, 809, 811, 813, 815, 1418, 1593, 1914, 2162 },
    Leatherworking = { 379, 380, 460, 871, 876, 878, 880, 882, 1334, 1587, 1916, 2163 },
    Tailoring = { 362, 369, 430, 942, 950, 952, 954, 956, 1395, 1591, 1922, 2166 },
    Cooking = { 64, 65, 66, 67, 68, 69, 72, 73, 74, 75, 90, 342, 475, 1118, 1323, 1585, 1902, 2156 },
    -- Gathering
    Herbalism = { 456, 1029, 1034, 1036, 1038, 1040, 1042, 1044, 1441, 1594, 1910, 2160 },
    Mining = { 425, 1065, 1068, 1070, 1072, 1074, 1076, 1078, 1320, 1584, 1918, 2164 },
    Skinning = { 459, 1046, 1050, 1052, 1054, 1056, 1058, 1060, 1331, 1586, 1920, 2165 },
    Fishing = { 1100, 1102, 1104, 1106, 1108, 1110, 1112, 1114, 1391, 1590, 1908, 2159 },
    -- Meta
    Riding = { 762 },
    -- No expansion-tier categoryIDs (tracked as a skill, but not a tiered TradeSkill UI category)
    Archaeology = {},
}

local function InitSV()
    if ns and ns._InitSV then
        ns._InitSV()
    end
end

local function EnsureCache()
    InitSV()
    AutoGossip_CharSettings = AutoGossip_CharSettings or {}
    if type(AutoGossip_CharSettings.knownSkillTiers) ~= "table" then
        AutoGossip_CharSettings.knownSkillTiers = {}
    end
    if type(AutoGossip_CharSettings.knownSkillTiersAt) ~= "number" then
        AutoGossip_CharSettings.knownSkillTiersAt = 0
    end
    return AutoGossip_CharSettings.knownSkillTiers
end

local function Trim(s)
    if type(s) ~= "string" then
        return ""
    end
    if (issecretvalue and issecretvalue(s)) or (ns and type(ns.IsSecretString) == "function" and ns.IsSecretString(s)) then
        return ""
    end
    s = s:gsub("^%s+", "")
    s = s:gsub("%s+$", "")
    return s
end

local function EnsureProfessionKeyCache()
    InitSV()
    AutoGossip_CharSettings = AutoGossip_CharSettings or {}
    if type(AutoGossip_CharSettings.knownProfessionKeys) ~= "table" then
        AutoGossip_CharSettings.knownProfessionKeys = {}
    end
    if type(AutoGossip_CharSettings.knownProfessionKeysAt) ~= "number" then
        AutoGossip_CharSettings.knownProfessionKeysAt = 0
    end
    return AutoGossip_CharSettings.knownProfessionKeys
end

-- Refresh the cached *base profession keys* ("Mining", "Alchemy", etc.).
-- Returns: true if refreshed with any data, false otherwise.
function Profs.RefreshKnownProfessionKeys(force)
    EnsureProfessionKeyCache()

    local now = (type(GetTime) == "function") and GetTime() or nil
    if not force and type(now) == "number" then
        if (now - (Profs._lastProfKeyRefreshAt or 0)) < 1 then
            return false
        end
    end
    Profs._lastProfKeyRefreshAt = (type(now) == "number") and now or (Profs._lastProfKeyRefreshAt or 0)

    local out = {}
    local sawAny = false

    local function Mark(key)
        key = Trim(tostring(key or ""))
        if key == "" then
            return
        end
        out[key] = true
        sawAny = true
    end

    local calledGetProfessions = false
    local p1, p2, p3, p4, p5 = nil, nil, nil, nil, nil
    if type(GetProfessions) == "function" and type(GetProfessionInfo) == "function" then
        calledGetProfessions = true
        p1, p2, p3, p4, p5 = GetProfessions()
        local indices = { p1, p2, p3, p4, p5 }
        for i = 1, 5 do
            local idx = indices[i]
            if idx ~= nil then
                local ok, name, _, _, _, _, skillLine = pcall(GetProfessionInfo, idx)
                if ok then
                    local stable = SKILLLINE_TO_PROFKEY[tonumber(skillLine or 0)]
                    Mark(stable or name)
                end
            end
        end
    end

    local function PlayerContextReady()
        if type(IsLoggedIn) == "function" and IsLoggedIn() then
            return true
        end
        if type(UnitName) == "function" then
            local n = UnitName("player")
            if type(n) == "string" and n ~= "" then
                return true
            end
        end
        return false
    end

    -- If we can call GetProfessions and we're logged in, an empty result is authoritative ("no professions").
    if not sawAny and calledGetProfessions and PlayerContextReady() and p1 == nil and p2 == nil and p3 == nil and p4 == nil and p5 == nil then
        sawAny = true
    end

    -- If we couldn't observe anything and we can't assert emptiness, do not clobber prior cache.
    if not sawAny then
        return false
    end

    AutoGossip_CharSettings.knownProfessionKeys = out
    if type(time) == "function" then
        AutoGossip_CharSettings.knownProfessionKeysAt = time()
    else
        AutoGossip_CharSettings.knownProfessionKeysAt = AutoGossip_CharSettings.knownProfessionKeysAt or 0
    end
    return true
end

-- Cache-only read: does the player know a base profession key?
-- Returns: true (known), false (not known), nil (unknown/not cached yet)
function Profs.GetCachedProfessionKey(professionKey)
    EnsureProfessionKeyCache()
    local at = AutoGossip_CharSettings.knownProfessionKeysAt
    if type(at) ~= "number" or at <= 0 then
        return nil
    end
    local key = Trim(tostring(professionKey or ""))
    if key == "" then
        return nil
    end
    return (AutoGossip_CharSettings.knownProfessionKeys and AutoGossip_CharSettings.knownProfessionKeys[key] == true) and true or false
end

-- Cache-only read: list known base profession keys.
-- Returns:
-- - nil: unknown/not cached yet
-- - {}: cached and known-empty (no professions)
-- - {"Mining", "Alchemy", ...}: cached known keys
function Profs.ListCachedProfessionKeys()
    EnsureProfessionKeyCache()

    local at = AutoGossip_CharSettings.knownProfessionKeysAt
    if type(at) ~= "number" or at <= 0 then
        return nil
    end

    local out = {}
    local t = AutoGossip_CharSettings.knownProfessionKeys
    if type(t) ~= "table" then
        return out
    end

    for k, v in pairs(t) do
        if v == true then
            out[#out + 1] = tostring(k)
        end
    end

    if #out > 1 then
        table.sort(out, function(a, b) return tostring(a):lower() < tostring(b):lower() end)
    end

    return out
end

local function QueryTierKnown(categoryID)
    if not (C_TradeSkillUI and type(C_TradeSkillUI.GetCategoryInfo) == "function") then
        return nil
    end
    local cat = C_TradeSkillUI.GetCategoryInfo(categoryID)
    local lvl = cat and cat.skillLineCurrentLevel
    if type(lvl) ~= "number" then
        return nil
    end
    if lvl > 0 then
        return true
    end
    if lvl == 0 then
        return false
    end
    return nil
end

function Profs.RefreshKnownSkillTiers(categoryIDs)
    local cache = EnsureCache()
    if type(categoryIDs) ~= "table" then
        categoryIDs = { categoryIDs }
    end

    local sawAny = false
    for _, id in ipairs(categoryIDs) do
        local v = QueryTierKnown(id)
        if v ~= nil then
            cache[id] = v
            sawAny = true
        end
    end

    if sawAny and type(time) == "function" then
        AutoGossip_CharSettings.knownSkillTiersAt = time()
    end
end

function Profs.RefreshTrackedSkillTiers(force)
    EnsureCache()

    -- Also refresh base profession keys so gossip hints can be profession-specific (e.g. Mining).
    Profs.RefreshKnownProfessionKeys(force)

    local now = (type(GetTime) == "function") and GetTime() or nil
    if not force and type(now) == "number" then
        if (now - (Profs._lastRefreshAt or 0)) < 1 then
            return
        end
    end
    Profs._lastRefreshAt = (type(now) == "number") and now or (Profs._lastRefreshAt or 0)

    local function AddUnique(list, seen, v)
        v = tonumber(v)
        if not v then return end
        if not seen[v] then
            seen[v] = true
            list[#list + 1] = v
        end
    end

    -- Build the tracked set dynamically based on known professions.
    local tracked = {}
    local seen = {}

    -- Always include the minimal core tiers we already depended on.
    for _, id in ipairs(Profs.TRACKED_TIERS or {}) do
        AddUnique(tracked, seen, id)
    end

    -- For robustness across users: if we know the character has a profession (e.g. Mining),
    -- track *all expansion tiers* for that profession so other modules can read the cache.
    local byProf = Profs.TIERS_BY_PROFKEY
    if type(byProf) == "table" and AutoGossip_CharSettings and type(AutoGossip_CharSettings.knownProfessionKeys) == "table" then
        for profKey, _ in pairs(AutoGossip_CharSettings.knownProfessionKeys) do
            if AutoGossip_CharSettings.knownProfessionKeys[profKey] == true then
                local ids = byProf[profKey]
                if type(ids) == "table" then
                    for i = 1, #ids do
                        AddUnique(tracked, seen, ids[i])
                    end
                end
            end
        end
    end

    -- Some modern expansion tiers can be "known" even with 0 current level immediately
    -- after training. Our specialized helpers handle that better than a raw
    -- skillLineCurrentLevel probe, so route tracked refreshes through them.
    for _, id in ipairs(tracked) do
        if id == 2156 then
            Profs.KnowsCookingMidnight()
        elseif id == 2159 then
            Profs.KnowsFishingMidnight()
        else
            Profs.RefreshKnownSkillTiers(id)
        end
    end
end

-- Generic helper for DB packs: ask whether an expansion-tier category is known.
-- Returns: true (known), false (not known), nil (unknown/not ready)
--
-- Notes:
-- - We intentionally preserve the tri-state behavior so Talk rules can avoid
--   misfiring when APIs aren't ready (nil should generally mean "don't auto-select").
-- - This uses the same per-character cache as the tracked-tier refresh.
function Profs.KnowsTier(categoryID)
    categoryID = tonumber(categoryID)
    if not categoryID or categoryID <= 0 then
        return nil
    end

    -- Midnight Cooking/Fishing need presence-based / fallback-aware logic.
    if categoryID == 2156 and type(Profs.KnowsCookingMidnight) == "function" then
        return Profs.KnowsCookingMidnight()
    end
    if categoryID == 2159 and type(Profs.KnowsFishingMidnight) == "function" then
        return Profs.KnowsFishingMidnight()
    end

    local cache = EnsureCache()
    local v = cache[categoryID]
    if v == true then
        return true
    end
    if v == false then
        return false
    end

    -- Try an immediate probe (may be nil if APIs aren't ready yet).
    local probed = QueryTierKnown(categoryID)
    if probed ~= nil then
        cache[categoryID] = probed and true or false
        if type(time) == "function" then
            AutoGossip_CharSettings.knownSkillTiersAt = time()
        end
        return cache[categoryID]
    end

    -- If the probe couldn't run, attempt a targeted refresh (still may remain nil).
    Profs.RefreshKnownSkillTiers({ categoryID })
    v = cache[categoryID]
    if v == true then
        return true
    end
    if v == false then
        return false
    end
    return nil
end

-- Cache-only read (no API probing/refresh).
-- Returns: true (known), false (not known), nil (unknown/not cached)
function Profs.GetCachedTier(categoryID)
    categoryID = tonumber(categoryID)
    if not categoryID or categoryID <= 0 then
        return nil
    end

    local cache = EnsureCache()
    local v = cache[categoryID]
    if v == true then
        return true
    end
    if v == false then
        return false
    end
    return nil
end

-- Returns: true (known), false (not known), nil (unknown/not ready)
function Profs.KnowsFishingMidnight()
    local cache = EnsureCache()
    local midnight = cache[2159]
    if midnight == true then
        return true
    end

    -- Fallback: try to detect by known professions list (more reliable than C_TradeSkillUI
    -- during early frames, and also fixes the "cached false" case right after learning).
    if type(GetProfessions) == "function" and type(GetProfessionInfo) == "function" then
        -- NOTE: GetProfessions() can return nil holes (e.g., archaeology) which would
        -- truncate a packed table and drop later returns (like Fishing). Avoid ipairs on
        -- a packed return table; instead, iterate the explicit returned indices.
        local p1, p2, p3, p4 = GetProfessions()
        local indices = { p1, p2, p3, p4 }
        for i = 1, 4 do
            local p = indices[i]
            if p ~= nil then
                local ok,
                    a1, a2, a3, a4, a5,
                    a6, a7, a8, a9, a10,
                    a11, a12, a13, a14, a15 = pcall(GetProfessionInfo, p)

                if not ok then
                    -- ignore
                else
                local info = { a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15 }
                local name = info[1]
                local rank = info[3]
                local skillLine = info[7]
                if skillLine == 2911 then
                    cache[2159] = true
                    if type(time) == "function" then
                        AutoGossip_CharSettings.knownSkillTiersAt = time()
                    end
                    return true
                end

                -- Modern Fishing tiers can show up as a specialization name (e.g. the last return value
                -- from GetProfessionInfo is "Midnight Fishing" even when the profession name is just "Fishing").
                local sawMidnightFishing = false
                for i = 1, 15 do
                    local v = info[i]
                    if type(v) == "string" then
                        if not (issecretvalue and issecretvalue(v)) then
                            local s = v:lower()
                            if s:find("midnight", 1, true) and s:find("fishing", 1, true) then
                                sawMidnightFishing = true
                                break
                            end
                        end
                    end
                end

                if sawMidnightFishing then
                    -- Rank can be 0 immediately after training; still treat as known.
                    if type(rank) == "number" and rank >= 0 then
                        cache[2159] = true
                        if type(time) == "function" then
                            AutoGossip_CharSettings.knownSkillTiersAt = time()
                        end
                        return true
                    end

                    cache[2159] = true
                    if type(time) == "function" then
                        AutoGossip_CharSettings.knownSkillTiersAt = time()
                    end
                    return true
                end
                end
            end
        end
    end

    if midnight == false then
        -- Cached false is useful, but can be stale if the player just trained and the
        -- trade-skill category probe isn't ready to overwrite it yet.
        -- If we couldn't positively detect Midnight Fishing above, keep the original false.
        return false
    end

    -- Try a targeted refresh (may still be nil if APIs not ready).
    Profs.RefreshKnownSkillTiers({ 2159 })
    midnight = cache[2159]
    if midnight == true then
        return true
    end
    if midnight == false then
        return false
    end

    return nil
end

-- Returns: true (known), false (not known), nil (unknown/not ready)
function Profs.KnowsCookingMidnight()
    local cache = EnsureCache()
    local cached = cache[2156]
    if cached == true then
        return true
    end

    local sawEnumeratedLines = false
    local enumSaysKnown = nil

    -- Most authoritative check: if the TradeSkill system can enumerate known profession
    -- lines, we can definitively say whether the player knows Midnight Cooking.
    if C_TradeSkillUI and type(C_TradeSkillUI.GetAllProfessionTradeSkillLines) == "function" then
        local ok, lines = pcall(C_TradeSkillUI.GetAllProfessionTradeSkillLines)
        if ok and type(lines) == "table" then
            sawEnumeratedLines = true
            enumSaysKnown = false
            for _, skillLineID in ipairs(lines) do
                if tonumber(skillLineID) == 2908 then
                    enumSaysKnown = true
                    break
                end
            end
            if enumSaysKnown then
                cache[2156] = true
                if type(time) == "function" then
                    AutoGossip_CharSettings.knownSkillTiersAt = time()
                end
                return true
            end
        end
    end

    -- Optional direct probe by skillLineID (if Blizzard provides it in this build).
    if C_TradeSkillUI and type(C_TradeSkillUI.GetProfessionInfoBySkillLineID) == "function" then
        local ok, info = pcall(C_TradeSkillUI.GetProfessionInfoBySkillLineID, 2908)
        if ok and type(info) == "table" then
            cache[2156] = true
            if type(time) == "function" then
                AutoGossip_CharSettings.knownSkillTiersAt = time()
            end
            return true
        end
    end

    -- Presence-based check: if the Professions UI can resolve the Midnight Cooking category at all,
    -- treat it as known regardless of current skill level.
    if C_TradeSkillUI and type(C_TradeSkillUI.GetCategoryInfo) == "function" then
        local okMid, midCat = pcall(C_TradeSkillUI.GetCategoryInfo, 2156)
        if okMid and type(midCat) == "table" then
            cache[2156] = true
            if type(time) == "function" then
                AutoGossip_CharSettings.knownSkillTiersAt = time()
            end
            return true
        end
    end

    -- Only return definitive "not known" when we have an authoritative negative (enumerated lines)
    -- or other strong evidence; otherwise keep tri-state nil so gossip rules don't misfire.
    if sawEnumeratedLines and enumSaysKnown == false then
        cache[2156] = false
        if type(time) == "function" then
            AutoGossip_CharSettings.knownSkillTiersAt = time()
        end
        return false
    end

    -- Fallback: try to detect by known professions list (more reliable than C_TradeSkillUI
    -- during early frames, and also fixes the "cached false" case right after learning).
    if type(GetProfessions) == "function" and type(GetProfessionInfo) == "function" then
        -- NOTE: GetProfessions() can return nil holes (e.g., archaeology) which would
        -- truncate a packed table and drop later returns (like Cooking). Avoid ipairs on
        -- a packed return table; instead, iterate the explicit returned indices.
        local p1, p2, p3, p4, p5 = GetProfessions()
        local indices = { p1, p2, p3, p4, p5 }
        for i = 1, 5 do
            local p = indices[i]
            if p ~= nil then
                local ok,
                    a1, a2, a3, a4, a5,
                    a6, a7, a8, a9, a10,
                    a11, a12, a13, a14, a15 = pcall(GetProfessionInfo, p)

                if not ok then
                    -- ignore
                else
                    local info = { a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15 }
                    local rank = info[3]
                    local skillLine = info[7]
                    if skillLine == 2908 then
                        cache[2156] = true
                        if type(time) == "function" then
                            AutoGossip_CharSettings.knownSkillTiersAt = time()
                        end
                        return true
                    end

                    -- Cooking tiers can show up as a specialization name (e.g. the last return value
                    -- from GetProfessionInfo is "Midnight Cooking" even when the profession name is just "Cooking").
                    local sawMidnightCooking = false
                    for i = 1, 15 do
                        local v = info[i]
                        if type(v) == "string" then
                            if not (issecretvalue and issecretvalue(v)) then
                                local s = v:lower()
                                if s:find("midnight", 1, true) and s:find("cooking", 1, true) then
                                    sawMidnightCooking = true
                                    break
                                end
                            end
                        end
                    end

                    if sawMidnightCooking then
                        -- Rank can be 0 immediately after training; still treat as known.
                        if type(rank) == "number" and rank >= 0 then
                            cache[2156] = true
                            if type(time) == "function" then
                                AutoGossip_CharSettings.knownSkillTiersAt = time()
                            end
                            return true
                        end

                        cache[2156] = true
                        if type(time) == "function" then
                            AutoGossip_CharSettings.knownSkillTiersAt = time()
                        end
                        return true
                    end
                end
            end
        end
    end

    -- Try a targeted refresh (may still be nil if APIs not ready).
    Profs.RefreshKnownSkillTiers({ 2156, 72 })
    local v = cache[2156]
    if v == true then
        return true
    end

    -- Only return definitive "not known" if we also have evidence that Cooking is known.
    -- (Avoid treating "0" levels as authoritative when APIs are half-ready.)
    if v == false and cache[72] == true then
        return false
    end

    return nil
end

-- Returns: true (known), false (not known), nil (unknown/not ready)
function Profs.KnowsFishingClassicOrMidnight()
    local cache = EnsureCache()
    local classic = cache[1100]
    local midnight = cache[2159]

    if classic == true or midnight == true then
        return true
    end
    if classic == false and midnight == false then
        return false
    end

    -- Try a targeted refresh (may still be nil if APIs not ready).
    Profs.RefreshKnownSkillTiers({ 1100, 2159 })
    classic = cache[1100]
    midnight = cache[2159]
    if classic == true or midnight == true then
        return true
    end
    if classic == false and midnight == false then
        return false
    end

    -- Fallback: if Fishing shows up as a secondary profession with rank info, use that.
    if type(GetProfessions) == "function" and type(GetProfessionInfo) == "function" then
        local _, _, _, fish = GetProfessions()
        if fish == nil then
            return nil
        end
        local _, _, rank = GetProfessionInfo(fish)
        if type(rank) == "number" then
            if rank > 0 then
                cache[1100] = true
                if type(time) == "function" then
                    AutoGossip_CharSettings.knownSkillTiersAt = time()
                end
                return true
            end
            if rank == 0 then
                cache[1100] = false
                if type(time) == "function" then
                    AutoGossip_CharSettings.knownSkillTiersAt = time()
                end
                return false
            end
        end
    end

    return nil
end
