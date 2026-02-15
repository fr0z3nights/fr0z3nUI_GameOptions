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

local function EnsureCommandsArray()
    InitSV()
    local s = GetSettings()
    if not s then
        return {}
    end
    if type(s.macroCmdsAcc) ~= "table" then
        s.macroCmdsAcc = {}
    end
    if s.macroCmdsAcc[1] == nil and next(s.macroCmdsAcc) ~= nil then
        s.macroCmdsAcc = {}
    end
    return s.macroCmdsAcc
end

local function Trim(s)
    if type(s) ~= "string" then
        return ""
    end
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
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

local function SplitLines(text)
    text = tostring(text or "")
    text = text:gsub("\r\n", "\n"):gsub("\r", "\n")
    local out = {}
    for line in text:gmatch("([^\n]*)\n?") do
        if line == "" and #out > 0 and out[#out] == "" then
            -- end
            break
        end
        out[#out + 1] = line
    end
    -- Trim trailing empties
    while #out > 0 and Trim(out[#out]) == "" do
        table.remove(out, #out)
    end
    return out
end

local function JoinLines(lines)
    if type(lines) ~= "table" then
        return ""
    end
    return table.concat(lines, "\n")
end

function ns.MacroCmdUI_Build(panel)
    if not (panel and CreateFrame) then
        return function() end
    end

    InitSV()

    local selectedIndex = nil
    local isLoadingFields = false

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 12, -52)
    title:SetJustifyH("LEFT")
    title:SetText("Macro /")

    local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    hint:SetJustifyH("LEFT")
    hint:SetText("Create /fgo m <command> entries. Each command has MAIN + OTHER macro text and a MAIN character list.")

    -- Left list area
    local listArea = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    listArea:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -96)
    listArea:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 10, 50)
    listArea:SetWidth(260)
    listArea:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        tile = true,
        tileSize = 16,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    listArea:SetBackdropColor(0, 0, 0, 0.25)

    local listTitle = listArea:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    listTitle:SetPoint("TOPLEFT", listArea, "TOPLEFT", 6, -6)
    listTitle:SetText("Commands")

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
    empty:SetText("No commands")

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

    -- Right editor
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

    local labelCmd = editArea:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    labelCmd:SetPoint("TOPLEFT", editArea, "TOPLEFT", 8, -30)
    labelCmd:SetText("Command")

    local editCmd = CreateFrame("EditBox", nil, editArea, "InputBoxTemplate")
    editCmd:SetSize(200, 20)
    editCmd:SetPoint("LEFT", labelCmd, "RIGHT", 8, 0)
    editCmd:SetAutoFocus(false)

    local labelUsage = editArea:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    labelUsage:SetPoint("LEFT", editCmd, "RIGHT", 10, 0)
    labelUsage:SetJustifyH("LEFT")
    labelUsage:SetText("Usage: /fgo m -")

    local labelMains = editArea:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    labelMains:SetPoint("TOPLEFT", labelCmd, "BOTTOMLEFT", 0, -12)
    labelMains:SetText("MAIN characters (one per line; with or without -Realm)")

    local mainsScroll = CreateFrame("ScrollFrame", nil, editArea, "UIPanelScrollFrameTemplate")
    mainsScroll:SetPoint("TOPLEFT", labelMains, "BOTTOMLEFT", -2, -6)
    mainsScroll:SetPoint("TOPRIGHT", editArea, "TOPRIGHT", -28, -92)
    mainsScroll:SetHeight(70)

    local mainsBox = CreateFrame("EditBox", nil, mainsScroll)
    mainsBox:SetMultiLine(true)
    mainsBox:SetAutoFocus(false)
    mainsBox:SetFontObject("ChatFontNormal")
    mainsBox:SetWidth(1)
    mainsBox:SetTextInsets(6, 6, 6, 6)
    mainsBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    mainsScroll:SetScrollChild(mainsBox)

    local labelMainText = editArea:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    labelMainText:SetPoint("TOPLEFT", mainsScroll, "BOTTOMLEFT", 2, -12)
    labelMainText:SetText("MAIN macro text")

    local mainScroll = CreateFrame("ScrollFrame", nil, editArea, "UIPanelScrollFrameTemplate")
    mainScroll:SetPoint("TOPLEFT", labelMainText, "BOTTOMLEFT", -2, -6)
    mainScroll:SetPoint("TOPRIGHT", editArea, "TOPRIGHT", -28, -220)
    mainScroll:SetHeight(110)

    local mainBox = CreateFrame("EditBox", nil, mainScroll)
    mainBox:SetMultiLine(true)
    mainBox:SetAutoFocus(false)
    mainBox:SetFontObject("ChatFontNormal")
    mainBox:SetWidth(1)
    mainBox:SetTextInsets(6, 6, 6, 6)
    mainBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    mainScroll:SetScrollChild(mainBox)

    local labelOtherText = editArea:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    labelOtherText:SetPoint("TOPLEFT", mainScroll, "BOTTOMLEFT", 2, -12)
    labelOtherText:SetText("OTHER macro text")

    local otherScroll = CreateFrame("ScrollFrame", nil, editArea, "UIPanelScrollFrameTemplate")
    otherScroll:SetPoint("TOPLEFT", labelOtherText, "BOTTOMLEFT", -2, -6)
    otherScroll:SetPoint("BOTTOMRIGHT", editArea, "BOTTOMRIGHT", -28, 8)

    local otherBox = CreateFrame("EditBox", nil, otherScroll)
    otherBox:SetMultiLine(true)
    otherBox:SetAutoFocus(false)
    otherBox:SetFontObject("ChatFontNormal")
    otherBox:SetWidth(1)
    otherBox:SetTextInsets(6, 6, 6, 6)
    otherBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    otherScroll:SetScrollChild(otherBox)

    local function GetSelectedEntry()
        local cmds = EnsureCommandsArray()
        if not selectedIndex then
            return nil
        end
        return cmds[selectedIndex]
    end

    local function LoadFields()
        isLoadingFields = true
        local entry = GetSelectedEntry()

        if not entry then
            editCmd:SetText("")
            mainsBox:SetText("")
            mainBox:SetText("")
            otherBox:SetText("")
            labelUsage:SetText("Usage: /fgo m -")
            status:SetText("")
            isLoadingFields = false
            return
        end

        editCmd:SetText(entry.key and tostring(entry.key) or "")
        mainsBox:SetText(JoinLines(entry.mains or {}))
        mainBox:SetText(entry.mainText and tostring(entry.mainText) or "")
        otherBox:SetText(entry.otherText and tostring(entry.otherText) or "")

        local key = entry.key and tostring(entry.key) or "-"
        labelUsage:SetText("Usage: /fgo m " .. key)
        status:SetText("")

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

            local key = Trim(editCmd:GetText() or "")
            entry.key = key

            entry.mains = SplitLines(mainsBox:GetText() or "")
            entry.mainText = tostring(mainBox:GetText() or "")
            entry.otherText = tostring(otherBox:GetText() or "")

            labelUsage:SetText("Usage: /fgo m " .. (key ~= "" and key or "-"))

            if panel._MacroCmdUI_RefreshList then
                panel:_MacroCmdUI_RefreshList()
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

    editCmd:SetScript("OnEditFocusLost", function() SaveFields(false) end)
    editCmd:SetScript("OnTextChanged", function() SaveFields(true) end)
    mainsBox:SetScript("OnEditFocusLost", function() SaveFields(false) end)
    mainsBox:SetScript("OnTextChanged", function() SaveFields(true) end)
    mainBox:SetScript("OnEditFocusLost", function() SaveFields(false) end)
    mainBox:SetScript("OnTextChanged", function() SaveFields(true) end)
    otherBox:SetScript("OnEditFocusLost", function() SaveFields(false) end)
    otherBox:SetScript("OnTextChanged", function() SaveFields(true) end)

    local function RefreshButtons()
        btnDel:SetEnabled(selectedIndex ~= nil)
    end

    local function RefreshList()
        local cmds = EnsureCommandsArray()
        empty:SetShown(#cmds == 0)

        if selectedIndex and (selectedIndex < 1 or selectedIndex > #cmds) then
            selectedIndex = nil
        end

        if FauxScrollFrame_Update then
            FauxScrollFrame_Update(scroll, #cmds, ROWS, ROW_H)
        end

        local offset = 0
        if FauxScrollFrame_GetOffset then
            offset = FauxScrollFrame_GetOffset(scroll)
        end

        for i = 1, ROWS do
            local idx = offset + i
            local row = rows[i]
            local entry = cmds[idx]
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

                local keyTxt = (type(entry.key) == "string" and entry.key ~= "") and entry.key or "(no command)"
                row.text:SetText(keyTxt)

                row:SetScript("OnClick", function()
                    selectedIndex = idx
                    RefreshButtons()
                    RefreshList()
                    LoadFields()
                end)
            end
        end
    end

    panel._MacroCmdUI_RefreshList = RefreshList

    scroll:SetScript("OnVerticalScroll", function(self, offset)
        if FauxScrollFrame_OnVerticalScroll then
            FauxScrollFrame_OnVerticalScroll(self, offset, ROW_H, function()
                RefreshList()
            end)
        end
    end)

    btnAdd:SetScript("OnClick", function()
        local cmds = EnsureCommandsArray()
        cmds[#cmds + 1] = { key = "", mains = {}, mainText = "", otherText = "" }
        selectedIndex = #cmds
        RefreshButtons()
        RefreshList()
        LoadFields()
        status:SetText("Added")
    end)

    btnDel:SetScript("OnClick", function()
        local cmds = EnsureCommandsArray()
        if not selectedIndex then
            return
        end
        table.remove(cmds, selectedIndex)
        if #cmds == 0 then
            selectedIndex = nil
        elseif selectedIndex > #cmds then
            selectedIndex = #cmds
        end
        RefreshButtons()
        RefreshList()
        LoadFields()
        status:SetText("Deleted")
    end)

    local function UpdateAll()
        RefreshButtons()
        RefreshList()
        LoadFields()
    end

    UpdateAll()
    return UpdateAll
end
