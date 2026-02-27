---@diagnostic disable: undefined-global

local addonName, ns = ...
if type(ns) ~= "table" then
    ns = {}
end

-- ============================================================================
-- Floating Reload UI button (text-only, draggable)
-- ============================================================================

do
    local btn

    local function InitSV()
        if ns and type(ns._InitSV) == "function" then
            ns._InitSV()
        end
    end

    local function GetUI()
        InitSV()
        return rawget(_G, "AutoGame_UI") or rawget(_G, "AutoGossip_UI")
    end

    local function IsEnabled()
        local ui = GetUI()
        if not ui then
            return false
        end
        return (ui.reloadFloatEnabled and true or false)
    end

    local function ApplySavedPosition(frame)
        local ui = GetUI()
        if not (ui and type(ui.reloadFloatPos) == "table" and frame and frame.SetPoint) then
            return
        end

        local p = ui.reloadFloatPos
        local point = type(p.point) == "string" and p.point or "TOP"
        local relPoint = type(p.relativePoint) == "string" and p.relativePoint or point
        local x = tonumber(p.x) or 0
        local y = tonumber(p.y) or -120

        frame:ClearAllPoints()
        frame:SetPoint(point, UIParent, relPoint, x, y)
    end

    function ns.EnsureReloadFloatButton()
        if btn and btn.SetText then
            return btn
        end

        if not (CreateFrame and UIParent) then
            return nil
        end

        btn = CreateFrame("Button", "FGO_FloatingReloadUIButton", UIParent)
        btn:SetSize(90, 18)
        btn:SetClampedToScreen(true)
        btn:SetFrameStrata("DIALOG")
        btn:EnableMouse(true)
        btn:SetMovable(true)
        btn:RegisterForDrag("RightButton")

        local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetAllPoints(btn)
        fs:SetJustifyH("CENTER")
        fs:SetJustifyV("MIDDLE")
        fs:SetText("|cff00ccffReload UI|r")
        btn._label = fs

        ApplySavedPosition(btn)

        btn:SetScript("OnClick", function()
            local r = _G and _G["ReloadUI"]
            if type(r) == "function" then
                r()
            end
        end)
        btn:SetScript("OnDragStart", function(self)
            if self and self.StartMoving then
                self:StartMoving()
            end
        end)
        btn:SetScript("OnDragStop", function(self)
            if self and self.StopMovingOrSizing then
                self:StopMovingOrSizing()
            end

            local ui = GetUI()
            if not ui then
                return
            end
            ui.reloadFloatPos = ui.reloadFloatPos or {}
            local point, _, relPoint, x, y = self:GetPoint(1)
            ui.reloadFloatPos.point = point
            ui.reloadFloatPos.relativePoint = relPoint
            ui.reloadFloatPos.x = x
            ui.reloadFloatPos.y = y
        end)

        btn:SetScript("OnEnter", function(self)
            if self and self._label and self._label.SetText then
                self._label:SetText("|cffffff00Reload UI|r")
            end
            if GameTooltip then
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText("Reload UI")
                GameTooltip:AddLine("Left-click: reload", 1, 1, 1, true)
                GameTooltip:AddLine("Right-drag: move", 1, 1, 1, true)
                GameTooltip:Show()
            end
        end)
        btn:SetScript("OnLeave", function(self)
            if self and self._label and self._label.SetText then
                self._label:SetText("|cff00ccffReload UI|r")
            end
            if GameTooltip then
                GameTooltip:Hide()
            end
        end)

        return btn
    end

    function ns.UpdateReloadFloatButton()
        InitSV()
        if IsEnabled() then
            local b = ns.EnsureReloadFloatButton()
            if b and b.Show then
                ApplySavedPosition(b)
                b:Show()
            end
        else
            if btn and btn.Hide then
                btn:Hide()
            end
        end
    end

    local function OnEvent(_, event)
        if event == "PLAYER_LOGIN" or event == "VARIABLES_LOADED" then
            ns.UpdateReloadFloatButton()
        end
    end

    local f = _G.CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:RegisterEvent("VARIABLES_LOADED")
    f:SetScript("OnEvent", OnEvent)
end

-- Switches module
-- Consolidates:
-- - fr0z3nUI_GameOptionsTutorial.lua
-- - fr0z3nUI_GameOptionsSwitchTooltip.lua
-- - fr0z3nUI_GameOptionsSwitchTooltipX.lua

-- ============================================================================
-- Tooltip Border (formerly SwitchTooltip)
-- ============================================================================

do
    local didInit = false

    local function InitSV()
        if ns and type(ns._InitSV) == "function" then
            ns._InitSV()
        end
    end

    local function GetSettings()
        InitSV()
        local acc = rawget(_G, "AutoGame_Settings") or rawget(_G, "AutoGossip_Settings")
        if type(acc) ~= "table" then
            return nil
        end
        return acc
    end

    local function IsHideEnabled()
        local acc = GetSettings()
        if not acc then
            return true
        end
        if type(acc.hideTooltipBorderAcc) ~= "boolean" then
            return true
        end
        return acc.hideTooltipBorderAcc
    end

    local function ApplyBorderState(tooltip)
        local nineSlice = tooltip and tooltip.NineSlice
        if not nineSlice then
            return
        end

        local hide = IsHideEnabled()

        -- When disabled, do not force any "show" state; leave Blizzard/default styling alone.
        if not hide then
            return
        end

        for _, regionName in ipairs({
            "TopEdge", "BottomEdge", "LeftEdge", "RightEdge",
            "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
        }) do
            local region = nineSlice[regionName]
            if region and region.SetAlpha then
                if region.__FGO_OrigAlpha == nil and region.GetAlpha then
                    region.__FGO_OrigAlpha = region:GetAlpha()
                end
                region:SetAlpha(0)
            end
        end
    end

    local function HookTooltipByName(globalName)
        local tt = _G and _G[globalName]
        if not (tt and tt.HookScript) then
            return
        end

        if tt.__FGO_TooltipBorderHooked then
            ApplyBorderState(tt)
            return
        end

        tt.__FGO_TooltipBorderHooked = true
        ApplyBorderState(tt)
        tt:HookScript("OnShow", ApplyBorderState)
    end

    local function HookAllKnownTooltips()
        for _, name in ipairs({
            "GameTooltip",
            "ItemRefTooltip",
            "ShoppingTooltip1",
            "ShoppingTooltip2",
            "ShoppingTooltip3",
            "WorldMapTooltip",
            "BattlePetTooltip",
            "FloatingBattlePetTooltip",
            "FloatingPetBattleAbilityTooltip",
            "EmbeddedItemTooltip",
        }) do
            HookTooltipByName(name)
        end
    end

    local function HookTooltipDataProcessor()
        if not (TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall) then
            return
        end
        if TooltipDataProcessor.__FGO_TooltipBorderHooked then
            return
        end
        TooltipDataProcessor.__FGO_TooltipBorderHooked = true

        if type(Enum) == "table" and type(Enum.TooltipDataType) == "table" then
            for _, tooltipDataType in pairs(Enum.TooltipDataType) do
                if type(tooltipDataType) == "number" then
                    TooltipDataProcessor.AddTooltipPostCall(tooltipDataType, ApplyBorderState)
                end
            end
        end
    end

    local function HookBackdropStyleFunctions()
        if not (_G and _G.hooksecurefunc) then
            return
        end
        if _G.__FGO_TooltipBorderBackdropHooked then
            return
        end
        _G.__FGO_TooltipBorderBackdropHooked = true

        local sharedSetBackdropStyle = _G and rawget(_G, "SharedTooltip_SetBackdropStyle")
        if type(sharedSetBackdropStyle) == "function" then
            _G.hooksecurefunc("SharedTooltip_SetBackdropStyle", function(tooltip)
                ApplyBorderState(tooltip)
            end)
        end

        local gameTooltipSetBackdropStyle = _G and rawget(_G, "GameTooltip_SetBackdropStyle")
        if type(gameTooltipSetBackdropStyle) == "function" then
            _G.hooksecurefunc("GameTooltip_SetBackdropStyle", function(tooltip)
                ApplyBorderState(tooltip)
            end)
        end
    end

    local function InitOnce()
        if didInit then
            return
        end
        didInit = true

        HookTooltipDataProcessor()
        HookBackdropStyleFunctions()
        HookAllKnownTooltips()
    end

    function ns.ApplyTooltipBorderSetting(force)
        InitOnce()

        -- Re-apply to existing tooltips immediately.
        if force then
            HookAllKnownTooltips()
        end
    end

    local function OnEvent(_, event, arg1)
        if event == "ADDON_LOADED" and arg1 == addonName then
            -- Initialize default if needed.
            if type(_G.AutoGossip_Settings) == "table" and type(_G.AutoGossip_Settings.hideTooltipBorderAcc) ~= "boolean" then
                _G.AutoGossip_Settings.hideTooltipBorderAcc = true
            end
            return
        end

        if event == "PLAYER_LOGIN" or event == "VARIABLES_LOADED" then
            InitOnce()
            ns.ApplyTooltipBorderSetting(true)
        end
    end

    local f = _G.CreateFrame("Frame")
    f:RegisterEvent("ADDON_LOADED")
    f:RegisterEvent("PLAYER_LOGIN")
    f:RegisterEvent("VARIABLES_LOADED")
    f:SetScript("OnEvent", OnEvent)
end

-- ============================================================================
-- TooltipX (formerly SwitchTooltipX)
-- ============================================================================

do
    local didInit = false
    local lastDebugAt = 0
    local lastDebugKey = nil

    local function GetSettings()
        if ns and type(ns._InitSV) == "function" then
            ns._InitSV()
        end
        local s = rawget(_G, "AutoGame_Settings") or rawget(_G, "AutoGossip_Settings")
        if type(s) ~= "table" then
            return nil
        end
        return s
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

    local function GetStringSetting(key, defaultValue)
        local s = GetSettings()
        if not s then
            return defaultValue
        end
        local v = s[key]
        if type(v) ~= "string" or v == "" then
            return defaultValue
        end
        return v
    end

    local function NormalizeModifier(mod)
        mod = (mod or ""):upper()
        if mod == "CTRL" or mod == "CONTROL" then return "CTRL" end
        if mod == "ALT" then return "ALT" end
        if mod == "SHIFT" then return "SHIFT" end
        if mod == "NONE" or mod == "OFF" then return "NONE" end
        return "CTRL"
    end

    local function IsModifierDown()
        local mod = NormalizeModifier(GetStringSetting("tooltipXCombatModifierAcc", "CTRL"))
        if mod == "NONE" then
            return false
        end
        if mod == "ALT" then
            return IsAltKeyDown and IsAltKeyDown() or false
        elseif mod == "SHIFT" then
            return IsShiftKeyDown and IsShiftKeyDown() or false
        else
            return IsControlKeyDown and IsControlKeyDown() or false
        end
    end

    local function InCombat()
        if InCombatLockdown and InCombatLockdown() then
            return true
        end
        if UnitAffectingCombat then
            return UnitAffectingCombat("player") and true or false
        end
        return false
    end

    local function DebugLog(key, msg)
        if not GetBoolSetting("tooltipXDebugAcc", false) then
            return
        end
        local now = (GetTime and GetTime()) or 0
        if key and lastDebugKey == key and (now - (lastDebugAt or 0)) < 0.35 then
            return
        end
        if (now - (lastDebugAt or 0)) < 0.12 then
            return
        end
        lastDebugAt = now
        lastDebugKey = key
        print("|cff00ccff[FGO]|r TooltipX: " .. tostring(msg))
    end

    local function TooltipGetUnitToken(tooltip)
        if not (tooltip and tooltip.GetUnit) then
            return nil
        end
        local ok, _, unit = pcall(tooltip.GetUnit, tooltip)
        if not ok then
            return nil
        end
        if type(unit) ~= "string" or unit == "" then
            return nil
        end
        return unit
    end

    local function ShouldHideTooltipNow(tooltip)
        if not GetBoolSetting("tooltipXCombatHideAcc", false) then
            return false
        end

        if not InCombat() then
            return false
        end

        if IsModifierDown() then
            return false
        end

        local unit = TooltipGetUnitToken(tooltip)
        if unit then
            if GetBoolSetting("tooltipXCombatShowTargetAcc", true) and UnitIsUnit and UnitIsUnit(unit, "target") then
                return false
            end
            if GetBoolSetting("tooltipXCombatShowFocusAcc", false) and UnitIsUnit and UnitIsUnit(unit, "focus") then
                return false
            end
            if GetBoolSetting("tooltipXCombatShowMouseoverAcc", true) and UnitIsUnit and UnitIsUnit(unit, "mouseover") then
                return false
            end
            if GetBoolSetting("tooltipXCombatShowFriendlyPlayersAcc", false) and UnitIsPlayer and UnitIsFriend then
                if UnitIsPlayer(unit) and UnitIsFriend("player", unit) then
                    return false
                end
            end
        end

        return true
    end

    local function RestoreTooltipAlpha(tooltip)
        if not (tooltip and tooltip.SetAlpha) then return end

        if tooltip.__FGO_TooltipX_OrigAlpha ~= nil then
            tooltip:SetAlpha(tooltip.__FGO_TooltipX_OrigAlpha)
        end
        tooltip.__FGO_TooltipX_ForcedHidden = nil
    end

    local function ForceHideTooltip(tooltip)
        if not (tooltip and tooltip.SetAlpha and tooltip.GetAlpha) then return end

        if tooltip.__FGO_TooltipX_OrigAlpha == nil then
            local ok, a = pcall(tooltip.GetAlpha, tooltip)
            if ok then
                tooltip.__FGO_TooltipX_OrigAlpha = a
            else
                tooltip.__FGO_TooltipX_OrigAlpha = 1
            end
        end

        tooltip.__FGO_TooltipX_ForcedHidden = true
        tooltip:SetAlpha(0)
    end

    local function StripColorCodes(text)
        if type(text) ~= "string" then return nil end
        text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
        text = text:gsub("|r", "")
        return text
    end

    local function RestoreHiddenTooltipLines(tooltip)
        if not (tooltip and tooltip.NumLines and tooltip.GetName) then
            return
        end

        local tooltipName = tooltip:GetName()
        if not tooltipName then
            return
        end

        local num = tooltip:NumLines() or 0
        for i = 1, num do
            local left = _G[tooltipName .. "TextLeft" .. i]
            if left and left.__FGO_TooltipX_Hidden and left.Show then
                left.__FGO_TooltipX_Hidden = nil
                left:Show()
            end

            local right = _G[tooltipName .. "TextRight" .. i]
            if right and right.__FGO_TooltipX_Hidden and right.Show then
                right.__FGO_TooltipX_Hidden = nil
                right:Show()
            end
        end
    end

    local function HideQuestProgressLines(tooltip)
        if not GetBoolSetting("tooltipXCleanupAcc", false) then
            return
        end
        if GetBoolSetting("tooltipXCleanupCombatOnlyAcc", true) and not InCombat() then
            return
        end

        local mode = (GetStringSetting("tooltipXCleanupModeAcc", "strict") or "strict"):lower()
        if mode ~= "strict" and mode ~= "more" then
            mode = "strict"
        end

        if not (tooltip and tooltip.NumLines and tooltip.GetName) then
            return
        end

        local tooltipName = tooltip:GetName()
        if not tooltipName then
            return
        end

        local num = tooltip:NumLines() or 0
        local hiddenCount = 0
        for i = 1, num do
            local left = _G[tooltipName .. "TextLeft" .. i]
            if left and left.IsShown and left:IsShown() and left.GetText and left.Hide then
                local raw = left:GetText()
                local text = StripColorCodes(raw)
                if text then
                    -- Common quest objective pattern: "0/1 Kill X".
                    local isProgress = text:match("^%s*%d+%s*/%s*%d+%s+%S+")
                    if not isProgress and mode == "more" then
                        -- More permissive: also hide lines like "(0/1) ..." or "0/1" anywhere near the start.
                        isProgress = text:match("^%s*%(%s*%d+%s*/%s*%d+%s*%)%s*%S+")
                            or text:match("^%s*%d+%s*/%s*%d+%s*$")
                            or text:match("^%s*%d+%s*/%s*%d+%s+")
                    end

                    if isProgress then
                        left.__FGO_TooltipX_Hidden = true
                        left:Hide()
                        hiddenCount = hiddenCount + 1
                    end
                end
            end

            local right = _G[tooltipName .. "TextRight" .. i]
            if right and right.IsShown and right:IsShown() and right.GetText and right.Hide then
                local raw = right:GetText()
                local text = StripColorCodes(raw)
                if text then
                    local isProgress = text:match("^%s*%d+%s*/%s*%d+%s+%S+")
                    if not isProgress and mode == "more" then
                        isProgress = text:match("^%s*%(%s*%d+%s*/%s*%d+%s*%)%s*%S+")
                            or text:match("^%s*%d+%s*/%s*%d+%s*$")
                            or text:match("^%s*%d+%s*/%s*%d+%s+")
                    end

                    if isProgress then
                        right.__FGO_TooltipX_Hidden = true
                        right:Hide()
                        hiddenCount = hiddenCount + 1
                    end
                end
            end
        end

        if hiddenCount > 0 then
            DebugLog("cleanup:" .. tostring(mode), ("cleanup hid %d line(s) (%s)"):format(hiddenCount, mode))
        end
    end

    local function ApplyTooltipX(tooltip)
        if not tooltip then return end

        -- Always restore any previous line hides so toggling works without reload.
        RestoreHiddenTooltipLines(tooltip)

        -- Master enable: when OFF, TooltipX should be inert and undo any prior hiding.
        if not GetBoolSetting("tooltipXEnabledAcc", false) then
            if tooltip.__FGO_TooltipX_ForcedHidden then
                RestoreTooltipAlpha(tooltip)
            end
            return
        end

        if ShouldHideTooltipNow(tooltip) then
            DebugLog("hide:combat", "combat hide")
            ForceHideTooltip(tooltip)
            return
        end

        if tooltip.__FGO_TooltipX_ForcedHidden then
            RestoreTooltipAlpha(tooltip)
        end

        HideQuestProgressLines(tooltip)
    end

    local function HookTooltipByName(globalName)
        local tt = _G and _G[globalName]
        if not (tt and tt.HookScript) then
            return
        end

        if tt.__FGO_TooltipX_Hooked then
            ApplyTooltipX(tt)
            return
        end

        tt.__FGO_TooltipX_Hooked = true
        tt:HookScript("OnShow", ApplyTooltipX)
        tt:HookScript("OnHide", function(self)
            RestoreHiddenTooltipLines(self)
            if self.__FGO_TooltipX_ForcedHidden then
                RestoreTooltipAlpha(self)
            end
        end)

        ApplyTooltipX(tt)
    end

    local function HookAllKnownTooltips()
        for _, name in ipairs({
            "GameTooltip",
            "ItemRefTooltip",
            "ShoppingTooltip1",
            "ShoppingTooltip2",
            "ShoppingTooltip3",
            "WorldMapTooltip",
            "BattlePetTooltip",
            "FloatingBattlePetTooltip",
            "FloatingPetBattleAbilityTooltip",
            "EmbeddedItemTooltip",
        }) do
            HookTooltipByName(name)
        end
    end

    local function HookTooltipDataProcessor()
        if not (TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall) then
            return
        end
        if TooltipDataProcessor.__FGO_TooltipX_Hooked then
            return
        end
        TooltipDataProcessor.__FGO_TooltipX_Hooked = true

        if type(Enum) == "table" and type(Enum.TooltipDataType) == "table" then
            for _, tooltipDataType in pairs(Enum.TooltipDataType) do
                if type(tooltipDataType) == "number" then
                    TooltipDataProcessor.AddTooltipPostCall(tooltipDataType, ApplyTooltipX)
                end
            end
        end
    end

    local function InitOnce()
        if didInit then
            return
        end
        didInit = true

        HookTooltipDataProcessor()
        HookAllKnownTooltips()
    end

    function ns.ApplyTooltipXSetting(force)
        InitOnce()

        if force then
            HookAllKnownTooltips()
        end
    end

    local function ReapplyIfTooltipShown()
        if GameTooltip and GameTooltip.IsShown and GameTooltip:IsShown() then
            ApplyTooltipX(GameTooltip)
        end
    end

    local function OnEvent(_, event, arg1)
        if event == "ADDON_LOADED" and arg1 == addonName then
            -- Initialize defaults if needed.
            local s = GetSettings()
            if type(s) == "table" then
                if type(s.tooltipXEnabledAcc) ~= "boolean" then s.tooltipXEnabledAcc = false end
                if type(s.tooltipXCombatHideAcc) ~= "boolean" then s.tooltipXCombatHideAcc = false end
                if type(s.tooltipXCombatModifierAcc) ~= "string" then s.tooltipXCombatModifierAcc = "CTRL" end
                if type(s.tooltipXCombatShowTargetAcc) ~= "boolean" then s.tooltipXCombatShowTargetAcc = true end
                if type(s.tooltipXCombatShowFocusAcc) ~= "boolean" then s.tooltipXCombatShowFocusAcc = false end
                if type(s.tooltipXCombatShowMouseoverAcc) ~= "boolean" then s.tooltipXCombatShowMouseoverAcc = true end
                if type(s.tooltipXCombatShowFriendlyPlayersAcc) ~= "boolean" then s.tooltipXCombatShowFriendlyPlayersAcc = false end
                if type(s.tooltipXCleanupAcc) ~= "boolean" then s.tooltipXCleanupAcc = false end
                if type(s.tooltipXCleanupCombatOnlyAcc) ~= "boolean" then s.tooltipXCleanupCombatOnlyAcc = true end
                if type(s.tooltipXCleanupModeAcc) ~= "string" then s.tooltipXCleanupModeAcc = "strict" end
                if type(s.tooltipXDebugAcc) ~= "boolean" then s.tooltipXDebugAcc = false end
            end
            return
        end

        if event == "PLAYER_LOGIN" or event == "VARIABLES_LOADED" then
            InitOnce()
            ns.ApplyTooltipXSetting(true)
            return
        end

        if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
            -- Combat state changed; if a tooltip is currently visible, update it.
            ReapplyIfTooltipShown()
            return
        end
    end

    local f = _G.CreateFrame("Frame")
    f:RegisterEvent("ADDON_LOADED")
    f:RegisterEvent("PLAYER_LOGIN")
    f:RegisterEvent("VARIABLES_LOADED")
    f:RegisterEvent("PLAYER_REGEN_DISABLED")
    f:RegisterEvent("PLAYER_REGEN_ENABLED")
    f:SetScript("OnEvent", OnEvent)
end

-- ============================================================================
-- Tutorial suppression (formerly Tutorial)
-- ============================================================================

do
    local didApplyHide
    local pendingChanges

    local IsAddOnLoadedSafe = (_G.C_AddOns and rawget(_G.C_AddOns, "IsAddOnLoaded")) or rawget(_G, "IsAddOnLoaded")
    if IsAddOnLoadedSafe then
        -- kept for future use / compatibility
    end

    local function GetSettings()
        if ns and type(ns._InitSV) == "function" then
            ns._InitSV()
        end
        local acc = rawget(_G, "AutoGame_Settings") or rawget(_G, "AutoGossip_Settings")
        if type(acc) ~= "table" then
            return nil
        end
        return acc
    end

    local function GetTutorialEnabledEffective()
        local acc = GetSettings()
        if type(acc) == "table" and type(acc.tutorialEnabledAcc) == "boolean" then
            return acc.tutorialEnabledAcc
        end

        -- Back-compat: old versions stored tutorialOffAcc.
        if type(acc) == "table" and type(acc.tutorialOffAcc) == "boolean" then
            return (not acc.tutorialOffAcc)
        end

        return true
    end

    local function GetTutorialOffEffective()
        return not GetTutorialEnabledEffective()
    end

    local function ApplyMicroAlertsHook()
        -- Intentionally a no-op.
        -- Overwriting Blizzard globals (like MainMenuMicroButton_AreAlertsEnabled) is a common source of UI taint
        -- and can lead to blocked protected calls inside Blizzard_ActionBarController.
        -- The tutorial suppression in this addon relies on CVars instead.
        return
    end

    local function ApplyHideTutorials(force)
        if didApplyHide and not force then
            return
        end
        didApplyHide = true

        if not GetTutorialOffEffective() then
            return
        end

        if _G.C_CVar and _G.C_CVar.SetCVar then
            _G.C_CVar.SetCVar("showTutorials", 0)
            _G.C_CVar.SetCVar("showNPETutorials", 0)
            _G.C_CVar.SetCVar("hideAdventureJournalAlerts", 1)
        elseif _G.SetCVar then
            _G.SetCVar("showTutorials", 0)
            _G.SetCVar("showNPETutorials", 0)
            _G.SetCVar("hideAdventureJournalAlerts", 1)
        end

        local numTutorials = tonumber(rawget(_G, "NUM_LE_FRAME_TUTORIALS"))
        local numAccountTutorials = tonumber(rawget(_G, "NUM_LE_FRAME_TUTORIAL_ACCCOUNTS"))

        local lastInfoFrame
        if numTutorials and _G.C_CVar and _G.C_CVar.GetCVarBitfield then
            lastInfoFrame = _G.C_CVar.GetCVarBitfield("closedInfoFrames", numTutorials)
        end

        if pendingChanges or (not lastInfoFrame) then
            if numTutorials and _G.C_CVar and _G.C_CVar.SetCVarBitfield then
                for i = 1, numTutorials do
                    _G.C_CVar.SetCVarBitfield("closedInfoFrames", i, true)
                end
            end
            if numAccountTutorials and _G.C_CVar and _G.C_CVar.SetCVarBitfield then
                for i = 1, numAccountTutorials do
                    _G.C_CVar.SetCVarBitfield("closedInfoFramesAccountWide", i, true)
                end
            end
        end

        ApplyMicroAlertsHook()
    end

    local function ApplyShowTutorials()
        if _G.C_CVar and _G.C_CVar.SetCVar then
            _G.C_CVar.SetCVar("showTutorials", 1)
            _G.C_CVar.SetCVar("showNPETutorials", 1)
            _G.C_CVar.SetCVar("hideAdventureJournalAlerts", 0)
        elseif _G.SetCVar then
            _G.SetCVar("showTutorials", 1)
            _G.SetCVar("showNPETutorials", 1)
            _G.SetCVar("hideAdventureJournalAlerts", 0)
        end

        ApplyMicroAlertsHook()
    end

    function ns.ApplyTutorialSetting(force)
        if GetTutorialOffEffective() then
            ApplyHideTutorials(force)
        else
            ApplyShowTutorials()
        end
    end

    -- If you're in Exile's Reach and level 1 this cvar gets automatically enabled.
    if _G.hooksecurefunc then
        _G.hooksecurefunc("NPE_CheckTutorials", function()
            if not GetTutorialOffEffective() then
                return
            end
            if _G.C_PlayerInfo and _G.C_PlayerInfo.IsPlayerNPERestricted and _G.UnitLevel and _G.SetCVar then
                if _G.C_PlayerInfo.IsPlayerNPERestricted() and _G.UnitLevel("player") == 1 then
                    print("fr0z3nUI_GameOptions: Disabling NPE tutorial, please disregard Blizzard debug prints.")
                    _G.SetCVar("showTutorials", 0)
                end
            end
        end)
    end

    local function OnEvent(_, event, arg1)
        if event == "ADDON_LOADED" and arg1 == addonName then
            local tocVersion = select(4, _G.GetBuildInfo())
            local acc = GetSettings()
            if type(acc) == "table" and GetTutorialOffEffective() then
                if (not acc.tutorialBuild) or (acc.tutorialBuild < tocVersion) then
                    acc.tutorialBuild = tocVersion
                    pendingChanges = true
                end
            end
            return
        end

        if event == "PLAYER_LOGIN" or event == "VARIABLES_LOADED" then
            ns.ApplyTutorialSetting(false)
        end
    end

    local f = _G.CreateFrame("Frame")
    f:RegisterEvent("ADDON_LOADED")
    f:RegisterEvent("PLAYER_LOGIN")
    f:RegisterEvent("VARIABLES_LOADED")
    f:SetScript("OnEvent", OnEvent)
end
