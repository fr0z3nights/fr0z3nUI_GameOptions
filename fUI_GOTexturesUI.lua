---@diagnostic disable: undefined-global, need-check-nil

local addonName, ns = ...
if type(ns) ~= "table" then ns = {} end

local function Clamp(v, minV, maxV)
    v = tonumber(v)
    if not v then return minV end
    if v < minV then return minV end
    if v > maxV then return maxV end
    return v
end

local function Trim(s)
    s = tostring(s or "")
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function SetShown(frame, shown)
    if not frame then return end
    if shown then frame:Show() else frame:Hide() end
end

local function CreateLabel(parent, text, w)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetText(text)
    if w then fs:SetWidth(w) fs:SetJustifyH("LEFT") end
    return fs
end

local function StripInputBoxArt(eb)
    if not eb then return end
    local l = rawget(eb, "Left")
    local m = rawget(eb, "Middle")
    local r = rawget(eb, "Right")
    if l and l.Hide then l:Hide() end
    if m and m.Hide then m:Hide() end
    if r and r.Hide then r:Hide() end
    if eb.SetTextInsets then
        eb:SetTextInsets(6, 6, 0, 0)
    end
end

local function StripDropDownArt(dd)
    if not dd then return end
    local l = rawget(dd, "Left")
    local m = rawget(dd, "Middle")
    local r = rawget(dd, "Right")
    if l and l.Hide then l:Hide() end
    if m and m.Hide then m:Hide() end
    if r and r.Hide then r:Hide() end
    -- keep Button visible/clickable; only strip border art
    local t = rawget(dd, "Text")
    if t and t.SetJustifyH then t:SetJustifyH("LEFT") end
end

local function AddGhostText(parent, anchor, text)
    if not (parent and parent.CreateFontString and anchor) then return nil end
    local fs = parent:CreateFontString(nil, "BACKGROUND", "GameFontDisable")
    fs:SetPoint("LEFT", anchor, "LEFT", 6, 0)
    fs:SetText(tostring(text or ""))
    if fs.SetAlpha then fs:SetAlpha(0.75) end
    fs:Hide()
    return fs
end

local function UpdateGhost(eb, ghost)
    if not (eb and ghost) then return end
    local txt = tostring((eb.GetText and eb:GetText()) or "")
    local show = (txt == "") and not (eb.HasFocus and eb:HasFocus())
    SetShown(ghost, show)
end

local function GetButtonFontString(btn)
    if not btn then return nil end
    if btn.GetFontString then
        local fs = btn:GetFontString()
        if fs then return fs end
    end
    local fs = rawget(btn, "Text") or rawget(btn, "text")
    if fs then return fs end

    if btn.GetRegions then
        local regions = { btn:GetRegions() }
        for _, r in ipairs(regions) do
            if r and r.GetObjectType and r:GetObjectType() == "FontString" then
                return r
            end
        end
    end
    return nil
end

local function SetBtnState(btn, on, onR, onG, onB, offR, offG, offB, fallbackTextOn, fallbackTextOff)
    if not btn then return end
    local fs = GetButtonFontString(btn)
    if not (fs and fs.SetTextColor) then
        if btn.SetText and (fallbackTextOn or fallbackTextOff) then
            if on then
                btn:SetText(tostring(fallbackTextOn or "ON"))
            else
                btn:SetText(tostring(fallbackTextOff or "OFF"))
            end
        end
        return
    end
    if on then
        fs:SetTextColor(onR or 1, onG or 0.85, onB or 0.1)
    else
        fs:SetTextColor(offR or 0.6, offG or 0.6, offB or 0.6)
    end
end

local function Tip(frame, title, body)
    if not (frame and frame.SetScript) then return end
    frame:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(tostring(title or ""))
        if body and body ~= "" then
            GameTooltip:AddLine(tostring(body), 1, 1, 1, true)
        end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
end

local function CreateEditBox(parent, width)
    local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    eb:SetAutoFocus(false)
    eb:SetSize(width or 140, 22)
    eb:SetTextInsets(8, 8, 0, 0)
    if eb.SetTextColor then eb:SetTextColor(1, 1, 1) end
    if eb.SetCursorColor then eb:SetCursorColor(1, 1, 1) end
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return eb
end

local function CreateButton(parent, text, w, h)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetText(text)
    b:SetSize(w or 80, h or 22)
    if b.EnableMouse then b:EnableMouse(true) end
    if b.RegisterForClicks then
        pcall(b.RegisterForClicks, b, "AnyUp")
    end
    return b
end

local function CreateCheck(parent, text)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb.text = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    cb.text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    cb.text:SetText(text)
    return cb
end

local function CreateSlider(parent, label, minV, maxV, step)
    local s = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(step or 0.01)
    s:SetObeyStepOnDrag(true)
    s.Text:SetText(label)
    s.Low:SetText(tostring(minV))
    s.High:SetText(tostring(maxV))
    if not s.Value then
        local fs = s:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("TOP", s, "BOTTOM", 0, -2)
        fs:SetJustifyH("CENTER")
        fs:SetText("")
        s.Value = fs
    end
    return s
end

local function SetSliderValueLabel(s, v, fmt)
    if not (s and s.Value and s.Value.SetText) then return end
    local f = fmt or "%.2f"
    s.Value:SetText(string.format(f, tonumber(v) or 0))
end

local _ddCounter = 0
local function CreateDropDown(parent, width)
    _ddCounter = _ddCounter + 1
    local name = "FGO_Textures_DropDown" .. tostring(_ddCounter)
    local dd = CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")
    UIDropDownMenu_SetWidth(dd, width or 160)
    return dd
end

local function GetDropDownText(dd)
    if not dd then return nil end
    if UIDropDownMenu_GetText then
        return UIDropDownMenu_GetText(dd)
    end
    return nil
end

local function SetDropDownText(dd, txt)
    if dd and UIDropDownMenu_SetText then
        UIDropDownMenu_SetText(dd, txt)
    end
end

local function SetDropDownSelected(dd, value, text)
    if dd then
        dd._fgoSelected = value
    end
    if dd and UIDropDownMenu_SetSelectedValue then
        UIDropDownMenu_SetSelectedValue(dd, value)
    end
    if text ~= nil then
        SetDropDownText(dd, text)
    end
end

local function GetDropDownSelected(dd)
    if dd and dd._fgoSelected ~= nil then
        return dd._fgoSelected
    end
    if dd and UIDropDownMenu_GetSelectedValue then
        return UIDropDownMenu_GetSelectedValue(dd)
    end
    return nil
end

local function CreateMultiLineBox(parent, width, height)
    local sf = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    sf:SetSize(width or 240, height or 70)

    if sf.ScrollBar then
        sf.ScrollBar:Hide()
        sf.ScrollBar.Show = sf.ScrollBar.Hide
    end

    if sf.EnableMouse then sf:EnableMouse(true) end

    local eb = CreateFrame("EditBox", nil, sf)
    eb:SetAutoFocus(false)
    eb:SetMultiLine(true)
    eb:SetFontObject("ChatFontNormal")
    eb:SetPoint("TOPLEFT", 0, 0)
    eb:SetSize((width or 240) - 4, height or 70)
    if eb.EnableMouse then eb:EnableMouse(true) end
    if eb.EnableKeyboard then eb:EnableKeyboard(true) end
    if eb.EnableMouseWheel then eb:EnableMouseWheel(true) end
    if eb.SetTextColor then eb:SetTextColor(1, 1, 1) end
    if eb.SetCursorColor then eb:SetCursorColor(1, 1, 1) end
    eb:SetText("")

    if eb.SetScript then
        eb:SetScript("OnMouseDown", function(self)
            if self.SetFocus then self:SetFocus() end
        end)
    end

    if eb.SetScript then
        eb:SetScript("OnMouseWheel", function(_, delta)
            local cur = sf.GetVerticalScroll and sf:GetVerticalScroll() or 0
            local step = 18
            if delta > 0 then
                sf:SetVerticalScroll(math.max(0, cur - step))
            else
                sf:SetVerticalScroll(cur + step)
            end
        end)
    end

    eb:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    eb:SetScript("OnTextChanged", function(self)
        local baseH = tonumber(height) or 70
        local textH = 0
        if self.GetTextHeight then
            textH = tonumber(self:GetTextHeight()) or 0
        elseif self.GetStringHeight then
            textH = tonumber(self:GetStringHeight()) or 0
        end
        local wantH = math.max(baseH, textH + 12)
        if self.SetHeight then
            self:SetHeight(wantH)
        end
    end)

    if sf.SetScript then
        sf:SetScript("OnMouseDown", function()
            if eb and eb.SetFocus then eb:SetFocus() end
        end)

        sf:SetScript("OnSizeChanged", function(self, w)
            if eb and eb.SetWidth and type(w) == "number" then
                eb:SetWidth(math.max(10, w - 4))
            end
        end)
    end

    sf:SetScrollChild(eb)
    return { Frame = sf, EditBox = eb }
end

local function SortedWidgetKeys(db)
    local out = {}
    for k in pairs((db and db.widgets) or {}) do
        out[#out + 1] = k
    end
    table.sort(out, function(a, b) return tostring(a):lower() < tostring(b):lower() end)
    return out
end

function ns.TexturesUI_Build(frame, panel, helpers)
    helpers = helpers or {}
    local InitSV = helpers.InitSV or function() end
    local Print = helpers.Print or function(msg) print(tostring(msg)) end

    if not (panel and frame) then
        return function() end
    end

    if not (ns and ns.Textures and ns.Textures.EnsureDB) then
        local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        hint:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -54)
        hint:SetText("Textures module not loaded")
        return function() end
    end

    InitSV()
    local db = ns.Textures.EnsureDB()

    -- Forward declare: used by the Spell Icon button, defined later.
    local SetTexturePath

    local function GetFactionFromWidget(w)
        if type(w) ~= "table" then return nil end
        do
            local direct = w.faction
            if direct ~= nil then
                local dv = Trim(direct)
                if dv:lower() == "alliance" then return "Alliance" end
                if dv:lower() == "horde" then return "Horde" end
            end
        end
        local conds = w.conds
        if type(conds) ~= "table" then return nil end
        for _, c in ipairs(conds) do
            if type(c) == "table" and tostring(c.type or ""):lower() == "faction" then
                local v = Trim(c.value or c.faction or "")
                if v:lower() == "alliance" then return "Alliance" end
                if v:lower() == "horde" then return "Horde" end
            end
        end
        return nil
    end

    local function GetTextureFromWidget(w)
        if type(w) ~= "table" then return "" end
        local t = w.texture
        if t == nil then t = w.tex end
        if t == nil then t = w.path end
        t = tostring(t or "")
        local fid = t:match("^[Ff][Ii][Ll][Ee][Ii][Dd]:(%d+)$")
        if fid then
            return fid
        end
        return t
    end

    local header = CreateFrame("Frame", nil, panel)
    header:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -40)
    header:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -10, -40)
    header:SetHeight(24)

    local widgetDD = CreateDropDown(header, 170)
    widgetDD:SetPoint("LEFT", header, "LEFT", 0, -2)
    StripDropDownArt(widgetDD)

    local newBtn = CreateButton(header, "New", 56, 22)
    newBtn:SetPoint("LEFT", widgetDD, "RIGHT", 6, 2)

    local delBtn = CreateButton(header, "Delete", 56, 22)
    delBtn:SetPoint("LEFT", newBtn, "RIGHT", 6, 0)

    local refreshBtn = CreateButton(header, "Refresh", 64, 22)
    refreshBtn:SetPoint("LEFT", delBtn, "RIGHT", 6, 0)

    -- Texture input moved to header line (no label, ghost text, no border)
    local texEB = CreateEditBox(header, 200)
    texEB:SetPoint("LEFT", refreshBtn, "RIGHT", 6, 0)
    StripInputBoxArt(texEB)
    local texGhost = AddGhostText(header, texEB, "Texture")

    -- Texture entry mode toggle:
    --   Tex (default): entry is treated as a texture path / addon media name.
    --   ID: entry is treated as a WoW texture fileID (numeric).
    local texMode = "texture" -- "texture" | "fileid"
    local texModeBtn = CreateButton(header, "T", 26, 22)
    Tip(texModeBtn, "Texture Entry Mode", "T: treat as texture path/addon media (numeric becomes textures\\123).\nI: treat numeric as a WoW texture fileID.")

    local texPickBtn = CreateButton(header, "Pick", 56, 22)
    texPickBtn:SetPoint("RIGHT", header, "RIGHT", 0, 0)
    texEB:ClearAllPoints()
    texEB:SetPoint("LEFT", refreshBtn, "RIGHT", 6, 0)
    texModeBtn:SetPoint("RIGHT", texPickBtn, "LEFT", -6, 0)
    texEB:SetPoint("RIGHT", texModeBtn, "LEFT", -6, 0)

    local function IsKnownAddonMediaName(name)
        if type(name) ~= "string" then
            return false
        end
        ns._TexturesMediaLookup = ns._TexturesMediaLookup or false
        if ns._TexturesMediaLookup == false then
            local lookup = {}
            local media = ns.TexturesMediaTextures
            if type(media) == "table" then
                for _, it in ipairs(media) do
                    if type(it) == "table" then
                        local v = tostring(it[2] or "")
                        if v ~= "" then
                            lookup[v] = true
                        end
                    end
                end
            end
            ns._TexturesMediaLookup = lookup
        end
        local l = ns._TexturesMediaLookup
        return type(l) == "table" and l[name] == true
    end

    local function SetTexMode(mode, adjustText)
        if mode == "fileid" then
            texMode = "fileid"
            texModeBtn:SetText("I")
        else
            texMode = "texture"
            texModeBtn:SetText("T")
        end

        if adjustText then
            local t = Trim(texEB:GetText())
            local fid = t:match("^[Ff][Ii][Ll][Ee][Ii][Dd]:(%d+)$")
            if fid then t = fid end
            if texMode == "fileid" then
                -- Show as digits; saving will prefix as fileid:...
                local n = t:match("^(%d+)$")
                if n then
                    texEB:SetText(n)
                end
            else
                -- Texture mode: keep as-is (digits-only are valid addon media names).
                texEB:SetText(t)
            end
            UpdateGhost(texEB, texGhost)
        end
    end

    texModeBtn:SetScript("OnClick", function()
        SetTexMode((texMode == "texture") and "fileid" or "texture", true)
        if selectedKey then ReadUIIntoWidget(selectedKey) end
    end)

    local controls = CreateFrame("Frame", nil, panel)
    controls:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -8)
    controls:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -10, 10)
    if controls.SetClipsChildren then controls:SetClipsChildren(false) end

    -- Widget name/key (rename)
    local nameEB = CreateEditBox(controls, 170)
    nameEB:SetPoint("TOPLEFT", controls, "TOPLEFT", 0, 0)
    StripInputBoxArt(nameEB)
    local nameGhost = AddGhostText(controls, nameEB, "Name")

    -- Level moved up beside Name
    local levelEB = CreateEditBox(controls, 60)
    levelEB:SetPoint("LEFT", nameEB, "RIGHT", 8, 0)
    StripInputBoxArt(levelEB)
    local levelGhost = AddGhostText(controls, levelEB, "Level")

    local noWidget = controls:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    noWidget:SetPoint("TOPLEFT", nameEB, "BOTTOMLEFT", 0, -10)
    noWidget:SetText("No widget selected")

    local body = CreateFrame("Frame", nil, controls)
    body:SetPoint("TOPLEFT", noWidget, "BOTTOMLEFT", 0, -10)
    body:SetPoint("BOTTOMRIGHT", controls, "BOTTOMRIGHT", 0, 0)

    -- Left column: core properties (matches ArtLayer)
    local left = CreateFrame("Frame", nil, body)
    left:SetPoint("TOPLEFT", body, "TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", body, "BOTTOMLEFT", 0, 0)
    left:SetPoint("RIGHT", body, "CENTER", -10, 0)

    -- Buttons (instead of checkboxes)
    local enabledBtn = CreateButton(left, "Widget", 72, 22)
    enabledBtn:SetPoint("TOPLEFT", 0, 0)
    Tip(enabledBtn, "Widget Enabled", "Toggles this widget on/off.")

    local clickBtn = CreateButton(left, "Click", 72, 22)
    clickBtn:SetPoint("LEFT", enabledBtn, "RIGHT", 6, 0)
    Tip(clickBtn, "Clickthrough", "ON: clickthrough (non-interactable). OFF: mouse can interact with it.")

    local unlockBtn = CreateButton(left, "Unlock", 72, 22)
    unlockBtn:SetPoint("LEFT", clickBtn, "RIGHT", 6, 0)
    Tip(unlockBtn, "Unlock / Drag", "ON: drag the widget on screen to reposition.")

    local combatBtn = CreateButton(left, "Off", 90, 22)
    combatBtn:SetPoint("LEFT", unlockBtn, "RIGHT", 6, 0)
    Tip(combatBtn, "Combat Condition", "Cycles: Off → In Combat → No Combat")

    local questBtn = CreateButton(left, "Quest", 72, 22)
    questBtn:SetPoint("TOPLEFT", enabledBtn, "BOTTOMLEFT", 0, -4)
    Tip(questBtn, "Hide When Quest Completed", "When ON, the widget hides if QuestID is completed.")

    local condQuestEB = CreateEditBox(left, 72)
    condQuestEB:SetPoint("LEFT", questBtn, "RIGHT", 6, 0)
    StripInputBoxArt(condQuestEB)
    local questGhost = AddGhostText(left, condQuestEB, "QuestID")

    -- Spell / class / spec moved under Quest row (left column)
    local condSpellEB = CreateEditBox(left, 180)
    condSpellEB:SetPoint("TOPLEFT", questBtn, "BOTTOMLEFT", 0, -10)
    StripInputBoxArt(condSpellEB)
    local spellGhost = AddGhostText(left, condSpellEB, "SpellID (ready)")

    local spellIconBtn = CreateButton(left, "Icon", 56, 22)
    spellIconBtn:SetPoint("LEFT", condSpellEB, "RIGHT", 6, 0)
    Tip(spellIconBtn, "Use Spell Icon", "Sets Texture to this spell's icon.")

    local condClassDD = CreateDropDown(left, 110)
    condClassDD:SetPoint("TOPLEFT", questBtn, "BOTTOMLEFT", -14, -14)
    StripDropDownArt(condClassDD)
    SetDropDownSelected(condClassDD, nil, "Class")

    local condSpecDD = CreateDropDown(left, 110)
    condSpecDD:SetPoint("LEFT", condClassDD, "RIGHT", 22, 0)
    StripDropDownArt(condSpecDD)
    SetDropDownSelected(condSpecDD, nil, "Spec")

    -- Spell cooldown conditions were removed from Textures.
    -- Keep these controls hidden to avoid confusing/non-functional UI.
    if condSpellEB and condSpellEB.Hide then condSpellEB:Hide() end
    if spellGhost and spellGhost.Hide then spellGhost:Hide() end
    if spellIconBtn and spellIconBtn.Hide then spellIconBtn:Hide() end

    -- Right column: strata/layer/blend/texture (matches ArtLayer)
    local right = CreateFrame("Frame", nil, body)
    right:SetPoint("TOPRIGHT", body, "TOPRIGHT", 0, 0)
    right:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", 0, 0)
    right:SetPoint("LEFT", body, "CENTER", 10, 0)
    if right.SetClipsChildren then right:SetClipsChildren(false) end

    -- Strata / Layer+Sub on one row (no labels)
    local strataDD = CreateDropDown(right, 110)
    strataDD:SetPoint("TOPLEFT", right, "TOPLEFT", 0, -2)
    StripDropDownArt(strataDD)

    local layerDD = CreateDropDown(right, 110)
    layerDD:SetPoint("LEFT", strataDD, "RIGHT", 6, 0)
    StripDropDownArt(layerDD)

    local subEB = CreateEditBox(right, 60)
    subEB:SetPoint("LEFT", layerDD, "RIGHT", 6, 2)
    StripInputBoxArt(subEB)

    -- Blend row (no label) + tip beside it
    local blendDD = CreateDropDown(right, 110)
    blendDD:SetPoint("TOPLEFT", strataDD, "BOTTOMLEFT", 0, -18)
    StripDropDownArt(blendDD)

    local hint = right:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("LEFT", blendDD, "RIGHT", 8, 2)
    hint:SetWidth(170)
    hint:SetJustifyH("LEFT")
    hint:SetText("Tip: blend + layer fixes some alpha issues")

    -- Size/Pos moved to right column above sliders
    local sizeLabel = CreateLabel(right, "Size (w/h):", 110)
    sizeLabel:SetPoint("TOPLEFT", blendDD, "BOTTOMLEFT", 0, -18)
    local wEB = CreateEditBox(right, 60)
    wEB:SetPoint("LEFT", sizeLabel, "RIGHT", 8, 0)
    local hEB = CreateEditBox(right, 60)
    hEB:SetPoint("LEFT", wEB, "RIGHT", 8, 0)

    local posLabel = CreateLabel(right, "Pos (point/x/y):", 110)
    posLabel:SetPoint("TOPLEFT", sizeLabel, "BOTTOMLEFT", 0, -12)
    local pointEB = CreateEditBox(right, 90)
    pointEB:SetPoint("LEFT", posLabel, "RIGHT", 8, 0)
    local xEB = CreateEditBox(right, 60)
    xEB:SetPoint("LEFT", pointEB, "RIGHT", 8, 0)
    local yEB = CreateEditBox(right, 60)
    yEB:SetPoint("LEFT", xEB, "RIGHT", 8, 0)

    -- Alpha/Scale next to each other under the texture input (right half)
    local alpha = CreateSlider(right, "Alpha", 0, 1, 0.01)
    alpha:SetPoint("TOPLEFT", posLabel, "BOTTOMLEFT", 0, -22)
    alpha:SetPoint("RIGHT", right, "CENTER", -6, 0)

    local scale = CreateSlider(right, "Scale", 0.05, 10, 0.05)
    scale:SetPoint("TOPLEFT", alpha, "TOPRIGHT", 12, 0)
    scale:SetPoint("RIGHT", right, "RIGHT", 0, 0)

    local zoom = CreateSlider(right, "Zoom", 1, 4, 0.01)
    zoom:SetPoint("TOPLEFT", alpha, "BOTTOMLEFT", 0, -28)
    zoom:SetPoint("RIGHT", right, "RIGHT", 0, 0)

    local afterTop = CreateFrame("Frame", nil, body)
    afterTop:SetSize(1, 1)
    afterTop:SetPoint("TOP", zoom, "BOTTOM", 0, -18)
    afterTop:SetPoint("LEFT", body, "LEFT", 0, 0)
    afterTop:SetPoint("RIGHT", body, "RIGHT", 0, 0)

    -- Faction dropdown (label-less, "Faction" means off/both)
    local factionDD = CreateDropDown(right, 110)
    factionDD:SetPoint("TOPLEFT", afterTop, "TOPLEFT", 0, -2)
    StripDropDownArt(factionDD)
    SetDropDownSelected(factionDD, "Faction", "Faction")

    -- Characters box moved to the old blend area region (ghost text)
    local condPlayerBox = CreateMultiLineBox(right, 240, 140)
    condPlayerBox.Frame:ClearAllPoints()
    condPlayerBox.Frame:SetPoint("TOPLEFT", factionDD, "BOTTOMLEFT", 0, -8)
    condPlayerBox.Frame:SetPoint("RIGHT", right, "RIGHT", 0, 0)
    local charsGhost = nil
    if condPlayerBox and condPlayerBox.EditBox then
        charsGhost = AddGhostText(right, condPlayerBox.EditBox, "Characters...")
    end

    -- Optional gating: spell cooldown + class/spec moved to left column.

    -- (Seen UI removed; Characters list already provides name gating.)

    -- Internal state
    local selectedKey = nil
    local dragKey = nil
    local uiSuppress = false

    -- Forward-declare: SelectWidgetKey is defined before the function body below.
    -- Without this, Lua resolves it as a global and it will be nil at runtime.
    local WriteWidgetIntoUI

    local function SelectWidgetKey(key)
        selectedKey = key
        if UIDropDownMenu_SetText then
            UIDropDownMenu_SetText(widgetDD, key or "(select widget)")
        end
        if nameEB and nameEB.SetText then
            nameEB:SetText(tostring(key or ""))
            UpdateGhost(nameEB, nameGhost)
        end
        WriteWidgetIntoUI(key)
    end

    local function GetWidget()
        db = ns.Textures.EnsureDB()
        if not (db and db.widgets and selectedKey) then return nil end
        return db.widgets[selectedKey]
    end

    local function ParseListText(text)
        text = tostring(text or "")
        text = text:gsub("\r", "")
        text = text:gsub("\n", ",")
        local out = {}
        for part in text:gmatch("[^,]+") do
            local p = Trim(part)
            if p ~= "" then out[#out + 1] = p end
        end
        return out
    end

    local function DisableDragMode()
        if not dragKey then return end
        local wf = ns.Textures.GetWidgetFrame and ns.Textures.GetWidgetFrame(dragKey) or nil
        if wf then
            if wf.StopMovingOrSizing then
                pcall(wf.StopMovingOrSizing, wf)
            end
            wf._fgoForceShow = nil
            wf._fgoDragging = nil
            if wf._fgoDragOverlay and wf._fgoDragOverlay.Hide then
                wf._fgoDragOverlay:Hide()
            end
            if wf.SetScript then
                wf:SetScript("OnDragStart", nil)
                wf:SetScript("OnDragStop", nil)
            end
            if wf.SetMovable then
                wf:SetMovable(false)
            end
        end
        if ns.Textures.ApplyWidget then
            ns.Textures.ApplyWidget(dragKey)
        end
        dragKey = nil
    end

    local function EnableDragMode(key)
        if not key then return end
        dragKey = key
        local wf = ns.Textures.GetWidgetFrame and ns.Textures.GetWidgetFrame(key) or nil
        if not wf then
            if ns.Textures.ApplyWidget then ns.Textures.ApplyWidget(key) end
            wf = ns.Textures.GetWidgetFrame and ns.Textures.GetWidgetFrame(key) or nil
        end
        if not wf then return end

        wf._fgoForceShow = true
        if ns.Textures.ApplyWidget then ns.Textures.ApplyWidget(key) end

        if wf.SetMovable then wf:SetMovable(true) end
        if wf.SetClampedToScreen then wf:SetClampedToScreen(true) end
        if wf.EnableMouse then wf:EnableMouse(true) end
        if wf.RegisterForDrag then
            pcall(wf.RegisterForDrag, wf, "LeftButton")
        end

        if not wf._fgoDragOverlay and wf.CreateTexture then
            local ov = wf:CreateTexture(nil, "OVERLAY")
            ov:SetAllPoints(wf)
            if ov.SetColorTexture then
                ov:SetColorTexture(0, 1, 1, 0.12)
            end
            wf._fgoDragOverlay = ov
        end
        if wf._fgoDragOverlay and wf._fgoDragOverlay.Show then
            wf._fgoDragOverlay:Show()
        end

        wf:SetScript("OnDragStart", function(self)
            self._fgoDragging = true
            if self.StartMoving then self:StartMoving() end
        end)

        wf:SetScript("OnDragStop", function(self)
            if self.StopMovingOrSizing then self:StopMovingOrSizing() end
            self._fgoDragging = nil

            db = ns.Textures.EnsureDB()
            local w = (db and db.widgets and dragKey) and db.widgets[dragKey] or nil
            if type(w) ~= "table" then return end

            local p, _, _, x, y = self:GetPoint(1)
            w.point = p or w.point or "CENTER"
            w.x = math.floor((tonumber(x) or 0) + 0.5)
            w.y = math.floor((tonumber(y) or 0) + 0.5)

            pointEB:SetText(tostring(w.point or "CENTER"))
            xEB:SetText(tostring(w.x or 0))
            yEB:SetText(tostring(w.y or 0))

            if ns.Textures.ApplyWidget then ns.Textures.ApplyWidget(dragKey) end
        end)
    end

    local function BuildCondsFromUI(w)
        local conds = {}

        do
            local sel = GetDropDownSelected(factionDD)
            local txt = tostring(sel or GetDropDownText(factionDD) or "Faction")
            if txt == "Alliance" or txt == "Horde" then
                table.insert(conds, { type = "faction", value = txt })
            end
        end

        do
            local raw = (condPlayerBox and condPlayerBox.EditBox and condPlayerBox.EditBox.GetText) and condPlayerBox.EditBox:GetText() or ""
            local list = ParseListText(raw)
            if list[1] then
                table.insert(conds, { type = "player", list = list })
            end
        end

        -- spellOffCooldown removed

        do
            local sel = GetDropDownSelected(condClassDD)
            local txt = Trim(tostring(sel or GetDropDownText(condClassDD) or ""))
            if txt ~= "" and txt ~= "Class" then
                table.insert(conds, { type = "class", value = txt })
            end
        end

        do
            local sel = GetDropDownSelected(condSpecDD)
            local sid = tonumber(sel)
            if sid then
                table.insert(conds, { type = "spec", id = sid })
            end
        end

        do
            local mode = w._uiCombatMode
            if mode == "in" or mode == "out" then
                table.insert(conds, { type = "combat", value = mode })
            end
        end

        if w._uiQuestHide == true then
            local qid = tonumber(Trim(condQuestEB:GetText()))
            if qid then
                table.insert(conds, { type = "questCompleteHide", id = qid })
            end
        end
        w.conds = conds
    end

    local function ReadUIIntoWidget(key)
        if not key then return end
        db = ns.Textures.EnsureDB()
        db.widgets[key] = db.widgets[key] or {}
        local w = db.widgets[key]

        w.type = w.type or "texture"

        w.enabled = (w._uiEnabled == true)
        w.clickthrough = (w._uiClickthrough == true)
        w.alpha = Clamp(alpha:GetValue(), 0, 1)
        w.scale = Clamp(scale:GetValue(), 0.05, 10)
        w.zoom = Clamp(zoom:GetValue(), 1, 4)
        w.w = tonumber(Trim(wEB:GetText())) or w.w or 128
        w.h = tonumber(Trim(hEB:GetText())) or w.h or 128
        w.point = Trim(pointEB:GetText()) ~= "" and Trim(pointEB:GetText()) or (w.point or "CENTER")
        w.x = tonumber(Trim(xEB:GetText())) or w.x or 0
        w.y = tonumber(Trim(yEB:GetText())) or w.y or 0

        if w.type ~= "model" then
            local t = Trim(texEB:GetText())
            local fid = t:match("^[Ff][Ii][Ll][Ee][Ii][Dd]:(%d+)$")
            if fid then
                t = fid
            end

            if texMode == "fileid" then
                if t:match("^%d+$") then
                    t = "fileid:" .. t
                end
            else
                -- Texture mode: never store the fileid: prefix.
                if t:match("^[Ff][Ii][Ll][Ee][Ii][Dd]:(%d+)$") then
                    t = t:match("^[Ff][Ii][Ll][Ee][Ii][Dd]:(%d+)$")
                end
            end

            w.texture = t
            w.layer = tostring(GetDropDownText(layerDD) or (w.layer or "ARTWORK"))
            w.sub = tonumber(Trim(subEB:GetText())) or w.sub or 0
        end

        do
            local st = tostring(GetDropDownText(strataDD) or "(default)")
            if st == "(default)" or st == "" then
                w.strata = nil
            else
                w.strata = st
            end
        end
        w.level = tonumber(Trim(levelEB:GetText())) or w.level
        if w.type ~= "model" then
            w.blend = tostring(GetDropDownText(blendDD) or (w.blend or "BLEND"))
        end

        BuildCondsFromUI(w)
        if ns.Textures.ApplyWidget then
            ns.Textures.ApplyWidget(key)
        end
    end

    WriteWidgetIntoUI = function(key)
        uiSuppress = true
        if dragKey and key ~= dragKey then
            DisableDragMode()
        end
        selectedKey = key
        local w = GetWidget()
        local has = (type(w) == "table")
        SetShown(noWidget, not has)
        SetShown(body, has)

        if nameEB and nameEB.SetEnabled then
            nameEB:SetEnabled(has)
        end
        if levelEB and levelEB.SetEnabled then
            levelEB:SetEnabled(has)
        end
        if nameEB and nameEB.SetText then
            nameEB:SetText(tostring(key or ""))
            UpdateGhost(nameEB, nameGhost)
        end

        if not has then
            DisableDragMode()
            uiSuppress = false
            return
        end

        w._uiEnabled = (w.enabled ~= false)
        -- Engine default matches ArtLayer: nil clickthrough behaves as ON.
        w._uiClickthrough = (w.clickthrough ~= nil) and (w.clickthrough == true) or true

        SetBtnState(enabledBtn, w._uiEnabled, nil, nil, nil, nil, nil, nil, "Widget ON", "Widget OFF")
        SetBtnState(clickBtn, w._uiClickthrough, nil, nil, nil, nil, nil, nil, "Click ON", "Click OFF")
        SetBtnState(unlockBtn, dragKey == key, nil, nil, nil, nil, nil, nil, "Unlock ON", "Unlock OFF")

        do
            local raw = tostring((w and w.texture) or "")
            if raw:match("^[Ff][Ii][Ll][Ee][Ii][Dd]:(%d+)$") then
                SetTexMode("fileid", false)
            elseif raw:match("^%d+$") and not IsKnownAddonMediaName(raw) then
                -- Legacy numeric-only fileID (before fileid: prefix existed)
                SetTexMode("fileid", false)
            else
                SetTexMode("texture", false)
            end
        end

        levelEB:SetText(tostring(w.level or ""))
        UpdateGhost(levelEB, levelGhost)

        alpha:SetValue(Clamp(w.alpha or 1, 0, 1))
        SetSliderValueLabel(alpha, alpha:GetValue(), "%.2f")

        scale:SetValue(Clamp(w.scale or 1, 0.05, 10))
        SetSliderValueLabel(scale, scale:GetValue(), "%.2f")

        zoom:SetValue(Clamp(w.zoom or 1, 1, 4))
        SetSliderValueLabel(zoom, zoom:GetValue(), "%.2f")

        wEB:SetText(tostring(w.w or 128))
        hEB:SetText(tostring(w.h or 128))
        pointEB:SetText(tostring(w.point or "CENTER"))
        xEB:SetText(tostring(w.x or 0))
        yEB:SetText(tostring(w.y or 0))

        SetDropDownText(strataDD, tostring(w.strata or "(default)"))

        local isTexture = (tostring(w.type or "texture") ~= "model")
        SetShown(texEB, isTexture)
        SetShown(texPickBtn, isTexture)
        SetShown(layerDD, isTexture)
        SetShown(subEB, isTexture)
        SetShown(blendDD, isTexture)
        SetShown(hint, isTexture)

        if isTexture then
            local raw = tostring((w and w.texture) or "")
            local fid = raw:match("^[Ff][Ii][Ll][Ee][Ii][Dd]:(%d+)$")
            if fid then
                texEB:SetText(fid)
            else
                texEB:SetText(GetTextureFromWidget(w))
            end
            SetDropDownText(layerDD, tostring(w.layer or "ARTWORK"))
            subEB:SetText(tostring(w.sub or 0))
            SetDropDownText(blendDD, tostring(w.blend or "BLEND"))
        else
            texEB:SetText("")
            SetDropDownText(layerDD, "ARTWORK")
            subEB:SetText("0")
            SetDropDownText(blendDD, "BLEND")
        end

        UpdateGhost(texEB, texGhost)

        -- Conditions
        SetDropDownSelected(factionDD, "Faction", "Faction")
        w._uiCombatMode = nil
        w._uiQuestHide = false
        combatBtn:SetText("Off")
        SetBtnState(combatBtn, false, nil, nil, nil, nil, nil, nil, nil, "Off")
        SetBtnState(questBtn, false, nil, nil, nil, nil, nil, nil, "Quest ON", "Quest OFF")
        condQuestEB:SetText("")
        UpdateGhost(condQuestEB, questGhost)
        if condPlayerBox and condPlayerBox.EditBox and condPlayerBox.EditBox.SetText then
            condPlayerBox.EditBox:SetText("")
        end
        if charsGhost and condPlayerBox and condPlayerBox.EditBox then
            UpdateGhost(condPlayerBox.EditBox, charsGhost)
        end

        condSpellEB:SetText("")
        if body and body._fgoSetClassToken then
            body._fgoSetClassToken(nil)
        else
            SetDropDownSelected(condClassDD, nil, "Class")
            SetDropDownSelected(condSpecDD, nil, "Spec")
        end
        UpdateGhost(condSpellEB, spellGhost)

        local wantSpecID = nil
        local wantSpecName = nil

        local conds = w.conds
        if type(conds) == "table" then
            for _, c in ipairs(conds) do
                if c.type == "faction" then
                    -- handled below via GetFactionFromWidget
                elseif c.type == "combat" then
                    local v = tostring(c.value or "in")
                    if v == "out" then
                        w._uiCombatMode = "out"
                        combatBtn:SetText("No Combat")
                        SetBtnState(combatBtn, true, 1, 0.85, 0.1)
                    else
                        w._uiCombatMode = "in"
                        combatBtn:SetText("In Combat")
                        SetBtnState(combatBtn, true, 1, 0.2, 0.2)
                    end
                elseif c.type == "questCompleteHide" then
                    w._uiQuestHide = true
                    SetBtnState(questBtn, true)
                    condQuestEB:SetText(tostring(c.id or c.questID or c.qid or ""))
                    UpdateGhost(condQuestEB, questGhost)
                elseif c.type == "player" then
                    local list = {}
                    if type(c.list) == "table" then
                        for _, who in ipairs(c.list) do
                            list[#list + 1] = tostring(who)
                        end
                    elseif type(c.list) == "string" then
                        -- Back-compat: some saved data stores this as CSV/newlines.
                        list = ParseListText(c.list)
                    end
                    if condPlayerBox and condPlayerBox.EditBox and condPlayerBox.EditBox.SetText then
                        condPlayerBox.EditBox:SetText(table.concat(list, "\n"))
                        if charsGhost then
                            UpdateGhost(condPlayerBox.EditBox, charsGhost)
                        end
                    end
                elseif c.type == "spellOffCooldown" then
                    -- removed
                elseif c.type == "class" then
                    local v = Trim(c.value or c.class or "")
                    if v ~= "" then
                        if body and body._fgoSetClassToken then
                            body._fgoSetClassToken(v)
                        else
                            SetDropDownSelected(condClassDD, v, v)
                        end
                    end
                elseif c.type == "spec" then
                    wantSpecID = tonumber(c.id or c.specID)
                    wantSpecName = Trim(c.name or c.value or c.specName or "")
                end
            end
        end

        if wantSpecID then
            -- If spec is set but class isn't, try to infer the class.
            local curClass = GetDropDownSelected(condClassDD)
            if (curClass == nil or curClass == "") and body and body._fgoFindClassTokenForSpecID then
                local inferred = body._fgoFindClassTokenForSpecID(wantSpecID)
                if inferred and body._fgoSetClassToken then
                    body._fgoSetClassToken(inferred)
                end
            end
            if body and body._fgoSetSpecSelection then
                body._fgoSetSpecSelection(wantSpecID)
            else
                SetDropDownSelected(condSpecDD, wantSpecID, tostring(wantSpecID))
            end
        elseif wantSpecName ~= "" then
            -- Legacy: spec condition saved by name; best-effort resolve to an ID.
            local items = condSpecDD and condSpecDD._fgoSpecItems
            if type(items) == "table" then
                for _, it in ipairs(items) do
                    if tostring(it.name or ""):lower() == wantSpecName:lower() then
                        if body and body._fgoSetSpecSelection then
                            body._fgoSetSpecSelection(it.id)
                        else
                            SetDropDownSelected(condSpecDD, it.id, tostring(it.name or it.id))
                        end
                        break
                    end
                end
            end
        end

        do
            local fval = GetFactionFromWidget(w)
            if fval == "Alliance" or fval == "Horde" then
                SetDropDownSelected(factionDD, fval, fval)
            else
                SetDropDownSelected(factionDD, "Faction", "Faction")
            end
        end

        UpdateGhost(texEB, texGhost)
        uiSuppress = false
    end

    local function RefreshWidgetList()
        db = ns.Textures.EnsureDB()
        local keys = SortedWidgetKeys(db)

        UIDropDownMenu_Initialize(widgetDD, function(_, level)
            local info = UIDropDownMenu_CreateInfo()
            info.func = function(self)
                local k = self.value
                SelectWidgetKey(k)
            end

            info.text = "(select widget)"
            info.value = nil
            UIDropDownMenu_AddButton(info, level)

            for _, k in ipairs(keys) do
                info.text = k
                info.value = k
                UIDropDownMenu_AddButton(info, level)
            end
        end)

        if selectedKey and not (db.widgets and db.widgets[selectedKey]) then
            selectedKey = nil
        end
        if not selectedKey and keys[1] then
            selectedKey = keys[1]
        end
        SelectWidgetKey(selectedKey)
    end

    -- ArtLayer parity: New prompts for widget key name
    local function EnsureCreateWidgetDialog()
        if type(StaticPopupDialogs) ~= "table" then return end
        if StaticPopupDialogs["FGO_TEXTURES_CREATE_WIDGET"] then return end

        StaticPopupDialogs["FGO_TEXTURES_CREATE_WIDGET"] = {
            text = "Create widget key (texture widget).",
            button1 = "Create",
            button2 = "Cancel",
            hasEditBox = true,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            OnAccept = function(self)
                local eb = self.editBox or self.EditBox
                if not (eb and eb.GetText) then return end
                local key = Trim(eb:GetText() or "")
                if key == "" then
                    Print("Invalid key")
                    return
                end

                db = ns.Textures.EnsureDB()
                db.widgets = db.widgets or {}
                db.widgets[key] = db.widgets[key] or {}
                local w = db.widgets[key]

                w.type = w.type or "texture"
                if w.enabled == nil then w.enabled = true end
                if w.clickthrough == nil then w.clickthrough = true end
                w.texture = w.texture or ""
                w.w = w.w or 128
                w.h = w.h or 128
                w.point = w.point or "CENTER"
                w.x = w.x or 0
                w.y = w.y or 0
                w.alpha = w.alpha or 1
                w.scale = w.scale or 1
                w.zoom = w.zoom or 1
                w.layer = w.layer or "ARTWORK"
                w.sub = w.sub or 0
                w.blend = w.blend or "BLEND"
                w.conds = w.conds or {}

                if ns.Textures.ApplyWidget then ns.Textures.ApplyWidget(key) end
                RefreshWidgetList()
                SelectWidgetKey(key)
            end,
            EditBoxOnEnterPressed = function(self)
                local parent = self:GetParent()
                local b1 = parent and (parent.button1 or parent.Button1)
                if b1 and b1.Click then b1:Click() end
            end,
            OnShow = function(self)
                local eb = self.editBox or self.EditBox
                if eb and eb.SetText then eb:SetText("") end
                if eb and eb.SetFocus then eb:SetFocus() end
            end,
        }
    end

    EnsureCreateWidgetDialog()

    do
        local items = { "(default)", "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP" }
        UIDropDownMenu_Initialize(strataDD, function(_, level)
            for _, s in ipairs(items) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = s
                info.func = function()
                    SetDropDownText(strataDD, s)
                    if selectedKey then ReadUIIntoWidget(selectedKey) end
                end
                UIDropDownMenu_AddButton(info, level)
            end
        end)
        SetDropDownText(strataDD, "(default)")
    end

    do
        local items = { "BACKGROUND", "BORDER", "ARTWORK", "OVERLAY", "HIGHLIGHT" }
        UIDropDownMenu_Initialize(layerDD, function(_, level)
            for _, s in ipairs(items) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = s
                info.func = function()
                    SetDropDownText(layerDD, s)
                    if selectedKey then ReadUIIntoWidget(selectedKey) end
                end
                UIDropDownMenu_AddButton(info, level)
            end
        end)
        SetDropDownText(layerDD, "ARTWORK")
    end

    do
        local items = { "BLEND", "ADD", "MOD", "ALPHAKEY" }
        UIDropDownMenu_Initialize(blendDD, function(_, level)
            for _, s in ipairs(items) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = s
                info.func = function()
                    SetDropDownText(blendDD, s)
                    if selectedKey then ReadUIIntoWidget(selectedKey) end
                end
                UIDropDownMenu_AddButton(info, level)
            end
        end)
        SetDropDownText(blendDD, "BLEND")
    end

    do
        local items = { "Faction", "Alliance", "Horde" }
        UIDropDownMenu_Initialize(factionDD, function(_, level)
            for _, s in ipairs(items) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = s
                info.value = s
                info.checked = function()
                    return GetDropDownSelected(factionDD) == s
                end
                info.func = function(self)
                    SetDropDownSelected(factionDD, s, s)
                    if selectedKey then ReadUIIntoWidget(selectedKey) end
                end
                UIDropDownMenu_AddButton(info, level)
            end
        end)
        SetDropDownSelected(factionDD, "Faction", "Faction")
    end

    -- Class/Spec dropdowns (moved under Quest; Spec list depends on Class)
    local classIDByToken = nil
    local function EnsureClassIDByToken()
        if classIDByToken ~= nil then return end
        classIDByToken = {}
        if type(GetClassInfo) == "function" then
            for classID = 1, 30 do
                local ok, className, classFile = pcall(GetClassInfo, classID)
                if ok and classFile then
                    classIDByToken[tostring(classFile)] = tonumber(classID)
                end
            end
        end
    end

    local localizedClassToToken = nil
    local function EnsureLocalizedClassLookup()
        if localizedClassToToken ~= nil then return end
        localizedClassToToken = {}
        local function AddLookup(tbl)
            if type(tbl) ~= "table" then return end
            for token, name in pairs(tbl) do
                token = tostring(token or "")
                name = tostring(name or "")
                if token ~= "" and name ~= "" then
                    localizedClassToToken[name:lower()] = token
                end
            end
        end
        AddLookup(_G.LOCALIZED_CLASS_NAMES_MALE)
        AddLookup(_G.LOCALIZED_CLASS_NAMES_FEMALE)
    end

    local function ClassDisplayName(token)
        token = tostring(token or "")
        if token == "" then return "Class" end
        if type(_G.LOCALIZED_CLASS_NAMES_MALE) == "table" and _G.LOCALIZED_CLASS_NAMES_MALE[token] then
            return tostring(_G.LOCALIZED_CLASS_NAMES_MALE[token])
        end
        if type(_G.LOCALIZED_CLASS_NAMES_FEMALE) == "table" and _G.LOCALIZED_CLASS_NAMES_FEMALE[token] then
            return tostring(_G.LOCALIZED_CLASS_NAMES_FEMALE[token])
        end
        return token
    end

    local function NormalizeClassToken(text)
        text = Trim(tostring(text or ""))
        if text == "" or text == "Class" then return nil end
        EnsureClassIDByToken()
        EnsureLocalizedClassLookup()

        local upper = text:upper()
        if classIDByToken and classIDByToken[upper] then
            return upper
        end
        if localizedClassToToken then
            return localizedClassToToken[text:lower()]
        end
        return nil
    end

    local function BuildSpecItemsForClassToken(token)
        token = tostring(token or "")
        if token == "" then return {} end

        EnsureClassIDByToken()
        local classID = classIDByToken and classIDByToken[token]
        if not classID then return {} end
        if type(GetNumSpecializationsForClassID) ~= "function" or type(GetSpecializationInfoForClassID) ~= "function" then
            return {}
        end

        local out = {}
        local n = GetNumSpecializationsForClassID(classID)
        n = tonumber(n) or 0
        for i = 1, n do
            local specID, specName = GetSpecializationInfoForClassID(classID, i)
            if specID and specName then
                out[#out + 1] = { id = tonumber(specID), name = tostring(specName) }
            end
        end
        return out
    end

    local function FindClassTokenForSpecID(specID)
        specID = tonumber(specID)
        if not specID then return nil end
        EnsureClassIDByToken()
        if not classIDByToken then return nil end
        if type(GetNumSpecializationsForClassID) ~= "function" or type(GetSpecializationInfoForClassID) ~= "function" then
            return nil
        end
        for token, classID in pairs(classIDByToken) do
            local n = tonumber(GetNumSpecializationsForClassID(classID) or 0) or 0
            for i = 1, n do
                local sid = GetSpecializationInfoForClassID(classID, i)
                if tonumber(sid) == specID then
                    return token
                end
            end
        end
        return nil
    end

    local function SetClassToken(token)
        token = NormalizeClassToken(token) or nil
        if token then
            SetDropDownSelected(condClassDD, token, ClassDisplayName(token))
        else
            SetDropDownSelected(condClassDD, nil, "Class")
        end
        condSpecDD._fgoSpecItems = BuildSpecItemsForClassToken(token)
        SetDropDownSelected(condSpecDD, nil, "Spec")
    end

    local function SetSpecSelection(specID)
        specID = tonumber(specID)
        if not specID then
            SetDropDownSelected(condSpecDD, nil, "Spec")
            return
        end
        local items = condSpecDD._fgoSpecItems
        if type(items) == "table" then
            for _, it in ipairs(items) do
                if tonumber(it.id) == specID then
                    SetDropDownSelected(condSpecDD, specID, tostring(it.name or specID))
                    return
                end
            end
        end
        SetDropDownSelected(condSpecDD, specID, tostring(specID))
    end

    if UIDropDownMenu_Initialize then
        UIDropDownMenu_Initialize(condClassDD, function(_, level)
            local info = UIDropDownMenu_CreateInfo()
            info.notCheckable = true

            info.text = "(any)"
            info.func = function()
                SetClassToken(nil)
                if selectedKey then ReadUIIntoWidget(selectedKey) end
            end
            UIDropDownMenu_AddButton(info, level)

            local tokens = _G.CLASS_SORT_ORDER
            if type(tokens) ~= "table" then
                tokens = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK", "MONK", "DRUID", "DEMONHUNTER", "EVOKER" }
            end
            for _, token in ipairs(tokens) do
                token = tostring(token or "")
                if token ~= "" then
                    local txt = ClassDisplayName(token)
                    info.text = txt
                    info.func = function()
                        SetClassToken(token)
                        if selectedKey then ReadUIIntoWidget(selectedKey) end
                    end
                    UIDropDownMenu_AddButton(info, level)
                end
            end
        end)

        UIDropDownMenu_Initialize(condSpecDD, function(_, level)
            local info = UIDropDownMenu_CreateInfo()
            info.notCheckable = true

            info.text = "(any)"
            info.func = function()
                SetSpecSelection(nil)
                if selectedKey then ReadUIIntoWidget(selectedKey) end
            end
            UIDropDownMenu_AddButton(info, level)

            local items = condSpecDD._fgoSpecItems
            if type(items) == "table" then
                for _, it in ipairs(items) do
                    info.text = tostring(it.name or it.id)
                    info.func = function()
                        SetSpecSelection(it.id)
                        if selectedKey then ReadUIIntoWidget(selectedKey) end
                    end
                    UIDropDownMenu_AddButton(info, level)
                end
            end
        end)
    end

    -- expose for WriteWidgetIntoUI
    body._fgoSetClassToken = SetClassToken
    body._fgoSetSpecSelection = SetSpecSelection
    body._fgoFindClassTokenForSpecID = FindClassTokenForSpecID
    body._fgoNormalizeClassToken = NormalizeClassToken
    body._fgoBuildSpecItemsForClassToken = BuildSpecItemsForClassToken

    local function SetTexturePath(path)
        texEB:SetText(tostring(path or ""))
        UpdateGhost(texEB, texGhost)
        if selectedKey then
            ReadUIIntoWidget(selectedKey)
        end
    end

    if spellIconBtn and spellIconBtn.SetScript then
        spellIconBtn:SetScript("OnClick", function()
            local spellID = tonumber(Trim(condSpellEB and condSpellEB.GetText and condSpellEB:GetText() or ""))
            if not spellID then return end

            local icon
            if C_Spell and C_Spell.GetSpellTexture then
                icon = C_Spell.GetSpellTexture(spellID)
            end
            if icon == nil and GetSpellTexture then
                icon = GetSpellTexture(spellID)
            end

            if icon ~= nil then
                SetTexMode("fileid", false)
                SetTexturePath(icon)
            end
        end)
    end

    local function TryRenameSelected(desired)
        if uiSuppress then return end
        if not selectedKey then return end

        desired = Trim(desired)
        if desired == "" or desired == selectedKey then
            if nameEB and nameEB.SetText then
                nameEB:SetText(tostring(selectedKey or ""))
                UpdateGhost(nameEB, nameGhost)
            end
            return
        end

        db = ns.Textures.EnsureDB()
        if not (db and db.widgets and db.widgets[selectedKey]) then return end

        if db.widgets[desired] then
            if nameEB and nameEB.SetText then
                nameEB:SetText(tostring(selectedKey or ""))
                UpdateGhost(nameEB, nameGhost)
            end
            Print("Widget name already exists")
            return
        end

        local fn = ns.Textures.RenameWidgetKey
        if type(fn) ~= "function" then
            return
        end

        local newKey = fn(selectedKey, desired)
        if not newKey then
            if nameEB and nameEB.SetText then
                nameEB:SetText(tostring(selectedKey or ""))
                UpdateGhost(nameEB, nameGhost)
            end
            return
        end

        if dragKey == selectedKey then
            dragKey = newKey
        end

        RefreshWidgetList()
        SelectWidgetKey(newKey)
    end

    local function ShowMenu(btn, menu)
        body._texMenuFrame = body._texMenuFrame or CreateFrame("Frame", "FGO_Textures_TexMenu", UIParent, "UIDropDownMenuTemplate")
        local mf = body._texMenuFrame

        if EasyMenu then
            EasyMenu(menu, mf, btn, 0, 0, "MENU")
            return
        end

        if UIDropDownMenu_Initialize and ToggleDropDownMenu and UIDropDownMenu_AddButton and UIDropDownMenu_CreateInfo then
            UIDropDownMenu_Initialize(mf, function(_, level)
                for _, it in ipairs(menu) do
                    local info = UIDropDownMenu_CreateInfo()
                    info.text = it.text
                    info.isTitle = it.isTitle
                    info.notCheckable = (it.notCheckable ~= false)
                    info.func = it.func
                    info.disabled = it.disabled
                    UIDropDownMenu_AddButton(info, level)
                end
            end, "MENU")
            ToggleDropDownMenu(1, nil, mf, btn, 0, 0)
        end
    end

    texPickBtn:SetScript("OnClick", function(btn)

        local presets = {
            { "Solid (WHITE8X8)", "Interface\\Buttons\\WHITE8X8" },
            { "Soft Glow", "Interface\\Buttons\\UI-Quickslot2" },
            { "Dialog BG", "Interface\\DialogFrame\\UI-DialogBox-Background" },
            { "Tooltip BG", "Interface\\Tooltips\\UI-Tooltip-Background" },
            { "Circle (TargetingFrame)", "Interface\\TargetingFrame\\UI-StatusBar" },
            { "Raid Icon Star", "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1" },
            { "Raid Icon Circle", "Interface\\TargetingFrame\\UI-RaidTargetingIcon_2" },
            { "Raid Icon Diamond", "Interface\\TargetingFrame\\UI-RaidTargetingIcon_3" },
            { "Raid Icon Triangle", "Interface\\TargetingFrame\\UI-RaidTargetingIcon_4" },
        }

        local menu = {
            { text = "Texture Presets", isTitle = true, notCheckable = true },
            { text = "(clear)", notCheckable = true, func = function() SetTexturePath("") end },
        }
        for _, p in ipairs(presets) do
            menu[#menu + 1] = { text = p[1], notCheckable = true, func = function() SetTexturePath(p[2]) end }
        end

        local media = ns.TexturesMediaTextures
        if type(media) == "table" and media[1] then
            menu[#menu + 1] = { text = "Addon Media (.tga)", isTitle = true, notCheckable = true }
            for _, it in ipairs(media) do
                if type(it) == "table" then
                    local label = tostring(it[1] or "")
                    local value = tostring(it[2] or "")
                    if label ~= "" and value ~= "" then
                        menu[#menu + 1] = { text = label, notCheckable = true, func = function() SetTexturePath(value) end }
                    end
                end
            end
        end

        ShowMenu(btn, menu)
    end)

    local function CreateUniqueKey(base)
        base = Trim(base)
        if base == "" then base = "texture" end
        db = ns.Textures.EnsureDB()
        if not (db and db.widgets) then return base end
        if not db.widgets[base] then return base end
        for i = 2, 999 do
            local k = base .. tostring(i)
            if not db.widgets[k] then return k end
        end
        return base .. tostring(math.random(1000, 9999))
    end

    newBtn:SetScript("OnClick", function()
        if StaticPopup_Show then
            StaticPopup_Show("FGO_TEXTURES_CREATE_WIDGET")
            return
        end

        -- Fallback (no StaticPopup available): create a unique key.
        local k = CreateUniqueKey("texture")
        db = ns.Textures.EnsureDB()
        db.widgets[k] = db.widgets[k] or {}
        local w = db.widgets[k]
        w.type = w.type or "texture"
        if w.enabled == nil then w.enabled = true end
        if w.clickthrough == nil then w.clickthrough = true end
        w.texture = w.texture or ""
        w.w = w.w or 128
        w.h = w.h or 128
        w.point = w.point or "CENTER"
        w.x = w.x or 0
        w.y = w.y or 0
        w.alpha = w.alpha or 1
        w.scale = w.scale or 1
        w.zoom = w.zoom or 1
        w.layer = w.layer or "ARTWORK"
        w.sub = w.sub or 0
        w.blend = w.blend or "BLEND"
        w.conds = w.conds or {}

        if ns.Textures.ApplyWidget then ns.Textures.ApplyWidget(k) end
        RefreshWidgetList()
        SelectWidgetKey(k)
    end)

    delBtn:SetScript("OnClick", function()
        if not selectedKey then return end
        db = ns.Textures.EnsureDB()
        if db and db.widgets then
            db.widgets[selectedKey] = nil
        end
        if ns.Textures.RemoveWidgetFrame then
            ns.Textures.RemoveWidgetFrame(selectedKey)
        end
        selectedKey = nil
        if ns.Textures.ApplyAllWidgets then ns.Textures.ApplyAllWidgets() end
        RefreshWidgetList()
    end)

    refreshBtn:SetScript("OnClick", function()
        if ns.Textures.ApplyAllWidgets then
            ns.Textures.ApplyAllWidgets()
        end
        RefreshWidgetList()
        Print("Textures refreshed")
    end)

    if nameEB and nameEB.SetScript then
        nameEB:SetScript("OnEnterPressed", function(self)
            self:ClearFocus()
            TryRenameSelected(self:GetText())
        end)
        nameEB:SetScript("OnEditFocusLost", function(self)
            TryRenameSelected(self:GetText())
        end)
        nameEB:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
            if selectedKey and self.SetText then
                self:SetText(tostring(selectedKey))
                UpdateGhost(self, nameGhost)
            end
        end)
        if nameEB.HookScript then
            nameEB:HookScript("OnTextChanged", function() UpdateGhost(nameEB, nameGhost) end)
            nameEB:HookScript("OnEditFocusGained", function() UpdateGhost(nameEB, nameGhost) end)
            nameEB:HookScript("OnEditFocusLost", function() UpdateGhost(nameEB, nameGhost) end)
        end
    end

    local function HookChange(obj, fn)
        if obj and obj.SetScript then
            obj:SetScript("OnTextChanged", fn)
        end
    end

    local OnAnyChange

    local function EBApply(eb)
        if not (eb and eb.SetScript) then return end
        eb:SetScript("OnEnterPressed", function(self)
            self:ClearFocus()
            if OnAnyChange then OnAnyChange() end
        end)
        eb:SetScript("OnEditFocusLost", function()
            if OnAnyChange then OnAnyChange() end
        end)
        eb:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
            WriteWidgetIntoUI(selectedKey)
        end)
    end

    OnAnyChange = function()
        if uiSuppress then
            return
        end
        if selectedKey then
            ReadUIIntoWidget(selectedKey)
        end
    end

    local function GetWidgetOrNil()
        return GetWidget()
    end

    enabledBtn:SetScript("OnClick", function()
        local w = GetWidgetOrNil()
        if type(w) ~= "table" then return end
        w._uiEnabled = not (w._uiEnabled == true)
        SetBtnState(enabledBtn, w._uiEnabled, nil, nil, nil, nil, nil, nil, "Widget ON", "Widget OFF")
        OnAnyChange()
    end)

    clickBtn:SetScript("OnClick", function()
        local w = GetWidgetOrNil()
        if type(w) ~= "table" then return end
        w._uiClickthrough = not (w._uiClickthrough == true)
        SetBtnState(clickBtn, w._uiClickthrough, nil, nil, nil, nil, nil, nil, "Click ON", "Click OFF")
        OnAnyChange()
    end)

    unlockBtn:SetScript("OnClick", function()
        if not selectedKey then return end
        local w = GetWidgetOrNil()
        if type(w) ~= "table" then return end
        local now = not (dragKey == selectedKey)
        if now then
            EnableDragMode(selectedKey)
        else
            DisableDragMode()
        end
        SetBtnState(unlockBtn, now, nil, nil, nil, nil, nil, nil, "Unlock ON", "Unlock OFF")
        OnAnyChange()
    end)

    combatBtn:SetScript("OnClick", function()
        local w = GetWidgetOrNil()
        if type(w) ~= "table" then return end
        local cur = w._uiCombatMode
        if cur == nil then
            w._uiCombatMode = "in"
            combatBtn:SetText("In Combat")
            SetBtnState(combatBtn, true, 1, 0.2, 0.2)
        elseif cur == "in" then
            w._uiCombatMode = "out"
            combatBtn:SetText("No Combat")
            SetBtnState(combatBtn, true, 1, 0.85, 0.1)
        else
            w._uiCombatMode = nil
            combatBtn:SetText("Off")
            SetBtnState(combatBtn, false)
        end
        OnAnyChange()
    end)

    questBtn:SetScript("OnClick", function()
        local w = GetWidgetOrNil()
        if type(w) ~= "table" then return end
        w._uiQuestHide = not (w._uiQuestHide == true)
        SetBtnState(questBtn, w._uiQuestHide, nil, nil, nil, nil, nil, nil, "Quest ON", "Quest OFF")
        if w._uiQuestHide and condQuestEB and condQuestEB.SetFocus then
            condQuestEB:SetFocus()
        end
        OnAnyChange()
    end)

    alpha:SetScript("OnValueChanged", function(self, v)
        SetSliderValueLabel(self, v, "%.2f")
        OnAnyChange()
    end)
    scale:SetScript("OnValueChanged", function(self, v)
        SetSliderValueLabel(self, v, "%.2f")
        OnAnyChange()
    end)

    zoom:SetScript("OnValueChanged", function(self, v)
        SetSliderValueLabel(self, v, "%.2f")
        OnAnyChange()
    end)

    EBApply(wEB)
    EBApply(hEB)
    EBApply(pointEB)
    EBApply(xEB)
    EBApply(yEB)
    EBApply(subEB)
    EBApply(levelEB)
    EBApply(texEB)
    EBApply(condQuestEB)
    EBApply(condSpellEB)
    texEB:HookScript("OnTextChanged", function() UpdateGhost(texEB, texGhost) end)
    texEB:HookScript("OnEditFocusGained", function() UpdateGhost(texEB, texGhost) end)
    texEB:HookScript("OnEditFocusLost", function() UpdateGhost(texEB, texGhost) end)

    levelEB:HookScript("OnTextChanged", function() UpdateGhost(levelEB, levelGhost) end)
    levelEB:HookScript("OnEditFocusGained", function() UpdateGhost(levelEB, levelGhost) end)
    levelEB:HookScript("OnEditFocusLost", function() UpdateGhost(levelEB, levelGhost) end)

    condQuestEB:HookScript("OnTextChanged", function() UpdateGhost(condQuestEB, questGhost) end)
    condQuestEB:HookScript("OnEditFocusGained", function() UpdateGhost(condQuestEB, questGhost) end)
    condQuestEB:HookScript("OnEditFocusLost", function() UpdateGhost(condQuestEB, questGhost) end)

    condSpellEB:HookScript("OnTextChanged", function() UpdateGhost(condSpellEB, spellGhost) end)
    condSpellEB:HookScript("OnEditFocusGained", function() UpdateGhost(condSpellEB, spellGhost) end)
    condSpellEB:HookScript("OnEditFocusLost", function() UpdateGhost(condSpellEB, spellGhost) end)

    if condPlayerBox and condPlayerBox.EditBox then
        if charsGhost then
            condPlayerBox.EditBox:HookScript("OnTextChanged", function() UpdateGhost(condPlayerBox.EditBox, charsGhost) end)
            condPlayerBox.EditBox:HookScript("OnEditFocusGained", function() UpdateGhost(condPlayerBox.EditBox, charsGhost) end)
            condPlayerBox.EditBox:HookScript("OnEditFocusLost", function() UpdateGhost(condPlayerBox.EditBox, charsGhost) end)
        end
        if condPlayerBox.EditBox.HookScript then
            condPlayerBox.EditBox:HookScript("OnEditFocusLost", function() OnAnyChange() end)
            condPlayerBox.EditBox:HookScript("OnEscapePressed", function(self)
                self:ClearFocus()
                WriteWidgetIntoUI(selectedKey)
            end)
        else
            condPlayerBox.EditBox:SetScript("OnEditFocusLost", function() OnAnyChange() end)
            condPlayerBox.EditBox:SetScript("OnEscapePressed", function(self)
                self:ClearFocus()
                WriteWidgetIntoUI(selectedKey)
            end)
        end
    end

    RefreshWidgetList()
end
