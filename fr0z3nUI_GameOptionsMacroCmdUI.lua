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

local function HideScrollBarAndEnableWheel(sf, step)
    if not sf then
        return
    end

    local sb = sf.ScrollBar or sf.scrollBar
    if sb then
        sb:Hide()
        sb.Show = function() end
        if sb.SetAlpha then sb:SetAlpha(0) end
        if sb.EnableMouse then sb:EnableMouse(false) end
    end

    if sf.EnableMouseWheel then
        sf:EnableMouseWheel(true)
    end
    sf:SetScript("OnMouseWheel", function(self, delta)
        local bar = self.ScrollBar or self.scrollBar
        if not (bar and bar.GetValue and bar.SetValue) then
            return
        end
        local cur = bar:GetValue() or 0
        local s = step or 24
        bar:SetValue(cur - (delta * s))
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

    local PAD_L, PAD_R = 10, 10
    local PAD_B = 50 -- leave space for bottom footer buttons (Reload/Print/Debug)
    local TOP_Y = 54
    local GAP = 10
    local CMD_H = 28
    local LIST_W = 280

    -- Commands list (right)
    local listArea = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    listArea:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PAD_R, -TOP_Y)
    listArea:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -PAD_R, PAD_B)
    listArea:SetWidth(LIST_W)
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

    -- Left side: command input + 3 equal stacked editor boxes
    local leftArea = CreateFrame("Frame", nil, panel)
    leftArea:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD_L, -TOP_Y)
    leftArea:SetPoint("BOTTOMRIGHT", listArea, "BOTTOMLEFT", -GAP, PAD_B)

    local status = leftArea:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    status:SetPoint("TOPRIGHT", leftArea, "TOPRIGHT", -2, -2)
    status:SetJustifyH("RIGHT")
    status:SetText("")

    local cmdArea = CreateFrame("Frame", nil, leftArea, "BackdropTemplate")
    cmdArea:SetPoint("TOPLEFT", leftArea, "TOPLEFT", 0, 0)
    cmdArea:SetPoint("TOPRIGHT", leftArea, "TOPRIGHT", 0, 0)
    cmdArea:SetHeight(CMD_H)
    cmdArea:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        tile = true,
        tileSize = 16,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    cmdArea:SetBackdropColor(0, 0, 0, 0.25)

    local cmdPrefix = cmdArea:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    cmdPrefix:SetPoint("LEFT", cmdArea, "LEFT", 8, 0)
    cmdPrefix:SetText("/fgo m")

    local editCmd = CreateFrame("EditBox", nil, cmdArea)
    editCmd:SetAutoFocus(false)
    editCmd:SetMultiLine(false)
    editCmd:SetFontObject("GameFontNormalLarge")
    editCmd:SetTextInsets(6, 6, 4, 4)
    editCmd:SetPoint("TOPLEFT", cmdPrefix, "TOPRIGHT", 6, 0)
    editCmd:SetPoint("BOTTOMRIGHT", cmdArea, "BOTTOMRIGHT", -8, 0)
    editCmd:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    local cmdGhost = cmdArea:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    cmdGhost:SetPoint("LEFT", editCmd, "LEFT", 2, 0)
    cmdGhost:SetText("enter command name")

    local function UpdateCmdGhost()
        local txt = tostring(editCmd:GetText() or "")
        local show = (txt == "") and not (editCmd.HasFocus and editCmd:HasFocus())
        cmdGhost:SetShown(show)
    end

    local function MakeBox(labelText)
        local box = CreateFrame("Frame", nil, leftArea, "BackdropTemplate")
        box:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            tile = true,
            tileSize = 16,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        box:SetBackdropColor(0, 0, 0, 0.25)

        local label = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("TOP", box, "TOP", 0, -8)
        label:SetJustifyH("CENTER")
        label:SetText(tostring(labelText or ""))

        do
            local fontPath, fontSize, flags = label:GetFont()
            if fontPath and fontSize then
                label:SetFont(fontPath, fontSize + 2, flags)
            end
        end

        local sf = CreateFrame("ScrollFrame", nil, box, "UIPanelScrollFrameTemplate")
        sf:SetPoint("TOPLEFT", box, "TOPLEFT", 6, -28)
        sf:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -6, 6)
        HideScrollBarAndEnableWheel(sf)

        local eb = CreateFrame("EditBox", nil, sf)
        eb:SetMultiLine(true)
        eb:SetAutoFocus(false)
        eb:SetFontObject("ChatFontNormal")
        eb:SetWidth(1)
        eb:SetTextInsets(6, 6, 6, 6)
        eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        sf:SetScrollChild(eb)

        return box, eb
    end

    local charsArea, mainsBox = MakeBox("CHARACTERS")
    local mainArea, mainBox = MakeBox("CHARACTERS MACRO")
    local otherArea, otherBox = MakeBox("OTHERS MACRO")

    local function LayoutLeft()
        local h = leftArea.GetHeight and leftArea:GetHeight() or 0
        if not h or h <= 0 then
            return
        end

        local avail = h - CMD_H - (GAP * 3)
        if avail < 180 then
            avail = 180
        end
        local boxH = math.floor(avail / 3)
        if boxH < 60 then
            boxH = 60
        end

        charsArea:ClearAllPoints()
        charsArea:SetPoint("TOPLEFT", cmdArea, "BOTTOMLEFT", 0, -GAP)
        charsArea:SetPoint("TOPRIGHT", cmdArea, "BOTTOMRIGHT", 0, -GAP)
        charsArea:SetHeight(boxH)

        mainArea:ClearAllPoints()
        mainArea:SetPoint("TOPLEFT", charsArea, "BOTTOMLEFT", 0, -GAP)
        mainArea:SetPoint("TOPRIGHT", charsArea, "BOTTOMRIGHT", 0, -GAP)
        mainArea:SetHeight(boxH)

        otherArea:ClearAllPoints()
        otherArea:SetPoint("TOPLEFT", mainArea, "BOTTOMLEFT", 0, -GAP)
        otherArea:SetPoint("TOPRIGHT", mainArea, "BOTTOMRIGHT", 0, -GAP)
        otherArea:SetPoint("BOTTOMLEFT", leftArea, "BOTTOMLEFT", 0, 0)
        otherArea:SetPoint("BOTTOMRIGHT", leftArea, "BOTTOMRIGHT", 0, 0)
    end

    LayoutLeft()
    leftArea:SetScript("OnShow", LayoutLeft)
    leftArea:SetScript("OnSizeChanged", LayoutLeft)

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
            status:SetText("")
            UpdateCmdGhost()
            isLoadingFields = false
            return
        end

        editCmd:SetText(entry.key and tostring(entry.key) or "")
        mainsBox:SetText(JoinLines(entry.mains or {}))
        mainBox:SetText(entry.mainText and tostring(entry.mainText) or "")
        otherBox:SetText(entry.otherText and tostring(entry.otherText) or "")
        status:SetText("")

        UpdateCmdGhost()

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

            UpdateCmdGhost()

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

    editCmd:SetScript("OnEditFocusGained", function() UpdateCmdGhost() end)
    editCmd:SetScript("OnEditFocusLost", function()
        UpdateCmdGhost()
        SaveFields(false)
    end)
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

                local keyTxt = (type(entry.key) == "string" and entry.key ~= "") and entry.key or "<new>"
                row.text:SetText("/fgo m " .. keyTxt)

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
