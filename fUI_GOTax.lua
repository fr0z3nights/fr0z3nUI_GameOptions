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

  -- Optional UI refresh callback (set by the Tax tab UI when built).
  local function RequestUIRefresh()
    local fn = Tax and rawget(Tax, "_RefreshUI")
    if type(fn) == "function" then
      pcall(fn)
    end
  end

  local DB
  local CHARDB
  local Print = function(...) end

  local state = {
    merchant = { open = false, startMoney = 0, chatMoney = 0 },
    mail = { open = false, startMoney = 0, chatMoney = 0 },
    guildBankOpen = false,
    warbankOpen = false,
  }

  local goldStr, silverStr, copperStr
  local lastTokenPrice = nil
  local lastTokenPriceTS = 0

  local function GetCurrentGuildKeyAndName()
    if type(IsInGuild) == "function" then
      local ok, inGuild = pcall(IsInGuild)
      if ok and inGuild ~= true then
        return nil, nil
      end
    end
    if type(GetGuildInfo) ~= "function" then
      return nil, nil
    end
    local ok, guildName, _, _, homeRealm = pcall(GetGuildInfo, "player")
    guildName = ok and guildName or nil
    homeRealm = ok and homeRealm or nil
    if type(guildName) ~= "string" or guildName == "" then
      return nil, nil
    end

    local guildGUID
    if type(C_GuildInfo) == "table" and type(C_GuildInfo.GetGuildGUID) == "function" then
      local okGuid, guid = pcall(C_GuildInfo.GetGuildGUID)
      guildGUID = okGuid and guid or nil
    end

    local realm = (type(GetRealmName) == "function") and GetRealmName() or nil
    realm = (type(realm) == "string" and realm ~= "") and realm or ""
    local homeRealmStr = (type(homeRealm) == "string" and homeRealm ~= "") and homeRealm or nil

    -- WoW commonly omits the realm string when it matches your current realm.
    -- In that case, treat it as same-realm rather than "unknown".
    if not homeRealmStr and realm ~= "" then
      homeRealmStr = realm
    end

    if type(guildGUID) == "string" and guildGUID ~= "" then
      return guildGUID, guildName, homeRealmStr
    end

    -- Fallback for older clients / edge cases.
    return realm .. "::" .. guildName, guildName, homeRealmStr
  end

  local function Clamp(v, mn, mx)
    v = tonumber(v)
    mn = tonumber(mn)
    mx = tonumber(mx)
    if not v then return mn end
    if mn and v < mn then return mn end
    if mx and v > mx then return mx end
    return v
  end

  local function EnsureMoneyStrings()
    if goldStr and silverStr and copperStr then return end

    if type(GOLD_AMOUNT) == "string" and strmatch and format then
      goldStr = strmatch(format(GOLD_AMOUNT, 20), "%d+%s(.+)")
    end
    if type(SILVER_AMOUNT) == "string" and strmatch and format then
      silverStr = strmatch(format(SILVER_AMOUNT, 20), "%d+%s(.+)")
    end
    if type(COPPER_AMOUNT) == "string" and strmatch and format then
      copperStr = strmatch(format(COPPER_AMOUNT, 20), "%d+%s(.+)")
    end

    goldStr = goldStr or ""
    silverStr = silverStr or ""
    copperStr = copperStr or ""
  end

  local function ParseMoneyFromChat(msg)
    if type(msg) ~= "string" then return 0 end
    if type(issecretvalue) == "function" and issecretvalue(msg) then return 0 end

    EnsureMoneyStrings()

    local g = 0
    local s = 0
    local c = 0

    if goldStr ~= "" then
      g = tonumber(string.match(msg, "(%d+)%s" .. goldStr)) or 0
    end
    if silverStr ~= "" then
      s = tonumber(string.match(msg, "(%d+)%s" .. silverStr)) or 0
    end
    if copperStr ~= "" then
      c = tonumber(string.match(msg, "(%d+)%s" .. copperStr)) or 0
    end

    local total = (g * (COPPER_PER_GOLD or 10000)) + (s * (COPPER_PER_SILVER or 100)) + c
    total = math.floor(tonumber(total) or 0)
    if total < 0 then total = 0 end
    return total
  end

  local function EnsureTaxDB()
    local db = DB or (_G and rawget(_G, "fr0z3nUI_LootItDB"))
    if type(db) ~= "table" then return nil end

    db.tax = (type(db.tax) == "table") and db.tax or {}
    local t = db.tax

    t.ldbDisplay = (type(t.ldbDisplay) == "table") and t.ldbDisplay or {}
    if t.ldbDisplay.player == nil then t.ldbDisplay.player = true end
    if t.ldbDisplay.guild == nil then t.ldbDisplay.guild = true end
    if t.ldbDisplay.war == nil then t.ldbDisplay.war = true end
    t.ldbDisplay.player = (t.ldbDisplay.player == true)
    t.ldbDisplay.guild = (t.ldbDisplay.guild == true)
    t.ldbDisplay.war = (t.ldbDisplay.war == true)
    if not t.ldbDisplay.player and not t.ldbDisplay.guild and not t.ldbDisplay.war then
      t.ldbDisplay.player = true
      t.ldbDisplay.guild = true
      t.ldbDisplay.war = true
    end

    -- Warbank control indicator mode in Tax LDB:
    --   text => current behavior (tint whole war value when controlled)
    --   icon => keep text white and tint only the gold icon (gold/gray)
    t.ldbWarControlStyle = tostring(t.ldbWarControlStyle or "text"):lower()
    if t.ldbWarControlStyle ~= "text" and t.ldbWarControlStyle ~= "icon" then
      t.ldbWarControlStyle = "text"
    end

    -- Guild-scoped settings/balances.
    t.guilds = (type(t.guilds) == "table") and t.guilds or {}

    -- Balances are per-character by default (stored in character savedvars).
    -- Optionally, guild scope can use a shared per-guild balance bucket (behind a per-guild toggle).
    -- Clear legacy account-wide balances once to avoid stale/phantom owed values.
    if t._balanceMode ~= "character" then
      t._balanceMode = "character"

      -- Legacy account-wide fields.
      t.due = 0
      t.dueTax = 0
      t.dueBorrowed = 0
      t.paidToDate = 0
      t.borrowedLastTS = 0
    end

    -- Legacy account-wide fields (kept for backward compatibility; no longer the active model).
    t.enabled = (t.enabled == true) and true or false
    t.rate = Clamp(t.rate, 0, 100) or 0
    t.quiet = (t.quiet == true) and true or false
    t.due = math.floor(tonumber(t.due) or 0)
    t.paidToDate = math.floor(tonumber(t.paidToDate) or 0)

    -- Split balances: normal tax due vs. guild-withdrawn debt (cannot be cleared).
    -- If old data only has t.due, treat it as normal tax due.
    if t.dueTax == nil and t.dueBorrowed == nil then
      t.dueTax = t.due
      t.dueBorrowed = 0
    end
    t.dueTax = math.floor(tonumber(t.dueTax) or 0)
    t.dueBorrowed = math.floor(tonumber(t.dueBorrowed) or 0)
    if t.dueTax < 0 then t.dueTax = 0 end
    if t.dueBorrowed < 0 then t.dueBorrowed = 0 end
    t.borrowedLastTS = math.floor(tonumber(t.borrowedLastTS) or 0)
    if t.borrowedLastTS < 0 then t.borrowedLastTS = 0 end

    t.due = t.dueTax + t.dueBorrowed

    if t.due < 0 then t.due = 0 end
    if t.paidToDate < 0 then t.paidToDate = 0 end

    t.sources = (type(t.sources) == "table") and t.sources or {}
    if t.sources.vendor == nil then t.sources.vendor = true end
    if t.sources.questLoot == nil then t.sources.questLoot = true end
    if t.sources.systemMoney == nil then t.sources.systemMoney = false end
    if t.sources.mail == nil then t.sources.mail = true end

    if t.autoPayOnGuildBankOpen == nil then t.autoPayOnGuildBankOpen = true end

    -- Warband bank cache is account-wide; migrate any legacy character-scoped values once.
    if t.warBankMoneyCached == nil and type(CHARDB) == "table" and type(CHARDB.tax) == "table" then
      local legacyWar = tonumber(CHARDB.tax.warBankMoneyCached)
      if legacyWar and legacyWar >= 0 then
        t.warBankMoneyCached = math.floor(legacyWar)
      end
    end
    if t.warBankMoneyCached ~= nil then
      t.warBankMoneyCached = math.floor(tonumber(t.warBankMoneyCached) or 0)
      if t.warBankMoneyCached < 0 then t.warBankMoneyCached = 0 end
    end
    if t.warBankMoneyCachedTS == nil and type(CHARDB) == "table" and type(CHARDB.tax) == "table" then
      local legacyWarTS = tonumber(CHARDB.tax.warBankMoneyCachedTS)
      if legacyWarTS and legacyWarTS >= 0 then
        t.warBankMoneyCachedTS = math.floor(legacyWarTS)
      end
    end
    if t.warBankMoneyCachedTS ~= nil then
      t.warBankMoneyCachedTS = math.floor(tonumber(t.warBankMoneyCachedTS) or 0)
      if t.warBankMoneyCachedTS < 0 then t.warBankMoneyCachedTS = 0 end
    end

    if t.wowTokenMarketPriceCached ~= nil then
      t.wowTokenMarketPriceCached = math.floor(tonumber(t.wowTokenMarketPriceCached) or 0)
      if t.wowTokenMarketPriceCached < 0 then t.wowTokenMarketPriceCached = 0 end
    end
    if t.wowTokenMarketPriceCachedTS ~= nil then
      t.wowTokenMarketPriceCachedTS = math.floor(tonumber(t.wowTokenMarketPriceCachedTS) or 0)
      if t.wowTokenMarketPriceCachedTS < 0 then t.wowTokenMarketPriceCachedTS = 0 end
    end

    -- Normalize: enabled tracks whether the rate is > 0.
    if t.rate <= 0 then
      t.enabled = false
    else
      t.enabled = true
    end

    return t
  end

  local function EnsureGuildTaxDB(guildKey)
    if type(guildKey) ~= "string" or guildKey == "" then return nil end

    local t = EnsureTaxDB()
    if not t then return nil end
    t.guilds = (type(t.guilds) == "table") and t.guilds or {}
    t.guilds[guildKey] = (type(t.guilds[guildKey]) == "table") and t.guilds[guildKey] or {}
    local g = t.guilds[guildKey]

    -- Best-effort migration: legacy realm::guildName keys into new GUID-based key.
    -- Only runs when the current guild key is GUID-like (i.e. not the legacy format).
    if next(g) == nil and not string.find(guildKey, "::", 1, true) then
      local curKey, curName, curHomeRealm = GetCurrentGuildKeyAndName()
      if curKey == guildKey and type(curName) == "string" and curName ~= "" then
        local realmNow = (type(GetRealmName) == "function") and GetRealmName() or nil
        realmNow = (type(realmNow) == "string" and realmNow ~= "") and realmNow or ""
        local homeRealm = (type(curHomeRealm) == "string" and curHomeRealm ~= "") and curHomeRealm or nil

        local legacyKeyNow = realmNow .. "::" .. curName
        local legacyKeyHome = homeRealm and (homeRealm .. "::" .. curName) or nil

        local function ShallowCopyTable(src)
          if type(src) ~= "table" then return nil end
          local out = {}
          for k, v in pairs(src) do
            out[k] = v
          end
          return out
        end

        local function AddNumberField(dst, key, val)
          if type(dst) ~= "table" then return end
          local add = math.floor(tonumber(val) or 0)
          if add == 0 then return end
          dst[key] = math.floor(tonumber(dst[key]) or 0) + add
        end

        local function MergeLegacyBucket(srcKey)
          local src = t.guilds and t.guilds[srcKey]
          if type(src) ~= "table" or next(src) == nil then return false end

          -- Settings (pick the most permissive / highest-rate). 
          local srcRate = Clamp(src.rate, 0, 100) or 0
          local dstRate = Clamp(g.rate, 0, 100) or 0
          if srcRate > dstRate then g.rate = srcRate end

          if src.quiet == true then g.quiet = true end
          if src.bankPrintEnabled ~= nil and g.bankPrintEnabled == nil then g.bankPrintEnabled = (src.bankPrintEnabled == true) end
          if src.manualBankMovesEnabled ~= nil and g.manualBankMovesEnabled == nil then g.manualBankMovesEnabled = (src.manualBankMovesEnabled == true) end
          if type(src.owedScope) == "string" and (g.owedScope == nil or g.owedScope == "") then g.owedScope = src.owedScope end
          if src.autoPayOnGuildBankOpen ~= nil and g.autoPayOnGuildBankOpen == nil then g.autoPayOnGuildBankOpen = (src.autoPayOnGuildBankOpen == true) end

          if type(src.sources) == "table" then
            g.sources = (type(g.sources) == "table") and g.sources or {}
            if src.sources.vendor ~= false then g.sources.vendor = true end
            if src.sources.questLoot ~= false then g.sources.questLoot = true end
            if src.sources.systemMoney == true then g.sources.systemMoney = true end
            if src.sources.mail ~= false then g.sources.mail = true end
          end

          -- Balances (sum).
          AddNumberField(g, "due", src.due)
          AddNumberField(g, "paidToDate", src.paidToDate)
          AddNumberField(g, "dueTax", src.dueTax)
          AddNumberField(g, "dueBorrowed", src.dueBorrowed)
          AddNumberField(g, "borrowedLastTS", src.borrowedLastTS)

          if type(src.sharedBal) == "table" then
            g.sharedBal = (type(g.sharedBal) == "table") and g.sharedBal or {}
            AddNumberField(g.sharedBal, "due", src.sharedBal.due)
            AddNumberField(g.sharedBal, "paidToDate", src.sharedBal.paidToDate)
            AddNumberField(g.sharedBal, "dueTax", src.sharedBal.dueTax)
            AddNumberField(g.sharedBal, "dueBorrowed", src.sharedBal.dueBorrowed)
            AddNumberField(g.sharedBal, "borrowedLastTS", src.sharedBal.borrowedLastTS)
          end

          -- Copy any remaining fields only if missing (shallow).
          for k, v in pairs(src) do
            if g[k] == nil then
              if type(v) == "table" then
                g[k] = ShallowCopyTable(v)
              else
                g[k] = v
              end
            end
          end

          return true
        end

        if legacyKeyHome and legacyKeyHome ~= guildKey then
          local migratedHome = MergeLegacyBucket(legacyKeyHome)
          if migratedHome and t.guilds then t.guilds[legacyKeyHome] = nil end
        end
        if legacyKeyNow ~= guildKey then
          local migratedNow = MergeLegacyBucket(legacyKeyNow)
          if migratedNow and t.guilds then t.guilds[legacyKeyNow] = nil end
        end
      end
    end

    -- One-time best-effort migration from legacy account-wide tax into the first guild bucket.
    -- This avoids "losing" settings after the Guild-scope refactor.
    if next(g) == nil then
      local legacyRate = Clamp(t.rate, 0, 100) or 0
      local legacyDue = math.floor(tonumber(t.due) or 0)
      local legacyPaid = math.floor(tonumber(t.paidToDate) or 0)
      if legacyRate > 0 or legacyDue > 0 or legacyPaid > 0 then
        g.rate = legacyRate
        g.quiet = (t.quiet == true)
        g.due = legacyDue
        g.paidToDate = legacyPaid
        if type(t.sources) == "table" then
          g.sources = {
            vendor = (t.sources.vendor ~= false),
            questLoot = (t.sources.questLoot ~= false),
            systemMoney = (t.sources.systemMoney == true),
            mail = (t.sources.mail ~= false),
          }
        end
        if t.autoPayOnGuildBankOpen ~= nil then
          g.autoPayOnGuildBankOpen = (t.autoPayOnGuildBankOpen == true)
        end
      end
    end

    g.rate = Clamp(g.rate, 0, 100) or 0
    g.quiet = (g.quiet == true) and true or false

    -- Bank move prints (deposit/withdraw). Scope-scoped; stored per guild when in Guild scope.
    if g.bankPrintEnabled == nil then g.bankPrintEnabled = true end
    g.bankPrintEnabled = (g.bankPrintEnabled == true)

    -- Deposit print verbosity mode:
    --   off   => no bank move prints
    --   basic => "X deposited to Y" (legacy behavior)
    --   detail=> compact owed/XS explanation
    --   full  => multi-line explanation
    if g.bankPrintMode == nil or g.bankPrintMode == "" then
      g.bankPrintMode = (g.bankPrintEnabled == true) and "detail" or "off"
    end
    g.bankPrintMode = tostring(g.bankPrintMode or "basic"):lower()
    if g.bankPrintMode ~= "off" and g.bankPrintMode ~= "basic" and g.bankPrintMode ~= "detail" and g.bankPrintMode ~= "full" then
      g.bankPrintMode = (g.bankPrintEnabled == true) and "detail" or "off"
    end
    g.bankPrintEnabled = (g.bankPrintMode ~= "off")

    -- Manual bank move tracking (deposit/withdraw). Scope-scoped; stored per guild when in Guild scope.
    if g.manualBankMovesEnabled == nil then g.manualBankMovesEnabled = false end
    g.manualBankMovesEnabled = (g.manualBankMovesEnabled == true)

    -- Owed-scope toggle (saved per guild; only meaningful when viewing in Guild scope).
    if g.owedScope == nil then g.owedScope = "character" end
    g.owedScope = tostring(g.owedScope or "character"):lower()
    if g.owedScope ~= "character" and g.owedScope ~= "characters" then
      g.owedScope = "character"
    end

    -- Shared per-guild balance bucket (used when owedScope == "characters").
    g.sharedBal = (type(g.sharedBal) == "table") and g.sharedBal or {}
    local sb = g.sharedBal
    sb.due = math.floor(tonumber(sb.due) or 0)
    sb.paidToDate = math.floor(tonumber(sb.paidToDate) or 0)
    if sb.dueTax == nil and sb.dueBorrowed == nil then
      sb.dueTax = sb.due
      sb.dueBorrowed = 0
    end
    sb.dueTax = math.floor(tonumber(sb.dueTax) or 0)
    sb.dueBorrowed = math.floor(tonumber(sb.dueBorrowed) or 0)
    if sb.dueTax < 0 then sb.dueTax = 0 end
    if sb.dueBorrowed < 0 then sb.dueBorrowed = 0 end
    sb.borrowedLastTS = math.floor(tonumber(sb.borrowedLastTS) or 0)
    if sb.borrowedLastTS < 0 then sb.borrowedLastTS = 0 end
    sb.due = sb.dueTax + sb.dueBorrowed
    if sb.due < 0 then sb.due = 0 end
    if sb.paidToDate < 0 then sb.paidToDate = 0 end

    g.due = math.floor(tonumber(g.due) or 0)
    g.paidToDate = math.floor(tonumber(g.paidToDate) or 0)
    if g.dueTax == nil and g.dueBorrowed == nil then
      g.dueTax = g.due
      g.dueBorrowed = 0
    end
    g.dueTax = math.floor(tonumber(g.dueTax) or 0)
    g.dueBorrowed = math.floor(tonumber(g.dueBorrowed) or 0)
    if g.dueTax < 0 then g.dueTax = 0 end
    if g.dueBorrowed < 0 then g.dueBorrowed = 0 end
    g.borrowedLastTS = math.floor(tonumber(g.borrowedLastTS) or 0)
    if g.borrowedLastTS < 0 then g.borrowedLastTS = 0 end
    g.due = g.dueTax + g.dueBorrowed
    if g.due < 0 then g.due = 0 end
    if g.paidToDate < 0 then g.paidToDate = 0 end

    -- One-time migration: if legacy guild-bucket balances exist, seed sharedBal.
    if sb._migratedLegacy ~= true then
      local legacyDueTax = math.floor(tonumber(g.dueTax) or 0)
      local legacyDueBorrowed = math.floor(tonumber(g.dueBorrowed) or 0)
      local legacyPaid = math.floor(tonumber(g.paidToDate) or 0)
      local legacyLastTS = math.floor(tonumber(g.borrowedLastTS) or 0)
      if legacyDueTax < 0 then legacyDueTax = 0 end
      if legacyDueBorrowed < 0 then legacyDueBorrowed = 0 end
      if legacyPaid < 0 then legacyPaid = 0 end
      if legacyLastTS < 0 then legacyLastTS = 0 end

      if (sb.dueTax + sb.dueBorrowed + sb.paidToDate) <= 0 and (legacyDueTax + legacyDueBorrowed + legacyPaid) > 0 then
        sb.dueTax = legacyDueTax
        sb.dueBorrowed = legacyDueBorrowed
        sb.paidToDate = legacyPaid
        sb.borrowedLastTS = legacyLastTS
        sb.due = sb.dueTax + sb.dueBorrowed
      end
      sb._migratedLegacy = true
    end

    g.sources = (type(g.sources) == "table") and g.sources or {}
    if g.sources.vendor == nil then g.sources.vendor = true end
    if g.sources.questLoot == nil then g.sources.questLoot = true end
    if g.sources.systemMoney == nil then g.sources.systemMoney = false end
    if g.sources.mail == nil then g.sources.mail = true end

    -- Auto Pay is the only supported mode now; keep the field for backward compatibility,
    -- but enforce it on so there is no â€œmanual-onlyâ€ state.
    g.autoPayOnGuildBankOpen = true

    if g.showOwedSilverCopper == nil then g.showOwedSilverCopper = false end
    g.showOwedSilverCopper = (g.showOwedSilverCopper == true)

    -- Warbank support toggle (scope-scoped; stored per guild when in Guild scope).
    if g.warBankEnabled == nil then g.warBankEnabled = false end
    g.warBankEnabled = (g.warBankEnabled == true)

    -- Warbank: Excess toggle (XS) (scope-scoped). Migrate legacy EB field.
    if g.warBankXS == nil and g.warBankEB ~= nil then
      g.warBankXS = (g.warBankEB == true)
      g.warBankEB = nil
    end
    if g.warBankXS == nil then g.warBankXS = false end
    g.warBankXS = (g.warBankXS == true)

    -- Guild Bank: Excess toggle (XS) (scope-scoped). Migrate legacy EB field.
    if g.guildBankXS == nil and g.guildBankEB ~= nil then
      g.guildBankXS = (g.guildBankEB == true)
      g.guildBankEB = nil
    end
    if g.guildBankXS == nil then g.guildBankXS = false end
    g.guildBankXS = (g.guildBankXS == true)

    -- Cached bank balances (best-effort; used for XS balancing).
    if g.guildBankMoneyCached ~= nil then
      g.guildBankMoneyCached = math.floor(tonumber(g.guildBankMoneyCached) or 0)
      if g.guildBankMoneyCached < 0 then g.guildBankMoneyCached = 0 end
    end
    if g.guildBankMoneyCachedTS ~= nil then
      g.guildBankMoneyCachedTS = math.floor(tonumber(g.guildBankMoneyCachedTS) or 0)
      if g.guildBankMoneyCachedTS < 0 then g.guildBankMoneyCachedTS = 0 end
    end

    -- Scope-scoped safety/borrowing controls.
    if g.minGold == nil then g.minGold = 0 end
    g.minGold = Clamp(g.minGold, 0, 9999999) or 0
    if g.minGold < 0 then g.minGold = 0 end
    if g.excessMinGold == nil then g.excessMinGold = g.minGold end
    g.excessMinGold = Clamp(g.excessMinGold, 0, 9999999) or 0
    if g.excessMinGold < 0 then g.excessMinGold = 0 end
    if g.excessMinGoldUserSet == nil then g.excessMinGoldUserSet = false end
    g.excessMinGoldUserSet = (g.excessMinGoldUserSet == true)
    if g.excessMinUseToken == nil then g.excessMinUseToken = false end
    g.excessMinUseToken = (g.excessMinUseToken == true)
    if g.allowWithdraw == nil then g.allowWithdraw = false end
    g.allowWithdraw = (g.allowWithdraw == true)

    g.enabled = (g.rate > 0)
    return g
  end

  local function EnsureCharTaxDB()
    local cdb = CHARDB or (_G and rawget(_G, "fr0z3nUI_LootItCharDB"))
    if type(cdb) ~= "table" then return nil end

    cdb.tax = (type(cdb.tax) == "table") and cdb.tax or {}
    local ct = cdb.tax

    if ct.scope == nil then ct.scope = "guild" end
    ct.scope = tostring(ct.scope or "guild"):lower()
    if ct.scope ~= "guild" and ct.scope ~= "character" then
      ct.scope = "guild"
    end

    ct.cfg = (type(ct.cfg) == "table") and ct.cfg or {}
    local cfg = ct.cfg
    cfg.rate = Clamp(cfg.rate, 0, 100) or 0
    cfg.quiet = (cfg.quiet == true) and true or false

    -- Bank move prints (deposit/withdraw). Scope-scoped; stored per character when in Character scope.
    if cfg.bankPrintEnabled == nil then cfg.bankPrintEnabled = true end
    cfg.bankPrintEnabled = (cfg.bankPrintEnabled == true)

    if cfg.bankPrintMode == nil or cfg.bankPrintMode == "" then
      cfg.bankPrintMode = (cfg.bankPrintEnabled == true) and "detail" or "off"
    end
    cfg.bankPrintMode = tostring(cfg.bankPrintMode or "basic"):lower()
    if cfg.bankPrintMode ~= "off" and cfg.bankPrintMode ~= "basic" and cfg.bankPrintMode ~= "detail" and cfg.bankPrintMode ~= "full" then
      cfg.bankPrintMode = (cfg.bankPrintEnabled == true) and "detail" or "off"
    end
    cfg.bankPrintEnabled = (cfg.bankPrintMode ~= "off")

    -- Manual bank move tracking (deposit/withdraw). Scope-scoped; stored per character when in Character scope.
    if cfg.manualBankMovesEnabled == nil then cfg.manualBankMovesEnabled = false end
    cfg.manualBankMovesEnabled = (cfg.manualBankMovesEnabled == true)
    cfg.sources = (type(cfg.sources) == "table") and cfg.sources or {}
    if cfg.sources.vendor == nil then cfg.sources.vendor = true end
    if cfg.sources.questLoot == nil then cfg.sources.questLoot = true end
    if cfg.sources.systemMoney == nil then cfg.sources.systemMoney = false end
    if cfg.sources.mail == nil then cfg.sources.mail = true end
    -- Auto Pay is the only supported mode now; keep the field for backward compatibility,
    -- but enforce it on so there is no â€œmanual-onlyâ€ state.
    cfg.autoPayOnGuildBankOpen = true
    cfg.enabled = (cfg.rate > 0)

    if cfg.warBankEnabled == nil then cfg.warBankEnabled = false end
    cfg.warBankEnabled = (cfg.warBankEnabled == true)

    -- Excess toggle (XS). Migrate legacy EB fields.
    if cfg.warBankXS == nil and cfg.warBankEB ~= nil then
      cfg.warBankXS = (cfg.warBankEB == true)
      cfg.warBankEB = nil
    end
    if cfg.guildBankXS == nil and cfg.guildBankEB ~= nil then
      cfg.guildBankXS = (cfg.guildBankEB == true)
      cfg.guildBankEB = nil
    end

    if cfg.warBankXS == nil then cfg.warBankXS = false end
    cfg.warBankXS = (cfg.warBankXS == true)

    if cfg.guildBankXS == nil then cfg.guildBankXS = false end
    cfg.guildBankXS = (cfg.guildBankXS == true)

    -- Scope-scoped safety/borrowing controls live on the active cfg.
    -- Migrate legacy per-character fields (ct.minGold/ct.allowWithdraw) into cfg if present.
    if cfg.minGold == nil and ct.minGold ~= nil then cfg.minGold = ct.minGold end
    if cfg.allowWithdraw == nil and ct.allowWithdraw ~= nil then cfg.allowWithdraw = ct.allowWithdraw end
    if cfg.excessMinGold == nil and ct.excessMinGold ~= nil then cfg.excessMinGold = ct.excessMinGold end
    if cfg.excessMinGoldUserSet == nil and ct.excessMinGoldUserSet ~= nil then cfg.excessMinGoldUserSet = ct.excessMinGoldUserSet end
    if cfg.excessMinUseToken == nil and ct.excessMinUseToken ~= nil then cfg.excessMinUseToken = ct.excessMinUseToken end
    if cfg.minGold == nil then cfg.minGold = 0 end
    cfg.minGold = Clamp(cfg.minGold, 0, 9999999) or 0
    if cfg.minGold < 0 then cfg.minGold = 0 end
    if cfg.excessMinGold == nil then cfg.excessMinGold = cfg.minGold end
    cfg.excessMinGold = Clamp(cfg.excessMinGold, 0, 9999999) or 0
    if cfg.excessMinGold < 0 then cfg.excessMinGold = 0 end
    if cfg.excessMinGoldUserSet == nil then cfg.excessMinGoldUserSet = false end
    cfg.excessMinGoldUserSet = (cfg.excessMinGoldUserSet == true)
    if cfg.excessMinUseToken == nil then cfg.excessMinUseToken = false end
    cfg.excessMinUseToken = (cfg.excessMinUseToken == true)
    if cfg.allowWithdraw == nil then cfg.allowWithdraw = false end
    cfg.allowWithdraw = (cfg.allowWithdraw == true)

    if ct.debug == nil then ct.debug = false end
    ct.debug = (ct.debug == true)

    if ct.showOwedSilverCopper == nil then ct.showOwedSilverCopper = false end
    ct.showOwedSilverCopper = (ct.showOwedSilverCopper == true)

    -- Character-scoped balances.
    ct.bal = (type(ct.bal) == "table") and ct.bal or {}
    ct.bal.due = math.floor(tonumber(ct.bal.due) or 0)
    ct.bal.paidToDate = math.floor(tonumber(ct.bal.paidToDate) or 0)
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
    if ct.bal.paidToDate < 0 then ct.bal.paidToDate = 0 end

    -- Warbank balances are ALWAYS character-scoped.
    ct.warBal = (type(ct.warBal) == "table") and ct.warBal or {}
    ct.warBal.due = math.floor(tonumber(ct.warBal.due) or 0)
    ct.warBal.paidToDate = math.floor(tonumber(ct.warBal.paidToDate) or 0)
    if ct.warBal.dueTax == nil and ct.warBal.dueBorrowed == nil then
      ct.warBal.dueTax = ct.warBal.due
      ct.warBal.dueBorrowed = 0
    end
    ct.warBal.dueTax = math.floor(tonumber(ct.warBal.dueTax) or 0)
    ct.warBal.dueBorrowed = math.floor(tonumber(ct.warBal.dueBorrowed) or 0)
    if ct.warBal.dueTax < 0 then ct.warBal.dueTax = 0 end
    if ct.warBal.dueBorrowed < 0 then ct.warBal.dueBorrowed = 0 end
    ct.warBal.due = ct.warBal.dueTax + ct.warBal.dueBorrowed
    if ct.warBal.due < 0 then ct.warBal.due = 0 end
    if ct.warBal.paidToDate < 0 then ct.warBal.paidToDate = 0 end

    return ct
  end

  local function IsTaxDebugEnabled()
    local ct = EnsureCharTaxDB()
    return (type(ct) == "table") and (ct.debug == true)
  end

  -- Expose for other modules (core) to gate debug prints.
  function Tax.IsDebugEnabled()
    return IsTaxDebugEnabled() == true
  end

  local function TaxDbg(cfg, line)
    if not IsTaxDebugEnabled() then return end
    if type(cfg) == "table" and cfg.quiet == true then return end
    if type(line) ~= "string" or line == "" then return end
    Print("Tax debug: " .. line)
  end

  local function GetActiveScopeCfgAndBal()
    local ct = EnsureCharTaxDB()
    local scope = (ct and ct.scope) or "guild"
    if scope == "character" then
      return "character", (ct and ct.cfg) or nil, (ct and ct.bal) or nil
    end

    local guildKey = select(1, GetCurrentGuildKeyAndName())
    if not guildKey then
      -- Config is guild-scoped, but without a guild we can't resolve a guild bucket.
      -- Fall back to character cfg so Warbank and local tax tracking still work.
      return "guild", (ct and ct.cfg) or nil, (ct and ct.bal) or nil
    end
    local g = EnsureGuildTaxDB(guildKey)
    if type(g) == "table" and g.owedScope == "characters" then
      return "guild", g, (g.sharedBal)
    end
    return "guild", g, (ct and ct.bal) or nil
  end

  local function NowTS()
    if type(time) == "function" then
      local v = math.floor(tonumber(time()) or 0)
      if v > 0 then return v end
    end
    return 0
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

  local function FormatGoldIconFromCopper(copper)
    copper = math.floor(tonumber(copper) or 0)
    if copper < 0 then copper = 0 end
    local gold = math.floor(copper / (COPPER_PER_GOLD or 10000))
    if gold < 0 then gold = 0 end
    return FormatIntWithCommas(gold) .. "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t"
  end

  local function FormatGoldFromCopperNoIcon(copper)
    copper = math.floor(tonumber(copper) or 0)
    if copper < 0 then copper = 0 end
    local gold = math.floor(copper / (COPPER_PER_GOLD or 10000))
    if gold < 0 then gold = 0 end
    return FormatIntWithCommas(gold)
  end

  local function FormatGoldIconFromCopperWithIcon(copper, iconPath)
    copper = math.floor(tonumber(copper) or 0)
    if copper < 0 then copper = 0 end
    local gold = math.floor(copper / (COPPER_PER_GOLD or 10000))
    if gold < 0 then gold = 0 end

    local tex = tostring(iconPath or "Interface\\MoneyFrame\\UI-GoldIcon")
    if tex == "" then tex = "Interface\\MoneyFrame\\UI-GoldIcon" end
    return FormatIntWithCommas(gold) .. "|T" .. tex .. ":0:0:2:0|t"
  end

  local function ColorLDBGoldText(text)
    text = tostring(text or "")
    if text == "" then return text end
    if text:find("|c%x%x%x%x%x%x%x%x") then
      return text
    end
    return "|cffffd100" .. text .. "|r"
  end

  local function GetWarbankControlStyle()
    local t = EnsureTaxDB()
    if type(t) ~= "table" then return "text" end
    t.ldbWarControlStyle = tostring(t.ldbWarControlStyle or "text"):lower()
    if t.ldbWarControlStyle ~= "text" and t.ldbWarControlStyle ~= "icon" then
      t.ldbWarControlStyle = "text"
    end
    return t.ldbWarControlStyle
  end

  local function GetCachedGuildAndWarbankMoney()
    local guildMoney = 0
    local warMoney = 0

    local guildKey = select(1, GetCurrentGuildKeyAndName())
    if guildKey then
      local g = EnsureGuildTaxDB(guildKey)
      guildMoney = math.floor(tonumber(g and g.guildBankMoneyCached) or 0)
      if guildMoney < 0 then guildMoney = 0 end
    end

    local t = EnsureTaxDB()
    warMoney = math.floor(tonumber(t and t.warBankMoneyCached) or 0)
    if warMoney < 0 then warMoney = 0 end

    return guildMoney, warMoney
  end

  local function HasWarbankControl()
    local bankType = (Enum and Enum.BankType) and Enum.BankType or nil
    local cBank = _G and rawget(_G, "C_Bank")
    if type(cBank) ~= "table" or type(bankType) ~= "table" or bankType.Account == nil then
      return false
    end

    -- Broker_Everything-style gate: fetched value exists and > 0.
    if type(cBank.FetchDepositedMoney) ~= "function" then
      return false
    end

    local ok, v = pcall(cBank.FetchDepositedMoney, bankType.Account)
    local money = ok and tonumber(v) or nil
    return (type(money) == "number" and money > 0)
  end

  local function GetWowTokenMarketPrice()
    local t = EnsureTaxDB()
    if not (C_WowTokenPublic and type(C_WowTokenPublic.GetCurrentMarketPrice) == "function") then
      if type(t) == "table" and tonumber(t.wowTokenMarketPriceCached) and tonumber(t.wowTokenMarketPriceCached) > 0 then
        lastTokenPrice = math.floor(tonumber(t.wowTokenMarketPriceCached) or 0)
        lastTokenPriceTS = math.floor(tonumber(t.wowTokenMarketPriceCachedTS) or 0)
        return lastTokenPrice
      end
      return lastTokenPrice
    end

    local ok, price = pcall(C_WowTokenPublic.GetCurrentMarketPrice)
    if not ok then
      if type(t) == "table" and tonumber(t.wowTokenMarketPriceCached) and tonumber(t.wowTokenMarketPriceCached) > 0 then
        lastTokenPrice = math.floor(tonumber(t.wowTokenMarketPriceCached) or 0)
        lastTokenPriceTS = math.floor(tonumber(t.wowTokenMarketPriceCachedTS) or 0)
        return lastTokenPrice
      end
      return lastTokenPrice
    end

    price = tonumber(price)
    if not price or price <= 0 then
      -- If the quote is stale, ask Blizzard to refresh it and try once more.
      local staleTS = tonumber(lastTokenPriceTS) or 0
      local now = NowTS()
      if now > 0 and staleTS > 0 and (now - staleTS) >= 180 then
        pcall(C_WowTokenPublic.UpdateMarketPrice)
        local okRetry, retryPrice = pcall(C_WowTokenPublic.GetCurrentMarketPrice)
        retryPrice = okRetry and tonumber(retryPrice) or nil
        if type(retryPrice) == "number" and retryPrice > 0 then
          price = math.floor(retryPrice)
        end
      end

      if price and price > 0 then
        lastTokenPrice = price
        lastTokenPriceTS = NowTS()
        if type(t) == "table" then
          t.wowTokenMarketPriceCached = price
          t.wowTokenMarketPriceCachedTS = lastTokenPriceTS
        end
        return price
      end

      if type(t) == "table" and tonumber(t.wowTokenMarketPriceCached) and tonumber(t.wowTokenMarketPriceCached) > 0 then
        lastTokenPrice = math.floor(tonumber(t.wowTokenMarketPriceCached) or 0)
        lastTokenPriceTS = math.floor(tonumber(t.wowTokenMarketPriceCachedTS) or 0)
        return lastTokenPrice
      end
      return lastTokenPrice
    end

    price = math.floor(price)
    lastTokenPrice = price
    lastTokenPriceTS = NowTS()
    if type(t) == "table" then
      t.wowTokenMarketPriceCached = price
      t.wowTokenMarketPriceCachedTS = lastTokenPriceTS
    end
    return price
  end

  local function RequestWowTokenPriceRefresh()
    if not (C_WowTokenPublic and type(C_WowTokenPublic.UpdateMarketPrice) == "function") then
      return
    end
    pcall(C_WowTokenPublic.UpdateMarketPrice)
  end

  function Tax.RefreshWowTokenPrice()
    RequestWowTokenPriceRefresh()
    local price = GetWowTokenMarketPrice()
    if type(price) == "number" and price > 0 then
      return price
    end
    return nil
  end

  local function ScheduleWowTokenRefreshes()
    local delays = { 2, 10, 30, 120 }
    if not (C_Timer and C_Timer.After) then
      RequestWowTokenPriceRefresh()
      return
    end
    for i = 1, #delays do
      C_Timer.After(delays[i], function()
        local price = Tax.RefreshWowTokenPrice and Tax.RefreshWowTokenPrice() or nil
        if type(price) == "number" and price > 0 then
          -- Stop trying once we have a usable value in cache.
          return
        end
      end)
    end
  end

  function Tax.GetWowTokenMarketPrice()
    return GetWowTokenMarketPrice()
  end

  function Tax.GetWowTokenMarketPriceCached()
    local t = EnsureTaxDB()
    if type(t) == "table" and tonumber(t.wowTokenMarketPriceCached) and tonumber(t.wowTokenMarketPriceCached) > 0 then
      return math.floor(tonumber(t.wowTokenMarketPriceCached) or 0)
    end
    return lastTokenPrice
  end

  local function GetWowTokenDisplayText()
    local price = GetWowTokenMarketPrice()
    if type(price) == "number" and price > 0 then
      local useCached = (type(lastTokenPrice) == "number" and lastTokenPrice > 0 and price == lastTokenPrice and (NowTS() - (tonumber(lastTokenPriceTS) or 0) >= 180))
      local suffix = useCached and " *" or ""
      return "WoW Token: " .. FormatGoldIconFromCopper(price) .. suffix
    end

    if type(lastTokenPrice) == "number" and lastTokenPrice > 0 then
      return "WoW Token: " .. FormatGoldIconFromCopper(lastTokenPrice) .. " *"
    end

    return "WoW Token: unavailable"
  end

  local function GetTaxLDBText()
    local t = EnsureTaxDB()
    local disp = (type(t) == "table" and type(t.ldbDisplay) == "table") and t.ldbDisplay or { player = true, guild = true, war = true }

    local parts = {}
    if disp.player == true then
      local playerMoney = math.floor(tonumber(GetMoney and GetMoney() or 0) or 0)
      if playerMoney < 0 then playerMoney = 0 end
      parts[#parts + 1] = ColorLDBGoldText(FormatGoldIconFromCopper(playerMoney))
    end

    local guildMoney, warMoney = GetCachedGuildAndWarbankMoney()
    local warText
    local hasWarControl = HasWarbankControl()
    if GetWarbankControlStyle() == "icon" then
      if hasWarControl then
        warText = ColorLDBGoldText(FormatGoldIconFromCopperWithIcon(warMoney, "Interface\\MoneyFrame\\UI-GoldIcon"))
      else
        warText = ColorLDBGoldText(FormatGoldFromCopperNoIcon(warMoney))
      end
    else
      warText = ColorLDBGoldText(FormatGoldIconFromCopper(warMoney))
      if hasWarControl then
        warText = "|cffffd100" .. warText .. "|r"
      end
    end
    if disp.guild == true then
      parts[#parts + 1] = ColorLDBGoldText(FormatGoldIconFromCopper(guildMoney))
    end
    if disp.war == true then
      parts[#parts + 1] = warText
    end

    if #parts == 0 then
      return ColorLDBGoldText(FormatGoldIconFromCopper(guildMoney)) .. "    " .. warText
    end
    return table.concat(parts, "    ")
  end

  local function GetCurrentMapID()
    if not (C_Map and type(C_Map.GetBestMapForUnit) == "function") then
      return nil
    end
    local ok, mapID = pcall(C_Map.GetBestMapForUnit, "player")
    if not ok then
      return nil
    end
    mapID = tonumber(mapID)
    if not mapID or mapID <= 0 then
      return nil
    end
    return math.floor(mapID)
  end

  local function GetCurrentHearthLocationText()
    local hearth = (type(ns) == "table") and ns.Hearth or nil
    if type(hearth) == "table" then
      if type(hearth.GetCurrentDisplayText) == "function" then
        local a, b = hearth.GetCurrentDisplayText()
        a = tostring(a or "")
        b = tostring(b or "")
        if a ~= "" and b ~= "" then
          return a .. ", " .. b
        end
        if a ~= "" then
          return a
        end
        if b ~= "" then
          return b
        end
      end
      if type(hearth.GetHomeZoneContinentText) == "function" then
        local txt = tostring(hearth.GetHomeZoneContinentText() or "")
        if txt ~= "" then
          return txt
        end
      end
    end
    return "unknown"
  end

  local function UpdateTaxLDBText()
    if type(Tax.LDB) == "table" then
      Tax.LDB.text = GetTaxLDBText()
    end
  end

  -- Re-read the cached values and push the latest text to the LDB broker.
  -- Called from Core on PLAYER_ENTERING_WORLD so the correct guild GUID key
  -- is available (guild data is not guaranteed to be ready at PLAYER_LOGIN).
  function Tax.RefreshLDB()
    UpdateTaxLDBText()
  end

  local function ToggleTaxOptionsTab()
    if AutoGameOptions and type(AutoGameOptions.IsShown) == "function" and AutoGameOptions:IsShown() then
      if type(AutoGameOptions.Hide) == "function" then
        AutoGameOptions:Hide()
      end
      return
    end

    if type(_G) == "table" and type(_G.FGO_OpenOptionsTab) == "function" then
      pcall(_G.FGO_OpenOptionsTab, 10, true)
      return
    end
    if AutoGameOptions and type(AutoGameOptions.Show) == "function" then
      pcall(function()
        AutoGameOptions:Show()
        if type(AutoGameOptions.SelectTab) == "function" then
          AutoGameOptions:SelectTab(10)
        end
      end)
    end
  end

  local function EnsureTaxLDB()
    if type(Tax.LDB) == "table" then
      return Tax.LDB
    end
    if type(LibStub) ~= "table" then
      return nil
    end

    local ok, ldb = pcall(function()
      return LibStub:GetLibrary("LibDataBroker-1.1")
    end)
    if not ok or type(ldb) ~= "table" then
      return nil
    end

    Tax.LDB = ldb:NewDataObject("FGO Money", {
      type = "data source",
      text = GetTaxLDBText(),
      icon = "Interface\\MoneyFrame\\UI-GoldIcon",
      OnClick = function(_, button)
        if button == "RightButton" then
          ToggleTaxOptionsTab()
        end
      end,
      OnTooltipShow = function(tooltip)
        if not (tooltip and tooltip.AddLine) then return end
        local title = "|cff0080FFTax Owed|r"
        local _, _, bal = GetActiveScopeCfgAndBal()
        local guildOwed = (type(bal) == "table") and math.floor(tonumber(bal.due) or 0) or 0
        if guildOwed < 0 then guildOwed = 0 end
        local ct = EnsureCharTaxDB()
        local wb = ct and ct.warBal
        local warOwed = (type(wb) == "table") and math.floor(tonumber(wb.due) or 0) or 0
        if warOwed < 0 then warOwed = 0 end
        local owedLine = FormatGoldIconFromCopper(guildOwed) .. "  |  " .. FormatGoldIconFromCopper(warOwed)
        tooltip:AddLine(title .. "    " .. owedLine)

        local tokenText = GetWowTokenDisplayText()
        tooltip:AddLine(tokenText, 0.8, 0.8, 0.8)

        tooltip:AddLine("Hearth: " .. GetCurrentHearthLocationText(), 0.8, 0.8, 0.8)
      end,
    })

    return Tax.LDB
  end

  local function CacheGuildBankMoneyFromAPI()
    local guildKey = select(1, GetCurrentGuildKeyAndName())
    if not guildKey then return end
    local g = EnsureGuildTaxDB(guildKey)
    if type(g) ~= "table" then return end
    if type(GetGuildBankMoney) ~= "function" then return end

    local ok, v = pcall(GetGuildBankMoney)
    local money = ok and math.floor(tonumber(v) or 0) or nil
    if type(money) == "number" and money >= 0 then
      g.guildBankMoneyCached = money
      g.guildBankMoneyCachedTS = NowTS()
      UpdateTaxLDBText()
    end
  end

  local function CacheWarbankMoneyFromAPI()
    local t = EnsureTaxDB()
    if type(t) ~= "table" then return end

    local bankType = (Enum and Enum.BankType) and Enum.BankType or nil
    local cBank = _G and rawget(_G, "C_Bank")
    if type(cBank) ~= "table" then return end

    local function HasWarbankAccess()
      local canDeposit = nil
      local canWithdraw = nil

      if bankType and bankType.Account ~= nil then
        if type(cBank.CanDepositMoney) == "function" then
          local ok, can = pcall(cBank.CanDepositMoney, bankType.Account)
          if ok then canDeposit = can end
        end
        if type(cBank.CanWithdrawMoney) == "function" then
          local ok, can = pcall(cBank.CanWithdrawMoney, bankType.Account)
          if ok then canWithdraw = can end
        end
      end

      return canDeposit ~= false or canWithdraw ~= false
    end

    if type(cBank.FetchDepositedMoney) == "function" and bankType and bankType.Account ~= nil then
      local ok, v = pcall(cBank.FetchDepositedMoney, bankType.Account)
      local money = ok and math.floor(tonumber(v) or 0) or nil
      if type(money) == "number" and money >= 0 then
        if money == 0 and t.warBankMoneyCached ~= nil and not HasWarbankAccess() then
          return
        end
        t.warBankMoneyCached = money
        t.warBankMoneyCachedTS = NowTS()
        UpdateTaxLDBText()
        return
      end
    end

    local typeCandidates = {}
    if type(bankType) == "table" then
      if bankType.Account ~= nil then typeCandidates[#typeCandidates + 1] = bankType.Account end
      if bankType.AccountBank ~= nil then typeCandidates[#typeCandidates + 1] = bankType.AccountBank end
      if bankType.Warband ~= nil then typeCandidates[#typeCandidates + 1] = bankType.Warband end
      if bankType.WarbandBank ~= nil then typeCandidates[#typeCandidates + 1] = bankType.WarbandBank end
    end

    local function TryMoneyCall(fn)
      if type(fn) ~= "function" then return nil end

      -- API signatures vary by client build. Try typed calls first, then no-arg fallback.
      for i = 1, #typeCandidates do
        local ok, v = pcall(fn, typeCandidates[i])
        if ok then
          local n = tonumber(v)
          if type(n) == "number" and n >= 0 then
            return math.floor(n)
          end
        end
      end

      local okNoArg, vNoArg = pcall(fn)
      if okNoArg then
        local n = tonumber(vNoArg)
        if type(n) == "number" and n >= 0 then
          return math.floor(n)
        end
      end

      return nil
    end

    local money = nil
    -- Best-effort: API names/signatures vary by client build.
    money = TryMoneyCall(cBank.GetBankMoney)
    if money == nil then
      money = TryMoneyCall(cBank.GetMoney)
    end

    if type(money) == "number" and money >= 0 then
      if money == 0 and t.warBankMoneyCached ~= nil and not HasWarbankAccess() then
        return
      end
      t.warBankMoneyCached = money
      t.warBankMoneyCachedTS = NowTS()
      UpdateTaxLDBText()
    end
  end

  local function ApplyBankDeltaToCaches(bankKind, playerMoneyDelta)
    playerMoneyDelta = math.floor(tonumber(playerMoneyDelta) or 0)
    if playerMoneyDelta == 0 then return end
    local bankDelta = -playerMoneyDelta

    if bankKind == "guild" then
      local guildKey = select(1, GetCurrentGuildKeyAndName())
      if not guildKey then return end
      local g = EnsureGuildTaxDB(guildKey)
      if type(g) ~= "table" then return end

      if g.guildBankMoneyCached == nil then
        CacheGuildBankMoneyFromAPI()
      end
      local cur = tonumber(g.guildBankMoneyCached)
      if type(cur) ~= "number" then return end
      cur = math.floor(cur)
      cur = cur + bankDelta
      if cur < 0 then cur = 0 end
      g.guildBankMoneyCached = cur
      g.guildBankMoneyCachedTS = NowTS()
      UpdateTaxLDBText()
      return
    end

    if bankKind == "warbank" then
      local t = EnsureTaxDB()
      if type(t) ~= "table" then return end

      if t.warBankMoneyCached == nil then
        CacheWarbankMoneyFromAPI()
      end
      local cur = tonumber(t.warBankMoneyCached)
      if type(cur) ~= "number" then return end
      cur = math.floor(cur)
      cur = cur + bankDelta
      if cur < 0 then cur = 0 end
      t.warBankMoneyCached = cur
      t.warBankMoneyCachedTS = NowTS()
      UpdateTaxLDBText()
      return
    end
  end

  -- When both bank XS toggles are enabled, route excess to the bank with the lower cached balance.
  -- If balances are unavailable or tied, prefer the currently active bank.
  local function ComputeEBExtraSplit(extra, guildMoneyCached, warMoneyCached, preferGuild)
    extra = math.floor(tonumber(extra) or 0)
    if extra <= 0 then return 0, 0 end

    local g = (type(guildMoneyCached) == "number") and math.floor(guildMoneyCached) or nil
    local w = (type(warMoneyCached) == "number") and math.floor(warMoneyCached) or nil
    if g == nil or w == nil then
      if preferGuild == true then
        return extra, 0
      end
      return 0, extra
    end
    if g < 0 then g = 0 end
    if w < 0 then w = 0 end

    if g == w then
      if preferGuild == true then
        return extra, 0
      end
      return 0, extra
    end

    if g < w then
      return extra, 0
    end

    return 0, extra
  end

  local function MoneyToString(copper)
    copper = math.floor(tonumber(copper) or 0)
    if copper < 0 then copper = 0 end
    if type(GetMoneyString) == "function" then
      local ok, res = pcall(GetMoneyString, copper)
      if ok and type(res) == "string" then
        return res
      end
    end
    return tostring(copper) .. "c"
  end

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

  local function PrintBankMove(cfg, copper, direction, bank)
    if type(cfg) ~= "table" then return end
    if cfg.quiet == true then return end
    if tostring(cfg.bankPrintMode or ""):lower() == "off" then return end
    if not (cfg.bankPrintEnabled == true) then return end
    copper = math.floor(tonumber(copper) or 0)
    if copper <= 0 then return end

    local function NormalizeBankLabel(bankName)
      local raw = tostring(bankName or "")
      raw = raw:gsub("^%s+", ""):gsub("%s+$", "")
      local key = raw:lower():gsub("%s+", "")
      if key == "guildbank" or key == "guild" then
        return "Guild Bank", "guild"
      end
      if key == "warbank" or key == "warbandbank" or key == "warband" then
        return "Warband Bank", "warbank"
      end
      if key == "" then
        return "Bank", "bank"
      end
      return raw, key
    end

    local function NormalizeDirection(dir)
      local s = tostring(dir or "")
      local k = s:lower():gsub("%s+", "")
      if k:find("withdraw", 1, true) then
        return "Withdraw"
      end
      if k:find("deposit", 1, true) then
        return "deposited to"
      end
      return s
    end

    local bankLabel, bankKey = NormalizeBankLabel(bank)
    direction = NormalizeDirection(direction)
    local bankShort = bankLabel
    if bankKey == "guild" then
      bankShort = "GB"
    elseif bankKey == "warbank" then
      bankShort = "WB"
    end

    -- Safety: only print while the relevant frame is actually open.
    if bankKey == "guild" then
      local f = _G and rawget(_G, "GuildBankFrame")
      if not (f and f.IsShown and f:IsShown()) then return end
    elseif bankKey == "warbank" or bankKey == "bank" then
      local f = _G and rawget(_G, "BankFrame")
      if not (f and f.IsShown and f:IsShown()) then return end
    end

    if direction == "Withdraw" then
      Print(GetClassColoredPlayerName() .. " " .. bankShort .. " " .. tostring(direction or "") .. " " .. FormatGoldOnly(copper))
    else
      Print(GetClassColoredPlayerName() .. " " .. FormatGoldOnly(copper) .. " " .. tostring(direction or "") .. " " .. bankLabel)
    end
  end

  local function GetBankPrintMode(cfg)
    if type(cfg) ~= "table" then return "off" end
    local mode = tostring(cfg.bankPrintMode or "")
    mode = mode:lower()
    if mode == "off" or mode == "basic" or mode == "detail" or mode == "full" then
      return mode
    end
    if cfg.bankPrintEnabled == true then
      return "basic"
    end
    return "off"
  end

  local function PrintTaxAutoDeposit(cfg, bankName, toPayCopper, info)
    if type(cfg) ~= "table" then return end
    if cfg.quiet == true then return end
    if not (cfg.bankPrintEnabled == true) then return end

    local mode = GetBankPrintMode(cfg)
    if mode == "off" then return end

    local copper = math.floor(tonumber(toPayCopper) or 0)
    if copper <= 0 then return end

    if mode == "basic" then
      PrintBankMove(cfg, copper, "deposited to", bankName)
      return
    end

    local function NormalizeBankLabel(bankName2)
      local raw = tostring(bankName2 or "")
      raw = raw:gsub("^%s+", ""):gsub("%s+$", "")
      local key = raw:lower():gsub("%s+", "")
      if key == "guildbank" or key == "guild" then
        return "Guild Bank", "guild"
      end
      if key == "warbank" or key == "warbandbank" or key == "warband" then
        return "Warband Bank", "warbank"
      end
      if key == "" then
        return "Bank", "bank"
      end
      return raw, key
    end

    local bankLabel, bankKey = NormalizeBankLabel(bankName)

    -- Safety: only print while the relevant frame is actually open.
    if bankKey == "guild" then
      local f = _G and rawget(_G, "GuildBankFrame")
      if not (f and f.IsShown and f:IsShown()) then return end
    elseif bankKey == "warbank" or bankKey == "bank" then
      local f = _G and rawget(_G, "BankFrame")
      if not (f and f.IsShown and f:IsShown()) then return end
    end

    local owedTax = math.floor(tonumber(info and info.owedTax) or 0)
    local owedBorrowed = math.floor(tonumber(info and info.owedBorrowed) or 0)
    if owedTax < 0 then owedTax = 0 end
    if owedBorrowed < 0 then owedBorrowed = 0 end
    local owed = math.floor(tonumber(info and info.owed) or (owedTax + owedBorrowed) or 0)
    if owed < 0 then owed = 0 end

    local xsOn = (info and info.xsEnabled == true) and true or false
    local payToOwed = math.floor(tonumber(info and info.payToOwed) or 0)
    if payToOwed < 0 then payToOwed = 0 end
    if payToOwed == 0 then
      payToOwed = copper
      if payToOwed > owed then payToOwed = owed end
      if payToOwed < 0 then payToOwed = 0 end
    end
    if payToOwed > copper then payToOwed = copper end
    local payToXS = copper - payToOwed
    if payToXS < 0 then payToXS = 0 end

    local name = GetClassColoredPlayerName()
    local paidGold = FormatGoldOnly(copper)

    if mode == "detail" then
      local bankShort = "B"
      if bankKey == "guild" then
        bankShort = "GB"
      elseif bankKey == "warbank" then
        bankShort = "WB"
      end

      -- Compact output:
      --  Name: GB/WB Deposit <paidToOwed> / <owed> Owed
      --  (optional) Name: GB/WB Deposit <totalMoneyMinusOwed> - <paidToXS> XS
      Print(name .. " " .. bankShort .. " Deposit  " .. FormatGoldOnly(payToOwed) .. " / " .. FormatGoldOnly(owed) .. " Owed")

      if xsOn and payToXS > 0 then
        local totalMoney = math.floor(tonumber(info and info.totalMoney) or 0) -- full pre-deposit snapshot
        if totalMoney < 0 then totalMoney = 0 end
        local totalMoneyMinusOwed = math.floor(totalMoney - payToOwed)
        if totalMoneyMinusOwed < 0 then totalMoneyMinusOwed = 0 end
        Print(name .. " " .. bankShort .. " Deposit  " .. FormatGoldOnly(totalMoneyMinusOwed) .. " - " .. FormatGoldOnly(payToXS) .. " XS")
      end
      return
    end

    -- full (multi-line)
    local prefix = name .. " " .. paidGold .. " deposited to " .. bankLabel
    Print(prefix)
    Print("  owed=" .. MoneyToString(owed) .. " (tax=" .. MoneyToString(owedTax) .. ", borrowed=" .. MoneyToString(owedBorrowed) .. ")")
    Print("  paid: owed=" .. MoneyToString(payToOwed) .. ", XS=" .. MoneyToString(payToXS) .. " (XS " .. (xsOn and "ON" or "OFF") .. ")")
    local minCopper = math.floor(tonumber(info and info.minCopper) or 0)
    local available = math.floor(tonumber(info and info.available) or 0)
    local totalOwed = math.floor(tonumber(info and info.totalOwed) or 0)
    if minCopper < 0 then minCopper = 0 end
    if available < 0 then available = 0 end
    if totalOwed < 0 then totalOwed = 0 end
    Print("  Min=" .. MoneyToString(minCopper) .. ", available=" .. MoneyToString(available) .. ", totalOwed(all banks)=" .. MoneyToString(totalOwed))
  end

  local function PushPendingDelta(queue, delta)
    if type(queue) ~= "table" then return end
    delta = math.floor(tonumber(delta) or 0)
    if delta == 0 then return end
    queue[#queue + 1] = delta
  end

  local function PopIfMatches(queue, delta)
    if type(queue) ~= "table" or #queue == 0 then return false end
    delta = math.floor(tonumber(delta) or 0)
    if delta == 0 then return false end
    if queue[1] ~= delta then return false end
    table.remove(queue, 1)
    return true
  end

  local function ApplyManualDepositOrWithdraw(cfg, bal, delta, bankLabel)
    if type(cfg) ~= "table" or type(bal) ~= "table" then return end
    if not (cfg.manualBankMovesEnabled == true) then
      if IsTaxDebugEnabled() and not (cfg.quiet == true) then
        Print("Manual " .. tostring(bankLabel or "Bank") .. " ignored: Manual OFF.")
      end
      return
    end

    delta = math.floor(tonumber(delta) or 0)
    if delta == 0 then return end

    if IsTaxDebugEnabled() and not (cfg.quiet == true) then
      Print("Manual " .. tostring(bankLabel or "Bank") .. " delta: " .. tostring(delta))
    end

    -- delta > 0 => player gained money => withdrew from bank.
    if delta > 0 then
      bal.dueBorrowed = math.floor((tonumber(bal.dueBorrowed) or 0) + delta)
      if bal.dueBorrowed < 0 then bal.dueBorrowed = 0 end
      bal.dueTax = math.floor(tonumber(bal.dueTax) or 0)
      if bal.dueTax < 0 then bal.dueTax = 0 end
      bal.due = bal.dueTax + bal.dueBorrowed
      if type(time) == "function" then
        local now = math.floor(tonumber(time()) or 0)
        if now > 0 then
          bal.borrowedLastTS = now
        end
      end
      PrintBankMove(cfg, delta, "withdrawn from", bankLabel)
      RequestUIRefresh()
      return
    end

    -- delta < 0 => player spent money => deposited to bank.
    local deposit = -delta
    if deposit <= 0 then return end

    local dueTax = math.floor(tonumber(bal.dueTax) or 0)
    local dueBorrowed = math.floor(tonumber(bal.dueBorrowed) or 0)
    if dueTax < 0 then dueTax = 0 end
    if dueBorrowed < 0 then dueBorrowed = 0 end
    local due = dueTax + dueBorrowed
    if due <= 0 then
      if IsTaxDebugEnabled() and not (cfg.quiet == true) then
        Print("Manual " .. tostring(bankLabel or "Bank") .. " deposit ignored: nothing owed.")
      end
      return
    end

    local pay = deposit
    if pay > due then pay = due end
    if pay <= 0 then return end

    local payTax = pay
    if payTax > dueTax then payTax = dueTax end
    local remain = pay - payTax
    local payBorrowed = remain
    if payBorrowed > dueBorrowed then payBorrowed = dueBorrowed end

    bal.dueTax = math.floor(dueTax - payTax)
    bal.dueBorrowed = math.floor(dueBorrowed - payBorrowed)
    if bal.dueTax < 0 then bal.dueTax = 0 end
    if bal.dueBorrowed < 0 then bal.dueBorrowed = 0 end
    bal.due = bal.dueTax + bal.dueBorrowed
    bal.paidToDate = math.floor((tonumber(bal.paidToDate) or 0) + pay)

    PrintBankMove(cfg, pay, "deposited to", bankLabel)
    RequestUIRefresh()
  end

  local BORROW_APR = 0.1149 -- 11.49% per annum
  local YEAR_SECONDS = 31557600 -- 365.25 days

  local function AccrueBorrowedInterest(bal)
    if type(bal) ~= "table" then return end
    local borrowed = math.floor(tonumber(bal.dueBorrowed) or 0)
    if borrowed <= 0 then
      bal.borrowedLastTS = math.floor(tonumber(bal.borrowedLastTS) or 0)
      return
    end
    if type(time) ~= "function" then return end
    local now = math.floor(tonumber(time()) or 0)
    if now <= 0 then return end

    local last = math.floor(tonumber(bal.borrowedLastTS) or 0)
    if last <= 0 or last > now then
      bal.borrowedLastTS = now
      return
    end

    local dt = now - last
    if dt < 60 then return end

    local growth = (1 + BORROW_APR) ^ (dt / YEAR_SECONDS)
    local newBorrowed = math.floor((borrowed * growth) + 0.5)
    if newBorrowed < borrowed then newBorrowed = borrowed end
    if newBorrowed > borrowed then
      bal.dueBorrowed = newBorrowed
      bal.dueTax = math.floor(tonumber(bal.dueTax) or 0)
      if bal.dueTax < 0 then bal.dueTax = 0 end
      bal.due = bal.dueTax + bal.dueBorrowed
    end
    bal.borrowedLastTS = now
  end

  local function AddDue(rawCopper, label)
    rawCopper = math.floor(tonumber(rawCopper) or 0)
    if rawCopper <= 0 then return end

    local _, cfg, bal = GetActiveScopeCfgAndBal()
    if type(cfg) ~= "table" then return end
    if type(bal) ~= "table" then return end
    if not (cfg.enabled == true) then return end

    local rate = Clamp(cfg.rate, 0, 100) or 0
    if rate <= 0 then return end

    local taxCopper = math.floor((rawCopper * rate / 100) + 0.5)
    if taxCopper <= 0 then return end

    bal.dueTax = math.floor((tonumber(bal.dueTax) or 0) + taxCopper)
    if bal.dueTax < 0 then bal.dueTax = 0 end
    bal.dueBorrowed = math.floor(tonumber(bal.dueBorrowed) or 0)
    if bal.dueBorrowed < 0 then bal.dueBorrowed = 0 end
    bal.due = bal.dueTax + bal.dueBorrowed

    -- Tax should only print on deposit; other informational prints are Debug-only.
    if IsTaxDebugEnabled() and not (cfg.quiet == true) then
      Print(string.format("%s Contribution: %s", tostring(label or "Tax"), MoneyToString(taxCopper)))
    end

    -- Warbank: when enabled, accrue the same tax percentage to the character-only warbank bucket.
    if cfg.warBankEnabled == true then
      local ct = EnsureCharTaxDB()
      local wb = ct and ct.warBal
      if type(wb) == "table" then
        wb.dueTax = math.floor((tonumber(wb.dueTax) or 0) + taxCopper)
        if wb.dueTax < 0 then wb.dueTax = 0 end
        wb.dueBorrowed = math.floor(tonumber(wb.dueBorrowed) or 0)
        if wb.dueBorrowed < 0 then wb.dueBorrowed = 0 end
        wb.due = wb.dueTax + wb.dueBorrowed
      end
    end
  end

  local function TryPayGuildBank(isAuto)
    local scope, cfg, bal = GetActiveScopeCfgAndBal()
    if type(cfg) ~= "table" then return end
    if type(bal) ~= "table" then return end

    AccrueBorrowedInterest(bal)

    if scope == "guild" then
      -- No guild = no tax.
      local guildKey = select(1, GetCurrentGuildKeyAndName())
      if not guildKey then
        return
      end
    end

    if isAuto and not (cfg.autoPayOnGuildBankOpen == true) then
      return
    end

    local ct = EnsureCharTaxDB()
    local minGold
    if type(cfg) == "table" and cfg.minGold ~= nil then
      minGold = tonumber(cfg.minGold) or 0
    else
      -- Backward compatibility fallback (pre-scope-scoped Min Gold).
      minGold = ct and (tonumber(ct.minGold) or 0) or 0
    end
    if minGold < 0 then minGold = 0 end
    local minCopper = math.floor(minGold * (COPPER_PER_GOLD or 10000))
    if minCopper < 0 then minCopper = 0 end

    local excessMinGold = minGold
    if type(cfg) == "table" and cfg.excessMinGold ~= nil then
      excessMinGold = tonumber(cfg.excessMinGold) or minGold
    end
    if type(cfg) == "table" and cfg.excessMinUseToken == true then
      local tokenCopper = GetWowTokenMarketPrice()
      local tokenGold = math.floor((tonumber(tokenCopper) or 0) / (COPPER_PER_GOLD or 10000))
      if tokenGold > 0 then
        excessMinGold = tokenGold
      end
    end
    if excessMinGold < 0 then excessMinGold = 0 end
    local excessMinCopper = math.floor(excessMinGold * (COPPER_PER_GOLD or 10000))
    if excessMinCopper < 0 then excessMinCopper = 0 end

    local allowWithdraw
    if type(cfg) == "table" and cfg.allowWithdraw ~= nil then
      allowWithdraw = (cfg.allowWithdraw == true)
    else
      -- Backward compatibility fallback (pre-scope-scoped Withdraw).
      allowWithdraw = (ct and ct.allowWithdraw == true) and true or false
    end

    local function GetNowSecondsLocal()
      if type(GetTime) == "function" then
        return tonumber(GetTime()) or 0
      end
      if type(time) == "function" then
        return tonumber(time()) or 0
      end
      return 0
    end

    local function CanDeposit()
      if type(CanDepositGuildBankMoney) == "function" then
        local ok, can = pcall(CanDepositGuildBankMoney)
        if ok and can == false then
          return false, "Tax deposit failed: cannot deposit to guild bank."
        end
      end
      if type(DepositGuildBankMoney) ~= "function" then
        return false, "Tax deposit failed: guild bank API unavailable."
      end
      return true
    end

    local function DoDeposit()
      local xsEnabled = (cfg.guildBankXS == true)
      local dueTax = math.floor(tonumber(bal.dueTax) or 0)
      local dueBorrowed = math.floor(tonumber(bal.dueBorrowed) or 0)
      if dueTax < 0 then dueTax = 0 end
      if dueBorrowed < 0 then dueBorrowed = 0 end

      -- Prevent immediate payback of a just-borrowed amount from the same auto-withdraw cycle.
      local suppressBorrowedRepay = false
      do
        local now = GetNowSecondsLocal()
        local lastBorrow = tonumber(state._guildBorrowedAtTS) or 0
        if now > 0 and lastBorrow > 0 and (now - lastBorrow) < 2.0 then
          suppressBorrowedRepay = true
        end
      end

      local duePayBorrowed = suppressBorrowedRepay and 0 or dueBorrowed
      local duePayable = dueTax + duePayBorrowed
      local dueFull = dueTax + dueBorrowed
      if duePayable <= 0 and not xsEnabled then return end

      -- XS: only pay excess above MinGold + owed.
      local warDue = 0
      if cfg.warBankEnabled == true then
        local ct = EnsureCharTaxDB()
        local wb = ct and ct.warBal
        if type(wb) == "table" then
          local wTax = math.floor(tonumber(wb.dueTax) or 0)
          local wBorrow = math.floor(tonumber(wb.dueBorrowed) or 0)
          if wTax < 0 then wTax = 0 end
          if wBorrow < 0 then wBorrow = 0 end
          warDue = wTax + wBorrow
          if warDue < 0 then warDue = 0 end
        end
      end
      local totalOwed = dueFull + warDue

      local okCan, why = CanDeposit()
      if not okCan then
        if IsTaxDebugEnabled() and not (cfg.quiet == true) and why then Print(why) end
        return
      end

      local money = math.floor(tonumber(GetMoney and GetMoney() or 0) or 0)
      local available = money
      if minCopper > 0 then
        available = money - minCopper
      end
      if available < 0 then available = 0 end

      local toPay
      if xsEnabled then
        local availableForXS = money - excessMinCopper
        if availableForXS < 0 then availableForXS = 0 end
        local extra = availableForXS - totalOwed
        if extra < 0 then extra = 0 end
        if scope == "guild" and cfg.warBankEnabled == true and cfg.warBankXS == true then
          local guildKey = select(1, GetCurrentGuildKeyAndName())
          local g = guildKey and EnsureGuildTaxDB(guildKey) or nil
          local gMoney = (type(g) == "table") and g.guildBankMoneyCached or nil
          local t = EnsureTaxDB()
          local wMoney = (type(t) == "table") and t.warBankMoneyCached or nil
          local extraGuild, extraWar = ComputeEBExtraSplit(extra, gMoney, wMoney, true)
          TaxDbg(cfg, string.format(
            "XS split: extra=%d gCached=%s wCached=%s -> gExtra=%d wExtra=%d",
            extra,
            tostring(gMoney),
            tostring(wMoney),
            math.floor(tonumber(extraGuild) or 0),
            math.floor(tonumber(extraWar) or 0)
          ))
          toPay = duePayable + extraGuild
        else
          toPay = duePayable + extra
        end
      else
        toPay = duePayable
        if toPay > available then
          toPay = available
        end
      end
      -- Always cap deposits to funds above Min Gold.
      -- XS changes only how "extra" is computed, not how much can be paid below Min.
      local maxPay = available
      if maxPay < 0 then maxPay = 0 end
      if toPay > maxPay then
        toPay = maxPay
      end
      toPay = math.floor(tonumber(toPay) or 0)
      if toPay <= 0 then
        if IsTaxDebugEnabled() and (not isAuto) and (not (cfg.quiet == true)) and minCopper > 0 then
          Print("Tax deposit skipped: below Min Gold.")
        end
        return
      end

      C_Timer.After(0.30, function()
        state._pendingGuildDeltas = (type(state._pendingGuildDeltas) == "table") and state._pendingGuildDeltas or {}
        PushPendingDelta(state._pendingGuildDeltas, -toPay)
        local ok = pcall(DepositGuildBankMoney, toPay)
        if ok then
          ApplyBankDeltaToCaches("guild", -toPay)
          local payToDue = toPay
          if payToDue > duePayable then payToDue = duePayable end

          local payTax = payToDue
          if payTax > dueTax then payTax = dueTax end
          local remain = payToDue - payTax
          local payBorrowed = suppressBorrowedRepay and 0 or remain
          if payBorrowed > dueBorrowed then payBorrowed = dueBorrowed end

          bal.dueTax = math.floor(dueTax - payTax)
          bal.dueBorrowed = math.floor(dueBorrowed - payBorrowed)
          if bal.dueTax < 0 then bal.dueTax = 0 end
          if bal.dueBorrowed < 0 then bal.dueBorrowed = 0 end
          bal.due = bal.dueTax + bal.dueBorrowed
          bal.paidToDate = math.floor((tonumber(bal.paidToDate) or 0) + toPay)
          PrintTaxAutoDeposit(cfg, "Guild Bank", toPay, {
            totalMoney = money,
            owedTax = dueTax,
            owedBorrowed = dueBorrowed,
            owed = dueFull,
            xsEnabled = xsEnabled,
            payToOwed = payToDue,
            extra = extra,
            minCopper = minCopper,
            available = available,
            totalOwed = totalOwed,
          })
          RequestUIRefresh()
        else
          if IsTaxDebugEnabled() and not (cfg.quiet == true) then Print("Tax deposit failed.") end
          RequestUIRefresh()
        end
      end)
    end

    -- If enabled, keep player at or above Min Gold by borrowing from the guild bank.
    -- This debt cannot be cleared, accrues interest, and is paid AFTER normal tax due.
    if allowWithdraw and minCopper > 0 and type(WithdrawGuildBankMoney) == "function" then
      local money = math.floor(tonumber(GetMoney and GetMoney() or 0) or 0)
      if money < minCopper then
        local need = math.floor(minCopper - money)
        if need > 0 then
          local canWithdraw = true
          if type(CanWithdrawGuildBankMoney) == "function" then
            local okW, can = pcall(CanWithdrawGuildBankMoney)
            if okW and can == false then
              canWithdraw = false
            end
          end
          if canWithdraw then
            state._pendingGuildDeltas = (type(state._pendingGuildDeltas) == "table") and state._pendingGuildDeltas or {}
            PushPendingDelta(state._pendingGuildDeltas, need)
            local ok = pcall(WithdrawGuildBankMoney, need)
            if ok then
              ApplyBankDeltaToCaches("guild", need)
              state._guildBorrowedAtTS = GetNowSecondsLocal()
              bal.dueBorrowed = math.floor((tonumber(bal.dueBorrowed) or 0) + need)
              if bal.dueBorrowed < 0 then bal.dueBorrowed = 0 end
              bal.dueTax = math.floor(tonumber(bal.dueTax) or 0)
              if bal.dueTax < 0 then bal.dueTax = 0 end
              bal.due = bal.dueTax + bal.dueBorrowed
              if type(time) == "function" then
                local now = math.floor(tonumber(time()) or 0)
                if now > 0 then
                  bal.borrowedLastTS = now
                end
              end
                PrintBankMove(cfg, need, "withdrawn from", "Guild Bank")
              RequestUIRefresh()
              C_Timer.After(0.60, DoDeposit)
              return
            end
          end
        end
      end
    end
    DoDeposit()
  end

  local function TryPayWarbank(isAuto)
    local _, cfg, bal = GetActiveScopeCfgAndBal()
    if type(cfg) ~= "table" then return end

    local function TaxWarDbg(msg)
      TaxDbg(cfg, "Warbank pay: " .. tostring(msg or ""))
    end

    local function ToGoldFmt(copper)
      local denom = tonumber(COPPER_PER_GOLD) or 10000
      if denom <= 0 then denom = 10000 end
      local g = math.floor((tonumber(copper) or 0) / denom)
      return tostring(g)
    end

    if not (cfg.warBankEnabled == true) then
      TaxWarDbg("skip (warBankEnabled=false)")
      return
    end

    -- Guard: Warbank open detection can fire from multiple UI paths (interaction manager,
    -- bank ticker sync, and PLAYER_MONEY). Ensure we don't schedule overlapping deposit/withdraw
    -- sequences that each compute availability from the same snapshot.
    local function NowSeconds()
      if type(GetTime) == "function" then
        return tonumber(GetTime()) or 0
      end
      if type(time) == "function" then
        return tonumber(time()) or 0
      end
      return 0
    end

    local function IsAutoLocked()
      if not (isAuto == true) then return false end
      local now = NowSeconds()
      local untilTS = tonumber(state._warbankAutoLockUntil) or 0
      local lockToken = tonumber(state._warbankAutoLockToken) or 0
      local openToken = tonumber(state._warbankOpenToken) or 0
      if now > 0 and untilTS > 0 and now < untilTS and lockToken == openToken then
        return true
      end
      return false
    end

    local function SetAutoLock(seconds)
      if not (isAuto == true) then return end
      seconds = tonumber(seconds) or 0
      if seconds <= 0 then return end
      local now = NowSeconds()
      if now <= 0 then return end
      local openToken = tonumber(state._warbankOpenToken) or 0
      state._warbankAutoLockToken = openToken
      state._warbankAutoLockUntil = now + seconds
    end

    if IsAutoLocked() then
      TaxWarDbg("skip (auto lock active)")
      return
    end

    local ct = EnsureCharTaxDB()
    local wb = ct and ct.warBal
    if type(wb) ~= "table" then
      TaxWarDbg("skip (warBal missing)")
      return
    end
    local openToken = tonumber(state._warbankOpenToken) or 0

    local bankType = (Enum and Enum.BankType) and Enum.BankType or nil
    if not (bankType and bankType.Account) then
      TaxWarDbg("skip (Enum.BankType.Account unavailable)")
      return
    end
    if not (C_Bank and type(C_Bank.DepositMoney) == "function" and type(C_Bank.WithdrawMoney) == "function") then
      TaxWarDbg("skip (C_Bank deposit/withdraw API unavailable)")
      return
    end

    local minGold = tonumber(cfg.minGold) or 0
    if minGold < 0 then minGold = 0 end
    local minCopper = math.floor(minGold * (COPPER_PER_GOLD or 10000))
    if minCopper < 0 then minCopper = 0 end

    local excessMinGold = minGold
    if cfg.excessMinGold ~= nil then
      excessMinGold = tonumber(cfg.excessMinGold) or minGold
    end
    if cfg.excessMinUseToken == true then
      local tokenCopper = GetWowTokenMarketPrice()
      local tokenGold = math.floor((tonumber(tokenCopper) or 0) / (COPPER_PER_GOLD or 10000))
      if tokenGold > 0 then
        excessMinGold = tokenGold
      end
    end
    if excessMinGold < 0 then excessMinGold = 0 end
    local excessMinCopper = math.floor(excessMinGold * (COPPER_PER_GOLD or 10000))
    if excessMinCopper < 0 then excessMinCopper = 0 end

    local function CanDeposit()
      if C_Bank and type(C_Bank.CanDepositMoney) == "function" then
        local ok, can = pcall(C_Bank.CanDepositMoney, bankType.Account)
        if ok and can == false then
          return false
        end
      end
      return true
    end

    local function CanWithdraw()
      if C_Bank and type(C_Bank.CanWithdrawMoney) == "function" then
        local ok, can = pcall(C_Bank.CanWithdrawMoney, bankType.Account)
        if ok and can == false then
          return false
        end
      end
      return true
    end

    local function ScheduleAutoRetryIfNotReady()
      if not (isAuto == true) then return end
      if openToken <= 0 then return end
      local retryToken = tonumber(state._warbankCanDepositRetryToken) or 0
      if retryToken == openToken then
        TaxWarDbg("retry skipped (already retried this open token)")
        return
      end
      state._warbankCanDepositRetryToken = openToken
      TaxWarDbg("retry scheduled in 0.45s (CanDepositMoney=false)")
      if C_Timer and C_Timer.After then
        C_Timer.After(0.45, function()
          if not (state.warbankOpen == true) then return end
          if (tonumber(state._warbankOpenToken) or 0) ~= openToken then return end
          TryPayWarbank(true)
        end)
      else
        TryPayWarbank(true)
      end
    end

    local function DoDeposit()
      local xsEnabled = (cfg.warBankXS == true)

      local dueTax = math.floor(tonumber(wb.dueTax) or 0)
      local dueBorrowed = math.floor(tonumber(wb.dueBorrowed) or 0)
      if dueTax < 0 then dueTax = 0 end
      if dueBorrowed < 0 then dueBorrowed = 0 end

      -- Prevent immediate payback of a just-borrowed amount from the same auto-withdraw cycle.
      local suppressBorrowedRepay = false
      do
        local now = NowSeconds()
        local lastBorrow = tonumber(state._warbankBorrowedAtTS) or 0
        if now > 0 and lastBorrow > 0 and (now - lastBorrow) < 2.0 then
          suppressBorrowedRepay = true
        end
      end

      local duePayBorrowed = suppressBorrowedRepay and 0 or dueBorrowed
      local duePayable = dueTax + duePayBorrowed
      local dueFull = dueTax + dueBorrowed
      if duePayable <= 0 and not xsEnabled then
        TaxWarDbg(string.format(
          "skip (nothing due, XS off): dueTax=%s dueBorrowed=%s duePayable=%s",
          ToGoldFmt(dueTax),
          ToGoldFmt(dueBorrowed),
          ToGoldFmt(duePayable)
        ))
        return
      end

      -- XS: only pay excess above MinGold + owed.
      local guildDue = 0
      if type(bal) == "table" then
        local gTax = math.floor(tonumber(bal.dueTax) or 0)
        local gBorrow = math.floor(tonumber(bal.dueBorrowed) or 0)
        if gTax < 0 then gTax = 0 end
        if gBorrow < 0 then gBorrow = 0 end
        guildDue = gTax + gBorrow
        if guildDue < 0 then guildDue = 0 end
      end
      local totalOwed = guildDue + dueFull

      local money = math.floor(tonumber(GetMoney and GetMoney() or 0) or 0)
      local available = money
      if minCopper > 0 then
        available = money - minCopper
      end
      if available < 0 then available = 0 end

      local toPay
      local xsExtra = 0
      if xsEnabled then
        local availableForXS = money - excessMinCopper
        if availableForXS < 0 then availableForXS = 0 end
        local extra = availableForXS - totalOwed
        if extra < 0 then extra = 0 end
        xsExtra = extra
        if cfg.guildBankXS == true then
          local guildKey = select(1, GetCurrentGuildKeyAndName())
          local g = guildKey and EnsureGuildTaxDB(guildKey) or nil
          local gMoney = (type(g) == "table") and g.guildBankMoneyCached or nil
          local t = EnsureTaxDB()
          local wMoney = (type(t) == "table") and t.warBankMoneyCached or nil
          local _, extraWar = ComputeEBExtraSplit(extra, gMoney, wMoney, false)
          local extraGuild = extra - math.floor(tonumber(extraWar) or 0)
          if extraGuild < 0 then extraGuild = 0 end
          TaxDbg(cfg, string.format(
            "XS split: extra=%d gCached=%s wCached=%s -> gExtra=%d wExtra=%d",
            extra,
            tostring(gMoney),
            tostring(wMoney),
            math.floor(tonumber(extraGuild) or 0),
            math.floor(tonumber(extraWar) or 0)
          ))
          toPay = duePayable + extraWar
        else
          toPay = duePayable + extra
        end
      else
        toPay = duePayable
        if toPay > available then
          toPay = available
        end
      end
      -- Always cap deposits to funds above Min Gold.
      -- XS changes only how "extra" is computed, not how much can be paid below Min.
      local maxPay = available
      if maxPay < 0 then maxPay = 0 end
      if toPay > maxPay then
        toPay = maxPay
      end
      toPay = math.floor(tonumber(toPay) or 0)
      if IsTaxDebugEnabled() and not (cfg.quiet == true) then
        Print(string.format(
          "Tax debug: Warbank pay: calc: dueTax=%s dueBorrowed=%s duePayable=%s dueFull=%s guildDue=%s totalOwed=%s",
          ToGoldFmt(dueTax),
          ToGoldFmt(dueBorrowed),
          ToGoldFmt(duePayable),
          ToGoldFmt(dueFull),
          ToGoldFmt(guildDue),
          ToGoldFmt(totalOwed)
        ))
        Print(string.format(
          "Tax debug: Warbank pay: calc: money=%s min=%s excessMin=%s available=%s xs=%s toPay=%s",
          ToGoldFmt(money),
          ToGoldFmt(minCopper),
          ToGoldFmt(excessMinCopper),
          ToGoldFmt(available),
          tostring(xsEnabled == true),
          ToGoldFmt(toPay)
        ))
      end

      local canDepositNow = CanDeposit()
      if not canDepositNow then
        -- First-frame permission can be false right after opening Warbank.
        -- Retry once for the current open session before giving up.
        TaxWarDbg(string.format(
          "skip (CanDepositMoney=false): dueTax=%s dueBorrowed=%s duePayable=%s openToken=%d",
          ToGoldFmt(dueTax),
          ToGoldFmt(dueBorrowed),
          ToGoldFmt(duePayable),
          openToken
        ))
        ScheduleAutoRetryIfNotReady()
        RequestUIRefresh()
        return
      end
      if toPay <= 0 then
        TaxWarDbg("skip (toPay<=0 after caps)")
        return
      end

      -- Lock long enough for the delayed deposit to fire and settle.
      SetAutoLock(1.10)

      C_Timer.After(0.30, function()
        state._pendingWarbankDeltas = (type(state._pendingWarbankDeltas) == "table") and state._pendingWarbankDeltas or {}
        PushPendingDelta(state._pendingWarbankDeltas, -toPay)
        TaxWarDbg("attempt deposit: toPay=" .. ToGoldFmt(toPay))
        local ok, err = pcall(C_Bank.DepositMoney, bankType.Account, toPay)
        if ok then
          ApplyBankDeltaToCaches("warbank", -toPay)
          local payToDue = toPay
          if payToDue > duePayable then payToDue = duePayable end

          local payTax = payToDue
          if payTax > dueTax then payTax = dueTax end
          local remain = payToDue - payTax
          local payBorrowed = suppressBorrowedRepay and 0 or remain
          if payBorrowed > dueBorrowed then payBorrowed = dueBorrowed end

          wb.dueTax = math.floor(dueTax - payTax)
          wb.dueBorrowed = math.floor(dueBorrowed - payBorrowed)
          if wb.dueTax < 0 then wb.dueTax = 0 end
          if wb.dueBorrowed < 0 then wb.dueBorrowed = 0 end
          wb.due = wb.dueTax + wb.dueBorrowed
          wb.paidToDate = math.floor((tonumber(wb.paidToDate) or 0) + toPay)
          PrintTaxAutoDeposit(cfg, "Warband Bank", toPay, {
            totalMoney = money,
            owedTax = dueTax,
            owedBorrowed = dueBorrowed,
            owed = dueFull,
            xsEnabled = xsEnabled,
            payToOwed = payToDue,
            extra = extra,
            minCopper = minCopper,
            available = available,
            totalOwed = totalOwed,
          })
          RequestUIRefresh()
        else
          TaxWarDbg("deposit call failed: " .. tostring(err))
          RequestUIRefresh()
        end
      end)
    end

    -- Always allow borrowing from Warbank up to Min Gold.
    if minCopper > 0 then
      local money = math.floor(tonumber(GetMoney and GetMoney() or 0) or 0)
      if money < minCopper then
        local need = math.floor(minCopper - money)
        if need > 0 and CanWithdraw() then
          -- Lock long enough for withdraw + follow-up deposit scheduling.
          SetAutoLock(1.60)
          state._pendingWarbankDeltas = (type(state._pendingWarbankDeltas) == "table") and state._pendingWarbankDeltas or {}
          PushPendingDelta(state._pendingWarbankDeltas, need)
          local ok = pcall(C_Bank.WithdrawMoney, bankType.Account, need)
          if ok then
            ApplyBankDeltaToCaches("warbank", need)
            state._warbankBorrowedAtTS = NowSeconds()
            wb.dueBorrowed = math.floor((tonumber(wb.dueBorrowed) or 0) + need)
            if wb.dueBorrowed < 0 then wb.dueBorrowed = 0 end
            wb.dueTax = math.floor(tonumber(wb.dueTax) or 0)
            if wb.dueTax < 0 then wb.dueTax = 0 end
            wb.due = wb.dueTax + wb.dueBorrowed
            PrintBankMove(cfg, need, "withdrawn from", "WarBank")
            TaxWarDbg("borrowed from warbank to min: need=" .. tostring(need))
            RequestUIRefresh()
            C_Timer.After(0.60, DoDeposit)
            return
          end
        elseif need > 0 then
          TaxWarDbg("skip borrow (CanWithdrawMoney=false): need=" .. tostring(need))
        end
      end
    end
    DoDeposit()
  end

  local function ScheduleTryPayWarbankAuto()
    if not (state.warbankOpen == true) then return end
    local token = tonumber(state._warbankOpenToken) or 0
    if token <= 0 then return end
    state._warbankAutoScheduledToken = tonumber(state._warbankAutoScheduledToken) or 0
    if state._warbankAutoScheduledToken == token then
      return
    end
    state._warbankAutoScheduledToken = token
    if C_Timer and C_Timer.After then
      C_Timer.After(0.25, function()
        if not (state.warbankOpen == true) then return end
        if (tonumber(state._warbankOpenToken) or 0) ~= token then return end
        TryPayWarbank(true)
      end)
    else
      TryPayWarbank(true)
    end
  end

  function Tax.Init(db, charDb, env)
    DB = (type(db) == "table") and db or DB
    CHARDB = (type(charDb) == "table") and charDb or CHARDB
    env = (type(env) == "table") and env or {}

    Print = env.Print or Print
    if type(Print) ~= "function" then
      Print = function(...) end
    end

    EnsureTaxDB()
  EnsureCharTaxDB()
  EnsureTaxLDB()
  UpdateTaxLDBText()

    -- Warm the WoW Token cache so the tooltip can show a value without manual intervention.
    ScheduleWowTokenRefreshes()

    -- Reset any stale "open" state that could cause login-time PLAYER_MONEY to be treated as a bank move.
    state.guildBankOpen = false
    state.warbankOpen = false
    state._manualPrevMoney = nil
    state._manualPrevMoneyWar = nil
    state._pendingGuildDeltas = nil
    state._pendingWarbankDeltas = nil
    state._warbankCanDepositRetryToken = nil
  end

  function Tax.OnMerchantShow()
    state.merchant.open = true
    state.merchant.startMoney = math.floor(tonumber(GetMoney and GetMoney() or 0) or 0)
    state.merchant.chatMoney = 0

    local _, cfg = GetActiveScopeCfgAndBal()
    TaxDbg(cfg, "merchant show (start=" .. MoneyToString(state.merchant.startMoney) .. ")")
  end

  function Tax.OnMerchantClosed()
    if not state.merchant.open then return end
    state.merchant.open = false

    local _, cfg = GetActiveScopeCfgAndBal()
    if type(cfg) ~= "table" then return end
    if not (cfg.sources and cfg.sources.vendor) then return end

    local nowMoney = math.floor(tonumber(GetMoney and GetMoney() or 0) or 0)
    local delta = nowMoney - (tonumber(state.merchant.startMoney) or 0)

    local chatDuring = math.floor(tonumber(state.merchant.chatMoney) or 0)
    local taxable = delta - chatDuring

    TaxDbg(cfg, "merchant closed (delta=" .. MoneyToString(delta) .. ", chat=" .. MoneyToString(chatDuring) .. ", taxable=" .. MoneyToString(taxable) .. ")")

    if taxable > 0 then
      AddDue(taxable, "Vendor")
    end
  end

  function Tax.OnMoneyMessage(event, msg)
    local _, cfg = GetActiveScopeCfgAndBal()
    if type(cfg) ~= "table" then return end

    local allow = false
    local denyReason
    if event == "CHAT_MSG_MONEY" then
      allow = (cfg.sources and cfg.sources.questLoot) and true or false
      if not allow then denyReason = "questLoot off" end
    elseif event == "CHAT_MSG_SYSTEM" then
      allow = (cfg.sources and cfg.sources.systemMoney) and true or false
      if not allow then denyReason = "systemMoney off" end
      if allow and type(msg) == "string" then
        -- Retail: msg may be a "secret" string value in tainted paths; any string
        -- operations can throw. Best effort: if we can't safely inspect, keep allow=true.
        local okLower, m = pcall(string.lower, msg)
        if okLower and type(m) == "string" then
          if m:find("spent", 1, true) or m:find("pay", 1, true) or m:find("paid", 1, true) or m:find("lost", 1, true) or m:find("cost", 1, true) or m:find("repair", 1, true) then
            allow = false
            denyReason = "system spend/pay/cost/repair"
          end
        end
      end
    end

    local copper = 0
    local parseMode = "legacy"
    local likelySystem
    if event == "CHAT_MSG_SYSTEM" then
      -- Prefer LootIt's own system-money detection/parsing (used by the chat reprint) when available.
      local lc = LI and LI.LootChat
      if lc and type(lc.IsLikelyMoneyMessage) == "function" and type(lc.ParseCoinsFromMoneyMessage) == "function" then
        parseMode = "lootchat"
        local okLikely, likely = pcall(lc.IsLikelyMoneyMessage, msg)
        likelySystem = (okLikely and likely) and true or false
        if okLikely and likely then
          local okCoins, coins = pcall(lc.ParseCoinsFromMoneyMessage, msg)
          if okCoins and type(coins) == "table" then
            local g = math.floor(tonumber(coins.gold) or 0)
            local s = math.floor(tonumber(coins.silver) or 0)
            local c = math.floor(tonumber(coins.copper) or 0)
            copper = (g * (COPPER_PER_GOLD or 10000)) + (s * (COPPER_PER_SILVER or 100)) + c
          end
        end
      else
        local ok, v = pcall(ParseMoneyFromChat, msg)
        copper = (ok and tonumber(v)) or 0
      end
    else
      local ok, v = pcall(ParseMoneyFromChat, msg)
      copper = (ok and tonumber(v)) or 0
    end
    if copper <= 0 then return end

    do
      local allowStr = allow and "y" or "n"
      local mOpen = (state.merchant.open == true) and "y" or "n"
      local mailOpen = (state.mail.open == true) and "y" or "n"
      local likelyStr = (likelySystem == nil) and "-" or ((likelySystem and "y") or "n")
      local extra = (allow or not denyReason) and "" or (", why=" .. tostring(denyReason))
      TaxDbg(cfg, "money msg (ev=" .. tostring(event) .. ", copper=" .. MoneyToString(copper) .. ", allow=" .. allowStr .. ", parse=" .. tostring(parseMode) .. ", likely=" .. likelyStr .. ", merchant=" .. mOpen .. ", mail=" .. mailOpen .. extra .. ")")
    end

    if state.merchant.open then
      state.merchant.chatMoney = math.floor((tonumber(state.merchant.chatMoney) or 0) + copper)
    end

    if state.mail.open then
      state.mail.chatMoney = math.floor((tonumber(state.mail.chatMoney) or 0) + copper)
    end

    if allow then
      AddDue(copper, "Quest & Loot")
    end
  end

  function Tax.OnInteraction(isShow, interactionType)
    local it = (Enum and Enum.PlayerInteractionType) and Enum.PlayerInteractionType or nil
    if not it then return end

    if interactionType == it.MailInfo then
      if isShow then
        state.mail.open = true
        state.mail.startMoney = math.floor(tonumber(GetMoney and GetMoney() or 0) or 0)
        state.mail.chatMoney = 0

        local _, cfg = GetActiveScopeCfgAndBal()
        TaxDbg(cfg, "mailbox show (start=" .. MoneyToString(state.mail.startMoney) .. ")")
      else
        if not state.mail.open then return end
        state.mail.open = false

        local _, cfg = GetActiveScopeCfgAndBal()
        if type(cfg) ~= "table" then return end
        if not (cfg.sources and cfg.sources.mail) then return end

        local nowMoney = math.floor(tonumber(GetMoney and GetMoney() or 0) or 0)
        local delta = nowMoney - (tonumber(state.mail.startMoney) or 0)

        local chatDuring = math.floor(tonumber(state.mail.chatMoney) or 0)
        local taxable = delta - chatDuring

        TaxDbg(cfg, "mailbox hide (delta=" .. MoneyToString(delta) .. ", chat=" .. MoneyToString(chatDuring) .. ", taxable=" .. MoneyToString(taxable) .. ")")

        if taxable > 0 then
          AddDue(taxable, "Mail")
        end
      end
      return
    end

    if interactionType == it.GuildBanker then
      if IsTaxDebugEnabled() then
        Print("Tax interaction: GuildBanker " .. ((isShow and "show") or "hide"))
      end
      local wasOpen = (state.guildBankOpen == true)
      state.guildBankOpen = (isShow == true)
      if state.guildBankOpen then
        if not wasOpen then
          state._manualPrevMoney = math.floor(tonumber(GetMoney and GetMoney() or 0) or 0)
          state._pendingGuildDeltas = {}
        end

        -- Seed cached money (used for XS balancing).
        CacheGuildBankMoneyFromAPI()
      else
        if wasOpen and state._manualPrevMoney ~= nil then
          local nowMoney = math.floor(tonumber(GetMoney and GetMoney() or 0) or 0)
          local delta = nowMoney - math.floor(tonumber(state._manualPrevMoney) or 0)
          if delta ~= 0 then
            ApplyBankDeltaToCaches("guild", delta)
          end
        end
        -- Best-effort close snapshot while the APIs may still be warm.
        CacheGuildBankMoneyFromAPI()
        state._manualPrevMoney = nil
        state._pendingGuildDeltas = {}
      end
      if isShow and not wasOpen then
        -- Guild bank APIs/permissions can be briefly unavailable on the first frame.
        -- A small delay here makes auto-pay/borrow consistent across client paths.
        if C_Timer and C_Timer.After then
          C_Timer.After(0.25, function() TryPayGuildBank(true) end)
        else
          TryPayGuildBank(true)
        end
      end
      RequestUIRefresh()
      return
    end

    if interactionType == it.AccountBanker then
      if IsTaxDebugEnabled() then
        Print("Tax interaction: AccountBanker " .. ((isShow and "show") or "hide"))
      end
      local wasOpen = (state.warbankOpen == true)
      state.warbankOpen = (isShow == true)
      if state.warbankOpen and not wasOpen then
        state._warbankOpenToken = (tonumber(state._warbankOpenToken) or 0) + 1
      end
      if state.warbankOpen then
        if not wasOpen then
          state._manualPrevMoneyWar = math.floor(tonumber(GetMoney and GetMoney() or 0) or 0)
          state._pendingWarbankDeltas = {}
        end

        -- Seed cached money (used for XS balancing).
        CacheWarbankMoneyFromAPI()
      else
        if wasOpen and state._manualPrevMoneyWar ~= nil then
          local nowMoney = math.floor(tonumber(GetMoney and GetMoney() or 0) or 0)
          local delta = nowMoney - math.floor(tonumber(state._manualPrevMoneyWar) or 0)
          if delta ~= 0 then
            ApplyBankDeltaToCaches("warbank", delta)
          end
        end
        -- Best-effort close snapshot while the APIs may still be warm.
        CacheWarbankMoneyFromAPI()
        state._manualPrevMoneyWar = nil
        state._pendingWarbankDeltas = {}
        state._warbankAutoScheduledToken = 0
        state._warbankAutoLockToken = 0
        state._warbankAutoLockUntil = 0
      end
      if isShow and not wasOpen then
        ScheduleTryPayWarbankAuto()
      end
      RequestUIRefresh()
      return
    end
  end

  -- Some interaction paths only fire the classic guild bank frame events (GUILDBANKFRAME_*),
  -- not PlayerInteractionManager. Expose a dedicated entrypoint so the core event handler can
  -- keep Tax in sync without needing Enum.PlayerInteractionType.
  function Tax.OnGuildBankFrame(isOpen)
    local wasOpen = (state.guildBankOpen == true)
    state.guildBankOpen = (isOpen == true)
    if IsTaxDebugEnabled() then
      Print("Tax guild bank: " .. ((state.guildBankOpen and "open") or "closed"))
    end
    if state.guildBankOpen then
      if not wasOpen then
        state._manualPrevMoney = math.floor(tonumber(GetMoney and GetMoney() or 0) or 0)
        state._pendingGuildDeltas = {}
      end

      CacheGuildBankMoneyFromAPI()
    else
      if wasOpen and state._manualPrevMoney ~= nil then
        local nowMoney = math.floor(tonumber(GetMoney and GetMoney() or 0) or 0)
        local delta = nowMoney - math.floor(tonumber(state._manualPrevMoney) or 0)
        if delta ~= 0 then
          ApplyBankDeltaToCaches("guild", delta)
        end
      end
      CacheGuildBankMoneyFromAPI()
      state._manualPrevMoney = nil
      state._pendingGuildDeltas = {}
    end
    if state.guildBankOpen and not wasOpen then
      if C_Timer and C_Timer.After then
        C_Timer.After(0.25, function() TryPayGuildBank(true) end)
      else
        TryPayGuildBank(true)
      end
    end
    RequestUIRefresh()
  end

  -- Classic guild bank frame events bridging.
  -- The core may also be tracking InteractionManager GuildBanker state; pass that in to avoid double-triggering.
  function Tax.OnGuildBankFrameClassicEvent(event, interactionManagerGuildBankOpen)
    if IsTaxDebugEnabled() then
      Print("Tax guild bank classic: " .. tostring(event) .. " (imOpen=" .. tostring(interactionManagerGuildBankOpen == true) .. ")")
    end
    if event == "GUILDBANKFRAME_OPENED" then
      if not (interactionManagerGuildBankOpen == true) then
        Tax.OnGuildBankFrame(true)
      end
      return
    end
    if event == "GUILDBANKFRAME_CLOSED" then
      Tax.OnGuildBankFrame(false)
      return
    end
  end

  -- Warbank frame state can be embedded in the main BankFrame and may not always
  -- surface as PlayerInteractionManager.AccountBanker. Expose an entrypoint so
  -- the core event handler can keep Tax in sync.
  function Tax.OnWarbankFrame(isOpen)
    local wasOpen = (state.warbankOpen == true)
    state.warbankOpen = (isOpen == true)
    if state.warbankOpen and not wasOpen then
      state._warbankOpenToken = (tonumber(state._warbankOpenToken) or 0) + 1
    end
    if IsTaxDebugEnabled() then
      Print("Tax warbank: " .. ((state.warbankOpen and "open") or "closed"))
    end
    if state.warbankOpen then
      if not wasOpen then
        state._manualPrevMoneyWar = math.floor(tonumber(GetMoney and GetMoney() or 0) or 0)
        state._pendingWarbankDeltas = {}
      end

      CacheWarbankMoneyFromAPI()
    else
      if wasOpen and state._manualPrevMoneyWar ~= nil then
        local nowMoney = math.floor(tonumber(GetMoney and GetMoney() or 0) or 0)
        local delta = nowMoney - math.floor(tonumber(state._manualPrevMoneyWar) or 0)
        if delta ~= 0 then
          ApplyBankDeltaToCaches("warbank", delta)
        end
      end
      CacheWarbankMoneyFromAPI()
      state._manualPrevMoneyWar = nil
      state._pendingWarbankDeltas = {}
      state._warbankAutoScheduledToken = 0
      state._warbankAutoLockToken = 0
      state._warbankAutoLockUntil = 0
      state._warbankCanDepositRetryToken = 0
    end
    if state.warbankOpen and not wasOpen then
      ScheduleTryPayWarbankAuto()
    end
    RequestUIRefresh()
  end

  -- Bank ticker sync for Warbank: called periodically while the unified BankFrame is open.
  -- Uses a small state in the core to detect transitions; pass Get/Set closures so core stays thin.
  function Tax.OnBankTickerTick(env)
    local e = env or {}
    if type(Tax.OnWarbankFrame) ~= "function" then return end
    local isOpenFn = e.IsWarbankOpen
    local getPrev = e.GetTaxWarbankOpen
    local setPrev = e.SetTaxWarbankOpen
    if type(isOpenFn) ~= "function" or type(getPrev) ~= "function" or type(setPrev) ~= "function" then
      return
    end

    local nowOpen = (isOpenFn() == true)
    if nowOpen ~= (getPrev() == true) then
      setPrev(nowOpen)
      if IsTaxDebugEnabled() then
        Print("Tax warbank sync (ticker): " .. ((nowOpen and "open") or "closed"))
      end
      Tax.OnWarbankFrame(nowOpen)
      return
    end

    if nowOpen == true then
      -- Keep cache warm while Warbank is visible; first-frame reads can be nil.
      CacheWarbankMoneyFromAPI()
    end
  end

  -- Ensure Warbank state closes when the unified BankFrame closes.
  function Tax.OnBankFrameClosed(env)
    local e = env or {}
    local getPrev = e.GetTaxWarbankOpen
    local setPrev = e.SetTaxWarbankOpen
    if type(getPrev) ~= "function" or type(setPrev) ~= "function" then
      return
    end
    if getPrev() == true then
      setPrev(false)
      if IsTaxDebugEnabled() then
        Print("Tax warbank safety: closed on BANKFRAME_CLOSED")
      end
      Tax.OnWarbankFrame(false)
    end
  end

  function Tax.PayNow()
    -- Prefer our tracked state, but also allow PayNow if the frame is visibly open.
    if not (state.guildBankOpen == true) then
      local f = _G and rawget(_G, "GuildBankFrame")
      local shown = (f and f.IsShown and f:IsShown()) and true or false
      if not shown then
        return
      end
      state.guildBankOpen = true
    end
    TryPayGuildBank(false)
  end

  function Tax.OnPlayerMoney()
    local money = math.floor(tonumber(GetMoney and GetMoney() or 0) or 0)

    -- Keep the player-gold segment live for all money deltas, not only bank flows.
    UpdateTaxLDBText()

    -- Safety: if our state claims a bank is open but the UI isn't actually shown, clear it.
    if state.guildBankOpen == true then
      local f = _G and rawget(_G, "GuildBankFrame")
      if not (f and f.IsShown and f:IsShown()) then
        state.guildBankOpen = false
        state._manualPrevMoney = nil
        state._pendingGuildDeltas = nil
      end
    end
    if state.warbankOpen == true then
      local f = _G and rawget(_G, "BankFrame")
      if not (f and f.IsShown and f:IsShown()) then
        state.warbankOpen = false
        state._manualPrevMoneyWar = nil
        state._pendingWarbankDeltas = nil
      end
    end

    -- Guild bank manual moves.
    if state.guildBankOpen == true and state._manualPrevMoney ~= nil then
      local delta = money - math.floor(tonumber(state._manualPrevMoney) or 0)
      if delta ~= 0 then
        state._manualPrevMoney = money

        state._pendingGuildDeltas = (type(state._pendingGuildDeltas) == "table") and state._pendingGuildDeltas or {}
        if not PopIfMatches(state._pendingGuildDeltas, delta) then
          local _, cfg, bal = GetActiveScopeCfgAndBal()
          if type(cfg) == "table" and type(bal) == "table" then
            ApplyBankDeltaToCaches("guild", delta)
            ApplyManualDepositOrWithdraw(cfg, bal, delta, "Guild Bank")
          end
        else
          ApplyBankDeltaToCaches("guild", delta)
        end
      end
    end

    -- Warbank manual moves.
    if state.warbankOpen == true and state._manualPrevMoneyWar ~= nil then
      local delta = money - math.floor(tonumber(state._manualPrevMoneyWar) or 0)
      if delta ~= 0 then
        state._manualPrevMoneyWar = money

        state._pendingWarbankDeltas = (type(state._pendingWarbankDeltas) == "table") and state._pendingWarbankDeltas or {}
        if not PopIfMatches(state._pendingWarbankDeltas, delta) then
          local _, cfg = GetActiveScopeCfgAndBal()
          if type(cfg) == "table" and cfg.warBankEnabled == true then
            local ct = EnsureCharTaxDB()
            local wb = ct and ct.warBal
            if type(wb) == "table" then
              ApplyBankDeltaToCaches("warbank", delta)
              ApplyManualDepositOrWithdraw(cfg, wb, delta, "WarBank")
            end
          end
        else
          ApplyBankDeltaToCaches("warbank", delta)
        end
      end
    end

    -- If WarBank is open and we are below Min Gold, re-run the WarBank borrow logic.
    -- This matters when the player manually deposits/spends gold while the WarBank UI
    -- remains open (no "open" event fires again).
    if state.warbankOpen == true then
      local _, cfg = GetActiveScopeCfgAndBal()
      if type(cfg) == "table" and cfg.warBankEnabled == true then
        local minGold = tonumber(cfg.minGold) or 0
        if minGold < 0 then minGold = 0 end
        local minCopper = math.floor(minGold * (COPPER_PER_GOLD or 10000))
        if minCopper > 0 and money < minCopper then
          local now = 0
          if type(GetTime) == "function" then
            now = tonumber(GetTime()) or 0
          elseif type(time) == "function" then
            now = tonumber(time()) or 0
          end
          state._autoWarbankBorrowTS = tonumber(state._autoWarbankBorrowTS) or 0
          if now <= 0 or (now - state._autoWarbankBorrowTS) >= 0.40 then
            state._autoWarbankBorrowTS = (now > 0) and now or state._autoWarbankBorrowTS
            if C_Timer and C_Timer.After then
              C_Timer.After(0, function() TryPayWarbank(true) end)
            else
              TryPayWarbank(true)
            end
          end
        end
      end
    end
  end

  function Tax.ClearDue()
    local _, _, bal = GetActiveScopeCfgAndBal()
    if type(bal) ~= "table" then return end
    bal.dueTax = 0
    bal.dueBorrowed = math.floor(tonumber(bal.dueBorrowed) or 0)
    if bal.dueBorrowed < 0 then bal.dueBorrowed = 0 end
    AccrueBorrowedInterest(bal)
    bal.due = math.floor(tonumber(bal.dueTax) or 0) + math.floor(tonumber(bal.dueBorrowed) or 0)
  end

  function Tax.ClearDueWarbank()
    local ct = EnsureCharTaxDB()
    local wb = ct and ct.warBal
    if type(wb) ~= "table" then return end
    wb.dueTax = 0
    wb.dueBorrowed = math.floor(tonumber(wb.dueBorrowed) or 0)
    if wb.dueBorrowed < 0 then wb.dueBorrowed = 0 end
    wb.due = math.floor(tonumber(wb.dueTax) or 0) + math.floor(tonumber(wb.dueBorrowed) or 0)
  end


  -- UI bridge for fUI_GOTaxUI.lua (exports local closures).
  Tax._ui = Tax._ui or {}
  Tax._ui.EnsureCharTaxDB = EnsureCharTaxDB
  Tax._ui.EnsureGuildTaxDB = EnsureGuildTaxDB
  Tax._ui.GetCurrentGuildKeyAndName = GetCurrentGuildKeyAndName
  Tax._ui.AccrueBorrowedInterest = AccrueBorrowedInterest
  Tax._ui.TryPayWarbank = TryPayWarbank
  Tax._ui.Clamp = Clamp

  -- UI builder extracted into fUI_GOTaxUI.lua
  function Tax.BuildTab(panel, env)
    local fn = Tax and Tax.BuildTab_UI
    if type(fn) == "function" then
      return fn(panel, env)
    end
  end
end

