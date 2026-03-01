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
