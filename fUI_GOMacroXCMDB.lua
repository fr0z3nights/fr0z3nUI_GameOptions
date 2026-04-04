---@diagnostic disable: undefined-global

local addonName, ns = ...
if type(ns) ~= "table" then
    ns = {}
end

-- Built-in (seed) Macro CMD entries.
-- These are copied into SavedVariables only if missing.
-- Users can then edit them in the Macro CMD UI.

ns.MacroXCMD_DB = ns.MacroXCMD_DB or {}

-- Helper to reduce duplication.
local function Add(mode, key, text)
    ns.MacroXCMD_DB[#ns.MacroXCMD_DB + 1] = {
        mode = tostring(mode or "d"),
        key = tostring(key or ""),
        text = tostring(text or ""),
    }
end

-- x-mode helper: stores two macro bodies + optional mains list.
-- Runtime chooses mainText vs otherText based on whether your character is in mains.
local function AddX(key, mainText, otherText, mains)
    local list = {}
    if type(mains) == "table" then
        for i = 1, #mains do
            local v = mains[i]
            if v ~= nil then
                list[#list + 1] = tostring(v)
            end
        end
    end
    ns.MacroXCMD_DB[#ns.MacroXCMD_DB + 1] = {
        mode = "x",
        key = tostring(key or ""),
        mains = list,
        mainText = tostring(mainText or ""),
        otherText = tostring(otherText or ""),
    }
end

-- CVar / utility macros (d-mode)
Add("d", "loot", [[/run local k="autoLootDefault"; local v=tonumber(C_CVar.GetCVar(k)) or 0; C_CVar.SetCVar(k, v==1 and 0 or 1); print("Auto Loot "..(v==1 and "Disabled" or "Enabled"))]])
Add("d", "script", [[/run local k="ScriptErrors"; local v=tonumber(C_CVar.GetCVar(k)) or 0; C_CVar.SetCVar(k, v==1 and 0 or 1); print("ScriptErrors "..(v==1 and "Disabled" or "Enabled"))]])
Add("d", "mouse", [[/run local k="lootUnderMouse"; local v=tonumber(C_CVar.GetCVar(k)) or 0; C_CVar.SetCVar(k, v==1 and 0 or 1); print("Loot Under Mouse "..(v==1 and "Disabled" or "Enabled"))]])
Add("d", "trade", [[/run local k="blockTrades"; local v=tonumber(C_CVar.GetCVar(k)) or 0; C_CVar.SetCVar(k, v==1 and 0 or 1); print("Block Trades "..(v==1 and "Disabled" or "Enabled"))]])
Add("d", "friend", [[/run local k="UnitNameFriendlyPlayerName"; local v=tonumber(C_CVar.GetCVar(k)) or 0; C_CVar.SetCVar(k, v==1 and 0 or 1); print("Friendly Names "..(v==1 and "Disabled" or "Enabled"))]])
Add("d", "bars", [[/run local k="lockActionBars"; local v=tonumber(C_CVar.GetCVar(k)) or 0; C_CVar.SetCVar(k, v==1 and 0 or 1); print("ActionBar Lock "..(v==1 and "Disabled" or "Enabled"))]])
Add("d", "bagrev", [[/run local k="reverseCleanupBags"; local v=tonumber(C_CVar.GetCVar(k)) or 0; C_CVar.SetCVar(k, v==1 and 0 or 1); print("Bag Sort Reverse "..(v==1 and "Disabled" or "Enabled"))]])
Add("d", "token", [[/run C_WowTokenPublic.UpdateMarketPrice(); C_Timer.After(2,function () print("WoW Token: ") print(GetMoneyString(C_WowTokenPublic.GetCurrentMarketPrice())) end);]])

-- keep cmd closing ]]) on a seperate line in multi-line macros to avoid confusion with the macro text closing ].
Add("d", "setup", [[
/console autoLootDefault 1
/console deselectOnClick 1
/console autoClearAFK 10
/console lootUnderMouse 0
/console autoLootDefault 1
/console cameraSmoothStyle 0
/script SetCVar("nameplateOtherBottomInset", 0.24);SetCVar("nameplateOtherTopInset", 0.11)
]])

Add("d", "fish", [[
/console autoLootDefault 1
/console Sound_EnableMusic 0
/console Sound_MasterVolume 1
]])

Add("d", "logout", [[
/console Sound_MasterVolume 0.5
/console Sound_EnableMusic 1
]])

-- Convenience macros (d-mode)
Add("d", "exit", [[
/console Sound_MasterVolume 0.5
/console Sound_EnableMusic 1
]])

-- DK | DH | DR | EV | HN | MG | MK | PD | PT | RG | SM | WL | WR
-- ============================================================================
-- x-mode example layout (template)
-- Uncomment and customize if you want a built-in x entry seeded.
--
-- AddX("examplex",
-- [[
-- /say MAIN text (mains list)
-- ]],
-- [[
-- /say OTHER text (everyone else)
-- ]],
-- {
--     "Yourmain-Area52",
--     "Altname",
-- })

 AddX("mt1",
 [[
/console Sound_MasterVolume 1
/console Sound_EnableMusic 1
/console autoLootDefault 1
 ]],
 [[
/console Sound_MasterVolume 1
/console Sound_EnableMusic 0
/console autoLootDefault 1
 ]],
 {
"Name",
})


 AddX("mt2",
 [[

/console Sound_MasterVolume 0.5
/console Sound_EnableMusic 1
/console autoLootDefault 1
 ]],
 [[
/console Sound_MasterVolume 0.5
/console Sound_EnableMusic 0
/console autoLootDefault 1
 ]],
 {
"Name",
})


 AddX("mt3",
 [[
/console Sound_MasterVolume 0.2
/console Sound_EnableMusic 1
/console autoLootDefault 1
 ]],
 [[
/console Sound_MasterVolume 0.1
/console Sound_EnableMusic 0
/console autoLootDefault 1
 ]],
 {
"Name",
})



 AddX("mt4",
 [[
/console Sound_MasterVolume 0.5
/console Sound_EnableMusic 1
/console autoLootDefault 1
 ]],
 [[
/console Sound_EnableMusic 0
/console Sound_MasterVolume 0.5
/console autoLootDefault 1
]],
 {
"Name",
})


 AddX("mt5",
 [[
/console Sound_MasterVolume 0.5
/console Sound_EnableMusic 1
/console autoLootDefault 1
 ]],
 [[
/console Sound_MasterVolume 0.5
/console Sound_EnableMusic 0
/console autoLootDefault 1
 ]],
 {
"Name",
})


 AddX("mt6",
 [[
/console Sound_MasterVolume 0.5
/console Sound_EnableMusic 1
/console autoLootDefault 1
 ]],
 [[
/console Sound_MasterVolume 0.5
/console Sound_EnableMusic 0
/console autoLootDefault 1
 ]],
 {
"Name",
})

-- ============================================================================
-- Click aliases (seed list)
-- These are NOT Macro CMD entries.
-- The Click popout uses them as: /click <shorthand> -> (proxy clicks) <original>.
--
-- Notes:
-- - Seeds are only imported if your saved Click alias list is empty.
-- - Keep names to letters/numbers/underscore (global frame name rules).
-- - "original" should be the real button/global frame name.
-- ============================================================================

ns.ClickAlias_DB = ns.ClickAlias_DB or {}

local function AddClickAlias(shorthand, original)
    ns.ClickAlias_DB[#ns.ClickAlias_DB + 1] = {
        shorthand = tostring(shorthand or ""),
        original = tostring(original or ""),
    }
end

-- Examples (uncomment and customize):
AddClickAlias("tdBPS",    "tdBattlePetScriptAutoButton")
AddClickAlias("TSCan",    "TSMCancelAuctionBtn")
AddClickAlias("TSVen",    "TSMVendoringSellAllButton")
AddClickAlias("TSBuy",    "TSMShoppingBuyoutBtn")
AddClickAlias("TSnip",    "TSMSniperBtn")
AddClickAlias("TSCrft",   "TSMCraftingBtn")
AddClickAlias("TSAuc",    "TSMAuctioningBtn")
AddClickAlias("TSDel",    "TSMDestroyBtn")
AddClickAlias("TSBid",    "TSMBidBuyConfirmBtn")
AddClickAlias("TFTB",     "TradeFrameTradeButton")
AddClickAlias("ERG",      "rcButton")

-- ============================================================================
-- Safari Hat (toy) — DB section
-- Data-only seeds for the Safari floating button feature (Switches).
-- Mirrors the ClickAlias_DB style: curated entries live in-repo.
-- ============================================================================

ns.SafariHat_DB = ns.SafariHat_DB or {}

-- Layout matches the curated entries below:
--   AddSafariHat(questID, npcID, textSize, "Name")
local function AddSafariHat(questID, npcID, textSize, name)
    ns.SafariHat_DB[#ns.SafariHat_DB + 1] = {
        questID = tonumber(questID) or 0,
        npcID = tonumber(npcID) or 0,
        textSize = tonumber(textSize) or 12,
        name = tostring(name or ""),
    }
end

-- Examples (uncomment and customize):
-- AddSafariHat(questID, npcID, textSize, "name")
AddSafariHat(32441,  68465, 24, "Thundering Spirit")
AddSafariHat(37208,  87125, 24, "Taralune")
AddSafariHat(32434,  68463, 24, "Burning Spirit")
AddSafariHat(63435, 176655, 24, "Anthea")
AddSafariHat(31958,  66741, 24, "Aki The Chosen")
AddSafariHat(31954,  66733, 24, "Mo'ruk")
AddSafariHat(37201,  83837, 24, "Brightblade")
AddSafariHat(31957,  66739, 24, "Wastewalker")
AddSafariHat(31955,  66734, 24, "Nishi")
AddSafariHat(37207,  87123, 24, "Vesharr")
AddSafariHat(31991,  66918, 24, "Zusshi")
AddSafariHat(31953,  66730, 24, "Hyuna")
AddSafariHat(32439,  68469, 24, "Flowing Spirit")
AddSafariHat(37203,  87127, 24, "Ashlei")
AddSafariHat(37205,  87129, 24, "Gargra")
AddSafariHat(32440,  68470, 24, "Whispering Spirit")
AddSafariHat(37206,  87128, 24, "Tarr Terrible")
AddSafariHat(31956,  66738, 24, "Courageous Yon")
AddSafariHat(45083, 115286, 24, "Crysa")
AddSafariHat(47895, 124617, 24, "Environeer Bert")