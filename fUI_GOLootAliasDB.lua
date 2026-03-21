-- Addon Alias Database (AliasDB)
-- Built-in aliases shipped with the addon.
-- Keyed by itemID; values are display-only text (link remains the original item).

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

LI.AddonLinkAliases = fr0z3nUI_LootIt_AddonAliases
LI.AddonCurrencyAliases = fr0z3nUI_LootIt_AddonCurrencyAliases
