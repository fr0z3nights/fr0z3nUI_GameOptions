local addonName, ns = ...
if type(ns) ~= "table" then ns = {} end

local LI = (ns and ns.LootIt) or fr0z3nUI_LootIt
if type(LI) ~= "table" then return end

ns.LootIt = LI
fr0z3nUI_LootIt = LI

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
    -- Macro friendly: only does something when bank UI is open.
    SafeCall(e.RunDeposit, nil)
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
    SafeCall(e.Print, "Merchant ticker: start")
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
    for bag = 0, 6 do
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
  local _liMerchantWantsCache = false

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
    if not low:find("health", 1, true) then return nil end

    local pct = low:match("restores%s+(%d+)%s*%%")
    pct = pct and tonumber(pct) or nil
    if not pct then return nil end

    local dur = low:match("over%s+(%d+)%s*sec") or low:match("for%s+(%d+)%s*sec")
    dur = dur and tonumber(dur) or nil

    local hasMana = (low:find("mana", 1, true) ~= nil)
    return {
      pct = pct,
      dur = dur,
      hasMana = hasMana,
    }
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
    if C_TooltipInfo and type(C_TooltipInfo.GetHyperlink) == "function" then
      local ok, tip = pcall(C_TooltipInfo.GetHyperlink, "item:" .. tostring(itemID))
      if ok and type(tip) == "table" and type(tip.lines) == "table" then
        for _, line in ipairs(tip.lines) do
          local left = (type(line) == "table") and line.leftText or nil
          if type(left) == "string" then
            tuple = ParseFoodDrinkUseLine(left)
            if tuple then break end
          end
        end
      end
    end

    if C_TooltipInfo and type(C_TooltipInfo.GetHyperlink) == "function" then
      _foodUseCacheByID[itemID] = tuple or false
    end
    return tuple
  end

  local function GetFoodDrinkCategoryKey(tuple)
    if type(tuple) ~= "table" then return nil end
    return "foodrestores"
  end

  local function FoodDrinkScore(tuple)
    if type(tuple) ~= "table" then return nil end
    local pct = tonumber(tuple.pct) or nil
    if not pct then return nil end
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

    if C_TooltipInfo and type(C_TooltipInfo.GetHyperlink) == "function" then
      local ok, tip = pcall(C_TooltipInfo.GetHyperlink, "item:" .. tostring(itemID))
      if ok and type(tip) == "table" and type(tip.lines) == "table" then
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

    if #useLines == 0 then
      if C_TooltipInfo and type(C_TooltipInfo.GetHyperlink) == "function" then
        _useKeyCacheByID[itemID] = false
      end
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

  local function PlayerUsesMana()
    if type(UnitPowerType) ~= "function" then return false end
    local pt = UnitPowerType("player")
    return (pt == 0)
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
    for i = 1, n do
      local link = type(GetMerchantItemLink) == "function" and GetMerchantItemLink(i) or nil
      if type(link) == "string" then
        local id = link:match("Hitem:(%d+):")
        id = id and tonumber(id) or nil
        if id == itemID then
          return i
        end
      end
    end
    return nil
  end

  local function GetItemRequiredPlayerLevel(itemID)
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
    if n <= 0 then return nil end

    local pl = (type(UnitLevel) == "function") and tonumber(UnitLevel("player")) or nil
    local best = { idx = nil, itemID = nil, score = nil, pct = nil, unitPrice = nil }

    for i = 1, n do
      local link = type(GetMerchantItemLink) == "function" and GetMerchantItemLink(i) or nil
      if type(link) == "string" then
        local id = link:match("Hitem:(%d+):")
        id = id and tonumber(id) or nil
        if id and id > 0 and IsItemUsableForPlayerLevel(id, pl) then
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
    end

    if not best.idx then return nil end
    return best
  end

  local function GetBestMerchantItemForUseKey(useKey, usesMana)
    if type(useKey) ~= "string" or useKey == "" then return nil end
    if type(GetMerchantNumItems) ~= "function" then return nil end
    local n = tonumber(GetMerchantNumItems()) or 0
    if n <= 0 then return nil end

    local pl = (type(UnitLevel) == "function") and tonumber(UnitLevel("player")) or nil
    local best = { idx = nil, itemID = nil, unitPrice = nil }

    for i = 1, n do
      local link = type(GetMerchantItemLink) == "function" and GetMerchantItemLink(i) or nil
      if type(link) == "string" then
        local id = link:match("Hitem:(%d+):")
        id = id and tonumber(id) or nil
        if id and id > 0 and IsItemUsableForPlayerLevel(id, pl) then
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
    local threshold = pl - diff

    local soldByID = {}
    local ops = 0
    local maxOps = 200

    IterateBagSlots(function(bag, slot)
      if ops >= maxOps then return end
      local info = GetBagItemInfo(bag, slot)
      if not info or info.isLocked then return end
      local itemID = tonumber(info.itemID)
      if not itemID or not IsFoodItemID(itemID) then return end
      if type(protectedIDs) == "table" and protectedIDs[itemID] == true then return end
      local link = nil
      if C_Container and type(C_Container.GetContainerItemLink) == "function" then
        local okL, vL = pcall(C_Container.GetContainerItemLink, bag, slot)
        link = okL and vL or nil
      end
      local req = GetItemMinLevel(itemID, link)
      if not req or req <= 0 then return end
      if req > threshold then return end
      local sellPrice = GetItemSellPrice(itemID)
      if not sellPrice or sellPrice <= 0 then return end

      local stack = tonumber(info.stackCount) or 1
      UseContainerItemSafe(bag, slot)
      soldByID[itemID] = (soldByID[itemID] or 0) + stack
      ops = ops + 1
    end)

    for id, cnt in pairs(soldByID) do
      local perItem = GetItemSellPrice(id)
      local total = (perItem and perItem > 0) and (perItem * cnt) or nil
      local moneyText = FormatGoldOnly(total or 0)
      local itemText = StripLinkBrackets(GetItemLinkSafe(id) or tostring(id))
      Print(GetClassColoredPlayerName() .. " " .. tostring(moneyText) .. "  Sold  " .. tostring(itemText) .. " x" .. tostring(cnt))
    end
  end

  local function IsSellFoodEnabled()
    SyncDB()
    local acc = DepositCfgAcc()
    local ch = DepositCfgChar()
    return ((acc and acc.sellFoodEnabledAcc) == true) or ((ch and ch.sellFoodEnabledChar) == true)
  end

  local function DebugSellOldFoodAtMerchant(levelDiff, maxLines)
    local diff = tonumber(levelDiff) or 10
    if diff < 1 then diff = 1 end
    if diff > 80 then diff = 80 end

    local pl = type(UnitLevel) == "function" and tonumber(UnitLevel("player")) or nil
    local threshold = (pl and pl > 1) and (pl - diff) or nil

    local mf = _G and rawget(_G, "MerchantFrame")
    local merchantShown = (mf and mf.IsShown and mf:IsShown()) and true or false

    Print("Food debug: merchantShown=" .. tostring(merchantShown) .. ", enabled=" .. tostring(IsSellFoodEnabled()) .. ", diff=" .. tostring(diff) .. ", player=" .. tostring(pl) .. ", threshold=" .. tostring(threshold))

    local lines = 0
    local cap = tonumber(maxLines) or 25
    if cap < 5 then cap = 5 end
    if cap > 60 then cap = 60 end

    local counts = { total = 0, food = 0, eligible = 0, locked = 0, noReq = 0, above = 0, noPrice = 0 }

    IterateBagSlots(function(bag, slot)
      if lines >= cap then return end

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

      local link = nil
      if C_Container and type(C_Container.GetContainerItemLink) == "function" then
        local okL, vL = pcall(C_Container.GetContainerItemLink, bag, slot)
        link = okL and vL or nil
      end

      local req = GetItemMinLevel(itemID, link)
      if not req or req <= 0 then counts.noReq = counts.noReq + 1 end

      local sellPrice = GetItemSellPrice(itemID)
      if not sellPrice or sellPrice <= 0 then counts.noPrice = counts.noPrice + 1 end

      local okThreshold = (threshold ~= nil) and (req ~= nil) and (req > 0) and (req <= threshold)
      if threshold ~= nil and req and req > threshold then counts.above = counts.above + 1 end

      local eligible = (not locked) and okThreshold and (sellPrice and sellPrice > 0)
      if eligible then counts.eligible = counts.eligible + 1 end

      local name = (GetItemNameSafe and GetItemNameSafe(itemID)) or tostring(itemID)
      local stack = tonumber(info.stackCount) or 1
      Print(string.format("Food slot: bag=%d slot=%d id=%d x%d class=%s/%s req=%s price=%s eligible=%s %s", bag, slot, itemID, stack, tostring(classID), tostring(subClassID), tostring(req), tostring(sellPrice), tostring(eligible), name))
      lines = lines + 1
    end)

    Print(string.format("Food debug summary: totalItems=%d, food=%d, eligible=%d, locked=%d, noReq=%d, aboveThreshold=%d, noPrice=%d", counts.total, counts.food, counts.eligible, counts.locked, counts.noReq, counts.above, counts.noPrice))
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

  local function RunMerchantTradeOnce(skipFoodSell)
    SyncDB()
    local mode = GetTradeMode()
    _liMerchantWantsCache = false

    local foodEnabled = IsSellFoodEnabled()
    local foodDiff = (DB and DB.deposit and tonumber(DB.deposit.sellFoodLevelDiff)) or 10
    foodDiff = foodDiff and math.floor(foodDiff) or 10
    if foodDiff < 1 then foodDiff = 1 end
    if foodDiff > 80 then foodDiff = 80 end

    if (skipFoodSell ~= true) and foodEnabled then
      local protected = nil
      local buyRules = GetEffectiveTradeRules("buy")
      if type(buyRules) == "table" and next(buyRules) then
        protected = {}
        for id in pairs(buyRules) do
          id = tonumber(id)
          if id and id > 0 then
            protected[id] = true
          end
        end
      end
      SellOldFoodAtMerchant(foodDiff, protected)
    end

    local dbg = (LI and LI.Trade and LI.Trade._debugOn == true) and true or false

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

      local buyRules = GetEffectiveTradeRules("buy")
      local sellRules = GetEffectiveTradeRules("sell")
      local bn, br = CountRules(buyRules)
      local sn, sr = CountRules(sellRules)
      Print(
        "Merchant debug: mode=" .. tostring(mode) ..
        ", buyRules=" .. tostring(bn) .. " (restock " .. tostring(br) .. ")" ..
        ", sellRules=" .. tostring(sn) .. " (restock " .. tostring(sr) .. ")"
      )
      _liMerchantDebugSummaryPrinted = true
    end

    if mode ~= "buy" and mode ~= "sell" then
      if dbg and _liMerchantDebugRulePrinted ~= true then
        Print("Merchant debug: not in Buy/Sell mode; no vendor actions will run.")
        _liMerchantDebugRulePrinted = true
      end
      return 0
    end

    local rules = GetEffectiveTradeRules(mode)
    if type(rules) ~= "table" then return 0 end

    local any = false
    for _, r in pairs(rules) do
      any = true
      if r and r.restock == true then
        -- marker only
      end
    end
    if not any then
      if dbg and _liMerchantDebugRulePrinted ~= true then
        Print("Merchant debug: no effective rules in this mode (all disabled or missing Target count).")
        _liMerchantDebugRulePrinted = true
      end
      return 0
    end

    local usesMana = PlayerUsesMana()
    local pl = (type(UnitLevel) == "function") and tonumber(UnitLevel("player")) or nil
    local ops = 0
    local maxOps = 200

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

    local function GetHaveCount(id)
      id = tonumber(id)
      if not id or id <= 0 then return 0 end

      local raw = CountItemInBags(id) or 0

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

    if mode == "buy" then
      local restockGroupTarget = {}
      local restockGroupSeed = {}
      for itemID, r in pairs(rules) do
        itemID = tonumber(itemID)
        local target = r and tonumber(r.count) or nil
        if itemID and itemID > 0 and r and r.restock == true and target and target > 0 then
          local gk = GetRestockGroupKey(itemID)
          if gk then
            local cur = tonumber(restockGroupTarget[gk])
            if (cur == nil) or (target > cur) then
              restockGroupTarget[gk] = target
            end

            local prev = tonumber(restockGroupSeed[gk])
            if prev == nil then
              restockGroupSeed[gk] = itemID
            else
              local prevUsable = IsItemUsableForPlayerLevel(prev, pl)
              local thisUsable = IsItemUsableForPlayerLevel(itemID, pl)
              local prevReq = GetItemRequiredPlayerLevel(prev) or 0
              local thisReq = GetItemRequiredPlayerLevel(itemID) or 0

              local better = false
              if thisUsable and not prevUsable then
                better = true
              elseif thisUsable == prevUsable then
                if thisReq < prevReq then
                  better = true
                elseif thisReq == prevReq and itemID < prev then
                  better = true
                end
              end

              if better then
                restockGroupSeed[gk] = itemID
              end
            end
          end
        end
      end

      for itemID, r in pairs(rules) do
        if ops >= maxOps then break end
        local target = r and tonumber(r.count) or nil
        if target and target > 0 then
          local skipThisRule = false
          if r and r.restock == true then
            local gk = GetRestockGroupKey(itemID)
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
              local cat = fd and GetFoodDrinkCategoryKey(fd) or nil
              if cat then
                local best = GetBestMerchantFoodDrinkForCategory(cat, usesMana)
                local skipLowerTierVendor = false
                if best and best.score then
                  local maxBag = GetMaxFoodDrinkScoreInBags(cat)
                  if maxBag and maxBag > best.score then
                    skipLowerTierVendor = true
                    Print("Restock skipped (merchant lower tier): " .. (GetItemNameSafe(itemID) or tostring(itemID)))
                  end
                end

                if skipLowerTierVendor then
                  current = target
                else
                  local desiredScore = (best and best.score) or FoodDrinkScore(fd) or 0
                  current = CountFoodDrinkAtOrAboveInBags(cat, desiredScore)
                  if best and best.itemID then
                    current = current + GetPendingBought(best.itemID)
                  else
                    current = current + GetPendingBought(itemID)
                  end
                end
              else
                local key = GetUseKeyForItemID(itemID)
                if key then
                  local hasMana = (key:sub(-7) == "|mana:1")
                  if (not usesMana) and hasMana then
                    current = target
                  else
                    local best = GetBestMerchantItemForUseKey(key, usesMana)
                    current = CountEquivalentByUseKeyInBags(key)
                    if best and best.itemID then
                      current = current + GetPendingBought(best.itemID)
                    else
                      current = current + GetPendingBought(itemID)
                    end
                  end
                else
                  current = GetHaveCount(itemID)
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
                local cat = fd and GetFoodDrinkCategoryKey(fd) or nil
                if cat then
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
                else
                  local key = GetUseKeyForItemID(itemID)
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

                if not buyID and IsItemUsableForPlayerLevel(itemID, pl) then
                  if _liMerchantWantsCache == true then
                    buyID, idx = nil, nil
                  else
                    buyID, idx = itemID, nil
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
                Print(
                  "Merchant debug buy: freeSlots=" .. tostring(freeSlots) ..
                  ", buyID=" .. tostring(buyID) ..
                  ", idx=" .. tostring(idx)
                )
                _liMerchantDebugRulePrinted = true
              end
              if buyID and idx and type(BuyMerchantItem) == "function" then
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

                  local maxCall = tonumber(bi.maxStack) or 0
                  if maxCall > 0 and buyCount > maxCall then buyCount = maxCall end
                  if buyCount > 200 then buyCount = 200 end

                  local p = tonumber(price) or 0
                  if p > 0 and type(GetMoney) == "function" then
                    local money = tonumber(GetMoney()) or 0
                    local maxAffordable = math.floor(money / p)
                    if maxAffordable < buyCount then buyCount = maxAffordable end
                  end

                  if buyCount > 0 then
                    pcall(BuyMerchantItem, idx, buyCount)
                    if type(_liMerchantBuySessionBought) == "table" then
                      local id = tonumber(buyID)
                      if id and id > 0 then
                        _liMerchantBuySessionBought[id] = (tonumber(_liMerchantBuySessionBought[id]) or 0) + buyCount
                      end
                    end
                    ops = ops + 1
                    Print("Buying: " .. tostring(buyCount) .. "x " .. (name or (GetItemNameSafe(buyID) or tostring(buyID))))
                    return ops
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
      return ops
    end

    for itemID, r in pairs(rules) do
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
    return ops
  end

  local _liMerchantTicker
  local _liMerchantDidFoodSell = false
  local _liMerchantIdleTicks = 0

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
    _liMerchantDebugSummaryPrinted = false
    _liMerchantDebugRulePrinted = false
  end

  local function StartMerchantTradeTicker()
    StopMerchantTradeTicker()

    _liMerchantBuyBaselineHave = {}
    _liMerchantBuySessionBought = {}
    _liMerchantNotSoldWarned = {}

    _liMerchantDebugSummaryPrinted = false
    _liMerchantDebugRulePrinted = false

    if not (C_Timer and type(C_Timer.NewTicker) == "function") then
      RunMerchantTradeOnce(false)
      return
    end

    _liMerchantTicker = C_Timer.NewTicker(0.20, function()
      local ok, err = pcall(function()
        local mf = _G and rawget(_G, "MerchantFrame")
        if not (mf and mf.IsShown and mf:IsShown()) then
          StopMerchantTradeTicker()
          return
        end

        local opsDone = RunMerchantTradeOnce(_liMerchantDidFoodSell == true)
        _liMerchantDidFoodSell = true
        opsDone = tonumber(opsDone) or 0

        if opsDone <= 0 then
          if _liMerchantWantsCache == true then
            _liMerchantIdleTicks = 0
          else
            _liMerchantIdleTicks = (_liMerchantIdleTicks or 0) + 1
          end
        else
          _liMerchantIdleTicks = 0
        end

        if (_liMerchantIdleTicks or 0) >= 25 then
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
end

