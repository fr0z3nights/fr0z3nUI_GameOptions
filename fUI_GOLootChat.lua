---@diagnostic disable: undefined-global
local addonName, ns = ...
if type(ns) ~= "table" then ns = {} end

local LI = (ns and ns.LootIt) or {}
ns.LootIt = LI
fr0z3nUI_LootIt = LI
LI.ADDON = LI.ADDON or addonName

LI.LootChat = LI.LootChat or {}
local LootChat = LI.LootChat

local env = nil
local DB
local CHARDB

-- Forward declarations used by AddMessage hook (must be declared before the hook is defined).
local LOOT_PATTERNS, LOOT_PREFIXES, LOOT_GROUP_PATTERNS, RECEIVE_ITEM_PATTERNS
local BuildLootPatterns
local MessageStartsWithLootPrefix

-- Forward declarations for helpers used by AddMessage hook.
local ParseCoinsFromMoneyMessage
local FormatMoney
local IsLikelyMoneyMessage
local FormatSelfLine

-- Secret-string guard (must be a local up-front; early helpers use it).
local IsSecretString

-- Forward declarations for helpers used by chat filters.
local QuestXPEnabled
local IsPlayedSystemMessage

local function SuppressRulesEnabled()
  local s = DB and DB.suppress
  if type(s) ~= "table" then return false, nil end
  if s.enabled == false then return false, nil end
  local rules = (type(s.rules) == "table") and s.rules or nil
  local seeds = (type(LI) == "table" and type(LI.AddonSuppressSeeds) == "table") and LI.AddonSuppressSeeds
    or (_G and rawget(_G, "fr0z3nUI_LootIt_AddonSuppressSeeds"))

  local hasRules = (type(rules) == "table") and (#rules > 0)
  local hasSeeds = (type(seeds) == "table") and (#seeds > 0)
  if (not hasRules) and (not hasSeeds) then
    return false, nil
  end
  return true, { rules = rules, seeds = seeds }
end

local function NormalizeSuppressText(msg)
  if type(msg) ~= "string" or msg == "" then return nil end
  if IsSecretString(msg) then return nil end

  local t = msg:gsub("\r", " "):gsub("\n", " ")
  t = t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  t = t:gsub("|H.-|h(.-)|h", "%1")
  t = t:gsub("|T.-|t", "")
  t = t:gsub("\194\160", " ")
  t = t:gsub("\226\128\175", " ")
  t = t:gsub("\226\128\135", " ")
  t = t:gsub("%s+", " ")
  t = t:gsub("^%s+", ""):gsub("%s+$", "")
  if t == "" then return nil end
  return t:lower()
end

local function ShouldSuppressMessage(msg)
  local ok, rules = SuppressRulesEnabled()
  if (not ok) or type(rules) ~= "table" then return false end

  local t = NormalizeSuppressText(msg)
  if not t then return false end

  local svRules = rules.rules
  if type(svRules) == "table" then
    for i = 1, #svRules do
      local r = svRules[i]
      if type(r) == "table" and r.enabled ~= false then
        local needle = r.text
        if type(needle) == "string" and needle ~= "" and not IsSecretString(needle) then
          local n = needle:lower():gsub("^%s+", ""):gsub("%s+$", "")
          if n ~= "" and string.find(t, n, 1, true) then
            return true, i, needle
          end
        end
      end
    end
  end

  local seeds = rules.seeds
  if type(seeds) == "table" and #seeds > 0 then
    local s = DB and DB.suppress
    local disabled = (type(s) == "table" and type(s.seedDisabled) == "table") and s.seedDisabled or nil

    for i = 1, #seeds do
      local r = seeds[i]
      if type(r) == "table" then
        local needle = r.text
        if type(needle) == "string" and needle ~= "" and not IsSecretString(needle) then
          local key = (type(r.key) == "string" and r.key ~= "") and r.key or tostring(i)
          if not (disabled and disabled[key] == true) then
            local n = needle:lower():gsub("^%s+", ""):gsub("%s+$", "")
            if n ~= "" and string.find(t, n, 1, true) then
              return true, "seed:" .. key, needle
            end
          end
        end
      end
    end
  end

  return false
end

function LootChat.SetEnv(e)
  env = e or {}
end

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

local function EnsureRefs()
  if env and env.EnsureDB then
    env.EnsureDB()
  end
  if env and env.GetDB then
    DB = env.GetDB()
  end
  if env and env.GetCharDB then
    CHARDB = env.GetCharDB()
  end
end

IsSecretString = function(v)
  if type(issecretvalue) == "function" then
    local ok, r = pcall(issecretvalue, v)
    return ok and r == true
  end
  local g = _G and rawget(_G, "IsSecretString")
  if type(g) == "function" then
    local ok, r = pcall(g, v)
    return ok and r == true
  end
  return false
end

local function IsNonEmptyPublicString(v)
  -- IMPORTANT: Secret string values cannot be compared (even to "") and will throw.
  -- Always check issecretvalue() BEFORE any string comparisons or string operations.
  if type(v) ~= "string" then return false end
  if IsSecretString(v) then return false end
  return v ~= ""
end

local function IsEnabled()
  return (env and env.IsEnabled and env.IsEnabled()) and true or false
end

local function IsIgnoredItemID(itemID)
  if env and env.IsIgnoredItemID then
    return env.IsIgnoredItemID(itemID) and true or false
  end
  return false
end

local function IsItemLevelEnabled()
  if env and env.IsItemLevelEnabled then
    return env.IsItemLevelEnabled() and true or false
  end
  return false
end

local function Print(msg)
  if env and env.Print then
    return env.Print(msg)
  end
end

local function PrintToChatFrame(msg, chatFrameID)
  if env and env.PrintToChatFrame then
    return env.PrintToChatFrame(msg, chatFrameID)
  end
  return Print(msg)
end

local function GetChatWindowName(id)
  id = tonumber(id)
  if not id then return nil end
  if type(GetChatWindowInfo) ~= "function" then return nil end
  local ok, name = pcall(GetChatWindowInfo, id)
  if ok and type(name) == "string" and name ~= "" then
    return name
  end
  return nil
end

local function DebugChatSetupEnabled()
  EnsureRefs()
  return (DB and DB.debugChatSetup) == true
end

local function DebugPrint(line)
  if not DebugChatSetupEnabled() then return end
  local outFrame = (DB and DB.outputChatFrame) or 1
  PrintToChatFrame("[LootIt ChatDebug] " .. tostring(line or ""), outFrame)
end

-- Debug-only: track whether handlers are firing (helps diagnose boss-fight "stops working" cases
-- where filters remain installed but no events arrive, or settings flip mid-fight).
local _debugEventStats = {
  startedAt = (type(GetTime) == "function" and GetTime()) or 0,
  ev = {},
}

local _debugSecretStats = {
  ev = {}, -- [eventKey] = { n=?, last=? }
}

local function DebugBumpEvent(key)
  if type(key) ~= "string" or key == "" then return end
  local now = (type(GetTime) == "function" and GetTime()) or 0
  _debugEventStats.ev = _debugEventStats.ev or {}
  local s = _debugEventStats.ev[key]
  if type(s) ~= "table" then s = { n = 0 } end
  s.n = (tonumber(s.n) or 0) + 1
  s.last = now
  -- Snapshot the relevant toggles at last-seen time.
  s.enabled = IsEnabled() and true or false
  s.hide = (DB and DB.hideLootText) and true or false
  s.echo = (DB and DB.echoItem) and true or false
  _debugEventStats.ev[key] = s
end

local function DebugBumpSecret(key)
  if type(key) ~= "string" or key == "" then return end
  local now = (type(GetTime) == "function" and GetTime()) or 0
  _debugSecretStats.ev = _debugSecretStats.ev or {}
  local s = _debugSecretStats.ev[key]
  if type(s) ~= "table" then s = { n = 0 } end
  s.n = (tonumber(s.n) or 0) + 1
  s.last = now
  _debugSecretStats.ev[key] = s
end

function LootChat.DumpEventStats(PrintFn)
  EnsureRefs()
  local now = (type(GetTime) == "function" and GetTime()) or 0
  local startAt = tonumber(_debugEventStats.startedAt) or 0
  SafeCall(PrintFn, string.format("Event stats: up=%.1fs", (now - startAt)))

  local function Line(key, label)
    local s = _debugEventStats.ev and _debugEventStats.ev[key] or nil
    local ss = _debugSecretStats.ev and _debugSecretStats.ev[key] or nil
    local secretN = (type(ss) == "table" and tonumber(ss.n)) or 0
    local secretAge = (type(ss) == "table" and ss.last) and (now - ss.last) or nil
    local secretText = (secretN > 0)
      and string.format(" secret=%d(last %.2fs)", secretN, tonumber(secretAge) or 0)
      or ""
    if type(s) ~= "table" then
      SafeCall(PrintFn, string.format("  %s: n=0 last=(never)%s", label, secretText))
      return
    end
    local age = (s.last and (now - s.last)) or nil
    local ageText = age and string.format("%.2fs ago", age) or "?"
    SafeCall(PrintFn, string.format(
      "  %s: n=%d last=%s enabled=%s hide=%s echo=%s%s",
      label,
      tonumber(s.n) or 0,
      ageText,
      tostring(s.enabled == true),
      tostring(s.hide == true),
      tostring(s.echo == true),
      secretText
    ))
  end

  Line("CHAT_MSG_LOOT", "loot")
  Line("CHAT_MSG_MONEY", "money")
  Line("CHAT_MSG_CURRENCY", "currency")
  Line("CHAT_MSG_SYSTEM", "system")
  Line("CHAT_MSG_COMBAT_MISC_INFO", "combat_misc")
  Line("CHAT_MSG_COMBAT_XP_GAIN", "xp_gain")
  Line("CHAT_MSG_SKILL", "skill")
  Line("CHAT_MSG_TRADESKILLS", "tradeskills")
  Line("CHAT_MSG_ACHIEVEMENT", "achievement")
  Line("CHAT_MSG_GUILD_ACHIEVEMENT", "guild_achievement")
  Line("ChatFrame.AddMessage", "direct_print")
end

-- Loot lifecycle hooks (delegated from core) so LOOT_OPENED/READY can re-apply
-- chat filters and start the combine window, and LOOT_CLOSED can end it.
function LootChat.OnLootLifecycle(event, wiring)
  wiring = (type(wiring) == "table") and wiring or {}
  local ApplyFilters = wiring.ApplyFilters
  local LootCombineWindowStart = wiring.LootCombineWindowStart
  local LootCombineWindowEnd = wiring.LootCombineWindowEnd

  event = tostring(event or "")
  if event == "LOOT_OPENED" or event == "LOOT_READY" then
    DebugPrint("Loot lifecycle: " .. event .. " (reapply filters + combine start)")
    SafeCall(ApplyFilters)
    SafeCall(LootCombineWindowStart)
    return
  end
  if event == "LOOT_CLOSED" then
    do
      local now = (type(GetTime) == "function") and GetTime() or nil
      if now and LootChat._lastLootClosedDebugAt and (now - LootChat._lastLootClosedDebugAt) < 0.25 then
        -- Skip duplicate close debug prints emitted by some client loot-close paths.
      else
        LootChat._lastLootClosedDebugAt = now
        DebugPrint("Loot lifecycle: LOOT_CLOSED (combine end)")
      end
    end
    SafeCall(LootCombineWindowEnd)
    return
  end
end

local addMessageHooks = nil
local addMessageInHook = false

-- Some loot-related messages bypass chat event filters and are printed directly to frames.
-- We use localized global strings to build safe prefix checks for money/currency lines.
local DIRECT_MONEY_PREFIXES
local DIRECT_CURRENCY_PREFIXES

local function BuildDirectPrefixes(keys)
  local out = {}
  for _, k in ipairs(keys or {}) do
    local gs = _G and rawget(_G, k)
    if type(gs) == "string" and gs ~= "" then
      local prefix = gs:match("^(.-)%%[sd]")
      if prefix and prefix ~= "" then
        out[#out + 1] = prefix
      end
    end
  end
  return out
end

local function MessageStartsWithAnyPrefix(msg, prefixes)
  if type(msg) ~= "string" then return false end
  if IsSecretString(msg) then return false end
  if msg == "" then return false end
  if type(prefixes) ~= "table" or #prefixes == 0 then return false end
  -- Minimal normalization: trim leading whitespace.
  local s = msg:gsub("^%s+", "")
  for _, p in ipairs(prefixes) do
    if type(p) == "string" and p ~= "" then
      local tp = p:gsub("^%s+", "")
      if tp ~= "" and s:sub(1, #tp) == tp then
        return true
      end
    end
  end
  return false
end

-- Direct-print dedupe: some clients print a currency line directly via ChatFrame:AddMessage
-- while also emitting the normal CHAT_MSG_CURRENCY event. Suppress the direct print if we
-- very recently printed the same currency/qty ourselves.
local function SafeGetTime()
  if type(GetTime) == "function" then
    local ok, v = pcall(GetTime)
    if ok and type(v) == "number" then
      return v
    end
  end
  return nil
end

local function RememberRecentCurrencyPrint(currencyID, qty)
  LootChat._recentCurrencyPrint = {
    ts = SafeGetTime(),
    id = tonumber(currencyID),
    qty = tonumber(qty),
  }
end

local function IsDuplicateRecentCurrencyPrint(currencyID, qty, windowSec)
  local t = LootChat._recentCurrencyPrint
  if type(t) ~= "table" then return false end
  local now = SafeGetTime()
  if not now or type(t.ts) ~= "number" then return false end
  local w = tonumber(windowSec) or 0.35
  if w < 0.05 then w = 0.05 end
  if (now - t.ts) > w then return false end
  local id = tonumber(currencyID)
  local q = tonumber(qty)
  if not id or id <= 0 then return false end
  if tonumber(t.id) ~= id then return false end
  -- Qty can be missing on some direct prints; treat missing as match.
  if q and q > 0 and t.qty and tonumber(t.qty) ~= q then
    return false
  end
  return true
end

local function HookChatFrameAddMessage(frame)
  if not frame or type(frame.AddMessage) ~= "function" then return end

  local key = tostring(frame)
  if not addMessageHooks then addMessageHooks = {} end
  if addMessageHooks[key] then return end

  local orig = frame.AddMessage
  addMessageHooks[key] = orig

  -- Debug visibility: count how many frames we successfully hooked.
  LootChat._debugAddMessageHookCount = (tonumber(LootChat._debugAddMessageHookCount) or 0) + 1

  frame.AddMessage = function(self, text, ...)
    if addMessageInHook then
      return orig(self, text, ...)
    end

    EnsureRefs()
    if LootChat and LootChat._inChatDebugDump then
      return orig(self, text, ...)
    end
    if type(text) == "string" and IsSecretString(text) then
      DebugBumpEvent("ChatFrame.AddMessage")
      DebugBumpSecret("ChatFrame.AddMessage")
      if LootChat.CaptureEnabled() then
        LootChat.CaptureAppend("CHAT_SECRET", { event = "ChatFrame.AddMessage" })
      end
      return orig(self, text, ...)
    end
    if type(text) == "string" and text:match("^%[LootIt") then
      return orig(self, text, ...)
    end
    if not IsNonEmptyPublicString(text) then
      return orig(self, text, ...)
    end

    DebugBumpEvent("ChatFrame.AddMessage")

    -- Capture debug: direct AddMessage prints can bypass chat event filters.
    LootChat.CaptureChatIn("CHATFRAME_ADD", text)

    -- Generic suppress rules (SV-backed): catches addon spam that prints directly via AddMessage.
    do
      local hit, idx, needle = ShouldSuppressMessage(text)
      if hit then
        LootChat.CaptureChatOut("CHAT_MSG_SYSTEM", "(suppress) suppressed", {
          handled = true,
          suppressedByRule = true,
          suppressRuleIndex = idx,
          suppressRuleText = needle,
          directPrint = true,
        })
        return
      end
    end

    -- /played system output can bypass chat event filters and print directly.
    -- Suppress it whenever the Played toggle is enabled (independent of hideLootText).
    if (DB and DB.other and DB.other.hidePlayed) == true and IsPlayedSystemMessage then
      local playedKey = IsPlayedSystemMessage(text)
      if playedKey then
        LootChat.CaptureChatOut("CHAT_MSG_SYSTEM", "(played) suppressed", {
          handled = true,
          suppressedPlayed = true,
          directPrint = true,
          fromKey = playedKey,
        })
        return
      end
    end

    if not (IsEnabled() and DB and DB.hideLootText) then
      return orig(self, text, ...)
    end

    -- Catch messages that bypass chat event filters and are directly printed to frames.
    if not LOOT_PREFIXES then BuildLootPatterns() end
    if not DIRECT_MONEY_PREFIXES then
      DIRECT_MONEY_PREFIXES = BuildDirectPrefixes({ "LOOT_MONEY", "LOOT_MONEY_SPLIT" })
    end
    if not DIRECT_CURRENCY_PREFIXES then
      DIRECT_CURRENCY_PREFIXES = BuildDirectPrefixes({
        "CURRENCY_GAINED",
        "CURRENCY_GAINED_MULTIPLE",
        "CURRENCY_GAINED_SELF",
        "CURRENCY_GAINED_SELF_MULTIPLE",
      })
    end

    local startsLoot = MessageStartsWithLootPrefix(text)
    local startsMoney = MessageStartsWithAnyPrefix(text, DIRECT_MONEY_PREFIXES)
    local startsCurrency = MessageStartsWithAnyPrefix(text, DIRECT_CURRENCY_PREFIXES)
    local isMoney = (IsLikelyMoneyMessage and IsLikelyMoneyMessage(text)) and true or false

    if startsLoot or startsMoney or startsCurrency or isMoney then
      local hasItem = (string.find(text, "|Hitem:", 1, true) ~= nil)
      local hasCurrency = (string.find(text, "|Hcurrency:", 1, true) ~= nil)
      local hasBracket = (string.match(text, "%b[]") ~= nil)

      if hasItem or hasCurrency or hasBracket or isMoney then
        local outFrame = (DB and DB.outputChatFrame) or 1

        local function GetPlayerColoredName()
          local name = (UnitName and UnitName("player")) or "You"
          if not (UnitClass and name) then
            return tostring(name)
          end

          local _, classFile = UnitClass("player")
          if C_ClassColor and C_ClassColor.GetClassColor and classFile then
            local color = C_ClassColor.GetClassColor(classFile)
            if color and color.WrapTextInColorCode then
              return color:WrapTextInColorCode(name)
            end
          end
          local rc = RAID_CLASS_COLORS and classFile and RAID_CLASS_COLORS[classFile]
          if rc and rc.colorStr then
            return "|c" .. rc.colorStr .. name .. "|r"
          end
          return tostring(name)
        end

        -- Reprint (if configured) so the loot isn't lost.
        local handledByEcho = false
        local combined = false
        local display = nil

        if DB and DB.echoItem then
          if isMoney and ParseCoinsFromMoneyMessage and FormatMoney then
            local coins = ParseCoinsFromMoneyMessage(text)
            display = FormatMoney(coins)
          else
            local link = string.match(text, "(|c%x%x%x%x%x%x%x%x|Hitem:%d+.-|h.-|h|r)")
              or string.match(text, "(|Hitem:%d+.-|h.-|h|r)")
              or string.match(text, "(|Hitem:%d+.-|h.-|h)")
              or string.match(text, "(|c%x+|Hitem:%d+.-|h.-|h|r)")
              or string.match(text, "(|c%x%x%x%x%x%x%x%x|Hcurrency:%d+.-|h.-|h|r)")
              or string.match(text, "(|Hcurrency:%d+.-|h.-|h)")

            -- If we captured an uncolored item link, try to upgrade to the full colored item link.
            if link and type(link) == "string" and string.len(link) > 0 and not string.match(link, "^|c%x%x%x%x%x%x%x%x|Hitem:") and string.find(link, "|Hitem:", 1, true) then
              if C_Item and C_Item.GetItemInfo then
                local _, itemLink = C_Item.GetItemInfo(link)
                if type(itemLink) == "string" and string.len(itemLink) > 0 then
                  link = itemLink
                end
              end
            end

            if link then
              -- Currency dedupe: if we very recently printed the same currency via CHAT_MSG_CURRENCY,
              -- suppress this direct print without echoing a second line.
              if startsCurrency and link:find("|Hcurrency:", 1, true) then
                local currencyID = GetCurrencyIDFromLink(link)

                local qty
                do
                  local escaped = EscapeLuaPattern(link)
                  qty = string.match(text, escaped .. "%s*[x×]%s*(%d+)")
                    or string.match(text, escaped .. "[\r\n ]*[x×]%s*(%d+)")
                    or string.match(text, "%s*[x×]%s*(%d+)%s*%.?$")
                end
                local n = tonumber(qty)

                if currencyID and IsDuplicateRecentCurrencyPrint(currencyID, n, 0.35) then
                  LootChat.CaptureChatOut("CHATFRAME_ADD", "(currency) deduped", {
                    handled = true,
                    directPrint = true,
                    dedupedCurrency = true,
                    currencyID = currencyID,
                    qty = n,
                  })
                  return
                end

                -- Build a clean display for currency direct prints (alias + qty) when we *do* echo.
                if currencyID and C_CurrencyInfo and C_CurrencyInfo.GetCurrencyLink then
                  local built = C_CurrencyInfo.GetCurrencyLink(currencyID, (n and n > 0) and n or 0)
                  if type(built) == "string" and built ~= "" then
                    link = built
                  end
                end
                link = (ApplyCurrencyLinkAlias and ApplyCurrencyLinkAlias(link)) or link
                display = StripDisplayedLinkBrackets(link)
                if n and n > 1 then
                  display = string.format("%s x%d", display, n)
                end
              else
                -- Remove brackets in the displayed portion: |h[Name]|h -> |hName|h
                display = string.gsub(link, "|h%[([^%]]+)%]|h", "|h%1|h")
              end
            else
              -- Fallback: use the shown [Name]
              display = string.match(text, "%b[]")
            end
          end

          if type(display) == "string" and string.len(display) > 0 then
            local combineEnabled = LootChat.LootCombineEnabled() and true or false
            local canCombine = false
            if combineEnabled then
              if isMoney then
                canCombine = (DB and DB.lootCombineIncludeGold) and true or false
              elseif startsCurrency then
                canCombine = (DB and DB.lootCombineIncludeCurrency) and true or false
              else
                -- Items / other loot: always include.
                canCombine = true
              end
            end

            if canCombine then
              if isMoney then
                LootCombineAdd(tostring(display), "money")
              elseif startsCurrency then
                LootCombineAdd(tostring(display), "currency")
              else
                LootCombineAdd(tostring(display), "item")
              end
              combined = true
              handledByEcho = true
            else
              addMessageInHook = true
              PrintToChatFrame(FormatSelfLine(tostring(display)), outFrame)
              addMessageInHook = false
              handledByEcho = true
            end
          end
        end

        -- Capture debug: record what we did with this direct print.
        LootChat.CaptureChatOut("CHATFRAME_ADD", tostring(display or ""), {
          handled = true,
          directPrint = true,
          echo = (DB and DB.echoItem) and true or false,
          echoed = handledByEcho,
          combined = combined,
          isMoney = isMoney,
          startsMoney = startsMoney,
          startsLoot = startsLoot,
          startsCurrency = startsCurrency,
        })

        if DebugChatSetupEnabled() then
          addMessageInHook = true
          DebugPrint(string.format(
            "AddMessage: suppressed direct print (loot=%s money=%s currency=%s hasItem=%s hasCur=%s hasBracket=%s isMoney=%s echo=%s) text=%s",
            tostring(startsLoot),
            tostring(startsMoney),
            tostring(startsCurrency),
            tostring(hasItem),
            tostring(hasCurrency),
            tostring(hasBracket),
            tostring(isMoney),
            tostring((DB and DB.echoItem) and true or false),
            tostring(text)
          ))
          addMessageInHook = false
        end
        return
      end
    end

    return orig(self, text, ...)
  end
end

-- Filter audit tracking (for clients that do not expose ChatFrame_GetMessageEventFilters).
-- We hook add/remove calls and keep a best-effort view of which filters are installed.
local _filterAuditHooked = false
local _filterAudit = {
  events = {}, -- [eventName][fn] = true
  last = {}, -- ring buffer of recent add/remove operations
}

local function AuditRemember(op, eventName, fn)
  local t = _filterAudit
  if not t then return end
  t.last = t.last or {}
  local stack = nil
  if (DB and DB.debugChatSetup) or (DB and DB.debugCaptureStacks) then
    if type(debugstack) == "function" then
      stack = debugstack(3, 4, 8)
    end
  end
  t.last[#t.last + 1] = {
    t = (type(date) == "function" and date("%H:%M:%S")) or "",
    op = tostring(op or ""),
    ev = tostring(eventName or ""),
    fn = tostring(fn),
    stack = stack,
  }
  while #t.last > 12 do
    table.remove(t.last, 1)
  end
end

local function EnsureFilterAuditHooks()
  if _filterAuditHooked then return end
  if type(hooksecurefunc) ~= "function" then return end
  if type(ChatFrame_AddMessageEventFilter) ~= "function" or type(ChatFrame_RemoveMessageEventFilter) ~= "function" then return end

  _filterAuditHooked = true

  -- Some clients only support the string/table+method forms of hooksecurefunc.
  hooksecurefunc("ChatFrame_AddMessageEventFilter", function(eventName, fn)
    EnsureRefs()
    local t = _filterAudit
    t.events = t.events or {}
    t.events[eventName] = t.events[eventName] or {}
    if type(fn) == "function" then
      t.events[eventName][fn] = true
      AuditRemember("add", eventName, fn)
    end
  end)

  hooksecurefunc("ChatFrame_RemoveMessageEventFilter", function(eventName, fn)
    EnsureRefs()
    local t = _filterAudit
    if t.events and t.events[eventName] and type(fn) == "function" then
      t.events[eventName][fn] = nil
    end
    if type(fn) == "function" then
      AuditRemember("remove", eventName, fn)
    end
  end)
end

local function HookAllChatFramesAddMessage()
  -- Prefer CHAT_FRAMES if present; otherwise fall back to numbered frames.
  if type(CHAT_FRAMES) == "table" then
    for _, frameName in ipairs(CHAT_FRAMES) do
      local f = _G and rawget(_G, frameName)
      if f then
        HookChatFrameAddMessage(f)
      end
    end
  else
    local n = tonumber(NUM_CHAT_WINDOWS) or 10
    for i = 1, n do
      local f = _G and rawget(_G, "ChatFrame" .. tostring(i))
      if f then
        HookChatFrameAddMessage(f)
      end
    end
  end
end

local function GetDefaultMoneyConfig()
  local d = env and env.DEFAULTS
  if type(d) == "table" and type(d.money) == "table" then
    return d.money
  end
  return { gold = true, silver = true, copper = true }
end

local function GetAddonLinkAliases()
  local t = env and env.ADDON_LINK_ALIASES
  return (type(t) == "table") and t or {}
end

local function GetAddonCurrencyAliases()
  local t = env and env.ADDON_CURRENCY_ALIASES
  return (type(t) == "table") and t or {}
end

function LootChat.CaptureEnabled()
  EnsureRefs()
  return (DB and DB.debugCapture) == true
end

function LootChat.CaptureGetLog()
  EnsureRefs()
  if not CHARDB then return nil end
  if type(CHARDB.debugCaptureLog) ~= "table" then
    CHARDB.debugCaptureLog = {}
  end
  return CHARDB.debugCaptureLog
end

local function CaptureNowString()
  if type(date) == "function" then
    return date("%H:%M:%S")
  end
  if type(time) == "function" then
    return tostring(time())
  end
  return ""
end

local function CaptureExtractLink(msg)
  if type(msg) ~= "string" then return nil end
  return msg:match("(|c%x%x%x%x%x%x%x%x|Hitem:.-|h%[.-%]|h|r)")
    or msg:match("(|Hitem:.-|h%[.-%]|h)")
    or msg:match("(|c%x%x%x%x%x%x%x%x|Hcurrency:.-|h%[.-%]|h|r)")
    or msg:match("(|Hcurrency:.-|h%[.-%]|h)")
end

local function CaptureItemIDFromLink(link)
  if type(link) ~= "string" then return nil end
  local id = link:match("Hitem:(%d+):")
  return id and tonumber(id) or nil
end

function LootChat.CaptureAppend(kind, data)
  if not LootChat.CaptureEnabled() then return end
  local log = LootChat.CaptureGetLog()
  if not log then return end

  local entry = (type(data) == "table") and data or { msg = tostring(data or "") }
  entry.t = entry.t or CaptureNowString()
  entry.kind = tostring(kind or entry.kind or "CAP")
  log[#log + 1] = entry

  EnsureRefs()
  local maxN = tonumber(DB and DB.debugCaptureMax) or 200
  if maxN < 20 then maxN = 20 end
  if maxN > 500 then maxN = 500 end
  while #log > maxN do
    table.remove(log, 1)
  end
end

function LootChat.CaptureChatIn(eventName, msg, author)
  if not LootChat.CaptureEnabled() then return end
  local link = CaptureExtractLink(msg)
  LootChat.CaptureAppend("CHAT_IN", {
    event = tostring(eventName or ""),
    author = (type(author) == "string") and author or nil,
    msg = msg,
    hasItemLink = (type(msg) == "string" and msg:find("|Hitem:", 1, true) ~= nil) or false,
    hasCurrencyLink = (type(msg) == "string" and msg:find("|Hcurrency:", 1, true) ~= nil) or false,
    link = link,
    itemID = CaptureItemIDFromLink(link),
  })
end

function LootChat.CaptureChatOut(eventName, out, meta)
  if not LootChat.CaptureEnabled() then return end
  local entry = (type(meta) == "table") and meta or {}
  entry.event = tostring(eventName or "")
  entry.out = out
  LootChat.CaptureAppend("CHAT_OUT", entry)
end

-- Slash handler for /fli chatdebug ... (kept here for portability).
function LootChat.HandleChatDebugSlash(rest, e)
  if type(e) == "table" then
    LootChat.SetEnv(e)
  end
  EnsureRefs()

  local PrintFn = env and env.Print
  local ApplyFilters = env and env.ApplyFilters

  local parts = {}
  for w in tostring(rest or ""):gmatch("%S+") do
    parts[#parts + 1] = w
  end
  local sub = (parts[1] and parts[1]:lower()) or "status"

  local function DumpChatFrames()
    LootChat._inChatDebugDump = true
    local maxN = tonumber(_G and rawget(_G, "NUM_CHAT_WINDOWS")) or 10
    if maxN < 1 then maxN = 10 end
    if maxN > 20 then maxN = 20 end

    local v = GetLootItVersion()
    if v and v ~= "" then
      SafeCall(PrintFn, "LootIt version=" .. tostring(v))
    end

    SafeCall(PrintFn, "Chat windows (id -> name, shown):")
    for i = 1, maxN do
      local name = ""
      if type(GetChatWindowInfo) == "function" then
        local ok, n = pcall(GetChatWindowInfo, i)
        if ok and type(n) == "string" then name = n end
      end
      if name == "" then name = "?" end

      local shown = false
      local f = _G and _G["ChatFrame" .. i]
      if f and f.IsShown then
        local okS, v2 = pcall(f.IsShown, f)
        shown = okS and (v2 == true) or false
      end
      SafeCall(PrintFn, string.format("  %d: %s (shown=%s)", i, name, tostring(shown)))
    end
    SafeCall(PrintFn, string.format("LootIt outputChatFrame=%s", tostring(DB and DB.outputChatFrame)))
    SafeCall(PrintFn, string.format("LootIt other.outputChatFrame=%s", tostring(DB and DB.other and DB.other.outputChatFrame)))
    SafeCall(PrintFn, string.format(
      "LootIt other.achievement.outputChatFrame=%s",
      tostring(DB and DB.other and DB.other.achievement and DB.other.achievement.outputChatFrame)
    ))
    SafeCall(PrintFn, string.format(
      "LootIt other.experience.outputChatFrame=%s",
      tostring(DB and DB.other and DB.other.experience and DB.other.experience.outputChatFrame)
    ))

    if LootChat and LootChat.DumpFilterAudit then
      LootChat.DumpFilterAudit(PrintFn)
    end

    LootChat._inChatDebugDump = false
  end

  if sub == "on" then
    if DB then DB.debugChatSetup = true end
    SafeCall(PrintFn, "Chat debug: on")
    SafeCall(ApplyFilters)
    return
  end
  if sub == "off" then
    if DB then DB.debugChatSetup = false end
    SafeCall(PrintFn, "Chat debug: off")
    return
  end
  if sub == "toggle" then
    if DB then DB.debugChatSetup = not (DB and DB.debugChatSetup) end
    SafeCall(PrintFn, "Chat debug: " .. (((DB and DB.debugChatSetup) and "on") or "off"))
    SafeCall(ApplyFilters)
    return
  end
  if sub == "dump" then
    local ok = pcall(DumpChatFrames)
    LootChat._inChatDebugDump = false
    if not ok then
      -- best-effort
    end
    return
  end

  if sub == "filters" or sub == "audit" then
    LootChat._inChatDebugDump = true
    local ok = pcall(function()
      if LootChat and LootChat.DumpFilterAudit then
        LootChat.DumpFilterAudit(PrintFn)
      end
    end)
    LootChat._inChatDebugDump = false
    if not ok then
      -- best-effort
    end
    return
  end

  if sub == "events" then
    LootChat._inChatDebugDump = true
    local ok = pcall(function()
      if LootChat and LootChat.DumpEventStats then
        LootChat.DumpEventStats(PrintFn)
      end
    end)
    LootChat._inChatDebugDump = false
    if not ok then
      -- best-effort
    end
    return
  end

  SafeCall(PrintFn, "Chat debug: " .. (((DB and DB.debugChatSetup) and "on") or "off"))
  SafeCall(PrintFn, "Run: /fgo li chatdebug dump")
  SafeCall(PrintFn, "Also: /fgo li chatdebug filters")
  SafeCall(PrintFn, "Also: /fgo li chatdebug events")
end

-- Slash handler for /fli capture ... (kept here for portability).
function LootChat.HandleCaptureSlash(rest, e)
  if type(e) == "table" then
    LootChat.SetEnv(e)
  end
  EnsureRefs()

  local PrintFn = env and env.Print

  local parts = {}
  for w in tostring(rest or ""):gmatch("%S+") do
    parts[#parts + 1] = w
  end
  local sub = (parts[1] and parts[1]:lower()) or "status"

  if sub == "on" then
    if DB then DB.debugCapture = true end
    -- Force a first entry so users can verify capture is working immediately.
    LootChat.CaptureAppend("CAPTURE", { event = "manual_on", msg = "Capture enabled" })
    SafeCall(PrintFn, "Capture: on")
    return
  end
  if sub == "off" then
    if DB then DB.debugCapture = false end
    SafeCall(PrintFn, "Capture: off")
    return
  end
  if sub == "stacks" then
    if DB then DB.debugCaptureStacks = not (DB and DB.debugCaptureStacks) end
    SafeCall(PrintFn, "Capture stacks: " .. (((DB and DB.debugCaptureStacks) and "on") or "off"))
    return
  end
  if sub == "max" then
    local n = tonumber(parts[2])
    if not n then
      SafeCall(PrintFn, "Capture max: " .. tostring(DB and DB.debugCaptureMax or 200))
      return
    end
    if n < 20 then n = 20 end
    if n > 500 then n = 500 end
    if DB then DB.debugCaptureMax = n end
    SafeCall(PrintFn, "Capture max set: " .. n)
    return
  end
  if sub == "clear" then
    if CHARDB then
      CHARDB.debugCaptureLog = {}
    end
    SafeCall(PrintFn, "Capture: cleared")
    return
  end
  if sub == "dump" then
    if not (DB and DB.debugCapture) then
      SafeCall(PrintFn, "Capture is OFF. Run: /fgo li capture on")
    end

    do
      local v = GetLootItVersion()
      if v and v ~= "" then
        SafeCall(PrintFn, "LootIt version=" .. tostring(v))
      end
    end

    local function EscapeChatPipes(s)
      if type(s) ~= "string" or s == "" then return s end
      -- WoW chat uses '|' for escape codes; doubling shows a literal pipe.
      return (s:gsub("|", "||"))
    end

    local dumpRaw = false
    local idxN = 2
    local p2 = parts[2] and parts[2]:lower() or nil
    if p2 == "raw" or p2 == "pipes" or p2 == "escaped" then
      dumpRaw = true
      idxN = 3
    end

    local n = tonumber(parts[idxN]) or 30
    if n < 1 then n = 1 end
    if n > 200 then n = 200 end

    local idxFilter = idxN + 1
    local filter = table.concat(parts, " ", idxFilter)
    filter = (type(filter) == "string") and filter:lower() or ""

    local log = (CHARDB and type(CHARDB.debugCaptureLog) == "table") and CHARDB.debugCaptureLog or {}
    SafeCall(PrintFn, string.format("Capture dump: %d entries (showing last %d)", #log, n))
    if #log == 0 then
      SafeCall(PrintFn, "(No entries yet. Make sure you ran /fgo li capture on, then loot something or run /fgo li status.)")
    end
    local start = #log - n + 1
    if start < 1 then start = 1 end
    for i = start, #log do
      local entry = log[i]
      if type(entry) == "table" then
        local line = string.format("%s %s %s", tostring(entry.t or ""), tostring(entry.kind or ""), tostring(entry.event or ""))
        local msg2 = tostring(entry.out or entry.msg or entry.link or "")

        local hay = (msg2 ~= "" and msg2 or line)
        if filter == "" or hay:lower():find(filter, 1, true) then
          local extra = ""
          if entry.kind == "MATCH" then
            extra = string.format(" (hasItemLink=%s link=%s qty=%s)", tostring(entry.hasItemLink), tostring(entry.link or ""), tostring(entry.qty or ""))
          else
            if entry.itemID then
              extra = extra .. string.format(" (itemID=%s)", tostring(entry.itemID))
            end
            if entry.link and entry.link ~= "" and (entry.kind == "CHAT_IN" or entry.kind == "CHAT_OUT") then
              extra = extra .. string.format(" (link=%s)", tostring(entry.link))
            end
            if entry.hasItemLink ~= nil and entry.kind == "CHAT_IN" then
              extra = extra .. string.format(" (hasItemLink=%s)", tostring(entry.hasItemLink))
            end
            if entry.rewrittenMoney then
              extra = extra .. " (rewrittenMoney=true)"
            end
            if entry.rewrittenCurrency then
              extra = extra .. " (rewrittenCurrency=true)"
            end
            if entry.async then
              extra = extra .. " (async=true)"
            end
          end

          if msg2 ~= "" then
            local outLine = line .. " :: " .. msg2 .. extra
            if dumpRaw then
              outLine = EscapeChatPipes(outLine)
            end
            SafeCall(PrintFn, outLine)
          else
            local outLine = line .. extra
            if dumpRaw then
              outLine = EscapeChatPipes(outLine)
            end
            SafeCall(PrintFn, outLine)
          end
        end
      end
    end
    return
  end

  local enabled = (DB and DB.debugCapture) and "on" or "off"
  local stacks = (DB and DB.debugCaptureStacks) and "on" or "off"
  local count = (CHARDB and type(CHARDB.debugCaptureLog) == "table") and #CHARDB.debugCaptureLog or 0

  do
    local v = GetLootItVersion()
    if v and v ~= "" then
      SafeCall(PrintFn, "LootIt version=" .. tostring(v))
    end
  end

  SafeCall(PrintFn, string.format("Capture: %s (stacks=%s, max=%s, entries=%d)", enabled, stacks, tostring(DB and DB.debugCaptureMax or 200), count))
  SafeCall(PrintFn, "Usage: /fgo li capture on|off|status|dump [raw] [n] [filter]|clear|max <n>|stacks")
end

-- Loot patterns
LOOT_PATTERNS = nil
LOOT_PREFIXES = nil
LOOT_GROUP_PATTERNS = nil
RECEIVE_ITEM_PATTERNS = nil

local LOOT_PATTERN_KEYS
local LOOT_GROUP_PATTERN_KEYS

local function EscapeLuaPattern(text)
  text = tostring(text or "")
  return (text:gsub("([%(%)%.%+%-%*%?%[%]%^%$%%])", "%%%1"))
end

local function GlobalStringToPattern(globalString)
  if type(globalString) ~= "string" or globalString == "" then return nil end

  local s = globalString
  s = s:gsub("%%s", "\0S\0")
  s = s:gsub("%%d", "\0D\0")

  s = EscapeLuaPattern(s)

  s = s:gsub("\0S\0", "(.-)")
  s = s:gsub("\0D\0", "(%d+)")

  return "^" .. s .. "$"
end

LOOT_PATTERN_KEYS = {
  "LOOT_ITEM_SELF",
  "LOOT_ITEM_SELF_MULTIPLE",
  "LOOT_ITEM_PUSHED_SELF",
  "LOOT_ITEM_PUSHED_SELF_MULTIPLE",
  "LOOT_ITEM_CREATED_SELF",
  "LOOT_ITEM_CREATED_SELF_MULTIPLE",
  "YOU_RECEIVE_ITEM",
  "YOU_RECEIVE_ITEM_MULTIPLE",
  "LOOT_ITEM_BONUS_ROLL_SELF",
  "LOOT_ITEM_BONUS_ROLL_SELF_MULTIPLE",
}

LOOT_GROUP_PATTERN_KEYS = {
  "LOOT_ITEM",
  "LOOT_ITEM_MULTIPLE",
  "LOOT_ITEM_PUSHED",
  "LOOT_ITEM_PUSHED_MULTIPLE",
  "LOOT_ITEM_CREATED",
  "LOOT_ITEM_CREATED_MULTIPLE",
  "LOOT_ITEM_BONUS_ROLL",
  "LOOT_ITEM_BONUS_ROLL_MULTIPLE",
}

BuildLootPatterns = function()
  local patterns = {}
  local prefixes = {}
  local groupPatterns = {}
  local receiveItemPatterns = {}

  local keys = {
    "LOOT_ITEM_SELF",
    "LOOT_ITEM_SELF_MULTIPLE",
    "LOOT_ITEM_PUSHED_SELF",
    "LOOT_ITEM_PUSHED_SELF_MULTIPLE",
    "LOOT_ITEM_CREATED_SELF",
    "LOOT_ITEM_CREATED_SELF_MULTIPLE",
    "YOU_RECEIVE_ITEM",
    "YOU_RECEIVE_ITEM_MULTIPLE",
    "LOOT_ITEM_BONUS_ROLL_SELF",
    "LOOT_ITEM_BONUS_ROLL_SELF_MULTIPLE",
  }

  for _, k in ipairs(keys) do
    local gs = _G and rawget(_G, k)
    local pat = GlobalStringToPattern(gs)
    if pat then
      patterns[#patterns + 1] = pat

      if k == "YOU_RECEIVE_ITEM" or k == "YOU_RECEIVE_ITEM_MULTIPLE" then
        receiveItemPatterns[#receiveItemPatterns + 1] = pat
      end

      -- Some chat lines omit the trailing '.' (or localization differs). Allow optional period for all patterns.
      do
        local alt = pat:gsub("%%%.%$", "%%.?$")
        if alt ~= pat then
          patterns[#patterns + 1] = alt
          if k == "YOU_RECEIVE_ITEM" or k == "YOU_RECEIVE_ITEM_MULTIPLE" then
            receiveItemPatterns[#receiveItemPatterns + 1] = alt
          end
        end
      end
    end

    if type(gs) == "string" and gs ~= "" then
      local prefix = gs:match("^(.-)%%[sd]")
      if prefix and prefix ~= "" then
        prefixes[#prefixes + 1] = prefix
      end
    end
  end

  for _, k in ipairs(LOOT_GROUP_PATTERN_KEYS) do
    local gs = _G and rawget(_G, k)
    local pat = GlobalStringToPattern(gs)
    if pat then
      groupPatterns[#groupPatterns + 1] = pat
    end
  end

  LOOT_PATTERNS = patterns
  LOOT_PREFIXES = prefixes
  LOOT_GROUP_PATTERNS = groupPatterns
  RECEIVE_ITEM_PATTERNS = receiveItemPatterns
end

local function NormalizeForPrefixMatch(s)
  if not IsNonEmptyPublicString(s) then return "" end
  -- Some client strings use non-breaking spaces; normalize them to regular spaces.
  -- NBSP (U+00A0) in UTF-8 is \194\160, narrow NBSP (U+202F) is \226\128\175.
  s = string.gsub(s, "\194\160", " ")
  s = string.gsub(s, "\226\128\175", " ")
  s = string.gsub(s, "^%s+", "")
  s = string.gsub(s, "%s+$", "")
  -- collapse any whitespace runs (including NBSP-ish) to a single space
  s = string.gsub(s, "%s+", " ")
  return s
end

MessageStartsWithLootPrefix = function(msg)
  if not IsNonEmptyPublicString(msg) then return false end
  if not (LOOT_PREFIXES and #LOOT_PREFIXES > 0) then return false end
  local tmsg = NormalizeForPrefixMatch(msg)
  for _, prefix in ipairs(LOOT_PREFIXES) do
    if type(prefix) == "string" and string.len(prefix) > 0 then
      local tp = NormalizeForPrefixMatch(prefix)
      if string.len(tp) > 0 and string.find(tmsg, tp, 1, true) == 1 then
        return true
      end
    end
  end
  return false
end

local function StripRealmFromName(name)
  if type(name) ~= "string" then return name end
  return string.match(name, "^([^%-]+)") or name
end

local function IsItemLink(text)
  return type(text) == "string" and string.find(text, "|Hitem:", 1, true) ~= nil
end

local function ColorizeByClass(classFile, text)
  if type(text) ~= "string" then
    text = tostring(text or "")
  end
  if not classFile or classFile == "" then
    return text
  end

  if C_ClassColor and C_ClassColor.GetClassColor then
    local color = C_ClassColor.GetClassColor(classFile)
    if color and color.WrapTextInColorCode then
      return color:WrapTextInColorCode(text)
    end
  end

  local rc = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
  if rc and rc.colorStr then
    return "|c" .. rc.colorStr .. text .. "|r"
  end

  return text
end

local function GetGroupUnitForShortName(shortName)
  if type(shortName) ~= "string" or shortName == "" then return nil end

  if IsInRaid and IsInRaid() then
    local count = (GetNumGroupMembers and GetNumGroupMembers()) or 0
    for i = 1, count do
      local unit = "raid" .. i
      local unitName = UnitName and UnitName(unit)
      unitName = StripRealmFromName(unitName)
      if unitName == shortName then
        return unit
      end
    end
  elseif IsInGroup and IsInGroup() then
    local count = (GetNumSubgroupMembers and GetNumSubgroupMembers()) or 0
    for i = 1, count do
      local unit = "party" .. i
      local unitName = UnitName and UnitName(unit)
      unitName = StripRealmFromName(unitName)
      if unitName == shortName then
        return unit
      end
    end
  end

  return nil
end

local function GetClassColoredName(fullOrShortName)
  local shortName = StripRealmFromName(fullOrShortName)
  if not shortName or shortName == "" then
    return ""
  end

  local myName = StripRealmFromName((UnitName and UnitName("player")) or "")
  if myName ~= "" and shortName == myName then
    local classFile
    if UnitClass then
      _, classFile = UnitClass("player")
    end
    return ColorizeByClass(classFile, shortName)
  end

  local unit = GetGroupUnitForShortName(shortName)
  if unit then
    local classFile
    if UnitClass then
      _, classFile = UnitClass(unit)
    end
    return ColorizeByClass(classFile, shortName)
  end

  return shortName
end

local function IsInAnyGroup()
  if IsInRaid and IsInRaid() then
    local n = (GetNumGroupMembers and GetNumGroupMembers()) or 0
    return (tonumber(n) or 0) > 1
  end
  if IsInGroup and IsInGroup() then
    local sub = (GetNumSubgroupMembers and GetNumSubgroupMembers())
    if (tonumber(sub) or 0) > 0 then
      return true
    end
    local n = (GetNumGroupMembers and GetNumGroupMembers()) or 0
    return (tonumber(n) or 0) > 1
  end
  return false
end

local function ExtractLinkFallback(msg)
  if type(msg) ~= "string" then return nil end
  return string.match(msg, "(|c%x+|Hitem:.-|h%[.-%]|h|r)")
    or string.match(msg, "(|c%x+|Hitem:.-|h.-|h|r)")
    or string.match(msg, "(|Hitem:.-|h%[.-%]|h)")
    or string.match(msg, "(|Hitem:.-|h.-|h)")
end

local function ExtractItemLinkRobust(msg)
  if not IsNonEmptyPublicString(msg) then return nil end
  -- Try to match the most common (and some uncommon) hyperlink forms.
  return string.match(msg, "(|c%x%x%x%x%x%x%x%x|Hitem:%d+.-|h.-|h|r)")
    or string.match(msg, "(|c%x%x%x%x%x%x%x%x|Hitem:%d+.-|h.-|h)")
    or string.match(msg, "(|Hitem:%d+.-|h.-|h|r)")
    or string.match(msg, "(|Hitem:%d+.-|h.-|h)")
    or ExtractLinkFallback(msg)
end

local function NormalizeItemLink(link)
  if type(link) ~= "string" or string.len(link) == 0 then return link end

  -- Retail can prepend an item-quality marker like "|cnIQ1:" right before the hyperlink.
  -- That prefix is not part of the actual |Hitem:... link and can break normalization.
  link = link:gsub("^|cnIQ%d+:", "")

  if string.match(link, "^|c%x%x%x%x%x%x%x%x|Hitem:") then
    return link
  end

  do
    local name = link
    local bracketName = string.match(link, "^%[([^%]]+)%]$")
    if bracketName and string.len(bracketName) > 0 then
      name = bracketName
    end

    if name and not string.match(name, "|Hitem:") then
      if C_Item and C_Item.GetItemInfo then
        local _, itemLink = C_Item.GetItemInfo(name)
        if type(itemLink) == "string" and string.len(itemLink) > 0 then
          return itemLink
        end
      end
    end
  end

  if string.match(link, "|Hitem:") then
    if C_Item and C_Item.GetItemInfo then
      local _, itemLink = C_Item.GetItemInfo(link)
      if type(itemLink) == "string" and string.len(itemLink) > 0 then
        return itemLink
      end
    end
  end

  return link
end

local function StripDisplayedLinkBrackets(link)
  if type(link) ~= "string" or string.len(link) == 0 then return link end

  EnsureRefs()
  local qualityEnabled = true
  local qualityPos = "before"
  if DB then
    qualityEnabled = (DB.lootQualityIconEnabled ~= false)
    qualityPos = tostring(DB.lootQualityIconPosition or "before")
    qualityPos = qualityPos:lower():gsub("%s+", "")
    if qualityPos ~= "before" and qualityPos ~= "after" then
      qualityPos = "before"
    end
  end

  -- Some gathered items embed a profession-quality (rank) icon in the item name/link text.
  -- If that icon is taller than the chat font, WoW increases the line height and leaves extra top gap.
  -- Also, the icon placement affects where the "xN" quantity suffix ends up.
  --
  -- Implementation: extract ANY matching quality icon markup (atlas or texture) found in the link,
  -- normalize it to a small fixed size, and re-insert it before/after based on DB.
  local ICON_W, ICON_H, ICON_Y = 10, 10, -1

  local function IsQualityToken(s)
    if type(s) ~= "string" or s == "" then return false end
    local t = s:lower()
    -- Be tolerant: Blizzard has used multiple naming variants across expansions/patches.
    -- In the loot line context, any atlas/texture token mentioning quality/tier/rank is almost
    -- certainly the profession-quality indicator.
    if t:find("quality", 1, true) then
      return true
    end
    if t:find("tier", 1, true) or t:find("rank", 1, true) then
      if t:find("profession", 1, true) or t:find("professions", 1, true) or t:find("craft", 1, true) or t:find("chat", 1, true) then
        return true
      end
    end
    return false
  end

  local function ExtractQualityIcons(text)
    if type(text) ~= "string" or text == "" then
      return {}, text
    end

    local icons = {}

    local function PullAtlas(full, atlas)
      if IsQualityToken(atlas) then
        icons[#icons + 1] = string.format("|A:%s:%d:%d:0:%d|a", atlas, ICON_W, ICON_H, ICON_Y)
        return ""
      end
      return full
    end

    local function PullTexture(full, path)
      if IsQualityToken(path) then
        icons[#icons + 1] = string.format("|T%s:%d:%d:0:%d|t", path, ICON_W, ICON_H, ICON_Y)
        return ""
      end
      return full
    end

    -- Atlas tags can have multiple parameter forms; match anything up to the terminator.
    text = text:gsub("(|A:([^:|]+)[^|]-|a)", PullAtlas)
    text = text:gsub("(|T([^:|]+)[^|]-|t)", PullTexture)

    text = text:gsub("%s+", " ")
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    return icons, text
  end

  local out = string.gsub(link, "|h%[([^%]]+)%]|h", "|h%1|h")
  local icons, cleaned = ExtractQualityIcons(out)

  if (not qualityEnabled) or (not icons) or (#icons == 0) then
    return cleaned
  end

  local iconText = table.concat(icons, "")
  if qualityPos == "after" then
    return cleaned .. " " .. iconText
  end
  return iconText .. " " .. cleaned
end

local function GetItemIDFromLink(link)
  if type(link) ~= "string" or string.len(link) == 0 then return nil end
  local id = string.match(link, "|Hitem:(%d+)")
  if not id then return nil end
  return tonumber(id)
end

local function GetCurrencyIDFromLink(link)
  if type(link) ~= "string" or string.len(link) == 0 then return nil end
  local id = string.match(link, "|Hcurrency:(%d+)")
  if not id then return nil end
  return tonumber(id)
end

local function ApplyItemLinkAlias(link)
  EnsureRefs()
  if type(link) ~= "string" or string.len(link) == 0 then return link end
  local id = GetItemIDFromLink(link)
  if not id then return link end

  local alias

  local charDisabled = (CHARDB and type(CHARDB.linkAliasDisabledChar) == "table" and CHARDB.linkAliasDisabledChar[id] == true)
  local acctDisabled = (DB and type(DB.linkAliasDisabledAccount) == "table" and DB.linkAliasDisabledAccount[id] == true)
  local addonDisabled = (DB and type(DB.linkAliasDisabledAddon) == "table" and DB.linkAliasDisabledAddon[id] == true)

  if charDisabled then
    return link
  end

  if (not charDisabled) and CHARDB and type(CHARDB.linkAliases) == "table" then
    alias = CHARDB.linkAliases[id]
  end
  if (type(alias) ~= "string" or alias == "") and (not acctDisabled) and DB and type(DB.linkAliases) == "table" then
    alias = DB.linkAliases[id]
  end
  if (type(alias) ~= "string" or alias == "") and (not addonDisabled) then
    alias = GetAddonLinkAliases()[id]
  end
  if type(alias) ~= "string" or alias == "" then
    return link
  end

  local out = link
  out = out:gsub("(|Hitem:[^|]+|h)%[([^%]]+)%](|h)", "%1" .. alias .. "%3", 1)
  out = out:gsub("(|Hitem:[^|]+|h)([^|]+)(|h)", "%1" .. alias .. "%3", 1)
  return out
end

local function ApplyCurrencyLinkAlias(link)
  EnsureRefs()
  if type(link) ~= "string" or link == "" then return link end
  local id = GetCurrencyIDFromLink(link)
  if not id then return link end

  local alias

  local charDisabled = (CHARDB and type(CHARDB.currencyAliasDisabledChar) == "table" and CHARDB.currencyAliasDisabledChar[id] == true)
  local acctDisabled = (DB and type(DB.currencyAliasDisabledAccount) == "table" and DB.currencyAliasDisabledAccount[id] == true)
  local addonDisabled = (DB and type(DB.currencyAliasDisabledAddon) == "table" and DB.currencyAliasDisabledAddon[id] == true)

  if charDisabled then
    return link
  end

  if (not charDisabled) and CHARDB and type(CHARDB.currencyAliases) == "table" then
    alias = CHARDB.currencyAliases[id]
  end
  if (type(alias) ~= "string" or alias == "") and (not acctDisabled) and DB and type(DB.currencyAliases) == "table" then
    alias = DB.currencyAliases[id]
  end
  if (type(alias) ~= "string" or alias == "") and (not addonDisabled) then
    alias = GetAddonCurrencyAliases()[id]
  end
  if type(alias) ~= "string" or alias == "" then
    return link
  end

  local out = link
  out = out:gsub("(|Hcurrency:[^|]+|h)%[([^%]]+)%](|h)", "%1" .. alias .. "%3", 1)
  out = out:gsub("(|Hcurrency:[^|]+|h)([^|]+)(|h)", "%1" .. alias .. "%3", 1)
  return out
end

local function GetEquippableItemLevelSuffix(link)
  if type(link) ~= "string" or link == "" then return nil end

  local isEquippable
  if C_Item and C_Item.IsEquippableItem then
    isEquippable = C_Item.IsEquippableItem(link)
  end
  if not isEquippable then
    return nil
  end

  local equipLoc
  if C_Item and C_Item.GetItemInfoInstant then
    local _, _, _, e = C_Item.GetItemInfoInstant(link)
    equipLoc = e
  end
  if not equipLoc or equipLoc == "" then
    return nil
  end

  if _G and CreateFrame and UIParent then
    if not (_G and rawget(_G, "fr0z3nUI_LootItScanTooltip")) then
      local tt = CreateFrame("GameTooltip", "fr0z3nUI_LootItScanTooltip", UIParent, "GameTooltipTemplate")
      tt:SetOwner(UIParent, "ANCHOR_NONE")
      tt:Hide()
    end

    local tt = _G and rawget(_G, "fr0z3nUI_LootItScanTooltip")
    if tt and tt.SetOwner and tt.SetHyperlink and tt.NumLines then
      tt:ClearLines()
      tt:SetOwner(UIParent, "ANCHOR_NONE")
      tt:SetHyperlink(link)

      local pat = GlobalStringToPattern((_G and rawget(_G, "ITEM_LEVEL")) or "")
      local nLines = tt:NumLines() or 0
      for i = 2, nLines do
        local fs = _G["fr0z3nUI_LootItScanTooltipTextLeft" .. i]
        local text = fs and fs.GetText and fs:GetText()
        if type(text) == "string" and text ~= "" then
          local lvl
          if pat then
            lvl = tonumber((text:match(pat)))
          end
          if not lvl then
            lvl = tonumber(text:match("(%d+)$"))
          end
          if lvl and lvl > 0 then
            tt:Hide()
            return lvl
          end
        end
      end
      tt:Hide()
    end
  end

  return nil
end

local function ExtractCurrencyLinkFallback(msg)
  if type(msg) ~= "string" then return nil end
  return string.match(msg, "(|c%x+|Hcurrency:.-|h%[.-%]|h|r)")
    or string.match(msg, "(|Hcurrency:.-|h%[.-%]|h)")
end

local function ExtractAchievementLinkFallback(msg)
  if type(msg) ~= "string" then return nil end
  return string.match(msg, "(|c%x+|Hachievement:.-|h%[.-%]|h|r)")
    or string.match(msg, "(|Hachievement:.-|h%[.-%]|h)")
end

local function AppendSuffixInsideColorReset(text, suffix)
  if type(text) ~= "string" then
    text = tostring(text or "")
  end
  suffix = tostring(suffix or "")
  if suffix == "" then
    return text
  end
  if text:sub(-2) == "|r" then
    return text:sub(1, -3) .. suffix .. "|r"
  end
  return text .. suffix
end

FormatSelfLine = function(text)
  EnsureRefs()
  if IsInAnyGroup() or (DB and DB.showSelfNameAlways) then
    local me = GetClassColoredName(UnitName and UnitName("player"))
    if me and me ~= "" then
      return string.format("%s %s", AppendSuffixInsideColorReset(me, ":"), text)
    end
  end
  return text
end

-- Loot combine
local LOOT_COMBINE_DELAY = 0.75
local LOOT_COMBINE_POSTCLOSE_DELAY = 0.75
local LOOT_COMBINE_MONEY_GRACE_DELAY = 1.25
local lootCombineParts
local lootCombineGen = 0
local lootCombineLootOpen = false
local lootCombineHasItem = false
local lootCombineHasMoney = false
local lootCombineHasCurrency = false

function LootChat.LootCombineEnabled()
  EnsureRefs()
  local n = DB and tonumber(DB.lootCombineCount) or 1
  return (n and n > 1)
end

local function LootCombineMode()
  EnsureRefs()
  local mode = DB and tostring(DB.lootCombineMode or "loot") or "loot"
  mode = mode:lower():gsub("%s+", "")
  if mode == "timer" then mode = "per" end
  if mode ~= "loot" and mode ~= "per" then mode = "loot" end
  return mode
end

function LootChat.LootCombineFlush()
  EnsureRefs()
  -- If LootIt is disabled while a combine timer/window is pending, we must not
  -- print a delayed combined line after the user has switched Off.
  if not IsEnabled() then
    if lootCombineParts and #lootCombineParts > 0 then
      for i = #lootCombineParts, 1, -1 do
        lootCombineParts[i] = nil
      end
    end
    return
  end
  if not lootCombineParts or #lootCombineParts == 0 then return end

  local maxN = tonumber(DB and DB.lootCombineCount) or 1
  if not maxN or maxN < 2 then
    maxN = 25
  end
  if maxN > 25 then maxN = 25 end

  local sep = "|cff15AB0D,|r "
  local i = 1
  local n = #lootCombineParts
  while i <= n do
    local last = i + maxN - 1
    if last > n then last = n end
    local lineParts = {}
    for j = i, last do
      lineParts[#lineParts + 1] = lootCombineParts[j]
    end
    Print(FormatSelfLine(table.concat(lineParts, sep)))
    i = last + 1
  end

  for k = #lootCombineParts, 1, -1 do
    lootCombineParts[k] = nil
  end
  lootCombineHasItem = false
  lootCombineHasMoney = false
  lootCombineHasCurrency = false
end

function LootChat.LootCombineCancelTimers()
  lootCombineGen = (lootCombineGen or 0) + 1
end

function LootChat.LootCombineWindowStart()
  if not LootChat.LootCombineEnabled() then return end
  if LootCombineMode() ~= "loot" then return end
  lootCombineLootOpen = true
  LootChat.LootCombineCancelTimers()
end

function LootChat.LootCombineWindowEnd()
  if not lootCombineLootOpen then return end
  lootCombineLootOpen = false
  if LootCombineMode() == "per" then
    -- Print Per mode buffers across loot windows until the configured count is met.
    return
  end
  -- Important: many clients fire the money line slightly after LOOT_CLOSED.
  -- If we flush too soon, money can't be inlined into the same combined output.
  -- Hold the buffer for a short grace period after close.
  LootChat.LootCombineCancelTimers()
  local gen = lootCombineGen
  if C_Timer and C_Timer.After then
    C_Timer.After(LOOT_COMBINE_POSTCLOSE_DELAY, function()
      if gen ~= lootCombineGen then return end

      -- If money is arriving late, give it one more grace window.
      -- This avoids printing the item line too early and then printing money on its own.
      if LootChat.LootCombineEnabled() and (DB and DB.lootCombineIncludeGold) and lootCombineHasItem and (not lootCombineHasMoney) then
        DebugPrint(string.format(
          "Combine: post-close waiting for money (items=%s money=%s cur=%s delay=+%.2fs)",
          tostring(lootCombineHasItem),
          tostring(lootCombineHasMoney),
          tostring(lootCombineHasCurrency),
          LOOT_COMBINE_MONEY_GRACE_DELAY
        ))

        local gen2 = lootCombineGen
        C_Timer.After(LOOT_COMBINE_MONEY_GRACE_DELAY, function()
          if gen2 ~= lootCombineGen then return end
          LootChat.LootCombineFlush()
        end)
        return
      end

      LootChat.LootCombineFlush()
    end)
  else
    LootChat.LootCombineFlush()
  end
end

local function LootCombineAdd(part, kind)
  if not LootChat.LootCombineEnabled() then
    Print(FormatSelfLine(part))
    return
  end

  EnsureRefs()
  local maxN = tonumber(DB and DB.lootCombineCount) or 1
  if maxN < 2 then
    Print(FormatSelfLine(part))
    return
  end
  if maxN > 25 then maxN = 25 end

  if not lootCombineParts then lootCombineParts = {} end
  lootCombineParts[#lootCombineParts + 1] = part

  if kind == "money" then
    lootCombineHasMoney = true
  elseif kind == "currency" then
    lootCombineHasCurrency = true
  else
    lootCombineHasItem = true
  end

  local mode = LootCombineMode()
  if mode == "per" then
    if #lootCombineParts >= maxN then
      LootChat.LootCombineFlush()
    end
    return
  end
  if #lootCombineParts >= maxN then
    -- Timer mode: don't flush immediately on count; the timer is the grouping mechanism.
    -- Loot Window mode: don't flush mid-window; money often arrives after the item lines.
    if not (mode == "timer" or (mode == "loot" and lootCombineLootOpen)) then
      LootChat.LootCombineFlush()
      return
    end
  end

  if mode == "timer" then
    LootChat.LootCombineCancelTimers()
    local gen = lootCombineGen
    if C_Timer and C_Timer.After then
      C_Timer.After(LOOT_COMBINE_DELAY, function()
        if gen ~= lootCombineGen then return end
        LootChat.LootCombineFlush()
      end)
    end
  else
    if not lootCombineLootOpen then
      LootChat.LootCombineCancelTimers()
      local gen = lootCombineGen
      if C_Timer and C_Timer.After then
        C_Timer.After(LOOT_COMBINE_POSTCLOSE_DELAY, function()
          if gen ~= lootCombineGen then return end
          LootChat.LootCombineFlush()
        end)
      end
    end
  end
end

-- Delay-print aggregation
local delayPrintBuckets

local function GetDelayPrintSecondsForItemID(itemID)
  EnsureRefs()
  if not (DB and DB.delayPrint and DB.delayPrint.enabled) then return nil end
  if not (itemID and itemID > 0) then return nil end
  local t = DB.delayPrint.itemSeconds
  if type(t) ~= "table" then return nil end
  local sec = tonumber(t[itemID])
  if not sec or sec <= 0 then return nil end
  if sec > 3600 then sec = 3600 end
  return sec
end

local function FormatLootItemPartFromLink(link, totalQty)
  if type(link) ~= "string" or link == "" then return nil end
  link = NormalizeItemLink(link)
  link = ApplyItemLinkAlias(link)

  local displayLink = StripDisplayedLinkBrackets(link)
  local out = displayLink
  local n = tonumber(totalQty)
  if n and n > 1 then
    out = string.format("%s x%d", displayLink, n)
  end

  if IsItemLevelEnabled() then
    local ilvl = GetEquippableItemLevelSuffix(link)
    if ilvl then
      local color = link:match("^(|c%x%x%x%x%x%x%x%x)")
      local ilvlText = color and (color .. tostring(ilvl) .. "|r") or tostring(ilvl)
      out = out .. " " .. ilvlText
    end
  end

  return out
end

local function DelayPrintFlushBucket(secKey)
  EnsureRefs()
  if not delayPrintBuckets then return 0 end
  local b = delayPrintBuckets[secKey]
  if not (b and b.order and b.items) then return 0 end
  if #b.order == 0 then return 0 end

  local parts = {}
  for i = 1, #b.order do
    local id = b.order[i]
    local it = b.items[id]
    if it and it.link and it.qty and it.qty > 0 then
      local part = FormatLootItemPartFromLink(it.link, it.qty)
      if part then
        parts[#parts + 1] = part
      end
    end
  end

  b.items = {}
  b.order = {}
  b.gen = (b.gen or 0) + 1

  if #parts > 0 then
    local msg = table.concat(parts, "|cff15AB0D,|r ")
    Print(FormatSelfLine(msg))
    return 1
  end

  return 0
end

function LootChat.DelayPrintFlushAll()
  EnsureRefs()
  if not delayPrintBuckets then return 0 end
  local lines = 0
  for secKey in pairs(delayPrintBuckets) do
    lines = lines + (DelayPrintFlushBucket(secKey) or 0)
  end

  return lines
end

local function DelayPrintAddItem(itemID, link, qty, sec)
  EnsureRefs()
  if not (sec and sec > 0) then return false end
  if not (C_Timer and C_Timer.After) then
    local part = FormatLootItemPartFromLink(link, qty)
    if part then
      Print(FormatSelfLine(part))
      return true
    end
    return false
  end

  local secKey = tostring(sec)
  if not delayPrintBuckets then delayPrintBuckets = {} end
  if not delayPrintBuckets[secKey] then
    delayPrintBuckets[secKey] = { items = {}, order = {}, gen = 0 }
  end
  local b = delayPrintBuckets[secKey]
  b.gen = (b.gen or 0) + 1
  local myGen = b.gen

  local n = tonumber(qty) or 1
  if n < 1 then n = 1 end

  local it = b.items[itemID]
  if not it then
    it = { link = link, qty = 0 }
    b.items[itemID] = it
    b.order[#b.order + 1] = itemID
  else
    it.link = link or it.link
  end
  it.qty = (tonumber(it.qty) or 0) + n

  C_Timer.After(sec, function()
    EnsureRefs()
    if not delayPrintBuckets then return end
    local cur = delayPrintBuckets[secKey]
    if not cur then return end
    if cur.gen ~= myGen then return end
    DelayPrintFlushBucket(secKey)
  end)

  return true
end

local function FormatOtherLine(name, text)
  local colored = GetClassColoredName(name or "")
  if colored and colored ~= "" then
    return string.format("%s %s", AppendSuffixInsideColorReset(colored, ":"), text)
  end
  return text
end

local function FormatOtherInline(name, text)
  local colored = GetClassColoredName(name or "")
  if colored and colored ~= "" then
    return string.format("%s %s", colored, text)
  end
  if type(name) == "string" and name ~= "" then
    return string.format("%s %s", name, text)
  end
  return text
end

-- Currency patterns
local CURRENCY_PATTERNS
local CURRENCY_PREFIXES

local CURRENCY_PATTERN_KEYS = {
  "CURRENCY_GAINED",
  "CURRENCY_GAINED_MULTIPLE",
  "CURRENCY_GAINED_SELF",
  "CURRENCY_GAINED_SELF_MULTIPLE",
}

local function BuildCurrencyPatterns()
  local patterns = {}
  local prefixes = {}

  for _, k in ipairs(CURRENCY_PATTERN_KEYS) do
    local gs = _G and rawget(_G, k)
    local pat = GlobalStringToPattern(gs)
    if pat then
      patterns[#patterns + 1] = pat
    end
    if type(gs) == "string" and gs ~= "" then
      local prefix = gs:match("^(.-)%%[sd]")
      if prefix and prefix ~= "" then
        prefixes[#prefixes + 1] = prefix
      end
    end
  end

  CURRENCY_PATTERNS = patterns
  CURRENCY_PREFIXES = prefixes
end

local function OnCurrencyChat(_, _, msg, ...)
  EnsureRefs()
  DebugBumpEvent("CHAT_MSG_CURRENCY")
  if not IsEnabled() then return false end
  if type(msg) == "string" and IsSecretString(msg) then
    DebugBumpSecret("CHAT_MSG_CURRENCY")
    if LootChat.CaptureEnabled() then
      LootChat.CaptureAppend("CHAT_SECRET", { event = "CHAT_MSG_CURRENCY" })
    end
    return false
  end
  if not IsNonEmptyPublicString(msg) then return false end

  LootChat.CaptureChatIn("CHAT_MSG_CURRENCY", msg)

  if not CURRENCY_PATTERNS then BuildCurrencyPatterns() end

  local link, qty
  for _, pat in ipairs(CURRENCY_PATTERNS or {}) do
    local a, b = string.match(msg, pat)
    if a then
      if b then
        local aIsLink = type(a) == "string" and string.find(a, "|Hcurrency:", 1, true) ~= nil
        local bIsLink = type(b) == "string" and string.find(b, "|Hcurrency:", 1, true) ~= nil

        if aIsLink and not bIsLink then
          link, qty = a, b
        elseif bIsLink and not aIsLink then
          link, qty = b, a
        else
          -- Neither capture looks like a currency hyperlink.
          -- Prefer any real link embedded in the message; otherwise treat the non-numeric capture as the currency name.
          local aNum = tonumber(a)
          local bNum = tonumber(b)
          if aNum and not bNum then
            qty = a
            link = ExtractCurrencyLinkFallback(msg) or b
          elseif bNum and not aNum then
            qty = b
            link = ExtractCurrencyLinkFallback(msg) or a
          else
            link = ExtractCurrencyLinkFallback(msg) or a
            qty = qty or b
          end
        end
      else
        link = a
      end
      break
    end
  end

  if not link then
    link = ExtractCurrencyLinkFallback(msg)
  end
  if not link then
    return false
  end

  -- Guard: never allow a bare number to become the "link" (this produces outputs like "16").
  if type(link) == "string" and tonumber(link) ~= nil and string.find(link, "|Hcurrency:", 1, true) == nil then
    qty = qty or link
    link = ExtractCurrencyLinkFallback(msg) or msg:match("%b[]")
    if not link then
      -- Nothing useful to show; still allow suppression via hideLootText.
      return (DB and DB.hideLootText) and true or false
    end
  end

  if not qty then
    local escaped = EscapeLuaPattern(link)
    qty = string.match(msg, escaped .. "%s*[x×]%s*(%d+)")
      or string.match(msg, escaped .. "[\r\n ]*[x×]%s*(%d+)")
      or string.match(msg, "%s*[x×]%s*(%d+)%s*%.?$")
  end

  local n = tonumber(qty)
  local currencyID = GetCurrencyIDFromLink(link)
  if currencyID and C_CurrencyInfo and C_CurrencyInfo.GetCurrencyLink then
    local built = C_CurrencyInfo.GetCurrencyLink(currencyID, (n and n > 0) and n or 0)
    if type(built) == "string" and string.len(built) > 0 then
      link = built
    end
  end

  local handled = false
  if DB and DB.echoItem then
    if currencyID and IsDuplicateRecentCurrencyPrint(currencyID, n, 0.35) then
      LootChat.CaptureChatOut("CHAT_MSG_CURRENCY", "(currency) deduped", {
        handled = (DB and DB.hideLootText) and true or false,
        dedupedCurrency = true,
        qty = n,
        currencyID = currencyID,
      })
      return (DB and DB.hideLootText) and true or false
    end

    local out = ApplyCurrencyLinkAlias(link)
    out = StripDisplayedLinkBrackets(out)
    if n and n > 1 then
      out = string.format("%s x%d", out, n)
    end
    if LootChat.LootCombineEnabled() then
      if DB and DB.lootCombineIncludeCurrency then
        LootCombineAdd(out, "currency")
        handled = true
      end
    else
      Print(FormatSelfLine(out))
      handled = true
    end

    if handled and currencyID then
      RememberRecentCurrencyPrint(currencyID, n)
    end

    LootChat.CaptureChatOut("CHAT_MSG_CURRENCY", out, {
      handled = handled,
      combine = LootChat.LootCombineEnabled() and true or false,
      includeCurrency = (DB and DB.lootCombineIncludeCurrency) and true or false,
      qty = n,
      currencyID = currencyID,
    })
  end

  -- Suppression policy:
  -- - Always suppress when Hide Loot Text is enabled.
  -- - When combine is active and we handled the message (combined/echoed), suppress the default line so
  --   the user actually sees a single combined output instead of separate Blizzard lines.
  if handled and LootChat.LootCombineEnabled() then
    return true
  end
  return (DB and DB.hideLootText) and true or false
end

-- Money patterns
local MONEY_PATTERNS
local MONEY_PREFIXES

local MONEY_PATTERN_KEYS = {
  "LOOT_MONEY",
  "LOOT_MONEY_SPLIT",
}

local function BuildMoneyPatterns()
  local patterns = {}
  local prefixes = {}

  for _, k in ipairs(MONEY_PATTERN_KEYS) do
    local gs = _G and rawget(_G, k)
    local pat = GlobalStringToPattern(gs)
    if pat then
      patterns[#patterns + 1] = pat
    end
    if type(gs) == "string" and gs ~= "" then
      local prefix = gs:match("^(.-)%%[sd]")
      if prefix and prefix ~= "" then
        prefixes[#prefixes + 1] = prefix
      end
    end
  end

  MONEY_PATTERNS = patterns
  MONEY_PREFIXES = prefixes
end

ParseCoinsFromMoneyMessage = function(msg)
  if not IsNonEmptyPublicString(msg) then return nil end

  local function numBeforeTexture(textureNeedle)
    local s = string.match(msg, "([%d,]+)%s*|T.-" .. textureNeedle .. ".-|t")
    if not s then return nil end
    s = string.gsub(s, ",", "")
    return tonumber(s)
  end

  local gold = numBeforeTexture("UI%-GoldIcon")
  local silver = numBeforeTexture("UI%-SilverIcon")
  local copper = numBeforeTexture("UI%-CopperIcon")

  if not (gold or silver or copper) then
    local lower = string.lower(msg)

    local function numBeforeToken(token)
      if type(token) ~= "string" or token == "" then return nil end
      local pat = EscapeLuaPattern(string.lower(token))
      local n, tokenEndPos = string.match(lower, "([%d,]+)%s*" .. pat .. "()%f[%W]")
      if not n then return nil end

      -- Reject false positives like "n=1, gold=on": the numeric capture ends with a comma
      -- and the token is used in an assignment expression.
      if string.match(n, ",$") then return nil end
      if tokenEndPos and string.match(lower:sub(tokenEndPos), "^%s*=") then return nil end

      n = string.gsub(n, ",", "")
      return tonumber(n)
    end

    gold = numBeforeToken((_G and rawget(_G, "GOLD")) or "gold")
      or numBeforeToken((_G and rawget(_G, "GOLD_AMOUNT_SYMBOL")) or "g")
    silver = numBeforeToken((_G and rawget(_G, "SILVER")) or "silver")
      or numBeforeToken((_G and rawget(_G, "SILVER_AMOUNT_SYMBOL")) or "s")
    copper = numBeforeToken((_G and rawget(_G, "COPPER")) or "copper")
      or numBeforeToken((_G and rawget(_G, "COPPER_AMOUNT_SYMBOL")) or "c")
  end

  -- Some chat paths (or other addons) can print money without textures/tokens,
  -- leaving only a numeric triple (gold/silver/copper) after a prefix.
  -- Example: "You gained: 7,536 63 26"
  if not (gold or silver or copper) then
    local cleaned = msg
    cleaned = cleaned:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    cleaned = cleaned:gsub("|T.-|t", "")
    cleaned = cleaned:gsub("\194\160", " ")
    cleaned = cleaned:gsub("\226\128\175", " ")
    cleaned = cleaned:gsub("\226\128\135", " ")
    cleaned = cleaned:gsub("%s+", " ")
    cleaned = cleaned:gsub("^%s+", ""):gsub("%s+$", "")

    local lower = string.lower(cleaned)
    local g, s, c = string.match(lower, "^you gained:%s*([%d,]+)%s+([%d,]+)%s+([%d,]+)%s*[%.!]*%s*$")
    if g and s and c then
      if type(g) == "string" then g = tonumber((g:gsub(",", ""))) end
      if type(s) == "string" then s = tonumber((s:gsub(",", ""))) end
      if type(c) == "string" then c = tonumber((c:gsub(",", ""))) end
      if g or s or c then
        gold = g
        silver = s
        copper = c
      end
    else
      local g2, s2 = string.match(lower, "^you gained:%s*([%d,]+)%s+([%d,]+)%s*[%.!]*%s*$")
      if g2 and s2 then
        if type(g2) == "string" then g2 = tonumber((g2:gsub(",", ""))) end
        if type(s2) == "string" then s2 = tonumber((s2:gsub(",", ""))) end
        if g2 or s2 then
          gold = g2
          silver = s2
          copper = 0
        end
      else
        local g3 = string.match(lower, "^you gained:%s*([%d,]+)%s*[%.!]*%s*$")
        if g3 then
          if type(g3) == "string" then g3 = tonumber((g3:gsub(",", ""))) end
          if g3 then
            gold = g3
            silver = 0
            copper = 0
          end
        end
      end
    end
  end

  return {
    gold = gold or 0,
    silver = silver or 0,
    copper = copper or 0,
  }
end

FormatMoney = function(coins)
  if type(coins) ~= "table" then return nil end
  EnsureRefs()
  local m = (DB and type(DB.money) == "table") and DB.money or GetDefaultMoneyConfig()

  local parts = {}
  if m.gold and (tonumber(coins.gold) or 0) > 0 then
    parts[#parts + 1] = tostring(coins.gold) .. "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t"
  end
  if m.silver and (tonumber(coins.silver) or 0) > 0 then
    parts[#parts + 1] = tostring(coins.silver) .. "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t"
  end
  if m.copper and (tonumber(coins.copper) or 0) > 0 then
    parts[#parts + 1] = tostring(coins.copper) .. "|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t"
  end

  if #parts == 0 then
    return nil
  end

  return table.concat(parts, " ")
end

local function TryFormatMoneyFromMessage(msg)
  if not IsNonEmptyPublicString(msg) then return nil, nil end
  local coins = ParseCoinsFromMoneyMessage(msg)
  if not coins then return nil, nil end
  local out = FormatMoney(coins)
  if not out then return nil, coins end
  return out, coins
end

IsLikelyMoneyMessage = function(msg)
  if not IsNonEmptyPublicString(msg) then return false end

  -- Strip color codes but keep textures for some checks.
  local noclr = msg:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")

  -- Texture-based money lines should only be treated as money when the line STARTS with
  -- an amount + coin texture. (Prevents addon prints that happen to include coin textures
  -- later in the line from being misclassified and rewritten.)
  if string.match(noclr, "^%s*[%d,]+%s*|TInterface\\MoneyFrame\\UI%-GoldIcon")
    or string.match(noclr, "^%s*[%d,]+%s*|TInterface\\MoneyFrame\\UI%-SilverIcon")
    or string.match(noclr, "^%s*[%d,]+%s*|TInterface\\MoneyFrame\\UI%-CopperIcon")
  then
    return true
  end

  local plain = noclr:gsub("|T.-|t", "")
  local lower = string.lower(plain)

  -- Textureless numeric triple money line (gold/silver/copper).
  if string.match(lower, "^%s*you gained:%s*[%d,]+%s+[%d,]+%s+[%d,]+%s*$") then
    return true
  end

  if not MONEY_PATTERNS then BuildMoneyPatterns() end

  for _, pat in ipairs(MONEY_PATTERNS or {}) do
    if string.match(msg, pat) then
      return true
    end
  end

  for _, prefix in ipairs(MONEY_PREFIXES or {}) do
    if type(prefix) == "string" and string.len(prefix) > 0 and string.find(msg, prefix, 1, true) == 1 then
      return true
    end
  end

  -- Avoid false positives on config/status text like "gold=on".
  -- Only treat GOLD/SILVER/COPPER words as money when an amount precedes them.
  local function hasNumberBeforeWordToken(token)
    if type(token) ~= "string" or token == "" then return false end
    local pat = EscapeLuaPattern(string.lower(token))
    local n, tokenEndPos = string.match(lower, "([%d,]+)%s*" .. pat .. "()%f[%W]")
    if not n then return false end
    if string.match(n, ",$") then return false end
    if tokenEndPos and string.match(lower:sub(tokenEndPos), "^%s*=") then return false end
    return true
  end
  if hasNumberBeforeWordToken((_G and rawget(_G, "GOLD")) or "gold")
    or hasNumberBeforeWordToken((_G and rawget(_G, "SILVER")) or "silver")
    or hasNumberBeforeWordToken((_G and rawget(_G, "COPPER")) or "copper") then
    return true
  end

  local function hasNumberBeforeToken(token)
    if type(token) ~= "string" or token == "" then return false end
    local pat = EscapeLuaPattern(string.lower(token))

    -- Guard against false positives like "8612 guides" matching the gold symbol "g".
    -- Require a non-alphanumeric boundary after the token.
    local n, tokenEndPos = string.match(lower, "([%d,]+)%s*" .. pat .. "()%f[%W]")
    if not n then return false end
    if string.match(n, ",$") then return false end
    if tokenEndPos and string.match(lower:sub(tokenEndPos), "^%s*=") then return false end
    return true
  end
  if hasNumberBeforeToken((_G and rawget(_G, "GOLD_AMOUNT_SYMBOL")) or "g")
    or hasNumberBeforeToken((_G and rawget(_G, "SILVER_AMOUNT_SYMBOL")) or "s")
    or hasNumberBeforeToken((_G and rawget(_G, "COPPER_AMOUNT_SYMBOL")) or "c") then
    return true
  end

  return false
end

-- Public: shared money parsing for other LootIt modules (e.g., Tax).
LootChat.IsLikelyMoneyMessage = IsLikelyMoneyMessage
LootChat.ParseCoinsFromMoneyMessage = ParseCoinsFromMoneyMessage

local function OnMoneyChat(_, _, msg, ...)
  EnsureRefs()
  DebugBumpEvent("CHAT_MSG_MONEY")
  if not IsEnabled() then return false end
  if type(msg) == "string" and IsSecretString(msg) then
    DebugBumpSecret("CHAT_MSG_MONEY")
    if LootChat.CaptureEnabled() then
      LootChat.CaptureAppend("CHAT_SECRET", { event = "CHAT_MSG_MONEY" })
    end
    return false
  end
  if not IsNonEmptyPublicString(msg) then return false end

  LootChat.CaptureChatIn("CHAT_MSG_MONEY", msg)

  local out, coins = TryFormatMoneyFromMessage(msg)
  if not out then return false end

  local handled = false
  if DB and DB.echoItem then
    if LootChat.LootCombineEnabled() then
      if DB and DB.lootCombineIncludeGold then
        LootCombineAdd(out, "money")
        handled = true
      end
    else
      Print(FormatSelfLine(out))
      handled = true
    end

    LootChat.CaptureChatOut("CHAT_MSG_MONEY", out, {
      handled = handled,
      combine = LootChat.LootCombineEnabled() and true or false,
      includeGold = (DB and DB.lootCombineIncludeGold) and true or false,
      gold = coins and coins.gold or nil,
      silver = coins and coins.silver or nil,
      copper = coins and coins.copper or nil,
    })
  end

  if handled and LootChat.LootCombineEnabled() then
    return true
  end
  return (DB and DB.hideLootText) and true or false
end

local QUEST_STATUS_PATTERNS
local function BuildQuestStatusPatterns()
  local patterns = {}

  local function GS2PatPos(globalString)
    if type(globalString) ~= "string" or globalString == "" then return nil end
    local s = globalString
    s = s:gsub("%%%%", "\0P\0")
    s = s:gsub("%%%d*%$?s", "\0S\0")
    s = s:gsub("%%%d*%$?d", "\0D\0")
    s = EscapeLuaPattern(s)
    s = s:gsub("\0S\0", "(.-)")
    s = s:gsub("\0D\0", "([%d,%.%s'%\194\160]+)")
    s = s:gsub("\0P\0", "%%")
    return "^" .. s .. "$"
  end

  local function AddByKey(kind, key)
    local gs = _G and rawget(_G, key)
    local pat = GS2PatPos(gs)
    if pat then
      patterns[#patterns + 1] = { kind = kind, key = key, pat = pat }
    end
  end

  -- These keys vary by client/patch/locale; include all that might exist.
  AddByKey("accepted", "ERR_QUEST_ACCEPTED_S")
  AddByKey("accepted", "QUEST_ACCEPTED")
  AddByKey("completed", "ERR_QUEST_COMPLETE_S")
  AddByKey("completed", "QUEST_COMPLETE")

  -- Quest log status lines (e.g. removed/abandoned).
  AddByKey("removed", "ERR_QUEST_REMOVED_S")
  AddByKey("removed", "QUEST_REMOVED")
  AddByKey("abandoned", "ERR_QUEST_ABANDONED_S")
  AddByKey("abandoned", "QUEST_ABANDONED")

  QUEST_STATUS_PATTERNS = patterns
end

local PLAYED_PATTERNS
local function BuildPlayedPatterns()
  local patterns = {}

  local function GS2Pat(globalString)
    if type(globalString) ~= "string" or globalString == "" then return nil end
    local s = globalString
    s = s:gsub("%%%%", "\0P\0")
    s = s:gsub("%%%d*%$?s", "\0S\0")
    s = s:gsub("%%%d*%$?d", "\0D\0")
    s = EscapeLuaPattern(s)
    -- We don't need captures for suppression; just match loosely.
    s = s:gsub("\0S\0", ".-")
    s = s:gsub("\0D\0", "[%d,%.%s'%\194\160]+")
    s = s:gsub("\0P\0", "%%")
    return "^" .. s .. "$"
  end

  local function AddByKey(key)
    local gs = _G and rawget(_G, key)
    local pat = GS2Pat(gs)
    if pat then
      patterns[#patterns + 1] = { key = key, pat = pat }
    end
  end

  AddByKey("TIME_PLAYED_TOTAL")
  AddByKey("TIME_PLAYED_LEVEL")

  PLAYED_PATTERNS = patterns
end

IsPlayedSystemMessage = function(msg)
  if type(msg) ~= "string" or msg == "" then return nil end

  local t = msg:gsub("\r", " "):gsub("\n", " ")
  t = t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  t = t:gsub("|T.-|t", "")
  t = t:gsub("\194\160", " ")
  t = t:gsub("\226\128\175", " ")
  t = t:gsub("\226\128\135", " ")
  t = t:gsub("\239\188\136", "(")
  t = t:gsub("\239\188\137", ")")
  t = t:gsub("%s+", " ")
  t = t:gsub("^%s+", ""):gsub("%s+$", "")

  if PLAYED_PATTERNS == nil then BuildPlayedPatterns() end
  for _, e in ipairs(PLAYED_PATTERNS or {}) do
    if t:match(e.pat) then
      return e.key or true
    end
  end

  -- Fallback (English-like).
  if t:match("^Total time played:%s*") then return "fallback" end
  if t:match("^Time played this level:%s*") then return "fallback" end

  return nil
end

local function ParseQuestStatusSystemMessage(msg)
  if type(msg) ~= "string" or msg == "" then return nil end

  local t = msg:gsub("\r", " "):gsub("\n", " ")
  t = t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  t = t:gsub("|T.-|t", "")
  t = t:gsub("\194\160", " ")
  t = t:gsub("\226\128\175", " ")
  t = t:gsub("\226\128\135", " ")
  t = t:gsub("\239\188\136", "(")
  t = t:gsub("\239\188\137", ")")
  t = t:gsub("%s+", " ")
  t = t:gsub("^%s+", ""):gsub("%s+$", "")

  if QUEST_STATUS_PATTERNS == nil then BuildQuestStatusPatterns() end
  for _, e in ipairs(QUEST_STATUS_PATTERNS or {}) do
    local a = t:match(e.pat)
    if IsNonEmptyPublicString(a) then
      local title = a:gsub("^%s+", ""):gsub("%s+$", "")
      if title ~= "" then
        return { kind = e.kind, title = title, key = e.key }
      end
    end
  end

  -- Fallback (English-like).
  do
    local title = t:match("^[Qq]uest%s+[Aa]ccepted:%s*(.-)%s*$")
    if IsNonEmptyPublicString(title) then
      title = title:gsub("^%s+", ""):gsub("%s+$", "")
      if title ~= "" then
        return { kind = "accepted", title = title, key = "fallback" }
      end
    end
  end
  do
    local title = t:match("^[Qq]uest%s+[Cc]ompleted:%s*(.-)%s*$")
    if IsNonEmptyPublicString(title) then
      title = title:gsub("^%s+", ""):gsub("%s+$", "")
      if title ~= "" then
        return { kind = "completed", title = title, key = "fallback" }
      end
    end
  end

  -- Fallback: some clients/styles use "<Quest Title> completed." (no "Quest completed:" prefix).
  -- Keep this fairly strict to avoid false positives.
  do
    local low = t:lower()
    -- Avoid matching achievement/other system lines.
    if (not low:find("achievement", 1, true)) and (not low:find("earned", 1, true)) then
      local title = t:match("^(.+)%s+[Cc]ompleted%.?$")
      if IsNonEmptyPublicString(title) then
        title = title:gsub("^%s+", ""):gsub("%s+$", "")
        -- Exclude generic phrases like "Quest completed" etc.
        local tlow = title:lower()
        if title ~= "" and (not tlow:find("quest", 1, true)) and #title >= 3 then
          return { kind = "completed", title = title, key = "fallback-title-completed" }
        end
      end
    end
  end

  -- Fallback: quest removed from quest log (English-like).
  do
    local title = t:match("^The quest%s+(.+)%s+has been removed from your quest log%.?$")
    if IsNonEmptyPublicString(title) then
      title = title:gsub("^%s+", ""):gsub("%s+$", "")
      if title ~= "" then
        return { kind = "removed", title = title, key = "fallback" }
      end
    end
  end

  return nil
end

-- Forward decls: quest completed system lines are processed much earlier than
-- XP parsing, but they need a consistent timebase + a later fallback printer.
local SafeNow
local ScheduleQuestCompletedFallbackPrint
local MaybePrintXPDebug

local function OnSystemChat(_, eventName, msg, ...)
  EnsureRefs()
  DebugBumpEvent(tostring(eventName or "CHAT_MSG_SYSTEM"))
  if type(msg) == "string" and IsSecretString(msg) then
    DebugBumpSecret(tostring(eventName or "CHAT_MSG_SYSTEM"))
    if LootChat.CaptureEnabled() then
      LootChat.CaptureAppend("CHAT_SECRET", { event = tostring(eventName or "CHAT_MSG_SYSTEM") })
    end
    return false
  end
  if not IsNonEmptyPublicString(msg) then return false end

  local ev = (type(eventName) == "string" and eventName ~= "") and eventName or "CHAT_MSG_SYSTEM"
  LootChat.CaptureChatIn(ev, msg)

  -- Generic suppress rules (SV-backed): hide matching lines early.
  do
    local hit, idx, needle = ShouldSuppressMessage(msg)
    if hit then
      LootChat.CaptureChatOut(ev, "(suppress) suppressed", {
        handled = true,
        suppressedByRule = true,
        suppressRuleIndex = idx,
        suppressRuleText = needle,
      })
      return true
    end
  end

  -- /played system output (two lines). Optional suppression toggle.
  -- This is intentionally independent of LootIt's main enabled toggle.
  if (DB and DB.other and DB.other.hidePlayed) == true then
    local playedKey = IsPlayedSystemMessage(msg)
    if playedKey then
      LootChat.CaptureChatOut(ev, "(played) suppressed", {
        handled = true,
        suppressedPlayed = true,
        fromKey = playedKey,
      })
      return true
    end
  end

  -- Quest system lines (accepted/completed) are separate from XP gain lines.
  -- This behavior belongs to the Experience module; it should work even if
  -- LootIt's main toggle is off.
  if (DB and DB.other and DB.other.experience and DB.other.experience.enabled) and QuestXPEnabled() then
    -- Some clients emit a generic "Quest completed" line without a title. If we recently
    -- captured a titled completion (e.g. "<Title> completed."), suppress this too so the
    -- quest name can live on the XP line.
    do
      local t = msg:gsub("\r", " "):gsub("\n", " ")
      t = t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
      t = t:gsub("|T.-|t", "")
      t = t:gsub("\194\160", " ")
      t = t:gsub("\226\128\175", " ")
      t = t:gsub("\226\128\135", " ")
      t = t:gsub("%s+", " ")
      t = t:gsub("^%s+", ""):gsub("%s+$", "")
      if t:lower():match("^quest%s+completed%.?$") then
        local now = SafeNow()
        if IsNonEmptyPublicString(_xpQuestLastTitle) and _xpQuestLastTS and (now - _xpQuestLastTS) <= QUEST_XP_ATTACH_WINDOW then
          LootChat.CaptureChatOut(ev, "(quest) suppressed", {
            handled = true,
            suppressedQuestStatus = true,
            questStatus = "completed",
            questTitle = _xpQuestLastTitle,
            fromKey = "fallback-generic-completed",
          })
          MaybePrintXPDebug("quest-completed suppressed (generic)")
          return true
        end
      end
    end

    local qs = ParseQuestStatusSystemMessage(msg)
    if qs and IsNonEmptyPublicString(qs.title) then
      if qs.kind == "completed" then
        _xpQuestLastTS = SafeNow()
        _xpQuestLastTitle = qs.title
        _xpQuestLastXP = nil
        MaybePrintXPDebug(string.format("quest-completed stored title='%s'", tostring(qs.title)))
      else
        MaybePrintXPDebug(string.format("quest-%s suppressed title='%s'", tostring(qs.kind), tostring(qs.title)))
      end

      LootChat.CaptureChatOut(ev, "(quest) suppressed", {
        handled = true,
        suppressedQuestStatus = true,
        questStatus = qs.kind,
        questTitle = qs.title,
        fromKey = qs.key,
      })
      return true
    end
  end

  if not IsEnabled() then return false end

  if (DB and DB.other and DB.other.instance and DB.other.instance.enabled) then
    local ev = (type(eventName) == "string" and eventName ~= "") and eventName or "CHAT_MSG_SYSTEM"
    if ev == "CHAT_MSG_SYSTEM"
      or ev == "CHAT_MSG_PARTY"
      or ev == "CHAT_MSG_PARTY_LEADER"
      or ev == "CHAT_MSG_RAID"
      or ev == "CHAT_MSG_RAID_LEADER"
      or ev == "CHAT_MSG_GUILD" then
      local parsed = ParseInstanceSystemMessage(msg)
      if parsed then
        local handled = HandleParsedInstanceMessage(ev, msg, parsed)
        if handled then
          return true
        end
      end
    end
  end

  local moneyOut, moneyCoins = TryFormatMoneyFromMessage(msg)
  if moneyOut then
    local handled = false
    if DB and DB.echoItem then
      if LootChat.LootCombineEnabled() then
        if DB and DB.lootCombineIncludeGold then
          LootCombineAdd(moneyOut, "money")
          handled = true
        end
      else
        Print(FormatSelfLine(moneyOut))
        handled = true
      end

      LootChat.CaptureChatOut("CHAT_MSG_SYSTEM", moneyOut, {
        handled = handled,
        rewrittenMoney = true,
        combine = LootChat.LootCombineEnabled() and true or false,
        includeGold = (DB and DB.lootCombineIncludeGold) and true or false,
        gold = moneyCoins and moneyCoins.gold or nil,
        silver = moneyCoins and moneyCoins.silver or nil,
        copper = moneyCoins and moneyCoins.copper or nil,
      })
    end

    if handled and LootChat.LootCombineEnabled() then
      return true
    end
    return (DB and DB.hideLootText) and true or false
  end

  if not LOOT_PATTERNS then BuildLootPatterns() end

  -- Some system lines include item/currency names but are not loot (e.g. transfers to another player).
  -- These should not be rewritten/reprinted by LootIt; if Hide Loot Text is on, suppress them.
  do
    -- Normalize to avoid missing matches due to color codes, textures, or NBSP/thin spaces.
    local t = msg
    t = t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    t = t:gsub("|T.-|t", "")
    t = t:gsub("\r", " "):gsub("\n", " ")
    t = t:gsub("\194\160", " ")
    t = t:gsub("\226\128\175", " ")
    t = t:gsub("\226\128\135", " ")
    t = t:gsub("%s+", " ")
    t = t:gsub("^%s+", ""):gsub("%s+$", "")

    local low = t:lower()
    local looksLikeTransfer = (low:find("transfer", 1, true) ~= nil)
      and ((low:find(" to ", 1, true) ~= nil) or (low:match("%sto%s") ~= nil))

    if looksLikeTransfer then
      local hasItem = (msg:find("|Hitem:", 1, true) ~= nil) and true or false
      local hasCurrency = (msg:find("|Hcurrency:", 1, true) ~= nil) and true or false
      local hasBracket = (msg:match("%b[]") ~= nil) and true or false
      if hasItem or hasCurrency or hasBracket then
        local suppress = (DB and DB.hideLootText) and true or false
        LootChat.CaptureChatOut(ev, suppress and "(transfer) suppressed" or "(transfer) passthru", {
          handled = suppress,
          passedThroughTransfer = true,
          hasItemLink = hasItem,
          hasCurrencyLink = hasCurrency,
          hasBracket = hasBracket,
        })
        return suppress
      end
    end
  end

  -- Some loot lines (notably fishing) can show up as CHAT_MSG_SYSTEM instead of CHAT_MSG_LOOT.
  -- If the message begins with a known loot prefix, treat it as self loot and rewrite/suppress it.
  do
    local prefixMatched = false
    if LOOT_PREFIXES and #LOOT_PREFIXES > 0 then
      local tmsg = msg:gsub("^%s+", "")
      for _, prefix in ipairs(LOOT_PREFIXES) do
        if type(prefix) == "string" and prefix ~= "" then
          local tp = prefix:gsub("^%s+", "")
          if tp ~= "" and tmsg:sub(1, #tp) == tp then
            prefixMatched = true
            break
          end
        end
      end
    end

    if prefixMatched then
      local link = ExtractLinkFallback(msg)
      if not link then
        link = msg:match("%b[]")
      end

      if not link then
        if DebugChatSetupEnabled and DebugChatSetupEnabled() then
          DebugPrint(string.format(
            "OnSystemChat: loot-prefix but no link (event=%s hide=%s echo=%s) msg=%s",
            tostring(ev),
            tostring((DB and DB.hideLootText) and true or false),
            tostring((DB and DB.echoItem) and true or false),
            tostring(msg)
          ))
        end
        return false
      end

      local qty
      do
        local escaped = EscapeLuaPattern(link)
        qty = msg:match(escaped .. "%s*[x×]%s*(%d+)")
          or msg:match(escaped .. "[\r\n ]*[x×]%s*(%d+)")
          or msg:match("%s*[x×]%s*(%d+)%s*%.?$")
      end

      local handled = false
      if DB and DB.echoItem then
        link = NormalizeItemLink(link)

        local itemID = CaptureItemIDFromLink(link)
        if itemID and IsIgnoredItemID(itemID) then
          LootChat.CaptureChatOut(ev, link, { handled = true, ignored = true, qty = tonumber(qty), itemID = itemID, rewrittenLoot = true })
          return true
        end

        do
          local n = tonumber(qty)
          local delaySec = itemID and GetDelayPrintSecondsForItemID(itemID) or nil
          if delaySec then
            if DelayPrintAddItem(itemID, link, n, delaySec) then
              LootChat.CaptureChatOut("CHAT_MSG_SYSTEM", link, { handled = true, delayed = true, delaySec = delaySec, qty = n, itemID = itemID, rewrittenLoot = true })
              return true
            end
          end
        end

        link = ApplyItemLinkAlias(link)
        local displayLink = StripDisplayedLinkBrackets(link)
        local out = displayLink
        local n = tonumber(qty)
        if n and n > 1 then
          out = string.format("%s x%d", displayLink, n)
        end

        if IsItemLevelEnabled() and type(link) == "string" and link:find("|Hitem:", 1, true) then
          local ilvl = GetEquippableItemLevelSuffix(link)
          if ilvl then
            local color = link:match("^(|c%x%x%x%x%x%x%x%x)")
            local ilvlText = color and (color .. tostring(ilvl) .. "|r") or tostring(ilvl)
            out = out .. " " .. ilvlText
          end
        end

        LootCombineAdd(out)
        handled = true
        LootChat.CaptureChatOut(ev, out, {
          handled = handled,
          rewrittenLoot = true,
          combine = LootChat.LootCombineEnabled() and true or false,
          qty = tonumber(qty),
          itemID = CaptureItemIDFromLink(link),
        })
      end

      if handled and LootChat.LootCombineEnabled() then
        return true
      end
      return (handled and DB and DB.hideLootText) and true or false
    end
  end

  local link, qty
  for _, pat in ipairs(RECEIVE_ITEM_PATTERNS or {}) do
    local a, b = msg:match(pat)
    if a then
      link = a
      qty = b
      break
    end
  end

  if LootChat.CaptureEnabled() then
    LootChat.CaptureAppend("MATCH", {
      event = ev,
      link = link,
      qty = qty,
      hasItemLink = (msg:find("|Hitem:", 1, true) ~= nil) or false,
    })
  end

  if not link then
    link = ExtractLinkFallback(msg)
  end
  if not link then
    return false
  end

  local handled = false
  if DB and DB.echoItem then
    link = NormalizeItemLink(link)
    local ignoredID = CaptureItemIDFromLink(link)
    if ignoredID and IsIgnoredItemID(ignoredID) then
      LootChat.CaptureChatOut("CHAT_MSG_SYSTEM", link, {
        handled = true,
        ignored = true,
        qty = tonumber(qty),
        itemID = ignoredID,
      })
      return true
    end

    do
      local n = tonumber(qty)
      local delaySec = GetDelayPrintSecondsForItemID(ignoredID)
      if delaySec then
        if DelayPrintAddItem(ignoredID, link, n, delaySec) then
          LootChat.CaptureChatOut("CHAT_MSG_SYSTEM", link, {
            handled = true,
            delayed = true,
            delaySec = delaySec,
            qty = n,
            itemID = ignoredID,
          })
          return true
        end
      end
    end

    link = ApplyItemLinkAlias(link)
    local displayLink = StripDisplayedLinkBrackets(link)
    local out = displayLink
    local n = tonumber(qty)
    if n and n > 1 then
      out = string.format("%s x%d", displayLink, n)
    end

    if IsItemLevelEnabled() then
      local ilvl = GetEquippableItemLevelSuffix(link)
      if ilvl then
        local color = link:match("^(|c%x%x%x%x%x%x%x%x)")
        local ilvlText
        if color then
          ilvlText = color .. tostring(ilvl) .. "|r"
        else
          ilvlText = tostring(ilvl)
        end
        out = out .. " " .. ilvlText
      end
    end

    LootCombineAdd(out)
    handled = true

    LootChat.CaptureChatOut("CHAT_MSG_SYSTEM", out, {
      handled = handled,
      combine = LootChat.LootCombineEnabled() and true or false,
      qty = tonumber(qty),
      itemID = CaptureItemIDFromLink(link),
    })
  end

  if handled and LootChat.LootCombineEnabled() then
    return true
  end
  return (DB and DB.hideLootText) and true or false
end

local pendingAsyncLoot = {}

local function OnLootChat(_, _, msg, author, ...)
  EnsureRefs()
  DebugBumpEvent("CHAT_MSG_LOOT")
  if not IsEnabled() then return false end
  if type(msg) == "string" and IsSecretString(msg) then
    DebugBumpSecret("CHAT_MSG_LOOT")
    if LootChat.CaptureEnabled() then
      LootChat.CaptureAppend("CHAT_SECRET", { event = "CHAT_MSG_LOOT", author = (type(author) == "string") and author or nil })
    end
    return false
  end
  if not IsNonEmptyPublicString(msg) then return false end

  LootChat.CaptureChatIn("CHAT_MSG_LOOT", msg, author)

  if not LOOT_PATTERNS then BuildLootPatterns() end

  if string.find(msg, "|Hcurrency:", 1, true) then
    local handled = false

    local link = (ExtractCurrencyLinkFallback and ExtractCurrencyLinkFallback(msg))
      or string.match(msg, "(|Hcurrency:%d+.-|h.-|h)")
      or string.match(msg, "(|c%x%x%x%x%x%x%x%x|Hcurrency:%d+.-|h.-|h|r)")

    if link and DB and DB.echoItem then
      local qty
      local escaped = EscapeLuaPattern(link)
      qty = string.match(msg, escaped .. "%s*[x×]%s*(%d+)")
        or string.match(msg, escaped .. "[\r\n ]*[x×]%s*(%d+)")
        or string.match(msg, "%s*[x×]%s*(%d+)%s*%.?$")

      local n = tonumber(qty)
      local currencyID = (GetCurrencyIDFromLink and GetCurrencyIDFromLink(link)) or nil

      if currencyID and IsDuplicateRecentCurrencyPrint(currencyID, n, 0.35) then
        LootChat.CaptureChatOut("CHAT_MSG_LOOT", "(currency) deduped", {
          handled = (DB and DB.hideLootText) and true or false,
          dedupedCurrency = true,
          qty = n,
          currencyID = currencyID,
          rewrittenCurrency = true,
        })
        return (DB and DB.hideLootText) and true or false
      end

      if currencyID and C_CurrencyInfo and C_CurrencyInfo.GetCurrencyLink then
        local built = C_CurrencyInfo.GetCurrencyLink(currencyID, (n and n > 0) and n or 0)
        if type(built) == "string" and string.len(built) > 0 then
          link = built
        end
      end

      local out = (ApplyCurrencyLinkAlias and ApplyCurrencyLinkAlias(link)) or link
      out = StripDisplayedLinkBrackets(out)
      if n and n > 1 then
        out = string.format("%s x%d", out, n)
      end

      if LootChat.LootCombineEnabled() then
        if DB and DB.lootCombineIncludeCurrency then
          LootCombineAdd(out, "currency")
          handled = true
        end
      else
        Print(FormatSelfLine(out))
        handled = true
      end

      if handled and currencyID then
        RememberRecentCurrencyPrint(currencyID, n)
      end

      LootChat.CaptureChatOut("CHAT_MSG_LOOT", out, {
        handled = handled,
        rewrittenCurrency = true,
        combine = LootChat.LootCombineEnabled() and true or false,
        includeCurrency = (DB and DB.lootCombineIncludeCurrency) and true or false,
        qty = n,
        currencyID = currencyID,
      })
    end

    if handled and LootChat.LootCombineEnabled() then
      return true
    end
    return (DB and DB.hideLootText) and true or false
  end

  if (DB and DB.hideLootText) and (LOOT_PREFIXES and #LOOT_PREFIXES > 0) then
    local hasItem = string.find(msg, "|Hitem:", 1, true) ~= nil
    local hasCurrency = string.find(msg, "|Hcurrency:", 1, true) ~= nil
    if (not hasItem) and (not hasCurrency) and (not IsLikelyMoneyMessage(msg)) then
      local tmsg = NormalizeForPrefixMatch(msg)
      for _, prefix in ipairs(LOOT_PREFIXES) do
        if type(prefix) == "string" and string.len(prefix) > 0 then
          local tp = NormalizeForPrefixMatch(prefix)
          if string.len(tp) > 0 and string.find(tmsg, tp, 1, true) == 1 and string.len(tmsg) == string.len(tp) then
            return true
          end
        end
      end
    end
  end

  local moneyOut, moneyCoins = TryFormatMoneyFromMessage(msg)
  if moneyOut then
    local handled = false
    if DB and DB.echoItem then
      if LootChat.LootCombineEnabled() and (DB and DB.lootCombineIncludeGold) then
        LootCombineAdd(moneyOut, "money")
        handled = true
      else
        Print(FormatSelfLine(moneyOut))
        handled = true
      end

      LootChat.CaptureChatOut("CHAT_MSG_LOOT", moneyOut, {
        handled = handled,
        rewrittenMoney = true,
        combine = LootChat.LootCombineEnabled() and true or false,
        includeGold = (DB and DB.lootCombineIncludeGold) and true or false,
        gold = moneyCoins and moneyCoins.gold or nil,
        silver = moneyCoins and moneyCoins.silver or nil,
        copper = moneyCoins and moneyCoins.copper or nil,
      })
    end
    if handled and LootChat.LootCombineEnabled() then
      return true
    end
    return (DB and DB.hideLootText) and true or false
  end

  local isSelfLoot = false
  local playerName
  local link, qty
  local matchedByPattern = false
  local handled = false

  local dbgLootPrefixLine = (DebugChatSetupEnabled and DebugChatSetupEnabled()) and MessageStartsWithLootPrefix(msg) or false

  -- Prefer the chat event author for self-detection; some localized/variant loot lines don't match patterns.
  do
    local me = (UnitName and UnitName("player")) or nil
    if type(author) == "string" and author ~= "" and type(me) == "string" and me ~= "" then
      local a = StripRealmFromName(author)
      local m = StripRealmFromName(me)
      if a ~= "" and m ~= "" and a == m then
        isSelfLoot = true
      end
    end
  end

  for _, pat in ipairs(LOOT_PATTERNS or {}) do
    local a, b = msg:match(pat)
    if a then
      isSelfLoot = true
      matchedByPattern = true
      if b then
        link, qty = a, b
      else
        link = a
      end
      break
    end
  end

  -- Some clients/patches format the quantity suffix as "|rx2" (no space) and/or patterns may
  -- match the link but fail to capture the qty. Recover qty from the full message when needed.
  if link and not qty then
    local escaped = EscapeLuaPattern(link)
    qty = msg:match(escaped .. "%s*[x×]%s*(%d+)")
      or msg:match(escaped .. "[\r\n ]*[x×]%s*(%d+)")
      or msg:match("|h|r%s*[x×]%s*(%d+)")
      or msg:match("%s*[x×]%s*(%d+)%s*%.?$")
  end

  -- Fallback: if patterns miss but the message starts with a known loot prefix and contains an item hyperlink,
  -- extract the first item link and optional quantity.
  if (not matchedByPattern) and (not link) and (LOOT_PREFIXES and #LOOT_PREFIXES > 0) then
    local hasItem = (msg:find("|Hitem:", 1, true) ~= nil) and true or false
    if hasItem then
      if MessageStartsWithLootPrefix(msg) then
        local extracted = ExtractItemLinkRobust(msg) or ExtractLinkFallback(msg)
        if extracted then
          isSelfLoot = true
          matchedByPattern = true
          link = extracted
          do
            local escaped = EscapeLuaPattern(extracted)
            qty = msg:match(escaped .. "%s*[x×]%s*(%d+)")
              or msg:match(escaped .. "[\r\n ]*[x×]%s*(%d+)")
              or msg:match("%s*[x×]%s*(%d+)%s*%.?$")
          end
        else
          -- As a last resort, use the displayed [Item Name] token.
          local bracket = msg:match("%b[]")
          if bracket then
            isSelfLoot = true
            matchedByPattern = true
            link = bracket
          end
        end
      end
    end
  end

  if not link then
    for _, pat in ipairs(LOOT_GROUP_PATTERNS or {}) do
      local a, b, c = msg:match(pat)
      if a and b then
        matchedByPattern = true
        if IsItemLink(a) and not IsItemLink(b) then
          link, playerName, qty = a, b, c
        elseif IsItemLink(b) and not IsItemLink(a) then
          playerName, link, qty = a, b, c
        else
          playerName, link, qty = a, b, c
        end
        break
      end
    end

    if (not playerName or playerName == "") and type(author) == "string" and author ~= "" then
      playerName = author
    end
  end

  if not link then
    link = ExtractLinkFallback(msg)
  end

  -- If the message contains an item hyperlink but our normal matcher couldn't extract it,
  -- fall back to a very permissive hyperlink extractor.
  if not link then
    if msg:find("|Hitem:", 1, true) then
      link = ExtractItemLinkRobust(msg)
      if link then
        isSelfLoot = true
        matchedByPattern = true
      end
    end
  end

  if DebugChatSetupEnabled and DebugChatSetupEnabled() and (not matchedByPattern) then
    local hasItem = (msg:find("|Hitem:", 1, true) ~= nil) and true or false
    local hasCurrency = (msg:find("|Hcurrency:", 1, true) ~= nil) and true or false
    DebugPrint(string.format(
      "OnLootChat: pattern miss (hide=%s echo=%s hasItem=%s hasCurrency=%s author=%s) msg=%s",
      tostring((DB and DB.hideLootText) and true or false),
      tostring((DB and DB.echoItem) and true or false),
      tostring(hasItem),
      tostring(hasCurrency),
      tostring(author),
      tostring(msg)
    ))
  end

  if LootChat.CaptureEnabled() then
    LootChat.CaptureAppend("MATCH", {
      event = "CHAT_MSG_LOOT",
      isSelfLoot = isSelfLoot and true or false,
      link = link,
      qty = qty,
      hasItemLink = (msg:find("|Hitem:", 1, true) ~= nil) or false,
    })
  end
  if not link then
    if DebugChatSetupEnabled and DebugChatSetupEnabled() then
      local hasItem = (msg:find("|Hitem:", 1, true) ~= nil) and true or false
      local hasCurrency = (msg:find("|Hcurrency:", 1, true) ~= nil) and true or false
      local raw = tostring(msg):gsub("|", "||")
      DebugPrint(string.format(
        "OnLootChat: NO LINK (hasItem=%s hasCurrency=%s) msg=%s",
        tostring(hasItem), tostring(hasCurrency), tostring(msg)
      ))
      -- Print a raw form (escaped pipes) so we can see the hyperlink codes in chat.
      DebugPrint("OnLootChat: NO LINK raw=" .. raw)
    end
    return false
  end

  do
    local ignoredID = CaptureItemIDFromLink(link)
    if ignoredID and IsIgnoredItemID(ignoredID) then
      LootChat.CaptureChatOut("CHAT_MSG_LOOT", link, {
        handled = true,
        ignored = true,
        isSelfLoot = isSelfLoot and true or false,
        player = (not isSelfLoot) and playerName or nil,
        qty = tonumber(qty),
        itemID = ignoredID,
      })
      return true
    end
  end

  do
    local bracketName = (type(link) == "string") and link:match("^%[([^%]]+)%]$") or nil
    if bracketName and not link:find("|Hitem:", 1, true) then
      local knownItemID = nil
      if bracketName == "Chest of Gold" then
        knownItemID = 226814
      end

      if knownItemID and IsIgnoredItemID(knownItemID) then
        LootChat.CaptureChatOut("CHAT_MSG_LOOT", "[" .. bracketName .. "]", { handled = true, ignored = true, async = true, itemID = knownItemID, from = bracketName })
        return true
      end

      if knownItemID and Item and (Item.CreateFromItemID or Item.createFromItemID) then
        local n = tonumber(qty)
        if not n or n < 1 then n = 1 end

        local key = tostring(knownItemID) .. ":" .. tostring(n)
        if not pendingAsyncLoot[key] then
          pendingAsyncLoot[key] = true

          local itemObj = (Item.CreateFromItemID and Item:CreateFromItemID(knownItemID))
            or (Item.createFromItemID and Item:createFromItemID(knownItemID))

          local function finalize(withLink)
            pendingAsyncLoot[key] = nil
            EnsureRefs()
            if not (IsEnabled() and DB and DB.echoItem) then return end

            if IsIgnoredItemID(knownItemID) then
              LootChat.CaptureChatOut("CHAT_MSG_LOOT", "[" .. bracketName .. "]", { handled = true, ignored = true, async = true, itemID = knownItemID, from = bracketName })
              return
            end

            local resolved = withLink
            if type(resolved) ~= "string" or resolved == "" then
              resolved = "[" .. bracketName .. "]"
            end

            resolved = NormalizeItemLink(resolved)
            resolved = ApplyItemLinkAlias(resolved)
            local displayLink = StripDisplayedLinkBrackets(resolved)
            local out = displayLink
            if n and n > 1 then
              out = string.format("%s x%d", displayLink, n)
            end

            if IsItemLevelEnabled() then
              local ilvl = GetEquippableItemLevelSuffix(resolved)
              if ilvl then
                local color = resolved:match("^(|c%x%x%x%x%x%x%x%x)")
                local ilvlText = color and (color .. tostring(ilvl) .. "|r") or tostring(ilvl)
                out = out .. " " .. ilvlText
              end
            end

            LootCombineAdd(out)
            LootChat.CaptureChatOut("CHAT_MSG_LOOT", out, { handled = true, async = true, itemID = knownItemID, from = bracketName })
          end

          if itemObj and itemObj.ContinueOnItemLoad then
            itemObj:ContinueOnItemLoad(function()
              local itemLink = (itemObj.GetItemLink and itemObj:GetItemLink()) or nil
              finalize(itemLink)
            end)

            if C_Timer and C_Timer.After then
              C_Timer.After(1.0, function()
                if pendingAsyncLoot[key] then
                  finalize(nil)
                end
              end)
            end

            return (DB and DB.hideLootText) and true or false
          end
        end
      end
    end
  end

  if DB and DB.echoItem then
    link = NormalizeItemLink(link)
    local n = tonumber(qty)
    do
      local ignoredID = CaptureItemIDFromLink(link)
      if ignoredID and IsIgnoredItemID(ignoredID) then
        LootChat.CaptureChatOut("CHAT_MSG_LOOT", link, {
          handled = true,
          ignored = true,
          isSelfLoot = isSelfLoot and true or false,
          player = (not isSelfLoot) and playerName or nil,
          qty = tonumber(qty),
          itemID = ignoredID,
          combine = LootChat.LootCombineEnabled() and true or false,
        })
        return true
      end
    end

    if isSelfLoot then
      local itemID = CaptureItemIDFromLink(link)
      local delaySec = GetDelayPrintSecondsForItemID(itemID)
      if delaySec then
        if DelayPrintAddItem(itemID, link, n, delaySec) then
          LootChat.CaptureChatOut("CHAT_MSG_LOOT", link, {
            handled = true,
            delayed = true,
            delaySec = delaySec,
            isSelfLoot = true,
            qty = n,
            itemID = itemID,
          })
          return true
        end
      end
    end

    link = ApplyItemLinkAlias(link)
    local displayLink = StripDisplayedLinkBrackets(link)
    local out = displayLink
    if n and n > 1 then
      out = string.format("%s x%d", displayLink, n)
    end

    if IsItemLevelEnabled() then
      local ilvl = GetEquippableItemLevelSuffix(link)
      if ilvl then
        local color = link:match("^(|c%x%x%x%x%x%x%x%x)")
        local ilvlText
        if color then
          ilvlText = color .. tostring(ilvl) .. "|r"
        else
          ilvlText = tostring(ilvl)
        end

        out = out .. " " .. ilvlText
      end
    end

    if isSelfLoot then
      LootCombineAdd(out)
      handled = true
    else
      Print(FormatOtherLine(playerName, out))
      handled = true
    end

    LootChat.CaptureChatOut("CHAT_MSG_LOOT", out, {
      handled = true,
      isSelfLoot = isSelfLoot and true or false,
      player = (not isSelfLoot) and playerName or nil,
      qty = tonumber(qty),
      itemID = CaptureItemIDFromLink(link),
      combine = LootChat.LootCombineEnabled() and true or false,
    })
  end

  local suppress = (handled and ((DB and DB.hideLootText) or (LootChat.LootCombineEnabled() and isSelfLoot))) and true or false
  if dbgLootPrefixLine then
    DebugPrint(string.format(
      "OnLootChat(prefix): handled=%s suppress=%s isSelfLoot=%s link=%s qty=%s hasItem=%s",
      tostring(handled and true or false),
      tostring(suppress),
      tostring(isSelfLoot and true or false),
      tostring(link),
      tostring(qty),
      tostring(string.find(msg, "|Hitem:", 1, true) ~= nil)
    ))
  end
  return suppress
end

local function OnAchievementChat(_, _, msg, author, ...)
  EnsureRefs()
  DebugBumpEvent("CHAT_MSG_ACHIEVEMENT")
  if not (DB and DB.other and DB.other.achievement and DB.other.achievement.enabled) then
    return false
  end
  if type(msg) == "string" and IsSecretString(msg) then
    DebugBumpSecret("CHAT_MSG_ACHIEVEMENT")
    if LootChat.CaptureEnabled() then
      LootChat.CaptureAppend("CHAT_SECRET", { event = "CHAT_MSG_ACHIEVEMENT", author = (type(author) == "string") and author or nil })
    end
    return false
  end
  if not IsNonEmptyPublicString(msg) then
    return false
  end

  local link = ExtractAchievementLinkFallback(msg)
  if not link then
    return false
  end

  local name = StripRealmFromName(author)
  if not IsNonEmptyPublicString(name) then
    name = "Character"
  end

  local function ClassColorName(nameText, guid)
    nameText = tostring(nameText or "")
    if nameText == "" then
      return nameText
    end

    local classFile = nil
    if type(guid) == "string" and type(GetPlayerInfoByGUID) == "function" then
      local ok, _, class = pcall(GetPlayerInfoByGUID, guid)
      if ok and type(class) == "string" and class ~= "" then
        classFile = class
      end
    end

    if not classFile and type(UnitClass) == "function" and type(UnitGUID) == "function" then
      local pg = UnitGUID("player")
      if pg and pg == guid then
        local _, cls = UnitClass("player")
        if type(cls) == "string" and cls ~= "" then
          classFile = cls
        end
      end
    end

    -- Prefer the game's class-color helpers.
    -- NOTE: ColorMixin:GenerateHexColor() may return either RRGGBB or AARRGGBB depending on client;
    -- do NOT blindly prefix "ff" or you'll end up with extra trailing digits showing in chat.
    if classFile and C_ClassColor and type(C_ClassColor.GetClassColor) == "function" then
      local c = C_ClassColor.GetClassColor(classFile)
      if c and type(c.WrapTextInColorCode) == "function" then
        return c:WrapTextInColorCode(nameText)
      end
    end

    local hex = nil
    if classFile and C_ClassColor and type(C_ClassColor.GetClassColor) == "function" then
      local c = C_ClassColor.GetClassColor(classFile)
      if c and type(c.GenerateHexColor) == "function" then
        local raw = tostring(c:GenerateHexColor() or "")
        raw = raw:gsub("[^0-9a-fA-F]", "")
        if #raw == 6 then
          hex = "ff" .. raw
        elseif #raw == 8 then
          hex = raw
        end
      end
    end

    if not hex and classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile] then
      local c = RAID_CLASS_COLORS[classFile]
      if type(c.colorStr) == "string" and c.colorStr ~= "" then
        hex = c.colorStr
      elseif c and c.r and c.g and c.b then
        hex = string.format("ff%02x%02x%02x", math.floor(c.r * 255 + 0.5), math.floor(c.g * 255 + 0.5), math.floor(c.b * 255 + 0.5))
      end
    end

    if not hex then
      return nameText
    end

    if WrapTextInColorCode then
      return WrapTextInColorCode(nameText, hex)
    end
    return "|c" .. hex .. nameText .. "|r"
  end

  -- Chat message events include GUID in a fixed position; do not assume it is the last arg.
  -- CHAT_MSG_* payload (after msg, author): languageName, channelName, author2, specialFlags,
  -- zoneChannelID, channelIndex, channelBaseName, unused, lineID, guid, ...
  local guid = select(10, ...)
  if type(guid) ~= "string" or not guid:find("^Player%-") then
    guid = nil
  end
  -- Color the "Name:" prefix as a unit so the ':' matches the name color.
  local coloredPrefix = ClassColorName(name .. ":", guid)

  local displayLink = StripDisplayedLinkBrackets(link)
  local out = string.format("%s earned %s!", coloredPrefix, displayLink)

  -- Dedupe: some clients/addons can surface the same achievement twice in quick
  -- succession (commonly one via CHAT_MSG_ACHIEVEMENT and one via
  -- CHAT_MSG_GUILD_ACHIEVEMENT). We still suppress the original event line, but
  -- avoid printing our rewritten line twice.
  local now2 = (GetTime and GetTime()) or 0
  local outFrame = (DB.other and DB.other.achievement and DB.other.achievement.outputChatFrame)
    or (DB.other and DB.other.outputChatFrame)
    or (DB and DB.outputChatFrame)
    or 1
  do
    if not LootChat._achDedupe then
      LootChat._achDedupe = { map = {}, lastPurgeAt = 0 }
    end
    local st = LootChat._achDedupe
    local key = tostring(outFrame) .. "|" .. tostring(name) .. "|" .. tostring(displayLink)
    local lastAt = st.map[key]
    if type(lastAt) == "number" and (now2 - lastAt) < 0.75 then
      return true
    end
    st.map[key] = now2

    if (now2 - (tonumber(st.lastPurgeAt) or 0)) > 5 then
      st.lastPurgeAt = now2
      for k, t in pairs(st.map) do
        if type(t) ~= "number" or (now2 - t) > 10 then
          st.map[k] = nil
        end
      end
    end
  end
  PrintToChatFrame(out, outFrame)

  return true
end

local function ParseNumberFromChat(s)
  if type(s) ~= "string" or s == "" then return nil end
  -- Locale-safe: allow common thousands separators/spaces.
  -- Keep only digits for parsing.
  s = s:gsub("[^%d]", "")
  local n = tonumber(s)
  if not n then return nil end
  if n < 0 then return nil end
  return n
end

local XP_PATTERNS

local function GlobalStringToPatternPositional(globalString)
  if type(globalString) ~= "string" or globalString == "" then return nil end

  -- Support both plain (%s/%d) and positional (%1$s/%2$d) placeholders.
  -- Keep %% (literal percent) intact.
  local s = globalString
  s = s:gsub("%%%%", "\0P\0")
  s = s:gsub("%%%d*%$?s", "\0S\0")
  s = s:gsub("%%%d*%$?d", "\0D\0")

  s = EscapeLuaPattern(s)

  s = s:gsub("\0S\0", "(.-)")
  -- Allow common thousands separators in numbers (locale dependent).
  -- Examples: 1,234  |  1 234  |  1.234  |  1'234
  s = s:gsub("\0D\0", "([%d,%.%s'%\194\160]+)")
  s = s:gsub("\0P\0", "%%")

  return "^" .. s .. "$"
end

local XP_PATTERN_KEYS = {
  -- Kill XP, unrested.
  "COMBATLOG_XPGAIN_FIRSTPERSON",
  -- Kill XP, explicit rested message (some clients/patches).
  "COMBATLOG_XPGAIN_FIRSTPERSON_RESTED",
  -- Kill XP, rested bonus.
  "COMBATLOG_XPGAIN_EXHAUSTION1",
  -- Some clients/patches expose other exhaustion variants.
  "COMBATLOG_XPGAIN_EXHAUSTION",
  "COMBATLOG_XPGAIN_EXHAUSTION2",
  -- Quest/objective XP (no mob name).
  "COMBATLOG_XPGAIN_FIRSTPERSON_UNNAMED",
}

local function BuildXPGainPatterns()
  local patterns = {}
  for _, k in ipairs(XP_PATTERN_KEYS) do
    local gs = _G and rawget(_G, k)
    local pat = GlobalStringToPatternPositional(gs)
    if pat then
      patterns[#patterns + 1] = { key = k, pat = pat }
    end
  end
  XP_PATTERNS = patterns
end

local function ParseRestedBonusFromParen(paren)
  if type(paren) ~= "string" or paren == "" then return nil end
  -- Examples:
  --   "(+47 exp Rested Bonus)"
  --   "(47 rested bonus)"
  --   "(+47 rested bonus)"
  -- Be tolerant of wording and capitalization.
  local low = paren:lower()
  local n = low:match("%+?%s*([%d,%.%s'%\194\160]+)%s*exp")
    or low:match("%+?%s*([%d,%.%s'%\194\160]+)%s*experience")
    or low:match("%+?%s*([%d,%.%s'%\194\160]+)")
  return n and ParseNumberFromChat(n) or nil
end

local function ParseExperienceGainMessage(msg)
  if type(msg) ~= "string" or msg == "" then return nil end

  -- Normalize whitespace a bit, but keep original mob text.
  local t = msg:gsub("\r", " "):gsub("\n", " ")
  -- Strip common chat formatting that can appear in system/combat messages.
  t = t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  t = t:gsub("|T.-|t", "")

  -- Normalize common Unicode spaces to ASCII spaces (NBSP, narrow NBSP, figure space).
  t = t:gsub("\194\160", " ")
  t = t:gsub("\226\128\175", " ")
  t = t:gsub("\226\128\135", " ")

  -- Normalize common lookalike punctuation.
  -- Fullwidth parentheses: （ ）
  t = t:gsub("\239\188\136", "(")
  t = t:gsub("\239\188\137", ")")

  t = t:gsub("%s+", " ")
  t = t:gsub("^%s+", ""):gsub("%s+$", "")

  -- Prefer Blizzard global-string patterns (localized + stable across punctuation changes).
  if not XP_PATTERNS then BuildXPGainPatterns() end
  for _, e in ipairs(XP_PATTERNS or {}) do
    local a, b, c = t:match(e.pat)
    if a then
      -- Patterns vary:
      --  - FIRSTPERSON:            mob, xp
      --  - EXHAUSTION1:            mob, xp, rested
      --  - FIRSTPERSON_UNNAMED:    xp
      local xp, mob, rested
      if ParseNumberFromChat(a) then
        xp = ParseNumberFromChat(a)
        rested = ParseNumberFromChat(b)
      else
        mob = a
        xp = ParseNumberFromChat(b)
        rested = ParseNumberFromChat(c)
      end

      if xp then
        local kind = "kill"
        if e.key == "COMBATLOG_XPGAIN_FIRSTPERSON_UNNAMED" then
          kind = "unnamed"
        end
        return { xp = xp, rested = rested, mob = mob, kind = kind, sourceKey = e.key }
      end
    end
  end

  -- Fallbacks for non-standard lines.
  -- 1) Mob kill line: "X dies, you gain N experience. (...)"
  do
    local mob, n, paren = t:match("^(.-)%s+dies[^%w]+you gain%s+([%d,%.%s'%\194\160]+)%s+experience[^%w%(]*%s*(%b())?%s*$")
    if mob and n then
      local xp = ParseNumberFromChat(n)
      if xp then
        local rested = ParseRestedBonusFromParen(paren)
        return { xp = xp, rested = rested, mob = mob, kind = "kill", sourceKey = "fallback-dies" }
      end
    end
  end

  -- 2) Generic/self line: "You gain N experience. (...)"
  do
    local n, paren = t:match("^You gain%s+([%d,%.%s'%\194\160]+)%s+experience[^%w%(]*%s*(%b())?%s*$")
    if n then
      local xp = ParseNumberFromChat(n)
      if xp then
        local rested = ParseRestedBonusFromParen(paren)
        return { xp = xp, rested = rested, kind = "unnamed", sourceKey = "fallback-you-gain" }
      end
    end
  end

  -- 3) Discovery XP (system): "Discovered Place: N experience gained"
  do
    local place, n = t:match("^Discovered%s+(.-)%s*:%s*([%d,%.%s'%\194\160]+)%s+experience gained%.?%s*$")
    if n then
      local xp = ParseNumberFromChat(n)
      if xp then
        if IsNonEmptyPublicString(place) then
          return { xp = xp, mob = place, kind = "discovery", sourceKey = "fallback-discovery" }
        end
        return { xp = xp, kind = "discovery", sourceKey = "fallback-discovery" }
      end
    end
  end

  -- 4) Very tolerant English fallback (and generally robust across punctuation/casing):
  --    Look for "you gain <n> experience" and optionally extract "<mob> dies".
  do
    local low = t:lower()
    if low:find("you gain", 1, true) and low:find("experience", 1, true) then
      local n = low:match("you gain%s+([%d,%.%s'%\194\160]+)%s+experience")
      if n then
        local xp = ParseNumberFromChat(n)
        if xp then
          local paren = t:match("(%b())")
          local rested = ParseRestedBonusFromParen(paren)

          local mob
          local diesAt = low:find(" dies", 1, true)
          if diesAt and diesAt > 1 then
            mob = t:sub(1, diesAt - 1)
            mob = mob:gsub("^%s+", ""):gsub("%s+$", "")
            if mob == "" then mob = nil end
          end

          local kind = mob and "kill" or "unnamed"
          return { xp = xp, rested = rested, mob = mob, kind = kind, sourceKey = "fallback-tolerant" }
        end
      end
    end
  end

  return nil
end

local function GetOtherSelfPrefix()
  local me = StripRealmFromName((UnitName and UnitName("player")) or "")
  if not IsNonEmptyPublicString(me) then
    me = "Character"
  end
  local colored = GetClassColoredName(me)
  if IsNonEmptyPublicString(colored) then
    return "<" .. colored .. ">"
  end
  return "<" .. me .. ">"
end

SafeNow = function()
  local now
  if type(GetTime) == "function" then
    local ok, v = pcall(GetTime)
    now = ok and tonumber(v) or nil
  end
  return now or 0
end

local _xpDbgLastTS
local function XPDebugEnabled()
  return (DB and DB.debugCapture) == true
end

local _xpLastXP
local _xpLastMaxXP
local _xpRecentPrintedTS
local _xpRecentPrintedDelta
local _xpPendingNoMatchTS
local _xpPendingNoMatchMsg
local _xpPendingNoMatchCleanMsg
local _xpPendingNoMatchEvent
local _xpPendingNoMatchToken
local _xpPendingNoMatchGuessXP
local _xpPendingNoMatchLiteSig
local _xpPendingNoMatchUseTimer
local _xpChatLastSig
local _xpChatLastTS
local _xpChatLastLiteSig
local _xpChatLastLiteTS
local _xpChatLastLiteHadInfo

local _xpChatPendingPreferredLiteSig
local _xpChatPendingPreferredUntilTS

local function GetExperienceOutputFrame()
  return (DB and DB.other and DB.other.experience and DB.other.experience.outputChatFrame)
    or (DB and DB.other and DB.other.outputChatFrame)
    or (DB and DB.outputChatFrame)
    or 1
end

local function GetProfessionOutputFrame()
  return (DB and DB.other and DB.other.profession and DB.other.profession.outputChatFrame)
    or (DB and DB.other and DB.other.outputChatFrame)
    or (DB and DB.outputChatFrame)
    or 1
end

local function GetInstanceOutputFrame()
  return (DB and DB.other and DB.other.instance and DB.other.instance.outputChatFrame)
    or (DB and DB.other and DB.other.outputChatFrame)
    or (DB and DB.outputChatFrame)
    or 1
end

local function ColorCodes()
  local close = rawget(_G, "FONT_COLOR_CODE_CLOSE") or "|r"
  -- IMPORTANT: NORMAL/HIGHLIGHT can be effectively white depending on chat theme.
  -- Prefer Blizzard's gold if present; otherwise use the canonical gold hex.
  local gold = rawget(_G, "GOLD_FONT_COLOR_CODE") or "|cffffd100"
  if type(gold) ~= "string" or gold == "" or gold:lower() == "|cffffffff" then
    gold = "|cffffd100"
  end

  local green = rawget(_G, "GREEN_FONT_COLOR_CODE") or "|cff20ff20"
  if type(green) ~= "string" or green == "" or green:lower() == "|cffffffff" then
    green = "|cff20ff20"
  end

  return gold, green, close
end

MaybePrintXPDebug = function(line)
  if not XPDebugEnabled() then return end
  if not IsNonEmptyPublicString(line) then return end

  -- Debug bursts (quest turn-ins can fire multiple XP-related events instantly).
  -- Default: allow a few lines per second.
  -- If debugCaptureStacks is enabled, do not throttle.
  local now = SafeNow()
  local noThrottle = (DB and DB.debugCaptureStacks) == true
  if (not noThrottle) and _xpDbgLastTS and (now - _xpDbgLastTS) < 0.12 then
    return
  end
  _xpDbgLastTS = now

  local dbgFrame = GetExperienceOutputFrame()
  PrintToChatFrame("[LootIt XP] " .. line, dbgFrame)
end

local function GetXPLabelPos()
  local pos = (DB and DB.other and DB.other.experience and DB.other.experience.xpLabelPos) or "after"
  pos = tostring(pos or "after"):lower():gsub("%s+", "")
  if pos ~= "before" and pos ~= "after" then pos = "after" end
  return pos
end

QuestXPEnabled = function()
  return (DB and DB.other and DB.other.experience and DB.other.experience.questXP) == true
end

local XP_NUM_WIDTH = 5
local XP_PAD_COLOR = "|cff555555"
local XP_PAD_CHAR = "0"

local function FormatXPNumberColored(x, numCC, close)
  x = tonumber(x) or 0
  x = math.floor(x)
  local s = tostring(x)

  -- Use dim 0-padding (not spaces) so the number block aligns in proportional fonts.
  -- Avoid "real" leading zeros by keeping them visually distinct.
  local padCount = XP_NUM_WIDTH - #s
  if padCount <= 0 then
    return string.format("%s%s%s", tostring(numCC or ""), s, tostring(close or ""))
  end

  local pad = XP_PAD_COLOR .. string.rep(XP_PAD_CHAR, padCount)
  return string.format("%s%s%s%s", pad, tostring(numCC or ""), s, tostring(close or ""))
end

local function FormatXPMainChunk(xp, xpPos, hcc, gcc, close)
  if xpPos == "before" then
    return string.format("%sXP%s %s", hcc, close, FormatXPNumberColored(xp, gcc, close))
  end
  return string.format("%s %sXP%s", FormatXPNumberColored(xp, gcc, close), hcc, close)
end

local function FormatXPBonusChunk(rested, xpPos, hcc, close)
  if xpPos == "before" then
    return string.format(" (%s+XP %s)", hcc, FormatXPNumberColored(rested, hcc, close))
  end
  return string.format(" (%s+%s %sXP%s)", hcc, FormatXPNumberColored(rested, hcc, close), hcc, close)
end

local function ShortXPMsg(s)
  if type(s) ~= "string" then return "" end
  -- sanitize a bit (strip color/texture; collapse whitespace)
  s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  s = s:gsub("|T.-|t", "")
  s = s:gsub("\194\160", " ")
  s = s:gsub("\226\128\175", " ")
  s = s:gsub("\226\128\135", " ")
  s = s:gsub("\239\188\136", "(")
  s = s:gsub("\239\188\137", ")")
  s = s:gsub("%s+", " ")
  s = s:gsub("^%s+", ""):gsub("%s+$", "")
  if #s > 90 then
    s = s:sub(1, 90) .. "…"
  end
  return s
end

local function CleanXPMsg(s)
  if type(s) ~= "string" then return "" end
  -- sanitize (strip color/texture; collapse whitespace) but do NOT truncate
  s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  s = s:gsub("|T.-|t", "")
  s = s:gsub("\194\160", " ")
  s = s:gsub("\226\128\175", " ")
  s = s:gsub("\226\128\135", " ")
  s = s:gsub("\239\188\136", "(")
  s = s:gsub("\239\188\137", ")")
  s = s:gsub("%s+", " ")
  s = s:gsub("^%s+", ""):gsub("%s+$", "")
  return s
end

local function GuessXPFromXPishLine(cleanMsg)
  if type(cleanMsg) ~= "string" or cleanMsg == "" then return nil end

  local t = cleanMsg
  local low = t:lower()
  if not (low:find("experience", 1, true) or low:find(" exp", 1, true) or low:find("discovered", 1, true)) then
    return nil
  end

  -- Try common quest/system variants first.
  local n = low:match("^experience gained:%s*([%d,%.%s'%\194\160]+)")
    or low:match("experience gained:%s*([%d,%.%s'%\194\160]+)")
    or low:match("you gain%s+([%d,%.%s'%\194\160]+)%s+experience")
    or low:match("([%d,%.%s'%\194\160]+)%s+experience")

  local xp = n and ParseNumberFromChat(n) or nil
  if xp and xp > 0 then
    return xp
  end
  return nil
end

local _xpQuestLastTS
local _xpQuestLastTitle
local _xpQuestLastXP

local QUEST_XP_ATTACH_WINDOW = 10.0
local QUEST_XP_COMPLETED_FALLBACK_DELAY = 10.25

local _xpQuestCompletedLastTS
local _xpQuestCompletedLastTitle

local function GetQuestTitleSafe(questID)
  questID = tonumber(questID)
  if not questID then return nil end

  if C_QuestLog and type(C_QuestLog.GetTitleForQuestID) == "function" then
    local ok, title = pcall(C_QuestLog.GetTitleForQuestID, questID)
    if ok and IsNonEmptyPublicString(title) then
      return title
    end
  end

  return nil
end

local function GetRecentQuestTitleForXP(xp)
  local title = _xpQuestLastTitle
  if not IsNonEmptyPublicString(title) then return nil end

  local now = SafeNow()
  if not (_xpQuestLastTS and (now - _xpQuestLastTS) <= QUEST_XP_ATTACH_WINDOW) then
    return nil
  end

  local qxp = tonumber(_xpQuestLastXP)
  xp = tonumber(xp)
  if qxp and xp and qxp > 0 and xp > 0 and qxp ~= xp then
    -- xpReward from QUEST_TURNED_IN can differ from the final XP gain message
    -- due to various bonuses; tolerate small/moderate drift.
    local diff = math.abs(qxp - xp)
    local maxv = math.max(qxp, xp)
    if maxv > 0 and (diff / maxv) > 0.30 then
      return nil
    end
  end

  return title
end

local function GetRecentQuestCompletedTitle()
  local title = _xpQuestCompletedLastTitle
  if not IsNonEmptyPublicString(title) then return nil end

  local now = SafeNow()
  if not (_xpQuestCompletedLastTS and (now - _xpQuestCompletedLastTS) <= 2.5) then
    return nil
  end

  -- One-shot: consume so it won't attach to unrelated XP lines.
  _xpQuestCompletedLastTS = nil
  _xpQuestCompletedLastTitle = nil
  return title
end

local _xpQuestCompletedFallbackToken = 0
ScheduleQuestCompletedFallbackPrint = function(ts, title)
  -- Intentionally disabled: quest completion system lines are always hidden,
  -- and we only display the quest title when it can be appended onto an XP line.
  -- If no XP line occurs, do not print a fallback completion line.
  _xpQuestCompletedFallbackToken = (_xpQuestCompletedFallbackToken or 0) + 1
end

local _xpQuestDelayedToken = 0
local _xpQuestDelayed = {}
local _xpQuestDelayedByLite = {}

do
  if type(CreateFrame) == "function" then
    local qev = CreateFrame("Frame")
    qev:RegisterEvent("QUEST_TURNED_IN")
    qev:SetScript("OnEvent", function(_, _, questID, xpReward)
      _xpQuestLastTS = SafeNow()
      _xpQuestLastXP = tonumber(xpReward)
      local t = GetQuestTitleSafe(questID)
      -- Don't erase a title we captured from system messages if the quest log API
      -- can't resolve the title (cache/timing).
      if IsNonEmptyPublicString(t) then
        _xpQuestLastTitle = t
      end
    end)
  end
end

local function OnExperienceChat(_, eventName, msg, ...)
  EnsureRefs()
  DebugBumpEvent(tostring(eventName or "CHAT_MSG_COMBAT_XP_GAIN"))
  if not (DB and DB.other and DB.other.experience and DB.other.experience.enabled) then
    return false
  end
  if type(msg) == "string" and IsSecretString(msg) then
    DebugBumpSecret(tostring(eventName or "CHAT_MSG_COMBAT_XP_GAIN"))
    if LootChat.CaptureEnabled() then
      LootChat.CaptureAppend("CHAT_SECRET", { event = tostring(eventName or "CHAT_MSG_COMBAT_XP_GAIN") })
    end
    return false
  end
  if not IsNonEmptyPublicString(msg) then
    return false
  end

  local ev = (type(eventName) == "string" and eventName ~= "") and eventName or "CHAT_MSG_COMBAT_XP_GAIN"

  -- CHAT_MSG_SYSTEM / CHAT_MSG_COMBAT_MISC_INFO can contain lots of unrelated lines.
  -- Only attempt parse when the line looks XP-related (keeps debug and avoids suppressing
  -- unrelated misc system lines).
  if ev == "CHAT_MSG_SYSTEM" or ev == "CHAT_MSG_COMBAT_MISC_INFO" then
    local low = msg:lower()
    if not (low:find("experience", 1, true) or low:find(" exp", 1, true) or low:find("discovered", 1, true)) then
      return false
    end
  end
  LootChat.CaptureChatIn(ev, msg)

  local parsed = ParseExperienceGainMessage(msg)
  if not parsed then
    local now = SafeNow()
    _xpPendingNoMatchTS = now
    _xpPendingNoMatchMsg = msg
    _xpPendingNoMatchCleanMsg = CleanXPMsg(msg)
    _xpPendingNoMatchEvent = ev

    -- Special handling for quest turn-ins: some clients emit *two* Blizzard XP messages
    -- (one system-side, one combat/chat-side). If the system-side line doesn't parse,
    -- the old XP_UPDATE fallback can race and print a second line before our other-source
    -- output (especially when we delay briefly to attach the quest title).
    --
    -- For system no-match XP lines, schedule our own very short fallback print that:
    --  - cancels itself if we already printed (or have a delayed print pending) for the same XP
    --  - prevents XP_UPDATE from printing in the meantime
    do
      _xpPendingNoMatchGuessXP = nil
      _xpPendingNoMatchLiteSig = nil
      _xpPendingNoMatchUseTimer = nil

      if ev == "CHAT_MSG_SYSTEM" then
        local guessXP = GuessXPFromXPishLine(_xpPendingNoMatchCleanMsg)
        if guessXP and guessXP > 0 and type(C_Timer) == "table" and type(C_Timer.After) == "function" then
          local lite = tostring(guessXP) .. "|0"
          _xpPendingNoMatchGuessXP = guessXP
          _xpPendingNoMatchLiteSig = lite
          _xpPendingNoMatchUseTimer = true

          -- Prefer the upcoming formatted (quest-title) output over a plain duplicate
          -- from the other Blizzard XP source while we wait.
          _xpChatPendingPreferredLiteSig = lite
          _xpChatPendingPreferredUntilTS = SafeNow() + 0.45

          MaybePrintXPDebug(string.format(
            "no-match(system) guessXP=%d lite=%s preferUntil=+0.45 msg='%s'",
            guessXP, lite, ShortXPMsg(_xpPendingNoMatchCleanMsg)
          ))

          _xpPendingNoMatchToken = (_xpPendingNoMatchToken or 0) + 1
          local token = _xpPendingNoMatchToken

          MaybePrintXPDebug(string.format("no-match-timer scheduled token=%d xp=%d lite=%s", token, guessXP, lite))

          C_Timer.After(0.30, function()
            -- Only act if this is still the latest pending no-match.
            if token ~= _xpPendingNoMatchToken then return end

            local now2 = SafeNow()
            if not (_xpPendingNoMatchTS and (now2 - _xpPendingNoMatchTS) < 1.0) then return end
            EnsureRefs()
            if not (DB and DB.other and DB.other.experience and DB.other.experience.enabled) then return end

            local xp2 = _xpPendingNoMatchGuessXP
            if not xp2 or xp2 <= 0 then return end
            local lite2 = tostring(xp2) .. "|0"

            -- If we already printed this XP, or have an informative delayed print pending, don't emit.
            if _xpRecentPrintedTS and (now2 - _xpRecentPrintedTS) < 0.90 and _xpRecentPrintedDelta == xp2 then
              MaybePrintXPDebug(string.format("no-match-timer cancel: recentPrinted xp=%d", xp2))
              _xpPendingNoMatchTS = nil
              _xpPendingNoMatchMsg = nil
              _xpPendingNoMatchCleanMsg = nil
              _xpPendingNoMatchEvent = nil
              _xpPendingNoMatchGuessXP = nil
              _xpPendingNoMatchLiteSig = nil
              _xpPendingNoMatchUseTimer = nil
              return
            end
            do
              local pendingToken = _xpQuestDelayedByLite and _xpQuestDelayedByLite[lite2]
              if pendingToken and _xpQuestDelayed and _xpQuestDelayed[pendingToken] then
                MaybePrintXPDebug(string.format("no-match-timer cancel: pendingQuestDelayed xp=%d lite=%s", xp2, lite2))
                _xpPendingNoMatchTS = nil
                _xpPendingNoMatchMsg = nil
                _xpPendingNoMatchCleanMsg = nil
                _xpPendingNoMatchEvent = nil
                _xpPendingNoMatchGuessXP = nil
                _xpPendingNoMatchLiteSig = nil
                _xpPendingNoMatchUseTimer = nil
                return
              end
            end
            if _xpChatPendingPreferredLiteSig == lite2 and _xpChatPendingPreferredUntilTS and now2 <= _xpChatPendingPreferredUntilTS then
              MaybePrintXPDebug(string.format("no-match-timer cancel: pendingPreferred xp=%d lite=%s", xp2, lite2))
              _xpPendingNoMatchTS = nil
              _xpPendingNoMatchMsg = nil
              _xpPendingNoMatchCleanMsg = nil
              _xpPendingNoMatchEvent = nil
              _xpPendingNoMatchGuessXP = nil
              _xpPendingNoMatchLiteSig = nil
              _xpPendingNoMatchUseTimer = nil
              return
            end
            if _xpChatLastLiteSig == lite2 and _xpChatLastLiteTS and (now2 - _xpChatLastLiteTS) < 0.50 and _xpChatLastLiteHadInfo == true then
              MaybePrintXPDebug(string.format("no-match-timer cancel: lastLiteHadInfo xp=%d lite=%s", xp2, lite2))
              _xpPendingNoMatchTS = nil
              _xpPendingNoMatchMsg = nil
              _xpPendingNoMatchCleanMsg = nil
              _xpPendingNoMatchEvent = nil
              _xpPendingNoMatchGuessXP = nil
              _xpPendingNoMatchLiteSig = nil
              _xpPendingNoMatchUseTimer = nil
              return
            end

            -- Emit a single fallback line (formatted) and try to attach quest title if available.
            local hcc, gcc, close = ColorCodes()
            local xpPos = GetXPLabelPos()
            local outText = FormatXPMainChunk(xp2, xpPos, hcc, gcc, close)
            if QuestXPEnabled() then
              local qTitle = GetRecentQuestTitleForXP(xp2)
              if IsNonEmptyPublicString(qTitle) then
                outText = outText .. "  |cffffffff" .. qTitle .. close
                _xpQuestLastTS = nil
                _xpQuestLastTitle = nil
                _xpQuestLastXP = nil
              end
            end

            local out = FormatSelfLine(outText)
            local outFrame = GetExperienceOutputFrame()
            PrintToChatFrame(out, outFrame)
            _xpRecentPrintedTS = now2
            _xpRecentPrintedDelta = xp2

            MaybePrintXPDebug(string.format("out(no-match-timer)->%s %s", tostring(outFrame), tostring(out)))
            LootChat.CaptureChatOut("CHAT_MSG_SYSTEM", out, {
              handled = true,
              xp = xp2,
              xpNoMatch = true,
              xpNoMatchTimer = true,
              outFrame = outFrame,
            })

            _xpPendingNoMatchTS = nil
            _xpPendingNoMatchMsg = nil
            _xpPendingNoMatchCleanMsg = nil
            _xpPendingNoMatchEvent = nil
            _xpPendingNoMatchGuessXP = nil
            _xpPendingNoMatchLiteSig = nil
            _xpPendingNoMatchUseTimer = nil
          end)
        end
      end
    end

    LootChat.CaptureChatOut(ev, "(xp) no-match", { handled = false, xpNoMatch = true })
    MaybePrintXPDebug(string.format("no-match (event=%s) msg='%s'", tostring(ev), ShortXPMsg(msg)))

    -- If we leave the original line visible, the XP_UPDATE fallback prints a second line.
    -- Suppress here so the player sees only one XP line.
    return true
  end
  local xp = parsed.xp
  local rested = parsed.rested
  local mob = parsed.mob
  local kind = parsed.kind

  local showBonus = true
  if DB and DB.other and DB.other.experience and DB.other.experience.showBonus ~= nil then
    showBonus = (DB.other.experience.showBonus == true)
  end

  local hcc, gcc, close = ColorCodes()
  local xpPos = GetXPLabelPos()

  local attachedQuestTitle = false

  -- Main XP number in green; literal "XP" (and bonus marker/chunk) in gold.
  local outText = FormatXPMainChunk(xp, xpPos, hcc, gcc, close)
  if rested and rested > 0 then
    if showBonus then
      outText = outText .. FormatXPBonusChunk(rested, xpPos, hcc, close)
    else
      outText = outText .. string.format("%s*%s", hcc, close)
    end
  end
  do
    if type(mob) == "string" and mob ~= "" then
      mob = mob:gsub("^%s+", ""):gsub("%s+$", "")
      if mob ~= "" then
        if kind == "discovery" then
          -- Discovery XP: treat the place name like a proper label (extra spacing + light-blue).
          outText = outText .. "  |cff66ccff" .. mob .. close
        else
          outText = outText .. " " .. mob
        end
      end
    end

    -- Quest completion titles should attach to the next *unnamed* XP line.
    -- Some clients use XP patterns we don't have a key for; in that case, infer
    -- unnamed vs kill from whether we have a mob string.
    local effectiveKind = kind
    if effectiveKind == nil then
      effectiveKind = (type(mob) == "string" and mob ~= "") and "kill" or "unnamed"
    end

    if QuestXPEnabled() and effectiveKind == "unnamed" then
      local qTitle = GetRecentQuestTitleForXP(xp)
      if IsNonEmptyPublicString(qTitle) then
        outText = outText .. "  |cffffffff" .. qTitle .. close
        attachedQuestTitle = true
        _xpQuestLastTS = nil
        _xpQuestLastTitle = nil
        _xpQuestLastXP = nil
      else
        -- Some clients emit the XP line before the quest-completed system line.
        -- Delay printing very briefly so a completion that arrives just after can
        -- still be appended onto the XP line.
        if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
          -- De-dupe before scheduling so repeated events don't queue multiple prints.
          do
            local now = SafeNow()
            local sig = tostring(xp or 0) .. "|" .. tostring(rested or 0) .. "|" .. tostring(mob or "")
            if _xpChatLastSig == sig and _xpChatLastTS and (now - _xpChatLastTS) < 0.35 then
              MaybePrintXPDebug(string.format("dedup (event=%s) sig=%s", tostring(ev), sig))
              return true
            end
            _xpChatLastSig = sig
            _xpChatLastTS = now
          end

          local liteSig = tostring(xp or 0) .. "|" .. tostring(rested or 0)
          do
            -- If a delayed print is already pending for this exact XP amount, don't queue another.
            -- This is the common case when two Blizzard XP sources fire for the same quest turn-in.
            local pendingToken = _xpQuestDelayedByLite and _xpQuestDelayedByLite[liteSig]
            if pendingToken and _xpQuestDelayed and _xpQuestDelayed[pendingToken] then
              MaybePrintXPDebug(string.format("dedup-delayed (event=%s) sig=%s", tostring(ev), liteSig))
              LootChat.CaptureChatOut(ev, "(xp) suppressed", {
                handled = true,
                xp = xp,
                rested = rested,
                mob = mob,
                xpDelayed = true,
                suppressedPendingDelayed = true,
              })
              return true
            end
          end

          local outFrame = (DB.other and DB.other.experience and DB.other.experience.outputChatFrame)
            or (DB.other and DB.other.outputChatFrame)
            or (DB and DB.outputChatFrame)
            or 1

          _xpQuestDelayedToken = (_xpQuestDelayedToken or 0) + 1
          local token = _xpQuestDelayedToken
          _xpQuestDelayed[token] = {
            xp = xp,
            rested = rested,
            mob = mob,
            baseOutText = outText,
            outFrame = outFrame,
            ev = ev,
          }
          _xpQuestDelayedByLite[liteSig] = token

          do
            -- While we wait briefly for a quest title to arrive, suppress a plain duplicate
            -- XP line from the other source (same xp/rested) to avoid double prints.
            _xpChatPendingPreferredLiteSig = liteSig
            _xpChatPendingPreferredUntilTS = SafeNow() + 0.30
          end

          C_Timer.After(0.25, function()
            local entry = _xpQuestDelayed and _xpQuestDelayed[token]
            if not entry then return end
            _xpQuestDelayed[token] = nil

            do
              local lite = tostring(entry.xp or 0) .. "|" .. tostring(entry.rested or 0)
              if _xpQuestDelayedByLite and _xpQuestDelayedByLite[lite] == token then
                _xpQuestDelayedByLite[lite] = nil
              end
            end

            -- Clear pending suppression window now that we're about to emit.
            _xpChatPendingPreferredLiteSig = nil
            _xpChatPendingPreferredUntilTS = nil

            EnsureRefs()
            if not (DB and DB.other and DB.other.experience and DB.other.experience.enabled) then return end

            local finalText = entry.baseOutText
            local delayedAttachedQuestTitle = false
            if QuestXPEnabled() then
              local t = GetRecentQuestTitleForXP(entry.xp)
              if IsNonEmptyPublicString(t) then
                finalText = finalText .. "  |cffffffff" .. t .. close
                delayedAttachedQuestTitle = true
                _xpQuestLastTS = nil
                _xpQuestLastTitle = nil
                _xpQuestLastXP = nil
              end
            end

            local out = FormatSelfLine(finalText)
            PrintToChatFrame(out, entry.outFrame)
            do
              local now = SafeNow()
              _xpRecentPrintedTS = now
              _xpRecentPrintedDelta = entry.xp

              -- Mark this as the most recent "lite" XP variant. If it carried extra info
              -- (mob label or quest title), we can suppress a plain duplicate that follows.
              local lite = tostring(entry.xp or 0) .. "|" .. tostring(entry.rested or 0)
              local hasInfo = IsNonEmptyPublicString(entry.mob) or delayedAttachedQuestTitle
              _xpChatLastLiteSig = lite
              _xpChatLastLiteTS = now
              _xpChatLastLiteHadInfo = hasInfo and true or false
            end
            MaybePrintXPDebug(string.format("out(delayed)->%s %s", tostring(entry.outFrame), tostring(out)))
            LootChat.CaptureChatOut(entry.ev or "CHAT_MSG_COMBAT_XP_GAIN", out, {
              handled = true,
              xp = entry.xp,
              rested = entry.rested,
              mob = entry.mob,
              outFrame = entry.outFrame,
              xpDelayed = true,
            })
          end)

          MaybePrintXPDebug(string.format("xp delayed (quest-title-wait) xp=%d lite=%s event=%s", tonumber(xp) or 0, tostring(liteSig), tostring(ev)))
          LootChat.CaptureChatOut(ev, "(xp) delayed", { handled = true, xp = xp, rested = rested, mob = mob, xpDelayed = true })
          return true
        end
      end
    end
  end

  -- De-dupe: some clients fire the same XP text on multiple events (e.g. COMBAT_XP_GAIN + COMBAT_MISC_INFO).
  -- We swallow duplicates but only print once.
  do
    local now = SafeNow()
    local sig = tostring(xp or 0) .. "|" .. tostring(rested or 0) .. "|" .. tostring(mob or "")
    if _xpChatLastSig == sig and _xpChatLastTS and (now - _xpChatLastTS) < 0.35 then
      MaybePrintXPDebug(string.format("dedup (event=%s) sig=%s", tostring(ev), sig))
      return true
    end

    -- Some clients emit two variants back-to-back: one with a mob/source label and one without.
    -- Prefer the more informative line; suppress the plain one if the XP amount matches.
    do
      local lite = tostring(xp or 0) .. "|" .. tostring(rested or 0)
      local hasInfo = IsNonEmptyPublicString(mob) or attachedQuestTitle

      if (not hasInfo) and _xpChatPendingPreferredLiteSig == lite and _xpChatPendingPreferredUntilTS and now <= _xpChatPendingPreferredUntilTS then
        MaybePrintXPDebug(string.format("dedup-pending (event=%s) sig=%s", tostring(ev), lite))
        return true
      end

      if (not hasInfo) and _xpChatLastLiteSig == lite and _xpChatLastLiteTS and (now - _xpChatLastLiteTS) < 0.40 and _xpChatLastLiteHadInfo == true then
        MaybePrintXPDebug(string.format("dedup-lite (event=%s) sig=%s", tostring(ev), lite))
        return true
      end
      _xpChatLastLiteSig = lite
      _xpChatLastLiteTS = now
      _xpChatLastLiteHadInfo = hasInfo and true or false
    end

    _xpChatLastSig = sig
    _xpChatLastTS = now
  end

  -- If we have a pending delayed print for this same XP amount, cancel it now.
  -- This prevents the pattern: first source schedules delayed -> second source prints immediately -> delayed prints again.
  do
    local lite = tostring(xp or 0) .. "|" .. tostring(rested or 0)
    local pendingToken = _xpQuestDelayedByLite and _xpQuestDelayedByLite[lite]
    if pendingToken and _xpQuestDelayed and _xpQuestDelayed[pendingToken] then
      _xpQuestDelayed[pendingToken] = nil
      _xpQuestDelayedByLite[lite] = nil
      MaybePrintXPDebug(string.format("cancel-delayed (event=%s) sig=%s", tostring(ev), lite))
    end
  end

  local out = FormatSelfLine(outText)

  local outFrame = (DB.other and DB.other.experience and DB.other.experience.outputChatFrame)
    or (DB.other and DB.other.outputChatFrame)
    or (DB and DB.outputChatFrame)
    or 1
  PrintToChatFrame(out, outFrame)

  do
    local now = SafeNow()
    _xpRecentPrintedTS = now
    _xpRecentPrintedDelta = xp
  end

  MaybePrintXPDebug(string.format("out->%s %s", tostring(outFrame), tostring(out)))

  LootChat.CaptureChatOut(ev, out, {
    handled = true,
    xp = xp,
    rested = rested,
    mob = mob,
    outFrame = outFrame,
  })

  return true
end

function LootChat.OnPlayerXPUpdate()
  EnsureRefs()
  if type(UnitXP) ~= "function" or type(UnitXPMax) ~= "function" then
    return
  end

  local cur = tonumber(UnitXP("player") or 0)
  local max = tonumber(UnitXPMax("player") or 0)

  -- Always update caches so enabling XP later doesn't print a huge backlog.
  if _xpLastXP == nil then
    _xpLastXP = cur
    _xpLastMaxXP = max
    return
  end

  local delta = cur - (_xpLastXP or 0)
  if delta < 0 and (_xpLastMaxXP or 0) > 0 then
    -- Level-up rollover.
    delta = (_xpLastMaxXP - (_xpLastXP or 0)) + cur
  end

  _xpLastXP = cur
  _xpLastMaxXP = max

  if not (DB and DB.other and DB.other.experience and DB.other.experience.enabled) then
    return
  end
  if not delta or delta <= 0 then
    local now = SafeNow()
    if _xpPendingNoMatchTS and (now - _xpPendingNoMatchTS) < 1.0 then
      -- If we're handling a system XP no-match via the short timer fallback,
      -- do NOT print the raw pending message here (that raw message is exactly
      -- the duplicate you see as "Experience gained: ...").
      if _xpPendingNoMatchUseTimer == true then
        MaybePrintXPDebug("xpupdate(drop raw no-match; timer mode)")
        return
      end

      -- If we already printed a real XP line for this same gain, do NOT print the
      -- stored raw no-match message (this is the quest turn-in duplication case).
      do
        local clean = _xpPendingNoMatchCleanMsg or CleanXPMsg(_xpPendingNoMatchMsg)
        local guessXP = GuessXPFromXPishLine(clean)
        if guessXP and guessXP > 0 and _xpRecentPrintedTS and (now - _xpRecentPrintedTS) < 0.90 and _xpRecentPrintedDelta == guessXP then
          -- Invalidate any pending timer callback as well.
          _xpPendingNoMatchToken = (_xpPendingNoMatchToken or 0) + 1
          _xpPendingNoMatchTS = nil
          _xpPendingNoMatchMsg = nil
          _xpPendingNoMatchCleanMsg = nil
          _xpPendingNoMatchEvent = nil
          _xpPendingNoMatchGuessXP = nil
          _xpPendingNoMatchLiteSig = nil
          _xpPendingNoMatchUseTimer = nil
          MaybePrintXPDebug(string.format("drop(no-match-msg already-printed) xp=%d", guessXP))
          return
        end
      end

      local msg = _xpPendingNoMatchCleanMsg or CleanXPMsg(_xpPendingNoMatchMsg)
      local ev = _xpPendingNoMatchEvent or "CHAT_MSG_COMBAT_XP_GAIN"
      _xpPendingNoMatchTS = nil
      _xpPendingNoMatchMsg = nil
      _xpPendingNoMatchCleanMsg = nil
      _xpPendingNoMatchEvent = nil

      if IsNonEmptyPublicString(msg) then
        local outFrame = GetExperienceOutputFrame()
        local out = FormatSelfLine(msg)
        PrintToChatFrame(out, outFrame)
        MaybePrintXPDebug(string.format("fallback-print-msg (event=%s) msg='%s' out->%s %s", tostring(ev), ShortXPMsg(msg), tostring(outFrame), tostring(out)))
        LootChat.CaptureChatOut("PLAYER_XP_UPDATE", out, {
          handled = true,
          xp = 0,
          xpUpdateFallback = true,
          fromEvent = ev,
          msg = ShortXPMsg(msg),
          outFrame = outFrame,
          xpUpdatePrintedMsg = true,
        })
      end
    end
    return
  end

  local now = SafeNow()

  -- If we have a pending no-match system XP line that is being handled by the short
  -- timer fallback, do not also print via XP_UPDATE (prevents double prints on quest turn-ins).
  if _xpPendingNoMatchUseTimer == true and _xpPendingNoMatchTS and (now - _xpPendingNoMatchTS) < 1.0 then
    return
  end

  -- Suppress duplicates when we already printed from the chat filter.
  if _xpRecentPrintedTS and (now - _xpRecentPrintedTS) < 0.75 and _xpRecentPrintedDelta == delta then
    return
  end

  -- Only use XP_UPDATE as a fallback when a recent XP chat line failed to parse.
  if not (_xpPendingNoMatchTS and (now - _xpPendingNoMatchTS) < 1.0) then
    return
  end

  local msg = _xpPendingNoMatchMsg
  local ev = _xpPendingNoMatchEvent or "CHAT_MSG_COMBAT_XP_GAIN"
  _xpPendingNoMatchTS = nil
  _xpPendingNoMatchMsg = nil
  _xpPendingNoMatchCleanMsg = nil
  _xpPendingNoMatchEvent = nil

  local hcc, gcc, close = ColorCodes()
  local xpPos = GetXPLabelPos()
  local outText = FormatXPMainChunk(delta, xpPos, hcc, gcc, close)
  do
    if QuestXPEnabled() then
      -- XP_UPDATE fallback always represents an unnamed gain; safe to attach.
      local qTitle = GetRecentQuestTitleForXP(delta)
      if IsNonEmptyPublicString(qTitle) then
        outText = outText .. " " .. qTitle
        _xpQuestLastTS = nil
        _xpQuestLastTitle = nil
        _xpQuestLastXP = nil
      end
    end
  end
  local out = FormatSelfLine(outText)

  local outFrame = GetExperienceOutputFrame()
  PrintToChatFrame(out, outFrame)

  MaybePrintXPDebug(string.format("fallback-xpupdate (event=%s) delta=%d msg='%s' out->%s %s", tostring(ev), delta, ShortXPMsg(msg), tostring(outFrame), tostring(out)))
  LootChat.CaptureChatOut("PLAYER_XP_UPDATE", out, {
    handled = true,
    xp = delta,
    xpUpdateFallback = true,
    fromEvent = ev,
    msg = ShortXPMsg(msg),
    outFrame = outFrame,
  })
end

local SKILL_PATTERN_KEYS = {
  "SKILL_RANK_UP",
  "SKILL_LEARNED",
}

local SKILL_PATTERNS
local function BuildSkillPatterns()
  local patterns = {}
  for _, k in ipairs(SKILL_PATTERN_KEYS) do
    local gs = _G and rawget(_G, k)
    local pat = GlobalStringToPatternPositional(gs)
    if pat then
      patterns[#patterns + 1] = { key = k, pat = pat }
    end
  end
  SKILL_PATTERNS = patterns
end

local function ParseSkillMessage(msg)
  if type(msg) ~= "string" or msg == "" then return nil end

  local t = msg:gsub("\r", " "):gsub("\n", " ")
  t = t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  t = t:gsub("|T.-|t", "")

  t = t:gsub("\194\160", " ")
  t = t:gsub("\226\128\175", " ")
  t = t:gsub("\226\128\135", " ")
  t = t:gsub("\239\188\136", "(")
  t = t:gsub("\239\188\137", ")")

  t = t:gsub("%s+", " ")
  t = t:gsub("^%s+", ""):gsub("%s+$", "")

  if not SKILL_PATTERNS then BuildSkillPatterns() end
  for _, e in ipairs(SKILL_PATTERNS or {}) do
    local a, b, c = t:match(e.pat)
    if a then
      if e.key == "SKILL_RANK_UP" then
        local skill = a
        local rank = ParseNumberFromChat(b)
        if IsNonEmptyPublicString(skill) and rank then
          return { skill = skill, rank = rank }
        end
      elseif e.key == "SKILL_LEARNED" then
        local skill = a
        if IsNonEmptyPublicString(skill) then
          return { skill = skill, learned = true }
        end
      end
    end
  end

  -- Fallbacks (English-like) for clients where the global string keys differ.
  do
    local skill, rank = t:match("^Your skill in%s+(.-)%s+has increased to%s+(%d+)%.%s*$")
    if skill and rank then
      local n = ParseNumberFromChat(rank)
      if n and IsNonEmptyPublicString(skill) then
        return { skill = skill, rank = n }
      end
    end
  end
  do
    local skill = t:match("^You have gained the%s+(.-)%s+skill%.%s*$")
    if skill and IsNonEmptyPublicString(skill) then
      return { skill = skill, learned = true }
    end
  end

  return nil
end

local _skillLastSig
local _skillLastTS
local _skillLastRankByName
local _learnedItemLastSig
local _learnedItemLastTS

local function GetProfessionRankCache()
  -- Persist per-character so the first rank-up after /reload can still show +Δ.
  if CHARDB and type(CHARDB.otherProfessionRanks) ~= "table" then
    CHARDB.otherProfessionRanks = {}
  end
  if CHARDB and type(CHARDB.otherProfessionRanks) == "table" then
    _skillLastRankByName = CHARDB.otherProfessionRanks
    return CHARDB.otherProfessionRanks
  end
  _skillLastRankByName = _skillLastRankByName or {}
  return _skillLastRankByName
end

local function ParseLearnedItemMessage(msg)
  if type(msg) ~= "string" or msg == "" then return nil end

  -- Prefer an item link if present (some clients/chat settings may include it).
  local link = msg:match("You have learned how to create a new item:%s*(|c%x+|Hitem:.-|h%[.-%]|h|r)")
    or msg:match("You have learned how to create a new item:%s*(|Hitem:.-|h%[.-%]|h)")
  if link and link ~= "" then
    return { display = link }
  end

  local name = msg:match("^You have learned how to create a new item:%s*(.-)%.%s*$")
    or msg:match("^You have learned how to create a new item:%s*(.-)%s*$")
  if name and name ~= "" then
    return { display = name }
  end

  return nil
end

local function ParseInstanceSystemMessage(msg)
  if type(msg) ~= "string" or msg == "" then return nil end

  local t = msg:gsub("\r", " "):gsub("\n", " ")
  t = t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  t = t:gsub("|H.-|h(.-)|h", "%1")
  t = t:gsub("|T.-|t", "")

  t = t:gsub("\194\160", " ")
  t = t:gsub("\226\128\175", " ")
  t = t:gsub("\226\128\135", " ")
  t = t:gsub("\239\188\136", "(")
  t = t:gsub("\239\188\137", ")")

  t = t:gsub("%s+", " ")
  t = t:gsub("^%s+", ""):gsub("%s+$", "")

  local name = t:match("^(.-)%s+has left the instance group%.?$")
  if IsNonEmptyPublicString(name) then
    return { kind = "member_left", name = name }
  end

  if t:lower():match("^you leave the group%.?$") then
    return { kind = "you_leave" }
  end

  if t:lower():match("^you are now queued in the dungeon finder%.?$") then
    return { kind = "queued" }
  end

  if t:lower():match("^you are queued for too many instances%.?$") then
    return { kind = "queue_limit" }
  end

  if t:lower():match("^you don't meet the requirements for that quest%.?$") then
    return { kind = "quest_requirements_fail" }
  end

  do
    local v = t:match("^You are now Away:%s*(.-)%s*%.?$")
    if IsNonEmptyPublicString(v) then
      return { kind = "away", value = v }
    end
  end

  do
    local name = t:match("^%[?(.-)%]?%s+has gone offline%.?$")
    if IsNonEmptyPublicString(name) then
      return { kind = "went_offline", name = name }
    end
  end

  do
    local name = t:match("^%[?(.-)%]?%s+has come online%.?$")
    if IsNonEmptyPublicString(name) then
      return { kind = "came_online", name = name }
    end
  end

  if t:lower():match("^someone has declined the invite%. you have been returned to the front of the queue%.?$") then
    return { kind = "queue_returned_front" }
  end

  if t:lower():match("^you have been removed from the queue because you did not accept the invitation%.?$") then
    return { kind = "queue_removed_no_accept" }
  end

  do
    local v = t:match("^Dungeon Difficulty set to%s+(.+)%.?$")
    if IsNonEmptyPublicString(v) then
      return { kind = "dungeon_difficulty", value = v }
    end
  end

  do
    local v = t:match("^Looting set to%s+(.+)%.?$")
    if IsNonEmptyPublicString(v) then
      return { kind = "looting_mode", value = v }
    end
  end

  do
    local v = t:match("^Loot threshold set to%s+(.+)%.?$")
    if IsNonEmptyPublicString(v) then
      return { kind = "loot_threshold", value = v }
    end
  end

  do
    local v = t:match("^Loot%s+Specialization%s+set%s+to:?%s*(.+)%.?$")
      or t:match("^Loot%s+specialization%s+set%s+to:?%s*(.+)%.?$")
    if IsNonEmptyPublicString(v) then
      return { kind = "loot_specialization", value = v }
    end
  end

  if t:lower():match("^you aren't in a party%.?$") then
    return { kind = "not_in_party" }
  end

  do
    local name = t:match("^(.-)%s+is now the leader of your group!?%s*$")
      or t:match("^(.-)%s+is now the leader of your party!?%s*$")
      or t:match("^(.-)%s+is now the group leader%.?%s*$")
      or t:match("^(.-)%s+is now the party leader%.?%s*$")
    if IsNonEmptyPublicString(name) then
      return { kind = "group_leader", name = name }
    end
  end

  if t:lower():match("^you are now the leader of your group!?%s*$")
    or t:lower():match("^you are now the leader of your party!?%s*$")
    or t:lower():match("^you are now the group leader%.?%s*$")
    or t:lower():match("^you are now the party leader%.?%s*$") then
    return { kind = "group_leader_self" }
  end

  if t:lower():match("^legacy loot rules are no longer in effect%.?$") then
    return { kind = "legacy_loot_off" }
  end

  if t:lower():match("^legacy loot rules are enabled%.?$") then
    return { kind = "legacy_loot_on" }
  end

  do
    local instanceName = t:match("^(.-)%s+has been reset%.?$")
    if IsNonEmptyPublicString(instanceName) then
      return { kind = "instance_reset", name = instanceName }
    end
  end

  return nil
end

local _instanceLastSig
local _instanceLastTS
local _instanceLegacyLootOn

local function HandleParsedInstanceMessage(ev, msg, parsed)
  if not parsed then
    return false
  end

  do
    local now = SafeNow()
    local sig = tostring(parsed.kind or "") .. "|" .. tostring(parsed.name or "") .. "|" .. tostring(parsed.value or "")
    if _instanceLastSig == sig and _instanceLastTS and (now - _instanceLastTS) < 0.35 then
      return true
    end
    _instanceLastSig = sig
    _instanceLastTS = now
  end

  local hcc, gcc, close = ColorCodes()
  local outText

  if parsed.kind == "legacy_loot_on" then
    _instanceLegacyLootOn = true
  elseif parsed.kind == "legacy_loot_off" then
    _instanceLegacyLootOn = false
  end

  if parsed.kind == "member_left" then
    outText = FormatOtherLine(parsed.name, string.format("%sLeft the Instance%s", hcc, close))
  elseif parsed.kind == "you_leave" then
    outText = FormatSelfLine(string.format("%sLeft the Group%s", hcc, close))
  elseif parsed.kind == "queued" then
    outText = FormatSelfLine(string.format("%sQueued in Dungeon Finder%s", hcc, close))
  elseif parsed.kind == "queue_limit" then
    outText = FormatSelfLine(string.format("%sQueue Limit Reached%s", hcc, close))
  elseif parsed.kind == "quest_requirements_fail" then
    outText = FormatSelfLine(string.format("%sQuest Requirements Not Met%s", hcc, close))
  elseif parsed.kind == "away" then
    outText = FormatSelfLine(string.format("%sAway: %s%s", hcc, tostring(parsed.value or "AFK"), close))
  elseif parsed.kind == "went_offline" then
    outText = FormatOtherInline(parsed.name, string.format("is now %sOffline%s", hcc, close))
  elseif parsed.kind == "came_online" then
    outText = FormatOtherInline(parsed.name, string.format("is now %sOnline%s", hcc, close))
  elseif parsed.kind == "queue_returned_front" then
    outText = FormatSelfLine(string.format("%sQueue Failed, Returned to Queue%s", hcc, close))
  elseif parsed.kind == "queue_removed_no_accept" then
    outText = FormatSelfLine(string.format("%sMissed the Invite, Removed from Queue%s", hcc, close))
  elseif parsed.kind == "dungeon_difficulty" then
    outText = FormatSelfLine(string.format("%sDungeon: %s%s", hcc, tostring(parsed.value or ""), close))
  elseif parsed.kind == "looting_mode" then
    local mode = tostring(parsed.value or "")
    local low = mode:lower():gsub("^%s+", ""):gsub("%s+$", "")
    if _instanceLegacyLootOn == true and low == "group loot" then
      mode = "Group Legacy Loot"
    end
    outText = FormatSelfLine(string.format("%s%s%s", hcc, mode, close))
  elseif parsed.kind == "loot_threshold" then
    outText = FormatSelfLine(string.format("%sLoot Threshold: %s%s", hcc, tostring(parsed.value or ""), close))
  elseif parsed.kind == "loot_specialization" then
    outText = FormatSelfLine(string.format("%sLoot Specialization: %s%s", hcc, tostring(parsed.value or ""), close))
  elseif parsed.kind == "not_in_party" then
    outText = FormatSelfLine(string.format("%sNot in a Party%s", hcc, close))
  elseif parsed.kind == "group_leader" then
    outText = FormatOtherLine(parsed.name, string.format("is %sParty Leader%s", hcc, close))
  elseif parsed.kind == "group_leader_self" then
    outText = FormatSelfLine(string.format("%sParty Leader%s", hcc, close))
  elseif parsed.kind == "legacy_loot_off" then
    outText = nil
  elseif parsed.kind == "legacy_loot_on" then
    outText = FormatSelfLine(string.format("%sGroup Legacy Loot%s", hcc, close))
  elseif parsed.kind == "instance_reset" then
    outText = FormatSelfLine(string.format("%s%s Reset%s", hcc, tostring(parsed.name or "Instance"), close))
  else
    return false
  end

  local outFrame = GetInstanceOutputFrame()
  if IsNonEmptyPublicString(outText) then
    PrintToChatFrame(outText, outFrame)
  end

  LootChat.CaptureChatOut(ev, outText, {
    handled = true,
    instance = true,
    kind = parsed.kind,
    outFrame = outFrame,
  })

  return true
end

local function OnInstanceSystemChat(_, eventName, msg, ...)
  EnsureRefs()
  DebugBumpEvent(tostring(eventName or "CHAT_MSG_SYSTEM"))
  if not (DB and DB.other and DB.other.instance and DB.other.instance.enabled) then
    return false
  end
  if type(msg) == "string" and IsSecretString(msg) then
    DebugBumpSecret(tostring(eventName or "CHAT_MSG_SYSTEM"))
    if LootChat.CaptureEnabled() then
      LootChat.CaptureAppend("CHAT_SECRET", { event = tostring(eventName or "CHAT_MSG_SYSTEM") })
    end
    return false
  end
  if not IsNonEmptyPublicString(msg) then
    return false
  end

  local ev = (type(eventName) == "string" and eventName ~= "") and eventName or "CHAT_MSG_SYSTEM"
  if ev ~= "CHAT_MSG_SYSTEM"
    and ev ~= "CHAT_MSG_PARTY"
    and ev ~= "CHAT_MSG_PARTY_LEADER"
    and ev ~= "CHAT_MSG_RAID"
    and ev ~= "CHAT_MSG_RAID_LEADER"
    and ev ~= "CHAT_MSG_GUILD" then
    return false
  end

  LootChat.CaptureChatIn(ev, msg)

  local parsed = ParseInstanceSystemMessage(msg)
  if not parsed then
    LootChat.CaptureChatOut(ev, "(instance) no-match", { handled = false, instanceNoMatch = true })
    return false
  end

  return HandleParsedInstanceMessage(ev, msg, parsed)
end

local function OnProfessionSkillChat(_, eventName, msg, ...)
  EnsureRefs()
  DebugBumpEvent(tostring(eventName or "CHAT_MSG_SKILL"))
  if not (DB and DB.other and DB.other.profession and DB.other.profession.enabled) then
    return false
  end
  if type(msg) == "string" and IsSecretString(msg) then
    DebugBumpSecret(tostring(eventName or "CHAT_MSG_SKILL"))
    if LootChat.CaptureEnabled() then
      LootChat.CaptureAppend("CHAT_SECRET", { event = tostring(eventName or "CHAT_MSG_SKILL") })
    end
    return false
  end
  if not IsNonEmptyPublicString(msg) then
    return false
  end

  local ev = (type(eventName) == "string" and eventName ~= "") and eventName or "CHAT_MSG_SKILL"
  LootChat.CaptureChatIn(ev, msg)

  -- Recipe learned lines ("You have learned how to create a new item: X.")
  if DB and DB.other and DB.other.profession and DB.other.profession.learnedItems == true then
    local parsedLearned = ParseLearnedItemMessage(msg)
    if parsedLearned and parsedLearned.display then
      local now = SafeNow()
      local sig = tostring(parsedLearned.display)
      if _learnedItemLastSig == sig and _learnedItemLastTS and (now - _learnedItemLastTS) < 0.35 then
        return true
      end
      _learnedItemLastSig = sig
      _learnedItemLastTS = now

      local outText = string.format("Learned %s", tostring(parsedLearned.display))
      local out = FormatSelfLine(outText)
      local outFrame = GetProfessionOutputFrame()
      PrintToChatFrame(out, outFrame)
      LootChat.CaptureChatOut(ev, out, { handled = true, learnedItem = true, outFrame = outFrame })
      return true
    end
  end

  local parsed = ParseSkillMessage(msg)
  if not parsed then
    LootChat.CaptureChatOut(ev, "(skill) no-match", { handled = false, skillNoMatch = true })
    return false
  end

  -- De-dupe in case the same skill line fires more than once.
  do
    local now = SafeNow()
    local sig = tostring(parsed.skill or "") .. "|" .. tostring(parsed.rank or 0) .. "|" .. tostring(parsed.learned or false)
    if _skillLastSig == sig and _skillLastTS and (now - _skillLastTS) < 0.35 then
      return true
    end
    _skillLastSig = sig
    _skillLastTS = now
  end

  local outText
  if parsed.rank then
    local skillName = tostring(parsed.skill)
    local rank = tonumber(parsed.rank) or 0
    local cache = GetProfessionRankCache()
    local prev = tonumber(cache[skillName])
    cache[skillName] = rank

    local delta = (prev and rank and rank > prev) and (rank - prev) or nil
    local hcc, gcc, close = ColorCodes()
    if delta and delta > 0 then
      outText = string.format("%s%s %s+%d%s (%d)%s", hcc, skillName, gcc, delta, hcc, rank, close)
    else
      outText = string.format("%s%s %s+?%s (%d)%s", hcc, skillName, gcc, hcc, rank, close)
    end
  else
    local skillName = tostring(parsed.skill)
    local hcc, _, close = ColorCodes()
    outText = string.format("%s%s learned%s", hcc, skillName, close)
  end
  local out = FormatSelfLine(outText)

  local outFrame = GetProfessionOutputFrame()
  PrintToChatFrame(out, outFrame)

  LootChat.CaptureChatOut(ev, out, {
    handled = true,
    skill = parsed.skill,
    rank = parsed.rank,
    learned = parsed.learned and true or false,
    outFrame = outFrame,
  })

  return true
end

function LootChat.ApplyFilters()
  EnsureRefs()

  -- Make filter auditing available even when the client doesn't expose ChatFrame_GetMessageEventFilters.
  EnsureFilterAuditHooks()

  -- Install direct-print suppression once; only activates when enabled+hideLootText.
  HookAllChatFramesAddMessage()

  local dbg = (DB and DB.debugChatSetup) == true
  local function D(s)
    if not dbg then return end
    local outFrame = (DB and DB.outputChatFrame) or 1
    PrintToChatFrame("[LootIt ChatDebug] " .. tostring(s or ""), outFrame)
  end

  if dbg then
    local outFrame = (DB and DB.outputChatFrame) or 1
    local otherFrameAch = (DB and DB.other and DB.other.achievement and DB.other.achievement.outputChatFrame)
      or (DB and DB.other and DB.other.outputChatFrame)
      or nil
    local otherFrameXP = (DB and DB.other and DB.other.experience and DB.other.experience.outputChatFrame)
      or (DB and DB.other and DB.other.outputChatFrame)
      or nil
    local outName = GetChatWindowName(outFrame) or "?"
    local otherNameAch = otherFrameAch and (GetChatWindowName(otherFrameAch) or "?") or "(nil)"
    local otherNameXP = otherFrameXP and (GetChatWindowName(otherFrameXP) or "?") or "(nil)"
    local ach = (DB and DB.other and DB.other.achievement and DB.other.achievement.enabled) and true or false
    local xp = (DB and DB.other and DB.other.experience and DB.other.experience.enabled) and true or false
    D(string.format(
      "ApplyFilters begin enabled=%s output=%s('%s') otherAch=%s('%s') otherXP=%s('%s') achievement=%s experience=%s",
      tostring(IsEnabled()),
      tostring(outFrame), tostring(outName),
      tostring(otherFrameAch), tostring(otherNameAch),
      tostring(otherFrameXP), tostring(otherNameXP),
      tostring(ach), tostring(xp)
    ))
  end

  if not ChatFrame_AddMessageEventFilter then
    ChatFrame_AddMessageEventFilter = _G and rawget(_G, "ChatFrame_AddMessageEventFilter")
  end
  if not ChatFrame_RemoveMessageEventFilter then
    ChatFrame_RemoveMessageEventFilter = _G and rawget(_G, "ChatFrame_RemoveMessageEventFilter")
  end
  if not (ChatFrame_AddMessageEventFilter and ChatFrame_RemoveMessageEventFilter) then return end

  if dbg then
    D(string.format("ChatFrame_AddMessageEventFilter=%s Remove=%s", type(ChatFrame_AddMessageEventFilter), type(ChatFrame_RemoveMessageEventFilter)))
  end

  ChatFrame_RemoveMessageEventFilter("CHAT_MSG_LOOT", OnLootChat)
  ChatFrame_RemoveMessageEventFilter("CHAT_MSG_CURRENCY", OnCurrencyChat)
  ChatFrame_RemoveMessageEventFilter("CHAT_MSG_MONEY", OnMoneyChat)
  ChatFrame_RemoveMessageEventFilter("CHAT_MSG_SYSTEM", OnSystemChat)
  ChatFrame_RemoveMessageEventFilter("CHAT_MSG_COMBAT_MISC_INFO", OnSystemChat)
  ChatFrame_RemoveMessageEventFilter("CHAT_MSG_SKILL", OnSystemChat)
  ChatFrame_RemoveMessageEventFilter("CHAT_MSG_TRADESKILLS", OnSystemChat)
  ChatFrame_RemoveMessageEventFilter("CHAT_MSG_SKILL", OnProfessionSkillChat)
  ChatFrame_RemoveMessageEventFilter("CHAT_MSG_ACHIEVEMENT", OnAchievementChat)
  ChatFrame_RemoveMessageEventFilter("CHAT_MSG_GUILD_ACHIEVEMENT", OnAchievementChat)
  ChatFrame_RemoveMessageEventFilter("CHAT_MSG_COMBAT_XP_GAIN", OnExperienceChat)
  ChatFrame_RemoveMessageEventFilter("CHAT_MSG_COMBAT_MISC_INFO", OnExperienceChat)
  ChatFrame_RemoveMessageEventFilter("CHAT_MSG_SYSTEM", OnExperienceChat)
  ChatFrame_RemoveMessageEventFilter("CHAT_MSG_SYSTEM", OnProfessionSkillChat)
  ChatFrame_RemoveMessageEventFilter("CHAT_MSG_SYSTEM", OnInstanceSystemChat)
  ChatFrame_RemoveMessageEventFilter("CHAT_MSG_PARTY", OnInstanceSystemChat)
  ChatFrame_RemoveMessageEventFilter("CHAT_MSG_PARTY_LEADER", OnInstanceSystemChat)
  ChatFrame_RemoveMessageEventFilter("CHAT_MSG_RAID", OnInstanceSystemChat)
  ChatFrame_RemoveMessageEventFilter("CHAT_MSG_RAID_LEADER", OnInstanceSystemChat)
  ChatFrame_RemoveMessageEventFilter("CHAT_MSG_GUILD", OnInstanceSystemChat)
  local enabledNow = IsEnabled() and true or false
  local wantSuppress = (SuppressRulesEnabled() and true or false)
  local wantQuestXP = (DB and DB.other and DB.other.experience and DB.other.experience.enabled) and QuestXPEnabled()
  local wantInstance = (DB and DB.other and DB.other.instance and DB.other.instance.enabled) and true or false
  local wantSystemFilter = enabledNow or ((DB and DB.other and DB.other.hidePlayed) == true) or wantSuppress or (wantQuestXP and true or false) or wantInstance

  if enabledNow then
    ChatFrame_AddMessageEventFilter("CHAT_MSG_LOOT", OnLootChat)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_CURRENCY", OnCurrencyChat)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_MONEY", OnMoneyChat)
    -- OnSystemChat handles multiple optional suppressions (including Played).
    ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", OnSystemChat)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_COMBAT_MISC_INFO", OnSystemChat)
    if not (DB and DB.other and DB.other.profession and DB.other.profession.enabled) then
      ChatFrame_AddMessageEventFilter("CHAT_MSG_SKILL", OnSystemChat)
    end
    ChatFrame_AddMessageEventFilter("CHAT_MSG_TRADESKILLS", OnSystemChat)
  end

  -- If LootIt is disabled, still allow system-level filters that belong to submodules
  -- (e.g. /played suppression, QuestXP quest-line suppression).
  if (not enabledNow) and wantSystemFilter then
    ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", OnSystemChat)
  end
  if DB and DB.other and DB.other.achievement and DB.other.achievement.enabled then
    ChatFrame_AddMessageEventFilter("CHAT_MSG_ACHIEVEMENT", OnAchievementChat)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_GUILD_ACHIEVEMENT", OnAchievementChat)
  end
  if DB and DB.other and DB.other.experience and DB.other.experience.enabled then
    ChatFrame_AddMessageEventFilter("CHAT_MSG_COMBAT_XP_GAIN", OnExperienceChat)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_COMBAT_MISC_INFO", OnExperienceChat)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", OnExperienceChat)
  end
  if DB and DB.other and DB.other.profession and DB.other.profession.enabled then
    ChatFrame_AddMessageEventFilter("CHAT_MSG_SKILL", OnProfessionSkillChat)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", OnProfessionSkillChat)
  end
  if DB and DB.other and DB.other.instance and DB.other.instance.enabled then
    ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", OnInstanceSystemChat)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_PARTY", OnInstanceSystemChat)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_PARTY_LEADER", OnInstanceSystemChat)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID", OnInstanceSystemChat)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID_LEADER", OnInstanceSystemChat)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_GUILD", OnInstanceSystemChat)
  end

  if dbg then
    local enabled = IsEnabled() and true or false
    local ach = (DB and DB.other and DB.other.achievement and DB.other.achievement.enabled) and true or false
    local xp = (DB and DB.other and DB.other.experience and DB.other.experience.enabled) and true or false
    local prof = (DB and DB.other and DB.other.profession and DB.other.profession.enabled) and true or false
    local inst = (DB and DB.other and DB.other.instance and DB.other.instance.enabled) and true or false
    D(string.format("ApplyFilters done (enabled=%s, achievement=%s, experience=%s, profession=%s, instance=%s)", tostring(enabled), tostring(ach), tostring(xp), tostring(prof), tostring(inst)))
  end
end

function LootChat.ApplyFiltersSoon(delaySeconds)
  if not (C_Timer and C_Timer.After) then return end
  local d = tonumber(delaySeconds) or 0
  if d < 0 then d = 0 end
  C_Timer.After(d, function()
    EnsureRefs()
    LootChat.ApplyFilters()
  end)
end

-- Returns true/false when we can verify filter installation, or nil if the client
-- does not expose ChatFrame_GetMessageEventFilters (rare / restricted environments).
function LootChat.FiltersInstalled()
  EnsureRefs()
  local getFilters = _G and rawget(_G, "ChatFrame_GetMessageEventFilters")
  if type(getFilters) ~= "function" then
    return nil
  end

  local function Has(eventName, fn)
    if type(fn) ~= "function" then return false end
    local ok, filters = pcall(getFilters, eventName)
    if not ok or type(filters) ~= "table" then return false end
    for _, f in ipairs(filters) do
      if f == fn then
        return true
      end
    end
    return false
  end

  local enabledNow = IsEnabled() and true or false
  if not enabledNow then
    -- If LootIt is disabled, we intentionally don't guarantee loot filters.
    return true
  end

  if not (Has("CHAT_MSG_LOOT", OnLootChat) and Has("CHAT_MSG_MONEY", OnMoneyChat) and Has("CHAT_MSG_CURRENCY", OnCurrencyChat)) then
    return false
  end

  -- System-level filter is used both for loot-mode and optional suppressions.
  if not (Has("CHAT_MSG_SYSTEM", OnSystemChat) and Has("CHAT_MSG_COMBAT_MISC_INFO", OnSystemChat)) then
    return false
  end

  if DB and DB.other and DB.other.achievement and DB.other.achievement.enabled then
    if not (Has("CHAT_MSG_ACHIEVEMENT", OnAchievementChat) and Has("CHAT_MSG_GUILD_ACHIEVEMENT", OnAchievementChat)) then
      return false
    end
  end

  if DB and DB.other and DB.other.experience and DB.other.experience.enabled then
    if not (Has("CHAT_MSG_COMBAT_XP_GAIN", OnExperienceChat)
      and Has("CHAT_MSG_COMBAT_MISC_INFO", OnExperienceChat)
      and Has("CHAT_MSG_SYSTEM", OnExperienceChat)) then
      return false
    end
  end

  if DB and DB.other and DB.other.profession and DB.other.profession.enabled then
    if not (Has("CHAT_MSG_SKILL", OnProfessionSkillChat) and Has("CHAT_MSG_SYSTEM", OnProfessionSkillChat)) then
      return false
    end
  end

  if DB and DB.other and DB.other.instance and DB.other.instance.enabled then
    if not (
      Has("CHAT_MSG_SYSTEM", OnInstanceSystemChat)
      or Has("CHAT_MSG_PARTY", OnInstanceSystemChat)
      or Has("CHAT_MSG_PARTY_LEADER", OnInstanceSystemChat)
      or Has("CHAT_MSG_RAID", OnInstanceSystemChat)
      or Has("CHAT_MSG_RAID_LEADER", OnInstanceSystemChat)
      or Has("CHAT_MSG_GUILD", OnInstanceSystemChat)
    ) then
      return false
    end
  end

  return true
end

function LootChat.DumpFilterAudit(PrintFn)
  EnsureRefs()
  local getFilters = _G and rawget(_G, "ChatFrame_GetMessageEventFilters")
  if type(getFilters) ~= "function" then
    EnsureFilterAuditHooks()
  end

  local function Has(eventName, fn)
    if type(fn) ~= "function" then return false, 0 end
    if type(getFilters) == "function" then
      local ok, filters = pcall(getFilters, eventName)
      if not ok or type(filters) ~= "table" then
        return false, 0
      end
      local has = false
      for _, f in ipairs(filters) do
        if f == fn then
          has = true
          break
        end
      end
      return has, #filters
    end

    -- Fallback: use our tracked state (best-effort; misses addons using cached function refs).
    local t = _filterAudit
    local ev = t and t.events and t.events[eventName]
    if ev then
      return (ev[fn] == true), 0
    end
    return false, 0
  end

  local enabledNow = IsEnabled() and true or false
  local hookN = tonumber(LootChat._debugAddMessageHookCount) or 0
  local mode = (type(getFilters) == "function") and "api" or "tracked"
  SafeCall(PrintFn, string.format("Filter audit: enabled=%s addMessageHooks=%d mode=%s", tostring(enabledNow), hookN, mode))

  local lines = {
    { "CHAT_MSG_LOOT", OnLootChat, "loot" },
    { "CHAT_MSG_CURRENCY", OnCurrencyChat, "currency" },
    { "CHAT_MSG_MONEY", OnMoneyChat, "money" },
    { "CHAT_MSG_SYSTEM", OnSystemChat, "system" },
    { "CHAT_MSG_COMBAT_MISC_INFO", OnSystemChat, "combat_misc->system" },
    { "CHAT_MSG_ACHIEVEMENT", OnAchievementChat, "achievement" },
    { "CHAT_MSG_GUILD_ACHIEVEMENT", OnAchievementChat, "guild_achievement" },
    { "CHAT_MSG_COMBAT_XP_GAIN", OnExperienceChat, "xp_gain" },
    { "CHAT_MSG_COMBAT_MISC_INFO", OnExperienceChat, "combat_misc->xp" },
    { "CHAT_MSG_SYSTEM", OnExperienceChat, "system->xp" },
    { "CHAT_MSG_SKILL", OnProfessionSkillChat, "skill->profession" },
    { "CHAT_MSG_SYSTEM", OnProfessionSkillChat, "system->profession" },
    { "CHAT_MSG_SYSTEM", OnInstanceSystemChat, "system->instance" },
    { "CHAT_MSG_PARTY", OnInstanceSystemChat, "party->instance" },
    { "CHAT_MSG_PARTY_LEADER", OnInstanceSystemChat, "party_leader->instance" },
    { "CHAT_MSG_RAID", OnInstanceSystemChat, "raid->instance" },
    { "CHAT_MSG_RAID_LEADER", OnInstanceSystemChat, "raid_leader->instance" },
    { "CHAT_MSG_GUILD", OnInstanceSystemChat, "guild->instance" },
  }

  local missing = {}
  for _, row in ipairs(lines) do
    local ev, fn, label = row[1], row[2], row[3]
    local has, n = Has(ev, fn)
    if mode == "api" then
      SafeCall(PrintFn, string.format("  %s: %s (filters=%d)", tostring(label), tostring(has), tonumber(n) or 0))
    else
      SafeCall(PrintFn, string.format("  %s: %s", tostring(label), tostring(has)))
    end
    if enabledNow and not has then
      missing[#missing + 1] = label
    end
  end
  if enabledNow and #missing > 0 then
    SafeCall(PrintFn, "  Missing while enabled: " .. table.concat(missing, ", "))
  end

  if mode ~= "api" then
    local t = _filterAudit
    local last = t and t.last or nil
    if type(last) == "table" and #last > 0 then
      SafeCall(PrintFn, string.format("  Recent filter ops (last %d):", #last))
      for _, e in ipairs(last) do
        SafeCall(PrintFn, string.format("    %s %s %s", tostring(e.t or ""), tostring(e.op or ""), tostring(e.ev or "")))
        if e.stack and e.stack ~= "" then
          local s = tostring(e.stack):gsub("\n", " | ")
          -- WoW chat uses '|' for escape codes; doubling shows a literal pipe.
          s = s:gsub("|", "||")
          SafeCall(PrintFn, "      stack: " .. s)
        end
      end
    else
      SafeCall(PrintFn, "  Recent filter ops: (none observed)")
    end
  end
end

function LootChat.GetSupportedMessageLines()
  local lines = {}
  lines[#lines + 1] = "CHAT_MSG_LOOT"
  lines[#lines + 1] = "  - Filters only self loot lines (localized via GlobalStrings)"
  lines[#lines + 1] = "  - GlobalString keys:"
  for _, k in ipairs(LOOT_PATTERN_KEYS) do
    lines[#lines + 1] = "    - " .. k
  end
  lines[#lines + 1] = ""
  lines[#lines + 1] = "  - Also handles group loot lines (other players)"
  lines[#lines + 1] = "  - Reprints as 'Name: [Item]' (realm suffix removed)"
  lines[#lines + 1] = "  - GlobalString keys:"
  for _, k in ipairs(LOOT_GROUP_PATTERN_KEYS) do
    lines[#lines + 1] = "    - " .. k
  end
  lines[#lines + 1] = ""
  lines[#lines + 1] = "Notes:"
  lines[#lines + 1] = "  - This does not block loot itself, only chat text."
  lines[#lines + 1] = "  - Loot distribution is unchanged; only chat text is filtered."
  lines[#lines + 1] = ""
  lines[#lines + 1] = "CHAT_MSG_ACHIEVEMENT / CHAT_MSG_GUILD_ACHIEVEMENT"
  lines[#lines + 1] = "  - Optional: rewrites to 'Name: earned Link!'"
  lines[#lines + 1] = "  - Realm removed; achievement link brackets removed"
  lines[#lines + 1] = ""
  lines[#lines + 1] = "CHAT_MSG_CURRENCY"
  lines[#lines + 1] = "  - Filters 'You receive currency: ...' (self)"
  lines[#lines + 1] = "  - GlobalString keys:"
  for _, k in ipairs(CURRENCY_PATTERN_KEYS) do
    lines[#lines + 1] = "    - " .. k
  end

  lines[#lines + 1] = ""
  lines[#lines + 1] = "CHAT_MSG_MONEY"
  lines[#lines + 1] = "  - Filters 'You loot ...' money lines (self)"
  lines[#lines + 1] = "  - Reprints selected coins (gold/silver/copper)"
  lines[#lines + 1] = "  - GlobalString keys:"
  for _, k in ipairs(MONEY_PATTERN_KEYS) do
    lines[#lines + 1] = "    - " .. k
  end

  lines[#lines + 1] = ""
  lines[#lines + 1] = "CHAT_MSG_SYSTEM"
  lines[#lines + 1] = "  - Filters 'You receive item: ...' reward lines when they show up as system messages"
  lines[#lines + 1] = "  - GlobalString keys:"
  lines[#lines + 1] = "    - YOU_RECEIVE_ITEM"
  lines[#lines + 1] = "    - YOU_RECEIVE_ITEM_MULTIPLE"
  lines[#lines + 1] = "  - Optional: Instance system cleaner"
  lines[#lines + 1] = "    - Name has left the instance group."
  lines[#lines + 1] = "    - You leave the group."
  lines[#lines + 1] = "    - You are now queued in the Dungeon Finder."
  lines[#lines + 1] = "    - You are queued for too many instances."
  lines[#lines + 1] = "    - You don't meet the requirements for that quest."
  lines[#lines + 1] = "    - You are now Away: AFK"
  lines[#lines + 1] = "    - Name has gone offline."
  lines[#lines + 1] = "    - [Name] has come online."
  lines[#lines + 1] = "    - Someone has declined the invite. You have been returned to the front of the queue."
  lines[#lines + 1] = "    - You have been removed from the queue because you did not accept the invitation."
  lines[#lines + 1] = "    - Dungeon Difficulty set to <value>."
  lines[#lines + 1] = "    - Looting set to <value>."
  lines[#lines + 1] = "    - Loot threshold set to <value>."
  lines[#lines + 1] = "    - You aren't in a party."
  lines[#lines + 1] = "    - <name> is now the leader of your group!"
  lines[#lines + 1] = "    - Legacy loot rules are no longer in effect."
  lines[#lines + 1] = "    - Legacy loot rules are enabled."
  lines[#lines + 1] = "    - <instance> has been reset."
  return lines
end
