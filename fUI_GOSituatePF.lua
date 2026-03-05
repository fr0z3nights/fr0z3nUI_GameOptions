local addonName, ns = ...
ns = ns or {}

-- Professions/skill-tier cache (per character)
-- Used by Talk DB packs to make decisions even when C_TradeSkillUI APIs are not ready during a gossip frame.
ns.Profs = ns.Profs or {}

local Profs = ns.Profs

Profs.TRACKED_TIERS = Profs.TRACKED_TIERS or { 1100, 2159 } -- Fishing (Classic), Fishing (Midnight)
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
    Profs.RefreshKnownSkillTiers(Profs.TRACKED_TIERS or {})
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
        local profs = { GetProfessions() }
        for _, p in ipairs(profs) do
            if p ~= nil then
                local name, _, rank, _, _, _, skillLine = GetProfessionInfo(p)
                if skillLine == 2911 then
                    cache[2159] = true
                    if type(time) == "function" then
                        AutoGossip_CharSettings.knownSkillTiersAt = time()
                    end
                    return true
                end
                if type(name) == "string" then
                    local lname = name:lower()
                    if lname:find("midnight", 1, true) and lname:find("fishing", 1, true) then
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
