local addonName, ns = ...
if type(ns) ~= "table" then ns = {} end

local LI = (ns and ns.LootIt) or {}
ns.LootIt = LI
fr0z3nUI_LootIt = LI
LI.ADDON = LI.ADDON or addonName

LI.Alias = LI.Alias or {}

LI.Alias._env = LI.Alias._env or nil

function LI.Alias.SetEnv(env)
  LI.Alias._env = (type(env) == "table") and env or nil
end

local function SafeCall(fn, ...)
  if type(fn) == "function" then
    return fn(...)
  end
end

-- Slash helper (used by /fli alias ...) so Alias can be transplanted cleanly.
-- Behavior should match the legacy inline handler.
function LI.Alias.HandleSlash(rest, env)
  local ENV = (type(env) == "table") and env or (LI.Alias and LI.Alias._env) or {}

  SafeCall(ENV.EnsureDB)
  local DB = SafeCall(ENV.GetDB)
  local CHARDB = SafeCall(ENV.GetCharDB)

  if not DB then
    DB = rawget(_G, "fr0z3nUI_LootItDB")
  end
  if not CHARDB then
    CHARDB = rawget(_G, "fr0z3nUI_LootItCharDB")
  end

  local Print = ENV.Print

  local parts = {}
  for w in tostring(rest or ""):gmatch("%S+") do
    parts[#parts + 1] = w
  end

  local sub = (parts[1] and parts[1]:lower()) or ""

  local function NormalizeScope(s)
    s = (s and s:lower()) or ""
    if s == "acc" or s == "account" then return "acc" end
    if s == "char" or s == "character" then return "char" end
    return nil
  end

  local function AliasStatusLine(scopeLabel)
    local a = 0
    local t
    if scopeLabel == "char" then
      t = (CHARDB and type(CHARDB.linkAliases) == "table") and CHARDB.linkAliases or {}
    else
      t = (DB and type(DB.linkAliases) == "table") and DB.linkAliases or {}
    end
    for _ in pairs(t) do a = a + 1 end
    SafeCall(Print, string.format("Aliases (%s): %d", scopeLabel == "char" and "Character" or "Account", a))
    for id, text in pairs(t) do
      SafeCall(Print, string.format("  %d = %s", tonumber(id) or 0, tostring(text or "")))
    end
  end

  if sub == "" or sub == "list" then
    AliasStatusLine("acc")
    AliasStatusLine("char")
    return
  end

  if sub == "set" or sub == "add" then
    local scope = NormalizeScope(parts[2]) or "acc"
    local idIndex = (NormalizeScope(parts[2]) and 3) or 2
    local id = tonumber(parts[idIndex])
    local text = table.concat(parts, " ", idIndex + 1)
    if not id or id <= 0 or text == "" then
      SafeCall(Print, "Usage: /fgo li alias set [acc|char] <itemID> <text>")
      return
    end

    if scope == "char" then
      CHARDB = (type(CHARDB) == "table") and CHARDB or {}
      CHARDB.linkAliases = (type(CHARDB.linkAliases) == "table") and CHARDB.linkAliases or {}
      CHARDB.linkAliasDisabledChar = (type(CHARDB.linkAliasDisabledChar) == "table") and CHARDB.linkAliasDisabledChar or {}
      CHARDB.linkAliases[id] = text
      CHARDB.linkAliasDisabledChar[id] = nil
      SafeCall(Print, string.format("Alias set (Character): %d -> %s", id, text))
    else
      DB = (type(DB) == "table") and DB or {}
      DB.linkAliases = (type(DB.linkAliases) == "table") and DB.linkAliases or {}
      DB.linkAliasDisabledAccount = (type(DB.linkAliasDisabledAccount) == "table") and DB.linkAliasDisabledAccount or {}
      DB.linkAliases[id] = text
      DB.linkAliasDisabledAccount[id] = nil
      SafeCall(Print, string.format("Alias set (Account): %d -> %s", id, text))
    end
    return
  end

  if sub == "del" or sub == "remove" or sub == "clear" then
    local scope = NormalizeScope(parts[2]) or "acc"
    local idIndex = (NormalizeScope(parts[2]) and 3) or 2
    local id = tonumber(parts[idIndex])
    if not id or id <= 0 then
      SafeCall(Print, "Usage: /fgo li alias del [acc|char] <itemID>")
      return
    end

    if scope == "char" then
      CHARDB = (type(CHARDB) == "table") and CHARDB or {}
      CHARDB.linkAliases = (type(CHARDB.linkAliases) == "table") and CHARDB.linkAliases or {}
      CHARDB.linkAliasDisabledChar = (type(CHARDB.linkAliasDisabledChar) == "table") and CHARDB.linkAliasDisabledChar or {}
      CHARDB.linkAliases[id] = nil
      CHARDB.linkAliasDisabledChar[id] = nil
      SafeCall(Print, "Alias removed (Character): " .. id)
    else
      DB = (type(DB) == "table") and DB or {}
      DB.linkAliases = (type(DB.linkAliases) == "table") and DB.linkAliases or {}
      DB.linkAliasDisabledAccount = (type(DB.linkAliasDisabledAccount) == "table") and DB.linkAliasDisabledAccount or {}
      DB.linkAliases[id] = nil
      DB.linkAliasDisabledAccount[id] = nil
      SafeCall(Print, "Alias removed (Account): " .. id)
    end
    return
  end

  SafeCall(Print, "Usage: /fgo li alias set|del|list")
  SafeCall(Print, "  /fgo li alias set [acc|char] <itemID> <text>")
  SafeCall(Print, "  /fgo li alias del [acc|char] <itemID>")
end

function LI.Alias.BuildTab(aliasPanel, env)
  if not aliasPanel then return end

  local ENV = (type(env) == "table") and env or (LI.Alias and LI.Alias._env) or nil

  local EnsureDBFn = (ENV and ENV.EnsureDB) or (LI and LI.EnsureDB) or nil
  local GetDBFn = (ENV and ENV.GetDB) or (LI and LI.GetDB) or nil
  local GetCharDBFn = (ENV and ENV.GetCharDB) or (LI and LI.GetCharDB) or nil

  local DB
  local CHARDB

  local function EnsureDB()
    if type(EnsureDBFn) == "function" then
      EnsureDBFn()
    end
    if type(GetDBFn) == "function" then
      DB = GetDBFn()
    else
      DB = rawget(_G, "fr0z3nUI_LootItDB")
    end
    if type(GetCharDBFn) == "function" then
      CHARDB = GetCharDBFn()
    else
      CHARDB = rawget(_G, "fr0z3nUI_LootItCharDB")
    end
  end

  local PREFIX = (ENV and ENV.PREFIX) or (LI and LI.PREFIX) or "|cff00ccff[LI]|r "
  local Print = (ENV and ENV.Print) or ((LI and type(LI.Print) == "function") and LI.Print or nil)
  if type(Print) ~= "function" then
    Print = function(...) end
  end

  local ADDON_LINK_ALIASES = (ENV and ENV.AddonLinkAliases) or (LI and LI.AddonLinkAliases) or {}
  local ADDON_CURRENCY_ALIASES = (ENV and ENV.AddonCurrencyAliases) or (LI and LI.AddonCurrencyAliases) or {}

  local SetCheckBoxText = (ENV and ENV.SetCheckBoxText) or ((LI and type(LI.SetCheckBoxText) == "function") and LI.SetCheckBoxText or nil)
  if type(SetCheckBoxText) ~= "function" then
    SetCheckBoxText = function(...) end
  end

  EnsureDB()

  local function HideInputBoxTemplateArt(e)
    if not (e and e.GetRegions) then return end
    for _, region in ipairs({ e:GetRegions() }) do
      if region and region.GetObjectType and region:GetObjectType() == "Texture" then
        region:Hide()
      end
    end
  end

  local function SetEditFontSize(e, size)
    if not (e and e.GetFont and e.SetFont) then return end
    local font, _, flags = e:GetFont()
    if type(font) ~= "string" or font == "" then
      font = "Fonts\\FRIZQT__.TTF"
    end
    e:SetFont(font, size, flags)
  end

  local function SetFontStringSize(fs, size)
    if not (fs and fs.GetFont and fs.SetFont) then return end
    local font, _, flags = fs:GetFont()
    if type(font) ~= "string" or font == "" then
      font = "Fonts\\FRIZQT__.TTF"
    end
    fs:SetFont(font, size, flags)
  end

  local function AddPlaceholder(e, text)
    if not (e and e.CreateFontString) then return nil end
    local fs = e:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    fs:SetText(tostring(text or ""))
    fs:SetPoint("LEFT", e, "LEFT", 10, 0)
    fs:SetJustifyH("LEFT")

    local function Update()
      local t = tostring(e:GetText() or "")
      if t == "" and not e:HasFocus() then
        fs:Show()
      else
        fs:Hide()
      end
    end

    e:HookScript("OnEditFocusGained", Update)
    e:HookScript("OnEditFocusLost", Update)
    e:HookScript("OnTextChanged", Update)
    Update()
    return fs
  end

  local info = aliasPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  info:SetPoint("TOP", aliasPanel, "TOP", 0, -18)
  info:SetText("Enter ItemID Below")
  SetFontStringSize(info, 15)

  local itemEdit = CreateFrame("EditBox", nil, aliasPanel, "InputBoxTemplate")
  itemEdit:SetSize(175, 38)
  itemEdit:SetPoint("TOP", info, "BOTTOM", 0, -2)
  itemEdit:SetAutoFocus(false)
  itemEdit:SetJustifyH("CENTER")
  if itemEdit.SetJustifyV then itemEdit:SetJustifyV("MIDDLE") end
  itemEdit:SetTextInsets(6, 6, 0, 0)
  SetEditFontSize(itemEdit, 16)
  HideInputBoxTemplateArt(itemEdit)
  itemEdit:SetNumeric(true)

  local MODE_ITEM = "item"
  local MODE_CURRENCY = "currency"

  local modeBtn = CreateFrame("Button", nil, aliasPanel)
  modeBtn:SetSize(18, 18)
  modeBtn:SetPoint("RIGHT", itemEdit, "LEFT", -6, 0)
  modeBtn:RegisterForClicks("LeftButtonUp")

  local modeBtnText = modeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  modeBtnText:SetPoint("CENTER", modeBtn, "CENTER", 0, 0)
  SetFontStringSize(modeBtnText, 16)

  local function GetAliasInputMode()
    EnsureDB()
    local m = DB and DB.aliasInputMode
    if m ~= MODE_ITEM and m ~= MODE_CURRENCY then
      m = MODE_ITEM
    end
    return m
  end

  local function SetAliasInputMode(m)
    EnsureDB()
    if m ~= MODE_ITEM and m ~= MODE_CURRENCY then
      m = MODE_ITEM
    end
    DB.aliasInputMode = m
  end

  local itemPH = aliasPanel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
  itemPH:SetPoint("CENTER", itemEdit, "CENTER", 0, 0)
  itemPH:SetText("ItemID")
  itemPH:SetTextColor(1, 1, 1, 0.35)
  SetFontStringSize(itemPH, 13)

  local function UpdateItemPlaceholder()
    local txt = tostring(itemEdit:GetText() or "")
    local hasText = (txt ~= "")
    local focused = (itemEdit.HasFocus and itemEdit:HasFocus()) or false
    itemPH:SetShown((not hasText) and (not focused))
  end
  itemEdit:SetScript("OnEditFocusGained", function() itemPH:Hide() end)
  itemEdit:SetScript("OnEditFocusLost", function() UpdateItemPlaceholder() end)
  itemEdit:HookScript("OnTextChanged", function() UpdateItemPlaceholder() end)
  UpdateItemPlaceholder()

  local nameLabel = aliasPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  nameLabel:SetPoint("TOP", itemEdit, "BOTTOM", 0, -2)
  nameLabel:SetPoint("LEFT", aliasPanel, "LEFT", 10, 0)
  nameLabel:SetPoint("RIGHT", aliasPanel, "RIGHT", -10, 0)
  nameLabel:SetJustifyH("CENTER")
  nameLabel:SetWordWrap(true)
  nameLabel:SetText("")
  nameLabel:SetTextColor(1, 0.82, 0, 1)
  SetFontStringSize(nameLabel, 17)

  local renameEdit = CreateFrame("EditBox", nil, aliasPanel, "InputBoxTemplate")
  renameEdit:SetSize(175, 38)
  renameEdit:SetPoint("TOP", nameLabel, "BOTTOM", 0, -2)
  renameEdit:SetAutoFocus(false)
  renameEdit:SetJustifyH("CENTER")
  if renameEdit.SetJustifyV then renameEdit:SetJustifyV("MIDDLE") end
  renameEdit:SetTextInsets(6, 6, 0, 0)
  SetEditFontSize(renameEdit, 16)
  HideInputBoxTemplateArt(renameEdit)

  local aliasPH = aliasPanel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
  aliasPH:SetPoint("CENTER", renameEdit, "CENTER", 0, 0)
  aliasPH:SetText("Short Name Here")
  aliasPH:SetTextColor(1, 1, 1, 0.35)
  SetFontStringSize(aliasPH, 13)

  local function UpdateAliasPlaceholder()
    local txt = tostring(renameEdit:GetText() or "")
    local hasText = (txt ~= "")
    local focused = (renameEdit.HasFocus and renameEdit:HasFocus()) or false
    aliasPH:SetShown((not hasText) and (not focused))
  end
  renameEdit:SetScript("OnEditFocusGained", function() aliasPH:Hide() end)
  renameEdit:SetScript("OnEditFocusLost", function() UpdateAliasPlaceholder() end)
  renameEdit:HookScript("OnTextChanged", function() UpdateAliasPlaceholder() end)
  UpdateAliasPlaceholder()

  local status = aliasPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  status:SetPoint("TOP", renameEdit, "BOTTOM", 0, -2)
  status:SetPoint("LEFT", aliasPanel, "LEFT", 10, 0)
  status:SetPoint("RIGHT", aliasPanel, "RIGHT", -10, 0)
  status:SetJustifyH("CENTER")
  status:SetTextColor(1, 0.55, 0.1, 1)
  status:SetText("Type/Paste an ID above")
  SetFontStringSize(status, 13)

  local ignoreCB = CreateFrame("CheckButton", nil, aliasPanel, "UICheckButtonTemplate")
  ignoreCB:SetPoint("BOTTOMLEFT", aliasPanel, "BOTTOMLEFT", 10, 44)
  SetCheckBoxText(ignoreCB, "Ignore (hide from loot chat)")
  ignoreCB:Disable()

  local delayLabel = aliasPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  delayLabel:SetPoint("BOTTOMRIGHT", aliasPanel, "BOTTOMRIGHT", -140, 48)
  delayLabel:SetText("Delay print (sec)")

  local delayBox = CreateFrame("EditBox", nil, aliasPanel, "InputBoxTemplate")
  delayBox:SetSize(54, 20)
  delayBox:SetPoint("LEFT", delayLabel, "RIGHT", 8, -2)
  delayBox:SetAutoFocus(false)
  delayBox:SetJustifyH("CENTER")
  delayBox:SetNumeric(true)
  delayBox:SetText("0")
  delayBox:Disable()

  local BTN_W, BTN_H, BTN_GAP = 120, 22, 10
  local ADD_ROW_X = (BTN_W / 2) + (BTN_GAP / 2)

  local btnAcc = CreateFrame("Button", nil, aliasPanel, "UIPanelButtonTemplate")
  btnAcc:SetSize(BTN_W, BTN_H)
  btnAcc:SetPoint("BOTTOM", aliasPanel, "BOTTOM", -ADD_ROW_X, 18)
  btnAcc:SetText("Account")
  btnAcc:Disable()
  btnAcc:RegisterForClicks("LeftButtonUp")

  do
    local fs = btnAcc.GetFontString and btnAcc:GetFontString()
    if fs then
      SetFontStringSize(fs, 13)
    end
  end

  local btnChar = CreateFrame("Button", nil, aliasPanel, "UIPanelButtonTemplate")
  btnChar:SetSize(BTN_W, BTN_H)
  btnChar:SetPoint("BOTTOM", aliasPanel, "BOTTOM", ADD_ROW_X, 18)
  btnChar:SetText("Character")
  btnChar:Disable()
  btnChar:RegisterForClicks("LeftButtonUp")

  do
    local fs = btnChar.GetFontString and btnChar:GetFontString()
    if fs then
      SetFontStringSize(fs, 13)
    end
  end

  local function SetButtonColor(btn, label, state)
    if not btn then return end
    local s = tostring(state or "inactive")
    if s == "active" then
      btn:SetText("|cff00ff00" .. label .. "|r")
      return
    end
    if s == "disabled" then
      btn:SetText("|cffffa500" .. label .. "|r")
      return
    end
    btn:SetText("|cffffff00" .. label .. "|r")
  end

  local function Trim(s)
    s = tostring(s or "")
    return s:gsub("^%s+", ""):gsub("%s+$", "")
  end

  local function GetValidID()
    local txt = tostring(itemEdit:GetText() or "")
    local n = tonumber(txt)
    if n and n > 0 then
      return n
    end
    return nil
  end

  local function SetNameLabelColorForItem(id)
    if not id then
      nameLabel:SetTextColor(1, 0.82, 0, 1)
      return
    end

    local quality
    if C_Item and C_Item.GetItemInfo then
      local _, _, q = C_Item.GetItemInfo(id)
      quality = q
    end

    if type(quality) == "number" then
      local c = _G and rawget(_G, "ITEM_QUALITY_COLORS")
      c = (type(c) == "table") and c[quality] or nil
      if c and type(c.r) == "number" and type(c.g) == "number" and type(c.b) == "number" then
        nameLabel:SetTextColor(c.r, c.g, c.b, 1)
        return
      end
    end

    nameLabel:SetTextColor(1, 0.82, 0, 1)
  end

  local function SetNameLabelColorForCurrency()
    -- Rare blue
    nameLabel:SetTextColor(0, 0.44, 0.87, 1)
  end

  local function GetDisplayNameForID(mode, id)
    if not id then return nil end
    if mode == MODE_CURRENCY then
      if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
        local info = C_CurrencyInfo.GetCurrencyInfo(id)
        if info and type(info.name) == "string" and info.name ~= "" then
          return info.name
        end
      end
      return "CurrencyID: " .. tostring(id)
    end

    if C_Item and C_Item.GetItemInfo then
      local name = C_Item.GetItemInfo(id)
      if type(name) == "string" and name ~= "" then
        return name
      end
    end
    return "ItemID: " .. tostring(id)
  end

  local function GetAliasState(mode, id)
    EnsureDB()

    local out = {
      char = { text = nil, disabled = false },
      acc = { text = nil, disabled = false },
      addon = { text = nil, disabled = false },
    }

    if mode == MODE_CURRENCY then
      if CHARDB and type(CHARDB.currencyAliases) == "table" then
        out.char.text = CHARDB.currencyAliases[id]
      end
      if CHARDB and type(CHARDB.currencyAliasDisabledChar) == "table" then
        out.char.disabled = (CHARDB.currencyAliasDisabledChar[id] == true)
      end

      if DB and type(DB.currencyAliases) == "table" then
        out.acc.text = DB.currencyAliases[id]
      end
      if DB and type(DB.currencyAliasDisabledAccount) == "table" then
        out.acc.disabled = (DB.currencyAliasDisabledAccount[id] == true)
      end

      out.addon.text = ADDON_CURRENCY_ALIASES[id]
      if DB and type(DB.currencyAliasDisabledAddon) == "table" then
        out.addon.disabled = (DB.currencyAliasDisabledAddon[id] == true)
      end
    else
      if CHARDB and type(CHARDB.linkAliases) == "table" then
        out.char.text = CHARDB.linkAliases[id]
      end
      if CHARDB and type(CHARDB.linkAliasDisabledChar) == "table" then
        out.char.disabled = (CHARDB.linkAliasDisabledChar[id] == true)
      end

      if DB and type(DB.linkAliases) == "table" then
        out.acc.text = DB.linkAliases[id]
      end
      if DB and type(DB.linkAliasDisabledAccount) == "table" then
        out.acc.disabled = (DB.linkAliasDisabledAccount[id] == true)
      end

      out.addon.text = ADDON_LINK_ALIASES[id]
      if DB and type(DB.linkAliasDisabledAddon) == "table" then
        out.addon.disabled = (DB.linkAliasDisabledAddon[id] == true)
      end
    end

    return out
  end

  local function AnyAliasExists(st)
    if not st then return false end
    if type(st.acc.text) == "string" and st.acc.text ~= "" then return true end
    if type(st.addon.text) == "string" and st.addon.text ~= "" then return true end
    if type(st.char.text) == "string" and st.char.text ~= "" then return true end
    return false
  end

  local function IsOnlyAddonAlias(st)
    if not st then return false end
    local hasAcc = (type(st.acc.text) == "string" and st.acc.text ~= "") and true or false
    local hasChar = (type(st.char.text) == "string" and st.char.text ~= "") and true or false
    local hasAddon = (type(st.addon.text) == "string" and st.addon.text ~= "") and true or false
    return hasAddon and (not hasAcc) and (not hasChar)
  end

  local function GetEffectiveAlias(mode, id)
    local st = GetAliasState(mode, id)

    -- Per-character disable suppresses all sources.
    if st.char.disabled then
      return nil, nil
    end

    if type(st.char.text) == "string" and st.char.text ~= "" then
      return st.char.text, "Character"
    end
    if type(st.acc.text) == "string" and st.acc.text ~= "" and not st.acc.disabled then
      return st.acc.text, "Account"
    end
    if type(st.addon.text) == "string" and st.addon.text ~= "" and not st.addon.disabled then
      return st.addon.text, "Addon"
    end

    return nil, nil
  end

  local function GetEditSeedAlias(mode, id)
    local st = GetAliasState(mode, id)
    if type(st.acc.text) == "string" and st.acc.text ~= "" then
      return st.acc.text, "Account"
    end
    if type(st.addon.text) == "string" and st.addon.text ~= "" then
      return st.addon.text, "Addon"
    end
    if type(st.char.text) == "string" and st.char.text ~= "" then
      return st.char.text, "Character"
    end
    return "", nil
  end

  local function SyncUI()
    local mode = GetAliasInputMode()
    aliasPanel._aliasMode = mode
    local id = GetValidID()
    aliasPanel._aliasID = id

    if aliasPanel._aliasBaseline == nil then
      aliasPanel._aliasBaseline = ""
    end

    if not id then
      nameLabel:SetText("")
      status:SetText("Type/Paste an ID above")
      btnAcc:Disable()
      btnChar:Disable()
      ignoreCB:SetChecked(false)
      ignoreCB:Disable()
      delayBox:SetText("0")
      delayBox:Disable()
      SetButtonColor(btnAcc, "Account", "inactive")
      SetButtonColor(btnChar, "Character", "inactive")
      return
    end

    nameLabel:SetText(GetDisplayNameForID(mode, id) or "")
    if mode == MODE_CURRENCY then
      SetNameLabelColorForCurrency()
    else
      SetNameLabelColorForItem(id)
    end

    local st = GetAliasState(mode, id)
    local exists = AnyAliasExists(st)

    if mode == MODE_ITEM then
      local ignored = (DB and type(DB.ignoredItemIDs) == "table" and DB.ignoredItemIDs[id] == true) and true or false
      ignoreCB:SetChecked(ignored)
      ignoreCB:Enable()

      do
        EnsureDB()
        DB.delayPrint = (type(DB.delayPrint) == "table") and DB.delayPrint or {}
        DB.delayPrint.itemSeconds = (type(DB.delayPrint.itemSeconds) == "table") and DB.delayPrint.itemSeconds or {}
        local sec = tonumber(DB.delayPrint.itemSeconds[id]) or 0
        if sec < 0 then sec = 0 end
        if sec > 3600 then sec = 3600 end
        delayBox:SetText(tostring(math.floor(sec + 0.5)))
        delayBox:Enable()
      end

      if ignored then
        status:SetText("Ignored: hidden (no chat output)")
      end
    else
      ignoreCB:SetChecked(false)
      ignoreCB:Disable()
      delayBox:SetText("0")
      delayBox:Disable()
    end

    local activeText, activeSource = GetEffectiveAlias(mode, id)
    if activeText then
      -- Keep status instructional; details are already visible via the name + alias box.
    else
    end

    -- Seed rename box and baseline when not actively editing.
    if not renameEdit:HasFocus() then
      local seedText = select(1, GetEditSeedAlias(mode, id))
      renameEdit:SetText(tostring(seedText or ""))
      renameEdit:HighlightText()
      aliasPanel._aliasBaseline = Trim(seedText)
      UpdateAliasPlaceholder()
    end

    local current = Trim(renameEdit:GetText())
    local baseline = Trim(aliasPanel._aliasBaseline)
    local edited = (current ~= baseline)

    if not exists then
      -- Input - Doesn't exist: Account Active / Character Inactive.
      btnAcc:Enable()
      btnChar:Disable()
      SetButtonColor(btnAcc, "Account", "inactive")
      SetButtonColor(btnChar, "Character", "inactive")
      if not (mode == MODE_ITEM and ignoreCB:GetChecked()) then
        status:SetText("Type an Alias, Click Account to Save")
      end
      return
    end

    if edited then
      -- Alias edited: Account Yellow / Character Inactive.
      btnAcc:Enable()
      btnChar:Disable()
      SetButtonColor(btnAcc, "Account", "inactive")
      SetButtonColor(btnChar, "Character", "inactive")
      if not (mode == MODE_ITEM and ignoreCB:GetChecked()) then
        status:SetText("Click Account to Save")
      end
      return
    end

    if IsOnlyAddonAlias(st) then
      -- Addon-only alias: Account toggles the built-in addon alias enable/disable.
      btnAcc:Enable()
      btnChar:Enable()
      SetButtonColor(btnAcc, "Account", st.addon.disabled and "disabled" or "active")
      SetButtonColor(btnChar, "Character", st.char.disabled and "disabled" or "active")

      if not (mode == MODE_ITEM and ignoreCB:GetChecked()) then
        if st.addon.disabled then
          status:SetText("Addon alias disabled: Click Account to Enable")
        else
          status:SetText("Addon alias active: Click Account to Disable")
        end
      end
      return
    end

    -- Input - Exists, no edit: Account (remove from both), Character (toggle char disable).
    btnAcc:Enable()
    btnChar:Enable()
    -- Use Trade-style coloring: green=enabled, orange=disabled, yellow=inactive.
    -- Account is a destructive action here (removes from both), so use orange.
    SetButtonColor(btnAcc, "Account", "disabled")
    SetButtonColor(btnChar, "Character", st.char.disabled and "disabled" or "active")

    if st.char.disabled then
      if not (mode == MODE_ITEM and ignoreCB:GetChecked()) then
        status:SetText("Click Character to Enable, Account to Remove")
      end
    else
      if not (mode == MODE_ITEM and ignoreCB:GetChecked()) then
        status:SetText("Click Character to Disable, Account to Remove")
      end
    end
  end

  local function RemoveFromBoth(mode, id)
    EnsureDB()
    if not id then return end

    if mode == MODE_CURRENCY then
      DB.currencyAliases = (type(DB.currencyAliases) == "table") and DB.currencyAliases or {}
      DB.currencyAliasDisabledAccount = (type(DB.currencyAliasDisabledAccount) == "table") and DB.currencyAliasDisabledAccount or {}
      DB.currencyAliasDisabledAddon = (type(DB.currencyAliasDisabledAddon) == "table") and DB.currencyAliasDisabledAddon or {}

      CHARDB.currencyAliases = (type(CHARDB.currencyAliases) == "table") and CHARDB.currencyAliases or {}
      CHARDB.currencyAliasDisabledChar = (type(CHARDB.currencyAliasDisabledChar) == "table") and CHARDB.currencyAliasDisabledChar or {}

      DB.currencyAliases[id] = nil
      DB.currencyAliasDisabledAccount[id] = nil
      CHARDB.currencyAliases[id] = nil
      CHARDB.currencyAliasDisabledChar[id] = nil

      if ADDON_CURRENCY_ALIASES and ADDON_CURRENCY_ALIASES[id] then
        DB.currencyAliasDisabledAddon[id] = true
      end

      Print(PREFIX .. string.format("Alias removed (Currency): %d", id))
    else
      DB.linkAliases = (type(DB.linkAliases) == "table") and DB.linkAliases or {}
      DB.linkAliasDisabledAccount = (type(DB.linkAliasDisabledAccount) == "table") and DB.linkAliasDisabledAccount or {}
      DB.linkAliasDisabledAddon = (type(DB.linkAliasDisabledAddon) == "table") and DB.linkAliasDisabledAddon or {}

      CHARDB.linkAliases = (type(CHARDB.linkAliases) == "table") and CHARDB.linkAliases or {}
      CHARDB.linkAliasDisabledChar = (type(CHARDB.linkAliasDisabledChar) == "table") and CHARDB.linkAliasDisabledChar or {}

      DB.linkAliases[id] = nil
      DB.linkAliasDisabledAccount[id] = nil
      CHARDB.linkAliases[id] = nil
      CHARDB.linkAliasDisabledChar[id] = nil

      if ADDON_LINK_ALIASES and ADDON_LINK_ALIASES[id] then
        DB.linkAliasDisabledAddon[id] = true
      end

      Print(PREFIX .. string.format("Alias removed: %d", id))
    end
    aliasPanel._aliasBaseline = ""
  end

  local function ToggleAddonDisable(mode, id)
    EnsureDB()
    if not id then return end

    if mode == MODE_CURRENCY then
      DB.currencyAliasDisabledAddon = (type(DB.currencyAliasDisabledAddon) == "table") and DB.currencyAliasDisabledAddon or {}
      if DB.currencyAliasDisabledAddon[id] == true then
        DB.currencyAliasDisabledAddon[id] = nil
        Print(PREFIX .. string.format("Alias enabled (Addon, Currency): %d", id))
      else
        DB.currencyAliasDisabledAddon[id] = true
        Print(PREFIX .. string.format("Alias disabled (Addon, Currency): %d", id))
      end
    else
      DB.linkAliasDisabledAddon = (type(DB.linkAliasDisabledAddon) == "table") and DB.linkAliasDisabledAddon or {}
      if DB.linkAliasDisabledAddon[id] == true then
        DB.linkAliasDisabledAddon[id] = nil
        Print(PREFIX .. string.format("Alias enabled (Addon): %d", id))
      else
        DB.linkAliasDisabledAddon[id] = true
        Print(PREFIX .. string.format("Alias disabled (Addon): %d", id))
      end
    end
  end

  local function SaveToAccount(mode, id)
    EnsureDB()
    if not id then return end

    local txt = Trim(renameEdit:GetText())
    if txt == "" then
      RemoveFromBoth(mode, id)
      return
    end

    if mode == MODE_CURRENCY then
      DB.currencyAliases = (type(DB.currencyAliases) == "table") and DB.currencyAliases or {}
      DB.currencyAliasDisabledAccount = (type(DB.currencyAliasDisabledAccount) == "table") and DB.currencyAliasDisabledAccount or {}
      DB.currencyAliasDisabledAddon = (type(DB.currencyAliasDisabledAddon) == "table") and DB.currencyAliasDisabledAddon or {}

      DB.currencyAliases[id] = txt
      DB.currencyAliasDisabledAccount[id] = nil
      DB.currencyAliasDisabledAddon[id] = nil

      Print(PREFIX .. string.format("Alias set (Account, Currency): %d -> %s", id, txt))
    else
      DB.linkAliases = (type(DB.linkAliases) == "table") and DB.linkAliases or {}
      DB.linkAliasDisabledAccount = (type(DB.linkAliasDisabledAccount) == "table") and DB.linkAliasDisabledAccount or {}
      DB.linkAliasDisabledAddon = (type(DB.linkAliasDisabledAddon) == "table") and DB.linkAliasDisabledAddon or {}

      DB.linkAliases[id] = txt
      DB.linkAliasDisabledAccount[id] = nil
      DB.linkAliasDisabledAddon[id] = nil

      Print(PREFIX .. string.format("Alias set (Account): %d -> %s", id, txt))
    end
    aliasPanel._aliasBaseline = txt
  end

  local function ToggleCharDisable(mode, id)
    EnsureDB()
    if not id then return end

    if mode == MODE_CURRENCY then
      CHARDB.currencyAliasDisabledChar = (type(CHARDB.currencyAliasDisabledChar) == "table") and CHARDB.currencyAliasDisabledChar or {}
      if CHARDB.currencyAliasDisabledChar[id] then
        CHARDB.currencyAliasDisabledChar[id] = nil
        Print(PREFIX .. string.format("Alias enabled (Character, Currency): %d", id))
      else
        CHARDB.currencyAliasDisabledChar[id] = true
        Print(PREFIX .. string.format("Alias disabled (Character, Currency): %d", id))
      end
    else
      CHARDB.linkAliasDisabledChar = (type(CHARDB.linkAliasDisabledChar) == "table") and CHARDB.linkAliasDisabledChar or {}
      if CHARDB.linkAliasDisabledChar[id] then
        CHARDB.linkAliasDisabledChar[id] = nil
        Print(PREFIX .. string.format("Alias enabled (Character): %d", id))
      else
        CHARDB.linkAliasDisabledChar[id] = true
        Print(PREFIX .. string.format("Alias disabled (Character): %d", id))
      end
    end
  end

  local function UpdateModeUI()
    local mode = GetAliasInputMode()
    if mode == MODE_CURRENCY then
      info:SetText("Enter CurrencyID Below")
      itemPH:SetText("CurrencyID")
      modeBtnText:SetText("C")
      modeBtnText:SetTextColor(0, 0.44, 0.87, 1)
    else
      info:SetText("Enter ItemID Below")
      itemPH:SetText("ItemID")
      modeBtnText:SetText("I")
      modeBtnText:SetTextColor(0.64, 0.21, 0.93, 1)
    end
    itemEdit:SetText("")
    renameEdit:SetText("")
    aliasPanel._aliasBaseline = ""
    UpdateItemPlaceholder()
    UpdateAliasPlaceholder()
  end

  modeBtn:SetScript("OnClick", function()
    local cur = GetAliasInputMode()
    if cur == MODE_CURRENCY then
      SetAliasInputMode(MODE_ITEM)
    else
      SetAliasInputMode(MODE_CURRENCY)
    end
    UpdateModeUI()
    SyncUI()
  end)

  itemEdit:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
    SyncUI()
  end)
  itemEdit:SetScript("OnTextChanged", function()
    SyncUI()
  end)

  renameEdit:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
    local id = aliasPanel._aliasID or GetValidID()
    local mode = aliasPanel._aliasMode or GetAliasInputMode()
    SaveToAccount(mode, id)
    SyncUI()
  end)

  renameEdit:SetScript("OnTextChanged", function(self)
    if self and self.HasFocus and self:HasFocus() then
      SyncUI()
    end
  end)

  ignoreCB:SetScript("OnClick", function(self)
    local id = aliasPanel._aliasID or GetValidID()
    local mode = aliasPanel._aliasMode or GetAliasInputMode()
    if not (id and mode == MODE_ITEM) then
      self:SetChecked(false)
      self:Disable()
      return
    end

    EnsureDB()
    DB.ignoredItemIDs = (type(DB.ignoredItemIDs) == "table") and DB.ignoredItemIDs or {}
    local on = self:GetChecked() and true or false
    DB.ignoredItemIDs[id] = on and true or nil
    Print(PREFIX .. string.format("Ignore %s: %d", on and "enabled" or "disabled", id))
    SyncUI()
  end)

  delayBox:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
    local id = aliasPanel._aliasID or GetValidID()
    local mode = aliasPanel._aliasMode or GetAliasInputMode()
    if not (id and mode == MODE_ITEM) then
      self:SetText("0")
      self:Disable()
      return
    end

    EnsureDB()
    DB.delayPrint = (type(DB.delayPrint) == "table") and DB.delayPrint or {}
    DB.delayPrint.itemSeconds = (type(DB.delayPrint.itemSeconds) == "table") and DB.delayPrint.itemSeconds or {}

    local sec = tonumber(self:GetText() or "") or 0
    if sec < 0 then sec = 0 end
    if sec > 3600 then sec = 3600 end

    if sec <= 0 then
      DB.delayPrint.itemSeconds[id] = nil
      Print(PREFIX .. string.format("Delay print: disabled (%d)", id))
    else
      DB.delayPrint.itemSeconds[id] = sec
      Print(PREFIX .. string.format("Delay print: %ds (%d)", sec, id))
    end

    SyncUI()
  end)

  delayBox:SetScript("OnEscapePressed", function(self)
    local id = aliasPanel._aliasID or GetValidID()
    EnsureDB()
    local sec = (DB and DB.delayPrint and DB.delayPrint.itemSeconds and id and tonumber(DB.delayPrint.itemSeconds[id])) or 0
    if sec < 0 then sec = 0 end
    if sec > 3600 then sec = 3600 end
    self:SetText(tostring(math.floor(sec + 0.5)))
    self:ClearFocus()
  end)

  btnAcc:SetScript("OnClick", function()
    local id = aliasPanel._aliasID or GetValidID()
    local mode = aliasPanel._aliasMode or GetAliasInputMode()
    if not id then return end

    local st = GetAliasState(mode, id)
    local exists = AnyAliasExists(st)
    local current = Trim(renameEdit:GetText())
    local baseline = Trim(aliasPanel._aliasBaseline)
    local edited = (current ~= baseline)

    if exists and (not edited) and IsOnlyAddonAlias(st) then
      ToggleAddonDisable(mode, id)
    elseif (not exists) or edited then
      SaveToAccount(mode, id)
    else
      RemoveFromBoth(mode, id)
    end
    SyncUI()
  end)

  btnChar:SetScript("OnClick", function()
    local id = aliasPanel._aliasID or GetValidID()
    local mode = aliasPanel._aliasMode or GetAliasInputMode()
    if not id then return end

    local st = GetAliasState(mode, id)
    local exists = AnyAliasExists(st)
    if not exists then return end

    local current = Trim(renameEdit:GetText())
    local baseline = Trim(aliasPanel._aliasBaseline)
    local edited = (current ~= baseline)
    if edited then return end

    ToggleCharDisable(mode, id)
    SyncUI()
  end)

  aliasPanel.Refresh = function()
    EnsureDB()
    UpdateModeUI()
    SyncUI()
  end

  UpdateModeUI()
  SyncUI()
end
