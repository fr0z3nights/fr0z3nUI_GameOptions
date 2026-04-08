local _, ns = ...

-- NOTE (FGO): Do NOT reference legacy standalone addons (e.g., HearthZone / global fHZ).
-- This addon’s logic should use the current FGO-integrated modules and SavedVariables (AutoGame_*).

-- Macro helpers (non-UI). Split out of Hearth module.

local PREFIX = "|cff00ccff[FGO]|r "
local function Print(msg)
    print(PREFIX .. tostring(msg or ""))
end

local function InCombat()
    return InCombatLockdown and InCombatLockdown() or false
end

local function GetHearthDB()
    if ns and ns.Hearth and type(ns.Hearth.EnsureInit) == "function" then
        return ns.Hearth.EnsureInit()
    end

    -- Fallback (should not normally happen): mimic Hearth module storage.
    _G.AutoGame_UI = _G.AutoGame_UI or {}
    local root = _G.AutoGame_UI
    root.hearth = root.hearth or {}
    root.hearth.window = root.hearth.window or { tab = "hearth", macroPerChar = false }
    return root.hearth, ""
end

local function GetMacroPerCharSetting()
    local db = GetHearthDB()
    local w = (db and db.window) or {}
    return w.macroPerChar and true or false
end

local function SetMacroPerCharSetting(perChar)
    local db = GetHearthDB()
    db.window = db.window or {}
    db.window.macroPerChar = perChar and true or false
end

local MAX_MACRO_CHARS = 255

local BUILTIN_SHOWTOOLTIP_NAME = "#showtooltip (25)"
-- 25 chars including the newline when injected: '#showtooltip item:0000000' (24) + '\n' (1)
-- The 'item:0000000' token is intended to be replaced by the first /use'd item in the macro.
local BUILTIN_SHOWTOOLTIP_TEXT = "#showtooltip item:0000000"
local BUILTIN_SAFARI_NAME = "Safari Hat"
local BUILTIN_SAFARI_TEXT = "/cancelaura Safari Hat"

local function EnsureOptionalEntryAt(opt, name, text, index)
    if type(opt) ~= "table" then
        return
    end

    opt.entries = opt.entries or {}
    local entries = opt.entries

    local foundIndex
    for i = 1, #entries do
        local e = entries[i]
        if type(e) == "table" and e.name == name then
            foundIndex = i
            break
        end
    end

    if foundIndex then
        entries[foundIndex].text = text
        if type(index) == "number" and index >= 1 and index <= #entries and foundIndex ~= index then
            local e = table.remove(entries, foundIndex)
            table.insert(entries, index, e)
        end
        return
    end

    local newEntry = { name = name, text = text }
    if type(index) == "number" and index >= 1 and index <= (#entries + 1) then
        table.insert(entries, index, newEntry)
    else
        entries[#entries + 1] = newEntry
    end
end

local function GetMacroOptionalDB()
    local db = GetHearthDB()
    db.window = db.window or {}
    db.window.optionalMacro = db.window.optionalMacro or {}
    local opt = db.window.optionalMacro

    local DEFAULT_ICON = 134400 -- INV_Misc_QuestionMark

    -- Migration from older schema.
    if opt.entries == nil then
        opt.entries = {}
    end
    if opt.selected == nil then
        opt.selected = {}
    end

    if opt.icon == nil then
        opt.icon = DEFAULT_ICON
    end

    if opt.enabled ~= nil or opt.cancelSafariHat ~= nil or opt.custom ~= nil then
        local hadEnabled = opt.enabled and true or false
        if opt.cancelSafariHat then
            opt.entries[#opt.entries + 1] = { name = BUILTIN_SAFARI_NAME, text = BUILTIN_SAFARI_TEXT }
            if hadEnabled then opt.selected[BUILTIN_SAFARI_NAME] = true end
        end
        if type(opt.custom) == "string" and opt.custom ~= "" then
            opt.entries[#opt.entries + 1] = { name = "Custom", text = opt.custom }
            if hadEnabled then opt.selected["Custom"] = true end
        end
        opt.enabled = nil
        opt.cancelSafariHat = nil
        opt.custom = nil
    end

    -- Ensure built-ins exist and appear first.
    EnsureOptionalEntryAt(opt, BUILTIN_SHOWTOOLTIP_NAME, BUILTIN_SHOWTOOLTIP_TEXT, 1)
    EnsureOptionalEntryAt(opt, BUILTIN_SAFARI_NAME, BUILTIN_SAFARI_TEXT, 2)

    return opt
end

local function NormalizeMacroIcon(icon)
    if type(icon) == "number" and icon > 0 then
        return icon
    end
    if type(icon) == "string" and icon ~= "" then
        return icon
    end

    local opt = GetMacroOptionalDB()
    local fallback = (opt and opt.icon) or 134400
    if type(fallback) == "number" and fallback > 0 then
        return fallback
    end
    if type(fallback) == "string" and fallback ~= "" then
        return fallback
    end
    return 134400
end

local function GetDefaultMacroIcon()
    local opt = GetMacroOptionalDB()
    return NormalizeMacroIcon(opt and opt.icon)
end

local function SetDefaultMacroIcon(icon)
    local opt = GetMacroOptionalDB()
    opt.icon = NormalizeMacroIcon(icon)
    return opt.icon
end

local function SplitLines(s)
    local out = {}
    if type(s) ~= "string" or s == "" then
        return out
    end
    s = s:gsub("\r\n", "\n"):gsub("\r", "\n")
    for line in s:gmatch("[^\n]+") do
        local trimmed = tostring(line):gsub("^%s+", ""):gsub("%s+$", "")
        if trimmed ~= "" then
            out[#out + 1] = trimmed
        end
    end
    return out
end

local function NormalizeName(name)
    name = tostring(name or "")
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    return name
end

local function AddOrUpdateOptionalEntry(name, text)
    local opt = GetMacroOptionalDB()
    name = NormalizeName(name)
    if name == "" then
        return false, "Missing name"
    end
    text = tostring(text or "")

    local entries = opt.entries or {}
    for i = 1, #entries do
        local e = entries[i]
        if type(e) == "table" and e.name == name then
            e.text = text
            return true
        end
    end

    entries[#entries + 1] = { name = name, text = text }
    opt.entries = entries
    return true
end

local function ToggleOptionalEntry(name)
    local opt = GetMacroOptionalDB()
    name = NormalizeName(name)
    if name == "" then
        return
    end
    opt.selected = opt.selected or {}
    opt.selected[name] = not (opt.selected[name] and true or false)
end

local function IsOptionalEntrySelected(name)
    local opt = GetMacroOptionalDB()
    name = NormalizeName(name)
    return (opt.selected and opt.selected[name]) and true or false
end

local function GetOptionalEntries()
    local opt = GetMacroOptionalDB()
    return opt.entries or {}
end

local function GetOptionalEntryText(name)
    local opt = GetMacroOptionalDB()
    name = NormalizeName(name)
    if name == "" then
        return ""
    end

    local entries = opt.entries or {}
    for i = 1, #entries do
        local e = entries[i]
        if type(e) == "table" and e.name == name then
            return tostring(e.text or "")
        end
    end
    return ""
end

local function DeleteOptionalEntry(name)
    local opt = GetMacroOptionalDB()
    name = NormalizeName(name)
    if name == "" then
        return false, "Missing name"
    end
    if name == BUILTIN_SHOWTOOLTIP_NAME or name == BUILTIN_SAFARI_NAME then
        return false, "Cannot delete built-in"
    end

    local entries = opt.entries or {}
    for i = 1, #entries do
        local e = entries[i]
        if type(e) == "table" and e.name == name then
            table.remove(entries, i)
            opt.entries = entries
            if opt.selected then
                opt.selected[name] = nil
            end
            return true
        end
    end
    return false, "Not found"
end

local function ClearOptionalSelections()
    local opt = GetMacroOptionalDB()
    opt.selected = {}
end

local function GetOptionalMacroLines()
    local opt = GetMacroOptionalDB()
    local lines = {}

    local entries = opt.entries or {}
    local selected = opt.selected or {}
    for i = 1, #entries do
        local e = entries[i]
        local name = type(e) == "table" and e.name or nil
        local text = type(e) == "table" and e.text or nil
        if name and selected[name] then
            local entryLines = SplitLines(text)
            for j = 1, #entryLines do
                lines[#lines + 1] = entryLines[j]
            end
        end
    end

    return lines
end

local function FindFirstUseItemID(body)
    if type(body) ~= "string" then
        return nil
    end
    body = body:gsub("\r\n", "\n"):gsub("\r", "\n")
    local id = body:match("/use[^\n]*item:(%d+)")
    return tonumber(id)
end

local function ReplaceShowtooltipItemPlaceholder(body)
    if type(body) ~= "string" or body == "" then
        return body
    end

    -- Only act on a showtooltip line that uses an all-zero item placeholder.
    if not body:match("^#showtooltip%s+item:0+") then
        return body
    end

    local firstUseID = FindFirstUseItemID(body)
    if not firstUseID then
        return body
    end

    local lines = {}
    body = body:gsub("\r\n", "\n"):gsub("\r", "\n")
    for line in body:gmatch("[^\n]*\n?") do
        if line == "" then break end
        local ln = line:gsub("\n$", "")
        if ln:match("^#showtooltip%s+item:0+") then
            ln = ln:gsub("item:0+", "item:" .. tostring(firstUseID), 1)
        end
        lines[#lines + 1] = ln
    end
    return table.concat(lines, "\n")
end

local function FinalizeMacroBody(body)
    -- Keep placeholder during counting; replace only when writing.
    return ReplaceShowtooltipItemPlaceholder(body)
end

local function ApplyOptionalLines(body)
    if type(body) ~= "string" or body == "" then
        return body
    end

    body = body:gsub("\r\n", "\n"):gsub("\r", "\n")

    local lines = GetOptionalMacroLines()
    if #lines == 0 then
        return body
    end

    local tooltipLine
    local otherLines = {}
    for i = 1, #lines do
        local ln = lines[i]
        if not tooltipLine and type(ln) == "string" and ln:match("^#showtooltip") then
            tooltipLine = ln
        else
            otherLines[#otherLines + 1] = ln
        end
    end

    if tooltipLine then
        local first, rest = body:match("^(#[^\n]*showtooltip[^\n]*)(\n.*)$")
        if first then
            body = tooltipLine .. (rest or "")
        else
            body = tooltipLine .. "\n" .. body
        end
    end

    if #otherLines == 0 then
        return body
    end

    local first, rest = body:match("^(#[^\n]*showtooltip[^\n]*)(\n.*)$")
    if first then
        return first .. "\n" .. table.concat(otherLines, "\n") .. (rest or "")
    end

    return table.concat(otherLines, "\n") .. "\n" .. body
end

local function MacroWithinLimit(body)
    if type(body) ~= "string" then
        return false, "Invalid macro"
    end
    if #body > MAX_MACRO_CHARS then
        return false, "Macro too long"
    end
    return true
end

local function EnsureMacro(name, body, perCharacter, icon)
    if InCombat() then
        return false, "Can't create macros in combat"
    end
    if not (GetMacroIndexByName and CreateMacro and EditMacro) then
        return false, "Macro API unavailable"
    end
    if type(body) ~= "string" or body == "" then
        return false, "Empty macro body"
    end

    body = ApplyOptionalLines(body)
    local okLen, whyLen = MacroWithinLimit(body)
    if not okLen then
        return false, whyLen or "Macro too long"
    end

    body = FinalizeMacroBody(body)
    okLen, whyLen = MacroWithinLimit(body)
    if not okLen then
        return false, whyLen or "Macro too long"
    end

    local idx = GetMacroIndexByName(name)
    if idx and idx > 0 then
        EditMacro(idx, name, nil, body)
        ClearOptionalSelections()
        return true
    end

    local iconTexture = NormalizeMacroIcon(icon)
    local created = CreateMacro(name, iconTexture, body, perCharacter and true or false)
    if created then
        ClearOptionalSelections()
        return true
    end

    return false, "CreateMacro failed (macro limit?)"
end

local function CreateOrUpdateNamedMacro(name, body, perCharacter, icon)
    if InCombat() then
        Print("Can't create macros in combat.")
        return
    end
    if type(GetMacroIndexByName) ~= "function" or type(CreateMacro) ~= "function" then
        Print("Macro API unavailable.")
        return
    end
    if type(body) ~= "string" or body == "" then
        Print("Nothing to write for macro '" .. tostring(name) .. "'.")
        return
    end

    body = ApplyOptionalLines(body)
    local okLen, whyLen = MacroWithinLimit(body)
    if not okLen then
        Print("Macro too long (" .. tostring(#body) .. "/" .. tostring(MAX_MACRO_CHARS) .. "). Remove optional lines.")
        return
    end

    body = FinalizeMacroBody(body)
    okLen, whyLen = MacroWithinLimit(body)
    if not okLen then
        Print("Macro too long (" .. tostring(#body) .. "/" .. tostring(MAX_MACRO_CHARS) .. "). Remove optional lines.")
        return
    end

    local idx = GetMacroIndexByName(name)
    if idx and idx > 0 then
        if type(EditMacro) == "function" then
            EditMacro(idx, name, NormalizeMacroIcon(icon), body)
            ClearOptionalSelections()
            Print("Updated macro '" .. tostring(name) .. "'.")
        else
            Print("Macro '" .. tostring(name) .. "' already exists.")
        end
        return
    end

    if perCharacter == nil then
        perCharacter = GetMacroPerCharSetting()
    end

    local ok = CreateMacro(name, NormalizeMacroIcon(icon), body, perCharacter and true or false)
    if ok then
        ClearOptionalSelections()
        Print("Created macro '" .. tostring(name) .. "'.")
    else
        Print("Could not create macro '" .. tostring(name) .. "' (macro slots full?).")
    end
end

local function CreateOrUpdateNamedMacro_NoOptional(name, body, perCharacter, icon)
    if InCombat() then
        return
    end
    if type(GetMacroIndexByName) ~= "function" or type(CreateMacro) ~= "function" then
        Print("Macro API unavailable.")
        return
    end
    if type(body) ~= "string" or body == "" then
        Print("Nothing to write for macro '" .. tostring(name) .. "'.")
        return
    end

    local function NormalizeBodyForCompare(s)
        if type(s) ~= "string" then
            return ""
        end
        s = s:gsub("\r", "")
        s = s:gsub("%s+$", "")
        return s
    end

    local okLen, whyLen = MacroWithinLimit(body)
    if not okLen then
        Print("Macro too long (" .. tostring(#body) .. "/" .. tostring(MAX_MACRO_CHARS) .. ").")
        return
    end

    local idx = GetMacroIndexByName(name)
    if idx and idx > 0 then
        if type(EditMacro) == "function" then
            local existingBody = nil
            if type(GetMacroInfo) == "function" then
                local ok, _, _, b = pcall(GetMacroInfo, idx)
                if ok then
                    existingBody = b
                end
            end

            if NormalizeBodyForCompare(existingBody) == NormalizeBodyForCompare(body) then
                return
            end

            EditMacro(idx, name, NormalizeMacroIcon(icon), body)
        else
            -- No-op (can't edit). Intentionally silent.
        end
        return
    end

    if perCharacter == nil then
        perCharacter = GetMacroPerCharSetting()
    end

    local ok = CreateMacro(name, NormalizeMacroIcon(icon), body, perCharacter and true or false)
    if ok then
        -- Success. Intentionally silent.
    else
        Print("Could not create macro '" .. tostring(name) .. "' (macro slots full?).")
    end
end

local function GetMacroBindText(macroName)
    if not (GetBindingKey and macroName) then return "" end
    local k1, k2 = GetBindingKey("MACRO " .. macroName)
    if k1 and k2 then return k1 .. ", " .. k2 end
    return k1 or k2 or ""
end

local function SetMacroBinding(macroName, key)
    if not (SetBindingMacro and SaveBindings and GetCurrentBindingSet) then
        return false, "Binding API unavailable"
    end

    if key == nil or key == "" then
        return false, "No key"
    end

    if key == "LeftButton" or key == "RightButton" or key == "MiddleButton" then
        return false, "Mouse buttons not supported here"
    end

    SetBindingMacro(key, macroName)
    SaveBindings(GetCurrentBindingSet())
    return true
end

-- Macro bodies
local function MacroBody_HS_Garrison()
    return table.concat({
        "/fgo hs garrison",
        "/use item:110560",
    }, "\n")
end

local function MacroBody_HS_Dalaran()
    return table.concat({
        "/fgo hs dalaran",
        "/use item:140192",
    }, "\n")
end

local function MacroBody_HS_Whistle()
    return table.concat({
        "/fgo hs whistle",
        "/use item:230850",
        "/use item:141605",
        "/use item:205255",
    }, "\n")
end

local function MacroBody_HS_Dornogal()
    return table.concat({
        "/fgo hs dornogal",
        "/use item:243056",
    }, "\n")
end

local function MacroBody_HS_Arcantina()
    return table.concat({
        "/fgo hs arcantina",
        "/use item:253629",
    }, "\n")
end

local function MacroBody_InstanceIO()
    return table.concat({
        "/run LFGTeleport(IsInLFGDungeon())",
        "/run LFGTeleport(IsInLFGDungeon())",
        "/run print(\"Attempting Dungeon Teleport\")",
    }, "\n")
end

local function MacroBody_InstanceReset()
    return "/script ResetInstances();"
end

local function MacroBody_Rez()
    return table.concat({
        "/use Ancestral Spirit",
        "/cast Redemption",
        "/cast Resurrection",
        "/cast Resuscitate",
        "/cast Return",
        "/cast Revive",
        "/cast Raise Ally",
    }, "\n")
end

local function MacroBody_RezCombat()
    return table.concat({
        "/cast Rebirth",
        "/cast Intercession",
        "/cast Raise Ally",
    }, "\n")
end

local function MacroBody_ScriptErrors()
    return "/fgo scripterrors"
end

-- ====================================
-- Food/Drink macros (DrinkBot-style, minimal)
-- ====================================

local FOOD_DRINK_SCAN_COOLDOWN_SEC = 1.0
local FOOD_DRINK_SCAN_MIN_DELAY_SEC = 0.10
local FOOD_DRINK_RETRY_MAX_ATTEMPTS = 8
local FOOD_DRINK_RETRY_INITIAL_DELAY_SEC = 0.50
local FOOD_DRINK_RETRY_MAX_DELAY_SEC = 3.00

local FOOD_MACRO_NAME = "FGO Food"
local DRINK_MACRO_NAME = "FGO Drink"

local CLASS_CONSUMABLE = (Enum and Enum.ItemClass and Enum.ItemClass.Consumable) or 0
local SUB_FOOD_DRINK = (Enum and Enum.ItemConsumableSubclass and Enum.ItemConsumableSubclass.FoodAndDrink) or 5
local foodDrinkSubclassIDs = { [SUB_FOOD_DRINK] = true }
do
    if Enum and Enum.ItemConsumableSubclass then
        local S = Enum.ItemConsumableSubclass
        if S.Food then foodDrinkSubclassIDs[S.Food] = true end
        if S.Drink then foodDrinkSubclassIDs[S.Drink] = true end
    end
end

local function GetHighestPlayerBagIndex()
    local highest = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
    if REAGENTBAG_CONTAINER and REAGENTBAG_CONTAINER > highest then
        highest = REAGENTBAG_CONTAINER
    end
    return highest
end

local function GetFoodDrinkDB()
    local db = GetHearthDB()
    db.window = db.window or {}
    db.window.foodDrink = db.window.foodDrink or {}
    local fd = db.window.foodDrink
    if fd.preferConjured == nil then
        fd.preferConjured = true
    end
    return fd
end

local function GetPreferConjured()
    local fd = GetFoodDrinkDB()
    return fd.preferConjured and true or false
end

local function SetPreferConjured(on)
    local fd = GetFoodDrinkDB()
    fd.preferConjured = on and true or false
end

local FoodDrink = {
    pendingBags = {},
    itemsPending = {},
    itemInfoRequestAt = {},
    tooltipCache = {},
    lastScanAt = 0,
    scanTimerArmed = false,
    scanPending = false,
    needsRewrite = false,
    percentRatesDirty = false,
    createdFood = false,
    createdDrink = false,
    lastFoodID = 0,
    lastDrinkID = 0,

    lastBagScan = { anySlots = false, anyItems = false, at = 0 },
    retryAttempts = 0,
    retryTimerArmed = false,
}

local function RequestLoadItemDataByID_Throttled(itemID)
    if not (C_Item and C_Item.RequestLoadItemDataByID) then
        return
    end

    itemID = tonumber(itemID)
    if not itemID or itemID <= 0 then
        return
    end

    FoodDrink.itemsPending[itemID] = true

    local now = GetTime()
    local last = FoodDrink.itemInfoRequestAt[itemID] or 0
    if (now - last) < 0.20 then
        return
    end
    FoodDrink.itemInfoRequestAt[itemID] = now
    pcall(C_Item.RequestLoadItemDataByID, itemID)
end

local function IsFoodDrinkActive()
    if FoodDrink.createdFood or FoodDrink.createdDrink then
        return true
    end
    if type(GetMacroIndexByName) == "function" then
        if (GetMacroIndexByName(FOOD_MACRO_NAME) or 0) > 0 then
            return true
        end
        if (GetMacroIndexByName(DRINK_MACRO_NAME) or 0) > 0 then
            return true
        end
    end
    return false
end

local function HasPendingItemData()
    return next(FoodDrink.itemsPending) ~= nil
end

local ScheduleFoodDrinkRetry

local function StrNum(s)
    if not s then return 0 end
    s = tostring(s)
    s = s:gsub("%s", "")
    s = s:gsub("[^%d,%.]", "")
    local hasComma = s:find(",", 1, true) ~= nil
    local hasDot = s:find(".", 1, true) ~= nil

    if hasComma and hasDot then
        local lastComma = s:match(".*(),")
        local lastDot = s:match(".*()%." )
        if (lastComma or 0) > (lastDot or 0) then
            s = s:gsub("%.", "")
            s = s:gsub(",", ".")
        else
            s = s:gsub(",", "")
        end
    elseif hasComma then
        local nCommas = select(2, s:gsub(",", ""))
        if nCommas == 1 then
            local pre, post = s:match("^(%d+),(%d+)$")
            if post and #post <= 2 then
                s = pre .. "." .. post
            else
                s = s:gsub(",", "")
            end
        else
            s = s:gsub(",", "")
        end
    elseif hasDot then
        local nDots = select(2, s:gsub("%.", ""))
        if nDots > 1 then
            s = s:gsub("%.", "")
        end
    end

    return tonumber(s) or 0
end

local scanTip
local function EnsureScanTip()
    if scanTip then return scanTip end
    scanTip = CreateFrame("GameTooltip", "FGOFoodDrinkScanTip", UIParent, "GameTooltipTemplate")
    scanTip:SetOwner(UIParent, "ANCHOR_NONE")
    return scanTip
end

local function GetTooltipLinesByItemID(itemID)
    local lines = {}

    local function SurfaceArgsSafe(x)
        if TooltipUtil and TooltipUtil.SurfaceArgs then
            TooltipUtil.SurfaceArgs(x)
        end
    end
    local data = C_TooltipInfo and C_TooltipInfo.GetItemByID and C_TooltipInfo.GetItemByID(itemID)
    if data and data.lines then
        SurfaceArgsSafe(data)
        for i = 1, #data.lines do
            local line = data.lines[i]
            SurfaceArgsSafe(line)
            if line.leftText and line.leftText ~= "" then
                lines[#lines + 1] = line.leftText
            end
            if line.rightText and line.rightText ~= "" then
                lines[#lines + 1] = line.rightText
            end
        end
        return lines
    end

    local tip = EnsureScanTip()
    tip:ClearLines()
    tip:SetItemByID(itemID)
    tip:Show()

    for i = 1, 30 do
        local fs = _G["FGOFoodDrinkScanTipTextLeft" .. i]
        if fs then
            local t = fs:GetText()
            if t and t ~= "" then
                lines[#lines + 1] = t
            end
        end
    end

    tip:Hide()
    return lines
end

local function IsFoodDrinkSubclass(subID, subclassName)
    if subID and foodDrinkSubclassIDs[subID] then
        return true
    end
    if subclassName and _G.ITEM_SUBCLASS_CONSUMABLE_FOOD_AND_DRINK and subclassName == _G.ITEM_SUBCLASS_CONSUMABLE_FOOD_AND_DRINK then
        return true
    end
    return false
end

local function GetItemClassSubclassReq(itemID)
    local name, link, quality, iLevel, reqLevel, className, subclassName,
          maxStack, equipLoc, icon, sellPrice, classID, subclassID = GetItemInfo(itemID)

    if classID and subclassID then
        return classID, subclassID, reqLevel or 0, subclassName
    end

    local _, _, _, _, _, iclass, isub = C_Item.GetItemInfoInstant(itemID)
    if iclass and isub then
        local _, _, _, _, req, _, subName = GetItemInfo(itemID)
        return iclass, isub, req or 0, subName
    end

    return nil, nil, 0, nil
end

local function IsConjuredItem(itemID, tooltipLines)
    if C_Item and C_Item.IsConjuredItem then
        local ok, v = pcall(C_Item.IsConjuredItem, itemID)
        if ok and v ~= nil then
            return v and true or false
        end
    end

    if type(tooltipLines) == "table" then
        for i = 1, #tooltipLines do
            local t = tostring(tooltipLines[i] or "")
            if t ~= "" and t:lower():find("conjured", 1, true) then
                return true
            end
        end
    end

    return false
end

local function GetMaxPercentRate(text, maxValue)
    if not text or text == "" or not maxValue or maxValue <= 0 then
        return 0, nil
    end
    local bestRate = 0
    local bestSec = nil
    for percentText, secText in text:gmatch("(%d+)%s*%%%D+(%d+)") do
        local pct = tonumber(percentText)
        local sec = tonumber(secText)
        if pct and sec and sec > 0 then
            local rate = (maxValue * (pct / 100)) / sec
            if rate > bestRate then
                bestRate = rate
                bestSec = sec
            end
        end
    end
    return bestRate, bestSec
end

local function ParseFoodDrinkRates(itemID)
    local lines = GetTooltipLinesByItemID(itemID)
    if not lines or #lines == 0 then
        return nil
    end

    local hpMax = UnitHealthMax("player") or 0

    -- Percent-based tooltips can say "100% Mana" even on classes/specs that don't use mana.
    -- Using powerType=0 would yield mpMax=0 and cause those items to be ignored.
    -- Prefer the player's active power type max; fall back to any non-zero power max.
    local mpMax = 0
    do
        local pt = nil
        if UnitPowerType then
            local ok, p = pcall(UnitPowerType, "player")
            if ok then
                pt = p
            end
        end
        if UnitPowerMax and pt ~= nil then
            mpMax = UnitPowerMax("player", pt) or 0
        end
        if mpMax <= 0 and UnitPowerMax then
            for p = 0, 10 do
                local v = UnitPowerMax("player", p) or 0
                if v and v > mpMax then
                    mpMax = v
                end
            end
        end
    end
    local kwHealth = tostring(_G.HEALTH or "health"):lower()
    local kwMana = tostring(_G.MANA or "mana"):lower()

    local st = {
        hRate = 0,
        mRate = 0,
        isPercent = false,
        percentDuration = nil,
        lastSec = nil,
        lines = lines,
        parsedLines = #lines,
    }

    local function isSecondsToken(x)
        local n = tonumber(x)
        return n and n > 0 and n <= 120 and n or nil
    end

    local function parseLine(text)
        if not text or text == "" then return end
        local tl = tostring(text):lower()

        -- Percent-based parsing (best-effort, enUS-ish but generally robust)
        if tl:find("%%") then
            local percentHealthRate, secH = GetMaxPercentRate(tl, hpMax)
            local percentManaRate, secM = GetMaxPercentRate(tl, mpMax)

            -- Some modern tooltips are per-second percent restores, e.g.:
            -- "Restores 6% of your maximum health every second over 20 sec."
            -- Treat as a per-second rate (do NOT divide by the duration).
            do
                local pctH, durH = tl:match("(%d+)%s*%%%D+" .. kwHealth .. "%D+every%s+second%D+over%D+(%d+)")
                if pctH and durH then
                    local pct = tonumber(pctH)
                    local dur = tonumber(durH)
                    if pct and pct > 0 and dur and dur > 0 then
                        percentHealthRate = math.max(percentHealthRate, (hpMax * (pct / 100)))
                        secH = dur
                    end
                end

                local pctM, durM = tl:match("(%d+)%s*%%%D+" .. kwMana .. "%D+every%s+second%D+over%D+(%d+)")
                if pctM and durM then
                    local pct = tonumber(pctM)
                    local dur = tonumber(durM)
                    if pct and pct > 0 and dur and dur > 0 then
                        percentManaRate = math.max(percentManaRate, (mpMax * (pct / 100)))
                        secM = dur
                    end
                end
            end

            local sawH = percentHealthRate > 0 and tl:find(kwHealth, 1, true) ~= nil
            local sawM = percentManaRate > 0 and tl:find(kwMana, 1, true) ~= nil
            if sawH then
                st.hRate = math.max(st.hRate, percentHealthRate)
                st.isPercent = true
                st.percentDuration = secH or st.percentDuration
            end
            if sawM then
                st.mRate = math.max(st.mRate, percentManaRate)
                st.isPercent = true
                st.percentDuration = secM or st.percentDuration
            end
        end

        -- Track a seconds token for continuation lines.
        do
            local s = isSecondsToken(tl:match("over%s+(%d+)%s*sec"))
                or isSecondsToken(tl:match("over%s+(%d+)%s*seconds"))
                or isSecondsToken(tl:match("over%s+(%d+)%s"))
                or isSecondsToken(tl:match("(%d+)%s*sec"))
                or isSecondsToken(tl:match("(%d+)%s*seconds"))
            if s then
                st.lastSec = s
            end
        end

        -- Generic parsing using a detected duration.
        -- This intentionally does not depend on a specific "Restores" vs "restore" token.
        if st.lastSec and st.lastSec > 0 and not tl:find("%", 1, true) then
            local sec = st.lastSec

            -- "... X health and Y mana ..."
            local h, m = tl:match("(%d[%d,%.]*)%s+.-" .. kwHealth .. ".-and%s+(%d[%d,%.]*)%s+.-" .. kwMana)
            if not (h and m) then
                -- Sometimes the tooltip reverses the order.
                m, h = tl:match("(%d[%d,%.]*)%s+.-" .. kwMana .. ".-and%s+(%d[%d,%.]*)%s+.-" .. kwHealth)
            end
            if h and m then
                local hv = StrNum(h)
                local mv = StrNum(m)
                if hv > 0 then st.hRate = math.max(st.hRate, hv / sec) end
                if mv > 0 then st.mRate = math.max(st.mRate, mv / sec) end
                return
            end

            -- "... X health and mana ..." (single amount applies to both)
            local both = tl:match("(%d[%d,%.]*)%s+.-" .. kwHealth .. "%s+and%s+" .. kwMana)
            if both then
                local v = StrNum(both)
                if v > 0 then
                    st.hRate = math.max(st.hRate, v / sec)
                    st.mRate = math.max(st.mRate, v / sec)
                end
                return
            end
        end

        -- EnUS restore patterns.
        -- "Restores X health and Y mana over Z sec"
        local a1, a2, s = tl:match("restores?%s+(%d[%d,%.]*)%s+.-" .. kwHealth .. ".-and%s+(%d[%d,%.]*)%s+.-" .. kwMana .. ".-over%s+(%d+)")
        if not (a1 and a2 and s) then
            -- Some tooltips reverse order.
            a1, a2, s = tl:match("restores?%s+(%d[%d,%.]*)%s+.-" .. kwMana .. ".-and%s+(%d[%d,%.]*)%s+.-" .. kwHealth .. ".-over%s+(%d+)")
            if a1 and a2 and s then
                -- swap into health,mana order
                a1, a2 = a2, a1
            end
        end
        if a1 and a2 and s then
            local sec = isSecondsToken(s)
            if sec then
                local h = StrNum(a1)
                local m = StrNum(a2)
                if h > 0 then st.hRate = math.max(st.hRate, h / sec) end
                if m > 0 then st.mRate = math.max(st.mRate, m / sec) end
            end
            return
        end

        -- "Restores X health over Z sec" / "Restores X mana over Z sec"
        local one, s2 = tl:match("restores?%s+(%d[%d,%.]*)%s+.-" .. kwHealth .. ".-over%s+(%d+)")
        if one and s2 then
            local sec = isSecondsToken(s2)
            if sec then
                local h = StrNum(one)
                if h > 0 then st.hRate = math.max(st.hRate, h / sec) end
            end
            return
        end

        one, s2 = tl:match("restores?%s+(%d[%d,%.]*)%s+.-" .. kwMana .. ".-over%s+(%d+)")
        if one and s2 then
            local sec = isSecondsToken(s2)
            if sec then
                local m = StrNum(one)
                if m > 0 then st.mRate = math.max(st.mRate, m / sec) end
            end
            return
        end

        -- Sec-first patterns: "Over Z sec, restores X health and Y mana" (rare but happens in some strings)
        local sFirst, n1, n2 = tl:match("over%s+(%d+)%s*sec.-restores%s+(%d[%d,%.]*)%s+.-" .. kwHealth .. ".-and%s+(%d[%d,%.]*)%s+.-" .. kwMana)
        if sFirst and n1 and n2 then
            local sec = isSecondsToken(sFirst)
            if sec then
                local h = StrNum(n1)
                local m = StrNum(n2)
                if h > 0 then st.hRate = math.max(st.hRate, h / sec) end
                if m > 0 then st.mRate = math.max(st.mRate, m / sec) end
            end
            return
        end

        sFirst, n1 = tl:match("over%s+(%d+)%s*sec.-restores%s+(%d[%d,%.]*)%s+.-" .. kwHealth)
        if sFirst and n1 then
            local sec = isSecondsToken(sFirst)
            if sec then
                local h = StrNum(n1)
                if h > 0 then st.hRate = math.max(st.hRate, h / sec) end
            end
            return
        end

        sFirst, n1 = tl:match("over%s+(%d+)%s*sec.-restores%s+(%d[%d,%.]*)%s+.-" .. kwMana)
        if sFirst and n1 then
            local sec = isSecondsToken(sFirst)
            if sec then
                local m = StrNum(n1)
                if m > 0 then st.mRate = math.max(st.mRate, m / sec) end
            end
            return
        end

        -- Continuation fallback: line has a value and keyword, but no explicit seconds.
        if st.lastSec and st.lastSec > 0 then
            local v = tl:match("(%d[%d,%.]*)")
            if v and tl:find(kwHealth, 1, true) then
                local h = StrNum(v)
                if h > 0 then st.hRate = math.max(st.hRate, h / st.lastSec) end
                return
            end
            if v and tl:find(kwMana, 1, true) then
                local m = StrNum(v)
                if m > 0 then st.mRate = math.max(st.mRate, m / st.lastSec) end
                return
            end
        end
    end

    for i = 1, #lines do
        parseLine(lines[i])
    end
    if #lines > 1 then
        parseLine(table.concat(lines, " "))
    end

    -- If we got nothing useful and the tooltip is effectively empty, treat as pending item data.
    if st.hRate <= 0 and st.mRate <= 0 then
        local joined = table.concat(lines, " "):lower()
        -- At login, consumable tooltips are sometimes missing restore lines (only name/req lines).
        -- If we don't see any restore signal, request item data and retry later.
        local hasRestoreSignal = (joined:find("%", 1, true) ~= nil)
            or (joined:find("restore", 1, true) ~= nil)
            or (joined:find(kwHealth, 1, true) ~= nil)
            or (joined:find(kwMana, 1, true) ~= nil)
        local looksEmpty = (#joined <= 8) or (not hasRestoreSignal)
        if looksEmpty then
            RequestLoadItemDataByID_Throttled(itemID)
        end
    end

    return st
end

local function ClassifyFoodDrink(itemID)
    if not itemID then return nil end

    local classID, subID, req, subName = GetItemClassSubclassReq(itemID)
    if not classID then
        RequestLoadItemDataByID_Throttled(itemID)
        return nil
    end

    if classID ~= CLASS_CONSUMABLE or not IsFoodDrinkSubclass(subID, subName) then
        return nil
    end

    local cached = FoodDrink.tooltipCache[itemID]
    if cached then
        if cached.isPercent and FoodDrink.percentRatesDirty then
            local st = ParseFoodDrinkRates(itemID)
            if st then
                cached.hRate = st.hRate or cached.hRate or 0
                cached.mRate = st.mRate or cached.mRate or 0
                cached.isPercent = st.isPercent and true or cached.isPercent
                cached.percentDuration = st.percentDuration or cached.percentDuration
                FoodDrink.tooltipCache[itemID] = cached
            end
        end
        return cached
    end

    local st = ParseFoodDrinkRates(itemID)
    if not st then return nil end

    local conjured = IsConjuredItem(itemID, st.lines)

    cached = {
        id = itemID,
        req = req or 0,
        hRate = st.hRate or 0,
        mRate = st.mRate or 0,
        isPercent = st.isPercent and true or false,
        percentDuration = st.percentDuration,
        conjured = conjured,
    }
    FoodDrink.tooltipCache[itemID] = cached
    return cached
end

local function PickBestFromBags(kind)
    local bestID = 0
    local bestScore = 0
    local lvl = UnitLevel("player") or 1
    local preferConjured = GetPreferConjured()

    for bag = 0, GetHighestPlayerBagIndex() do
        local n = C_Container and C_Container.GetContainerNumSlots and (C_Container.GetContainerNumSlots(bag) or 0) or 0
        if n and n > 0 then
            FoodDrink.lastBagScan.anySlots = true
        end
        for slot = 1, n do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local id = info and info.itemID
            if id then
                FoodDrink.lastBagScan.anyItems = true
                local qty = (GetItemCount and GetItemCount(id, false)) or 0
                if qty and qty > 0 then
                    local e = ClassifyFoodDrink(id)
                    if e and (e.req or 0) <= lvl then
                        local rate = (kind == "food") and (e.hRate or 0) or (e.mRate or 0)
                        -- Fallback: if tooltip parsing yields 0, still pick the highest-tier usable item.
                        -- Keep this score tiny so real parsed rates always win.
                        local score = tonumber(rate) or 0
                        if score <= 0 then
                            score = (tonumber(e.req) or 0) * 0.0001
                        end
                        if score > 0 then
                            if preferConjured and e.conjured then
                                -- Absolute priority when enabled.
                                score = score + 1e12
                            end
                            if score > bestScore or (score == bestScore and id < bestID) then
                                bestScore = score
                                bestID = id
                            end
                        end
                    end
                end
            end
        end
    end

    return bestID
end

local function BuildUseItemMacroBody(itemID, includeHealthstoneCombat, includeConjureRightClick)
    itemID = tonumber(itemID) or 0
    if itemID <= 0 then
        return "#showtooltip\n"
    end

    local out = "#showtooltip item:" .. tostring(itemID) .. "\n"
    if includeHealthstoneCombat then
        -- Healthstone (item:5512): combat fallback when available.
        out = out .. "/use [combat] item:5512\n"
    end
    out = out .. "/use [btn:1] item:" .. tostring(itemID) .. "\n"

    if includeConjureRightClick then
        -- Right-click conjure fallback (guarded so non-mages don't spam errors).
        out = out .. "/cast [btn:2,known:Conjure Refreshment] Conjure Refreshment\n"
        out = out .. "/cast [btn:2,known:Conjure Water] Conjure Water\n"
        out = out .. "/cast [btn:2,known:Conjure Food] Conjure Food\n"
    end
    return out
end

local function UpdateFoodDrinkMacros(forceRewrite, allowCreateFood, allowCreateDrink)
    if not (GetMacroIndexByName and CreateMacro and EditMacro) then
        return false, "Macro API unavailable"
    end

    if InCombat() then
        FoodDrink.needsRewrite = true
        return false, "in-combat"
    end

    FoodDrink.lastBagScan.anySlots = false
    FoodDrink.lastBagScan.anyItems = false
    FoodDrink.lastBagScan.at = GetTime()

    local bestFood = tonumber(PickBestFromBags("food")) or 0
    local bestDrink = tonumber(PickBestFromBags("drink")) or 0

    -- Reset percent-derived dirty flag after a pass that re-classifies candidates.
    FoodDrink.percentRatesDirty = false

    local foodIdx = (GetMacroIndexByName(FOOD_MACRO_NAME) or 0)
    local drinkIdx = (GetMacroIndexByName(DRINK_MACRO_NAME) or 0)

    local blocked = false

    if allowCreateFood or FoodDrink.createdFood or foodIdx > 0 then
        if forceRewrite or bestFood ~= (tonumber(FoodDrink.lastFoodID) or 0) or foodIdx == 0 then
            if bestFood > 0 then
                FoodDrink.lastFoodID = bestFood
                CreateOrUpdateNamedMacro_NoOptional(FOOD_MACRO_NAME, BuildUseItemMacroBody(bestFood, true, true), GetMacroPerCharSetting(), GetDefaultMacroIcon())
            else
                -- Never overwrite an existing macro with the placeholder body.
                -- Defer until bags/tooltips are ready and we can pick a real item.
                blocked = true
            end
        end
    end

    if allowCreateDrink or FoodDrink.createdDrink or drinkIdx > 0 then
        if forceRewrite or bestDrink ~= (tonumber(FoodDrink.lastDrinkID) or 0) or drinkIdx == 0 then
            if bestDrink > 0 then
                FoodDrink.lastDrinkID = bestDrink
                CreateOrUpdateNamedMacro_NoOptional(DRINK_MACRO_NAME, BuildUseItemMacroBody(bestDrink, false, true), GetMacroPerCharSetting(), GetDefaultMacroIcon())
            else
                blocked = true
            end
        end
    end

    FoodDrink.needsRewrite = blocked
    if blocked then
        if not FoodDrink.lastBagScan.anySlots then
            ScheduleFoodDrinkRetry("bags not ready")
            return false, "bags not ready"
        end
        if HasPendingItemData() then
            ScheduleFoodDrinkRetry("item data pending")
            return false, "item data pending"
        end
        FoodDrink.retryAttempts = 0
        FoodDrink.retryTimerArmed = false
        return false, "no food/drink candidate"
    end

    FoodDrink.retryAttempts = 0
    FoodDrink.retryTimerArmed = false
    return true
end

local function RunFoodDrinkScan(forceRewrite)
    FoodDrink.lastScanAt = GetTime()

    local active = (FoodDrink.createdFood or FoodDrink.createdDrink)
    if not active and type(GetMacroIndexByName) == "function" then
        active = ((GetMacroIndexByName(FOOD_MACRO_NAME) or 0) > 0) or ((GetMacroIndexByName(DRINK_MACRO_NAME) or 0) > 0)
    end

    if active then
        UpdateFoodDrinkMacros(forceRewrite, false, false)
    end
end

local function RequestFoodDrinkScan(forceRewrite)
    FoodDrink.scanPending = true
    local now = GetTime()
    local elapsed = now - (FoodDrink.lastScanAt or 0)

    if not FoodDrink.scanTimerArmed then
        if elapsed >= FOOD_DRINK_SCAN_COOLDOWN_SEC then
            FoodDrink.scanPending = false
            RunFoodDrinkScan(forceRewrite)
            return
        end

        FoodDrink.scanTimerArmed = true
        local delay = math.max(FOOD_DRINK_SCAN_MIN_DELAY_SEC, FOOD_DRINK_SCAN_COOLDOWN_SEC - elapsed)
        C_Timer.After(delay, function()
            FoodDrink.scanTimerArmed = false
            if not FoodDrink.scanPending then return end
            FoodDrink.scanPending = false
            RunFoodDrinkScan(forceRewrite)
        end)
    end
end

ScheduleFoodDrinkRetry = function(_)
    if FoodDrink.retryTimerArmed then return end
    if (FoodDrink.retryAttempts or 0) >= FOOD_DRINK_RETRY_MAX_ATTEMPTS then return end
    if not IsFoodDrinkActive() then return end

    FoodDrink.retryAttempts = (FoodDrink.retryAttempts or 0) + 1
    FoodDrink.retryTimerArmed = true

    local delay = FOOD_DRINK_RETRY_INITIAL_DELAY_SEC * (FoodDrink.retryAttempts or 1)
    if delay > FOOD_DRINK_RETRY_MAX_DELAY_SEC then
        delay = FOOD_DRINK_RETRY_MAX_DELAY_SEC
    end

    C_Timer.After(delay, function()
        FoodDrink.retryTimerArmed = false
        if not IsFoodDrinkActive() then return end
        RequestFoodDrinkScan(true)
    end)
end

do
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("BAG_UPDATE")
    f:RegisterEvent("BAG_UPDATE_DELAYED")
    f:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    f:RegisterEvent("ITEM_DATA_LOAD_RESULT")
    f:RegisterEvent("ITEM_PUSH")
    f:RegisterEvent("MERCHANT_CLOSED")
    f:RegisterEvent("PLAYER_REGEN_ENABLED")
    f:RegisterEvent("PLAYER_LEVEL_UP")
    f:RegisterEvent("UNIT_MAXHEALTH")
    f:RegisterEvent("UNIT_MAXPOWER")

    f:SetScript("OnEvent", function(_, event, arg1, arg2)
        if event == "PLAYER_ENTERING_WORLD" then
            C_Timer.After(1.0, function()
                if IsFoodDrinkActive() then
                    RequestFoodDrinkScan(true)
                end
            end)

            -- One-shot follow-up scan: helps when bag/item tooltip data stabilizes a few seconds
            -- after login/zone load even though BAG_UPDATE events already fired.
            C_Timer.After(4.0, function()
                if IsFoodDrinkActive() then
                    RequestFoodDrinkScan(true)
                end
            end)
            return
        end

        if event == "BAG_UPDATE" then
            if IsFoodDrinkActive() then
                RequestFoodDrinkScan(false)
            end
            return
        end

        if event == "BAG_UPDATE_DELAYED" then
            if IsFoodDrinkActive() then
                RequestFoodDrinkScan(false)
            end
            return
        end

        if event == "ITEM_PUSH" then
            if IsFoodDrinkActive() then
                RequestFoodDrinkScan(false)
            end
            return
        end

        if event == "GET_ITEM_INFO_RECEIVED" then
            local itemID = arg1
            if itemID and FoodDrink.itemsPending[itemID] then
                FoodDrink.itemsPending[itemID] = nil
                FoodDrink.itemInfoRequestAt[itemID] = nil
                -- Force an update after new item info arrives.
                if IsFoodDrinkActive() then
                    RequestFoodDrinkScan(true)
                end
            end
            return
        end

        if event == "ITEM_DATA_LOAD_RESULT" then
            local itemID, ok = arg1, arg2
            if ok and itemID and FoodDrink.itemsPending[itemID] then
                FoodDrink.itemsPending[itemID] = nil
                FoodDrink.itemInfoRequestAt[itemID] = nil
                if IsFoodDrinkActive() then
                    RequestFoodDrinkScan(true)
                end
            end
            return
        end

        if event == "MERCHANT_CLOSED" then
            if IsFoodDrinkActive() then
                RequestFoodDrinkScan(false)
            end
            return
        end

        if event == "PLAYER_REGEN_ENABLED" then
            if FoodDrink.needsRewrite then
                UpdateFoodDrinkMacros(true, false, false)
            end
            return
        end

        if event == "PLAYER_LEVEL_UP" then
            if IsFoodDrinkActive() then
                RequestFoodDrinkScan(true)
            end
            return
        end

        if event == "UNIT_MAXHEALTH" then
            local unit = arg1
            if unit == "player" and IsFoodDrinkActive() then
                -- Percent-based foods depend on max health.
                FoodDrink.percentRatesDirty = true
                RequestFoodDrinkScan(true)
            end
            return
        end

        if event == "UNIT_MAXPOWER" then
            local unit, powerType = arg1, arg2
            if unit == "player" and (powerType == nil or powerType == "MANA" or powerType == 0) and IsFoodDrinkActive() then
                FoodDrink.percentRatesDirty = true
                RequestFoodDrinkScan(true)
            end
            return
        end
    end)
end

ns.Macros = ns.Macros or {}
ns.Macros.Print = Print
ns.Macros.InCombat = InCombat
ns.Macros.GetMacroPerCharSetting = GetMacroPerCharSetting
ns.Macros.SetMacroPerCharSetting = SetMacroPerCharSetting
ns.Macros.GetMacroOptionalDB = GetMacroOptionalDB
ns.Macros.GetDefaultMacroIcon = GetDefaultMacroIcon
ns.Macros.SetDefaultMacroIcon = SetDefaultMacroIcon
ns.Macros.GetOptionalEntries = GetOptionalEntries
ns.Macros.AddOrUpdateOptionalEntry = AddOrUpdateOptionalEntry
ns.Macros.ToggleOptionalEntry = ToggleOptionalEntry
ns.Macros.IsOptionalEntrySelected = IsOptionalEntrySelected
ns.Macros.GetOptionalEntryText = GetOptionalEntryText
ns.Macros.DeleteOptionalEntry = DeleteOptionalEntry
ns.Macros.ClearOptionalSelections = ClearOptionalSelections
ns.Macros.ApplyOptionalLines = ApplyOptionalLines
ns.Macros.MAX_MACRO_CHARS = MAX_MACRO_CHARS
ns.Macros.EnsureMacro = EnsureMacro
ns.Macros.CreateOrUpdateNamedMacro = CreateOrUpdateNamedMacro
ns.Macros.GetMacroBindText = GetMacroBindText
ns.Macros.SetMacroBinding = SetMacroBinding

ns.Macros.MacroBody_HS_Garrison = MacroBody_HS_Garrison
ns.Macros.MacroBody_HS_Dalaran = MacroBody_HS_Dalaran
ns.Macros.MacroBody_HS_Dornogal = MacroBody_HS_Dornogal
ns.Macros.MacroBody_HS_Arcantina = MacroBody_HS_Arcantina
ns.Macros.MacroBody_HS_Whistle = MacroBody_HS_Whistle
ns.Macros.MacroBody_InstanceIO = MacroBody_InstanceIO
ns.Macros.MacroBody_InstanceReset = MacroBody_InstanceReset
ns.Macros.MacroBody_Rez = MacroBody_Rez
ns.Macros.MacroBody_RezCombat = MacroBody_RezCombat
ns.Macros.MacroBody_ScriptErrors = MacroBody_ScriptErrors

-- Food/Drink macros
ns.Macros.FoodDrink_GetPreferConjured = GetPreferConjured
ns.Macros.FoodDrink_SetPreferConjured = function(on)
    SetPreferConjured(on)
    if (FoodDrink.createdFood or FoodDrink.createdDrink) or ((type(GetMacroIndexByName) == "function") and (((GetMacroIndexByName(FOOD_MACRO_NAME) or 0) > 0) or ((GetMacroIndexByName(DRINK_MACRO_NAME) or 0) > 0))) then
        RequestFoodDrinkScan(true)
    end
end
ns.Macros.FoodDrink_CreateFoodMacro = function()
    FoodDrink.createdFood = true
    local ok, why = UpdateFoodDrinkMacros(true, true, false)
end
ns.Macros.FoodDrink_CreateDrinkMacro = function()
    FoodDrink.createdDrink = true
    local ok, why = UpdateFoodDrinkMacros(true, false, true)
end

ns.Macros.FoodDrink_ForceUpdate = function()
    -- Explicit user action: allow create if missing.
    FoodDrink.createdFood = true
    FoodDrink.createdDrink = true
    return UpdateFoodDrinkMacros(true, true, true)
end

ns.Macros.FoodDrink_DebugStatus = function()
    local lvl = UnitLevel("player") or 1
    local hpMax = UnitHealthMax("player") or 0
    local mpMax = 0
    do
        local pt = nil
        if UnitPowerType then
            local ok, p = pcall(UnitPowerType, "player")
            if ok then
                pt = p
            end
        end
        if UnitPowerMax and pt ~= nil then
            mpMax = UnitPowerMax("player", pt) or 0
        end
        if mpMax <= 0 and UnitPowerMax then
            for p = 0, 10 do
                local v = UnitPowerMax("player", p) or 0
                if v and v > mpMax then
                    mpMax = v
                end
            end
        end
    end

    local bestFoodID = tonumber(PickBestFromBags("food")) or 0
    local bestDrinkID = tonumber(PickBestFromBags("drink")) or 0

    local foodEntry = (bestFoodID > 0) and ClassifyFoodDrink(bestFoodID) or nil
    local drinkEntry = (bestDrinkID > 0) and ClassifyFoodDrink(bestDrinkID) or nil

    local foodIdx = (type(GetMacroIndexByName) == "function") and (GetMacroIndexByName(FOOD_MACRO_NAME) or 0) or 0
    local drinkIdx = (type(GetMacroIndexByName) == "function") and (GetMacroIndexByName(DRINK_MACRO_NAME) or 0) or 0

    return {
        inCombat = InCombat(),
        level = lvl,
        hpMax = hpMax,
        mpMax = mpMax,
        preferConjured = GetPreferConjured(),
        active = IsFoodDrinkActive(),
        createdFood = FoodDrink.createdFood and true or false,
        createdDrink = FoodDrink.createdDrink and true or false,
        macroPerChar = GetMacroPerCharSetting() and true or false,
        foodMacroIndex = foodIdx,
        drinkMacroIndex = drinkIdx,
        lastFoodID = tonumber(FoodDrink.lastFoodID) or 0,
        lastDrinkID = tonumber(FoodDrink.lastDrinkID) or 0,
        bestFoodID = bestFoodID,
        bestDrinkID = bestDrinkID,
        bestFood = foodEntry,
        bestDrink = drinkEntry,
        pendingItemData = HasPendingItemData() and true or false,
        lastScanAt = tonumber(FoodDrink.lastScanAt) or 0,
        lastBagScan = {
            anySlots = FoodDrink.lastBagScan.anySlots and true or false,
            anyItems = FoodDrink.lastBagScan.anyItems and true or false,
            at = tonumber(FoodDrink.lastBagScan.at) or 0,
        },
    }
end
