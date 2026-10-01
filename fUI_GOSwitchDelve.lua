---@diagnostic disable: undefined-global
local addonName, ns = ...
if type(ns) ~= 'table' then
    ns = {}
end

ns.TalkUP = ns.TalkUP or {}
local M = ns.TalkUP

-- Floating Dundun reminder (armed by Dundun's Delve notification)
-- ============================================================================

do
    local button
    local DUNDUN_NPC_ID = "242704"
    local DUNDUN_TARGET_NPC_IDS = {
        ["242704"] = true,
        ["251601"] = true,
    }
    local DUNDUN_GOSSIP_OPTIONS = {
        [140123] = true,
        [140126] = true,
        [140496] = true,
        [140495] = true,
        [140513] = true,
        [140514] = true,
    }
    local DELVE_MAP_IDS = {
		[2635] = true,					--	DELV: Gnarldor Isle
		[2633] = true,					--	DELV: The Ring of Glory
		[2502] = true,					--	DELV: The Shadow Enclave
		[2510] = true,					--	DELV: The Grudge Pit
		[2505] = true,					--	DELV: Gulf of Memory
		[2545] = true, [2578] = true,	--	DELV: Parhelion Plaza
		[2547] = true, [2577] = true,	--	DELV: Collegiate Calamity
		[2525] = true,					--	DELV: The Darkway
		[2506] = true,					--	DELV: Shadowguard Point
		[2528] = true, [2571] = true,	--	DELV: Sunkiller Sanctum1
		[2535] = true, [2536] = true,	--	DELV: Atal'Aman (Also shows in outter Atal'Aman)
		[2503] = true, [2504] = true,	--	DELV: Twilight Crypts
    }

    local function InitSV()
        if ns and type(ns._InitSV) == "function" then
            ns._InitSV()
        end
    end

    local function GetUI()
        InitSV()
        return rawget(_G, "AutoGame_UI") or rawget(_G, "AutoGossip_UI")
    end

    local function GetCurrentMapID()
        if not (C_Map and type(C_Map.GetBestMapForUnit) == "function") then
            return nil
        end
        local ok, mapID = pcall(C_Map.GetBestMapForUnit, "player")
        mapID = ok and tonumber(mapID) or nil
        return (mapID and mapID > 0) and math.floor(mapID) or nil
    end

    local function GetCurrentDelveMapID()
        local mapID = GetCurrentMapID()
        if not mapID then
            return nil
        end

        if not (C_Map and type(C_Map.GetMapInfo) == "function") then
            return DELVE_MAP_IDS[mapID] and mapID or nil
        end

        local seen = {}
        for _ = 1, 30 do
            if not mapID or seen[mapID] then
                return nil
            end
            seen[mapID] = true
            if DELVE_MAP_IDS[mapID] then
                return mapID
            end

            local ok, info = pcall(C_Map.GetMapInfo, mapID)
            if not ok or type(info) ~= "table" then
                return nil
            end
            mapID = tonumber(info.parentMapID)
        end
        return nil
    end

    -- Every delve scenario surfaces the ScenarioHeaderDelves widget, so this catches delve maps
    -- that aren't in DELVE_MAP_IDS yet and clients where C_DelvesUI.HasActiveDelve misreports.
    local function HasDelveScenarioWidget()
        if not (C_ScenarioInfo and type(C_ScenarioInfo.GetScenarioStepInfo) == "function"
            and C_UIWidgetManager and type(C_UIWidgetManager.GetAllWidgetsBySetID) == "function"
            and Enum and Enum.UIWidgetVisualizationType
            and Enum.UIWidgetVisualizationType.ScenarioHeaderDelves) then
            return false
        end

        local ok, stepInfo = pcall(C_ScenarioInfo.GetScenarioStepInfo)
        local widgetSetID = (ok and type(stepInfo) == "table") and tonumber(stepInfo.widgetSetID) or nil
        if not widgetSetID then
            return false
        end

        local widgetsOK, widgets = pcall(C_UIWidgetManager.GetAllWidgetsBySetID, widgetSetID)
        if not widgetsOK or type(widgets) ~= "table" then
            return false
        end

        for _, widget in ipairs(widgets) do
            if type(widget) == "table"
                and widget.widgetType == Enum.UIWidgetVisualizationType.ScenarioHeaderDelves then
                return true
            end
        end

        return false
    end

    local function IsInDelve()
        local mapID = GetCurrentDelveMapID()
        if mapID ~= nil then
            return true, mapID
        end

        if C_DelvesUI and type(C_DelvesUI.HasActiveDelve) == "function" then
            local ok, active = pcall(C_DelvesUI.HasActiveDelve)
            if ok and active == true then
                return true, "delve-instance"
            end
        end

        if HasDelveScenarioWidget() then
            return true, "delve-instance"
        end

        return false, nil
    end

    local function HasActiveDelveInstance()
        if C_DelvesUI and type(C_DelvesUI.HasActiveDelve) == "function" then
            local ok, active = pcall(C_DelvesUI.HasActiveDelve)
            if ok and active == true then
                return true
            end
        end
        return HasDelveScenarioWidget()
    end

    local function IsInPetBattle()
        if C_PetBattles and type(C_PetBattles.IsInBattle) == "function" then
            local ok, active = pcall(C_PetBattles.IsInBattle)
            return ok and active == true
        end
        return false
    end

    -- DELVE_MAP_IDS intentionally covers outdoor zones (e.g. outer Atal'Aman) for the reminder,
    -- so callers that must act only inside the delve itself need the instance check too.
    local function IsInsideDelveInstance()
        if HasActiveDelveInstance() then
            return true
        end
        if GetCurrentDelveMapID() == nil then
            return false
        end
        if type(IsInInstance) ~= "function" then
            return false
        end
        local ok, inInstance = pcall(IsInInstance)
        return ok and inInstance == true
    end

    local delveExitPopupHooked = false
    local delveExitCooldownUntil = 0
    local delveWasActive = false

    local function StartDelveExitDelay()
        local now = type(GetTime) == "function" and GetTime() or 0
        local delay = math.max(0, math.min(300,
            tonumber(AutoGossip_Settings and AutoGossip_Settings.autoDelveExitDelayAcc) or 300))
        local deadline = now + delay
        if deadline > delveExitCooldownUntil then
            delveExitCooldownUntil = deadline
        end
    end

    local function TrackDelveStateTransition()
        local activeDelve = HasActiveDelveInstance()
        if delveWasActive and not activeDelve then
            StartDelveExitDelay()
        end
        delveWasActive = activeDelve
    end

    local function DelveExitDebug(message)
        if AutoGame_Settings and AutoGame_Settings.valeera and AutoGame_Settings.valeera.debug then
            print("|cffff8000[FGO Delve exit]|r " .. tostring(message))
        end
    end

    local function AcceptVisibleDelveExitPopup(attempt, expectedWhich, expectedData)
        for index = 1, 4 do
            local popup = _G["StaticPopup" .. index]
            local text = popup and popup:IsShown() and popup.text
            local message = text and text:GetText()
            local isKnownDelvePopup = popup and popup:IsShown()
                and expectedWhich == "SPELL_CONFIRMATION_PROMPT"
                and popup.which == expectedWhich
                and tonumber(popup.data) == tonumber(expectedData)
            local isLeaveText = type(message) == "string"
                and string.find(string.lower(message), "ready to leave", 1, true)
            if isKnownDelvePopup or isLeaveText then
                local button = popup.button1 or _G["StaticPopup" .. index .. "Button1"]
                DelveExitDebug("popup=" .. tostring(index) .. " text=" .. tostring(message)
                    .. " button1=" .. tostring(button and button:IsShown() == true))
                if button and button:IsShown() and type(button.Click) == "function" then
                    DelveExitDebug("confirmation requires a hardware click")
                    return true
                end
            end
        end
        DelveExitDebug("leave popup not ready, attempt=" .. tostring(attempt or 1))
        if (tonumber(attempt) or 1) < 5 and C_Timer
            and type(C_Timer.After) == "function" then
            C_Timer.After(0.1, function()
                AcceptVisibleDelveExitPopup((tonumber(attempt) or 1) + 1,
                    expectedWhich, expectedData)
            end)
        end
        return false
    end

    local function HookAutoDelveExitPopup()
        if delveExitPopupHooked or type(hooksecurefunc) ~= "function"
            or type(StaticPopup_Show) ~= "function" then
            return
        end
        delveExitPopupHooked = true

        hooksecurefunc("StaticPopup_Show", function(which, textArg1, textArg2, data)
            if not ns.GetAutoDelveExitEnabled() then
                return
            end
            DelveExitDebug("StaticPopup_Show which=" .. tostring(which)
                .. " data=" .. tostring(data))
            if which == "SPELL_CONFIRMATION_PROMPT" and tonumber(data) == 469212 then
                print("Sorry this exit requires manual click")
                if C_Timer and type(C_Timer.After) == "function" then
                    C_Timer.After(0, function()
                        AcceptVisibleDelveExitPopup(1, which, data)
                    end)
                else
                    AcceptVisibleDelveExitPopup(1, which, data)
                end
                return
            end
            if tonumber(data) ~= 424700 then
                if C_Timer and type(C_Timer.After) == "function" then
                    C_Timer.After(0, function()
                        AcceptVisibleDelveExitPopup(1, which, data)
                    end)
                else
                    AcceptVisibleDelveExitPopup(1, which, data)
                end
                return
            end
            if C_PartyInfo and type(C_PartyInfo.DelveTeleportOut) == "function" then
                StartDelveExitDelay()
                pcall(C_PartyInfo.DelveTeleportOut)
            end
        end)
    end

    function ns.GetAutoDelveEnabled()
        InitSV()
        return AutoGossip_Settings and AutoGossip_Settings.autoDelveAcc == true
            and AutoGossip_CharSettings and AutoGossip_CharSettings.autoDelveEnabledChar == true
    end

    function ns.GetAutoDelveAccountEnabled()
        InitSV()
        return AutoGossip_Settings and AutoGossip_Settings.autoDelveAcc == true
    end

    function ns.SetAutoDelveEnabled(enabled)
        InitSV()
        enabled = enabled == true
        if AutoGossip_Settings then
            AutoGossip_Settings.autoDelveAcc = enabled
        end
    end

    function ns.GetAutoDelveCharacterEnabled()
        InitSV()
        return AutoGossip_CharSettings and AutoGossip_CharSettings.autoDelveEnabledChar == true
    end

    function ns.SetAutoDelveCharacterEnabled(enabled)
        InitSV()
        if AutoGossip_CharSettings then
            AutoGossip_CharSettings.autoDelveEnabledChar = enabled == true
        end
    end

    function ns.GetAutoDelveConfigPopupFrame()
        return rawget(_G, "FGO_DelveConfigPopup")
    end

    local function UpdateDelveConfigPopup()
        local popup = ns.GetAutoDelveConfigPopupFrame()
        if not popup then return end
        local enter = ns.GetAutoDelveAccountEnabled()
        local exit = ns.GetAutoDelveExitEnabled()
        popup.enter:SetText(enter and "Enter: ON" or "Enter: OFF")
        popup.exit:SetText(exit and "Exit: ON" or "Exit: OFF")
        popup.delay:SetText(tostring(tonumber(AutoGossip_Settings.autoDelveEnterDelayAcc) or 0))
        popup.exitDelay:SetText(tostring(tonumber(AutoGossip_Settings.autoDelveExitDelayAcc) or 300))
        popup.allowNemesis:SetChecked(ns.GetAutoDelveAllowNemesis() == true)
    end

    function ns.OpenAutoDelveConfigPopup()
        InitSV()
        local popup = ns.GetAutoDelveConfigPopupFrame()
        if popup then
            UpdateDelveConfigPopup()
            popup:Show()
            return popup
        end
        popup = CreateFrame("Frame", "FGO_DelveConfigPopup", AutoGameOptions or UIParent, "BackdropTemplate")
        popup:SetSize(300, 155)
        popup:SetFrameStrata("DIALOG")
        popup:SetPoint("TOPLEFT", AutoGameOptions or UIParent, "TOPRIGHT", 10, -70)
        if popup.SetBackdrop then
            popup:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", tile = true, tileSize = 32 })
        end
        local title = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOP", 0, -10)
        title:SetText("Delve")
        popup.enter = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
        popup.enter:SetSize(85, 22)
        popup.enter:SetPoint("TOPLEFT", 18, -35)
        popup.enter:SetScript("OnClick", function()
            ns.SetAutoDelveEnabled(not ns.GetAutoDelveAccountEnabled())
            UpdateDelveConfigPopup()
        end)
        popup.exit = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
        popup.exit:SetSize(85, 22)
        popup.exit:SetPoint("LEFT", popup.enter, "RIGHT", 8, 0)
        popup.exit:SetScript("OnClick", function()
            ns.SetAutoDelveExitEnabled(not ns.GetAutoDelveExitEnabled())
            UpdateDelveConfigPopup()
        end)
        local delayLabel = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        delayLabel:SetPoint("TOPLEFT", 18, -70)
        delayLabel:SetText("Entry delay (sec)")
        popup.delay = CreateFrame("EditBox", nil, popup, "InputBoxTemplate")
        popup.delay:SetSize(55, 22)
        popup.delay:SetPoint("LEFT", delayLabel, "RIGHT", 10, 0)
        popup.delay:SetAutoFocus(false)
        popup.delay:SetNumeric(true)
        popup.delay:SetScript("OnEnterPressed", function(self)
            local value = math.max(0, math.min(10, tonumber(self:GetText()) or 0))
            AutoGossip_Settings.autoDelveEnterDelayAcc = value
            self:ClearFocus()
            UpdateDelveConfigPopup()
        end)
        local exitDelayLabel = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        exitDelayLabel:SetPoint("TOPLEFT", 18, -100)
        exitDelayLabel:SetText("Exit delay (sec)")
        popup.exitDelay = CreateFrame("EditBox", nil, popup, "InputBoxTemplate")
        popup.exitDelay:SetSize(75, 22)
        popup.exitDelay:SetPoint("LEFT", exitDelayLabel, "RIGHT", 10, 0)
        popup.exitDelay:SetAutoFocus(false)
        popup.exitDelay:SetNumeric(true)
        popup.exitDelay:SetScript("OnEnterPressed", function(self)
            local value = math.max(0, math.min(300, tonumber(self:GetText()) or 300))
            AutoGossip_Settings.autoDelveExitDelayAcc = value
            self:ClearFocus()
            UpdateDelveConfigPopup()
        end)
        popup.allowNemesis = CreateFrame("CheckButton", nil, popup, "UICheckButtonTemplate")
        popup.allowNemesis:SetPoint("TOPLEFT", 12, -130)
        popup.allowNemesis.Text:SetText("Allow Nemesis Delves")
        popup.allowNemesis:SetScript("OnClick", function(self)
            ns.SetAutoDelveAllowNemesis(self:GetChecked() == true)
        end)
        local close = CreateFrame("Button", nil, popup, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -4, -4)
        popup:Hide()
        UpdateDelveConfigPopup()
        return popup
    end

    function ns.GetAutoDelveExitEnabled()
        InitSV()
        return AutoGossip_Settings and AutoGossip_Settings.autoDelveExitAcc == true
    end

    function ns.SetAutoDelveExitEnabled(enabled)
        InitSV()
        if AutoGossip_Settings then
            AutoGossip_Settings.autoDelveExitAcc = enabled == true
        end
    end

    function ns.GetAutoDelveAllowNemesis()
        InitSV()
        return AutoGossip_Settings and AutoGossip_Settings.autoDelveAllowNemesisAcc == true
    end

    function ns.SetAutoDelveAllowNemesis(enabled)
        InitSV()
        if AutoGossip_Settings then
            AutoGossip_Settings.autoDelveAllowNemesisAcc = enabled == true
        end
    end

    local BOUNTIFUL_POI_BY_MAP = {
        [2635] = 8760,
        [2633] = 8763,
    }
    local NEMESIS_MAPS = {
        [2634] = true,
    }

    local function GetCurrentDelveKind(mapID)
        local isNemesis = NEMESIS_MAPS[tonumber(mapID)] == true
        local isBountiful = false

        if C_DelvesUI and type(C_DelvesUI.GetDelveEntranceHeaderString) == "function" then
            local ok, header = pcall(C_DelvesUI.GetDelveEntranceHeaderString)
            header = ok and tostring(header or ""):lower() or ""
            isNemesis = isNemesis or header:find("nemesis", 1, true) ~= nil
            isBountiful = header:find("bountiful", 1, true) ~= nil
        end

        local bountifulPoi = BOUNTIFUL_POI_BY_MAP[tonumber(mapID)]
        if bountifulPoi and C_Map and C_AreaPoiInfo
            and type(C_Map.GetMapInfo) == "function"
            and type(C_AreaPoiInfo.GetDelvesForMap) == "function" then
            local ok, mapInfo = pcall(C_Map.GetMapInfo, mapID)
            local parentMapID = ok and mapInfo and tonumber(mapInfo.parentMapID) or nil
            if parentMapID then
                local listOK, pois = pcall(C_AreaPoiInfo.GetDelvesForMap, parentMapID)
                if listOK and type(pois) == "table" then
                    for _, poiID in ipairs(pois) do
                        if tonumber(poiID) == bountifulPoi then
                            isBountiful = true
                            break
                        end
                    end
                end
            end
        end

        return isBountiful, isNemesis
    end

    local function HandoffDelveAutoEnter(tier)
        if not ns.GetAutoDelveEnabled() then
            return
        end

        tier = tonumber(tier)
        if not tier or not (C_DelvesUI and type(C_DelvesUI.SelectDelveEntranceTier) == "function") then
            return
        end

        local highestTier = 0
        if type(GetCVarTableValue) == "function" and type(C_DelvesUI.GetTieredEntrancePDEID) == "function" then
            local ok, pdeID = pcall(C_DelvesUI.GetTieredEntrancePDEID)
            if ok and pdeID then
                local tierOK, value = pcall(GetCVarTableValue, "highestUnlockedTieredEntranceTier", pdeID, 0)
                highestTier = tierOK and tonumber(value) or 0
            end
        end
        if highestTier < tier then
            print("|cffff8000[FGO Delve]|r Auto Enter blocked: Tier " .. tostring(tier) .. " is not unlocked.")
            return
        end

        local isBountiful, isNemesis = GetCurrentDelveKind(GetCurrentDelveMapID())
        if isNemesis and not ns.GetAutoDelveAllowNemesis() then
            print("|cffff8000[FGO Delve]|r Auto Enter blocked: Nemesis Delves are disabled.")
            return
        end
        if isBountiful then
            local keyInfo = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(3028)
            local shardInfo = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(3310)
            local keys = tonumber(keyInfo and keyInfo.quantity) or 0
            local shards = tonumber(shardInfo and shardInfo.quantity) or 0
            if keys < 1 and shards < 100 then
                print("|cffff8000[FGO Delve]|r Auto Enter blocked: Bountiful Delve needs a key or 100 shards.")
                return
            end
        end

        local function EnterSelectedTier()
            selectedDelveTier = tier
            local ok = pcall(C_DelvesUI.SelectDelveEntranceTier, tier)
            if not ok then
                print("|cffff8000[FGO Delve]|r Auto Enter failed for Tier " .. tostring(tier) .. ".")
            end
        end
        local delay = math.max(0, math.min(10, tonumber(AutoGossip_Settings.autoDelveEnterDelayAcc) or 0))
        if delay > 0 and C_Timer and type(C_Timer.After) == "function" then
            C_Timer.After(delay, EnterSelectedTier)
        else
            EnterSelectedTier()
        end
    end

    local function GetCurrentInstanceID()
        if type(GetInstanceInfo) ~= "function" then
            return nil
        end
        local ok, _, _, _, _, _, _, instanceID = pcall(GetInstanceInfo)
        return ok and tonumber(instanceID) or nil
    end

    local function EnsureDelveState()
        local ui = GetUI()
        local inDelve, mapID = IsInDelve()
        if not inDelve or type(ui) ~= "table" then
            return nil, nil
        end

        local instanceID = GetCurrentInstanceID()
        if tonumber(ui.dundunReminderInstanceID) ~= instanceID then
            ui.dundunReminderInstanceID = instanceID
            ui.dundunReminderMapID = mapID
            ui.dundunReminderState = "notfound"
        elseif type(ui.dundunReminderState) ~= "string" then
            ui.dundunReminderMapID = mapID
            ui.dundunReminderState = "notfound"
        end
        ui.dundunReminderMapID = mapID
        return mapID, ui.dundunReminderState
    end

    local function ResetForInstanceEntry(isReload)
        if isReload then
            return
        end
        local ui = GetUI()
        local inDelve, mapID = IsInDelve()
        if type(ui) == "table" then
            ui.dundunReminderInstanceID = nil
            ui.dundunReminderMapID = nil
            ui.dundunReminderState = "notfound"
            if button and button._label then
                button._label:SetTextColor(1.0, 0.25, 0.25)
                button._label:SetText("DUNDUN")
            end
        end
    end

    local function ResetForTierSelection()
        local ui = GetUI()
        if type(ui) == "table" then
            ui.dundunReminderInstanceID = nil
            ui.dundunReminderMapID = nil
            ui.dundunReminderState = "notfound"
        end
    end

    local delveTierApplyPending = false
    local delveTierAppliedFrame = nil
    local delveTierAttemptedFrame = nil
    local delveTierWatchElapsed = 0
    local delveTierWasVisible = false
    local delveTierManualDebug = false
    local enteredDelveTierPrinted = false
    local selectedDelveTier

    local function DelveTierDebug(message)
        if delveTierManualDebug and AutoGame_Settings and AutoGame_Settings.valeera and AutoGame_Settings.valeera.debug then
            print("|cffff8000[fr0z3nUI Delve]|r " .. tostring(message))
        end
    end

    local function FormatDelveTierValues(values)
        local parts = {}
        for tier, value in pairs(values or {}) do
            parts[#parts + 1] = tostring(tier) .. "=" .. tostring(value)
        end
        table.sort(parts)
        return #parts > 0 and table.concat(parts, ", ") or "none"
    end

    local function GetClassColoredPlayerName()
        local name = UnitName and UnitName("player") or "Unknown"
        local classFile
        if UnitClass then
            local _, value = UnitClass("player")
            classFile = value
        end
        if classFile and C_ClassColor and type(C_ClassColor.GetClassColor) == "function" then
            local ok, color = pcall(C_ClassColor.GetClassColor, classFile)
            if ok and color and type(color.WrapTextInColorCode) == "function" then
                return color:WrapTextInColorCode(name)
            end
        end
        local colors = rawget(_G, "RAID_CLASS_COLORS")
        local color = colors and classFile and colors[classFile]
        if color and color.colorStr then
            return "|c" .. color.colorStr .. tostring(name) .. "|r"
        end
        return tostring(name)
    end

    local function PrintSelectedDelveTier(equippedItemLevel, tier, recommendedItemLevel, nextTierItemLevel)
        local nextTierValue = tonumber(nextTierItemLevel) or tonumber(recommendedItemLevel)
        local nextTierText = nextTierValue
            and tostring(math.floor(nextTierValue)) or "--"
        print("|cff00ccff[FGO]|r |cff00ccffDelve|r  Tier " .. tostring(tier)
            .. " (" .. tostring(math.floor(tonumber(recommendedItemLevel) or 0))
            .. ") set for " .. GetClassColoredPlayerName()
            .. " (" .. tostring(math.floor(tonumber(equippedItemLevel) or 0))
            .. "/" .. nextTierText .. ")")
    end

    local function GetDelveTierCache()
        local ui = GetUI()
        if type(ui) ~= "table" then
            return nil
        end
        ui.delveTierAuto = type(ui.delveTierAuto) == "table" and ui.delveTierAuto or {}
        local cache = ui.delveTierAuto
        local now = type(GetServerTime) == "function" and GetServerTime() or 0
        if cache.resetAt and now > 0 and now >= tonumber(cache.resetAt) then
            cache.requirements = nil
            cache.resetAt = nil
        end
        if not cache.resetAt and C_DateAndTime and type(C_DateAndTime.GetSecondsUntilWeeklyReset) == "function" and now > 0 then
            local ok, seconds = pcall(C_DateAndTime.GetSecondsUntilWeeklyReset)
            seconds = ok and tonumber(seconds) or nil
            if seconds and seconds > 0 then
                cache.resetAt = now + seconds
            end
        end
        return cache
    end

    local function GetDelveTierButtonTier(button)
        if type(button) ~= "table" then
            return nil
        end
        local tierInfo = type(button.tierInfo) == "table" and button.tierInfo
            or type(button.info) == "table" and button.info
            or type(button.data) == "table" and button.data
        local tier = tonumber(tierInfo and tierInfo.tier) or tonumber(button.tier or button.tierIndex or button.tierID or button.delveTier
            or button.difficultyTier or button.difficultyID or button.level)
        if tier and tier > 0 then
            return math.floor(tier)
        end
        local name = button.GetName and button:GetName() or ""
        tier = tonumber(tostring(name):match("[Tt]ier[_%s]*(%d+)"))
        if tier and tier > 0 then
            return tier
        end
        local text = button.GetText and button:GetText() or nil
        if type(text) ~= "string" and button.Text and button.Text.GetText then
            text = button.Text:GetText()
        end
        tier = tonumber(tostring(text or ""):match("[Tt]ier%s*(%d+)"))
        return tier and tier > 0 and tier or nil
    end

    local function GetDelveTierButtons(frame)
        local buttons = {}
        local seen = {}
        local function AddButton(button, tier)
            tier = tonumber(tier) or GetDelveTierButtonTier(button)
            local hasClick = button and ((button.GetScript and button:GetScript("OnClick")) or type(button.OnClick) == "function")
            if tier and tier > 0 and hasClick then
                buttons[math.floor(tier)] = button
            end
        end
        for _, field in ipairs({ "tierButtons", "TierButtons", "difficultyButtons", "DifficultyButtons" }) do
            local collection = frame and frame[field]
            if type(collection) == "table" then
                for index, button in pairs(collection) do
                    AddButton(button, index)
                end
            end
        end
        local function Scan(parent, depth)
            if not (parent and parent.GetChildren and depth > 0) then
                return
            end
            local children = { parent:GetChildren() }
            for _, child in ipairs(children) do
                if child and not seen[child] then
                    seen[child] = true
                    local tier = GetDelveTierButtonTier(child)
                    AddButton(child, tier)
                    Scan(child, depth - 1)
                end
            end
        end
        Scan(frame, 5)
        return buttons
    end

    local function ClickDelveTierButton(button)
        if button and type(button.Click) == "function" then
            return pcall(button.Click, button)
        end
        if button and type(button.OnClick) == "function" then
            return pcall(button.OnClick, button, "LeftButton")
        end
        if button and button.GetScript then
            local onClick = button:GetScript("OnClick")
            if type(onClick) == "function" then
                return pcall(onClick, button, "LeftButton")
            end
        end
        return false
    end

    local function GetDelveTierInfos(frame)
        if not frame then
            return nil
        end
        if type(frame.GetTierInfos) == "function" then
            local ok, tierInfos = pcall(frame.GetTierInfos, frame)
            if ok and type(tierInfos) == "table" then
                return tierInfos
            end
        end
        return type(frame.tierInfos) == "table" and frame.tierInfos or nil
    end

    local function FindDelveTierDropdown(frame)
        local dropdown
        local function Scan(parent, depth)
            if not (parent and parent.GetChildren and depth > 0) then
                return
            end
            local children = { parent:GetChildren() }
            for _, child in ipairs(children) do
                local text = child.GetText and child:GetText() or nil
                if type(text) == "string" and text:match("^[Tt]ier%s+%d+") then
                    local onMouseDown = child.GetScript and child:GetScript("OnMouseDown")
                    if type(onMouseDown) == "function" then
                        dropdown = child
                        return
                    end
                end
                Scan(child, depth - 1)
                if dropdown then
                    return
                end
            end
        end
        Scan(frame, 5)
        return dropdown
    end

    local function SetDelveTierDropdownText(frame, tierInfo)
        local dropdown = FindDelveTierDropdown(frame)
        local text = tierInfo and tierInfo.tierDescription
        if not (dropdown and type(text) == "string" and text ~= "") then
            return false
        end
        if type(dropdown.SetText) == "function" and pcall(dropdown.SetText, dropdown, text) then
            return true
        end
        if dropdown.Text and type(dropdown.Text.SetText) == "function" and pcall(dropdown.Text.SetText, dropdown.Text, text) then
            return true
        end
        return false
    end

    local function DumpDelveTierPicker(frame)
        if not frame then
            return
        end
        local fields = {}
        for key, value in pairs(frame) do
            if type(key) == "string" then
                local lower = key:lower()
                if lower:find("tier", 1, true) or lower:find("difficulty", 1, true) or lower:find("button", 1, true) then
                    fields[#fields + 1] = key .. "=" .. type(value)
                end
            end
        end
        table.sort(fields)
        print("|cffff8000[fr0z3nUI Delve]|r fields=" .. (#fields > 0 and table.concat(fields, ", ") or "none"))

        local children = { frame:GetChildren() }
        local details = {}
        for index, child in ipairs(children) do
            local name = child.GetName and child:GetName() or "(unnamed)"
            local id = child.GetID and child:GetID() or nil
            details[#details + 1] = tostring(index) .. ":" .. tostring(name) .. " id=" .. tostring(id)
            if child.GetChildren then
                local grandchildren = { child:GetChildren() }
                for childIndex, grandchild in ipairs(grandchildren) do
                    local childName = grandchild.GetName and grandchild:GetName() or "(unnamed)"
                    local childID = grandchild.GetID and grandchild:GetID() or nil
                    details[#details + 1] = "  " .. tostring(index) .. "." .. tostring(childIndex)
                        .. ":" .. tostring(childName) .. " id=" .. tostring(childID)
                end
            end
        end
        print("|cffff8000[fr0z3nUI Delve]|r children=" .. (#details > 0 and table.concat(details, " | ") or "none"))

        local clickable = {}
        local function ScanClickable(parent, path, depth)
            if not (parent and parent.GetChildren and depth > 0) then
                return
            end
            local children = { parent:GetChildren() }
            for index, child in ipairs(children) do
                local childPath = path .. "." .. tostring(index)
                local handlerNames = {}
                for _, handlerName in ipairs({ "OnClick", "OnMouseDown", "OnMouseUp", "OnMouseWheel" }) do
                    local handler = (child.GetScript and child:GetScript(handlerName))
                        or (handlerName == "OnClick" and child.OnClick)
                    if type(handler) == "function" then
                        handlerNames[#handlerNames + 1] = handlerName
                    end
                end
                if #handlerNames > 0 then
                    local tier = GetDelveTierButtonTier(child)
                    local info = type(child.tierInfo) == "table" and child.tierInfo or nil
                    local point, relativePoint, x, y
                    if child.GetPoint then
                        point, _, relativePoint, x, y = child:GetPoint(1)
                    end
                    local width = child.GetWidth and math.floor(child:GetWidth() or 0) or 0
                    local height = child.GetHeight and math.floor(child:GetHeight() or 0) or 0
                    local text = child.GetText and child:GetText() or ""
                    clickable[#clickable + 1] = childPath .. " tier=" .. tostring(tier)
                        .. " tierInfo=" .. tostring(info and info.tier)
                        .. " handlers=" .. table.concat(handlerNames, "+")
                        .. " point=" .. tostring(point) .. "/" .. tostring(relativePoint)
                        .. "@" .. tostring(x) .. "," .. tostring(y)
                        .. " size=" .. tostring(width) .. "x" .. tostring(height)
                        .. " text=" .. tostring(text)
                end
                ScanClickable(child, childPath, depth - 1)
            end
        end
        ScanClickable(frame, "root", 5)
        print("|cffff8000[fr0z3nUI Delve]|r clickable="
            .. (#clickable > 0 and table.concat(clickable, " | ") or "none"))

        local tierInfos = GetDelveTierInfos(frame)
        if type(tierInfos) ~= "table" then
            print("|cffff8000[fr0z3nUI Delve]|r tierInfos=none")
            return
        end
        for index, info in ipairs(tierInfos) do
            local values = {}
            if type(info) == "table" then
                for key, value in pairs(info) do
                    if type(key) == "string" and type(value) ~= "table" and type(value) ~= "function" then
                        values[#values + 1] = key .. "=" .. tostring(value)
                    elseif type(key) == "string" and type(value) == "table" then
                        values[#values + 1] = key .. "=table"
                    end
                end
            end
            table.sort(values)
            print("|cffff8000[fr0z3nUI Delve]|r tierInfo[" .. tostring(index) .. "]="
                .. (#values > 0 and table.concat(values, ", ") or tostring(info)))
        end
    end

    local function FindShownDelveTierFrame()
        for _, name in ipairs({ "DelvesDifficultyFrame", "DelvesDifficultyPickerFrame", "DelveDifficultyPickerFrame", "DelvesDashboardFrame" }) do
            local frame = _G and rawget(_G, name)
            if frame and frame.IsShown and frame:IsShown() then
                return frame
            end
        end
        return nil
    end

    local function GetTierRequirementFromTooltip(button)
        if not (button and button.GetScript and GameTooltip) then
            return nil
        end
        local onEnter = button:GetScript("OnEnter") or button.OnEnter
        if type(onEnter) ~= "function" then
            return nil
        end
        local ok = pcall(onEnter, button)
        if not ok or not GameTooltip:IsShown() then
            return nil
        end
        local tooltipName = GameTooltip.GetName and GameTooltip:GetName() or "GameTooltip"
        local requirement
        for index = 1, GameTooltip:NumLines() or 0 do
            local line = _G[tooltipName .. "TextLeft" .. index]
            local text = line and line.GetText and line:GetText()
            if type(text) == "string" then
                local lower = text:lower()
                requirement = tonumber(lower:match("item%s*level[^%d]*(%d+)"))
                    or tonumber(lower:match("recommended[^%d]*(%d+)"))
                if requirement and requirement > 0 then
                    break
                end
            end
        end
        local onLeave = button:GetScript("OnLeave") or button.OnLeave
        if type(onLeave) == "function" then
            pcall(onLeave, button)
        end
        GameTooltip:Hide()
        return requirement
    end

    local function GetDelveTierRequirements(buttons)
        local cache = GetDelveTierCache()
        if not cache then
            return nil
        end
        if type(cache.requirements) == "table" and next(cache.requirements) then
            return cache.requirements
        end
        local requirements = {}
        for tier, button in pairs(buttons) do
            local requirement = GetTierRequirementFromTooltip(button)
            if requirement then
                requirements[tier] = requirement
            end
        end
        if next(requirements) then
            cache.requirements = requirements
            return requirements
        end
        return nil
    end

    local function ApplyDelveTier(frame)
        if not (frame and frame.IsShown and frame:IsShown()) or delveTierAppliedFrame == frame then
            DelveTierDebug("skip: picker hidden or already applied")
            return true
        end
        if type(GetAverageItemLevel) ~= "function" then
            DelveTierDebug("skip: GetAverageItemLevel unavailable")
            return true
        end
        local ok, _, equippedItemLevel = pcall(GetAverageItemLevel)
        equippedItemLevel = ok and tonumber(equippedItemLevel) or nil
        if not equippedItemLevel or equippedItemLevel <= 0 then
            DelveTierDebug("wait: equipped item level unavailable")
            return false
        end
        local tierInfos = GetDelveTierInfos(frame)
        if type(tierInfos) == "table" then
            local targetInfo
            local targetTier
            for _, tierInfo in ipairs(tierInfos) do
                local tier = type(tierInfo) == "table" and tonumber(tierInfo.tier) or nil
                local suggestedItemLevel = type(tierInfo) == "table" and tonumber(tierInfo.suggestedILvl) or nil
                if tier and suggestedItemLevel and tierInfo.unlocked == true
                    and equippedItemLevel >= suggestedItemLevel and (not targetTier or tier > targetTier) then
                    targetInfo = tierInfo
                    targetTier = tier
                end
            end
            if not targetInfo then
                DelveTierDebug("skip: no unlocked native tier meets the item level")
                return false
            end
            local nextTierItemLevel
            for _, tierInfo in ipairs(tierInfos) do
                if type(tierInfo) == "table"
                    and tonumber(tierInfo.tier) == targetTier + 1 then
                    nextTierItemLevel = tonumber(tierInfo.suggestedILvl)
                    break
                end
            end
            local targetButton = GetDelveTierButtons(frame)[targetTier]
            if targetButton then
                local clicked = ClickDelveTierButton(targetButton)
                if clicked then
                    delveTierAppliedFrame = frame
                    HandoffDelveAutoEnter(targetTier)
                    PrintSelectedDelveTier(equippedItemLevel, targetTier,
                        targetInfo.suggestedILvl, nextTierItemLevel)
                    DelveTierDebug("clicked rendered tier control=" .. tostring(targetTier))
                    return true
                end
                DelveTierDebug("rendered tier control click failed for tier=" .. tostring(targetTier))
            end
            if type(frame.SetSelectedTierInfo) ~= "function" then
                DelveTierDebug("wait: no clickable rendered control for tier=" .. tostring(targetTier))
                return false
            end
            local selected = pcall(frame.SetSelectedTierInfo, frame, targetInfo)
            if selected and type(frame.SetupTiers) == "function" then
                selected = pcall(frame.SetupTiers, frame)
            end
            if selected and type(frame.SelectedTierInfoChanged) == "function" then
                selected = pcall(frame.SelectedTierInfoChanged, frame)
            end
            if selected and type(frame.SetupViewRewardButton) == "function" then
                pcall(frame.SetupViewRewardButton, frame)
            end
            if selected and type(frame.UpdatePortalButtonState) == "function" then
                pcall(frame.UpdatePortalButtonState, frame)
            end
            if selected then
                SetDelveTierDropdownText(frame, targetInfo)
                delveTierAppliedFrame = frame
                HandoffDelveAutoEnter(targetTier)
                PrintSelectedDelveTier(equippedItemLevel, targetTier,
                    targetInfo.suggestedILvl, nextTierItemLevel)
                DelveTierDebug("selected dropdown tier=" .. tostring(targetTier))
            end
            return selected
        end
        local buttons = GetDelveTierButtons(frame)
        local frameName = frame.GetName and frame:GetName() or "(unnamed)"
        DelveTierDebug("picker=" .. tostring(frameName) .. " ilvl=" .. tostring(equippedItemLevel)
            .. " buttons=" .. FormatDelveTierValues(buttons))
        local requirements = GetDelveTierRequirements(buttons)
        if not requirements then
            DelveTierDebug("wait: no tier tooltip requirements found")
            return false
        end
        DelveTierDebug("requirements=" .. FormatDelveTierValues(requirements))
        local targetTier
        for tier, requirement in pairs(requirements) do
            local button = buttons[tier]
            local enabled = not (button and button.IsEnabled) or button:IsEnabled()
            if button and enabled and equippedItemLevel >= requirement and (not targetTier or tier > targetTier) then
                targetTier = tier
            end
        end
        if not targetTier or not buttons[targetTier] or not buttons[targetTier].Click then
            DelveTierDebug("skip: no enabled tier meets the item level")
            return false
        end
        local selected = false
        for _, methodName in ipairs({ "SetSelectedTier", "SetTier", "SelectTier", "SetDifficultyTier" }) do
            local method = frame[methodName]
            if type(method) == "function" then
                local okSet = pcall(method, frame, targetTier)
                if okSet then
                    selected = true
                    DelveTierDebug("selected tier=" .. tostring(targetTier) .. " via " .. methodName)
                    break
                end
            end
        end
        if not selected then
            selected = pcall(buttons[targetTier].Click, buttons[targetTier])
            DelveTierDebug("selected tier=" .. tostring(targetTier) .. " via button click=" .. tostring(selected))
        end
        if selected and type(frame.Update) == "function" then
            pcall(frame.Update, frame)
        end
        if selected then
            delveTierAppliedFrame = frame
            HandoffDelveAutoEnter(targetTier)
            PrintSelectedDelveTier(equippedItemLevel, targetTier, requirements[targetTier],
                requirements[targetTier + 1])
        end
        return selected
    end

    local function ScheduleDelveTierApply(frame)
        local now = type(GetTime) == "function" and GetTime() or 0
        if delveExitCooldownUntil > now then
            if C_Timer and type(C_Timer.After) == "function" then
                C_Timer.After(delveExitCooldownUntil - now, function()
                    ScheduleDelveTierApply(frame)
                end)
            end
            return
        end
        if delveTierApplyPending or delveTierAppliedFrame == frame or delveTierAttemptedFrame == frame
            or not (C_Timer and C_Timer.After) then
            return
        end
        delveTierApplyPending = true
        local attempts = 0
        local function TryApply()
            attempts = attempts + 1
            if ApplyDelveTier(frame) or attempts >= 10 then
                if attempts >= 10 then
                    DelveTierDebug("gave up after 10 attempts")
                    delveTierAttemptedFrame = frame
                end
                delveTierApplyPending = false
            else
                C_Timer.After(0.1, TryApply)
            end
        end
        C_Timer.After(0, TryApply)
    end

    local tierSelectionFrames = {
        "DelvesDifficultyFrame",
        "DelvesDifficultyPickerFrame",
        "DelveDifficultyPickerFrame",
        "DelvesDashboardFrame",
    }

    local function HookTierSelectionFrame(name)
        local frame = _G and rawget(_G, name)
        if not (frame and frame.HookScript) then
            return false
        end
        if not frame.__FGO_DundunTierHooked then
            frame.__FGO_DundunTierHooked = true
            frame:HookScript("OnShow", function(self)
                ResetForTierSelection()
                delveTierWasVisible = true
                ScheduleDelveTierApply(self)
            end)
            frame:HookScript("OnHide", function(self)
                if delveTierAppliedFrame == self then
                    delveTierAppliedFrame = nil
                end
                if delveTierAttemptedFrame == self then
                    delveTierAttemptedFrame = nil
                end
            end)
        end
        if frame.IsShown and frame:IsShown() then
            ResetForTierSelection()
            delveTierWasVisible = true
            ScheduleDelveTierApply(frame)
        end
        return true
    end

    local function HookTierSelectionFrames()
        local hooked = false
        for _, name in ipairs(tierSelectionFrames) do
            if HookTierSelectionFrame(name) then
                hooked = true
            end
        end
        if not hooked and C_Timer and type(C_Timer.After) == "function" then
            C_Timer.After(1, HookTierSelectionFrames)
        end
    end

    local function IsDundunTarget()
        if not (UnitExists and UnitGUID and UnitExists("target")) then
            return false
        end

        if UnitName then
            local nameOK, name = pcall(UnitName, "target")
            if nameOK and type(name) == "string"
                and not (issecretvalue and issecretvalue(name))
                and name:lower() == "dundun" then
                return true
            end
        end

        local ok, guid = pcall(UnitGUID, "target")
        if not ok or type(guid) ~= "string" then
            return false
        end
        local guidOK, _, _, _, _, _, npcID = pcall(strsplit, "-", guid)
        return guidOK and DUNDUN_TARGET_NPC_IDS[tostring(npcID)] == true
    end

    local function ClearReminder()
        local ui = GetUI()
        if type(ui) == "table" then
            ui.dundunReminderMapID = nil
            ui.dundunReminderInstanceID = nil
        end
        if button and button.Hide then
            button:Hide()
        end
    end

    local function SetDelveState(state)
        local ui = GetUI()
        local mapID = EnsureDelveState()
        if type(ui) == "table" and mapID then
            ui.dundunReminderState = state
        end
    end

    local function GetDelveCooldownLabel()
        local now = type(GetTime) == "function" and GetTime() or 0
        if delveExitCooldownUntil <= now then
            return nil
        end
        local remaining = math.max(0, math.floor(delveExitCooldownUntil - now))
        local minutes = math.floor(remaining / 60)
        local seconds = remaining % 60
        return minutes > 0
            and (tostring(minutes) .. "m " .. tostring(seconds) .. "s")
            or (tostring(seconds) .. "s")
    end

    local function ApplyStateStyle(self, state)
        if not (self and self._label) then
            return
        end
        local fs = self._label
        if not (fs and fs.SetTextColor) then
            return
        end
        local cooldownText = GetDelveCooldownLabel()
        if cooldownText then
            fs:SetTextColor(1.0, 0.8, 0.1)
            fs:SetText("Delve Auto Entry\nCooldown: " .. cooldownText)
            return
        end
        if state == "interacted" then
            fs:SetTextColor(0.25, 1.0, 0.25)
            fs:SetText("DUNDUN")
        elseif state == "notfound" then
            fs:SetTextColor(1.0, 0.25, 0.25)
            fs:SetText("DUNDUN")
        else
            fs:SetTextColor(1.0, 0.65, 0.1)
            fs:SetText("DUNDUN")
        end
    end

    local function SavePosition(self)
        local ui = GetUI()
        if not (type(ui) == "table" and self and self.GetPoint) then
            return
        end
        local point, _, relativePoint, x, y = self:GetPoint(1)
        ui.dundunReminderFloatPos = {
            point = point,
            relativePoint = relativePoint,
            x = x,
            y = y,
        }
    end

    local function ApplyPosition(self)
        local ui = GetUI()
        local pos = type(ui) == "table" and ui.dundunReminderFloatPos or nil
        self:ClearAllPoints()
        self:SetPoint(
            type(pos) == "table" and pos.point or "TOP",
            UIParent,
            type(pos) == "table" and pos.relativePoint or "TOP",
            type(pos) == "table" and tonumber(pos.x) or 0,
            type(pos) == "table" and tonumber(pos.y) or -140
        )
    end

    local function EnsureButton()
        if button then
            return button
        end
        if not (CreateFrame and UIParent) then
            return nil
        end

        button = CreateFrame("Button", "FGO_FloatingDundunReminderButton", UIParent, "SecureActionButtonTemplate")
        button:SetSize(190, 38)
        button:SetClampedToScreen(true)
        button:SetFrameStrata("DIALOG")
        button:SetMovable(true)
        button:EnableMouse(true)
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        button:RegisterForDrag("RightButton")
        local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetAllPoints(button)
        label:SetJustifyH("CENTER")
        label:SetJustifyV("MIDDLE")
        local fontPath, _, fontFlags = label:GetFont()
        if fontPath then
            label:SetFont(fontPath, 18, fontFlags)
        end
        button._label = label
        if button.SetAttribute then
            button:SetAttribute("type", "macro")
            button:SetAttribute("macrotext", "/cleartarget\n/target Dundun\n/focus [@target,exists]\n/ping [@target,exists] assist\n/cleartarget")
            button:SetAttribute("shift-leftbutton-type", "macro")
            button:SetAttribute("shift-leftbutton-macrotext", "/vap use Default")
        end
        ApplyPosition(button)

        button:SetScript("PostClick", function(self, mouseButton)
            local now = type(GetTime) == "function" and GetTime() or 0
            if delveExitCooldownUntil > now then
                delveExitCooldownUntil = 0
                local _, state = EnsureDelveState()
                ApplyStateStyle(self, state)
                return
            end
            local inDelve, mapID = IsInDelve()
            if not inDelve or not mapID then
                return
            end
            if mouseButton == "RightButton" then
                local _, state = EnsureDelveState()
                local nextState = state == "found" and "notfound" or "found"
                SetDelveState(nextState)
                ApplyStateStyle(self, nextState)
                return
            end
            if not IsDundunTarget() then
                return
            end
            SetDelveState("found")
            ApplyStateStyle(self, "found")
        end)

        button:SetScript("OnDragStart", function(self)
            if not (IsShiftKeyDown and IsShiftKeyDown()) then
                return
            end
            self._fgoDundunDragging = true
            self:StartMoving()
        end)
        button:SetScript("OnDragStop", function(self)
            if not self._fgoDundunDragging then
                return
            end
            self._fgoDundunDragging = nil
            self:StopMovingOrSizing()
            SavePosition(self)
        end)
        button:SetScript("OnEnter", function(self)
            if GameTooltip then
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(" Click to Target Dundun")
                GameTooltip:AddLine("     or Clear Cooldown", 1, 1, 1, true)
                GameTooltip:AddLine("Right-click: Toggles Found", 1, 1, 1, true)
                GameTooltip:AddLine("       +Shift: Drag to Move", 1, 1, 1, true)
                GameTooltip:Show()
            end
        end)
        button:SetScript("OnLeave", function()
            if GameTooltip then GameTooltip:Hide() end
        end)
        return button
    end

    local function UpdateReminder()
        local inDelve, mapID = IsInDelve()
        local activeDelve = HasActiveDelveInstance()
        local _, state = EnsureDelveState()
        if not inDelve or (not activeDelve and state ~= "interacted") then
            if GetDelveCooldownLabel() then
                local b = EnsureButton()
                if b then
                    ApplyPosition(b)
                    ApplyStateStyle(b, "notfound")
                    b:Show()
                end
                return
            end
            ClearReminder()
            return
        end

        local b = EnsureButton()
        if b and mapID then
            ApplyPosition(b)
            ApplyStateStyle(b, state)
            b:Show()
        elseif b then
            b:Hide()
        end
    end

    function ns.ClearDelveAutoEnterCooldown()
        delveExitCooldownUntil = 0
        UpdateReminder()
        return true
    end

    local function MarkDundunInteracted()
        local inDelve = IsInDelve()
        if not inDelve then
            return
        end

        local interacted = IsDundunTarget()
        if not interacted and ns and type(ns.GetCurrentNpcID) == "function" then
            local ok, npcID = pcall(ns.GetCurrentNpcID)
            interacted = ok and tonumber(npcID) == 251601
        end

        if interacted then
            SetDelveState("interacted")
            UpdateReminder()
        end
    end

    function ns.Dundun_OnGossipInteraction(npcID, optionID)
        if not DUNDUN_GOSSIP_OPTIONS[tonumber(optionID)] then
            return
        end
        if not IsInDelve() then
            return
        end
        SetDelveState("interacted")
        UpdateReminder()
    end

    local function GetDetectedDelveTier()
        local function ParseTier(value)
            local tier = tonumber(tostring(value or ""):match("[Tt]ier[^%d]*(%d+)"))
            return tier and tier >= 1 and tier <= 11 and math.floor(tier) or nil
        end

        if C_DelvesUI and type(C_DelvesUI.GetActiveDelveTier) == "function" then
            local ok, info = pcall(C_DelvesUI.GetActiveDelveTier)
            local tier = ok and type(info) == "table" and tonumber(info.tier) or nil
            DelveTierDebug("activeTier ok=" .. tostring(ok) .. " type=" .. type(info)
                .. " tier=" .. tostring(tier))
            if tier and tier >= 1 and tier <= 11 then
                return math.floor(tier)
            end
        end

        if type(GetInstanceInfo) == "function" then
            local ok, _, _, _, difficultyName = pcall(GetInstanceInfo)
            DelveTierDebug("difficulty ok=" .. tostring(ok) .. " value=" .. tostring(difficultyName))
            if ok then
                local tier = ParseTier(difficultyName)
                if tier then return tier end
            end
        end

        if C_Scenario then
            if type(C_Scenario.GetInfo) == "function" then
                local ok, value = pcall(C_Scenario.GetInfo)
                DelveTierDebug("scenarioInfo ok=" .. tostring(ok) .. " value=" .. tostring(value))
                local tier = ok and ParseTier(value) or nil
                if tier then return tier end
            end
            if type(C_Scenario.GetStepInfo) == "function" then
                local ok, value = pcall(C_Scenario.GetStepInfo)
                DelveTierDebug("scenarioStep ok=" .. tostring(ok) .. " value=" .. tostring(value))
                local tier = ok and ParseTier(value) or nil
                if tier then return tier end
            end
        end

        if C_ScenarioInfo and type(C_ScenarioInfo.GetScenarioStepInfo) == "function"
            and C_UIWidgetManager and type(C_UIWidgetManager.GetAllWidgetsBySetID) == "function"
            and Enum and Enum.UIWidgetVisualizationType
            and Enum.UIWidgetVisualizationType.ScenarioHeaderDelves
            and type(C_UIWidgetManager.GetScenarioHeaderDelvesWidgetVisualizationInfo) == "function" then
            local stepOK, stepInfo = pcall(C_ScenarioInfo.GetScenarioStepInfo)
            local widgetSetID = stepOK and type(stepInfo) == "table" and stepInfo.widgetSetID or nil
            if widgetSetID then
                local widgetsOK, widgets = pcall(C_UIWidgetManager.GetAllWidgetsBySetID, widgetSetID)
                if widgetsOK and type(widgets) == "table" then
                    for _, widget in ipairs(widgets) do
                        if widget.widgetType == Enum.UIWidgetVisualizationType.ScenarioHeaderDelves then
                            local infoOK, info = pcall(
                                C_UIWidgetManager.GetScenarioHeaderDelvesWidgetVisualizationInfo,
                                widget.widgetID)
                            local tier = infoOK and info and tonumber(info.tierText) or nil
                            DelveTierDebug("scenario header tier=" .. tostring(tier))
                            if tier and tier >= 1 and tier <= 11 then
                                return math.floor(tier)
                            end
                        end
                    end
                end
            end
        end

        local tracker = _G["ObjectiveTrackerFrame"] or _G["ScenarioObjectiveTracker"]
        DelveTierDebug("tracker=" .. tostring(tracker ~= nil))
        if tracker then
            local foundDelveHeader = false
            local zoneName = type(GetRealZoneText) == "function" and GetRealZoneText() or ""
            local foundTier

            local function SearchTracker(frame)
                if foundTier or not frame then return end
                if frame.IsForbidden and frame:IsForbidden() then return end

                if frame.GetRegions and frame.GetNumRegions then
                    local regions = { frame:GetRegions() }
                    for _, region in ipairs(regions) do
                        if region and region.GetObjectType and region:GetObjectType() == "FontString"
                            and (not region.IsShown or region:IsShown()) then
                            local text = region.GetText and region:GetText() or ""
                            text = tostring(text or "")
                                :gsub("|c%x%x%x%x%x%x%x%x", "")
                                :gsub("|r", "")
                            local explicit = text:match("[Tt]ier%s*:?%s*(%d+)")
                                or text:match("[Dd]ifficulty%s*:?%s*(%d+)")
                            local value = tonumber(explicit)
                            if value and value >= 1 and value <= 11 then
                                foundTier = math.floor(value)
                                return
                            end
                            if text == "Delves" or text == zoneName then
                                foundDelveHeader = true
                            elseif foundDelveHeader and text:match("^%d+$") then
                                value = tonumber(text)
                                if value and value >= 1 and value <= 11 then
                                    foundTier = math.floor(value)
                                    return
                                end
                            end
                        end
                    end
                end

                if frame.GetChildren and frame.GetNumChildren then
                    local children = { frame:GetChildren() }
                    for _, child in ipairs(children) do
                        SearchTracker(child)
                        if foundTier then return end
                    end
                end
            end

            pcall(SearchTracker, tracker)
            if foundTier then
                return foundTier
            end
        end

        return nil
    end

    local function PrintEnteredDelveTier(attempt)
        if enteredDelveTierPrinted then
            return
        end
        local inDelve, mapID = IsInDelve()
        local detectedTier = GetDetectedDelveTier()
        DelveTierDebug("entry attempt=" .. tostring(attempt or 1)
            .. " inDelve=" .. tostring(inDelve)
            .. " map=" .. tostring(mapID)
            .. " detected=" .. tostring(detectedTier)
            .. " selected=" .. tostring(selectedDelveTier))
        if not IsInDelve() then
            if (tonumber(attempt) or 1) < 10 and C_Timer and type(C_Timer.After) == "function" then
                C_Timer.After(0.5, function()
                    PrintEnteredDelveTier((tonumber(attempt) or 1) + 1)
                end)
            end
            return
        end
        local tier = detectedTier
        if not tier or AutoGossip_Settings.autoDelvePrintTierAcc == false then
            if (tonumber(attempt) or 1) < 10 and C_Timer and type(C_Timer.After) == "function" then
                C_Timer.After(0.5, function()
                    PrintEnteredDelveTier((tonumber(attempt) or 1) + 1)
                end)
            end
            return
        end
        enteredDelveTierPrinted = true
        print("|cff00ccff[FGO]|r |cff00ccffDelve|r  Tier " .. tostring(tier) .. " Entered")
    end

    local zygorDelveViewerHidden = false
    local zygorAutoHideEnabled = true
    local function UpdateZygorDelveViewer()
        local zygor = rawget(_G, "ZGV")
        local profile = zygor and zygor.db and zygor.db.profile
        local frame = zygor and zygor.Frame
        if type(profile) ~= "table" or not (frame and type(zygor.ToggleFrame) == "function") then
            return
        end

        if not zygorAutoHideEnabled then
            if zygorDelveViewerHidden and frame.IsVisible and not frame:IsVisible() then
                zygor:ToggleFrame()
            end
            zygorDelveViewerHidden = false
            return
        end

        local activeDelve = IsInsideDelveInstance()
        local activePetBattle = IsInPetBattle()
        if activeDelve or activePetBattle then
            if profile.zgvhideindungeons == true and frame.IsVisible and frame:IsVisible() then
                zygor:ToggleFrame()
                zygorDelveViewerHidden = true
            end
            return
        end

        if zygorDelveViewerHidden then
            if profile.showafterdungeons ~= false and frame.IsVisible and not frame:IsVisible() then
                zygor:ToggleFrame()
            end
            zygorDelveViewerHidden = false
        end
    end

    function ns.ZygorViewerHide()
        local zygor = rawget(_G, "ZGV")
        if zygor and zygor.Frame and zygor.Frame.IsVisible
            and zygor.Frame:IsVisible() and type(zygor.ToggleFrame) == "function" then
            zygor:ToggleFrame()
            return true
        end
        return false
    end

    function ns.ZygorViewerShow()
        local zygor = rawget(_G, "ZGV")
        if zygor and zygor.Frame and zygor.Frame.IsVisible
            and not zygor.Frame:IsVisible() and type(zygor.ToggleFrame) == "function" then
            zygor:ToggleFrame()
            return true
        end
        return false
    end

    function ns.SetZygorAutoHideEnabled(enabled)
        zygorAutoHideEnabled = enabled == true
        UpdateZygorDelveViewer()
        return zygorAutoHideEnabled
    end

    local eventFrame = CreateFrame("Frame")
    HookAutoDelveExitPopup()
    HookTierSelectionFrames()
    eventFrame:RegisterEvent("PLAYER_LOGIN")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("LOADING_SCREEN_DISABLED")
    eventFrame:RegisterEvent("PET_BATTLE_OPENING_START")
    eventFrame:RegisterEvent("PET_BATTLE_OPENING_DONE")
    eventFrame:RegisterEvent("PET_BATTLE_CLOSE")
    eventFrame:RegisterEvent("SCENARIO_UPDATE")
    eventFrame:RegisterEvent("SCENARIO_CRITERIA_UPDATE")
    eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    eventFrame:RegisterEvent("VIGNETTE_MINIMAP_UPDATED")
    eventFrame:RegisterEvent("GOSSIP_SHOW")
    eventFrame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
    eventFrame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")
    eventFrame:SetScript("OnEvent", function(_, event, text, isReload)
        if event == "PLAYER_LOGIN" then
            HookTierSelectionFrames()
            UpdateReminder()
            C_Timer.After(0.5, UpdateZygorDelveViewer)
        elseif event == "PLAYER_ENTERING_WORLD" then
            ResetForInstanceEntry(isReload)
            TrackDelveStateTransition()
            if HasActiveDelveInstance() then
                delveExitCooldownUntil = 0
            end
            enteredDelveTierPrinted = false
            selectedDelveTier = nil
            UpdateReminder()
            C_Timer.After(0.5, UpdateZygorDelveViewer)
            if C_Timer and type(C_Timer.After) == "function" then
                C_Timer.After(1, PrintEnteredDelveTier)
            end
        elseif event == "LOADING_SCREEN_DISABLED" then
            C_Timer.After(0.5, UpdateZygorDelveViewer)
        elseif event == "PET_BATTLE_OPENING_START"
            or event == "PET_BATTLE_OPENING_DONE"
            or event == "PET_BATTLE_CLOSE" then
            C_Timer.After(0.5, UpdateZygorDelveViewer)
        elseif event == "SCENARIO_UPDATE" or event == "SCENARIO_CRITERIA_UPDATE" then
            TrackDelveStateTransition()
            if HasActiveDelveInstance() then
                delveExitCooldownUntil = 0
            end
            C_Timer.After(0.5, UpdateZygorDelveViewer)
            if not enteredDelveTierPrinted and C_Timer and type(C_Timer.After) == "function" then
                C_Timer.After(0.25, PrintEnteredDelveTier)
            end
        elseif event == "ZONE_CHANGED_NEW_AREA" then
            TrackDelveStateTransition()
            UpdateReminder()
        elseif event == "PLAYER_TARGET_CHANGED" and IsDundunTarget() then
            SetDelveState("found")
            if button then
                ApplyStateStyle(button, "found")
            end
        elseif event == "GOSSIP_SHOW"
            or event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW"
            or event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
            MarkDundunInteracted()
            HookTierSelectionFrames()
            local tierFrame = FindShownDelveTierFrame()
            if tierFrame then
                ScheduleDelveTierApply(tierFrame)
            end
        else
            UpdateReminder()
        end
    end)
    eventFrame:SetScript("OnUpdate", function(_, elapsed)
        delveTierWatchElapsed = delveTierWatchElapsed + (tonumber(elapsed) or 0)
        if delveTierWatchElapsed < 0.25 then
            return
        end
        delveTierWatchElapsed = 0
        UpdateZygorDelveViewer()
        if button and button.IsShown and button:IsShown() then
            local inDelve = IsInDelve()
            if not inDelve and not GetDelveCooldownLabel() then
                button:Hide()
            else
                local _, state = EnsureDelveState()
                ApplyStateStyle(button, state)
            end
        end
        local tierFrame = FindShownDelveTierFrame()
        if tierFrame then
            delveTierWasVisible = true
            ScheduleDelveTierApply(tierFrame)
        else
            delveTierWasVisible = false
            delveTierAttemptedFrame = nil
        end
    end)

    SLASH_FGODELVE1 = "/fgodelve"
    SlashCmdList.FGODELVE = function(message)
        InitSV()
        AutoGame_Settings.valeera = AutoGame_Settings.valeera or {}
        local command = string.lower(string.gsub(tostring(message or ""), "^%s*(.-)%s*$", "%1"))
        if command == "off" then
            AutoGame_Settings.valeera.debug = false
            delveTierManualDebug = false
            print("|cffff8000[fr0z3nUI Delve]|r diagnostic disabled")
            return
        end
        if command ~= "on" then
            print("|cffff8000[fr0z3nUI Delve]|r use /fgodelve on or /fgodelve off")
            return
        end
        AutoGame_Settings.valeera.debug = true
        print("|cffff8000[fr0z3nUI Delve]|r diagnostic enabled")
        HookTierSelectionFrames()
        delveTierManualDebug = true
    end
end




