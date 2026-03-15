local addonName, ns = ...
if type(ns) ~= "table" then ns = {} end

local LI = (ns and ns.LootIt) or fr0z3nUI_LootIt
if type(LI) ~= "table" then return end

ns.LootIt = LI
fr0z3nUI_LootIt = LI

local function Print(msg)
  local frame = DEFAULT_CHAT_FRAME
  if frame and frame.AddMessage then
    frame:AddMessage((LI.PREFIX or "") .. tostring(msg or ""))
  end
end

-- Loot core slash handling (kept here for portability; major-surface module, not per-command files).
LI.Loot = LI.Loot or {}
do
  local Loot = LI.Loot

  local function SafeCall(fn, ...)
    if type(fn) == "function" then
      return fn(...)
    end
  end

  local function GetLootItVersion()
    local addon = (LI and LI.ADDON) or "fr0z3nUI_LootIt"
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
    return v
  end

  function Loot.HandleSlash(cmd, rest, env)
    cmd = tostring(cmd or ""):lower()
    env = (type(env) == "table") and env or {}

    local restStr = tostring(rest or "")
    local restTokenLower = (restStr:match("^(%S+)") or ""):lower()

    local EnsureDB = env.EnsureDB
    local EnsureCharDB = env.EnsureCharDB
    local GetDB = env.GetDB
    local GetCharDB = env.GetCharDB
    local ApplyFilters = env.ApplyFilters
    local LootCombineEnabled = env.LootCombineEnabled
    local IsEnabled = env.IsEnabled

    local PrintFn = env.Print or Print

    SafeCall(EnsureDB)
    SafeCall(EnsureCharDB)
    local DB = SafeCall(GetDB)
    local CHARDB = SafeCall(GetCharDB)

    local function Status()
      local v = GetLootItVersion()
      if v and v ~= "" then
        SafeCall(PrintFn, "version=" .. tostring(v))
      end

      local mode
      if CHARDB and CHARDB.enabledOverride == true then
        mode = "on"
      elseif CHARDB and CHARDB.enabledOverride == false then
        mode = "off"
      elseif DB and DB.enabled then
        mode = "acc"
      else
        mode = "off"
      end
      local enabledNow = (type(IsEnabled) == "function" and IsEnabled()) and "on" or "off"
      local hideNow = (DB and DB.hideLootText) and "on" or "off"
      local echoNow = (DB and DB.echoItem) and "on" or "off"
      local selfnameNow = (DB and DB.showSelfNameAlways) and "on" or "off"
      local combineNow = (type(LootCombineEnabled) == "function" and LootCombineEnabled()) and "on" or "off"
      local combineMode = (DB and DB.lootCombineMode) and tostring(DB.lootCombineMode) or "loot"
      local combineCount = (DB and DB.lootCombineCount) and tostring(DB.lootCombineCount) or "1"
      local combineGold = (DB and DB.lootCombineIncludeGold) and "on" or "off"
      local combineCur = (DB and DB.lootCombineIncludeCurrency) and "on" or "off"
      SafeCall(PrintFn, string.format(
        "enabled=%s (%s), hide=%s, echo=%s, selfname=%s, combine=%s (mode=%s, n=%s, gold=%s, cur=%s)",
        enabledNow,
        (mode == "acc") and "acc" or "char",
        hideNow,
        echoNow,
        selfnameNow,
        combineNow,
        combineMode,
        combineCount,
        combineGold,
        combineCur
      ))
    end

    if cmd == "on" or cmd == "enable" then
      if CHARDB then CHARDB.enabledOverride = nil end
      if DB then DB.enabled = true end
      SafeCall(ApplyFilters)
      Status()
      return true
    end
    if cmd == "off" or cmd == "disable" then
      if CHARDB then CHARDB.enabledOverride = nil end
      if DB then DB.enabled = false end
      SafeCall(ApplyFilters)
      Status()
      return true
    end
    if cmd == "toggle" then
      if CHARDB then CHARDB.enabledOverride = nil end
      if DB then DB.enabled = not DB.enabled end
      SafeCall(ApplyFilters)
      Status()
      return true
    end

    if cmd == "hide" then
      local v = restTokenLower
      if DB then DB.hideLootText = (v ~= "off" and v ~= "0" and v ~= "false") end
      SafeCall(ApplyFilters)
      Status()
      return true
    end
    if cmd == "echo" then
      local v = restTokenLower
      if DB then DB.echoItem = (v ~= "off" and v ~= "0" and v ~= "false") end
      SafeCall(ApplyFilters)
      Status()
      return true
    end
    if cmd == "selfname" then
      local v = restTokenLower
      if DB then DB.showSelfNameAlways = (v ~= "off" and v ~= "0" and v ~= "false") end
      SafeCall(ApplyFilters)
      Status()
      return true
    end
    if cmd == "prefix" then
      local p = restStr
      local pTrim = p:match("^%s*(.-)%s*$") or ""
      local pToken = restTokenLower
      if DB then
        if pTrim == "" then
          DB.echoPrefix = ""
        elseif pToken == "default" then
          DB.echoPrefix = tostring(env.PREFIX or (LI and LI.PREFIX) or "")
        else
          DB.echoPrefix = p
        end
      end
      SafeCall(ApplyFilters)
      Status()
      return true
    end

    if cmd == "ignore" then
      local id = tonumber((tostring(rest or "")):match("(%d+)"))
      if not id or id <= 0 then
        local n = 0
        if DB and type(DB.ignoredItemIDs) == "table" then
          for _ in pairs(DB.ignoredItemIDs) do n = n + 1 end
        end
        SafeCall(PrintFn, "Usage: /fgo li ignore <itemID>")
        SafeCall(PrintFn, "Ignored items: " .. tostring(n))
        return true
      end

      if DB then
        DB.ignoredItemIDs = (type(DB.ignoredItemIDs) == "table") and DB.ignoredItemIDs or {}
        local on = not (DB.ignoredItemIDs[id] == true)
        DB.ignoredItemIDs[id] = on and true or nil
        SafeCall(PrintFn, string.format("Ignore %s: %d", on and "enabled" or "disabled", id))
      end

      SafeCall(ApplyFilters)
      return true
    end

    if cmd == "status" then
      Status()
      return true
    end

    if cmd == "repair" or cmd == "reapply" then
      SafeCall(ApplyFilters)
      local combine = (type(LootCombineEnabled) == "function" and LootCombineEnabled()) and "on" or "off"
      SafeCall(PrintFn, string.format(
        "reapplied filters (enabled=%s, hide=%s, echo=%s, combine=%s)",
        (type(IsEnabled) == "function" and IsEnabled()) and "on" or "off",
        (DB and DB.hideLootText) and "on" or "off",
        (DB and DB.echoItem) and "on" or "off",
        combine
      ))
      return true
    end

    if cmd == "debugfilters" or cmd == "debug" then
      local add = _G and rawget(_G, "ChatFrame_AddMessageEventFilter")
      local rem = _G and rawget(_G, "ChatFrame_RemoveMessageEventFilter")
      local combine = (type(LootCombineEnabled) == "function" and LootCombineEnabled()) and "on" or "off"
      SafeCall(PrintFn, string.format(
        "enabled=%s, hide=%s, echo=%s, combine=%s",
        (type(IsEnabled) == "function" and IsEnabled()) and "on" or "off",
        (DB and DB.hideLootText) and "on" or "off",
        (DB and DB.echoItem) and "on" or "off",
        combine
      ))
      SafeCall(PrintFn, string.format("ChatFrame_AddMessageEventFilter=%s", type(add)))
      SafeCall(PrintFn, string.format("ChatFrame_RemoveMessageEventFilter=%s", type(rem)))
      SafeCall(PrintFn, "(If those are nil, chat filters cannot install yet.)")
      return true
    end

    return false
  end
end
