---@diagnostic disable: undefined-global

local addonName, ns = ...
if type(ns) ~= "table" then ns = {} end

local LI = (ns and ns.LootIt) or {}
ns.LootIt = LI
fr0z3nUI_LootIt = LI
LI.ADDON = LI.ADDON or addonName

LI.Tax = LI.Tax or {}

do
  local Tax = LI.Tax
  local ui = rawget(Tax, "_ui") or {}
  local EnsureCharTaxDB = ui.EnsureCharTaxDB or function(...) return {} end
  local EnsureGuildTaxDB = ui.EnsureGuildTaxDB or function(...) return {} end
  local GetCurrentGuildKeyAndName = ui.GetCurrentGuildKeyAndName or function() return nil, nil end
  local AccrueBorrowedInterest = ui.AccrueBorrowedInterest or function(...) end
  local TryPayWarbank = ui.TryPayWarbank or function(...) end
  local Clamp = ui.Clamp or rawget(_G, "Clamp")
  if type(Clamp) ~= "function" then
    Clamp = function(v, mn, mx)
      v = tonumber(v)
      mn = tonumber(mn)
      mx = tonumber(mx)
      if not v then return mn end
      if mn and v < mn then return mn end
      if mx and v > mx then return mx end
      return v
    end
  end

  -- Tax tab UI builder (extracted from fUI_GOTax.lua)

  function Tax.BuildTab_UI(panel, env)
    if not panel then return end
    if panel._taxBuilt then return end
    panel._taxBuilt = true

    env = env or {}

    local EnsureDB = env.EnsureDB or function() end
    local GetDB = env.GetDB or function() return _G and rawget(_G, "fr0z3nUI_LootItDB") end

    local Refresh

    local clampFn = env.Clamp
    if type(clampFn) ~= "function" then
      clampFn = Clamp
    end

    local function HideEditBoxFrame(box)
      if not box or not box.GetRegions then return end
      for i = 1, select("#", box:GetRegions()) do
        local region = select(i, box:GetRegions())
        if region and region.Hide and region.GetObjectType and region:GetObjectType() == "Texture" then
          region:Hide()
        end
      end
    end

    local function SetFSSize(fs, size)
      if not (fs and fs.GetFont and fs.SetFont) then return end
      local font, _, flags = fs:GetFont()
      if type(font) ~= "string" or font == "" then
        font = "Fonts\\FRIZQT__.TTF"
      end
      fs:SetFont(font, size, flags)
    end

    -- Match FGO's standard in-frame Reload UI button size.
    local BTN_W, BTN_H = 90, 22
    local BTN_GAP = 12
    local GAP_Y = 14

    local GUILDNAME_H = 46

    -- Coin icon sizing/offsets (used for both EditBox and inline textures).
    -- Coin icon sizing/offsets (used for both EditBox and owed display textures).
    -- Larger text is allowed; do not reduce text size.
    local COIN_W, COIN_H = 16, 16
    local COIN_TEX_Y = -3
    local COIN_TEXT_SIZE_MIN = 18
    local COIN_TEXT_SIZE_OWED = 20

    local function SetFontStringSize(fs, size)
      if not (fs and fs.GetFont and fs.SetFont) then return end
      local font, _, flags = fs:GetFont()
      if type(font) ~= "string" or font == "" then
        font = "Fonts\\FRIZQT__.TTF"
      end
      fs:SetFont(font, size, flags)
    end

    local function FormatIntWithCommas(v)
      v = math.floor(tonumber(v) or 0)
      local sign = ""
      if v < 0 then
        sign = "-"
        v = -v
      end
      local s = tostring(v)
      while true do
        local newS, k = s:gsub("^(%d+)(%d%d%d)", "%1,%2")
        s = newS
        if k == 0 then break end
      end
      return sign .. s
    end

    -- Scope button (Guild / Character) - copies size/display style from Trade's main scope button.
    local scopeBtn = CreateFrame("Button", nil, panel)
    scopeBtn:SetSize(240, 28)
    scopeBtn:SetPoint("TOP", panel, "TOP", 0, -12)

    local scopeBtnHL = scopeBtn:CreateTexture(nil, "BACKGROUND")
    scopeBtnHL:SetAllPoints(scopeBtn)
    scopeBtnHL:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight2")
    scopeBtnHL:SetBlendMode("ADD")
    scopeBtnHL:SetVertexColor(0.55, 0.25, 0.85, 0.45)
    scopeBtnHL:Hide()

    local scopeBtnText = scopeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    scopeBtnText:SetPoint("CENTER", scopeBtn, "CENTER", 0, 0)
    SetFontStringSize(scopeBtnText, 16)

    -- Percent input (borderless)
    local rateEdit = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    rateEdit:SetSize(260, 32)
    -- Leave space for the guild name row between Scope and Rate.
    rateEdit:SetPoint("TOP", scopeBtn, "BOTTOM", 0, -(GUILDNAME_H + GAP_Y + 4))
    rateEdit:SetAutoFocus(false)
    rateEdit:SetMaxLetters(3)
    local RATE_INSET_L, RATE_INSET_R = 6, 18
    rateEdit:SetTextInsets(RATE_INSET_L, RATE_INSET_R, 0, 0)
    rateEdit:SetJustifyH("CENTER")
    if rateEdit.SetJustifyV then rateEdit:SetJustifyV("MIDDLE") end
    if rateEdit.SetNumeric then rateEdit:SetNumeric(true) end
    if rateEdit.GetFont and rateEdit.SetFont then
      local fontPath, _, fontFlags = rateEdit:GetFont()
      if fontPath then rateEdit:SetFont(fontPath, 20, fontFlags) end
    end
    HideEditBoxFrame(rateEdit)

    local ratePH = panel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    ratePH:SetPoint("CENTER", rateEdit, "CENTER", 0, 0)
    ratePH:SetText("Tax %")
    ratePH:SetTextColor(1, 1, 1, 0.35)

    local rateSuffix = rateEdit:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    rateSuffix:SetText("%")
    rateSuffix:SetTextColor(1, 1, 1, 0.95)
    SetFontStringSize(rateSuffix, 20)
    rateSuffix:Hide()

    local rateMeasure = rateEdit:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    rateMeasure:SetPoint("TOPLEFT", rateEdit, "TOPLEFT", -1000, 0)
    rateMeasure:SetAlpha(0)
    if rateEdit.GetFont and rateMeasure.SetFont then
      local fontPath, fontSize, fontFlags = rateEdit:GetFont()
      if fontPath then rateMeasure:SetFont(fontPath, fontSize or 18, fontFlags) end
    end

    local function GetGuildNameColor()
      local faction = UnitFactionGroup and UnitFactionGroup("player") or nil
      if faction == "Horde" then
        return 0.77, 0.12, 0.23
      elseif faction == "Alliance" then
        return 0.11, 0.39, 0.88
      end
      return 1, 1, 1
    end

    -- Detected guild name (two-line header) centered between Scope and Rate.
    local guildNameRow = CreateFrame("Frame", nil, panel)
    guildNameRow:SetPoint("TOP", scopeBtn, "BOTTOM", 0, 0)
    guildNameRow:SetPoint("BOTTOM", rateEdit, "TOP", 0, 0)
    guildNameRow:SetPoint("LEFT", panel, "LEFT", 0, 0)
    guildNameRow:SetPoint("RIGHT", panel, "RIGHT", 0, 0)

    local guildNameText = guildNameRow:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    guildNameText:SetPoint("CENTER", guildNameRow, "CENTER", 0, 12)
    guildNameText:SetJustifyH("CENTER")
    -- Match the old single-line behavior: keep guild name large and only shrink to fit.
    local guildNameFontPath, _, guildNameFontFlags
    if guildNameText.GetFont then
      guildNameFontPath, _, guildNameFontFlags = guildNameText:GetFont()
    end
    if type(guildNameFontPath) ~= "string" or guildNameFontPath == "" then
      guildNameFontPath = "Fonts\\FRIZQT__.TTF"
    end
    local GUILDNAME_FONT_MAX = 30
    local GUILDNAME_FONT_MIN = 10
    if guildNameText.SetFont then
      guildNameText:SetFont(guildNameFontPath, GUILDNAME_FONT_MAX, guildNameFontFlags)
    end

    local function FitGuildNameToRow()
      if not (guildNameText and guildNameText.SetFont and guildNameText.GetStringWidth and guildNameText.GetText) then return end
      if not (guildNameRow and guildNameRow.GetWidth) then return end

      local text = tostring(guildNameText:GetText() or "")
      if text == "" then
        guildNameText:SetFont(guildNameFontPath, GUILDNAME_FONT_MAX, guildNameFontFlags)
        return
      end

      local w = tonumber(guildNameRow:GetWidth() or 0) or 0
      local available = w - 24
      if available <= 0 then return end

      local size = GUILDNAME_FONT_MAX
      guildNameText:SetFont(guildNameFontPath, size, guildNameFontFlags)
      local textW = (guildNameText.GetStringWidth and guildNameText:GetStringWidth()) or 0
      if type(textW) ~= "number" then textW = 0 end

      while size > GUILDNAME_FONT_MIN and textW > available do
        size = size - 1
        guildNameText:SetFont(guildNameFontPath, size, guildNameFontFlags)
        textW = (guildNameText.GetStringWidth and guildNameText:GetStringWidth()) or 0
        if type(textW) ~= "number" then textW = 0 end
      end
    end

    if guildNameRow and guildNameRow.HookScript then
      guildNameRow:HookScript("OnSizeChanged", FitGuildNameToRow)
    end

    local guildRealmText = guildNameRow:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    guildRealmText:SetPoint("CENTER", guildNameRow, "CENTER", 0, -8)
    guildRealmText:SetJustifyH("CENTER")
    -- Realm line: match the small "button" text size.
    SetFontStringSize(guildRealmText, 16)

    local guildNamePH = guildNameRow:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    guildNamePH:SetPoint("CENTER", guildNameRow, "CENTER", 0, 0)
    guildNamePH:SetText("NO GUILD")
    guildNamePH:SetTextColor(1, 1, 1, 0.35)

    local function PlaceInlineSuffix(edit, measureFS, suffixFS, text, insetL, insetR, gap)
      if not (edit and measureFS and suffixFS and suffixFS.ClearAllPoints and suffixFS.SetPoint) then return end
      text = tostring(text or "")
      if text == "" then
        suffixFS:Hide()
        return
      end
      measureFS:SetText(text)
      local w = measureFS.GetStringWidth and measureFS:GetStringWidth() or 0
      if w < 0 then w = 0 end
      local centerOffset = ((tonumber(insetL) or 0) - (tonumber(insetR) or 0)) / 2
      suffixFS:ClearAllPoints()
      suffixFS:SetPoint("LEFT", edit, "CENTER", centerOffset + (w / 2) + (tonumber(gap) or 0), 0)
      suffixFS:Show()
    end

    local function UpdateRatePlaceholder()
      local txt = rateEdit:GetText() or ""
      local focused = rateEdit.HasFocus and rateEdit:HasFocus() or false
      ratePH:SetShown((txt == "") and (not focused))
      PlaceInlineSuffix(rateEdit, rateMeasure, rateSuffix, txt, RATE_INSET_L, RATE_INSET_R, 2)
    end
    rateEdit:SetScript("OnEditFocusGained", function() ratePH:Hide() end)
    rateEdit:SetScript("OnEditFocusLost", function() UpdateRatePlaceholder() end)

    -- Scope-scoped Min Gold (borderless), matching Trade tab input size/position.
    local minEdit = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    minEdit:SetSize(140, 38)
    minEdit:SetPoint("TOP", rateEdit, "BOTTOM", 0, -GAP_Y)
    minEdit:SetAutoFocus(false)
    minEdit:SetMaxLetters(10)
    local MIN_INSET_L, MIN_INSET_R = 6, 18
    minEdit:SetTextInsets(MIN_INSET_L, MIN_INSET_R, 0, 0)
    minEdit:SetJustifyH("CENTER")
    if minEdit.SetJustifyV then minEdit:SetJustifyV("MIDDLE") end
    if minEdit.SetNumeric then minEdit:SetNumeric(false) end
    if minEdit.EnableMouse then minEdit:EnableMouse(true) end
    if minEdit.SetTextColor then
      -- Match the gold used in the Due display (|cffffd100).
      minEdit:SetTextColor(1.0, 0.82, 0.0, 1)
    end
    if minEdit.GetFont and minEdit.SetFont then
      local fontPath, _, fontFlags = minEdit:GetFont()
      if fontPath then minEdit:SetFont(fontPath, COIN_TEXT_SIZE_MIN, fontFlags) end
    end
    HideEditBoxFrame(minEdit)

    local minPH = panel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    minPH:SetPoint("CENTER", minEdit, "CENTER", 0, 0)
    minPH:SetText("Min Gold")
    minPH:SetTextColor(1, 1, 1, 0.35)

    local minMeasure = minEdit:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    minMeasure:SetPoint("TOPLEFT", minEdit, "TOPLEFT", -1000, 0)
    minMeasure:SetAlpha(0)
    if minEdit.GetFont and minMeasure.SetFont then
      local fontPath, fontSize, fontFlags = minEdit:GetFont()
      if fontPath then minMeasure:SetFont(fontPath, fontSize or COIN_TEXT_SIZE_MIN, fontFlags) end
    end

    local minGoldIcon = minEdit:CreateTexture(nil, "OVERLAY")
    minGoldIcon:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
    minGoldIcon:SetSize(COIN_W, COIN_H)
    minGoldIcon:Hide()

    local function UpdateMinPlaceholder()
      local txt = minEdit:GetText() or ""
      local focused = minEdit.HasFocus and minEdit:HasFocus() or false
      minPH:SetShown((txt == "") and (not focused))
      local clean = txt:gsub("[^%d]", "")
      local v = tonumber(clean) or 0
      if v and v > 0 then
        minMeasure:SetText(txt)
        local w = minMeasure.GetStringWidth and minMeasure:GetStringWidth() or 0
        if w < 0 then w = 0 end
        local centerOffset = (MIN_INSET_L - MIN_INSET_R) / 2
        minGoldIcon:ClearAllPoints()
        -- Add a visible "space" before the icon, and keep it vertically centered on the text line.
        minGoldIcon:SetPoint("CENTER", minEdit, "CENTER", centerOffset + (w / 2) + 6 + (COIN_W / 2), 0)
        minGoldIcon:Show()
      else
        minGoldIcon:Hide()
      end
    end
    local function CreateOwedRow(parent, withHighlight)
      local row = CreateFrame("Frame", nil, parent)
      row:SetPoint("TOP", rateEdit, "BOTTOM", 0, -GAP_Y) -- final position set after sourcesRow exists
      row:SetSize(240, 28)

      local hl
      if withHighlight == true then
        hl = row:CreateTexture(nil, "BACKGROUND")
        hl:SetAllPoints(row)
        hl:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight2")
        hl:SetBlendMode("ADD")
        hl:SetVertexColor(0.55, 0.25, 0.85, 0.45)
        hl:Hide()
      end

      local goldFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
      local silverFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
      local copperFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
      SetFSSize(goldFS, COIN_TEXT_SIZE_OWED)
      SetFSSize(silverFS, COIN_TEXT_SIZE_OWED)
      SetFSSize(copperFS, COIN_TEXT_SIZE_OWED)
      goldFS:SetTextColor(1.0, 0.82, 0.0, 1)
      silverFS:SetTextColor(0.78, 0.78, 0.81, 1)
      copperFS:SetTextColor(0.93, 0.65, 0.37, 1)

      local goldIcon = row:CreateTexture(nil, "OVERLAY")
      goldIcon:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
      goldIcon:SetSize(COIN_W, COIN_H)

      local silverIcon = row:CreateTexture(nil, "OVERLAY")
      silverIcon:SetTexture("Interface\\MoneyFrame\\UI-SilverIcon")
      silverIcon:SetSize(COIN_W, COIN_H)

      local copperIcon = row:CreateTexture(nil, "OVERLAY")
      copperIcon:SetTexture("Interface\\MoneyFrame\\UI-CopperIcon")
      copperIcon:SetSize(COIN_W, COIN_H)

      local function Update(copper, showSilverCopper)
        copper = math.floor(tonumber(copper) or 0)
        if copper < 0 then copper = 0 end

        local g = math.floor(copper / (COPPER_PER_GOLD or 10000))
        local rem = copper - (g * (COPPER_PER_GOLD or 10000))
        local s = math.floor(rem / (COPPER_PER_SILVER or 100))
        local c = math.floor(rem - (s * (COPPER_PER_SILVER or 100)))

        goldFS:SetText(FormatIntWithCommas(g))
        silverFS:SetText(tostring(s))
        copperFS:SetText(tostring(c))

        local preIcon = 4
        local postCoin = 10

        goldFS:ClearAllPoints()
        goldIcon:ClearAllPoints()
        silverFS:ClearAllPoints()
        silverIcon:ClearAllPoints()
        copperFS:ClearAllPoints()
        copperIcon:ClearAllPoints()

        local wG = goldFS.GetStringWidth and goldFS:GetStringWidth() or 0
        if wG < 0 then wG = 0 end

        local availW = (row and row.GetWidth and row:GetWidth()) or 0
        if availW < 0 then availW = 0 end

        if showSilverCopper == true then
          silverFS:Show(); silverIcon:Show()
          copperFS:Show(); copperIcon:Show()

          local wS = silverFS.GetStringWidth and silverFS:GetStringWidth() or 0
          local wC = copperFS.GetStringWidth and copperFS:GetStringWidth() or 0
          if wS < 0 then wS = 0 end
          if wC < 0 then wC = 0 end

          local totalW = wG + preIcon + COIN_W + postCoin + wS + preIcon + COIN_W + postCoin + wC + preIcon + COIN_W
          if totalW < 10 then totalW = 10 end
          local startX = 0
          if availW > totalW then
            startX = (availW - totalW) / 2
          end

          goldFS:SetPoint("LEFT", row, "LEFT", startX, 0)
          goldIcon:SetPoint("CENTER", goldFS, "RIGHT", preIcon + (COIN_W / 2), 0)

          silverFS:SetPoint("LEFT", goldIcon, "RIGHT", postCoin, 0)
          silverIcon:SetPoint("CENTER", silverFS, "RIGHT", preIcon + (COIN_W / 2), 0)

          copperFS:SetPoint("LEFT", silverIcon, "RIGHT", postCoin, 0)
          copperIcon:SetPoint("CENTER", copperFS, "RIGHT", preIcon + (COIN_W / 2), 0)
        else
          silverFS:Hide(); silverIcon:Hide()
          copperFS:Hide(); copperIcon:Hide()

          local totalW = wG + preIcon + COIN_W
          if totalW < 10 then totalW = 10 end
          local startX = 0
          if availW > totalW then
            startX = (availW - totalW) / 2
          end

          goldFS:SetPoint("LEFT", row, "LEFT", startX, 0)
          goldIcon:SetPoint("CENTER", goldFS, "RIGHT", preIcon + (COIN_W / 2), 0)
        end
      end

      return row, hl, Update
    end

    local warOwedRow, _, UpdateWarOwedRow = CreateOwedRow(panel, false)
    local guildOwedRow, guildOwedRowHL, UpdateGuildOwedRow = CreateOwedRow(panel, true)

    local owedScopeBtn = CreateFrame("Button", nil, guildOwedRow)
    owedScopeBtn:SetAllPoints(guildOwedRow)
    owedScopeBtn:RegisterForClicks("LeftButtonUp")
    owedScopeBtn:SetScript("OnClick", function()
      EnsureDB()
      local ct = EnsureCharTaxDB()
      local scope = (ct and tostring(ct.scope or "guild"):lower()) or "guild"
      if scope ~= "guild" then
        Refresh()
        return
      end
      local guildKey = select(1, GetCurrentGuildKeyAndName())
      if not guildKey then
        Refresh()
        return
      end
      local g = EnsureGuildTaxDB(guildKey)
      if type(g) ~= "table" then
        Refresh()
        return
      end
      if g.owedScope == "characters" then
        g.owedScope = "character"
      else
        g.owedScope = "characters"
      end
      Refresh()

      -- If the tooltip is currently showing for this button, refresh it immediately.
      if owedScopeBtn and owedScopeBtn.GetScript and GameTooltip and GameTooltip.IsOwned then
        local owned = false
        pcall(function() owned = GameTooltip:IsOwned(owedScopeBtn) end)
        local over = (type(MouseIsOver) == "function") and MouseIsOver(owedScopeBtn) or false
        if owned or over then
          local onEnter = owedScopeBtn:GetScript("OnEnter")
          if type(onEnter) == "function" then
            pcall(onEnter, owedScopeBtn)
          end
        end
      end
    end)

    local function PlaceTooltipDownRightOfCursor()
      if not (GameTooltip and GameTooltip.ClearAllPoints and GameTooltip.SetPoint) then return end
      if not (UIParent and UIParent.GetEffectiveScale) then return end
      if type(GetCursorPosition) ~= "function" then return end

      local x, y = GetCursorPosition()
      local scale = UIParent:GetEffectiveScale() or 1
      if scale <= 0 then scale = 1 end
      x = (tonumber(x) or 0) / scale
      y = (tonumber(y) or 0) / scale

      GameTooltip:ClearAllPoints()
      GameTooltip:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x + 14, y - 14)
    end

    owedScopeBtn:SetScript("OnEnter", function(self)
      if not (GameTooltip and GameTooltip.SetOwner and GameTooltip.SetText) then return end

      if guildOwedRowHL then guildOwedRowHL:Show() end

      local ct = EnsureCharTaxDB()
      local scope = (ct and tostring(ct.scope or "guild"):lower()) or "guild"
      if scope ~= "guild" then return end

      local guildKey = select(1, GetCurrentGuildKeyAndName())
      if not guildKey then return end

      local g = EnsureGuildTaxDB(guildKey)
      if type(g) ~= "table" then return end

      local mode = tostring(g.owedScope or "character"):lower()
      local txt
      if mode == "characters" then
        txt = "Owed Scope: CHARACTERS OWE\nGuild Tax is owed by all characters per guild.\nClick to toggle."
      else
        txt = "Owed Scope: CHARACTER OWES\nGuild Tax is owed by only this character.\nClick to toggle."
      end

      GameTooltip:SetOwner(self, "ANCHOR_NONE")
      PlaceTooltipDownRightOfCursor()
      GameTooltip:SetText(txt)
      GameTooltip:Show()
    end)
    owedScopeBtn:SetScript("OnLeave", function()
      if guildOwedRowHL then guildOwedRowHL:Hide() end
      if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end
    end)
    minEdit:SetScript("OnEditFocusGained", function()
      minPH:Hide()
      local txt = minEdit:GetText() or ""
      local clean = txt:gsub("[^%d]", "")
      if clean ~= txt then
        minEdit:SetText(clean)
      end
    end)
    minEdit:SetScript("OnEditFocusLost", function()
      local txt = minEdit:GetText() or ""
      local clean = txt:gsub("[^%d]", "")
      local v = tonumber(clean) or 0
      if v > 0 then
        minEdit:SetText(FormatIntWithCommas(v))
      else
        minEdit:SetText("")
      end
      UpdateMinPlaceholder()
    end)
    minEdit:SetScript("OnEnter", function(self)
      if not (GameTooltip and GameTooltip.SetOwner and GameTooltip.SetText) then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText("Minimum gold to keep on the character.\n0 disables this feature.\nStored per-scope (Guild/Character).")
      GameTooltip:Show()
    end)
    minEdit:SetScript("OnLeave", function()
      if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end
    end)

    -- Toggle-as-text helpers
    local function SetToggleText(btn, label, on)
      if not (btn and btn._fs and btn._fs.SetText and btn._fs.SetTextColor) then return end
      btn._fs:SetText(label)
      if on then
        local c = rawget(_G, "GREEN_FONT_COLOR")
        if c and type(c.GetRGB) == "function" then
          local r, g, b = c:GetRGB()
          btn._fs:SetTextColor(r or 0.20, g or 1.00, b or 0.20, 1)
        elseif type(c) == "table" and c.r and c.g and c.b then
          btn._fs:SetTextColor(c.r, c.g, c.b, c.a or 1)
        else
          btn._fs:SetTextColor(0.20, 1.00, 0.20, 1)
        end
      else
        btn._fs:SetTextColor(0.55, 0.55, 0.55, 1)
      end
    end

    local function CreateTextToggleButton(parent)
      local b = CreateFrame("Button", nil, parent)
      b:SetSize(BTN_W, BTN_H)
      local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      fs:SetPoint("CENTER", b, "CENTER", 0, 0)
      b._fs = fs
      return b
    end

    local sourcesRow = CreateFrame("Frame", nil, panel)
    sourcesRow:SetPoint("TOP", rateEdit, "BOTTOM", 0, -GAP_Y)
    sourcesRow:SetSize(1, BTN_H)

    local vendorBtn = CreateTextToggleButton(sourcesRow)
    vendorBtn:SetPoint("LEFT", sourcesRow, "LEFT", 0, 0)

    local lootBtn = CreateTextToggleButton(sourcesRow)
    lootBtn:SetPoint("LEFT", vendorBtn, "RIGHT", 14, 0)

    local mailBtn = CreateTextToggleButton(sourcesRow)
    mailBtn:SetPoint("LEFT", lootBtn, "RIGHT", 14, 0)

    local systemBtn = CreateTextToggleButton(sourcesRow)
    systemBtn:SetPoint("LEFT", mailBtn, "RIGHT", 14, 0)

    -- Withdraw toggle (above System), default off.
    local withdrawBtn = CreateTextToggleButton(panel)
    withdrawBtn:SetPoint("BOTTOM", systemBtn, "TOP", 0, 0)

    -- Warbank toggle (left of Min Gold, opposite Withdraw).
    local warbankBtn = CreateTextToggleButton(panel)
    warbankBtn:SetPoint("BOTTOM", vendorBtn, "TOP", 0, 0)

    -- Warbank Everything-But-Min toggle (between WarBank and Min Gold; only shown when WarBank enabled).
    local warbankEBBtn = CreateTextToggleButton(panel)
    warbankEBBtn:SetPoint("RIGHT", minEdit, "LEFT", 0, 0)
    warbankEBBtn:Hide()

    warbankEBBtn:SetScript("OnEnter", function(self)
      if not (GameTooltip and GameTooltip.SetOwner and GameTooltip.SetText) then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText("Pays Excess to WarBank")
      GameTooltip:Show()
    end)
    warbankEBBtn:SetScript("OnLeave", function()
      if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end
    end)

    -- Clear Due buttons live below each owed amount.
    local clearWarBtn = CreateTextToggleButton(panel)
    local clearGuildBtn = CreateTextToggleButton(panel)

    local scBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    scBtn:SetSize(44, BTN_H)
    scBtn:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 0)
    scBtn:SetText("")

    local scSilver = scBtn:CreateTexture(nil, "ARTWORK")
    scSilver:SetTexture("Interface\\MoneyFrame\\UI-SilverIcon")
    scSilver:SetSize(COIN_W, COIN_H)
    scSilver:SetPoint("CENTER", scBtn, "CENTER", -(COIN_W / 2) - 2, COIN_TEX_Y)

    local scCopper = scBtn:CreateTexture(nil, "ARTWORK")
    scCopper:SetTexture("Interface\\MoneyFrame\\UI-CopperIcon")
    scCopper:SetSize(COIN_W, COIN_H)
    scCopper:SetPoint("CENTER", scBtn, "CENTER", (COIN_W / 2) + 2, COIN_TEX_Y)

    -- Initial layout; Refresh() finalizes positions.
    warOwedRow:ClearAllPoints()
    guildOwedRow:ClearAllPoints()
    warOwedRow:SetPoint("TOP", sourcesRow, "BOTTOM", 0, -GAP_Y)
    guildOwedRow:SetPoint("TOP", sourcesRow, "BOTTOM", 0, -GAP_Y)

    clearWarBtn:ClearAllPoints()
    clearGuildBtn:ClearAllPoints()
    clearWarBtn:SetPoint("TOP", warOwedRow, "BOTTOM", 0, -2)
    clearGuildBtn:SetPoint("TOP", guildOwedRow, "BOTTOM", 0, -2)

    minEdit:ClearAllPoints()
    -- Keep Min Gold centered even when the owed rows split left/right.
    minEdit:SetPoint("TOP", sourcesRow, "BOTTOM", 0, -(GAP_Y + 28 + 2 + BTN_H + GAP_Y))

    local reloadBtn = (env and env.reloadBtn) or nil
    if not reloadBtn then
      local parent = (panel and panel.GetParent) and panel:GetParent() or nil
      reloadBtn = parent and parent._reloadBtn or nil
    end

    -- Fallback (standalone Tax UI): create an in-panel reload button if the host didn't provide one.
    if not (reloadBtn and reloadBtn.SetScript and reloadBtn.SetText) then
      reloadBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
      reloadBtn:SetSize(BTN_W, BTN_H)
      reloadBtn:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)
      reloadBtn:SetText("Reload UI")
      reloadBtn:SetScript("OnClick", function()
        local r = _G and _G["ReloadUI"]
        if r then r() end
      end)
    end

    local SHORT_BTN_W = math.floor((tonumber(BTN_W) or 110) * 0.62)
    if SHORT_BTN_W < 54 then SHORT_BTN_W = 54 end
    if SHORT_BTN_W > (tonumber(BTN_W) or 110) then SHORT_BTN_W = (tonumber(BTN_W) or 110) end

    -- XS uses the same short-width sizing as Debug.
    if warbankEBBtn and warbankEBBtn.SetSize then
      warbankEBBtn:SetSize(SHORT_BTN_W, BTN_H)
    end

    -- Debug toggle (gates all non-deposit Tax prints) - move next to Reload UI and make it a real button.
    local debugBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    debugBtn:SetSize(SHORT_BTN_W, BTN_H)
    debugBtn:SetPoint("BOTTOMRIGHT", reloadBtn, "BOTTOMLEFT", -BTN_GAP, 0)
    debugBtn:SetText("Debug")
    debugBtn._fs = (debugBtn.GetFontString and debugBtn:GetFontString()) or nil
    if not debugBtn._fs then
      local fs = debugBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      fs:SetPoint("CENTER", debugBtn, "CENTER", 0, 0)
      debugBtn._fs = fs
    end

    -- Print toggle (gates bank move prints: deposit/withdraw).
    local bankPrintBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    bankPrintBtn:SetSize(SHORT_BTN_W, BTN_H)
    bankPrintBtn:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 0)
    bankPrintBtn:SetText("Print")
    bankPrintBtn._fs = (bankPrintBtn.GetFontString and bankPrintBtn:GetFontString()) or nil
    if not bankPrintBtn._fs then
      local fs = bankPrintBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      fs:SetPoint("CENTER", bankPrintBtn, "CENTER", 0, 0)
      bankPrintBtn._fs = fs
    end

    local manualBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    manualBtn:SetSize(SHORT_BTN_W, BTN_H)
    manualBtn:SetText("Manual")
    manualBtn._fs = (manualBtn.GetFontString and manualBtn:GetFontString()) or nil
    if not manualBtn._fs then
      local fs = manualBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      fs:SetPoint("CENTER", manualBtn, "CENTER", 0, 0)
      manualBtn._fs = fs
    end

    -- Move Debug + SC next to Print.
    debugBtn:ClearAllPoints()
    debugBtn:SetPoint("BOTTOMLEFT", bankPrintBtn, "BOTTOMRIGHT", BTN_GAP, 0)

    scBtn:ClearAllPoints()
    scBtn:SetPoint("BOTTOMLEFT", debugBtn, "BOTTOMRIGHT", BTN_GAP, 0)

    manualBtn:ClearAllPoints()
    manualBtn:SetPoint("TOP", minEdit, "BOTTOM", 0, -GAP_Y)

    panel:HookScript("OnHide", function() end)

    Refresh = function()
      EnsureDB()
      local db = GetDB()
      if type(db) ~= "table" then return end
      db.tax = (type(db.tax) == "table") and db.tax or {}

      local cdb = (env.GetCharDB and env.GetCharDB()) or (LI and type(LI.GetCharDB) == "function" and LI.GetCharDB()) or (_G and rawget(_G, "fr0z3nUI_LootItCharDB"))
      if type(cdb) ~= "table" then cdb = nil end
      cdb = cdb or {}
      cdb.tax = (type(cdb.tax) == "table") and cdb.tax or {}
      local ct = cdb.tax
      ct._guildCache = (type(ct._guildCache) == "table") and ct._guildCache or {}
      local cache = ct._guildCache

      local guildKey, guildName, guildRealm = GetCurrentGuildKeyAndName()
      if type(guildName) == "string" and guildName ~= "" then
        -- Cache per-character guild identity/display once it is known.
        do
          local changed = false
          if type(guildKey) == "string" and guildKey ~= "" and cache.key ~= guildKey then
            cache.key = guildKey
            changed = true
          end
          if cache.name ~= guildName then
            cache.name = guildName
            changed = true
          end
          if type(guildRealm) == "string" and guildRealm ~= "" and cache.realm ~= guildRealm then
            cache.realm = guildRealm
            changed = true
          end
          if changed then
            cache.updatedAt = (type(time) == "function") and time() or (cache.updatedAt or 0)
          end
        end

        guildNameText:SetText(string.upper(guildName))
        guildNameText:SetTextColor(GetGuildNameColor())
        guildNameText:Show()

        FitGuildNameToRow()

        local realmText
        if type(guildRealm) == "string" and guildRealm ~= "" then
          realmText = guildRealm
        elseif type(cache.realm) == "string" and cache.realm ~= "" and cache.name == guildName then
          realmText = cache.realm
        else
          realmText = "UNKNOWN"
        end
        guildRealmText:SetText(string.upper(realmText))
        guildRealmText:SetTextColor(GetGuildNameColor())
        guildRealmText:Show()

        guildNamePH:Hide()
      else
        guildNameText:SetText("")
        guildRealmText:SetText("")
        guildNameText:Hide()
        guildRealmText:Hide()
        guildNamePH:Show()
      end
      local scope = tostring(ct.scope or "guild"):lower()
      if scope ~= "guild" and scope ~= "character" then scope = "guild" end
      ct.scope = scope

      ct.cfg = (type(ct.cfg) == "table") and ct.cfg or {}
      ct.cfg.sources = (type(ct.cfg.sources) == "table") and ct.cfg.sources or {}
      ct.bal = (type(ct.bal) == "table") and ct.bal or {}
      ct.bal.due = math.floor(tonumber(ct.bal.due) or 0)
      ct.bal.paidToDate = math.floor(tonumber(ct.bal.paidToDate) or 0)
      if ct.bal.due < 0 then ct.bal.due = 0 end
      if ct.bal.paidToDate < 0 then ct.bal.paidToDate = 0 end

      -- Normalize split balances (per-character): normal tax due vs borrowed/withdrawn debt.
      if ct.bal.dueTax == nil and ct.bal.dueBorrowed == nil then
        ct.bal.dueTax = ct.bal.due
        ct.bal.dueBorrowed = 0
      end
      ct.bal.dueTax = math.floor(tonumber(ct.bal.dueTax) or 0)
      ct.bal.dueBorrowed = math.floor(tonumber(ct.bal.dueBorrowed) or 0)
      if ct.bal.dueTax < 0 then ct.bal.dueTax = 0 end
      if ct.bal.dueBorrowed < 0 then ct.bal.dueBorrowed = 0 end
      ct.bal.borrowedLastTS = math.floor(tonumber(ct.bal.borrowedLastTS) or 0)
      if ct.bal.borrowedLastTS < 0 then ct.bal.borrowedLastTS = 0 end
      ct.bal.due = ct.bal.dueTax + ct.bal.dueBorrowed
      if ct.bal.due < 0 then ct.bal.due = 0 end

      local cfg
      local bal
      if scope == "character" then
        cfg = ct.cfg
        bal = ct.bal
      else
        cfg = guildKey and EnsureGuildTaxDB(guildKey) or nil
        if type(cfg) == "table" and cfg.owedScope == "characters" then
          bal = cfg.sharedBal
        else
          bal = ct.bal
        end
      end

      if type(bal) == "table" then AccrueBorrowedInterest(bal) end

      -- If guild scope and no guild, treat cfg as disabled with defaults.
      local viewCfg = cfg
      local viewBal = bal
      if type(viewCfg) ~= "table" then
        viewCfg = {
          enabled = false,
          rate = 0,
          quiet = false,
          sources = { vendor = true, questLoot = true, systemMoney = false, mail = true },
          autoPayOnGuildBankOpen = true,
          minGold = 0,
          allowWithdraw = false,
          warBankEnabled = false,
          warBankEB = false,
        }
      end
      if type(viewBal) ~= "table" then
        viewBal = { due = 0, paidToDate = 0 }
      end

      viewCfg.sources = (type(viewCfg.sources) == "table") and viewCfg.sources or {}
      if viewCfg.sources.vendor == nil then viewCfg.sources.vendor = true end
      if viewCfg.sources.questLoot == nil then viewCfg.sources.questLoot = true end
      if viewCfg.sources.systemMoney == nil then viewCfg.sources.systemMoney = false end
      if viewCfg.sources.mail == nil then viewCfg.sources.mail = true end
      if viewCfg.autoPayOnGuildBankOpen == nil then viewCfg.autoPayOnGuildBankOpen = true end
      if viewCfg.minGold == nil then viewCfg.minGold = 0 end
      if viewCfg.allowWithdraw == nil then viewCfg.allowWithdraw = false end
      if viewCfg.warBankEnabled == nil then viewCfg.warBankEnabled = false end
      if viewCfg.warBankEB == nil then viewCfg.warBankEB = false end

      if viewCfg.bankPrintEnabled == nil then viewCfg.bankPrintEnabled = true end
      if viewCfg.manualBankMovesEnabled == nil then viewCfg.manualBankMovesEnabled = false end

      local rate = clampFn(viewCfg.rate, 0, 100) or 0
      viewCfg.rate = rate
      viewCfg.enabled = (rate > 0)

      -- Disable SCOPE-SCOPED config controls when in Guild scope but not currently in a guild.
      local cfgControlsEnabled = true
      if scope == "guild" and not guildKey then cfgControlsEnabled = false end

      -- Split balances: Clear Due only clears normal tax due (not borrowed/withdrawn debt).
      local viewDueTax = viewBal.dueTax
      if viewDueTax == nil then viewDueTax = viewBal.due end
      local dueTax = math.floor(tonumber(viewDueTax) or 0)
      local dueBorrowed = math.floor(tonumber(viewBal.dueBorrowed) or 0)
      if dueTax < 0 then dueTax = 0 end
      if dueBorrowed < 0 then dueBorrowed = 0 end
      local dueTotal = dueTax + dueBorrowed
      if dueTotal < 0 then dueTotal = 0 end

      local ct2 = EnsureCharTaxDB()
      local showSilverCopper
      if scope == "guild" then
        showSilverCopper = (type(cfg) == "table") and (cfg.showOwedSilverCopper == true) or false
      else
        showSilverCopper = (ct2 and ct2.showOwedSilverCopper == true)
      end

      -- Warbank balance is always character-only.
      local warBal = (type(ct2) == "table") and ct2.warBal or nil
      if type(warBal) ~= "table" then
        warBal = { dueTax = 0, dueBorrowed = 0, due = 0, paidToDate = 0 }
        if type(ct2) == "table" then ct2.warBal = warBal end
      end
      if warBal.dueTax == nil and warBal.dueBorrowed == nil then
        warBal.dueTax = warBal.due
        warBal.dueBorrowed = 0
      end
      local warDueTax = math.floor(tonumber(warBal.dueTax) or 0)
      local warDueBorrowed = math.floor(tonumber(warBal.dueBorrowed) or 0)
      if warDueTax < 0 then warDueTax = 0 end
      if warDueBorrowed < 0 then warDueBorrowed = 0 end
      local warDueTotal = warDueTax + warDueBorrowed
      if warDueTotal < 0 then warDueTotal = 0 end

      local showWarbank = (type(viewCfg) == "table") and (viewCfg.warBankEnabled == true)
      if showWarbank then
        if warOwedRow and warOwedRow.Show then warOwedRow:Show() end
        if clearWarBtn and clearWarBtn.Show then clearWarBtn:Show() end
        if warbankEBBtn and warbankEBBtn.Show then warbankEBBtn:Show() end
      else
        if warOwedRow and warOwedRow.Hide then warOwedRow:Hide() end
        if clearWarBtn and clearWarBtn.Hide then clearWarBtn:Hide() end
        if warbankEBBtn and warbankEBBtn.Hide then warbankEBBtn:Hide() end
      end

      if guildOwedRow and guildOwedRow.Show then guildOwedRow:Show() end
      if clearGuildBtn and clearGuildBtn.Show then clearGuildBtn:Show() end

      UpdateGuildOwedRow(dueTotal, showSilverCopper)
      UpdateWarOwedRow(warDueTotal, showSilverCopper)

      -- Enable owed-scope toggle only in Guild scope and while in a guild.
      if owedScopeBtn and owedScopeBtn.EnableMouse then
        owedScopeBtn:EnableMouse((scope == "guild") and (guildKey ~= nil))
      end

      if scSilver and scSilver.SetDesaturated and scSilver.SetAlpha then
        scSilver:SetDesaturated(not showSilverCopper)
        scSilver:SetAlpha(showSilverCopper and 1 or 0.35)
      end
      if scCopper and scCopper.SetDesaturated and scCopper.SetAlpha then
        scCopper:SetDesaturated(not showSilverCopper)
        scCopper:SetAlpha(showSilverCopper and 1 or 0.35)
      end

      if rateEdit and rateEdit.SetText then
        if rate <= 0 then
          if rateEdit.GetText and rateEdit:GetText() ~= "" then
            rateEdit:SetText("")
          end
        else
          local want = tostring(math.floor(rate))
          if rateEdit.GetText and rateEdit:GetText() ~= want then
            rateEdit:SetText(want)
          end
        end
        UpdateRatePlaceholder()
      end

      local minGold = (type(viewCfg) == "table") and (tonumber(viewCfg.minGold) or 0) or 0
      if minEdit and minEdit.SetText then
        local focused = minEdit.HasFocus and minEdit:HasFocus() or false
        if not focused then
          if minGold <= 0 then
            if minEdit.GetText and minEdit:GetText() ~= "" then
              minEdit:SetText("")
            end
          else
            local want = FormatIntWithCommas(math.floor(minGold))
            if minEdit.GetText and minEdit:GetText() ~= want then
              minEdit:SetText(want)
            end
          end
        end
        UpdateMinPlaceholder()
      end

      SetToggleText(vendorBtn, "Vendor", viewCfg.sources.vendor == true)
      SetToggleText(lootBtn, "Looted", viewCfg.sources.questLoot == true)
      SetToggleText(mailBtn, "Mail", viewCfg.sources.mail == true)
      SetToggleText(systemBtn, "System", viewCfg.sources.systemMoney == true)
      SetToggleText(withdrawBtn, "Withdraw", (type(viewCfg) == "table") and (viewCfg.allowWithdraw == true))
      SetToggleText(warbankBtn, "WarBank", (type(viewCfg) == "table") and (viewCfg.warBankEnabled == true))
      SetToggleText(warbankEBBtn, "XS", (type(viewCfg) == "table") and (viewCfg.warBankEB == true))
      SetToggleText(debugBtn, "Debug", (ct and ct.debug == true))
      SetToggleText(bankPrintBtn, "Print", (type(viewCfg) == "table") and (viewCfg.bankPrintEnabled == true))
      SetToggleText(manualBtn, "Manual", (type(viewCfg) == "table") and (viewCfg.manualBankMovesEnabled == true))

      -- Action button state
      SetToggleText(clearGuildBtn, "Guild Bank", (dueTax > 0))
      SetToggleText(clearWarBtn, "WarBank", (warDueTax > 0))

      -- Center the Vendor/Looted/Mail/System row after widths update.
      do
        local gap = 14
        local w1 = vendorBtn.GetWidth and vendorBtn:GetWidth() or 0
        local w2 = lootBtn.GetWidth and lootBtn:GetWidth() or 0
        local w3 = mailBtn.GetWidth and mailBtn:GetWidth() or 0
        local w4 = systemBtn.GetWidth and systemBtn:GetWidth() or 0
        local totalW = w1 + w2 + w3 + w4 + (gap * 3)
        if totalW < 10 then totalW = 10 end
        sourcesRow:SetWidth(totalW)
        vendorBtn:ClearAllPoints()
        lootBtn:ClearAllPoints()
        mailBtn:ClearAllPoints()
        systemBtn:ClearAllPoints()
        vendorBtn:SetPoint("LEFT", sourcesRow, "LEFT", 0, 0)
        lootBtn:SetPoint("LEFT", vendorBtn, "RIGHT", gap, 0)
        mailBtn:SetPoint("LEFT", lootBtn, "RIGHT", gap, 0)
        systemBtn:SetPoint("LEFT", mailBtn, "RIGHT", gap, 0)
      end

      -- Keep Min Gold centered under the (potentially split) Due section.
      do
        local owedH = (guildOwedRow and guildOwedRow.GetHeight and guildOwedRow:GetHeight()) or 28
        local y = -((tonumber(GAP_Y) or 0) + owedH + 2 + (tonumber(BTN_H) or 22) + (tonumber(GAP_Y) or 0))
        minEdit:ClearAllPoints()
        minEdit:SetPoint("TOP", sourcesRow, "BOTTOM", 0, y)
      end

      -- Place Withdraw aligned with the Min Gold input row, and horizontally aligned over System.
      do
        local pLeft = panel.GetLeft and panel:GetLeft() or nil
        local pBottom = panel.GetBottom and panel:GetBottom() or nil
        local sLeft = systemBtn.GetLeft and systemBtn:GetLeft() or nil
        local _, mY
        if minEdit and minEdit.GetCenter then
          _, mY = minEdit:GetCenter()
        end

        if pLeft and pBottom and sLeft and mY then
          withdrawBtn:ClearAllPoints()
          withdrawBtn:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", (sLeft - pLeft), (mY - pBottom) - (BTN_H / 2))
        else
          -- Fallback: above System.
          withdrawBtn:ClearAllPoints()
          withdrawBtn:SetPoint("BOTTOM", systemBtn, "TOP", 0, 0)
        end
      end

      -- Place WarBank aligned with the Min Gold input row, and horizontally aligned over Vendor.
      do
        local pLeft = panel.GetLeft and panel:GetLeft() or nil
        local pBottom = panel.GetBottom and panel:GetBottom() or nil
        local vLeft = vendorBtn.GetLeft and vendorBtn:GetLeft() or nil
        local _, mY
        if minEdit and minEdit.GetCenter then
          _, mY = minEdit:GetCenter()
        end

        if pLeft and pBottom and vLeft and mY then
          warbankBtn:ClearAllPoints()
          warbankBtn:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", (vLeft - pLeft), (mY - pBottom) - (BTN_H / 2))
        else
          -- Fallback: above Vendor.
          warbankBtn:ClearAllPoints()
          warbankBtn:SetPoint("BOTTOM", vendorBtn, "TOP", 0, 0)
        end
      end

      -- Place XS between the WarBank button and the Min Gold input (only when WarBank is enabled).
      do
        if showWarbank then
          warbankEBBtn:ClearAllPoints()
          -- Flush XS against the left edge of Min Gold.
          warbankEBBtn:SetPoint("RIGHT", minEdit, "LEFT", 0, 0)

          -- Keep XS between WarBank and Min Gold by shrinking to the available gap.
          if warbankEBBtn.SetWidth then
            local mL = minEdit.GetLeft and minEdit:GetLeft() or nil
            local wbR = warbankBtn.GetRight and warbankBtn:GetRight() or nil
            if mL and wbR then
              local maxW = tonumber(SHORT_BTN_W) or 54
              local gap = (mL - wbR) - 2
              if gap < 16 then gap = 16 end
              if gap < maxW then
                warbankEBBtn:SetWidth(gap)
              else
                warbankEBBtn:SetWidth(maxW)
              end
            else
              local maxW = tonumber(SHORT_BTN_W) or 54
              warbankEBBtn:SetWidth(maxW)
            end
          end
        end
      end

      -- Place owed rows below the source row (WarBank left / Guild right when enabled).
      do
        local srCX = (sourcesRow.GetCenter and select(1, sourcesRow:GetCenter())) or nil

        local function GetGapCenterX(a, b)
          if not (a and b) then return nil end
          local aR = a.GetRight and a:GetRight() or nil
          local bL = b.GetLeft and b:GetLeft() or nil
          if aR and bL then
            return (aR + bL) / 2
          end
          local aCX = a.GetCenter and select(1, a:GetCenter()) or nil
          local bCX = b.GetCenter and select(1, b:GetCenter()) or nil
          if aCX and bCX then
            return (aCX + bCX) / 2
          end
          return nil
        end

        warOwedRow:ClearAllPoints()
        guildOwedRow:ClearAllPoints()

        if showWarbank and srCX then
          local leftGapX = GetGapCenterX(vendorBtn, lootBtn)
          local rightGapX = GetGapCenterX(mailBtn, systemBtn)
          if leftGapX and rightGapX then
            warOwedRow:SetPoint("TOP", sourcesRow, "BOTTOM", (leftGapX - srCX), -GAP_Y)
            guildOwedRow:SetPoint("TOP", sourcesRow, "BOTTOM", (rightGapX - srCX), -GAP_Y)
          else
            warOwedRow:SetPoint("TOP", sourcesRow, "BOTTOM", 0, -GAP_Y)
            guildOwedRow:SetPoint("TOP", sourcesRow, "BOTTOM", 0, -GAP_Y)
          end
        else
          guildOwedRow:SetPoint("TOP", sourcesRow, "BOTTOM", 0, -GAP_Y)
        end

        clearGuildBtn:ClearAllPoints()
        clearGuildBtn:SetPoint("TOP", guildOwedRow, "BOTTOM", 0, -2)
        if showWarbank then
          clearWarBtn:ClearAllPoints()
          clearWarBtn:SetPoint("TOP", warOwedRow, "BOTTOM", 0, -2)
        end
      end

      -- Scope button UI
      scopeBtnText:SetText((scope == "character") and "CHARACTER" or "GUILD")
      if scopeBtnText and scopeBtnText.SetTextColor then
        scopeBtnText:SetTextColor(1.0, 0.82, 0.0, 1)
      end
      if rateEdit and rateEdit.SetEnabled then rateEdit:SetEnabled(cfgControlsEnabled) end
      if minEdit and minEdit.SetEnabled then minEdit:SetEnabled(cfgControlsEnabled) end
      if vendorBtn and vendorBtn.SetEnabled then vendorBtn:SetEnabled(cfgControlsEnabled) end
      if lootBtn and lootBtn.SetEnabled then lootBtn:SetEnabled(cfgControlsEnabled) end
      if mailBtn and mailBtn.SetEnabled then mailBtn:SetEnabled(cfgControlsEnabled) end
      if systemBtn and systemBtn.SetEnabled then systemBtn:SetEnabled(cfgControlsEnabled) end
      if withdrawBtn and withdrawBtn.SetEnabled then withdrawBtn:SetEnabled(cfgControlsEnabled) end
      if warbankBtn and warbankBtn.SetEnabled then warbankBtn:SetEnabled(cfgControlsEnabled) end
      if warbankEBBtn and warbankEBBtn.SetEnabled then warbankEBBtn:SetEnabled(cfgControlsEnabled and showWarbank) end
      if debugBtn and debugBtn.SetEnabled then debugBtn:SetEnabled(true) end
      if bankPrintBtn and bankPrintBtn.SetEnabled then bankPrintBtn:SetEnabled(cfgControlsEnabled) end
      if manualBtn and manualBtn.SetEnabled then manualBtn:SetEnabled(cfgControlsEnabled) end
      if clearGuildBtn and clearGuildBtn.SetEnabled then clearGuildBtn:SetEnabled(dueTax > 0) end
      if clearWarBtn and clearWarBtn.SetEnabled then clearWarBtn:SetEnabled(showWarbank and (warDueTax > 0)) end
    end

    -- Allow core logic to refresh the UI immediately after deposits.
    Tax._RefreshUI = Refresh

    scopeBtn:SetScript("OnClick", function()
      EnsureDB()
      local cdb = (env.GetCharDB and env.GetCharDB()) or (LI and type(LI.GetCharDB) == "function" and LI.GetCharDB()) or (_G and rawget(_G, "fr0z3nUI_LootItCharDB"))
      if type(cdb) ~= "table" then return end
      cdb.tax = (type(cdb.tax) == "table") and cdb.tax or {}
      local cur = tostring(cdb.tax.scope or "guild"):lower()
      local nextScope = (cur == "guild") and "character" or "guild"
      cdb.tax.scope = nextScope
      Refresh()

      -- Refresh the tooltip immediately if still hovering.
      if scopeBtn and scopeBtn.GetScript and GameTooltip and GameTooltip.IsOwned then
        local owned = false
        pcall(function() owned = GameTooltip:IsOwned(scopeBtn) end)
        local over = (type(MouseIsOver) == "function") and MouseIsOver(scopeBtn) or false
        if owned or over then
          local onEnter = scopeBtn:GetScript("OnEnter")
          if type(onEnter) == "function" then
            pcall(onEnter, scopeBtn)
          end
        end
      end
    end)

    scopeBtn:SetScript("OnEnter", function(self)
      if not (GameTooltip and GameTooltip.SetOwner and GameTooltip.SetText) then return end

      if scopeBtnHL then scopeBtnHL:Show() end

      local ct = EnsureCharTaxDB()
      local scope = (ct and tostring(ct.scope or "guild"):lower()) or "guild"
      if scope ~= "guild" and scope ~= "character" then scope = "guild" end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      if scope == "guild" then
        GameTooltip:SetText("Scope: GUILD\nEdits tax rate/sources/min/withdraw for the current guild.\nOwed amount can be toggled (Character Owes / Characters Owe), saved per guild.")
      else
        GameTooltip:SetText("Scope: CHARACTER\nEdits tax rate/sources/min/withdraw for this character only.\nOwed scope is locked to Character Owes.")
      end
      GameTooltip:Show()
    end)
    scopeBtn:SetScript("OnLeave", function()
      if scopeBtnHL then scopeBtnHL:Hide() end
      if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end
    end)

    rateEdit:SetScript("OnTextChanged", function(self)
      if self._cleaning == true then return end
      EnsureDB()
      local db = GetDB()
      if type(db) ~= "table" then return end
      db.tax = (type(db.tax) == "table") and db.tax or {}

      local cdb = (env.GetCharDB and env.GetCharDB()) or (LI and type(LI.GetCharDB) == "function" and LI.GetCharDB()) or (_G and rawget(_G, "fr0z3nUI_LootItCharDB"))
      if type(cdb) ~= "table" then cdb = nil end
      cdb = cdb or {}
      cdb.tax = (type(cdb.tax) == "table") and cdb.tax or {}
      cdb.tax.cfg = (type(cdb.tax.cfg) == "table") and cdb.tax.cfg or {}
      cdb.tax.scope = tostring(cdb.tax.scope or "guild"):lower()
      if cdb.tax.scope ~= "guild" and cdb.tax.scope ~= "character" then cdb.tax.scope = "guild" end

      local cfg
      if cdb.tax.scope == "character" then
        cfg = cdb.tax.cfg
      else
        local guildKey = select(1, GetCurrentGuildKeyAndName())
        if not guildKey then return end
        cfg = EnsureGuildTaxDB(guildKey)
        if not cfg then return end
      end

      local txt = self:GetText() or ""
      local clean = txt:gsub("%D+", "")
      if clean ~= txt then
        self._cleaning = true
        self:SetText(clean)
        self._cleaning = false
        txt = clean
      end

      local v = tonumber(txt)
      if not v then v = 0 end
      v = clampFn(v, 0, 100) or 0
      cfg.rate = v
      cfg.enabled = (v > 0)
      Refresh()
    end)

    minEdit:SetScript("OnTextChanged", function(self)
      EnsureDB()
      local cdb = (env.GetCharDB and env.GetCharDB()) or (LI and type(LI.GetCharDB) == "function" and LI.GetCharDB()) or (_G and rawget(_G, "fr0z3nUI_LootItCharDB"))
      if type(cdb) ~= "table" then cdb = nil end
      cdb = cdb or {}
      cdb.tax = (type(cdb.tax) == "table") and cdb.tax or {}
      cdb.tax.cfg = (type(cdb.tax.cfg) == "table") and cdb.tax.cfg or {}
      cdb.tax.scope = tostring(cdb.tax.scope or "guild"):lower()
      if cdb.tax.scope ~= "guild" and cdb.tax.scope ~= "character" then cdb.tax.scope = "guild" end

      local txt = self:GetText() or ""
      local clean = txt:gsub("[^%d]", "")
      if clean ~= txt and not (self._cleaning == true) and (self.HasFocus and self:HasFocus()) then
        self._cleaning = true
        self:SetText(clean)
        self._cleaning = false
        txt = clean
      end

      local v = tonumber(clean)
      if not v then v = 0 end
      v = clampFn(v, 0, 9999999) or 0

      local cfg
      if cdb.tax.scope == "character" then
        cfg = cdb.tax.cfg
      else
        local guildKey = select(1, GetCurrentGuildKeyAndName())
        if not guildKey then return end
        cfg = EnsureGuildTaxDB(guildKey)
        if not cfg then return end
      end

      cfg.minGold = v
      Refresh()
    end)

    vendorBtn:SetScript("OnClick", function()
      EnsureDB()
      local db = GetDB(); if type(db) ~= "table" then return end
      db.tax = (type(db.tax) == "table") and db.tax or {}

      local cdb = (env.GetCharDB and env.GetCharDB()) or (LI and type(LI.GetCharDB) == "function" and LI.GetCharDB()) or (_G and rawget(_G, "fr0z3nUI_LootItCharDB"))
      if type(cdb) ~= "table" then cdb = nil end
      cdb = cdb or {}
      cdb.tax = (type(cdb.tax) == "table") and cdb.tax or {}
      cdb.tax.cfg = (type(cdb.tax.cfg) == "table") and cdb.tax.cfg or {}
      cdb.tax.scope = tostring(cdb.tax.scope or "guild"):lower()
      if cdb.tax.scope ~= "guild" and cdb.tax.scope ~= "character" then cdb.tax.scope = "guild" end

      local cfg
      if cdb.tax.scope == "character" then
        cfg = cdb.tax.cfg
      else
        local guildKey = select(1, GetCurrentGuildKeyAndName())
        if not guildKey then return end
        cfg = EnsureGuildTaxDB(guildKey)
        if not cfg then return end
      end
      cfg.sources = (type(cfg.sources) == "table") and cfg.sources or {}
      cfg.sources.vendor = not (cfg.sources.vendor == true)
      Refresh()
    end)

    lootBtn:SetScript("OnClick", function()
      EnsureDB()
      local db = GetDB(); if type(db) ~= "table" then return end
      db.tax = (type(db.tax) == "table") and db.tax or {}

      local cdb = (env.GetCharDB and env.GetCharDB()) or (LI and type(LI.GetCharDB) == "function" and LI.GetCharDB()) or (_G and rawget(_G, "fr0z3nUI_LootItCharDB"))
      if type(cdb) ~= "table" then cdb = nil end
      cdb = cdb or {}
      cdb.tax = (type(cdb.tax) == "table") and cdb.tax or {}
      cdb.tax.cfg = (type(cdb.tax.cfg) == "table") and cdb.tax.cfg or {}
      cdb.tax.scope = tostring(cdb.tax.scope or "guild"):lower()
      if cdb.tax.scope ~= "guild" and cdb.tax.scope ~= "character" then cdb.tax.scope = "guild" end

      local cfg
      if cdb.tax.scope == "character" then
        cfg = cdb.tax.cfg
      else
        local guildKey = select(1, GetCurrentGuildKeyAndName())
        if not guildKey then return end
        cfg = EnsureGuildTaxDB(guildKey)
        if not cfg then return end
      end
      cfg.sources = (type(cfg.sources) == "table") and cfg.sources or {}
      cfg.sources.questLoot = not (cfg.sources.questLoot == true)
      Refresh()
    end)

    mailBtn:SetScript("OnClick", function()
      EnsureDB()
      local db = GetDB(); if type(db) ~= "table" then return end
      db.tax = (type(db.tax) == "table") and db.tax or {}

      local cdb = (env.GetCharDB and env.GetCharDB()) or (LI and type(LI.GetCharDB) == "function" and LI.GetCharDB()) or (_G and rawget(_G, "fr0z3nUI_LootItCharDB"))
      if type(cdb) ~= "table" then cdb = nil end
      cdb = cdb or {}
      cdb.tax = (type(cdb.tax) == "table") and cdb.tax or {}
      cdb.tax.cfg = (type(cdb.tax.cfg) == "table") and cdb.tax.cfg or {}
      cdb.tax.scope = tostring(cdb.tax.scope or "guild"):lower()
      if cdb.tax.scope ~= "guild" and cdb.tax.scope ~= "character" then cdb.tax.scope = "guild" end

      local cfg
      if cdb.tax.scope == "character" then
        cfg = cdb.tax.cfg
      else
        local guildKey = select(1, GetCurrentGuildKeyAndName())
        if not guildKey then return end
        cfg = EnsureGuildTaxDB(guildKey)
        if not cfg then return end
      end
      cfg.sources = (type(cfg.sources) == "table") and cfg.sources or {}
      cfg.sources.mail = not (cfg.sources.mail == true)
      Refresh()
    end)

    systemBtn:SetScript("OnClick", function()
      EnsureDB()
      local db = GetDB(); if type(db) ~= "table" then return end
      db.tax = (type(db.tax) == "table") and db.tax or {}

      local cdb = (env.GetCharDB and env.GetCharDB()) or (LI and type(LI.GetCharDB) == "function" and LI.GetCharDB()) or (_G and rawget(_G, "fr0z3nUI_LootItCharDB"))
      if type(cdb) ~= "table" then cdb = nil end
      cdb = cdb or {}
      cdb.tax = (type(cdb.tax) == "table") and cdb.tax or {}
      cdb.tax.cfg = (type(cdb.tax.cfg) == "table") and cdb.tax.cfg or {}
      cdb.tax.scope = tostring(cdb.tax.scope or "guild"):lower()
      if cdb.tax.scope ~= "guild" and cdb.tax.scope ~= "character" then cdb.tax.scope = "guild" end

      local cfg
      if cdb.tax.scope == "character" then
        cfg = cdb.tax.cfg
      else
        local guildKey = select(1, GetCurrentGuildKeyAndName())
        if not guildKey then return end
        cfg = EnsureGuildTaxDB(guildKey)
        if not cfg then return end
      end
      cfg.sources = (type(cfg.sources) == "table") and cfg.sources or {}
      cfg.sources.systemMoney = not (cfg.sources.systemMoney == true)
      Refresh()
    end)

    warbankBtn:SetScript("OnClick", function()
      EnsureDB()

      local cdb = (env.GetCharDB and env.GetCharDB()) or (LI and type(LI.GetCharDB) == "function" and LI.GetCharDB()) or (_G and rawget(_G, "fr0z3nUI_LootItCharDB"))
      if type(cdb) ~= "table" then cdb = nil end
      cdb = cdb or {}
      cdb.tax = (type(cdb.tax) == "table") and cdb.tax or {}
      cdb.tax.cfg = (type(cdb.tax.cfg) == "table") and cdb.tax.cfg or {}
      cdb.tax.scope = tostring(cdb.tax.scope or "guild"):lower()
      if cdb.tax.scope ~= "guild" and cdb.tax.scope ~= "character" then cdb.tax.scope = "guild" end

      local cfg
      if cdb.tax.scope == "character" then
        cfg = cdb.tax.cfg
      else
        local guildKey = select(1, GetCurrentGuildKeyAndName())
        if not guildKey then return end
        cfg = EnsureGuildTaxDB(guildKey)
        if not cfg then return end
      end
      cfg.warBankEnabled = not (cfg.warBankEnabled == true)
      Refresh()
    end)

    warbankEBBtn:SetScript("OnClick", function()
      EnsureDB()

      local cdb = (env.GetCharDB and env.GetCharDB()) or (LI and type(LI.GetCharDB) == "function" and LI.GetCharDB()) or (_G and rawget(_G, "fr0z3nUI_LootItCharDB"))
      if type(cdb) ~= "table" then cdb = nil end
      cdb = cdb or {}
      cdb.tax = (type(cdb.tax) == "table") and cdb.tax or {}
      cdb.tax.cfg = (type(cdb.tax.cfg) == "table") and cdb.tax.cfg or {}
      cdb.tax.scope = tostring(cdb.tax.scope or "guild"):lower()
      if cdb.tax.scope ~= "guild" and cdb.tax.scope ~= "character" then cdb.tax.scope = "guild" end

      local cfg
      if cdb.tax.scope == "character" then
        cfg = cdb.tax.cfg
      else
        local guildKey = select(1, GetCurrentGuildKeyAndName())
        if not guildKey then return end
        cfg = EnsureGuildTaxDB(guildKey)
        if not cfg then return end
      end
      cfg.warBankEB = not (cfg.warBankEB == true)
      Refresh()
    end)

    scBtn:SetScript("OnClick", function()
      EnsureDB()
      local ct = EnsureCharTaxDB()
      if type(ct) ~= "table" then return end

      local scope = tostring(ct.scope or "guild"):lower()
      if scope == "character" then
        ct.showOwedSilverCopper = not (ct.showOwedSilverCopper == true)
      else
        local guildKey = select(1, GetCurrentGuildKeyAndName())
        if not guildKey then return end
        local g = EnsureGuildTaxDB(guildKey)
        if type(g) ~= "table" then return end
        g.showOwedSilverCopper = not (g.showOwedSilverCopper == true)
      end
      Refresh()
    end)

    withdrawBtn:SetScript("OnClick", function()
      EnsureDB()
      local cdb = (env.GetCharDB and env.GetCharDB()) or (LI and type(LI.GetCharDB) == "function" and LI.GetCharDB()) or (_G and rawget(_G, "fr0z3nUI_LootItCharDB"))
      if type(cdb) ~= "table" then cdb = nil end
      cdb = cdb or {}
      cdb.tax = (type(cdb.tax) == "table") and cdb.tax or {}
      cdb.tax.cfg = (type(cdb.tax.cfg) == "table") and cdb.tax.cfg or {}
      cdb.tax.scope = tostring(cdb.tax.scope or "guild"):lower()
      if cdb.tax.scope ~= "guild" and cdb.tax.scope ~= "character" then cdb.tax.scope = "guild" end

      local cfg
      if cdb.tax.scope == "character" then
        cfg = cdb.tax.cfg
      else
        local guildKey = select(1, GetCurrentGuildKeyAndName())
        if not guildKey then return end
        cfg = EnsureGuildTaxDB(guildKey)
        if not cfg then return end
      end
      cfg.allowWithdraw = not (cfg.allowWithdraw == true)
      Refresh()
    end)

    debugBtn:SetScript("OnClick", function()
      EnsureDB()
      local cdb = (env.GetCharDB and env.GetCharDB()) or (LI and type(LI.GetCharDB) == "function" and LI.GetCharDB()) or (_G and rawget(_G, "fr0z3nUI_LootItCharDB"))
      if type(cdb) ~= "table" then return end
      cdb.tax = (type(cdb.tax) == "table") and cdb.tax or {}
      cdb.tax.debug = not (cdb.tax.debug == true)
      Refresh()
    end)

    bankPrintBtn:SetScript("OnClick", function()
      EnsureDB()
      local cdb = (env.GetCharDB and env.GetCharDB()) or (LI and type(LI.GetCharDB) == "function" and LI.GetCharDB()) or (_G and rawget(_G, "fr0z3nUI_LootItCharDB"))
      if type(cdb) ~= "table" then cdb = nil end
      cdb = cdb or {}
      cdb.tax = (type(cdb.tax) == "table") and cdb.tax or {}
      cdb.tax.cfg = (type(cdb.tax.cfg) == "table") and cdb.tax.cfg or {}
      cdb.tax.scope = tostring(cdb.tax.scope or "guild"):lower()
      if cdb.tax.scope ~= "guild" and cdb.tax.scope ~= "character" then cdb.tax.scope = "guild" end

      local cfg
      if cdb.tax.scope == "character" then
        cfg = cdb.tax.cfg
      else
        local guildKey = select(1, GetCurrentGuildKeyAndName())
        if not guildKey then return end
        cfg = EnsureGuildTaxDB(guildKey)
        if not cfg then return end
      end
      cfg.bankPrintEnabled = not (cfg.bankPrintEnabled == true)
      Refresh()
    end)

    bankPrintBtn:SetScript("OnEnter", function(self)
      if not (GameTooltip and GameTooltip.SetOwner and GameTooltip.SetText) then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText("Print Deposit/Withdraw")
      GameTooltip:Show()
    end)
    bankPrintBtn:SetScript("OnLeave", function() if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end end)

    manualBtn:SetScript("OnClick", function()
      EnsureDB()
      local cdb = (env.GetCharDB and env.GetCharDB()) or (LI and type(LI.GetCharDB) == "function" and LI.GetCharDB()) or (_G and rawget(_G, "fr0z3nUI_LootItCharDB"))
      if type(cdb) ~= "table" then cdb = nil end
      cdb = cdb or {}
      cdb.tax = (type(cdb.tax) == "table") and cdb.tax or {}
      cdb.tax.cfg = (type(cdb.tax.cfg) == "table") and cdb.tax.cfg or {}
      cdb.tax.scope = tostring(cdb.tax.scope or "guild"):lower()
      if cdb.tax.scope ~= "guild" and cdb.tax.scope ~= "character" then cdb.tax.scope = "guild" end

      local cfg
      if cdb.tax.scope == "character" then
        cfg = cdb.tax.cfg
      else
        local guildKey = select(1, GetCurrentGuildKeyAndName())
        if not guildKey then return end
        cfg = EnsureGuildTaxDB(guildKey)
        if not cfg then return end
      end
      cfg.manualBankMovesEnabled = not (cfg.manualBankMovesEnabled == true)
      Refresh()
    end)

    manualBtn:SetScript("OnEnter", function(self)
      if not (GameTooltip and GameTooltip.SetOwner and GameTooltip.SetText) then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText("Count manual bank deposits/withdrawals")
      GameTooltip:Show()
    end)
    manualBtn:SetScript("OnLeave", function() if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end end)

    withdrawBtn:SetScript("OnEnter", function(self)
      if not (GameTooltip and GameTooltip.SetOwner and GameTooltip.SetText) then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText("Allows lending Guild funds up to the Min Gold balance.\nRepaid after other Taxes, Interest of 11.49% pa applies.")
      GameTooltip:Show()
    end)
    withdrawBtn:SetScript("OnLeave", function() if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end end)

    clearGuildBtn:SetScript("OnEnter", function(self)
      if not (GameTooltip and GameTooltip.SetOwner and GameTooltip.SetText) then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText("Clears Due, excluding Withdrawn Amount")
      GameTooltip:Show()
    end)
    clearGuildBtn:SetScript("OnLeave", function() if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end end)

    clearWarBtn:SetScript("OnEnter", function(self)
      if not (GameTooltip and GameTooltip.SetOwner and GameTooltip.SetText) then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText("Clears Due, excluding Withdrawn Amount")
      GameTooltip:Show()
    end)
    clearWarBtn:SetScript("OnLeave", function() if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end end)

    -- Tooltips
    lootBtn:SetScript("OnEnter", function(self)
      if not (GameTooltip and GameTooltip.SetOwner and GameTooltip.SetText) then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText("Looted includes quest rewards and looted money.")
      GameTooltip:Show()
    end)
    lootBtn:SetScript("OnLeave", function() if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end end)

    systemBtn:SetScript("OnEnter", function(self)
      if not (GameTooltip and GameTooltip.SetOwner and GameTooltip.SetText) then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText("System money can be risky.\nLootIt tries to reuse its own money parsing to reduce false positives.")
      GameTooltip:Show()
    end)
    systemBtn:SetScript("OnLeave", function() if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end end)

    clearGuildBtn:SetScript("OnClick", function()
      Tax.ClearDue()
      Refresh()
    end)

    clearWarBtn:SetScript("OnClick", function()
      Tax.ClearDueWarbank()
      Refresh()
    end)

    panel:SetScript("OnShow", Refresh)
    Refresh()
  end
end

