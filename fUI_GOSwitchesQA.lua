local addonName, ns = ...
ns = ns or {}

ns.SwitchesQA = ns.SwitchesQA or {}
local QA = ns.SwitchesQA

local function InitSV()
    if ns and ns._InitSV then
        ns._InitSV()
    end
end

local queueOverlayButton = nil
local queueOverlayHint = nil
local queueOverlayPendingHide = false
local queueOverlayWatchdogElapsed = 0
local queueOverlaySuppressUntil = 0
local queueOverlayProposalToken = 0
local queueOverlayDismissedToken = 0
local queueOverlayDidBoostVolume = false
local queueOverlayRepeatNextAt = 0

local queueSoundRepeatRunning = false
local queueSoundRepeatId = 0
local queueSoundRepeatNoProposalTries = 0

local function GetTimeNow()
    return (GetTime and GetTime()) or 0
end

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

local function ClampNumber(v, minV, maxV)
    v = tonumber(v)
    if v == nil then
        return nil
    end
    if minV ~= nil and v < minV then v = minV end
    if maxV ~= nil and v > maxV then v = maxV end
    return v
end

local function GetAccEnabled()
    return AutoGossip_Settings and AutoGossip_Settings.queueAcceptAcc == true
end

local function GetCharOverride()
    if not AutoGossip_CharSettings then
        return nil
    end
    local v = AutoGossip_CharSettings.queueAcceptEnabledOverride
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

local function GetRestoreVolumePct()
    local pct = AutoGossip_Settings and AutoGossip_Settings.queueAcceptRestoreVolumePctAcc
    pct = math.floor((tonumber(pct) or 50) + 0.5)
    if pct < 0 then pct = 0 end
    if pct > 100 then pct = 100 end
    return pct
end

local function RestoreMasterVolumeIfNeeded()
    if not queueOverlayDidBoostVolume then
        return
    end
    queueOverlayDidBoostVolume = false

    InitSV()
    if not (SetCVar or (C_CVar and C_CVar.SetCVar)) then
        return
    end

    local restorePct = GetRestoreVolumePct()
    local restoreVol = ClampNumber(restorePct / 100, 0, 1) or 0.5
    SetCVarLocal("Sound_MasterVolume", tostring(restoreVol))
end

local function MaybeBoostMasterVolumeOnPop()
    InitSV()
    if not (AutoGossip_Settings and AutoGossip_Settings.queueAcceptBoostVolumeAcc) then
        return
    end
    if not (SetCVar or (C_CVar and C_CVar.SetCVar)) then
        return
    end
    SetCVarLocal("Sound_MasterVolume", "1")
    queueOverlayDidBoostVolume = true
end

local function PlayQueuePopSound()
    if type(PlaySound) ~= "function" then
        return
    end

    local kit = nil
    if SOUNDKIT then
        kit = SOUNDKIT.LFG_READY_CHECK
            or SOUNDKIT.LFG_REWARDS_AVAILABLE
            or SOUNDKIT.UI_GROUP_FINDER_RECEIVE_APPLICATION
            or SOUNDKIT.READY_CHECK
    end

    local function Try(kitOrId)
        if kitOrId == nil then
            return false
        end
        -- Prefer Master, but some clients are picky; fall back to SFX.
        local ok1, played1 = pcall(PlaySound, kitOrId, "Master", false)
        if ok1 and played1 then return true end
        local ok2, played2 = pcall(PlaySound, kitOrId, "SFX", false)
        return (ok2 and played2) and true or false
    end

    if Try(kit) then
        return
    end
    -- Fallback: try a Ready Check-ish sound ID (may vary between clients).
    Try(8960)
end

local function IsCurrentProposalDismissed()
    return (queueOverlayProposalToken or 0) > 0
        and (queueOverlayDismissedToken or 0) == (queueOverlayProposalToken or 0)
end

local function GetRepeatIntervalSeconds()
    InitSV()
    local interval = AutoGossip_Settings and AutoGossip_Settings.queueAcceptRepeatSoundIntervalAcc
    interval = math.floor((tonumber(interval) or 3) + 0.5)
    if interval < 1 then interval = 1 end
    if interval > 30 then interval = 30 end
    return interval
end

local function StopQueueRepeatSoundLoop()
    queueSoundRepeatRunning = false
    queueSoundRepeatId = (queueSoundRepeatId or 0) + 1
    queueSoundRepeatNoProposalTries = 0
end

local function UpdateQueueRepeatSoundLoop()
    InitSV()
    if not (AutoGossip_Settings and AutoGossip_Settings.queueAcceptRepeatSoundAcc) then
        StopQueueRepeatSoundLoop()
        return
    end
    if not QA.IsQueueAcceptEnabled() then
        StopQueueRepeatSoundLoop()
        return
    end
    -- Use the proposal token as the primary source of truth for whether we *should* be repeating.
    -- Some clients fire LFG_PROPOSAL_SHOW slightly before GetLFGProposal()/dialogs are fully ready.
    if (queueOverlayProposalToken or 0) <= 0 then
        StopQueueRepeatSoundLoop()
        return
    end
    if IsCurrentProposalDismissed() then
        StopQueueRepeatSoundLoop()
        return
    end

    if not (C_Timer and type(C_Timer.After) == "function") then
        -- No reliable timer available; fall back to single-shot behavior.
        StopQueueRepeatSoundLoop()
        return
    end

    if queueSoundRepeatRunning then
        return
    end

    queueSoundRepeatRunning = true
    queueSoundRepeatId = (queueSoundRepeatId or 0) + 1
    local id = queueSoundRepeatId

    local function Tick()
        if not queueSoundRepeatRunning or queueSoundRepeatId ~= id then
            return
        end

        InitSV()
        if not (AutoGossip_Settings and AutoGossip_Settings.queueAcceptRepeatSoundAcc) then
            StopQueueRepeatSoundLoop()
            return
        end
        if not QA.IsQueueAcceptEnabled() then
            StopQueueRepeatSoundLoop()
            return
        end
        if (queueOverlayProposalToken or 0) <= 0 then
            StopQueueRepeatSoundLoop()
            return
        end
        if IsCurrentProposalDismissed() then
            StopQueueRepeatSoundLoop()
            return
        end

        -- If proposal state isn't queryable yet, keep the loop alive briefly and retry.
        if not QA.HasActiveLfgProposal() then
            queueSoundRepeatNoProposalTries = (queueSoundRepeatNoProposalTries or 0) + 1
            if queueSoundRepeatNoProposalTries >= 10 then
                StopQueueRepeatSoundLoop()
                return
            end
            C_Timer.After(0.50, Tick)
            return
        end

        queueSoundRepeatNoProposalTries = 0

        PlayQueuePopSound()
        C_Timer.After(GetRepeatIntervalSeconds(), Tick)
    end

    -- Match prior behavior: first repeat fires immediately.
    Tick()
end

function QA.GetQueueAcceptState()
    InitSV()
    local accOn = GetAccEnabled()
    local override = GetCharOverride()

    if override == false then
        return "off"
    end
    if accOn then
        return "acc"
    end
    if override == true then
        return "char"
    end
    return "off"
end

function QA.SetQueueAcceptState(state)
    InitSV()
    if state == "acc" then
        AutoGossip_Settings.queueAcceptAcc = true
        AutoGossip_CharSettings.queueAcceptMode = "acc"
        AutoGossip_CharSettings.queueAcceptEnabledOverride = nil
        return
    end
    if state == "char" then
        AutoGossip_Settings.queueAcceptAcc = false
        AutoGossip_CharSettings.queueAcceptMode = "on"
        AutoGossip_CharSettings.queueAcceptEnabledOverride = true
        return
    end
    AutoGossip_Settings.queueAcceptAcc = false
    AutoGossip_CharSettings.queueAcceptMode = "acc"
    AutoGossip_CharSettings.queueAcceptEnabledOverride = nil
end

function QA.IsQueueAcceptEnabled()
    InitSV()
    return GetEffectiveEnabled() and true or false
end

function QA.HasActiveLfgProposal()
    if type(GetLFGProposal) == "function" then
        local proposalExists = GetLFGProposal()
        return proposalExists and true or false
    end

    local dialog = _G and _G["LFGDungeonReadyDialog"]
    if dialog and dialog.IsShown and dialog:IsShown() then
        return true
    end
    local popup = _G and _G["LFGDungeonReadyPopup"]
    if popup and popup.IsShown and popup:IsShown() then
        return true
    end
    return false
end

local function FindLfgAcceptButton()
    local candidates = {
        _G and _G["LFGDungeonReadyDialogEnterDungeonButton"],
        _G and _G["LFGDungeonReadyDialogAcceptButton"],
        _G and _G["LFGDungeonReadyPopupAcceptButton"],
        _G and _G["LFGDungeonReadyPopupEnterDungeonButton"],
    }

    for _, btn in ipairs(candidates) do
        if btn and btn.IsShown and btn:IsShown() and btn.IsEnabled and btn:IsEnabled() then
            return btn
        end
    end
    return nil
end

local HideQueueOverlay

local function DismissQueueOverlayForCurrentProposal()
    -- Dismiss until the current proposal ends (or a new one starts).
    if (queueOverlayProposalToken or 0) > 0 then
        queueOverlayDismissedToken = queueOverlayProposalToken
    end
    StopQueueRepeatSoundLoop()
    HideQueueOverlay()
end

local function EnsureQueueOverlay()
    if queueOverlayButton then
        return queueOverlayButton
    end

    local b = CreateFrame("Button", "AutoGossipQueueAcceptOverlay", UIParent, "SecureActionButtonTemplate")
    queueOverlayButton = b

    b:SetAllPoints(UIParent)
    b:SetFrameStrata("BACKGROUND")
    b:SetFrameLevel(1)
    b:EnableMouse(true)
    b:RegisterForClicks("AnyUp")

    -- Configure secure attributes once to avoid tainting Blizzard action buttons.
    -- Using a macro here means we don't need to call :SetAttribute() again at runtime.
    b:SetAttribute("type1", "macro")
    b:SetAttribute("macrotext", table.concat({
        "/click LFGDungeonReadyDialogEnterDungeonButton",
        "/click LFGDungeonReadyDialogAcceptButton",
        "/click LFGDungeonReadyPopupAcceptButton",
        "/click LFGDungeonReadyPopupEnterDungeonButton",
    }, "\n"))

    -- PostClick runs after the secure macro has executed.
    -- - Left click: accept, then dismiss overlay for this proposal.
    -- - Right click: dismiss overlay for this proposal.
    b:SetScript("PostClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            DismissQueueOverlayForCurrentProposal()
            return
        end

        -- After accepting, keep hidden until this invite ends.
        DismissQueueOverlayForCurrentProposal()
    end)

    b:SetScript("OnUpdate", function(self, elapsed)
        if not (self and self.IsShown and self:IsShown()) then
            return
        end

        queueOverlayWatchdogElapsed = (queueOverlayWatchdogElapsed or 0) + (elapsed or 0)
        if queueOverlayWatchdogElapsed < 0.20 then
            return
        end
        queueOverlayWatchdogElapsed = 0

        if not QA.IsQueueAcceptEnabled() then
            HideQueueOverlay()
            return
        end
        if not QA.HasActiveLfgProposal() then
            HideQueueOverlay()
            return
        end

        -- Optional: repeat queue sound while the overlay is shown.
        InitSV()
        if AutoGossip_Settings and AutoGossip_Settings.queueAcceptRepeatSoundAcc then
            local dismissed = (queueOverlayProposalToken or 0) > 0
                and (queueOverlayDismissedToken or 0) == (queueOverlayProposalToken or 0)
            if not dismissed then
                local now = GetTimeNow()
                local nextAt = tonumber(queueOverlayRepeatNextAt) or 0
                if nextAt <= 0 then
                    queueOverlayRepeatNextAt = now
                    nextAt = now
                end
                if now >= nextAt then
                    PlayQueuePopSound()
                    local interval = AutoGossip_Settings.queueAcceptRepeatSoundIntervalAcc
                    interval = math.floor((tonumber(interval) or 3) + 0.5)
                    if interval < 1 then interval = 1 end
                    if interval > 30 then interval = 30 end
                    queueOverlayRepeatNextAt = now + interval
                end
            end
        else
            queueOverlayRepeatNextAt = 0
        end

        local acceptButton = FindLfgAcceptButton()
        if not acceptButton then
            HideQueueOverlay()
            return
        end
    end)
    b:Hide()

    local hint = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    queueOverlayHint = hint
    hint:SetAllPoints(UIParent)
    hint:SetFrameStrata("FULLSCREEN_DIALOG")
    hint:EnableMouse(false)

    hint:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    hint:SetBackdropColor(0, 0, 0, 0.35)
    hint:SetBackdropBorderColor(1, 0.82, 0, 0.95)

    local fs = hint:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOP", UIParent, "TOP", 0, -140)
    fs:SetText("|cff00ccff[FGO]|r Queue ready — left click the world to accept (right click to dismiss)")
    hint.text = fs

    do
        local ag = hint:CreateAnimationGroup()
        ag:SetLooping("BOUNCE")

        local a1 = ag:CreateAnimation("Alpha")
        a1:SetFromAlpha(0.15)
        a1:SetToAlpha(1.0)
        a1:SetDuration(0.35)
        a1:SetSmoothing("OUT")

        local a2 = ag:CreateAnimation("Alpha")
        a2:SetFromAlpha(1.0)
        a2:SetToAlpha(0.15)
        a2:SetDuration(0.35)
        a2:SetSmoothing("IN")
        a2:SetOrder(2)

        hint.flash = ag
    end

    hint:Hide()

    return b
end

HideQueueOverlay = function()
    if not (queueOverlayButton and queueOverlayButton.IsShown and queueOverlayButton:IsShown()) then
        queueOverlayPendingHide = false
        if queueOverlayHint and queueOverlayHint.Hide then
            queueOverlayHint:Hide()
        end
        RestoreMasterVolumeIfNeeded()
        queueOverlayRepeatNextAt = 0
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        queueOverlayPendingHide = true
        return
    end

    queueOverlayButton:Hide()
    if queueOverlayHint and queueOverlayHint.flash and queueOverlayHint.flash.IsPlaying and queueOverlayHint.flash:IsPlaying() then
        queueOverlayHint.flash:Stop()
    end
    if queueOverlayHint and queueOverlayHint.Hide then
        queueOverlayHint:Hide()
    end
    queueOverlayPendingHide = false
    RestoreMasterVolumeIfNeeded()
    queueOverlayRepeatNextAt = 0
end

function QA.HideQueueOverlay()
    return HideQueueOverlay()
end

function QA.ShowQueueOverlayIfNeeded()
    local now = GetTimeNow()
    if (queueOverlaySuppressUntil or 0) > now then
        return
    end

    if (queueOverlayProposalToken or 0) > 0 and (queueOverlayDismissedToken or 0) == (queueOverlayProposalToken or 0) then
        return
    end

    if not QA.IsQueueAcceptEnabled() then
        HideQueueOverlay()
        StopQueueRepeatSoundLoop()
        return
    end
    if not QA.HasActiveLfgProposal() then
        HideQueueOverlay()
        queueOverlayProposalToken = 0
        queueOverlayDismissedToken = 0
        StopQueueRepeatSoundLoop()
        return
    end

    -- Safety: if we missed the proposal events (e.g. /reload mid-proposal), seed a token
    -- so the repeat-sound loop can still start.
    if (queueOverlayProposalToken or 0) <= 0 then
        queueOverlayProposalToken = 1
        queueOverlayDismissedToken = 0
    end

    -- Repeat sound is driven by the overlay OnUpdate (not by a background ticker).
    InitSV()
    StopQueueRepeatSoundLoop()
    if not (AutoGossip_Settings and AutoGossip_Settings.queueAcceptRepeatSoundAcc) then
        queueOverlayRepeatNextAt = 0
    end

    if InCombatLockdown and InCombatLockdown() then
        return
    end

    local acceptButton = FindLfgAcceptButton()
    if not acceptButton then
        HideQueueOverlay()
        return
    end

    local overlay = EnsureQueueOverlay()
    overlay:Show()
    if queueOverlayHint and queueOverlayHint.Show then
        queueOverlayHint:Show()
        if queueOverlayHint.flash and queueOverlayHint.flash.Play then
            queueOverlayHint.flash:Play()
        end
    end
end

function QA.OnPlayerRegenEnabled()
    InitSV()
    if queueOverlayPendingHide then
        HideQueueOverlay()
    end
    QA.ShowQueueOverlayIfNeeded()
end

function QA.OnLfgProposalShow()
    -- Start a new proposal session.
    queueOverlayProposalToken = (queueOverlayProposalToken or 0) + 1
    queueOverlayDismissedToken = 0
    InitSV()

    if QA.IsQueueAcceptEnabled() then
        MaybeBoostMasterVolumeOnPop()
    end

    if AutoGossip_Settings and AutoGossip_Settings.queueAcceptRepeatSoundAcc then
        queueOverlayRepeatNextAt = GetTimeNow()
    else
        queueOverlayRepeatNextAt = 0
    end
    QA.ShowQueueOverlayIfNeeded()
end

function QA.OnLfgProposalUpdate()
    -- Some edge cases (e.g., /reload mid-proposal) may not fire SHOW again.
    if (queueOverlayProposalToken or 0) == 0 and QA.HasActiveLfgProposal() then
        queueOverlayProposalToken = 1
        queueOverlayDismissedToken = 0
    end
    InitSV()

    if AutoGossip_Settings and AutoGossip_Settings.queueAcceptRepeatSoundAcc then
        if (queueOverlayRepeatNextAt or 0) <= 0 then
            queueOverlayRepeatNextAt = GetTimeNow()
        end
    else
        queueOverlayRepeatNextAt = 0
    end
    QA.ShowQueueOverlayIfNeeded()
end

function QA.OnLfgProposalEnded()
    queueOverlayProposalToken = 0
    queueOverlayDismissedToken = 0
    HideQueueOverlay()
    RestoreMasterVolumeIfNeeded()
    queueOverlayRepeatNextAt = 0
    StopQueueRepeatSoundLoop()
end
