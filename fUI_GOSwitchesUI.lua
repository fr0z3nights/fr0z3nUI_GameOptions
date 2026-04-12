---@diagnostic disable: undefined-global

local _, ns = ...
ns = ns or {}

-- Switches tab (formerly "Toggles") UI.
-- Extracted from fr0z3nUI_GameOptions.lua to keep the main file slimmer.

function ns.SwitchesUI_Build(frame, panel, helpers)
    if not panel then
        return function() end
    end

    helpers = helpers or {}

    local InitSV = helpers.InitSV
        or (ns and ns._InitSV)
        or function() end

    local ShowQueueOverlayIfNeeded = helpers.ShowQueueOverlayIfNeeded

    local EnsureChromieIndicator = helpers.EnsureChromieIndicator
    local UpdateChromieIndicator = helpers.UpdateChromieIndicator
    local ForceHideChromieIndicator = helpers.ForceHideChromieIndicator
    local OpenChromieConfigPopup = helpers.OpenChromieConfigPopup
    local GetChromieConfigPopupFrame = helpers.GetChromieConfigPopupFrame

    local EnsureReloadFloatButton = helpers.EnsureReloadFloatButton
    local UpdateReloadFloatButton = helpers.UpdateReloadFloatButton

    local function HideIfShown(f)
        if f and f.IsShown and f:IsShown() then
            if f.Hide then
                f:Hide()
            end
        end
    end

    local function CloseAllConfigPopouts(exceptFrame)
        local pet = nil
        if ns and ns.SwitchesBP and ns.SwitchesBP.GetPetWalkConfigPopupFrame then
            pet = ns.SwitchesBP.GetPetWalkConfigPopupFrame()
        end
        pet = pet or (_G and rawget(_G, "FGO_PetWalkConfigPopup"))

        local mu = nil
        if ns and ns.SwitchesMU and ns.SwitchesMU.GetMountUpConfigPopupFrame then
            mu = ns.SwitchesMU.GetMountUpConfigPopupFrame()
        end
        mu = mu or (_G and rawget(_G, "FGO_MountUpConfigPopup"))

        local chromie = nil
        if GetChromieConfigPopupFrame then
            chromie = GetChromieConfigPopupFrame()
        end
        chromie = chromie or (_G and rawget(_G, "FGO_ChromieConfigPopup"))

        local safari = (_G and rawget(_G, "FGO_SafariPopout"))
        local fishing = nil
        if ns and ns.SwitchesFB and ns.SwitchesFB.GetFishingConfigPopupFrame then
            fishing = ns.SwitchesFB.GetFishingConfigPopupFrame()
        end
        fishing = fishing or (_G and rawget(_G, "FGO_FishingPopout"))
        local queueAccept = (_G and rawget(_G, "FGO_QueueAcceptPopout"))

        for _, f in ipairs({ pet, mu, chromie, safari, fishing, queueAccept }) do
            if f and f ~= exceptFrame then
                HideIfShown(f)
            end
        end
    end

    local BTN_W, BTN_H = 260, 22
    -- Move both columns up by 1.0 button height (net: down 0.5 from the previous +1.5).
    local START_Y = -64 + math.floor(BTN_H + 0.5)
    local GAP_Y = 10

    -- Split screen (figuratively): TooltipX on the left, everything else on the right.
    local COL_GAP = 40
    local RIGHT_X = math.floor((BTN_W / 2) + COL_GAP + 0.5)
    local LEFT_X = -RIGHT_X

    local SEG_GAP = 2
    local SEG_W = math.floor((BTN_W - (SEG_GAP * 2)) / 3)
    local SEG_W3 = BTN_W - (SEG_W * 2) - (SEG_GAP * 2)

    local function SetAcc2StateText(btn, label, enabled)
        if enabled then
            btn:SetText(label .. ": |cff00ccffON ACC|r")
        else
            btn:SetText(label .. ": |cffff0000OFF ACC|r")
        end
    end

    local function SetGreenGrey(btn, label, enabled)
        if enabled then
            btn:SetText("|cff00ff00" .. label .. "|r")
        else
            btn:SetText("|cff888888" .. label .. "|r")
        end
    end

    local function SetTriState(btn, label, state)
        -- Spec: Green / Orange / Grey = Off Acc / On Acc / On Char
        if state == "acc" then
            btn:SetText("|cffff9900" .. label .. "|r")
        elseif state == "char" then
            btn:SetText("|cff888888" .. label .. "|r")
        else
            btn:SetText("|cff00ff00" .. label .. "|r")
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

    -- Tooltip Border
    local btnBorder = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnBorder:SetSize(BTN_W, BTN_H)
    btnBorder:SetPoint("TOP", panel, "TOP", LEFT_X, START_Y)
    if frame then
        frame.btnBorder = btnBorder
    end

    local function UpdateBorderButton()
        InitSV()
        local hidden = (AutoGossip_Settings and AutoGossip_Settings.hideTooltipBorderAcc) and true or false
        if hidden then
            btnBorder:SetText("Tooltip Border: |cff00ccffHIDE ACC|r")
        else
            btnBorder:SetText("Tooltip Border: |cffff0000OFF ACC|r")
        end
    end

    btnBorder:SetScript("OnClick", function()
        InitSV()
        AutoGossip_Settings.hideTooltipBorderAcc = not (AutoGossip_Settings.hideTooltipBorderAcc and true or false)
        if ns and ns.ApplyTooltipBorderSetting then
            ns.ApplyTooltipBorderSetting(true)
        end
        UpdateBorderButton()
    end)
    btnBorder:SetScript("OnEnter", function()
        if GameTooltip then
            GameTooltip:SetOwner(btnBorder, "ANCHOR_RIGHT")
            GameTooltip:SetText("Tooltip Border")
            GameTooltip:AddLine("HIDE ACC: hide tooltip borders.", 1, 1, 1, true)
            GameTooltip:AddLine("OFF ACC: stop forcing hide (does not restore).", 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    btnBorder:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)

    -- Queue Accept (3-button row: Queue / Enable / Config)
    local queueAcceptPopout = nil
    local UpdateQueueAcceptSegments = nil

    local function ClampInt(v, minV, maxV, defaultV)
        v = tonumber(v)
        if v == nil then
            v = defaultV
        end
        v = math.floor(v + 0.5)
        if minV ~= nil and v < minV then v = minV end
        if maxV ~= nil and v > maxV then v = maxV end
        return v
    end

    local function GetQueueAcceptAccEnabled()
        InitSV()
        return (AutoGossip_Settings and AutoGossip_Settings.queueAcceptAcc) and true or false
    end

    local function GetQueueAcceptCharOverride()
        InitSV()
        if not AutoGossip_CharSettings then
            return nil
        end
        local v = AutoGossip_CharSettings.queueAcceptEnabledOverride
        if type(v) == "boolean" then
            return v
        end
        return nil
    end

    local function GetQueueAcceptEffectiveEnabled()
        local override = GetQueueAcceptCharOverride()
        if override ~= nil then
            return override
        end
        return GetQueueAcceptAccEnabled()
    end

    local function EnsureQueueAcceptPopout()
        if queueAcceptPopout and queueAcceptPopout.SetPoint then
            return queueAcceptPopout
        end

        local popout = CreateFrame("Frame", nil, panel, "BackdropTemplate")
        if not popout then
            return nil
        end
        queueAcceptPopout = popout

        popout:SetSize(360, 140)
        popout:ClearAllPoints()
        popout:SetPoint("TOPLEFT", panel, "TOPRIGHT", 10, 0)
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
        if _G then
            _G.FGO_QueueAcceptPopout = popout
        end

        popout:SetScript("OnShow", function()
            if popout and popout._fgoUpdate then
                popout._fgoUpdate()
            end
            if UpdateQueueAcceptSegments then
                UpdateQueueAcceptSegments()
            end
        end)
        popout:SetScript("OnHide", function()
            if UpdateQueueAcceptSegments then
                UpdateQueueAcceptSegments()
            end
        end)

        local close = CreateFrame("Button", nil, popout, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", popout, "TOPRIGHT", -6, -6)

        local title = popout:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOPLEFT", popout, "TOPLEFT", 12, -10)
        title:SetText("Queue Accept")
        title:SetTextColor(1, 0.82, 0, 1)

        local hint = popout:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
        hint:SetText("Sound/volume behavior while a queue is ready")

        local row1 = CreateFrame("Frame", nil, popout)
        row1:SetSize(320, BTN_H)
        row1:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -10)

        local btnBoost = CreateFrame("Button", nil, row1, "UIPanelButtonTemplate")
        btnBoost:SetSize(SEG_W + 20, BTN_H)
        btnBoost:SetPoint("LEFT", row1, "LEFT", 12, 0)

        local lblRestore = row1:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        lblRestore:SetPoint("LEFT", btnBoost, "RIGHT", 8, 0)
        lblRestore:SetText("Restore %")

        local ebRestore = MakeNumericBox(row1, 40, BTN_H)
        ebRestore:SetPoint("LEFT", lblRestore, "RIGHT", 6, 0)

        local row2 = CreateFrame("Frame", nil, popout)
        row2:SetSize(320, BTN_H)
        row2:SetPoint("TOPLEFT", row1, "BOTTOMLEFT", 0, -10)

        local btnRepeat = CreateFrame("Button", nil, row2, "UIPanelButtonTemplate")
        btnRepeat:SetSize(SEG_W + 20, BTN_H)
        btnRepeat:SetPoint("LEFT", row2, "LEFT", 12, 0)

        local lblEvery = row2:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        lblEvery:SetPoint("LEFT", btnRepeat, "RIGHT", 8, 0)
        lblEvery:SetText("Every")

        local ebEvery = MakeNumericBox(row2, 40, BTN_H)
        ebEvery:SetPoint("LEFT", lblEvery, "RIGHT", 6, 0)

        local lblSec = row2:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        lblSec:SetPoint("LEFT", ebEvery, "RIGHT", 6, 0)
        lblSec:SetText("sec")

        local function UpdateQueueAcceptPopout()
            InitSV()
            local boost = (AutoGossip_Settings and AutoGossip_Settings.queueAcceptBoostVolumeAcc) and true or false
            local restorePct = ClampInt(AutoGossip_Settings and AutoGossip_Settings.queueAcceptRestoreVolumePctAcc, 0, 100, 50)
            local repeatSound = (AutoGossip_Settings and AutoGossip_Settings.queueAcceptRepeatSoundAcc) and true or false
            local every = ClampInt(AutoGossip_Settings and AutoGossip_Settings.queueAcceptRepeatSoundIntervalAcc, 1, 30, 3)

            SetGreenGrey(btnBoost, "Boost Vol", boost)
            SetGreenGrey(btnRepeat, "Repeat Sound", repeatSound)
            if ebRestore and ebRestore.SetText then
                ebRestore:SetText(tostring(restorePct))
            end
            if ebEvery and ebEvery.SetText then
                ebEvery:SetText(tostring(every))
            end
        end

        btnBoost:SetScript("OnClick", function()
            InitSV()
            AutoGossip_Settings.queueAcceptBoostVolumeAcc = not (AutoGossip_Settings.queueAcceptBoostVolumeAcc and true or false)
            UpdateQueueAcceptPopout()
        end)
        btnBoost:SetScript("OnEnter", function()
            if GameTooltip then
                GameTooltip:SetOwner(btnBoost, "ANCHOR_RIGHT")
                GameTooltip:SetText("Boost Vol")
                GameTooltip:AddLine("If ON, sets master volume to 100% when a queue pops.", 1, 1, 1, true)
                GameTooltip:AddLine("When the queue ends/dismisses, restores to the configured %.", 1, 1, 1, true)
                GameTooltip:Show()
            end
        end)
        btnBoost:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

        btnRepeat:SetScript("OnClick", function()
            InitSV()
            AutoGossip_Settings.queueAcceptRepeatSoundAcc = not (AutoGossip_Settings.queueAcceptRepeatSoundAcc and true or false)
            UpdateQueueAcceptPopout()
            if ShowQueueOverlayIfNeeded then
                ShowQueueOverlayIfNeeded()
            end
        end)
        btnRepeat:SetScript("OnEnter", function()
            if GameTooltip then
                GameTooltip:SetOwner(btnRepeat, "ANCHOR_RIGHT")
                GameTooltip:SetText("Repeat Sound")
                GameTooltip:AddLine("If ON, repeats a queue-ready sound while a proposal is active.", 1, 1, 1, true)
                GameTooltip:AddLine("Uses the configured interval (sec).", 1, 1, 1, true)
                GameTooltip:Show()
            end
        end)
        btnRepeat:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

        local function SaveRestorePct()
            InitSV()
            local v = ClampInt(ebRestore and ebRestore.GetText and ebRestore:GetText(), 0, 100, 50)
            AutoGossip_Settings.queueAcceptRestoreVolumePctAcc = v
            UpdateQueueAcceptPopout()
        end
        ebRestore:SetScript("OnEnterPressed", function(self)
            SaveRestorePct()
            if self and self.ClearFocus then self:ClearFocus() end
        end)
        ebRestore:SetScript("OnEditFocusLost", SaveRestorePct)

        local function SaveEvery()
            InitSV()
            local v = ClampInt(ebEvery and ebEvery.GetText and ebEvery:GetText(), 1, 30, 3)
            AutoGossip_Settings.queueAcceptRepeatSoundIntervalAcc = v
            UpdateQueueAcceptPopout()
            if ShowQueueOverlayIfNeeded then
                ShowQueueOverlayIfNeeded()
            end
        end
        ebEvery:SetScript("OnEnterPressed", function(self)
            SaveEvery()
            if self and self.ClearFocus then self:ClearFocus() end
        end)
        ebEvery:SetScript("OnEditFocusLost", SaveEvery)

        popout._fgoUpdate = UpdateQueueAcceptPopout
        UpdateQueueAcceptPopout()
        return popout
    end

    local queueAcceptSegContainer = CreateFrame("Frame", nil, panel)
    queueAcceptSegContainer:SetSize(BTN_W, BTN_H)
    queueAcceptSegContainer:SetPoint("TOP", panel, "TOP", RIGHT_X, START_Y)
    if frame then
        frame.queueAcceptSegContainer = queueAcceptSegContainer
    end

    local segQueueAcceptQueue = CreateFrame("Button", nil, queueAcceptSegContainer, "UIPanelButtonTemplate")
    segQueueAcceptQueue:SetSize(SEG_W, BTN_H)
    segQueueAcceptQueue:SetPoint("LEFT", queueAcceptSegContainer, "LEFT", 0, 0)

    local segQueueAcceptEnable = CreateFrame("Button", nil, queueAcceptSegContainer, "UIPanelButtonTemplate")
    segQueueAcceptEnable:SetSize(SEG_W, BTN_H)
    segQueueAcceptEnable:SetPoint("LEFT", segQueueAcceptQueue, "RIGHT", SEG_GAP, 0)

    local segQueueAcceptConfig = CreateFrame("Button", nil, queueAcceptSegContainer, "UIPanelButtonTemplate")
    segQueueAcceptConfig:SetSize(SEG_W3, BTN_H)
    segQueueAcceptConfig:SetPoint("LEFT", segQueueAcceptEnable, "RIGHT", SEG_GAP, 0)

    UpdateQueueAcceptSegments = function()
        InitSV()
        local accOn = GetQueueAcceptAccEnabled()
        local effectiveOn = GetQueueAcceptEffectiveEnabled()
        local configOpen = (queueAcceptPopout and queueAcceptPopout.IsShown and queueAcceptPopout:IsShown()) and true or false

        SetGreenGrey(segQueueAcceptQueue, "Queue", accOn)
        SetGreenGrey(segQueueAcceptEnable, "Enable", effectiveOn)
        SetGreenGrey(segQueueAcceptConfig, "Config", configOpen)
    end

    segQueueAcceptQueue:SetScript("OnClick", function()
        InitSV()
        AutoGossip_Settings.queueAcceptAcc = not (AutoGossip_Settings.queueAcceptAcc and true or false)
        UpdateQueueAcceptSegments()
        if ShowQueueOverlayIfNeeded then
            ShowQueueOverlayIfNeeded()
        end
    end)
    segQueueAcceptQueue:SetScript("OnEnter", function()
        if GameTooltip then
            GameTooltip:SetOwner(segQueueAcceptQueue, "ANCHOR_RIGHT")
            GameTooltip:SetText("Queue")
            GameTooltip:AddLine("Account default for Queue Accept.", 1, 1, 1, true)
            GameTooltip:AddLine("If ON, Queue Accept is enabled unless a character override disables it.", 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    segQueueAcceptQueue:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    segQueueAcceptEnable:SetScript("OnClick", function()
        InitSV()
        local effective = GetQueueAcceptEffectiveEnabled()
        AutoGossip_CharSettings.queueAcceptEnabledOverride = (not effective) and true or false
        UpdateQueueAcceptSegments()
        if ShowQueueOverlayIfNeeded then
            ShowQueueOverlayIfNeeded()
        end
    end)
    segQueueAcceptEnable:SetScript("OnEnter", function()
        if GameTooltip then
            GameTooltip:SetOwner(segQueueAcceptEnable, "ANCHOR_RIGHT")
            GameTooltip:SetText("Enable")
            GameTooltip:AddLine("Per-character override.", 1, 1, 1, true)
            GameTooltip:AddLine("Click to toggle effective enable for this character.", 1, 1, 1, true)
            GameTooltip:AddLine("When a dungeon queue pops, clicking the world will accept.", 1, 1, 1, true)
            GameTooltip:AddLine("Clicks on other UI should not accept.", 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    segQueueAcceptEnable:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    segQueueAcceptConfig:SetScript("OnClick", function()
        local p = EnsureQueueAcceptPopout()
        if p and p.IsShown and p:IsShown() then
            p:Hide()
            UpdateQueueAcceptSegments()
            return
        end

        CloseAllConfigPopouts(p)
        if p and p.Show then
            p:Show()
            if p._fgoUpdate then
                p._fgoUpdate()
            end
        end
        UpdateQueueAcceptSegments()
    end)
    segQueueAcceptConfig:SetScript("OnEnter", function()
        if GameTooltip then
            GameTooltip:SetOwner(segQueueAcceptConfig, "ANCHOR_RIGHT")
            GameTooltip:SetText("Config")
            GameTooltip:AddLine("Open Queue Accept sound/volume configuration.", 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    segQueueAcceptConfig:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    -- Row: PopUp / PopDbg / Reload (below Queue Accept)
    local popupRow = CreateFrame("Frame", nil, panel)
    popupRow:SetSize(BTN_W, BTN_H)
    popupRow:SetPoint("TOP", queueAcceptSegContainer, "BOTTOM", 0, -GAP_Y)
    if frame then
        frame.popupRow = popupRow
    end

    local btnPopUp = CreateFrame("Button", nil, popupRow, "UIPanelButtonTemplate")
    btnPopUp:SetSize(SEG_W, BTN_H)
    btnPopUp:SetPoint("LEFT", popupRow, "LEFT", 0, 0)
    if frame then
        frame.btnPopUp = btnPopUp
    end

    local btnPopDbg = CreateFrame("Button", nil, popupRow, "UIPanelButtonTemplate")
    btnPopDbg:SetSize(SEG_W, BTN_H)
    btnPopDbg:SetPoint("LEFT", btnPopUp, "RIGHT", SEG_GAP, 0)
    if frame then
        frame.btnPopDbg = btnPopDbg
    end

    local btnReload = CreateFrame("Button", nil, popupRow, "UIPanelButtonTemplate")
    btnReload:SetSize(SEG_W3, BTN_H)
    btnReload:SetPoint("LEFT", btnPopDbg, "RIGHT", SEG_GAP, 0)
    if frame then
        frame.btnReload = btnReload
    end

    local ebReloadSize = MakeNumericBox(popupRow, 22, BTN_H)
    ebReloadSize:SetPoint("LEFT", btnReload, "RIGHT", 2, 0)
    if frame then
        frame.ebReloadSize = ebReloadSize
    end

    local function UpdatePopUpRow()
        InitSV()
        local popOn = (AutoGossip_Settings and AutoGossip_Settings.autoAcceptPetPrepareAcc) and true or false
        local dbgOn = (AutoGossip_Settings and AutoGossip_Settings.debugPetPopupsAcc) and true or false
        local reloadOn = (AutoGossip_UI and AutoGossip_UI.reloadFloatEnabled) and true or false
        local size = (AutoGossip_UI and tonumber(AutoGossip_UI.reloadFloatTextSize)) or 12

        SetGreenGrey(btnPopUp, "PopUp", popOn)
        SetGreenGrey(btnPopDbg, "PopDbg", dbgOn)
        SetGreenGrey(btnReload, "Reload", reloadOn)
        if ebReloadSize and ebReloadSize.SetText then
            ebReloadSize:SetText(tostring(math.floor((tonumber(size) or 12) + 0.5)))
        end
    end

    btnPopUp:SetScript("OnClick", function()
        InitSV()
        AutoGossip_Settings.autoAcceptPetPrepareAcc = not (AutoGossip_Settings.autoAcceptPetPrepareAcc and true or false)
        UpdatePopUpRow()
    end)
    btnPopUp:SetScript("OnEnter", function()
        if GameTooltip then
            GameTooltip:SetOwner(btnPopUp, "ANCHOR_RIGHT")
            GameTooltip:SetText("PopUp")
            GameTooltip:AddLine("Green: auto-accept the pet battle confirmation popup.", 1, 1, 1, true)
            GameTooltip:AddLine("Grey: do nothing.", 1, 1, 1, true)
            GameTooltip:AddLine("Macro: /fgo petbattle (forces ON; no prints).", 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    btnPopUp:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    btnPopDbg:SetScript("OnClick", function()
        InitSV()
        AutoGossip_Settings.debugPetPopupsAcc = not (AutoGossip_Settings.debugPetPopupsAcc and true or false)
        UpdatePopUpRow()
    end)
    btnPopDbg:SetScript("OnEnter", function()
        if GameTooltip then
            GameTooltip:SetOwner(btnPopDbg, "ANCHOR_RIGHT")
            GameTooltip:SetText("PopDbg")
            GameTooltip:AddLine("Green: log StaticPopup dialogs (name/text/args).", 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    btnPopDbg:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    btnReload:RegisterForClicks("LeftButtonUp")
    btnReload:SetScript("OnClick", function()
        InitSV()
        AutoGossip_UI.reloadFloatEnabled = not (AutoGossip_UI.reloadFloatEnabled and true or false)
        UpdatePopUpRow()
        if UpdateReloadFloatButton then
            UpdateReloadFloatButton()
        elseif EnsureReloadFloatButton then
            EnsureReloadFloatButton()
        end
    end)
    btnReload:SetScript("OnEnter", function()
        if GameTooltip then
            GameTooltip:SetOwner(btnReload, "ANCHOR_RIGHT")
            GameTooltip:SetText("Reload")
            GameTooltip:AddLine("Green: show the floating Reload UI button.", 1, 1, 1, true)
            GameTooltip:AddLine("Grey: hide it.", 1, 1, 1, true)
            GameTooltip:AddLine("Text size: edit the box to the right.", 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    btnReload:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    ebReloadSize:SetScript("OnEnterPressed", function(self)
        InitSV()
        local v = tonumber(self:GetText())
        if not v then
            self:ClearFocus()
            UpdatePopUpRow()
            return
        end
        if v < 8 then v = 8 end
        if v > 24 then v = 24 end
        AutoGossip_UI.reloadFloatTextSize = v
        self:ClearFocus()
        UpdatePopUpRow()
        if UpdateReloadFloatButton then
            UpdateReloadFloatButton()
        elseif EnsureReloadFloatButton then
            EnsureReloadFloatButton()
        end
    end)
    ebReloadSize:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        UpdatePopUpRow()
    end)

    -- Row: Action / NPC Name / Tutorial (below popup line)
    local actionRow = CreateFrame("Frame", nil, panel)
    actionRow:SetSize(BTN_W, BTN_H)
    actionRow:SetPoint("TOP", popupRow, "BOTTOM", 0, -GAP_Y)
    if frame then
        frame.actionRow = actionRow
    end

    local btnAction = CreateFrame("Button", nil, actionRow, "UIPanelButtonTemplate")
    btnAction:SetSize(SEG_W, BTN_H)
    btnAction:SetPoint("LEFT", actionRow, "LEFT", 0, 0)
    if frame then
        frame.btnAction = btnAction
    end

    local btnNPCName = CreateFrame("Button", nil, actionRow, "UIPanelButtonTemplate")
    btnNPCName:SetSize(SEG_W, BTN_H)
    btnNPCName:SetPoint("LEFT", btnAction, "RIGHT", SEG_GAP, 0)
    if frame then
        frame.btnNPCName = btnNPCName
    end

    local btnTutorial = CreateFrame("Button", nil, actionRow, "UIPanelButtonTemplate")
    btnTutorial:SetSize(SEG_W, BTN_H)
    btnTutorial:SetPoint("LEFT", btnNPCName, "RIGHT", SEG_GAP, 0)
    if frame then
        frame.btnTutorial = btnTutorial
    end

    local function GetActionState()
        if ns and ns.GetActionUseKeyDownState then
            return ns.GetActionUseKeyDownState()
        end
        return "off"
    end

    local function GetNPCNameState()
        if ns and ns.GetNPCNameplatesState then
            return ns.GetNPCNameplatesState()
        end
        return "off"
    end

    local function UpdateActionRow()
        InitSV()
        SetTriState(btnAction, "Action", GetActionState())
        SetTriState(btnNPCName, "NPC Name", GetNPCNameState())

        local hideTutorials = not ((AutoGossip_Settings and AutoGossip_Settings.tutorialEnabledAcc) and true or false)
        SetGreenGrey(btnTutorial, "Tutorial", hideTutorials)
    end

    local function Tooltip_RefreshIfOwnedBy(btn, buildFn)
        if not (GameTooltip and GameTooltip.GetOwner and GameTooltip.IsShown) then
            return
        end
        if GameTooltip:GetOwner() ~= btn then
            return
        end
        if not GameTooltip:IsShown() then
            return
        end
        if type(buildFn) == "function" then
            buildFn()
        end
    end

    local function ShowActionTooltip()
        if not GameTooltip then return end
        GameTooltip:SetOwner(btnAction, "ANCHOR_RIGHT")
        GameTooltip:SetText("Action")
        GameTooltip:AddLine("Green: OFF ACC", 1, 1, 1, true)
        GameTooltip:AddLine("Orange: ON ACC", 1, 1, 1, true)
        GameTooltip:AddLine("Grey: ON CHAR", 1, 1, 1, true)
        local st = GetActionState()
        if st == "acc" then
            GameTooltip:AddLine("State: ON ACC", 1, 1, 1, true)
        elseif st == "char" then
            GameTooltip:AddLine("State: ON CHAR", 1, 1, 1, true)
        else
            GameTooltip:AddLine("State: OFF ACC", 1, 1, 1, true)
        end
        if GetCVar then
            GameTooltip:AddLine("Current CVar: ActionButtonUseKeyDown = " .. tostring(GetCVar("ActionButtonUseKeyDown")), 1, 1, 1, true)
        end
        GameTooltip:Show()
    end

    local function ShowNPCTooltip()
        if not GameTooltip then return end
        GameTooltip:SetOwner(btnNPCName, "ANCHOR_RIGHT")
        GameTooltip:SetText("NPC Name")
        GameTooltip:AddLine("Green: OFF ACC", 1, 1, 1, true)
        GameTooltip:AddLine("Orange: ON ACC", 1, 1, 1, true)
        GameTooltip:AddLine("Grey: ON CHAR", 1, 1, 1, true)
        local st = GetNPCNameState()
        if st == "acc" then
            GameTooltip:AddLine("State: ON ACC", 1, 1, 1, true)
        elseif st == "char" then
            GameTooltip:AddLine("State: ON CHAR", 1, 1, 1, true)
        else
            GameTooltip:AddLine("State: OFF ACC", 1, 1, 1, true)
        end
        if ns and ns.GetFriendlyNPCNameplatesSafe then
            local curv = ns.GetFriendlyNPCNameplatesSafe()
            if curv ~= nil then
                GameTooltip:AddLine("Current CVar: " .. (curv and "ON" or "OFF"), 1, 1, 1, true)
            end
        end
        GameTooltip:Show()
    end

    btnAction:SetScript("OnClick", function()
        local cur = GetActionState()
        local nextState = "off"
        if cur == "off" then
            nextState = "acc"
        elseif cur == "acc" then
            nextState = "char"
        else
            nextState = "off"
        end
        if ns and ns.SetActionUseKeyDownState then
            ns.SetActionUseKeyDownState(nextState)
        end
        UpdateActionRow()
        Tooltip_RefreshIfOwnedBy(btnAction, ShowActionTooltip)
    end)
    btnAction:SetScript("OnEnter", function()
        ShowActionTooltip()
    end)
    btnAction:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    btnNPCName:SetScript("OnClick", function()
        local cur = GetNPCNameState()
        local nextState = "off"
        if cur == "off" then
            nextState = "acc"
        elseif cur == "acc" then
            nextState = "char"
        else
            nextState = "off"
        end
        if ns and ns.SetNPCNameplatesState then
            ns.SetNPCNameplatesState(nextState)
        end
        UpdateActionRow()
        Tooltip_RefreshIfOwnedBy(btnNPCName, ShowNPCTooltip)
    end)
    btnNPCName:SetScript("OnEnter", function()
        ShowNPCTooltip()
    end)
    btnNPCName:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    btnTutorial:SetScript("OnClick", function()
        InitSV()
        local hide = not ((AutoGossip_Settings and AutoGossip_Settings.tutorialEnabledAcc) and true or false)
        hide = not hide
        AutoGossip_Settings.tutorialEnabledAcc = not hide
        AutoGossip_Settings.tutorialOffAcc = hide
        if ns and ns.ApplyTutorialSetting then
            ns.ApplyTutorialSetting(true)
        end
        UpdateActionRow()
    end)
    btnTutorial:SetScript("OnEnter", function()
        if GameTooltip then
            GameTooltip:SetOwner(btnTutorial, "ANCHOR_RIGHT")
            GameTooltip:SetText("Tutorial")
            GameTooltip:AddLine("Green is hiding.", 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    btnTutorial:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    -- Pet Walk segments (above Chromie)
    local petSegContainer = CreateFrame("Frame", nil, panel)
    petSegContainer:SetSize(BTN_W, BTN_H)
    petSegContainer:SetPoint("TOP", actionRow, "BOTTOM", 0, -GAP_Y)
    if frame then
        frame.petWalkSegContainer = petSegContainer
    end

    local segPetWalk = CreateFrame("Button", nil, petSegContainer, "UIPanelButtonTemplate")
    segPetWalk:SetSize(SEG_W, BTN_H)
    segPetWalk:SetPoint("LEFT", petSegContainer, "LEFT", 0, 0)
    if frame then
        frame.btnPetWalkSegMain = segPetWalk
    end

    local segPetDisable = CreateFrame("Button", nil, petSegContainer, "UIPanelButtonTemplate")
    segPetDisable:SetSize(SEG_W, BTN_H)
    segPetDisable:SetPoint("LEFT", segPetWalk, "RIGHT", SEG_GAP, 0)
    if frame then
        frame.btnPetWalkSegDisable = segPetDisable
    end

    local segPetConfig = CreateFrame("Button", nil, petSegContainer, "UIPanelButtonTemplate")
    segPetConfig:SetSize(SEG_W3, BTN_H)
    segPetConfig:SetPoint("LEFT", segPetDisable, "RIGHT", SEG_GAP, 0)
    if frame then
        frame.btnPetWalkSegConfig = segPetConfig
    end

    local function SetSegGreenGrey(btn, label, enabled)
        if enabled then
            btn:SetText("|cff00ff00" .. label .. "|r")
        else
            btn:SetText("|cff888888" .. label .. "|r")
        end
    end

    local function UpdatePetWalkSegments()
        InitSV()
        SetSegGreenGrey(segPetWalk, "Pet Walk", (AutoGossip_Settings and AutoGossip_Settings.petWalkEnabledAcc) and true or false)
        local enabledChar = not ((AutoGossip_CharSettings and AutoGossip_CharSettings.petWalkDisabledChar) and true or false)
        SetSegGreenGrey(segPetDisable, "Enable", enabledChar)
        segPetConfig:SetText("Config")
    end

    local function PetWalkSettingsChanged()
        if ns and ns.SwitchesBP and ns.SwitchesBP.OnSettingsChanged then
            ns.SwitchesBP.OnSettingsChanged()
        end
    end

    segPetWalk:SetScript("OnClick", function()
        InitSV()
        AutoGossip_Settings.petWalkEnabledAcc = not (AutoGossip_Settings.petWalkEnabledAcc and true or false)
        UpdatePetWalkSegments()
        PetWalkSettingsChanged()
    end)
    segPetWalk:SetScript("OnEnter", function()
        if GameTooltip then
            GameTooltip:SetOwner(segPetWalk, "ANCHOR_RIGHT")
            GameTooltip:SetText("Pet Walk")
            GameTooltip:AddLine("Green: ON ACC (tries to keep a battle pet summoned).", 1, 1, 1, true)
            GameTooltip:AddLine("Grey: OFF ACC.", 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    segPetWalk:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    segPetDisable:SetScript("OnClick", function()
        InitSV()
        AutoGossip_CharSettings.petWalkDisabledChar = not (AutoGossip_CharSettings.petWalkDisabledChar and true or false)
        UpdatePetWalkSegments()
        PetWalkSettingsChanged()
    end)
    segPetDisable:SetScript("OnEnter", function()
        if GameTooltip then
            GameTooltip:SetOwner(segPetDisable, "ANCHOR_RIGHT")
            GameTooltip:SetText("Enable")
            GameTooltip:AddLine("Green: enables Pet Walk on this character.", 1, 1, 1, true)
            GameTooltip:AddLine("Grey: disabled on this character.", 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    segPetDisable:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    segPetConfig:SetScript("OnEnter", function()
        if GameTooltip then
            GameTooltip:SetOwner(segPetConfig, "ANCHOR_RIGHT")
            GameTooltip:SetText("Config")
            GameTooltip:AddLine("Configure Pet Walk behavior.", 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    segPetConfig:SetScript("OnClick", function()
        if not (ns and ns.SwitchesBP and ns.SwitchesBP.OpenPetWalkConfigPopup) then
            return
        end

        local p = nil
        if ns.SwitchesBP.GetPetWalkConfigPopupFrame then
            p = ns.SwitchesBP.GetPetWalkConfigPopupFrame()
        end
        if p and p.IsShown and p:IsShown() then
            if p.Hide then p:Hide() end
            return
        end

        CloseAllConfigPopouts(p)
        ns.SwitchesBP.OpenPetWalkConfigPopup()
    end)
    segPetConfig:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    -- Mount Up segments (between Pet Walk and Chromie)
    local mountSegContainer = CreateFrame("Frame", nil, panel)
    mountSegContainer:SetSize(BTN_W, BTN_H)
    mountSegContainer:SetPoint("TOP", petSegContainer, "BOTTOM", 0, -GAP_Y)
    if frame then
        frame.mountUpSegContainer = mountSegContainer
    end

    local segMountUp = CreateFrame("Button", nil, mountSegContainer, "UIPanelButtonTemplate")
    segMountUp:SetSize(SEG_W, BTN_H)
    segMountUp:SetPoint("LEFT", mountSegContainer, "LEFT", 0, 0)
    if frame then
        frame.btnMountUpSegMain = segMountUp
    end

    local segMountDisable = CreateFrame("Button", nil, mountSegContainer, "UIPanelButtonTemplate")
    segMountDisable:SetSize(SEG_W, BTN_H)
    segMountDisable:SetPoint("LEFT", segMountUp, "RIGHT", SEG_GAP, 0)
    if frame then
        frame.btnMountUpSegDisable = segMountDisable
    end

    local segMountConfig = CreateFrame("Button", nil, mountSegContainer, "UIPanelButtonTemplate")
    segMountConfig:SetSize(SEG_W3, BTN_H)
    segMountConfig:SetPoint("LEFT", segMountDisable, "RIGHT", SEG_GAP, 0)
    if frame then
        frame.btnMountUpSegConfig = segMountConfig
    end

    local function UpdateMountUpSegments()
        InitSV()
        SetSegGreenGrey(segMountUp, "Mount Up", (AutoGossip_Settings and AutoGossip_Settings.mountUpEnabledAcc) and true or false)
        SetSegGreenGrey(segMountDisable, "Enable", (AutoGossip_CharSettings and AutoGossip_CharSettings.mountUpEnabledChar) and true or false)
        segMountConfig:SetText("Config")
    end

    local function MountUpSettingsChanged()
        if ns and ns.SwitchesMU and ns.SwitchesMU.OnSettingsChanged then
            ns.SwitchesMU.OnSettingsChanged()
        end
    end

    segMountUp:SetScript("OnClick", function()
        InitSV()
        AutoGossip_Settings.mountUpEnabledAcc = not (AutoGossip_Settings.mountUpEnabledAcc and true or false)
        UpdateMountUpSegments()
        MountUpSettingsChanged()
    end)
    segMountUp:SetScript("OnEnter", function()
        if GameTooltip then
            GameTooltip:SetOwner(segMountUp, "ANCHOR_RIGHT")
            GameTooltip:SetText("Mount Up")
            GameTooltip:AddLine("Green: ON ACC (allows Mount Up on enabled characters).", 1, 1, 1, true)
            GameTooltip:AddLine("Grey: OFF ACC.", 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    segMountUp:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    segMountDisable:SetScript("OnClick", function()
        InitSV()
        AutoGossip_CharSettings.mountUpEnabledChar = not (AutoGossip_CharSettings.mountUpEnabledChar and true or false)
        UpdateMountUpSegments()
        MountUpSettingsChanged()
    end)
    segMountDisable:SetScript("OnEnter", function()
        if GameTooltip then
            GameTooltip:SetOwner(segMountDisable, "ANCHOR_RIGHT")
            GameTooltip:SetText("Enable")
            GameTooltip:AddLine("Green: enables Mount Up on this character.", 1, 1, 1, true)
            GameTooltip:AddLine("Grey: disabled on this character.", 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    segMountDisable:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    segMountConfig:SetScript("OnEnter", function()
        if GameTooltip then
            GameTooltip:SetOwner(segMountConfig, "ANCHOR_RIGHT")
            GameTooltip:SetText("Config")
            GameTooltip:AddLine("Configure Mount Up behavior.", 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    segMountConfig:SetScript("OnClick", function()
        if not (ns and ns.SwitchesMU and ns.SwitchesMU.OpenMountUpConfigPopup) then
            return
        end

        local p = nil
        if ns.SwitchesMU.GetMountUpConfigPopupFrame then
            p = ns.SwitchesMU.GetMountUpConfigPopupFrame()
        end
        if p and p.IsShown and p:IsShown() then
            if p.Hide then p:Hide() end
            return
        end

        CloseAllConfigPopouts(p)
        ns.SwitchesMU.OpenMountUpConfigPopup()
    end)
    segMountConfig:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    -- Chromie segments
    local segContainer = CreateFrame("Frame", nil, panel)
    segContainer:SetSize(BTN_W, BTN_H)
    segContainer:SetPoint("TOP", mountSegContainer, "BOTTOM", 0, -GAP_Y)
    if frame then
        frame.chromieSegContainer = segContainer
    end
    local segChromie = CreateFrame("Button", nil, segContainer, "UIPanelButtonTemplate")
    segChromie:SetSize(SEG_W, BTN_H)
    segChromie:SetPoint("LEFT", segContainer, "LEFT", 0, 0)
    if frame then
        frame.btnChromieSegChromie = segChromie
    end

    local segLock = CreateFrame("Button", nil, segContainer, "UIPanelButtonTemplate")
    segLock:SetSize(SEG_W, BTN_H)
    segLock:SetPoint("LEFT", segChromie, "RIGHT", SEG_GAP, 0)
    if frame then
        frame.btnChromieSegLock = segLock
    end

    local segConfig = CreateFrame("Button", nil, segContainer, "UIPanelButtonTemplate")
    segConfig:SetSize(SEG_W3, BTN_H)
    segConfig:SetPoint("LEFT", segLock, "RIGHT", SEG_GAP, 0)
    if frame then
        frame.btnChromieSegConfig = segConfig
    end

    local function SetSegYellowGrey(btn, label, enabled)
        if enabled then
            btn:SetText("|cffffff00" .. label .. "|r")
        else
            btn:SetText("|cff888888" .. label .. "|r")
        end
    end

    local function UpdateChromieSegments()
        InitSV()
        SetSegYellowGrey(segChromie, "Chromie", (AutoGossip_UI and AutoGossip_UI.chromieFrameEnabled) and true or false)
        SetSegYellowGrey(segLock, "Lock", (AutoGossip_CharSettings and AutoGossip_CharSettings.chromieFrameLocked) and true or false)
        segConfig:SetText("Config")
    end

    segChromie:SetScript("OnClick", function()
        InitSV()
        AutoGossip_UI.chromieFrameEnabled = not (AutoGossip_UI.chromieFrameEnabled and true or false)
        if EnsureChromieIndicator then EnsureChromieIndicator() end
        if UpdateChromieIndicator then UpdateChromieIndicator() end
        UpdateChromieSegments()
        if frame and frame.UpdateChromieLabel then
            frame.UpdateChromieLabel()
        end
    end)
    segChromie:SetScript("OnEnter", function()
        if GameTooltip then
            GameTooltip:SetOwner(segChromie, "ANCHOR_RIGHT")
            GameTooltip:SetText("Chromie")
            GameTooltip:AddLine("ON ACC: shows the on-screen Chromie indicator when available.", 1, 1, 1, true)
            GameTooltip:AddLine("OFF ACC: disables the indicator.", 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    segChromie:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    segLock:SetScript("OnClick", function()
        InitSV()
        AutoGossip_CharSettings.chromieFrameLocked = not (AutoGossip_CharSettings.chromieFrameLocked and true or false)
        if EnsureChromieIndicator then EnsureChromieIndicator() end
        if UpdateChromieIndicator then UpdateChromieIndicator() end
        UpdateChromieSegments()
    end)
    segLock:SetScript("OnEnter", function()
        if GameTooltip then
            GameTooltip:SetOwner(segLock, "ANCHOR_RIGHT")
            GameTooltip:SetText("Lock")
            GameTooltip:AddLine("ON CHAR: locks dragging for this character.", 1, 1, 1, true)
            GameTooltip:AddLine("OFF CHAR: allow dragging.", 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    segLock:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    segConfig:SetScript("OnEnter", function()
        if GameTooltip then
            GameTooltip:SetOwner(segConfig, "ANCHOR_RIGHT")
            GameTooltip:SetText("Config")
            GameTooltip:AddLine("Edit the Chromie indicator frame style.", 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    segConfig:SetScript("OnClick", function()
        local p = nil
        if GetChromieConfigPopupFrame then
            p = GetChromieConfigPopupFrame()
        end
        if p and p.IsShown and p:IsShown() then
            if p.Hide then p:Hide() end
            return
        end

        CloseAllConfigPopouts(p)
        if OpenChromieConfigPopup then
            OpenChromieConfigPopup()
        end
    end)
    segConfig:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    -- Mail Notifier segments (above Reload Button)
    local mailSegContainer = CreateFrame("Frame", nil, panel)
    mailSegContainer:SetSize(BTN_W, BTN_H)
    mailSegContainer:SetPoint("TOP", petSegContainer, "BOTTOM", 0, -GAP_Y)
    if frame then
        frame.mailNotifySegContainer = mailSegContainer
    end

    local segMail = CreateFrame("Button", nil, mailSegContainer, "UIPanelButtonTemplate")
    segMail:SetSize(SEG_W, BTN_H)
    segMail:SetPoint("LEFT", mailSegContainer, "LEFT", 0, 0)
    if frame then
        frame.btnMailNotifySegMain = segMail
    end

    local segMailEnable = CreateFrame("Button", nil, mailSegContainer, "UIPanelButtonTemplate")
    segMailEnable:SetSize(SEG_W, BTN_H)
    segMailEnable:SetPoint("LEFT", segMail, "RIGHT", SEG_GAP, 0)
    if frame then
        frame.btnMailNotifySegEnable = segMailEnable
    end

    local segMailConfig = CreateFrame("Button", nil, mailSegContainer, "UIPanelButtonTemplate")
    segMailConfig:SetSize(SEG_W3, BTN_H)
    segMailConfig:SetPoint("LEFT", segMailEnable, "RIGHT", SEG_GAP, 0)
    if frame then
        frame.btnMailNotifySegConfig = segMailConfig
    end

    local function GetMailDBRefs()
        local LI = (ns and ns.LootIt) or (_G and rawget(_G, "fr0z3nUI_LootIt"))
        if LI and type(LI.EnsureDB) == "function" then
            pcall(LI.EnsureDB)
        end

        local db = (LI and type(LI.GetDB) == "function" and LI.GetDB()) or (_G and rawget(_G, "fr0z3nUI_LootItDB"))
        local ch = (LI and type(LI.GetCharDB) == "function" and LI.GetCharDB()) or (_G and rawget(_G, "fr0z3nUI_LootItCharDB"))
        if type(db) ~= "table" then db = nil end
        if type(ch) ~= "table" then ch = nil end
        if db and type(db.mailNotify) ~= "table" then db.mailNotify = {} end
        return db, ch, LI
    end

    local function UpdateMailNotifierNow()
        local _, _, LI = GetMailDBRefs()
        local ui = LI and LI.UI
        local env = (ui and type(ui.GetEnv) == "function") and ui.GetEnv() or {}
        local fn = rawget(env, "UpdateMailNotifier") or (LI and LI.Mail and LI.Mail.UpdateMailNotifier) or (LI and LI.UpdateMailNotifier)
        if type(fn) == "function" then
            pcall(fn)
        end
    end

    local function UpdateMailNotifySegments()
        local db, ch = GetMailDBRefs()

        local accOn = (db and db.mailNotify and db.mailNotify.enabled) and true or false
        local effective = accOn
        if ch and ch.mailNotifyEnabledOverride ~= nil then
            effective = (ch.mailNotifyEnabledOverride == true)
        end

        SetSegGreenGrey(segMail, "Mail", accOn)
        SetSegGreenGrey(segMailEnable, "Enable", effective)
        segMailConfig:SetText("Config")
    end

    segMail:SetScript("OnClick", function()
        local db = GetMailDBRefs()
        if type(db) ~= "table" then return end
        db.mailNotify = (type(db.mailNotify) == "table") and db.mailNotify or {}
        db.mailNotify.enabled = not (db.mailNotify.enabled and true or false)
        UpdateMailNotifySegments()
        UpdateMailNotifierNow()
    end)
    segMail:SetScript("OnEnter", function()
        if GameTooltip then
            GameTooltip:SetOwner(segMail, "ANCHOR_RIGHT")
            GameTooltip:SetText("Mail Notifier")
            GameTooltip:AddLine("Green: ON ACC (enables Mail Notifier account-wide).", 1, 1, 1, true)
            GameTooltip:AddLine("Grey: OFF ACC.", 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    segMail:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    segMailEnable:SetScript("OnClick", function()
        local db, ch = GetMailDBRefs()
        if type(ch) ~= "table" then return end

        local accOn = (db and db.mailNotify and db.mailNotify.enabled) and true or false
        local effective = accOn
        if ch.mailNotifyEnabledOverride ~= nil then
            effective = (ch.mailNotifyEnabledOverride == true)
        end
        ch.mailNotifyEnabledOverride = not effective

        UpdateMailNotifySegments()
        UpdateMailNotifierNow()
    end)
    segMailEnable:SetScript("OnEnter", function()
        if GameTooltip then
            GameTooltip:SetOwner(segMailEnable, "ANCHOR_RIGHT")
            GameTooltip:SetText("Enable")
            GameTooltip:AddLine("Green: enabled on this character.", 1, 1, 1, true)
            GameTooltip:AddLine("Grey: disabled on this character.", 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    segMailEnable:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    segMailConfig:SetScript("OnEnter", function()
        if GameTooltip then
            GameTooltip:SetOwner(segMailConfig, "ANCHOR_RIGHT")
            GameTooltip:SetText("Config")
            GameTooltip:AddLine("Open Mail Notifier configuration.", 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    segMailConfig:SetScript("OnClick", function()
        if _G and type(_G.FGO_IsMailPopoutOpen) == "function" and _G.FGO_IsMailPopoutOpen() then
            if type(_G.FGO_ToggleMailPopout) == "function" then
                _G.FGO_ToggleMailPopout(false)
            end
            return
        end

        CloseAllConfigPopouts(nil)
        if _G and type(_G.FGO_ToggleMailPopout) == "function" then
            _G.FGO_ToggleMailPopout(true)
        end
    end)
    segMailConfig:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    -- Fishing (FB) segments (between Mail and Safari)
    local fishSegContainer = CreateFrame("Frame", nil, panel)
    fishSegContainer:SetSize(BTN_W, BTN_H)
    fishSegContainer:SetPoint("TOP", mailSegContainer, "BOTTOM", 0, -GAP_Y)
    if frame then
        frame.fishingSegContainer = fishSegContainer
    end

    local segFish = CreateFrame("Button", nil, fishSegContainer, "UIPanelButtonTemplate")
    segFish:SetSize(SEG_W, BTN_H)
    segFish:SetPoint("LEFT", fishSegContainer, "LEFT", 0, 0)
    if frame then
        frame.btnFishingSegMain = segFish
    end

    local segFishEnable = CreateFrame("Button", nil, fishSegContainer, "UIPanelButtonTemplate")
    segFishEnable:SetSize(SEG_W, BTN_H)
    segFishEnable:SetPoint("LEFT", segFish, "RIGHT", SEG_GAP, 0)
    if frame then
        frame.btnFishingSegEnable = segFishEnable
    end

    local segFishConfig = CreateFrame("Button", nil, fishSegContainer, "UIPanelButtonTemplate")
    segFishConfig:SetSize(SEG_W3, BTN_H)
    segFishConfig:SetPoint("LEFT", segFishEnable, "RIGHT", SEG_GAP, 0)
    if frame then
        frame.btnFishingSegConfig = segFishConfig
    end

    local function UpdateFishingSegments()
        InitSV()
        local accOn = (AutoGossip_Settings and AutoGossip_Settings.fishingEnabledAcc) and true or false
        local effective = accOn
        if AutoGossip_CharSettings and AutoGossip_CharSettings.fishingEnabledOverride ~= nil then
            effective = (AutoGossip_CharSettings.fishingEnabledOverride == true)
        end

        SetSegGreenGrey(segFish, "Fish", accOn)
        SetSegGreenGrey(segFishEnable, "Enable", effective)
        segFishConfig:SetText("Config")
    end

    segFish:SetScript("OnClick", function()
        InitSV()
        if type(AutoGossip_Settings) ~= "table" then return end
        AutoGossip_Settings.fishingEnabledAcc = not (AutoGossip_Settings.fishingEnabledAcc and true or false)
        UpdateFishingSegments()
        if ns and ns.SwitchesFB and type(ns.SwitchesFB.OnSettingsChanged) == "function" then
            ns.SwitchesFB.OnSettingsChanged()
        end
    end)
    segFish:SetScript("OnEnter", function()
        if GameTooltip then
            GameTooltip:SetOwner(segFish, "ANCHOR_RIGHT")
            GameTooltip:SetText("Fishing")
            GameTooltip:AddLine("Green: ON ACC (enables Fishing module account-wide).", 1, 1, 1, true)
            GameTooltip:AddLine("Grey: OFF ACC.", 1, 1, 1, true)

            InitSV()
            local toyID = tonumber(AutoGossip_Settings and AutoGossip_Settings.fishingBobberToyIDAcc) or 0
            local lureID = tonumber(AutoGossip_Settings and AutoGossip_Settings.fishingLureItemIDAcc) or 0
            if toyID > 0 or lureID > 0 then
                GameTooltip:AddLine(" ", 1, 1, 1, true)
            end
            if toyID > 0 then
                local link = nil
                if type(GetItemInfo) == "function" then
                    link = select(2, GetItemInfo(toyID))
                end
                GameTooltip:AddLine("Bobber: " .. tostring(link or ("item:" .. tostring(toyID))), 1, 1, 1, true)
            end
            if lureID > 0 then
                local link = nil
                if type(GetItemInfo) == "function" then
                    link = select(2, GetItemInfo(lureID))
                end
                GameTooltip:AddLine("Lure: " .. tostring(link or ("item:" .. tostring(lureID))), 1, 1, 1, true)
            end
            GameTooltip:Show()
        end
    end)
    segFish:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    segFishEnable:SetScript("OnClick", function()
        InitSV()
        if type(AutoGossip_CharSettings) ~= "table" then return end

        local accOn = (AutoGossip_Settings and AutoGossip_Settings.fishingEnabledAcc) and true or false
        local effective = accOn
        if AutoGossip_CharSettings.fishingEnabledOverride ~= nil then
            effective = (AutoGossip_CharSettings.fishingEnabledOverride == true)
        end
        AutoGossip_CharSettings.fishingEnabledOverride = not effective

        UpdateFishingSegments()
        if ns and ns.SwitchesFB and type(ns.SwitchesFB.OnSettingsChanged) == "function" then
            ns.SwitchesFB.OnSettingsChanged()
        end
    end)
    segFishEnable:SetScript("OnEnter", function()
        if GameTooltip then
            GameTooltip:SetOwner(segFishEnable, "ANCHOR_RIGHT")
            GameTooltip:SetText("Enable")
            GameTooltip:AddLine("Green: enabled on this character.", 1, 1, 1, true)
            GameTooltip:AddLine("Grey: disabled on this character.", 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    segFishEnable:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    segFishConfig:SetScript("OnEnter", function()
        if GameTooltip then
            GameTooltip:SetOwner(segFishConfig, "ANCHOR_RIGHT")
            GameTooltip:SetText("Config")
            GameTooltip:AddLine("Open Fishing configuration.", 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    segFishConfig:SetScript("OnClick", function()
        local pop = nil
        if ns and ns.SwitchesFB and type(ns.SwitchesFB.GetFishingConfigPopupFrame) == "function" then
            pop = ns.SwitchesFB.GetFishingConfigPopupFrame()
        end
        pop = pop or (_G and rawget(_G, "FGO_FishingPopout"))

        if pop and pop.IsShown and pop:IsShown() then
            if pop.Hide then pop:Hide() end
            return
        end

        if ns and ns.SwitchesFB and type(ns.SwitchesFB.ToggleFishingConfigPopup) == "function" then
            ns.SwitchesFB.ToggleFishingConfigPopup(panel, true, CloseAllConfigPopouts)
        end
    end)
    segFishConfig:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    -- Safari Hat float segments (below Mail)
    local safariSegContainer = CreateFrame("Frame", nil, panel)
    safariSegContainer:SetSize(BTN_W, BTN_H)
    safariSegContainer:SetPoint("TOP", fishSegContainer, "BOTTOM", 0, -GAP_Y)
    if frame then
        frame.safariHatSegContainer = safariSegContainer
    end

    local segSafari = CreateFrame("Button", nil, safariSegContainer, "UIPanelButtonTemplate")
    segSafari:SetSize(SEG_W, BTN_H)
    segSafari:SetPoint("LEFT", safariSegContainer, "LEFT", 0, 0)
    if frame then
        frame.btnSafariHatSegMain = segSafari
    end

    local segSafariEnable = CreateFrame("Button", nil, safariSegContainer, "UIPanelButtonTemplate")
    segSafariEnable:SetSize(SEG_W, BTN_H)
    segSafariEnable:SetPoint("LEFT", segSafari, "RIGHT", SEG_GAP, 0)
    if frame then
        frame.btnSafariHatSegEnable = segSafariEnable
    end

    local segSafariConfig = CreateFrame("Button", nil, safariSegContainer, "UIPanelButtonTemplate")
    segSafariConfig:SetSize(SEG_W3, BTN_H)
    segSafariConfig:SetPoint("LEFT", segSafariEnable, "RIGHT", SEG_GAP, 0)
    if frame then
        frame.btnSafariHatSegConfig = segSafariConfig
    end

    local function UpdateSafariHatNow()
        if ns and type(ns.UpdateSafariHatFloatButton) == "function" then
            pcall(ns.UpdateSafariHatFloatButton)
        end
    end

    local function UpdateSafariHatSegments()
        InitSV()
        local accOn = (AutoGossip_UI and AutoGossip_UI.safariHatFloatEnabledAcc) and true or false
        local charOn = (AutoGossip_CharSettings and AutoGossip_CharSettings.safariHatFloatEnabledChar ~= false) and true or false

        SetSegGreenGrey(segSafari, "Safari", accOn)
        SetSegGreenGrey(segSafariEnable, "Enable", charOn)
        segSafariConfig:SetText("Config")
    end

    local safariPop
    local function FGO_IsSafariPopoutOpen()
        return safariPop and safariPop.IsShown and safariPop:IsShown() or false
    end
    _G.FGO_IsSafariPopoutOpen = FGO_IsSafariPopoutOpen

    local function MakeEditBoxBorderless(editBox)
        if not editBox then return end
        if editBox.Left and editBox.Left.Hide then editBox.Left:Hide() end
        if editBox.Middle and editBox.Middle.Hide then editBox.Middle:Hide() end
        if editBox.Right and editBox.Right.Hide then editBox.Right:Hide() end
        if editBox.SetTextInsets then
            editBox:SetTextInsets(6, 6, 2, 2)
        end
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

    local function MakeNumericBox(parent, width, height)
        local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
        eb:SetSize(width, height)
        eb:SetAutoFocus(false)
        if eb.SetNumeric then
            eb:SetNumeric(true)
        end
        MakeEditBoxBorderless(eb)
        return eb
    end

    local function MakeTextBox(parent, width, height)
        local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
        eb:SetSize(width, height)
        eb:SetAutoFocus(false)
        MakeEditBoxBorderless(eb)
        return eb
    end

    local function EnsureSafariPopout()
        if safariPop and safariPop.SetPoint then
            return safariPop
        end

        safariPop = CreateFrame("Frame", nil, panel, "BackdropTemplate")
        safariPop:SetSize(480, 360)
        safariPop:ClearAllPoints()
        safariPop:SetPoint("TOPLEFT", panel, "TOPRIGHT", 10, 0)
        if safariPop.SetFrameStrata then safariPop:SetFrameStrata("DIALOG") end
        safariPop:SetFrameLevel((panel.GetFrameLevel and panel:GetFrameLevel() or 0) + 80)
        if safariPop.SetClampedToScreen then safariPop:SetClampedToScreen(true) end
        safariPop:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            tile = true,
            tileSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        safariPop:SetBackdropColor(0, 0, 0, 0.85)
        safariPop:Hide()
        if _G then
            _G.FGO_SafariPopout = safariPop
        end

        local close = CreateFrame("Button", nil, safariPop, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", safariPop, "TOPRIGHT", -6, -6)

        local title = safariPop:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOPLEFT", safariPop, "TOPLEFT", 12, -10)
        title:SetText("Safari")
        title:SetTextColor(1, 0.82, 0, 1)

        local hint = safariPop:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
        hint:SetText("Toy: Safari Hat (92738)")

        -- Click-popout style input row (borderless boxes + ghost text)
        -- Tight widths: Quest/NPC ~6 digits, Size ~2 digits.
        local questBox = MakeNumericBox(safariPop, 70, 20)
        questBox:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 14, -10)
        if questBox.SetJustifyH then questBox:SetJustifyH("CENTER") end
        AttachGhostText(questBox, "QuestID")

        local npcBox = MakeNumericBox(safariPop, 70, 20)
        npcBox:SetPoint("LEFT", questBox, "RIGHT", 6, 0)
        if npcBox.SetJustifyH then npcBox:SetJustifyH("CENTER") end
        AttachGhostText(npcBox, "NPCID")

        local nameBox = MakeTextBox(safariPop, 260, 20)
        nameBox:SetPoint("LEFT", npcBox, "RIGHT", 6, 0)
        AttachGhostText(nameBox, "Name")

        local sizeBox = MakeNumericBox(safariPop, 36, 20)
        sizeBox:SetPoint("LEFT", nameBox, "RIGHT", 6, 0)
        if sizeBox.SetJustifyH then sizeBox:SetJustifyH("CENTER") end
        AttachGhostText(sizeBox, "Size")

        local listHeader = safariPop:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        listHeader:SetPoint("TOPLEFT", questBox, "BOTTOMLEFT", -2, -12)
        listHeader:SetText("Rules")

        local listWidth = 420
        local rowHeight = 20
        local rowGap = 4
        local listHeight = (rowHeight * 10) + (rowGap * 9)

        local listScroll = CreateFrame("ScrollFrame", nil, safariPop, "UIPanelScrollFrameTemplate")
        listScroll:SetPoint("TOPLEFT", listHeader, "BOTTOMLEFT", -2, -6)
        listScroll:SetSize(listWidth + 24, listHeight + 6)
        if listScroll.ScrollBar and listScroll.ScrollBar.Hide then
            listScroll.ScrollBar:Hide()
            listScroll.ScrollBar.Show = function() end
        end
        listScroll:EnableMouseWheel(true)

        local listChild = CreateFrame("Frame", nil, listScroll)
        listChild:SetSize(listWidth, listHeight)
        listScroll:SetScrollChild(listChild)

        local seedEmpty = safariPop:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        seedEmpty:SetPoint("CENTER", listScroll, "CENTER", -10, 0)
        seedEmpty:SetText("No rules")
        seedEmpty:Hide()

        listScroll:SetScript("OnMouseWheel", function(self, delta)
            local current = self:GetVerticalScroll() or 0
            local maxScroll = self:GetVerticalScrollRange() or 0
            local newScroll = current - (delta * (rowHeight + rowGap) * 2)
            if newScroll < 0 then newScroll = 0 end
            if newScroll > maxScroll then newScroll = maxScroll end
            self:SetVerticalScroll(newScroll)
        end)

        local seedRows = {}

        local function BuildRuleEntries()
            if ns and type(ns.SafariHat_List) == "function" then
                return ns.SafariHat_List()
            end
            return {}
        end

        local function RebuildSeedList()
            local entries = BuildRuleEntries()
            seedEmpty:SetShown(#entries == 0)

            for i = 1, #entries do
                local row = seedRows[i]
                if not row then
                    row = CreateFrame("Frame", nil, listChild)
                    row:SetSize(listWidth, rowHeight)
                    if i == 1 then
                        row:SetPoint("TOPLEFT", listChild, "TOPLEFT", 0, 0)
                    else
                        row:SetPoint("TOPLEFT", seedRows[i - 1], "BOTTOMLEFT", 0, -rowGap)
                    end

                    row.bg = row:CreateTexture(nil, "BACKGROUND")
                    row.bg:SetAllPoints(row)
                    row.bg:SetColorTexture(1, 1, 1, 0.04)
                    row.bg:Hide()

                    row.btnToggle = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                    row.btnToggle:SetSize(44, rowHeight)
                    row.btnToggle:SetPoint("RIGHT", row, "RIGHT", -4, 0)

                    row.btnDelete = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                    row.btnDelete:SetSize(22, rowHeight)
                    row.btnDelete:SetPoint("RIGHT", row.btnToggle, "LEFT", -4, 0)
                    row.btnDelete:SetText("X")

                    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                    row.text:SetPoint("LEFT", row, "LEFT", 6, 0)
                    row.text:SetPoint("RIGHT", row.btnDelete, "LEFT", -6, 0)
                    row.text:SetJustifyH("LEFT")

                    seedRows[i] = row
                end

                local e = entries[i]
                row._fgoQuestID = tonumber(e.questID) or 0
                row._fgoNpcID = tonumber(e.npcID) or 0
                row._fgoTextSize = tonumber(e.textSize) or 12
                row._fgoName = tostring(e.name or "")
                row._fgoEnabled = (e.enabled ~= false)
                row._fgoSeeded = (e.seeded and true or false)

                local label = (row._fgoName ~= "" and row._fgoName) or "(unnamed)"
                local qtxt = (row._fgoQuestID and row._fgoQuestID > 0) and ("Q" .. tostring(row._fgoQuestID)) or "Q-"
                local ntxt = (row._fgoNpcID and row._fgoNpcID > 0) and ("N" .. tostring(row._fgoNpcID)) or "N-"
                row.text:SetText(label .. "  [" .. qtxt .. "  " .. ntxt .. "]  Size " .. tostring(row._fgoTextSize or 12))

                if row._fgoEnabled then
                    row.text:SetTextColor(1, 1, 1, 1)
                    row.btnToggle:SetText("ON")
                else
                    row.text:SetTextColor(0.6, 0.6, 0.6, 1)
                    row.btnToggle:SetText("OFF")
                end

                row.btnDelete:SetShown(not row._fgoSeeded)

                local zebra = (i % 2) == 0
                row.bg:SetShown(zebra)

                row:EnableMouse(true)
                row:SetScript("OnMouseDown", function()
                    questBox:SetText((row._fgoQuestID and row._fgoQuestID > 0) and tostring(row._fgoQuestID) or "")
                    npcBox:SetText((row._fgoNpcID and row._fgoNpcID > 0) and tostring(row._fgoNpcID) or "")
                    nameBox:SetText(tostring(row._fgoName or ""))
                    sizeBox:SetText(tostring(math.floor((tonumber(row._fgoTextSize) or 12) + 0.5)))
                    hint:SetText("Rule loaded (press Enter to add/update)")
                end)

                row.btnToggle:SetScript("OnClick", function()
                    if ns and type(ns.SafariHat_SetEnabled) == "function" then
                        ns.SafariHat_SetEnabled(row._fgoNpcID, not row._fgoEnabled)
                    end
                    RebuildSeedList()
                    UpdateSafariHatNow()
                end)

                row.btnDelete:SetScript("OnClick", function()
                    if ns and type(ns.SafariHat_Remove) == "function" then
                        ns.SafariHat_Remove(row._fgoNpcID)
                    end
                    RebuildSeedList()
                    UpdateSafariHatNow()
                end)

                row:Show()
            end

            for i = #entries + 1, #seedRows do
                if seedRows[i] then
                    seedRows[i]:Hide()
                    seedRows[i]:SetScript("OnMouseDown", nil)
                    if seedRows[i].btnToggle then seedRows[i].btnToggle:SetScript("OnClick", nil) end
                    if seedRows[i].btnDelete then seedRows[i].btnDelete:SetScript("OnClick", nil) end
                end
            end

            local n = #entries
            local childHeight = 0
            if n <= 0 then
                childHeight = listHeight
            else
                childHeight = (n * rowHeight) + ((n - 1) * rowGap)
                if childHeight < listHeight then childHeight = listHeight end
            end
            listChild:SetHeight(childHeight)
            if listScroll.SetVerticalScroll then listScroll:SetVerticalScroll(0) end
        end

        local function RefreshSafariPopout()
            RebuildSeedList()
        end

        local function ApplyFromBoxes()
            InitSV()
            local npc = tonumber(npcBox:GetText()) or 0
            if npc < 0 then npc = 0 end

            local name = tostring(nameBox:GetText() or "")

            local size = tonumber(sizeBox:GetText())
            if not size then size = 12 end
            if size < 8 then size = 8 end
            if size > 24 then size = 24 end

            local q = tonumber(questBox:GetText()) or 0
            if q < 0 then q = 0 end

            if ns and type(ns.SafariHat_Upsert) == "function" then
                local ok, err = ns.SafariHat_Upsert(q, npc, size, name)
                if not ok then
                    hint:SetText("Invalid rule: " .. tostring(err or ""))
                else
                    hint:SetText("Rule saved")
                end
            end

            RefreshSafariPopout()
            UpdateSafariHatNow()
        end

        npcBox:SetScript("OnEnterPressed", function(self) self:ClearFocus(); ApplyFromBoxes() end)
        nameBox:SetScript("OnEnterPressed", function(self) self:ClearFocus(); ApplyFromBoxes() end)
        sizeBox:SetScript("OnEnterPressed", function(self) self:ClearFocus(); ApplyFromBoxes() end)
        questBox:SetScript("OnEnterPressed", function(self) self:ClearFocus(); ApplyFromBoxes() end)

        npcBox:SetScript("OnEscapePressed", function(self) self:ClearFocus(); RefreshSafariPopout() end)
        nameBox:SetScript("OnEscapePressed", function(self) self:ClearFocus(); RefreshSafariPopout() end)
        sizeBox:SetScript("OnEscapePressed", function(self) self:ClearFocus(); RefreshSafariPopout() end)
        questBox:SetScript("OnEscapePressed", function(self) self:ClearFocus(); RefreshSafariPopout() end)

        safariPop._fgoRefresh = RefreshSafariPopout
        RefreshSafariPopout()

        return safariPop
    end

    local function FGO_ToggleSafariPopout(show)
        local p = EnsureSafariPopout()
        if not p then
            return
        end
        if show == nil then
            show = not (p.IsShown and p:IsShown())
        end
        if show then
            if p._fgoRefresh then p._fgoRefresh() end
            p:Show()
        else
            p:Hide()
        end
    end
    _G.FGO_ToggleSafariPopout = FGO_ToggleSafariPopout

    segSafari:SetScript("OnClick", function()
        InitSV()
        AutoGossip_UI.safariHatFloatEnabledAcc = not (AutoGossip_UI.safariHatFloatEnabledAcc and true or false)
        UpdateSafariHatSegments()
        UpdateSafariHatNow()
    end)
    segSafari:SetScript("OnEnter", function()
        if GameTooltip then
            GameTooltip:SetOwner(segSafari, "ANCHOR_RIGHT")
            GameTooltip:SetText("Safari")
            GameTooltip:AddLine("Green: ON ACC (enables the floating Safari button).", 1, 1, 1, true)
            GameTooltip:AddLine("Grey: OFF ACC.", 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    segSafari:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    segSafariEnable:SetScript("OnClick", function()
        InitSV()
        AutoGossip_CharSettings.safariHatFloatEnabledChar = not (AutoGossip_CharSettings.safariHatFloatEnabledChar ~= false)
        UpdateSafariHatSegments()
        UpdateSafariHatNow()
    end)
    segSafariEnable:SetScript("OnEnter", function()
        if GameTooltip then
            GameTooltip:SetOwner(segSafariEnable, "ANCHOR_RIGHT")
            GameTooltip:SetText("Enable")
            GameTooltip:AddLine("Green: enabled on this character.", 1, 1, 1, true)
            GameTooltip:AddLine("Grey: disabled on this character.", 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    segSafariEnable:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    segSafariConfig:SetScript("OnEnter", function()
        if GameTooltip then
            GameTooltip:SetOwner(segSafariConfig, "ANCHOR_RIGHT")
            GameTooltip:SetText("Config")
            GameTooltip:AddLine("Open Safari float configuration.", 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    segSafariConfig:SetScript("OnClick", function()
        if _G and type(_G.FGO_IsSafariPopoutOpen) == "function" and _G.FGO_IsSafariPopoutOpen() then
            if type(_G.FGO_ToggleSafariPopout) == "function" then
                _G.FGO_ToggleSafariPopout(false)
            end
            return
        end

        local p = EnsureSafariPopout()
        CloseAllConfigPopouts(p)
        if _G and type(_G.FGO_ToggleSafariPopout) == "function" then
            _G.FGO_ToggleSafariPopout(true)
        end
    end)
    segSafariConfig:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    -- Reorder right-column segment rows to match spec:
    -- Chromie (top) -> Mount Up -> Pet Walk -> then the rest of the buttons.
    if segContainer and mountSegContainer and petSegContainer and mailSegContainer and fishSegContainer and safariSegContainer then
        segContainer:ClearAllPoints()
        segContainer:SetPoint("TOP", panel, "TOP", RIGHT_X, START_Y)

        mountSegContainer:ClearAllPoints()
        mountSegContainer:SetPoint("TOP", segContainer, "BOTTOM", 0, -GAP_Y)

        petSegContainer:ClearAllPoints()
        petSegContainer:SetPoint("TOP", mountSegContainer, "BOTTOM", 0, -GAP_Y)

        mailSegContainer:ClearAllPoints()
        mailSegContainer:SetPoint("TOP", petSegContainer, "BOTTOM", 0, -GAP_Y)

        fishSegContainer:ClearAllPoints()
        fishSegContainer:SetPoint("TOP", mailSegContainer, "BOTTOM", 0, -GAP_Y)

        safariSegContainer:ClearAllPoints()
        safariSegContainer:SetPoint("TOP", fishSegContainer, "BOTTOM", 0, -GAP_Y)
    end

    -- Anchor Queue Accept + new rows under Mail buttons.
    if queueAcceptSegContainer and safariSegContainer then
        queueAcceptSegContainer:ClearAllPoints()
        queueAcceptSegContainer:SetPoint("TOP", safariSegContainer, "BOTTOM", 0, -GAP_Y)
    end
    if popupRow and queueAcceptSegContainer then
        popupRow:ClearAllPoints()
        popupRow:SetPoint("TOP", queueAcceptSegContainer, "BOTTOM", 0, -GAP_Y)
    end
    if actionRow and popupRow then
        actionRow:ClearAllPoints()
        actionRow:SetPoint("TOP", popupRow, "BOTTOM", 0, -GAP_Y)
    end

    -- TooltipX
    local btnTooltipXEnabled = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnTooltipXEnabled:SetSize(BTN_W, BTN_H)
    btnTooltipXEnabled:SetPoint("TOP", btnBorder, "BOTTOM", 0, -GAP_Y)
    if frame then
        frame.btnTooltipXEnabled = btnTooltipXEnabled
    end

    local function UpdateTooltipXEnabledButton()
        InitSV()
        local on = (AutoGossip_Settings and AutoGossip_Settings.tooltipXEnabledAcc) and true or false
        if on then
            btnTooltipXEnabled:SetText("TooltipX Module: |cff00ccffON ACC|r")
        else
            btnTooltipXEnabled:SetText("TooltipX Module: |cffff0000OFF ACC|r")
        end
    end

    -- Initialize new rows on build.
    UpdateQueueAcceptSegments()
    UpdatePopUpRow()
    UpdateActionRow()
    UpdateFishingSegments()
    UpdateSafariHatSegments()

    local function TooltipXDisabledPrefix()
        InitSV()
        if AutoGossip_Settings and AutoGossip_Settings.tooltipXEnabledAcc then
            return ""
        end
        return "|cff888888(disabled)|r "
    end

    btnTooltipXEnabled:SetScript("OnClick", function()
        InitSV()
        AutoGossip_Settings.tooltipXEnabledAcc = not (AutoGossip_Settings.tooltipXEnabledAcc and true or false)
        if ns and ns.ApplyTooltipXSetting then
            ns.ApplyTooltipXSetting(true)
        end
        UpdateTooltipXEnabledButton()
    end)
    btnTooltipXEnabled:SetScript("OnEnter", function()
        if GameTooltip then
            GameTooltip:SetOwner(btnTooltipXEnabled, "ANCHOR_RIGHT")
            GameTooltip:SetText("TooltipX Module")
            GameTooltip:AddLine("Master enable/disable for all TooltipX behavior.", 1, 1, 1, true)
            GameTooltip:AddLine("Default is OFF ACC to avoid interfering after install.", 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    btnTooltipXEnabled:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)

    local btnTooltipXCombat = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnTooltipXCombat:SetSize(BTN_W, BTN_H)
    btnTooltipXCombat:SetPoint("TOP", btnTooltipXEnabled, "BOTTOM", 0, -GAP_Y)
    if frame then
        frame.btnTooltipXCombat = btnTooltipXCombat
    end

    local function UpdateTooltipXCombatButton()
        InitSV()
        local on = (AutoGossip_Settings and AutoGossip_Settings.tooltipXCombatHideAcc) and true or false
        if on then
            btnTooltipXCombat:SetText("TooltipX Combat Hide: " .. TooltipXDisabledPrefix() .. "|cff00ccffON ACC|r")
        else
            btnTooltipXCombat:SetText("TooltipX Combat Hide: " .. TooltipXDisabledPrefix() .. "|cffff0000OFF ACC|r")
        end
    end

    btnTooltipXCombat:SetScript("OnClick", function()
        InitSV()
        AutoGossip_Settings.tooltipXCombatHideAcc = not (AutoGossip_Settings.tooltipXCombatHideAcc and true or false)
        if ns and ns.ApplyTooltipXSetting then
            ns.ApplyTooltipXSetting(true)
        end
        UpdateTooltipXCombatButton()
    end)
    btnTooltipXCombat:SetScript("OnEnter", function()
        if GameTooltip then
            GameTooltip:SetOwner(btnTooltipXCombat, "ANCHOR_RIGHT")
            GameTooltip:SetText("TooltipX: Combat Hide")
            GameTooltip:AddLine("ON ACC: hides most tooltips while in combat.", 1, 1, 1, true)
            GameTooltip:AddLine("Hold the configured reveal key to show them.", 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    btnTooltipXCombat:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)

    local btnTooltipXMod = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnTooltipXMod:SetSize(BTN_W, BTN_H)
    btnTooltipXMod:SetPoint("TOP", btnTooltipXCombat, "BOTTOM", 0, -GAP_Y)
    if frame then
        frame.btnTooltipXMod = btnTooltipXMod
    end

    local function NormalizeMod(m)
        m = (m or ""):upper()
        if m == "CTRL" or m == "CONTROL" then return "CTRL" end
        if m == "ALT" then return "ALT" end
        if m == "SHIFT" then return "SHIFT" end
        if m == "NONE" or m == "OFF" then return "NONE" end
        return "CTRL"
    end

    local function UpdateTooltipXModButton()
        InitSV()
        local mod = NormalizeMod(AutoGossip_Settings and AutoGossip_Settings.tooltipXCombatModifierAcc or "CTRL")
        btnTooltipXMod:SetText("TooltipX Reveal Key: " .. TooltipXDisabledPrefix() .. "|cff00ccff" .. mod .. "|r")
    end

    btnTooltipXMod:SetScript("OnClick", function()
        InitSV()
        local mod = NormalizeMod(AutoGossip_Settings and AutoGossip_Settings.tooltipXCombatModifierAcc or "CTRL")
        if mod == "CTRL" then
            mod = "ALT"
        elseif mod == "ALT" then
            mod = "SHIFT"
        elseif mod == "SHIFT" then
            mod = "NONE"
        else
            mod = "CTRL"
        end
        AutoGossip_Settings.tooltipXCombatModifierAcc = mod
        if ns and ns.ApplyTooltipXSetting then
            ns.ApplyTooltipXSetting(true)
        end
        UpdateTooltipXModButton()
    end)
    btnTooltipXMod:SetScript("OnEnter", function()
        if GameTooltip then
            GameTooltip:SetOwner(btnTooltipXMod, "ANCHOR_RIGHT")
            GameTooltip:SetText("TooltipX: Reveal Key")
            GameTooltip:AddLine("Hold this key in combat to show hidden tooltips.", 1, 1, 1, true)
            GameTooltip:AddLine("NONE: no key override (tooltips stay hidden in combat).", 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    btnTooltipXMod:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)

    local btnTooltipXTarget = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnTooltipXTarget:SetSize(BTN_W, BTN_H)
    btnTooltipXTarget:SetPoint("TOP", btnTooltipXMod, "BOTTOM", 0, -GAP_Y)
    if frame then
        frame.btnTooltipXTarget = btnTooltipXTarget
    end

    local function UpdateTooltipXTargetButton()
        InitSV()
        local on = (AutoGossip_Settings and AutoGossip_Settings.tooltipXCombatShowTargetAcc) and true or false
        if on then
            btnTooltipXTarget:SetText("TooltipX Show Target: " .. TooltipXDisabledPrefix() .. "|cff00ccffON ACC|r")
        else
            btnTooltipXTarget:SetText("TooltipX Show Target: " .. TooltipXDisabledPrefix() .. "|cffff0000OFF ACC|r")
        end
    end

    btnTooltipXTarget:SetScript("OnClick", function()
        InitSV()
        AutoGossip_Settings.tooltipXCombatShowTargetAcc = not (AutoGossip_Settings.tooltipXCombatShowTargetAcc and true or false)
        if ns and ns.ApplyTooltipXSetting then
            ns.ApplyTooltipXSetting(true)
        end
        UpdateTooltipXTargetButton()
    end)
    btnTooltipXTarget:SetScript("OnEnter", function()
        if GameTooltip then
            GameTooltip:SetOwner(btnTooltipXTarget, "ANCHOR_RIGHT")
            GameTooltip:SetText("TooltipX: Show Target")
            GameTooltip:AddLine("If ON, your target's tooltip will remain visible in combat.", 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    btnTooltipXTarget:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)

    local btnTooltipXFocus = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnTooltipXFocus:SetSize(BTN_W, BTN_H)
    btnTooltipXFocus:SetPoint("TOP", btnTooltipXTarget, "BOTTOM", 0, -GAP_Y)
    if frame then
        frame.btnTooltipXFocus = btnTooltipXFocus
    end

    local function UpdateTooltipXFocusButton()
        InitSV()
        local on = (AutoGossip_Settings and AutoGossip_Settings.tooltipXCombatShowFocusAcc) and true or false
        if on then
            btnTooltipXFocus:SetText("TooltipX Show Focus: " .. TooltipXDisabledPrefix() .. "|cff00ccffON ACC|r")
        else
            btnTooltipXFocus:SetText("TooltipX Show Focus: " .. TooltipXDisabledPrefix() .. "|cffff0000OFF ACC|r")
        end
    end

    btnTooltipXFocus:SetScript("OnClick", function()
        InitSV()
        AutoGossip_Settings.tooltipXCombatShowFocusAcc = not (AutoGossip_Settings.tooltipXCombatShowFocusAcc and true or false)
        if ns and ns.ApplyTooltipXSetting then
            ns.ApplyTooltipXSetting(true)
        end
        UpdateTooltipXFocusButton()
    end)
    btnTooltipXFocus:SetScript("OnEnter", function()
        if GameTooltip then
            GameTooltip:SetOwner(btnTooltipXFocus, "ANCHOR_RIGHT")
            GameTooltip:SetText("TooltipX: Show Focus")
            GameTooltip:AddLine("If ON, your focus tooltip remains visible in combat.", 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    btnTooltipXFocus:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)

    local btnTooltipXMouseover = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnTooltipXMouseover:SetSize(BTN_W, BTN_H)
    btnTooltipXMouseover:SetPoint("TOP", btnTooltipXFocus, "BOTTOM", 0, -GAP_Y)
    if frame then
        frame.btnTooltipXMouseover = btnTooltipXMouseover
    end

    local function UpdateTooltipXMouseoverButton()
        InitSV()
        local on = (AutoGossip_Settings and AutoGossip_Settings.tooltipXCombatShowMouseoverAcc) and true or false
        if on then
            btnTooltipXMouseover:SetText("TooltipX Show Mouseover: " .. TooltipXDisabledPrefix() .. "|cff00ccffON ACC|r")
        else
            btnTooltipXMouseover:SetText("TooltipX Show Mouseover: " .. TooltipXDisabledPrefix() .. "|cffff0000OFF ACC|r")
        end
    end

    btnTooltipXMouseover:SetScript("OnClick", function()
        InitSV()
        AutoGossip_Settings.tooltipXCombatShowMouseoverAcc = not (AutoGossip_Settings.tooltipXCombatShowMouseoverAcc and true or false)
        if ns and ns.ApplyTooltipXSetting then
            ns.ApplyTooltipXSetting(true)
        end
        UpdateTooltipXMouseoverButton()
    end)
    btnTooltipXMouseover:SetScript("OnEnter", function()
        if GameTooltip then
            GameTooltip:SetOwner(btnTooltipXMouseover, "ANCHOR_RIGHT")
            GameTooltip:SetText("TooltipX: Show Mouseover")
            GameTooltip:AddLine("If ON, mouseover unit tooltips remain visible in combat.", 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    btnTooltipXMouseover:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)

    local btnTooltipXFriendly = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnTooltipXFriendly:SetSize(BTN_W, BTN_H)
    btnTooltipXFriendly:SetPoint("TOP", btnTooltipXMouseover, "BOTTOM", 0, -GAP_Y)
    if frame then
        frame.btnTooltipXFriendly = btnTooltipXFriendly
    end

    local function UpdateTooltipXFriendlyButton()
        InitSV()
        local on = (AutoGossip_Settings and AutoGossip_Settings.tooltipXCombatShowFriendlyPlayersAcc) and true or false
        if on then
            btnTooltipXFriendly:SetText("TooltipX Show Friendly: " .. TooltipXDisabledPrefix() .. "|cff00ccffON ACC|r")
        else
            btnTooltipXFriendly:SetText("TooltipX Show Friendly: " .. TooltipXDisabledPrefix() .. "|cffff0000OFF ACC|r")
        end
    end

    btnTooltipXFriendly:SetScript("OnClick", function()
        InitSV()
        AutoGossip_Settings.tooltipXCombatShowFriendlyPlayersAcc = not (AutoGossip_Settings.tooltipXCombatShowFriendlyPlayersAcc and true or false)
        if ns and ns.ApplyTooltipXSetting then
            ns.ApplyTooltipXSetting(true)
        end
        UpdateTooltipXFriendlyButton()
    end)
    btnTooltipXFriendly:SetScript("OnEnter", function()
        if GameTooltip then
            GameTooltip:SetOwner(btnTooltipXFriendly, "ANCHOR_RIGHT")
            GameTooltip:SetText("TooltipX: Show Friendly Players")
            GameTooltip:AddLine("If ON, friendly player tooltips remain visible in combat.", 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    btnTooltipXFriendly:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)

    local btnTooltipXCleanup = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnTooltipXCleanup:SetSize(BTN_W, BTN_H)
    btnTooltipXCleanup:SetPoint("TOP", btnTooltipXFriendly, "BOTTOM", 0, -GAP_Y)
    if frame then
        frame.btnTooltipXCleanup = btnTooltipXCleanup
    end

    local function UpdateTooltipXCleanupButton()
        InitSV()
        local on = (AutoGossip_Settings and AutoGossip_Settings.tooltipXCleanupAcc) and true or false
        if on then
            btnTooltipXCleanup:SetText("TooltipX Cleanup: " .. TooltipXDisabledPrefix() .. "|cff00ccffON ACC|r")
        else
            btnTooltipXCleanup:SetText("TooltipX Cleanup: " .. TooltipXDisabledPrefix() .. "|cffff0000OFF ACC|r")
        end
    end

    btnTooltipXCleanup:SetScript("OnClick", function()
        InitSV()
        AutoGossip_Settings.tooltipXCleanupAcc = not (AutoGossip_Settings.tooltipXCleanupAcc and true or false)
        if ns and ns.ApplyTooltipXSetting then
            ns.ApplyTooltipXSetting(true)
        end
        UpdateTooltipXCleanupButton()
    end)
    btnTooltipXCleanup:SetScript("OnEnter", function()
        if GameTooltip then
            GameTooltip:SetOwner(btnTooltipXCleanup, "ANCHOR_RIGHT")
            GameTooltip:SetText("TooltipX: Cleanup")
            GameTooltip:AddLine("Hides common quest objective progress lines (e.g. '0/1 ...').", 1, 1, 1, true)
            GameTooltip:AddLine("This is intentionally lightweight and avoids async quest loads.", 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    btnTooltipXCleanup:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)

    local btnTooltipXCleanupMode = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnTooltipXCleanupMode:SetSize(BTN_W, BTN_H)
    btnTooltipXCleanupMode:SetPoint("TOP", btnTooltipXCleanup, "BOTTOM", 0, -GAP_Y)
    if frame then
        frame.btnTooltipXCleanupMode = btnTooltipXCleanupMode
    end

    local function NormalizeCleanupMode(v)
        v = (v or ""):lower()
        if v ~= "strict" and v ~= "more" then
            return "strict"
        end
        return v
    end

    local function UpdateTooltipXCleanupModeButton()
        InitSV()
        local mode = NormalizeCleanupMode(AutoGossip_Settings and AutoGossip_Settings.tooltipXCleanupModeAcc or "strict")
        btnTooltipXCleanupMode:SetText("TooltipX Cleanup Mode: " .. TooltipXDisabledPrefix() .. "|cff00ccff" .. mode:upper() .. "|r")
    end

    btnTooltipXCleanupMode:SetScript("OnClick", function()
        InitSV()
        local mode = NormalizeCleanupMode(AutoGossip_Settings and AutoGossip_Settings.tooltipXCleanupModeAcc or "strict")
        if mode == "strict" then
            mode = "more"
        else
            mode = "strict"
        end
        AutoGossip_Settings.tooltipXCleanupModeAcc = mode
        if ns and ns.ApplyTooltipXSetting then
            ns.ApplyTooltipXSetting(true)
        end
        UpdateTooltipXCleanupModeButton()
    end)
    btnTooltipXCleanupMode:SetScript("OnEnter", function()
        if GameTooltip then
            GameTooltip:SetOwner(btnTooltipXCleanupMode, "ANCHOR_RIGHT")
            GameTooltip:SetText("TooltipX: Cleanup Mode")
            GameTooltip:AddLine("STRICT: hides the most common '0/1 ...' quest objective lines.", 1, 1, 1, true)
            GameTooltip:AddLine("MORE: hides a few additional numeric progress formats.", 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    btnTooltipXCleanupMode:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)

    local btnTooltipXCleanupScope = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnTooltipXCleanupScope:SetSize(BTN_W, BTN_H)
    btnTooltipXCleanupScope:SetPoint("TOP", btnTooltipXCleanupMode, "BOTTOM", 0, -GAP_Y)
    if frame then
        frame.btnTooltipXCleanupScope = btnTooltipXCleanupScope
    end

    local function UpdateTooltipXCleanupScopeButton()
        InitSV()
        local combatOnly = (AutoGossip_Settings and AutoGossip_Settings.tooltipXCleanupCombatOnlyAcc) and true or false
        if combatOnly then
            btnTooltipXCleanupScope:SetText("TooltipX Cleanup Scope: " .. TooltipXDisabledPrefix() .. "|cff00ccffCOMBAT|r")
        else
            btnTooltipXCleanupScope:SetText("TooltipX Cleanup Scope: " .. TooltipXDisabledPrefix() .. "|cff00ccffALWAYS|r")
        end
    end

    btnTooltipXCleanupScope:SetScript("OnClick", function()
        InitSV()
        AutoGossip_Settings.tooltipXCleanupCombatOnlyAcc = not (AutoGossip_Settings.tooltipXCleanupCombatOnlyAcc and true or false)
        if ns and ns.ApplyTooltipXSetting then
            ns.ApplyTooltipXSetting(true)
        end
        UpdateTooltipXCleanupScopeButton()
    end)
    btnTooltipXCleanupScope:SetScript("OnEnter", function()
        if GameTooltip then
            GameTooltip:SetOwner(btnTooltipXCleanupScope, "ANCHOR_RIGHT")
            GameTooltip:SetText("TooltipX: Cleanup Scope")
            GameTooltip:AddLine("COMBAT: only clean tooltips while in combat.", 1, 1, 1, true)
            GameTooltip:AddLine("ALWAYS: clean tooltips everywhere.", 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    btnTooltipXCleanupScope:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)

    local btnTooltipXDebug = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnTooltipXDebug:SetSize(BTN_W, BTN_H)
    btnTooltipXDebug:SetPoint("TOP", btnTooltipXCleanupScope, "BOTTOM", 0, -GAP_Y)
    if frame then
        frame.btnTooltipXDebug = btnTooltipXDebug
    end

    local function UpdateTooltipXDebugButton()
        InitSV()
        local on = (AutoGossip_Settings and AutoGossip_Settings.tooltipXDebugAcc) and true or false
        if on then
            btnTooltipXDebug:SetText("TooltipX Debug: " .. TooltipXDisabledPrefix() .. "|cff00ccffON ACC|r")
        else
            btnTooltipXDebug:SetText("TooltipX Debug: " .. TooltipXDisabledPrefix() .. "|cffff0000OFF ACC|r")
        end
    end

    btnTooltipXDebug:SetScript("OnClick", function()
        InitSV()
        AutoGossip_Settings.tooltipXDebugAcc = not (AutoGossip_Settings.tooltipXDebugAcc and true or false)
        if ns and ns.ApplyTooltipXSetting then
            ns.ApplyTooltipXSetting(true)
        end
        UpdateTooltipXDebugButton()
    end)
    btnTooltipXDebug:SetScript("OnEnter", function()
        if GameTooltip then
            GameTooltip:SetOwner(btnTooltipXDebug, "ANCHOR_RIGHT")
            GameTooltip:SetText("TooltipX: Debug")
            GameTooltip:AddLine("Prints a short reason when TooltipX hides/cleans a tooltip.", 1, 1, 1, true)
            GameTooltip:AddLine("Throttled to avoid spam.", 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    btnTooltipXDebug:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)

    -- Initial paint
    UpdateBorderButton()
    UpdateQueueAcceptSegments()
    UpdatePopUpRow()
    UpdateActionRow()
    UpdatePetWalkSegments()
    UpdateMountUpSegments()
    UpdateChromieSegments()
    UpdateMailNotifySegments()
    UpdateFishingSegments()
    UpdateTooltipXEnabledButton()
    UpdateTooltipXCombatButton()
    UpdateTooltipXModButton()
    UpdateTooltipXTargetButton()
    UpdateTooltipXFocusButton()
    UpdateTooltipXMouseoverButton()
    UpdateTooltipXFriendlyButton()
    UpdateTooltipXCleanupButton()
    UpdateTooltipXCleanupModeButton()
    UpdateTooltipXCleanupScopeButton()
    UpdateTooltipXDebugButton()

    return function()
        UpdateBorderButton()
        UpdateQueueAcceptSegments()
        UpdatePopUpRow()
        UpdateActionRow()
        UpdatePetWalkSegments()
        UpdateMountUpSegments()
        UpdateChromieSegments()
        UpdateMailNotifySegments()
        UpdateFishingSegments()
        UpdateTooltipXEnabledButton()
        UpdateTooltipXCombatButton()
        UpdateTooltipXModButton()
        UpdateTooltipXTargetButton()
        UpdateTooltipXFocusButton()
        UpdateTooltipXMouseoverButton()
        UpdateTooltipXFriendlyButton()
        UpdateTooltipXCleanupButton()
        UpdateTooltipXCleanupModeButton()
        UpdateTooltipXCleanupScopeButton()
        UpdateTooltipXDebugButton()

        if AutoGossip_UI and AutoGossip_UI.chromieFrameEnabled and EnsureChromieIndicator and UpdateChromieIndicator then
            EnsureChromieIndicator()
            UpdateChromieIndicator()
        elseif ForceHideChromieIndicator then
            ForceHideChromieIndicator()
        end

        if UpdateReloadFloatButton then
            UpdateReloadFloatButton()
        end
    end
end
