---@diagnostic disable: undefined-global

local addonName, ns = ...
if type(ns) ~= "table" then
    ns = {}
end

local function InitSV()
    if ns and type(ns._InitSV) == "function" then
        ns._InitSV()
    end
end

local function GetSettings()
    InitSV()
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

local function EnsureLayoutArray()
    InitSV()
    local s = GetSettings()
    if not s then
        return {}
    end
    if type(s.actionBarLayoutAcc) ~= "table" then
        s.actionBarLayoutAcc = {}
    end
    if s.actionBarLayoutAcc[1] == nil and next(s.actionBarLayoutAcc) ~= nil then
        s.actionBarLayoutAcc = {}
    end
    return s.actionBarLayoutAcc
end

local function NormalizeSlot(slot)
    slot = tonumber(slot)
    if not slot then
        return nil
    end
    slot = math.floor(slot)
    if slot < 1 or slot > 180 then
        return nil
    end
    return slot
end

local function SetAcc2StateText(btn, label, enabled)
    if enabled then
        btn:SetText(label .. ": |cff00ccffON ACC|r")
    else
        btn:SetText(label .. ": |cffff0000OFF ACC|r")
    end
end

local function SetAcc2StateTextYellow(btn, label, enabled)
    if enabled then
        btn:SetText(label .. ": |cffffff00ON ACC|r")
    else
        btn:SetText(label .. ": |cff888888OFF ACC|r")
    end
end

local function HideFauxScrollBarAndEnableWheel(sf, rowHeight)
    if not sf then
        return
    end

    local sb = sf.ScrollBar or sf.scrollBar
    if not sb and sf.GetChildren then
        local n = select("#", sf:GetChildren())
        for i = 1, n do
            local child = select(i, sf:GetChildren())
            if child and child.GetObjectType and child:GetObjectType() == "Slider" then
                sb = child
                break
            end
        end
    end
    sf._fgoScrollBar = sb

    if sb then
        sb:Hide()
        sb.Show = function() end
        if sb.SetAlpha then
            sb:SetAlpha(0)
        end
        if sb.EnableMouse then
            sb:EnableMouse(false)
        end
    end

    if sf.EnableMouseWheel then
        sf:EnableMouseWheel(true)
    end
    sf:SetScript("OnMouseWheel", function(self, delta)
        local bar = self._fgoScrollBar or self.ScrollBar or self.scrollBar
        if not (bar and bar.GetValue and bar.SetValue) then
            return
        end
        local step = rowHeight or 16
        bar:SetValue((bar:GetValue() or 0) - (delta * step))
    end)
end

local function SafeMacroIndexByName(name)
    if type(name) ~= "string" or name == "" then
        return 0
    end
    if not GetMacroIndexByName then
        return 0
    end
    local ok, idx = pcall(GetMacroIndexByName, name)
    if not ok then
        return 0
    end
    if type(idx) ~= "number" then
        return 0
    end
    return idx
end

local function FindActionSlotFromFocus(focus)
    local function TryGetSlot(obj)
        if not obj then
            return nil
        end

        if obj.GetAttribute then
            local a = obj:GetAttribute("action")
            if type(a) == "number" then
                return a
            end
            if type(a) == "string" then
                local n = tonumber(a)
                if n then
                    return n
                end
            end
        end

        if type(obj.action) == "number" then
            return obj.action
        end

        if obj.GetPagedID then
            local ok, id = pcall(obj.GetPagedID, obj)
            if ok and type(id) == "number" then
                return id
            end
        end

        return nil
    end

    local obj = focus
    for _ = 1, 8 do
        local slot = TryGetSlot(obj)
        if slot then
            return slot
        end
        if not (obj and obj.GetParent) then
            break
        end
        obj = obj:GetParent()
    end
    return nil
end

-- Optional helper used by the Toggles tab (kept for backward compatibility).
function ns.ActionBarUI_CreateToggleButton(parent, anchorButton, gapY, btnW, btnH)
    if not (CreateFrame and parent) then
        return nil, function() end
    end

    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(btnW or 260, btnH or 22)
    if anchorButton then
        btn:SetPoint("TOP", anchorButton, "BOTTOM", 0, -(gapY or 10))
    else
        btn:SetPoint("TOP", parent, "TOP", 0, -64)
    end

    local function Update()
        InitSV()
        local on = GetBoolSetting("actionBarEnabledAcc", false)
        SetAcc2StateText(btn, "ActionBar Module", on)
    end

    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:SetScript("OnClick", function(_, mouseButton)
        InitSV()
        local s = GetSettings()
        if not s then
            return
        end
        if mouseButton == "RightButton" then
            if ns and ns.ActionBar_ApplyNow then
                ns.ActionBar_ApplyNow("manual")
            end
            return
        end
        s.actionBarEnabledAcc = not (s.actionBarEnabledAcc and true or false)
        if ns and ns.ApplyActionBarSetting then
            ns.ApplyActionBarSetting(true)
        end
        Update()
    end)

    Update()
    return btn, Update
end

function ns.ActionBarUI_Build(panel)
    if not (panel and CreateFrame) then
        return function() end
    end

    InitSV()

    local selectedIndex = nil
    local isLoadingFields = false

    -- Title + hint
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 12, -52)
    title:SetJustifyH("LEFT")
    title:SetText("ActionBar")

    local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    hint:SetJustifyH("LEFT")
    hint:SetText("Place macros into action slots. Slot range: 1-180. Applying is blocked in combat.")

    -- Top buttons
    local BTN_W, BTN_H = 180, 22
    local btnEnabled = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnEnabled:SetSize(BTN_W, BTN_H)
    btnEnabled:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -12, -54)

    local btnOverwrite = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnOverwrite:SetSize(BTN_W, BTN_H)
    btnOverwrite:SetPoint("TOP", btnEnabled, "BOTTOM", 0, -8)

    local btnDebug = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnDebug:SetSize(BTN_W, BTN_H)
    btnDebug:SetPoint("TOP", btnOverwrite, "BOTTOM", 0, -8)

    local btnApply = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnApply:SetSize(BTN_W, BTN_H)
    btnApply:SetPoint("TOP", btnDebug, "BOTTOM", 0, -8)
    btnApply:SetText("Apply Now")

    local btnDetect = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnDetect:SetSize(BTN_W, BTN_H)
    btnDetect:SetPoint("TOP", btnApply, "BOTTOM", 0, -8)

    local btnUseHover = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnUseHover:SetSize(BTN_W, BTN_H)
    btnUseHover:SetPoint("TOP", btnDetect, "BOTTOM", 0, -8)
    btnUseHover:SetText("Use Hover Slot")

    local hoverText = panel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    hoverText:SetPoint("TOPRIGHT", btnUseHover, "BOTTOMRIGHT", 0, -6)
    hoverText:SetJustifyH("RIGHT")
    hoverText:SetText("Hover: -")

    local detectorOn = false
    local hoverSlot, hoverType, hoverId = nil, nil, nil
    local lastHoverKey = nil
    local detectorFrame = CreateFrame("Frame")
    detectorFrame:Hide()

    local function SetDetectorButtonText()
        if detectorOn then
            btnDetect:SetText("Detector: |cff00ccffON|r")
        else
            btnDetect:SetText("Detector: |cffff0000OFF|r")
        end
    end

    local function UpdateHoverText()
        if not hoverSlot then
            hoverText:SetText("Hover: -")
            return
        end
        local parts = { "Hover: " .. tostring(hoverSlot) }
        if hoverType then
            parts[#parts + 1] = tostring(hoverType)
        end
        if hoverId ~= nil then
            parts[#parts + 1] = tostring(hoverId)
        end
        hoverText:SetText(table.concat(parts, " "))
    end

    local function RefreshHoverNow()
        local focus = GetMouseFocus and GetMouseFocus() or nil
        local slot = FindActionSlotFromFocus(focus)
        slot = NormalizeSlot(slot)

        if not slot then
            hoverSlot, hoverType, hoverId = nil, nil, nil
            lastHoverKey = nil
            UpdateHoverText()
            return
        end

        local aType, aId = nil, nil
        if GetActionInfo then
            aType, aId = GetActionInfo(slot)
        end
        local key = tostring(slot) .. ":" .. tostring(aType) .. ":" .. tostring(aId)
        if key == lastHoverKey then
            return
        end
        lastHoverKey = key

        hoverSlot, hoverType, hoverId = slot, aType, aId
        UpdateHoverText()
    end

    detectorFrame:SetScript("OnUpdate", function(self, elapsed)
        self._acc = (self._acc or 0) + (elapsed or 0)
        if self._acc < 0.06 then
            return
        end
        self._acc = 0
        RefreshHoverNow()
    end)

    -- Left list area
    local listArea = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    listArea:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -96)
    listArea:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 10, 50)
    listArea:SetWidth(340)
    listArea:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        tile = true,
        tileSize = 16,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    listArea:SetBackdropColor(0, 0, 0, 0.25)

    local listTitle = listArea:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    listTitle:SetPoint("TOPLEFT", listArea, "TOPLEFT", 6, -6)
    listTitle:SetText("Placements")

    local btnAdd = CreateFrame("Button", nil, listArea, "UIPanelButtonTemplate")
    btnAdd:SetSize(60, 20)
    btnAdd:SetPoint("TOPRIGHT", listArea, "TOPRIGHT", -6, -4)
    btnAdd:SetText("Add")

    local btnDel = CreateFrame("Button", nil, listArea, "UIPanelButtonTemplate")
    btnDel:SetSize(60, 20)
    btnDel:SetPoint("RIGHT", btnAdd, "LEFT", -6, 0)
    btnDel:SetText("Del")

    local empty = listArea:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    empty:SetPoint("CENTER", listArea, "CENTER", 0, 0)
    empty:SetText("No entries")

    local scroll = CreateFrame("ScrollFrame", nil, listArea, "FauxScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", listArea, "TOPLEFT", 4, -28)
    scroll:SetPoint("BOTTOMRIGHT", listArea, "BOTTOMRIGHT", -4, 4)

    local ROW_H = 18
    local ROWS = 14
    local rows = {}

    HideFauxScrollBarAndEnableWheel(scroll, ROW_H)

    for i = 1, ROWS do
        local row = CreateFrame("Button", nil, listArea)
        row:SetHeight(ROW_H)
        row:SetPoint("TOPLEFT", listArea, "TOPLEFT", 8, -30 - (i - 1) * ROW_H)
        row:SetPoint("TOPRIGHT", listArea, "TOPRIGHT", -8, -30 - (i - 1) * ROW_H)

        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(row)
        bg:Hide()
        row.bg = bg

        local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("LEFT", row, "LEFT", 0, 0)
        fs:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(false)
        row.text = fs

        row:Hide()
        rows[i] = row
    end

    -- Right editor area
    local editArea = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    editArea:SetPoint("TOPLEFT", listArea, "TOPRIGHT", 10, 0)
    editArea:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -10, 50)
    editArea:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        tile = true,
        tileSize = 16,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    editArea:SetBackdropColor(0, 0, 0, 0.25)

    local editTitle = editArea:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    editTitle:SetPoint("TOPLEFT", editArea, "TOPLEFT", 6, -6)
    editTitle:SetText("Entry")

    local status = editArea:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    status:SetPoint("TOPRIGHT", editArea, "TOPRIGHT", -6, -6)
    status:SetJustifyH("RIGHT")
    status:SetText("")

    local function CreateLabel(text, anchor, x, y)
        local fs = editArea:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", x or 0, y or -6)
        fs:SetText(text)
        return fs
    end

    local labelSlot = editArea:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    labelSlot:SetPoint("TOPLEFT", editArea, "TOPLEFT", 8, -30)
    labelSlot:SetText("Slot")

    local editSlot = CreateFrame("EditBox", nil, editArea, "InputBoxTemplate")
    editSlot:SetSize(70, 20)
    editSlot:SetPoint("LEFT", labelSlot, "RIGHT", 8, 0)
    editSlot:SetAutoFocus(false)
    if editSlot.SetNumeric then
        editSlot:SetNumeric(true)
    end

    local labelName = editArea:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    labelName:SetPoint("LEFT", editSlot, "RIGHT", 12, 0)
    labelName:SetText("Name")

    local editName = CreateFrame("EditBox", nil, editArea, "InputBoxTemplate")
    editName:SetSize(200, 20)
    editName:SetPoint("LEFT", labelName, "RIGHT", 8, 0)
    editName:SetAutoFocus(false)
    editName:SetMaxLetters(64)

    local labelIcon = CreateLabel("Icon (optional)", labelSlot, 0, -14)
    local editIcon = CreateFrame("EditBox", nil, editArea, "InputBoxTemplate")
    editIcon:SetSize(90, 20)
    editIcon:SetPoint("LEFT", labelIcon, "RIGHT", 8, 0)
    editIcon:SetAutoFocus(false)
    if editIcon.SetNumeric then
        editIcon:SetNumeric(true)
    end

    local btnPerChar = CreateFrame("Button", nil, editArea, "UIPanelButtonTemplate")
    btnPerChar:SetSize(140, 20)
    btnPerChar:SetPoint("LEFT", editIcon, "RIGHT", 12, 0)

    local labelBody = CreateLabel("Body", labelIcon, 0, -14)

    local bodyScroll = CreateFrame("ScrollFrame", nil, editArea, "UIPanelScrollFrameTemplate")
    bodyScroll:SetPoint("TOPLEFT", labelBody, "BOTTOMLEFT", -2, -6)
    bodyScroll:SetPoint("BOTTOMRIGHT", editArea, "BOTTOMRIGHT", -28, 8)

    local bodyBox = CreateFrame("EditBox", nil, bodyScroll)
    bodyBox:SetMultiLine(true)
    bodyBox:SetAutoFocus(false)
    bodyBox:SetFontObject("ChatFontNormal")
    bodyBox:SetWidth(1)
    bodyBox:SetTextInsets(6, 6, 6, 6)
    bodyBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    bodyScroll:SetScrollChild(bodyBox)

    local function SetStatusForEntry(entry)
        if type(entry) ~= "table" then
            status:SetText("")
            return
        end
        local slot = NormalizeSlot(entry.slot)
        local name = entry.name
        local idx = SafeMacroIndexByName(name)
        local macroState = (idx and idx > 0) and "macro ok" or "macro missing"
        local slotState = ""
        if slot and GetActionInfo then
            local t = GetActionInfo(slot)
            if not t then
                slotState = "slot empty"
            else
                slotState = "slot occupied"
            end
        end
        local parts = {}
        if slotState ~= "" then parts[#parts + 1] = slotState end
        parts[#parts + 1] = macroState
        status:SetText(table.concat(parts, " / "))
    end

    local function GetSelectedEntry()
        local layout = EnsureLayoutArray()
        if not selectedIndex then
            return nil
        end
        return layout[selectedIndex]
    end

    local function UpdatePerCharButton(entry)
        local on = (type(entry) == "table" and entry.perChar) and true or false
        if on then
            btnPerChar:SetText("Per-Char: |cff00ccffYES|r")
        else
            btnPerChar:SetText("Per-Char: |cffff0000NO|r")
        end
    end

    local function LoadFields()
        isLoadingFields = true
        local entry = GetSelectedEntry()

        if not entry then
            editSlot:SetText("")
            editName:SetText("")
            editIcon:SetText("")
            bodyBox:SetText("")
            UpdatePerCharButton({ perChar = false })
            SetStatusForEntry(nil)
            isLoadingFields = false
            return
        end

        editSlot:SetText(entry.slot and tostring(entry.slot) or "")
        editName:SetText(entry.name and tostring(entry.name) or "")
        editIcon:SetText(entry.icon and tostring(entry.icon) or "")
        bodyBox:SetText(entry.body and tostring(entry.body) or "")
        UpdatePerCharButton(entry)
        SetStatusForEntry(entry)
        isLoadingFields = false
    end

    local saveTimer = nil
    local function SaveFields(debounce)
        if isLoadingFields then
            return
        end
        local entry = GetSelectedEntry()
        if not entry then
            return
        end

        local function doSave()
            saveTimer = nil
            local slot = NormalizeSlot(editSlot:GetText())
            entry.slot = slot

            local name = editName:GetText()
            if type(name) ~= "string" then
                name = ""
            end
            name = name:gsub("^%s+", ""):gsub("%s+$", "")
            entry.name = name

            local iconText = editIcon:GetText()
            local iconNum = tonumber(iconText)
            if iconNum then
                entry.icon = math.floor(iconNum)
            else
                entry.icon = nil
            end

            local body = bodyBox:GetText() or ""
            entry.body = tostring(body)

            SetStatusForEntry(entry)
            if panel._ActionBarUI_RefreshList then
                panel:_ActionBarUI_RefreshList()
            end
        end

        if debounce and C_Timer and C_Timer.NewTimer then
            if saveTimer and saveTimer.Cancel then
                saveTimer:Cancel()
            end
            saveTimer = C_Timer.NewTimer(0.30, doSave)
        else
            doSave()
        end
    end

    btnPerChar:SetScript("OnClick", function()
        local entry = GetSelectedEntry()
        if not entry then
            return
        end
        entry.perChar = not (entry.perChar and true or false)
        UpdatePerCharButton(entry)
    end)

    editSlot:SetScript("OnEditFocusLost", function() SaveFields(false) end)
    editSlot:SetScript("OnTextChanged", function() SaveFields(true) end)
    editName:SetScript("OnEditFocusLost", function() SaveFields(false) end)
    editName:SetScript("OnTextChanged", function() SaveFields(true) end)
    editIcon:SetScript("OnEditFocusLost", function() SaveFields(false) end)
    editIcon:SetScript("OnTextChanged", function() SaveFields(true) end)
    bodyBox:SetScript("OnEditFocusLost", function() SaveFields(false) end)
    bodyBox:SetScript("OnTextChanged", function() SaveFields(true) end)

    local function RefreshButtons()
        InitSV()
        local s = GetSettings()
        local on = (s and s.actionBarEnabledAcc) and true or false
        SetAcc2StateText(btnEnabled, "Enabled", on)

        local ov = (s and s.actionBarOverwriteAcc) and true or false
        SetAcc2StateTextYellow(btnOverwrite, "Overwrite", ov)

        local dbg = (s and s.actionBarDebugAcc) and true or false
        SetAcc2StateTextYellow(btnDebug, "Debug", dbg)

        btnDel:SetEnabled(selectedIndex ~= nil)
    end

    btnEnabled:SetScript("OnClick", function()
        InitSV()
        local s = GetSettings()
        if not s then
            return
        end
        s.actionBarEnabledAcc = not (s.actionBarEnabledAcc and true or false)
        if ns and ns.ApplyActionBarSetting then
            ns.ApplyActionBarSetting(true)
        end
        RefreshButtons()
    end)

    btnOverwrite:SetScript("OnClick", function()
        InitSV()
        local s = GetSettings()
        if not s then
            return
        end
        s.actionBarOverwriteAcc = not (s.actionBarOverwriteAcc and true or false)
        RefreshButtons()
    end)

    btnDebug:SetScript("OnClick", function()
        InitSV()
        local s = GetSettings()
        if not s then
            return
        end
        s.actionBarDebugAcc = not (s.actionBarDebugAcc and true or false)
        RefreshButtons()
    end)

    btnApply:SetScript("OnClick", function()
        if ns and ns.ActionBar_ApplyNow then
            ns.ActionBar_ApplyNow("ui")
        end
    end)

    btnDetect:SetScript("OnClick", function()
        detectorOn = not detectorOn
        if detectorOn then
            detectorFrame:Show()
            RefreshHoverNow()
        else
            detectorFrame:Hide()
            hoverSlot, hoverType, hoverId = nil, nil, nil
            lastHoverKey = nil
            UpdateHoverText()
        end
        SetDetectorButtonText()
    end)

    btnDetect:SetScript("OnEnter", function()
        if not GameTooltip then
            return
        end
        GameTooltip:SetOwner(btnDetect, "ANCHOR_RIGHT")
        GameTooltip:SetText("Slot Detector")
        GameTooltip:AddLine("ON: reads the underlying action slot from the bar button you are hovering.", 1, 1, 1, true)
        GameTooltip:AddLine("Works with Blizzard bars and most bar addons (e.g. Bartender) that use action slots.", 1, 1, 1, true)
        GameTooltip:AddLine("Use 'Use Hover Slot' to fill the Slot field of the selected entry.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btnDetect:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    btnUseHover:SetScript("OnClick", function()
        if not hoverSlot then
            status:SetText("Hover a bar button first")
            return
        end
        if not selectedIndex then
            status:SetText("Select an entry first")
            return
        end
        editSlot:SetText(tostring(hoverSlot))
        SaveFields(false)
    end)


    local function RefreshList()
        local layout = EnsureLayoutArray()
        empty:SetShown(#layout == 0)

        if selectedIndex and (selectedIndex < 1 or selectedIndex > #layout) then
            selectedIndex = nil
        end

        if FauxScrollFrame_Update then
            FauxScrollFrame_Update(scroll, #layout, ROWS, ROW_H)
        end

        local offset = 0
        if FauxScrollFrame_GetOffset then
            offset = FauxScrollFrame_GetOffset(scroll)
        end

        for i = 1, ROWS do
            local idx = offset + i
            local row = rows[i]
            local entry = layout[idx]
            if not entry then
                row:Hide()
            else
                row:Show()

                local zebra = (idx % 2) == 0
                row.bg:SetShown(zebra or (selectedIndex == idx))
                if selectedIndex == idx then
                    row.bg:SetColorTexture(0.2, 0.6, 1, 0.18)
                else
                    row.bg:SetColorTexture(1, 1, 1, zebra and 0.05 or 0)
                end

                local slotTxt = entry.slot and tostring(entry.slot) or "?"
                local nameTxt = (type(entry.name) == "string" and entry.name ~= "") and entry.name or "(no name)"
                row.text:SetText(string.format("%s: %s", slotTxt, nameTxt))

                row:SetScript("OnClick", function()
                    selectedIndex = idx
                    RefreshButtons()
                    RefreshList()
                    LoadFields()
                end)
            end
        end
    end

    panel._ActionBarUI_RefreshList = RefreshList

    scroll:SetScript("OnVerticalScroll", function(self, offset)
        if FauxScrollFrame_OnVerticalScroll then
            FauxScrollFrame_OnVerticalScroll(self, offset, ROW_H, function()
                RefreshList()
            end)
        end
    end)

    btnAdd:SetScript("OnClick", function()
        local layout = EnsureLayoutArray()
        layout[#layout + 1] = { slot = nil, name = "", body = "", icon = nil, perChar = false }
        selectedIndex = #layout
        RefreshButtons()
        RefreshList()
        LoadFields()
    end)

    btnDel:SetScript("OnClick", function()
        local layout = EnsureLayoutArray()
        if not selectedIndex then
            return
        end
        table.remove(layout, selectedIndex)
        if #layout == 0 then
            selectedIndex = nil
        elseif selectedIndex > #layout then
            selectedIndex = #layout
        end
        RefreshButtons()
        RefreshList()
        LoadFields()
    end)

    local function UpdateAll()
        SetDetectorButtonText()
        RefreshButtons()
        RefreshList()
        LoadFields()
    end

    panel:SetScript("OnHide", function()
        if detectorOn then
            detectorOn = false
            detectorFrame:Hide()
            hoverSlot, hoverType, hoverId = nil, nil, nil
            lastHoverKey = nil
            UpdateHoverText()
            SetDetectorButtonText()
        end
    end)

    UpdateAll()
    return UpdateAll
end
