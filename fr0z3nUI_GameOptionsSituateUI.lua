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

local function GetActiveSpecID()
    if not (GetSpecialization and GetSpecializationInfo) then
        return nil
    end
    local specIndex = GetSpecialization()
    if not specIndex then
        return nil
    end
    local ok, specID = pcall(GetSpecializationInfo, specIndex)
    if not ok or type(specID) ~= "number" then
        return nil
    end
    return specID
end

local function EnsureLayoutArray()
    InitSV()
    local s = GetSettings()
    if not s then
        return {}
    end

    local specID = GetActiveSpecID()
    if specID then
        if type(s.actionBarLayoutBySpecAcc) ~= "table" then
            s.actionBarLayoutBySpecAcc = {}
        end
        if type(s.actionBarLayoutBySpecAcc[specID]) ~= "table" then
            s.actionBarLayoutBySpecAcc[specID] = {}
        end
        local t = s.actionBarLayoutBySpecAcc[specID]
        if t[1] == nil and next(t) ~= nil then
            s.actionBarLayoutBySpecAcc[specID] = {}
        end
        return s.actionBarLayoutBySpecAcc[specID]
    end

    -- Fallback (no spec API): legacy global layout.
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

local function SetStateTextYellowNoOff(btn, label, enabled)
    if enabled then
        btn:SetText(label .. ": |cffffff00ON|r")
    else
        btn:SetText("|cff888888" .. label .. "|r")
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

local function Trim(s)
    if type(s) ~= "string" then
        return ""
    end
    return s:gsub("^%s+", ""):gsub("%s+$", "")
end

local function GetSpellIDFromText(text)
    text = Trim(text)
    if text == "" then
        return nil
    end
    local n = tonumber(text)
    if n then
        n = math.floor(n)
        if n > 0 then
            return n
        end
    end
    if GetSpellInfo then
        local ok, _, _, _, _, _, id = pcall(GetSpellInfo, text)
        if ok and type(id) == "number" and id > 0 then
            return id
        end
    end
    return nil
end

local function GetEntryKind(entry)
    local k = entry and entry.kind
    if k == "spell" or k == "macro" then
        return k
    end
    return "macro"
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
        SetAcc2StateText(btn, "Situate", on)
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

function ns.SituateUI_Build(panel)
    if not (panel and CreateFrame) then
        return function() end
    end

    InitSV()

    local selectedIndex = nil
    local isLoadingFields = false

    -- Hint (centered under the tab bar)
    local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOP", panel, "TOP", 0, -54)
    hint:SetJustifyH("CENTER")
    hint:SetText("Place existing macros/spells into action slots. Slot range: 1-180. Applying is blocked in combat.")

    -- Top buttons
    local BTN_H = 22

    local btnEnabled = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnEnabled:SetSize(150, BTN_H)
    btnEnabled:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -74)

    local btnApply = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnApply:SetSize(110, BTN_H)
    btnApply:SetPoint("LEFT", btnEnabled, "RIGHT", 8, 0)
    btnApply:SetText("Apply")

    local btnUseHover = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnUseHover:SetSize(110, BTN_H)
    btnUseHover:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 12, 12)
    btnUseHover:SetText("Hover Fill")

    local btnDetect = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnDetect:SetSize(110, BTN_H)
    btnDetect:SetPoint("LEFT", btnUseHover, "RIGHT", 8, 0)

    local btnOverwrite = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnOverwrite:SetSize(120, BTN_H)
    btnOverwrite:SetPoint("LEFT", btnDetect, "RIGHT", 8, 0)

    local btnDebug = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnDebug:SetSize(100, BTN_H)
    do
        local root = panel.GetParent and panel:GetParent() or nil
        local reloadBtn = root and rawget(root, "_reloadBtn") or nil
        if reloadBtn and reloadBtn.GetObjectType then
            btnDebug:SetPoint("RIGHT", reloadBtn, "LEFT", -8, 0)
        else
            btnDebug:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -12, 12)
        end
    end

    local hoverText = panel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    hoverText:SetPoint("BOTTOMLEFT", btnUseHover, "TOPLEFT", 0, 6)
    hoverText:SetJustifyH("LEFT")
    hoverText:SetText("Hover: -")

    local detectorOn = false
    local hoverSlot, hoverType, hoverId = nil, nil, nil
    local lastHoverKey = nil
    local detectorFrame = CreateFrame("Frame")
    detectorFrame:Hide()

    local function SetDetectorButtonText()
        SetStateTextYellowNoOff(btnDetect, "Detector", detectorOn)
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

    -- Placements list (right)
    local listArea = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    listArea:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -10, -88)
    listArea:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -10, 50)
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

    -- Editor area (left)
    local editArea = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    editArea:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -88)
    editArea:SetPoint("BOTTOMRIGHT", listArea, "BOTTOMLEFT", -10, 0)
    editArea:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        tile = true,
        tileSize = 16,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    editArea:SetBackdropColor(0, 0, 0, 0.25)

    local editTitle = editArea:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    editTitle:SetPoint("TOPLEFT", editArea, "TOPLEFT", 6, -6)
    editTitle:SetText("")

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

    local labelKind = editArea:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    labelKind:SetPoint("LEFT", editSlot, "RIGHT", 12, 0)
    labelKind:SetText("Type")

    local btnKind = CreateFrame("Button", nil, editArea, "UIPanelButtonTemplate")
    btnKind:SetSize(90, 20)
    btnKind:SetPoint("LEFT", labelKind, "RIGHT", 8, 0)

    local labelValue = editArea:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    labelValue:SetPoint("LEFT", btnKind, "RIGHT", 12, 0)
    labelValue:SetText("Macro")

    local editValue = CreateFrame("EditBox", nil, editArea, "InputBoxTemplate")
    editValue:SetSize(220, 20)
    editValue:SetPoint("LEFT", labelValue, "RIGHT", 8, 0)
    editValue:SetAutoFocus(false)
    editValue:SetMaxLetters(96)

    local function SetStatusForEntry(entry)
        if type(entry) ~= "table" then
            status:SetText("")
            return
        end
        local slot = NormalizeSlot(entry.slot)
        local kind = GetEntryKind(entry)
        local valueText = Trim(entry.value or entry.name or "")
        local macroState = ""
        if kind == "spell" then
            local sid = GetSpellIDFromText(valueText)
            if sid then
                macroState = "spell ok"
            else
                macroState = "spell missing"
            end
        else
            local idx = SafeMacroIndexByName(valueText)
            macroState = (idx and idx > 0) and "macro ok" or "macro missing"
        end
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

    local function UpdateKindButton(entry)
        local k = GetEntryKind(entry)
        if k == "spell" then
            btnKind:SetText("Spell")
            labelValue:SetText("Spell")
        else
            btnKind:SetText("Macro")
            labelValue:SetText("Macro")
        end
    end

    local function LoadFields()
        isLoadingFields = true
        local entry = GetSelectedEntry()

        if not entry then
            editSlot:SetText("")
            editValue:SetText("")
            UpdateKindButton({ kind = "macro" })
            SetStatusForEntry(nil)
            isLoadingFields = false
            return
        end

        editSlot:SetText(entry.slot and tostring(entry.slot) or "")
        -- Back-compat: legacy entries used entry.name.
        local v = entry.value
        if type(v) ~= "string" or v == "" then
            v = entry.name
        end
        editValue:SetText(v and tostring(v) or "")
        UpdateKindButton(entry)
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

            local value = Trim(editValue:GetText() or "")
            entry.value = value
            -- keep legacy key in sync (core defaults to macro and reads entry.name)
            entry.name = value

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

    btnKind:SetScript("OnClick", function()
        local entry = GetSelectedEntry()
        if not entry then
            return
        end
        local k = GetEntryKind(entry)
        if k == "spell" then
            entry.kind = "macro"
        else
            entry.kind = "spell"
        end
        UpdateKindButton(entry)
        SetStatusForEntry(entry)
        if panel._ActionBarUI_RefreshList then
            panel:_ActionBarUI_RefreshList()
        end
    end)

    btnKind:SetScript("OnEnter", function()
        if not GameTooltip then return end
        GameTooltip:SetOwner(btnKind, "ANCHOR_RIGHT")
        GameTooltip:SetText("Type")
        GameTooltip:AddLine("Macro: places an existing macro by name.", 1, 1, 1, true)
        GameTooltip:AddLine("Spell: places an existing spell by spell name or spellID.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btnKind:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    editSlot:SetScript("OnEditFocusLost", function() SaveFields(false) end)
    editSlot:SetScript("OnTextChanged", function() SaveFields(true) end)
    editValue:SetScript("OnEditFocusLost", function() SaveFields(false) end)
    editValue:SetScript("OnTextChanged", function() SaveFields(true) end)

    local function RefreshButtons()
        InitSV()
        local s = GetSettings()
        local on = (s and s.actionBarEnabledAcc) and true or false
        SetAcc2StateTextYellow(btnEnabled, "Enabled", on)

        local ov = (s and s.actionBarOverwriteAcc) and true or false
        SetStateTextYellowNoOff(btnOverwrite, "Overwrite", ov)

        local dbg = (s and s.actionBarDebugAcc) and true or false
        SetStateTextYellowNoOff(btnDebug, "Debug", dbg)

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

    btnEnabled:SetScript("OnEnter", function()
        if not GameTooltip then return end
        GameTooltip:SetOwner(btnEnabled, "ANCHOR_RIGHT")
        GameTooltip:SetText("Enabled")
        GameTooltip:AddLine("Toggles automatic applying of placements.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btnEnabled:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    btnOverwrite:SetScript("OnEnter", function()
        if not GameTooltip then return end
        GameTooltip:SetOwner(btnOverwrite, "ANCHOR_RIGHT")
        GameTooltip:SetText("Overwrite")
        GameTooltip:AddLine("ON: allows replacing occupied action slots.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btnOverwrite:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    btnDebug:SetScript("OnEnter", function()
        if not GameTooltip then return end
        GameTooltip:SetOwner(btnDebug, "ANCHOR_RIGHT")
        GameTooltip:SetText("Debug")
        GameTooltip:AddLine("Prints debug info when applying placements.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btnDebug:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    btnUseHover:SetScript("OnEnter", function()
        if not GameTooltip then return end
        GameTooltip:SetOwner(btnUseHover, "ANCHOR_RIGHT")
        GameTooltip:SetText("Hover Fill")
        GameTooltip:AddLine("Copies detected action slot into Slot.", 1, 1, 1, true)
        GameTooltip:AddLine("If hovering a macro/spell, also fills Type + Value.", 1, 1, 1, true)
        GameTooltip:AddLine("Requires Detector ON and hovering a bar button.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btnUseHover:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

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
        GameTooltip:AddLine("Use 'Hover Slot' to fill the Slot field of the selected entry.", 1, 1, 1, true)
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

        local entry = GetSelectedEntry()
        if entry and hoverType == "macro" and hoverId then
            entry.kind = "macro"
            UpdateKindButton(entry)
            if GetMacroInfo then
                local ok, name = pcall(GetMacroInfo, hoverId)
                if ok and type(name) == "string" and name ~= "" then
                    editValue:SetText(name)
                end
            end
        elseif entry and hoverType == "spell" and hoverId then
            entry.kind = "spell"
            UpdateKindButton(entry)
            if GetSpellInfo then
                local ok, spellName = pcall(GetSpellInfo, hoverId)
                if ok and type(spellName) == "string" and spellName ~= "" then
                    editValue:SetText(spellName)
                else
                    editValue:SetText(tostring(hoverId))
                end
            else
                editValue:SetText(tostring(hoverId))
            end
        end
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
                local kind = GetEntryKind(entry)
                local value = Trim(entry.value or entry.name or "")
                if value == "" then
                    value = "(empty)"
                end
                local tag = (kind == "spell") and "[S]" or "[M]"
                row.text:SetText(string.format("%s: %s %s", slotTxt, tag, value))

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
        layout[#layout + 1] = { slot = nil, kind = "macro", value = "", name = "" }
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

-- Back-compat alias (older core builds may still call this)
ns.ActionBarUI_Build = ns.SituateUI_Build
