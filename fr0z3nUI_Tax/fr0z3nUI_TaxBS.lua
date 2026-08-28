local addonName, ns = ...
local IsAddOnLoadedSafe = (_G.C_AddOns and rawget(_G.C_AddOns, "IsAddOnLoaded")) or rawget(_G, "IsAddOnLoaded")

-- The nested module is loaded by FGO through its parent TOC. When the folder is
-- copied as its own addon, this bootstrap supplies the missing FGO host services.
if addonName == "fr0z3nUI_GameOptions"
    or (type(IsAddOnLoadedSafe) == "function" and IsAddOnLoadedSafe("fr0z3nUI_GameOptions")) then
  return
end

ns = (type(ns) == "table") and ns or {}
local LI = ns.LootIt or _G.fr0z3nUI_LootIt or {}
ns.LootIt = LI
_G.fr0z3nUI_LootIt = LI
LI.Tax = LI.Tax or {}

local db = _G.fr0z3nUI_TaxDB
if type(db) ~= "table" then
  db = {}
  _G.fr0z3nUI_TaxDB = db
end
local charDB = _G.fr0z3nUI_TaxCharDB
if type(charDB) ~= "table" then
  charDB = {}
  _G.fr0z3nUI_TaxCharDB = charDB
end

LI.GetDB = function() return db end
LI.GetCharDB = function() return charDB end

local function Print(message)
  print("|cff00ccff[FTX]|r " .. tostring(message or ""))
end

local function InitTax()
  -- Re-check at PLAYER_LOGIN (after all addons finish loading) rather than only at file-parse
  -- time, since load order between this addon and fr0z3nUI_GameOptions is not guaranteed.
  if type(IsAddOnLoadedSafe) == "function" and IsAddOnLoadedSafe("fr0z3nUI_GameOptions") then
    return
  end
  if type(_G.fr0z3nUI_TaxDB) == "table" then
    db = _G.fr0z3nUI_TaxDB
  else
    _G.fr0z3nUI_TaxDB = db
  end
  if type(_G.fr0z3nUI_TaxCharDB) == "table" then
    charDB = _G.fr0z3nUI_TaxCharDB
  else
    _G.fr0z3nUI_TaxCharDB = charDB
  end
  if LI.Tax and type(LI.Tax.Init) == "function" then
    LI.Tax.Init(db, charDB, { Print = Print, standalone = true })
  end
end

local function IsStandaloneWarbankOpen()
  local bankFrame = _G.BankFrame
  if not (bankFrame and bankFrame.IsShown and bankFrame:IsShown()) then
    return false
  end

  local bankType = (Enum and Enum.BankType) and Enum.BankType or nil
  local cBank = _G.C_Bank
  if type(cBank) ~= "table" or not (bankType and bankType.Account ~= nil) then
    return false
  end

  local canDeposit
  local canWithdraw
  if type(cBank.CanDepositMoney) == "function" then
    local ok, value = pcall(cBank.CanDepositMoney, bankType.Account)
    if ok then canDeposit = value end
  end
  if type(cBank.CanWithdrawMoney) == "function" then
    local ok, value = pcall(cBank.CanWithdrawMoney, bankType.Account)
    if ok then canWithdraw = value end
  end

  return canDeposit == true or canWithdraw == true
end

local function ProbeStandaloneWarbank()
  if not IsStandaloneWarbankOpen() then return end
  local tax = LI.Tax
  if tax and type(tax.OnWarbankFrame) == "function" then
    tax.OnWarbankFrame(true)
  end
end

local function OpenTaxWindow()
  if type(LI.Tax.OpenConfig) == "function" then
    LI.Tax.OpenConfig()
  end
end

local function HandleEvent(_, event, arg1, arg2)
  local tax = LI.Tax
  if event == "PLAYER_LOGIN" or event == "VARIABLES_LOADED" then
    InitTax()
  elseif event == "PLAYER_MONEY" and tax.OnPlayerMoney then
    tax.OnPlayerMoney()
  elseif (event == "CHAT_MSG_MONEY" or event == "CHAT_MSG_SYSTEM") and tax.OnMoneyMessage then
    tax.OnMoneyMessage(event, arg1)
  elseif event == "MERCHANT_SHOW" and tax.OnMerchantShow then
    tax.OnMerchantShow()
  elseif event == "MERCHANT_CLOSED" and tax.OnMerchantClosed then
    tax.OnMerchantClosed()
  elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" and tax.OnInteraction then
    tax.OnInteraction(true, arg1)
  elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" and tax.OnInteraction then
    tax.OnInteraction(false, arg1)
  elseif event == "BANKFRAME_OPENED" and tax.OnWarbankFrame then
    if IsStandaloneWarbankOpen() then
      tax.OnWarbankFrame(true)
    elseif C_Timer and type(C_Timer.After) == "function" then
      C_Timer.After(0.25, ProbeStandaloneWarbank)
      C_Timer.After(0.75, ProbeStandaloneWarbank)
    end
  elseif event == "GUILDBANKFRAME_OPENED" and tax.OnGuildBankFrameClassicEvent then
    tax.OnGuildBankFrameClassicEvent(event, false)
  elseif event == "GUILDBANKFRAME_CLOSED" and tax.OnGuildBankFrameClassicEvent then
    tax.OnGuildBankFrameClassicEvent(event, false)
  elseif event == "BANKFRAME_CLOSED" and tax.OnWarbankFrame then
    tax.OnWarbankFrame(false)
  end
end

local eventFrame = CreateFrame("Frame")
for _, event in ipairs({
  "PLAYER_LOGIN", "VARIABLES_LOADED", "PLAYER_MONEY", "CHAT_MSG_MONEY", "CHAT_MSG_SYSTEM",
  "MERCHANT_SHOW", "MERCHANT_CLOSED",
  "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", "PLAYER_INTERACTION_MANAGER_FRAME_HIDE",
  "BANKFRAME_OPENED", "GUILDBANKFRAME_OPENED", "GUILDBANKFRAME_CLOSED", "BANKFRAME_CLOSED",
}) do
  eventFrame:RegisterEvent(event)
end
eventFrame:SetScript("OnEvent", HandleEvent)

local function ToggleTaxWindow()
  if not LI.TaxStandaloneFrame then
    local frame = CreateFrame("Frame", "fr0z3nUI_TaxStandaloneFrame", UIParent, "BackdropTemplate")
    frame:SetSize(760, 440)
    frame:SetPoint("CENTER")
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:EnableKeyboard(true)
    frame:SetPropagateKeyboardInput(false)
    frame:SetScript("OnKeyDown", function(self, key)
      if key == "ESCAPE" then
        self:Hide()
      end
    end)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetBackdrop({
      bgFile = "Interface/Tooltips/UI-Tooltip-Background",
      tile = true,
      tileSize = 16,
      insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(0, 0, 0, 0.85)

    local tabBarBG = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    tabBarBG:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -4)
    tabBarBG:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
    tabBarBG:SetHeight(26)
    tabBarBG:SetBackdrop({
      bgFile = "Interface/Tooltips/UI-Tooltip-Background",
      tile = true,
      tileSize = 16,
      insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    tabBarBG:SetBackdropColor(0, 0, 0, 0.92)
    tabBarBG:SetFrameLevel((frame.GetFrameLevel and frame:GetFrameLevel() or 0) + 1)

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -6)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetParent(tabBarBG)
    title:SetPoint("LEFT", tabBarBG, "LEFT", 8, 0)
    title:SetText("|cff00ccff[FAX]|r")
    do
      local fontPath, fontSize, fontFlags = title:GetFont()
      if fontPath and fontSize then
        title:SetFont(fontPath, fontSize + 2, fontFlags)
      end
    end

    local panel = CreateFrame("Frame", nil, frame)
    panel:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -34)
    panel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)

    if type(LI.Tax.BuildTab_UI) == "function" then
      LI.Tax.BuildTab_UI(panel, {
        EnsureDB = InitTax,
        GetDB = function() return db end,
        GetCharDB = function() return charDB end,
        Clamp = function(value, minimum, maximum)
          value = tonumber(value)
          if not value then return minimum end
          if minimum and value < minimum then return minimum end
          if maximum and value > maximum then return maximum end
          return value
        end,
      })
    end
    LI.TaxStandaloneFrame = frame
  end

  local frame = LI.TaxStandaloneFrame
  if frame:IsShown() then frame:Hide() else frame:Show() end
end

LI.Tax.OpenConfig = ToggleTaxWindow

SLASH_FROZENUITAX1 = "/ftax"
SLASH_FROZENUITAX2 = "/fax"
SlashCmdList.FROZENUITAX = ToggleTaxWindow