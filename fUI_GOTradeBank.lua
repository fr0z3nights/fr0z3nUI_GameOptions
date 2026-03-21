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

local DB
local CHARDB
local function EnsureDB()
  if LI and type(LI.EnsureDB) == "function" then
    LI.EnsureDB()
  end
  if LI and type(LI.GetDB) == "function" then
    DB = LI.GetDB()
  end
  if LI and type(LI.GetCharDB) == "function" then
    CHARDB = LI.GetCharDB()
  end
end

local function Print(msg)
  if LI and type(LI.Print) == "function" then
    LI.Print(msg)
  end
end

local function IsTradeDebugEnabled(env)
  local e = env or {}
  local DB2 = SafeCall(e.GetDB)
  return (DB2 and DB2.deposit and DB2.deposit.tradeDebug == true) and true or false
end

-- Bank ticker lifecycle handlers (used by core OnEvent).
function LI.Trade.OnBankFrameOpened(env)
  local e = env or {}
  if IsTradeDebugEnabled(e) then
    SafeCall(e.Print, "Bank ticker: start")
  end
  SafeCall(e.StartBankTicker)
end

function LI.Trade.OnBankFrameClosed(env)
  local e = env or {}
  if IsTradeDebugEnabled(e) then
    SafeCall(e.Print, "Bank ticker: stop")
  end
  SafeCall(e.StopBankTicker)
end

-- Banking interaction tracking via PlayerInteractionManager (Banker/AccountBanker/GuildBanker).
function LI.Trade.OnInteractionBanking(env, isShow, isBanker, isAccountBanker, isGuildBanker)
  local e = env or {}
  if not (isBanker or isAccountBanker or isGuildBanker) then
    return false
  end

  if isBanker then
    if IsTradeDebugEnabled(e) then
      SafeCall(e.Print, "Bank interaction: Banker " .. ((isShow and "show") or "hide"))
    end
    SafeCall(e.SetBankInteractionOpen, isShow)
  elseif isAccountBanker then
    if IsTradeDebugEnabled(e) then
      SafeCall(e.Print, "Bank interaction: AccountBanker " .. ((isShow and "show") or "hide"))
    end
    SafeCall(e.SetWarbankInteractionOpen, isShow)
  elseif isGuildBanker then
    if IsTradeDebugEnabled(e) then
      SafeCall(e.Print, "Bank interaction: GuildBanker " .. ((isShow and "show") or "hide"))
    end
    SafeCall(e.SetGuildbankInteractionOpen, isShow)
    if isShow then
      SafeCall(e.ResetGuildBankQuerySession)
    end
  end

  SafeCall(e.UpdateDepositButtonVisibility)
  return true
end

-- Classic bank / guild bank frame events (supplement InteractionManager on some client paths).
function LI.Trade.OnBankOrGuildBankFrameEvent(env, event)
  local e = env or {}
  local ev = tostring(event or "")
  if ev == "GUILDBANKFRAME_OPENED" or ev == "GUILDBANKFRAME_CLOSED" then
    SafeCall(e.ResetGuildBankQuerySession)
  end
  SafeCall(e.UpdateDepositButtonVisibility)
  return true
end

-- Deposit engine extracted from Host into this file.

-- Deposit helpers
local function DepositCfgAcc()
  EnsureDB()
  if type(DB) ~= "table" then
    return nil
  end
  DB.deposit = (type(DB.deposit) == "table") and DB.deposit or {}
  if DB.deposit.tradeMode == nil then DB.deposit.tradeMode = "deposit" end
  if DB.deposit.tradeDebug == nil then DB.deposit.tradeDebug = false end
  if DB.deposit.keepAmount == nil then DB.deposit.keepAmount = 0 end
  if DB.deposit.stackPull == nil then DB.deposit.stackPull = false end -- legacy; replaced by stackPullByItem
  DB.deposit.stackPullByItem = (type(DB.deposit.stackPullByItem) == "table") and DB.deposit.stackPullByItem or {}
  DB.deposit.keepByItem = (type(DB.deposit.keepByItem) == "table") and DB.deposit.keepByItem or {}
  DB.deposit.keepScopeByItem = (type(DB.deposit.keepScopeByItem) == "table") and DB.deposit.keepScopeByItem or {}
  DB.deposit.itemsAcc = (type(DB.deposit.itemsAcc) == "table") and DB.deposit.itemsAcc or {}
  DB.deposit.itemsAccDisabled = (type(DB.deposit.itemsAccDisabled) == "table") and DB.deposit.itemsAccDisabled or {}
  DB.deposit.itemsAccDisableRealm = (type(DB.deposit.itemsAccDisableRealm) == "table") and DB.deposit.itemsAccDisableRealm or {}
  DB.deposit.itemsRealm = (type(DB.deposit.itemsRealm) == "table") and DB.deposit.itemsRealm or {}
  DB.deposit.itemsRealmDisabled = (type(DB.deposit.itemsRealmDisabled) == "table") and DB.deposit.itemsRealmDisabled or {}

  -- Per-target Deposit item lists (legacy feature).
  -- New behavior (reverted): Deposit rules are a SINGLE shared list; target only
  -- controls destination. The per-target tables remain for compatibility but are
  -- aliased back to the shared tables.
  DB.deposit.itemsAccByTarget = (type(DB.deposit.itemsAccByTarget) == "table") and DB.deposit.itemsAccByTarget or {}
  DB.deposit.itemsAccDisabledByTarget = (type(DB.deposit.itemsAccDisabledByTarget) == "table") and DB.deposit.itemsAccDisabledByTarget or {}
  DB.deposit.itemsAccDisableRealmByTarget = (type(DB.deposit.itemsAccDisableRealmByTarget) == "table") and DB.deposit.itemsAccDisableRealmByTarget or {}
  DB.deposit.itemsRealmByTarget = (type(DB.deposit.itemsRealmByTarget) == "table") and DB.deposit.itemsRealmByTarget or {}
  DB.deposit.itemsRealmDisabledByTarget = (type(DB.deposit.itemsRealmDisabledByTarget) == "table") and DB.deposit.itemsRealmDisabledByTarget or {}

  -- Migration: earlier builds used non-canonical target keys (e.g. warband/personalbank).
  -- Normalize/merge those keys into the current canonical set.
  if DB.deposit._targetKeyMigrated ~= true then
    local function EnsureTargetTable(parent, key)
      parent[key] = (type(parent[key]) == "table") and parent[key] or {}
      return parent[key]
    end

    local function MergeItemTable(fromTbl, toTbl)
      if type(fromTbl) ~= "table" or type(toTbl) ~= "table" then return end
      for k, v in pairs(fromTbl) do
        if v == true then
          toTbl[k] = true
        end
      end
    end

    local function MergeRealmItemTable(fromTbl, toTbl)
      if type(fromTbl) ~= "table" or type(toTbl) ~= "table" then return end
      for realmKey, realmTbl in pairs(fromTbl) do
        if type(realmKey) == "string" and realmKey ~= "" and type(realmTbl) == "table" then
          toTbl[realmKey] = (type(toTbl[realmKey]) == "table") and toTbl[realmKey] or {}
          MergeItemTable(realmTbl, toTbl[realmKey])
        end
      end
    end

    local function MigrateTarget(parent, fromKey, toKey, isRealmMap)
      if type(parent) ~= "table" then return end
      local fromTbl = parent[fromKey]
      if type(fromTbl) ~= "table" then return end
      local toTbl = EnsureTargetTable(parent, toKey)
      if isRealmMap == true then
        MergeRealmItemTable(fromTbl, toTbl)
      else
        MergeItemTable(fromTbl, toTbl)
      end
      parent[fromKey] = nil
    end

    -- Simple per-item maps.
    MigrateTarget(DB.deposit.itemsAccByTarget, "either", "bank", false)
    MigrateTarget(DB.deposit.itemsAccByTarget, "personalbank", "personal", false)
    MigrateTarget(DB.deposit.itemsAccByTarget, "guildbank", "guild", false)
    MigrateTarget(DB.deposit.itemsAccByTarget, "warband", "warbank", false)

    MigrateTarget(DB.deposit.itemsAccDisabledByTarget, "either", "bank", false)
    MigrateTarget(DB.deposit.itemsAccDisabledByTarget, "personalbank", "personal", false)
    MigrateTarget(DB.deposit.itemsAccDisabledByTarget, "guildbank", "guild", false)
    MigrateTarget(DB.deposit.itemsAccDisabledByTarget, "warband", "warbank", false)

    -- Realm->item maps.
    MigrateTarget(DB.deposit.itemsAccDisableRealmByTarget, "either", "bank", true)
    MigrateTarget(DB.deposit.itemsAccDisableRealmByTarget, "personalbank", "personal", true)
    MigrateTarget(DB.deposit.itemsAccDisableRealmByTarget, "guildbank", "guild", true)
    MigrateTarget(DB.deposit.itemsAccDisableRealmByTarget, "warband", "warbank", true)

    MigrateTarget(DB.deposit.itemsRealmByTarget, "either", "bank", true)
    MigrateTarget(DB.deposit.itemsRealmByTarget, "personalbank", "personal", true)
    MigrateTarget(DB.deposit.itemsRealmByTarget, "guildbank", "guild", true)
    MigrateTarget(DB.deposit.itemsRealmByTarget, "warband", "warbank", true)

    MigrateTarget(DB.deposit.itemsRealmDisabledByTarget, "either", "bank", true)
    MigrateTarget(DB.deposit.itemsRealmDisabledByTarget, "personalbank", "personal", true)
    MigrateTarget(DB.deposit.itemsRealmDisabledByTarget, "guildbank", "guild", true)
    MigrateTarget(DB.deposit.itemsRealmDisabledByTarget, "warband", "warbank", true)

    DB.deposit._targetKeyMigrated = true
  end

  local function EnsureTargetTable(parent, key)
    parent[key] = (type(parent[key]) == "table") and parent[key] or {}
    return parent[key]
  end

  -- One-time migration: convert legacy per-target deposit lists into destination-tagged
  -- rules stored in the shared tables (itemsAcc/itemsRealm).
  if DB.deposit._destTagMigrated ~= true then
    local function NormalizeDest(v)
      v = tostring(v or "")
      v = v:lower():gsub("%s+", "")
      if v == "either" then v = "bank" end
      if v == "warband" then v = "warbank" end
      if v == "personalbank" then v = "personal" end
      if v == "guildbank" then v = "guild" end
      if v ~= "bank" and v ~= "personal" and v ~= "guild" and v ~= "warbank" then
        v = "bank"
      end
      return v
    end

    local function NormalizeTaggedValue(val)
      if val == true or val == 1 then
        return "bank"
      end
      if type(val) == "string" then
        return NormalizeDest(val)
      end
      return nil
    end

    local function EnsureRealmTable(parent, realmKey)
      parent[realmKey] = (type(parent[realmKey]) == "table") and parent[realmKey] or {}
      return parent[realmKey]
    end

    -- Normalize legacy booleans in shared tables (true -> "bank").
    for id, val in pairs(DB.deposit.itemsAcc or {}) do
      local d = NormalizeTaggedValue(val)
      if d then
        DB.deposit.itemsAcc[id] = d
      end
    end
    for realmKey, realmTbl in pairs(DB.deposit.itemsRealm or {}) do
      if type(realmKey) == "string" and realmKey ~= "" and type(realmTbl) == "table" then
        for id, val in pairs(realmTbl) do
          local d = NormalizeTaggedValue(val)
          if d then
            realmTbl[id] = d
          end
        end
      end
    end

    local keys = { "bank", "personal", "guild", "warbank", "either", "personalbank", "guildbank", "warband" }
    for i = 1, #keys do
      local fromKey = keys[i]
      local dest = NormalizeDest(fromKey)

      local fromAcc = EnsureTargetTable(DB.deposit.itemsAccByTarget, fromKey)
      for id, on in pairs(fromAcc) do
        if on == true then
          id = tonumber(id)
          if id and id > 0 and DB.deposit.itemsAcc[id] == nil then
            DB.deposit.itemsAcc[id] = dest
          end
        end
      end

      local fromAccDisabled = EnsureTargetTable(DB.deposit.itemsAccDisabledByTarget, fromKey)
      for id, on in pairs(fromAccDisabled) do
        if on == true then
          id = tonumber(id)
          if id and id > 0 then
            DB.deposit.itemsAccDisabled[id] = true
          end
        end
      end

      local fromAccDisableRealm = EnsureTargetTable(DB.deposit.itemsAccDisableRealmByTarget, fromKey)
      for realmKey, realmTbl in pairs(fromAccDisableRealm) do
        if type(realmKey) == "string" and realmKey ~= "" and type(realmTbl) == "table" then
          local outRealm = EnsureRealmTable(DB.deposit.itemsAccDisableRealm, realmKey)
          for id, on in pairs(realmTbl) do
            if on == true then
              id = tonumber(id)
              if id and id > 0 then
                outRealm[id] = true
              end
            end
          end
        end
      end

      local fromRealm = EnsureTargetTable(DB.deposit.itemsRealmByTarget, fromKey)
      for realmKey, realmTbl in pairs(fromRealm) do
        if type(realmKey) == "string" and realmKey ~= "" and type(realmTbl) == "table" then
          local outRealm = EnsureRealmTable(DB.deposit.itemsRealm, realmKey)
          for id, on in pairs(realmTbl) do
            if on == true then
              id = tonumber(id)
              if id and id > 0 and outRealm[id] == nil then
                outRealm[id] = dest
              end
            end
          end
        end
      end

      local fromRealmDisabled = EnsureTargetTable(DB.deposit.itemsRealmDisabledByTarget, fromKey)
      for realmKey, realmTbl in pairs(fromRealmDisabled) do
        if type(realmKey) == "string" and realmKey ~= "" and type(realmTbl) == "table" then
          local outRealm = EnsureRealmTable(DB.deposit.itemsRealmDisabled, realmKey)
          for id, on in pairs(realmTbl) do
            if on == true then
              id = tonumber(id)
              if id and id > 0 then
                outRealm[id] = true
              end
            end
          end
        end
      end
    end

    DB.deposit._destTagMigrated = true
  end
  DB.deposit.guildTabByRealm = (type(DB.deposit.guildTabByRealm) == "table") and DB.deposit.guildTabByRealm or {}
  DB.deposit.guildTabRandomByRealm = (type(DB.deposit.guildTabRandomByRealm) == "table") and DB.deposit.guildTabRandomByRealm or {}
  if DB.deposit.guildTabRandom == nil then DB.deposit.guildTabRandom = false end
  DB.deposit.buyItemsAcc = (type(DB.deposit.buyItemsAcc) == "table") and DB.deposit.buyItemsAcc or {}
  DB.deposit.buyItemsAccDisabled = (type(DB.deposit.buyItemsAccDisabled) == "table") and DB.deposit.buyItemsAccDisabled or {}
  DB.deposit.buyItemsAccDisableRealm = (type(DB.deposit.buyItemsAccDisableRealm) == "table") and DB.deposit.buyItemsAccDisableRealm or {}
  DB.deposit.buyItemsRealm = (type(DB.deposit.buyItemsRealm) == "table") and DB.deposit.buyItemsRealm or {}
  DB.deposit.buyItemsRealmDisabled = (type(DB.deposit.buyItemsRealmDisabled) == "table") and DB.deposit.buyItemsRealmDisabled or {}
  DB.deposit.sellItemsAcc = (type(DB.deposit.sellItemsAcc) == "table") and DB.deposit.sellItemsAcc or {}
  DB.deposit.sellItemsAccDisabled = (type(DB.deposit.sellItemsAccDisabled) == "table") and DB.deposit.sellItemsAccDisabled or {}
  DB.deposit.sellItemsAccDisableRealm = (type(DB.deposit.sellItemsAccDisableRealm) == "table") and DB.deposit.sellItemsAccDisableRealm or {}
  DB.deposit.sellItemsRealm = (type(DB.deposit.sellItemsRealm) == "table") and DB.deposit.sellItemsRealm or {}
  DB.deposit.sellItemsRealmDisabled = (type(DB.deposit.sellItemsRealmDisabled) == "table") and DB.deposit.sellItemsRealmDisabled or {}

  -- One-time migration (stage 1): old global keepAmount -> per-item keepByItem for
  -- account/realm Deposit items. Character items are migrated in DepositCfgChar
  -- (stage 2) after CHARDB tables are initialized.
  if DB.deposit._keepMigratedAcc ~= true then
    local legacy = tonumber(DB.deposit.keepAmount) or 0
    legacy = legacy and math.floor(legacy) or 0
    if legacy < 1 then legacy = 0 end
    if legacy > 9999 then legacy = 9999 end

    DB.deposit._keepLegacyValue = (legacy > 0) and legacy or nil

    if legacy > 0 then
      local function applyTo(tbl)
        if type(tbl) ~= "table" then return end
        for k, v in pairs(tbl) do
          if v == true then
            local id = tonumber(k)
            if id and id > 0 and DB.deposit.keepByItem[id] == nil then
              DB.deposit.keepByItem[id] = legacy
            end
          end
        end
      end

      applyTo(DB.deposit.itemsAcc)
      if type(DB.deposit.itemsRealm) == "table" then
        for _, realmTbl in pairs(DB.deposit.itemsRealm) do
          applyTo(realmTbl)
        end
      end
    end

    -- Clear legacy value to avoid UI confusion.
    DB.deposit.keepAmount = 0
    DB.deposit._keepMigratedAcc = true
  end
  return DB.deposit
end

LI.DepositCfgAcc = DepositCfgAcc

-- Forward declarations required for earlier helpers that reference these.
-- (Lua locals are scoped from the declaration downward; without this, earlier
-- references bind to a global and silently become nil at runtime.)
local QueryGuildBankTabIfNeeded

local function GetCurrentGuildKey()
  if type(IsInGuild) == "function" then
    local ok, inGuild = pcall(IsInGuild)
    if ok and inGuild ~= true then
      return nil
    end
  end
  if type(GetGuildInfo) ~= "function" then
    return nil
  end
  local ok, guildName = pcall(GetGuildInfo, "player")
  guildName = ok and guildName or nil
  if type(guildName) ~= "string" or guildName == "" then
    return nil
  end
  local realm = (type(GetRealmName) == "function") and GetRealmName() or nil
  realm = (type(realm) == "string" and realm ~= "") and realm or ""
  return realm .. "::" .. guildName, guildName, realm
end

local function GetCurrentRealmKey()
  local rn = (type(GetRealmName) == "function") and GetRealmName() or nil
  rn = (type(rn) == "string" and rn ~= "") and rn or ""
  return rn
end

local function DepositCfgRealm()
  local cfg = DepositCfgAcc()
  if type(cfg) ~= "table" then
    return nil, nil
  end
  local rk = GetCurrentRealmKey()
  if rk == "" then
    return nil, nil
  end
  cfg.itemsRealm = (type(cfg.itemsRealm) == "table") and cfg.itemsRealm or {}
  cfg.itemsRealm[rk] = (type(cfg.itemsRealm[rk]) == "table") and cfg.itemsRealm[rk] or {}
  return cfg.itemsRealm[rk], rk
end

local function DepositCfgChar()
  EnsureDB()
  CHARDB.deposit = (type(CHARDB.deposit) == "table") and CHARDB.deposit or {}
  CHARDB.deposit.itemsChar = (type(CHARDB.deposit.itemsChar) == "table") and CHARDB.deposit.itemsChar or {}
  CHARDB.deposit.itemsCharDisabled = (type(CHARDB.deposit.itemsCharDisabled) == "table") and CHARDB.deposit.itemsCharDisabled or {}
  CHARDB.deposit.disableAcc = (type(CHARDB.deposit.disableAcc) == "table") and CHARDB.deposit.disableAcc or {}
  CHARDB.deposit.disableRealm = (type(CHARDB.deposit.disableRealm) == "table") and CHARDB.deposit.disableRealm or {}
  CHARDB.deposit.buyItemsChar = (type(CHARDB.deposit.buyItemsChar) == "table") and CHARDB.deposit.buyItemsChar or {}
  CHARDB.deposit.buyItemsCharDisabled = (type(CHARDB.deposit.buyItemsCharDisabled) == "table") and CHARDB.deposit.buyItemsCharDisabled or {}
  CHARDB.deposit.buyDisableAcc = (type(CHARDB.deposit.buyDisableAcc) == "table") and CHARDB.deposit.buyDisableAcc or {}
  CHARDB.deposit.buyDisableRealm = (type(CHARDB.deposit.buyDisableRealm) == "table") and CHARDB.deposit.buyDisableRealm or {}
  CHARDB.deposit.sellItemsChar = (type(CHARDB.deposit.sellItemsChar) == "table") and CHARDB.deposit.sellItemsChar or {}
  CHARDB.deposit.sellItemsCharDisabled = (type(CHARDB.deposit.sellItemsCharDisabled) == "table") and CHARDB.deposit.sellItemsCharDisabled or {}
  CHARDB.deposit.sellDisableAcc = (type(CHARDB.deposit.sellDisableAcc) == "table") and CHARDB.deposit.sellDisableAcc or {}
  CHARDB.deposit.sellDisableRealm = (type(CHARDB.deposit.sellDisableRealm) == "table") and CHARDB.deposit.sellDisableRealm or {}

  -- Per-target Deposit item lists (legacy feature). Reverted behavior: single shared list.
  CHARDB.deposit.itemsCharByTarget = (type(CHARDB.deposit.itemsCharByTarget) == "table") and CHARDB.deposit.itemsCharByTarget or {}
  CHARDB.deposit.itemsCharDisabledByTarget = (type(CHARDB.deposit.itemsCharDisabledByTarget) == "table") and CHARDB.deposit.itemsCharDisabledByTarget or {}
  CHARDB.deposit.disableAccByTarget = (type(CHARDB.deposit.disableAccByTarget) == "table") and CHARDB.deposit.disableAccByTarget or {}
  CHARDB.deposit.disableRealmByTarget = (type(CHARDB.deposit.disableRealmByTarget) == "table") and CHARDB.deposit.disableRealmByTarget or {}

  -- Migration: earlier builds used non-canonical target keys (e.g. warband/personalbank).
  if CHARDB.deposit._targetKeyMigrated ~= true then
    local function EnsureTargetTable(parent, key)
      parent[key] = (type(parent[key]) == "table") and parent[key] or {}
      return parent[key]
    end

    local function MergeItemTable(fromTbl, toTbl)
      if type(fromTbl) ~= "table" or type(toTbl) ~= "table" then return end
      for k, v in pairs(fromTbl) do
        if v == true then
          toTbl[k] = true
        end
      end
    end

    local function MigrateTarget(parent, fromKey, toKey)
      if type(parent) ~= "table" then return end
      local fromTbl = parent[fromKey]
      if type(fromTbl) ~= "table" then return end
      local toTbl = EnsureTargetTable(parent, toKey)
      MergeItemTable(fromTbl, toTbl)
      parent[fromKey] = nil
    end

    MigrateTarget(CHARDB.deposit.itemsCharByTarget, "either", "bank")
    MigrateTarget(CHARDB.deposit.itemsCharByTarget, "personalbank", "personal")
    MigrateTarget(CHARDB.deposit.itemsCharByTarget, "guildbank", "guild")
    MigrateTarget(CHARDB.deposit.itemsCharByTarget, "warband", "warbank")

    MigrateTarget(CHARDB.deposit.itemsCharDisabledByTarget, "either", "bank")
    MigrateTarget(CHARDB.deposit.itemsCharDisabledByTarget, "personalbank", "personal")
    MigrateTarget(CHARDB.deposit.itemsCharDisabledByTarget, "guildbank", "guild")
    MigrateTarget(CHARDB.deposit.itemsCharDisabledByTarget, "warband", "warbank")

    MigrateTarget(CHARDB.deposit.disableAccByTarget, "either", "bank")
    MigrateTarget(CHARDB.deposit.disableAccByTarget, "personalbank", "personal")
    MigrateTarget(CHARDB.deposit.disableAccByTarget, "guildbank", "guild")
    MigrateTarget(CHARDB.deposit.disableAccByTarget, "warband", "warbank")

    MigrateTarget(CHARDB.deposit.disableRealmByTarget, "either", "bank")
    MigrateTarget(CHARDB.deposit.disableRealmByTarget, "personalbank", "personal")
    MigrateTarget(CHARDB.deposit.disableRealmByTarget, "guildbank", "guild")
    MigrateTarget(CHARDB.deposit.disableRealmByTarget, "warband", "warbank")

    CHARDB.deposit._targetKeyMigrated = true
  end

  local function EnsureTargetTable(parent, key)
    parent[key] = (type(parent[key]) == "table") and parent[key] or {}
    return parent[key]
  end

  -- One-time migration: convert legacy per-target char data into destination-tagged rules.
  if CHARDB.deposit._destTagMigrated ~= true then
    local function NormalizeDest(v)
      v = tostring(v or "")
      v = v:lower():gsub("%s+", "")
      if v == "either" then v = "bank" end
      if v == "warband" then v = "warbank" end
      if v == "personalbank" then v = "personal" end
      if v == "guildbank" then v = "guild" end
      if v ~= "bank" and v ~= "personal" and v ~= "guild" and v ~= "warbank" then
        v = "bank"
      end
      return v
    end

    local function NormalizeTaggedValue(val)
      if val == true or val == 1 then
        return "bank"
      end
      if type(val) == "string" then
        return NormalizeDest(val)
      end
      return nil
    end

    -- Normalize existing shared values (true -> "bank").
    for id, val in pairs(CHARDB.deposit.itemsChar or {}) do
      local d = NormalizeTaggedValue(val)
      if d then
        CHARDB.deposit.itemsChar[id] = d
      end
    end

    local keys = { "bank", "personal", "guild", "warbank", "either", "personalbank", "guildbank", "warband" }
    for i = 1, #keys do
      local fromKey = keys[i]
      local dest = NormalizeDest(fromKey)

      local from = EnsureTargetTable(CHARDB.deposit.itemsCharByTarget, fromKey)
      for id, on in pairs(from) do
        if on == true then
          id = tonumber(id)
          if id and id > 0 and CHARDB.deposit.itemsChar[id] == nil then
            CHARDB.deposit.itemsChar[id] = dest
          end
        end
      end

      local fromDisabled = EnsureTargetTable(CHARDB.deposit.itemsCharDisabledByTarget, fromKey)
      for id, on in pairs(fromDisabled) do
        if on == true then
          id = tonumber(id)
          if id and id > 0 then
            CHARDB.deposit.itemsCharDisabled[id] = true
          end
        end
      end

      local fromDisAcc = EnsureTargetTable(CHARDB.deposit.disableAccByTarget, fromKey)
      for id, on in pairs(fromDisAcc) do
        if on == true then
          id = tonumber(id)
          if id and id > 0 then
            CHARDB.deposit.disableAcc[id] = true
          end
        end
      end

      local fromDisRealm = EnsureTargetTable(CHARDB.deposit.disableRealmByTarget, fromKey)
      for id, on in pairs(fromDisRealm) do
        if on == true then
          id = tonumber(id)
          if id and id > 0 then
            CHARDB.deposit.disableRealm[id] = true
          end
        end
      end
    end

    CHARDB.deposit._destTagMigrated = true
  end

  -- Alias all per-target tables to the shared tables.
  EnsureTargetTable(CHARDB.deposit.itemsCharByTarget, "bank")
  EnsureTargetTable(CHARDB.deposit.itemsCharByTarget, "personal")
  EnsureTargetTable(CHARDB.deposit.itemsCharByTarget, "guild")
  EnsureTargetTable(CHARDB.deposit.itemsCharByTarget, "warbank")
  CHARDB.deposit.itemsCharByTarget.bank = CHARDB.deposit.itemsChar
  CHARDB.deposit.itemsCharByTarget.personal = CHARDB.deposit.itemsChar
  CHARDB.deposit.itemsCharByTarget.guild = CHARDB.deposit.itemsChar
  CHARDB.deposit.itemsCharByTarget.warbank = CHARDB.deposit.itemsChar

  EnsureTargetTable(CHARDB.deposit.itemsCharDisabledByTarget, "bank")
  EnsureTargetTable(CHARDB.deposit.itemsCharDisabledByTarget, "personal")
  EnsureTargetTable(CHARDB.deposit.itemsCharDisabledByTarget, "guild")
  EnsureTargetTable(CHARDB.deposit.itemsCharDisabledByTarget, "warbank")
  CHARDB.deposit.itemsCharDisabledByTarget.bank = CHARDB.deposit.itemsCharDisabled
  CHARDB.deposit.itemsCharDisabledByTarget.personal = CHARDB.deposit.itemsCharDisabled
  CHARDB.deposit.itemsCharDisabledByTarget.guild = CHARDB.deposit.itemsCharDisabled
  CHARDB.deposit.itemsCharDisabledByTarget.warbank = CHARDB.deposit.itemsCharDisabled

  EnsureTargetTable(CHARDB.deposit.disableAccByTarget, "bank")
  EnsureTargetTable(CHARDB.deposit.disableAccByTarget, "personal")
  EnsureTargetTable(CHARDB.deposit.disableAccByTarget, "guild")
  EnsureTargetTable(CHARDB.deposit.disableAccByTarget, "warbank")
  CHARDB.deposit.disableAccByTarget.bank = CHARDB.deposit.disableAcc
  CHARDB.deposit.disableAccByTarget.personal = CHARDB.deposit.disableAcc
  CHARDB.deposit.disableAccByTarget.guild = CHARDB.deposit.disableAcc
  CHARDB.deposit.disableAccByTarget.warbank = CHARDB.deposit.disableAcc

  EnsureTargetTable(CHARDB.deposit.disableRealmByTarget, "bank")
  EnsureTargetTable(CHARDB.deposit.disableRealmByTarget, "personal")
  EnsureTargetTable(CHARDB.deposit.disableRealmByTarget, "guild")
  EnsureTargetTable(CHARDB.deposit.disableRealmByTarget, "warbank")
  CHARDB.deposit.disableRealmByTarget.bank = CHARDB.deposit.disableRealm
  CHARDB.deposit.disableRealmByTarget.personal = CHARDB.deposit.disableRealm
  CHARDB.deposit.disableRealmByTarget.guild = CHARDB.deposit.disableRealm
  CHARDB.deposit.disableRealmByTarget.warbank = CHARDB.deposit.disableRealm

  -- One-time migration (stage 2): apply legacy keepAmount to character-scoped Deposit items.
  do
    local acc = DepositCfgAcc()
    if acc and acc._keepMigratedChar ~= true then
      local legacy = tonumber(acc._keepLegacyValue) or 0
      legacy = legacy and math.floor(legacy) or 0
      if legacy < 1 then legacy = 0 end
      if legacy > 9999 then legacy = 9999 end

      if legacy > 0 and type(acc.keepByItem) == "table" then
        for k, v in pairs(CHARDB.deposit.itemsChar or {}) do
          if v == true then
            local id = tonumber(k)
            if id and id > 0 and acc.keepByItem[id] == nil then
              acc.keepByItem[id] = legacy
            end
          end
        end
      end

      acc._keepMigratedChar = true
      if acc._keepMigratedAcc == true and acc._keepMigratedChar == true then
        acc._keepLegacyValue = nil
        acc._keepMigrated = true
      end
    end
  end
  return CHARDB.deposit
end

LI.DepositCfgChar = DepositCfgChar

local function NormalizeDepositDestInput(t)
  t = tostring(t or "")
  t = t:lower():gsub("%s+", "")
  if t == "either" then t = "bank" end
  if t == "warband" then t = "warbank" end
  if t == "personalbank" then t = "personal" end
  if t == "guildbank" then t = "guild" end
  if t ~= "bank" and t ~= "personal" and t ~= "guild" and t ~= "warbank" then
    t = ""
  end
  return t
end

local function NormalizeDepositRuleDest(v)
  if v == true or v == 1 then
    return "bank"
  end
  if type(v) == "string" then
    local t = NormalizeDepositDestInput(v)
    if t ~= "" then
      return t
    end
  end
  return nil
end

local function GetEffectiveDepositRuleMap()
  local acc = DepositCfgAcc()
  acc = (type(acc) == "table") and acc or {}
  local ch = DepositCfgChar()
  ch = (type(ch) == "table") and ch or {}
  local out = {}
  local src = {}
  local rk = GetCurrentRealmKey()

  local accItems = (type(acc.itemsAcc) == "table") and acc.itemsAcc or {}
  local accItemsDisabled = (type(acc.itemsAccDisabled) == "table") and acc.itemsAccDisabled or {}
  local accAccDisableRealmAll = (type(acc.itemsAccDisableRealm) == "table") and acc.itemsAccDisableRealm or {}
  local accDisableRealm = (rk ~= "" and type(accAccDisableRealmAll) == "table") and accAccDisableRealmAll[rk] or nil

  local realmItemsAll = (type(acc.itemsRealm) == "table") and acc.itemsRealm or nil
  local realmItems = (type(realmItemsAll) == "table") and realmItemsAll[rk] or nil
  local realmDisabledAll = (type(acc.itemsRealmDisabled) == "table") and acc.itemsRealmDisabled or nil
  local realmDisabled = (type(realmDisabledAll) == "table") and realmDisabledAll[rk] or nil

  local chItems = (type(ch.itemsChar) == "table") and ch.itemsChar or {}
  local chItemsDisabled = (type(ch.itemsCharDisabled) == "table") and ch.itemsCharDisabled or {}
  local chDisableAcc = (type(ch.disableAcc) == "table") and ch.disableAcc or {}
  local chDisableRealm = (type(ch.disableRealm) == "table") and ch.disableRealm or {}

  -- Account base
  for id, v in pairs(accItems) do
    id = tonumber(id)
    local dest = NormalizeDepositRuleDest(v)
    if id and id > 0 and dest
      and not (type(accItemsDisabled) == "table" and accItemsDisabled[id] == true)
      and not (type(accDisableRealm) == "table" and accDisableRealm[id] == true)
      and not (type(chDisableAcc) == "table" and chDisableAcc[id] == true)
    then
      out[id] = dest
      src[id] = "acc"
    end
  end

  -- Realm overrides Account
  if type(realmItems) == "table" then
    for id, v in pairs(realmItems) do
      id = tonumber(id)
      local dest = NormalizeDepositRuleDest(v)
      if id and id > 0 and dest
        and not (type(realmDisabled) == "table" and realmDisabled[id] == true)
        and not (type(chDisableRealm) == "table" and chDisableRealm[id] == true)
      then
        out[id] = dest
        src[id] = "realm"
      end
    end
  end

  -- Character overrides Realm/Account
  for id, v in pairs(chItems) do
    id = tonumber(id)
    local dest = NormalizeDepositRuleDest(v)
    if id and id > 0 and dest and not (type(chItemsDisabled) == "table" and chItemsDisabled[id] == true) then
      out[id] = dest
      src[id] = "char"
    end
  end

  return out, src
end

local function GetEffectiveDepositDestMap()
  local out = GetEffectiveDepositRuleMap()
  return out
end

function LI.GetEffectiveDepositRuleMap()
  return GetEffectiveDepositRuleMap()
end

local function GetEffectiveDepositItemIDs(destWanted)
  destWanted = NormalizeDepositDestInput(destWanted)
  local destMap = GetEffectiveDepositDestMap()
  local out = {}
  if destWanted == "" then
    for id in pairs(destMap) do
      out[id] = true
    end
    return out
  end

  for id, d in pairs(destMap) do
    if d == destWanted then
      out[id] = true
    elseif d == "bank" and (destWanted == "personal" or destWanted == "guild" or destWanted == "warbank") then
      out[id] = true
    end
  end

  return out
end

local _bankInteractionOpen = false
local _warbankInteractionOpen = false
local _guildbankInteractionOpen = false
local _taxWarbankOpen = false

local function IsGuildBankOpen()
  if _guildbankInteractionOpen == true then
    return true
  end
  local f = _G and rawget(_G, "GuildBankFrame")
  if f and f.IsShown and f:IsShown() then
    return true
  end
  return false
end

local function GetBankPanel()
  local p = _G and rawget(_G, "BankPanel")
  if p then return p end
  local bank = _G and rawget(_G, "BankFrame")
  if bank and bank.BankPanel then return bank.BankPanel end
  return nil
end

local function GetSelectedBankType()
  local p = GetBankPanel()
  if p and p.bankType ~= nil then
    return p.bankType
  end
  return nil
end

local function IsBankUIShown()
  local p = GetBankPanel()
  if p and p.IsShown and p:IsShown() then
    return true
  end
  local f = _G and rawget(_G, "BankFrame")
  if f and f.IsShown and f:IsShown() then
    return true
  end
  return false
end

local function TryAutoSortBankPanel()
  local p = GetBankPanel()
  local btn = p and p.AutoSortButton or nil
  if btn and btn.IsEnabled and btn:IsEnabled() and btn.Click then
    local ok = pcall(btn.Click, btn)
    return ok == true
  end

  -- Fallbacks (older APIs/builds)
  if C_Container and type(C_Container.SortBankBags) == "function" then
    local ok = pcall(C_Container.SortBankBags)
    return ok == true
  end
  local f = _G and rawget(_G, "SortBankBags")
  if type(f) == "function" then
    local ok = pcall(f)
    return ok == true
  end
  return false
end

local function TryAutoSortGuildBank()
  local f = _G and rawget(_G, "SortGuildBankItems")
  if type(f) == "function" then
    local ok = pcall(f)
    return ok == true
  end
  local frame = _G and rawget(_G, "GuildBankFrame")
  local btn = frame and (frame.SortButton or frame.AutoSortButton) or nil
  if btn and btn.IsEnabled and btn:IsEnabled() and btn.Click then
    local ok = pcall(btn.Click, btn)
    return ok == true
  end
  return false
end

local _liGuildBankScanTip
local function GetGuildBankItemLinkSafe(tab, slot)
  tab = tonumber(tab)
  slot = tonumber(slot)
  if not tab or tab <= 0 then return nil end
  if not slot or slot <= 0 then return nil end

  if type(GetGuildBankItemLink) == "function" then
    local ok, link = pcall(GetGuildBankItemLink, tab, slot)
    link = ok and link or nil
    if type(link) == "string" and link ~= "" then
      return link
    end
  end

  if not (CreateFrame and UIParent) then return nil end
  if not _liGuildBankScanTip then
    _liGuildBankScanTip = CreateFrame("GameTooltip", "fr0z3nUI_LootIt_GuildBankScanTip", UIParent, "GameTooltipTemplate")
    _liGuildBankScanTip:SetOwner(UIParent, "ANCHOR_NONE")
  end

  if not (_liGuildBankScanTip and _liGuildBankScanTip.SetGuildBankItem and _liGuildBankScanTip.GetItem) then
    return nil
  end

  _liGuildBankScanTip:ClearLines()
  local okSet = pcall(_liGuildBankScanTip.SetGuildBankItem, _liGuildBankScanTip, tab, slot)
  if not okSet then
    return nil
  end
  local _, link = _liGuildBankScanTip:GetItem()
  if type(link) == "string" and link ~= "" then
    return link
  end
  return nil
end

local function CountItemInGuildBankTab(tab, itemID)
  if not IsGuildBankOpen() then return 0 end
  tab = tonumber(tab)
  itemID = tonumber(itemID)
  if not tab or tab <= 0 then return 0 end
  if not itemID or itemID <= 0 then return 0 end

  if QueryGuildBankTabIfNeeded then
    QueryGuildBankTabIfNeeded(tab)
  end

  local maxSlots = _G and rawget(_G, "MAX_GUILDBANK_SLOTS_PER_TAB")
  maxSlots = tonumber(maxSlots) or 98

  local total = 0
  for slot = 1, maxSlots do
    local link = GetGuildBankItemLinkSafe(tab, slot)
    if type(link) == "string" then
      local id = tonumber(string.match(link, "item:(%d+)"))
      if id and id == itemID then
        local okI, _, count = false, nil, nil
        if type(GetGuildBankItemInfo) == "function" then
          okI, _, count = pcall(GetGuildBankItemInfo, tab, slot)
        end
        count = okI and tonumber(count) or nil
        if count and count > 0 then
          total = total + count
        end
      end
    end
  end
  return total
end

local function GetResetToken(resetKind)
  resetKind = tostring(resetKind or "daily")
  local now = nil
  if type(GetServerTime) == "function" then
    local ok, v = pcall(GetServerTime)
    now = ok and tonumber(v) or nil
  end
  if not now and type(time) == "function" then
    local ok, v = pcall(time)
    now = ok and tonumber(v) or nil
  end
  if not now then return nil end

  if C_DateAndTime and type(C_DateAndTime.GetSecondsUntilWeeklyReset) == "function" and resetKind == "weekly" then
    local ok, sec = pcall(C_DateAndTime.GetSecondsUntilWeeklyReset)
    sec = ok and tonumber(sec) or nil
    if sec and sec > 0 and sec < 2000000 then
      local resetAt = now + sec
      return math.floor(resetAt / 60)
    end
  end

  if C_DateAndTime and type(C_DateAndTime.GetSecondsUntilDailyReset) == "function" and resetKind == "daily" then
    local ok, sec = pcall(C_DateAndTime.GetSecondsUntilDailyReset)
    sec = ok and tonumber(sec) or nil
    if sec and sec > 0 and sec < 200000 then
      local resetAt = now + sec
      return math.floor(resetAt / 60)
    end
  end

  if type(GetQuestResetTime) == "function" and resetKind == "daily" then
    local ok, sec = pcall(GetQuestResetTime)
    sec = ok and tonumber(sec) or nil
    if sec and sec > 0 and sec < 200000 then
      -- Tokenize by the next reset moment; this stays stable throughout the day.
      local resetAt = now + sec
      return math.floor(resetAt / 60)
    end
  end

  if type(date) == "function" then
    local fmt = (resetKind == "weekly") and "%Y%W" or "%Y%m%d"
    local ok, s = pcall(date, fmt)
    if ok and type(s) == "string" then
      return tonumber(s)
    end
    return nil
  end

  return nil
end

local function RunDepositCleanupOncePerReset(bankKey, fn, scope, resetKind)
  if type(fn) ~= "function" then return false end
  EnsureDB()
  scope = tostring(scope or "account")

  local cfg
  if scope == "char" then
    cfg = DepositCfgChar()
  else
    cfg = DepositCfgAcc()
  end

  if type(cfg) ~= "table" then return fn() == true end

  cfg.cleanupOncePerReset = (type(cfg.cleanupOncePerReset) == "table") and cfg.cleanupOncePerReset or {}
  local token = GetResetToken(resetKind or "daily")
  if not token then
    return fn() == true
  end

  bankKey = tostring(bankKey or "")
  if bankKey == "" then
    bankKey = "bank"
  end

  if cfg.cleanupOncePerReset[bankKey] == token then
    return false
  end

  cfg.cleanupOncePerReset[bankKey] = token
  return fn() == true
end

local function IsPersonalBankOpen()
  -- New bank UI: single window with Character/Account tabs.
  -- Only trust bankType while the bank UI is actually visible; the value can linger.
  if IsBankUIShown() then
    local bankType = GetSelectedBankType()
    local charType = (Enum and Enum.BankType) and Enum.BankType.Character or nil
    local acctType = (Enum and Enum.BankType) and Enum.BankType.Account or nil
    if bankType ~= nil then
      if charType ~= nil then
        return bankType == charType
      end
      -- If we can't resolve Character constant, avoid treating Account as personal.
      if acctType ~= nil and bankType == acctType then
        return false
      end
    end
  end

  -- Fallbacks for older UI.
  if _bankInteractionOpen == true then
    return true
  end
  local f = _G and rawget(_G, "BankFrame")
  if f and f.IsShown and f:IsShown() then
    return true
  end
  return false
end

local function IsAccountBankBagID(bagID)
  bagID = tonumber(bagID)
  if not bagID then return false end
  if not (Enum and Enum.BagIndex) then return false end
  local e = Enum.BagIndex
  return (bagID == e.AccountBankTab_1)
    or (bagID == e.AccountBankTab_2)
    or (bagID == e.AccountBankTab_3)
    or (bagID == e.AccountBankTab_4)
    or (bagID == e.AccountBankTab_5)
end

local function GetSelectedAccountBankTabBagID()
  local p = _G and rawget(_G, "AccountBankPanel")
  if not (p and p.IsVisible and p:IsVisible()) then return nil end
  if type(p.GetSelectedTabID) ~= "function" then return nil end
  local ok, tab = pcall(p.GetSelectedTabID, p)
  tab = ok and tab or nil
  if IsAccountBankBagID(tab) then
    return tab
  end
  return nil
end

local function FindShownChildByNamePattern(root, patterns)
  if not (root and root.GetChildren and type(patterns) == "table") then return nil end

  local q = { root }
  local qi = 1
  local visited = 0
  local maxNodes = 200

  while q[qi] do
    local node = q[qi]
    qi = qi + 1
    visited = visited + 1
    if visited > maxNodes then break end

    local okShown, isShown = pcall(function()
      return node.IsShown and node:IsShown()
    end)
    if okShown and isShown then
      local name = nil
      if node.GetName then
        local okName, v = pcall(node.GetName, node)
        if okName then name = v end
      end
      if type(name) == "string" and name ~= "" then
        for _, p in ipairs(patterns) do
          if type(p) == "string" and p ~= "" and name:find(p, 1, true) then
            return node
          end
        end
      end
    end

    if node.GetChildren then
      local okKids, kids = pcall(function() return { node:GetChildren() } end)
      if okKids and type(kids) == "table" then
        for i = 1, #kids do
          local child = kids[i]
          if child then q[#q + 1] = child end
        end
      end
    end
  end
  return nil
end

local function GetWarbankFrame()
  local candidates = {
    "AccountBankFrame",
    "AccountBankPanel",
    "WarbandBankFrame",
    "WarbandBankPanel",
    "WarbandBank",
  }
  for _, k in ipairs(candidates) do
    local f = _G and rawget(_G, k)
    if f and f.IsVisible and f:IsVisible() then
      return f
    end
    if f and f.IsShown and f:IsShown() then
      return f
    end
  end

  -- If the Blizzard panel exists and a valid tab is selected, treat as open.
  if GetSelectedAccountBankTabBagID() ~= nil then
    local p = _G and rawget(_G, "AccountBankPanel")
    if p then return p end
  end

  -- Some builds embed the Warband/AccountBank panel inside BankFrame.
  local bank = _G and rawget(_G, "BankFrame")
  if bank and bank.IsShown and bank:IsShown() then
    -- Common field names (best-effort).
    local direct = { bank.AccountBankPanel, bank.AccountBankFrame, bank.WarbandBankPanel, bank.WarbandBankFrame }
    for i = 1, #direct do
      local f = direct[i]
      if f and f.IsShown and f:IsShown() then
        return f
      end
    end

    local found = FindShownChildByNamePattern(bank, { "AccountBank", "WarbandBank" })
    if found then
      return found
    end
  end

  return nil
end

local function IsWarbankOpen()
  if _warbankInteractionOpen == true then
    return true
  end
  if GetSelectedAccountBankTabBagID() ~= nil then
    return true
  end

  -- Only trust bankType while the bank UI is actually visible; the value can linger.
  if IsBankUIShown() then
    local bankType = GetSelectedBankType()
    local acctType = (Enum and Enum.BankType) and Enum.BankType.Account or nil
    if acctType ~= nil and bankType == acctType then
      return true
    end
  end
  return (GetWarbankFrame() ~= nil)
end

local _depositScanTip
local function ScanItemTooltipText(link, scanText)
  if type(link) ~= "string" or link == "" then return end
  if not (CreateFrame and UIParent) then return end
  if type(scanText) ~= "function" then return end

  if not _depositScanTip then
    _depositScanTip = CreateFrame("GameTooltip", "fr0z3nUI_LootIt_DepositScanTip", UIParent, "GameTooltipTemplate")
    _depositScanTip:SetOwner(UIParent, "ANCHOR_NONE")
  end

  _depositScanTip:ClearLines()
  _depositScanTip:SetHyperlink(link)
  local n = _depositScanTip:NumLines() or 0
  for i = 1, n do
    local left = _G and _G["fr0z3nUI_LootIt_DepositScanTipTextLeft" .. i]
    local right = _G and _G["fr0z3nUI_LootIt_DepositScanTipTextRight" .. i]
    if left and left.GetText then scanText(left:GetText()) end
    if right and right.GetText then scanText(right:GetText()) end
  end
end

local function GetDepositItemFlagsFromLink(link)
  local out = {
    soulbound = false,
    warbound = false,
  }

  local function scanText(s)
    if type(s) ~= "string" or s == "" then return end
    local low = s:lower()
    if low:find("soulbound", 1, true) then
      out.soulbound = true
    end
    if low:find("bind on pickup", 1, true) then
      out.soulbound = true
    end
    if low:find("warbound", 1, true) then
      out.warbound = true
    end

    if (not out.warbound) and low:find("account bound", 1, true) then
      out.warbound = true
    end
    if (not out.warbound) and low:find("bound to warband", 1, true) then
      out.warbound = true
    end
    if (not out.warbound) and low:find("warband", 1, true) and low:find("bound", 1, true) then
      out.warbound = true
    end
    if (not out.warbound) and low:find("binds", 1, true) and low:find("warband", 1, true) then
      out.warbound = true
    end
    if (not out.warbound) and low:find("bound", 1, true) and low:find("warband", 1, true) then
      out.warbound = true
    end
  end

  if C_TooltipInfo and type(C_TooltipInfo.GetHyperlink) == "function" then
    local ok, tip = pcall(C_TooltipInfo.GetHyperlink, link)
    if ok and type(tip) == "table" and type(tip.lines) == "table" then
      for _, line in ipairs(tip.lines) do
        if type(line) == "table" then
          scanText(line.leftText)
          scanText(line.rightText)
        end
      end
    end
  end

  if (not out.warbound) or (not out.soulbound) then
    ScanItemTooltipText(link, scanText)
  end

  return out
end

local function GetConfiguredGuildBankTab()
  local cfg = DepositCfgAcc()
  cfg = (type(cfg) == "table") and cfg or {}
  local want = nil
  do
    local rk = GetCurrentRealmKey()
    local tbr = (type(cfg.guildTabByRealm) == "table") and cfg.guildTabByRealm or nil
    want = (rk ~= "" and tbr and tonumber(tbr[rk])) or nil
  end
  if want == nil then
    want = tonumber(cfg.guildTab) or 0
  end
  if want and want > 0 then
    return math.floor(want)
  end
  if type(GetCurrentGuildBankTab) == "function" then
    local ok, t = pcall(GetCurrentGuildBankTab)
    t = ok and tonumber(t) or nil
    if t and t > 0 then
      return math.floor(t)
    end
  end
  return 1
end

local GuildBankTabCanDeposit

local function IsGuildTabRandomEnabled(cfg)
  cfg = cfg or DepositCfgAcc()
  local rk = GetCurrentRealmKey()
  if rk ~= "" and type(cfg.guildTabRandomByRealm) == "table" and cfg.guildTabRandomByRealm[rk] ~= nil then
    return cfg.guildTabRandomByRealm[rk] == true
  end
  return cfg.guildTabRandom == true
end

local function GetGuildBankTabCount()
  local n = (GetNumGuildBankTabs and GetNumGuildBankTabs()) or 8
  n = tonumber(n) or 8
  n = math.floor(n)
  if n < 1 then n = 1 end
  if n > 8 then n = 8 end
  return n
end

local function PickRandomGuildBankDepositTab()
  local n = GetGuildBankTabCount()
  local allowed = {}
  for t = 1, n do
    local ok = false
    if GuildBankTabCanDeposit then
      ok = GuildBankTabCanDeposit(t)
    else
      ok = true
    end
    if ok == true then
      allowed[#allowed + 1] = t
    end
  end
  if #allowed < 1 then
    return nil
  end
  local idx = math.random(1, #allowed)
  return allowed[idx]
end

local CreateItemLocationFromBagSlot

local function FindBestGuildBankSlot(tab, itemID)
  tab = tonumber(tab)
  if not tab or tab <= 0 then return nil end
  local maxSlots = _G and rawget(_G, "MAX_GUILDBANK_SLOTS_PER_TAB")
  maxSlots = tonumber(maxSlots) or 98
  if type(GetGuildBankItemLink) ~= "function" then
    return nil
  end

  local wantID = tonumber(itemID)
  local maxStack = 1
  if wantID and type(GetItemInfo) == "function" then
    local okS, s = pcall(function() return select(8, GetItemInfo(wantID)) end)
    maxStack = (okS and tonumber(s)) or 1
  end

  local firstEmpty = nil
  for slot = 1, maxSlots do
    local ok, link = pcall(GetGuildBankItemLink, tab, slot)
    link = ok and link or nil
    if link then
      if wantID and maxStack and maxStack > 1 and type(GetGuildBankItemInfo) == "function" then
        local id = tonumber(string.match(link, "item:(%d+)"))
        if id and id == wantID then
          local okI, _, count, locked = pcall(GetGuildBankItemInfo, tab, slot)
          count = okI and tonumber(count) or nil
          locked = okI and locked or nil
          if count and count > 0 and count < maxStack and locked ~= true then
            return slot
          end
        end
      end
    else
      if not firstEmpty then firstEmpty = slot end
    end
  end
  return firstEmpty
end

-- Forward declarations (avoid analyzer 'undefined global' when referenced earlier)
local GetItemMaxStack
local WithdrawFromGuildBankToBags
local WithdrawFromContainerBagsToBags
local GetPersonalBankBagIDs

-- Guild bank data must be queried per open-session.
-- Caching across close/reopen can leave tabs unqueried and make withdraw/deposit look "broken".
local _guildBankQuerySession = 0
local _guildTabQueriedSession = {}

local function ResetGuildBankQuerySession()
  _guildBankQuerySession = (_guildBankQuerySession or 0) + 1
  _guildTabQueriedSession = {}
end

QueryGuildBankTabIfNeeded = function(tab)
  tab = tonumber(tab)
  if not tab or tab <= 0 then return end
  if _guildTabQueriedSession[tab] == _guildBankQuerySession then return end
  if type(QueryGuildBankTab) ~= "function" then return end
  pcall(QueryGuildBankTab, tab)
  _guildTabQueriedSession[tab] = _guildBankQuerySession
end

local function GuildBankTabCanView(tab)
  tab = tonumber(tab)
  if not tab or tab <= 0 then
    return false, "invalid tab"
  end
  if type(GetGuildBankTabInfo) ~= "function" then
    return true
  end
  QueryGuildBankTabIfNeeded(tab)
  local ok, name, _, canView = pcall(GetGuildBankTabInfo, tab)
  if not ok then
    return false, "tab info unavailable"
  end
  if not name or canView ~= true then
    return false, "no view permission"
  end
  return true
end

GuildBankTabCanDeposit = function(tab)
  tab = tonumber(tab)
  if not tab or tab <= 0 then
    return false, "invalid tab"
  end
  if type(GetGuildBankTabInfo) ~= "function" then
    return true
  end
  QueryGuildBankTabIfNeeded(tab)
  local ok, name, _, canView, canDeposit = pcall(GetGuildBankTabInfo, tab)
  if not ok then
    return false, "tab info unavailable"
  end
  if not name or canView ~= true then
    return false, "no view permission"
  end
  if canDeposit ~= true then
    return false, "no deposit permission"
  end
  return true
end

local function SplitPickupContainerItemSafe(bag, slot, amount)
  if not (C_Container and type(C_Container.PickupContainerItem) == "function") then
    return false, "No container pickup API"
  end
  amount = tonumber(amount)
  if amount and amount > 0 then
    if C_Container and type(C_Container.SplitContainerItem) == "function" then
      local ok, err = pcall(C_Container.SplitContainerItem, bag, slot, amount)
      if ok then return true end
      return false, tostring(err)
    end
    local split = _G and rawget(_G, "SplitContainerItem")
    if type(split) == "function" then
      local ok, err = pcall(split, bag, slot, amount)
      if ok then return true end
      return false, tostring(err)
    end
  end
  local ok, err = pcall(C_Container.PickupContainerItem, bag, slot)
  if ok then return true end
  return false, tostring(err)
end

local function DepositToGuildBankOnce(bag, slot, tab, bankSlot, amount)
  if not (C_Container and type(C_Container.PickupContainerItem) == "function") then
    return false, "No container pickup API"
  end
  if type(PickupGuildBankItem) ~= "function" then
    return false, "No guild bank pickup API"
  end

  local clear = _G and rawget(_G, "ClearCursor")

  local function cursorHasItem()
    if type(GetCursorInfo) == "function" then
      local ok, kind = pcall(GetCursorInfo)
      return ok and kind == "item"
    end
    local cursorHas = _G and rawget(_G, "CursorHasItem")
    if type(cursorHas) == "function" then
      local ok, has = pcall(cursorHas)
      return ok and has == true
    end
    return false
  end

  if type(clear) == "function" then pcall(clear) end

  local okPick, errPick = SplitPickupContainerItemSafe(bag, slot, amount)
  if not okPick then
    if type(clear) == "function" then pcall(clear) end
    return false, "Pickup failed: " .. tostring(errPick)
  end
  if not cursorHasItem() then
    if type(clear) == "function" then pcall(clear) end
    return false, "Pickup did not put item on cursor"
  end

  QueryGuildBankTabIfNeeded(tab)
  local okDrop, errDrop = pcall(PickupGuildBankItem, tab, bankSlot)
  if not okDrop then
    if type(clear) == "function" then pcall(clear) end
    return false, "Place failed: " .. tostring(errDrop)
  end

  -- Cursor still holding item => place was blocked.
  if cursorHasItem() then
    if type(clear) == "function" then pcall(clear) end
    return false, "Place was blocked"
  end

  if type(clear) == "function" then pcall(clear) end
  return true
end

local function GetEffectiveKeepAmount(itemID)
  itemID = tonumber(itemID)
  if not itemID or itemID <= 0 then return 0 end
  local cfg = DepositCfgAcc()
  local v = 0
  if cfg and type(cfg.keepByItem) == "table" then
    v = tonumber(cfg.keepByItem[itemID]) or 0
  end
  v = v and math.floor(v) or 0
  if v < 1 then return 0 end
  if v > 9999 then v = 9999 end
  return v
end

local function GetEffectiveKeepScope(itemID)
  itemID = tonumber(itemID)
  if not itemID or itemID <= 0 then return "K" end
  local cfg = DepositCfgAcc()
  local v = (cfg and type(cfg.keepScopeByItem) == "table") and cfg.keepScopeByItem[itemID] or nil
  if v == "S" then return "S" end
  return "K"
end

local function IsStackPullEnabledForItem(itemID)
  itemID = tonumber(itemID)
  if not itemID or itemID <= 0 then return false end
  local cfg = DepositCfgAcc()
  return (cfg and type(cfg.stackPullByItem) == "table" and cfg.stackPullByItem[itemID] == true) and true or false
end

local function GetPlayerBagIDs()
  local out = {}
  local seen = {}
  local function add(id)
    id = tonumber(id)
    if id == nil then return end
    if seen[id] then return end
    seen[id] = true
    out[#out + 1] = id
  end

  -- Backpack + equipped bags.
  for id = 0, 4 do add(id) end

  -- Reagent bag (Retail): avoid guessing unless we can confirm slots.
  local e = (Enum and Enum.BagIndex) and Enum.BagIndex or nil
  if type(e) == "table" then
    add(rawget(e, "ReagentBag"))
  else
    -- Historically this is 5 on Retail; only include it if it looks like a real container.
    add(5)
  end

  if not (C_Container and type(C_Container.GetContainerNumSlots) == "function") then
    return out
  end

  local filtered = {}
  for i = 1, #out do
    local bagID = out[i]
    local ok, n = pcall(C_Container.GetContainerNumSlots, bagID)
    n = ok and tonumber(n) or 0
    if n and n > 0 then
      filtered[#filtered + 1] = bagID
    end
  end
  return filtered
end

local function CountItemInPlayerBags(itemID)
  itemID = tonumber(itemID)
  if not itemID or itemID <= 0 then return 0 end
  if not (C_Container and type(C_Container.GetContainerNumSlots) == "function") then return 0 end
  local total = 0
  local bags = GetPlayerBagIDs()
  for i = 1, #bags do
    local bag = bags[i]
    local okN, n = pcall(C_Container.GetContainerNumSlots, bag)
    n = okN and tonumber(n) or 0
    if n and n > 0 then
      for slot = 1, n do
        local info = nil
        if type(C_Container.GetContainerItemInfo) == "function" then
          local ok, v = pcall(C_Container.GetContainerItemInfo, bag, slot)
          info = ok and v or nil
        end
        if info and tonumber(info.itemID) == itemID then
          local stack = tonumber(info.stackCount)
          total = total + (stack or 1)
        end
      end
    end
  end
  return total
end

local function CountItemInContainerBags(sourceBags, itemID)
  if type(sourceBags) ~= "table" then return 0 end
  itemID = tonumber(itemID)
  if not itemID or itemID <= 0 then return 0 end
  if not (C_Container and type(C_Container.GetContainerNumSlots) == "function") then return 0 end

  local total = 0
  for i = 1, #sourceBags do
    local bag = sourceBags[i]
    local okN, n = pcall(C_Container.GetContainerNumSlots, bag)
    n = okN and tonumber(n) or 0
    if n and n > 0 then
      for slot = 1, n do
        local info = nil
        if type(C_Container.GetContainerItemInfo) == "function" then
          local ok, v = pcall(C_Container.GetContainerItemInfo, bag, slot)
          info = ok and v or nil
        end
        if info and tonumber(info.itemID) == itemID then
          local stack = tonumber(info.stackCount)
          total = total + (stack or 1)
        end
      end
    end
  end
  return total
end

local function RunDepositGuild(destWanted)
  if not IsGuildBankOpen() then
    return false
  end

  do
    local key, guildName, realm = GetCurrentGuildKey()
    if key and DB and DB.deposit and type(DB.deposit.guildEnabled) == "table" and DB.deposit.guildEnabled[key] == false then
      local display = guildName or "Guild"
      if type(realm) == "string" and realm ~= "" then
        display = display .. " (" .. realm .. ")"
      end
      Print("Guild deposit disabled: " .. display)
      return false
    end
  end

  local targets = GetEffectiveDepositItemIDs(destWanted)
  local hasAny = false
  for _ in pairs(targets) do hasAny = true break end
  if not hasAny then
    Print("Deposit list is empty.")
    return false
  end

  local cfg = DepositCfgAcc()
  local tab = nil
  if IsGuildTabRandomEnabled(cfg) then
    tab = PickRandomGuildBankDepositTab()
  end
  if not tab then
    tab = GetConfiguredGuildBankTab()
  end
  if type(SetCurrentGuildBankTab) == "function" and tab and tab > 0 then
    pcall(SetCurrentGuildBankTab, tab)
  end
  local okPerm, whyPerm = GuildBankTabCanDeposit(tab)
  if not okPerm then
    Print("Deposit blocked (guild): " .. tostring(whyPerm or "no permission"))
    return false
  end
  QueryGuildBankTabIfNeeded(tab)

  -- Optional Stack Pull: if this guild tab already has a partial stack (count < max stack)
  -- for an SP-enabled item, withdraw that partial stack to bags first (only if bags have
  -- enough to fill it), then proceed with deposit.
  do
    local maxSlots = _G and rawget(_G, "MAX_GUILDBANK_SLOTS_PER_TAB")
    maxSlots = tonumber(maxSlots) or 98
    local touched = {}

    if type(GetGuildBankItemLink) == "function" and type(GetGuildBankItemInfo) == "function" then
      for itemID in pairs(targets) do
        itemID = tonumber(itemID)
        if itemID and itemID > 0 and IsStackPullEnabledForItem(itemID) and not touched[itemID] then
          local maxStack = GetItemMaxStack(itemID)
          if maxStack and maxStack > 1 then
            local inBags = CountItemInPlayerBags(itemID)
            if inBags and inBags > 0 then
              local partialCount = nil
              for slot = 1, maxSlots do
                local link = GetGuildBankItemLinkSafe(tab, slot)
                if type(link) == "string" then
                  local id = tonumber(string.match(link, "item:(%d+)"))
                  if id and id == itemID then
                    local okI, _, count, locked = pcall(GetGuildBankItemInfo, tab, slot)
                    count = okI and tonumber(count) or nil
                    locked = okI and locked or nil
                    if count and count > 0 and count < maxStack and locked ~= true then
                      partialCount = count
                      break
                    end
                  end
                end
              end

              if partialCount and partialCount > 0 and partialCount < maxStack then
                local needToFill = maxStack - partialCount
                if needToFill > 0 and inBags >= needToFill then
                  touched[itemID] = true
                  local movedW, whyW = WithdrawFromGuildBankToBags(tab, itemID, partialCount)
                  if whyW then
                    Print("Withdraw blocked (guild): " .. tostring(whyW))
                    return false
                  end
                  if not movedW or movedW <= 0 then
                    -- If we couldn't withdraw, just continue without the pre-pass.
                    touched[itemID] = true
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  -- Store scope (S): keep amount in this guild tab; deposit up to Keep, withdraw excess.
  local storeHave = {}
  do
    for itemID in pairs(targets) do
      itemID = tonumber(itemID)
      if itemID and itemID > 0 then
        local keep = GetEffectiveKeepAmount(itemID)
        if keep > 0 and GetEffectiveKeepScope(itemID) == "S" then
          storeHave[itemID] = CountItemInGuildBankTab(tab, itemID)
        end
      end
    end
  end

  local moved = 0
  local movedLines = {}
  local skippedSoulbound = 0
  local skippedWarbound = 0
  local maxMoves = 200

  local bags = GetPlayerBagIDs()
  for iB = 1, #bags do
    local bag = bags[iB]
    local n = 0
    if C_Container and type(C_Container.GetContainerNumSlots) == "function" then
      local ok, v = pcall(C_Container.GetContainerNumSlots, bag)
      n = ok and tonumber(v) or 0
    end
    if n and n > 0 then
      for slot = 1, n do
        if moved >= maxMoves then break end

        local info = nil
        if C_Container and type(C_Container.GetContainerItemInfo) == "function" then
          local ok, v = pcall(C_Container.GetContainerItemInfo, bag, slot)
          info = ok and v or nil
        end
        local itemID = info and tonumber(info.itemID) or nil
        if itemID and targets[itemID] == true then
          local stack = (info and tonumber(info.stackCount)) or 1
          local depositCount = stack
          local keep = GetEffectiveKeepAmount(itemID)
          if keep > 0 then
            local scope = GetEffectiveKeepScope(itemID)
            if scope == "S" then
              local have = tonumber(storeHave[itemID]) or 0
              local need = keep - have
              if need <= 0 then
                depositCount = 0
              elseif need < depositCount then
                depositCount = need
              end
            else
              local current = CountItemInPlayerBags(itemID)
              local excess = (current or 0) - keep
              if excess <= 0 then
                depositCount = 0
              elseif excess < depositCount then
                depositCount = excess
              end
            end
          end

          if depositCount and depositCount > 0 then
            local link = nil
            if C_Container and type(C_Container.GetContainerItemLink) == "function" then
              local okL, vL = pcall(C_Container.GetContainerItemLink, bag, slot)
              link = okL and vL or nil
            end

            local flags = GetDepositItemFlagsFromLink(link or ("item:" .. tostring(itemID)))
            local isBound = false
            do
              local loc = CreateItemLocationFromBagSlot(bag, slot)
              if loc and C_Item and type(C_Item.IsBound) == "function" then
                local okB, vB = pcall(C_Item.IsBound, loc)
                isBound = okB and vB == true
              end
            end
            if flags.soulbound or isBound then
              skippedSoulbound = skippedSoulbound + 1
              Print("Skipped (soulbound, can't deposit to guild bank): " .. tostring(link or itemID))
            elseif flags.warbound then
              skippedWarbound = skippedWarbound + 1
            else
              local bankSlot = FindBestGuildBankSlot(tab, itemID)
              if not bankSlot then
                Print("Guild bank tab is full.")
                return moved > 0
              end
              local okMove, why = DepositToGuildBankOnce(bag, slot, tab, bankSlot, depositCount ~= stack and depositCount or nil)
              if okMove then
                moved = moved + 1
                if keep > 0 and GetEffectiveKeepScope(itemID) == "S" then
                  storeHave[itemID] = (tonumber(storeHave[itemID]) or 0) + (tonumber(depositCount) or 0)
                end
                if moved <= 15 then
                  movedLines[#movedLines + 1] = tostring(link or itemID) .. " x" .. tostring(depositCount)
                end
              else
                Print("Deposit blocked (guild): " .. tostring(why or "unknown"))
                return moved > 0
              end
            end
          end
        end
      end
    end
    if moved >= maxMoves then break end
  end

  local storeMoved = 0
  do
    for itemID in pairs(targets) do
      itemID = tonumber(itemID)
      if itemID and itemID > 0 then
        local keep = GetEffectiveKeepAmount(itemID)
        if keep > 0 and GetEffectiveKeepScope(itemID) == "S" then
          local have = tonumber(storeHave[itemID])
          if have == nil then
            have = CountItemInGuildBankTab(tab, itemID)
          end
          local excess = (have or 0) - keep
          if excess > 0 then
            local did, why = WithdrawFromGuildBankToBags(tab, itemID, excess)
            if why then
              if tostring(why) == "No bag space" then
                Print("Store withdraw blocked (guild): bags are full (free bag space and retry deposit)")
              else
                Print("Store withdraw blocked (guild): " .. tostring(why))
              end
              return moved > 0
            end
            did = tonumber(did) or 0
            if did > 0 then
              storeMoved = storeMoved + did
              storeHave[itemID] = (have or 0) - did
            end
          end
        end
      end
    end
  end

  if moved > 0 then
    Print("Deposited: " .. tostring(moved) .. " move(s)")
    for i = 1, #movedLines do
      Print("  " .. movedLines[i])
    end
    if moved > #movedLines then
      Print("  (and " .. tostring(moved - #movedLines) .. " more)")
    end
    if skippedSoulbound > 0 then
      Print("Skipped soulbound: " .. tostring(skippedSoulbound))
    end
    if storeMoved > 0 then
      Print("Withdrew (store): " .. tostring(storeMoved) .. " item(s)")
    end
    return true
  end
  if storeMoved > 0 then
    Print("Withdrew (store): " .. tostring(storeMoved) .. " item(s)")
    return true
  end
  -- Nothing left to deposit; run a cleanup pass like BankStack /sort guild.
  RunDepositCleanupOncePerReset("guild", TryAutoSortGuildBank, "account", "daily")
  return false
end

local function DepositToPersonalBankOnce(bag, slot, amount)
  if not (C_Container and type(C_Container.PickupContainerItem) == "function") then
    return false, "No container pickup API"
  end

  local clear = _G and rawget(_G, "ClearCursor")
  local function clearCursor()
    if type(clear) == "function" then pcall(clear) end
  end
  local function cursorHasItem()
    if GetCursorInfo then
      local ok, kind = pcall(GetCursorInfo)
      return ok and kind == "item"
    end
    local cursorHas = _G and rawget(_G, "CursorHasItem")
    if type(cursorHas) == "function" then
      local ok, has = pcall(cursorHas)
      return ok and has == true
    end
    return false
  end

  local wantID = nil
  if type(C_Container.GetContainerItemID) == "function" then
    local ok, v = pcall(C_Container.GetContainerItemID, bag, slot)
    wantID = ok and tonumber(v) or nil
  end
  local maxStack = 1
  if wantID and type(GetItemInfo) == "function" then
    local okS, s = pcall(function() return select(8, GetItemInfo(wantID)) end)
    maxStack = (okS and tonumber(s)) or 1
  end

  -- Most compatible path (12.x bank panel): UseContainerItem behaves like right-clicking the item
  -- while the bank UI is open and deposits to the active Personal bank.
  -- Note: this can't deposit partial amounts, so only use it for whole stacks.
  if amount == nil then
    local use = (C_Container and type(C_Container.UseContainerItem) == "function") and C_Container.UseContainerItem
      or (_G and rawget(_G, "UseContainerItem"))
    if type(use) == "function" and type(C_Container.GetContainerItemInfo) == "function" then
      local okBefore, before = pcall(C_Container.GetContainerItemInfo, bag, slot)
      before = okBefore and before or nil
      local beforeCount = before and tonumber(before.stackCount) or nil

      clearCursor()
      pcall(use, bag, slot)

      local okAfter, after = pcall(C_Container.GetContainerItemInfo, bag, slot)
      after = okAfter and after or nil
      if after == nil then
        return true
      end
      local afterCount = tonumber(after.stackCount)
      if beforeCount and afterCount and afterCount < beforeCount then
        return true
      end
      return false, "UseContainerItem blocked"
    end
  end

  -- Prefer modern 12.0+ bank APIs (when present).
  do
    local bankTypeChar = (Enum and Enum.BankType) and Enum.BankType.Character or nil
    local loc = CreateItemLocationFromBagSlot(bag, slot)

    local candidates = {
      { tbl = _G and rawget(_G, "C_Bank"), fn = "DepositItem" },
      { tbl = _G and rawget(_G, "C_Bank"), fn = "DepositToCharacterBank" },
      { tbl = _G and rawget(_G, "C_Bank"), fn = "DepositToPersonalBank" },
    }

    local f, fnName
    for _, c in ipairs(candidates) do
      if type(c.tbl) == "table" and type(c.tbl[c.fn]) == "function" then
        f, fnName = c.tbl[c.fn], c.fn
        break
      end
    end

    if type(f) == "function" and loc ~= nil then
      local lastErr
      local function tryCall(...)
        local ok, resOrErr = pcall(f, ...)
        if ok then
          if resOrErr == false then
            lastErr = "returned false"
            return false
          end
          return true
        end
        lastErr = tostring(resOrErr)
        return false
      end

      -- Try common signature permutations. We treat nil return as success.
      if amount ~= nil then
        if bankTypeChar ~= nil and tryCall(bankTypeChar, loc, amount) then return true end
        if tryCall(loc, amount) then return true end
        if bankTypeChar ~= nil and tryCall(bankTypeChar, bag, slot, amount) then return true end
        if tryCall(bag, slot, amount) then return true end
      end

      if bankTypeChar ~= nil and tryCall(bankTypeChar, loc) then return true end
      if tryCall(loc) then return true end
      if bankTypeChar ~= nil and tryCall(bankTypeChar, bag, slot) then return true end
      if tryCall(bag, slot) then return true end

      -- If the modern API exists but failed, fall through to cursor placement.
      if lastErr then
        -- Keep lastErr for fallback error context.
      end
    end
  end

  local function getTargetBankBags()
    -- Prefer explicit Character-bank indices (works with the new bank panel UI).
    local e = (Enum and Enum.BagIndex) and Enum.BagIndex or nil
    if type(e) == "table" then
      local list = {}
      local function add(id)
        id = tonumber(id)
        if id == nil then return end
        list[#list + 1] = id
      end
      add(rawget(e, "Bank"))
      add(rawget(e, "ReagentBank"))
      for i = 1, 7 do
        add(rawget(e, "BankBag_" .. tostring(i)))
      end
      local bankContainer = _G and rawget(_G, "BANK_CONTAINER")
      if bankContainer ~= nil then
        add(bankContainer)
      else
        add(-1)
      end
      return list
    end

    local bankContainer = _G and rawget(_G, "BANK_CONTAINER")
    return { bankContainer ~= nil and bankContainer or -1 }
  end

  local function findBestSlot(tBag)
    local n = 0
    if type(C_Container.GetContainerNumSlots) == "function" then
      local ok, v = pcall(C_Container.GetContainerNumSlots, tBag)
      n = ok and tonumber(v) or 0
    end
    if not (n and n > 0) then return nil end

    local firstEmpty
    for tSlot = 1, n do
      local info = nil
      if type(C_Container.GetContainerItemInfo) == "function" then
        local ok, v = pcall(C_Container.GetContainerItemInfo, tBag, tSlot)
        info = ok and v or nil
      end
      if info and wantID and maxStack and maxStack > 1 then
        local id = tonumber(info.itemID)
        local count = tonumber(info.stackCount)
        local locked = info.isLocked
        if id and id == wantID and count and count > 0 and count < maxStack and locked ~= true then
          return tSlot
        end
      end
      if info == nil and not firstEmpty then
        firstEmpty = tSlot
      end
    end
    return firstEmpty
  end

  clearCursor()

  local okPick, errPick = SplitPickupContainerItemSafe(bag, slot, amount)
  if not okPick then
    clearCursor()
    return false, "Pickup failed: " .. tostring(errPick)
  end
  if not cursorHasItem() then
    clearCursor()
    return false, "Pickup did not put item on cursor"
  end

  -- Legacy-but-still-often-working fallback: let Blizzard place into the open Character bank.
  do
    local putInBank = _G and rawget(_G, "PutItemInBank")
    if type(putInBank) == "function" then
      local ok = pcall(putInBank)
      if ok and not cursorHasItem() then
        clearCursor()
        return true
      end
      -- If it didn't clear the cursor, treat as blocked. (Character bank slots may not be enumerable.)
      clearCursor()
      return false, "PutItemInBank blocked"
    end
  end

  local targetBags = getTargetBankBags()
  local targetBag, targetSlot
  for i = 1, #targetBags do
    local tBag = targetBags[i]
    local tSlot = tBag and findBestSlot(tBag) or nil
    if tSlot then
      targetBag, targetSlot = tBag, tSlot
      break
    end
  end

  if not (targetBag and targetSlot) then
    clearCursor()
    return false, "No enumerable personal-bank container slots"
  end

  local okPlace, errPlace = pcall(C_Container.PickupContainerItem, targetBag, targetSlot)
  if not okPlace then
    clearCursor()
    return false, "Place failed: " .. tostring(errPlace)
  end
  if cursorHasItem() then
    -- Still holding item => place was blocked.
    clearCursor()
    return false, "Place was blocked"
  end

  clearCursor()
  return true
end

local function RunDepositPersonalBank(destWanted)
  if not IsPersonalBankOpen() then
    return false
  end

  local targets = GetEffectiveDepositItemIDs(destWanted)
  local hasAny = false
  for _ in pairs(targets) do hasAny = true break end
  if not hasAny then
    Print("Deposit list is empty.")
    return false
  end

  local bankBags = GetPersonalBankBagIDs and GetPersonalBankBagIDs() or nil

  local moved = 0
  local movedLines = {}
  local maxMoves = 200
  local skippedBlocked = 0

  -- Optional Stack Pull: withdraw a partial stack from the bank first (per item), but only
  -- when the player has enough in bags to fill it.
  do
    local touched = {}
    if type(bankBags) == "table" and #bankBags > 0 and C_Container and type(C_Container.GetContainerNumSlots) == "function" then
      for itemID in pairs(targets) do
        itemID = tonumber(itemID)
        if itemID and itemID > 0 and IsStackPullEnabledForItem(itemID) and not touched[itemID] then
          local maxStack = GetItemMaxStack(itemID)
          if maxStack and maxStack > 1 then
            local inBags = CountItemInPlayerBags(itemID)
            if inBags and inBags > 0 then
              local partialCount = nil
              for i = 1, #bankBags do
                local b = bankBags[i]
                local okN, n = pcall(C_Container.GetContainerNumSlots, b)
                n = okN and tonumber(n) or 0
                if n and n > 0 then
                  for s = 1, n do
                    local info = nil
                    if type(C_Container.GetContainerItemInfo) == "function" then
                      local ok, v = pcall(C_Container.GetContainerItemInfo, b, s)
                      info = ok and v or nil
                    end
                    if info and tonumber(info.itemID) == itemID then
                      local count = tonumber(info.stackCount)
                      local locked = info.isLocked
                      if count and count > 0 and count < maxStack and locked ~= true then
                        partialCount = count
                        break
                      end
                    end
                  end
                end
                if partialCount then break end
              end

              if partialCount and partialCount > 0 and partialCount < maxStack then
                local needToFill = maxStack - partialCount
                if needToFill > 0 and inBags >= needToFill then
                  touched[itemID] = true
                  WithdrawFromContainerBagsToBags(bankBags, itemID, partialCount)
                end
              end
            end
          end
        end
      end
    end
  end

  -- Store scope (S): keep amount in bank; deposit up to Keep, withdraw excess.
  local storeHave = {}
  do
    if type(bankBags) == "table" and #bankBags > 0 then
      for itemID in pairs(targets) do
        itemID = tonumber(itemID)
        if itemID and itemID > 0 then
          local keep = GetEffectiveKeepAmount(itemID)
          if keep > 0 and GetEffectiveKeepScope(itemID) == "S" then
            storeHave[itemID] = CountItemInContainerBags(bankBags, itemID)
          end
        end
      end
    end
  end

  local bags = GetPlayerBagIDs()
  for iB = 1, #bags do
    local bag = bags[iB]
    local n = 0
    if C_Container and type(C_Container.GetContainerNumSlots) == "function" then
      local ok, v = pcall(C_Container.GetContainerNumSlots, bag)
      n = ok and tonumber(v) or 0
    end
    if n and n > 0 then
      for slot = 1, n do
        if moved >= maxMoves then break end

        local info = nil
        if C_Container and type(C_Container.GetContainerItemInfo) == "function" then
          local ok, v = pcall(C_Container.GetContainerItemInfo, bag, slot)
          info = ok and v or nil
        end
        local itemID = info and tonumber(info.itemID) or nil
        if itemID and targets[itemID] == true then
          local stack = (info and tonumber(info.stackCount)) or 1
          local depositCount = stack
          local keep = GetEffectiveKeepAmount(itemID)
          if keep > 0 then
            local scope = GetEffectiveKeepScope(itemID)
            if scope == "S" then
              local have = tonumber(storeHave[itemID]) or 0
              local need = keep - have
              if need <= 0 then
                depositCount = 0
              elseif need < depositCount then
                depositCount = need
              end
            else
              local current = CountItemInPlayerBags(itemID)
              local excess = (current or 0) - keep
              if excess <= 0 then
                depositCount = 0
              elseif excess < depositCount then
                depositCount = excess
              end
            end
          end

          if depositCount and depositCount > 0 then
            local link = nil
            if C_Container and type(C_Container.GetContainerItemLink) == "function" then
              local okL, vL = pcall(C_Container.GetContainerItemLink, bag, slot)
              link = okL and vL or nil
            end

            local okMove, whyMove = DepositToPersonalBankOnce(bag, slot, depositCount ~= stack and depositCount or nil)
            if okMove then
              moved = moved + 1
              if keep > 0 and GetEffectiveKeepScope(itemID) == "S" then
                storeHave[itemID] = (tonumber(storeHave[itemID]) or 0) + (tonumber(depositCount) or 0)
              end
              if moved <= 15 then
                movedLines[#movedLines + 1] = tostring(link or itemID) .. " x" .. tostring(depositCount)
              end
            else
              skippedBlocked = skippedBlocked + 1
              if skippedBlocked <= 15 then
                Print("Skipped (personal bank): " .. tostring(link or itemID) .. " — " .. tostring(whyMove or "blocked"))
              end
              -- Don't abort the entire run just because one item can't move (e.g., Hearthstone).
            end
          end
        end
      end
    end
    if moved >= maxMoves then break end
  end

  local storeMoved = 0
  do
    if type(bankBags) == "table" and #bankBags > 0 then
      for itemID in pairs(targets) do
        itemID = tonumber(itemID)
        if itemID and itemID > 0 then
          local keep = GetEffectiveKeepAmount(itemID)
          if keep > 0 and GetEffectiveKeepScope(itemID) == "S" then
            local have = tonumber(storeHave[itemID])
            if have == nil then
              have = CountItemInContainerBags(bankBags, itemID)
            end
            local excess = (have or 0) - keep
            if excess > 0 then
              local did, why = WithdrawFromContainerBagsToBags(bankBags, itemID, excess)
              if why then
                if tostring(why) == "No bag space" then
                  Print("Store withdraw blocked (bank): bags are full (free bag space and retry deposit)")
                else
                  Print("Store withdraw blocked (bank): " .. tostring(why))
                end
                return moved > 0
              end
              did = tonumber(did) or 0
              if did > 0 then
                storeMoved = storeMoved + did
                storeHave[itemID] = (have or 0) - did
              end
            end
          end
        end
      end
    end
  end

  if moved > 0 then
    Print("Deposited: " .. tostring(moved) .. " move(s)")
    for i = 1, #movedLines do
      Print("  " .. movedLines[i])
    end
    if moved > #movedLines then
      Print("  (and " .. tostring(moved - #movedLines) .. " more)")
    end
    if storeMoved > 0 then
      Print("Withdrew (store): " .. tostring(storeMoved) .. " item(s)")
    end
    return true
  end
  if storeMoved > 0 then
    Print("Withdrew (store): " .. tostring(storeMoved) .. " item(s)")
    return true
  end
  -- Nothing left to deposit; run a cleanup pass like BankStack /sort bank.
  RunDepositCleanupOncePerReset("bank", TryAutoSortBankPanel, "char", "daily")
  return false
end

local function WarbandDepositCapability()
  -- Retail always has Warband Bank; we keep a best-effort callable detector for the eventual mover.
  local candidates = {
    { tbl = _G and rawget(_G, "C_AccountBank"), fn = "DepositItem" },
    { tbl = _G and rawget(_G, "C_Bank"), fn = "DepositItem" },
    { tbl = _G and rawget(_G, "C_Bank"), fn = "DepositToAccountBank" },
  }
  for _, c in ipairs(candidates) do
    if type(c.tbl) == "table" and type(c.tbl[c.fn]) == "function" then
      return true, c.tbl, c.fn
    end
  end
  -- Treat as supported even if we didn't find a callable (API naming can change).
  return true, nil, nil
end

local function GetWarbankDepositCallable()
  local cap, tbl, fn = WarbandDepositCapability()
  if not cap then return nil, nil, nil end
  if type(tbl) == "table" and type(fn) == "string" and type(tbl[fn]) == "function" then
    return tbl[fn], fn
  end
  return nil, nil
end

CreateItemLocationFromBagSlot = function(bag, slot)
  if not (bag and slot) then return nil end
  local il = _G and rawget(_G, "ItemLocation")
  if type(il) == "table" then
    if type(il.CreateFromBagAndSlot) == "function" then
      local ok, loc = pcall(il.CreateFromBagAndSlot, bag, slot)
      if ok then return loc end
    end
    -- Some mixin-style APIs expect self as the first arg.
    if type(il.CreateFromBagAndSlot) == "function" then
      local ok, loc = pcall(il.CreateFromBagAndSlot, il, bag, slot)
      if ok then return loc end
    end
  end
  return nil
end

local function DepositToWarbankOnce(bag, slot, sourceItemID, amount)
  local function TryDepositViaCursor()
    if not (C_Container and type(C_Container.PickupContainerItem) == "function") then
      return false, "No container pickup API"
    end

    local wantID = tonumber(sourceItemID)
    if not wantID and type(C_Container.GetContainerItemID) == "function" then
      local ok, v = pcall(C_Container.GetContainerItemID, bag, slot)
      wantID = ok and tonumber(v) or nil
    end

    local maxStack = 1
    if wantID and type(GetItemInfo) == "function" then
      local okS, s = pcall(function() return select(8, GetItemInfo(wantID)) end)
      maxStack = (okS and tonumber(s)) or 1
    end

    local selectedTab = GetSelectedAccountBankTabBagID()
    local targetBags = {}
    if selectedTab then
      targetBags[1] = selectedTab
    elseif Enum and Enum.BagIndex then
      local e = Enum.BagIndex
      local all = { e.AccountBankTab_1, e.AccountBankTab_2, e.AccountBankTab_3, e.AccountBankTab_4, e.AccountBankTab_5 }
      for i = 1, #all do
        if IsAccountBankBagID(all[i]) then
          targetBags[#targetBags + 1] = all[i]
        end
      end
    end

    if #targetBags == 0 then
      return false, "No AccountBank tab is available/selected"
    end

    -- Optional pre-check: is the item allowed in Account bank.
    local loc = CreateItemLocationFromBagSlot(bag, slot)
    local bankTypeAccount = (Enum and Enum.BankType) and Enum.BankType.Account or nil
    if bankTypeAccount ~= nil and loc ~= nil
      and C_Bank and type(C_Bank.IsItemAllowedInBankType) == "function" and type(C_Bank.CanViewBank) == "function"
    then
      local okView, canView = pcall(C_Bank.CanViewBank, bankTypeAccount)
      if okView and canView == true then
        local okAllow, allowed = pcall(C_Bank.IsItemAllowedInBankType, bankTypeAccount, loc)
        if okAllow and allowed == false then
          return false, "Not allowed in Warbank"
        end
      end
    end

    local function findBestSlot(tBag)
      local n = 0
      if type(C_Container.GetContainerNumSlots) == "function" then
        local ok, v = pcall(C_Container.GetContainerNumSlots, tBag)
        n = ok and tonumber(v) or 0
      end
      if not (n and n > 0) then return nil end

      local firstEmpty
      for tSlot = 1, n do
        local info = nil
        if type(C_Container.GetContainerItemInfo) == "function" then
          local ok, v = pcall(C_Container.GetContainerItemInfo, tBag, tSlot)
          info = ok and v or nil
        end
        if info and wantID and maxStack and maxStack > 1 then
          local id = tonumber(info.itemID)
          local count = tonumber(info.stackCount)
          local locked = info.isLocked
          if id and id == wantID and count and count > 0 and count < maxStack and locked ~= true then
            return tSlot
          end
        end
        if info == nil and not firstEmpty then
          firstEmpty = tSlot
        end
      end

      return firstEmpty
    end

    local targetBag, targetSlot
    for i = 1, #targetBags do
      local tBag = targetBags[i]
      local tSlot = findBestSlot(tBag)
      if tSlot then
        targetBag, targetSlot = tBag, tSlot
        break
      end
    end
    if not (targetBag and targetSlot) then
      return false, "Warbank tab full"
    end

    if GetCursorInfo and GetCursorInfo() == "item" and ClearCursor then
      ClearCursor()
    end

    local okPick, errPick = SplitPickupContainerItemSafe(bag, slot, amount)
    if not okPick then
      return false, "Pickup failed: " .. tostring(errPick)
    end
    if GetCursorInfo and GetCursorInfo() ~= "item" then
      return false, "Pickup did not put item on cursor"
    end

    local okPlace, errPlace = pcall(C_Container.PickupContainerItem, targetBag, targetSlot)
    if not okPlace then
      if ClearCursor then ClearCursor() end
      return false, "Place failed: " .. tostring(errPlace)
    end
    if GetCursorInfo and GetCursorInfo() == "item" then
      if ClearCursor then ClearCursor() end
      return false, "Place was blocked"
    end

    return true
  end

  -- Prefer the same approach as BankStack: move to AccountBankTab containers.
  local okCursor, whyCursor = TryDepositViaCursor()
  if okCursor then
    return true
  end

  if amount and tonumber(amount) and tonumber(amount) > 0 then
    -- For partial-stack deposits we must not fall back to any opaque API
    -- that would deposit the full remaining stack from the original slot.
    if ClearCursor then pcall(ClearCursor) end
    return false, tostring(whyCursor or "Partial deposit failed")
  end

  -- Fallback: try any detected Warbank deposit API.
  local f, fnName = GetWarbankDepositCallable()
  if type(f) ~= "function" then
    return false, tostring(whyCursor or "No Warbank deposit API")
  end

  -- Try common signatures (API differs by build).
  local loc = CreateItemLocationFromBagSlot(bag, slot)
  local bankTypeAccount = (Enum and Enum.BankType) and Enum.BankType.Account or nil

  local lastErr
  local function tryCall(...)
    local ok, resOrErr = pcall(f, ...)
    if ok then
      if resOrErr == false then
        lastErr = "returned false"
        return false
      end
      return true
    end
    lastErr = tostring(resOrErr)
    return false
  end

  -- Signature zoo: different builds use different function names/args.
  -- We try the safest/most common permutations first.
  if loc ~= nil then
    if tryCall(loc) then return true end
  end
  if tryCall(bag, slot) then return true end

  if bankTypeAccount ~= nil then
    if loc ~= nil and tryCall(bankTypeAccount, loc) then return true end
    if tryCall(bankTypeAccount, bag, slot) then return true end
    if loc ~= nil and tryCall(loc, bankTypeAccount) then return true end
    if tryCall(bag, slot, bankTypeAccount) then return true end
  end

  return false, tostring(fnName or "deposit") .. ": " .. tostring(lastErr or "failed")
end

GetItemMaxStack = function(itemID)
  itemID = tonumber(itemID)
  if not itemID or itemID <= 0 then return 1 end
  if type(GetItemInfo) ~= "function" then return 1 end
  local okS, s = pcall(function() return select(8, GetItemInfo(itemID)) end)
  local maxStack = (okS and tonumber(s)) or 1
  if not maxStack or maxStack < 1 then maxStack = 1 end
  return math.floor(maxStack)
end

local function WithdrawWarbankPartialStacksToBags(itemID, maxStack)
  itemID = tonumber(itemID)
  maxStack = tonumber(maxStack)
  if not itemID or itemID <= 0 then return true end
  if not maxStack or maxStack <= 1 then return true end
  if not (C_Container and type(C_Container.PickupContainerItem) == "function") then
    return false, "No container pickup API"
  end

  local function cursorHasItem()
    if GetCursorInfo then
      local ok, kind = pcall(GetCursorInfo)
      return ok and kind == "item"
    end
    local cursorHas = _G and rawget(_G, "CursorHasItem")
    if type(cursorHas) == "function" then
      local ok, has = pcall(cursorHas)
      return ok and has == true
    end
    return false
  end

  local function clearCursor()
    if ClearCursor and type(ClearCursor) == "function" then
      pcall(ClearCursor)
    end
  end

  local function findBestBagSlot()
    local bestBag, bestSlot
    local firstEmptyBag, firstEmptySlot
    local bags = GetPlayerBagIDs()
    for iB = 1, #bags do
      local bag = bags[iB]
      local n = 0
      if type(C_Container.GetContainerNumSlots) == "function" then
        local ok, v = pcall(C_Container.GetContainerNumSlots, bag)
        n = ok and tonumber(v) or 0
      end
      if n and n > 0 then
        for slot = 1, n do
          local info = nil
          if type(C_Container.GetContainerItemInfo) == "function" then
            local ok, v = pcall(C_Container.GetContainerItemInfo, bag, slot)
            info = ok and v or nil
          end
          if info and tonumber(info.itemID) == itemID then
            local count = tonumber(info.stackCount)
            local locked = info.isLocked
            if count and count > 0 and count < maxStack and locked ~= true then
              return bag, slot
            end
          end
          if info == nil and not firstEmptyBag then
            firstEmptyBag, firstEmptySlot = bag, slot
          end
        end
      end
    end
    return firstEmptyBag, firstEmptySlot
  end

  local selectedTab = GetSelectedAccountBankTabBagID()
  local warBags = {}
  if selectedTab then
    warBags[1] = selectedTab
  elseif Enum and Enum.BagIndex then
    local e = Enum.BagIndex
    warBags = { e.AccountBankTab_1, e.AccountBankTab_2, e.AccountBankTab_3, e.AccountBankTab_4, e.AccountBankTab_5 }
  end

  local moved = 0
  local maxMoves = 80
  for i = 1, #warBags do
    local wBag = warBags[i]
    if IsAccountBankBagID(wBag) then
      local n = 0
      if type(C_Container.GetContainerNumSlots) == "function" then
        local ok, v = pcall(C_Container.GetContainerNumSlots, wBag)
        n = ok and tonumber(v) or 0
      end
      if n and n > 0 then
        for wSlot = 1, n do
          if moved >= maxMoves then
            return true
          end

          local info = nil
          if type(C_Container.GetContainerItemInfo) == "function" then
            local ok, v = pcall(C_Container.GetContainerItemInfo, wBag, wSlot)
            info = ok and v or nil
          end
          if info and tonumber(info.itemID) == itemID then
            local count = tonumber(info.stackCount)
            local locked = info.isLocked
            if count and count > 0 and count < maxStack and locked ~= true then
              local tBag, tSlot = findBestBagSlot()
              if not (tBag and tSlot) then
                clearCursor()
                return false, "No bag space to withdraw partial Warbank stack"
              end

              if cursorHasItem() then clearCursor() end

              local okPick, errPick = pcall(C_Container.PickupContainerItem, wBag, wSlot)
              if not okPick then
                clearCursor()
                return false, "Withdraw pickup failed: " .. tostring(errPick)
              end
              if not cursorHasItem() then
                clearCursor()
                return false, "Withdraw pickup did not put item on cursor"
              end

              local okPlace, errPlace = pcall(C_Container.PickupContainerItem, tBag, tSlot)
              if not okPlace then
                clearCursor()
                return false, "Withdraw place failed: " .. tostring(errPlace)
              end
              if cursorHasItem() then
                clearCursor()
                return false, "Withdraw place was blocked"
              end
              moved = moved + 1
            end
          end
        end
      end
    end
  end

  return true
end

local function RunDepositWarband(destWanted)
  if not IsWarbankOpen() then
    return false
  end

  local targets = GetEffectiveDepositItemIDs(destWanted)
  local hasAny = false
  for _ in pairs(targets) do hasAny = true break end
  if not hasAny then
    Print("Deposit list is empty.")
    return false
  end

  local warbankBags = {}
  do
    local selectedTab = GetSelectedAccountBankTabBagID()
    local all = {}
    if selectedTab then
      all[1] = selectedTab
    elseif Enum and Enum.BagIndex then
      local e = Enum.BagIndex
      all = { e.AccountBankTab_1, e.AccountBankTab_2, e.AccountBankTab_3, e.AccountBankTab_4, e.AccountBankTab_5 }
    end
    for i = 1, #all do
      local b = all[i]
      if IsAccountBankBagID(b) then
        warbankBags[#warbankBags + 1] = b
      end
    end
  end

  -- Optional workaround (Stack Pull): For stackable items, if Warbank already has
  -- a partial stack (count < max stack), withdraw that partial stack to bags first, then deposit.
  do
    local function FindAnyPartialWarbankStackCount(itemID, maxStack)
      itemID = tonumber(itemID)
      maxStack = tonumber(maxStack) or 1
      if not itemID or itemID <= 0 then return nil end
      if not maxStack or maxStack < 2 then return nil end

      local warBags = {}
      if Enum and Enum.BagIndex then
        local e = Enum.BagIndex
        warBags = { e.AccountBankTab_1, e.AccountBankTab_2, e.AccountBankTab_3, e.AccountBankTab_4, e.AccountBankTab_5 }
      end

      for i = 1, #warBags do
        local wBag = warBags[i]
        if IsAccountBankBagID(wBag) then
          local n = 0
          if type(C_Container.GetContainerNumSlots) == "function" then
            local ok, v = pcall(C_Container.GetContainerNumSlots, wBag)
            n = ok and tonumber(v) or 0
          end
          if n and n > 0 then
            for wSlot = 1, n do
              local info = nil
              if type(C_Container.GetContainerItemInfo) == "function" then
                local ok, v = pcall(C_Container.GetContainerItemInfo, wBag, wSlot)
                info = ok and v or nil
              end
              if info and tonumber(info.itemID) == itemID then
                local count = tonumber(info.stackCount)
                local locked = info.isLocked
                if count and count > 0 and count < maxStack and locked ~= true then
                  return count
                end
              end
            end
          end
        end
      end

      return nil
    end

    local touched = {}
    for itemID in pairs(targets) do
      itemID = tonumber(itemID)
      if itemID and itemID > 0 and IsStackPullEnabledForItem(itemID) and not touched[itemID] then
        local maxStack = GetItemMaxStack(itemID)
        if maxStack and maxStack > 1 then
          -- Prevent oscillation: only apply the workaround when we can actually
          -- fill a partial stack using items currently in bags.
          local inBags = CountItemInPlayerBags(itemID)
          if inBags and inBags > 0 then
            local partialCount = FindAnyPartialWarbankStackCount(itemID, maxStack)
            if partialCount and partialCount > 0 and partialCount < maxStack then
              local needToFill = maxStack - partialCount
              if needToFill > 0 and inBags >= needToFill then
                touched[itemID] = true
                local okW, whyW = WithdrawWarbankPartialStacksToBags(itemID, maxStack)
                if not okW then
                  Print("Withdraw blocked (warbank): " .. tostring(whyW or "unknown"))
                  return false
                end
              end
            end
          end
        end
      end
    end
  end

  local moved = 0
  local movedLines = {}
  local maxMoves = 200

  -- Store scope (S): keep amount in warbank; deposit up to Keep, withdraw excess.
  local storeHave = {}
  do
    if type(warbankBags) == "table" and #warbankBags > 0 then
      for itemID in pairs(targets) do
        itemID = tonumber(itemID)
        if itemID and itemID > 0 then
          local keep = GetEffectiveKeepAmount(itemID)
          if keep > 0 and GetEffectiveKeepScope(itemID) == "S" then
            storeHave[itemID] = CountItemInContainerBags(warbankBags, itemID)
          end
        end
      end
    end
  end
  local bags = GetPlayerBagIDs()
  for iB = 1, #bags do
    local bag = bags[iB]
    local n = 0
    if C_Container and type(C_Container.GetContainerNumSlots) == "function" then
      local ok, v = pcall(C_Container.GetContainerNumSlots, bag)
      n = ok and tonumber(v) or 0
    end
    if n and n > 0 then
      for slot = 1, n do
        if moved >= maxMoves then break end

        local info = nil
        if C_Container and type(C_Container.GetContainerItemInfo) == "function" then
          local ok, v = pcall(C_Container.GetContainerItemInfo, bag, slot)
          info = ok and v or nil
        end
        local itemID = info and tonumber(info.itemID) or nil
        if itemID and targets[itemID] == true then
          local stack = (info and tonumber(info.stackCount)) or 1
          local depositCount = stack
          local keep = GetEffectiveKeepAmount(itemID)
          if keep > 0 then
            local scope = GetEffectiveKeepScope(itemID)
            if scope == "S" then
              local have = tonumber(storeHave[itemID]) or 0
              local need = keep - have
              if need <= 0 then
                depositCount = 0
              elseif need < depositCount then
                depositCount = need
              end
            else
              local current = CountItemInPlayerBags(itemID)
              local excess = (current or 0) - keep
              if excess <= 0 then
                depositCount = 0
              elseif excess < depositCount then
                depositCount = excess
              end
            end
          end

          if depositCount and depositCount > 0 then
            local link = nil
            if C_Container and type(C_Container.GetContainerItemLink) == "function" then
              local okL, vL = pcall(C_Container.GetContainerItemLink, bag, slot)
              link = okL and vL or nil
            end

            local okMove, why = DepositToWarbankOnce(bag, slot, itemID, depositCount ~= stack and depositCount or nil)
            if okMove then
              moved = moved + 1
              if keep > 0 and GetEffectiveKeepScope(itemID) == "S" then
                storeHave[itemID] = (tonumber(storeHave[itemID]) or 0) + (tonumber(depositCount) or 0)
              end
              if moved <= 15 then
                movedLines[#movedLines + 1] = tostring(link or itemID) .. " x" .. tostring(depositCount)
              end
            else
              Print("Deposit blocked (warbank): " .. tostring(why or "unknown"))
              return moved > 0
            end
          end
        end
      end
    end
    if moved >= maxMoves then break end
  end

  local storeMoved = 0
  do
    if type(warbankBags) == "table" and #warbankBags > 0 then
      for itemID in pairs(targets) do
        itemID = tonumber(itemID)
        if itemID and itemID > 0 then
          local keep = GetEffectiveKeepAmount(itemID)
          if keep > 0 and GetEffectiveKeepScope(itemID) == "S" then
            local have = tonumber(storeHave[itemID])
            if have == nil then
              have = CountItemInContainerBags(warbankBags, itemID)
            end
            local excess = (have or 0) - keep
            if excess > 0 then
              local did, why = WithdrawFromContainerBagsToBags(warbankBags, itemID, excess)
              if why then
                if tostring(why) == "No bag space" then
                  Print("Store withdraw blocked (warbank): bags are full (free bag space and retry deposit)")
                else
                  Print("Store withdraw blocked (warbank): " .. tostring(why))
                end
                return moved > 0
              end
              did = tonumber(did) or 0
              if did > 0 then
                storeMoved = storeMoved + did
                storeHave[itemID] = (have or 0) - did
              end
            end
          end
        end
      end
    end
  end

  if moved > 0 then
    Print("Deposited: " .. tostring(moved) .. " move(s)")
    for i = 1, #movedLines do
      Print("  " .. movedLines[i])
    end
    if moved > #movedLines then
      Print("  (and " .. tostring(moved - #movedLines) .. " more)")
    end
    if storeMoved > 0 then
      Print("Withdrew (store): " .. tostring(storeMoved) .. " item(s)")
    end
    return true
  end
  if storeMoved > 0 then
    Print("Withdrew (store): " .. tostring(storeMoved) .. " item(s)")
    return true
  end
  -- Nothing left to deposit; run a cleanup pass like BankStack /sort account.
  RunDepositCleanupOncePerReset("warbank", TryAutoSortBankPanel, "account", "daily")
  return false
end

-- Keep amount (Deposit mode): if bags have less than Keep and the selected/open
-- bank has stock, withdraw up to the amount needed.

local function CursorHasItemSafe()
  if type(GetCursorInfo) == "function" then
    local ok, kind = pcall(GetCursorInfo)
    return ok and kind == "item"
  end
  local cursorHas = _G and rawget(_G, "CursorHasItem")
  if type(cursorHas) == "function" then
    local ok, has = pcall(cursorHas)
    return ok and has == true
  end
  return false
end

local function ClearCursorSafe()
  if ClearCursor and type(ClearCursor) == "function" then
    pcall(ClearCursor)
  end
end

local function FindBestBagSlotForItem(itemID, maxStack)
  itemID = tonumber(itemID)
  maxStack = tonumber(maxStack) or 1
  if not itemID or itemID <= 0 then return nil end
  if not maxStack or maxStack < 1 then maxStack = 1 end

  local firstEmptyBag, firstEmptySlot
  local bags = GetPlayerBagIDs()
  for iB = 1, #bags do
    local bag = bags[iB]
    local n = 0
    if C_Container and type(C_Container.GetContainerNumSlots) == "function" then
      local ok, v = pcall(C_Container.GetContainerNumSlots, bag)
      n = ok and tonumber(v) or 0
    end
    if n and n > 0 then
      for slot = 1, n do
        local info = nil
        if C_Container and type(C_Container.GetContainerItemInfo) == "function" then
          local ok, v = pcall(C_Container.GetContainerItemInfo, bag, slot)
          info = ok and v or nil
        end

        if info and tonumber(info.itemID) == itemID then
          local count = tonumber(info.stackCount)
          local locked = info.isLocked
          if count and count > 0 and count < maxStack and locked ~= true then
            return bag, slot
          end
        end

        if info == nil and not firstEmptyBag then
          firstEmptyBag, firstEmptySlot = bag, slot
        end
      end
    end
  end
  return firstEmptyBag, firstEmptySlot
end

WithdrawFromContainerBagsToBags = function(sourceBags, itemID, wantCount)
  if not (C_Container and type(C_Container.GetContainerNumSlots) == "function") then
    return 0, "No container API"
  end
  itemID = tonumber(itemID)
  wantCount = tonumber(wantCount)
  if not itemID or itemID <= 0 then return 0 end
  wantCount = wantCount and math.floor(wantCount) or 0
  if wantCount <= 0 then return 0 end

  local maxStack = GetItemMaxStack(itemID)
  local moved = 0

  for i = 1, #sourceBags do
    local sBag = sourceBags[i]
    local n = 0
    local okN, vN = pcall(C_Container.GetContainerNumSlots, sBag)
    n = okN and tonumber(vN) or 0
    if n and n > 0 then
      for sSlot = 1, n do
        if moved >= wantCount then
          return moved
        end

        local info = nil
        if type(C_Container.GetContainerItemInfo) == "function" then
          local ok, v = pcall(C_Container.GetContainerItemInfo, sBag, sSlot)
          info = ok and v or nil
        end
        local id = info and tonumber(info.itemID) or nil
        if id and id == itemID then
          local count = (info and tonumber(info.stackCount)) or 1
          local locked = info and info.isLocked or nil
          if locked ~= true and count > 0 then
            local need = wantCount - moved
            local take = (need < count) and need or count
            if take > 0 then
              local tBag, tSlot = FindBestBagSlotForItem(itemID, maxStack)
              if not (tBag and tSlot) then
                ClearCursorSafe()
                return moved, "No bag space"
              end

              if CursorHasItemSafe() then ClearCursorSafe() end

              local okPick, errPick = SplitPickupContainerItemSafe(sBag, sSlot, (take < count) and take or nil)
              if not okPick then
                ClearCursorSafe()
                return moved, "Withdraw pickup failed: " .. tostring(errPick)
              end
              if not CursorHasItemSafe() then
                ClearCursorSafe()
                return moved, "Withdraw pickup did not put item on cursor"
              end

              local okPlace, errPlace = pcall(C_Container.PickupContainerItem, tBag, tSlot)
              if not okPlace then
                ClearCursorSafe()
                return moved, "Withdraw place failed: " .. tostring(errPlace)
              end
              if CursorHasItemSafe() then
                ClearCursorSafe()
                return moved, "Withdraw place was blocked"
              end

              moved = moved + take
            end
          end
        end
      end
    end
  end

  return moved
end

GetPersonalBankBagIDs = function()
  local out = {}
  local seen = {}
  local function add(id)
    id = tonumber(id)
    if not id then return end
    if seen[id] then return end
    seen[id] = true
    out[#out + 1] = id
  end

  -- Newer client constants (access via rawget to keep analyzers happy).
  local e = (Enum and Enum.BagIndex) and Enum.BagIndex or nil
  if type(e) == "table" then
    add(rawget(e, "Bank"))
    add(rawget(e, "ReagentBank"))
    for i = 1, 7 do
      add(rawget(e, "BankBag_" .. tostring(i)))
    end
  end

  local bankContainer = _G and rawget(_G, "BANK_CONTAINER")
  if bankContainer ~= nil then
    add(bankContainer)
  else
    add(-1)
  end

  -- Legacy-ish bank bag ids (best-effort). Avoid 5 (Retail reagent bag is commonly 5).
  if not (Enum and Enum.BagIndex) then
    for id = 6, 12 do
      add(id)
    end
  end

  -- Filter to those that actually have slots.
  if not (C_Container and type(C_Container.GetContainerNumSlots) == "function") then
    return out
  end
  local filtered = {}
  for i = 1, #out do
    local bagID = out[i]
    local ok, n = pcall(C_Container.GetContainerNumSlots, bagID)
    n = ok and tonumber(n) or 0
    if n and n > 0 then
      filtered[#filtered + 1] = bagID
    end
  end
  return filtered
end

WithdrawFromGuildBankToBags = function(tab, itemID, wantCount)
  tab = tonumber(tab)
  itemID = tonumber(itemID)
  wantCount = tonumber(wantCount)
  if not tab or tab <= 0 then return 0 end
  if not itemID or itemID <= 0 then return 0 end
  wantCount = wantCount and math.floor(wantCount) or 0
  if wantCount <= 0 then return 0 end
  if type(GetGuildBankItemLink) ~= "function" and not (CreateFrame and UIParent) then
    return 0, "No guild bank API"
  end
  if type(PickupGuildBankItem) ~= "function" then return 0, "No guild bank API" end
  if not (C_Container and type(C_Container.PickupContainerItem) == "function") then
    return 0, "No container pickup API"
  end

  do
    local okView, whyView = GuildBankTabCanView(tab)
    if not okView then
      return 0, whyView
    end
  end

  -- Some clients are picky about the current tab being selected before data is fully available.
  if type(SetCurrentGuildBankTab) == "function" then
    pcall(SetCurrentGuildBankTab, tab)
  end

  if QueryGuildBankTabIfNeeded then
    QueryGuildBankTabIfNeeded(tab)
  end
  local maxSlots = _G and rawget(_G, "MAX_GUILDBANK_SLOTS_PER_TAB")
  maxSlots = tonumber(maxSlots) or 98

  local maxStack = GetItemMaxStack(itemID)
  local moved = 0
  for slot = 1, maxSlots do
    if moved >= wantCount then return moved end
    local link = GetGuildBankItemLinkSafe(tab, slot)
    if type(link) == "string" then
      local id = tonumber(string.match(link, "item:(%d+)"))
      if id and id == itemID then
        local okI, _, count, locked = false, nil, nil, nil
        if type(GetGuildBankItemInfo) == "function" then
          okI, _, count, locked = pcall(GetGuildBankItemInfo, tab, slot)
        end
        count = okI and tonumber(count) or nil
        locked = okI and locked or nil
        if locked ~= true and count and count > 0 then
          local need = wantCount - moved
          local take = (need < count) and need or count
          if take > 0 then
            local tBag, tSlot = FindBestBagSlotForItem(itemID, maxStack)
            if not (tBag and tSlot) then
              ClearCursorSafe()
              return moved, "No bag space"
            end
            if CursorHasItemSafe() then ClearCursorSafe() end

            local okPick, errPick
            if take < count and type(SplitGuildBankItem) == "function" then
              okPick, errPick = pcall(SplitGuildBankItem, tab, slot, take)
            else
              okPick, errPick = pcall(PickupGuildBankItem, tab, slot)
            end
            if not okPick then
              ClearCursorSafe()
              return moved, "Withdraw pickup failed: " .. tostring(errPick)
            end
            if not CursorHasItemSafe() then
              ClearCursorSafe()
              return moved, "Withdraw pickup did not put item on cursor"
            end

            local okPlace, errPlace = pcall(C_Container.PickupContainerItem, tBag, tSlot)
            if not okPlace then
              ClearCursorSafe()
              return moved, "Withdraw place failed: " .. tostring(errPlace)
            end
            if CursorHasItemSafe() then
              ClearCursorSafe()
              return moved, "Withdraw place was blocked"
            end

            moved = moved + take
          end
        end
      end
    end
  end
  return moved
end

local function WithdrawFromGuildBankToBagsAuto(preferredTab, itemID, wantCount)
  preferredTab = tonumber(preferredTab)
  itemID = tonumber(itemID)
  wantCount = tonumber(wantCount)
  if not itemID or itemID <= 0 then return 0 end
  wantCount = wantCount and math.floor(wantCount) or 0
  if wantCount <= 0 then return 0 end
  if not IsGuildBankOpen() then return 0, "Guild bank not open" end

  local nTabs = GetGuildBankTabCount and GetGuildBankTabCount() or 8
  nTabs = tonumber(nTabs) or 8
  nTabs = math.floor(nTabs)
  if nTabs < 1 then nTabs = 1 end
  if nTabs > 8 then nTabs = 8 end

  local moved = 0
  local anyViewable = false

  local function tryTab(t)
    if moved >= wantCount then return end
    t = tonumber(t)
    if not t or t <= 0 then return end
    if t > nTabs then return end
    local okView = true
    if GuildBankTabCanView then
      okView = (select(1, GuildBankTabCanView(t)) == true)
    end
    if not okView then return end
    anyViewable = true
    local did, why = WithdrawFromGuildBankToBags(t, itemID, wantCount - moved)
    if why then
      return why
    end
    moved = moved + (tonumber(did) or 0)
  end

  local why = nil
  if preferredTab and preferredTab > 0 then
    why = tryTab(preferredTab) or why
  end
  for t = 1, nTabs do
    if moved >= wantCount then break end
    if not preferredTab or t ~= preferredTab then
      why = tryTab(t) or why
    end
  end

  if moved > 0 then return moved end
  if not anyViewable then
    return 0, "No view permission"
  end
  return 0
end

local function RunKeepTopUpForTarget(target, targets)
  if type(targets) ~= "table" then return false end
  local hasAny = false
  for _ in pairs(targets) do hasAny = true break end
  if not hasAny then return false end

  local function resolvedTarget(t)
    t = tostring(t or "")
    t = t:lower():gsub("%s+", "")
    if t == "either" then t = "bank" end
    if t == "warband" then t = "warbank" end
    if t == "personalbank" then t = "personal" end
    if t == "guildbank" then t = "guild" end
    if t ~= "bank" and t ~= "personal" and t ~= "guild" and t ~= "warbank" then t = "" end
    return t
  end

  target = resolvedTarget(target)
  if target == "" then
    -- No explicit target: treat as "bank" (auto to whichever bank is open).
    target = "bank"
  end

  if target == "bank" then
    -- Prefer Guild Bank when both states appear open.
    if IsGuildBankOpen() then target = "guild"
    elseif IsWarbankOpen() then target = "warbank"
    elseif IsPersonalBankOpen() then target = "bank"
    else return false end
  elseif target == "personal" then
    if not IsPersonalBankOpen() then return false end
  end

  local anyMoved = false
  for itemID in pairs(targets) do
    itemID = tonumber(itemID)
    if itemID and itemID > 0 then
      local keep = GetEffectiveKeepAmount(itemID)
      local scope = GetEffectiveKeepScope(itemID)
      if keep > 0 and scope ~= "S" then
        local have = CountItemInPlayerBags(itemID)
        if have < keep then
          local need = keep - have
          local moved = 0
          local why

          if target == "warbank" then
            if not IsWarbankOpen() then
              return anyMoved
            end

            local selectedTab = GetSelectedAccountBankTabBagID()
            local warBags = {}
            if selectedTab then
              warBags[1] = selectedTab
            elseif Enum and Enum.BagIndex then
              local e = Enum.BagIndex
              warBags = {
                rawget(e, "AccountBankTab_1"),
                rawget(e, "AccountBankTab_2"),
                rawget(e, "AccountBankTab_3"),
                rawget(e, "AccountBankTab_4"),
                rawget(e, "AccountBankTab_5"),
              }
            end
            local src = {}
            for i = 1, #warBags do
              local id = warBags[i]
              if id and IsAccountBankBagID(id) then src[#src + 1] = id end
            end
            if #src == 0 then
              moved, why = 0, "No Warbank tab is available/selected"
            else
              moved, why = WithdrawFromContainerBagsToBags(src, itemID, need)
            end
          elseif target == "guild" then
            if not IsGuildBankOpen() then
              return anyMoved
            end
            local tab = GetConfiguredGuildBankTab()
            moved, why = WithdrawFromGuildBankToBagsAuto(tab, itemID, need)
          else
            if not IsPersonalBankOpen() then
              return anyMoved
            end
            local src = GetPersonalBankBagIDs()
            moved, why = WithdrawFromContainerBagsToBags(src, itemID, need)
          end

          if moved and moved > 0 then
            anyMoved = true
          elseif why then
            -- Don't spam: only warn when Keep is configured and something is actively blocked.
            Print("Keep withdraw blocked: " .. tostring(why))
            return anyMoved
          end
        end
      end
    end
  end

  return anyMoved
end

local function RunDeposit(target)
  -- Hard gate: do nothing at all unless some bank UI is open.
  if not (IsWarbankOpen() or IsGuildBankOpen() or IsPersonalBankOpen()) then
    return false
  end

  target = NormalizeDepositDestInput(target)
  if target == "" then
    target = "bank"
  end

  local destWanted = target
  if target == "bank" then
    -- Auto: whichever bank is currently open. Prefer Guild when both look open.
    if IsGuildBankOpen() then
      destWanted = "guild"
    elseif IsWarbankOpen() then
      destWanted = "warbank"
    elseif IsPersonalBankOpen() then
      destWanted = "personal"
    else
      return false
    end
  end

  local targets = GetEffectiveDepositItemIDs(destWanted)
  local keepMoved = RunKeepTopUpForTarget(destWanted, targets) == true

  local didDeposit = false
  if destWanted == "guild" then
    didDeposit = RunDepositGuild(destWanted) == true
  elseif destWanted == "warbank" then
    didDeposit = RunDepositWarband(destWanted) == true
  else
    didDeposit = (IsPersonalBankOpen() and RunDepositPersonalBank(destWanted) == true) and true or false
  end

  return (keepMoved or didDeposit) and true or false
end

LI.RunDeposit = RunDeposit

function LI.GetDepositReport(target)
  local normalized = NormalizeDepositDestInput(target)
  local usedDefaultTarget = false
  if normalized == "" then
    normalized = "bank"
    usedDefaultTarget = true
  end

  local resolvedDest = normalized
  if normalized == "bank" then
    if IsGuildBankOpen() then
      resolvedDest = "guild"
    elseif IsWarbankOpen() then
      resolvedDest = "warbank"
    elseif IsPersonalBankOpen() then
      resolvedDest = "personal"
    else
      resolvedDest = ""
    end
  end

  local listTarget = "shared"
  local rk = GetCurrentRealmKey()

  local function IsOn(v)
    if v == true or v == 1 then return true end
    if type(v) == "string" then
      return NormalizeDepositRuleDest(v) ~= nil
    end
    return false
  end

  local function CountAll(tbl)
    if type(tbl) ~= "table" then return 0 end
    local n = 0
    for _ in pairs(tbl) do n = n + 1 end
    return n
  end

  local function CountOn(tbl)
    if type(tbl) ~= "table" then return 0 end
    local n = 0
    for _, v in pairs(tbl) do
      if IsOn(v) then n = n + 1 end
    end
    return n
  end

  local acc = DepositCfgAcc()
  acc = (type(acc) == "table") and acc or {}
  local ch = DepositCfgChar()
  ch = (type(ch) == "table") and ch or {}

  local accItems = (type(acc.itemsAcc) == "table") and acc.itemsAcc or {}
  local accItemsDisabled = (type(acc.itemsAccDisabled) == "table") and acc.itemsAccDisabled or {}
  local accAccDisableRealmAll = (type(acc.itemsAccDisableRealm) == "table") and acc.itemsAccDisableRealm or {}
  local accDisableRealm = (rk ~= "" and type(accAccDisableRealmAll) == "table") and accAccDisableRealmAll[rk] or nil

  local chItems = (type(ch.itemsChar) == "table") and ch.itemsChar or {}
  local chItemsDisabled = (type(ch.itemsCharDisabled) == "table") and ch.itemsCharDisabled or {}
  local chDisableAcc = (type(ch.disableAcc) == "table") and ch.disableAcc or {}
  local chDisableRealm = (type(ch.disableRealm) == "table") and ch.disableRealm or {}

  local realmItemsAll = (type(acc.itemsRealm) == "table") and acc.itemsRealm or nil
  local realmItems = (type(realmItemsAll) == "table") and realmItemsAll[rk] or nil
  local realmDisabledAll = (type(acc.itemsRealmDisabled) == "table") and acc.itemsRealmDisabled or nil
  local realmDisabled = (type(realmDisabledAll) == "table") and realmDisabledAll[rk] or nil

  local destMap = GetEffectiveDepositDestMap()
  local destCounts = { bank = 0, personal = 0, guild = 0, warbank = 0 }
  for _, d in pairs(destMap) do
    if destCounts[d] ~= nil then
      destCounts[d] = destCounts[d] + 1
    end
  end

  local effective = {}
  if resolvedDest ~= "" then
    effective = GetEffectiveDepositItemIDs(resolvedDest)
  end
  local effectiveCount = 0
  local sampleIDs = {}
  if type(effective) == "table" then
    for id in pairs(effective) do
      effectiveCount = effectiveCount + 1
      if #sampleIDs < 12 then
        sampleIDs[#sampleIDs + 1] = id
      end
    end
    table.sort(sampleIDs)
  end

  local bankUIShown = IsBankUIShown() == true
  local bankType = GetSelectedBankType()
  local bankTypeName = nil
  do
    local e = (Enum and Enum.BankType) and Enum.BankType or nil
    if type(e) == "table" and bankType ~= nil then
      if e.Character ~= nil and bankType == e.Character then
        bankTypeName = "character"
      elseif e.Account ~= nil and bankType == e.Account then
        bankTypeName = "account"
      else
        bankTypeName = "unknown"
      end
    end
  end

  local cBank = _G and rawget(_G, "C_Bank")
  local cBankFns = {
    DepositItem = (type(cBank) == "table" and type(cBank.DepositItem) == "function") and true or false,
    DepositToCharacterBank = (type(cBank) == "table" and type(cBank.DepositToCharacterBank) == "function") and true or false,
    DepositToPersonalBank = (type(cBank) == "table" and type(cBank.DepositToPersonalBank) == "function") and true or false,
    DepositToAccountBank = (type(cBank) == "table" and type(cBank.DepositToAccountBank) == "function") and true or false,
    CanViewBank = (type(cBank) == "table" and type(cBank.CanViewBank) == "function") and true or false,
    IsItemAllowedInBankType = (type(cBank) == "table" and type(cBank.IsItemAllowedInBankType) == "function") and true or false,
  }

  return {
    bankOpen = {
      personal = IsPersonalBankOpen() == true,
      guild = IsGuildBankOpen() == true,
      warbank = IsWarbankOpen() == true,
    },
    bankUIShown = bankUIShown,
    bankType = bankType,
    bankTypeName = bankTypeName,
    cBankFns = cBankFns,
    inputTarget = tostring(target or ""),
    normalizedTarget = normalized,
    resolvedDest = resolvedDest,
    listTarget = listTarget,
    usedDefaultTarget = usedDefaultTarget,
    realmKey = rk,
    counts = {
      accItems = { all = CountAll(accItems), on = CountOn(accItems) },
      accItemsDisabled = { all = CountAll(accItemsDisabled), on = CountOn(accItemsDisabled) },
      accDisableRealm = { all = CountAll(accDisableRealm), on = CountOn(accDisableRealm) },
      realmItems = { all = CountAll(realmItems), on = CountOn(realmItems) },
      realmDisabled = { all = CountAll(realmDisabled), on = CountOn(realmDisabled) },
      chItems = { all = CountAll(chItems), on = CountOn(chItems) },
      chItemsDisabled = { all = CountAll(chItemsDisabled), on = CountOn(chItemsDisabled) },
      chDisableAcc = { all = CountAll(chDisableAcc), on = CountOn(chDisableAcc) },
      chDisableRealm = { all = CountAll(chDisableRealm), on = CountOn(chDisableRealm) },
      effective = effectiveCount,
      effectiveByDest = destCounts,
    },
    sampleIDs = sampleIDs,
  }
end

-- Trade (merchant buy/sell/restock + food selling) engine moved into fUI_GOTrade.lua

local DepositButton
local function EnsureDepositButton()
  if DepositButton then return DepositButton end

  local b = CreateFrame("Button", "fr0z3nUI_LootItDepositButton", UIParent, "UIPanelButtonTemplate")
  b:SetSize(74, 22)
  b:SetText("Deposit")
  b:Hide()
  b:SetScript("OnClick", function()
    RunDeposit(nil)
  end)

  DepositButton = b
  return b
end

local function UpdateDepositButtonVisibility()
  local b = EnsureDepositButton()
  local cfg = DepositCfgAcc()
  if not (cfg and cfg.showButton ~= false) then
    b:Hide()
    return
  end

  local wb = GetWarbankFrame()
  if wb then
    if b.ClearAllPoints and b.SetPoint then
      b:ClearAllPoints()
      b:SetPoint("TOPRIGHT", wb, "TOPLEFT", -8, -10)
    end
    b:Show()
    return
  end

  if IsGuildBankOpen() then
    local g = _G and rawget(_G, "GuildBankFrame")
    if g and b.ClearAllPoints and b.SetPoint then
      b:ClearAllPoints()
      b:SetPoint("TOPRIGHT", g, "TOPLEFT", -8, -10)
    end
    b:Show()
    return
  end
  b:Hide()
end

LI.UpdateDepositButtonVisibility = UpdateDepositButtonVisibility

-- Bank UI can switch between Character/WarBank without firing BANKFRAME_OPENED/CLOSED.
-- Use a short-lived ticker while BankFrame is open to keep related UI + Tax in sync.
local _liBankTicker
local function StopBankTicker()
  if _liBankTicker and _liBankTicker.Cancel then
    _liBankTicker:Cancel()
  end
  _liBankTicker = nil
end

local function StartBankTicker()
  StopBankTicker()
  if not (C_Timer and C_Timer.NewTicker) then return end

  _liBankTicker = C_Timer.NewTicker(0.25, function()
    local ok, err = pcall(function()
      local bf = _G and rawget(_G, "BankFrame")
      if not (bf and bf.IsShown and bf:IsShown()) then
        StopBankTicker()
        return
      end

      if UpdateDepositButtonVisibility then
        UpdateDepositButtonVisibility()
      end

      local tax = LI and LI.Tax
      if tax and type(tax.OnBankTickerTick) == "function" then
        tax.OnBankTickerTick({
          IsWarbankOpen = IsWarbankOpen,
          GetTaxWarbankOpen = function()
            return _taxWarbankOpen
          end,
          SetTaxWarbankOpen = function(v)
            _taxWarbankOpen = (v == true)
          end,
        })
      elseif tax and tax.OnWarbankFrame then
        local nowOpen = (IsWarbankOpen() == true)
        if nowOpen ~= _taxWarbankOpen then
          _taxWarbankOpen = nowOpen
          tax.OnWarbankFrame(nowOpen)
        end
      end
    end)

    if not ok then
      if Print and LI and LI.Trade and LI.Trade._debugOn == true then
        Print("Bank ticker error: " .. tostring(err))
      end
      StopBankTicker()
    end
  end)
end


-- Exports for Host wiring.
LI.StartBankTicker = StartBankTicker
LI.StopBankTicker = StopBankTicker
LI.ResetGuildBankQuerySession = ResetGuildBankQuerySession
LI.SetBankInteractionOpen = function(v) _bankInteractionOpen = (v == true) end
LI.SetWarbankInteractionOpen = function(v) _warbankInteractionOpen = (v == true) end
LI.SetGuildbankInteractionOpen = function(v) _guildbankInteractionOpen = (v == true) end
LI.GetBankInteractionOpen = function() return _bankInteractionOpen == true end
LI.GetWarbankInteractionOpen = function() return _warbankInteractionOpen == true end
LI.GetGuildbankInteractionOpen = function() return _guildbankInteractionOpen == true end
LI.IsGuildBankOpen = IsGuildBankOpen
LI.IsPersonalBankOpen = IsPersonalBankOpen
LI.IsWarbankOpen = IsWarbankOpen

