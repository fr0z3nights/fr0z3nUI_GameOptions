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

    local GetQueueAcceptState = helpers.GetQueueAcceptState
    local SetQueueAcceptState = helpers.SetQueueAcceptState
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

        for _, f in ipairs({ pet, mu, chromie }) do
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

    -- Queue Accept
    local btnQueueAccept = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnQueueAccept:SetSize(BTN_W, BTN_H)
    btnQueueAccept:SetPoint("TOP", panel, "TOP", RIGHT_X, START_Y)
    if frame then
        frame.btnQueueAccept = btnQueueAccept
    end

    local function UpdateQueueAcceptButton()
        if not GetQueueAcceptState then
            btnQueueAccept:SetText("Queue Accept: |cff888888(unavailable)|r")
            return
        end
        local state = GetQueueAcceptState()
        if state == "acc" then
            btnQueueAccept:SetText("Queue Accept: |cff00ccffACC ON|r")
        elseif state == "char" then
            btnQueueAccept:SetText("Queue Accept: |cff00ccffON|r")
        else
            btnQueueAccept:SetText("Queue Accept: |cffff0000OFF|r")
        end
    end

    btnQueueAccept:SetScript("OnClick", function()
        if not (GetQueueAcceptState and SetQueueAcceptState) then
            return
        end
        local state = GetQueueAcceptState()
        if state == "acc" then
            SetQueueAcceptState("char")
        elseif state == "char" then
            SetQueueAcceptState("off")
        else
            SetQueueAcceptState("acc")
        end
        UpdateQueueAcceptButton()
        if ShowQueueOverlayIfNeeded then
            ShowQueueOverlayIfNeeded()
        end
    end)
    btnQueueAccept:SetScript("OnEnter", function()
        if GameTooltip then
            GameTooltip:SetOwner(btnQueueAccept, "ANCHOR_RIGHT")
            GameTooltip:SetText("Queue Accept")
            GameTooltip:AddLine("ACC ON: enable for all characters.", 1, 1, 1, true)
            GameTooltip:AddLine("ON: enable only this character.", 1, 1, 1, true)
            GameTooltip:AddLine("OFF: disable.", 1, 1, 1, true)
            GameTooltip:AddLine("When a dungeon queue pops, clicking the world will accept.", 1, 1, 1, true)
            GameTooltip:AddLine("Clicks on other UI should not accept.", 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    btnQueueAccept:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)

    -- Row: PopUp / PopDbg / Reload (below Queue Accept)
    local popupRow = CreateFrame("Frame", nil, panel)
    popupRow:SetSize(BTN_W, BTN_H)
    popupRow:SetPoint("TOP", btnQueueAccept, "BOTTOM", 0, -GAP_Y)
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

    -- Reorder right-column segment rows to match spec:
    -- Chromie (top) -> Mount Up -> Pet Walk -> then the rest of the buttons.
    if segContainer and mountSegContainer and petSegContainer and mailSegContainer then
        segContainer:ClearAllPoints()
        segContainer:SetPoint("TOP", panel, "TOP", RIGHT_X, START_Y)

        mountSegContainer:ClearAllPoints()
        mountSegContainer:SetPoint("TOP", segContainer, "BOTTOM", 0, -GAP_Y)

        petSegContainer:ClearAllPoints()
        petSegContainer:SetPoint("TOP", mountSegContainer, "BOTTOM", 0, -GAP_Y)

        mailSegContainer:ClearAllPoints()
        mailSegContainer:SetPoint("TOP", petSegContainer, "BOTTOM", 0, -GAP_Y)
    end

    -- Anchor Queue Accept + new rows under Mail buttons.
    if btnQueueAccept and mailSegContainer then
        btnQueueAccept:ClearAllPoints()
        btnQueueAccept:SetPoint("TOP", mailSegContainer, "BOTTOM", 0, -GAP_Y)
    end
    if popupRow and btnQueueAccept then
        popupRow:ClearAllPoints()
        popupRow:SetPoint("TOP", btnQueueAccept, "BOTTOM", 0, -GAP_Y)
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
    UpdateQueueAcceptButton()
    UpdatePopUpRow()
    UpdateActionRow()

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
    UpdateQueueAcceptButton()
    UpdatePopUpRow()
    UpdateActionRow()
    UpdatePetWalkSegments()
    UpdateMountUpSegments()
    UpdateChromieSegments()
    UpdateMailNotifySegments()
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
        UpdateQueueAcceptButton()
        UpdatePopUpRow()
        UpdateActionRow()
        UpdatePetWalkSegments()
        UpdateMountUpSegments()
        UpdateChromieSegments()
        UpdateMailNotifySegments()
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
