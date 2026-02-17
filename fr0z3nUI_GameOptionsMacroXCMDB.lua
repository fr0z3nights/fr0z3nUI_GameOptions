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


