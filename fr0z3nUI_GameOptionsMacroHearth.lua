local _, ns = ...

-- NOTE (FGO): Do NOT reference legacy standalone addons (e.g., HearthZone / global fHZ).
-- This module owns the hearth storage + macro rotation + bind/zone display logic.

local PREFIX = "|cff00ccff[FGO]|r "
local function Print(msg)
    print(PREFIX .. tostring(msg or ""))
end

local function InCombat()
    return InCombatLockdown and InCombatLockdown() or false
end

-- Hearth logic (extracted from fr0z3nUI_GameOptionsMacro.lua).
do
    local MACRO_NAME = "FGO Hearth"

    local function SafeLower(s)
        return tostring(s or ""):lower()
    end

    local function GetCharKey()
        if UnitFullName then
            local name, realm = UnitFullName("player")
            if name and realm and realm ~= "" then
                return tostring(name) .. "-" .. tostring(realm)
            end
            if name then
                return tostring(name)
            end
        end
        if UnitName then
            local name = UnitName("player")
            local realm = GetRealmName and GetRealmName() or nil
            if name and realm and realm ~= "" then
                return tostring(name) .. "-" .. tostring(realm)
            end
            if name then
                return tostring(name)
            end
        end
        return "player"
    end

    local function EnsureInit()
        _G.AutoGame_UI = _G.AutoGame_UI or {}
        local root = _G.AutoGame_UI
        root.hearth = root.hearth or {}
        local db = root.hearth

        db.window = db.window or { tab = "hearth", macroPerChar = false }
        db.zoneByChar = db.zoneByChar or {}
        db.customUseItems = db.customUseItems or {}

        if db.selectedUseItemID ~= nil then
            db.selectedUseItemID = tonumber(db.selectedUseItemID)
        end

        if db.autoRotate ~= nil then
            db.autoRotate = db.autoRotate and true or false
        else
            db.autoRotate = false
        end

        if db.toyShowAll ~= nil then
            db.toyShowAll = db.toyShowAll and true or false
        else
            db.toyShowAll = false
        end

        if db.toyFilter == nil then
            db.toyFilter = ""
        end

        return db, GetCharKey()
    end

    local function IsDraeneiPlayer()
        if not UnitRace then return false end
        local _, raceFile = UnitRace("player")
        return raceFile == "Draenei" or raceFile == "LightforgedDraenei"
    end

    local function GetItemCountByID(itemID)
        itemID = tonumber(itemID)
        if not itemID then return 0 end
        if C_Item and C_Item.GetItemCount then
            return tonumber(C_Item.GetItemCount(itemID, true, false)) or 0
        end
        if GetItemCount then
            return tonumber(GetItemCount(itemID, true)) or 0
        end
        return 0
    end

    local function GetItemNameByID(itemID)
        itemID = tonumber(itemID)
        if not itemID then return nil end
        if C_Item and C_Item.GetItemNameByID then
            return C_Item.GetItemNameByID(itemID)
        end
        if GetItemInfo then
            return GetItemInfo(itemID)
        end
        return nil
    end

    local function BuildMacroRunLine(useItemID)
        useItemID = tonumber(useItemID) or 6948
        return ("/run local id=%d; local s,d=GetItemCooldown(id); s=s+d-GetTime(); if s>1 then print(format('Hearth in %d mins', s/60)) else print('Hearthing') end")
            :format(useItemID)
    end

    local CURATED_USE_ITEMS = {
        { id = 263489, label = "Naaru's Enfold" },
        { id = 246565, label = "Cosmic Hearthstone" },
        { id = 245970, label = "P.O.S.T. Master's Express Hearthstone" },
        { id = 236687, label = "Explosive Hearthstone" },
        { id = 235016, label = "Redeployment Module" },
        { id = 228940, label = "Notorious Thread's Hearthstone" },
        { id = 228834, label = "Explosive Hearthstone (alt)" },
        { id = 228833, label = "Redeployment Module (alt)" },
        { id = 213327, label = "Stone of the Hearth (alt)" },
        { id = 212337, label = "Stone of the Hearth" },
        { id = 210629, label = "Deepdweller's Earthen Hearthstone (alt)" },
        { id = 210455, label = "Draenic Hologem" },
        { id = 209035, label = "Hearthstone of the Flame" },
        { id = 208704, label = "Deepdweller's Earthen Hearthstone" },
        { id = 206195, label = "Path of the Naaru" },
        { id = 200630, label = "Ohn'ir Windsage's Hearthstone" },
        { id = 193588, label = "Timewalker's Hearthstone" },
        { id = 190237, label = "Broker Translocation Matrix" },
        { id = 190196, label = "Enlightened Hearthstone" },
        { id = 188952, label = "Dominated Hearthstone" },
        { id = 184353, label = "Kyrian Hearthstone" },
        { id = 183716, label = "Venthyr Sinstone" },
        { id = 183710, label = "Venthyr Sinstone (alt)" },
        { id = 183709, label = "Necrolord Hearthstone (alt)" },
        { id = 183708, label = "Night Fae Hearthstone (alt)" },
        { id = 182773, label = "Necrolord Hearthstone" },
        { id = 180290, label = "Night Fae Hearthstone" },
        { id = 172179, label = "Eternal Traveler's Hearthstone" },
        { id = 168907, label = "Holographic Digitalization Hearthstone" },
        { id = 166747, label = "Brewfest Reveler's Hearthstone" },
        { id = 166746, label = "Fire Eater's Hearthstone" },
        { id = 165802, label = "Noble Gardener's Lovely Hearthstone" },
        { id = 165670, label = "Peddlefeet's Lovely Hearthstone" },
        { id = 165669, label = "Lunar Elder's Hearthstone" },
        { id = 163045, label = "Headless Horseman's Hearthstone" },
        { id = 162973, label = "Greatfather Winter's Hearthstone" },
        { id = 142542, label = "Tome of Town Portal" },
        { id = 93672, label = "Dark Portal" },
        { id = 64488, label = "The Innkeeper's Daughter" },
        { id = 54452, label = "Ethereal Portal" },
    }

    local function HasUseItem(itemID)
        itemID = tonumber(itemID)
        if not itemID then return false end

        if itemID == 210455 and not IsDraeneiPlayer() then
            return false
        end

        if itemID == 6948 then
            return (GetItemCountByID(6948) or 0) > 0
        end
        if PlayerHasToy and PlayerHasToy(itemID) then
            return true
        end
        return (GetItemCountByID(itemID) or 0) > 0
    end

    local function GetUseItemName(itemID, fallback)
        itemID = tonumber(itemID)
        if not itemID then return tostring(fallback or "") end
        if itemID == 6948 then
            return "Hearthstone"
        end
        return GetItemNameByID(itemID) or tostring(fallback or ("item:" .. tostring(itemID)))
    end

    local function GetToyCooldownStart(itemID)
        itemID = tonumber(itemID)
        if not itemID then return 0 end
        if PlayerHasToy and PlayerHasToy(itemID) and C_ToyBox and C_ToyBox.GetToyCooldown then
            local startTime, duration = C_ToyBox.GetToyCooldown(itemID)
            startTime = tonumber(startTime) or 0
            duration = tonumber(duration) or 0
            if startTime > 0 and duration > 0 then
                return startTime
            end
            return 0
        end
        if C_Item and C_Item.GetItemCooldown then
            local startTime, duration = C_Item.GetItemCooldown(itemID)
            startTime = tonumber(startTime) or 0
            duration = tonumber(duration) or 0
            if startTime > 0 and duration > 0 then
                return startTime
            end
        end
        return 0
    end

    local function RollRandomUseItem(db)
        if type(db) ~= "table" then return nil end
        local pool = {}
        for _, e in ipairs(CURATED_USE_ITEMS) do
            local id = tonumber(e.id)
            if id and HasUseItem(id) then
                pool[#pool + 1] = id
            end
        end
        if HasUseItem(6948) then
            pool[#pool + 1] = 6948
        end
        if #pool == 0 then
            return nil
        end
        local pick = pool[math.random(1, #pool)]
        db.selectedUseItemID = pick
        return pick
    end

    local function BuildMacroText(db)
        local useID = db and tonumber(db.selectedUseItemID)
        if useID and not HasUseItem(useID) then
            useID = nil
        end
        local lines = { "/fgo hs hearth" }
        if useID and useID > 0 then
            lines[#lines + 1] = "/use item:" .. tostring(useID)
        end
        return table.concat(lines, "\n")
    end

    local function GetOwnedHearthToys()
        local out = {}

        local hsCount = GetItemCountByID(6948)
        if hsCount and hsCount > 0 then
            out[#out + 1] = { id = 6948, name = "Hearthstone (item)" }
        end

        if not (C_ToyBox and C_ToyBox.GetNumToys and C_ToyBox.GetToyFromIndex and PlayerHasToy) then
            return out
        end

        local n = C_ToyBox.GetNumToys() or 0
        for i = 1, n do
            local itemID = C_ToyBox.GetToyFromIndex(i)
            if itemID and PlayerHasToy(itemID) then
                if C_Item and C_Item.RequestLoadItemDataByID then
                    C_Item.RequestLoadItemDataByID(itemID)
                end
                local name = GetItemNameByID(itemID)
                out[#out + 1] = { id = itemID, name = name or ("Toy " .. tostring(itemID)) }
            end
        end

        table.sort(out, function(a, b)
            return SafeLower(a.name) < SafeLower(b.name)
        end)

        return out
    end

    local function PassToyFilter(toyName, filterText)
        local ft = SafeLower(filterText)
        if ft == "" then return true end
        local tn = SafeLower(toyName)
        return tn:find(ft, 1, true) ~= nil
    end

    local function GetPlayerContinentName()
        if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetMapInfo) then
            return nil
        end

        local mapID = C_Map.GetBestMapForUnit("player")
        if not mapID then return nil end

        local continentType = Enum and Enum.UIMapType and Enum.UIMapType.Continent or nil
        local info = C_Map.GetMapInfo(mapID)

        while info do
            if continentType and info.mapType == continentType and info.name and info.name ~= "" then
                return info.name
            end
            local parentMapID = info.parentMapID
            if not parentMapID or parentMapID == 0 then
                break
            end
            info = C_Map.GetMapInfo(parentMapID)
        end
        return nil
    end

    local function GetHearthZoneCaptureText()
        local continent = GetPlayerContinentName()
        if continent and continent ~= "" then
            return continent
        end
        if GetZoneText then
            local z = GetZoneText()
            if z and z ~= "" then return z end
        end
        if GetRealZoneText then
            local z = GetRealZoneText()
            if z and z ~= "" then return z end
        end
        return ""
    end

    local function GetCurrentDisplayText()
        local db, charKey = EnsureInit()
        local bind = (GetBindLocation and GetBindLocation()) or ""
        local zone = (db.zoneByChar and db.zoneByChar[charKey]) or ""
        if zone == "" then
            return bind, "(zone not captured yet - set your hearth once)"
        end
        return bind, zone
    end

    ns.Hearth = ns.Hearth or {}
    ns.Hearth.MACRO_NAME = MACRO_NAME
    ns.Hearth.CURATED_USE_ITEMS = CURATED_USE_ITEMS
    ns.Hearth.EnsureInit = EnsureInit
    ns.Hearth.PassToyFilter = PassToyFilter
    ns.Hearth.GetUseItemName = GetUseItemName
    ns.Hearth.HasUseItem = HasUseItem
    ns.Hearth.GetOwnedHearthToys = GetOwnedHearthToys
    ns.Hearth.RollRandomUseItem = RollRandomUseItem
    ns.Hearth.BuildMacroText = BuildMacroText
    ns.Hearth.GetCurrentDisplayText = GetCurrentDisplayText

    -- Event wiring: zone capture + auto-rotate behavior for the hearth macro.
    do
        local f = CreateFrame("Frame")
        f:RegisterEvent("PLAYER_LOGIN")
        f:RegisterEvent("PLAYER_ENTERING_WORLD")
        f:RegisterEvent("HEARTHSTONE_BOUND")
        f:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
        f:RegisterEvent("SPELL_UPDATE_COOLDOWN")
        f:RegisterEvent("BAG_UPDATE_COOLDOWN")
        f:RegisterEvent("TOYS_UPDATED")

        local lastSeenCooldownStart = 0
        local lastMacroUpdateAt = 0

        local function MacroExists()
            return type(GetMacroIndexByName) == "function" and (GetMacroIndexByName(MACRO_NAME) or 0) > 0
        end

        local function UpdateMacroIfExists()
            if InCombat() then return end
            if type(GetMacroIndexByName) ~= "function" or type(EditMacro) ~= "function" then return end
            local idx = GetMacroIndexByName(MACRO_NAME)
            if not (idx and idx > 0) then return end

            local now = (GetTime and GetTime()) or 0
            if now > 0 and (now - lastMacroUpdateAt) < 0.5 then
                return
            end
            lastMacroUpdateAt = now

            local db = EnsureInit()
            local body = BuildMacroText(db)
            EditMacro(idx, MACRO_NAME, "INV_Misc_QuestionMark", body)
        end

        local function MaybeRotateAndUpdate(reason)
            local db = EnsureInit()
            if not db.autoRotate then return end
            if not MacroExists() then return end
            if InCombat() then return end

            local id = RollRandomUseItem(db)
            if not id then return end
            UpdateMacroIfExists()

            if reason then
                Print("Auto-rotated macro (" .. tostring(reason) .. "): " .. GetUseItemName(id))
            end
        end

        local function CheckUsedAndRotate()
            local db = EnsureInit()
            if not db.autoRotate then return end
            if InCombat() then return end
            if not MacroExists() then return end

            local useID = tonumber(db.selectedUseItemID)
            if not useID or useID <= 0 then return end

            local start = GetToyCooldownStart(useID)
            if start > 0 and (lastSeenCooldownStart == 0 or start ~= lastSeenCooldownStart) then
                lastSeenCooldownStart = start
                MaybeRotateAndUpdate("used")
            end
            if start == 0 then
                lastSeenCooldownStart = 0
            end
        end

        f:SetScript("OnEvent", function(_, event)
            if event == "PLAYER_LOGIN" then
                EnsureInit()
                local rs = math and rawget(math, "randomseed")
                local rr = math and rawget(math, "random")
                if time and rs then
                    rs((time() or 0) + (GetServerTime and (GetServerTime() or 0) or 0))
                    if rr then
                        rr()
                        rr()
                    end
                end
                return
            end

            if event == "PLAYER_ENTERING_WORLD" then
                MaybeRotateAndUpdate("login")
                return
            end

            local db, charKey = EnsureInit()
            if event == "HEARTHSTONE_BOUND" then
                db.zoneByChar = db.zoneByChar or {}
                db.zoneByChar[charKey] = GetHearthZoneCaptureText()
                return
            end

            if event == "ACTIONBAR_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_COOLDOWN" or event == "BAG_UPDATE_COOLDOWN" or event == "TOYS_UPDATED" then
                CheckUsedAndRotate()
            end
        end)
    end
end
