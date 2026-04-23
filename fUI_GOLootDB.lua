-- LootIt data DB (built-in tables)
-- - Addon aliases / currency aliases
-- - Suppress seeds (for the Suppress popout)

local addonName, ns = ...
if type(ns) ~= "table" then ns = {} end

local LI = (ns and ns.LootIt) or {}
ns.LootIt = LI
fr0z3nUI_LootIt = LI
LI.ADDON = LI.ADDON or addonName

fr0z3nUI_LootIt_AddonAliases = fr0z3nUI_LootIt_AddonAliases or {
  [116415] = "TW Token", -- Timewarped Badge
  [ 67151] = "Poseidus", -- Reins of Poseidus
  -- Add itemID aliases here (not currencies).
}

-- Built-in currency aliases shipped with the addon.
-- Keyed by currencyID; values are display-only text (link remains the original currency).
fr0z3nUI_LootIt_AddonCurrencyAliases = fr0z3nUI_LootIt_AddonCurrencyAliases or {
  [1166] = "TW Token", -- Timewarped Badge
}

-- Built-in suppress seeds shipped with the addon.
-- These are *not* saved as rules; they are toggled on/off via the LootIt DB.
-- Each entry is a case-insensitive substring match.
fr0z3nUI_LootIt_AddonSuppressSeeds = fr0z3nUI_LootIt_AddonSuppressSeeds or {

--Blizzard
    { key = "BLZ:Discovery",    text = "You have made a new discovery" },
    { key = "BLZ:Finesse",      text = "Your Finesse helps you gather something extra" },
    { key = "BLZ:HouseXP",      text = "House XP increased" },
    { key = "BLZ:NLAway",       text = "You are no longer Away" },
    { key = "BLZ:NLRested",     text = "You are no longer Rested" },
    { key = "BLZ:Responsibly",  text = "Remember to act responsibly, protect" },
--Darkmoon 
    { key = "DMF:PBJeremy",     text = "Jeremy Feasel says" },
    { key = "DMF:PBChristoph",  text = "Christoph VonFeasel says" },
--Mists of Pandaria
    { key = "X05:PBAki",        text = "Aki the Chosen says" },
    { key = "X05:PBAnthea",     text = "Anthea says" },
    { key = "X05:PBBurning",    text = "Burning Pandaren Spirit says" },
    { key = "X05:TIChiji",      text = "Chi-ji yells" },
    { key = "X05:TIEmpShaohao", text = "Emperor Shaohao yells" },
    { key = "X05:TINiuzao",     text = "Niuzao yells" },
    { key = "X05:TIOrdos",      text = "Ordos yells" },
    { key = "X05:TIXuen",       text = "Xuen yells" },
    { key = "X05:TIYulon",      text = "Yu'lon yells" },
--Midnight
    { key = "X12:Valeera",      text = "Valeera Sanguinar says" },
--Stormwind
    { key = "X01:JaneyAnship",  text = "Janey Anship says" },
    { key = "X01:LisanPierce",  text = "Lisan Pierce says" },
    { key = "X01:Suzanne",      text = "Suzanne says" },
--Addon
    { key = "ANG:Awake",        text = "Is awake. To temporarily disable" },
    { key = "ANG:Config",       text = "To access the configuration menu," },
    { key = "ANG:Thank",        text = "Thank you for using Angleur" },
    { key = "ANG:Visual",       text = "the Visual Button." },
    { key = "DJK:NoJunk",       text = "No junk items to destroy" },
    { key = "ERG:RecGearCmbt",  text = "Cannot recommend gear while in combat" },
    { key = "RMB:NoKeybind",    text = "Hey Bud! You're seeing this because" },
    { key = "SLH:LootBindAprv", text = "Auto Approved Loot Bind" },
    { key = "SLH:LootBindNTrf", text = "Auto Approved Performing this action" },
    { key = "SLH:LUAErrors",    text = "Auto Approved Ignoring Too Many Lua Errors" },
    { key = "VMB:Version",      text = "Vamoose's Endeavors v" },
    { key = "XAN:Loaded",       text = "] loaded" },
    { key = "ZYG:ActvGuide",    text = "Activated guide:" },
    { key = "ZYG:GoldGuide",    text = "Gold Guide:" },
    { key = "ZYG:GuidesLoad",   text = "guides are loaded" },

}

LI.AddonLinkAliases = fr0z3nUI_LootIt_AddonAliases
LI.AddonCurrencyAliases = fr0z3nUI_LootIt_AddonCurrencyAliases
LI.AddonSuppressSeeds = fr0z3nUI_LootIt_AddonSuppressSeeds
