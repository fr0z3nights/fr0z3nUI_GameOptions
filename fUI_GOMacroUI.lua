local _, ns = ...

-- NOTE (FGO): Do NOT reference legacy standalone addons (e.g., HearthZone / global fHZ).
-- This UI reads from the current FGO modules and SavedVariables (AutoGame_*).

-- Macros tab UI (split out of Hearth module).

local function SafeLower(s)
    return tostring(s or ""):lower()
end

local function SetButtonTooltip(btn, tooltipText)
    if not (btn and tooltipText) then return end
    btn:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        local tt = tooltipText
        if type(tt) == "function" then
            tt = tt(self)
        end
        if not tt or tt == "" then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local first = true
        for line in tostring(tt):gmatch("[^\n]+") do
            if first then
                GameTooltip:SetText(line, 1, 1, 1)
                first = false
            else
                GameTooltip:AddLine(line, 0.9, 0.9, 0.9, true)
            end
        end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
end

local function FitFontStringToWidth(fs, text, maxWidth, targetHeight)
    if not (fs and fs.SetText and fs.GetFont and fs.SetFont) then
        return
    end

    local wantedText = tostring(text or "")
    fs:SetText(wantedText)

    local fontPath, fontSize, flags = fs:GetFont()
    if not fontPath then
        return
    end

    if not fs._fgoBaseFont then
        fs._fgoBaseFont = { path = fontPath, size = tonumber(fontSize) or 14, flags = flags }
    end

    local base = fs._fgoBaseFont
    if base and base.path then
        fs:SetFont(base.path, base.size or 14, base.flags)
        fontPath, fontSize, flags = fs:GetFont()
    end

    local w = tonumber(maxWidth) or 0
    if w <= 0 and fs.GetWidth then
        w = tonumber(fs:GetWidth()) or 0
    end
    if w <= 0 then
        w = 320
    end

    local startSize = tonumber(fontSize) or math.floor(tonumber(targetHeight) or 14)
    startSize = math.floor(startSize)
    if startSize < 10 then startSize = 10 end
    if startSize > 24 then startSize = 24 end

    local minSize = 6
    for s = startSize, minSize, -1 do
        fs:SetFont(fontPath, s, flags)
        -- Some clients only update width reliably after re-setting text.
        fs:SetText(wantedText)
        local curW = 0
        if fs.GetUnboundedStringWidth then
            curW = tonumber(fs:GetUnboundedStringWidth()) or 0
        else
            curW = tonumber(fs:GetStringWidth()) or 0
        end
        if curW <= w then
            break
        end
    end
end

local function GetPanelWidth(parent)
    local w = parent and parent.GetWidth and parent:GetWidth() or 0
    if not w or w <= 0 then
        w = 520
    end
    return w
end

local function MakeEditBoxBorderless(editBox)
    if not editBox then return end
    if editBox.Left and editBox.Left.Hide then editBox.Left:Hide() end
    if editBox.Middle and editBox.Middle.Hide then editBox.Middle:Hide() end
    if editBox.Right and editBox.Right.Hide then editBox.Right:Hide() end
    if editBox.SetTextInsets then
        editBox:SetTextInsets(6, 6, 2, 2)
    end
end

local function AttachGhostText(editBox, text, point)
    if not (editBox and editBox.CreateFontString) then
        return
    end

    local ghost = editBox:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    ghost:SetText(tostring(text or ""))
    ghost:SetJustifyH("LEFT")
    if point == "TOPLEFT" then
        ghost:SetPoint("TOPLEFT", editBox, "TOPLEFT", 6, -6)
    else
        ghost:SetPoint("LEFT", editBox, "LEFT", 6, 0)
    end

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

local function BuildMacrosPanel(parent)
    if not parent or parent._fgoMacrosBuilt then
        return
    end
    parent._fgoMacrosBuilt = true

    if not (ns and ns.Macros) then
        return
    end

    local M = ns.Macros
    local H = (ns and ns.Hearth) or {}

    local BTN_W, BTN_H = 95, 23 -- ~5% bigger than 90x22 (Reload UI)
    local BTN_GAP = BTN_H

    -- New layout: split tab into Macro controls (left 1/3) and Home (right 2/3)
    local COL_GAP = 12
    local macroCol = CreateFrame("Frame", nil, parent)
    local homeCol = CreateFrame("Frame", nil, parent)
    macroCol:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    macroCol:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    homeCol:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    homeCol:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    homeCol:SetPoint("LEFT", macroCol, "RIGHT", COL_GAP, 0)

    -- Ensure the macro column is never zero-width (which can cause the Home column to overlap it),
    -- and keep it above Home in case of any overlap.
    if macroCol.SetWidth then
        macroCol:SetWidth(260)
    end
    if macroCol.SetFrameLevel and homeCol.GetFrameLevel and homeCol.SetFrameLevel then
        homeCol:SetFrameLevel((parent and parent.GetFrameLevel and parent:GetFrameLevel() or 0) + 5)
        macroCol:SetFrameLevel(homeCol:GetFrameLevel() + 5)
    end

    local colSep = parent:CreateTexture(nil, "ARTWORK")
    colSep:SetColorTexture(1, 1, 1, 0.12)
    colSep:SetWidth(1)

    -- Home content moved onto this tab (top area)
    local homeArea = CreateFrame("Frame", nil, homeCol)
    homeArea:SetAllPoints(homeCol)

    -- Embed Home panel but place its credit line under the saved-locations window.
    -- (The Home panel resolves "SAVED_BOX" to its saved-locations frame.)
    homeArea._fgoCreditAnchor = "SAVED_BOX"
    homeArea._fgoCreditYOffset = -12

    if type(ns.BuildHomePanel) == "function" then
        ns.BuildHomePanel(homeArea)
    end

    -- Forward declarations (used by Optional/Hearth helpers below)
    local btnHS06, btnHS07, btnHS11, btnHS12, btnHS78
    local btnInstanceIO, btnInstanceReset, btnRez, btnRezCombat
    local btnScriptErrors
    local hearthPopout, btnCreateHearthMacro

    -- Optional macro additions (left popout)
    local btnOptional = CreateFrame("Button", nil, macroCol, "UIPanelButtonTemplate")
    btnOptional:SetSize(80, 20)
    btnOptional:SetText("+ Macro")
    btnOptional:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 12, 12)

    -- Popout anchored OUTSIDE the tab (to the right) so it doesn't overlap the Home column.
    local optPopout = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    optPopout:SetWidth(260)
    optPopout:SetPoint("TOPLEFT", parent, "TOPRIGHT", COL_GAP, 0)
    optPopout:SetPoint("BOTTOMLEFT", parent, "BOTTOMRIGHT", COL_GAP, 0)
    optPopout:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        tile = true, tileSize = 16,
    })
    optPopout:SetBackdropColor(0, 0, 0, 0.85)
    optPopout:Hide()

    local optTitle = optPopout:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    optTitle:SetPoint("TOP", optPopout, "TOP", 0, -10)
    optTitle:SetText("Add to Macro")

    local function GetCurrentMacroIcon()
        if type(M.GetDefaultMacroIcon) == "function" then
            local icon = M.GetDefaultMacroIcon()
            if icon ~= nil then
                return icon
            end
        end
        return 134400
    end

    local function SetCurrentMacroIcon(icon)
        if type(M.SetDefaultMacroIcon) == "function" then
            return M.SetDefaultMacroIcon(icon)
        end
        return nil
    end

    local function GetMacroPopupButtons(frame)
        if type(frame) ~= "table" then return nil, nil end
        local ok = frame.OkayButton or frame.OKButton or frame.AcceptButton or frame.SaveButton
        local cancel = frame.CancelButton or frame.CloseButton

        ok = ok or rawget(_G, "MacroPopupOkayButton") or rawget(_G, "MacroPopupFrameOkayButton")
        cancel = cancel or rawget(_G, "MacroPopupCancelButton") or rawget(_G, "MacroPopupFrameCancelButton")
        return ok, cancel
    end

    local function GetMacroPopupSelectedIcon()
        local f = rawget(_G, "MacroPopupFrame")
        if not f then return nil end

        local icon = f.selectedIcon or f.icon or f.selectedIconTexture or f.selectedTexture
        if icon ~= nil and icon ~= "" then
            return icon
        end

        local selector = f.IconSelector or f.iconSelector
        if selector then
            if type(selector.GetSelectedIconID) == "function" then
                local ok, id = pcall(selector.GetSelectedIconID, selector)
                if ok and id then return id end
            end
            if type(selector.GetSelectedIcon) == "function" then
                local ok, sel = pcall(selector.GetSelectedIcon, selector)
                if ok and sel then return sel end
            end
        end

        local iconButton = f.SelectedIconButton or f.IconButton or f.SelectedIcon or f.SelectedTexture
        if iconButton then
            if iconButton.Icon and type(iconButton.Icon.GetTexture) == "function" then
                local tex = iconButton.Icon:GetTexture()
                if tex then return tex end
            end
            if type(iconButton.GetNormalTexture) == "function" then
                local nt = iconButton:GetNormalTexture()
                if nt and type(nt.GetTexture) == "function" then
                    local tex = nt:GetTexture()
                    if tex then return tex end
                end
            end
            if type(iconButton.GetTexture) == "function" then
                local tex = iconButton:GetTexture()
                if tex then return tex end
            end
        end

        return nil
    end

    local function TryLoadBlizzardMacroUI()
        if rawget(_G, "MacroPopupFrame") then
            return true
        end

        local okLoad = false
        if C_AddOns and type(C_AddOns.LoadAddOn) == "function" then
            okLoad = pcall(C_AddOns.LoadAddOn, "Blizzard_MacroUI")
        else
            local loadAddOn = rawget(_G, "LoadAddOn")
            if type(loadAddOn) == "function" then
                okLoad = pcall(loadAddOn, "Blizzard_MacroUI")
            end
        end

        if type(MacroFrame_LoadUI) == "function" then
            pcall(MacroFrame_LoadUI)
        end

        return rawget(_G, "MacroPopupFrame") ~= nil or okLoad
    end

    local function OpenBlizzardMacroIconPicker(onAccept)
        if not TryLoadBlizzardMacroUI() then
            if type(M.Print) == "function" then
                M.Print("Blizzard Macro UI not available.")
            end
            return
        end

        local f = rawget(_G, "MacroPopupFrame")
        if not f or type(f.Show) ~= "function" then
            if type(M.Print) == "function" then
                M.Print("Blizzard Macro icon picker not available.")
            end
            return
        end

        if not f._fgoIconPickerHooked and type(f.HookScript) == "function" then
            f._fgoIconPickerHooked = true
            f:HookScript("OnHide", function(self)
                local state = rawget(self, "_fgoIconPickerState")
                if type(state) ~= "table" then
                    return
                end

                if state.okBtn and state.okBtn.SetScript then
                    state.okBtn:SetScript("OnClick", state.okScript)
                end
                if state.cancelBtn and state.cancelBtn.SetScript then
                    state.cancelBtn:SetScript("OnClick", state.cancelScript)
                end

                rawset(self, "_fgoIconPickerState", nil)

                if state.didAccept and type(state.onAccept) == "function" then
                    local icon = state.selectedIcon or GetMacroPopupSelectedIcon() or GetCurrentMacroIcon()
                    pcall(state.onAccept, icon)
                end
            end)
        end

        local okBtn, cancelBtn = GetMacroPopupButtons(f)
        if not okBtn or not cancelBtn or type(okBtn.SetScript) ~= "function" or type(cancelBtn.SetScript) ~= "function" then
            if type(M.Print) == "function" then
                M.Print("Could not hook Blizzard Macro icon picker buttons.")
            end
            return
        end

        local state = {
            okBtn = okBtn,
            cancelBtn = cancelBtn,
            okScript = (type(okBtn.GetScript) == "function") and okBtn:GetScript("OnClick") or nil,
            cancelScript = (type(cancelBtn.GetScript) == "function") and cancelBtn:GetScript("OnClick") or nil,
            onAccept = onAccept,
            didAccept = false,
            selectedIcon = nil,
        }
        rawset(f, "_fgoIconPickerState", state)

        okBtn:SetScript("OnClick", function()
            state.didAccept = true
            state.selectedIcon = GetMacroPopupSelectedIcon()
            f:Hide()
        end)
        cancelBtn:SetScript("OnClick", function()
            state.didAccept = false
            f:Hide()
        end)

        if IconSelectorPopupFrameModes and IconSelectorPopupFrameModes.New then
            f.mode = IconSelectorPopupFrameModes.New
        else
            f.mode = f.mode or "new"
        end

        f:Show()
    end

    local btnPickIcon = CreateFrame("Button", nil, optPopout, "UIPanelButtonTemplate")
    btnPickIcon:SetSize(72, 18)
    btnPickIcon:SetPoint("TOPRIGHT", optPopout, "TOPRIGHT", -12, -10)
    btnPickIcon:SetText("Icon")

    local iconPreview = optPopout:CreateTexture(nil, "OVERLAY")
    iconPreview:SetSize(18, 18)
    iconPreview:SetPoint("RIGHT", btnPickIcon, "LEFT", -6, 0)

    local function UpdateIconPreview()
        local icon = GetCurrentMacroIcon()
        if type(iconPreview.SetTexture) == "function" then
            if type(icon) == "string" and icon ~= "" and not icon:find("[/\\]") and not icon:find("Interface") then
                iconPreview:SetTexture("Interface\\Icons\\" .. icon)
            else
                iconPreview:SetTexture(icon)
            end
        end
    end
    UpdateIconPreview()

    SetButtonTooltip(btnPickIcon, function()
        return "Icon\n\nPick the icon used when creating/updating macros from this panel."
    end)

    btnPickIcon:SetScript("OnClick", function()
        OpenBlizzardMacroIconPicker(function(icon)
            local saved = SetCurrentMacroIcon(icon)
            if saved ~= nil then
                UpdateIconPreview()
            end
        end)
    end)

    local nameBox = CreateFrame("EditBox", nil, optPopout, "InputBoxTemplate")
    nameBox:SetSize(220, 18)
    nameBox:SetPoint("TOP", optPopout, "TOP", 0, -34)
    nameBox:SetAutoFocus(false)
    nameBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    MakeEditBoxBorderless(nameBox)
    AttachGhostText(nameBox, "Name of Addition")

    local textLabel = optPopout:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    textLabel:SetPoint("TOPLEFT", optPopout, "TOPLEFT", 12, -58)
    textLabel:SetText("Text:")

    local textScroll = CreateFrame("ScrollFrame", nil, optPopout, "UIPanelScrollFrameTemplate")
    textScroll:SetPoint("TOPLEFT", textLabel, "BOTTOMLEFT", -2, -6)
    textScroll:SetPoint("TOPRIGHT", optPopout, "TOPRIGHT", -28, -78)
    textScroll:SetHeight(120)
    if textScroll.ScrollBar and textScroll.ScrollBar.Hide then
        textScroll.ScrollBar:Hide()
    end

    local textBox = CreateFrame("EditBox", nil, textScroll, "InputBoxTemplate")
    textBox:SetMultiLine(true)
    textBox:SetAutoFocus(false)
    textBox:SetFontObject("ChatFontNormal")
    textBox:SetWidth(220)
    textBox:SetHeight(120)
    textBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    textBox:SetScript("OnEnterPressed", nil)
    MakeEditBoxBorderless(textBox)
    AttachGhostText(textBox, "What do you want it to add?", "TOPLEFT")
    textScroll:SetScrollChild(textBox)

    local btnAddOptional = CreateFrame("Button", nil, optPopout, "UIPanelButtonTemplate")
    btnAddOptional:SetSize(60, 18)
    btnAddOptional:SetText("Add")
    btnAddOptional:SetPoint("TOP", textScroll, "BOTTOM", 0, -10)

    local listScroll = CreateFrame("ScrollFrame", nil, optPopout, "UIPanelScrollFrameTemplate")
    listScroll:SetPoint("TOPLEFT", btnAddOptional, "BOTTOMLEFT", -110, -12)
    listScroll:SetPoint("TOPRIGHT", btnAddOptional, "BOTTOMRIGHT", 110, -12)
    listScroll:SetPoint("BOTTOMLEFT", optPopout, "BOTTOMLEFT", 12, 12)
    listScroll:SetPoint("BOTTOMRIGHT", optPopout, "BOTTOMRIGHT", -28, 12)

    local listChild = CreateFrame("Frame", nil, listScroll)
    listChild:SetSize(1, 1)
    listScroll:SetScrollChild(listChild)

    SetButtonTooltip(btnOptional, "+ Macro\n\nAdd lines into macros when creating them")
    SetButtonTooltip(nameBox, "Name\n\nExample: Safari Hat")
    SetButtonTooltip(textBox, "Text\n\nThese lines will be inserted into macros when this option is selected.")
    SetButtonTooltip(btnAddOptional, "Add\n\nAdds/updates the entry by name.")

    local optionalRows = {}
    local editingOldName

    local function StripCountSuffix(name)
        name = tostring(name or "")
        return (name:gsub("%s*%(%d+%)%s*$", ""))
    end

    local function WithCountSuffix(name, count)
        name = StripCountSuffix(name)
        local n = tonumber(count) or 0
        if n > 0 then
            return name .. " (" .. n .. ")"
        end
        return name
    end

    local function MacroWouldFit(rawBody)
        if type(rawBody) ~= "string" then return true end
        local max = tonumber(M.MAX_MACRO_CHARS) or 255
        local body = rawBody
        if type(M.ApplyOptionalLines) == "function" then
            body = M.ApplyOptionalLines(body)
        end
        return #tostring(body or "") <= max
    end

    local function MacroUsesItem(rawBody)
        if type(rawBody) ~= "string" then return false end
        local s = rawBody:gsub("\r\n", "\n"):gsub("\r", "\n")
        return s:match("/use[^\n]*item:%d+") ~= nil
    end

    local function UpdateMacroCreateButtonsEnabled()
        -- Disable any macro creation buttons that would exceed the macro length limit.
        -- If '#showtooltip (25)' is selected, also disable any macros that do not '/use item:<id>'.
        local showTooltipSelected = (type(M.IsOptionalEntrySelected) == "function") and M.IsOptionalEntrySelected("#showtooltip (25)") or false

        local rawHS06 = (M.MacroBody_HS_Garrison and M.MacroBody_HS_Garrison()) or ""
        if btnHS06 then btnHS06:SetEnabled(MacroWouldFit(rawHS06) and (not showTooltipSelected or MacroUsesItem(rawHS06))) end

        local rawHS07 = (M.MacroBody_HS_Dalaran and M.MacroBody_HS_Dalaran()) or ""
        if btnHS07 then btnHS07:SetEnabled(MacroWouldFit(rawHS07) and (not showTooltipSelected or MacroUsesItem(rawHS07))) end

        local rawHS11 = (M.MacroBody_HS_Dornogal and M.MacroBody_HS_Dornogal()) or ""
        if btnHS11 then btnHS11:SetEnabled(MacroWouldFit(rawHS11) and (not showTooltipSelected or MacroUsesItem(rawHS11))) end

        local rawHS12 = (M.MacroBody_HS_Arcantina and M.MacroBody_HS_Arcantina()) or ""
        if btnHS12 then btnHS12:SetEnabled(MacroWouldFit(rawHS12) and (not showTooltipSelected or MacroUsesItem(rawHS12))) end

        local rawHS78 = (M.MacroBody_HS_Whistle and M.MacroBody_HS_Whistle()) or ""
        if btnHS78 then btnHS78:SetEnabled(MacroWouldFit(rawHS78) and (not showTooltipSelected or MacroUsesItem(rawHS78))) end

        local rawIO = (M.MacroBody_InstanceIO and M.MacroBody_InstanceIO()) or ""
        if btnInstanceIO then btnInstanceIO:SetEnabled(MacroWouldFit(rawIO) and (not showTooltipSelected or MacroUsesItem(rawIO))) end

        local rawReset = (M.MacroBody_InstanceReset and M.MacroBody_InstanceReset()) or ""
        if btnInstanceReset then btnInstanceReset:SetEnabled(MacroWouldFit(rawReset) and (not showTooltipSelected or MacroUsesItem(rawReset))) end

        local rawRez = (M.MacroBody_Rez and M.MacroBody_Rez()) or ""
        if btnRez then btnRez:SetEnabled(MacroWouldFit(rawRez) and (not showTooltipSelected or MacroUsesItem(rawRez))) end

        local rawRezCombat = (M.MacroBody_RezCombat and M.MacroBody_RezCombat()) or ""
        if btnRezCombat then btnRezCombat:SetEnabled(MacroWouldFit(rawRezCombat) and (not showTooltipSelected or MacroUsesItem(rawRezCombat))) end

        local rawErrors = (M.MacroBody_ScriptErrors and M.MacroBody_ScriptErrors()) or ""
        if btnScriptErrors then btnScriptErrors:SetEnabled(MacroWouldFit(rawErrors) and (not showTooltipSelected or MacroUsesItem(rawErrors))) end

        if hearthPopout and hearthPopout:IsShown() and btnCreateHearthMacro and type(H.BuildMacroText) == "function" and type(H.EnsureInit) == "function" then
            local db2 = H.EnsureInit()
            local raw = H.BuildMacroText(db2)
            local ok = MacroWouldFit(raw) and (not showTooltipSelected or MacroUsesItem(raw))
            btnCreateHearthMacro:SetEnabled(ok)
        end
    end

    local function RebuildOptionalList()
        if type(M.GetOptionalEntries) ~= "function" then
            return
        end

        local entries = M.GetOptionalEntries() or {}
        local rowH = 18

        local w = listScroll.GetWidth and listScroll:GetWidth() or 0
        if w and w > 0 and listChild.SetWidth then
            listChild:SetWidth(w)
        end

        local y = 0
        for i = 1, #entries do
            local e = entries[i]
            local name = type(e) == "table" and e.name or nil
            if name and name ~= "" then
                local row = optionalRows[i]
                if not row then
                    row = {}

                    local main = CreateFrame("Button", nil, listChild, "UIPanelButtonTemplate")
                    main:SetHeight(rowH)
                    local fs = main.GetFontString and main:GetFontString() or nil
                    if fs and fs.SetJustifyH then
                        fs:SetJustifyH("LEFT")
                    end

                    local btnEdit = CreateFrame("Button", nil, listChild, "UIPanelButtonTemplate")
                    btnEdit:SetSize(20, rowH)
                    btnEdit:SetText("E")

                    local btnDel = CreateFrame("Button", nil, listChild, "UIPanelButtonTemplate")
                    btnDel:SetSize(20, rowH)
                    btnDel:SetText("D")

                    row.main = main
                    row.edit = btnEdit
                    row.del = btnDel
                    optionalRows[i] = row
                end

                row.main:Show()
                row.edit:Show()
                row.del:Show()

                row.main:ClearAllPoints()
                row.main:SetPoint("TOPLEFT", listChild, "TOPLEFT", 0, -y)
                row.main:SetPoint("TOPRIGHT", listChild, "TOPRIGHT", -44, -y)
                row.main:SetText(tostring(name))

                row.edit:ClearAllPoints()
                row.edit:SetPoint("TOPLEFT", row.main, "TOPRIGHT", 2, 0)

                row.del:ClearAllPoints()
                row.del:SetPoint("TOPLEFT", row.edit, "TOPRIGHT", 2, 0)

                local selected = (type(M.IsOptionalEntrySelected) == "function") and M.IsOptionalEntrySelected(name) or false
                if selected then row.main:LockHighlight() else row.main:UnlockHighlight() end

                row.main:SetScript("OnClick", function()
                    if type(M.ToggleOptionalEntry) == "function" then
                        M.ToggleOptionalEntry(name)
                    end
                    RebuildOptionalList()
                    UpdateMacroCreateButtonsEnabled()
                end)

                row.edit:SetScript("OnClick", function()
                    editingOldName = name
                    nameBox:SetText(tostring(name))
                    if type(M.GetOptionalEntryText) == "function" then
                        textBox:SetText(tostring(M.GetOptionalEntryText(name) or ""))
                    else
                        textBox:SetText("")
                    end
                    nameBox:SetFocus()
                    if nameBox.HighlightText then
                        nameBox:HighlightText()
                    end
                end)

                row.del:SetScript("OnClick", function()
                    if type(M.DeleteOptionalEntry) ~= "function" then
                        return
                    end
                    local ok, why = M.DeleteOptionalEntry(name)
                    if not ok then
                        if type(M.Print) == "function" then
                            M.Print(why or "Could not delete")
                        end
                    end
                    if editingOldName == name then
                        editingOldName = nil
                        nameBox:SetText("")
                        textBox:SetText("")
                    end
                    RebuildOptionalList()
                    UpdateMacroCreateButtonsEnabled()
                end)

                y = y + rowH + 2
            end
        end

        for i = #entries + 1, #optionalRows do
            local row = optionalRows[i]
            if row then
                if row.main and row.main.Hide then row.main:Hide() end
                if row.edit and row.edit.Hide then row.edit:Hide() end
                if row.del and row.del.Hide then row.del:Hide() end
            end
        end

        listChild:SetHeight(math.max(1, y))
    end

    btnAddOptional:SetScript("OnClick", function()
        if type(M.AddOrUpdateOptionalEntry) ~= "function" then
            return
        end

        local rawName = tostring(nameBox:GetText() or "")
        local text = tostring(textBox:GetText() or "")
        text = text:gsub("\r\n", "\n"):gsub("\r", "\n")
        local count = #text
        local name = WithCountSuffix(rawName, count)

        if editingOldName and editingOldName ~= "" and editingOldName ~= name and type(M.DeleteOptionalEntry) == "function" then
            M.DeleteOptionalEntry(editingOldName)
        end

        local ok, why = M.AddOrUpdateOptionalEntry(name, text)
        if not ok then
            M.Print(why or "Could not add")
            return
        end

        editingOldName = nil

        nameBox:SetText("")
        textBox:SetText("")
        nameBox:ClearFocus()
        textBox:ClearFocus()

        RebuildOptionalList()
        UpdateMacroCreateButtonsEnabled()
    end)

    optPopout:SetScript("OnShow", function()
        UpdateIconPreview()
        RebuildOptionalList()
        UpdateMacroCreateButtonsEnabled()
    end)
    btnOptional:SetScript("OnClick", function()
        if optPopout:IsShown() then optPopout:Hide() else optPopout:Show() end
    end)

    -- Macro scope (Account/Character) - keep this as a simple label-style button (not like the other buttons)
    local macroScopeBtn = CreateFrame("Button", nil, macroCol)
    macroScopeBtn:SetSize(170, BTN_H)

    local macroScopeText = macroScopeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    macroScopeText:SetPoint("LEFT", macroScopeBtn, "LEFT", 0, 0)
    macroScopeText:SetPoint("RIGHT", macroScopeBtn, "RIGHT", 0, 0)
    macroScopeText:SetJustifyH("CENTER")
    macroScopeBtn._text = macroScopeText

    SetButtonTooltip(macroScopeBtn, function()
        local perChar = (type(M.GetMacroPerCharSetting) == "function") and M.GetMacroPerCharSetting() or false
        local current = perChar and "CHARACTER" or "ACCOUNT"
        local nextScope = perChar and "ACCOUNT" or "CHARACTER"
        local what = perChar and "character-only" or "account-wide"
        return "Macro Creation Scope\n\nCurrent: " .. current .. "\nCreates/updates " .. what .. " macros.\n\nSwitches to: " .. nextScope
    end)

    local function UpdateMacroScopeUI()
        local perChar = (type(M.GetMacroPerCharSetting) == "function") and M.GetMacroPerCharSetting() or false
        if perChar then
            macroScopeText:SetText("Character Macro")
        else
            macroScopeText:SetText("Account Macro")
        end
    end

    macroScopeBtn:SetScript("OnClick", function()
        if type(M.SetMacroPerCharSetting) ~= "function" or type(M.GetMacroPerCharSetting) ~= "function" then
            return
        end

        M.SetMacroPerCharSetting(not M.GetMacroPerCharSetting())
        UpdateMacroScopeUI()
    end)

    macroScopeBtn:SetScript("OnShow", UpdateMacroScopeUI)

    -- Helpers for macro buttons
    local function MakeMacroButton(text, bodyFn, tooltipText, macroNameOverride, perCharacter)
        local btn = CreateFrame("Button", nil, macroCol, "UIPanelButtonTemplate")
        btn:SetSize(BTN_W, BTN_H)
        btn:SetText(text)
        if tooltipText and tooltipText ~= "" then
            SetButtonTooltip(btn, tooltipText)
        end
        btn:SetScript("OnClick", function()
            local macroName = tostring(macroNameOverride or text)
            local body = bodyFn and bodyFn() or ""
            local icon = GetCurrentMacroIcon()
            M.CreateOrUpdateNamedMacro(macroName, body, perCharacter, icon)
            if type(M.ClearOptionalSelections) == "function" then
                M.ClearOptionalSelections()
            end
            RebuildOptionalList()
            UpdateMacroCreateButtonsEnabled()
        end)
        return btn
    end

    -- Macro buttons (layout defined later)
    btnHS06 = MakeMacroButton("HS 06 Garrison", M.MacroBody_HS_Garrison)
    btnHS07 = MakeMacroButton("HS 07 Dalaran", M.MacroBody_HS_Dalaran)
    btnHS11 = MakeMacroButton("HS 11 Dornogal", M.MacroBody_HS_Dornogal)
    btnHS12 = MakeMacroButton("HS 12 Arcantina", M.MacroBody_HS_Arcantina)
    btnHS78 = MakeMacroButton("HS 78 Whistle", M.MacroBody_HS_Whistle, "Legion/BFA Flight Points\nZaralek Caverns Mitts")

    btnInstanceIO = MakeMacroButton("Instance IO", M.MacroBody_InstanceIO, "Teleport to/from LFG Instances")
    btnInstanceReset = MakeMacroButton("Instance Reset", M.MacroBody_InstanceReset)
    btnRez = MakeMacroButton("Rez", M.MacroBody_Rez)
    btnRezCombat = MakeMacroButton("Rez Combat", M.MacroBody_RezCombat)

    btnScriptErrors = MakeMacroButton("Script Errors", M.MacroBody_ScriptErrors)

    -- Home row
    local function NormalizeOwnedHouses(raw)
        if type(raw) ~= "table" then
            return {}
        end
        if raw[1] and type(raw[1]) == "table" then
            return raw
        end
        if type(raw.houses) == "table" and raw.houses[1] then
            return raw.houses
        end
        if type(raw.ownedHouses) == "table" and raw.ownedHouses[1] then
            return raw.ownedHouses
        end
        if type(raw.playerOwnedHouses) == "table" and raw.playerOwnedHouses[1] then
            return raw.playerOwnedHouses
        end

        local keyed = {}
        for k, v in pairs(raw) do
            if type(k) == "number" and type(v) == "table" then
                keyed[#keyed + 1] = { k = k, v = v }
            end
        end
        table.sort(keyed, function(a, b) return a.k < b.k end)
        if #keyed > 0 then
            local out = {}
            for i = 1, #keyed do
                out[i] = keyed[i].v
            end
            return out
        end

        local out = {}
        for _, v in pairs(raw) do
            if type(v) == "table" and (v.houseGUID ~= nil or v.neighborhoodGUID ~= nil or v.plotID ~= nil) then
                out[#out + 1] = v
            end
        end
        return out
    end

    -- Hearth selection row + popout
    local btnHSHearth = CreateFrame("Button", nil, macroCol, "UIPanelButtonTemplate")
    btnHSHearth:SetSize(BTN_W, BTN_H)
    btnHSHearth:SetText("HS Hearth")

    ---@type any
    local hearthZoneLine = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    hearthZoneLine:SetJustifyH("CENTER")
    hearthZoneLine:SetWordWrap(false)
    if hearthZoneLine.SetMaxLines then hearthZoneLine:SetMaxLines(1) end
    hearthZoneLine:SetText("")

    hearthPopout = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    hearthPopout:SetWidth(360)
    hearthPopout:SetPoint("TOPLEFT", parent, "TOPRIGHT", COL_GAP, 0)
    hearthPopout:SetPoint("BOTTOMLEFT", parent, "BOTTOMRIGHT", COL_GAP, 0)
    hearthPopout:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        tile = true, tileSize = 16,
    })
    hearthPopout:SetBackdropColor(0, 0, 0, 0.85)
    hearthPopout:Hide()

    local popoutClose = CreateFrame("Button", nil, hearthPopout, "UIPanelCloseButton")
    popoutClose:SetPoint("TOPRIGHT", hearthPopout, "TOPRIGHT", -3, -3)

    local popoutFilter = CreateFrame("EditBox", nil, hearthPopout, "InputBoxTemplate")
    popoutFilter:SetSize(200, 18)
    popoutFilter:SetPoint("TOP", hearthPopout, "TOP", 0, -12)
    popoutFilter:SetAutoFocus(false)
    popoutFilter:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    SetButtonTooltip(popoutFilter, "Type to filter\nOr enter an itemID to add")

    local btnAll = CreateFrame("Button", nil, hearthPopout, "UIPanelButtonTemplate")
    btnAll:SetSize(56, 18)
    btnAll:SetPoint("BOTTOM", hearthPopout, "BOTTOM", -(56 + 10), 42)
    btnAll:SetText("All")

    SetButtonTooltip(btnAll, function()
        if type(H.EnsureInit) ~= "function" then
            return "All\n\nShows the full hearthstone list."
        end
        local db2 = H.EnsureInit()
        local on = db2.toyShowAll and true or false
        return "All\n\nToggle showing ALL hearthstones in the list.\n\nCurrently: " .. (on and "ON" or "OFF")
    end)

    local btnAuto = CreateFrame("Button", nil, hearthPopout, "UIPanelButtonTemplate")
    btnAuto:SetSize(56, 18)
    btnAuto:SetPoint("LEFT", btnAll, "RIGHT", 10, 0)
    btnAuto:SetText("Auto")

    SetButtonTooltip(btnAuto, function()
        if type(H.EnsureInit) ~= "function" then
            return "Auto\n\nAuto-rotates hearthstones when creating the macro."
        end
        local db2 = H.EnsureInit()
        local on = db2.autoRotate and true or false
        return "Auto\n\nWhen ON, 'Create Macro' will use a rolled hearthstone automatically.\n\nCurrently: " .. (on and "ON" or "OFF")
    end)

    local btnRoll = CreateFrame("Button", nil, hearthPopout, "UIPanelButtonTemplate")
    btnRoll:SetSize(56, 18)
    btnRoll:SetPoint("LEFT", btnAuto, "RIGHT", 10, 0)
    btnRoll:SetText("Roll")

    SetButtonTooltip(btnRoll, "Roll\n\nPick a random hearthstone from the list for this macro.")

    local scroll = CreateFrame("ScrollFrame", nil, hearthPopout, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", hearthPopout, "TOPLEFT", 10, -44)
    scroll:SetPoint("TOPRIGHT", hearthPopout, "TOPRIGHT", -28, -44)
    scroll:SetPoint("BOTTOM", hearthPopout, "BOTTOM", 0, 74)

    local scrollChild = CreateFrame("Frame", nil, scroll)
    scrollChild:SetSize(1, 1)
    scroll:SetScrollChild(scrollChild)

    btnCreateHearthMacro = CreateFrame("Button", nil, hearthPopout, "UIPanelButtonTemplate")
    btnCreateHearthMacro:SetSize(BTN_W, BTN_H)
    btnCreateHearthMacro:SetPoint("BOTTOM", hearthPopout, "BOTTOM", 0, 12)
    btnCreateHearthMacro:SetText("Create Macro")

    local function UpdateHearthZoneLine()
        if type(H.GetCurrentDisplayText) ~= "function" then
            hearthZoneLine:SetText("")
            return
        end
        local bind, zone = H.GetCurrentDisplayText()
        local line = tostring(bind or "")
        if zone and zone ~= "" then
            line = line .. ", " .. tostring(zone)
        end

        local maxW = hearthZoneLine._maxWidth
        if not maxW or maxW <= 0 then
            maxW = hearthZoneLine.GetWidth and hearthZoneLine:GetWidth() or 0
        end
        if not maxW or maxW <= 0 then
            maxW = 320
        end

        FitFontStringToWidth(hearthZoneLine, line, maxW, BTN_H)
    end

    local function UpdatePopoutButtons()
        if type(H.EnsureInit) ~= "function" then
            return
        end

    -- Keep the HS location line in sync with bind/zone changes.
    do
        local ev = CreateFrame("Frame")
        ev:RegisterEvent("PLAYER_ENTERING_WORLD")
        ev:RegisterEvent("UPDATE_BINDINGS")
        ev:RegisterEvent("HEARTHSTONE_BOUND")
        ev:SetScript("OnEvent", function()
            if parent and parent.IsShown and parent:IsShown() then
                UpdateHearthZoneLine()
            end
        end)
    end
        local db2 = H.EnsureInit()
        if db2.toyShowAll then btnAll:LockHighlight() else btnAll:UnlockHighlight() end
        if db2.autoRotate then btnAuto:LockHighlight() else btnAuto:UnlockHighlight() end

        local hasSelection = (tonumber(db2.selectedUseItemID) ~= nil)
        local canCreate = (db2.autoRotate and true or false) or hasSelection
        btnCreateHearthMacro:SetEnabled(canCreate)

        if canCreate and type(H.BuildMacroText) == "function" then
            local body = H.BuildMacroText(db2)
            if type(M.ApplyOptionalLines) == "function" then
                body = M.ApplyOptionalLines(body)
            end
            local max = tonumber(M.MAX_MACRO_CHARS) or 255
            if #tostring(body or "") > max then
                btnCreateHearthMacro:SetEnabled(false)
            end
        end
    end

    local function GetPopoutList()
        if type(H.EnsureInit) ~= "function" then
            return {}
        end
        local db2 = H.EnsureInit()
        local filterText = tostring(db2.toyFilter or "")

        local curated = H.CURATED_USE_ITEMS or {}
        local pass = H.PassToyFilter
        local getName = H.GetUseItemName
        local hasItem = H.HasUseItem

        local list = {}
        local seen = {}
        local function Add(id, label)
            id = tonumber(id)
            if not id or id <= 0 then return end
            if seen[id] then return end
            local name = (type(getName) == "function") and getName(id, label) or ("item:" .. tostring(id))
            if type(pass) == "function" then
                if not pass(name, filterText) then return end
            else
                local ft = SafeLower(filterText)
                if ft ~= "" and not SafeLower(name):find(ft, 1, true) then return end
            end

            local owned = (type(hasItem) == "function") and (hasItem(id) == true) or true
            list[#list + 1] = { id = id, name = tostring(name), owned = owned }
            seen[id] = true
        end

        if type(db2.customUseItems) == "table" then
            for _, id in ipairs(db2.customUseItems) do
                Add(id)
            end
        end

        for _, e in ipairs(curated) do
            Add(e.id, e.label)
        end

        if db2.toyShowAll and type(H.GetOwnedHearthToys) == "function" then
            for _, t in ipairs(H.GetOwnedHearthToys()) do
                Add(t.id, t.name)
            end
        end

        table.sort(list, function(a, b)
            return SafeLower(a.name) < SafeLower(b.name)
        end)

        return list
    end

    local listButtons = {}
    local function ClearListButtons()
        for i = 1, #listButtons do
            local b = listButtons[i]
            if b and b.Hide then b:Hide() end
        end
    end

    local function RebuildPopoutList()
        ClearListButtons()
        if type(H.EnsureInit) ~= "function" then
            return
        end
        local db2 = H.EnsureInit()
        local selected = tonumber(db2.selectedUseItemID)
        local list = GetPopoutList()

        local w = scroll.GetWidth and scroll:GetWidth() or 0
        if w and w > 0 and scrollChild.SetWidth then
            scrollChild:SetWidth(w)
        end

        local y = 0
        local rowH = 18
        for i = 1, #list do
            local e = list[i]
            local btn = listButtons[i]
            if not btn then
                btn = CreateFrame("Button", nil, scrollChild, "UIPanelButtonTemplate")
                btn:SetHeight(rowH)
                listButtons[i] = btn
            end
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -y)
            btn:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, -y)
            btn:SetText(e.name)
            if e.owned then btn:Enable() else btn:Disable() end
            if selected and selected == e.id then btn:LockHighlight() else btn:UnlockHighlight() end
            btn:SetScript("OnClick", function()
                if not e.owned then return end
                db2.selectedUseItemID = e.id
                RebuildPopoutList()
                UpdatePopoutButtons()
                UpdateHearthZoneLine()
            end)
            y = y + rowH + 2
        end

        scrollChild:SetHeight(math.max(1, y))
    end

    local function TryCreateHearthMacro()
        if M.InCombat() then
            M.Print("Can't create macros in combat.")
            return
        end
        if type(GetMacroIndexByName) ~= "function" or type(CreateMacro) ~= "function" then
            M.Print("Macro API unavailable.")
            return
        end
        if type(H.EnsureInit) ~= "function" or type(H.BuildMacroText) ~= "function" then
            M.Print("Hearth data unavailable.")
            return
        end

        local db2 = H.EnsureInit()
        if db2.autoRotate and not db2.selectedUseItemID and type(H.RollRandomUseItem) == "function" then
            H.RollRandomUseItem(db2)
        end

        local body = H.BuildMacroText(db2)
        if type(M.ApplyOptionalLines) == "function" then
            body = M.ApplyOptionalLines(body)
        end

        local max = tonumber(M.MAX_MACRO_CHARS) or 255
        if #tostring(body or "") > max then
            M.Print("Macro too long (" .. tostring(#tostring(body or "")) .. "/" .. tostring(max) .. "). Remove Optional lines.")
            return
        end
        local idx = GetMacroIndexByName(H.MACRO_NAME or "FGO Hearth")
        local macroName = H.MACRO_NAME or "FGO Hearth"
        local perCharacter = M.GetMacroPerCharSetting()

        if idx and idx > 0 then
            if type(EditMacro) == "function" then
                EditMacro(idx, macroName, "INV_Misc_QuestionMark", body)
                M.Print("Updated macro '" .. macroName .. "'.")
            else
                M.Print("Macro '" .. macroName .. "' already exists.")
            end
            if type(M.ClearOptionalSelections) == "function" then
                M.ClearOptionalSelections()
            end
            RebuildOptionalList()
            UpdateMacroCreateButtonsEnabled()
            hearthPopout:Hide()
            return
        end

        local ok = CreateMacro(macroName, "INV_Misc_QuestionMark", body, perCharacter)
        if ok then
            M.Print("Created macro '" .. macroName .. "'.")
            if type(M.ClearOptionalSelections) == "function" then
                M.ClearOptionalSelections()
            end
            RebuildOptionalList()
            UpdateMacroCreateButtonsEnabled()
            hearthPopout:Hide()
        else
            M.Print("Could not create macro (macro slots full?).")
        end
    end

    btnCreateHearthMacro:SetScript("OnClick", TryCreateHearthMacro)
    popoutClose:SetScript("OnClick", function() hearthPopout:Hide() end)

    btnAll:SetScript("OnClick", function()
        if type(H.EnsureInit) ~= "function" then return end
        local db2 = H.EnsureInit()
        db2.toyShowAll = not (db2.toyShowAll and true or false)
        UpdatePopoutButtons()
        RebuildPopoutList()
        UpdateMacroCreateButtonsEnabled()
    end)

    btnAuto:SetScript("OnClick", function()
        if type(H.EnsureInit) ~= "function" then return end
        local db2 = H.EnsureInit()
        db2.autoRotate = not (db2.autoRotate and true or false)
        UpdatePopoutButtons()
        UpdateMacroCreateButtonsEnabled()
    end)

    btnRoll:SetScript("OnClick", function()
        if M.InCombat() then
            M.Print("Can't roll in combat.")
            return
        end
        if type(H.EnsureInit) ~= "function" or type(H.RollRandomUseItem) ~= "function" or type(H.GetUseItemName) ~= "function" then
            return
        end
        local db2 = H.EnsureInit()
        local id = H.RollRandomUseItem(db2)
        if id then
            db2.selectedUseItemID = id
            M.Print("Rolled: " .. H.GetUseItemName(id))
        else
            M.Print("No usable hearth toys found.")
        end
        UpdatePopoutButtons()
        RebuildPopoutList()
        UpdateHearthZoneLine()
    end)

    local function AddCustomUseItem(id)
        if type(H.EnsureInit) ~= "function" then return end
        local db2 = H.EnsureInit()
        db2.customUseItems = db2.customUseItems or {}
        for _, v in ipairs(db2.customUseItems) do
            if tonumber(v) == id then
                return
            end
        end
        table.insert(db2.customUseItems, id)
    end

    popoutFilter:SetScript("OnShow", function(self)
        if type(H.EnsureInit) ~= "function" then return end
        local db2 = H.EnsureInit()
        self:SetText(tostring(db2.toyFilter or ""))
    end)
    popoutFilter:SetScript("OnEnterPressed", function(self)
        if type(H.EnsureInit) ~= "function" then return end
        local txt = tostring(self:GetText() or "")
        local id = tonumber(txt)
        local db2 = H.EnsureInit()
        if id and id > 0 then
            AddCustomUseItem(id)
            self:SetText("")
        else
            db2.toyFilter = txt
        end
        self:ClearFocus()
        RebuildPopoutList()
        UpdatePopoutButtons()
    end)
    popoutFilter:SetScript("OnEditFocusLost", function(self)
        if type(H.EnsureInit) ~= "function" then return end
        local db2 = H.EnsureInit()
        db2.toyFilter = tostring(self:GetText() or "")
        RebuildPopoutList()
        UpdatePopoutButtons()
    end)

    btnHSHearth:SetScript("OnClick", function()
        if hearthPopout:IsShown() then
            hearthPopout:Hide()
            return
        end
        UpdateHearthZoneLine()
        popoutFilter:GetScript("OnShow")(popoutFilter)
        UpdatePopoutButtons()
        RebuildPopoutList()
        hearthPopout:Show()
    end)

    -- Layout
    local function LayoutMacroButtons()
        -- Size the macro column to ~1/3 of the available width (clamped), Home takes the rest.
        do
            local fullW = GetPanelWidth(parent)
            local desiredRight = math.floor((fullW / 3) + 0.5)
            -- Minimum needs to support the requested split: HS buttons centered-left,
            -- other buttons centered-right.
            local minRight = (BTN_W * 2) + 12 + 24
            if desiredRight < minRight then desiredRight = minRight end
            local maxRight = fullW - (BTN_W + 24)
            if maxRight < minRight then maxRight = minRight end
            if desiredRight > maxRight then desiredRight = maxRight end
            if macroCol.SetWidth then
                macroCol:SetWidth(desiredRight)
            end
        end

        local panelW = GetPanelWidth(macroCol)
        local halfGap = math.floor((BTN_H / 2) + 0.5)
        if halfGap < 4 then halfGap = 4 end
        local colGap = halfGap

    -- Keep macro-side controls below the panel tab strip.
    -- (Extra space so the scope label reads like a title.)
    local topInset = 40

        local leftPad = 12
        local rightPad = 12
        local groupGap = 12
        local innerW = panelW - leftPad - rightPad
        if innerW < (BTN_W * 2 + groupGap) then
            innerW = (BTN_W * 2 + groupGap)
        end

        -- Place buttons from the TOP of the macro column (so the whole set sits under the scope label).
        local function PlaceGridInArea(buttons, areaX, areaW, startY)
            areaW = math.max(BTN_W, tonumber(areaW) or BTN_W)
            local cols = math.floor((areaW + colGap) / (BTN_W + colGap))
            if cols < 1 then cols = 1 end
            if cols > 2 then cols = 2 end

            local contentW = (cols * BTN_W) + ((cols - 1) * colGap)
            local x0 = areaX + math.floor((areaW - contentW) / 2)
            if x0 < areaX then x0 = areaX end

            for i = 1, #buttons do
                local b = buttons[i]
                if b then
                    local col = (i - 1) % cols
                    local row = math.floor((i - 1) / cols)
                    local x = x0 + (col * (BTN_W + colGap))
                    local y = startY + (row * (BTN_H + halfGap))
                    b:ClearAllPoints()
                    b:SetPoint("TOPLEFT", macroCol, "TOPLEFT", x, -y)
                end
            end
            return math.ceil(#buttons / cols) * (BTN_H + halfGap)
        end

        -- Bottom layout:
        -- - "+ Macro" stays bottom-left
        -- - Hearth location line stays bottom-centered on the whole tab
        -- - Home credit line is handled by the embedded Home panel (anchored under its saved-locations box)
        local bottomY = 12
        local hearthLineY = bottomY

        -- Bottom-left: + Macro
        btnOptional:ClearAllPoints()
        btnOptional:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 12, bottomY)

        -- Divider between columns (stop above the hearth location line)
        do
            colSep:ClearAllPoints()
            colSep:SetPoint("TOP", parent, "TOP", 0, -topInset)
            colSep:SetPoint("BOTTOM", parent, "BOTTOM", 0, hearthLineY + BTN_H + 6)
            colSep:SetPoint("LEFT", macroCol, "RIGHT", math.floor(COL_GAP / 2), 0)
        end

        -- Start the macro button groups just below the scope label.
        local yCursor = topInset + (BTN_H + 8) + 16

        -- Macro scope button: title-like at the top center of the macro column
        do
            macroScopeBtn:ClearAllPoints()
            macroScopeBtn:SetPoint("TOP", macroCol, "TOP", 0, -topInset)
            macroScopeBtn:SetPoint("LEFT", macroCol, "LEFT", leftPad, 0)
            macroScopeBtn:SetPoint("RIGHT", macroCol, "RIGHT", -leftPad, 0)
            macroScopeBtn:SetHeight(BTN_H + 8)
            -- Ensure it can't get stuck hidden/under other content.
            if macroScopeBtn.Show then macroScopeBtn:Show() end
            if macroScopeBtn.SetFrameLevel and macroCol and macroCol.GetFrameLevel then
                macroScopeBtn:SetFrameLevel((macroCol:GetFrameLevel() or 0) + 20)
            end
        end

        -- Macro buttons: HS group centered-left, utilities centered-right.
        do
            local areaW = math.floor((innerW - groupGap) / 2)
            if areaW < BTN_W then areaW = BTN_W end
            local leftAreaX = leftPad
            local rightAreaX = leftPad + areaW + groupGap

            local hsButtons = { btnHSHearth, btnHS06, btnHS07, btnHS11, btnHS12, btnHS78 }
            local utilButtons = { btnInstanceIO, btnInstanceReset, btnRez, btnRezCombat, btnScriptErrors }

            local h1 = PlaceGridInArea(hsButtons, leftAreaX, areaW, yCursor)
            local h2 = PlaceGridInArea(utilButtons, rightAreaX, areaW, yCursor)
            yCursor = yCursor + math.max(h1, h2)
        end

        -- Hearth location line: centered just above the credit line
        do
            local lineW = GetPanelWidth(parent) - 160
            if lineW < 260 then lineW = 260 end
            if lineW > 420 then lineW = 420 end
            hearthZoneLine:ClearAllPoints()
            hearthZoneLine:SetPoint("BOTTOM", parent, "BOTTOM", 0, hearthLineY)
            hearthZoneLine:SetHeight(BTN_H)
            hearthZoneLine:SetWidth(lineW)
            hearthZoneLine._maxWidth = lineW
        end

        do
            local w = GetPanelWidth(macroCol) + 40
            if w < 260 then w = 260 end
            if w > 360 then w = 360 end
            hearthPopout:SetWidth(w)
        end

        UpdateHearthZoneLine()
    end

    -- Use HookScript so we don't clobber any existing OnShow handler on this panel.
    if parent.HookScript then
        parent:HookScript("OnShow", function()
            UpdateMacroScopeUI()
            LayoutMacroButtons()
        end)

        parent:HookScript("OnSizeChanged", function()
            LayoutMacroButtons()
        end)
    else
        parent:SetScript("OnShow", function()
            UpdateMacroScopeUI()
            LayoutMacroButtons()
        end)
    end

    UpdateMacroScopeUI()
    LayoutMacroButtons()
end

ns.BuildMacrosPanel = BuildMacrosPanel
ns.BuildHearthMacrosPanel = BuildMacrosPanel

-- Home panel UI (merged from the former standalone fr0z3nUI_GameOptionsHomeUI.lua).
-- Kept as a scoped block to avoid leaking locals into the Macro UI module.
do
    -- Home tab: Home Teleports UI + Guests popout.
    -- Home Teleports mirrors the working "Add" -> "Create Macro" flow from MultipleHouseTeleports,
    -- using FGO's secure /click buttons and captured current-house info.

    local PREFIX = "|cff00ccff[FGO]|r "
    local function Print(msg)
        if ns and ns.Macros and type(ns.Macros.Print) == "function" then
            ns.Macros.Print(msg)
            return
        end
        print(PREFIX .. tostring(msg or ""))
    end

    local function ErrorMessage(msg)
        if UIErrorsFrame and UIErrorsFrame.AddMessage then
            UIErrorsFrame:AddMessage(tostring(msg or ""), 1, 0, 0)
        end
    end

    local function SetTooltip(frame, textOrFn)
        if not (frame and frame.SetScript) then
            return
        end
        frame:SetScript("OnEnter", function(self)
            local txt = textOrFn
            if type(txt) == "function" then
                txt = txt()
            end
            if type(txt) ~= "string" or txt == "" then
                return
            end
            if GameTooltip and GameTooltip.SetOwner and GameTooltip.SetText then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(txt)
                GameTooltip:Show()
            end
        end)
        frame:SetScript("OnLeave", function()
            if GameTooltip and GameTooltip.Hide then
                GameTooltip:Hide()
            end
        end)
    end

    local function GetHomeTeleportSV()
        local cs = _G.AutoGame_CharSettings
        if type(cs) ~= "table" then
            return {}
        end
        local sv = cs.fgoHomeTeleports
        if type(sv) ~= "table" then
            return {}
        end
        return sv
    end

    local function GetSavedTeleportsDB()
        _G.AutoGame_CharSettings = _G.AutoGame_CharSettings or {}
        local cs = _G.AutoGame_CharSettings
        if type(cs.fgoSavedTeleports) ~= "table" then
            cs.fgoSavedTeleports = {}
        end
        local db = cs.fgoSavedTeleports
        if type(db.list) ~= "table" then
            db.list = {}
        end
        if type(db.nextId) ~= "number" then
            db.nextId = 1
        end
        return db
    end

    local function Trim(s)
        if type(s) ~= "string" then
            return ""
        end
        return (s:gsub("^%s+", ""):gsub("%s+$", ""))
    end

    local function GetSavedTeleportMacroName(id)
        id = tonumber(id)
        if not id then
            return nil
        end
        return "FGO TP " .. tostring(id)
    end

    local function EnsureFGOStaticPopups()
        local dialogs = _G and rawget(_G, "StaticPopupDialogs")
        if type(dialogs) ~= "table" then
            return false
        end

        if not dialogs["FGO_ADD_SAVED_LOCATION"] then
            dialogs["FGO_ADD_SAVED_LOCATION"] = {
                text = "Enter a name for this location:",
                button1 = "Save",
                button2 = "Cancel",
                hasEditBox = true,
                maxLetters = 50,
                OnAccept = function(self)
                    local data = self.data
                    if type(data) == "table" and type(data.onAccept) == "function" then
                        data.onAccept(self.EditBox:GetText())
                    end
                end,
                OnShow = function(self)
                    local data = self.data
                    local prefill
                    if type(data) == "table" and type(data.getPrefill) == "function" then
                        local ok, v = pcall(data.getPrefill)
                        if ok and type(v) == "string" then
                            prefill = v
                        end
                    end
                    if prefill == nil and type(data) == "table" then
                        prefill = data.prefill
                    end
                    if type(prefill) ~= "string" then
                        prefill = ""
                    end
                    self.EditBox:SetText(prefill)
                    self.EditBox:HighlightText()
                end,
                EditBoxOnEnterPressed = function(self)
                    local parent = self:GetParent()
                    local data = parent.data
                    if type(data) == "table" and type(data.onAccept) == "function" then
                        data.onAccept(self:GetText())
                    end
                    parent:Hide()
                end,
                EditBoxOnEscapePressed = function(self)
                    self:GetParent():Hide()
                end,
                timeout = 0,
                whileDead = true,
                hideOnEscape = true,
                preferredIndex = 3,
            }
        end

        if not dialogs["FGO_RENAME_SAVED_LOCATION"] then
            dialogs["FGO_RENAME_SAVED_LOCATION"] = {
                text = "Enter a new name:",
                button1 = "Rename",
                button2 = "Cancel",
                hasEditBox = true,
                maxLetters = 50,
                OnAccept = function(self)
                    local data = self.data
                    if type(data) == "table" and type(data.onAccept) == "function" then
                        data.onAccept(self.EditBox:GetText())
                    end
                end,
                OnShow = function(self)
                    local data = self.data
                    local currentName = (type(data) == "table") and data.currentName or nil
                    if type(currentName) ~= "string" then
                        currentName = ""
                    end
                    self.EditBox:SetText(currentName)
                    self.EditBox:HighlightText()
                end,
                EditBoxOnEnterPressed = function(self)
                    local parent = self:GetParent()
                    local data = parent.data
                    if type(data) == "table" and type(data.onAccept) == "function" then
                        data.onAccept(self:GetText())
                    end
                    parent:Hide()
                end,
                EditBoxOnEscapePressed = function(self)
                    self:GetParent():Hide()
                end,
                timeout = 0,
                whileDead = true,
                hideOnEscape = true,
                preferredIndex = 3,
            }
        end

        return true
    end

    local function LookupNeighborhoodNameByGUID(neighborhoodGUID)
        return nil
    end

    local function CaptureSavedTeleport(name)
        name = Trim(name)
        if InCombatLockdown and InCombatLockdown() then
            ErrorMessage("Can't capture in combat")
            return false
        end
        if not (C_Housing and type(C_Housing.GetCurrentHouseInfo) == "function") then
            ErrorMessage("Housing API unavailable")
            return false
        end

        if C_HousingNeighborhood and type(C_HousingNeighborhood.RequestNeighborhoodInfo) == "function" then
            pcall(C_HousingNeighborhood.RequestNeighborhoodInfo)
        end

        local ok, info = pcall(C_Housing.GetCurrentHouseInfo)
        if not ok or type(info) ~= "table" then
            ErrorMessage("No current house info")
            return false
        end

        local neighborhoodGUID = info.neighborhoodGUID
        local houseGUID = info.houseGUID
        local plotID = info.plotID
        if neighborhoodGUID == nil or houseGUID == nil or plotID == nil then
            ErrorMessage("Enter a plot first")
            return false
        end

        local neighborhoodName = info.neighborhoodName or info["neighborhood"]
        if type(neighborhoodName) ~= "string" then
            neighborhoodName = ""
        end
        if neighborhoodName == "" then
            local lookedUp = LookupNeighborhoodNameByGUID(neighborhoodGUID)
            if type(lookedUp) == "string" and lookedUp ~= "" then
                neighborhoodName = lookedUp
            end
        end

        if name == "" then
            local fallback = info["plotName"] or info["ownerName"]
            if type(fallback) == "string" and fallback ~= "" then
                name = fallback
            else
                name = "Location"
            end
        end

        local db = GetSavedTeleportsDB()
        local list = db.list

        for i = 1, #list do
            local e = list[i]
            if type(e) == "table" and e.neighborhoodGUID == neighborhoodGUID and e.houseGUID == houseGUID and e.plotID == plotID then
                e.name = name
                e.neighborhoodName = neighborhoodName
                if ns and ns.Home and type(ns.Home.ConfigureSavedTeleportClickButtonById) == "function" then
                    ns.Home.ConfigureSavedTeleportClickButtonById(e.id)
                end
                return true, e.id, true
            end
        end

        local id = tonumber(db.nextId) or 1
        db.nextId = id + 1

        local entry = {
            id = id,
            name = name,
            neighborhoodGUID = neighborhoodGUID,
            houseGUID = houseGUID,
            plotID = plotID,
            neighborhoodName = neighborhoodName,
        }
        table.insert(list, entry)

        if ns and ns.Home and type(ns.Home.ConfigureSavedTeleportClickButtonById) == "function" then
            ns.Home.ConfigureSavedTeleportClickButtonById(id)
        end
        return true, id, false
    end

    local function CanAddSavedLocation()
        if not (C_Housing and type(C_Housing.GetCurrentHouseInfo) == "function") then
            return false
        end
        -- Some clients keep the last house info cached even when you leave the plot.
        -- Prefer the explicit API when available.
        if type(C_Housing.IsInsidePlot) == "function" then
            local okInside, inside = pcall(C_Housing.IsInsidePlot)
            if not okInside or not inside then
                return false
            end
        end
        local ok, info = pcall(C_Housing.GetCurrentHouseInfo)
        if not ok or type(info) ~= "table" then
            return false
        end
        return (info.neighborhoodGUID ~= nil and info.houseGUID ~= nil and info.plotID ~= nil)
    end

    local function GetHomeSlotLabel(which)
        local sv = GetHomeTeleportSV()
        local h = sv and sv[which] or nil
        if type(h) ~= "table" then
            return "(empty)"
        end
        local n = h.neighborhoodName
        if type(n) ~= "string" or n == "" then
            n = "House"
        end

        if n == "Founder's Point" then
            return "Alliance - " .. n
        end
        if n == "Razorwind Shores" then
            return "Horde - " .. n
        end
        return n
    end

    local function GetDefaultMacroNameForSlot(which)
        local sv = GetHomeTeleportSV()
        local h = sv and sv[which] or nil
        local n = (type(h) == "table") and h.neighborhoodName or nil
        if n == "Founder's Point" then
            return "FGO HM Alliance"
        end
        if n == "Razorwind Shores" then
            return "FGO HM Horde"
        end
        return (which == 2) and "FGO Home2" or "FGO Home1"
    end

    local function CaptureNow()
        if C_HousingNeighborhood and type(C_HousingNeighborhood.RequestNeighborhoodInfo) == "function" then
            pcall(C_HousingNeighborhood.RequestNeighborhoodInfo)
        end
        if not (C_Housing and type(C_Housing.GetCurrentHouseInfo) == "function") then
            ErrorMessage("Housing API unavailable")
            return false
        end
        local ok, info = pcall(C_Housing.GetCurrentHouseInfo)
        if not ok or type(info) ~= "table" then
            ErrorMessage("No current house info")
            return false
        end
        local neighborhoodGUID = info.neighborhoodGUID
        local houseGUID = info.houseGUID
        local plotID = info.plotID
        if neighborhoodGUID == nil or houseGUID == nil or plotID == nil then
            ErrorMessage("Enter your plot first")
            return false
        end

        _G.AutoGame_CharSettings = _G.AutoGame_CharSettings or {}
        local cs = _G.AutoGame_CharSettings
        cs.fgoHomeTeleports = cs.fgoHomeTeleports or {}
        local sv = cs.fgoHomeTeleports

        local neighborhoodName = info.neighborhoodName or info["neighborhood"]
        if type(neighborhoodName) ~= "string" then
            neighborhoodName = ""
        end

        if neighborhoodName == "" then
            local lookedUp = LookupNeighborhoodNameByGUID(neighborhoodGUID)
            if type(lookedUp) == "string" and lookedUp ~= "" then
                neighborhoodName = lookedUp
            end
        end

        local which
        if neighborhoodName == "Founder's Point" then
            which = 1
        elseif neighborhoodName == "Razorwind Shores" then
            which = 2
        else
            which = (type(sv[1]) ~= "table") and 1 or 2
        end

        sv[which] = {
            neighborhoodGUID = neighborhoodGUID,
            houseGUID = houseGUID,
            plotID = plotID,
            neighborhoodName = neighborhoodName,
        }

        return true
    end

    local function CaptureHomeSlot(which)
        if InCombatLockdown and InCombatLockdown() then
            ErrorMessage("Can't capture in combat")
            return false
        end
        if C_HousingNeighborhood and type(C_HousingNeighborhood.RequestNeighborhoodInfo) == "function" then
            pcall(C_HousingNeighborhood.RequestNeighborhoodInfo)
        end
        if not (C_Housing and type(C_Housing.GetCurrentHouseInfo) == "function") then
            ErrorMessage("Housing API unavailable")
            return false
        end

        local ok, info = pcall(C_Housing.GetCurrentHouseInfo)
        if not ok or type(info) ~= "table" then
            ErrorMessage("No current house info")
            return false
        end

        local neighborhoodGUID = info.neighborhoodGUID
        local houseGUID = info.houseGUID
        local plotID = info.plotID
        if neighborhoodGUID == nil or houseGUID == nil or plotID == nil then
            ErrorMessage("Enter a plot first")
            return false
        end

        local neighborhoodName = info.neighborhoodName or info["neighborhood"]
        if type(neighborhoodName) ~= "string" then
            neighborhoodName = ""
        end

        local sv = GetHomeTeleportSV()
        sv[which] = {
            neighborhoodGUID = neighborhoodGUID,
            houseGUID = houseGUID,
            plotID = plotID,
            neighborhoodName = neighborhoodName,
        }
        return true
    end

    local function EnsureHomeMacro(which, perCharacter)
        if InCombatLockdown and InCombatLockdown() then
            ErrorMessage("Can't create macros in combat")
            return false
        end
        if not (ns and ns.Macros and type(ns.Macros.EnsureMacro) == "function") then
            ErrorMessage("Macro helpers unavailable")
            return false
        end

        local sv = GetHomeTeleportSV()
        local h = sv and sv[which] or nil
        if type(h) ~= "table" then
            ErrorMessage("Capture a plot first")
            return false
        end

        local macroName = GetDefaultMacroNameForSlot(which)
        local macroBody = (ns.Home and ns.Home.GetHomeClickMacroBody and ns.Home.GetHomeClickMacroBody(which)) or ("/click " .. ((which == 2) and "FGO_HomeTeleport2" or "FGO_HomeTeleport1"))

        local ok, why = ns.Macros.EnsureMacro(macroName, macroBody, perCharacter and true or false)
        if not ok then
            ErrorMessage(tostring(why or "Could not create macro"))
            return false
        end
        return true
    end

    local function EnsureFactionHomeMacro(faction)
        local which = (faction == "HORDE") and 2 or 1
        local perCharacter = (ns and ns.Macros and type(ns.Macros.GetMacroPerCharSetting) == "function" and ns.Macros.GetMacroPerCharSetting()) or false

        local sv = GetHomeTeleportSV()
        local h = sv and sv[which] or nil
        if type(h) ~= "table" then
            ErrorMessage("Capture your " .. ((which == 2) and "Horde" or "Alliance") .. " plot first")
            return false
        end

        if not (ns and ns.Macros and type(ns.Macros.EnsureMacro) == "function") then
            ErrorMessage("Macro helpers unavailable")
            return false
        end

        local macroName = (which == 2) and "FGO HM Horde" or "FGO HM Alliance"
        local macroBody = (ns.Home and ns.Home.GetHomeClickMacroBody and ns.Home.GetHomeClickMacroBody(which)) or ("/click " .. ((which == 2) and "FGO_HomeTeleport2" or "FGO_HomeTeleport1"))

        do
            local legacyName = (which == 2) and "FAO HM Horde" or "FAO HM Alliance"
            if type(GetMacroIndexByName) == "function" and type(EditMacro) == "function" then
                local legacyIdx = GetMacroIndexByName(legacyName)
                local newIdx = GetMacroIndexByName(macroName)
                if legacyIdx and legacyIdx > 0 and (not newIdx or newIdx == 0) then
                    pcall(EditMacro, legacyIdx, macroName, nil, nil)
                end
            end
        end
        local ok, why = ns.Macros.EnsureMacro(macroName, macroBody, perCharacter and true or false)
        if not ok then
            ErrorMessage(tostring(why or "Could not create macro"))
            return false
        end
        return true, macroName
    end

    local function GetClassColorStr(classFile)
        if not classFile then return nil end
        if type(classFile) ~= "string" then return nil end
        local colors
        if type(_G) == "table" and rawget then
            colors = rawget(_G, "CUSTOM_CLASS_COLORS") or rawget(_G, "RAID_CLASS_COLORS")
        end
        local c = colors and colors[classFile] or nil
        if not c then return nil end
        if c.colorStr then return c.colorStr end
        if c.GenerateHexColor then return c:GenerateHexColor() end
        return nil
    end

    local function ColorName(name, classFile)
        local n = tostring(name or "")
        local hex = GetClassColorStr(classFile)
        if hex and hex ~= "" then
            return "|c" .. hex .. n .. "|r"
        end
        return n
    end

    local function SafeOwnedHouses()
        if not (C_Housing and C_Housing.GetPlayerOwnedHouses) then return nil end
        local ok, v = pcall(C_Housing.GetPlayerOwnedHouses)
        if ok then return v end
        return nil
    end

    local function SafeNeighborhoodCitizens()
        if not (C_Housing and C_Housing.GetNeighborhoodCitizens) then return nil end
        local ok, v = pcall(C_Housing.GetNeighborhoodCitizens)
        if ok then return v end
        return nil
    end

    local cachedNeighborhoodInfo = nil
    do
        local f = CreateFrame("Frame")
        f:RegisterEvent("NEIGHBORHOOD_INFO_UPDATED")
        f:RegisterEvent("PLAYER_ENTERING_WORLD")
        f:SetScript("OnEvent", function(_, event, ...)
            if event == "NEIGHBORHOOD_INFO_UPDATED" then
                cachedNeighborhoodInfo = ...
                return
            end

            if event == "PLAYER_ENTERING_WORLD" then
                if C_HousingNeighborhood and type(C_HousingNeighborhood.RequestNeighborhoodInfo) == "function" then
                    pcall(C_HousingNeighborhood.RequestNeighborhoodInfo)
                end
            end
        end)
    end

    LookupNeighborhoodNameByGUID = function(neighborhoodGUID)
        if neighborhoodGUID == nil then
            return nil
        end

        local info = cachedNeighborhoodInfo
        if type(info) ~= "table" then
            return nil
        end

        local function TryTable(t)
            if type(t) ~= "table" then
                return nil
            end
            local guid = t.neighborhoodGUID or t.guid
            if guid ~= nil and guid == neighborhoodGUID then
                local n = t.neighborhoodName or t.name or t.neighborhood or t["neighborhoodName"] or t["name"]
                if type(n) == "string" and n ~= "" then
                    return n
                end
            end
            return nil
        end

        local direct = TryTable(info)
        if direct then
            return direct
        end

        for _, v in pairs(info) do
            local n = TryTable(v)
            if n then
                return n
            end
        end

        return nil
    end

    local function GuessMyPlotID(citizens)
        local myGUID = UnitGUID and UnitGUID("player") or nil
        if myGUID and type(citizens) == "table" then
            for _, c in ipairs(citizens) do
                if type(c) == "table" and c.guid == myGUID and c.plotID ~= nil then
                    return c.plotID
                end
            end
        end

        local houses = SafeOwnedHouses()
        if type(houses) == "table" then
            for _, h in ipairs(houses) do
                if type(h) == "table" and h.plotID ~= nil then
                    return h.plotID
                end
            end
        end

        return nil
    end

    local function BuildGuestList()
        if not C_Housing then
            return {}, "Housing API unavailable"
        end
        if type(C_Housing.GetNeighborhoodCitizens) ~= "function" then
            return {}, "GetNeighborhoodCitizens unavailable"
        end

        local citizens = SafeNeighborhoodCitizens()
        if type(citizens) ~= "table" then
            return {}, "No neighborhood data (yet)"
        end

        local myGUID = UnitGUID and UnitGUID("player") or nil
        local myPlotID = GuessMyPlotID(citizens)
        local unfiltered = (myPlotID == nil)

        local out = {}
        for _, c in ipairs(citizens) do
            if type(c) == "table" then
                local guid = c.guid
                if guid and guid ~= myGUID then
                    local plotOk = unfiltered or (c.plotID == myPlotID)
                    if plotOk then
                        local classFile = c.class or c.classFile or c.classFilename
                        local name = c.name or c.fullName or "Unknown"
                        out[#out + 1] = {
                            guid = guid,
                            plotID = c.plotID,
                            name = name,
                            classFile = classFile,
                            coloredName = ColorName(name, classFile),
                        }
                    end
                end
            end
        end

        table.sort(out, function(a, b)
            return tostring(a.name or "") < tostring(b.name or "")
        end)

        local note
        if unfiltered then
            note = "(unfiltered: plotID unknown)"
        elseif myPlotID ~= nil then
            note = "(plotID " .. tostring(myPlotID) .. ")"
        end

        return out, note
    end

    local function BuildHomePanel(parent)
        if not parent or parent._fgoHomeBuilt then return end
        parent._fgoHomeBuilt = true

        local btnAlliance = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        btnAlliance:SetSize(90, 18)
        btnAlliance:SetPoint("TOP", parent, "TOP", -54, -52)
        btnAlliance:SetText("Alliance")

        local btnHorde = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        btnHorde:SetSize(90, 18)
        btnHorde:SetPoint("TOP", parent, "TOP", 54, -52)
        btnHorde:SetText("Horde")

        local clickTitle = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        clickTitle:SetPoint("TOP", btnAlliance, "BOTTOM", 54, -6)
        clickTitle:SetJustifyH("CENTER")
        clickTitle:SetText("Click At Home")
        do
            local font, size, flags = clickTitle:GetFont()
            if font and size then
                clickTitle:SetFont(font, math.max(8, (size or 12) - 2), flags)
            end
        end

        local function SetStatus(text, kind) end

        -- The Macros tab has a compact table UI below; keep the legacy top buttons hidden.
        btnAlliance:Hide()
        btnHorde:Hide()
        clickTitle:Hide()

        local btnGuests = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        btnGuests:SetSize(70, 18)
        btnGuests:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -18, -52)
        btnGuests:SetText("Guests")

        local popout = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        popout:SetWidth(360)
        popout:SetPoint("TOPLEFT", parent, "TOPRIGHT", 0, 0)
        popout:SetPoint("BOTTOMLEFT", parent, "BOTTOMRIGHT", 0, 0)
        popout:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            tile = true, tileSize = 16,
        })
        popout:SetBackdropColor(0, 0, 0, 0.85)
        popout:Hide()

        local popoutClose = CreateFrame("Button", nil, popout, "UIPanelCloseButton")
        popoutClose:SetPoint("TOPRIGHT", popout, "TOPRIGHT", -3, -3)
        popoutClose:SetScript("OnClick", function() popout:Hide() end)

        btnGuests:SetScript("OnClick", function()
            if popout:IsShown() then popout:Hide() else popout:Show() end
        end)

        local gTitle = popout:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        gTitle:SetPoint("TOPLEFT", popout, "TOPLEFT", 14, -12)
        gTitle:SetJustifyH("LEFT")
        gTitle:SetText("Guests")

        local gStatus = popout:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        gStatus:SetPoint("TOPLEFT", gTitle, "BOTTOMLEFT", 0, -6)
        gStatus:SetJustifyH("LEFT")
        gStatus:SetText("")

        local btnRefresh = CreateFrame("Button", nil, popout, "UIPanelButtonTemplate")
        btnRefresh:SetSize(70, 18)
        btnRefresh:SetPoint("TOPRIGHT", popout, "TOPRIGHT", -18, -12)
        btnRefresh:SetText("Refresh")

        local scroll = CreateFrame("ScrollFrame", nil, popout, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", gStatus, "BOTTOMLEFT", 0, -10)
        scroll:SetPoint("TOPRIGHT", popout, "TOPRIGHT", -28, -48)
        scroll:SetPoint("BOTTOMLEFT", popout, "BOTTOMLEFT", 14, 14)

        local scrollChild = CreateFrame("Frame", nil, scroll)
        scrollChild:SetSize(1, 1)
        scroll:SetScrollChild(scrollChild)

        local rows = {}
        local ROW_H = 20

        local function EnsureRow(i)
            if rows[i] then return rows[i] end
            local row = CreateFrame("Frame", nil, scrollChild)
            row:SetHeight(ROW_H)
            row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -((i - 1) * ROW_H))
            row:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -6, -((i - 1) * ROW_H))

            local nameFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            nameFS:SetPoint("LEFT", row, "LEFT", 0, 0)
            nameFS:SetJustifyH("LEFT")
            nameFS:SetText("")

            local btnKick = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            btnKick:SetSize(46, 18)
            btnKick:SetPoint("RIGHT", row, "RIGHT", 0, 0)
            btnKick:SetText("Kick")
            btnKick:Disable()

            row._nameFS = nameFS
            row._btnKick = btnKick
            rows[i] = row
            return row
        end

        local function SetKickEnabled(btn, guid)
            if not btn then return end
            if guid and type(C_Housing) == "table" and type(C_Housing.EjectGuest) == "function" then
                btn:Enable()
            else
                btn:Disable()
            end
        end

        local function RefreshGuests()
            local list, note = BuildGuestList()
            local msg
            if type(note) == "string" and note ~= "" then
                msg = tostring(#list) .. " guest(s) " .. note
            else
                msg = tostring(#list) .. " guest(s)"
            end
            gStatus:SetText(msg)

            local shown = 0
            for i = 1, #list do
                local e = list[i]
                local row = EnsureRow(i)
                row:Show()
                row._nameFS:SetText(e.coloredName or e.name or "")

                local guid = e.guid
                row._btnKick:SetScript("OnClick", function()
                    if InCombatLockdown and InCombatLockdown() then
                        Print("Cannot kick in combat")
                        return
                    end
                    if not (C_Housing and C_Housing.EjectGuest) then
                        Print("EjectGuest unavailable")
                        return
                    end
                    local ok, err = pcall(C_Housing.EjectGuest, guid)
                    if ok then
                        Print("Kick attempted")
                    else
                        Print("Kick failed: " .. tostring(err or "unknown"))
                    end
                end)
                SetKickEnabled(row._btnKick, guid)

                shown = i
            end

            for i = shown + 1, #rows do
                if rows[i] then rows[i]:Hide() end
            end

            local totalH = math.max(1, shown) * ROW_H
            scrollChild:SetHeight(totalH)
        end

        btnRefresh:SetScript("OnClick", RefreshGuests)

        local binder = parent._fgoHomeBinder
        if not binder then
            binder = CreateFrame("Frame", nil, UIParent)
            binder:Hide()
            binder:EnableKeyboard(true)
            if binder.SetPropagateKeyboardInput then binder:SetPropagateKeyboardInput(false) end
            binder:SetAllPoints(UIParent)
            binder:SetFrameStrata("TOOLTIP")
            binder:SetFrameLevel(999)
            parent._fgoHomeBinder = binder
        end

        local function StopBindCapture(msg)
            binder:Hide()
            binder._targetMacro = nil
            if msg and msg ~= "" then
                ErrorMessage(msg)
            end
        end

        if not binder._fgoHomeKeyScripted then
            binder._fgoHomeKeyScripted = true
            binder:SetScript("OnKeyDown", function(_, key)
                if key == "ESCAPE" then
                    StopBindCapture("")
                    return
                end

                if key == "LALT" or key == "RALT" or key == "ALT"
                    or key == "LSHIFT" or key == "RSHIFT" or key == "SHIFT"
                    or key == "LCTRL" or key == "RCTRL" or key == "CTRL" then
                    return
                end

                if key == "UNKNOWN" or key == nil or key == "" then
                    return
                end

                local macroName = binder._targetMacro
                if not macroName then
                    StopBindCapture("")
                    return
                end

                if InCombatLockdown and InCombatLockdown() then
                    StopBindCapture("Cannot bind in combat")
                    return
                end

                if not (ns and ns.Macros and type(ns.Macros.SetMacroBinding) == "function") then
                    StopBindCapture("Bind unavailable")
                    return
                end

                local bindingKey = tostring(key)
                if IsShiftKeyDown and IsShiftKeyDown() then
                    bindingKey = "SHIFT-" .. bindingKey
                end
                if IsControlKeyDown and IsControlKeyDown() then
                    bindingKey = "CTRL-" .. bindingKey
                end
                if IsAltKeyDown and IsAltKeyDown() then
                    bindingKey = "ALT-" .. bindingKey
                end

                local ok, why = ns.Macros.SetMacroBinding(macroName, bindingKey)
                if ok then
                    StopBindCapture("")
                else
                    StopBindCapture(tostring(why or "Bind failed"))
                end
            end)
        end

        local function StartBind(macroName)
            binder._targetMacro = macroName
            ErrorMessage("Press a key to bind (ESC cancels)")
            binder:Show()
        end

        SetTooltip(btnAlliance, "Captures current plot (if possible) and creates 'FGO HM Alliance'\nShift-click to bind")
        SetTooltip(btnHorde, "Captures current plot (if possible) and creates 'FGO HM Horde'\nShift-click to bind")

        local function MakeTeleportRow(which, y)
            local row = CreateFrame("Frame", nil, parent)
            row:SetHeight(22)
            row:SetPoint("TOPLEFT", btnAlliance, "BOTTOMLEFT", 0, -(y))
            row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -18, -(52 + 24 + 12 + 18 + 6 + y))

            local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            label:SetPoint("LEFT", row, "LEFT", 0, 0)
            label:SetJustifyH("LEFT")
            label:SetText("")

            local btnAdd = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            btnAdd:SetSize(46, 18)
            btnAdd:SetPoint("RIGHT", row, "RIGHT", 0, 0)
            btnAdd:SetText("Add")

            local btnMacro = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            btnMacro:SetSize(86, 18)
            btnMacro:SetPoint("RIGHT", btnAdd, "LEFT", -6, 0)
            btnMacro:SetText("Create Macro")

            local function FlashButtonText(btn, text, seconds, fallback)
                if not btn then return end
                local old = btn:GetText()
                btn:SetText(text)
                if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
                    C_Timer.After(seconds or 0.8, function()
                        if btn and btn.SetText then
                            btn:SetText(fallback or old or "")
                        end
                    end)
                end
            end

            local function RefreshRow()
                local sv = GetHomeTeleportSV()
                local has = (type(sv) == "table") and type(sv[which]) == "table"
                local prefix = "|cffffff00FGO|r "
                label:SetText(prefix .. ((which == 2) and "Home 2: " or "Home 1: ") .. GetHomeSlotLabel(which))

                local macroName = GetDefaultMacroNameForSlot(which)
                local macroExists = false
                if type(GetMacroIndexByName) == "function" and type(macroName) == "string" and macroName ~= "" then
                    local idx = GetMacroIndexByName(macroName)
                    macroExists = (idx and idx > 0) and true or false
                end

                if not has then
                    btnMacro:Disable()
                    btnMacro:SetText("Create Macro")
                elseif macroExists then
                    btnMacro:Disable()
                    btnMacro:SetText("Macro Exists")
                else
                    btnMacro:Enable()
                    btnMacro:SetText("Create Macro")
                end
            end

            btnAdd:SetScript("OnClick", function()
                if InCombatLockdown and InCombatLockdown() then
                    ErrorMessage("Can't capture in combat")
                    return
                end
                if CaptureNow() then
                    RefreshRow()
                    FlashButtonText(btnAdd, "Added", 0.8, "Add")
                    SetStatus("Home " .. tostring(which) .. " captured. Click Create Macro.", "ok")
                end
            end)

            btnMacro:SetScript("OnClick", function()
                local perCharacter = (ns and ns.Macros and type(ns.Macros.GetMacroPerCharSetting) == "function" and ns.Macros.GetMacroPerCharSetting()) or false
                if EnsureHomeMacro(which, perCharacter) then
                    FlashButtonText(btnMacro, "Created", 0.8, "Macro Exists")
                    RefreshRow()
                    SetStatus("Created macro: " .. tostring(GetDefaultMacroNameForSlot(which)) .. " (open /macro to place)", "ok")
                end
            end)

            RefreshRow()
            return RefreshRow
        end

        local refreshRow1 = function() end
        local refreshRow2 = function() end

        local function FlashButtonText(btn, text, seconds, fallback)
            if not btn then return end
            local old = btn:GetText()
            btn:SetText(text)
            if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
                C_Timer.After(seconds or 0.8, function()
                    if btn and btn.SetText then
                        btn:SetText(fallback or old or "")
                    end
                end)
            end
        end

        local btnAddSaved = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        btnAddSaved:SetSize(90, 18)
        btnAddSaved:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, -52)

        local function RefreshAddSavedButton()
            local canAdd = CanAddSavedLocation()
            btnAddSaved:SetText(canAdd and "|cFF00FF00+ Friend|r" or "|cFF888888+ Friend|r")
            if canAdd then
                btnAddSaved:Enable()
            else
                btnAddSaved:Disable()
            end
        end
        RefreshAddSavedButton()

        SetTooltip(btnAddSaved, function()
            if CanAddSavedLocation() then
                return "+ Friend\nSaves the plot you are currently standing in."
            end
            return "+ Friend\nEnter a housing plot first."
        end)

        local savedBox = CreateFrame("Frame", nil, parent)
        savedBox:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, -80)
        savedBox:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -14, -80)
        savedBox:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 14, 42)

        local savedBoxBg = savedBox:CreateTexture(nil, "BACKGROUND")
        savedBoxBg:SetAllPoints()
        savedBoxBg:SetColorTexture(0, 0, 0, 0.20)

        local savedScroll = CreateFrame("ScrollFrame", nil, savedBox, "UIPanelScrollFrameTemplate")
        savedScroll:SetPoint("TOPLEFT", savedBox, "TOPLEFT", 4, -4)
        savedScroll:SetPoint("BOTTOMRIGHT", savedBox, "BOTTOMRIGHT", -4, 4)
        if savedScroll.ScrollBar then
            savedScroll.ScrollBar:Hide()
            savedScroll.ScrollBar:SetAlpha(0)
            savedScroll.ScrollBar:EnableMouse(false)
        end

        local savedChild = CreateFrame("Frame", nil, savedScroll)
        savedChild:SetSize(1, 1)
        savedScroll:SetScrollChild(savedChild)

        local emptyText = savedChild:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        emptyText:SetPoint("TOPLEFT", savedChild, "TOPLEFT", 8, -8)
        emptyText:SetPoint("RIGHT", savedChild, "RIGHT", -8, 0)
        emptyText:SetJustifyH("LEFT")
        emptyText:SetText("No saved locations.")
        emptyText:Hide()

        local function RefreshSavedChildWidth()
            if not (savedScroll and savedChild) then return end
            local w = savedScroll:GetWidth()
            if w and w > 0 then
                savedChild:SetWidth(w)
            end
        end

        savedBox:SetScript("OnSizeChanged", RefreshSavedChildWidth)
        savedBox:HookScript("OnShow", function()
            RefreshSavedChildWidth()
            if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
                C_Timer.After(0, RefreshSavedChildWidth)
            end
        end)

        RefreshSavedChildWidth()
        if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
            C_Timer.After(0, RefreshSavedChildWidth)
        end

        local SAVED_ROW_H = 24
        local savedRows = {}

        emptyText:ClearAllPoints()
        emptyText:SetPoint("TOPLEFT", savedChild, "TOPLEFT", 8, -((3 * SAVED_ROW_H) + 8))
        emptyText:SetPoint("RIGHT", savedChild, "RIGHT", -8, 0)

        local function EnsureSavedRow(i)
            if savedRows[i] then
                return savedRows[i]
            end
            local row = CreateFrame("Frame", nil, savedChild)
            row:SetHeight(SAVED_ROW_H)
            row:SetPoint("TOPLEFT", savedChild, "TOPLEFT", 0, -((i - 1) * SAVED_ROW_H))
            row:SetPoint("TOPRIGHT", savedChild, "TOPRIGHT", -6, -((i - 1) * SAVED_ROW_H))

            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            if i % 2 == 0 then
                bg:SetColorTexture(1, 1, 1, 0.03)
            else
                bg:SetColorTexture(0, 0, 0, 0.03)
            end

            local hl = row:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetColorTexture(1, 1, 1, 0.05)

            local indexFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            indexFS:SetPoint("LEFT", row, "LEFT", 0, 0)
            indexFS:SetJustifyH("LEFT")
            indexFS:SetWidth(18)
            indexFS:SetText("")
            indexFS:SetTextColor(0.6, 0.6, 0.6)

            local nameFS = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            nameFS:SetPoint("LEFT", indexFS, "RIGHT", 6, 0)
            nameFS:SetJustifyH("LEFT")
            nameFS:SetText("")
            nameFS:SetWordWrap(false)

            local btnDel = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            btnDel:SetSize(26, 24)
            btnDel:SetPoint("RIGHT", row, "RIGHT", 0, 0)
            btnDel:SetText("D")
            btnDel:GetFontString():SetTextColor(1, 0.3, 0.3)

            local btnRename = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            btnRename:SetSize(26, 24)
            btnRename:SetPoint("RIGHT", btnDel, "LEFT", -4, 0)
            btnRename:SetText("R")

            local btnMacro = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            btnMacro:SetSize(26, 24)
            btnMacro:SetPoint("RIGHT", btnRename, "LEFT", -4, 0)
            btnMacro:SetText("M")

            -- Static rows (Alliance/Horde/Portal) use compact M/R/D buttons.
            local btnDStatic = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            btnDStatic:SetSize(26, 24)
            btnDStatic:SetPoint("RIGHT", row, "RIGHT", 0, 0)
            btnDStatic:SetText("D")
            btnDStatic:GetFontString():SetTextColor(1, 0.3, 0.3)
            btnDStatic:Hide()

            local btnRStatic = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            btnRStatic:SetSize(26, 24)
            btnRStatic:SetPoint("RIGHT", btnDStatic, "LEFT", -4, 0)
            btnRStatic:SetText("R")
            btnRStatic:Hide()

            local btnMStatic = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            btnMStatic:SetSize(26, 24)
            btnMStatic:SetPoint("RIGHT", btnRStatic, "LEFT", -4, 0)
            btnMStatic:SetText("M")
            btnMStatic:Hide()

            local labelBtn = CreateFrame("Button", nil, row)
            labelBtn:SetFrameLevel((row:GetFrameLevel() or 1) + 2)
            labelBtn:SetPoint("LEFT", nameFS, "LEFT", 0, 0)
            labelBtn:SetPoint("TOP", row, "TOP", 0, 0)
            labelBtn:SetPoint("BOTTOM", row, "BOTTOM", 0, 0)
            labelBtn:SetWidth(10)
            labelBtn:Hide()

            nameFS:SetPoint("RIGHT", btnMacro, "LEFT", -8, 0)

            row._indexFS = indexFS
            row._nameFS = nameFS
            row._btnMacro = btnMacro
            row._btnRename = btnRename
            row._btnDel = btnDel
            row._btnMStatic = btnMStatic
            row._btnRStatic = btnRStatic
            row._btnDStatic = btnDStatic
            row._labelBtn = labelBtn
            savedRows[i] = row
            return row
        end

        local function RefreshSavedList()
            local db = GetSavedTeleportsDB()
            local list = db.list
            local shown = 0
            local savedIndex = 0

            local function EnsurePortalMacro(perCharacter)
                if not (ns and ns.Macros and type(ns.Macros.EnsureMacro) == "function") then
                    ErrorMessage("Macro helpers unavailable")
                    return false
                end

                local macroName = "FGO HM Portal"
                local macroBody = "/fgo hm portal"

                do
                    local legacyName = "FAO HM Portal"
                    if type(GetMacroIndexByName) == "function" and type(EditMacro) == "function" then
                        local legacyIdx = GetMacroIndexByName(legacyName)
                        local newIdx = GetMacroIndexByName(macroName)
                        if legacyIdx and legacyIdx > 0 and (not newIdx or newIdx == 0) then
                            pcall(EditMacro, legacyIdx, macroName, nil, nil)
                        end
                    end
                end

                local ok, why = ns.Macros.EnsureMacro(macroName, macroBody, perCharacter and true or false)
                if not ok then
                    ErrorMessage(tostring(why or "Could not create macro"))
                    return false
                end
                return true, macroName, macroBody
            end

            local function SizeLabelHitbox(row)
                if not (row and row._labelBtn and row._nameFS) then return end
                local w = 10
                if row._nameFS.GetUnboundedStringWidth then
                    w = tonumber(row._nameFS:GetUnboundedStringWidth()) or w
                elseif row._nameFS.GetStringWidth then
                    w = tonumber(row._nameFS:GetStringWidth()) or w
                end
                if w < 10 then w = 10 end
                row._labelBtn:SetWidth(w)
            end

            local function TryRunMacroTextOrChat(text)
                text = tostring(text or "")
                if text == "" then return end

                if InCombatLockdown and InCombatLockdown() then
                    Print("Can't run in combat. Use: |cFFFFCC00" .. text .. "|r")
                    return
                end

                ---@diagnostic disable-next-line: undefined-global
                if type(RunMacroText) == "function" then
                    ---@diagnostic disable-next-line: undefined-global
                    local ok = pcall(RunMacroText, text)
                    if ok then
                        return
                    end
                end

                if type(ChatFrame_OpenChat) == "function" then
                    ChatFrame_OpenChat(text)
                else
                    Print("Use: |cFFFFCC00" .. text .. "|r")
                end
            end

            local function DeleteMacroByName(name)
                if type(GetMacroIndexByName) ~= "function" or type(DeleteMacro) ~= "function" then
                    return
                end
                local idx = GetMacroIndexByName(tostring(name or ""))
                if idx and idx > 0 then
                    pcall(DeleteMacro, idx)
                end
            end

            local function MacroExists(name)
                if type(GetMacroIndexByName) ~= "function" then
                    return false
                end
                local idx = GetMacroIndexByName(tostring(name or ""))
                return (idx and idx > 0) and true or false
            end

            local function SetupStaticRow(row, displayText, colorHex, onCreate, runText, deleteName)
                row._isFactionRow = true
                row._indexFS:SetText("")

                row._btnMacro:Hide()
                row._btnRename:Hide()
                row._btnDel:Hide()

                row._btnMStatic:Show()
                row._btnRStatic:Show()
                row._btnDStatic:Show()
                row._labelBtn:Show()

                row._nameFS:ClearAllPoints()
                row._nameFS:SetPoint("LEFT", row._indexFS, "RIGHT", 6, 0)
                row._nameFS:SetPoint("RIGHT", row._btnMStatic, "LEFT", -8, 0)
                row._nameFS:SetText("|c" .. tostring(colorHex or "FFFFFFFF") .. tostring(displayText or "") .. "|r")
                SizeLabelHitbox(row)

                row._btnMStatic:SetScript("OnClick", function()
                    onCreate()
                    RefreshSavedList()
                end)
                row._labelBtn:SetScript("OnClick", function()
                    onCreate()
                    RefreshSavedList()
                end)
                row._btnRStatic:SetScript("OnClick", function()
                    TryRunMacroTextOrChat(runText)
                end)
                row._btnDStatic:SetScript("OnClick", function()
                    DeleteMacroByName(deleteName)
                    RefreshSavedList()
                end)

                if MacroExists(deleteName) then
                    row._btnMStatic:Disable()
                else
                    row._btnMStatic:Enable()
                end
            end

            do
                local perCharacter = (ns and ns.Macros and type(ns.Macros.GetMacroPerCharSetting) == "function" and ns.Macros.GetMacroPerCharSetting()) or false

                shown = shown + 1
                local rowA = EnsureSavedRow(shown)
                rowA:Show()
                SetupStaticRow(
                    rowA,
                    "FGO HM Alliance",
                    "FF4DA6FF",
                    function()
                        if InCombatLockdown and InCombatLockdown() then
                            ErrorMessage("Can't create macros in combat")
                            return
                        end
                        if CanAddSavedLocation() then
                            CaptureHomeSlot(1)
                        end
                        local ok, createdName = EnsureFactionHomeMacro("ALLIANCE")
                        if ok and createdName and IsShiftKeyDown and IsShiftKeyDown() then
                            StartBind(createdName)
                        end
                    end,
                    (ns.Home and ns.Home.GetHomeClickMacroBody and ns.Home.GetHomeClickMacroBody(1)) or ("/click FGO_HomeTeleport1"),
                    "FGO HM Alliance"
                )

                SetTooltip(rowA._btnMStatic, "Creates 'FGO HM Alliance'\nShift-click to bind")
                SetTooltip(rowA._btnRStatic, "Runs the home teleport macro")
                SetTooltip(rowA._btnDStatic, "Deletes the macro")
                SetTooltip(rowA._labelBtn, "Create macro")

                shown = shown + 1
                local rowH = EnsureSavedRow(shown)
                rowH:Show()
                SetupStaticRow(
                    rowH,
                    "FGO HM Horde",
                    "FFFF4040",
                    function()
                        if InCombatLockdown and InCombatLockdown() then
                            ErrorMessage("Can't create macros in combat")
                            return
                        end
                        if CanAddSavedLocation() then
                            CaptureHomeSlot(2)
                        end
                        local ok, createdName = EnsureFactionHomeMacro("HORDE")
                        if ok and createdName and IsShiftKeyDown and IsShiftKeyDown() then
                            StartBind(createdName)
                        end
                    end,
                    (ns.Home and ns.Home.GetHomeClickMacroBody and ns.Home.GetHomeClickMacroBody(2)) or ("/click FGO_HomeTeleport2"),
                    "FGO HM Horde"
                )

                SetTooltip(rowH._btnMStatic, "Creates 'FGO HM Horde'\nShift-click to bind")
                SetTooltip(rowH._btnRStatic, "Runs the home teleport macro")
                SetTooltip(rowH._btnDStatic, "Deletes the macro")
                SetTooltip(rowH._labelBtn, "Create macro")

                shown = shown + 1
                local rowP = EnsureSavedRow(shown)
                rowP:Show()
                SetupStaticRow(
                    rowP,
                    "FGO HM Portal",
                    "FFA335EE",
                    function()
                        if InCombatLockdown and InCombatLockdown() then
                            ErrorMessage("Can't create macros in combat")
                            return
                        end
                        local ok = EnsurePortalMacro(perCharacter)
                        if ok then
                            -- no bind flow here; macro is a slash macro
                        end
                    end,
                    "/fgo hm portal",
                    "FGO HM Portal"
                )

                SetTooltip(rowP._btnMStatic, "Creates 'FGO HM Portal'")
                SetTooltip(rowP._btnRStatic, "Runs /fgo hm portal")
                SetTooltip(rowP._btnDStatic, "Deletes the macro")
                SetTooltip(rowP._labelBtn, "Create macro")
            end

            for i = 1, #list do
                local e = list[i]
                if type(e) == "table" and e.id ~= nil then
                    local entry = e
                    local entryId = entry.id
                    local macroName = GetSavedTeleportMacroName(entryId)

                    savedIndex = savedIndex + 1
                    shown = shown + 1
                    local row = EnsureSavedRow(shown)
                    row:Show()

                    row._isFactionRow = nil
                    row._btnMStatic:Hide()
                    row._btnRStatic:Hide()
                    row._btnDStatic:Hide()
                    row._labelBtn:Hide()

                    row._btnMacro:Show()
                    row._btnDel:Show()
                    row._btnRename:Show()
                    row._btnDel:Enable()
                    row._btnRename:Enable()

                    row._btnMacro:ClearAllPoints()
                    row._btnMacro:SetPoint("RIGHT", row._btnRename, "LEFT", -4, 0)

                    row._nameFS:ClearAllPoints()
                    row._nameFS:SetPoint("LEFT", row._indexFS, "RIGHT", 6, 0)
                    row._nameFS:SetPoint("RIGHT", row._btnMacro, "LEFT", -8, 0)

                    row._indexFS:SetText(tostring(savedIndex) .. ".")

                    local baseName = entry.name
                    if type(baseName) ~= "string" or baseName == "" then
                        baseName = "Location"
                    end
                    local display = tostring(baseName)
                    local neigh = entry.neighborhoodName
                    if type(neigh) == "string" and neigh ~= "" then
                        display = display .. " |cFF888888(" .. neigh .. ")|r"
                    end
                    row._nameFS:SetText(display)

                    local macroExists = false
                    if type(macroName) == "string" and macroName ~= "" and type(GetMacroIndexByName) == "function" then
                        local idx = GetMacroIndexByName(macroName)
                        macroExists = (idx and idx > 0) and true or false
                    end
                    if macroExists then
                        row._btnMacro:Disable()
                        row._btnMacro:SetText("M")
                    else
                        row._btnMacro:Enable()
                        row._btnMacro:SetText("M")
                    end

                    SetTooltip(row._btnMacro, function()
                        if macroExists then
                            return "M\nMacro already exists"
                        end
                        return "M\nCreate macro"
                    end)

                    row._btnMacro:SetScript("OnClick", function()
                        if InCombatLockdown and InCombatLockdown() then
                            ErrorMessage("Can't create macros in combat")
                            return
                        end
                        if not (ns and ns.Macros and type(ns.Macros.EnsureMacro) == "function") then
                            ErrorMessage("Macro helpers unavailable")
                            return
                        end
                        if ns.Home and type(ns.Home.ConfigureSavedTeleportClickButtonById) == "function" then
                            ns.Home.ConfigureSavedTeleportClickButtonById(entryId)
                        end
                        local body = (ns.Home and type(ns.Home.GetSavedTeleportClickMacroBodyById) == "function") and ns.Home.GetSavedTeleportClickMacroBodyById(entryId) or nil
                        if type(body) ~= "string" or body == "" then
                            ErrorMessage("Macro body unavailable")
                            return
                        end
                        local perCharacter = (ns and ns.Macros and type(ns.Macros.GetMacroPerCharSetting) == "function" and ns.Macros.GetMacroPerCharSetting()) or false

                        row._btnMacro:SetText("Creating...")
                        row._btnMacro:Disable()

                        local ok, why = ns.Macros.EnsureMacro(macroName, body, perCharacter and true or false)
                        if not ok then
                            ErrorMessage(tostring(why or "Could not create macro"))
                            row._btnMacro:SetText("Create Macro")
                            row._btnMacro:Enable()
                            SetStatus(tostring(why or "Could not create macro"), "error")
                            return
                        end

                        FlashButtonText(row._btnMacro, "Created", 0.8, "Macro Exists")
                        row._btnMacro:SetText("Macro Exists")
                        row._btnMacro:Disable()

                        SetStatus("Created macro: " .. tostring(macroName) .. " (open /macro to place)", "ok")

                        if IsShiftKeyDown and IsShiftKeyDown() then
                            StartBind(macroName)
                        end

                        RefreshSavedList()
                    end)

                    SetTooltip(row._btnMacro, function()
                        local body = (ns.Home and type(ns.Home.GetSavedTeleportClickMacroBodyById) == "function") and ns.Home.GetSavedTeleportClickMacroBodyById(entryId) or ""
                        return "Creates macro '" .. tostring(macroName or "") .. "'\n" .. tostring(body) .. "\nShift-click to bind"
                    end)

                    row._btnRename:SetScript("OnClick", function()
                        if InCombatLockdown and InCombatLockdown() then
                            ErrorMessage("Can't rename in combat")
                            return
                        end
                        local data = {
                            currentName = tostring(entry.name or ""),
                            onAccept = function(newName)
                                newName = Trim(newName)
                                if newName == "" then
                                    return
                                end
                                local db2 = GetSavedTeleportsDB()
                                local list2 = db2.list
                                for j = 1, #list2 do
                                    local cur = list2[j]
                                    if type(cur) == "table" and cur.id == entryId then
                                        cur.name = newName
                                        break
                                    end
                                end
                                RefreshSavedList()
                            end,
                        }
                        EnsureFGOStaticPopups()
                        StaticPopup_Show("FGO_RENAME_SAVED_LOCATION", nil, nil, data)
                    end)

                    row._btnDel:SetScript("OnClick", function()
                        if InCombatLockdown and InCombatLockdown() then
                            ErrorMessage("Can't delete in combat")
                            return
                        end

                        if not (IsShiftKeyDown and IsShiftKeyDown()) then
                            ErrorMessage("Hold Shift to delete")
                            return
                        end

                        local id = entryId
                        for j = 1, #list do
                            local cur = list[j]
                            if type(cur) == "table" and cur.id == id then
                                table.remove(list, j)
                                break
                            end
                        end

                        if ns and ns.Home and type(ns.Home.ConfigureSavedTeleportClickButtonById) == "function" then
                            ns.Home.ConfigureSavedTeleportClickButtonById(id)
                        end
                        RefreshSavedList()
                    end)
                end
            end

            for i = shown + 1, #savedRows do
                if savedRows[i] then
                    savedRows[i]:Hide()
                end
            end

            if #list <= 0 then
                emptyText:Show()
            else
                emptyText:Hide()
            end

            savedChild:SetHeight(math.max(1, shown) * SAVED_ROW_H)
        end

        btnAddSaved:SetScript("OnClick", function()
            if InCombatLockdown and InCombatLockdown() then
                ErrorMessage("Can't capture in combat")
                return
            end
            if not CanAddSavedLocation() then
                ErrorMessage("Enter a plot first")
                return
            end

            local data = {
                getPrefill = function()
                    if not (C_Housing and type(C_Housing.GetCurrentHouseInfo) == "function") then
                        return ""
                    end
                    local ok, info = pcall(C_Housing.GetCurrentHouseInfo)
                    if not ok or type(info) ~= "table" then
                        return ""
                    end
                    local v = info["plotName"] or info["ownerName"] or ""
                    if type(v) ~= "string" then
                        v = ""
                    end
                    return v
                end,
                onAccept = function(name)
                    local ok2, id, updated = CaptureSavedTeleport(name)
                    if ok2 then
                        btnAddSaved:Disable()
                        FlashButtonText(btnAddSaved, "Added", 0.8)

                        if updated then
                            SetStatus("Updated location #" .. tostring(id) .. ": " .. tostring(Trim(name) ~= "" and Trim(name) or "Location"), "ok")
                        else
                            SetStatus("Saved location #" .. tostring(id) .. ": " .. tostring(Trim(name) ~= "" and Trim(name) or "Location"), "ok")
                        end

                        RefreshSavedList()
                        if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
                            C_Timer.After(0.85, function()
                                if parent and parent:IsShown() then
                                    RefreshAddSavedButton()
                                end
                            end)
                        else
                            RefreshAddSavedButton()
                        end
                    end
                end,
            }
            EnsureFGOStaticPopups()
            StaticPopup_Show("FGO_ADD_SAVED_LOCATION", nil, nil, data)
        end)

        btnAlliance:SetScript("OnClick", function()
            if CanAddSavedLocation() then
                CaptureHomeSlot(1)
            end

            local ok, macroName = EnsureFactionHomeMacro("ALLIANCE")
            if ok and macroName and IsShiftKeyDown and IsShiftKeyDown() then
                StartBind(macroName)
            end
            RefreshSavedList()
        end)

        btnHorde:SetScript("OnClick", function()
            if CanAddSavedLocation() then
                CaptureHomeSlot(2)
            end

            local ok, macroName = EnsureFactionHomeMacro("HORDE")
            if ok and macroName and IsShiftKeyDown and IsShiftKeyDown() then
                StartBind(macroName)
            end
            RefreshSavedList()
        end)

        local ev = CreateFrame("Frame")
        parent._fgoHomeEventFrame = ev

        local function SafeRegisterEvent(frame, evName)
            if not (frame and frame.RegisterEvent and evName) then
                return
            end
            pcall(frame.RegisterEvent, frame, evName)
        end

        ev:RegisterEvent("PLAYER_ENTERING_WORLD")
        ev:RegisterEvent("NEIGHBORHOOD_LIST_UPDATED")
        ev:RegisterEvent("HOUSE_PLOT_ENTERED")
        SafeRegisterEvent(ev, "CURRENT_HOUSE_INFO_UPDATED")
        SafeRegisterEvent(ev, "CURRENT_HOUSE_INFO_RECIEVED")
        SafeRegisterEvent(ev, "CURRENT_HOUSE_INFO_RECEIVED")
        ev:SetScript("OnEvent", function()
            if parent:IsShown() then
                refreshRow1()
                refreshRow2()
                RefreshSavedList()
                RefreshAddSavedButton()
            end
            if popout:IsShown() then
                RefreshGuests()
            end
        end)

        popout:HookScript("OnShow", function()
            RefreshGuests()
        end)

        local credit = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        credit:ClearAllPoints()

        local anchor = parent._fgoCreditAnchor
        local yOff = tonumber(parent._fgoCreditYOffset)
        if yOff == nil then yOff = 10 end

        if anchor == "SAVED_BOX" and savedBox then
            credit:SetPoint("TOP", savedBox, "BOTTOM", 0, yOff)
        else
            credit:SetPoint("BOTTOM", parent, "BOTTOM", 0, yOff)
        end
        credit:SetJustifyH("CENTER")
        credit:SetWordWrap(false)
        credit:SetNonSpaceWrap(false)
        credit:SetText("Thanks to Sponson's Multiple House Teleports")

        refreshRow1()
        refreshRow2()
        RefreshSavedList()
    end

    ns.BuildHomePanel = BuildHomePanel
end
