local _, ns = ...
ns = ns or {}

ns.SwitchesBP = ns.SwitchesBP or {}
local BP = ns.SwitchesBP

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
    if not (AutoGossip_Settings.petWalkEnabledAcc and true or false) then
        return false
    end
    if AutoGossip_CharSettings.petWalkDisabledChar and true or false then
        return false
    end
    return true
end

local function NormalizeMode(m)
    if m == "favorite" or m == "specific" or m == "random" then
        return m
    end
    return "random"
end

local function GetMode()
    InitSV()
    return NormalizeMode(AutoGossip_Settings and AutoGossip_Settings.petWalkModeAcc)
end

local function GetDelay()
    InitSV()
    local d = tonumber(AutoGossip_Settings and AutoGossip_Settings.petWalkDelayAcc)
    if type(d) ~= "number" then
        return 1.0
    end
    if d < 0 then
        return 0
    end
    if d > 10 then
        return 10
    end
    return d
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

local function GetSummonedGUID()
    return SafeCall(C_PetJournal and C_PetJournal.GetSummonedPetGUID)
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

local function CanSummonNow()
    if not IsEnabled() then
        return false
    end

    if not (C_PetJournal and (C_PetJournal.SummonPetByGUID or C_PetJournal.SummonRandomPet)) then
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

    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then
        return false
    end

    if UnitOnTaxi and UnitOnTaxi("player") then
        return false
    end

    if IsMounted and IsMounted() then
        return false
    end

    if IsFalling and IsFalling() then
        return false
    end

    if UnitCastingInfo and UnitCastingInfo("player") then
        return false
    end

    if UnitChannelInfo and UnitChannelInfo("player") then
        return false
    end

    if GetUnitSpeed and (GetUnitSpeed("player") or 0) > 0 then
        return false
    end

    local summoned = GetSummonedGUID()
    if type(summoned) == "string" and summoned ~= "" then
        return false
    end

    return true
end

local function GetPetNameByGUID(guid)
    if type(guid) ~= "string" or guid == "" then
        return nil
    end
    if not (C_PetJournal and C_PetJournal.GetPetInfoByPetID) then
        return nil
    end

    local petID, speciesID, isOwned, customName, level, favorite
    petID, speciesID, isOwned, customName, level, favorite = SafeCall(C_PetJournal.GetPetInfoByPetID, guid)

    if type(customName) == "string" and customName ~= "" then
        return customName
    end

    if not (C_PetJournal and C_PetJournal.GetPetInfoBySpeciesID) then
        return nil
    end

    local speciesName = SafeCall(C_PetJournal.GetPetInfoBySpeciesID, speciesID)
    if type(speciesName) == "string" and speciesName ~= "" then
        return speciesName
    end

    return nil
end

local function PickFavoritePetGUID()
    if not (C_PetJournal and C_PetJournal.GetNumPets and C_PetJournal.GetPetInfoByIndex) then
        return nil
    end

    local numPets = SafeCall(C_PetJournal.GetNumPets)
    numPets = tonumber(numPets) or 0
    if numPets <= 0 then
        return nil
    end

    for i = 1, numPets do
        local petID, speciesID, isOwned, customName, level, favorite, isRevoked
        petID, speciesID, isOwned, customName, level, favorite, isRevoked = SafeCall(C_PetJournal.GetPetInfoByIndex, i)

        if petID and isOwned and (favorite and true or false) then
            return petID
        end
    end

    return nil
end

local function TrySummon(reason)
    if not CanSummonNow() then
        return false
    end

    InitSV()

    local mode = GetMode()
    local specificGUID = AutoGossip_Settings and AutoGossip_Settings.petWalkSpecificGUIDAcc

    if mode == "specific" then
        if type(specificGUID) == "string" and specificGUID ~= "" and C_PetJournal and C_PetJournal.SummonPetByGUID then
            SafeCall(C_PetJournal.SummonPetByGUID, specificGUID)
            return true
        end

        -- Fallback: if specific is not set/valid, behave like favorite.
        mode = "favorite"
    end

    if mode == "favorite" then
        local fav = PickFavoritePetGUID()
        if type(fav) == "string" and fav ~= "" and C_PetJournal and C_PetJournal.SummonPetByGUID then
            SafeCall(C_PetJournal.SummonPetByGUID, fav)
            return true
        end

        -- Fallback: if no favorite exists, behave like random.
        mode = "random"
    end

    if mode == "random" and C_PetJournal and C_PetJournal.SummonRandomPet then
        SafeCall(C_PetJournal.SummonRandomPet)
        return true
    end

    return false
end

local pendingTimer
local lastAttemptAt = 0

local function GetTimeNow()
    return (GetTime and GetTime()) or 0
end

local function CancelPending()
    if pendingTimer and pendingTimer.Cancel then
        pendingTimer:Cancel()
    end
    pendingTimer = nil
end

local function ScheduleSummon(reason, delay)
    if not IsEnabled() then
        CancelPending()
        return
    end

    delay = tonumber(delay)
    if type(delay) ~= "number" then
        delay = GetDelay()
    end
    if delay < 0 then
        delay = 0
    end

    CancelPending()

    if not (C_Timer and C_Timer.NewTimer) then
        TrySummon(reason)
        return
    end

    pendingTimer = C_Timer.NewTimer(delay, function()
        pendingTimer = nil

        local now = GetTimeNow()
        if now - (lastAttemptAt or 0) < 1.0 then
            return
        end
        lastAttemptAt = now

        TrySummon(reason)
    end)
end

local function MaybeDismissOnStealth()
    InitSV()
    if not IsEnabled() then
        return
    end

    if not (AutoGossip_Settings and AutoGossip_Settings.petWalkDismissOnStealthAcc) then
        return
    end

    if not (IsStealthed and IsStealthed()) then
        return
    end

    local summoned = GetSummonedGUID()
    if type(summoned) ~= "string" or summoned == "" then
        return
    end

    if C_PetJournal and C_PetJournal.DismissPet then
        SafeCall(C_PetJournal.DismissPet)
        return
    end

    if C_PetJournal and C_PetJournal.SummonPetByGUID then
        -- SummonPetByGUID toggles: summoned pet => dismiss.
        SafeCall(C_PetJournal.SummonPetByGUID, summoned)
    end
end

function BP.OnSettingsChanged()
    -- Keep things responsive when toggles change.
    if not IsEnabled() then
        CancelPending()
        return
    end
    ScheduleSummon("settings", 0.15)
end

-- ============================================================================
-- Config popout
-- ============================================================================

local configPopup

local function EnsureConfigPopup()
    if configPopup or not UIParent or not CreateFrame then
        return configPopup
    end

    local p = CreateFrame("Frame", "FGO_PetWalkConfigPopup", UIParent, "BasicFrameTemplateWithInset")
    p:SetSize(360, 220)
    p:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    p:SetFrameStrata("DIALOG")
    p:Hide()

    do
        if p.NineSlice and p.NineSlice.Hide then p.NineSlice:Hide() end
        if p.Bg and p.Bg.Hide then p.Bg:Hide() end
        if p.TitleBg and p.TitleBg.Hide then p.TitleBg:Hide() end
        if p.InsetBg and p.InsetBg.Hide then p.InsetBg:Hide() end
        if p.Inset and p.Inset.Hide then p.Inset:Hide() end

        local bg = CreateFrame("Frame", nil, p, "BackdropTemplate")
        bg:SetAllPoints(p)
        bg:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            tile = true,
            tileSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        bg:SetBackdropColor(0, 0, 0, 0.85)
        bg:SetFrameLevel((p.GetFrameLevel and p:GetFrameLevel() or 0))
        p._unifiedBG = bg

        local closeBtn = p.CloseButton
        if not closeBtn then
            closeBtn = CreateFrame("Button", nil, p, "UIPanelCloseButton")
        end
        if closeBtn and closeBtn.ClearAllPoints and closeBtn.SetPoint then
            closeBtn:ClearAllPoints()
            closeBtn:SetPoint("TOPRIGHT", p, "TOPRIGHT", -6, -6)
            if closeBtn.SetFrameLevel then
                closeBtn:SetFrameLevel((p.GetFrameLevel and p:GetFrameLevel() or 0) + 20)
            end
            closeBtn:SetScript("OnClick", function() if p and p.Hide then p:Hide() end end)
        end
    end

    p.title = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    p.title:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -6)
    p.title:SetText("Pet Walk Config")
    do
        local fontPath, fontSize, fontFlags = p.title:GetFont()
        if fontPath and fontSize then
            p.title:SetFont(fontPath, fontSize + 2, fontFlags)
        end
    end

    local btnMode = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    btnMode:SetSize(330, 22)
    btnMode:SetPoint("TOP", p, "TOP", 0, -40)
    p.btnMode = btnMode

    local btnSpecific = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    btnSpecific:SetSize(160, 22)
    btnSpecific:SetPoint("TOPLEFT", btnMode, "BOTTOMLEFT", 0, -10)
    btnSpecific:SetText("Use Current Pet")
    p.btnSpecific = btnSpecific

    local specificLabel = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    specificLabel:SetPoint("LEFT", btnSpecific, "RIGHT", 10, 0)
    specificLabel:SetJustifyH("LEFT")
    specificLabel:SetText("Specific: (none)")
    p.specificLabel = specificLabel

    local btnDelay = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    btnDelay:SetSize(160, 22)
    btnDelay:SetPoint("TOPLEFT", btnSpecific, "BOTTOMLEFT", 0, -10)
    p.btnDelay = btnDelay

    local btnStealth = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    btnStealth:SetSize(160, 22)
    btnStealth:SetPoint("LEFT", btnDelay, "RIGHT", 10, 0)
    p.btnStealth = btnStealth

    local function RefreshFromSV()
        InitSV()

        local mode = GetMode()
        local modeText = (mode == "random" and "Random") or (mode == "favorite" and "Favorites") or "Specific"
        btnMode:SetText("Mode: " .. modeText)

        local delay = GetDelay()
        btnDelay:SetText(string.format("Delay: %.1fs", delay))

        local stealthOn = (AutoGossip_Settings and AutoGossip_Settings.petWalkDismissOnStealthAcc) and true or false
        if stealthOn then
            btnStealth:SetText("Stealth: |cff00ccffDismiss|r")
        else
            btnStealth:SetText("Stealth: |cff888888Keep|r")
        end

        local guid = AutoGossip_Settings and AutoGossip_Settings.petWalkSpecificGUIDAcc
        local name = GetPetNameByGUID(guid)
        if type(name) == "string" and name ~= "" then
            specificLabel:SetText("Specific: " .. name)
        elseif type(guid) == "string" and guid ~= "" then
            specificLabel:SetText("Specific: (set)")
        else
            specificLabel:SetText("Specific: (none)")
        end
    end

    p.RefreshFromSV = RefreshFromSV

    btnMode:SetScript("OnClick", function()
        InitSV()
        local m = GetMode()
        if m == "random" then
            m = "favorite"
        elseif m == "favorite" then
            m = "specific"
        else
            m = "random"
        end
        AutoGossip_Settings.petWalkModeAcc = m
        RefreshFromSV()
        BP.OnSettingsChanged()
    end)

    btnSpecific:SetScript("OnClick", function()
        InitSV()
        local guid = GetSummonedGUID()
        if type(guid) ~= "string" or guid == "" then
            return
        end
        AutoGossip_Settings.petWalkSpecificGUIDAcc = guid
        AutoGossip_Settings.petWalkModeAcc = "specific"
        RefreshFromSV()
        BP.OnSettingsChanged()
    end)

    btnDelay:SetScript("OnClick", function()
        InitSV()
        local d = GetDelay()
        if d <= 0.5 then
            d = 1.0
        elseif d <= 1.0 then
            d = 2.0
        else
            d = 0.5
        end
        AutoGossip_Settings.petWalkDelayAcc = d
        RefreshFromSV()
        BP.OnSettingsChanged()
    end)

    btnStealth:SetScript("OnClick", function()
        InitSV()
        AutoGossip_Settings.petWalkDismissOnStealthAcc = not (AutoGossip_Settings.petWalkDismissOnStealthAcc and true or false)
        RefreshFromSV()
        MaybeDismissOnStealth()
    end)

    p:SetScript("OnShow", function()
        if p.RefreshFromSV then
            p.RefreshFromSV()
        end
    end)

    configPopup = p
    return configPopup
end

function BP.OpenPetWalkConfigPopup()
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

BP.GetPetWalkConfigPopupFrame = function()
    return configPopup or (_G and rawget(_G, "FGO_PetWalkConfigPopup"))
end

-- ============================================================================
-- Runtime loop
-- ============================================================================

do
    local f = CreateFrame("Frame")

    local lastMoving = false
    local movePollElapsed = 0
    local periodicElapsed = 0

    local function IsMoving()
        return (GetUnitSpeed and (GetUnitSpeed("player") or 0) > 0) and true or false
    end

    local function OnEvent(_, event)
        if event == "PLAYER_LOGIN" or event == "VARIABLES_LOADED" then
            InitSV()
            ScheduleSummon(event, 2.0)
            return
        end

        if event == "UPDATE_STEALTH" then
            MaybeDismissOnStealth()
            if IsEnabled() and (not (IsStealthed and IsStealthed())) then
                ScheduleSummon(event, GetDelay())
            end
            return
        end

        if event == "PLAYER_REGEN_ENABLED" then
            ScheduleSummon(event, GetDelay())
            return
        end

        if event == "PLAYER_CONTROL_GAINED" or event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_MOUNT_DISPLAY_CHANGED" or event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then
            ScheduleSummon(event, 2.0)
            return
        end

        if event == "PET_JOURNAL_LIST_UPDATE" then
            if IsEnabled() then
                ScheduleSummon(event, GetDelay())
            end
            return
        end
    end

    f:RegisterEvent("PLAYER_LOGIN")
    f:RegisterEvent("VARIABLES_LOADED")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("PLAYER_CONTROL_GAINED")
    f:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
    f:RegisterEvent("PLAYER_REGEN_ENABLED")
    f:RegisterEvent("PLAYER_ALIVE")
    f:RegisterEvent("PLAYER_UNGHOST")
    f:RegisterEvent("UPDATE_STEALTH")
    f:RegisterEvent("PET_JOURNAL_LIST_UPDATE")
    f:SetScript("OnEvent", OnEvent)

    f:SetScript("OnUpdate", function(_, elapsed)
        if not IsEnabled() then
            lastMoving = false
            movePollElapsed = 0
            periodicElapsed = 0
            return
        end

        elapsed = elapsed or 0
        movePollElapsed = movePollElapsed + elapsed
        periodicElapsed = periodicElapsed + elapsed

        if movePollElapsed >= 0.25 then
            movePollElapsed = 0
            local moving = IsMoving()
            if lastMoving and (not moving) then
                ScheduleSummon("move_stop", GetDelay())
            end
            lastMoving = moving
        end

        if periodicElapsed >= 4.0 then
            periodicElapsed = 0
            if not pendingTimer then
                -- If we're idle (not moving) and have no pet, try periodically.
                ScheduleSummon("periodic", GetDelay())
            end
        end
    end)
end
