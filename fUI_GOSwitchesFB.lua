local _, ns = ...
ns = ns or {}

-- Fishing (FB) Switches module.
-- Provides a minimal config popout and shared helpers for the Switches tab.

ns.SwitchesFB = ns.SwitchesFB or {}
local FB = ns.SwitchesFB

local function InitSV()
    if ns and type(ns._InitSV) == "function" then
        ns._InitSV()
    end
end

local function GetAccEnabled()
    InitSV()
    return (AutoGossip_Settings and AutoGossip_Settings.fishingEnabledAcc) and true or false
end

local function GetCharOverride()
    InitSV()
    if type(AutoGossip_CharSettings) ~= "table" then
        return nil
    end
    local v = AutoGossip_CharSettings.fishingEnabledOverride
    if type(v) == "boolean" then
        return v
    end
    return nil
end

local function GetEffectiveEnabled()
    local override = GetCharOverride()
    if override ~= nil then
        return override
    end
    return GetAccEnabled()
end

function FB.IsEnabled()
    return GetEffectiveEnabled()
end

-- ============================================================================
-- Fishing helper: create/update a real macro + on-screen reminder while fishing
-- ============================================================================

local MACRO_NAME = "FGO_Fish"

local FISHING_SPELL_NAME = nil
do
    if type(GetSpellInfo) == "function" then
        local ok, name = pcall(GetSpellInfo, 7620) -- Fishing
        if ok and type(name) == "string" and name ~= "" then
            FISHING_SPELL_NAME = name
        end
    end
    FISHING_SPELL_NAME = FISHING_SPELL_NAME or "Fishing"
end

local function IsFishingSpellName(spellName)
    if type(spellName) ~= "string" or spellName == "" then
        return false
    end
    return spellName:lower() == tostring(FISHING_SPELL_NAME):lower()
end

local function InCombat()
    return (type(InCombatLockdown) == "function" and InCombatLockdown()) and true or false
end

local function BuildMacroText(mode, lureItemID, bobberToyID)
    mode = tostring(mode or "spam"):lower()
    lureItemID = tonumber(lureItemID) or 0
    bobberToyID = tonumber(bobberToyID) or 0

    local lines = { "#showtooltip " .. tostring(FISHING_SPELL_NAME) }

    if mode == "shift" then
        if lureItemID > 0 then
            lines[#lines + 1] = "/use [mod:shift] item:" .. tostring(lureItemID)
        end
        if bobberToyID > 0 then
            lines[#lines + 1] = "/use [mod:shift] item:" .. tostring(bobberToyID)
        end
        lines[#lines + 1] = "/cast " .. tostring(FISHING_SPELL_NAME)
    else
        -- spam mode: press repeatedly; WoW will no-op /use once buffs are active
        if lureItemID > 0 then
            lines[#lines + 1] = "/use item:" .. tostring(lureItemID)
        end
        if bobberToyID > 0 then
            lines[#lines + 1] = "/use item:" .. tostring(bobberToyID)
        end
        lines[#lines + 1] = "/cast " .. tostring(FISHING_SPELL_NAME)
    end

    return table.concat(lines, "\n")
end

local function UpsertMacro(mode)
    if InCombat() then
        return false, "in-combat"
    end
    if type(GetMacroIndexByName) ~= "function" or type(EditMacro) ~= "function" or type(CreateMacro) ~= "function" then
        return false, "macro api unavailable"
    end

    EnsureSettings()
    local lureItemID = GetPreferredLureItemID()
    local bobberToyID = GetPreferredBobberToyID()
    local text = BuildMacroText(mode, lureItemID, bobberToyID)

    local idx = 0
    local okIdx, v = pcall(GetMacroIndexByName, MACRO_NAME)
    if okIdx and type(v) == "number" then
        idx = v
    end

    if idx and idx > 0 then
        local ok = pcall(EditMacro, idx, MACRO_NAME, "INV_Misc_Fish_02", text)
        if not ok then
            return false, "edit failed"
        end
    else
        local ok = pcall(CreateMacro, MACRO_NAME, "INV_Misc_Fish_02", text, nil)
        if not ok then
            return false, "create failed"
        end
    end

    if type(AutoGossip_Settings) == "table" then
        AutoGossip_Settings.fishingMacroModeAcc = tostring(mode)
    end
    return true
end

local remindFrame = nil
local fishingActive = false

local function EnsureReminderFrame()
    if remindFrame and remindFrame.SetPoint then
        return remindFrame
    end
    if not (UIParent and CreateFrame) then
        return nil
    end

    local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    f:SetSize(240, 34)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, -160)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:Hide()
    f:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        tile = true,
        tileSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    f:SetBackdropColor(0, 0, 0, 0.70)

    local t = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    t:SetPoint("CENTER", f, "CENTER", 0, 0)
    t:SetText("Fishing: use '" .. MACRO_NAME .. "'")
    f._text = t

    remindFrame = f
    return f
end

local function RefreshReminder()
    local f = EnsureReminderFrame()
    if not f then
        return
    end
    if fishingActive and FB.IsEnabled() then
        if f.Show then f:Show() end
    else
        if f.Hide then f:Hide() end
    end
end

function FB.OnSettingsChanged()
    RefreshReminder()
end

do
    local f = CreateFrame("Frame")
    if f then
        f:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
        f:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
        f:RegisterEvent("PLAYER_ENTERING_WORLD")

        f:SetScript("OnEvent", function(_, event, unit, _, spellID)
            if event == "PLAYER_ENTERING_WORLD" then
                fishingActive = false
                RefreshReminder()
                return
            end
            if unit ~= "player" then
                return
            end

            local spellName = nil
            if type(GetSpellInfo) == "function" and spellID then
                local ok, name = pcall(GetSpellInfo, spellID)
                if ok then
                    spellName = name
                end
            end
            if not spellName and type(UnitChannelInfo) == "function" then
                local ok, chName = pcall(UnitChannelInfo, "player")
                if ok then
                    spellName = chName
                end
            end

            if not IsFishingSpellName(spellName) then
                return
            end

            if event == "UNIT_SPELLCAST_CHANNEL_START" then
                fishingActive = true
            elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
                fishingActive = false
            end
            RefreshReminder()
        end)
    end
end

local fishingPopout = nil

local function EnsureSettings()
    InitSV()
    if type(AutoGossip_Settings) == "table" then
        AutoGossip_Settings.fishingBobberToyIDAcc = tonumber(AutoGossip_Settings.fishingBobberToyIDAcc) or 0
        AutoGossip_Settings.fishingLureItemIDAcc = tonumber(AutoGossip_Settings.fishingLureItemIDAcc) or 0
    end
end

local function MakeNumericBox(parent, width, height)
    local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    eb:SetSize(width, height)
    eb:SetAutoFocus(false)
    eb:SetJustifyH("CENTER")
    eb:SetTextInsets(1, 1, 0, 0)
    if eb.SetNumeric then
        eb:SetNumeric(true)
    end

    -- Borderless: hide the default InputBoxTemplate textures.
    if eb.Left and eb.Left.Hide then eb.Left:Hide() end
    if eb.Middle and eb.Middle.Hide then eb.Middle:Hide() end
    if eb.Right and eb.Right.Hide then eb.Right:Hide() end

    return eb
end

local function AttachGhostText(editBox, text)
    if not (editBox and editBox.CreateFontString) then
        return
    end
    local ghost = editBox:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    ghost:SetText(tostring(text or ""))
    ghost:SetJustifyH("LEFT")
    ghost:SetPoint("LEFT", editBox, "LEFT", 6, 0)

    local function Update()
        local hasText = (tostring(editBox:GetText() or "") ~= "")
        if editBox.HasFocus and editBox:HasFocus() then
            ghost:Hide()
        else
            ghost:SetShown(not hasText)
        end
    end
    editBox:HookScript("OnTextChanged", Update)
    editBox:HookScript("OnEditFocusGained", Update)
    editBox:HookScript("OnEditFocusLost", Update)
    Update()
    editBox._fgoGhost = ghost
end

local function GetPreferredBobberToyID()
    EnsureSettings()
    return tonumber(AutoGossip_Settings and AutoGossip_Settings.fishingBobberToyIDAcc) or 0
end

local function SetPreferredBobberToyID(id)
    EnsureSettings()
    if type(AutoGossip_Settings) ~= "table" then
        return
    end
    id = tonumber(id) or 0
    if id < 0 then id = 0 end
    AutoGossip_Settings.fishingBobberToyIDAcc = math.floor(id + 0.5)
end

local function GetPreferredLureItemID()
    EnsureSettings()
    return tonumber(AutoGossip_Settings and AutoGossip_Settings.fishingLureItemIDAcc) or 0
end

local function SetPreferredLureItemID(id)
    EnsureSettings()
    if type(AutoGossip_Settings) ~= "table" then
        return
    end
    id = tonumber(id) or 0
    if id < 0 then id = 0 end
    AutoGossip_Settings.fishingLureItemIDAcc = math.floor(id + 0.5)
end

function FB.GetFishingConfigPopupFrame()
    return fishingPopout
end

function FB.EnsureFishingConfigPopup(panel)
    if fishingPopout and fishingPopout.SetPoint then
        return fishingPopout
    end
    if not (panel and panel.CreateFontString and panel.SetPoint) then
        return nil
    end

    -- Match the Mail config popout pattern: a standalone UIParent popout
    -- anchored to the Switches panel (consistent padding/title/close).
    local popout = CreateFrame("Frame", "FGO_FishingConfigPopup", UIParent, "BackdropTemplate")
    if not popout then
        return nil
    end
    fishingPopout = popout

    popout:SetSize(480, 230)
    popout:ClearAllPoints()
    popout:SetPoint("TOPLEFT", panel, "TOPRIGHT", 10, -40)
    if popout.SetFrameStrata then popout:SetFrameStrata("DIALOG") end
    popout:SetFrameLevel((panel.GetFrameLevel and panel:GetFrameLevel() or 0) + 80)
    if popout.SetClampedToScreen then popout:SetClampedToScreen(true) end
    popout:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        tile = true,
        tileSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    popout:SetBackdropColor(0, 0, 0, 0.85)
    popout:Hide()

    do
        local reg = _G and rawget(_G, "FGO_RegisterPopout")
        if type(reg) == "function" then
            reg("fish", function()
                if popout and popout.Hide then
                    popout:Hide()
                end
            end)
        end
    end

    if _G then
        _G.FGO_FishingPopout = popout
    end

    local title = popout:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", popout, "TOPLEFT", 12, -10)
    title:SetText("Fishing")

    local close = CreateFrame("Button", nil, popout, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", popout, "TOPRIGHT", -6, -6)
    close:SetScript("OnClick", function()
        if popout and popout.Hide then
            popout:Hide()
        end
    end)

    local content = CreateFrame("Frame", nil, popout)
    content:SetPoint("TOPLEFT", popout, "TOPLEFT", 12, -40)
    content:SetPoint("BOTTOMRIGHT", popout, "BOTTOMRIGHT", -12, 12)

    local hint = content:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    hint:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    hint:SetText("Keeps one fishing macro up to date")

    local status = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    status:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -8)
    status:SetJustifyH("LEFT")
    status:SetWidth(440)

    local btnMakeSpam = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    btnMakeSpam:SetSize(200, 20)
    btnMakeSpam:SetPoint("TOPLEFT", status, "BOTTOMLEFT", 0, -8)
    btnMakeSpam:SetText("Make Macro (Spam)")

    local btnMakeShift = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    btnMakeShift:SetSize(200, 20)
    btnMakeShift:SetPoint("LEFT", btnMakeSpam, "RIGHT", 10, 0)
    btnMakeShift:SetText("Make Macro (Shift)")

    local rowBobber = CreateFrame("Frame", nil, content)
    rowBobber:SetSize(440, 20)
    rowBobber:SetPoint("TOPLEFT", btnMakeSpam, "BOTTOMLEFT", 0, -12)

    local lblBobber = rowBobber:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lblBobber:SetPoint("LEFT", rowBobber, "LEFT", 0, 0)
    lblBobber:SetText("Bobber Toy")

    local ebBobber = MakeNumericBox(rowBobber, 90, 20)
    ebBobber:SetPoint("LEFT", rowBobber, "LEFT", 120, 0)
    AttachGhostText(ebBobber, "ToyID")

    local bobberStatus = content:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    bobberStatus:SetPoint("TOPLEFT", rowBobber, "BOTTOMLEFT", 0, -4)
    bobberStatus:SetJustifyH("LEFT")
    bobberStatus:SetWidth(440)

    local rowLure = CreateFrame("Frame", nil, content)
    rowLure:SetSize(440, 20)
    rowLure:SetPoint("TOPLEFT", bobberStatus, "BOTTOMLEFT", 0, -10)

    local lblLure = rowLure:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lblLure:SetPoint("LEFT", rowLure, "LEFT", 0, 0)
    lblLure:SetText("Lure Item")

    local ebLure = MakeNumericBox(rowLure, 90, 20)
    ebLure:SetPoint("LEFT", rowLure, "LEFT", 120, 0)
    AttachGhostText(ebLure, "ItemID")

    local lureStatus = content:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    lureStatus:SetPoint("TOPLEFT", rowLure, "BOTTOMLEFT", 0, -4)
    lureStatus:SetJustifyH("LEFT")
    lureStatus:SetWidth(440)

    local function Refresh()
        EnsureSettings()
        local effective = GetEffectiveEnabled()
        local override = GetCharOverride()
        local overrideText
        if override == nil then
            overrideText = "(no override)"
        elseif override then
            overrideText = "(override: ON)"
        else
            overrideText = "(override: OFF)"
        end
        local mode = (AutoGossip_Settings and AutoGossip_Settings.fishingMacroModeAcc) or "spam"
        status:SetText(string.format("Macro: %s (%s)\nEnabled: %s %s", MACRO_NAME, tostring(mode), effective and "ON" or "OFF", overrideText))

        local toyID = GetPreferredBobberToyID()
        if ebBobber and ebBobber.SetText then
            ebBobber:SetText((toyID > 0) and tostring(toyID) or "")
        end
        local toyOwned = false
        if toyID > 0 and type(PlayerHasToy) == "function" then
            local ok, has = pcall(PlayerHasToy, toyID)
            toyOwned = ok and has == true
        end
        if toyID <= 0 then
            bobberStatus:SetText("Bobber: (none)")
        else
            local link = nil
            if type(GetItemInfo) == "function" then
                link = select(2, GetItemInfo(toyID))
            end
            local shown = link or ("item:" .. tostring(toyID))
            bobberStatus:SetText("Bobber: " .. tostring(shown) .. " (" .. (toyOwned and "owned" or "not owned") .. ")")
        end

        local lureID = GetPreferredLureItemID()
        if ebLure and ebLure.SetText then
            ebLure:SetText((lureID > 0) and tostring(lureID) or "")
        end
        local count = 0
        if lureID > 0 and type(GetItemCount) == "function" then
            local ok, c = pcall(GetItemCount, lureID, false, false)
            if ok and type(c) == "number" then
                count = c
            end
        end
        if lureID <= 0 then
            lureStatus:SetText("Lure: (none)")
        else
            local link = nil
            if type(GetItemInfo) == "function" then
                link = select(2, GetItemInfo(lureID))
            end
            local shown = link or ("item:" .. tostring(lureID))
            lureStatus:SetText("Lure: " .. tostring(shown) .. " x" .. tostring(count))
        end

    end

    btnMakeSpam:SetScript("OnClick", function()
        local ok, why = UpsertMacro("spam")
        if ok then
            Refresh()
        else
            if why == "in-combat" then
                -- Silent; avoid spam.
            end
        end
    end)
    btnMakeShift:SetScript("OnClick", function()
        local ok, why = UpsertMacro("shift")
        if ok then
            Refresh()
        else
            if why == "in-combat" then
                -- Silent; avoid spam.
            end
        end
    end)

    ebBobber:SetScript("OnEditFocusLost", function()
        SetPreferredBobberToyID(tonumber(ebBobber:GetText()) or 0)
        Refresh()
    end)

    ebLure:SetScript("OnEditFocusLost", function()
        SetPreferredLureItemID(tonumber(ebLure:GetText()) or 0)
        Refresh()
    end)

    popout._fgoUpdate = Refresh
    popout:SetScript("OnShow", function()
        if popout and popout._fgoUpdate then
            popout._fgoUpdate()
        end
    end)

    return popout
end

function FB.IsFishingPopoutOpen()
    return (fishingPopout and fishingPopout.IsShown and fishingPopout:IsShown()) and true or false
end

function FB.ToggleFishingConfigPopup(panel, show, closeAllFn)
    local popout = FB.EnsureFishingConfigPopup(panel)
    if not popout then
        return
    end

    local wantShow = show
    if wantShow == nil then
        wantShow = not FB.IsFishingPopoutOpen()
    end

    if wantShow then
        if type(closeAllFn) == "function" then
            closeAllFn(popout)
        end
        if popout.Show then
            popout:Show()
        end
    else
        if popout.Hide then
            popout:Hide()
        end
    end
end
