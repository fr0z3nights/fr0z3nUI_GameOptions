---@diagnostic disable: undefined-global

local addonName, ns = ...
if type(ns) ~= "table" then
    ns = {}
end

local function InitSV()
    if ns and type(ns._InitSV) == "function" then
        ns._InitSV()
    end
end

local function Print(msg)
    if ns and type(ns._Print) == "function" then
        ns._Print(msg)
    else
        print("|cff00ccff[FGO]|r " .. tostring(msg))
    end
end

local function GetSettings()
    InitSV()
    local s = rawget(_G, "AutoGame_Settings") or rawget(_G, "AutoGossip_Settings")
    if type(s) ~= "table" then
        return nil
    end
    return s
end

local function EnsureCommandsArray()
    InitSV()
    local s = GetSettings()
    if not s then
        return {}
    end
    if type(s.macroCmdsAcc) ~= "table" then
        s.macroCmdsAcc = {}
    end
    if s.macroCmdsAcc[1] == nil and next(s.macroCmdsAcc) ~= nil then
        s.macroCmdsAcc = {}
    end
    return s.macroCmdsAcc
end

local function Trim(s)
    if type(s) ~= "string" then
        return ""
    end
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function NormalizeRealm(realm)
    realm = Trim(realm):lower()
    realm = realm:gsub("%s+", "")
    realm = realm:gsub("%-+", "")
    realm = realm:gsub("'+", "")
    return realm
end

local function NormalizeName(name)
    name = Trim(name):lower()
    name = name:gsub("%s+", "")
    return name
end

local function GetPlayerNormalized()
    local name, realm = nil, nil
    if UnitFullName then
        name, realm = UnitFullName("player")
    end
    if not name and UnitName then
        name = UnitName("player")
    end
    if not realm and GetRealmName then
        realm = GetRealmName()
    end

    local nName = NormalizeName(name or "")
    local nRealm = NormalizeRealm(realm or "")
    return nName, nRealm
end

local function ParseMainListEntry(line)
    line = Trim(line)
    if line == "" then
        return nil
    end

    local namePart, realmPart = line:match("^([^%-]+)%-(.+)$")
    if not namePart then
        return NormalizeName(line), nil
    end
    return NormalizeName(namePart), NormalizeRealm(realmPart)
end

local function IsPlayerInMainList(cmd)
    if type(cmd) ~= "table" then
        return false
    end
    local mains = cmd.mains
    if type(mains) ~= "table" then
        return false
    end

    local pName, pRealm = GetPlayerNormalized()
    if pName == "" then
        return false
    end

    for _, line in ipairs(mains) do
        local n, r = ParseMainListEntry(tostring(line))
        if n and n ~= "" then
            if r and r ~= "" then
                if n == pName and r == pRealm then
                    return true
                end
            else
                if n == pName then
                    return true
                end
            end
        end
    end
    return false
end

local function FindCmd(key)
    key = Trim(key):lower()
    if key == "" then
        return nil, nil
    end
    local cmds = EnsureCommandsArray()
    for i, c in ipairs(cmds) do
        if type(c) == "table" and type(c.key) == "string" and c.key:lower() == key then
            return c, i
        end
    end
    return nil, nil
end

local function ValidateRunnableText(text)
    text = tostring(text or "")
    if Trim(text) == "" then
        return false, "Macro text is empty."
    end

    -- If player is typing /fgo m, it is a hardware event, so protected commands are generally fine.
    -- But we still warn about directives that only make sense for actual macro icons.
    if text:find("#showtooltip", 1, true) or text:find("#show", 1, true) then
        return true, "Note: #show/#showtooltip only affects real macros (icons/tooltips), not /fgo m execution."
    end

    return true, nil
end

local function RunMacroTextSafe(text)
    if type(RunMacroText) ~= "function" then
        return false, "RunMacroText() is unavailable in this client build."
    end

    local ok, err = pcall(RunMacroText, text)
    if not ok then
        return false, tostring(err)
    end
    return true, nil
end

function ns.MacroCmd_List()
    local cmds = EnsureCommandsArray()
    if #cmds == 0 then
        Print("No /fgo m commands defined. Open the 'Macro /' tab to add one.")
        return
    end

    Print("/fgo m commands:")
    for _, c in ipairs(cmds) do
        if type(c) == "table" and type(c.key) == "string" and c.key ~= "" then
            Print(" - " .. c.key)
        end
    end
end

function ns.MacroCmd_Run(key)
    InitSV()

    local cmd = FindCmd(key)
    if not cmd then
        Print("Unknown command: '" .. tostring(key) .. "'. Try: /fgo m list")
        return
    end

    local isMain = IsPlayerInMainList(cmd)
    local text = isMain and cmd.mainText or cmd.otherText

    local ok, noteOrErr = ValidateRunnableText(text)
    if not ok then
        Print("Cannot run '" .. tostring(cmd.key) .. "': " .. tostring(noteOrErr))
        return
    end

    if noteOrErr then
        Print(noteOrErr)
    end

    local ran, err = RunMacroTextSafe(text)
    if not ran then
        Print("Cannot run '" .. tostring(cmd.key) .. "': " .. tostring(err))
        return
    end
end

function ns.MacroCmd_HandleSlash(rest)
    rest = Trim(rest)
    if rest == "" or rest:lower() == "help" then
        Print("/fgo m list           - list available commands")
        Print("/fgo m <command>      - run MAIN/OTHER macro text based on your character list")
        return
    end

    if rest:lower() == "list" then
        ns.MacroCmd_List()
        return
    end

    ns.MacroCmd_Run(rest)
end
