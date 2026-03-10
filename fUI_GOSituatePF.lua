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
    local now = (type(GetTime) == "function") and GetTime() or nil
    if not force and type(now) == "number" then
        if (now - (Profs._lastRefreshAt or 0)) < 1 then
            return
        end
    end
    Profs._lastRefreshAt = (type(now) == "number") and now or (Profs._lastRefreshAt or 0)

    -- Some modern expansion tiers can be "known" even with 0 current level immediately
    -- after training. Our specialized helpers handle that better than a raw
    -- skillLineCurrentLevel probe, so route tracked refreshes through them.
    local tracked = Profs.TRACKED_TIERS or {}
    for _, id in ipairs(tracked) do
        id = tonumber(id)
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
