local addonName, ns = ...
if type(ns) ~= "table" then ns = {} end

local LI = (ns and ns.LootIt) or {}
ns.LootIt = LI
fr0z3nUI_LootIt = LI
LI.ADDON = LI.ADDON or addonName

LI.Trade = LI.Trade or {}

local function SafeCall(fn, ...)
  if type(fn) == "function" then
    return fn(...)
  end
end

local function IsTradeDebugEnabled(env)
  local e = env or {}
  local DB = SafeCall(e.GetDB)
  return (DB and DB.deposit and DB.deposit.tradeDebug == true) and true or false
end

-- Slash handler for Trade/Deposit surface commands.
-- Kept here for portability (so /fli dispatcher can remain a thin delegator).
function LI.Trade.HandleSlash(cmd, rest, env)
  cmd = tostring(cmd or ""):lower()
  local e = env or {}

  if cmd == "deposit" then
    local Print = e.Print

    local function PrintLine(msg)
      msg = tostring(msg or "")
      local c = _G and rawget(_G, "DEFAULT_CHAT_FRAME")
      if c and c.AddMessage then
        c:AddMessage(msg)
        return
      end
      SafeCall(Print, msg)
    end

    local sub = tostring(rest or "")
    local t1 = sub:match("^(%S+)")
    t1 = (t1 and t1:lower()) or ""
    local t2 = sub:match("^%S+%s+(%S+)")
    t2 = (t2 and t2:lower()) or ""

    local mode = "run"
    local targetArg = nil
    if t1 == "status" or t1 == "debug" then
      mode = t1
      targetArg = (t2 ~= "") and t2 or nil
    elseif t1 ~= "" then
      targetArg = t1
    end

    if mode == "status" or mode == "debug" then
      local rep = (LI and type(LI.GetDepositReport) == "function") and LI.GetDepositReport(targetArg) or nil
      if type(rep) ~= "table" then
        PrintLine("Deposit: status unavailable (missing report generator)")
        return true
      end

      local bo = rep.bankOpen or {}
      local cts = rep.counts or {}
      PrintLine(string.format(
        "Deposit status: open(guild=%s warbank=%s personal=%s) target=%s resolved=%s list=%s effective=%s realm=%s",
        tostring(bo.guild == true), tostring(bo.warbank == true), tostring(bo.personal == true),
        tostring(rep.normalizedTarget), tostring(rep.resolvedDest or ""), tostring(rep.listTarget), tostring(cts.effective), tostring(rep.realmKey)
      ))

      if mode == "debug" then
        local function F(k)
          local v = cts[k]
          if type(v) == "table" then
            return tostring(v.on) .. "/" .. tostring(v.all)
          end
          return tostring(v)
        end

        PrintLine("Deposit debug: acc=" .. F("accItems") .. " accDis=" .. F("accItemsDisabled") .. " accRealmDis=" .. F("accDisableRealm")
          .. " realm=" .. F("realmItems") .. " realmDis=" .. F("realmDisabled"))
        PrintLine("Deposit debug: char=" .. F("chItems") .. " charDis=" .. F("chItemsDisabled") .. " charAccDis=" .. F("chDisableAcc")
          .. " charRealmDis=" .. F("chDisableRealm"))

        do
          local fns = rep.cBankFns
          local parts = {}
          if type(fns) == "table" then
            parts[#parts + 1] = "DepositItem=" .. tostring(fns.DepositItem == true)
            parts[#parts + 1] = "Char=" .. tostring(fns.DepositToCharacterBank == true)
            parts[#parts + 1] = "Pers=" .. tostring(fns.DepositToPersonalBank == true)
            parts[#parts + 1] = "Acct=" .. tostring(fns.DepositToAccountBank == true)
          end
          PrintLine("Deposit debug: bankUIShown=" .. tostring(rep.bankUIShown == true)
            .. " bankType=" .. tostring(rep.bankType)
            .. " bankTypeName=" .. tostring(rep.bankTypeName)
            .. (parts[1] and (" C_Bank{" .. table.concat(parts, " ") .. "}") or ""))
        end

        do
          local by = cts.effectiveByDest
          if type(by) == "table" then
            PrintLine("Deposit debug: effectiveByDest bank=" .. tostring(by.bank or 0)
              .. " personal=" .. tostring(by.personal or 0)
              .. " guild=" .. tostring(by.guild or 0)
              .. " warbank=" .. tostring(by.warbank or 0))
          end
        end

        local sample = rep.sampleIDs
        if type(sample) == "table" and #sample > 0 then
          local parts = {}
          for i = 1, #sample do
            local id = sample[i]
            local link = nil
            if type(GetItemInfo) == "function" then
              local ok, name, itemLink = pcall(GetItemInfo, id)
              if ok and type(itemLink) == "string" and itemLink ~= "" then
                link = itemLink
              elseif ok and type(name) == "string" and name ~= "" then
                link = name
              end
            end
            parts[#parts + 1] = link or tostring(id)
          end
          PrintLine("Deposit sample: " .. table.concat(parts, ", "))
        end
      end
      return true
    end

    -- Macro friendly: only does something when bank UI is open.
    SafeCall(e.RunDeposit, targetArg)
    return true
  end

  if cmd == "food" then
    SafeCall(e.EnsureDB)
    local DB = SafeCall(e.GetDB)
    local CHARDB = SafeCall(e.GetCharDB)

    local Print = e.Print
    local DebugSellOldFoodAtMerchant = e.DebugSellOldFoodAtMerchant or (LI and LI.DebugSellOldFoodAtMerchant)

    local sub = tostring(rest or "")
    local subCmd = sub:match("^(%S+)")
    subCmd = (subCmd and subCmd:lower()) or ""

    local diff = (DB and DB.deposit and tonumber(DB.deposit.sellFoodLevelDiff)) or 10
    diff = diff and math.floor(diff) or 10
    if diff < 1 then diff = 1 end
    if diff > 80 then diff = 80 end

    local onAcc = (DB and DB.deposit and DB.deposit.sellFoodEnabledAcc == true) and true or false
    local onChar = (CHARDB and CHARDB.deposit and CHARDB.deposit.sellFoodEnabledChar == true) and true or false
    local effective = onAcc or onChar
    local state = onAcc and "On Acc" or (onChar and "On" or "Off")

    if subCmd == "debug" then
      SafeCall(DebugSellOldFoodAtMerchant, diff, 30)
      return true
    end

    SafeCall(Print, string.format("Food selling: %s (effective=%s, diff=%d)", state, tostring(effective), diff))
    SafeCall(Print, "Run: /fgo li food debug (prints why items are skipped)")
    return true
  end

  return false
end

-- Merchant lifecycle handlers (used by core OnEvent).
function LI.Trade.OnMerchantShow(env)
  local e = env or {}
  if IsTradeDebugEnabled(e) then
    local addon = (LI and LI.ADDON) or addonName
    local v
    do
      local api = _G and rawget(_G, "C_AddOns")
      if type(api) == "table" and type(api.GetAddOnMetadata) == "function" then
        local ok, r = pcall(api.GetAddOnMetadata, addon, "Version")
        if ok and type(r) == "string" and r ~= "" then v = r end
      end
    end
    if not v and type(GetAddOnMetadata) == "function" then
      local ok, r = pcall(GetAddOnMetadata, addon, "Version")
      if ok and type(r) == "string" and r ~= "" then v = r end
    end
    SafeCall(e.Print, "Merchant ticker: start (" .. tostring(v or "?") .. ")")
  end
  SafeCall(e.StartMerchantTradeTicker)
  local tax = e.Tax or (LI and LI.Tax)
  if tax and type(tax.OnMerchantShow) == "function" then
    SafeCall(tax.OnMerchantShow)
  end
end

function LI.Trade.OnMerchantClosed(env)
  local e = env or {}
  if IsTradeDebugEnabled(e) then
    SafeCall(e.Print, "Merchant ticker: stop")
  end
  SafeCall(e.StopMerchantTradeTicker)

  local DB = SafeCall(e.GetDB)
  if DB and DB.delayPrint and DB.delayPrint.flushOnMerchantClose then
    local flushedLines = SafeCall(e.DelayPrintFlushAll)
    if IsTradeDebugEnabled(e) then
      if type(flushedLines) == "number" then
        SafeCall(e.Print, "DelayPrint flush: " .. tostring(flushedLines) .. " line(s)")
      else
        SafeCall(e.Print, "DelayPrint flush: (unavailable)")
      end
    end
  end

  local tax = e.Tax or (LI and LI.Tax)
  if tax and type(tax.OnMerchantClosed) == "function" then
    SafeCall(tax.OnMerchantClosed)
  end
end

-- Bank/deposit lifecycle handlers live in fUI_GOTradeBank.lua.


-- UI builder extracted into fUI_GOTradeUI.lua
function LI.Trade.BuildTab(depositPanel)
  local fn = LI and LI.Trade and LI.Trade.BuildTab_UI
  if type(fn) == "function" then
    return fn(depositPanel)
  end
end

-- Vendor buy/sell/restock (merchant open)
-- Copied from live Host (then removed from Host in dev) so trade logic lives in Trade.
do
  local function EnsureDB()
    if LI and type(LI.EnsureDB) == "function" then
      LI.EnsureDB()
    end
  end

  local function DepositCfgAcc()
    if LI and type(LI.DepositCfgAcc) == "function" then
      return LI.DepositCfgAcc()
    end
    return {}
  end

  local function DepositCfgChar()
    if LI and type(LI.DepositCfgChar) == "function" then
      return LI.DepositCfgChar()
    end
    return {}
  end

  local function GetDB()
    if LI and type(LI.GetDB) == "function" then
      return LI.GetDB()
    end
    return nil
  end

  local function GetCharDB()
    if LI and type(LI.GetCharDB) == "function" then
      return LI.GetCharDB()
    end
    return nil
  end

  local function Print(msg)
    if LI and type(LI.Print) == "function" then
      LI.Print(msg)
    end
  end

  local function GetCurrentRealmKey()
    local rn = (type(GetRealmName) == "function") and GetRealmName() or nil
    rn = (type(rn) == "string" and rn ~= "") and rn or ""
    return rn
  end

  local DB
  local CHARDB
  local function SyncDB()
    EnsureDB()
    DB = GetDB()
    CHARDB = GetCharDB()

    -- Keep merchant debug in sync with the same toggle that prints
    -- "Merchant ticker: start" so users don't have to manage two flags.
    if LI and LI.Trade and DB and DB.deposit then
      LI.Trade._debugOn = (DB.deposit.tradeDebug == true) and true or false
    end
  end

  local function NormalizeTradeMode(mode)
    local m = tostring(mode or ""):lower():gsub("%s+", "")
    if m ~= "deposit" and m ~= "buy" and m ~= "sell" then
      m = "deposit"
    end
    return m
  end

  local function GetTradeMode()
    local cfg = DepositCfgAcc()
    return NormalizeTradeMode(cfg and cfg.tradeMode)
  end

  local function NormalizeRule(v)
    if v == nil then return nil end
    if type(v) == "number" then
      return { count = math.floor(v) }
    end
    if type(v) == "table" then
      local c = tonumber(v.count)
      if c == nil then c = tonumber(v[1]) end
      c = c and math.floor(c) or nil
      local r = (v.restock == true)
      if c == nil and r ~= true then return nil end
      return { count = c, restock = r }
    end
    return nil
  end

  local function GetItemNameSafe(itemID)
    itemID = tonumber(itemID)
    if not itemID or itemID <= 0 then return nil end
    if C_Item and type(C_Item.GetItemNameByID) == "function" then
      local ok, name = pcall(C_Item.GetItemNameByID, itemID)
      if ok and type(name) == "string" and name ~= "" then
        return name
      end
    end
    if type(GetItemInfo) == "function" then
      local name = GetItemInfo(itemID)
      if type(name) == "string" and name ~= "" then
        return name
      end
    end
    return nil
  end

  local function GetItemLinkSafe(itemID)
    itemID = tonumber(itemID)
    if not itemID or itemID <= 0 then return nil end
    if type(GetItemInfo) == "function" then
      local ok, name, link = pcall(GetItemInfo, itemID)
      if ok and type(link) == "string" and link ~= "" then
        return link
      end
      if ok and type(name) == "string" and name ~= "" then
        return name
      end
    end
    return GetItemNameSafe(itemID) or tostring(itemID)
  end

  local function StripLinkBrackets(s)
    if type(s) ~= "string" then return s end
    s = s:gsub("(|h)%[(.-)%](|h)", "%1%2%3")
    return s
  end

  local RAID_CLASS_COLORS = _G and rawget(_G, "RAID_CLASS_COLORS")

  local function GetClassColoredPlayerName()
    local n = (UnitName and UnitName("player")) or ""
    n = tostring(n or "")
    local short = n:match("^(.-)%-%") or n
    if short == "" then short = "Player" end

    local classFile = nil
    if type(UnitClass) == "function" then
      local _, c = UnitClass("player")
      classFile = c
    end

    local r, g, b = 1, 1, 1
    if classFile and type(C_ClassColor) == "table" and type(C_ClassColor.GetClassColor) == "function" then
      local ok, colorObj = pcall(C_ClassColor.GetClassColor, classFile)
      if ok and type(colorObj) == "table" then
        if type(colorObj.GetRGB) == "function" then
          local rr, gg, bb = colorObj:GetRGB()
          r, g, b = tonumber(rr) or r, tonumber(gg) or g, tonumber(bb) or b
        elseif type(colorObj.r) == "number" then
          r, g, b = colorObj.r or r, colorObj.g or g, colorObj.b or b
        end
      end
    elseif classFile and type(RAID_CLASS_COLORS) == "table" and type(RAID_CLASS_COLORS[classFile]) == "table" then
      local c = RAID_CLASS_COLORS[classFile]
      r, g, b = tonumber(c.r) or r, tonumber(c.g) or g, tonumber(c.b) or b
    end

    local function toHex(x)
      x = tonumber(x) or 0
      if x < 0 then x = 0 end
      if x > 1 then x = 1 end
      return string.format("%02x", math.floor(x * 255 + 0.5))
    end

    return "|cff" .. toHex(r) .. toHex(g) .. toHex(b) .. short .. ":|r"
  end

  local function FormatGoldOnly(totalCopper)
    local copper = tonumber(totalCopper) or 0
    if copper < 0 then copper = 0 end
    local gold = math.floor(copper / 10000)
    if gold < 1 then gold = 1 end
    return tostring(gold) .. "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t"
  end

  local function GetRealmRuleTable(cfg, mode)
    local rk = GetCurrentRealmKey()
    if rk == "" then return nil, nil end
    if mode == "buy" then
      cfg.buyItemsRealm = (type(cfg.buyItemsRealm) == "table") and cfg.buyItemsRealm or {}
      cfg.buyItemsRealm[rk] = (type(cfg.buyItemsRealm[rk]) == "table") and cfg.buyItemsRealm[rk] or {}
      return cfg.buyItemsRealm[rk], rk
    end
    if mode == "sell" then
      cfg.sellItemsRealm = (type(cfg.sellItemsRealm) == "table") and cfg.sellItemsRealm or {}
      cfg.sellItemsRealm[rk] = (type(cfg.sellItemsRealm[rk]) == "table") and cfg.sellItemsRealm[rk] or {}
      return cfg.sellItemsRealm[rk], rk
    end
    cfg.itemsRealm = (type(cfg.itemsRealm) == "table") and cfg.itemsRealm or {}
    cfg.itemsRealm[rk] = (type(cfg.itemsRealm[rk]) == "table") and cfg.itemsRealm[rk] or {}
    return cfg.itemsRealm[rk], rk
  end

  local function GetScopeStores(mode)
    local cfg = DepositCfgAcc()
    local ch = DepositCfgChar()
    local realmTbl, realmKey = GetRealmRuleTable(cfg, mode)
    if mode == "buy" then
      return cfg.buyItemsAcc, realmTbl, realmKey, ch.buyItemsChar, ch.buyDisableAcc
    end
    if mode == "sell" then
      return cfg.sellItemsAcc, realmTbl, realmKey, ch.sellItemsChar, ch.sellDisableAcc
    end
    return cfg.itemsAcc, realmTbl, realmKey, ch.itemsChar, ch.disableAcc
  end

  local function GetEffectiveTradeRules(mode)
    mode = NormalizeTradeMode(mode)
    local accTbl, realmTbl, realmKey, charTbl, disableAccTbl = GetScopeStores(mode)
    local out = {}

    local cfg = DepositCfgAcc()
    local ch = DepositCfgChar()

    local accDisabledTbl = nil
    local accDisableRealmTbl = nil
    local realmDisabledTbl = nil
    local charDisabledTbl = nil
    local disableRealmTbl = nil

    if mode == "buy" then
      accDisabledTbl = cfg.buyItemsAccDisabled
      accDisableRealmTbl = (type(cfg.buyItemsAccDisableRealm) == "table" and realmKey and realmKey ~= "") and cfg.buyItemsAccDisableRealm[realmKey] or nil
      realmDisabledTbl = (type(cfg.buyItemsRealmDisabled) == "table" and realmKey and realmKey ~= "") and cfg.buyItemsRealmDisabled[realmKey] or nil
      charDisabledTbl = ch.buyItemsCharDisabled
      disableRealmTbl = ch.buyDisableRealm
    elseif mode == "sell" then
      accDisabledTbl = cfg.sellItemsAccDisabled
      accDisableRealmTbl = (type(cfg.sellItemsAccDisableRealm) == "table" and realmKey and realmKey ~= "") and cfg.sellItemsAccDisableRealm[realmKey] or nil
      realmDisabledTbl = (type(cfg.sellItemsRealmDisabled) == "table" and realmKey and realmKey ~= "") and cfg.sellItemsRealmDisabled[realmKey] or nil
      charDisabledTbl = ch.sellItemsCharDisabled
      disableRealmTbl = ch.sellDisableRealm
    else
      accDisabledTbl = cfg.itemsAccDisabled
      accDisableRealmTbl = (type(cfg.itemsAccDisableRealm) == "table" and realmKey and realmKey ~= "") and cfg.itemsAccDisableRealm[realmKey] or nil
      realmDisabledTbl = (type(cfg.itemsRealmDisabled) == "table" and realmKey and realmKey ~= "") and cfg.itemsRealmDisabled[realmKey] or nil
      charDisabledTbl = ch.itemsCharDisabled
      disableRealmTbl = ch.disableRealm
    end

    local function setFrom(tbl, isAccount, isRealm, isChar)
      if type(tbl) ~= "table" then return end
      for id, v in pairs(tbl) do
        id = tonumber(id)
        if id and id > 0 then
          if isAccount and ((type(accDisabledTbl) == "table" and accDisabledTbl[id] == true) or (type(accDisableRealmTbl) == "table" and accDisableRealmTbl[id] == true) or (type(disableAccTbl) == "table" and disableAccTbl[id] == true)) then
            -- skip
          elseif isRealm and ((type(realmDisabledTbl) == "table" and realmDisabledTbl[id] == true) or (type(disableRealmTbl) == "table" and disableRealmTbl[id] == true)) then
            -- skip
          elseif isChar and (type(charDisabledTbl) == "table" and charDisabledTbl[id] == true) then
            -- skip
          else
            if mode == "deposit" then
              if v == true then
                out[id] = { on = true }
              end
            else
              local r = NormalizeRule(v)
              if r and r.count ~= nil then
                out[id] = { count = r.count, restock = r.restock == true }
              end
            end
          end
        end
      end
    end

    -- Priority: Account -> Realm -> Character
    setFrom(accTbl, true, false, false)
    setFrom(realmTbl, false, true, false)
    setFrom(charTbl, false, false, true)
    return out
  end

  local function IterateBagSlots(cb)
    local bagIDs = { 0, 1, 2, 3, 4 }
    local e = (Enum and Enum.BagIndex) and Enum.BagIndex or nil
    if type(e) == "table" then
      bagIDs[#bagIDs + 1] = rawget(e, "ReagentBag")
    else
      bagIDs[#bagIDs + 1] = 5
    end

    local seen = {}
    for i = 1, #bagIDs do
      local bag = tonumber(bagIDs[i])
      if bag ~= nil and not seen[bag] then
        seen[bag] = true
        local n = 0
        if C_Container and type(C_Container.GetContainerNumSlots) == "function" then
          local ok, v = pcall(C_Container.GetContainerNumSlots, bag)
          n = ok and tonumber(v) or 0
        end
        if n and n > 0 then
          for slot = 1, n do
            cb(bag, slot)
          end
        end
      end
    end
  end

  local function GetBagItemInfo(bag, slot)
    if C_Container and type(C_Container.GetContainerItemInfo) == "function" then
      local ok, v = pcall(C_Container.GetContainerItemInfo, bag, slot)
      return ok and v or nil
    end
    return nil
  end

  local function UseContainerItemSafe(bag, slot)
    if C_Container and type(C_Container.UseContainerItem) == "function" then
      pcall(C_Container.UseContainerItem, bag, slot)
      return
    end
    local uci = _G and _G["UseContainerItem"]
    if type(uci) == "function" then
      pcall(uci, bag, slot)
    end
  end

  local function CountItemInBags(itemID)
    itemID = tonumber(itemID)
    if not itemID or itemID <= 0 then return 0 end
    local total = 0
    IterateBagSlots(function(bag, slot)
      local info = GetBagItemInfo(bag, slot)
      if info and tonumber(info.itemID) == itemID then
        local stack = tonumber(info.stackCount)
        total = total + (stack or 1)
      end
    end)
    return total
  end

  local function GetItemMaxStackSafe(itemID)
    itemID = tonumber(itemID)
    if not itemID or itemID <= 0 then return nil end

    if C_Item and type(C_Item.GetItemMaxStackSizeByID) == "function" then
      local ok, v = pcall(C_Item.GetItemMaxStackSizeByID, itemID)
      if ok and type(v) == "number" then
        v = math.floor(v)
        if v < 1 then v = 1 end
        return v
      end
    end

    if C_Item and type(C_Item.GetItemMaxStackSize) == "function" then
      local ok, v = pcall(C_Item.GetItemMaxStackSize, itemID)
      if ok and type(v) == "number" then
        v = math.floor(v)
        if v < 1 then v = 1 end
        return v
      end
    end

    if type(GetItemInfo) == "function" then
      local ok, _, _, _, _, _, _, stackCount = pcall(GetItemInfo, itemID)
      if ok and type(stackCount) == "number" then
        stackCount = math.floor(stackCount)
        if stackCount < 1 then stackCount = 1 end
        return stackCount
      end
    end

    return nil
  end

  -- Buy-mode count: prefer API count (includes equipped) so Unique(1) items
  -- don't cause repeated buy attempts when the only copy is equipped.
  local function CountItemOwnedNoBank(itemID)
    itemID = tonumber(itemID)
    if not itemID or itemID <= 0 then return 0 end

    if C_Item and type(C_Item.GetItemCount) == "function" then
      local ok, v = pcall(C_Item.GetItemCount, itemID, false)
      if ok and type(v) == "number" then
        v = math.floor(v)
        if v < 0 then v = 0 end
        return v
      end
    end

    if type(GetItemCount) == "function" then
      local ok, v = pcall(GetItemCount, itemID, false)
      if ok and type(v) == "number" then
        v = math.floor(v)
        if v < 0 then v = 0 end
        return v
      end
    end

    -- Fallback: bags only.
    return CountItemInBags(itemID)
  end

  local function IsItemDataCachedByID(itemID)
    itemID = tonumber(itemID)
    if not itemID or itemID <= 0 then return false end
    if C_Item then
      if type(C_Item.IsItemDataCachedByID) == "function" then
        local ok, cached = pcall(C_Item.IsItemDataCachedByID, itemID)
        if ok and cached == true then
          return true
        end
      end
      if type(C_Item.IsItemDataCached) == "function" then
        local ok, cached = pcall(C_Item.IsItemDataCached, itemID)
        if ok and cached == true then
          return true
        end
      end

      if type(C_Item.GetItemNameByID) == "function" then
        local okN, name = pcall(C_Item.GetItemNameByID, itemID)
        if okN and type(name) == "string" and name ~= "" then
          return true
        end
      end
    end

    if type(GetItemInfo) == "function" then
      local okI, name, link = pcall(GetItemInfo, itemID)
      if okI and ((type(link) == "string" and link ~= "") or (type(name) == "string" and name ~= "")) then
        return true
      end
    end

    return false
  end

  local _useKeyCacheByID = {}
  local _foodUseCacheByID = {}
  local _foodHealthRateCacheByID = {}
  local _liMerchantWantsCache = false

  local function GetMerchantItemLinkSafe(i)
    i = tonumber(i)
    if not i or i <= 0 then return nil end

    if type(GetMerchantItemLink) == "function" then
      local ok, link = pcall(GetMerchantItemLink, i)
      if ok and type(link) == "string" and link ~= "" then
        return link
      end
    end

    if C_MerchantFrame and type(C_MerchantFrame.GetItemLink) == "function" then
      local ok, link = pcall(C_MerchantFrame.GetItemLink, i)
      if ok and type(link) == "string" and link ~= "" then
        return link
      end
    end

    return nil
  end

  local function GetMerchantItemIDSafe(i)
    i = tonumber(i)
    if not i or i <= 0 then return nil end

    local link = GetMerchantItemLinkSafe(i)
    if type(link) == "string" and link ~= "" then
      local id = link:match("item:(%d+)")
      id = id and tonumber(id) or nil
      if id and id > 0 then
        return id
      end
    end

    if C_MerchantFrame and type(C_MerchantFrame.GetItemInfo) == "function" then
      local ok, info = pcall(C_MerchantFrame.GetItemInfo, i)
      if ok and type(info) == "table" then
        local id = tonumber(info.itemID)
        if id and id > 0 then
          return id
        end
      end
    end

    return nil
  end

  local function IsFoodDrinkItemID(itemID)
    itemID = tonumber(itemID)
    if not itemID or itemID <= 0 then return false end
    if not (C_Item and type(C_Item.GetItemInfoInstant) == "function") then return false end
    local ok, _, _, _, _, _, classID, subClassID = pcall(C_Item.GetItemInfoInstant, itemID)
    if not ok then return false end
    return (tonumber(classID) == 0) and (tonumber(subClassID) == 5)
  end

  local function NormalizeUseText_Generic(s)
    if type(s) ~= "string" then return nil end
    local t = s:lower()
    local p = t:find("use:", 1, true)
    if p then
      t = t:sub(p)
    end
    t = t:gsub("^use:%s*", "")
    t = t:gsub("%d+", "")
    t = t:gsub("[%p%c]", " ")
    t = t:gsub("%s+", " ")
    t = t:gsub("^%s+", "")
    t = t:gsub("%s+$", "")
    if t == "" then return nil end
    return t
  end

  local function CleanTooltipText(s)
    if type(s) ~= "string" then return s end
    s = s:gsub("|c%x%x%x%x%x%x%x%x", "")
    s = s:gsub("|r", "")
    s = s:gsub("|T.-|t", "")
    s = s:gsub("^%s+", "")
    s = s:gsub("%s+$", "")
    return s
  end

  local function ParseFoodDrinkUseLine(s)
    if type(s) ~= "string" or s == "" then return nil end
    s = CleanTooltipText(s)
    local low = s:lower()
    local p = low:find("use:", 1, true)
    if not p then return nil end
    low = low:sub(p)
    if not low:find("restores", 1, true) then return nil end
    local healthPct = low:match("restores%s+(%d+)%s*%%%s*of your health")
    healthPct = healthPct and tonumber(healthPct) or nil
    local manaPct = low:match("restores%s+(%d+)%s*%%%s*of your mana")
    manaPct = manaPct and tonumber(manaPct) or nil

    local function ToNum(v)
      if type(v) ~= "string" then return nil end
      v = v:gsub(",", "")
      return tonumber(v)
    end

    local hasHealth = (healthPct ~= nil)
    local hasMana = (manaPct ~= nil)

    -- Fallback for phrasing that doesn't repeat "of your" for both.
    if (not healthPct) and (not manaPct) then
      local pct = low:match("restores%s+(%d+)%s*%%")
      pct = pct and tonumber(pct) or nil
      if not pct then return nil end
      -- Only use the generic % fallback if the line explicitly indicates health and/or mana.
      local mentionsHealth = (low:find("health", 1, true) ~= nil)
      local mentionsMana = (low:find("mana", 1, true) ~= nil)
      if (not mentionsHealth) and (not mentionsMana) then return nil end
      if mentionsHealth then healthPct = pct end
      if mentionsMana then manaPct = pct end
      hasHealth = (healthPct ~= nil)
      hasMana = (manaPct ~= nil)
    end

    -- Flat restore fallback used by most modern vendor food/drink.
    if (not hasHealth) and (not hasMana) then
      local mentionsHealth = (low:find("health", 1, true) ~= nil)
      local mentionsMana = (low:find("mana", 1, true) ~= nil)
      if mentionsHealth or mentionsMana then
        local flatHealth = low:match("restores%s+(%d[%d,%.]*)%s+health")
        local flatMana = low:match("restores%s+(%d[%d,%.]*)%s+mana")

        if flatHealth == nil then
          flatHealth = low:match("and%s+(%d[%d,%.]*)%s+health")
        end
        if flatMana == nil then
          flatMana = low:match("and%s+(%d[%d,%.]*)%s+mana")
        end

        local sharedFlat = nil
        if flatHealth == nil and flatMana == nil then
          sharedFlat = ToNum(low:match("restores%s+(%d[%d,%.]*)"))
        end

        local hpMax = (type(UnitHealthMax) == "function") and (tonumber(UnitHealthMax("player")) or 0) or 0
        if hpMax <= 0 then hpMax = 1 end

        local manaType = 0
        if Enum and type(Enum.PowerType) == "table" and type(Enum.PowerType.Mana) == "number" then
          manaType = Enum.PowerType.Mana
        end
        local manaMax = (type(UnitPowerMax) == "function") and (tonumber(UnitPowerMax("player", manaType)) or 0) or 0

        local flatHealthNum = ToNum(flatHealth) or ((mentionsHealth and sharedFlat) or nil)
        local flatManaNum = ToNum(flatMana) or ((mentionsMana and sharedFlat) or nil)

        if flatHealthNum and flatHealthNum > 0 then
          healthPct = (flatHealthNum / hpMax) * 100
        end
        if flatManaNum and flatManaNum > 0 and manaMax > 0 then
          manaPct = (flatManaNum / manaMax) * 100
        end

        hasHealth = (healthPct ~= nil)
        hasMana = (manaPct ~= nil)
      end
    end

    if (not hasHealth) and (not hasMana) then return nil end

    local pct = math.max(tonumber(healthPct) or 0, tonumber(manaPct) or 0)
    if pct <= 0 then return nil end

    local dur = low:match("over%s+(%d+)%s*sec") or low:match("for%s+(%d+)%s*sec")
    dur = dur and tonumber(dur) or nil

    return {
      pct = pct,
      healthPct = healthPct,
      manaPct = manaPct,
      dur = dur,
      hasHealth = hasHealth,
      hasMana = hasMana,
    }
  end

  local function GetFoodHealthRateForItemID(itemID)
    itemID = tonumber(itemID)
    if not itemID or itemID <= 0 then return nil end
    if _foodHealthRateCacheByID[itemID] ~= nil then
      return _foodHealthRateCacheByID[itemID]
    end

    if not IsItemDataCachedByID(itemID) then
      _liMerchantWantsCache = true
      if C_Item and type(C_Item.RequestLoadItemDataByID) == "function" then
        pcall(C_Item.RequestLoadItemDataByID, itemID)
      end
      return nil
    end

    local hpMax = (type(UnitHealthMax) == "function") and (tonumber(UnitHealthMax("player")) or 0) or 0
    if hpMax <= 0 then
      hpMax = 1
    end

    local function ToNum(s)
      if type(s) ~= "string" then return nil end
      s = s:gsub(",", "")
      return tonumber(s)
    end

    local best = 0
    local lastSec = nil

    local tipOk = false
    if C_TooltipInfo and type(C_TooltipInfo.GetHyperlink) == "function" then
      local ok, tip = pcall(C_TooltipInfo.GetHyperlink, "item:" .. tostring(itemID))
      if ok and type(tip) == "table" and type(tip.lines) == "table" then
        tipOk = true
        for _, line in ipairs(tip.lines) do
          local left = (type(line) == "table") and line.leftText or nil
          if type(left) == "string" and left ~= "" then
            local s = CleanTooltipText(left)
            local tl = tostring(s or ""):lower()

            do
              local sec = tl:match("over%s+(%d+)%s*sec") or tl:match("over%s+(%d+)%s*seconds")
              sec = sec and tonumber(sec) or nil
              if sec and sec > 0 and sec <= 120 then
                lastSec = sec
              end
            end

            -- Percent per-second patterns.
            do
              local pct = tl:match("(%d+)%s*%%%D+health%D+every%s+second")
              pct = pct and tonumber(pct) or nil
              if pct and pct > 0 then
                best = math.max(best, hpMax * (pct / 100))
              end
            end

            -- Percent over duration.
            do
              local pct, sec = tl:match("restores?%s+(%d+)%s*%%%D+health%D+over%s+(%d+)")
              pct = pct and tonumber(pct) or nil
              sec = sec and tonumber(sec) or nil
              if pct and sec and sec > 0 then
                best = math.max(best, (hpMax * (pct / 100)) / sec)
              end
            end

            -- Flat over duration.
            do
              local amt, sec = tl:match("restores?%s+(%d[%d,%.]*)%s+.-health.-over%s+(%d+)")
              local a = ToNum(amt)
              sec = sec and tonumber(sec) or nil
              if a and sec and sec > 0 then
                best = math.max(best, a / sec)
              end
            end

            -- Sec-first flat patterns.
            do
              local sec, amt = tl:match("over%s+(%d+)%s*sec.-restores?%s+(%d[%d,%.]*)%s+.-health")
              sec = sec and tonumber(sec) or nil
              local a = ToNum(amt)
              if a and sec and sec > 0 then
                best = math.max(best, a / sec)
              end
            end

            -- Continuation fallback: line has a number + health, use lastSec.
            if lastSec and lastSec > 0 and tl:find("health", 1, true) and (not tl:find("%", 1, true)) then
              local amt = tl:match("(%d[%d,%.]*)")
              local a = ToNum(amt)
              if a and a > 0 then
                best = math.max(best, a / lastSec)
              end
            end
          end
        end
      end
    end

    if not tipOk then
      _liMerchantWantsCache = true
      if C_Item and type(C_Item.RequestLoadItemDataByID) == "function" then
        pcall(C_Item.RequestLoadItemDataByID, itemID)
      end
      return nil
    end

    _foodHealthRateCacheByID[itemID] = best
    return best
  end

  local function GetFoodDrinkTupleForItemID(itemID)
    itemID = tonumber(itemID)
    if not itemID or itemID <= 0 then return nil end
    if _foodUseCacheByID[itemID] ~= nil then
      return _foodUseCacheByID[itemID]
    end

    if not IsItemDataCachedByID(itemID) then
      _liMerchantWantsCache = true
      if C_Item and type(C_Item.RequestLoadItemDataByID) == "function" then
        pcall(C_Item.RequestLoadItemDataByID, itemID)
      end
      return nil
    end

    if not IsFoodDrinkItemID(itemID) then
      _foodUseCacheByID[itemID] = false
      return nil
    end

    local tuple = nil
    local tipOk = false
    if C_TooltipInfo and type(C_TooltipInfo.GetHyperlink) == "function" then
      local ok, tip = pcall(C_TooltipInfo.GetHyperlink, "item:" .. tostring(itemID))
      if ok and type(tip) == "table" and type(tip.lines) == "table" then
        tipOk = true
        for _, line in ipairs(tip.lines) do
          local left = (type(line) == "table") and line.leftText or nil
          if type(left) == "string" then
            tuple = ParseFoodDrinkUseLine(left)
            if tuple then break end
          end
        end
      end
    end

    if not tipOk then
      -- Tooltip not ready yet (common right after login / first merchant open).
      -- Don't cache a false-negative; ask for cache and retry on a later tick.
      _liMerchantWantsCache = true
      if C_Item and type(C_Item.RequestLoadItemDataByID) == "function" then
        pcall(C_Item.RequestLoadItemDataByID, itemID)
      end
      return nil
    end

    _foodUseCacheByID[itemID] = tuple or false
    return tuple
  end

  local function GetFoodDrinkCategoryKey(tuple)
    if type(tuple) ~= "table" then return nil end
    if tuple.hasHealth and tuple.hasMana then
      return "fooddrink"
    end
    if tuple.hasMana then
      return "drink"
    end
    if tuple.hasHealth then
      return "food"
    end
    return nil
  end

  local function FoodDrinkScore(tuple)
    if type(tuple) ~= "table" then return nil end
    local pct = tonumber(tuple.pct) or nil
    if not pct then
      pct = math.max(tonumber(tuple.healthPct) or 0, tonumber(tuple.manaPct) or 0)
      if pct <= 0 then return nil end
    end
    local dur = tonumber(tuple.dur) or 20
    if dur <= 0 then dur = 20 end
    return pct * dur
  end

  local function GetUseKeyForItemID(itemID)
    itemID = tonumber(itemID)
    if not itemID or itemID <= 0 then return nil end

    if _useKeyCacheByID[itemID] ~= nil then
      return _useKeyCacheByID[itemID]
    end

    if not IsItemDataCachedByID(itemID) then
      _liMerchantWantsCache = true
      if C_Item and type(C_Item.RequestLoadItemDataByID) == "function" then
        pcall(C_Item.RequestLoadItemDataByID, itemID)
      end
      return nil
    end

    local fd = GetFoodDrinkTupleForItemID(itemID)
    if type(fd) == "table" then
      local score = FoodDrinkScore(fd) or 0
      local k = (GetFoodDrinkCategoryKey(fd) or "foodrestores") .. "|score:" .. tostring(score)
      _useKeyCacheByID[itemID] = k
      return k
    end

    local useLines = {}
    local hasMana = false
    local tipOk = false

    if C_TooltipInfo and type(C_TooltipInfo.GetHyperlink) == "function" then
      local ok, tip = pcall(C_TooltipInfo.GetHyperlink, "item:" .. tostring(itemID))
      if ok and type(tip) == "table" and type(tip.lines) == "table" then
        tipOk = true
        for _, line in ipairs(tip.lines) do
          local left = (type(line) == "table") and line.leftText or nil
          if type(left) == "string" and left:find("^Use:", 1) then
            local norm = NormalizeUseText_Generic(left)
            if norm then
              useLines[#useLines + 1] = norm
              if norm:find("mana", 1, true) then hasMana = true end
            end
          end
        end
      end
    end

    if not tipOk then
      -- Tooltip not ready: don't cache a false negative.
      _liMerchantWantsCache = true
      if C_Item and type(C_Item.RequestLoadItemDataByID) == "function" then
        pcall(C_Item.RequestLoadItemDataByID, itemID)
      end
      return nil
    end

    if #useLines == 0 then
      _useKeyCacheByID[itemID] = false
      return nil
    end
    local out = table.concat(useLines, " ") .. "|mana:" .. (hasMana and "1" or "0")
    _useKeyCacheByID[itemID] = out
    return out
  end

  local function PrewarmTradeItemCache(itemID)
    itemID = tonumber(itemID)
    if not itemID or itemID <= 0 then return end

    if C_Item and type(C_Item.RequestLoadItemDataByID) == "function" then
      pcall(C_Item.RequestLoadItemDataByID, itemID)
    end

    if type(GetItemInfo) == "function" then
      pcall(GetItemInfo, itemID)
    end

    if C_TooltipInfo and type(C_TooltipInfo.GetHyperlink) == "function" then
      pcall(C_TooltipInfo.GetHyperlink, "item:" .. tostring(itemID))
    end

    pcall(GetFoodDrinkTupleForItemID, itemID)
    pcall(GetUseKeyForItemID, itemID)
  end

  LI.Trade = LI.Trade or {}
  do
    local cfg = DepositCfgAcc and DepositCfgAcc() or nil
    if cfg and cfg.tradeDebug ~= nil then
      LI.Trade._debugOn = (cfg.tradeDebug == true)
    end
  end
  LI.Trade.PrewarmItem = PrewarmTradeItemCache
  LI.Trade.IsItemDataCachedByID = IsItemDataCachedByID
  LI.Trade.GetFoodDrinkTupleForItemID = GetFoodDrinkTupleForItemID
  LI.Trade.GetUseKeyForItemID = GetUseKeyForItemID

  local function CountFoodDrinkAtOrAboveInBags(categoryKey, minScore)
    if type(categoryKey) ~= "string" or categoryKey == "" then return 0 end
    minScore = tonumber(minScore) or 0
    local total = 0
    IterateBagSlots(function(bag, slot)
      local info = GetBagItemInfo(bag, slot)
      local itemID = info and tonumber(info.itemID) or nil
      if itemID then
        local t = GetFoodDrinkTupleForItemID(itemID)
        if type(t) == "table" and GetFoodDrinkCategoryKey(t) == categoryKey then
          local sc = FoodDrinkScore(t) or 0
          if sc >= minScore then
            local stack = info and tonumber(info.stackCount) or nil
            total = total + (stack or 1)
          end
        end
      end
    end)
    return total
  end

  -- Forward declare: used by bag-scanning helpers below.
  local GetItemRequiredPlayerLevel

  local function GetMaxFoodDrinkScoreInBags(categoryKey)
    if type(categoryKey) ~= "string" or categoryKey == "" then return nil end
    local best = nil
    IterateBagSlots(function(bag, slot)
      local info = GetBagItemInfo(bag, slot)
      local itemID = info and tonumber(info.itemID) or nil
      if itemID then
        local t = GetFoodDrinkTupleForItemID(itemID)
        if type(t) == "table" and GetFoodDrinkCategoryKey(t) == categoryKey then
          local sc = FoodDrinkScore(t)
          if sc and ((not best) or sc > best) then
            best = sc
          end
        end
      end
    end)
    return best
  end

  local function GetBestFoodDrinkInBags(categoryKey)
    if type(categoryKey) ~= "string" or categoryKey == "" then return nil end
    local bestItemID, bestScore, bestReq = nil, nil, nil
    IterateBagSlots(function(bag, slot)
      local info = GetBagItemInfo(bag, slot)
      local itemID = info and tonumber(info.itemID) or nil
      if itemID then
        local t = GetFoodDrinkTupleForItemID(itemID)
        if type(t) == "table" and GetFoodDrinkCategoryKey(t) == categoryKey then
          local sc = FoodDrinkScore(t)
          if sc and ((not bestScore) or sc > bestScore) then
            bestScore = sc
            bestItemID = itemID
            bestReq = (GetItemRequiredPlayerLevel and GetItemRequiredPlayerLevel(itemID)) or nil
          end
        end
      end
    end)
    if not bestItemID then
      return nil
    end
    return { itemID = bestItemID, score = bestScore or 0, req = bestReq or 0 }
  end

  local function GetBestFoodByHealthRateInBags(playerLevel)
    playerLevel = tonumber(playerLevel) or nil
    local bestItemID, bestRate, bestReq = nil, nil, nil
    IterateBagSlots(function(bag, slot)
      local info = GetBagItemInfo(bag, slot)
      local itemID = info and tonumber(info.itemID) or nil
      if itemID and IsFoodDrinkItemID(itemID) then
        local req = (GetItemRequiredPlayerLevel and GetItemRequiredPlayerLevel(itemID)) or nil
        if (not playerLevel) or (not req) or (req <= playerLevel) then
          local rate = GetFoodHealthRateForItemID(itemID)
          if rate and ((not bestRate) or rate > bestRate) then
            bestRate = rate
            bestItemID = itemID
            bestReq = req
          end
        end
      end
    end)
    if not bestItemID then return nil end
    return { itemID = bestItemID, rate = bestRate or 0, req = bestReq or 0 }
  end

  local function PlayerUsesMana()
    -- Don't rely on UnitPowerType() alone: some specs/forms report a non-mana primary power
    -- (e.g. holy power), even though the character still has a mana pool and can drink.
    local manaType = 0
    if Enum and type(Enum.PowerType) == "table" and type(Enum.PowerType.Mana) == "number" then
      manaType = Enum.PowerType.Mana
    end

    if type(UnitPowerMax) == "function" then
      local ok, maxMana = pcall(UnitPowerMax, "player", manaType)
      maxMana = ok and tonumber(maxMana) or nil
      if maxMana and maxMana > 0 then
        return true
      end
    end

    if type(UnitPowerType) == "function" then
      local pt, token = UnitPowerType("player")
      if tonumber(pt) == manaType then
        return true
      end
      if type(token) == "string" and token:upper() == "MANA" then
        return true
      end
    end

    return false
  end

  local function CountEquivalentByUseKeyInBags(useKey)
    if type(useKey) ~= "string" or useKey == "" then return 0 end
    local total = 0
    IterateBagSlots(function(bag, slot)
      local info = GetBagItemInfo(bag, slot)
      local itemID = info and tonumber(info.itemID) or nil
      if itemID then
        local k = GetUseKeyForItemID(itemID)
        if k and k == useKey then
          local stack = info and tonumber(info.stackCount) or nil
          total = total + (stack or 1)
        end
      end
    end)
    return total
  end

  local function GetMerchantIndexForItemID(itemID)
    itemID = tonumber(itemID)
    if not itemID or itemID <= 0 then return nil end
    if type(GetMerchantNumItems) ~= "function" then return nil end
    local n = tonumber(GetMerchantNumItems()) or 0
    if n <= 0 then
      _liMerchantWantsCache = true
      return nil
    end
    local wantedName = GetItemNameSafe(itemID)
    wantedName = (type(wantedName) == "string" and wantedName ~= "") and wantedName:lower() or nil

    for i = 1, n do
      local id = GetMerchantItemIDSafe(i)
      if id == nil then
        _liMerchantWantsCache = true
        if wantedName and type(GetMerchantItemInfo) == "function" then
          local ok, name = pcall(GetMerchantItemInfo, i)
          if ok and type(name) == "string" and name ~= "" and name:lower() == wantedName then
            return i
          end
        end
      elseif id == itemID then
        return i
      end
    end
    return nil
  end

  GetItemRequiredPlayerLevel = function(itemID)
    itemID = tonumber(itemID)
    if not itemID or itemID <= 0 then return nil end
    if type(GetItemInfo) ~= "function" then return nil end
    -- GetItemInfo returns (name, link, quality, itemLevel, reqLevel, ...)
    local ok, _, _, _, _, reqLevel = pcall(GetItemInfo, itemID)
    if not ok then return nil end
    reqLevel = tonumber(reqLevel)
    if reqLevel and reqLevel > 0 then
      return reqLevel
    end
    return nil
  end

  LI.Trade = LI.Trade or {}
  LI.Trade.GetItemRequiredPlayerLevel = GetItemRequiredPlayerLevel

  local function IsItemUsableForPlayerLevel(itemID, playerLevel)
    itemID = tonumber(itemID)
    if not itemID or itemID <= 0 then return false end
    playerLevel = tonumber(playerLevel)
    if not playerLevel then
      return true
    end

    local reqLevel = GetItemRequiredPlayerLevel(itemID)
    if reqLevel == nil then
      if IsItemDataCachedByID(itemID) then
        reqLevel = 0
      else
        _liMerchantWantsCache = true
        if C_Item and type(C_Item.RequestLoadItemDataByID) == "function" then
          pcall(C_Item.RequestLoadItemDataByID, itemID)
        end
        return false
      end
    end
    if reqLevel > playerLevel then
      return false
    end

    return true
  end

  local _liMerchantDebugSummaryPrinted = false
  local _liMerchantDebugRulePrinted = false
  LI.Trade.ResetMerchantDebug = function()
    _liMerchantDebugSummaryPrinted = false
    _liMerchantDebugRulePrinted = false
  end

  local function GetBestMerchantFoodDrinkForCategory(categoryKey, usesMana)
    if type(categoryKey) ~= "string" or categoryKey == "" then return nil end
    if type(GetMerchantNumItems) ~= "function" then return nil end
    local n = tonumber(GetMerchantNumItems()) or 0
    if n <= 0 then
      _liMerchantWantsCache = true
      return nil
    end

    local pl = (type(UnitLevel) == "function") and tonumber(UnitLevel("player")) or nil
    local best = { idx = nil, itemID = nil, score = nil, pct = nil, unitPrice = nil }

    for i = 1, n do
      local id = GetMerchantItemIDSafe(i)
      if id == nil then
        _liMerchantWantsCache = true
      elseif id > 0 and IsItemUsableForPlayerLevel(id, pl) then
        local t = GetFoodDrinkTupleForItemID(id)
        if type(t) == "table" and GetFoodDrinkCategoryKey(t) == categoryKey then
          local sc = FoodDrinkScore(t) or nil
          if sc then
            local price, qty = nil, nil
            if C_MerchantFrame and type(C_MerchantFrame.GetItemInfo) == "function" then
              local okI, info = pcall(C_MerchantFrame.GetItemInfo, i)
              if okI and type(info) == "table" then
                price = tonumber(info.price)
                qty = tonumber(info.stackCount or info.quantity)
              end
            end
            if price == nil and type(GetMerchantItemInfo) == "function" then
              local okI, _, _, p, q = pcall(GetMerchantItemInfo, i)
              if okI then
                price = tonumber(p)
                qty = tonumber(q)
              end
            end
            if qty == nil or qty <= 0 then qty = 1 end
            local unit = (price and price > 0) and (price / qty) or nil

            local better = false
            if not best.idx then
              better = true
            elseif sc > (best.score or 0) then
              better = true
            elseif sc == (best.score or 0) then
              if unit ~= nil and (best.unitPrice == nil or unit < best.unitPrice) then
                better = true
              end
            end

            if better then
              best.idx, best.itemID, best.score, best.pct, best.unitPrice = i, id, sc, tonumber(t.pct) or nil, unit
            end
          end
        end
      end
    end

    if not best.idx then return nil end
    return best
  end

  local function GetBestMerchantItemForUseKey(useKey, usesMana)
    if type(useKey) ~= "string" or useKey == "" then return nil end
    if type(GetMerchantNumItems) ~= "function" then return nil end
    local n = tonumber(GetMerchantNumItems()) or 0
    if n <= 0 then
      _liMerchantWantsCache = true
      return nil
    end

    local pl = (type(UnitLevel) == "function") and tonumber(UnitLevel("player")) or nil
    local best = { idx = nil, itemID = nil, unitPrice = nil }

    for i = 1, n do
      local id = GetMerchantItemIDSafe(i)
      if id == nil then
        _liMerchantWantsCache = true
      elseif id > 0 and IsItemUsableForPlayerLevel(id, pl) then
        local k = GetUseKeyForItemID(id)
        if k and k == useKey then
          if (usesMana == false) and (k:sub(-7) == "|mana:1") then
            -- skip
          else
            local price, qty = nil, nil
            if C_MerchantFrame and type(C_MerchantFrame.GetItemInfo) == "function" then
              local okI, info = pcall(C_MerchantFrame.GetItemInfo, i)
              if okI and type(info) == "table" then
                price = tonumber(info.price)
                qty = tonumber(info.stackCount or info.quantity)
              end
            end
            if price == nil and type(GetMerchantItemInfo) == "function" then
              local okI, _, _, p, q = pcall(GetMerchantItemInfo, i)
              if okI then
                price = tonumber(p)
                qty = tonumber(q)
              end
            end
            if qty == nil or qty <= 0 then qty = 1 end
            local unit = (price and price > 0) and (price / qty) or nil

            local better = false
            if not best.idx then
              better = true
            elseif unit ~= nil and (best.unitPrice == nil or unit < best.unitPrice) then
              better = true
            end

            if better then
              best.idx, best.itemID, best.unitPrice = i, id, unit
            end
          end
        end
      end
    end

    if not best.idx then return nil end
    return best
  end

  local function IsFoodItemID(itemID)
    if not (C_Item and type(C_Item.GetItemInfoInstant) == "function") then return false end
    local ok, _, _, _, _, _, classID, subClassID = pcall(C_Item.GetItemInfoInstant, itemID)
    if not ok then return false end
    return (tonumber(classID) == 0) and (tonumber(subClassID) == 5)
  end

  local function GetItemMinLevel(itemID, link)
    itemID = tonumber(itemID)
    if not itemID then return nil end
    if type(GetItemInfo) == "function" then
      local _, _, _, ilvl, reqLevel = GetItemInfo(itemID)
      reqLevel = tonumber(reqLevel)
      if reqLevel and reqLevel > 0 then
        return reqLevel
      end
      ilvl = tonumber(ilvl)
      if ilvl and ilvl > 0 then
        return ilvl
      end
    end
    if link and type(GetDetailedItemLevelInfo) == "function" then
      local okI, ilvl = pcall(GetDetailedItemLevelInfo, link)
      ilvl = okI and tonumber(ilvl) or nil
      if ilvl and ilvl > 0 then
        return ilvl
      end
    end
    return nil
  end

  local function GetItemSellPrice(itemID)
    itemID = tonumber(itemID)
    if not itemID or itemID <= 0 then return nil end
    if type(GetItemInfo) == "function" then
      local sellPrice = select(11, GetItemInfo(itemID))
      sellPrice = tonumber(sellPrice)
      return sellPrice
    end
    return nil
  end

  local function SellOldFoodAtMerchant(levelDiff, protectedIDs)
    local diff = tonumber(levelDiff) or 10
    if diff < 1 then diff = 1 end
    if diff > 80 then diff = 80 end

    local pl = type(UnitLevel) == "function" and tonumber(UnitLevel("player")) or nil
    if not pl or pl <= 1 then return end
    local threshold = pl - diff + 1

    local soldByID = {}
    local soldReqByID = {}
    local ops = 0
    local maxOps = 200

    -- Collect eligible sells first so we can optionally keep one "best" low-food stack
    -- when the player has NO usable non-low food.
    local toSell = {}
    local bestLowItemID = nil
    local bestLowRate = -1
    local hasNonLowUsableFood = false

    IterateBagSlots(function(bag, slot)
      if #toSell >= maxOps then return end
      local info = GetBagItemInfo(bag, slot)
      if not info or info.isLocked then return end
      local itemID = tonumber(info.itemID)
      if not itemID or not IsFoodItemID(itemID) then return end
      local isProtected = (type(protectedIDs) == "table" and protectedIDs[itemID] == true) and true or false

      local link = nil
      if C_Container and type(C_Container.GetContainerItemLink) == "function" then
        local okL, vL = pcall(C_Container.GetContainerItemLink, bag, slot)
        link = okL and vL or nil
      end

      local req = GetItemMinLevel(itemID, link)
      if not req or req <= 0 then return end

      -- If the player has any usable food at/above the low-food threshold, don't keep low food.
      if req <= pl and req >= threshold then
        hasNonLowUsableFood = true
      end

      -- Protected items are never sold, but they still count as "usable non-low".
      if isProtected then return end

      local hRate = GetFoodHealthRateForItemID(itemID) or 0

      -- Only sell food that is strictly below the low-food threshold.
      -- Example: at level 80 with diff=5, threshold=76; req=76+ food is NOT "low".
      if req >= threshold then
        return
      end

      local sellPrice = GetItemSellPrice(itemID)
      if not sellPrice or sellPrice <= 0 then return end

      local stack = tonumber(info.stackCount) or 1
      toSell[#toSell + 1] = { bag = bag, slot = slot, itemID = itemID, stack = stack, req = req, link = link, hRate = hRate }

      if hRate > bestLowRate then
        bestLowRate = hRate
        bestLowItemID = itemID
      end
    end)

    if bestLowItemID and #toSell > 0 then
      -- Keep ALL of the best low-food item only when you have NO usable non-low food.
      if not hasNonLowUsableFood then
        local filtered = {}
        for _, it in ipairs(toSell) do
          if it.itemID ~= bestLowItemID then
            filtered[#filtered + 1] = it
          end
        end
        toSell = filtered
      end
    end

    for _, it in ipairs(toSell) do
      if ops >= maxOps then break end
      UseContainerItemSafe(it.bag, it.slot)
      soldByID[it.itemID] = (soldByID[it.itemID] or 0) + (tonumber(it.stack) or 1)
      if soldReqByID[it.itemID] == nil then
        soldReqByID[it.itemID] = it.req
      end
      ops = ops + 1
    end

    for id, cnt in pairs(soldByID) do
      local perItem = GetItemSellPrice(id)
      local total = (perItem and perItem > 0) and (perItem * cnt) or nil
      local moneyText = FormatGoldOnly(total or 0)
      local itemLink = GetItemLinkSafe(id)
      local itemText = StripLinkBrackets(itemLink or tostring(id))
      local amtText = tostring(cnt) .. "x"
      local req = soldReqByID[id]
      if req == nil then
        req = GetItemMinLevel(id, itemLink)
      end
      local reasonText = "(Low Food " .. tostring(req or "?") .. ")"
      Print(GetClassColoredPlayerName() .. " " .. tostring(moneyText) .. "  " .. amtText .. " " .. tostring(itemText) .. "  " .. reasonText)
    end

    return ops
  end

  local function IsSellFoodEnabled()
    SyncDB()
    local acc = DepositCfgAcc()
    local ch = DepositCfgChar()
    return ((acc and acc.sellFoodEnabledAcc) == true) or ((ch and ch.sellFoodEnabledChar) == true)
  end

  local function DebugSellOldFoodAtMerchant(levelDiff, maxLines, protectedIDs)
    local diff = tonumber(levelDiff) or 10
    if diff < 1 then diff = 1 end
    if diff > 80 then diff = 80 end

    local pl = type(UnitLevel) == "function" and tonumber(UnitLevel("player")) or nil
    local threshold = (pl and pl > 1) and (pl - diff + 1) or nil

    local mf = _G and rawget(_G, "MerchantFrame")
    local merchantShown = (mf and mf.IsShown and mf:IsShown()) and true or false

    Print("Food debug: merchantShown=" .. tostring(merchantShown) .. ", enabled=" .. tostring(IsSellFoodEnabled()) .. ", diff=" .. tostring(diff) .. ", player=" .. tostring(pl) .. ", threshold=" .. tostring(threshold))

    local cap = tonumber(maxLines) or 25
    if cap < 5 then cap = 5 end
    if cap > 60 then cap = 60 end

    local counts = { total = 0, food = 0, eligible = 0, locked = 0, noReq = 0, above = 0, noPrice = 0, protected = 0 }

    local entries = {}
    local bestLowItemID = nil
    local bestLowRate = -1
    local bestUsableRate = -1
    local hasNonLowUsableFood = false

    IterateBagSlots(function(bag, slot)
      local info = GetBagItemInfo(bag, slot)
      if not info then return end
      local itemID = tonumber(info.itemID)
      if not itemID or itemID <= 0 then return end

      counts.total = counts.total + 1
      local locked = (info.isLocked == true)
      if locked then counts.locked = counts.locked + 1 end

      local classID, subClassID = nil, nil
      if C_Item and type(C_Item.GetItemInfoInstant) == "function" then
        local ok, _, _, _, _, _, c, s = pcall(C_Item.GetItemInfoInstant, itemID)
        if ok then classID, subClassID = tonumber(c), tonumber(s) end
      end
      local isFood = IsFoodItemID(itemID)
      if isFood then counts.food = counts.food + 1 end
      if not isFood then return end

      local isProtected = (type(protectedIDs) == "table" and protectedIDs[itemID] == true) and true or false
      if isProtected then
        counts.protected = (counts.protected or 0) + 1
      end

      local link = nil
      if C_Container and type(C_Container.GetContainerItemLink) == "function" then
        local okL, vL = pcall(C_Container.GetContainerItemLink, bag, slot)
        link = okL and vL or nil
      end

      local req = GetItemMinLevel(itemID, link)
      if not req or req <= 0 then counts.noReq = counts.noReq + 1 end

      local sellPrice = GetItemSellPrice(itemID)
      if not sellPrice or sellPrice <= 0 then counts.noPrice = counts.noPrice + 1 end

      local hRate = GetFoodHealthRateForItemID(itemID)
      hRate = (hRate ~= nil) and (tonumber(hRate) or 0) or nil

      local okThreshold = (threshold ~= nil) and (req ~= nil) and (req > 0) and (req < threshold)
      if threshold ~= nil and req and req >= threshold then counts.above = counts.above + 1 end

      if threshold ~= nil and pl ~= nil and req ~= nil and req > 0 then
        local usableNonLow = (req <= pl) and (req >= threshold)
        if usableNonLow then
          hasNonLowUsableFood = true
        end
      end

      local eligible = (not locked) and okThreshold and (sellPrice and sellPrice > 0) and (not isProtected)
      if eligible then counts.eligible = counts.eligible + 1 end

      -- Track best usable vs best low-food by hp/sec.
      local usable = (pl ~= nil) and (req ~= nil) and (req > 0) and (req <= pl)
      if usable and hRate and hRate > bestUsableRate then
        bestUsableRate = hRate
      end
      if okThreshold and hRate and hRate > bestLowRate then
        bestLowRate = hRate
        bestLowItemID = itemID
      end

      local stack = tonumber(info.stackCount) or 1

      if #entries < cap then
        entries[#entries + 1] = {
          bag = bag,
          slot = slot,
          itemID = itemID,
          stack = stack,
          classID = classID,
          subClassID = subClassID,
          req = req,
          price = sellPrice,
          eligible = eligible and true or false,
          okThreshold = okThreshold and true or false,
          locked = locked and true or false,
          hRate = hRate,
          protected = isProtected,
        }
      end
    end)

    local keepBestLow = false
    if bestLowItemID then
      -- Keep best low-food only when you have NO usable non-low food.
      keepBestLow = (threshold ~= nil) and (not hasNonLowUsableFood) and true or false
    end

    do
      local function fmtRate(x)
        if x == nil then return "?" end
        x = tonumber(x) or 0
        if x <= 0 then return "0" end
        if x >= 100 then return string.format("%.0f", x) end
        return string.format("%.1f", x)
      end

      local function fmtItem(id)
        local link = GetItemLinkSafe(id)
        return StripLinkBrackets(link or tostring(id))
      end

      Print("Food debug decision: bestUsable hp/s=" .. fmtRate(bestUsableRate) .. ", bestLow hp/s=" .. fmtRate(bestLowRate) .. ", hasNonLowUsable=" .. tostring(hasNonLowUsableFood) .. ", keepBestLow=" .. tostring(keepBestLow))
      if keepBestLow and bestLowItemID then
        Print("Food debug keep item: id=" .. tostring(bestLowItemID) .. " " .. fmtItem(bestLowItemID) .. " (hp/s=" .. fmtRate(bestLowRate) .. ")")
      end
    end

    do
      local function tag(colorHex, text)
        return "|cff" .. colorHex .. text .. "|r"
      end
      local TAG_KEEP = tag("00ff00", "KEEP")
      local TAG_SELL = tag("ff3333", "SELL")
      local TAG_SKIP = tag("aaaaaa", "SKIP")

      local function fmtRate(x)
        if x == nil then return "?" end
        x = tonumber(x) or 0
        if x <= 0 then return "0" end
        if x >= 100 then return string.format("%.0f", x) end
        return string.format("%.1f", x)
      end

      for _, e in ipairs(entries) do
        local action = TAG_SKIP
        local reason = "skip"
        if e.okThreshold then
          if e.protected then
            action = TAG_KEEP
            reason = "protected"
          elseif keepBestLow and bestLowItemID and e.itemID == bestLowItemID then
            action = TAG_KEEP
            reason = "bestLowFallback"
          elseif e.eligible then
            action = TAG_SELL
            reason = "eligible"
          else
            reason = "ineligible"
          end
        else
          if e.locked then
            reason = "locked"
          elseif e.req == nil or (tonumber(e.req) or 0) <= 0 then
            reason = "noReq"
          elseif threshold ~= nil and e.req ~= nil and tonumber(e.req) and tonumber(threshold) and tonumber(e.req) >= tonumber(threshold) then
            reason = "notLow"
          elseif e.price == nil or (tonumber(e.price) or 0) <= 0 then
            reason = "noPrice"
          else
            reason = "skip"
          end
        end

        Print(
          string.format(
            "Food slot: bag=%d slot=%d id=%d x%d class=%s/%s req=%s hp/s=%s price=%s low=%s eligible=%s %s (%s)",
            e.bag,
            e.slot,
            e.itemID,
            e.stack,
            tostring(e.classID),
            tostring(e.subClassID),
            tostring(e.req),
            tostring(fmtRate(e.hRate)),
            tostring(e.price),
            tostring(e.okThreshold),
            tostring(e.eligible),
            action,
            tostring(reason)
          )
        )
      end
    end

    Print(string.format("Food debug summary: totalItems=%d, food=%d, eligible=%d, locked=%d, protected=%d, noReq=%d, aboveThreshold=%d, noPrice=%d", counts.total, counts.food, counts.eligible, counts.locked, counts.protected or 0, counts.noReq, counts.above, counts.noPrice))
  end

  LI.DebugSellOldFoodAtMerchant = DebugSellOldFoodAtMerchant
  LI.Trade.DebugSellOldFoodAtMerchant = DebugSellOldFoodAtMerchant

  local function GetFreeBackpackSlots()
    if not (C_Container and type(C_Container.GetContainerNumFreeSlots) == "function") then
      return nil
    end
    local total = 0
    for bag = 0, 4 do
      local ok, free = pcall(C_Container.GetContainerNumFreeSlots, bag)
      if ok and type(free) == "number" then
        total = total + free
      end
    end
    return total
  end

  local _liMerchantBuyBaselineHave
  local _liMerchantBuySessionBought
  local _liMerchantNotSoldWarned
  local _liMerchantBuyPrinted

  local _liMerchantRestockComparePrinted
  local _liMerchantRestockLowerTierPrinted

  -- After a merchant buy, delay any selling until BAG_UPDATE_DELAYED fires.
  local _liMerchantSellBlockedUntilBag
  local _liMerchantSellWaitPrinted
  local _liMerchantSellSawBagUpdate
  local _liMerchantSellBagUpdateTS
  local _liMerchantSellPendingPrinted

  local _liMerchantPrewarmCursor

  -- Merchant ticker/session state.
  -- Must be declared BEFORE RunMerchantTradeOnce so all helpers share the same upvalues.
  local _liMerchantTicker
  local _liMerchantDidFoodSell = false
  local _liMerchantIdleTicks = 0
  local _liMerchantLastStartTS
  local _liMerchantLastTickSummary
  local _liMerchantLastNoOpReason
  local _liMerchantNoOpPrinted
  local _liMerchantBuyBlocked
  local _liMerchantLastBuyAttempt

  local function GetHaveCount(id)
    id = tonumber(id)
    if not id or id <= 0 then return 0 end

    local raw = CountItemInBags(id) or 0
    local owned = CountItemOwnedNoBank(id) or 0
    if owned > raw then raw = owned end

    if type(_liMerchantBuyBaselineHave) ~= "table" or type(_liMerchantBuySessionBought) ~= "table" then
      return raw
    end

    if _liMerchantBuyBaselineHave[id] == nil then
      _liMerchantBuyBaselineHave[id] = raw
    end

    local base = tonumber(_liMerchantBuyBaselineHave[id]) or 0
    local bought = tonumber(_liMerchantBuySessionBought[id]) or 0
    local expected = base + bought
    if expected > raw then
      return expected
    end
    return raw
  end

  local function GetPendingBought(id)
    id = tonumber(id)
    if not id or id <= 0 then return 0 end

    if type(_liMerchantBuyBaselineHave) ~= "table" or type(_liMerchantBuySessionBought) ~= "table" then
      return 0
    end

    local raw = CountItemInBags(id) or 0
    local owned = CountItemOwnedNoBank(id) or 0
    if owned > raw then raw = owned end
    if _liMerchantBuyBaselineHave[id] == nil then
      _liMerchantBuyBaselineHave[id] = raw
    end
    local base = tonumber(_liMerchantBuyBaselineHave[id]) or 0
    local bought = tonumber(_liMerchantBuySessionBought[id]) or 0
    local expected = base + bought
    local pending = expected - raw
    if pending > 0 then return pending end
    return 0
  end

  local function PrewarmMerchantItemList(maxItems)
    if type(GetMerchantNumItems) ~= "function" then return end
    local n = tonumber(GetMerchantNumItems()) or 0
    if n <= 0 then
      _liMerchantWantsCache = true
      return
    end

    maxItems = tonumber(maxItems) or 18
    maxItems = math.floor(maxItems)
    if maxItems < 1 then maxItems = 1 end
    if maxItems > 60 then maxItems = 60 end

    if type(_liMerchantPrewarmCursor) ~= "number" or _liMerchantPrewarmCursor < 1 then
      _liMerchantPrewarmCursor = 1
    end

    local warmed = 0
    while warmed < maxItems and _liMerchantPrewarmCursor <= n do
      local i = _liMerchantPrewarmCursor
      _liMerchantPrewarmCursor = _liMerchantPrewarmCursor + 1

      -- Touch link first: some clients populate item links lazily.
      pcall(GetMerchantItemLinkSafe, i)

      local id = GetMerchantItemIDSafe(i)
      if id and id > 0 then
        pcall(PrewarmTradeItemCache, id)
      else
        _liMerchantWantsCache = true
      end

      warmed = warmed + 1
    end
  end

  local function RunMerchantTradeOnce(skipFoodSell)
    SyncDB()
    local rawMode = GetTradeMode()
    _liMerchantWantsCache = false

    local foodEnabled = IsSellFoodEnabled()
    local foodDiff = (DB and DB.deposit and tonumber(DB.deposit.sellFoodLevelDiff)) or 10
    foodDiff = foodDiff and math.floor(foodDiff) or 10
    if foodDiff < 1 then foodDiff = 1 end
    if foodDiff > 80 then foodDiff = 80 end

    local dbg = false
    do
      if LI and type(LI.GetDB) == "function" then
        local DB = LI.GetDB()
        if DB and DB.deposit and DB.deposit.tradeDebug == true then
          dbg = true
        end
      end
      if (LI and LI.Trade and LI.Trade._debugOn == true) then
        dbg = true
      end
    end

    _liMerchantLastNoOpReason = nil

    -- IMPORTANT: merchant automation should not depend on what the Trade UI is set to.
    -- The UI is for editing rules; at a vendor, we run buy/restock rules AND sell rules (if present).
    local buyRules = GetEffectiveTradeRules("buy")
    local sellRules = GetEffectiveTradeRules("sell")
    local hasBuyRules = (type(buyRules) == "table" and next(buyRules) ~= nil) and true or false
    local hasSellRules = (type(sellRules) == "table" and next(sellRules) ~= nil) and true or false

    if dbg and _liMerchantDebugSummaryPrinted ~= true then
      local function CountRules(t)
        if type(t) ~= "table" then return 0, 0 end
        local total, restock = 0, 0
        for _, r in pairs(t) do
          total = total + 1
          if r and r.restock == true then restock = restock + 1 end
        end
        return total, restock
      end

      local bn, br = CountRules(buyRules)
      local sn, sr = CountRules(sellRules)

      local usesMana = PlayerUsesMana()
      local manaType = 0
      if Enum and type(Enum.PowerType) == "table" and type(Enum.PowerType.Mana) == "number" then
        manaType = Enum.PowerType.Mana
      end
      local maxMana = nil
      if type(UnitPowerMax) == "function" then
        local okMM, v = pcall(UnitPowerMax, "player", manaType)
        if okMM and type(v) == "number" then maxMana = math.floor(v) end
      end
      local pt, token = nil, nil
      if type(UnitPowerType) == "function" then
        pt, token = UnitPowerType("player")
      end

      Print(
        "Merchant debug: uiMode=" .. tostring(rawMode) ..
        ", buyRules=" .. tostring(bn) .. " (restock " .. tostring(br) .. ")" ..
        ", sellRules=" .. tostring(sn) .. " (restock " .. tostring(sr) .. ")"
        .. ", foodEnabled=" .. tostring(foodEnabled)
        .. ", foodDiff=" .. tostring(foodDiff)
        .. ", usesMana=" .. tostring(usesMana)
        .. ", maxMana=" .. tostring(maxMana)
        .. ", powerType=" .. tostring(pt)
        .. ", token=" .. tostring(token)
      )
      _liMerchantDebugSummaryPrinted = true
    end
    local usesMana = PlayerUsesMana()
    local pl = (type(UnitLevel) == "function") and tonumber(UnitLevel("player")) or nil
    local ops = 0
    local maxOps = 200

    -- Some UIs/clients populate the merchant item list a moment after MERCHANT_SHOW.
    -- If there are buy/restock rules but the list isn't ready yet, briefly mark wants-cache so the
    -- ticker keeps running (and doesn't idle-out) until the list is available.
    -- NOTE: some merchants genuinely have 0 items for sale but still BUY items; never block the sell
    -- pass (including Low Food) just because the merchant list is empty.
    local merchantN = nil
    if hasBuyRules and type(GetMerchantNumItems) == "function" then
      merchantN = tonumber(GetMerchantNumItems()) or 0
      if merchantN <= 0 then
        local now = (type(GetTime) == "function") and GetTime() or nil
        local startTS = _liMerchantLastStartTS or now
        if now and startTS and (now - startTS) < 0.90 then
          _liMerchantWantsCache = true
          _liMerchantLastNoOpReason = "waiting merchant list"
        end
      end
    end

    if hasBuyRules and (merchantN or 0) > 0 and (type(_liMerchantPrewarmCursor) ~= "number" or (_liMerchantPrewarmCursor <= (merchantN or 0))) then
      PrewarmMerchantItemList((_liMerchantWantsCache == true) and 30 or 18)
    end

    local function GetRestockGroupKey(itemID)
      itemID = tonumber(itemID)
      if not itemID or itemID <= 0 then return nil end
      local fd = GetFoodDrinkTupleForItemID(itemID)
      local cat = fd and GetFoodDrinkCategoryKey(fd) or nil
      if cat then
        return "food:" .. tostring(cat)
      end
      local key = GetUseKeyForItemID(itemID)
      if key then
        return "use:" .. tostring(key)
      end
      return nil
    end

    local function GetMerchantItemBuyInfo(idx)
      idx = tonumber(idx)
      if not idx or idx <= 0 then return nil end

      local maxStack = nil
      if type(GetMerchantItemMaxStack) == "function" then
        local okS, v = pcall(GetMerchantItemMaxStack, idx)
        maxStack = okS and tonumber(v) or nil
        if maxStack ~= nil and maxStack < 1 then maxStack = nil end
      end

      if C_MerchantFrame and type(C_MerchantFrame.GetItemInfo) == "function" then
        local ok, info = pcall(C_MerchantFrame.GetItemInfo, idx)
        if ok and type(info) == "table" then
          local name = info.name
          local price = tonumber(info.price) or 0
          local quantity = tonumber(info.stackCount or info.quantity) or 1
          local numAvailable = info.numAvailable
          return {
            name = (type(name) == "string" and name ~= "") and name or nil,
            price = price,
            quantity = (quantity and quantity > 0) and quantity or 1,
            numAvailable = (numAvailable ~= nil) and tonumber(numAvailable) or nil,
            maxStack = maxStack,
          }
        end
      end

      if type(GetMerchantItemInfo) == "function" then
        local ok, name, _, price, quantity, numAvailable = pcall(GetMerchantItemInfo, idx)
        if ok then
          price = tonumber(price) or 0
          quantity = tonumber(quantity) or 1
          return {
            name = (type(name) == "string" and name ~= "") and name or nil,
            price = price,
            quantity = (quantity and quantity > 0) and quantity or 1,
            numAvailable = (numAvailable ~= nil) and tonumber(numAvailable) or nil,
            maxStack = maxStack,
          }
        end
      end

      return nil
    end

    local canAttemptBuy = hasBuyRules and ((merchantN or 0) > 0)

    if canAttemptBuy then
      -- Prewarm rule item IDs so restock classification (food/use-key) is less likely
      -- to run with partial item cache on the first tick.
      for itemID in pairs(buyRules) do
        itemID = tonumber(itemID)
        if itemID and itemID > 0 then
          pcall(PrewarmTradeItemCache, itemID)
        end
      end

      local restockGroupTarget = {}
      local restockGroupSeed = {}
      for itemID, r in pairs(buyRules) do
        itemID = tonumber(itemID)
        local target = r and tonumber(r.count) or nil
        if itemID and itemID > 0 and r and r.restock == true and target and target > 0 then
          local gk = GetRestockGroupKey(itemID)
          if gk then
            local prev = tonumber(restockGroupSeed[gk])
            if prev == nil then
              restockGroupSeed[gk] = itemID
              -- Group target should follow the chosen seed item's configured target,
              -- not the max across all tier rules.
              restockGroupTarget[gk] = target
            else
              local prevUsable = IsItemUsableForPlayerLevel(prev, pl)
              local thisUsable = IsItemUsableForPlayerLevel(itemID, pl)
              local prevReq = GetItemRequiredPlayerLevel(prev) or 0
              local thisReq = GetItemRequiredPlayerLevel(itemID) or 0

              local better = false
              if thisUsable and not prevUsable then
                better = true
              elseif thisUsable and prevUsable then
                if thisReq > prevReq then
                  better = true
                elseif thisReq == prevReq and itemID < prev then
                  better = true
                end
              elseif (not thisUsable) and (not prevUsable) then
                if thisReq < prevReq then
                  better = true
                elseif thisReq == prevReq and itemID < prev then
                  better = true
                end
              end

              if better then
                restockGroupSeed[gk] = itemID
                restockGroupTarget[gk] = target
              end
            end
          end
        end
      end

      local buyBlockedByCache = false
      -- If restock grouping required uncached item data, wait for cache before buying.
      -- IMPORTANT: don't return here; still allow sell pass (Low Food + sell rules) to run.
      if _liMerchantWantsCache == true then
        _liMerchantLastNoOpReason = _liMerchantLastNoOpReason or "waiting item cache"
        buyBlockedByCache = true
      end

      -- If merchant list isn't ready yet, don't attempt to buy on this tick.
      if (merchantN or 0) <= 0 and type(GetMerchantNumItems) == "function" then
        -- wants-cache (briefly) already set above
      elseif not buyBlockedByCache then
        for itemID, r in pairs(buyRules) do
        if ops >= maxOps then break end
        local target = r and tonumber(r.count) or nil
        if target and target > 0 then
          local skipThisRule = false
          if r and r.restock == true then
            local gk = GetRestockGroupKey(itemID)
            if not gk then
              if _liMerchantWantsCache == true then
                return ops
              end
              -- Safety: restock rules must be classifiable; never fall back to exact-item buying.
              skipThisRule = true
            end
            if gk and restockGroupSeed[gk] ~= nil and restockGroupSeed[gk] ~= itemID then
              skipThisRule = true
            end
            if gk and restockGroupTarget[gk] ~= nil then
              target = tonumber(restockGroupTarget[gk]) or target
            end
          end
          if not skipThisRule then
            local current = 0
            if r.restock == true then
              local fd = GetFoodDrinkTupleForItemID(itemID)
              if fd == nil and _liMerchantWantsCache == true then
                return ops
              end
              local cat = fd and GetFoodDrinkCategoryKey(fd) or nil
              if cat then
                if (not usesMana) and cat == "drink" then
                  current = target
                else
                  local best = GetBestMerchantFoodDrinkForCategory(cat, usesMana)
                  if _liMerchantWantsCache == true then
                    return ops
                  end
                  local skipLowerTierVendor = false
                  if best and best.score then
                    local maxBag = GetMaxFoodDrinkScoreInBags(cat)
                    if maxBag and maxBag > best.score then
                      skipLowerTierVendor = true
                      if dbg and type(Print) == "function" then
                        if type(_liMerchantRestockLowerTierPrinted) ~= "table" then
                          _liMerchantRestockLowerTierPrinted = {}
                        end

                        local k = tostring(cat) .. ":" .. tostring(itemID)
                        if _liMerchantRestockLowerTierPrinted[k] ~= true then
                          _liMerchantRestockLowerTierPrinted[k] = true
                          Print("Restock skipped (merchant lower tier): " .. (GetItemNameSafe(itemID) or tostring(itemID)))
                        end
                      end
                    end
                  end

                  if skipLowerTierVendor then
                    current = target
                  else
                    local desiredScore = (best and best.score) or FoodDrinkScore(fd) or 0

                    -- Debug: show vendor-best vs bag-best comparison and the score threshold used.
                    if dbg and type(Print) == "function" then
                      if type(_liMerchantRestockComparePrinted) ~= "table" then
                        _liMerchantRestockComparePrinted = {}
                      end

                      local compareKey = tostring(cat) .. ":" .. tostring(itemID)
                      if _liMerchantRestockComparePrinted[compareKey] == true then
                        -- Avoid spamming the same comparison every ticker tick.
                        -- (still prints again on next merchant session)
                      else
                        _liMerchantRestockComparePrinted[compareKey] = true

                      local bagBest = GetBestFoodDrinkInBags(cat)
                      local bagHP = (not bagBest) and GetBestFoodByHealthRateInBags(pl) or nil
                      local vendorReq = (best and best.itemID) and (GetItemRequiredPlayerLevel(best.itemID) or 0) or 0
                      local ruleReq = GetItemRequiredPlayerLevel(itemID) or 0
                      local function fmtItem(id)
                        if not id then return "none" end
                        return StripLinkBrackets(GetItemLinkSafe(id) or tostring(id))
                      end
                      local bagSuffix = ""
                      if (not bagBest) and bagHP then
                        bagSuffix = " | bagBestHP=" .. fmtItem(bagHP.itemID)
                          .. " (req=" .. tostring(bagHP.req or "?")
                          .. ", hp/s=" .. tostring(bagHP.rate or "?") .. ")"
                      end
                      Print(
                        "Restock compare (" .. tostring(cat) .. "): vendorBest="
                          .. fmtItem(best and best.itemID)
                          .. " (req=" .. tostring(vendorReq)
                          .. ", score=" .. tostring((best and best.score) or "?")
                          .. ") vs bagBest="
                          .. fmtItem(bagBest and bagBest.itemID)
                          .. " (req=" .. tostring(bagBest and bagBest.req or "?")
                          .. ", score=" .. tostring(bagBest and bagBest.score or "?")
                          .. ") | rule=" .. fmtItem(itemID)
                          .. " (req=" .. tostring(ruleReq)
                          .. ") | desiredScore=" .. tostring(desiredScore)
                          .. bagSuffix
                      )
                      end
                    end

                    current = CountFoodDrinkAtOrAboveInBags(cat, desiredScore)
                    if best and best.itemID then
                      current = current + GetPendingBought(best.itemID)
                      -- If bag/item cache updated but the equivalence scan can't classify the item yet,
                      -- ensure we still count the exact purchased itemID to avoid repeat buys.
                      local floorHave = GetHaveCount(best.itemID)
                      if floorHave > current then current = floorHave end
                    else
                      current = current + GetPendingBought(itemID)
                      local floorHave = GetHaveCount(itemID)
                      if floorHave > current then current = floorHave end
                    end
                  end
                end
              else
                local key = GetUseKeyForItemID(itemID)
                if key == nil and _liMerchantWantsCache == true then
                  return ops
                end
                if key then
                  local hasMana = (key:sub(-7) == "|mana:1")
                  if (not usesMana) and hasMana then
                    current = target
                  else
                    local best = GetBestMerchantItemForUseKey(key, usesMana)
                    if _liMerchantWantsCache == true then
                      return ops
                    end
                    current = CountEquivalentByUseKeyInBags(key)
                    if best and best.itemID then
                      current = current + GetPendingBought(best.itemID)
                      -- UseKey matching can temporarily fail right after a purchase if item data isn't
                      -- cached yet; floor by exact itemID count to avoid buying multiple times.
                      local floorHave = GetHaveCount(best.itemID)
                      if floorHave > current then current = floorHave end
                    else
                      current = current + GetPendingBought(itemID)
                      local floorHave = GetHaveCount(itemID)
                      if floorHave > current then current = floorHave end
                    end
                  end
                else
                  -- Unclassified restock rule (not food/drink, no use-key). Fail closed.
                  current = target
                end
              end
            else
              current = GetHaveCount(itemID)
            end

            local need = target - current
            local debugThisRule = dbg and (_liMerchantDebugRulePrinted ~= true)
            if debugThisRule then
              Print(
                "Merchant debug rule: id=" .. tostring(itemID) ..
                ", target=" .. tostring(target) ..
                ", current=" .. tostring(current) ..
                ", need=" .. tostring(need) ..
                ", restock=" .. tostring(r.restock == true)
              )
            end
            if need > 0 then
              local freeSlots = GetFreeBackpackSlots()
              if freeSlots ~= nil and freeSlots <= 0 then
                if debugThisRule then
                  Print("Merchant debug buy: blocked (no free bag slots)")
                  _liMerchantDebugRulePrinted = true
                end
                return ops
              end

              local buyID, idx = itemID, nil

              if r.restock == true then
                local fd = GetFoodDrinkTupleForItemID(itemID)
                if fd == nil and _liMerchantWantsCache == true then
                  buyID, idx = nil, nil
                end
                local cat = fd and GetFoodDrinkCategoryKey(fd) or nil
                if cat then
                  if (not usesMana) and cat == "drink" then
                    buyID, idx = nil, nil
                  else
                    local best = GetBestMerchantFoodDrinkForCategory(cat, usesMana)
                    if best and best.idx and best.itemID then
                      buyID, idx = best.itemID, best.idx
                    else
                      if _liMerchantWantsCache == true then
                        buyID, idx = nil, nil
                      else
                        local exactIdx = GetMerchantIndexForItemID(itemID)
                        if exactIdx and IsItemUsableForPlayerLevel(itemID, pl) then
                          buyID, idx = itemID, exactIdx
                        else
                          buyID, idx = nil, nil
                        end
                      end
                    end
                  end
                else
                  local key = GetUseKeyForItemID(itemID)
                  if key == nil and _liMerchantWantsCache == true then
                    buyID, idx = nil, nil
                  end
                  if key then
                    local best = GetBestMerchantItemForUseKey(key, usesMana)
                    if best and best.idx and best.itemID then
                      buyID, idx = best.itemID, best.idx
                    else
                      if _liMerchantWantsCache == true then
                        buyID, idx = nil, nil
                      else
                        buyID, idx = nil, nil
                      end
                    end
                  else
                    buyID, idx = nil, nil
                  end
                end
              end

              if buyID and not IsItemUsableForPlayerLevel(buyID, pl) then
                buyID, idx = nil, nil
              end

              if buyID and (not idx) then
                idx = GetMerchantIndexForItemID(buyID)
              end

              if debugThisRule then
                local ruleName = GetItemNameSafe(itemID) or tostring(itemID)
                local buyName = (buyID and (GetItemNameSafe(buyID) or tostring(buyID))) or "nil"
                Print(
                  "Merchant debug buy: rule=" .. tostring(itemID) .. " (" .. tostring(ruleName) .. ")" ..
                  ", need=" .. tostring(need) ..
                  ", freeSlots=" .. tostring(freeSlots) ..
                  ", wantsCache=" .. tostring(_liMerchantWantsCache == true) ..
                  ", buyID=" .. tostring(buyID) .. " (" .. tostring(buyName) .. ")" ..
                  ", idx=" .. tostring(idx)
                )

                if not buyID then
                  if _liMerchantWantsCache == true then
                    Print("Merchant debug buy: waiting on cache (merchant list/item data)")
                  else
                    Print("Merchant debug buy: cannot resolve a buy item for this rule")
                  end
                elseif buyID and not idx then
                  if _liMerchantWantsCache == true then
                    Print("Merchant debug buy: buyID chosen but waiting on merchant item index")
                  else
                    Print("Merchant debug buy: buyID chosen but not sold by this merchant")
                  end
                end
                _liMerchantDebugRulePrinted = true
              end
              if buyID and idx and type(BuyMerchantItem) == "function" then
                if _liMerchantWantsCache == true then
                  return ops
                end
                local bi = GetMerchantItemBuyInfo(idx) or {}
                local name = bi.name
                local price = bi.price

                local availItems = tonumber(bi.numAvailable)
                if availItems == nil or availItems < 0 then
                  availItems = need
                end
                if availItems <= 0 then
                  -- out of stock
                else
                  local buyCount = need
                  if buyCount > availItems then buyCount = availItems end

                  -- BuyMerchantItem expects a "quantity" in purchase-units (stacks), not raw item units.
                  -- For merchant items that vend in stacks (e.g. 20 per purchase), convert needed units
                  -- into number of purchases. Track pending bought in units.
                  local perPurchase = tonumber(bi.quantity) or 1
                  if perPurchase < 1 then perPurchase = 1 end

                  -- IMPORTANT: on your client, BuyMerchantItem(idx, quantity) behaves like "buy quantity
                  -- item units" (not "buy quantity purchases"). Therefore keep calculations in units.
                  local needUnits = buyCount

                  -- Prefer buying in the item's real max-stack size (usually 20) so vendor bundle sizes
                  -- (e.g. 5 per click) don't force tiny buy calls.
                  local itemMaxStack = GetItemMaxStackSafe(buyID) or 0
                  local capUnits = 0
                  if itemMaxStack and itemMaxStack > 0 then
                    capUnits = itemMaxStack
                  end

                  local maxCall = tonumber(bi.maxStack) or 0
                  if maxCall > 0 then
                    if capUnits > 0 then
                      capUnits = math.min(capUnits, maxCall)
                    else
                      capUnits = maxCall
                    end
                  end

                  local buyUnits = needUnits
                  if capUnits > 0 and buyUnits > capUnits then buyUnits = capUnits end
                  if buyUnits > 200 then buyUnits = 200 end

                  local p = tonumber(price) or 0
                  if p > 0 and type(GetMoney) == "function" then
                    local money = tonumber(GetMoney()) or 0
                    -- Treat merchant price as per-unit price; some merchants report stackCount>1 as a
                    -- default purchase size but still allow buying arbitrary unit amounts.
                    local maxAffordablePurchases = math.floor(money / p)
                    if maxAffordablePurchases < 0 then maxAffordablePurchases = 0 end
                    local maxAffordableUnits = maxAffordablePurchases
                    if maxAffordableUnits < buyUnits then buyUnits = maxAffordableUnits end
                  end

                  if buyUnits > 0 then
                    local id = tonumber(buyID)
                    if id and type(_liMerchantBuyBlocked) == "table" and _liMerchantBuyBlocked[id] == true then
                      -- Item blocked for the remainder of this merchant session (e.g. max/unique).
                    else
                      local boughtUnits = buyUnits

                      _liMerchantLastBuyAttempt = {
                        id = id,
                        count = buyUnits,
                        ts = (type(GetTime) == "function") and GetTime() or nil,
                      }

                      pcall(BuyMerchantItem, idx, buyUnits)

                      -- Delay selling until bags reflect this purchase.
                      _liMerchantSellBlockedUntilBag = true
                      _liMerchantSellWaitPrinted = false
                      _liMerchantSellSawBagUpdate = false
                      _liMerchantSellBagUpdateTS = nil
                      _liMerchantSellPendingPrinted = false
                      if type(_liMerchantBuySessionBought) == "table" then
                        if id and id > 0 then
                          _liMerchantBuySessionBought[id] = (tonumber(_liMerchantBuySessionBought[id]) or 0) + boughtUnits
                        end
                      end

                      -- Some non-stackable / max-count-1 items can briefly report as 0 owned right after purchase
                      -- (bag cache/UI timing). If the rule target is 1, block further buys this session to avoid
                      local nm = name or (GetItemNameSafe(buyID) or tostring(buyID))
                      local already = false
                      if id and id > 0 and type(_liMerchantBuyPrinted) == "table" then
                        already = (_liMerchantBuyPrinted[id] == true)
                      end
                      if not already then
                        local shownUnits = boughtUnits
                        local shownNeed = needUnits
                        local suffix = ""
                        if tonumber(shownNeed) and tonumber(shownUnits) and tonumber(shownNeed) ~= tonumber(shownUnits) then
                          suffix = " (need " .. tostring(shownNeed) .. ")"
                        end
                        Print("Buying: " .. tostring(shownUnits) .. "x " .. tostring(nm) .. suffix)
                        if id and id > 0 and type(_liMerchantBuyPrinted) == "table" then
                          _liMerchantBuyPrinted[id] = true
                        end
                      end
                      if id and id > 0 and target and tonumber(target) == 1 then
                        local ms = GetItemMaxStackSafe(id)
                        if ms == 1 and type(_liMerchantBuyBlocked) == "table" then
                          _liMerchantBuyBlocked[id] = true
                        end
                      end

                      ops = ops + 1
                      return ops
                    end
                  end
                end
              else
                if buyID and LI and LI.Trade and LI.Trade._debugOn == true then
                  if type(_liMerchantNotSoldWarned) ~= "table" then _liMerchantNotSoldWarned = {} end
                  local warnID = tonumber(buyID) or buyID
                  if _liMerchantNotSoldWarned[warnID] ~= true then
                    _liMerchantNotSoldWarned[warnID] = true
                    Print("Cannot buy (not sold by this merchant): " .. (GetItemNameSafe(buyID) or tostring(buyID)))
                  end
                end
              end
            end
          end
        end
      end
      end

      if ops > 0 then
        return ops
      end
    end

    local pendingFoodSell = (skipFoodSell ~= true) and foodEnabled and (_liMerchantDidFoodSell ~= true)
    local pendingSellRules = hasSellRules

    -- Low Food selling is also "selling"; if we bought this tick/session, wait for BAG_UPDATE_DELAYED
    -- so we don't act on stale bag counts. Also run it AFTER buy/restock so old food can be sold
    -- based on what we just purchased.
    if (pendingFoodSell or pendingSellRules) and _liMerchantSellBlockedUntilBag == true then
      if _liMerchantSellSawBagUpdate ~= true then
        if dbg and _liMerchantSellWaitPrinted ~= true then
          Print("Merchant debug: sell delayed until BAG_UPDATE_DELAYED after buy.")
          _liMerchantSellWaitPrinted = true
        end
        _liMerchantLastNoOpReason = "waiting BAG_UPDATE_DELAYED"
        return ops
      end

      -- BAG_UPDATE_DELAYED can fire before the purchased stack is visible in bag scans.
      -- Keep selling blocked until the last purchase is reflected.
      local now = (type(GetTime) == "function") and GetTime() or nil
      if now and _liMerchantSellBagUpdateTS and (now - _liMerchantSellBagUpdateTS) < 0.15 then
        _liMerchantLastNoOpReason = "waiting post-bag debounce"
        return ops
      end

      local attempt = _liMerchantLastBuyAttempt
      local id = attempt and tonumber(attempt.id) or nil
      if id and id > 0 then
        local pending = GetPendingBought(id) or 0
        if pending > 0 then
          if dbg and _liMerchantSellPendingPrinted ~= true then
            Print("Merchant debug: sell still waiting for bag counts (pending " .. tostring(pending) .. ") for last buy id=" .. tostring(id) .. ".")
            _liMerchantSellPendingPrinted = true
          end
          _liMerchantLastNoOpReason = "waiting bag counts (pending " .. tostring(pending) .. ")"
          return ops
        end
      end

      -- Unblock and continue into the sell pass.
      _liMerchantSellBlockedUntilBag = false
      _liMerchantSellWaitPrinted = false
      _liMerchantSellPendingPrinted = false

      if dbg then
        Print("Merchant debug: sell unblocked; running sell pass.")
      end
    end

      local sellPassFoodOps = 0
      local sellPassRuleOps = 0

      if pendingFoodSell then
      local protected = nil
      if hasBuyRules then
        protected = {}
        for id in pairs(buyRules) do
          id = tonumber(id)
          if id and id > 0 then
            protected[id] = true
          end
        end
      end

      if dbg then
          DebugSellOldFoodAtMerchant(foodDiff, 30, protected)
      end

      local soldOps = SellOldFoodAtMerchant(foodDiff, protected)
      if type(soldOps) == "number" and soldOps > 0 then
        sellPassFoodOps = soldOps
        ops = ops + soldOps
      end
      _liMerchantDidFoodSell = true
    end

    if pendingSellRules then
      local before = ops
      for itemID, r in pairs(sellRules) do
        if ops >= maxOps then break end
        local target = r and tonumber(r.count) or 0
        if target < 0 then target = 0 end
        target = math.floor(target)

        local current = CountItemInBags(itemID)
        local toSell = current - target
        if toSell > 0 then
          local sold = 0
          IterateBagSlots(function(bag, slot)
            if ops >= maxOps then return end
            if sold >= toSell then return end
            local info = GetBagItemInfo(bag, slot)
            if not info or info.isLocked then return end
            if tonumber(info.itemID) ~= itemID then return end
            local sellPrice = GetItemSellPrice(itemID)
            if not sellPrice or sellPrice <= 0 then return end

            local stack = tonumber(info.stackCount) or 1
            UseContainerItemSafe(bag, slot)
            sold = sold + stack
            ops = ops + 1
          end)
          Print("Selling: " .. tostring(math.min(sold, toSell)) .. "x " .. (GetItemNameSafe(itemID) or tostring(itemID)))
        end
      end
      sellPassRuleOps = (ops - before)
    end

    if dbg and (pendingFoodSell or pendingSellRules) then
      Print("Merchant debug: sell pass done (foodOps=" .. tostring(sellPassFoodOps) .. ", sellRuleOps=" .. tostring(sellPassRuleOps) .. ")")
    end

    if ops <= 0 then
      local reason = nil
      if _liMerchantSellBlockedUntilBag == true then
        reason = _liMerchantLastNoOpReason or "sell blocked"
      elseif _liMerchantWantsCache == true then
        reason = _liMerchantLastNoOpReason or "waiting merchant cache"
      else
        reason = "no eligible actions"
        if (not hasBuyRules) and (not hasSellRules) and (not foodEnabled) then
          reason = "no rules + food selling off"
        elseif (not hasBuyRules) and (not hasSellRules) and foodEnabled and (skipFoodSell == true or _liMerchantDidFoodSell == true) then
          reason = "food already processed this session"
        end
      end

      _liMerchantLastNoOpReason = reason
      if dbg and _liMerchantNoOpPrinted ~= true and _liMerchantSellBlockedUntilBag ~= true and _liMerchantWantsCache ~= true then
        Print("Merchant debug: no actions (" .. tostring(reason) .. ")")
        _liMerchantNoOpPrinted = true
      end
    end

    return ops
  end

  local function GetMerchantTickSummary()
    return _liMerchantLastTickSummary
  end

  local function IsCannotCarryMoreErrorMessage(msg)
    if type(msg) ~= "string" or msg == "" then return false end
    local g = _G or {}
    if msg == g.ERR_ITEM_MAX_COUNT then return true end
    if msg == g.ERR_MERCHANT_ITEM_MAX_COUNT_EXCEEDED then return true end
    local m = msg:lower()
    if m:find("carry any more", 1, true) then return true end
    return false
  end

  local function StopMerchantTradeTicker()
    if _liMerchantTicker and _liMerchantTicker.Cancel then
      _liMerchantTicker:Cancel()
    end
    _liMerchantTicker = nil
    _liMerchantDidFoodSell = false
    _liMerchantIdleTicks = 0
    _liMerchantBuyBaselineHave = nil
    _liMerchantBuySessionBought = nil
    _liMerchantNotSoldWarned = nil
    _liMerchantBuyBlocked = nil
    _liMerchantLastBuyAttempt = nil
    _liMerchantBuyPrinted = nil
    _liMerchantRestockComparePrinted = nil
    _liMerchantRestockLowerTierPrinted = nil
    _liMerchantPrewarmCursor = nil
    _liMerchantSellBlockedUntilBag = false
    _liMerchantSellWaitPrinted = false
    _liMerchantSellSawBagUpdate = false
    _liMerchantSellBagUpdateTS = nil
    _liMerchantSellPendingPrinted = false
    _liMerchantDebugSummaryPrinted = false
    _liMerchantDebugRulePrinted = false
    _liMerchantLastNoOpReason = nil
    _liMerchantNoOpPrinted = false
  end

  local function StartMerchantTradeTicker()
    -- Some clients/UIs can fire multiple "merchant open" signals (e.g. MERCHANT_SHOW +
    -- PLAYER_INTERACTION_MANAGER_FRAME_SHOW). If we restart here, we reset per-session
    -- tracking (baseline + sessionBought) and can immediately re-buy before bags update.
    if _liMerchantTicker then
      -- If we get a real reopen shortly after a close, the previous ticker can still
      -- be alive (close delay / interaction churn). Re-arm the sell pass so the
      -- new open actually runs food selling.
      local now = (type(GetTime) == "function") and GetTime() or nil
      if now and _liMerchantLastStartTS and (now - _liMerchantLastStartTS) > 0.75 then
        _liMerchantDidFoodSell = false
        _liMerchantIdleTicks = 0
        _liMerchantSellBlockedUntilBag = false
        _liMerchantSellWaitPrinted = false
        _liMerchantSellPendingPrinted = false
      end
      if now then
        _liMerchantLastStartTS = now
      end
      if LI and LI.Trade and LI.Trade._debugOn == true then
        Print("Merchant ticker: already running")
      end
      return
    end

    StopMerchantTradeTicker()

    _liMerchantLastStartTS = (type(GetTime) == "function") and GetTime() or nil

    _liMerchantBuyBaselineHave = {}
    _liMerchantBuySessionBought = {}
    _liMerchantNotSoldWarned = {}
    _liMerchantBuyBlocked = {}
    _liMerchantLastBuyAttempt = nil
    _liMerchantBuyPrinted = {}
    _liMerchantRestockComparePrinted = {}
    _liMerchantRestockLowerTierPrinted = {}
    _liMerchantPrewarmCursor = nil

    _liMerchantSellBlockedUntilBag = false
    _liMerchantSellWaitPrinted = false
    _liMerchantSellSawBagUpdate = false
    _liMerchantSellBagUpdateTS = nil
    _liMerchantSellPendingPrinted = false

    _liMerchantDebugSummaryPrinted = false
    _liMerchantDebugRulePrinted = false

    _liMerchantLastNoOpReason = nil
    _liMerchantNoOpPrinted = false

    if not (C_Timer and type(C_Timer.NewTicker) == "function") then
      RunMerchantTradeOnce(false)
      return
    end

    _liMerchantTicker = C_Timer.NewTicker(0.20, function()
      local ok, err = pcall(function()
        -- IMPORTANT: don't require MerchantFrame:IsShown(). Some UIs (and some first-open
        -- paths) can delay-create or replace the default MerchantFrame; MERCHANT_CLOSED
        -- is the authoritative stop signal.

        local opsDone = RunMerchantTradeOnce(_liMerchantDidFoodSell == true)
        opsDone = tonumber(opsDone) or 0

        local tradeDebug = false
        if LI and type(LI.GetDB) == "function" then
          local DB = LI.GetDB()
          if DB and DB.deposit and DB.deposit.tradeDebug == true then
            tradeDebug = true
          end
        end

        if tradeDebug or (LI and LI.Trade and LI.Trade._debugOn == true) then
          local pending = nil
          local attempt = _liMerchantLastBuyAttempt
          local id = attempt and tonumber(attempt.id) or nil
          if id and id > 0 then
            pending = GetPendingBought(id)
          end
          _liMerchantLastTickSummary = string.format(
            "tick ops=%d didFoodSell=%s blocked=%s sawBag=%s pending=%s idle=%s",
            opsDone,
            tostring(_liMerchantDidFoodSell == true),
            tostring(_liMerchantSellBlockedUntilBag == true),
            tostring(_liMerchantSellSawBagUpdate == true),
            tostring(pending),
            tostring(_liMerchantIdleTicks or 0)
          )
        else
          _liMerchantLastTickSummary = nil
        end

        -- Don't auto-stop while we're explicitly waiting for post-buy bag updates.
        if _liMerchantSellBlockedUntilBag == true then
          _liMerchantIdleTicks = 0
        elseif opsDone <= 0 then
          if _liMerchantWantsCache == true then
            _liMerchantIdleTicks = 0
          else
            _liMerchantIdleTicks = (_liMerchantIdleTicks or 0) + 1
          end
        else
          _liMerchantIdleTicks = 0
        end

        if (_liMerchantIdleTicks or 0) >= 25 then
          if LI and type(LI.GetDB) == "function" then
            local DB = LI.GetDB()
            if DB and DB.deposit and DB.deposit.tradeDebug == true then
              Print("Merchant ticker: idle stop (" .. tostring(_liMerchantLastNoOpReason or "no-op") .. ")")
            end
          end
          StopMerchantTradeTicker()
        end
      end)

      if not ok then
        if LI and LI.Trade and LI.Trade._debugOn == true then
          Print("Merchant ticker error: " .. tostring(err))
        end
        StopMerchantTradeTicker()
      end
    end)
  end

  LI.Trade.NormalizeTradeMode = NormalizeTradeMode
  LI.Trade.GetEffectiveTradeRules = GetEffectiveTradeRules
  LI.Trade.SellOldFoodAtMerchant = SellOldFoodAtMerchant
  LI.Trade.RunMerchantTradeOnce = RunMerchantTradeOnce
  LI.Trade.StartMerchantTradeTicker = StartMerchantTradeTicker
  LI.Trade.StopMerchantTradeTicker = StopMerchantTradeTicker

  function LI.Trade.OnBagUpdateDelayed(env)
    if _liMerchantTicker then
      _liMerchantSellSawBagUpdate = true
      _liMerchantSellBagUpdateTS = (type(GetTime) == "function") and GetTime() or nil

      local e = env or {}
      local DB = SafeCall(e.GetDB)
      if DB and DB.deposit and DB.deposit.tradeDebug == true then
        if _liMerchantSellBlockedUntilBag == true then
          SafeCall(e.Print, "Merchant debug: BAG_UPDATE_DELAYED seen (post-buy)")
        end
      end
    end
  end

  LI.Trade.GetMerchantTickSummary = GetMerchantTickSummary

  function LI.Trade.OnUIErrorMessage(env, arg1, arg2)
    -- UI_ERROR_MESSAGE can be (errType, msg) or (msg) depending on client.
    local msg = nil
    if type(arg2) == "string" then
      msg = arg2
    elseif type(arg1) == "string" then
      msg = arg1
    end
    if not IsCannotCarryMoreErrorMessage(msg) then return end

    local attempt = _liMerchantLastBuyAttempt
    local id = attempt and tonumber(attempt.id) or nil
    if not id or id <= 0 then return end

    local now = (type(GetTime) == "function") and GetTime() or nil
    if now and attempt and attempt.ts and (now - attempt.ts) > 1.25 then
      return
    end

    if type(_liMerchantBuyBlocked) ~= "table" then
      _liMerchantBuyBlocked = {}
    end
    _liMerchantBuyBlocked[id] = true

    local e = env or {}
    local DB = SafeCall(e.GetDB)
    if DB and DB.deposit and DB.deposit.tradeDebug == true then
      SafeCall(e.Print, "Merchant buy blocked (max/unique): " .. (GetItemNameSafe(id) or tostring(id)))
    end
  end
end

