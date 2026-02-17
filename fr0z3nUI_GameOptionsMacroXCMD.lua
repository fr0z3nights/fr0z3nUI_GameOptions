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

local function NormalizeMode(mode)
    mode = tostring(mode or ""):lower()
    if mode == "" then
        return "x"
    end
    if mode == "x" or mode == "m" or mode == "c" or mode == "d" then
        return mode
    end
    -- Unknown/legacy tags fall under d-mode.
    return "d"
end

local function EnsureMode()
    InitSV()
    local s = GetSettings()
    if not s then
        return "x"
    end
    local cur = NormalizeMode(s.macroCmdModeAcc)
    s.macroCmdModeAcc = cur
    return cur
end

local function SetMode(mode)
    InitSV()
    local s = GetSettings()
    if not s then
        return
    end
    s.macroCmdModeAcc = NormalizeMode(mode)
end

local function GetCmdMode(cmd)
    if type(cmd) ~= "table" then
        return "x"
    end
    local m = cmd.mode
    if m == nil or m == "" then
        return "x"
    end
    return NormalizeMode(m)
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

local function FindCmd(mode, key)
    mode = NormalizeMode(mode)
    key = Trim(key):lower()
    if key == "" then
        return nil, nil
    end
    local cmds = EnsureCommandsArray()
    for i, c in ipairs(cmds) do
        local cmode = GetCmdMode(c)
        local okMode = (mode == "x" and cmode == "x") or (cmode == mode)
        if okMode and type(c) == "table" and type(c.key) == "string" and c.key:lower() == key then
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

local function FilterClassTaggedLines(text)
    text = tostring(text or "")
    text = text:gsub("\r\n", "\n"):gsub("\r", "\n")

    local CLASS_TOKEN_TO_SHORT = {
        WARRIOR = "WR",
        PALADIN = "PD",
        HUNTER = "HN",
        ROGUE = "RG",
        PRIEST = "PT",
        DEATHKNIGHT = "DK",
        SHAMAN = "SM",
        MAGE = "MG",
        WARLOCK = "WL",
        MONK = "MK",
        DRUID = "DR",
        DEMONHUNTER = "DH",
        EVOKER = "EV",
    }

    local _, classToken = nil, nil
    if UnitClass then
        _, classToken = UnitClass("player")
    end
    classToken = type(classToken) == "string" and classToken:upper() or ""
    local classShort = CLASS_TOKEN_TO_SHORT[classToken] or classToken

    local function CanonTag(tok)
        tok = Trim(tostring(tok or "")):upper()
        if tok == "" then
            return ""
        end
        if tok == "ALL" then
            return "ALL"
        end
        -- Accept either full class token (DRUID) or short code (DR).
        if CLASS_TOKEN_TO_SHORT[tok] then
            return CLASS_TOKEN_TO_SHORT[tok]
        end
        return tok
    end

    local out = {}
    for line in text:gmatch("([^\n]*)\n?") do
        if line == "" and #out > 0 and out[#out] == "" then
            break
        end

        local trimmed = Trim(line)
        if trimmed == "" then
            out[#out + 1] = line
        else
            local keep = true
            local emit = line

            if trimmed:sub(1, 1) == "[" then
                local tok, rest = trimmed:match("^%[([^%]]+)%]%s*(.-)$")
                if tok then
                    tok = CanonTag(tok)
                    rest = Trim(rest or "")
                    if tok ~= "" and tok ~= "ALL" and tok ~= classShort then
                        keep = false
                    end
                    emit = rest
                end
            elseif trimmed:sub(1, 1) == "@" then
                local tok, rest = trimmed:match("^@([%w_]+)%s+(.-)$")
                if tok then
                    tok = CanonTag(tok)
                    rest = Trim(rest or "")
                    if tok ~= "" and tok ~= "ALL" and tok ~= classShort then
                        keep = false
                    end
                    emit = rest
                end
            end

            if keep and Trim(emit) ~= "" then
                out[#out + 1] = emit
            end
        end
    end
    return table.concat(out, "\n")
end

local function SanitizeClickNameToken(s)
    s = tostring(s or "")
    if s == "" then
        return "_"
    end
    s = s:gsub("[^%w]", "_")
    if s:match("^%d") then
        s = "_" .. s
    end
    return s
end

local function GetMacroClickButtonName_Long(mode, key)
    mode = NormalizeMode(mode)
    key = Trim(key)
    return "FGO_MacroXCMD_Click_" .. SanitizeClickNameToken(mode) .. "_" .. SanitizeClickNameToken(key)
end

local function GetMacroClickButtonName_Short(mode, key)
    mode = NormalizeMode(mode)
    key = Trim(key)
    return "FGOC_" .. SanitizeClickNameToken(mode) .. "_" .. SanitizeClickNameToken(key)
end

-- Default to short names so user macros are readable.
local function GetMacroClickButtonName(mode, key)
    return GetMacroClickButtonName_Short(mode, key)
end

local function GetMacroClickBody(mode, key)
    return "/click " .. GetMacroClickButtonName(mode, key)
end

local function GetMacroClickBody_Long(mode, key)
    return "/click " .. GetMacroClickButtonName_Long(mode, key)
end

local function GetDefaultClickMacroNameForKey(key)
    key = Trim(key)
    if key == "" then
        return "FGO"
    end
    -- Macro names are limited (16 chars). Keep it compact and stable.
    local name = ("FGO_" .. key)
    name = name:gsub("%s+", "")
    if #name > 16 then
        name = name:sub(1, 16)
    end
    return name
end

local function EnsureClickMacro(macroName, clickBody, perCharacter)
    macroName = Trim(macroName)
    clickBody = tostring(clickBody or "")

    if macroName == "" then
        return false, "Missing macro name"
    end
    if #macroName > 16 then
        macroName = macroName:sub(1, 16)
    end
    if clickBody == "" then
        return false, "Empty macro body"
    end

    if InCombatLockdown and InCombatLockdown() then
        return false, "Can't create/update macros in combat"
    end
    if type(GetMacroIndexByName) ~= "function" or type(CreateMacro) ~= "function" then
        return false, "Macro API unavailable"
    end

    local idx = GetMacroIndexByName(macroName)
    if idx and idx > 0 then
        if type(EditMacro) == "function" then
            EditMacro(idx, macroName, "INV_Misc_QuestionMark", clickBody)
            return true, "updated"
        end
        return true, "exists"
    end

    local ok = CreateMacro(macroName, "INV_Misc_QuestionMark", clickBody, perCharacter and true or false)
    if ok then
        return true, "created"
    end
    return false, "CreateMacro failed (macro limit?)"
end

local function EnsureSecureMacroClickButton(mode, key)
    if not CreateFrame then
        return nil
    end

    local shortName = GetMacroClickButtonName_Short(mode, key)
    local longName = GetMacroClickButtonName_Long(mode, key)

    local btnShort = rawget(_G, shortName)
    if not btnShort then
        btnShort = CreateFrame("Button", shortName, UIParent, "SecureActionButtonTemplate")
        btnShort:Hide()
    end

    -- Make the button respond regardless of ActionButtonUseKeyDown (up/down).
    if btnShort then
        if btnShort.EnableMouse then
            btnShort:EnableMouse(true)
        end
        if btnShort.RegisterForClicks then
            btnShort:RegisterForClicks("AnyUp", "AnyDown")
        end
        if btnShort.SetAttribute then
            -- Set both the generic attributes and the button1-specific ones.
            btnShort:SetAttribute("type", "macro")
            btnShort:SetAttribute("macrotext", btnShort:GetAttribute("macrotext") or "")
            btnShort:SetAttribute("type1", "macro")
            btnShort:SetAttribute("macrotext1", btnShort:GetAttribute("macrotext1") or "")
        end
    end

    -- Back-compat alias: keep the old long name working for existing user macros.
    local btnLong = rawget(_G, longName)
    if not btnLong then
        btnLong = CreateFrame("Button", longName, UIParent, "SecureActionButtonTemplate")
        btnLong:Hide()
    end

    if btnLong then
        if btnLong.EnableMouse then
            btnLong:EnableMouse(true)
        end
        if btnLong.RegisterForClicks then
            btnLong:RegisterForClicks("AnyUp", "AnyDown")
        end
        if btnLong.SetAttribute then
            btnLong:SetAttribute("type", "macro")
            btnLong:SetAttribute("macrotext", btnLong:GetAttribute("macrotext") or "")
            btnLong:SetAttribute("type1", "macro")
            btnLong:SetAttribute("macrotext1", btnLong:GetAttribute("macrotext1") or "")
        end
    end

    return btnShort
end

local function SupportsMacroOptionToken(token)
    token = Trim(token):lower()
    if token == "" then
        return false
    end
    if type(SecureCmdOptionParse) ~= "function" then
        return false
    end

    -- If the token is unknown, some clients error; treat that as unsupported.
    local ok = pcall(SecureCmdOptionParse, "[" .. token .. "] ok; nope")
    return ok and true or false
end

local _flightOptionTokens = nil
local function GetExtraFlightStopmacroTokens()
    if _flightOptionTokens ~= nil then
        return _flightOptionTokens
    end

    local extra = {}
    -- Modern retail builds introduced advanced flight (Skyriding/dynamic flight) conditionals.
    -- Keep this conservative: only include tokens that this client can parse.
    if SupportsMacroOptionToken("advfly") then
        extra[#extra + 1] = "advfly"
    end

    _flightOptionTokens = extra
    return _flightOptionTokens
end

local function PreprocessMacroTextForClick(text)
    text = tostring(text or "")
    if Trim(text) == "" then
        return text
    end

    local extra = GetExtraFlightStopmacroTokens()
    if not extra or #extra == 0 then
        return text
    end

    -- Extend the common guard line without altering the user's stored macro.
    -- IMPORTANT: do NOT stack bracket blocks (e.g. [flying][advfly]) because that can behave
    -- like AND / a single option-set in some parsers. Instead, insert extra stop lines (OR).
    local insert = "/stopmacro [flying]"
    for i = 1, #extra do
        insert = insert .. "\n/stopmacro [" .. extra[i] .. "]"
    end

    text = text:gsub("/stopmacro%s*%[flying%]", insert)
    return text
end

local function GetRunnableTextForCmd(mode, cmd)
    mode = NormalizeMode(mode)
    if type(cmd) ~= "table" then
        return ""
    end

    local text = ""
    if mode == "x" then
        local isMain = IsPlayerInMainList(cmd)
        text = isMain and cmd.mainText or cmd.otherText
    elseif mode == "c" then
        text = FilterClassTaggedLines(tostring(cmd.otherText or ""))
        if Trim(text) == "" then
            local _, classToken = nil, nil
            if UnitClass then
                _, classToken = UnitClass("player")
            end
            classToken = type(classToken) == "string" and classToken:upper() or nil

            local perClass = nil
            if type(cmd.classText) == "table" and classToken and classToken ~= "" then
                perClass = cmd.classText[classToken]
            end
            text = tostring(perClass or "")
            if Trim(text) == "" then
                text = tostring(cmd.otherText or "")
            end
            if Trim(text) == "" then
                text = tostring(cmd.mainText or "")
            end
        end
    else
        text = tostring(cmd.otherText or "")
        if Trim(text) == "" then
            text = tostring(cmd.mainText or "")
        end
    end

    return tostring(text or "")
end

local function ArmSecureMacroClickButton(mode, key, text)
    mode = NormalizeMode(mode)
    key = Trim(key)
    if key == "" then
        return false, "Missing key"
    end
    if not CreateFrame then
        return false, "Frame API unavailable"
    end
    if InCombatLockdown and InCombatLockdown() then
        return false, "In combat"
    end

    local btn = EnsureSecureMacroClickButton(mode, key)
    if not (btn and btn.SetAttribute) then
        return false, "Secure button unavailable"
    end

    local macroText = PreprocessMacroTextForClick(text)
    btn:SetAttribute("type", "macro")
    btn:SetAttribute("macrotext", macroText)
    btn:SetAttribute("type1", "macro")
    btn:SetAttribute("macrotext1", macroText)

    -- Also arm the long-name alias if it exists.
    local alias = rawget(_G, GetMacroClickButtonName_Long(mode, key))
    if alias and alias.SetAttribute then
        alias:SetAttribute("type", "macro")
        alias:SetAttribute("macrotext", macroText)
        alias:SetAttribute("type1", "macro")
        alias:SetAttribute("macrotext1", macroText)
    end
    return true
end

local function RunMacroTextSafe(mode, key, text)
    -- Preferred path: global RunMacroText if the client still exposes it.
    if type(RunMacroText) == "function" then
        local ok, err
        if type(securecallfunction) == "function" then
            ok, err = pcall(securecallfunction, RunMacroText, text)
        else
            ok, err = pcall(RunMacroText, text)
        end
        if not ok then
            return false, tostring(err), nil
        end
        return true, nil, nil
    end

    -- Some modern clients hide the global but still expose C_Macro.RunMacroText.
    -- Try it before falling back to the secure /click arming flow.
    local cMacroErr = nil
    if type(C_Macro) == "table" and type(C_Macro.RunMacroText) == "function" then
        local ok, err
        if type(securecallfunction) == "function" then
            ok, err = pcall(securecallfunction, C_Macro.RunMacroText, text)
        else
            ok, err = pcall(C_Macro.RunMacroText, text)
        end
        if ok then
            return true, nil, nil
        end
        -- If Blizzard blocks this path (protected/taint), keep going to the /click flow.
        -- But return the underlying error if we can't even set up the secure click button.
        cMacroErr = tostring(err)
        -- continue
    end

    -- Newer builds often block macro APIs from addons; use the Home-style secure /click flow.
    local btn = EnsureSecureMacroClickButton(mode, key)
    local clickBody = GetMacroClickBody(mode, key)
    if not (btn and btn.SetAttribute) then
        return false, "Macro execution is unavailable in this client build.", clickBody
    end

    if InCombatLockdown and InCombatLockdown() then
        -- Can't (re)configure secure attributes in combat; user must arm it first.
        return false, "Can't arm this macro while in combat. Try again out of combat, then use: " .. clickBody, clickBody
    end

    local macroText = PreprocessMacroTextForClick(text)
    btn:SetAttribute("type", "macro")
    btn:SetAttribute("macrotext", macroText)
    btn:SetAttribute("type1", "macro")
    btn:SetAttribute("macrotext1", macroText)
    do
        local alias = rawget(_G, GetMacroClickButtonName_Long(mode, key))
        if alias and alias.SetAttribute then
            alias:SetAttribute("type", "macro")
            alias:SetAttribute("macrotext", macroText)
            alias:SetAttribute("type1", "macro")
            alias:SetAttribute("macrotext1", macroText)
        end
    end

    -- Do NOT click from Lua; it must be a hardware event.
    local why = "This client build blocks running macro text from addons. Use: " .. clickBody
    if cMacroErr and cMacroErr ~= "" then
        why = why .. "  (C_Macro.RunMacroText blocked: " .. cMacroErr .. ")"
    end
    return false, why, clickBody
end

local function MacroXCMD_ListImpl(mode)
    mode = NormalizeMode(mode)
    local cmds = EnsureCommandsArray()
    local any = false
    for _, c in ipairs(cmds) do
        local cmode = GetCmdMode(c)
        local okMode = (mode == "x" and cmode == "x") or (cmode == mode)
        if okMode and type(c) == "table" and type(c.key) == "string" and c.key ~= "" then
            any = true
            break
        end
    end

    if not any then
        Print("No /fgo " .. mode .. " commands defined. Open the 'Macro /' tab to add one.")
        return
    end

    Print("/fgo " .. mode .. " commands:")
    for _, c in ipairs(cmds) do
        local cmode = GetCmdMode(c)
        local okMode = (mode == "x" and cmode == "x") or (cmode == mode)
        if okMode and type(c) == "table" and type(c.key) == "string" and c.key ~= "" then
            Print(" - " .. c.key)
        end
    end
end

local function MacroXCMD_RunImpl(mode, key)
    mode = NormalizeMode(mode)
    InitSV()

    local cmd = FindCmd(mode, key)
    if not cmd then
        Print("Unknown command: '" .. tostring(key) .. "'. Try: /fgo " .. mode .. " list")
        return
    end

    local text = GetRunnableTextForCmd(mode, cmd)

    local ok, noteOrErr = ValidateRunnableText(text)
    if not ok then
        Print("Cannot run '" .. tostring(cmd.key) .. "': " .. tostring(noteOrErr))
        return
    end

    if noteOrErr then
        Print(noteOrErr)
    end

    -- If the client blocks macro execution APIs, we can still support a small subset
    -- of common utility directives directly (e.g. /run and /console), which is
    -- enough for things like token price and CVar toggles.
    local function TryRunDirect(textToRun)
        local norm = tostring(textToRun or ""):gsub("\r\n", "\n"):gsub("\r", "\n")
        local any = false

        local function SetCVarSafe(k, v)
            k = tostring(k or "")
            v = tostring(v or "")
            if k == "" then
                return false
            end
            if type(SetCVar) == "function" then
                pcall(SetCVar, k, v)
                return true
            end
            if type(C_CVar) == "table" and type(C_CVar.SetCVar) == "function" then
                pcall(C_CVar.SetCVar, k, v)
                return true
            end
            return false
        end

        for line in norm:gmatch("([^\n]*)\n?") do
            local t = Trim(line)
            if t ~= "" then
                local lower = t:lower()
                if lower:sub(1, 5) == "/run " then
                    any = true
                    local code = Trim(t:sub(6))
                    if code == "" then
                        return false, "Empty /run"
                    end
                    if type(RunScript) == "function" then
                        local ok, err = pcall(RunScript, code)
                        if not ok then
                            return false, tostring(err)
                        end
                    elseif type(loadstring) == "function" then
                        local f, err = loadstring(code)
                        if not f then
                            return false, tostring(err)
                        end
                        local ok, e2 = pcall(f)
                        if not ok then
                            return false, tostring(e2)
                        end
                    else
                        return false, "RunScript unavailable"
                    end
                elseif lower:sub(1, 8) == "/script " then
                    any = true
                    local code = Trim(t:sub(9))
                    if code == "" then
                        return false, "Empty /script"
                    end
                    if type(RunScript) == "function" then
                        local ok, err = pcall(RunScript, code)
                        if not ok then
                            return false, tostring(err)
                        end
                    elseif type(loadstring) == "function" then
                        local f, err = loadstring(code)
                        if not f then
                            return false, tostring(err)
                        end
                        local ok, e2 = pcall(f)
                        if not ok then
                            return false, tostring(e2)
                        end
                    else
                        return false, "RunScript unavailable"
                    end
                elseif lower:sub(1, 9) == "/console " then
                    any = true
                    local rest = Trim(t:sub(10))
                    local k, v = rest:match("^(%S+)%s*(.-)$")
                    k = tostring(k or "")
                    v = Trim(v or "")
                    if k == "" then
                        return false, "Bad /console"
                    end
                    if v == "" then
                        return false, "Missing value for /console " .. k
                    end
                    if not SetCVarSafe(k, v) then
                        return false, "CVar API unavailable"
                    end
                else
                    -- Unsupported directive: abort direct mode.
                    return false, "unsupported"
                end
            end
        end

        if any then
            return true, nil
        end
        return false, "unsupported"
    end

    do
        local okDirect, whyDirect = TryRunDirect(text)
        if okDirect then
            return
        end
        -- If it's unsupported, fall through to macro execution.
        -- If it failed for another reason, show it.
        if whyDirect and whyDirect ~= "unsupported" then
            Print("Cannot run '" .. tostring(cmd.key) .. "' directly: " .. tostring(whyDirect))
            return
        end
    end

    local ran, err, clickBody = RunMacroTextSafe(mode, cmd.key, text)
    if not ran then
        -- Match Home: provide a secure /click macro body when the client blocks addon macro execution.
        if clickBody and clickBody ~= "" then
            Print(tostring(err))
        else
            Print("Cannot run '" .. tostring(cmd.key) .. "': " .. tostring(err))
        end
        return
    end
end

local function MacroXCMD_ArmAllImpl()
    InitSV()
    local cmds = EnsureCommandsArray()
    if not cmds or #cmds == 0 then
        return 0, nil
    end

    if InCombatLockdown and InCombatLockdown() then
        return 0, "In combat"
    end

    local armed = 0
    for _, cmd in ipairs(cmds) do
        local mode = GetCmdMode(cmd)
        local key = type(cmd) == "table" and cmd.key or nil
        if type(key) == "string" and Trim(key) ~= "" then
            local text = GetRunnableTextForCmd(mode, cmd)
            if Trim(text) ~= "" then
                local ok = ArmSecureMacroClickButton(mode, key, text)
                if ok then
                    armed = armed + 1
                end
            end
        end
    end

    return armed, nil
end

local function MacroXCMD_RunAutoImpl(key)
    key = Trim(key)
    if key == "" then
        return false
    end

    -- Preserve legacy behavior: prefer d-mode for bare /fgo <key>.
    -- Then try the current selected mode, then the remaining modes.
    local cur = EnsureMode()
    local tried = {}
    local order = { "d", cur, "x", "m", "c" }
    for i = 1, #order do
        local m = NormalizeMode(order[i])
        if not tried[m] then
            tried[m] = true
            local cmd = FindCmd(m, key)
            if cmd then
                MacroXCMD_RunImpl(m, key)
                return true
            end
        end
    end

    return false
end

local function MacroXCMD_FindAutoImpl(key)
    key = Trim(key)
    if key == "" then
        return nil, nil
    end

    local cur = EnsureMode()
    local tried = {}
    local order = { "d", cur, "x", "m", "c" }
    for i = 1, #order do
        local m = NormalizeMode(order[i])
        if not tried[m] then
            tried[m] = true
            local cmd = FindCmd(m, key)
            if cmd then
                return cmd, m
            end
        end
    end

    return nil, nil
end

local function MacroXCMD_HandleSlashImpl(mode, rest)
    mode = NormalizeMode(mode)
    rest = Trim(rest)
    if rest == "" or rest:lower() == "help" then
        Print("/fgo " .. mode .. " list           - list available commands")
        if mode == "x" then
            Print("/fgo " .. mode .. " <command>      - run MAIN/OTHER macro text based on your character list")
        else
            Print("/fgo " .. mode .. " <command>      - run the macro text")
        end
        return
    end

    if rest:lower() == "list" then
        MacroXCMD_ListImpl(mode)
        return
    end

    MacroXCMD_RunImpl(mode, rest)
end

-- Public API: prefer MacroXCMD_* (aligned with file/module naming).
function ns.MacroXCMD_List()
    MacroXCMD_ListImpl("x")
end

function ns.MacroXCMD_Run(key)
    MacroXCMD_RunImpl("x", key)
end

function ns.MacroXCMD_HandleSlash(rest)
    MacroXCMD_HandleSlashImpl("x", rest)
end

function ns.MacroXCMD_ListMode(mode)
    MacroXCMD_ListImpl(mode)
end

function ns.MacroXCMD_RunMode(mode, key)
    MacroXCMD_RunImpl(mode, key)
end

function ns.MacroXCMD_HandleSlashMode(mode, rest)
    MacroXCMD_HandleSlashImpl(mode, rest)
end

function ns.MacroXCMD_RunAuto(key)
    return MacroXCMD_RunAutoImpl(key)
end

function ns.MacroXCMD_GetMode()
    return EnsureMode()
end

function ns.MacroXCMD_SetMode(mode)
    SetMode(mode)

    local panel = ns and ns._MacroXCMDUI_Panel or nil
    if panel and type(panel._MacroXCMDUI_UpdateMode) == "function" then
        panel._MacroXCMDUI_UpdateMode(mode)
    end
end

function ns.MacroXCMD_Debug(mode, key)
    InitSV()

    local function BoolStr(v)
        return v and "yes" or "no"
    end

    Print("Macro CMD debug:")
    Print(" - client has RunMacroText: " .. BoolStr(type(RunMacroText) == "function"))
    Print(" - client has C_Macro.RunMacroText: " .. BoolStr(type(C_Macro) == "table" and type(C_Macro.RunMacroText) == "function"))
    Print(" - can CreateFrame: " .. BoolStr(type(CreateFrame) == "function"))
    Print(" - in combat: " .. BoolStr(type(InCombatLockdown) == "function" and InCombatLockdown()))

    do
        local _, classToken = nil, nil
        if UnitClass then
            _, classToken = UnitClass("player")
        end
        classToken = type(classToken) == "string" and classToken or ""
        Print(" - player class: " .. tostring(classToken))
    end

    if mode == nil and key == nil then
        return
    end

    mode = NormalizeMode(mode)
    key = Trim(key)
    if key == "" then
        Print("Usage: /fgo debug <mode> <key>   (example: /fgo debug c XAB)")
        return
    end

    local cmd = FindCmd(mode, key)
    if not cmd then
        Print(" - find cmd: not found in mode '" .. tostring(mode) .. "'")
        return
    end

    local text = ""
    local xPicked = nil
    if mode == "x" then
        local isMain = IsPlayerInMainList(cmd)
        xPicked = isMain and "mainText" or "otherText"
        text = isMain and cmd.mainText or cmd.otherText
    elseif mode == "c" then
        text = FilterClassTaggedLines(tostring(cmd.otherText or ""))
    else
        text = tostring(cmd.otherText or "")
        if Trim(text) == "" then
            text = tostring(cmd.mainText or "")
        end
    end

    local lineCount = 0
    for _ in tostring(text):gmatch("[^\n]*\n?") do
        lineCount = lineCount + 1
    end

    Print(" - find cmd: ok")
    if xPicked then
        Print(" - x picked: " .. tostring(xPicked))
    end
    Print(" - text empty: " .. BoolStr(Trim(text) == ""))
    Print(" - lines: " .. tostring(lineCount))
    Print(" - contains /click: " .. BoolStr(tostring(text):find("/click", 1, true) ~= nil))

    -- Also show what the module *computed* to run (SavedVariables text after filtering).
    do
        local normT = tostring(text):gsub("\r\n", "\n"):gsub("\r", "\n")
        local cancelsT = {}
        local clicksT = {}
        for line in normT:gmatch("([^\n]*)\n?") do
            local t = Trim(line)
            if t:sub(1, 11):lower() == "/cancelaura" then
                cancelsT[#cancelsT + 1] = t
            elseif t:sub(1, 6):lower() == "/click" then
                clicksT[#clicksT + 1] = t
            end
        end
        Print(" - computed cancelaura lines: " .. tostring(#cancelsT))
        for i = 1, math.min(#cancelsT, 6) do
            Print("   * " .. cancelsT[i])
        end
        if #cancelsT > 6 then
            Print("   * (" .. tostring(#cancelsT - 6) .. " more)")
        end
        Print(" - computed click lines: " .. tostring(#clicksT))
        for i = 1, math.min(#clicksT, 6) do
            Print("   * " .. clicksT[i])
        end
        if #clicksT > 6 then
            Print("   * (" .. tostring(#clicksT - 6) .. " more)")
        end
    end
    Print(" - secure click macro: " .. tostring(GetMacroClickBody(mode, key)))
    Print(" - secure click macro (legacy): " .. tostring(GetMacroClickBody_Long(mode, key)))

    -- Prove whether /click is wired: check the secure buttons and their armed macrotext.
    local shortName = GetMacroClickButtonName_Short(mode, key)
    local longName = GetMacroClickButtonName_Long(mode, key)

    local function InspectBtn(name)
        local b = rawget(_G, name)
        if not b then
            return "missing"
        end
        if not b.GetAttribute then
            return "no GetAttribute"
        end
        local mt = b:GetAttribute("macrotext")
        if type(mt) ~= "string" or mt == "" then
            mt = b:GetAttribute("macrotext1")
        end
        mt = type(mt) == "string" and mt or ""
        local mt1 = b:GetAttribute("macrotext1")
        mt1 = type(mt1) == "string" and mt1 or ""
        local t = b:GetAttribute("type")
        local t1 = b:GetAttribute("type1")
        local isProt = (type(b.IsProtected) == "function") and (b:IsProtected() and true or false) or false
        local isForb = (type(b.IsForbidden) == "function") and (b:IsForbidden() and true or false) or false
        local norm = mt:gsub("\r\n", "\n"):gsub("\r", "\n")
        local stopLine = norm:match("(/stopmacro[^\n]*)")
        stopLine = type(stopLine) == "string" and stopLine or ""
        local hasStop = stopLine ~= ""
        local hasMountoff = mt:find("/mountoff", 1, true) ~= nil
        local hasAdv = mt:find("advfly", 1, true) ~= nil
        local stopDisp = (stopLine ~= "") and ("\"" .. stopLine .. "\"") or "none"
        return "ok (type=" .. tostring(t) .. ", type1=" .. tostring(t1) .. ", len=" .. tostring(#mt) .. ", len1=" .. tostring(#mt1) .. ", protected=" .. BoolStr(isProt) .. ", forbidden=" .. BoolStr(isForb) .. ", stopmacro=" .. BoolStr(hasStop) .. ", advfly=" .. BoolStr(hasAdv) .. ", mountoff=" .. BoolStr(hasMountoff) .. ", stopLine=" .. stopDisp .. ")"
    end

    Print(" - click button short: " .. tostring(shortName) .. " => " .. InspectBtn(shortName))
    Print(" - click button legacy: " .. tostring(longName) .. " => " .. InspectBtn(longName))

    do
        local rc = rawget(_G, "rcButton")
        if not rc then
            Print(" - rcButton: missing")
        else
            local rcName = (type(rc.GetName) == "function") and (rc:GetName() or "") or ""
            local canClick = type(rc.Click) == "function"
            local isProt = (type(rc.IsProtected) == "function") and (rc:IsProtected() and true or false) or false
            local isForb = (type(rc.IsForbidden) == "function") and (rc:IsForbidden() and true or false) or false
            Print(" - rcButton: present (name=" .. tostring(rcName) .. ", canClick=" .. BoolStr(canClick) .. ", protected=" .. BoolStr(isProt) .. ", forbidden=" .. BoolStr(isForb) .. ")")
        end
    end

    do
        local btn = rawget(_G, shortName)
        local mt = (btn and type(btn.GetAttribute) == "function") and (btn:GetAttribute("macrotext") or "") or nil
        if type(mt) ~= "string" or mt == "" then
            mt = (btn and type(btn.GetAttribute) == "function") and (btn:GetAttribute("macrotext1") or "") or mt
        end
        mt = type(mt) == "string" and mt or ""

        do
            local preview = {}
            local normPrev = mt:gsub("\r\n", "\n"):gsub("\r", "\n")
            for line in normPrev:gmatch("([^\n]*)\n?") do
                local t = Trim(line)
                if t ~= "" then
                    preview[#preview + 1] = t
                    if #preview >= 8 then
                        break
                    end
                end
            end
            if #preview > 0 then
                Print(" - armed preview (first non-empty lines):")
                for i = 1, #preview do
                    Print("   * " .. preview[i])
                end
            end
        end

        Print(" - armed contains '/click rcButton': " .. BoolStr(mt:find("/click rcButton", 1, true) ~= nil))
        Print(" - armed contains '/cancelaura': " .. BoolStr(mt:find("/cancelaura", 1, true) ~= nil))
        Print(" - armed contains '/fgo hs hearth': " .. BoolStr(mt:lower():find("/fgo hs hearth", 1, true) ~= nil))
        Print(" - armed contains '/click ExtraActionButton1': " .. BoolStr(mt:find("/click ExtraActionButton1", 1, true) ~= nil))

        -- Show what will actually run (after filtering + preprocessing):
        do
            local norm = mt:gsub("\r\n", "\n"):gsub("\r", "\n")
            local cancels = {}
            local clicks = {}
            local cancelTargets = {}
            for line in norm:gmatch("([^\n]*)\n?") do
                if line == "" and (#cancels + #clicks) > 0 and line == "" then
                    -- continue; blank lines don't matter
                end

                local t = Trim(line)
                if t:sub(1, 11):lower() == "/cancelaura" then
                    cancels[#cancels + 1] = t
                    do
                        local name = Trim(t:sub(12))
                        if name ~= "" then
                            cancelTargets[#cancelTargets + 1] = name
                        end
                    end
                elseif t:sub(1, 6):lower() == "/click" then
                    clicks[#clicks + 1] = t
                end
            end

            Print(" - armed cancelaura lines: " .. tostring(#cancels))
            for i = 1, math.min(#cancels, 6) do
                Print("   * " .. cancels[i])
            end
            if #cancels > 6 then
                Print("   * (" .. tostring(#cancels - 6) .. " more)")
            end

            -- Prove whether those cancelaura targets exist right now on the player.
            -- If a target doesn't match exactly, show up to a few close matches.
            do
                local function GetPlayerBuffs()
                    local buffs = {}

                    if type(C_UnitAuras) == "table" and type(C_UnitAuras.GetAuraDataByIndex) == "function" then
                        for i = 1, 80 do
                            ---@diagnostic disable-next-line: param-type-mismatch
                            local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
                            if not aura then
                                break
                            end
                            buffs[#buffs + 1] = aura
                        end
                    elseif type(UnitBuff) == "function" then
                        for i = 1, 80 do
                            local name, _, count, _, _, _, _, _, _, spellId = UnitBuff("player", i)
                            if not name then
                                break
                            end
                            buffs[#buffs + 1] = {
                                name = name,
                                applications = count,
                                spellId = spellId,
                            }
                        end
                    end

                    return buffs
                end

                local function FindExact(buffs, target)
                    local needle = tostring(target or "")
                    needle = Trim(needle)
                    if needle == "" then
                        return nil
                    end
                    needle = needle:lower()
                    for i = 1, #buffs do
                        local a = buffs[i]
                        local n = (type(a) == "table") and a.name or nil
                        if type(n) == "string" and n:lower() == needle then
                            return a
                        end
                    end
                    return nil
                end

                local function FindContains(buffs, target, max)
                    local needle = tostring(target or "")
                    needle = Trim(needle)
                    if needle == "" then
                        return {}
                    end
                    needle = needle:lower()

                    local out = {}
                    local cap = tonumber(max) or 3
                    for i = 1, #buffs do
                        if #out >= cap then
                            break
                        end
                        local a = buffs[i]
                        local n = (type(a) == "table") and a.name or nil
                        if type(n) == "string" and n:lower():find(needle, 1, true) ~= nil then
                            out[#out + 1] = a
                        end
                    end
                    return out
                end

                if #cancelTargets > 0 then
                    local buffs = GetPlayerBuffs()
                    Print(" - aura check (from armed cancelaura):")
                    for i = 1, math.min(#cancelTargets, 8) do
                        local target = cancelTargets[i]
                        local exact = FindExact(buffs, target)
                        if exact then
                            local sid = (type(exact) == "table" and exact.spellId) or nil
                            local apps = (type(exact) == "table" and exact.applications) or nil
                            Print("   * present: " .. tostring(target) .. " (spellId=" .. tostring(sid) .. ", stacks=" .. tostring(apps) .. ")")
                        else
                            Print("   * missing: " .. tostring(target))
                            local near = FindContains(buffs, target, 3)
                            for j = 1, #near do
                                local a = near[j]
                                Print("     - close match: " .. tostring(a.name) .. " (spellId=" .. tostring(a.spellId) .. ")")
                            end
                        end
                    end
                    if #cancelTargets > 8 then
                        Print("   * (" .. tostring(#cancelTargets - 8) .. " more not shown)")
                    end
                end
            end

            Print(" - armed click lines: " .. tostring(#clicks))
            for i = 1, math.min(#clicks, 6) do
                Print("   * " .. clicks[i])
            end
            if #clicks > 6 then
                Print("   * (" .. tostring(#clicks - 6) .. " more)")
            end
        end
    end
end

-- Public: arm secure /click buttons so user macros can run without a prep step.
function ns.MacroXCMD_ArmAllClickButtons()
    local armed, why = MacroXCMD_ArmAllImpl()
    return armed, why
end

function ns.MacroXCMD_ArmClickButton(mode, key)
    mode = NormalizeMode(mode)
    key = Trim(key)
    if key == "" then
        return false, "Missing key"
    end

    local cmd = FindCmd(mode, key)
    if not cmd then
        return false, "Not found"
    end

    local text = GetRunnableTextForCmd(mode, cmd)
    if Trim(text) == "" then
        return false, "Empty macro text"
    end

    return ArmSecureMacroClickButton(mode, key, text)
end

-- Debug helper: arm a click button with a visible marker so we can prove
-- whether macrotext actually runs when invoked via a real WoW macro.
function ns.MacroXCMD_ArmClickButtonWithMarker(mode, key, marker)
    mode = NormalizeMode(mode)
    key = Trim(key)
    if key == "" then
        return false, "Missing key"
    end

    if InCombatLockdown and InCombatLockdown() then
        return false, "In combat"
    end

    local cmd = FindCmd(mode, key)
    if not cmd then
        return false, "Not found"
    end

    local text = GetRunnableTextForCmd(mode, cmd)
    if Trim(text) == "" then
        return false, "Empty macro text"
    end

    local msg = Trim(tostring(marker or ""))
    if msg == "" then
        msg = "FGO MARKER: " .. tostring(mode) .. " " .. tostring(key)
    end

    -- Keep the marker simple and unambiguous.
    local prefix = "/say " .. msg .. "\n" .. "/run print(" .. string.format("%q", msg) .. ")\n"
    return ArmSecureMacroClickButton(mode, key, prefix .. text)
end

-- Create/update a real WoW macro that clicks the secure Macro CMD button.
-- This avoids manual macro creation; still requires the user to press the macro (hardware event).
function ns.MacroXCMD_MakeClickMacroMode(mode, key, macroName, perCharacter)
    InitSV()
    mode = NormalizeMode(mode)
    key = Trim(key)
    if key == "" then
        return false, "Missing key", nil, nil
    end

    local cmd = FindCmd(mode, key)
    if not cmd then
        return false, "Not found", nil, GetMacroClickBody(mode, key)
    end

    local realKey = tostring(cmd.key or key)
    local clickBody = GetMacroClickBody(mode, realKey)
    local finalName = Trim(macroName)
    if finalName == "" then
        finalName = GetDefaultClickMacroNameForKey(realKey)
    end

    -- Ensure the secure click target is armed for this character.
    if type(ns.MacroXCMD_ArmClickButton) == "function" then
        local okArm = nil
        okArm = select(1, ns.MacroXCMD_ArmClickButton(mode, realKey))
        if not okArm and InCombatLockdown and InCombatLockdown() then
            return false, "Can't arm in combat", finalName, clickBody
        end
    end

    local ok, why = EnsureClickMacro(finalName, clickBody, perCharacter)
    if not ok then
        return false, why, finalName, clickBody
    end
    return true, why, finalName, clickBody
end

function ns.MacroXCMD_MakeClickMacro(key, macroName, perCharacter)
    InitSV()
    local cmd, mode = MacroXCMD_FindAutoImpl(key)
    if not cmd then
        return false, "Not found", nil, nil
    end
    return ns.MacroXCMD_MakeClickMacroMode(mode, tostring(cmd.key or key), macroName, perCharacter)
end

-- Back-compat: keep older MacroCmd_* names working.
ns.MacroCmd_List = ns.MacroCmd_List or ns.MacroXCMD_List
ns.MacroCmd_Run = ns.MacroCmd_Run or ns.MacroXCMD_Run
ns.MacroCmd_HandleSlash = ns.MacroCmd_HandleSlash or ns.MacroXCMD_HandleSlash
