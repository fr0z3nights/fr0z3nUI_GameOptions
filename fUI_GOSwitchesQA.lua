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

local function GetTimeNow()
    return (GetTime and GetTime()) or 0
end

function QA.GetQueueAcceptState()
    InitSV()
    if AutoGossip_Settings and AutoGossip_Settings.queueAcceptAcc then
        return "acc"
    end
    if AutoGossip_CharSettings and AutoGossip_CharSettings.queueAcceptMode == "on" then
        return "char"
    end
    return "off"
end

function QA.SetQueueAcceptState(state)
    InitSV()
    if state == "acc" then
        AutoGossip_Settings.queueAcceptAcc = true
        AutoGossip_CharSettings.queueAcceptMode = "acc"
        return
    end
    if state == "char" then
        AutoGossip_Settings.queueAcceptAcc = false
        AutoGossip_CharSettings.queueAcceptMode = "on"
        return
    end
    AutoGossip_Settings.queueAcceptAcc = false
    AutoGossip_CharSettings.queueAcceptMode = "acc"
end

function QA.IsQueueAcceptEnabled()
    return QA.GetQueueAcceptState() ~= "off"
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
        return
    end
    if not QA.HasActiveLfgProposal() then
        HideQueueOverlay()
        queueOverlayProposalToken = 0
        queueOverlayDismissedToken = 0
        return
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
    QA.ShowQueueOverlayIfNeeded()
end

function QA.OnLfgProposalUpdate()
    -- Some edge cases (e.g., /reload mid-proposal) may not fire SHOW again.
    if (queueOverlayProposalToken or 0) == 0 and QA.HasActiveLfgProposal() then
        queueOverlayProposalToken = 1
        queueOverlayDismissedToken = 0
    end
    InitSV()
    QA.ShowQueueOverlayIfNeeded()
end

function QA.OnLfgProposalEnded()
    queueOverlayProposalToken = 0
    queueOverlayDismissedToken = 0
    HideQueueOverlay()
end
