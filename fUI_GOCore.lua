---@diagnostic disable: duplicate-set-field

local addonName, ns = ...
ns = ns or {}
local ADDON = addonName

local PREFIX = "|cff00ccff[FGO]|r "

local LI = (type(ns) == "table" and ns.LootIt) or {}
-- Single-addon model: keep LootIt under the FGO addon namespace.
-- The global is retained only as a compatibility alias for older modules.
ns.LootIt = LI
fr0z3nUI_LootIt = LI
fr0z3nUI_LootIt_HOST = ADDON
LI.PREFIX = PREFIX
LI.ADDON = ADDON

-- ==========================================================================
-- FGO core event frame (moved from fr0z3nUI_GameOptions.lua)
-- Keep event registration "early"; delegate handling to main via ns.
-- ==========================================================================

do
  local fgo = CreateFrame("Frame")
  ns._FGO_CoreEventFrame = fgo

  fgo:RegisterEvent("ADDON_LOADED")
  fgo:RegisterEvent("GOSSIP_SHOW")
  fgo:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
  fgo:RegisterEvent("LFG_PROPOSAL_SHOW")
  fgo:RegisterEvent("LFG_PROPOSAL_UPDATE")
  fgo:RegisterEvent("LFG_PROPOSAL_FAILED")
  fgo:RegisterEvent("LFG_PROPOSAL_SUCCEEDED")
  fgo:RegisterEvent("PLAYER_REGEN_ENABLED")
  fgo:RegisterEvent("PET_BATTLE_OPENING_START")
  fgo:RegisterEvent("PET_BATTLE_CLOSE")
  fgo:RegisterEvent("PLAYER_ENTERING_WORLD")
  fgo:RegisterEvent("SKILL_LINES_CHANGED")
  fgo:RegisterEvent("TRADE_SKILL_SHOW")
  fgo:RegisterEvent("TRADE_SKILL_DATA_SOURCE_CHANGED")
  fgo:RegisterEvent("TRADE_SKILL_LIST_UPDATE")
  fgo:RegisterEvent("PLAYER_LEVEL_UP")
  fgo:RegisterEvent("ZONE_CHANGED_NEW_AREA")
  fgo:RegisterEvent("QUEST_LOG_UPDATE")

  fgo:SetScript("OnEvent", function(_, event, arg1)
    local handler = ns and rawget(ns, "FGO_OnEvent")
    if type(handler) == "function" then
      handler(event, arg1)
    end
  end)
end

local function Print(msg)
  local frame = DEFAULT_CHAT_FRAME
  if frame and frame.AddMessage then
    frame:AddMessage(PREFIX .. tostring(msg or ""))
  end
end

-- ==========================================================================
-- Sound debug helper
-- Prints the soundKitID for sounds that finish playing (SOUNDKIT_FINISHED).
-- Note: This only applies to SoundKit-based sounds (not arbitrary PlaySoundFile paths).
-- ==========================================================================

do
  local spy = {
    enabled = false,
    max = 25,
    history = {},
    fileHistory = {},
    lastID = nil,
    lastAt = 0,
    lastFile = nil,
    lastFileAt = 0,
    hooks = {
      installed = false,
      hooksecurefunc = false,
      PlaySound = false,
      PlaySoundKitID = false,
      PlaySoundFile = false,
      C_Sound_PlaySound = false,
      C_Sound_PlaySoundKitID = false,
      C_Sound_PlaySoundFile = false,
    },
  }

  local f = CreateFrame("Frame")
  f:Hide()

  local function Now()
    if type(GetTime) == "function" then
      return GetTime() or 0
    end
    return 0
  end

  f:SetScript("OnEvent", function(_, event, arg1)
    if not spy.enabled then
      return
    end
    if event == "SOUNDKIT_FINISHED" then
      -- NOTE: Many builds pass a sound *handle* here (not a kit ID), and some UI
      -- sounds never trigger this event. Keep it as best-effort only.
      local handle = tonumber(arg1)
      if not handle then
        return
      end
      spy.lastID = handle
      spy.lastAt = Now()
      table.insert(spy.history, 1, { id = handle, at = spy.lastAt, kind = "finished" })
      if #spy.history > (spy.max or 25) then
        table.remove(spy.history)
      end
      Print("SoundFinished(handle): " .. tostring(handle))
    end
  end)

  -- Hook sound play calls so we can see the SoundKitID/file at the moment it's played.
  -- This is the reliable way to catch UI sounds like action bar pickup/place.
  do
    local function PushKit(id, kind)
      id = tonumber(id)
      if not id then return end
      spy.lastID = id
      spy.lastAt = Now()
      table.insert(spy.history, 1, { id = id, at = spy.lastAt, kind = kind or "play" })
      if #spy.history > (spy.max or 25) then
        table.remove(spy.history)
      end
      pcall(Print, "SoundKit(" .. tostring(kind or "play") .. "): " .. tostring(id))
    end

    local function PushFile(path)
      path = tostring(path or "")
      if path == "" then return end
      spy.lastFile = path
      spy.lastFileAt = Now()
      table.insert(spy.fileHistory, 1, { path = path, at = spy.lastFileAt })
      if #spy.fileHistory > (spy.max or 25) then
        table.remove(spy.fileHistory)
      end
      pcall(Print, "SoundFile: " .. path)
    end

    local function TryInstallHooks()
      spy.hooks.hooksecurefunc = (type(hooksecurefunc) == "function")
      if not spy.hooks.hooksecurefunc then
        return
      end

      local function TryHookGlobal(name, markKey, handler)
        if spy.hooks[markKey] then
          return
        end
        if type(name) ~= "string" or name == "" then
          return
        end
        if type(rawget(_G, name)) ~= "function" then
          return
        end
        local ok = pcall(hooksecurefunc, name, handler)
        if ok then
          spy.hooks[markKey] = true
          spy.hooks.installed = true
        end
      end

      local function TryHookMethod(tbl, method, markKey, handler)
        if spy.hooks[markKey] then
          return
        end
        if type(tbl) ~= "table" or type(method) ~= "string" or method == "" then
          return
        end
        if type(rawget(tbl, method)) ~= "function" then
          return
        end
        local ok = pcall(hooksecurefunc, tbl, method, handler)
        if ok then
          spy.hooks[markKey] = true
          spy.hooks.installed = true
        end
      end

      TryHookGlobal("PlaySound", "PlaySound", function(soundKitID)
        if spy.enabled then
          PushKit(soundKitID, "PlaySound")
        end
      end)

      TryHookGlobal("PlaySoundKitID", "PlaySoundKitID", function(soundKitID)
        if spy.enabled then
          PushKit(soundKitID, "PlaySoundKitID")
        end
      end)

      TryHookGlobal("PlaySoundFile", "PlaySoundFile", function(path)
        if spy.enabled then
          PushFile(path)
        end
      end)

      local cSound = rawget(_G, "C_Sound")
      if type(cSound) == "table" then
        TryHookMethod(cSound, "PlaySound", "C_Sound_PlaySound", function(...)
          if not spy.enabled then return end
          local a1, a2 = ...
          local sid = (type(a1) == "table") and a2 or a1
          PushKit(sid, "C_Sound.PlaySound")
        end)
        TryHookMethod(cSound, "PlaySoundKitID", "C_Sound_PlaySoundKitID", function(...)
          if not spy.enabled then return end
          local a1, a2 = ...
          local sid = (type(a1) == "table") and a2 or a1
          PushKit(sid, "C_Sound.PlaySoundKitID")
        end)
        TryHookMethod(cSound, "PlaySoundFile", "C_Sound_PlaySoundFile", function(...)
          if not spy.enabled then return end
          local a1, a2 = ...
          local path = (type(a1) == "table") and a2 or a1
          PushFile(path)
        end)
      end
    end

    -- Try now, and retry after the UI is fully up.
    TryInstallHooks()
    if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
      C_Timer.After(1.0, TryInstallHooks)
      C_Timer.After(5.0, TryInstallHooks)
    end

    local hookF = CreateFrame("Frame")
    hookF:RegisterEvent("PLAYER_ENTERING_WORLD")
    hookF:RegisterEvent("ADDON_LOADED")
    hookF:SetScript("OnEvent", function()
      TryInstallHooks()
    end)
  end

  local function SetEnabled(on)
    on = on and true or false
    spy.enabled = on
    if on then
      f:RegisterEvent("SOUNDKIT_FINISHED")
      f:Show()
    else
      f:UnregisterEvent("SOUNDKIT_FINISHED")
      f:Hide()
    end
    return spy.enabled
  end

  local function IsEnabled()
    return spy.enabled and true or false
  end

  local function GetLast()
    return spy.lastID, spy.lastAt
  end

  local function GetLastFile()
    return spy.lastFile, spy.lastFileAt
  end

  local function GetHistory()
    return spy.history
  end

  local function GetFileHistory()
    return spy.fileHistory
  end

  local function GetHookStatus()
    return spy.hooks
  end

  local function TestPlay(soundKitID)
    soundKitID = tonumber(soundKitID)
    if not soundKitID then
      return false, "invalid"
    end
    -- Try the most common entrypoints.
    if type(rawget(_G, "PlaySound")) == "function" then
      pcall(rawget(_G, "PlaySound"), soundKitID)
      return true, "PlaySound"
    end
    local cSound = rawget(_G, "C_Sound")
    if type(cSound) == "table" and type(rawget(cSound, "PlaySound")) == "function" then
      pcall(rawget(cSound, "PlaySound"), soundKitID)
      return true, "C_Sound.PlaySound"
    end
    return false, "no-api"
  end

  ns.SoundSpy_SetEnabled = SetEnabled
  ns.SoundSpy_IsEnabled = IsEnabled
  ns.SoundSpy_GetLast = GetLast
  ns.SoundSpy_GetLastFile = GetLastFile
  ns.SoundSpy_GetHistory = GetHistory
  ns.SoundSpy_GetFileHistory = GetFileHistory
  ns.SoundSpy_GetHookStatus = GetHookStatus
  ns.SoundSpy_TestPlay = TestPlay
end

-- Loot core slash handling moved to fUI_GOLoot.lua
LI.Loot = LI.Loot or {}

-- NOTE: UI shim + Bootstrap wiring helpers + LootIt slash handler implementation
-- are defined in fr0z3nUI_GameOptions.lua (main), so this file can remain strictly
-- "early core" (DB/event/runtime).

-- WoW globals (shadowed to locals so diagnostics stay clean)
local UISpecialFrames = _G and rawget(_G, "UISpecialFrames")
local NUM_CHAT_WINDOWS = _G and rawget(_G, "NUM_CHAT_WINDOWS")
local RAID_CLASS_COLORS = _G and rawget(_G, "RAID_CLASS_COLORS")

local ChatFrame_AddMessageEventFilter = _G and rawget(_G, "ChatFrame_AddMessageEventFilter")
local ChatFrame_RemoveMessageEventFilter = _G and rawget(_G, "ChatFrame_RemoveMessageEventFilter")

local UIDropDownMenu_Initialize = _G and rawget(_G, "UIDropDownMenu_Initialize")
local UIDropDownMenu_CreateInfo = _G and rawget(_G, "UIDropDownMenu_CreateInfo")
local UIDropDownMenu_AddButton = _G and rawget(_G, "UIDropDownMenu_AddButton")
local UIDropDownMenu_SetWidth = _G and rawget(_G, "UIDropDownMenu_SetWidth")
local UIDropDownMenu_SetText = _G and rawget(_G, "UIDropDownMenu_SetText")
local UIDropDownMenu_SetSelectedID = _G and rawget(_G, "UIDropDownMenu_SetSelectedID")
local ToggleDropDownMenu = _G and rawget(_G, "ToggleDropDownMenu")
local CloseDropDownMenus = _G and rawget(_G, "CloseDropDownMenus")

local Clamp = _G and rawget(_G, "Clamp")
if not Clamp then
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

-- Built-in aliases shipped with the addon (account aliases override these).
-- Keyed by itemID; values are display-only text (link remains the original item).
local ADDON_LINK_ALIASES = (type(rawget(_G, "fr0z3nUI_LootIt_AddonAliases")) == "table") and rawget(_G, "fr0z3nUI_LootIt_AddonAliases") or {}
-- Built-in currency aliases shipped with the addon.
-- Keyed by currencyID; values are display-only text (link remains the original currency).
local ADDON_CURRENCY_ALIASES = (type(rawget(_G, "fr0z3nUI_LootIt_AddonCurrencyAliases")) == "table") and rawget(_G, "fr0z3nUI_LootIt_AddonCurrencyAliases") or {}

LI.AddonLinkAliases = ADDON_LINK_ALIASES
LI.AddonCurrencyAliases = ADDON_CURRENCY_ALIASES

local DEFAULTS = {
  enabled = true,
  hideLootText = true, -- suppress the default "You receive loot:" chat line
  echoItem = true, -- re-print a simplified line with just the item link
  showItemLevel = true, -- append (ilvl N) for equippable items
  lootQualityIconEnabled = true, -- show DF+ profession quality (rank) icon embedded in some gathered item links
  lootQualityIconPosition = "before", -- before | after (relative to item name)
  ignoredItemIDs = {}, -- [itemID] = true hides the item from chat (suppresses both original + LootIt output)
  linkAliases = {}, -- [itemID] = "Short Name" (display only, keeps original link)
  linkAliasDisabledAddon = {}, -- [itemID] = true disables addon built-in alias
  linkAliasDisabledAccount = {}, -- [itemID] = true disables account alias
  currencyAliases = {}, -- [currencyID] = "Short Name" (display only, keeps original link)
  currencyAliasDisabledAddon = {}, -- [currencyID] = true disables addon built-in alias
  currencyAliasDisabledAccount = {}, -- [currencyID] = true disables account alias
  aliasInputMode = "item", -- item | currency
  echoPrefix = "", -- optional; leave blank for no prefix
  outputChatFrame = 1,
  showSelfNameAlways = true,
  lootCombineCount = 1, -- 1 = normal (one item per line); >1 buffers items briefly and prints as "A, B, C"
  lootCombineIncludeCurrency = false, -- when combining, include currency in the combined line
  lootCombineIncludeGold = false, -- when combining, include money (gold/silver/copper per toggles) in the combined line
  lootCombineIncludeMoneyCurrency = false, -- legacy (kept for migration)
  lootCombineMode = "loot", -- loot | per

  -- Delay-print: aggregate spammy items and print once after a delay.
  -- Configured per itemID via the Alias tab.
  delayPrint = {
    enabled = true,
    itemSeconds = {
      -- Darkmoon:
      [71083] = 30, -- Darkmoon Game Token
      -- Sack/Pouch o' Tokens variants:
      [78910] = 2,
      [78909] = 2,
      [78908] = 2,
      [78907] = 2,
      [78906] = 2,
      [78905] = 2,
      [78904] = 2,
    },
    flushOnMerchantClose = true,
  },

  mailNotify = {
    enabled = true,
  },
  money = {
    gold = true,
    silver = false,
    copper = false,
  },
  ui = {
    point = "CENTER",
    x = 0,
    y = 0,
  },

  other = {
    outputChatFrame = 1,
    achievement = {
      enabled = true,
    },
    experience = {
      enabled = true,
    },
    profession = {
      enabled = true,
      learnedItems = true,
    },
  },

  -- Debug capture: stores recent raw chat events and LootIt output decisions.
  -- Use via: /fgo li capture on|off|status|dump|clear|max|stacks
  debugCapture = false,
  debugCaptureMax = 200,
  debugCaptureStacks = false,

  -- Debug: print chat filter setup & ChatFrame mapping hints.
  -- Use via: /fgo li chatdebug on|off|toggle|status|dump
  debugChatSetup = false,

  tax = {
    enabled = false,
    rate = 0, -- percent (0..100)
    quiet = false,
    due = 0, -- copper
    paidToDate = 0, -- copper
    sources = {
      vendor = true,
      questLoot = true, -- CHAT_MSG_MONEY
      systemMoney = false, -- CHAT_MSG_SYSTEM (off by default)
      mail = true,
    },
    autoPayOnGuildBankOpen = false,
  },

  -- Deposit helper (bank open + command/button pressed).
  deposit = {
    tradeMode = "deposit", -- deposit | buy | sell
    target = "bank", -- bank | personal | guild | warbank
    guildTab = 0, -- legacy fallback; 0=current tab; 1..8 specific tab
    guildTabByRealm = {}, -- [realm] = 0..8
    showButton = true,
    sellFoodEnabled = false,
    sellFoodEnabledAcc = false,
    sellFoodLevelDiff = 10,
    itemsAcc = {}, -- [itemID] = true
    itemsRealm = {}, -- [realm] = { [itemID] = true }

    -- Vendor buy/sell rules (stored as: [itemID] = { count=<number>, restock=<bool?> } )
    buyItemsAcc = {},
    buyItemsRealm = {}, -- [realm] = { [itemID] = rule }
    sellItemsAcc = {},
    sellItemsRealm = {}, -- [realm] = { [itemID] = rule }
  },
}

-- LootIt DB is stored inside FGO SavedVariables (AutoGame_*).
-- Legacy globals are kept as runtime aliases for compatibility with existing modules.
fr0z3nUI_LootItDB = fr0z3nUI_LootItDB
fr0z3nUI_LootItCharDB = fr0z3nUI_LootItCharDB
local DB
local CHARDB

local function IsEnabled()
  if CHARDB and CHARDB.enabledOverride ~= nil then
    return (CHARDB.enabledOverride == true)
  end
  return (DB and DB.enabled) and true or false
end

local function CopyDefaults(dst, src)
  if type(dst) ~= "table" then dst = {} end
  for k, v in pairs(src) do
    if dst[k] == nil then
      if type(v) == "table" then
        dst[k] = CopyDefaults({}, v)
      else
        dst[k] = v
      end
    elseif type(v) == "table" and type(dst[k]) == "table" then
      dst[k] = CopyDefaults(dst[k], v)
    end
  end
  return dst
end

local function EnsureDB()
  -- Ensure FGO SV roots exist even if the main file loads later.
  AutoGame_Acc = (type(AutoGame_Acc) == "table") and AutoGame_Acc or {}
  AutoGame_Char = (type(AutoGame_Char) == "table") and AutoGame_Char or {}

  -- Store LootIt data under FGO SV.
  AutoGame_Acc.lootIt = (type(AutoGame_Acc.lootIt) == "table") and AutoGame_Acc.lootIt or {}
  AutoGame_Char.lootIt = (type(AutoGame_Char.lootIt) == "table") and AutoGame_Char.lootIt or {}

  -- Legacy aliases (some modules still rawget these globals).
  fr0z3nUI_LootItDB = AutoGame_Acc.lootIt
  fr0z3nUI_LootItCharDB = AutoGame_Char.lootIt

  -- Migration: older versions used a single toggle for "include money+currency".
  local hadNewCurrency = (fr0z3nUI_LootItDB.lootCombineIncludeCurrency ~= nil)
  local hadNewGold = (fr0z3nUI_LootItDB.lootCombineIncludeGold ~= nil)

  DB = CopyDefaults(fr0z3nUI_LootItDB, DEFAULTS)
  CHARDB = fr0z3nUI_LootItCharDB
  if type(DB.ignoredItemIDs) ~= "table" then DB.ignoredItemIDs = {} end
  if type(CHARDB.linkAliases) ~= "table" then CHARDB.linkAliases = {} end
  if type(CHARDB.linkAliasDisabledChar) ~= "table" then CHARDB.linkAliasDisabledChar = {} end

  -- Migration: legacy combine mode "timer" is now the UI's "Print Per" ("per").
  -- Normalize here so Status/UI/runtime never see an unknown or deprecated mode.
  do
    local m = tostring(DB.lootCombineMode or "loot")
    m = m:lower():gsub("%s+", "")
    if m == "timer" then m = "per" end
    if m ~= "loot" and m ~= "per" then m = "loot" end
    DB.lootCombineMode = m
    fr0z3nUI_LootItDB.lootCombineMode = m
  end

  if type(CHARDB.currencyAliases) ~= "table" then CHARDB.currencyAliases = {} end
  if type(CHARDB.currencyAliasDisabledChar) ~= "table" then CHARDB.currencyAliasDisabledChar = {} end

  -- Other/Professions: persist last-known skill ranks per character (used to compute +Î” after /reload).
  if type(CHARDB.otherProfessionRanks) ~= "table" then CHARDB.otherProfessionRanks = {} end

  -- Deposit config (account list + per-character list/overrides).
  if type(DB.deposit) ~= "table" then DB.deposit = {} end
  if DB.deposit.tradeMode == nil then DB.deposit.tradeMode = "deposit" end
  if type(DB.deposit.itemsAcc) ~= "table" then DB.deposit.itemsAcc = {} end
  if type(DB.deposit.itemsRealm) ~= "table" then DB.deposit.itemsRealm = {} end
  if type(DB.deposit.guildTabByRealm) ~= "table" then DB.deposit.guildTabByRealm = {} end
  if type(DB.deposit.buyItemsAcc) ~= "table" then DB.deposit.buyItemsAcc = {} end
  if type(DB.deposit.buyItemsRealm) ~= "table" then DB.deposit.buyItemsRealm = {} end
  if type(DB.deposit.sellItemsAcc) ~= "table" then DB.deposit.sellItemsAcc = {} end
  if type(DB.deposit.sellItemsRealm) ~= "table" then DB.deposit.sellItemsRealm = {} end
  if DB.deposit.sellFoodEnabled == nil then DB.deposit.sellFoodEnabled = false end
  if DB.deposit.sellFoodEnabledAcc == nil then
    -- Migration: older builds only had DB.deposit.sellFoodEnabled.
    DB.deposit.sellFoodEnabledAcc = (DB.deposit.sellFoodEnabled == true) and true or false
  end
  if DB.deposit.sellFoodLevelDiff == nil then DB.deposit.sellFoodLevelDiff = 10 end
  if DB.deposit.target == nil then DB.deposit.target = "bank" end
  if DB.deposit.guildTab == nil then DB.deposit.guildTab = 0 end
  if DB.deposit.showButton == nil then DB.deposit.showButton = true end

  -- Guild enable/disable (account-wide). Tracks guilds seen on any character.
  if type(DB.deposit.guildsSeen) ~= "table" then DB.deposit.guildsSeen = {} end
  if type(DB.deposit.guildEnabled) ~= "table" then DB.deposit.guildEnabled = {} end

  do
    local d = tonumber(DB.deposit.sellFoodLevelDiff)
    d = d and math.floor(d) or 10
    if d < 1 then d = 1 end
    if d > 80 then d = 80 end
    DB.deposit.sellFoodLevelDiff = d
  end

  -- The config UI no longer exposes toggling this; keep the on-screen button on.
  DB.deposit.showButton = true

  do
    local m = tostring(DB.deposit.tradeMode or ""):lower():gsub("%s+", "")
    if m ~= "deposit" and m ~= "buy" and m ~= "sell" then
      m = "deposit"
    end
    DB.deposit.tradeMode = m
  end

  -- Migration: previous targets were guild|warband|either.
  do
    local t = tostring(DB.deposit.target or "")
    t = t:lower():gsub("%s+", "")
    if t == "either" then t = "bank" end
    if t == "warband" then t = "warbank" end
    if t == "personalbank" or t == "personal" then t = "personal" end
    if t == "warbank" or t == "guild" or t == "bank" or t == "personal" then
      DB.deposit.target = t
    else
      DB.deposit.target = "bank"
    end
  end

  if type(CHARDB.deposit) ~= "table" then CHARDB.deposit = {} end
  if type(CHARDB.deposit.itemsChar) ~= "table" then CHARDB.deposit.itemsChar = {} end
  if type(CHARDB.deposit.disableAcc) ~= "table" then CHARDB.deposit.disableAcc = {} end
  if type(CHARDB.deposit.buyItemsChar) ~= "table" then CHARDB.deposit.buyItemsChar = {} end
  if type(CHARDB.deposit.buyDisableAcc) ~= "table" then CHARDB.deposit.buyDisableAcc = {} end
  if type(CHARDB.deposit.sellItemsChar) ~= "table" then CHARDB.deposit.sellItemsChar = {} end
  if type(CHARDB.deposit.sellDisableAcc) ~= "table" then CHARDB.deposit.sellDisableAcc = {} end
  if CHARDB.deposit.sellFoodEnabledChar == nil then CHARDB.deposit.sellFoodEnabledChar = false end

  if DB and type(DB.other) ~= "table" then
    DB.other = {}
  end
  if DB and DB.other and DB.other.outputChatFrame == nil then
    DB.other.outputChatFrame = DB.outputChatFrame or 1
  end
  if DB and DB.other and DB.other.hidePlayed == nil then
    -- UI toggle: when enabled, suppresses /played system output lines.
    DB.other.hidePlayed = false
  end
  if DB and DB.suppress == nil then
    -- Generic chat suppress list (SV-backed). Used to hide addon/chat spam without editing addons.
    DB.suppress = { enabled = true, rules = {} }
  end
  if DB and type(DB.suppress) == "table" then
    if DB.suppress.enabled == nil then DB.suppress.enabled = true end
    if type(DB.suppress.rules) ~= "table" then DB.suppress.rules = {} end
  end
  if DB and DB.other and type(DB.other.achievement) ~= "table" then
    DB.other.achievement = {}
  end
  if DB and DB.other and type(DB.other.experience) ~= "table" then
    DB.other.experience = {}
  end
  if DB and DB.other and type(DB.other.experience) == "table" and DB.other.experience.showBonus == nil then
    DB.other.experience.showBonus = true
  end
  if DB and DB.other and type(DB.other.experience) == "table" then
    if DB.other.experience.questXP == nil then
      -- Separate toggle (not part of Before/After). When on, hides Accepted/Completed lines and
      -- appends the Completed quest title to the XP gain output.
      DB.other.experience.questXP = false
    end

    local pos = tostring(DB.other.experience.xpLabelPos or "after")
    pos = pos:lower():gsub("%s+", "")
    -- Migration: older experiment used xpLabelPos='quest'. Preserve intent using questXP.
    if pos == "quest" then
      DB.other.experience.questXP = true
      pos = "after"
    end
    if pos ~= "before" and pos ~= "after" then pos = "after" end
    DB.other.experience.xpLabelPos = pos
  end
  if DB and DB.other and type(DB.other.profession) ~= "table" then
    DB.other.profession = {}
  end

  if DB then
    if type(DB.delayPrint) ~= "table" then DB.delayPrint = {} end
    if type(DB.delayPrint.itemSeconds) ~= "table" then DB.delayPrint.itemSeconds = {} end
    if DB.delayPrint.enabled == nil then DB.delayPrint.enabled = true end
    if DB.delayPrint.flushOnMerchantClose == nil then DB.delayPrint.flushOnMerchantClose = true end
  end

    -- Loot: quality icon config normalization.
    if DB then
      if DB.lootQualityIconEnabled == nil then DB.lootQualityIconEnabled = true end
      local pos = tostring(DB.lootQualityIconPosition or "before")
      pos = pos:lower():gsub("%s+", "")
      if pos ~= "before" and pos ~= "after" then pos = "before" end
      DB.lootQualityIconPosition = pos
    end

  if (not hadNewCurrency) and (not hadNewGold) and (fr0z3nUI_LootItDB.lootCombineIncludeMoneyCurrency == true) then
    fr0z3nUI_LootItDB.lootCombineIncludeCurrency = true
    fr0z3nUI_LootItDB.lootCombineIncludeGold = true
    DB.lootCombineIncludeCurrency = true
    DB.lootCombineIncludeGold = true
  end

  -- Migration: old versions used showSelfNameInGroup; new is showSelfNameAlways.
  if DB and DB.showSelfNameAlways == nil and fr0z3nUI_LootItDB.showSelfNameInGroup ~= nil then
    DB.showSelfNameAlways = (fr0z3nUI_LootItDB.showSelfNameInGroup == true)
    ---@diagnostic disable-next-line: assign-type-mismatch
    fr0z3nUI_LootItDB.showSelfNameAlways = DB.showSelfNameAlways
  end

  -- Mail notifier config scope is selectable (Account default; optional per-character).
  -- Enabled remains account-wide + per-character override.
  do
    -- Migration (2026-02-12): reset per-character mail settings to defaults on next load.
    -- IMPORTANT: Older versions stored mail notifier config account-wide; we must ensure
    -- the reset is not immediately overwritten by that legacy migration.
    if CHARDB then
      -- First-time reset.
      if CHARDB._m20260212_mailReset ~= true then
        CHARDB.mailNotifyEnabledOverride = nil
        CHARDB.mailNotify = { _migratedFromAcc = true, _resetToDefaults = true }
        CHARDB._m20260212_mailReset = true
      end

      -- Repair: earlier builds cleared mailNotify, then re-imported from account DB.
      -- If that happened, apply the intended reset once.
      if CHARDB._m20260212_mailReset == true then
        if type(CHARDB.mailNotify) ~= "table" or CHARDB.mailNotify._resetToDefaults ~= true then
          CHARDB.mailNotifyEnabledOverride = nil
          CHARDB.mailNotify = { _migratedFromAcc = true, _resetToDefaults = true }
        end
      end
    end

    if type(CHARDB.mailNotify) ~= "table" then
      CHARDB.mailNotify = {}
    end

    -- Migration: older versions stored mail notifier config account-wide.
    if type(fr0z3nUI_LootItDB.mailNotify) == "table" and not CHARDB.mailNotify._migratedFromAcc then
      local acc = fr0z3nUI_LootItDB.mailNotify
      local ch = CHARDB.mailNotify
      if ch.showInCombat == nil and acc.showInCombat ~= nil then
        ch.showInCombat = (acc.showInCombat ~= false)
      end
      if type(ch.model) ~= "table" and type(acc.model) == "table" then
        ch.model = CopyDefaults({}, acc.model)
      end
      if type(ch.ui) ~= "table" and type(acc.ui) == "table" then
        ch.ui = CopyDefaults({}, acc.ui)
      end
      ch._migratedFromAcc = true
    end

    local mn = CHARDB.mailNotify
    if mn.showInCombat == nil then mn.showInCombat = true end

    if type(mn.model) ~= "table" then mn.model = {} end
    if mn.model.kind == nil then mn.model.kind = "npc" end
    if mn.model.id == nil then mn.model.id = 104230 end -- Dalaran Mailemental
    if mn.model.rotation == nil then mn.model.rotation = 0.15 end
    if mn.model.zoom == nil then mn.model.zoom = 0.9 end
    if mn.model.anim == nil then mn.model.anim = 0 end
    if mn.model.animRandom == nil then mn.model.animRandom = false end
    if mn.model.animRepeat == nil then mn.model.animRepeat = false end
    if mn.model.animRepeatSec == nil then mn.model.animRepeatSec = 10 end

    if type(mn.ui) ~= "table" then mn.ui = {} end
    if mn.ui.point == nil then mn.ui.point = "TOPRIGHT" end
    if mn.ui.x == nil then mn.ui.x = -260 end
    if mn.ui.y == nil then mn.ui.y = -220 end
    if mn.ui.w == nil then mn.ui.w = 200 end
    if mn.ui.h == nil then mn.ui.h = 220 end
    if mn.ui.alpha == nil then mn.ui.alpha = 0.5 end
    if mn.ui.strata == nil then mn.ui.strata = "BACKGROUND" end

    -- Mail notifier config: optional account-wide scope.
    -- Default is Account (CHARDB.mailNotifyScope ~= "char").
    if DB then
      DB.mailNotify = DB.mailNotify or {}

      -- One-time seed: when switching to Account-default, copy the current
      -- per-character settings into the account table if it doesn't yet have them.
      if DB.mailNotify._m20260310_mailScope ~= true then
        if DB.mailNotify.showInCombat == nil and mn.showInCombat ~= nil then
          DB.mailNotify.showInCombat = (mn.showInCombat ~= false)
        end
        if type(DB.mailNotify.model) ~= "table" and type(mn.model) == "table" then
          DB.mailNotify.model = CopyDefaults({}, mn.model)
        end
        if type(DB.mailNotify.ui) ~= "table" and type(mn.ui) == "table" then
          DB.mailNotify.ui = CopyDefaults({}, mn.ui)
        end
        DB.mailNotify._m20260310_mailScope = true
      end

      local acc = DB.mailNotify
      if acc.showInCombat == nil then acc.showInCombat = true end

      -- Mail Debug: make it account-wide (independent of mail scope).
      -- Migration: if debug was previously stored in the scoped mail config,
      -- import it once into the account table.
      if acc._m20260315_mailDebugAcc ~= true then
        local imported
        if acc.debug == nil then
          local ch = CHARDB and CHARDB.mailNotify
          if type(ch) == "table" and ch.debug ~= nil then
            acc.debug = (ch.debug == true)
            imported = true
          end
        end
        acc._m20260315_mailDebugAcc = true
        acc._mailDebugImported = imported and true or nil
      end

      if type(acc.model) ~= "table" then acc.model = {} end
      if acc.model.kind == nil then acc.model.kind = "npc" end
      if acc.model.id == nil then acc.model.id = 104230 end
      if acc.model.rotation == nil then acc.model.rotation = 0.15 end
      if acc.model.zoom == nil then acc.model.zoom = 0.9 end
      if acc.model.anim == nil then acc.model.anim = 0 end
      if acc.model.animRandom == nil then acc.model.animRandom = false end
      if acc.model.animRepeat == nil then acc.model.animRepeat = false end
      if acc.model.animRepeatSec == nil then acc.model.animRepeatSec = 10 end

      if type(acc.ui) ~= "table" then acc.ui = {} end
      if acc.ui.point == nil then acc.ui.point = "TOPRIGHT" end
      if acc.ui.x == nil then acc.ui.x = -260 end
      if acc.ui.y == nil then acc.ui.y = -220 end
      if acc.ui.w == nil then acc.ui.w = 200 end
      if acc.ui.h == nil then acc.ui.h = 220 end
      if acc.ui.alpha == nil then acc.ui.alpha = 0.5 end
      if acc.ui.strata == nil then acc.ui.strata = "BACKGROUND" end
    end
  end
end

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

local function UpdateSeenGuilds(reason)
  EnsureDB()
  if not (DB and DB.deposit) then return end
  local key, guildName, realm = GetCurrentGuildKey()
  if not key then
    if DB.deposit.tradeDebug == true then
      local r = tostring(reason or "")
      if r ~= "" then r = " (" .. r .. ")" end
      Print(string.format("Guild tracking%s: (no guild)", r))
    end
    return
  end

  DB.deposit.guildsSeen = (type(DB.deposit.guildsSeen) == "table") and DB.deposit.guildsSeen or {}
  DB.deposit.guildEnabled = (type(DB.deposit.guildEnabled) == "table") and DB.deposit.guildEnabled or {}

  local wasNew = (DB.deposit.guildsSeen[key] == nil)
  DB.deposit.guildsSeen[key] = DB.deposit.guildsSeen[key] or {}
  local rec = DB.deposit.guildsSeen[key]
  rec.name = guildName
  rec.realm = realm
  if type(GetServerTime) == "function" then
    local okT, t = pcall(GetServerTime)
    if okT and tonumber(t) then rec.lastSeen = tonumber(t) end
  elseif type(time) == "function" then
    local okT, t = pcall(time)
    if okT and tonumber(t) then rec.lastSeen = tonumber(t) end
  end

  if DB.deposit.guildEnabled[key] == nil then
    DB.deposit.guildEnabled[key] = true
  end

  if DB.deposit.tradeDebug == true then
    local r = tostring(reason or "")
    if r ~= "" then r = " (" .. r .. ")" end
    Print(string.format("Guild tracking%s: %s", r, tostring(key)))
    if wasNew then
      Print("Guild tracking: new guild detected")
    end
  end
end

LI.EnsureDB = EnsureDB
LI.GetDB = function()
  EnsureDB()
  return DB
end
LI.GetCharDB = function()
  EnsureDB()
  return CHARDB
end

local function IsIgnoredItemID(itemID)
  return (DB and type(DB.ignoredItemIDs) == "table" and DB.ignoredItemIDs[itemID] == true) and true or false
end

local function IsItemLevelEnabled()
  if CHARDB and CHARDB.showItemLevel ~= nil then
    return (CHARDB.showItemLevel == true)
  end
  return (DB and DB.showItemLevel ~= false) and true or false
end

-- Deposit/bank engine moved to fUI_GOTradeBank.lua

local function IsMailNotifierEnabled()
  -- Tri-state:
  --   CHAR override true  -> On
  --   CHAR override false -> Off
  --   nil                 -> use account (DB.mailNotify.enabled)
  if CHARDB and CHARDB.mailNotifyEnabledOverride ~= nil then
    return (CHARDB.mailNotifyEnabledOverride == true)
  end
  return (DB and DB.mailNotify and DB.mailNotify.enabled) and true or false
end

local function MailNotifyCfg()
  EnsureDB()
  if not (DB and CHARDB) then return nil end

  -- Scope is per-character:
  --   CHARDB.mailNotifyScope == "char" -> use per-character config
  --   otherwise                         -> use account-wide config (default)
  if CHARDB.mailNotifyScope == "char" then
    if type(CHARDB.mailNotify) ~= "table" then
      CHARDB.mailNotify = {}
    end
    return CHARDB.mailNotify
  end

  DB.mailNotify = DB.mailNotify or {}
  return DB.mailNotify
end

Print = function(msg)
  local frame
  if DB and type(DB.outputChatFrame) == "number" then
    frame = _G and _G["ChatFrame" .. DB.outputChatFrame]
  end
  if not (frame and frame.AddMessage) then
    frame = DEFAULT_CHAT_FRAME
  end
  if frame and frame.AddMessage then
    local text = tostring(msg or "")
    local prefix = (DB and DB.echoPrefix)
    if type(prefix) ~= "string" then
      prefix = ""
    end

    local final = (prefix ~= "") and (prefix .. text) or text
    local lootChat = LI and LI.LootChat
    if lootChat and lootChat.CaptureEnabled and lootChat.CaptureEnabled() then
      local e = {
        msg = final,
        raw = text,
        prefix = prefix,
        outputChatFrame = (DB and DB.outputChatFrame) or nil,
      }
      if (DB and DB.debugCaptureStacks) and type(debugstack) == "function" then
        ---@diagnostic disable-next-line: param-type-mismatch
        e.stack = debugstack(2, 10, 10)
      end
      if lootChat.CaptureAppend then
        lootChat.CaptureAppend("PRINT", e)
      end
    end

    frame:AddMessage(final)
  end
end

LI.Print = Print

local function PrintToChatFrame(msg, chatFrameID)
  local frame
  local n = tonumber(chatFrameID)
  if n and _G then
    frame = _G["ChatFrame" .. n]
  end
  if not (frame and frame.AddMessage) then
    frame = DEFAULT_CHAT_FRAME
  end
  if frame and frame.AddMessage then
    local text = tostring(msg or "")
    local lootChat = LI and LI.LootChat
    if lootChat and lootChat.CaptureEnabled and lootChat.CaptureEnabled() then
      local e = {
        msg = text,
        outputChatFrame = tonumber(chatFrameID) or nil,
      }
      if (DB and DB.debugCaptureStacks) and type(debugstack) == "function" then
        ---@diagnostic disable-next-line: param-type-mismatch
        e.stack = debugstack(2, 10, 10)
      end
      if lootChat.CaptureAppend then
        lootChat.CaptureAppend("PRINT", e)
      end
    end
    frame:AddMessage(text)
  end
end

local function SetCheckBoxText(cb, text)
  if not cb then return end
  local label = cb.Text or (cb.GetName and cb:GetName() and _G[cb:GetName() .. "Text"]) or cb.text
  if label and label.SetText then
    label:SetText(text)
  end
end

LI.SetCheckBoxText = SetCheckBoxText

local function SetCheckBoxChecked(cb, checked)
  if cb and cb.SetChecked then
    cb:SetChecked(checked and true or false)
  end
end

LI.SetCheckBoxChecked = SetCheckBoxChecked

local function GetLootChatModule()
  return LI and LI.LootChat
end

local function CaptureAppend(kind, data)
  local lootChat = GetLootChatModule()
  if lootChat and lootChat.CaptureAppend then
    return lootChat.CaptureAppend(kind, data)
  end
end

local function LootCombineEnabled()
  local lootChat = GetLootChatModule()
  return (lootChat and lootChat.LootCombineEnabled and lootChat.LootCombineEnabled()) and true or false
end

local function LootCombineFlush()
  local lootChat = GetLootChatModule()
  if lootChat and lootChat.LootCombineFlush then
    return lootChat.LootCombineFlush()
  end
end

local function LootCombineCancelTimers()
  local lootChat = GetLootChatModule()
  if lootChat and lootChat.LootCombineCancelTimers then
    return lootChat.LootCombineCancelTimers()
  end
end

local function LootCombineWindowStart()
  local lootChat = GetLootChatModule()
  if lootChat and lootChat.LootCombineWindowStart then
    return lootChat.LootCombineWindowStart()
  end
end

local function LootCombineWindowEnd()
  local lootChat = GetLootChatModule()
  if lootChat and lootChat.LootCombineWindowEnd then
    return lootChat.LootCombineWindowEnd()
  end
end

local function DelayPrintFlushAll()
  local lootChat = GetLootChatModule()
  if lootChat and lootChat.DelayPrintFlushAll then
    return lootChat.DelayPrintFlushAll()
  end
end

local function ApplyFilters()
  local lootChat = GetLootChatModule()
  if lootChat and lootChat.ApplyFilters then
    return lootChat.ApplyFilters()
  end
end

local function ApplyFiltersSoon(delaySeconds)
  local lootChat = GetLootChatModule()
  if lootChat and lootChat.ApplyFiltersSoon then
    return lootChat.ApplyFiltersSoon(delaySeconds)
  end
end

local function GetSupportedMessageLines()
  local lootChat = GetLootChatModule()
  if lootChat and lootChat.GetSupportedMessageLines then
    return lootChat.GetSupportedMessageLines()
  end
  return {}
end

-- Main file owns Bootstrap wiring; core exposes an env-builder so the main file
-- can wire modules after all files are loaded.
function LI.CoreBuildBootstrapEnv()
  local function IsMailEditorOpen()
    local ui = LI and LI.UI
    if ui and ui.IsMailEditorOpen then
      return ui.IsMailEditorOpen() and true or false
    end
    return false
  end

  local function CreateConfigUI()
    local ui = LI and LI.UI
    if ui and ui.CreateConfigUI then
      return ui.CreateConfigUI()
    end
    return nil
  end

  local function ToggleConfigUI()
    local ui = LI and LI.UI
    if ui and ui.ToggleConfigUI then
      return ui.ToggleConfigUI()
    end
  end

  local function ToggleMailConfigUI()
    local openTab = _G and rawget(_G, "FGO_OpenOptionsTab")
    if type(openTab) == "function" then
      openTab(8, true) -- Textures
    end
    local toggleMail = _G and rawget(_G, "FGO_ToggleMailPopout")
    if type(toggleMail) == "function" then
      toggleMail(nil)
    end
  end

  return {
    -- Common
    EnsureDB = EnsureDB,
    GetDB = function() return DB end,
    GetCharDB = function() return CHARDB end,
    Clamp = Clamp,
    Print = Print,
    PREFIX = PREFIX,

    -- LootChat
    IsEnabled = IsEnabled,
    IsIgnoredItemID = IsIgnoredItemID,
    IsItemLevelEnabled = IsItemLevelEnabled,
    ADDON_LINK_ALIASES = ADDON_LINK_ALIASES,
    ADDON_CURRENCY_ALIASES = ADDON_CURRENCY_ALIASES,
    DEFAULTS = DEFAULTS,
    PrintToChatFrame = PrintToChatFrame,

    -- UI
    ApplyFilters = ApplyFilters,
    LootCombineCancelTimers = LootCombineCancelTimers,
    LootCombineFlush = LootCombineFlush,
    SetCheckBoxText = SetCheckBoxText,
    SetCheckBoxChecked = SetCheckBoxChecked,
    GetSupportedMessageLines = GetSupportedMessageLines,
    MailNotifyCfg = MailNotifyCfg,

    -- Mail notifier
    IsMailNotifierEnabled = IsMailNotifierEnabled,
    IsMailEditorOpen = IsMailEditorOpen,
    ToggleConfigUI = ToggleConfigUI,
    ToggleMailConfigUI = ToggleMailConfigUI,

    -- Slash handler
    CreateConfigUI = CreateConfigUI,
    RunDeposit = function(target)
      if LI and type(LI.RunDeposit) == "function" then
        return LI.RunDeposit(target)
      end
    end,
    LootCombineEnabled = LootCombineEnabled,
    CaptureAppend = CaptureAppend,
    DebugSellOldFoodAtMerchant = DebugSellOldFoodAtMerchant,
  }
end

local function SafeUpdateMailNotifier()
  local mail = LI and LI.Mail
  if mail and type(mail.SafeUpdateMailNotifier) == "function" then
    mail.SafeUpdateMailNotifier()
  elseif mail and type(mail.UpdateMailNotifier) == "function" then
    pcall(mail.UpdateMailNotifier)
  end
end

local function BootstrapMailNotifier()
  local mail = LI and LI.Mail
  if mail and type(mail.BootstrapMailNotifier) == "function" then
    mail.BootstrapMailNotifier()
  else
    SafeUpdateMailNotifier()
  end
end

local f = CreateFrame("Frame")
local _merchantInteractionOpen = false
local _merchantClosePendingToken = 0

local function IsTradeDebugEnabled()
  return (DB and DB.deposit and DB.deposit.tradeDebug == true) and true or false
end

local function IsMerchantStillOpen()
  local mf = _G and rawget(_G, "MerchantFrame")
  if mf and mf.IsShown and mf:IsShown() then
    return true
  end

  if type(GetMerchantNumItems) == "function" then
    local ok, n = pcall(GetMerchantNumItems)
    n = ok and tonumber(n) or 0
    if n and n > 0 then
      return true
    end
  end

  return false
end
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_GUILD_UPDATE")
f:RegisterEvent("PLAYER_MONEY")
f:RegisterEvent("PLAYER_XP_UPDATE")
f:RegisterEvent("CHAT_MSG_MONEY")
f:RegisterEvent("CHAT_MSG_SYSTEM")
f:RegisterEvent("MERCHANT_SHOW")
f:RegisterEvent("MERCHANT_CLOSED")
f:RegisterEvent("UPDATE_PENDING_MAIL")
f:RegisterEvent("MAIL_INBOX_UPDATE")
f:RegisterEvent("GUILDBANKFRAME_OPENED")
f:RegisterEvent("GUILDBANKFRAME_CLOSED")
f:RegisterEvent("BANKFRAME_OPENED")
f:RegisterEvent("BANKFRAME_CLOSED")
f:RegisterEvent("BAG_UPDATE_DELAYED")
f:RegisterEvent("UI_ERROR_MESSAGE")
f:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
f:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")
f:RegisterEvent("PLAYER_REGEN_DISABLED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("LOOT_OPENED")
f:RegisterEvent("LOOT_CLOSED")
f:RegisterEvent("LOOT_READY")
f:SetScript("OnEvent", function(_, event, arg1, arg2, ...)
  EnsureDB()
  if event == "PLAYER_LOGIN" then
    UpdateSeenGuilds("PLAYER_LOGIN")
    do
      local tax = LI and LI.Tax
      if tax and tax.Init then
        tax.Init(DB, CHARDB, { Print = Print })
      end
    end
    ApplyFilters()
    ApplyFiltersSoon(1)
    BootstrapMailNotifier()
    do
      local udbv = LI and LI.UpdateDepositButtonVisibility
      if type(udbv) == "function" then
        C_Timer.After(0.25, udbv)
      end
    end
  elseif event == "PLAYER_ENTERING_WORLD" then
    UpdateSeenGuilds("PLAYER_ENTERING_WORLD")
    ApplyFiltersSoon(0.5)
    BootstrapMailNotifier()
    do
      local udbv = LI and LI.UpdateDepositButtonVisibility
      if type(udbv) == "function" then
        C_Timer.After(0.25, udbv)
      end
    end
  elseif event == "PLAYER_GUILD_UPDATE" then
    UpdateSeenGuilds("PLAYER_GUILD_UPDATE")
  elseif event == "PLAYER_MONEY" then
    local tax = LI and LI.Tax
    if tax and tax.OnPlayerMoney then
      tax.OnPlayerMoney()
    end
  elseif event == "PLAYER_XP_UPDATE" then
    local lc = LI and LI.LootChat
    if lc and lc.OnPlayerXPUpdate then
      lc.OnPlayerXPUpdate()
    end
  elseif event == "CHAT_MSG_MONEY" or event == "CHAT_MSG_SYSTEM" then
    local tax = LI and LI.Tax
    if tax and tax.OnMoneyMessage then
      tax.OnMoneyMessage(event, arg1)
    end
  elseif event == "MERCHANT_SHOW" then
    _merchantInteractionOpen = true
    _merchantClosePendingToken = 0
    local trade = LI and LI.Trade
    if trade and type(trade.OnMerchantShow) == "function" then
      trade.OnMerchantShow({
        StartMerchantTradeTicker = trade.StartMerchantTradeTicker,
        StopMerchantTradeTicker = trade.StopMerchantTradeTicker,
        DelayPrintFlushAll = DelayPrintFlushAll,
        Print = Print,
        GetDB = function()
          return DB
        end,
        Tax = LI and LI.Tax,
      })
    else
      local t = LI and LI.Trade
      if t and type(t.StartMerchantTradeTicker) == "function" then
        t.StartMerchantTradeTicker()
      end
      local tax = LI and LI.Tax
      if tax and tax.OnMerchantShow then
        tax.OnMerchantShow()
      end
    end
  elseif event == "MERCHANT_CLOSED" then
    if IsTradeDebugEnabled() then
      Print("Merchant close: event=MERCHANT_CLOSED")
      local trade = LI and LI.Trade
      if trade and type(trade.GetMerchantTickSummary) == "function" then
        local s = trade.GetMerchantTickSummary()
        if type(s) == "string" and s ~= "" then
          Print("Merchant close: " .. s)
        end
      end
    end
    _merchantInteractionOpen = false
    _merchantClosePendingToken = 0
    local trade = LI and LI.Trade
    if trade and type(trade.OnMerchantClosed) == "function" then
      trade.OnMerchantClosed({
        StartMerchantTradeTicker = trade.StartMerchantTradeTicker,
        StopMerchantTradeTicker = trade.StopMerchantTradeTicker,
        DelayPrintFlushAll = DelayPrintFlushAll,
        Print = Print,
        GetDB = function()
          return DB
        end,
        Tax = LI and LI.Tax,
      })
    else
      local t = LI and LI.Trade
      if t and type(t.StopMerchantTradeTicker) == "function" then
        t.StopMerchantTradeTicker()
      end
      if DB and DB.delayPrint and DB.delayPrint.flushOnMerchantClose then
        DelayPrintFlushAll()
      end
      local tax = LI and LI.Tax
      if tax and tax.OnMerchantClosed then
        tax.OnMerchantClosed()
      end
    end
  elseif event == "UI_ERROR_MESSAGE" then
    if _merchantInteractionOpen == true then
      local trade = LI and LI.Trade
      if trade and type(trade.OnUIErrorMessage) == "function" then
        trade.OnUIErrorMessage({
          Print = Print,
          GetDB = function()
            return DB
          end,
        }, arg1, arg2)
      end
    end
  elseif event == "BAG_UPDATE_DELAYED" then
    if _merchantInteractionOpen == true then
      local trade = LI and LI.Trade
      if trade and type(trade.OnBagUpdateDelayed) == "function" then
        trade.OnBagUpdateDelayed({
          Print = Print,
          GetDB = function()
            return DB
          end,
        })
      end
    end
  elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" or event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
    local it = (Enum and Enum.PlayerInteractionType) and Enum.PlayerInteractionType or nil
    local isShow = (event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
    local isBanker = (it and it.Banker and arg1 == it.Banker) and true or false
    local isAccountBanker = (it and it.AccountBanker and arg1 == it.AccountBanker) and true or false
    local isGuildBanker = (it and it.GuildBanker and arg1 == it.GuildBanker) and true or false
    local isMailbox = (it and it.MailInfo and arg1 == it.MailInfo) and true or false
    local isMerchant = (it and it.Merchant and arg1 == it.Merchant) and true or false
    do
      local tax = LI and LI.Tax
      if tax and tax.OnInteraction then
        tax.OnInteraction(isShow, arg1)
      end

      if tax and type(tax.IsDebugEnabled) == "function" and tax.IsDebugEnabled() then
        local evName = (isShow and "PIM_SHOW") or "PIM_HIDE"
        local itName = tostring(arg1)
        local it = (Enum and Enum.PlayerInteractionType) and Enum.PlayerInteractionType or nil
        if it then
          if it.Banker and arg1 == it.Banker then itName = "Banker" end
          if it.AccountBanker and arg1 == it.AccountBanker then itName = "AccountBanker" end
          if it.GuildBanker and arg1 == it.GuildBanker then itName = "GuildBanker" end
        end
        Print("Tax debug: core " .. evName .. " type=" .. itName)
      end
    end

    -- Mail notifier: hide while mailbox is open; recheck when it closes.
    if isMailbox then
      local mail = LI and LI.Mail
      if mail and type(mail.OnMailboxInteraction) == "function" then
        pcall(mail.OnMailboxInteraction, isShow)
      else
        if mail and mail.SetMailboxOpen then
          pcall(mail.SetMailboxOpen, isShow)
        end
        if isShow then
          SafeUpdateMailNotifier()
        else
          if C_Timer and C_Timer.After then
            C_Timer.After(0.40, BootstrapMailNotifier)
          else
            BootstrapMailNotifier()
          end
        end
      end
    end

    -- Merchant interactions: some clients/UIs prefer the interaction manager events.
    -- Dedupe against MERCHANT_SHOW/CLOSED so we don't restart the ticker twice.
    if isMerchant then
      local trade = LI and LI.Trade
      if trade and isShow and (not _merchantInteractionOpen) and type(trade.OnMerchantShow) == "function" then
        _merchantInteractionOpen = true
        _merchantClosePendingToken = 0
        trade.OnMerchantShow({
          StartMerchantTradeTicker = trade.StartMerchantTradeTicker,
          StopMerchantTradeTicker = trade.StopMerchantTradeTicker,
          DelayPrintFlushAll = DelayPrintFlushAll,
          Print = Print,
          GetDB = function()
            return DB
          end,
          Tax = LI and LI.Tax,
        })
      elseif trade and (not isShow) and _merchantInteractionOpen and type(trade.OnMerchantClosed) == "function" then
        -- Some clients/UIs can emit a transient PIM_HIDE while the merchant is still open
        -- (e.g. right after buy/restock updates). Don't stop the ticker immediately.
        _merchantClosePendingToken = (_merchantClosePendingToken or 0) + 1
        local token = _merchantClosePendingToken
        if C_Timer and type(C_Timer.After) == "function" then
          C_Timer.After(0.25, function()
            if token ~= _merchantClosePendingToken then return end
            if not _merchantInteractionOpen then return end
            if IsMerchantStillOpen() then
              if IsTradeDebugEnabled() then
                Print("Merchant close: ignore transient PIM_HIDE (still open)")
              end
              return
            end

            if IsTradeDebugEnabled() then
              Print("Merchant close: event=PIM_HIDE (verified closed)")
            end

            _merchantInteractionOpen = false
            _merchantClosePendingToken = 0
            trade.OnMerchantClosed({
              StartMerchantTradeTicker = trade.StartMerchantTradeTicker,
              StopMerchantTradeTicker = trade.StopMerchantTradeTicker,
              DelayPrintFlushAll = DelayPrintFlushAll,
              Print = Print,
              GetDB = function()
                return DB
              end,
              Tax = LI and LI.Tax,
            })
          end)
        else
          if not IsMerchantStillOpen() then
            if IsTradeDebugEnabled() then
              Print("Merchant close: event=PIM_HIDE (no timer; verified closed)")
            end
            _merchantInteractionOpen = false
            _merchantClosePendingToken = 0
            trade.OnMerchantClosed({
              StartMerchantTradeTicker = trade.StartMerchantTradeTicker,
              StopMerchantTradeTicker = trade.StopMerchantTradeTicker,
              DelayPrintFlushAll = DelayPrintFlushAll,
              Print = Print,
              GetDB = function()
                return DB
              end,
              Tax = LI and LI.Tax,
            })
          end
        end
      end
    end
    if isBanker then
      local trade = LI and LI.Trade
      if trade and type(trade.OnInteractionBanking) == "function" then
        trade.OnInteractionBanking({
          SetBankInteractionOpen = LI and LI.SetBankInteractionOpen,
          SetWarbankInteractionOpen = LI and LI.SetWarbankInteractionOpen,
          SetGuildbankInteractionOpen = LI and LI.SetGuildbankInteractionOpen,
          ResetGuildBankQuerySession = LI and LI.ResetGuildBankQuerySession,
          UpdateDepositButtonVisibility = LI and LI.UpdateDepositButtonVisibility,
          Print = Print,
          GetDB = function()
            return DB
          end,
        }, isShow, isBanker, isAccountBanker, isGuildBanker)
      else
        if LI and type(LI.SetBankInteractionOpen) == "function" then
          LI.SetBankInteractionOpen(isShow)
        end
      end
    elseif isAccountBanker then
      local trade = LI and LI.Trade
      if trade and type(trade.OnInteractionBanking) == "function" then
        trade.OnInteractionBanking({
          SetBankInteractionOpen = LI and LI.SetBankInteractionOpen,
          SetWarbankInteractionOpen = LI and LI.SetWarbankInteractionOpen,
          SetGuildbankInteractionOpen = LI and LI.SetGuildbankInteractionOpen,
          ResetGuildBankQuerySession = LI and LI.ResetGuildBankQuerySession,
          UpdateDepositButtonVisibility = LI and LI.UpdateDepositButtonVisibility,
          Print = Print,
          GetDB = function()
            return DB
          end,
        }, isShow, isBanker, isAccountBanker, isGuildBanker)
      else
        if LI and type(LI.SetWarbankInteractionOpen) == "function" then
          LI.SetWarbankInteractionOpen(isShow)
        end
      end
    elseif isGuildBanker then
      local trade = LI and LI.Trade
      if trade and type(trade.OnInteractionBanking) == "function" then
        trade.OnInteractionBanking({
          SetBankInteractionOpen = LI and LI.SetBankInteractionOpen,
          SetWarbankInteractionOpen = LI and LI.SetWarbankInteractionOpen,
          SetGuildbankInteractionOpen = LI and LI.SetGuildbankInteractionOpen,
          ResetGuildBankQuerySession = LI and LI.ResetGuildBankQuerySession,
          UpdateDepositButtonVisibility = LI and LI.UpdateDepositButtonVisibility,
          Print = Print,
          GetDB = function()
            return DB
          end,
        }, isShow, isBanker, isAccountBanker, isGuildBanker)
      else
        if LI and type(LI.SetGuildbankInteractionOpen) == "function" then
          LI.SetGuildbankInteractionOpen(isShow)
        end
        if isShow and LI and type(LI.ResetGuildBankQuerySession) == "function" then
          LI.ResetGuildBankQuerySession()
        end
      end
    end
    if not ((isBanker or isAccountBanker or isGuildBanker) and LI and LI.Trade and type(LI.Trade.OnInteractionBanking) == "function") then
      if (isBanker or isAccountBanker or isGuildBanker) and LI and type(LI.UpdateDepositButtonVisibility) == "function" then
        LI.UpdateDepositButtonVisibility()
      end
    end
  elseif event == "GUILDBANKFRAME_OPENED" or event == "GUILDBANKFRAME_CLOSED" or event == "BANKFRAME_OPENED" or event == "BANKFRAME_CLOSED" then
    do
      local tax = LI and LI.Tax
      if tax and type(tax.IsDebugEnabled) == "function" and tax.IsDebugEnabled() then
        Print("Tax debug: core event=" .. tostring(event))
      end
    end
    do
      local trade = LI and LI.Trade
      if trade and type(trade.OnBankOrGuildBankFrameEvent) == "function" then
        trade.OnBankOrGuildBankFrameEvent({
          ResetGuildBankQuerySession = LI and LI.ResetGuildBankQuerySession,
          UpdateDepositButtonVisibility = LI and LI.UpdateDepositButtonVisibility,
        }, event)
      else
        if (event == "GUILDBANKFRAME_OPENED" or event == "GUILDBANKFRAME_CLOSED") and LI and type(LI.ResetGuildBankQuerySession) == "function" then
          LI.ResetGuildBankQuerySession()
        end
      end
    end

    -- Tax module primarily tracks guild bank state via PlayerInteractionManager, but some
    -- client/interaction paths only emit the classic GUILDBANKFRAME_* events.
    -- Bridge those here so PayNow/min-balance borrow logic still runs.
    if event == "GUILDBANKFRAME_OPENED" or event == "GUILDBANKFRAME_CLOSED" then
      local guildOpen = (LI and type(LI.GetGuildbankInteractionOpen) == "function" and LI.GetGuildbankInteractionOpen()) or false
      local tax = LI and LI.Tax
      if tax and type(tax.OnGuildBankFrameClassicEvent) == "function" then
        tax.OnGuildBankFrameClassicEvent(event, guildOpen)
      elseif tax and tax.OnGuildBankFrame then
        -- Avoid double-triggering if PlayerInteractionManager already handled this.
        if event == "GUILDBANKFRAME_OPENED" then
          if not (guildOpen == true) then
            tax.OnGuildBankFrame(true)
          end
        else
          tax.OnGuildBankFrame(false)
        end
      end
    end

    if not (LI and LI.Trade and type(LI.Trade.OnBankOrGuildBankFrameEvent) == "function") then
      if LI and type(LI.UpdateDepositButtonVisibility) == "function" then
        LI.UpdateDepositButtonVisibility()
      end
    end

    if event == "BANKFRAME_OPENED" then
      local trade = LI and LI.Trade
      if trade and type(trade.OnBankFrameOpened) == "function" then
        trade.OnBankFrameOpened({
          StartBankTicker = LI and LI.StartBankTicker,
          StopBankTicker = LI and LI.StopBankTicker,
          Print = Print,
          GetDB = function()
            return DB
          end,
        })
      else
        if LI and type(LI.StartBankTicker) == "function" then
          LI.StartBankTicker()
        end
      end
    elseif event == "BANKFRAME_CLOSED" then
      local trade = LI and LI.Trade
      if trade and type(trade.OnBankFrameClosed) == "function" then
        trade.OnBankFrameClosed({
          StartBankTicker = LI and LI.StartBankTicker,
          StopBankTicker = LI and LI.StopBankTicker,
          Print = Print,
          GetDB = function()
            return DB
          end,
        })
      else
        if LI and type(LI.StopBankTicker) == "function" then
          LI.StopBankTicker()
        end
      end

      -- Safety: some close paths don't emit interaction hide.
      if LI and type(LI.SetBankInteractionOpen) == "function" then
        LI.SetBankInteractionOpen(false)
      end
      if LI and type(LI.SetWarbankInteractionOpen) == "function" then
        LI.SetWarbankInteractionOpen(false)
      end

      do
        local tax = LI and LI.Tax
        if tax and type(tax.OnBankFrameClosed) == "function" then
          tax.OnBankFrameClosed({
            GetTaxWarbankOpen = function()
              return (LI and type(LI.GetTaxWarbankOpen) == "function" and LI.GetTaxWarbankOpen()) or false
            end,
            SetTaxWarbankOpen = function(v)
              if LI and type(LI.SetTaxWarbankOpen) == "function" then
                LI.SetTaxWarbankOpen(v == true)
              end
            end,
          })
        else
          -- Ensure Tax warbank state closes when the unified BankFrame closes.
          local wasOpen = (LI and type(LI.GetTaxWarbankOpen) == "function" and LI.GetTaxWarbankOpen()) or false
          if wasOpen == true then
            if LI and type(LI.SetTaxWarbankOpen) == "function" then
              LI.SetTaxWarbankOpen(false)
            end
            if tax and tax.OnWarbankFrame then
              tax.OnWarbankFrame(false)
            end
          end
        end
      end
    end
  elseif event == "UPDATE_PENDING_MAIL" then
    local mail = LI and LI.Mail
    if mail and type(mail.OnPendingMailChanged) == "function" then
      mail.OnPendingMailChanged()
    else
      BootstrapMailNotifier()
    end
  elseif event == "MAIL_INBOX_UPDATE" then
    -- Extra safety: some clients update HasNewMail/UI state later than UPDATE_PENDING_MAIL.
    local mail = LI and LI.Mail
    if mail and type(mail.OnPendingMailChanged) == "function" then
      mail.OnPendingMailChanged()
    else
      BootstrapMailNotifier()
    end
  elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
    local mail = LI and LI.Mail
    if mail and type(mail.OnCombatStateChanged) == "function" then
      mail.OnCombatStateChanged()
    else
      SafeUpdateMailNotifier()
    end
  elseif event == "LOOT_OPENED" or event == "LOOT_READY" then
    local lootChat = LI and LI.LootChat
    if lootChat and type(lootChat.OnLootLifecycle) == "function" then
      lootChat.OnLootLifecycle(event, {
        ApplyFilters = ApplyFilters,
        LootCombineWindowStart = LootCombineWindowStart,
        LootCombineWindowEnd = LootCombineWindowEnd,
      })
    else
      -- Other addons can remove chat filters at runtime; re-apply here so loot lines are still rewritten.
      ApplyFilters()
      LootCombineWindowStart()
    end
  elseif event == "LOOT_CLOSED" then
    local lootChat = LI and LI.LootChat
    if lootChat and type(lootChat.OnLootLifecycle) == "function" then
      lootChat.OnLootLifecycle(event, {
        ApplyFilters = ApplyFilters,
        LootCombineWindowStart = LootCombineWindowStart,
        LootCombineWindowEnd = LootCombineWindowEnd,
      })
    else
      LootCombineWindowEnd()
    end
  end
end)
