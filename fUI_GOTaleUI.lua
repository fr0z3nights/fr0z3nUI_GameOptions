---@diagnostic disable: undefined-global

local addonName, ns = ...
if type(ns) ~= "table" then ns = {} end

-- Tale tab (formerly "Gossip") UI.
-- Built from fr0z3nUI_GameOptions.lua to keep the main file slimmer.

function ns.TaleUI_Build(frame, panel, helpers)
    helpers = helpers or {}

    local f = frame
    local editPanel = panel

    local InitSV = helpers.InitSV or function(...) end
    local Print = helpers.Print or function(...) end
    local BumpFont = helpers.BumpFont or function(...) end
    local HideFauxScrollBarAndEnableWheel = helpers.HideFauxScrollBarAndEnableWheel or function(...) end
    local CloseOptionsWindow = helpers.CloseOptionsWindow or function(...) end
    local CloseGossipWindow = helpers.CloseGossipWindow or function(...) end

    local GetCurrentNpcID = helpers.GetCurrentNpcID or function(...) return nil end
    local GetCurrentNpcName = helpers.GetCurrentNpcName or function(...) return "" end
    local FindOptionInfoByID = helpers.FindOptionInfoByID or function(...) return nil end
    local HasRule = helpers.HasRule or function(...) return false end
    local AddRule = helpers.AddRule or function(...) end

    local GetDbNpcTable = helpers.GetDbNpcTable or function(...) return nil end
    local IsDisabled = helpers.IsDisabled or function(...) return false end
    local SetDisabled = helpers.SetDisabled or function(...) end
    local IsDisabledDB = helpers.IsDisabledDB or function(...) return false end
    local SetDisabledDB = helpers.SetDisabledDB or function(...) end

    if not (f and editPanel) then
        return function() end
    end

    local function SetYellowGreyStateText(btn, label, enabled)
        if not (btn and btn.SetText) then
            return
        end
        btn:SetText(label)
        local fs = (btn.GetFontString and btn:GetFontString()) or btn.Text
        if fs and fs.SetTextColor then
            if enabled then
                fs:SetTextColor(1, 1, 0)
            else
                fs:SetTextColor(0.62, 0.62, 0.62)
            end
        end
    end

    -- Print/Debug: only shown on the Tale (edit) tab
    local btnPrint = CreateFrame("Button", nil, editPanel, "UIPanelButtonTemplate")
    btnPrint:SetSize(90, 22)
    btnPrint:SetPoint("BOTTOMLEFT", editPanel, "BOTTOMLEFT", 12, 12)
    btnPrint:SetFrameLevel((editPanel.GetFrameLevel and editPanel:GetFrameLevel() or 0) + 10)
    f._btnPrint = btnPrint

    local function UpdatePrintButton()
        InitSV()
        local on = (AutoGossip_UI and AutoGossip_UI.printOnShow) and true or false
        SetYellowGreyStateText(btnPrint, "Print", on)
    end

    btnPrint:SetScript("OnClick", function()
        InitSV()
        AutoGossip_UI.printOnShow = not (AutoGossip_UI.printOnShow and true or false)
        UpdatePrintButton()
    end)
    btnPrint:SetScript("OnEnter", function()
        if GameTooltip then
            GameTooltip:SetOwner(btnPrint, "ANCHOR_TOPLEFT")
            GameTooltip:SetText("Print")
            GameTooltip:AddLine("ON: print current gossip options on show.", 1, 1, 1, true)
            GameTooltip:AddLine("Useful for building rules.", 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    btnPrint:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
    btnPrint:SetScript("OnShow", UpdatePrintButton)
    UpdatePrintButton()

    -- Minimum option count before Print-on-show fires.
    local editPrintMin = CreateFrame("EditBox", nil, editPanel, "InputBoxTemplate")
    editPrintMin:SetSize(36, 22)
    editPrintMin:SetPoint("LEFT", btnPrint, "RIGHT", 8, 0)
    editPrintMin:SetAutoFocus(false)
    editPrintMin:SetMaxLetters(3)
    editPrintMin:SetTextInsets(6, 6, 0, 0)
    editPrintMin:SetJustifyH("CENTER")
    if editPrintMin.SetJustifyV then
        editPrintMin:SetJustifyV("MIDDLE")
    end
    if editPrintMin.SetNumeric then
        editPrintMin:SetNumeric(true)
    end
    editPrintMin:SetFrameLevel((editPanel.GetFrameLevel and editPanel:GetFrameLevel() or 0) + 10)
    f._editPrintMin = editPrintMin

    local function SanitizePrintMinOptions(value)
        local n = tonumber(value)
        if type(n) ~= "number" then
            n = 2
        end
        n = math.floor(n)
        if n < 1 then
            n = 1
        end
        if n > 999 then
            n = 999
        end
        return n
    end

    local function UpdatePrintMinBox()
        InitSV()
        local n = SanitizePrintMinOptions(AutoGossip_UI and AutoGossip_UI.printOnShowMinOptions)
        editPrintMin._updating = true
        editPrintMin:SetText(tostring(n))
        editPrintMin._updating = false
        if editPrintMin.SetCursorPosition then
            editPrintMin:SetCursorPosition(0)
        end
    end

    local function CommitPrintMinBox()
        if editPrintMin._updating then
            return
        end
        InitSV()
        local n = SanitizePrintMinOptions(editPrintMin:GetText())
        AutoGossip_UI.printOnShowMinOptions = n
        UpdatePrintMinBox()
    end

    editPrintMin:SetScript("OnEnterPressed", function()
        CommitPrintMinBox()
        if editPrintMin.ClearFocus then
            editPrintMin:ClearFocus()
        end
    end)
    editPrintMin:SetScript("OnEscapePressed", function()
        UpdatePrintMinBox()
        if editPrintMin.ClearFocus then
            editPrintMin:ClearFocus()
        end
    end)
    editPrintMin:SetScript("OnEditFocusLost", function()
        CommitPrintMinBox()
    end)
    editPrintMin:SetScript("OnShow", UpdatePrintMinBox)
    editPrintMin:SetScript("OnEnter", function()
        if GameTooltip then
            GameTooltip:SetOwner(editPrintMin, "ANCHOR_TOPLEFT")
            GameTooltip:SetText("Print threshold")
            GameTooltip:AddLine("Minimum number of gossip options required before Print-on-show prints.", 1, 1, 1, true)
            GameTooltip:AddLine("Default: 2 (skips single-option NPCs)", 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    editPrintMin:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
    UpdatePrintMinBox()

    local btnDebug = CreateFrame("Button", nil, editPanel, "UIPanelButtonTemplate")
    btnDebug:SetSize(90, 22)
    btnDebug:SetPoint("LEFT", editPrintMin, "RIGHT", 8, 0)
    btnDebug:SetFrameLevel((editPanel.GetFrameLevel and editPanel:GetFrameLevel() or 0) + 10)
    f._btnDebug = btnDebug

    local function UpdateDebugButton()
        InitSV()
        local on = (AutoGossip_Settings and AutoGossip_Settings.debugAcc) and true or false
        SetYellowGreyStateText(btnDebug, "Debug", on)
    end

    btnDebug:SetScript("OnClick", function()
        InitSV()
        AutoGossip_Settings.debugAcc = not (AutoGossip_Settings.debugAcc and true or false)
        UpdateDebugButton()
    end)
    btnDebug:SetScript("OnEnter", function()
        if GameTooltip then
            GameTooltip:SetOwner(btnDebug, "ANCHOR_TOPLEFT")
            GameTooltip:SetText("Debug")
            GameTooltip:AddLine("ON: print detailed gossip info on show.", 1, 1, 1, true)
            GameTooltip:AddLine("Also prints why auto-select did/didn't fire.", 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    btnDebug:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
    btnDebug:SetScript("OnShow", UpdateDebugButton)
    UpdateDebugButton()

    -- Edit/Add layout: one full-width area containing 2 stacked boxes.
    local leftArea = CreateFrame("Frame", nil, editPanel)
    leftArea:SetPoint("TOPLEFT", editPanel, "TOPLEFT", 10, -54)
    leftArea:SetPoint("BOTTOMRIGHT", editPanel, "BOTTOMRIGHT", -10, 50)
    f._leftArea = leftArea

    -- Legacy container (kept for minimal churn). Not used in the new layout.
    local rightArea = CreateFrame("Frame", nil, editPanel)
    rightArea:Hide()
    f._rightArea = rightArea

    -- OptionID input (hidden by default; quick A/C buttons are the primary workflow)
    local info = editPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    info:SetPoint("TOPLEFT", leftArea, "TOPLEFT", 6, -2)
    info:SetText("")
    info:Hide()
    f._info = info

    local edit = CreateFrame("EditBox", nil, editPanel, "InputBoxTemplate")
    edit:SetSize(1, 1)
    edit:SetPoint("TOPLEFT", leftArea, "TOPLEFT", 0, 0)
    edit:SetAutoFocus(false)
    edit:SetMaxLetters(10)
    edit:SetTextInsets(6, 6, 0, 0)
    edit:SetJustifyH("CENTER")
    if edit.SetJustifyV then
        edit:SetJustifyV("MIDDLE")
    end
    if edit.SetNumeric then
        edit:SetNumeric(true)
    end
    if edit.GetFont and edit.SetFont then
        local fontPath, _, fontFlags = edit:GetFont()
        if fontPath then
            edit:SetFont(fontPath, 16, fontFlags)
        end
    end
    f.edit = edit

    local function HideEditBoxFrame(box)
        if not box or not box.GetRegions then
            return
        end
        for i = 1, select("#", box:GetRegions()) do
            local region = select(i, box:GetRegions())
            if region and region.Hide and region.GetObjectType and region:GetObjectType() == "Texture" then
                region:Hide()
            end
        end
    end
    HideEditBoxFrame(edit)

    -- NPC header (top center)
    local zoneContinentLabel = editPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    zoneContinentLabel:SetPoint("TOP", leftArea, "TOP", 0, -2)
    zoneContinentLabel:SetPoint("LEFT", leftArea, "LEFT", 0, 0)
    zoneContinentLabel:SetPoint("RIGHT", leftArea, "RIGHT", 0, 0)
    zoneContinentLabel:SetJustifyH("CENTER")
    zoneContinentLabel:SetWordWrap(true)
    zoneContinentLabel:SetText("")
    f.zoneContinentLabel = zoneContinentLabel

    local nameLabel = editPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    nameLabel:SetPoint("TOP", zoneContinentLabel, "BOTTOM", 0, -1)
    nameLabel:SetPoint("LEFT", leftArea, "LEFT", 0, 0)
    nameLabel:SetPoint("RIGHT", leftArea, "RIGHT", 0, 0)
    nameLabel:SetJustifyH("CENTER")
    nameLabel:SetWordWrap(true)
    BumpFont(nameLabel, 4)
    f.nameLabel = nameLabel

    local reasonLabel = editPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    reasonLabel:SetPoint("TOP", nameLabel, "BOTTOM", 0, -1)
    reasonLabel:SetPoint("LEFT", leftArea, "LEFT", 0, 0)
    reasonLabel:SetPoint("RIGHT", leftArea, "RIGHT", 0, 0)
    reasonLabel:SetJustifyH("CENTER")
    reasonLabel:SetWordWrap(true)
    f.reasonLabel = reasonLabel

    -- Helpers
    local function IsFontStringTruncated(fs)
        if not fs then return false end
        if fs.IsTruncated then
            return fs:IsTruncated()
        end
        local w = fs.GetStringWidth and fs:GetStringWidth() or 0
        local maxW = fs.GetWidth and fs:GetWidth() or 0
        return w > (maxW + 1)
    end

    local function AttachTruncatedTooltip(owner, fs, getText)
        owner:SetScript("OnEnter", function()
            if not (GameTooltip and fs) then
                return
            end
            if IsFontStringTruncated(fs) then
                GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
                GameTooltip:SetText(getText())
                GameTooltip:Show()
            end
        end)
        owner:SetScript("OnLeave", function()
            if GameTooltip then GameTooltip:Hide() end
        end)
    end

    -- Two stacked boxes: top = current rules, bottom = current options
    local rulesArea = CreateFrame("Frame", nil, editPanel, "BackdropTemplate")
    rulesArea:SetPoint("TOPLEFT", reasonLabel, "BOTTOMLEFT", -2, -8)
    rulesArea:SetPoint("TOPRIGHT", reasonLabel, "BOTTOMRIGHT", 2, -8)
    rulesArea:SetHeight(170)
    rulesArea:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        tile = true,
        tileSize = 16,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    rulesArea:SetBackdropColor(0, 0, 0, 0.25)

    local emptyLabel = rulesArea:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    emptyLabel:SetPoint("CENTER", rulesArea, "CENTER", 0, 0)
    emptyLabel:SetText("No rules for this NPC")

    local scrollFrame = CreateFrame("ScrollFrame", nil, rulesArea, "FauxScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", rulesArea, "TOPLEFT", 4, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", rulesArea, "BOTTOMRIGHT", -4, 4)
    f.scrollFrame = scrollFrame

    local RULE_ROW_H = 18
    local RULE_ROWS = 8
    local rows = {}

    HideFauxScrollBarAndEnableWheel(scrollFrame, RULE_ROW_H)

    local function SetRowVisible(row, visible)
        if visible then
            row:Show()
        else
            row:Hide()
        end
    end

    for i = 1, RULE_ROWS do
        local row = CreateFrame("Button", nil, rulesArea)
        row:SetHeight(RULE_ROW_H)
        row:SetPoint("TOPLEFT", rulesArea, "TOPLEFT", 8, -6 - (i - 1) * RULE_ROW_H)
        row:SetPoint("TOPRIGHT", rulesArea, "TOPRIGHT", -8, -6 - (i - 1) * RULE_ROW_H)

        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(row)
        bg:Hide()
        row.bg = bg

        local btnAccToggle = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        btnAccToggle:SetSize(22, RULE_ROW_H - 2)
        btnAccToggle:SetPoint("LEFT", row, "LEFT", 0, 0)
        btnAccToggle:SetText("A")
        row.btnAccToggle = btnAccToggle

        local btnCharToggle = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        btnCharToggle:SetSize(22, RULE_ROW_H - 2)
        btnCharToggle:SetPoint("LEFT", btnAccToggle, "RIGHT", 4, 0)
        btnCharToggle:SetText("C")
        row.btnCharToggle = btnCharToggle

        local btnDbToggle = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        btnDbToggle:SetSize(26, RULE_ROW_H - 2)
        btnDbToggle:SetPoint("LEFT", btnCharToggle, "RIGHT", 4, 0)
        btnDbToggle:SetText("DB")
        row.btnDbToggle = btnDbToggle

        local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("LEFT", btnDbToggle, "RIGHT", 6, 0)
        fs:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(false)
        row.text = fs

        AttachTruncatedTooltip(row, fs, function()
            return fs:GetText() or ""
        end)

        SetRowVisible(row, false)
        rows[i] = row
    end

    local function CollectRulesForNpc(npcID)
        local entries = {}
        if not npcID then
            return entries
        end

        local byOption = {}
        local function Ensure(optionID)
            local key = tostring(optionID)
            local e = byOption[key]
            if not e then
                e = {
                    optionID = tonumber(optionID) or optionID,
                    text = "",
                    hasChar = false,
                    hasAcc = false,
                    hasDb = false,
                    disabledChar = false,
                    disabledAcc = false,
                    disabledDb = false,
                    expansion = "",
                }
                byOption[key] = e
                table.insert(entries, e)
            end
            return e
        end

        local function AddFrom(scope)
            local db = (scope == "acc") and AutoGossip_Acc or AutoGossip_Char
            local npcTable = db[npcID]
            if type(npcTable) ~= "table" then
                return
            end
            for optionID, data in pairs(npcTable) do
                local numericID = tonumber(optionID) or optionID
                local text = ""
                if type(data) == "table" then
                    text = data.text or ""
                end

                local e = Ensure(numericID)
                if e.text == "" and type(text) == "string" and text ~= "" then
                    e.text = text
                end

                if scope == "char" then
                    e.hasChar = true
                    e.disabledChar = IsDisabled("char", npcID, e.optionID)
                else
                    e.hasAcc = true
                    e.disabledAcc = IsDisabled("acc", npcID, e.optionID)
                end
            end
        end

        AddFrom("char")
        AddFrom("acc")

        local dbNpc = GetDbNpcTable(npcID)
        if dbNpc then
            for optionID, data in pairs(dbNpc) do
                local numericID = tonumber(optionID) or optionID
                local text = ""
                local expansion = ""
                if type(data) == "table" then
                    text = data.text or ""
                    expansion = data.expansion or ""
                end

                local e = Ensure(numericID)
                if e.text == "" and type(text) == "string" and text ~= "" then
                    e.text = text
                end
                e.hasDb = true
                e.disabledDb = IsDisabledDB(npcID, e.optionID)
                e.expansion = expansion or e.expansion
            end
        end

        table.sort(entries, function(a, b)
            return (tonumber(a.optionID) or 0) < (tonumber(b.optionID) or 0)
        end)

        return entries
    end

    function f:RefreshRulesList(npcID)
        InitSV()
        self.currentNpcID = npcID

        local entries = CollectRulesForNpc(npcID)
        self._rulesEntries = entries

        emptyLabel:SetShown(npcID and (#entries == 0) or false)

        local total = #entries
        if FauxScrollFrame_Update then
            FauxScrollFrame_Update(scrollFrame, total, RULE_ROWS, RULE_ROW_H)
        end

        local offset = 0
        if FauxScrollFrame_GetOffset then
            offset = FauxScrollFrame_GetOffset(scrollFrame)
        end

        for i = 1, RULE_ROWS do
            local idx = offset + i
            local row = rows[i]
            local entry = entries[idx]
            if entry then
                SetRowVisible(row, true)

                local zebra = (idx % 2) == 0
                row.bg:SetShown(zebra)
                row.bg:SetColorTexture(1, 1, 1, zebra and 0.05 or 0)

                local suffix = ""
                if entry.hasDb and entry.expansion and entry.expansion ~= "" then
                    suffix = " (" .. entry.expansion .. ")"
                end

                local text = entry.text
                if type(text) ~= "string" or text == "" then
                    text = "(no text)"
                end
                row.text:SetText(string.format("%s: %s%s", tostring(entry.optionID), text, suffix))

                local function ConfigureToggle(btn, label, exists, isDisabled, onClick, tooltipLabel)
                    if not exists then
                        btn:Disable()
                        btn:SetText("|cff666666" .. label .. "|r")
                        btn:SetScript("OnClick", nil)
                        btn:SetScript("OnEnter", nil)
                        btn:SetScript("OnLeave", nil)
                        return
                    end

                    btn:Enable()
                    if isDisabled then
                        btn:SetText("|cffff9900" .. label .. "|r")
                    else
                        btn:SetText("|cff00ff00" .. label .. "|r")
                    end
                    btn:SetScript("OnClick", onClick)
                    btn:SetScript("OnEnter", function()
                        if GameTooltip then
                            GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
                            GameTooltip:SetText(tooltipLabel)
                            if isDisabled then
                                GameTooltip:AddLine("State: Disabled", 1, 0.6, 0, true)
                                GameTooltip:AddLine("Left-click: Enable", 1, 1, 1, true)
                            else
                                GameTooltip:AddLine("State: Active", 0, 1, 0, true)
                                GameTooltip:AddLine("Left-click: Disable", 1, 1, 1, true)
                            end
                            GameTooltip:Show()
                        end
                    end)
                    btn:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
                end

                ConfigureToggle(row.btnAccToggle, "A", entry.hasAcc, entry.disabledAcc, function()
                    InitSV()
                    SetDisabled("acc", npcID, entry.optionID, not IsDisabled("acc", npcID, entry.optionID))
                    f:RefreshRulesList(npcID)
                    if f.RefreshBrowserList then f:RefreshBrowserList() end
                    CloseOptionsWindow()
                    CloseGossipWindow()
                end, "Account")

                ConfigureToggle(row.btnCharToggle, "C", entry.hasChar, entry.disabledChar, function()
                    InitSV()
                    SetDisabled("char", npcID, entry.optionID, not IsDisabled("char", npcID, entry.optionID))
                    f:RefreshRulesList(npcID)
                    if f.RefreshBrowserList then f:RefreshBrowserList() end
                    CloseOptionsWindow()
                    CloseGossipWindow()
                end, "Character")

                ConfigureToggle(row.btnDbToggle, "DB", entry.hasDb, entry.disabledDb, function()
                    InitSV()
                    SetDisabledDB(npcID, entry.optionID, not IsDisabledDB(npcID, entry.optionID))
                    f:RefreshRulesList(npcID)
                    if f.RefreshBrowserList then f:RefreshBrowserList() end
                    CloseOptionsWindow()
                    CloseGossipWindow()
                end, "DB")
            else
                SetRowVisible(row, false)
            end
        end
    end

    scrollFrame:SetScript("OnVerticalScroll", function(self, offset)
        if FauxScrollFrame_OnVerticalScroll then
            FauxScrollFrame_OnVerticalScroll(self, offset, RULE_ROW_H, function()
                if f.RefreshRulesList then
                    f:RefreshRulesList(f.currentNpcID)
                end
            end)
        end
    end)

    -- Bottom: current NPC options list
    local optionsArea = CreateFrame("Frame", nil, editPanel, "BackdropTemplate")
    optionsArea:SetPoint("TOPLEFT", rulesArea, "BOTTOMLEFT", 0, -10)
    optionsArea:SetPoint("TOPRIGHT", rulesArea, "BOTTOMRIGHT", 0, -10)
    optionsArea:SetPoint("BOTTOMLEFT", leftArea, "BOTTOMLEFT", 0, 0)
    optionsArea:SetPoint("BOTTOMRIGHT", leftArea, "BOTTOMRIGHT", 0, 0)
    optionsArea:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        tile = true,
        tileSize = 16,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    optionsArea:SetBackdropColor(0, 0, 0, 0.25)

    local optEmpty = optionsArea:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    optEmpty:SetPoint("CENTER", optionsArea, "CENTER", 0, 0)
    optEmpty:SetText("Open a gossip window")

    local optScroll = CreateFrame("ScrollFrame", nil, optionsArea, "FauxScrollFrameTemplate")
    optScroll:SetPoint("TOPLEFT", optionsArea, "TOPLEFT", 4, -4)
    optScroll:SetPoint("BOTTOMRIGHT", optionsArea, "BOTTOMRIGHT", -4, 4)
    f.optScroll = optScroll

    local OPT_ROW_H = 18
    local OPT_ROWS = 8
    local optRows = {}

    HideFauxScrollBarAndEnableWheel(optScroll, OPT_ROW_H)

    for i = 1, OPT_ROWS do
        local row = CreateFrame("Button", nil, optionsArea)
        row:SetHeight(OPT_ROW_H)
        row:SetPoint("TOPLEFT", optionsArea, "TOPLEFT", 8, -6 - (i - 1) * OPT_ROW_H)
        row:SetPoint("TOPRIGHT", optionsArea, "TOPRIGHT", -8, -6 - (i - 1) * OPT_ROW_H)
        row:RegisterForClicks("LeftButtonUp")

        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(row)
        bg:Hide()
        row.bg = bg

        local btnAccQuick = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        btnAccQuick:SetSize(22, OPT_ROW_H - 2)
        btnAccQuick:SetPoint("LEFT", row, "LEFT", 0, 0)
        btnAccQuick:SetText("A")
        row.btnAccQuick = btnAccQuick

        local btnCharQuick = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        btnCharQuick:SetSize(22, OPT_ROW_H - 2)
        btnCharQuick:SetPoint("LEFT", btnAccQuick, "RIGHT", 4, 0)
        btnCharQuick:SetText("C")
        row.btnCharQuick = btnCharQuick

        local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("LEFT", btnCharQuick, "RIGHT", 6, 0)
        fs:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(false)
        row.text = fs

        AttachTruncatedTooltip(row, fs, function()
            return fs:GetText() or ""
        end)

        row:Hide()
        optRows[i] = row
    end

    function f:RefreshOptionsList()
        if not (C_GossipInfo and C_GossipInfo.GetOptions) then
            self._currentOptions = {}
            optEmpty:SetText("Gossip API not available")
            optEmpty:Show()
            for i = 1, OPT_ROWS do optRows[i]:Hide() end
            return
        end

        local options = C_GossipInfo.GetOptions() or {}
        table.sort(options, function(a, b)
            return (a and a.gossipOptionID or 0) < (b and b.gossipOptionID or 0)
        end)
        self._currentOptions = options

        optEmpty:SetShown(#options == 0)
        optEmpty:SetText(#options == 0 and "Open a gossip window" or "")

        if FauxScrollFrame_Update then
            FauxScrollFrame_Update(optScroll, #options, OPT_ROWS, OPT_ROW_H)
        end

        local offset = 0
        if FauxScrollFrame_GetOffset then
            offset = FauxScrollFrame_GetOffset(optScroll)
        end

        for i = 1, OPT_ROWS do
            local idx = offset + i
            local row = optRows[i]
            local opt = options[idx]
            if not opt then
                row:Hide()
            else
                row:Show()
                local zebra = (idx % 2) == 0
                row.bg:SetShown(zebra)
                row.bg:SetColorTexture(1, 1, 1, zebra and 0.05 or 0)
                local optionID = opt.gossipOptionID
                local text = opt.name
                if type(text) ~= "string" or text == "" then
                    text = "(no text)"
                end
                row.text:SetText(string.format("%d: %s", optionID or 0, text))

                local function QuickAdd(scope)
                    InitSV()
                    local npcID = GetCurrentNpcID()
                    if not npcID then
                        Print("Open a gossip window first (need an NPC).")
                        return
                    end
                    if not optionID then
                        return
                    end
                    local optInfo = FindOptionInfoByID(optionID)
                    local optName = (optInfo and optInfo.name) or text
                    local optType = optInfo and (rawget(optInfo, "type") or rawget(optInfo, "optionType")) or nil

                    if HasRule(scope, npcID, optionID) then
                        -- Toggle disable/enable for existing rule.
                        local nowDisabled = not IsDisabled(scope, npcID, optionID)
                        SetDisabled(scope, npcID, optionID, nowDisabled)
                    else
                        AddRule(scope, npcID, optionID, optName, optType)
                    end

                    if f.RefreshRulesList then f:RefreshRulesList(npcID) end
                    if f.RefreshBrowserList then f:RefreshBrowserList() end
                    if f.UpdateFromInput then f:UpdateFromInput() end

                    CloseOptionsWindow()
                    CloseGossipWindow()
                end

                row.btnCharQuick:SetScript("OnClick", function() QuickAdd("char") end)
                row.btnAccQuick:SetScript("OnClick", function() QuickAdd("acc") end)

                row.btnCharQuick:SetScript("OnEnter", function()
                    if GameTooltip then
                        GameTooltip:SetOwner(row.btnCharQuick, "ANCHOR_RIGHT")
                        GameTooltip:SetText("Character")
                        GameTooltip:AddLine("Add/enable this option for this character.", 1, 1, 1, true)
                        GameTooltip:Show()
                    end
                end)
                row.btnCharQuick:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

                row.btnAccQuick:SetScript("OnEnter", function()
                    if GameTooltip then
                        GameTooltip:SetOwner(row.btnAccQuick, "ANCHOR_RIGHT")
                        GameTooltip:SetText("Account")
                        GameTooltip:AddLine("Add/enable this option account-wide.", 1, 1, 1, true)
                        GameTooltip:Show()
                    end
                end)
                row.btnAccQuick:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

                row:SetScript("OnClick", nil)
            end
        end
    end

    optScroll:SetScript("OnVerticalScroll", function(self, offset)
        if FauxScrollFrame_OnVerticalScroll then
            FauxScrollFrame_OnVerticalScroll(self, offset, OPT_ROW_H, function()
                if f.RefreshOptionsList then
                    f:RefreshOptionsList()
                end
            end)
        end
    end)

    local function GetPlayerContinentNameForHeader()
        if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetMapInfo) then
            return ""
        end
        local mapID = C_Map.GetBestMapForUnit("player")
        local safety = 0
        while mapID and safety < 30 do
            local info = C_Map.GetMapInfo(mapID)
            if not info then
                break
            end
            if Enum and Enum.UIMapType and info.mapType == Enum.UIMapType.Continent then
                local name = info.name or ""
                -- Some APIs/overrides may include commas in continent names; normalize to spaces.
                if type(name) == "string" and name:find(",", 1, true) then
                    name = name:gsub("%s*,%s*", " ")
                    name = name:gsub("%s%s+", " ")
                    name = name:gsub("^%s+", ""):gsub("%s+$", "")
                end
                return name
            end
            mapID = info.parentMapID
            safety = safety + 1
        end
        return ""
    end

    local function GetPlayerZoneNameForHeader()
        if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetMapInfo) then
            return ""
        end
        local mapID = C_Map.GetBestMapForUnit("player")
        local safety = 0
        while mapID and safety < 30 do
            local info = C_Map.GetMapInfo(mapID)
            if not info then
                break
            end
            if Enum and Enum.UIMapType and info.mapType == Enum.UIMapType.Zone then
                return info.name or ""
            end
            mapID = info.parentMapID
            safety = safety + 1
        end
        return ""
    end

    function f:UpdateFromInput()
        InitSV()
        local npcID = GetCurrentNpcID() or f.selectedNpcID
        local npcName = GetCurrentNpcName() or f.selectedNpcName or ""

        if f.zoneContinentLabel and f.zoneContinentLabel.SetText then
            local zone = GetPlayerZoneNameForHeader()
            if zone == "" then
                zone = (GetRealZoneText and GetRealZoneText()) or ((GetZoneText and GetZoneText()) or "")
            end
            local continent = GetPlayerContinentNameForHeader()
            if zone ~= "" and continent ~= "" then
                f.zoneContinentLabel:SetText(zone .. ", " .. continent)
            else
                f.zoneContinentLabel:SetText(zone ~= "" and zone or (continent ~= "" and continent or ""))
            end
        end

        nameLabel:SetText(npcName or "")
        if npcID then
            reasonLabel:SetText(tostring(npcID))
            if f.RefreshRulesList then f:RefreshRulesList(npcID) end
        else
            reasonLabel:SetText("")
            if f.RefreshRulesList then f:RefreshRulesList(nil) end
        end
    end

    edit:SetScript("OnTextChanged", function()
        if f.UpdateFromInput then f:UpdateFromInput() end
    end)

    f:UpdateFromInput()
    if f.RefreshOptionsList then
        f:RefreshOptionsList()
    end

    -- Keep the option list in sync when the frame is shown.
    f:SetScript("OnShow", function()
        if f.edit and f.edit.ClearFocus then
            f.edit:ClearFocus()
        end
        if f.UpdateChromieLabel then
            f.UpdateChromieLabel()
        end
        if f.SelectTab then
            f:SelectTab(5)
        end
        if f.RefreshOptionsList then
            f:RefreshOptionsList()
        end
        if f.RefreshBrowserList then
            f:RefreshBrowserList()
        end
        if f.UpdateFromInput then
            f:UpdateFromInput()
        end
    end)

    return function()
        if f and f.UpdateFromInput then
            f:UpdateFromInput()
        end
    end
end
