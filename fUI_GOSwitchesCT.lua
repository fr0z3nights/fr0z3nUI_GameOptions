local addonName, ns = ...
ns = ns or {}

ns.SwitchesCT = ns.SwitchesCT or {}
local CT = ns.SwitchesCT

local function InitSV()
    if ns and ns._InitSV then
        ns._InitSV()
    end
end

local function IsSecretString(v)
    return type(v) == "string" and type(issecretvalue) == "function" and issecretvalue(v)
end

local function SafeToString(v)
    if IsSecretString(v) then
        return "<secret>"
    end
    return tostring(v)
end

local function Print(msg)
    if ns and ns._Print then
        ns._Print(msg)
        return
    end
    print("|cff00ccff[FGO]|r " .. SafeToString(msg))
end

local function SafeCall(func, ...)
    if type(func) ~= "function" then
        return nil
    end
    local ok, a, b, c, d = pcall(func, ...)
    if not ok then
        return nil
    end
    return a, b, c, d
end

local CHROMIE_TIME_FALLBACK_NAMES = {
    [0] = "Present",
    [1] = "The Burning Crusade",
    [2] = "Wrath of the Lich King",
    [3] = "Cataclysm",
    [4] = "Mists of Pandaria",
    [5] = "Warlords of Draenor",
    [6] = "Legion",
    [7] = "Battle for Azeroth",
    [8] = "Shadowlands",
    [9] = "Dragonflight",
    [10] = "The War Within",
}

-- Some clients return option IDs that don't match expansion IDs.
-- Normalize known Chromie option IDs to the expansion names the UI should show.
local CHROMIE_TIME_OPTIONID_CANONICAL_NAMES = {
    [5] = "Cataclysm",
    [6] = "The Burning Crusade",
    [7] = "Wrath of the Lich King",
    [8] = "Mists of Pandaria",
    [9] = "Warlords of Draenor",
    [10] = "Legion",
    [14] = "Shadowlands",
    [15] = "Battle for Azeroth",
    [16] = "Dragonflight",
}

-- Forward declarations (used by Chromie selection hooks).
local IsChromieTimeAvailableToPlayer
local UpdateChromieIndicator
local EnsureChromieIndicator
local ForceHideChromieIndicator
local chromieIndicator

local function CanonicalizeChromieTimelineName(optionID, rawName)
    if type(optionID) == "number" then
        local mapped = CHROMIE_TIME_OPTIONID_CANONICAL_NAMES[optionID]
        if type(mapped) == "string" and mapped ~= "" then
            return mapped
        end
    end
    if type(rawName) ~= "string" or rawName == "" then
        return nil
    end

    if IsSecretString(rawName) then
        return nil
    end

    local s = string.lower(rawName)
    if s:find("outland", 1, true) then
        return "The Burning Crusade"
    end
    if s:find("lich king", 1, true) then
        return "Wrath of the Lich King"
    end
    if s:find("pandaria", 1, true) then
        return "Mists of Pandaria"
    end
    if s:find("draenor", 1, true) then
        return "Warlords of Draenor"
    end
    if s:find("legion", 1, true) then
        return "Legion"
    end
    return rawName
end

local function RememberChromieSelection(optionID, rawName)
    local id = tonumber(optionID)
    local nm = CanonicalizeChromieTimelineName(id, rawName)
    if type(id) ~= "number" and (type(nm) ~= "string" or nm == "") then
        return
    end
    InitSV()

    if id == 0 then
        AutoGossip_UI.chromieLastOptionID = 0
        AutoGossip_UI.chromieLastName = nil
        AutoGossip_UI.chromieForcePresentUntil = (GetTime and (GetTime() + 10)) or AutoGossip_UI.chromieForcePresentUntil
        AutoGossip_UI.chromieForceOptionUntil = nil
        AutoGossip_UI.chromieForceOptionID = nil
        AutoGossip_UI.chromieForceName = nil
        AutoGossip_UI.chromieLastAt = (GetTime and GetTime()) or AutoGossip_UI.chromieLastAt
        return
    end

    if type(id) == "number" then
        AutoGossip_UI.chromieLastOptionID = id
    end
    if type(nm) == "string" and nm ~= "" then
        AutoGossip_UI.chromieLastName = nm
    end

    -- Force the just-selected option for a brief window to avoid API lag showing the previous timeline.
    if GetTime then
        AutoGossip_UI.chromieForceOptionUntil = GetTime() + 4
        AutoGossip_UI.chromieForceOptionID = id
        AutoGossip_UI.chromieForceName = nm
    end

    AutoGossip_UI.chromieLastAt = (GetTime and GetTime()) or AutoGossip_UI.chromieLastAt
end

local function ClearChromieSelection(forcePresentSeconds)
    InitSV()
    AutoGossip_UI.chromieLastOptionID = 0
    AutoGossip_UI.chromieLastName = nil
    if type(forcePresentSeconds) == "number" and forcePresentSeconds > 0 then
        AutoGossip_UI.chromieForcePresentUntil = (GetTime and (GetTime() + forcePresentSeconds)) or AutoGossip_UI.chromieForcePresentUntil
    end
    AutoGossip_UI.chromieLastAt = (GetTime and GetTime()) or AutoGossip_UI.chromieLastAt
end

local chromieSelectHooked = false
local chromieHookedFns = nil
local chromieHookedFnSet = nil
local function SetupChromieSelectionTracking()
    if chromieSelectHooked then
        return
    end

    if type(C_ChromieTime) ~= "table" then
        return
    end

    chromieSelectHooked = true
    chromieHookedFns = {}
    chromieHookedFnSet = {}

    local function CaptureSelectionFromArg(optionArg)
        local id = nil
        local nm = nil

        if type(optionArg) == "number" then
            id = optionArg
        elseif type(optionArg) == "string" then
            id = tonumber(optionArg)
        elseif type(optionArg) == "table" then
            nm = optionArg.name or optionArg.text or optionArg.title or optionArg.displayName or optionArg.expansionName
            id = optionArg.id or optionArg.optionID or optionArg.expansionID
            id = tonumber(id)
        end

        if type(nm) == "string" then
            if IsSecretString(nm) then
                nm = nil
            end
            local s = nm and string.lower(nm) or nil
            if s and (s:find("present", 1, true) or s:find("current", 1, true) or s:find("return", 1, true)) then
                ClearChromieSelection(10)

                if AutoGossipOptions and AutoGossipOptions.UpdateChromieLabel then
                    pcall(AutoGossipOptions.UpdateChromieLabel)
                end
                InitSV()
                if AutoGossip_UI and AutoGossip_UI.chromieFrameEnabled and IsChromieTimeAvailableToPlayer() then
                    EnsureChromieIndicator()
                    UpdateChromieIndicator()
                elseif chromieIndicator then
                    UpdateChromieIndicator()
                end
                return
            end
        end

        if type(id) ~= "number" then
            return
        end

        if id == 0 then
            ClearChromieSelection(10)

            if AutoGossipOptions and AutoGossipOptions.UpdateChromieLabel then
                pcall(AutoGossipOptions.UpdateChromieLabel)
            end
            InitSV()
            if AutoGossip_UI and AutoGossip_UI.chromieFrameEnabled and IsChromieTimeAvailableToPlayer() then
                EnsureChromieIndicator()
                UpdateChromieIndicator()
            elseif chromieIndicator then
                UpdateChromieIndicator()
            end
            return
        end

        -- Try to resolve a display name from the options list.
        local options = SafeCall(C_ChromieTime.GetChromieTimeExpansionOptions)
        if type(options) == "table" then
            for _, opt in ipairs(options) do
                if type(opt) == "table" then
                    local oid = tonumber(opt.id) or tonumber(opt.optionID) or tonumber(opt.expansionID)
                    if oid and oid == id then
                        nm = nm or (opt.name or opt.text or opt.title or opt.displayName or opt.expansionName)
                        break
                    end
                end
            end
        end
        RememberChromieSelection(id, nm)

        -- Live refresh: timeline changes don't always fire world/zone events.
        if AutoGossipOptions and AutoGossipOptions.UpdateChromieLabel then
            pcall(AutoGossipOptions.UpdateChromieLabel)
        end
        InitSV()
        if AutoGossip_UI and AutoGossip_UI.chromieFrameEnabled and IsChromieTimeAvailableToPlayer() then
            EnsureChromieIndicator()
            UpdateChromieIndicator()
        elseif chromieIndicator then
            UpdateChromieIndicator()
        end
    end

    local function TryHookMethod(methodName)
        if type(methodName) ~= "string" then
            return
        end
        if type(C_ChromieTime[methodName]) ~= "function" then
            return
        end
        if chromieHookedFnSet and chromieHookedFnSet[methodName] then
            return
        end
        hooksecurefunc(C_ChromieTime, methodName, function(a, b)
            -- Most APIs pass the option as first arg; some pass it as second.
            CaptureSelectionFromArg(a)
            CaptureSelectionFromArg(b)
        end)
        if chromieHookedFnSet then
            chromieHookedFnSet[methodName] = true
        end
        chromieHookedFns[#chromieHookedFns + 1] = methodName
    end

    -- Hook the known one if present.
    TryHookMethod("SelectChromieTimeOption")
    TryHookMethod("SelectChromieTimeExpansionOption")
    TryHookMethod("SelectChromieTimeExpansion")
    TryHookMethod("SetChromieTimeExpansionOption")
    TryHookMethod("SetChromieTimeExpansionOptionID")

    -- Also hook any other plausible setters/selectors exposed by this client.
    for k, v in pairs(C_ChromieTime) do
        if type(k) == "string" and type(v) == "function" then
            local lk = k:lower()
            if (lk:find("chromie", 1, true) and (lk:find("select", 1, true) or lk:find("set", 1, true))) then
                if not (lk:find("get", 1, true) or lk:find("options", 1, true)) then
                    TryHookMethod(k)
                end
            end
        end
    end

    if type(C_ChromieTime.SetChromieTimeEnabled) == "function" then
        hooksecurefunc(C_ChromieTime, "SetChromieTimeEnabled", function(isEnabled)
            -- `isEnabled` may be a "secret boolean" on some builds; avoid direct comparisons.
            if not isEnabled then
                ClearChromieSelection(10)
            end
        end)
        if chromieHookedFnSet and not chromieHookedFnSet["SetChromieTimeEnabled"] then
            chromieHookedFnSet["SetChromieTimeEnabled"] = true
            chromieHookedFns[#chromieHookedFns + 1] = "SetChromieTimeEnabled"
        end
    end
end

local function GetChromieTimeInfo()
    if type(C_ChromieTime) ~= "table" then
        return false, nil, nil, false
    end

    local function NormalizeChromieName(v)
        if type(v) == "string" then
            if v ~= "" then
                return v
            end
            return nil
        end
        if type(v) == "table" then
            local s = v.name or v.text or v.title or v.displayName or v.expansionName
            if type(s) == "string" and s ~= "" then
                return s
            end
        end
        return nil
    end

    local options = SafeCall(C_ChromieTime.GetChromieTimeExpansionOptions)

    -- Modern/robust "ON" detection.
    -- In some builds/timelines (e.g. DF), GetChromieTimeEnabled can be unreliable.
    local enabled = nil
    if type(C_PlayerInfo) == "table" then
        local inChromie = SafeCall(C_PlayerInfo.IsPlayerInChromieTime)
        if type(inChromie) == "boolean" then
            enabled = inChromie
        end
    end
    if type(enabled) ~= "boolean" then
        enabled = SafeCall(C_ChromieTime.GetChromieTimeEnabled)
    end

    local optionID = SafeCall(C_ChromieTime.GetChromieTimeExpansionOptionID)
    if type(optionID) ~= "number" then
        optionID = SafeCall(C_ChromieTime.GetChromieTimeExpansionOption)
    end
    local name = nil
    local expansionID = nil

    if type(optionID) == "table" then
        name = NormalizeChromieName(optionID.name or optionID.text or optionID.title or optionID.displayName or optionID.expansionName) or NormalizeChromieName(optionID)
        expansionID = tonumber(optionID.expansionID)
        optionID = optionID.id or optionID.optionID or optionID.expansionID
    end
    if type(optionID) ~= "number" then
        optionID = SafeCall(C_ChromieTime.GetActiveChromieTimeExpansionOption)
    end

    if type(optionID) == "table" then
        name = name or NormalizeChromieName(optionID.name or optionID.text or optionID.title or optionID.displayName or optionID.expansionName) or NormalizeChromieName(optionID)
        expansionID = expansionID or tonumber(optionID.expansionID)
        optionID = optionID.id or optionID.optionID or optionID.expansionID
    end

    -- Some builds expose richer data via GetChromieTimeExpansionOption; use it to get a name when possible.
    if not name and type(C_ChromieTime.GetChromieTimeExpansionOption) == "function" then
        local opt = SafeCall(C_ChromieTime.GetChromieTimeExpansionOption)
        if type(opt) == "table" then
            name = NormalizeChromieName(opt.name or opt.text or opt.title or opt.displayName or opt.expansionName) or NormalizeChromieName(opt)
            expansionID = expansionID or tonumber(opt.expansionID)
            if type(optionID) ~= "number" then
                optionID = opt.id or opt.optionID or opt.expansionID
            end
        end
    end

    -- Some clients expose selection state only on the options list.
    if type(options) == "table" and (not name or type(optionID) ~= "number") then
        local function IsSelectedEntry(opt)
            if type(opt) ~= "table" then
                return false
            end
            return (opt.selected == true)
                or (opt.isSelected == true)
                or (opt.isActive == true)
                or (opt.active == true)
                or (opt.isCurrent == true)
                or (opt.isCurrentTimeline == true)
                or (opt.isCurrentlySelected == true)
                or (opt.inUse == true)
                or (opt.alreadyOn == true)
        end

        for _, opt in ipairs(options) do
            if IsSelectedEntry(opt) then
                name = name or NormalizeChromieName(opt.name or opt.text or opt.title or opt.displayName or opt.expansionName) or NormalizeChromieName(opt)
                local id1 = tonumber(opt.id)
                local id2 = tonumber(opt.optionID)
                local id3 = tonumber(opt.expansionID)
                expansionID = expansionID or id3
                if type(optionID) ~= "number" then
                    optionID = id1 or id2 or id3
                end
                if type(enabled) ~= "boolean" and type(optionID) == "number" and optionID > 0 then
                    enabled = true
                end
                break
            end
        end
    end

    if type(enabled) ~= "boolean" then
        enabled = (type(optionID) == "number" and optionID > 0) and true or false
    end

    if type(optionID) == "number" and optionID == 0 then
        enabled = false
    end

    -- If we just selected "Present", some APIs can lag behind briefly.
    -- Honor a short force-present window so the indicator clears immediately.
    InitSV()
    if enabled and AutoGossip_UI and type(AutoGossip_UI.chromieForcePresentUntil) == "number" and GetTime then
        if GetTime() < AutoGossip_UI.chromieForcePresentUntil then
            enabled = false
            optionID = 0
        end
    end

    -- If we just selected a timeline, some APIs can lag and still return the previous one.
    -- Honor a short force-option window so the indicator updates immediately.
    if enabled and AutoGossip_UI and type(AutoGossip_UI.chromieForceOptionUntil) == "number" and GetTime then
        if GetTime() < AutoGossip_UI.chromieForceOptionUntil then
            local fid = tonumber(AutoGossip_UI.chromieForceOptionID)
            local fnm = AutoGossip_UI.chromieForceName
            if type(fid) == "number" and fid > 0 then
                optionID = fid
                name = CanonicalizeChromieTimelineName(fid, fnm or name)
            elseif type(AutoGossip_UI.chromieLastOptionID) == "number" and AutoGossip_UI.chromieLastOptionID > 0 then
                optionID = AutoGossip_UI.chromieLastOptionID
                name = CanonicalizeChromieTimelineName(optionID, AutoGossip_UI.chromieLastName or name)
            end
        end
    end

    if type(options) == "table" and type(optionID) == "number" then
        for _, opt in ipairs(options) do
            if type(opt) == "table" then
                local id1 = tonumber(opt.id)
                local id2 = tonumber(opt.optionID)
                local id3 = tonumber(opt.expansionID)
                if (id1 and id1 == optionID) or (id2 and id2 == optionID) or (id3 and id3 == optionID) then
                    name = name or NormalizeChromieName(opt.name or opt.text or opt.title or opt.displayName or opt.expansionName) or NormalizeChromieName(opt)
                    expansionID = expansionID or id3
                    break
                end
            end
        end
    end

    if type(optionID) == "number" then
        name = CanonicalizeChromieTimelineName(optionID, name)
    end

    if not name then
        if type(expansionID) == "number" then
            name = CHROMIE_TIME_FALLBACK_NAMES[expansionID]
        end
        if not name and type(optionID) == "number" then
            name = CHROMIE_TIME_FALLBACK_NAMES[optionID]
        end
    end

    -- If the game won't tell us the current option, fall back to the last one we observed being selected.
    if enabled and (type(name) ~= "string" or name == "") then
        InitSV()
        local lastName = AutoGossip_UI and AutoGossip_UI.chromieLastName or nil
        local lastID = AutoGossip_UI and AutoGossip_UI.chromieLastOptionID or nil
        if type(lastName) == "string" and lastName ~= "" then
            name = lastName
        end
        if type(optionID) ~= "number" and type(lastID) == "number" then
            optionID = lastID
        end
    end

    if enabled and type(optionID) == "number" and type(name) == "string" and name ~= "" then
        -- Avoid overwriting a just-selected timeline with stale API results during the force window.
        if not (AutoGossip_UI and type(AutoGossip_UI.chromieForceOptionUntil) == "number" and GetTime and GetTime() < AutoGossip_UI.chromieForceOptionUntil) then
            RememberChromieSelection(optionID, name)
        end
    end

    return enabled, optionID, name, true
end

SLASH_FGOCHROMIE1 = SLASH_FGOCHROMIE1 or "/fgochromie"
if type(SlashCmdList) == "table" and rawget(SlashCmdList, "FGOCHROMIE") == nil then
rawset(SlashCmdList, "FGOCHROMIE", function()
    local enabled, optionID, name, supported = GetChromieTimeInfo()
    Print("Chromie: supported=" .. tostring(supported) .. " enabled=" .. tostring(enabled) .. " optionID=" .. tostring(optionID) .. " name=" .. tostring(name))

    InitSV()
    Print("Chromie: saved optionID=" .. tostring(AutoGossip_UI and AutoGossip_UI.chromieLastOptionID) .. " saved name=" .. tostring(AutoGossip_UI and AutoGossip_UI.chromieLastName))
    if type(chromieHookedFns) == "table" and #chromieHookedFns > 0 then
        Print("Chromie: hooked=" .. table.concat(chromieHookedFns, ", "))
    else
        Print("Chromie: hooked=<none>")
    end

    if type(C_ChromieTime) ~= "table" or type(C_ChromieTime.GetChromieTimeExpansionOptions) ~= "function" then
        Print("Chromie: no options API")
        return
    end

    local options = SafeCall(C_ChromieTime.GetChromieTimeExpansionOptions)
    if type(options) ~= "table" then
        Print("Chromie: options=nil")
        return
    end

    local maxDump = 12
    Print("Chromie: options=" .. tostring(#options) .. " (dumping up to " .. tostring(maxDump) .. ")")
    for i = 1, math.min(#options, maxDump) do
        local opt = options[i]
        if type(opt) == "table" then
            local id1 = tostring(opt.id)
            local id2 = tostring(opt.optionID)
            local id3 = tostring(opt.expansionID)
            local nm = tostring(opt.name or opt.text or opt.title or opt.displayName or opt.expansionName)
            local flags = {}
            if opt.selected == true then flags[#flags + 1] = "selected" end
            if opt.isSelected == true then flags[#flags + 1] = "isSelected" end
            if opt.isActive == true then flags[#flags + 1] = "isActive" end
            if opt.active == true then flags[#flags + 1] = "active" end
            if opt.isCurrent == true then flags[#flags + 1] = "isCurrent" end
            if opt.isCurrentTimeline == true then flags[#flags + 1] = "isCurrentTimeline" end
            if opt.isCurrentlySelected == true then flags[#flags + 1] = "isCurrentlySelected" end
            if opt.inUse == true then flags[#flags + 1] = "inUse" end
            if opt.alreadyOn == true then flags[#flags + 1] = "alreadyOn" end
            local sp = tostring(opt.sortPriority)
            Print("Opt[" .. tostring(i) .. "] id=" .. id1 .. " optionID=" .. id2 .. " expansionID=" .. id3 .. " sortPriority=" .. sp .. " name=" .. nm .. " flags=" .. table.concat(flags, ","))
        else
            Print("Opt[" .. tostring(i) .. "]=" .. tostring(opt))
        end
    end
end)
end

local function GetPlayerLevel()
    if not UnitLevel then
        return nil
    end
    local lvl = UnitLevel("player")
    if type(lvl) ~= "number" then
        return nil
    end
    return lvl
end

IsChromieTimeAvailableToPlayer = function()
    if type(C_ChromieTime) ~= "table" then
        return false
    end

    if type(C_PlayerInfo) == "table" and type(C_PlayerInfo.CanPlayerEnterChromieTime) == "function" then
        local canEnter = SafeCall(C_PlayerInfo.CanPlayerEnterChromieTime)
        if type(canEnter) == "boolean" and not canEnter then
            return false
        end
    end

    -- If the options list isn't present, assume Chromie Time isn't usable.
    local options = SafeCall(C_ChromieTime.GetChromieTimeExpansionOptions)
    if type(options) ~= "table" or #options == 0 then
        return false
    end

    -- Gate by level (configurable): only show when player level <= gate.
    InitSV()
    local gate = AutoGossip_UI and tonumber(AutoGossip_UI.chromieGateLevel) or nil
    local lvl = GetPlayerLevel()
    if type(gate) ~= "number" or type(lvl) ~= "number" then
        return false
    end
    if lvl > gate then
        return false
    end

    return true
end

local function IsPlayerResting()
    if not IsResting then
        return false
    end
    return IsResting() and true or false
end

local function FindChromieOffOptionID()
    if type(C_ChromieTime) ~= "table" then
        return nil
    end

    local options = SafeCall(C_ChromieTime.GetChromieTimeExpansionOptions)
    if type(options) ~= "table" then
        return nil
    end

    for _, opt in ipairs(options) do
        if type(opt) == "table" then
            local id = opt.id or opt.optionID or opt.expansionID
            if tonumber(id) == 0 then
                return 0
            end
        end
    end

    for _, opt in ipairs(options) do
        if type(opt) == "table" then
            local id = opt.id or opt.optionID or opt.expansionID
            local name = opt.name or opt.text or opt.title
            if type(name) == "string" then
                local s = name:lower()
                if s:find("present", 1, true) or s:find("current", 1, true) or s:find("return", 1, true) then
                    if type(id) == "number" then
                        return id
                    end
                    local n = tonumber(id)
                    if n then
                        return n
                    end
                end
            end
        end
    end

    return 0
end

local function TryDisableChromieTime()
    if not IsChromieTimeAvailableToPlayer() then
        return false, "unavailable"
    end

    if not IsPlayerResting() then
        return false, "not-rested"
    end

    if type(C_ChromieTime) ~= "table" then
        return false, "no-api"
    end

    local didAny = false

    if type(C_ChromieTime.SetChromieTimeEnabled) == "function" then
        local ok = SafeCall(C_ChromieTime.SetChromieTimeEnabled, false)
        if ok ~= nil then
            didAny = true
        end
    end

    if type(C_ChromieTime.SelectChromieTimeOption) == "function" then
        local offID = FindChromieOffOptionID()
        SafeCall(C_ChromieTime.SelectChromieTimeOption, tonumber(offID) or 0)
        didAny = true
    end

    if not didAny then
        return false, "no-disable-func"
    end
    return true
end

local function GetChromieTimeDisplayText()
    local enabled, optionID, name, supported = GetChromieTimeInfo()
    if not supported then
        return "Chromie Time\nN/A"
    end
    if not enabled then
        return "Chromie Time\nPresent"
    end
    if type(name) == "string" and name ~= "" then
        return "Chromie Time\n" .. name
    end
    if type(optionID) == "number" then
        return "Chromie Time\nON (" .. tostring(optionID) .. ")"
    end
    return "Chromie Time\nON"
end

local CHROMIE_FONT_PRESETS = {
    { key = "default", name = "Default (UI)", path = nil },
    { key = "friz", name = "Friz Quadrata", path = "Fonts\\FRIZQT__.TTF" },
    { key = "arialn", name = "Arial Narrow", path = "Fonts\\ARIALN.TTF" },
    { key = "morpheus", name = "Morpheus", path = "Fonts\\MORPHEUS.TTF" },
    { key = "skurri", name = "Skurri", path = "Fonts\\SKURRI.TTF" },
    { key = "bazooka", name = "Bazooka (DateTime)", path = "Interface\\AddOns\\fr0z3nUI_DateTime\\media\\Bazooka.ttf" },
}

local function GetLibSharedMedia()
    local la = _G and rawget(_G, "LoadAddOn")
    if type(la) == "function" then
        pcall(la, "LibSharedMedia-3.0")
    end
    local libStub = _G and rawget(_G, "LibStub")
    if type(libStub) == "table" then
        if type(libStub.GetLibrary) == "function" then
            local ok, lib = pcall(libStub.GetLibrary, libStub, "LibSharedMedia-3.0", true)
            if ok and type(lib) == "table" then
                return lib
            end
        end
        -- LibStub is often a callable table.
        local ok2, lib2 = pcall(libStub, "LibSharedMedia-3.0", true)
        if ok2 and type(lib2) == "table" then
            return lib2
        end
    elseif type(libStub) == "function" then
        local ok, lib = pcall(libStub, "LibSharedMedia-3.0", true)
        if ok and type(lib) == "table" then
            return lib
        end
    end
    return nil
end

local function GetLSMFontNames()
    local lsm = GetLibSharedMedia()
    if not lsm then
        return nil
    end
    local names = {}
    if type(lsm.List) == "function" then
        local ok, list = pcall(lsm.List, lsm, "font")
        if ok and type(list) == "table" then
            for _, n in ipairs(list) do
                if type(n) == "string" and n ~= "" then
                    names[#names + 1] = n
                end
            end
        end
    end
    if #names == 0 and type(lsm.HashTable) == "function" then
        local ok, ht = pcall(lsm.HashTable, lsm, "font")
        if ok and type(ht) == "table" then
            for n in pairs(ht) do
                if type(n) == "string" and n ~= "" then
                    names[#names + 1] = n
                end
            end
        end
    end
    if #names == 0 then
        return nil
    end
    table.sort(names, function(a, b)
        return tostring(a):lower() < tostring(b):lower()
    end)
    return names
end

local function ResolveChromieFontPath(fontKey, fontString)
    if type(fontKey) ~= "string" or fontKey == "" then
        fontKey = "default"
    end

    local lsmName = fontKey:match("^lsm:(.+)$")
    if lsmName then
        local lsm = GetLibSharedMedia()
        if lsm then
            local fetch = lsm.Fetch or lsm.fetch
            if type(fetch) == "function" then
                local ok, path = pcall(fetch, lsm, "font", lsmName)
                if ok and type(path) == "string" and path ~= "" then
                    return path
                end
            end
            if type(lsm.HashTable) == "function" then
                local ok, ht = pcall(lsm.HashTable, lsm, "font")
                if ok and type(ht) == "table" then
                    local p = ht[lsmName]
                    if type(p) == "string" and p ~= "" then
                        return p
                    end
                end
            end
        end
    end

    for _, preset in ipairs(CHROMIE_FONT_PRESETS) do
        if preset.key == fontKey then
            if preset.path == nil then
                if fontString and fontString.GetFont then
                    local current = select(1, fontString:GetFont())
                    if type(current) == "string" and current ~= "" then
                        return current
                    end
                end
                return nil
            end
            return preset.path
        end
    end

    return nil
end

local function GetChromieFrameStyle()
    InitSV()
    local style = AutoGossip_UI and AutoGossip_UI.chromieFrameStyle
    if type(style) ~= "table" then
        return {
            fontKey = "default",
            textSize = 12,
            textColor = { 1, 1, 1 },
            bgAlpha = 0.55,
            borderAlpha = 0.55,
            textAlpha = 1,
        }
    end
    if type(style.textColor) ~= "table" then
        style.textColor = { 1, 1, 1 }
    end
    return style
end

local function GetPlayerClassColorRGB()
    if not UnitClass then
        return 1, 1, 1
    end
    local _, classTag = UnitClass("player")
    if type(classTag) ~= "string" then
        return 1, 1, 1
    end
    local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classTag]
    if c and type(c.r) == "number" and type(c.g) == "number" and type(c.b) == "number" then
        return c.r, c.g, c.b
    end
    return 1, 1, 1
end

local function ApplyChromieIndicatorStyle()
    if not chromieIndicator then
        return
    end
    local style = GetChromieFrameStyle()

    if chromieIndicator.bg and chromieIndicator.bg.SetColorTexture then
        chromieIndicator.bg:SetColorTexture(0, 0, 0, tonumber(style.bgAlpha) or 0.55)
    end

    if chromieIndicator.border and type(chromieIndicator.border) == "table" then
        local a = tonumber(style.borderAlpha)
        if a == nil then a = 0.55 end
        for _, t in ipairs(chromieIndicator.border) do
            if t and t.SetColorTexture then
                t:SetColorTexture(1, 1, 1, a)
            end
        end
    end

    if chromieIndicator.text and chromieIndicator.text.SetFont then
        local size = tonumber(style.textSize) or 12
        local path = ResolveChromieFontPath(style.fontKey, chromieIndicator.text)
        if type(path) == "string" and path ~= "" then
            pcall(chromieIndicator.text.SetFont, chromieIndicator.text, path, size)
        else
            -- Fallback: try to just set size on existing font.
            local current = chromieIndicator.text.GetFont and select(1, chromieIndicator.text:GetFont())
            if type(current) == "string" and current ~= "" then
                pcall(chromieIndicator.text.SetFont, chromieIndicator.text, current, size)
            end
        end

        local r, g, b = GetPlayerClassColorRGB()
        local a = tonumber(style.textAlpha)
        if a == nil then a = 1 end
        pcall(chromieIndicator.text.SetTextColor, chromieIndicator.text, r, g, b, a)

        -- Two-line label: ensure the frame is tall enough for two lines.
        -- Keep width stable; height scales with text size.
        if chromieIndicator.SetHeight then
            chromieIndicator:SetHeight(math.max(22, (size * 2) + 10))
        end
    end
end

local function ApplyChromieIndicatorPosition()
    if not chromieIndicator then
        return
    end
    if not (AutoGossip_UI and type(AutoGossip_UI.chromieFramePos) == "table") then
        return
    end

    local pos = AutoGossip_UI.chromieFramePos
    local point = pos.point or "CENTER"
    local relPoint = pos.relativePoint or point
    local x = tonumber(pos.x) or 0
    local y = tonumber(pos.y) or 0

    chromieIndicator:ClearAllPoints()
    chromieIndicator:SetPoint(point, UIParent, relPoint, x, y)
end

UpdateChromieIndicator = function()
    if not chromieIndicator then
        return
    end

    InitSV()

    local enabled = AutoGossip_UI and AutoGossip_UI.chromieFrameEnabled
    local available = IsChromieTimeAvailableToPlayer()
    -- Safety: enforce the gate here too so the frame can't get stuck visible.
    local gate = AutoGossip_UI and tonumber(AutoGossip_UI.chromieGateLevel) or nil
    local lvl = GetPlayerLevel()
    if type(gate) ~= "number" or type(lvl) ~= "number" or lvl > gate then
        available = false
    end
    chromieIndicator:SetShown(enabled and available)
    if enabled and available and chromieIndicator.text then
        chromieIndicator.text:SetText(GetChromieTimeDisplayText())
    end

    local locked = AutoGossip_CharSettings and AutoGossip_CharSettings.chromieFrameLocked
    chromieIndicator.isLocked = locked and true or false
    chromieIndicator:EnableMouse(true)

    ApplyChromieIndicatorStyle()
end

ForceHideChromieIndicator = function()
    if chromieIndicator and chromieIndicator.Hide then
        chromieIndicator:Hide()
    end
    local named = _G and rawget(_G, "FGO_ChromieIndicator")
    if named and named.Hide then
        named:Hide()
    end
end

EnsureChromieIndicator = function()
    if chromieIndicator or not UIParent then
        return chromieIndicator
    end

    local frame = CreateFrame("Frame", "FGO_ChromieIndicator", UIParent)
    frame:Hide()
    frame:SetSize(180, 34)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")

    frame:SetScript("OnShow", function(self)
        InitSV()
        local gate = AutoGossip_UI and tonumber(AutoGossip_UI.chromieGateLevel) or nil
        local lvl = GetPlayerLevel()
        if type(gate) ~= "number" or type(lvl) ~= "number" or lvl > gate then
            self:Hide()
            return
        end
        if not IsChromieTimeAvailableToPlayer() then
            self:Hide()
            return
        end
        if not (AutoGossip_UI and AutoGossip_UI.chromieFrameEnabled) then
            self:Hide()
            return
        end
    end)

    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.55)
    frame.bg = bg

    local border = {}
    local thickness = 1
    local top = frame:CreateTexture(nil, "BORDER")
    top:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    top:SetHeight(thickness)
    border[#border + 1] = top
    local bottom = frame:CreateTexture(nil, "BORDER")
    bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    bottom:SetHeight(thickness)
    border[#border + 1] = bottom
    local left = frame:CreateTexture(nil, "BORDER")
    left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    left:SetWidth(thickness)
    border[#border + 1] = left
    local right = frame:CreateTexture(nil, "BORDER")
    right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    right:SetWidth(thickness)
    border[#border + 1] = right
    frame.border = border

    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("CENTER", frame, "CENTER", 0, 0)
    text:SetJustifyH("CENTER")
    if text.SetJustifyV then
        text:SetJustifyV("MIDDLE")
    end
    text:SetWidth(176)
    text:SetText("")
    frame.text = text

    frame:SetScript("OnDragStart", function(self)
        if self.isLocked then
            return
        end
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        InitSV()

        local point, _, relativePoint, xOfs, yOfs = self:GetPoint(1)
        AutoGossip_UI.chromieFramePos = AutoGossip_UI.chromieFramePos or {}
        AutoGossip_UI.chromieFramePos.point = point
        AutoGossip_UI.chromieFramePos.relativePoint = relativePoint
        AutoGossip_UI.chromieFramePos.x = xOfs
        AutoGossip_UI.chromieFramePos.y = yOfs
    end)

    frame:SetScript("OnEnter", function(self)
        if GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText("Chromie Time")
            GameTooltip:AddLine("Shows current Chromie Time status.", 1, 1, 1, true)
            GameTooltip:AddLine("Only appears when Chromie Time is available.", 1, 1, 1, true)
            GameTooltip:AddLine("Drag to move (unless locked).", 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    frame:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)

    chromieIndicator = frame
    ApplyChromieIndicatorPosition()
    UpdateChromieIndicator()
    ApplyChromieIndicatorStyle()
    return chromieIndicator
end

local chromieConfigPopup

local function GetChromieFontDropdownItems()
    local items = {}
    for _, preset in ipairs(CHROMIE_FONT_PRESETS) do
        items[#items + 1] = { key = preset.key, name = preset.name }
    end

    local lsmFonts = GetLSMFontNames()
    if type(lsmFonts) == "table" then
        for _, n in ipairs(lsmFonts) do
            items[#items + 1] = { key = "lsm:" .. n, name = "LSM: " .. n }
        end
    end

    return items
end

local function GetChromieFontDisplayName(fontKey)
    if type(fontKey) ~= "string" then
        return "Default (UI)"
    end
    local lsmName = fontKey:match("^lsm:(.+)$")
    if lsmName then
        return "LSM: " .. lsmName
    end
    for _, preset in ipairs(CHROMIE_FONT_PRESETS) do
        if preset.key == fontKey then
            return preset.name
        end
    end
    return "Default (UI)"
end

local function EnsureChromieConfigPopup()
    if chromieConfigPopup or not UIParent then
        return chromieConfigPopup
    end

    local p = CreateFrame("Frame", "FGO_ChromieConfigPopup", UIParent, "BasicFrameTemplateWithInset")
    p:SetSize(360, 280)
    p:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    p:SetFrameStrata("DIALOG")
    p:Hide()

    do
        if p.NineSlice and p.NineSlice.Hide then p.NineSlice:Hide() end
        if p.Bg and p.Bg.Hide then p.Bg:Hide() end
        if p.TitleBg and p.TitleBg.Hide then p.TitleBg:Hide() end
        if p.InsetBg and p.InsetBg.Hide then p.InsetBg:Hide() end
        if p.Inset and p.Inset.Hide then p.Inset:Hide() end

        local bg = CreateFrame("Frame", nil, p, "BackdropTemplate")
        bg:SetAllPoints(p)
        bg:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            tile = true,
            tileSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        bg:SetBackdropColor(0, 0, 0, 0.85)
        bg:SetFrameLevel((p.GetFrameLevel and p:GetFrameLevel() or 0))
        p._unifiedBG = bg

        local closeBtn = p.CloseButton
        if not closeBtn then
            closeBtn = CreateFrame("Button", nil, p, "UIPanelCloseButton")
        end
        if closeBtn and closeBtn.ClearAllPoints and closeBtn.SetPoint then
            closeBtn:ClearAllPoints()
            closeBtn:SetPoint("TOPRIGHT", p, "TOPRIGHT", -6, -6)
            if closeBtn.SetFrameLevel then
                closeBtn:SetFrameLevel((p.GetFrameLevel and p:GetFrameLevel() or 0) + 20)
            end
            closeBtn:SetScript("OnClick", function() if p and p.Hide then p:Hide() end end)
        end
    end

    p.title = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    p.title:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -6)
    p.title:SetText("Chromie Frame Config")
    do
        local fontPath, fontSize, fontFlags = p.title:GetFont()
        if fontPath and fontSize then
            p.title:SetFont(fontPath, fontSize + 2, fontFlags)
        end
    end

    local fontLabel = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fontLabel:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -34)
    fontLabel:SetText("Font")

    local gateLabel = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    gateLabel:SetPoint("TOPRIGHT", p, "TOPRIGHT", -96, -34)
    gateLabel:SetJustifyH("RIGHT")
    gateLabel:SetText("Show <=")

    local gateBox = CreateFrame("EditBox", nil, p, "InputBoxTemplate")
    gateBox:SetAutoFocus(false)
    gateBox:SetSize(44, 18)
    gateBox:SetPoint("LEFT", gateLabel, "RIGHT", 6, 0)
    gateBox:SetNumeric(true)
    gateBox:SetMaxLetters(3)
    p.gateBox = gateBox

    -- Scrollable font picker (Blizzard UIDropDownMenu has no scroll and can run off-screen).
    local fontBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    fontBtn:SetSize(240, 22)
    fontBtn:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -54)
    fontBtn:SetText("Default (UI)")
    p.fontBtn = fontBtn

    local fontList
    local fontListScroll
    local fontListContent
    local fontListButtons = {}

    local function HideFontList()
        if fontList and fontList.IsShown and fontList:IsShown() then
            fontList:Hide()
        end
    end

    local function EnsureFontList()
        if fontList then
            return
        end

        fontList = CreateFrame("Frame", nil, p, "BackdropTemplate")
        fontList:SetFrameStrata("DIALOG")
        fontList:SetClampedToScreen(true)
        fontList:SetSize(260, 190)
        fontList:SetAlpha(1)
        fontList:SetBackdrop({
            bgFile = "Interface/Buttons/WHITE8X8",
            tile = false,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        fontList:SetBackdropColor(0, 0, 0, 1)
        fontList:Hide()

        fontListScroll = CreateFrame("ScrollFrame", nil, fontList, "UIPanelScrollFrameTemplate")
        fontListScroll:SetPoint("TOPLEFT", fontList, "TOPLEFT", 6, -6)
        fontListScroll:SetPoint("BOTTOMRIGHT", fontList, "BOTTOMRIGHT", -28, 6)

        fontListContent = CreateFrame("Frame", nil, fontListScroll)
        fontListContent:SetSize(1, 1)
        fontListScroll:SetScrollChild(fontListContent)
    end

    local function SetFontKey(key)
        InitSV()
        AutoGossip_UI.chromieFrameStyle = AutoGossip_UI.chromieFrameStyle or {}
        AutoGossip_UI.chromieFrameStyle.fontKey = key
        if fontBtn and fontBtn.SetText then
            fontBtn:SetText(GetChromieFontDisplayName(key))
        end
        EnsureChromieIndicator()
        ApplyChromieIndicatorStyle()
    end

    local function RebuildFontList()
        EnsureFontList()

        for _, b in ipairs(fontListButtons) do
            if b and b.Hide then
                b:Hide()
            end
        end
        wipe(fontListButtons)

        local items = GetChromieFontDropdownItems()
        local y = -2
        local rowH = 18
        local w = 210

        for i, it in ipairs(items) do
            local btn = CreateFrame("Button", nil, fontListContent)
            btn:SetSize(w, rowH)
            btn:SetPoint("TOPLEFT", fontListContent, "TOPLEFT", 0, y)
            y = y - rowH

            local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            fs:SetPoint("LEFT", btn, "LEFT", 4, 0)
            fs:SetJustifyH("LEFT")
            fs:SetText(it.name)

            -- Try to preview the font by rendering the label using that font.
            -- (Falls back silently to the default font if the path can't be resolved.)
            local previewPath = ResolveChromieFontPath(it.key, fs)
            if type(previewPath) == "string" and previewPath ~= "" and fs.SetFont then
                pcall(fs.SetFont, fs, previewPath, 12)
            end

            btn._key = it.key
            btn._label = fs

            btn:SetScript("OnClick", function(self)
                SetFontKey(self._key)
                HideFontList()
                if p.RefreshFromSV then
                    p.RefreshFromSV()
                end
            end)

            fontListButtons[i] = btn
        end

        local totalH = (-y) + 4
        fontListContent:SetHeight(totalH)
        fontListContent:SetWidth(w)

        -- Apply selection coloring.
        local selectedKey = GetChromieFrameStyle().fontKey
        for _, btn in ipairs(fontListButtons) do
            if btn and btn._label then
                if btn._key == selectedKey then
                    btn._label:SetTextColor(0, 1, 1)
                else
                    btn._label:SetTextColor(1, 1, 1)
                end
            end
        end
    end

    local function ToggleFontList()
        EnsureFontList()
        if fontList:IsShown() then
            fontList:Hide()
            return
        end

        RebuildFontList()

        fontList:ClearAllPoints()
        -- Prefer below the button; flip above if we're close to bottom of screen.
        local bottom = fontBtn and fontBtn.GetBottom and fontBtn:GetBottom() or nil
        if type(bottom) == "number" and bottom < 220 then
            fontList:SetPoint("BOTTOMLEFT", fontBtn, "TOPLEFT", 0, 4)
        else
            fontList:SetPoint("TOPLEFT", fontBtn, "BOTTOMLEFT", 0, -4)
        end
        fontList:Show()
        fontList:Raise()
    end

    fontBtn:SetScript("OnClick", function()
        ToggleFontList()
    end)
    fontBtn:SetScript("OnHide", HideFontList)
    if p.HookScript then
        p:HookScript("OnHide", HideFontList)
    end

    local function CreateSlider(_, label, minVal, maxVal, step, x, y)
        local s = CreateFrame("Slider", nil, p, "OptionsSliderTemplate")
        s:SetPoint("TOPLEFT", p, "TOPLEFT", x, y)
        s:SetMinMaxValues(minVal, maxVal)
        s:SetValueStep(step)
        s:SetObeyStepOnDrag(true)
        s:SetWidth(300)

        local text = s.Text
        local low = s.Low
        local high = s.High
        if (not text or not low or not high) and s.GetName then
            local n = s:GetName()
            if n then
                text = text or _G[n .. "Text"]
                low = low or _G[n .. "Low"]
                high = high or _G[n .. "High"]
            end
        end
        if text then text:SetText(label) end
        if low then low:SetText(tostring(minVal)) end
        if high then high:SetText(tostring(maxVal)) end
        s._label = label
        s._valueText = text
        return s
    end

    local sizeSlider = CreateSlider("chromieSize", "Text Size", 8, 24, 1, 16, -96)
    p.sizeSlider = sizeSlider

    local bgSlider = CreateSlider("chromieBg", "Background Alpha", 0, 100, 1, 16, -140)
    p.bgSlider = bgSlider

    local borderSlider = CreateSlider("chromieBorder", "Border Alpha", 0, 100, 1, 16, -184)
    p.borderSlider = borderSlider

    local textAlphaSlider = CreateSlider("chromieTextAlpha", "Text Alpha", 0, 100, 1, 16, -228)
    p.textAlphaSlider = textAlphaSlider

    local colorBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    colorBtn:SetSize(80, 22)
    colorBtn:SetPoint("TOPRIGHT", p, "TOPRIGHT", -14, -72)
    colorBtn:SetText("Color")
    p.colorBtn = colorBtn

    local preview = p:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    preview:SetPoint("BOTTOM", p, "BOTTOM", 0, 18)
    preview:SetText("Chromie: Preview")
    p.preview = preview

    local function RefreshFromSV()
        InitSV()
        local style = GetChromieFrameStyle()

        if gateBox and gateBox.SetText then
            gateBox:SetText(tostring(tonumber(AutoGossip_UI.chromieGateLevel) or 79))
        end

        if fontBtn and fontBtn.SetText then
            fontBtn:SetText(GetChromieFontDisplayName(style.fontKey))
        end

        sizeSlider:SetValue(tonumber(style.textSize) or 12)
        bgSlider:SetValue(math.floor((tonumber(style.bgAlpha) or 0.55) * 100 + 0.5))
        borderSlider:SetValue(math.floor((tonumber(style.borderAlpha) or 0.55) * 100 + 0.5))
        textAlphaSlider:SetValue(math.floor((tonumber(style.textAlpha) or 1) * 100 + 0.5))

        EnsureChromieIndicator()
        ApplyChromieIndicatorStyle()

        if preview and preview.SetFont then
            local path = ResolveChromieFontPath(style.fontKey, preview)
            local size = tonumber(style.textSize) or 12
            if type(path) == "string" and path ~= "" then
                pcall(preview.SetFont, preview, path, size)
            end
            local r, g, b = GetPlayerClassColorRGB()
            local a = tonumber(style.textAlpha)
            if a == nil then a = 1 end
            pcall(preview.SetTextColor, preview, r, g, b, a)
        end
    end
    p.RefreshFromSV = RefreshFromSV

    local function ApplyGateFromBox()
        InitSV()
        local raw = gateBox and gateBox.GetText and gateBox:GetText() or ""
        local n = tonumber(raw)
        if type(n) ~= "number" then
            n = 79
        end
        if n < 1 then n = 1 end
        if n > 80 then n = 80 end
        AutoGossip_UI.chromieGateLevel = n

        -- Refresh label + indicator (may hide immediately).
        if AutoGossipOptions and AutoGossipOptions.UpdateChromieLabel then
            AutoGossipOptions.UpdateChromieLabel()
        else
            EnsureChromieIndicator()
            UpdateChromieIndicator()
        end
    end

    gateBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        ApplyGateFromBox()
        if p.RefreshFromSV then
            p.RefreshFromSV()
        end
    end)
    gateBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        if p.RefreshFromSV then
            p.RefreshFromSV()
        end
    end)
    gateBox:SetScript("OnEditFocusLost", function()
        ApplyGateFromBox()
        if p.RefreshFromSV then
            p.RefreshFromSV()
        end
    end)
    gateBox:SetScript("OnEnter", function(self)
        if GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Chromie Show Gate")
            GameTooltip:AddLine("Only show Chromie status/frame when your level is <= this value.", 1, 1, 1, true)
            GameTooltip:AddLine("Default: 79", 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    gateBox:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    sizeSlider:SetScript("OnValueChanged", function(_, v)
        InitSV()
        AutoGossip_UI.chromieFrameStyle = AutoGossip_UI.chromieFrameStyle or {}
        AutoGossip_UI.chromieFrameStyle.textSize = math.floor((tonumber(v) or 12) + 0.5)
        ApplyChromieIndicatorStyle()
        if p.RefreshFromSV then
            p.RefreshFromSV()
        end
    end)

    bgSlider:SetScript("OnValueChanged", function(_, v)
        InitSV()
        AutoGossip_UI.chromieFrameStyle = AutoGossip_UI.chromieFrameStyle or {}
        AutoGossip_UI.chromieFrameStyle.bgAlpha = (tonumber(v) or 55) / 100
        ApplyChromieIndicatorStyle()
        if p.RefreshFromSV then
            p.RefreshFromSV()
        end
    end)

    borderSlider:SetScript("OnValueChanged", function(_, v)
        InitSV()
        AutoGossip_UI.chromieFrameStyle = AutoGossip_UI.chromieFrameStyle or {}
        AutoGossip_UI.chromieFrameStyle.borderAlpha = (tonumber(v) or 55) / 100
        ApplyChromieIndicatorStyle()
        if p.RefreshFromSV then
            p.RefreshFromSV()
        end
    end)

    textAlphaSlider:SetScript("OnValueChanged", function(_, v)
        InitSV()
        AutoGossip_UI.chromieFrameStyle = AutoGossip_UI.chromieFrameStyle or {}
        AutoGossip_UI.chromieFrameStyle.textAlpha = (tonumber(v) or 100) / 100
        ApplyChromieIndicatorStyle()
        if p.RefreshFromSV then
            p.RefreshFromSV()
        end
    end)

    colorBtn:SetScript("OnClick", function()
        InitSV()
        local style = GetChromieFrameStyle()
        local r = tonumber(style.textColor[1]) or 1
        local g = tonumber(style.textColor[2]) or 1
        local b = tonumber(style.textColor[3]) or 1

        if not ColorPickerFrame then
            return
        end

        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame.previousValues = { r = r, g = g, b = b }
        rawset(ColorPickerFrame, "func", function()
            local nr, ng, nb = ColorPickerFrame:GetColorRGB()
            InitSV()
            AutoGossip_UI.chromieFrameStyle = AutoGossip_UI.chromieFrameStyle or {}
            AutoGossip_UI.chromieFrameStyle.textColor = { nr, ng, nb }
            ApplyChromieIndicatorStyle()
            if p.RefreshFromSV then
                p.RefreshFromSV()
            end
        end)
        rawset(ColorPickerFrame, "cancelFunc", function(prev)
            local pr = (prev and prev.r) or r
            local pg = (prev and prev.g) or g
            local pb = (prev and prev.b) or b
            InitSV()
            AutoGossip_UI.chromieFrameStyle = AutoGossip_UI.chromieFrameStyle or {}
            AutoGossip_UI.chromieFrameStyle.textColor = { pr, pg, pb }
            ApplyChromieIndicatorStyle()
            if p.RefreshFromSV then
                p.RefreshFromSV()
            end
        end)
        ColorPickerFrame:SetColorRGB(r, g, b)
        ColorPickerFrame:Hide()
        ColorPickerFrame:Show()
    end)

    p:SetScript("OnShow", function()
        if p.RefreshFromSV then
            p.RefreshFromSV()
        end
    end)

    chromieConfigPopup = p
    return chromieConfigPopup
end

local function OpenChromieConfigPopup()
    local p = EnsureChromieConfigPopup()
    if not p then
        return
    end

    p:SetClampedToScreen(true)
    p:ClearAllPoints()

    local anchor = _G and rawget(_G, "AutoGossipOptions")
    if anchor and anchor.GetCenter and anchor.IsShown and anchor:IsShown() then
        local cx = anchor:GetCenter()
        local w = (UIParent and UIParent.GetWidth and UIParent:GetWidth()) or 0
        if type(cx) == "number" and type(w) == "number" and w > 0 then
            if cx < (w / 2) then
                -- Window is left-ish: pop to the right.
                p:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 8, 0)
            else
                -- Window is right-ish: pop to the left.
                p:SetPoint("TOPRIGHT", anchor, "TOPLEFT", -8, 0)
            end
        else
            p:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 8, 0)
        end
    else
        p:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end

    p:Show()
    p:Raise()
end

CT.SetupChromieSelectionTracking = SetupChromieSelectionTracking
CT.GetChromieTimeInfo = GetChromieTimeInfo
CT.IsChromieTimeAvailableToPlayer = function() return IsChromieTimeAvailableToPlayer() end
CT.TryDisableChromieTime = TryDisableChromieTime
CT.GetChromieTimeDisplayText = GetChromieTimeDisplayText
CT.EnsureChromieIndicator = function() return EnsureChromieIndicator() end
CT.UpdateChromieIndicator = function() return UpdateChromieIndicator() end
CT.ForceHideChromieIndicator = function() return ForceHideChromieIndicator() end
CT.OpenChromieConfigPopup = OpenChromieConfigPopup
CT.GetChromieConfigPopupFrame = function() return chromieConfigPopup or (_G and rawget(_G, "FGO_ChromieConfigPopup")) end
