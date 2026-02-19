local addonName, ns = ...
ns = ns or {}

local lastSelectAt = 0
local frame = CreateFrame("Frame")

local queueOverlayButton = nil
local queueOverlayHint = nil
local queueOverlayPendingHide = false
local queueOverlayWatchdogElapsed = 0
local queueOverlaySuppressUntil = 0
local queueOverlayProposalToken = 0
local queueOverlayDismissedToken = 0

local HideQueueOverlay

local function SuppressQueueOverlay(seconds)
    local now = (GetTime and GetTime()) or 0
    local untilTime = now + (seconds or 0)
    if untilTime > (queueOverlaySuppressUntil or 0) then
        queueOverlaySuppressUntil = untilTime
    end
    HideQueueOverlay()
end

local function DismissQueueOverlayForCurrentProposal()
    -- Dismiss until the current proposal ends (or a new one starts).
    if (queueOverlayProposalToken or 0) > 0 then
        queueOverlayDismissedToken = queueOverlayProposalToken
    end
    HideQueueOverlay()
end

local function Print(msg)
    print("|cff00ccff[FGO]|r " .. tostring(msg))
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

local CHROMIE_TIME_LEVEL_BUFFER = 11

local InitSV

-- Forward declarations (used by Chromie selection hooks).
local IsChromieTimeAvailableToPlayer
local UpdateChromieIndicator
local EnsureChromieIndicator
local chromieIndicator

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

    local s = rawName:lower()
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
            local s = nm:lower()
            if s:find("present", 1, true) or s:find("current", 1, true) or s:find("return", 1, true) then
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
            if isEnabled == false then
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

SLASH_FGOCHROMIE1 = "/fgochromie"
SlashCmdList.FGOCHROMIE = function()
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

local function GetExpansionMaxLevel()
    local maxLevel = nil
    if GetMaxLevelForPlayerExpansion then
        maxLevel = SafeCall(GetMaxLevelForPlayerExpansion)
    end
    if type(maxLevel) ~= "number" and GetMaxPlayerLevel then
        maxLevel = SafeCall(GetMaxPlayerLevel)
    end
    if type(maxLevel) ~= "number" then
        maxLevel = rawget(_G, "MAX_PLAYER_LEVEL")
    end
    if type(maxLevel) ~= "number" then
        return nil
    end
    return maxLevel
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

-- chromieIndicator is forward-declared at the top.

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

local function ForceHideChromieIndicator()
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

local function NormalizeID(value)
    if type(value) == "string" then
        local n = tonumber(value)
        if n then
            return n
        end
    end
    return value
end

local function MigrateDisabledFlatToNested(disabled)
    if type(disabled) ~= "table" then
        return {}
    end

    local sawLegacy = false
    for k, v in pairs(disabled) do
        if type(v) == "table" then
            -- Already nested.
            return disabled
        end
        if v and type(k) == "string" and k:find(":", 1, true) then
            sawLegacy = true
        end
    end
    if not sawLegacy then
        return disabled
    end

    local nested = {}
    for k, v in pairs(disabled) do
        if v and type(k) == "string" then
            local npc, opt = k:match("^(%d+):(%d+)$")
            if npc and opt then
                local npcID = tonumber(npc)
                local optID = tonumber(opt)
                if npcID and optID then
                    nested[npcID] = nested[npcID] or {}
                    nested[npcID][optID] = true
                end
            end
        end
    end
    return nested
end

InitSV = function()
    -- SavedVariables rename (2026): AutoGossip_* => AutoGame_*
    -- If the old tables exist from a previous install, reuse them so settings migrate automatically.
    AutoGame_Acc = AutoGame_Acc or AutoGossip_Acc or {}
    AutoGame_Char = AutoGame_Char or AutoGossip_Char or {}
    AutoGame_Settings = AutoGame_Settings or AutoGossip_Settings or { disabled = {}, disabledDB = {}, tutorialOffAcc = false, hideTooltipBorderAcc = true }
    AutoGame_CharSettings = AutoGame_CharSettings or AutoGossip_CharSettings or { disabled = {} }
    AutoGame_UI = AutoGame_UI or AutoGossip_UI or {}

    -- Backward-compatible aliases so existing modules (and older saved snippets) keep working.
    AutoGossip_Acc = AutoGame_Acc
    AutoGossip_Char = AutoGame_Char
    AutoGossip_Settings = AutoGame_Settings
    AutoGossip_CharSettings = AutoGame_CharSettings
    AutoGossip_UI = AutoGame_UI

    if type(AutoGossip_UI.printOnShow) ~= "boolean" then
        AutoGossip_UI.printOnShow = false
    end

    if type(AutoGossip_UI.chromieFrameEnabled) ~= "boolean" then
        AutoGossip_UI.chromieFrameEnabled = true
    end

    if type(AutoGossip_UI.chromieFramePos) ~= "table" then
        AutoGossip_UI.chromieFramePos = { point = "TOP", relativePoint = "TOP", x = 0, y = -160 }
    end

    if type(AutoGossip_UI.chromieFrameStyle) ~= "table" then
        AutoGossip_UI.chromieFrameStyle = {
            fontKey = "default",
            textSize = 12,
            textColor = { 1, 1, 1 },
            bgAlpha = 0.55,
            borderAlpha = 0.55,
            textAlpha = 1,
        }
    end

    if type(AutoGossip_UI.chromieGateLevel) ~= "number" then
        AutoGossip_UI.chromieGateLevel = 79
    end

    -- Chromie frame lock is per-character.
    if type(AutoGossip_CharSettings.chromieFrameLocked) ~= "boolean" then
        -- Migrate legacy account-wide lock if present.
        if type(AutoGossip_UI.chromieFrameLocked) == "boolean" then
            AutoGossip_CharSettings.chromieFrameLocked = AutoGossip_UI.chromieFrameLocked and true or false
        else
            AutoGossip_CharSettings.chromieFrameLocked = false
        end
    end

    if type(AutoGossip_Settings.disabled) ~= "table" then
        AutoGossip_Settings.disabled = {}
    end
    if type(AutoGossip_Settings.disabledDB) ~= "table" then
        AutoGossip_Settings.disabledDB = {}
    end

    -- Tutorials: migrate from legacy tutorialOffAcc => tutorialEnabledAcc.
    if type(AutoGossip_Settings.tutorialEnabledAcc) ~= "boolean" then
        if type(AutoGossip_Settings.tutorialOffAcc) == "boolean" then
            AutoGossip_Settings.tutorialEnabledAcc = (not AutoGossip_Settings.tutorialOffAcc)
        else
            AutoGossip_Settings.tutorialEnabledAcc = true
        end
    end
    -- Keep legacy key in sync for any older modules.
    if type(AutoGossip_Settings.tutorialOffAcc) ~= "boolean" then
        AutoGossip_Settings.tutorialOffAcc = (not AutoGossip_Settings.tutorialEnabledAcc)
    end

    if type(AutoGossip_Settings.hideTooltipBorderAcc) ~= "boolean" then
        -- Hide tooltip borders ON (default).
        AutoGossip_Settings.hideTooltipBorderAcc = true
    end

    -- TooltipX: combat hide + lightweight cleanup (safe, no async quest loads).
    if type(AutoGossip_Settings.tooltipXEnabledAcc) ~= "boolean" then
        -- Default OFF so it doesn't interfere after install.
        AutoGossip_Settings.tooltipXEnabledAcc = false
    end
    if type(AutoGossip_Settings.tooltipXCombatHideAcc) ~= "boolean" then
        AutoGossip_Settings.tooltipXCombatHideAcc = false
    end
    if type(AutoGossip_Settings.tooltipXCombatModifierAcc) ~= "string" then
        AutoGossip_Settings.tooltipXCombatModifierAcc = "CTRL"
    end
    if type(AutoGossip_Settings.tooltipXCombatShowTargetAcc) ~= "boolean" then
        AutoGossip_Settings.tooltipXCombatShowTargetAcc = true
    end
    if type(AutoGossip_Settings.tooltipXCombatShowFocusAcc) ~= "boolean" then
        AutoGossip_Settings.tooltipXCombatShowFocusAcc = false
    end
    if type(AutoGossip_Settings.tooltipXCombatShowMouseoverAcc) ~= "boolean" then
        AutoGossip_Settings.tooltipXCombatShowMouseoverAcc = true
    end
    if type(AutoGossip_Settings.tooltipXCombatShowFriendlyPlayersAcc) ~= "boolean" then
        AutoGossip_Settings.tooltipXCombatShowFriendlyPlayersAcc = false
    end
    if type(AutoGossip_Settings.tooltipXCleanupAcc) ~= "boolean" then
        AutoGossip_Settings.tooltipXCleanupAcc = false
    end
    if type(AutoGossip_Settings.tooltipXCleanupCombatOnlyAcc) ~= "boolean" then
        AutoGossip_Settings.tooltipXCleanupCombatOnlyAcc = true
    end
    if type(AutoGossip_Settings.tooltipXCleanupModeAcc) ~= "string" then
        AutoGossip_Settings.tooltipXCleanupModeAcc = "strict"
    end
    if type(AutoGossip_Settings.tooltipXDebugAcc) ~= "boolean" then
        AutoGossip_Settings.tooltipXDebugAcc = false
    end

    -- Situate (existing macros/spells -> action slots).
    if type(AutoGossip_Settings.actionBarEnabledAcc) ~= "boolean" then
        -- Default OFF so it can't surprise-move buttons after install.
        AutoGossip_Settings.actionBarEnabledAcc = false
    end
    if type(AutoGossip_Settings.actionBarDebugAcc) ~= "boolean" then
        AutoGossip_Settings.actionBarDebugAcc = false
    end
    if type(AutoGossip_Settings.actionBarOverwriteAcc) ~= "boolean" then
        -- Default OFF: only place into empty slots or matching macro slots.
        AutoGossip_Settings.actionBarOverwriteAcc = false
    end
    if type(AutoGossip_Settings.actionBarMainAcc) ~= "boolean" then
        -- Default OFF: treat this WoW account as a non-main profile.
        AutoGossip_Settings.actionBarMainAcc = false
    end

    -- Optional per-spec layouts (keyed by specID). Legacy global layout remains in actionBarLayoutAcc.
    if type(AutoGossip_Settings.actionBarLayoutBySpecAcc) ~= "table" then
        AutoGossip_Settings.actionBarLayoutBySpecAcc = {}
    end
    if type(AutoGossip_Settings.actionBarLayoutAcc) ~= "table" then
        AutoGossip_Settings.actionBarLayoutAcc = {}
    end
    -- Keep layout as an array.
    if AutoGossip_Settings.actionBarLayoutAcc[1] == nil and next(AutoGossip_Settings.actionBarLayoutAcc) ~= nil then
        AutoGossip_Settings.actionBarLayoutAcc = {}
    end
    if type(AutoGossip_Settings.debugAcc) ~= "boolean" then
        AutoGossip_Settings.debugAcc = false
    end
    if type(AutoGossip_Settings.debugPetPopupsAcc) ~= "boolean" then
        AutoGossip_Settings.debugPetPopupsAcc = false
    end

    -- Macro / commands (/fgo m <command>)
    if type(AutoGossip_Settings.macroCmdsAcc) ~= "table" then
        AutoGossip_Settings.macroCmdsAcc = {}
    end
    -- Keep macroCmds as an array.
    if AutoGossip_Settings.macroCmdsAcc[1] == nil and next(AutoGossip_Settings.macroCmdsAcc) ~= nil then
        AutoGossip_Settings.macroCmdsAcc = {}
    end

    -- Seed built-in Macro CMD defaults (idempotent; does not overwrite user edits).
    do
        local function NormKey(s)
            s = tostring(s or "")
            s = s:gsub("^%s+", ""):gsub("%s+$", "")
            return s:lower()
        end

        -- One-time migration: rename legacy c-mode keys to d-mode keys without the leading 'c'.
        -- This avoids ending up with both old and new names after DB updates.
        do
            local rename = {
                cloot = "loot",
                cscript = "script",
                cmouse = "mouse",
                ctrade = "trade",
                cfriend = "friend",
                cbars = "bars",
                cbagrev = "bagrev",
                ctoken = "token",
                csetup = "setup",
                cfish = "fish",
            }

            local existing = {}
            for i, c in ipairs(AutoGossip_Settings.macroCmdsAcc) do
                if type(c) == "table" and type(c.key) == "string" then
                    existing[NormKey(c.key)] = i
                end
            end

            for oldKey, newKey in pairs(rename) do
                local oldIdx = existing[oldKey]
                local newIdx = existing[newKey]
                if oldIdx and not newIdx then
                    local entry = AutoGossip_Settings.macroCmdsAcc[oldIdx]
                    if type(entry) == "table" then
                        entry.key = newKey
                        entry.mode = "d"
                    end
                end
            end
        end

        local function HasCmdKey(key)
            key = NormKey(key)
            if key == "" then
                return true
            end
            for _, c in ipairs(AutoGossip_Settings.macroCmdsAcc) do
                if type(c) == "table" and type(c.key) == "string" and NormKey(c.key) == key then
                    return true
                end
            end
            return false
        end

        local function EnsureDefaultMainsAcc()
            if type(AutoGossip_Settings) ~= "table" then
                return {}
            end
            if type(AutoGossip_Settings.macroCmdMainsDefaultAcc) ~= "table" then
                AutoGossip_Settings.macroCmdMainsDefaultAcc = {}
            end
            if AutoGossip_Settings.macroCmdMainsDefaultAcc[1] == nil and next(AutoGossip_Settings.macroCmdMainsDefaultAcc) ~= nil then
                AutoGossip_Settings.macroCmdMainsDefaultAcc = {}
            end
            return AutoGossip_Settings.macroCmdMainsDefaultAcc
        end

        -- Fix a common macro bug pattern in older seeds: if a macro dismounts first and
        -- only later does `/stopmacro [flying]`, you can dismount mid-air.
        local function FixStopmacroBeforeDismount(text)
            if type(text) ~= "string" or text == "" then
                return text, false
            end
            local norm = text:gsub("\r\n", "\n"):gsub("\r", "\n")
            local lines = {}
            for line in norm:gmatch("([^\n]*)\n?") do
                if line == "" and #lines > 0 and lines[#lines] == "" then
                    break
                end
                lines[#lines + 1] = line
            end

            local disIdx, stopIdx = nil, nil
            for i = 1, #lines do
                local l = (lines[i] or ""):gsub("^%s+", ""):gsub("%s+$", "")
                if not disIdx and l:match("^/dismount%s*%[.*noflying.*%]") then
                    disIdx = i
                end
                if not stopIdx and l == "/stopmacro [flying]" then
                    stopIdx = i
                end
            end

            if not (disIdx and stopIdx and stopIdx > disIdx) then
                return text, false
            end

            local stopLine = lines[stopIdx]
            table.remove(lines, stopIdx)
            table.insert(lines, disIdx, stopLine)
            return table.concat(lines, "\n"), true
        end

        do
            local cmds = AutoGossip_Settings.macroCmdsAcc
            for _, c in ipairs(cmds) do
                if type(c) == "table" then
                    local fixed, changed = FixStopmacroBeforeDismount(c.otherText)
                    if changed then
                        c.otherText = fixed
                    end
                end
            end
        end

        local db = ns and ns.MacroXCMD_DB
        if type(db) == "table" then
            for _, e in ipairs(db) do
                if type(e) == "table" then
                    local key = tostring(e.key or "")
                    local keyTrim = key:gsub("^%s+", ""):gsub("%s+$", "")
                    local mode = tostring(e.mode or "d")

                    -- If the user has no shared Characters list yet, allow the DB to provide an initial default.
                    if mode == "x" and type(e.mains) == "table" then
                        local defaultMains = EnsureDefaultMainsAcc()
                        if defaultMains[1] == nil and #e.mains > 0 then
                            for i = 1, #e.mains do
                                defaultMains[i] = tostring(e.mains[i] or "")
                            end
                        end
                    end

                    if keyTrim ~= "" and not HasCmdKey(keyTrim) then
                        local out = {
                            mode = mode,
                            key = keyTrim,
                            mains = {},
                            mainText = "",
                            otherText = "",
                        }

                        if mode == "x" then
                            if type(e.mains) == "table" then
                                for i = 1, #e.mains do
                                    local v = e.mains[i]
                                    if v ~= nil then
                                        out.mains[#out.mains + 1] = tostring(v)
                                    end
                                end
                            end
                            out.mainText = tostring(e.mainText or "")
                            out.otherText = tostring(e.otherText or "")
                        else
                            out.otherText = tostring(e.text or e.otherText or "")
                        end

                        AutoGossip_Settings.macroCmdsAcc[#AutoGossip_Settings.macroCmdsAcc + 1] = out
                    end
                end
            end
        else
            -- Safety fallback if DB file didn't load.
            if not HasCmdKey("logout") then
                AutoGossip_Settings.macroCmdsAcc[#AutoGossip_Settings.macroCmdsAcc + 1] = {
                    mode = "d",
                    key = "logout",
                    mains = {},
                    mainText = "",
                    otherText = [[/console Sound_MasterVolume 0.5
/console Sound_EnableMusic 1
/zygor hide
/cancelaura safari hat
/dejunk destroy
/stopmacro [flying]
/dugi automountoff
/dismount
/logout]],
                }
            end
        end
    end
    if type(AutoGossip_Settings.autoAcceptPetPrepareAcc) ~= "boolean" then
        -- Default ON: used for pet battle confirmation popup (e.g. "Prepare yourself!", "Let's rumble!").
        AutoGossip_Settings.autoAcceptPetPrepareAcc = true
    end

    -- Queue accept overlay: 3-state UX via two SVs.
    -- - Acc On: queueAcceptAcc=true,  queueAcceptMode="acc"
    -- - On:     queueAcceptAcc=false, queueAcceptMode="on"
    -- - Off:    queueAcceptAcc=false, queueAcceptMode="acc" (inherit)
    if type(AutoGossip_Settings.queueAcceptAcc) ~= "boolean" then
        AutoGossip_Settings.queueAcceptAcc = true
    end
    if type(AutoGossip_CharSettings.queueAcceptMode) ~= "string" then
        AutoGossip_CharSettings.queueAcceptMode = "acc"
    end
    if AutoGossip_CharSettings.queueAcceptMode ~= "acc" and AutoGossip_CharSettings.queueAcceptMode ~= "on" then
        AutoGossip_CharSettings.queueAcceptMode = "acc"
    end
    if type(AutoGossip_CharSettings.disabled) ~= "table" then
        AutoGossip_CharSettings.disabled = {}
    end
    if type(AutoGossip_CharSettings.disabledAcc) ~= "table" then
        AutoGossip_CharSettings.disabledAcc = {}
    end
    if type(AutoGossip_CharSettings.disabledDB) ~= "table" then
        AutoGossip_CharSettings.disabledDB = {}
    end

    -- Migrate legacy flat keys ("npcID:optionID") => nested disabled[npcID][optionID].
    AutoGossip_Settings.disabled = MigrateDisabledFlatToNested(AutoGossip_Settings.disabled)
    AutoGossip_Settings.disabledDB = MigrateDisabledFlatToNested(AutoGossip_Settings.disabledDB)
    AutoGossip_CharSettings.disabled = MigrateDisabledFlatToNested(AutoGossip_CharSettings.disabled)
    AutoGossip_CharSettings.disabledAcc = MigrateDisabledFlatToNested(AutoGossip_CharSettings.disabledAcc)
    AutoGossip_CharSettings.disabledDB = MigrateDisabledFlatToNested(AutoGossip_CharSettings.disabledDB)

    -- Migrate user rule tables to match DB pack layout (per-NPC __meta + minimal per-option entries).
    local function MigrateRulesDb(db)
        if type(db) ~= "table" then
            return
        end
        for _, npcTable in pairs(db) do
            if type(npcTable) == "table" then
                local meta = npcTable.__meta
                if type(meta) ~= "table" then
                    meta = {}
                    npcTable.__meta = meta
                end

                -- Promote any per-rule zone/npc fields into __meta (first non-empty wins).
                if not meta.zone or meta.zone == "" or not meta.npc or meta.npc == "" then
                    for optionID, data in pairs(npcTable) do
                        if optionID ~= "__meta" and type(data) == "table" then
                            if (not meta.zone or meta.zone == "") then
                                meta.zone = data.zoneName or data.zone or meta.zone
                            end
                            if (not meta.npc or meta.npc == "") then
                                meta.npc = data.npcName or data.npc or meta.npc
                            end
                        end
                    end
                end

                -- Strip redundant per-rule fields to keep entries compact.
                for optionID, data in pairs(npcTable) do
                    if optionID ~= "__meta" and type(data) == "table" then
                        data.zoneName = nil
                        data.zone = nil
                        data.npcName = nil
                        data.npc = nil
                    end
                end
            end
        end
    end

    MigrateRulesDb(AutoGossip_Acc)
    MigrateRulesDb(AutoGossip_Char)
end

-- Expose a couple of internals so helper modules (e.g. TalkXPOP) can share SV init + printing.
ns._InitSV = InitSV
ns._Print = Print

-- Popup handling moved to fr0z3nUI_GameOptionsTalkXPOP.lua

local function GetQueueAcceptState()
    InitSV()
    if AutoGossip_Settings and AutoGossip_Settings.queueAcceptAcc then
        return "acc"
    end
    if AutoGossip_CharSettings and AutoGossip_CharSettings.queueAcceptMode == "on" then
        return "char"
    end
    return "off"
end

local function SetQueueAcceptState(state)
    InitSV()
    if state == "acc" then
        AutoGossip_Settings.queueAcceptAcc = true
        AutoGossip_CharSettings.queueAcceptMode = "acc"
        return
    end
    if state == "char" then
        AutoGossip_Settings.queueAcceptAcc = false
        AutoGossip_CharSettings.queueAcceptMode = "on"
        return
    end
    AutoGossip_Settings.queueAcceptAcc = false
    AutoGossip_CharSettings.queueAcceptMode = "acc"
end

local function IsQueueAcceptEnabled()
    return GetQueueAcceptState() ~= "off"
end

local function HasActiveLfgProposal()
    if type(GetLFGProposal) == "function" then
        local proposalExists = GetLFGProposal()
        return proposalExists and true or false
    end

    local dialog = _G and _G["LFGDungeonReadyDialog"]
    if dialog and dialog.IsShown and dialog:IsShown() then
        return true
    end
    local popup = _G and _G["LFGDungeonReadyPopup"]
    if popup and popup.IsShown and popup:IsShown() then
        return true
    end
    return false
end

local function FindLfgAcceptButton()
    local candidates = {
        _G and _G["LFGDungeonReadyDialogEnterDungeonButton"],
        _G and _G["LFGDungeonReadyDialogAcceptButton"],
        _G and _G["LFGDungeonReadyPopupAcceptButton"],
        _G and _G["LFGDungeonReadyPopupEnterDungeonButton"],
    }

    for _, btn in ipairs(candidates) do
        if btn and btn.IsShown and btn:IsShown() and btn.IsEnabled and btn:IsEnabled() then
            return btn
        end
    end
    return nil
end

local function EnsureQueueOverlay()
    if queueOverlayButton then
        return queueOverlayButton
    end

    local b = CreateFrame("Button", "AutoGossipQueueAcceptOverlay", UIParent, "SecureActionButtonTemplate")
    queueOverlayButton = b

    b:SetAllPoints(UIParent)
    b:SetFrameStrata("BACKGROUND")
    b:SetFrameLevel(1)
    b:EnableMouse(true)
    b:RegisterForClicks("AnyUp")

    -- Configure secure attributes once to avoid tainting Blizzard action buttons.
    -- Using a macro here means we don't need to call :SetAttribute() again at runtime.
    b:SetAttribute("type1", "macro")
    b:SetAttribute("macrotext", table.concat({
        "/click LFGDungeonReadyDialogEnterDungeonButton",
        "/click LFGDungeonReadyDialogAcceptButton",
        "/click LFGDungeonReadyPopupAcceptButton",
        "/click LFGDungeonReadyPopupEnterDungeonButton",
    }, "\n"))

    -- PostClick runs after the secure macro has executed.
    -- - Left click: accept, then dismiss overlay for this proposal.
    -- - Right click: dismiss overlay for this proposal.
    b:SetScript("PostClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            DismissQueueOverlayForCurrentProposal()
            return
        end

        -- After accepting, keep hidden until this invite ends.
        DismissQueueOverlayForCurrentProposal()
    end)

    b:SetScript("OnUpdate", function(self, elapsed)
        if not (self and self.IsShown and self:IsShown()) then
            return
        end

        queueOverlayWatchdogElapsed = (queueOverlayWatchdogElapsed or 0) + (elapsed or 0)
        if queueOverlayWatchdogElapsed < 0.20 then
            return
        end
        queueOverlayWatchdogElapsed = 0

        if not IsQueueAcceptEnabled() then
            HideQueueOverlay()
            return
        end
        if not HasActiveLfgProposal() then
            HideQueueOverlay()
            return
        end

        local acceptButton = FindLfgAcceptButton()
        if not acceptButton then
            HideQueueOverlay()
            return
        end
    end)
    b:Hide()

    local hint = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    queueOverlayHint = hint
    hint:SetAllPoints(UIParent)
    hint:SetFrameStrata("FULLSCREEN_DIALOG")
    hint:EnableMouse(false)

    hint:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    hint:SetBackdropColor(0, 0, 0, 0.35)
    hint:SetBackdropBorderColor(1, 0.82, 0, 0.95)

    local fs = hint:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOP", UIParent, "TOP", 0, -140)
    fs:SetText("|cff00ccff[FGO]|r Queue ready — left click the world to accept (right click to dismiss)")
    hint.text = fs

    do
        local ag = hint:CreateAnimationGroup()
        ag:SetLooping("BOUNCE")

        local a1 = ag:CreateAnimation("Alpha")
        a1:SetFromAlpha(0.15)
        a1:SetToAlpha(1.0)
        a1:SetDuration(0.35)
        a1:SetSmoothing("OUT")

        local a2 = ag:CreateAnimation("Alpha")
        a2:SetFromAlpha(1.0)
        a2:SetToAlpha(0.15)
        a2:SetDuration(0.35)
        a2:SetSmoothing("IN")
        a2:SetOrder(2)

        hint.flash = ag
    end

    hint:Hide()

    return b
end

HideQueueOverlay = function()
    if not (queueOverlayButton and queueOverlayButton.IsShown and queueOverlayButton:IsShown()) then
        queueOverlayPendingHide = false
        if queueOverlayHint and queueOverlayHint.Hide then
            queueOverlayHint:Hide()
        end
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        queueOverlayPendingHide = true
        return
    end

    queueOverlayButton:Hide()
    if queueOverlayHint and queueOverlayHint.flash and queueOverlayHint.flash.IsPlaying and queueOverlayHint.flash:IsPlaying() then
        queueOverlayHint.flash:Stop()
    end
    if queueOverlayHint and queueOverlayHint.Hide then
        queueOverlayHint:Hide()
    end
    queueOverlayPendingHide = false
end

local function ShowQueueOverlayIfNeeded()
    local now = (GetTime and GetTime()) or 0
    if (queueOverlaySuppressUntil or 0) > now then
        return
    end

    if (queueOverlayProposalToken or 0) > 0 and (queueOverlayDismissedToken or 0) == (queueOverlayProposalToken or 0) then
        return
    end

    if not IsQueueAcceptEnabled() then
        HideQueueOverlay()
        return
    end
    if not HasActiveLfgProposal() then
        HideQueueOverlay()
        queueOverlayProposalToken = 0
        queueOverlayDismissedToken = 0
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        return
    end

    local acceptButton = FindLfgAcceptButton()
    if not acceptButton then
        HideQueueOverlay()
        return
    end

    local overlay = EnsureQueueOverlay()
    overlay:Show()
    if queueOverlayHint and queueOverlayHint.Show then
        queueOverlayHint:Show()
        if queueOverlayHint.flash and queueOverlayHint.flash.Play then
            queueOverlayHint.flash:Play()
        end
    end
end

local function GetNpcIDFromGuid(guid)
    if type(guid) ~= "string" then
        return nil
    end
    local _, _, _, _, _, npcID = strsplit("-", guid)
    return tonumber(npcID)
end

local function GetCurrentNpcID()
    local guid = UnitGUID("npc") or UnitGUID("target")
    local npcID = GetNpcIDFromGuid(guid)
    if npcID then
        return npcID
    end

    -- Fallback: some gossip-like interactions (objects / journals) don't have an "npc" unit.
    if C_PlayerInteractionManager and C_PlayerInteractionManager.GetInteractionTarget then
        local targetGuid = C_PlayerInteractionManager.GetInteractionTarget()
        npcID = GetNpcIDFromGuid(targetGuid)
        if npcID then
            return npcID
        end
    end
    return nil
end

local function GetCurrentNpcName()
    return UnitName("npc") or UnitName("target")
end

local function GetCurrentZoneName()
    if C_Map and C_Map.GetBestMapForUnit and C_Map.GetMapInfo then
        local mapID = C_Map.GetBestMapForUnit("player")
        if mapID then
            local info = C_Map.GetMapInfo(mapID)
            if info then
                -- In delves/scenarios/dungeons, the "best map" can be the instance map.
                -- Walk up the parent chain and prefer the first Zone-level map name.
                if Enum and Enum.UIMapType and info.mapType ~= Enum.UIMapType.Zone and info.parentMapID and info.parentMapID ~= 0 then
                    local cur = mapID
                    local maxHops = 25
                    while cur and maxHops > 0 do
                        maxHops = maxHops - 1
                        local i = C_Map.GetMapInfo(cur)
                        if not i then
                            break
                        end
                        if i.mapType == Enum.UIMapType.Zone and type(i.name) == "string" and i.name ~= "" then
                            return i.name
                        end
                        if not i.parentMapID or i.parentMapID == 0 then
                            break
                        end
                        cur = i.parentMapID
                    end
                end

                if type(info.name) == "string" and info.name ~= "" then
                    return info.name
                end
            end
        end
    end
    if GetRealZoneText then
        local z = GetRealZoneText()
        if type(z) == "string" and z ~= "" then
            return z
        end
    end
    return ""
end

local function GetCurrentContinentName()
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetMapInfo) then
        return ""
    end

    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then
        return ""
    end

    local maxHops = 25
    while mapID and maxHops > 0 do
        maxHops = maxHops - 1
        local info = C_Map.GetMapInfo(mapID)
        if not info then
            break
        end
        if Enum and Enum.UIMapType and info.mapType == Enum.UIMapType.Continent then
            if type(info.name) == "string" and info.name ~= "" then
                return info.name
            end
            break
        end
        if not info.parentMapID or info.parentMapID == 0 then
            break
        end
        mapID = info.parentMapID
    end
    return ""
end

local function MakeRuleKey(npcID, optionID)
    return tostring(npcID) .. ":" .. tostring(optionID)
end

local function IsDisabled(scope, npcID, optionID)
    npcID = NormalizeID(npcID)
    optionID = NormalizeID(optionID)

    if scope == "acc" then
        local t = AutoGossip_Settings.disabled
        local npcTable = t and t[npcID]
        if type(npcTable) == "table" and npcTable[optionID] then
            return true
        end
        -- Backward-compat read for older saves/versions.
        return (t and t[MakeRuleKey(npcID, optionID)]) and true or false
    end

    local t = AutoGossip_CharSettings.disabled
    local npcTable = t and t[npcID]
    if type(npcTable) == "table" and npcTable[optionID] then
        return true
    end
    return (t and t[MakeRuleKey(npcID, optionID)]) and true or false
end

-- Per-character override for Account-scoped rules.
-- (When an Account rule exists, the Character button represents "disabled on this character".)
local function IsDisabledAccOnChar(npcID, optionID)
    npcID = NormalizeID(npcID)
    optionID = NormalizeID(optionID)

    local t = AutoGossip_CharSettings and AutoGossip_CharSettings.disabledAcc
    local npcTable = t and t[npcID]
    if type(npcTable) == "table" and npcTable[optionID] then
        return true
    end
    return (t and t[MakeRuleKey(npcID, optionID)]) and true or false
end

local function SetDisabledAccOnChar(npcID, optionID, disabled)
    npcID = NormalizeID(npcID)
    optionID = NormalizeID(optionID)

    AutoGossip_CharSettings.disabledAcc = AutoGossip_CharSettings.disabledAcc or {}
    local t = AutoGossip_CharSettings.disabledAcc

    local key = MakeRuleKey(npcID, optionID)
    t[key] = nil
    t[npcID] = t[npcID] or {}
    if disabled then
        t[npcID][optionID] = true
    else
        t[npcID][optionID] = nil
        if next(t[npcID]) == nil then
            t[npcID] = nil
        end
    end
end

local function SetDisabled(scope, npcID, optionID, disabled)
    npcID = NormalizeID(npcID)
    optionID = NormalizeID(optionID)

    local key = MakeRuleKey(npcID, optionID)
    if scope == "acc" then
        local t = AutoGossip_Settings.disabled
        t[key] = nil
        t[npcID] = t[npcID] or {}
        if disabled then
            t[npcID][optionID] = true
        else
            t[npcID][optionID] = nil
            if next(t[npcID]) == nil then
                t[npcID] = nil
            end
        end
    else
        local t = AutoGossip_CharSettings.disabled
        t[key] = nil
        t[npcID] = t[npcID] or {}
        if disabled then
            t[npcID][optionID] = true
        else
            t[npcID][optionID] = nil
            if next(t[npcID]) == nil then
                t[npcID] = nil
            end
        end
    end
end

local function IsDisabledDB(npcID, optionID)
    npcID = NormalizeID(npcID)
    optionID = NormalizeID(optionID)

    local t = AutoGossip_Settings.disabledDB
    local npcTable = t and t[npcID]
    if type(npcTable) == "table" and npcTable[optionID] then
        return true
    end
    return (t and t[MakeRuleKey(npcID, optionID)]) and true or false
end

local function SetDisabledDB(npcID, optionID, disabled)
    npcID = NormalizeID(npcID)
    optionID = NormalizeID(optionID)

    local key = MakeRuleKey(npcID, optionID)
    local t = AutoGossip_Settings.disabledDB
    t[key] = nil
    t[npcID] = t[npcID] or {}
    if disabled then
        t[npcID][optionID] = true
    else
        t[npcID][optionID] = nil
        if next(t[npcID]) == nil then
            t[npcID] = nil
        end
    end
end

-- Per-character disable for DB pack rules.
local function IsDisabledDBOnChar(npcID, optionID)
    npcID = NormalizeID(npcID)
    optionID = NormalizeID(optionID)

    local t = AutoGossip_CharSettings and AutoGossip_CharSettings.disabledDB
    local npcTable = t and t[npcID]
    if type(npcTable) == "table" and npcTable[optionID] then
        return true
    end
    return (t and t[MakeRuleKey(npcID, optionID)]) and true or false
end

local function SetDisabledDBOnChar(npcID, optionID, disabled)
    npcID = NormalizeID(npcID)
    optionID = NormalizeID(optionID)

    AutoGossip_CharSettings.disabledDB = AutoGossip_CharSettings.disabledDB or {}
    local t = AutoGossip_CharSettings.disabledDB

    local key = MakeRuleKey(npcID, optionID)
    t[key] = nil
    t[npcID] = t[npcID] or {}
    if disabled then
        t[npcID][optionID] = true
    else
        t[npcID][optionID] = nil
        if next(t[npcID]) == nil then
            t[npcID] = nil
        end
    end
end

local function GetDbNpcTable(npcID)
    local rules = ns and ns.db and ns.db.rules
    if type(rules) ~= "table" then
        return nil
    end
    local npcTable = rules[npcID]
    if type(npcTable) ~= "table" then
        if type(npcID) == "number" then
            npcTable = rules[tostring(npcID)]
        elseif type(npcID) == "string" then
            local n = tonumber(npcID)
            if n then
                npcTable = rules[n]
            end
        end
    end
    if type(npcTable) ~= "table" then
        return nil
    end
    return npcTable
end

local function HasDbRule(npcID, optionID)
    local npcTable = GetDbNpcTable(npcID)
    if not npcTable then
        return false
    end
    if npcTable[optionID] ~= nil then
        return true
    end
    if type(optionID) == "number" then
        return npcTable[tostring(optionID)] ~= nil
    end
    if type(optionID) == "string" then
        local n = tonumber(optionID)
        if n then
            return npcTable[n] ~= nil
        end
    end
    return false
end

local function HasRule(scope, npcID, optionID)
    local db = (scope == "acc") and AutoGossip_Acc or AutoGossip_Char
    local npcTable = db[npcID]
    if type(npcTable) ~= "table" then
        return false
    end
    if npcTable[optionID] ~= nil then
        return true
    end
    if type(optionID) == "number" then
        return npcTable[tostring(optionID)] ~= nil
    end
    if type(optionID) == "string" then
        local n = tonumber(optionID)
        if n then
            return npcTable[n] ~= nil
        end
    end
    return false
end

local function DeleteRule(scope, npcID, optionID, preserveToDb)
    if not (npcID and optionID) then
        return
    end

    preserveToDb = preserveToDb and true or false
    local hadDb = preserveToDb and HasDbRule(npcID, optionID) and true or false
    local wasDisabled = preserveToDb and IsDisabled(scope, npcID, optionID) and true or false
    local wasDisabledAccOnChar = false
    if preserveToDb and scope == "acc" then
        wasDisabledAccOnChar = IsDisabledAccOnChar(npcID, optionID) and true or false
    end

    local db = (scope == "acc") and AutoGossip_Acc or AutoGossip_Char
    local npcTable = db[npcID]
    if type(npcTable) ~= "table" then
        return
    end
    npcTable[optionID] = nil
    if type(optionID) == "number" then
        npcTable[tostring(optionID)] = nil
    elseif type(optionID) == "string" then
        local n = tonumber(optionID)
        if n then
            npcTable[n] = nil
        end
    end
    if next(npcTable) == nil then
        db[npcID] = nil
    end
    -- If the only remaining key is __meta, also remove the NPC bucket.
    if db[npcID] then
        local firstKey = next(npcTable)
        if firstKey == "__meta" and next(npcTable, firstKey) == nil then
            db[npcID] = nil
        end
    end
    SetDisabled(scope, npcID, optionID, false)
    if scope == "acc" then
        SetDisabledAccOnChar(npcID, optionID, false)
    end

    if hadDb then
        -- If a DB rule exists for this option, keep the user's A/C disable state by applying it to the DB disable tables.
        if scope == "acc" then
            SetDisabledDB(npcID, optionID, wasDisabled)
            SetDisabledDBOnChar(npcID, optionID, wasDisabledAccOnChar)
        elseif scope == "char" then
            SetDisabledDBOnChar(npcID, optionID, wasDisabled)
        end
    end
end

local function AddRule(scope, npcID, optionID, optionText, optionType)
    if not npcID or not optionID then
        return false, "Missing NPC or option ID"
    end

    local db = (scope == "acc") and AutoGossip_Acc or AutoGossip_Char
    db[npcID] = db[npcID] or {}
    local npcTable = db[npcID]
    npcTable.__meta = (type(npcTable.__meta) == "table") and npcTable.__meta or {}

    if npcTable[optionID] then
        return false, "Already exists"
    end

    local zoneName = GetCurrentZoneName()
    local continentName = GetCurrentContinentName()
    if type(zoneName) ~= "string" then
        zoneName = ""
    end
    if type(continentName) == "string" and continentName ~= "" and (not zoneName:find(continentName, 1, true)) then
        if zoneName ~= "" then
            zoneName = zoneName .. ", " .. continentName
        else
            zoneName = continentName
        end
    end

    npcTable.__meta.zone = zoneName
    npcTable.__meta.npc = GetCurrentNpcName() or ""

    npcTable[optionID] = {
        text = optionText or "",
        type = optionType or "",
        addedAt = time(),
    }

    SetDisabled(scope, npcID, optionID, false)
    if scope == "acc" then
        SetDisabledAccOnChar(npcID, optionID, false)
    end
    return true
end

local didDedupUserRulesAgainstDb = false

local function DeduplicateUserRulesAgainstDb()
    if didDedupUserRulesAgainstDb then
        return
    end
    didDedupUserRulesAgainstDb = true

    InitSV()

    -- DB packs are authored as ns.db.rules; if no DB exists, nothing to do.
    if not (ns and ns.db and type(ns.db.rules) == "table") then
        return
    end

    local function RemoveDupes(scope, db)
        if type(db) ~= "table" then
            return
        end
        local toDelete = {}
        local seen = {}
        for npcID, npcTable in pairs(db) do
            if type(npcTable) == "table" then
                local nNpcID = NormalizeID(npcID)
                for optionID in pairs(npcTable) do
                    if optionID ~= "__meta" then
                        local nOptID = NormalizeID(optionID)
                        if nNpcID and nOptID and HasDbRule(nNpcID, nOptID) then
                            local k = tostring(nNpcID) .. ":" .. tostring(nOptID)
                            if not seen[k] then
                                seen[k] = true
                                table.insert(toDelete, { npcID = nNpcID, optionID = nOptID })
                            end
                        end
                    end
                end
            end
        end

        for _, it in ipairs(toDelete) do
            DeleteRule(scope, it.npcID, it.optionID, true)
        end
    end

    -- Process Account first, then Character so per-character DB disables win.
    RemoveDupes("acc", AutoGossip_Acc)
    RemoveDupes("char", AutoGossip_Char)
end

local function FindOptionInfoByID(optionID)
    if not (C_GossipInfo and C_GossipInfo.GetOptions) then
        return nil
    end
    for _, opt in ipairs(C_GossipInfo.GetOptions()) do
        if opt and opt.gossipOptionID == optionID then
            return opt
        end
    end
    return nil
end

local function LookupRuleEntry(npcTable, optionID)
    if type(npcTable) ~= "table" or optionID == nil then
        return nil
    end

    local v = npcTable[optionID]
    if v ~= nil then
        return v
    end
    if type(optionID) == "number" then
        return npcTable[tostring(optionID)]
    end
    if type(optionID) == "string" then
        local n = tonumber(optionID)
        if n then
            return npcTable[n]
        end
    end
    return nil
end

local function LookupNpcBucket(db, npcID)
    if type(db) ~= "table" or npcID == nil then
        return nil
    end

    local npcTable = db[npcID]
    if type(npcTable) == "table" then
        return npcTable
    end
    if type(npcID) == "number" then
        npcTable = db[tostring(npcID)]
    elseif type(npcID) == "string" then
        local n = tonumber(npcID)
        if n then
            npcTable = db[n]
        end
    end
    return (type(npcTable) == "table") and npcTable or nil
end

local function TryAutoSelect()
    local debug = AutoGossip_Settings and AutoGossip_Settings.debugAcc
    local function Debug(msg)
        if debug then
            Print("Gossip: " .. tostring(msg))
        end
    end

    if IsShiftKeyDown() then
        Debug("Blocked (Shift held)")
        return
    end
    -- When the options window is open, behave like Shift is held:
    -- don't auto-select while the user is inspecting/editing rules.
    if AutoGossipOptions and AutoGossipOptions.IsShown and AutoGossipOptions:IsShown() then
        Debug("Blocked (options window open)")
        return
    end
    if InCombatLockdown() then
        Debug("Blocked (in combat)")
        return
    end
    if not (C_GossipInfo and C_GossipInfo.GetOptions and C_GossipInfo.SelectOption) then
        Debug("Blocked (missing C_GossipInfo APIs)")
        return
    end

    local npcID = GetCurrentNpcID()
    if not npcID then
        Debug("Blocked (could not resolve NPC ID)")
        return
    end

    local now = GetTime()
    if now - lastSelectAt < 0.25 then
        Debug("Blocked (debounce)")
        return
    end

    local options = C_GossipInfo.GetOptions() or {}
    if #options == 0 then
        Debug("No gossip options")
    end

    -- Prefer character rules over account rules, then DB pack.
    for _, scope in ipairs({ "char", "acc" }) do
        local db = (scope == "acc") and AutoGossip_Acc or AutoGossip_Char
        local npcTable = LookupNpcBucket(db, npcID)
        if npcTable then
            for _, opt in ipairs(options) do
                local optionID = opt and opt.gossipOptionID
                local entry = optionID and LookupRuleEntry(npcTable, optionID)
                if entry ~= nil then
                    if IsDisabled(scope, npcID, optionID) then
                        Debug("Match blocked (" .. scope .. " disabled): " .. tostring(npcID) .. ":" .. tostring(optionID))
                    elseif scope == "acc" and IsDisabledAccOnChar(npcID, optionID) then
                        Debug("Match blocked (acc disabled on this char): " .. tostring(npcID) .. ":" .. tostring(optionID))
                    else
                        lastSelectAt = now
                        Debug("Selecting (" .. scope .. "): " .. tostring(npcID) .. ":" .. tostring(optionID))
                        C_GossipInfo.SelectOption(optionID)
                        return
                    end
                end
            end
        end
    end

    local dbNpc = GetDbNpcTable(npcID)
    if dbNpc then
        for _, opt in ipairs(options) do
            local optionID = opt and opt.gossipOptionID
            local entry = optionID and LookupRuleEntry(dbNpc, optionID)
            if entry ~= nil then
                if IsDisabledDB(npcID, optionID) then
                    Debug("DB match blocked (disabled): " .. tostring(npcID) .. ":" .. tostring(optionID))
                elseif IsDisabledDBOnChar(npcID, optionID) then
                    Debug("DB match blocked (disabled on this char): " .. tostring(npcID) .. ":" .. tostring(optionID))
                else
                    lastSelectAt = now
                    Debug("Selecting (DB): " .. tostring(npcID) .. ":" .. tostring(optionID))
                    C_GossipInfo.SelectOption(optionID)
                    return
                end
            end
        end
    end

    Debug("No matching enabled rules")
end

-- UI (layout mirrored from AutoOpen's item entry panel)
local function CreateOptionsWindow()
    if AutoGossipOptions then
        return
    end
    InitSV()

    local f = CreateFrame("Frame", "AutoGameOptions", UIParent, "BackdropTemplate")
    AutoGameOptions = f
    AutoGossipOptions = f

    do
        local special = _G and _G["UISpecialFrames"]
        if type(special) == "table" then
            local name = "AutoGameOptions"
            local exists = false
            for i = 1, #special do
                if special[i] == name then
                    exists = true
                    break
                end
            end
            if not exists and table and table.insert then
                table.insert(special, name)
            end
        end
    end

    -- Wider (horizontal) layout
    local FRAME_W, FRAME_H = 760, 440
    f:SetSize(FRAME_W, FRAME_H)

    if AutoGossip_UI and AutoGossip_UI.point then
        f:SetPoint(AutoGossip_UI.point, UIParent, AutoGossip_UI.relPoint or AutoGossip_UI.point, AutoGossip_UI.x or 0, AutoGossip_UI.y or 0)
    else
        f:SetPoint("CENTER")
    end

    f:SetClampedToScreen(true)
    f:SetFrameStrata("DIALOG")
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        if self.StopMovingOrSizing then
            self:StopMovingOrSizing()
        end
        local point, _, relPoint, x, y = self:GetPoint(1)
        AutoGossip_UI.point, AutoGossip_UI.relPoint, AutoGossip_UI.x, AutoGossip_UI.y = point, relPoint, x, y
    end)

    f:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        tile = true,
        tileSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    f:SetBackdropColor(0, 0, 0, 0.85)

    local browserPanel = CreateFrame("Frame", nil, f)
    browserPanel:SetAllPoints()
    f.browserPanel = browserPanel

    local editPanel = CreateFrame("Frame", nil, f)
    editPanel:SetAllPoints()
    editPanel:Hide()
    f.editPanel = editPanel

    local togglesPanel = CreateFrame("Frame", nil, f)
    togglesPanel:SetAllPoints()
    togglesPanel:Hide()
    f.togglesPanel = togglesPanel

    local actionBarPanel = CreateFrame("Frame", nil, f)
    actionBarPanel:SetAllPoints()
    actionBarPanel:Hide()
    f.actionBarPanel = actionBarPanel

    local macroPanel = CreateFrame("Frame", nil, f)
    macroPanel:SetAllPoints()
    macroPanel:Hide()
    f.macroPanel = macroPanel

    local macrosPanel = CreateFrame("Frame", nil, f)
    macrosPanel:SetAllPoints()
    macrosPanel:Hide()
    f.macrosPanel = macrosPanel

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 12, -6)
    title:SetJustifyH("LEFT")
    title:SetText("|cff00ccff[FGO]|r")

    do
        local fontPath, fontSize, fontFlags = title:GetFont()
        if fontPath and fontSize then
            title:SetFont(fontPath, fontSize + 2, fontFlags)
        end
    end

    local tabBarBG = CreateFrame("Frame", nil, f, "BackdropTemplate")
    tabBarBG:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -4)
    tabBarBG:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    tabBarBG:SetHeight(26)
    tabBarBG:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        tile = true,
        tileSize = 16,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    tabBarBG:SetBackdropColor(0, 0, 0, 0.92)
    tabBarBG:SetFrameLevel((f.GetFrameLevel and f:GetFrameLevel() or 0) + 1)
    f._tabBarBG = tabBarBG

    -- Keep the title above the tab bar background.
    if title and title.SetParent and f._tabBarBG then
        title:SetParent(f._tabBarBG)
        title:ClearAllPoints()
        title:SetPoint("LEFT", f._tabBarBG, "LEFT", 8, 0)
    end

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)
    closeBtn:SetFrameLevel((f.GetFrameLevel and f:GetFrameLevel() or 0) + 20)
    closeBtn:SetScript("OnClick", function()
        if f and f.Hide then
            f:Hide()
        end
    end)
    f._closeBtn = closeBtn

    local chromieLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    chromieLabel:SetPoint("TOPRIGHT", closeBtn, "TOPLEFT", -6, -6)
    chromieLabel:SetJustifyH("RIGHT")
    chromieLabel:SetText("")
    f._chromieLabel = chromieLabel
    f.UpdateChromieLabel = function()
        if f._chromieLabel then
            local available = IsChromieTimeAvailableToPlayer()
            f._chromieLabel:SetShown(available and true or false)
            if available then
                f._chromieLabel:SetText(GetChromieTimeDisplayText())
            end
            if f._chromieLabel.SetTextColor then
                if available then
                    f._chromieLabel:SetTextColor(1, 1, 1)
                else
                    f._chromieLabel:SetTextColor(0.62, 0.62, 0.62)
                end
            end
        end

        InitSV()
        if (AutoGossip_UI and AutoGossip_UI.chromieFrameEnabled) and IsChromieTimeAvailableToPlayer() then
            EnsureChromieIndicator()
            UpdateChromieIndicator()
        else
            ForceHideChromieIndicator()
        end
    end

    f.UpdateChromieLabel()

    local TAB_COUNT = 6
    local TAB_OVERLAP_X = -6

    local function SizeTabToText(btn, pad, minW)
        if not (btn and btn.GetFontString and btn.SetWidth) then return end
        local fs = btn:GetFontString()
        local w = (fs and fs.GetStringWidth and fs:GetStringWidth()) or 0
        w = (tonumber(w) or 0) + (tonumber(pad) or 18)
        if minW and w < minW then w = minW end
        btn:SetWidth(w)
    end

    local function StyleTab(btn, active)
        if not (btn and btn.GetFontString) then return end
        local fs = btn:GetFontString()
        if fs and fs.SetTextColor then
            if active then
                fs:SetTextColor(1.0, 0.82, 0.0, 1)
            else
                fs:SetTextColor(0.70, 0.70, 0.70, 1)
            end
        end
    end

    local function UpdateTabZOrder(activeTab)
        local base = (f.GetFrameLevel and f:GetFrameLevel()) or 0
        base = base + 20

        -- Default layering: left tabs sit in front of right tabs.
        -- Active tab always gets the top-most frame level.
        for i = 1, TAB_COUNT do
            local t = f["tab" .. tostring(i)]
            if t and t.SetFrameLevel then
                t:SetFrameLevel(base + (TAB_COUNT - i))
            end
        end
        local a = tonumber(activeTab)
        if a and a >= 1 and a <= TAB_COUNT then
            local t = f["tab" .. tostring(a)]
            if t and t.SetFrameLevel then
                t:SetFrameLevel(base + TAB_COUNT + 5)
            end
        end
    end

    local function SelectTab(self, tabID)
        f.activeTab = tabID
        -- Tab order: 1 Macro, 2 Macro CMD, 3 Situate, 4 Switches, 5 Tale, 6 Talk
        if f.macrosPanel then f.macrosPanel:SetShown(tabID == 1) end
        if f.macroPanel then f.macroPanel:SetShown(tabID == 2) end
        if f.actionBarPanel then f.actionBarPanel:SetShown(tabID == 3) end
        if f.togglesPanel then f.togglesPanel:SetShown(tabID == 4) end
        if f.editPanel then f.editPanel:SetShown(tabID == 5) end
        if f.browserPanel then f.browserPanel:SetShown(tabID == 6) end

        if tabID == 2 and f.UpdateMacroButtons then
            f.UpdateMacroButtons()
        end
        if tabID == 3 and f.UpdateSituateButtons then
            f.UpdateSituateButtons()
        end
        if tabID == 4 and f.UpdateToggleButtons then
            f.UpdateToggleButtons()
        end

        StyleTab(f.tab1, tabID == 1)
        StyleTab(f.tab2, tabID == 2)
        StyleTab(f.tab3, tabID == 3)
        StyleTab(f.tab4, tabID == 4)
        StyleTab(f.tab5, tabID == 5)
        StyleTab(f.tab6, tabID == 6)

        UpdateTabZOrder(tabID)
    end
    f.SelectTab = SelectTab

    local tab1 = CreateFrame("Button", "$parentTab1", f, "UIPanelButtonTemplate")
    tab1:SetID(1)
    tab1:SetText("Macro")
    tab1:SetPoint("LEFT", title, "RIGHT", 10, 0)
    tab1:SetScript("OnClick", function(self) f:SelectTab(self:GetID()) end)
    tab1:SetHeight(22)
    SizeTabToText(tab1, 18, 70)
    f.tab1 = tab1

    local tab2 = CreateFrame("Button", "$parentTab2", f, "UIPanelButtonTemplate")
    tab2:SetID(2)
    tab2:SetText("Macro CMD")
    tab2:SetPoint("LEFT", tab1, "RIGHT", TAB_OVERLAP_X, 0)
    tab2:SetScript("OnClick", function(self) f:SelectTab(self:GetID()) end)
    tab2:SetHeight(22)
    SizeTabToText(tab2, 18, 70)
    f.tab2 = tab2

    local tab3 = CreateFrame("Button", "$parentTab3", f, "UIPanelButtonTemplate")
    tab3:SetID(3)
    tab3:SetText("Situate")
    tab3:SetPoint("LEFT", tab2, "RIGHT", TAB_OVERLAP_X, 0)
    tab3:SetScript("OnClick", function(self) f:SelectTab(self:GetID()) end)
    tab3:SetHeight(22)
    SizeTabToText(tab3, 18, 70)
    f.tab3 = tab3

    local tab4 = CreateFrame("Button", "$parentTab4", f, "UIPanelButtonTemplate")
    tab4:SetID(4)
    tab4:SetText("Switches")
    tab4:SetPoint("LEFT", tab3, "RIGHT", TAB_OVERLAP_X, 0)
    tab4:SetScript("OnClick", function(self) f:SelectTab(self:GetID()) end)
    tab4:SetHeight(22)
    SizeTabToText(tab4, 18, 70)
    f.tab4 = tab4

    local tab5 = CreateFrame("Button", "$parentTab5", f, "UIPanelButtonTemplate")
    tab5:SetID(5)
    tab5:SetText("Tale")
    tab5:SetPoint("LEFT", tab4, "RIGHT", TAB_OVERLAP_X, 0)
    tab5:SetScript("OnClick", function(self) f:SelectTab(self:GetID()) end)
    tab5:SetHeight(22)
    SizeTabToText(tab5, 18, 70)
    f.tab5 = tab5

    local tab6 = CreateFrame("Button", "$parentTab6", f, "UIPanelButtonTemplate")
    tab6:SetID(6)
    tab6:SetText("Talk")
    tab6:SetPoint("LEFT", tab5, "RIGHT", TAB_OVERLAP_X, 0)
    tab6:SetScript("OnClick", function(self) f:SelectTab(self:GetID()) end)
    tab6:SetHeight(22)
    SizeTabToText(tab6, 18, 70)
    f.tab6 = tab6

    -- Initialize first tab styling + z-order.
    StyleTab(tab1, true)
    StyleTab(tab2, false)
    StyleTab(tab3, false)
    StyleTab(tab4, false)
    StyleTab(tab5, false)
    StyleTab(tab6, false)
    UpdateTabZOrder(1)

    -- Clear selection when the window closes so reopening starts fresh.
    f:SetScript("OnHide", function()
        f.selectedNpcID = nil
        f.selectedNpcName = nil
        if f.edit and f.edit.SetText then
            f.edit:SetText("")
        end
        if f.edit and f.edit.ClearFocus then
            f.edit:ClearFocus()
        end
        if f._currentOptions then
            f._currentOptions = {}
        end

        local p = chromieConfigPopup or (_G and rawget(_G, "FGO_ChromieConfigPopup"))
        if p and p.Hide then
            p:Hide()
        end
    end)

    local function BumpFont(fs, delta)
        if not (fs and fs.GetFont and fs.SetFont) then
            return
        end
        local fontPath, fontSize, fontFlags = fs:GetFont()
        if fontPath and fontSize then
            fs:SetFont(fontPath, fontSize + (delta or 0), fontFlags)
        end
    end

    local function BumpFontsInFrame(root, delta)
        if not root then
            return
        end

        local seen = {}
        local function bump(obj)
            if not obj or seen[obj] then
                return
            end
            seen[obj] = true

            local objType = obj.GetObjectType and obj:GetObjectType() or nil
            if objType == "FontString" then
                BumpFont(obj, delta)
            elseif objType == "EditBox" and obj.GetFont and obj.SetFont then
                local fontPath, fontSize, fontFlags = obj:GetFont()
                if fontPath and fontSize then
                    obj:SetFont(fontPath, fontSize + (delta or 0), fontFlags)
                end
            end

            if obj.GetFontString then
                BumpFont(obj:GetFontString(), delta)
            end

            if obj.GetRegions then
                for i = 1, select("#", obj:GetRegions()) do
                    bump(select(i, obj:GetRegions()))
                end
            end
            if obj.GetChildren then
                for i = 1, select("#", obj:GetChildren()) do
                    bump(select(i, obj:GetChildren()))
                end
            end
        end

        bump(root)
    end

    local function CloseOptionsWindow()
        if f and f.Hide then
            f:Hide()
        end
    end

    local function CloseGossipWindow()
        if C_GossipInfo and C_GossipInfo.CloseGossip then
            C_GossipInfo.CloseGossip()
            return
        end
        if _G and type(_G["CloseGossip"]) == "function" then
            _G["CloseGossip"]()
            return
        end
        if GossipFrame and GossipFrame.IsShown and GossipFrame:IsShown() then
            if HideUIPanel then
                HideUIPanel(GossipFrame)
            elseif GossipFrame.Hide then
                GossipFrame:Hide()
            end
        end
    end

    local reloadBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    reloadBtn:SetSize(90, 22)
    reloadBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 12)
    reloadBtn:SetFrameLevel((f.GetFrameLevel and f:GetFrameLevel() or 0) + 10)
    reloadBtn:SetText("Reload UI")
    reloadBtn:SetScript("OnClick", function()
        local r = _G and _G["ReloadUI"]
        if r then r() end
    end)
    f._reloadBtn = reloadBtn

    local function HideFauxScrollBarAndEnableWheel(sf, rowHeight)
        if not sf then
            return
        end

        local sb = sf.ScrollBar or sf.scrollBar
        if not sb and sf.GetChildren then
            local n = select("#", sf:GetChildren())
            for i = 1, n do
                local child = select(i, sf:GetChildren())
                if child and child.GetObjectType and child:GetObjectType() == "Slider" then
                    sb = child
                    break
                end
            end
        end
        sf._fgoScrollBar = sb

        if sb then
            sb:Hide()
            sb.Show = function() end
            if sb.SetAlpha then
                sb:SetAlpha(0)
            end
            if sb.EnableMouse then
                sb:EnableMouse(false)
            end
        end

        if sf.EnableMouseWheel then
            sf:EnableMouseWheel(true)
        end
        sf:SetScript("OnMouseWheel", function(self, delta)
            local bar = self._fgoScrollBar or self.ScrollBar or self.scrollBar
            if not (bar and bar.GetValue and bar.SetValue) then
                return
            end
            local step = rowHeight or 16
            bar:SetValue((bar:GetValue() or 0) - (delta * step))
        end)
    end

    -- Tale tab content
    do
        local panel = editPanel
        if panel and ns and ns.TaleUI_Build then
            ns.TaleUI_Build(f, panel, {
                InitSV = InitSV,
                Print = Print,
                BumpFont = BumpFont,
                HideFauxScrollBarAndEnableWheel = HideFauxScrollBarAndEnableWheel,
                CloseOptionsWindow = CloseOptionsWindow,
                CloseGossipWindow = CloseGossipWindow,
                GetCurrentNpcID = GetCurrentNpcID,
                GetCurrentNpcName = GetCurrentNpcName,
                FindOptionInfoByID = FindOptionInfoByID,
                HasRule = HasRule,
                AddRule = AddRule,
                GetDbNpcTable = GetDbNpcTable,
                IsDisabled = IsDisabled,
                SetDisabled = SetDisabled,
                IsDisabledDB = IsDisabledDB,
                SetDisabledDB = SetDisabledDB,
            })
        end
    end

    -- Talk tab content
    do
        local panel = browserPanel
        if panel and ns and ns.TalkUI_Build then
            ns.TalkUI_Build(f, panel, {
                InitSV = InitSV,
                HideFauxScrollBarAndEnableWheel = HideFauxScrollBarAndEnableWheel,
                IsDisabled = IsDisabled,
                IsDisabledDB = IsDisabledDB,
                IsDisabledDBOnChar = IsDisabledDBOnChar,
                IsDisabledAccOnChar = IsDisabledAccOnChar,
                SetDisabled = SetDisabled,
                SetDisabledDB = SetDisabledDB,
                SetDisabledDBOnChar = SetDisabledDBOnChar,
                SetDisabledAccOnChar = SetDisabledAccOnChar,
                DeleteRule = DeleteRule,
            })
        end
    end

    -- Switches tab content
    do
        local panel = f.togglesPanel
        if panel then
            local UpdateUI = function() end
            if ns and ns.SwitchesUI_Build then
                UpdateUI = ns.SwitchesUI_Build(f, panel, {
                    InitSV = InitSV,
                    GetQueueAcceptState = GetQueueAcceptState,
                    SetQueueAcceptState = SetQueueAcceptState,
                    ShowQueueOverlayIfNeeded = ShowQueueOverlayIfNeeded,
                    EnsureChromieIndicator = EnsureChromieIndicator,
                    UpdateChromieIndicator = UpdateChromieIndicator,
                    ForceHideChromieIndicator = ForceHideChromieIndicator,
                    OpenChromieConfigPopup = OpenChromieConfigPopup,
                }) or UpdateUI
            end
            f.UpdateToggleButtons = function()
                UpdateUI()
            end
        end
    end

    -- Situate tab content
    do
        local panel = f.actionBarPanel
        if panel then
            local UpdateUI = function() end
            if ns and ns.SituateUI_Build then
                UpdateUI = ns.SituateUI_Build(panel) or UpdateUI
            end
            f.UpdateSituateButtons = function()
                UpdateUI()
            end
        end
    end

    -- XCMD tab content
    do
        local panel = f.macroPanel
        if panel then
            local UpdateUI = function() end
            if ns and ns.MacroXCMDUI_Build then
                UpdateUI = ns.MacroXCMDUI_Build(panel) or UpdateUI
            end
            f.UpdateMacroButtons = function()
                UpdateUI()
            end
        end
    end

    -- Macros tab content
    do
        local panel = f.macrosPanel
        if panel and ns then
            if type(ns.BuildMacrosPanel) == "function" then
                ns.BuildMacrosPanel(panel)
            elseif type(ns.BuildHearthMacrosPanel) == "function" then
                ns.BuildHearthMacrosPanel(panel)
            end
        end
    end

    -- Creation tab (Edit/Add) font bump (+2pt) only.
    if not f._editFontsBumped then
        BumpFontsInFrame(editPanel, 2)
        f._editFontsBumped = true
    end

    -- Creation tab (Edit/Add): NPCID line extra bump (+5pt).
    if f.reasonLabel and not f._npcIdFontBumped then
        BumpFont(f.reasonLabel, 5)
        f._npcIdFontBumped = true
    end

    -- Default tab
    if f.SelectTab then
        f:SelectTab(1)
    end
    if f.RefreshBrowserList then
        f:RefreshBrowserList()
    end
    f:Hide()
end

local function ToggleUI(optionID)
    CreateOptionsWindow()
    if AutoGossipOptions:IsShown() then
        AutoGossipOptions:Hide()
    else
        AutoGossipOptions:Show()
        if AutoGossipOptions.RefreshBrowserList then
            AutoGossipOptions:RefreshBrowserList()
        end
        if AutoGossipOptions.SelectTab then
            AutoGossipOptions:SelectTab(5)
        end
        AutoGossipOptions.edit:SetText(optionID and tostring(optionID) or "")
        AutoGossipOptions.edit:HighlightText()
        if AutoGossipOptions.edit and AutoGossipOptions.edit.ClearFocus then
            AutoGossipOptions.edit:ClearFocus()
        end
        if AutoGossipOptions.UpdateFromInput then
            AutoGossipOptions:UpdateFromInput()
        end
    end
end

local function PrintCurrentOptions()
    if not (C_GossipInfo and C_GossipInfo.GetOptions) then
        Print("Gossip API not available")
        return
    end

    local options = C_GossipInfo.GetOptions() or {}
    -- If there's only one option, the addon will auto-select it anyway; avoid chat spam.
    if #options <= 1 then
        return
    end

    local npcID = GetCurrentNpcID()
    local npcName = GetCurrentNpcName() or ""
    if npcID then
        Print(string.format("NPC: %s (%d)", npcName, npcID))
    end
    for _, opt in ipairs(options) do
        if opt and opt.gossipOptionID then
            Print(string.format("OptionID %d: %s", opt.gossipOptionID, opt.name or ""))
        end
    end
end

local lastDebugPrintAt = 0
local lastDebugPrintKey = nil

local function PrintDebugOptionsOnShow()
    InitSV()

    -- Don't print debug on characters that already have at least one character-scoped rule.
    -- (Keeps chat clean on established characters; still prints for fresh characters.)
    do
        local db = AutoGossip_Char
        if type(db) == "table" then
            for _, npcTable in pairs(db) do
                if type(npcTable) == "table" and next(npcTable) ~= nil then
                    return
                end
            end
        end
    end

    if not (C_GossipInfo and C_GossipInfo.GetOptions) then
        return
    end

    local options = C_GossipInfo.GetOptions() or {}
    if #options <= 1 then
        return
    end

    local npcID = GetCurrentNpcID()
    local npcName = GetCurrentNpcName() or ""

    -- Debounce: both GOSSIP_SHOW and PLAYER_INTERACTION_MANAGER_FRAME_SHOW can fire for the
    -- same interaction, which would otherwise print the same block twice.
    do
        local ids = {}
        for _, opt in ipairs(options) do
            local optionID = opt and opt.gossipOptionID
            if optionID then
                ids[#ids + 1] = optionID
            end
        end
        table.sort(ids)
        local key = tostring(npcID or "?") .. ":" .. tostring(#options) .. ":" .. table.concat(ids, ",")

        local now = (GetTime and GetTime()) or 0
        if lastDebugPrintKey == key and (now - (lastDebugPrintAt or 0)) < 0.20 then
            return
        end
        lastDebugPrintKey = key
        lastDebugPrintAt = now
    end

    -- Don't print debug if we'd auto-select for this NPC/options.
    -- Treat the UI window being open like Shift held (suppresses auto-select).
    if npcID and (not IsShiftKeyDown()) and (not InCombatLockdown()) and (not (AutoGossipOptions and AutoGossipOptions.IsShown and AutoGossipOptions:IsShown())) then
        for _, opt in ipairs(options) do
            local optionID = opt and opt.gossipOptionID
            if optionID then
                if HasRule("char", npcID, optionID) and (not IsDisabled("char", npcID, optionID)) then
                    return
                end
                if HasRule("acc", npcID, optionID) and (not IsDisabled("acc", npcID, optionID)) then
                    return
                end
                if HasDbRule(npcID, optionID) and (not IsDisabledDB(npcID, optionID)) then
                    return
                end
            end
        end
    end

    if npcID then
        Print(string.format("%d: %s", npcID, npcName))
    else
        Print(string.format("?: %s", npcName))
    end

    for _, opt in ipairs(options) do
        local optionID = opt and opt.gossipOptionID
        if optionID then
            local text = opt.name
            if type(text) ~= "string" or text == "" then
                text = "(no text)"
            end
            Print(string.format("OptionID %d: %s", optionID, text))
        end
    end
end

SLASH_FROZENGAMEOPTIONS1 = "/fgo"
---@diagnostic disable-next-line: duplicate-set-field
SlashCmdList["FROZENGAMEOPTIONS"] = function(msg)
    msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "" then
        ToggleUI()
        return
    end

    do
        local function BuildFGOScopeText()
            -- Keep this as valid macro-ish lines so it can be copied into real macros.
            local lines = {
                "/fgo                       - open/toggle window",
                "/fgo <id>                  - open window + set option id",
                "/fgo list                  - print current gossip options",
                "/fgo petbattle             - force-enable pet battle auto-accept",
                "",
                "/fgo x <key>               - exclusion macros (MAIN/OTHER based on Characters list)",
                "/fgo m <key>               - macros (single text)",
                "/fgo c <key>               - faction macros (Both + Alliance/Horde)",
                "/fgo d <key>               - other macros (everything not in x/m/c)",
                "",
                "/fgo debug                 - print Macro CMD debug info",
                "/fgo debug <mode> <key>    - debug a specific Macro CMD entry",
                "/fgo arm <key>             - arm secure /click for current mode",
                "/fgo arm <mode> <key>      - arm secure /click for a specific mode",
                "/fgo armtest <mode> <key>  - arm with marker (debug)",
                "/fgo mk <key> [macroName]  - create a real WoW macro for /click",
                "/fgo mk <mode> <key> [macroName]",
                "",
                "/fgo hm ...                - housing macros (see 'Home' tab)",
                "/fgo hs hearth             - hearth status (prints destination/cooldown)",
                "/fgo hs loc                - print your current bind location",
                "/fgo hs garrison           - garrison hearth status",
                "/fgo hs dalaran            - dalaran hearth status",
                "/fgo hs dornogal           - dornogal portal status",
                "/fgo hs whistle            - delve whistle status",
                "",
                "/fgo script                - toggle ScriptErrors",
                "/fgo loot                  - toggle Auto Loot",
                "/fgo mouse                 - toggle Loot Under Mouse",
                "/fgo trade                 - toggle Block Trades",
                "/fgo friend                - toggle Friendly Names",
                "/fgo bars                  - toggle ActionBar Lock",
                "/fgo bagrev                - toggle Bag Sort Reverse",
                "/fgo token                 - print WoW Token price",
                "/fgo setup                 - apply common setup CVars",
                "/fgo fish                  - apply fishing prep CVars",
                "/fgo chromie               - print Chromie Time status",
                "/fgo ctoff                 - attempt to disable Chromie Time (rested only)",
                "",
                "/fgo scope                 - open this list in Macro CMD (copy/edit)",
            }
            return table.concat(lines, "\n")
        end

        local function OpenMacroCmdEditor(wantMode, wantKey)
            CreateOptionsWindow()
            if not AutoGossipOptions then
                return
            end

            AutoGossipOptions:Show()
            if AutoGossipOptions.SelectTab then
                AutoGossipOptions:SelectTab(2) -- Macro CMD
            end

            if ns and type(ns.MacroXCMD_SetMode) == "function" then
                ns.MacroXCMD_SetMode(wantMode)
            end

            local panel = ns and ns._MacroXCMDUI_Panel or nil
            if panel and type(panel._MacroCmdUI_SelectKey) == "function" then
                panel._MacroCmdUI_SelectKey(wantMode, wantKey)
            end
        end

        local function ToggleCVar(key, label)
            if not (C_CVar and C_CVar.GetCVar and C_CVar.SetCVar) then
                Print("CVar API unavailable")
                return
            end
            key = tostring(key or "")
            if key == "" then
                return
            end
            local v = tonumber(C_CVar.GetCVar(key)) or 0
            local newV = (v == 1) and 0 or 1
            C_CVar.SetCVar(key, tostring(newV))
            if label and label ~= "" then
                Print(tostring(label) .. " " .. ((v == 1) and "Disabled" or "Enabled"))
            else
                Print(key .. " " .. ((v == 1) and "Disabled" or "Enabled"))
            end
        end

        local function SetCVarSafe(key, value)
            if SetCVar then
                pcall(SetCVar, tostring(key or ""), tostring(value))
                return
            end
            if C_CVar and C_CVar.SetCVar then
                pcall(C_CVar.SetCVar, tostring(key or ""), tostring(value))
                return
            end
        end

        local cmd, rest = msg:match("^(%S+)%s*(.-)$")
        cmd = cmd and cmd:lower() or nil

        -- Back-compat: old faction mode was /fgo f (now /fgo c).
        if cmd == "f" then
            cmd = "c"
        end

        if cmd == "scope" then
            if ns and type(ns.MacroXCMD_UpsertText) == "function" then
                ns.MacroXCMD_UpsertText("d", "scope", BuildFGOScopeText())
            end
            OpenMacroCmdEditor("d", "scope")
            return
        end

        -- Allow optional space after single-letter mode commands.
        -- Examples:
        --   /fgo mfoo   -> cmd='m', rest='foo'
        --   /fgo xlist  -> cmd='x', rest='list'
        -- Keep existing full commands working (e.g. /fgo chromie, /fgo mouse).
        if cmd and #cmd > 1 then
            local known = {
                ["m"] = true,
                ["hm"] = true,
                ["hs"] = true,
                ["debug"] = true,
                ["arm"] = true,
                ["armtest"] = true,
                ["mk"] = true,
                ["mkmacro"] = true,
                ["script"] = true,
                ["scripterrors"] = true,
                ["chromie"] = true,
                ["chromietime"] = true,
                ["ct"] = true,
                ["ctoff"] = true,

                -- Macro CMD keys that would otherwise be mis-parsed as mode glue.
                -- Example: /fgo mouse would become /fgo m ouse without this.
                ["mouse"] = true,
            }

            if not known[cmd] then
                local first = cmd:sub(1, 1)
                if first == "x" or first == "m" or first == "c" or first == "d" then
                    local glued = cmd:sub(2)
                    if glued ~= "" then
                        rest = glued .. ((rest and rest ~= "") and (" " .. rest) or "")
                        cmd = first
                    end
                end
            end
        end

        -- Macro CMD modes:
        --  /fgo x ...  (Exclusion macros; old behavior)
        --  /fgo m ...  (Macros; disables character boxes)
        --  /fgo c ...  (Faction macros; Both + Alliance/Horde)
        --  /fgo d ...  (Other macros; everything not in x/m/c)
        if cmd == "x" or cmd == "m" or cmd == "c" or cmd == "d" then
            if ns and ns.MacroXCMD_SetMode then
                ns.MacroXCMD_SetMode(cmd)
            end

            -- Treat bare /fgo x|m|c|d as a UI toggle + mode select.
            local restTrim = (rest or ""):gsub("^%s+", ""):gsub("%s+$", "")
            if restTrim == "" then
                ToggleUI()
                Print("Macro mode: /fgo " .. cmd)
                return
            end

            -- Convenience editor: open the Macro CMD tab on a key.
            if restTrim:lower() == "scope" then
                if ns and type(ns.MacroXCMD_EnsureEntry) == "function" then
                    ns.MacroXCMD_EnsureEntry(cmd, "scope")
                end
                OpenMacroCmdEditor(cmd, "scope")
                return
            end

            if ns and ns.MacroXCMD_HandleSlashMode then
                ns.MacroXCMD_HandleSlashMode(cmd, rest)
            elseif ns and ns.MacroXCMD_HandleSlash then
                -- Back-compat: treat as x-mode.
                ns.MacroXCMD_HandleSlash(rest)
            else
                Print("Macro command module not loaded.")
            end
            return
        end

        if cmd == "hm" then
            local sub, subarg = (rest or ""):match("^(%S*)%s*(.-)$")
            if ns and ns.Home and type(ns.Home.HandleHM) == "function" then
                ns.Home.HandleHM(sub, subarg)
            else
                Print("Housing module not loaded.")
            end
            return
        end

        if cmd == "debug" then
            local a, b = (rest or ""):match("^(%S*)%s*(.-)$")
            if ns and type(ns.MacroXCMD_Debug) == "function" then
                if a == "" then
                    ns.MacroXCMD_Debug()
                else
                    local mode = a
                    local key = (b or "")
                    ns.MacroXCMD_Debug(mode, key)
                end
            else
                Print("Macro command module not loaded.")
            end
            return
        end

        if cmd == "arm" then
            if not (ns and type(ns.MacroXCMD_ArmClickButton) == "function") then
                Print("Macro command module not loaded.")
                return
            end

            local showHelperUsage = (AutoGossip_Settings and AutoGossip_Settings.debugAcc) and true or false

            local a, b = (rest or ""):match("^(%S*)%s*(.-)$")
            if a == "f" then a = "c" end
            if a == "" then
                if showHelperUsage then
                    Print("Usage: /fgo arm <key>")
                    Print("   or: /fgo arm <mode> <key>")
                    Print("Example: /fgo arm c XAB")
                end
                return
            end

            local mode = nil
            local key = nil
            if a == "x" or a == "m" or a == "c" or a == "d" then
                mode = a
                key = (b or ""):match("^(%S+)")
            else
                if ns and type(ns.MacroXCMD_GetMode) == "function" then
                    mode = ns.MacroXCMD_GetMode()
                end
                mode = mode or "x"
                key = a
            end

            key = tostring(key or "")
            if key == "" then
                if showHelperUsage then
                    Print("Usage: /fgo arm <mode> <key>")
                end
                return
            end

            local ok, why = ns.MacroXCMD_ArmClickButton(mode, key)
            if ok then
                Print("Armed Macro CMD secure button for /fgo " .. tostring(mode) .. " " .. tostring(key))
            else
                Print("Arm failed: " .. tostring(why))
            end
            return
        end

        if cmd == "armtest" then
            if not (ns and type(ns.MacroXCMD_ArmClickButtonWithMarker) == "function") then
                Print("Macro command module not loaded.")
                return
            end

            local showHelperUsage = (AutoGossip_Settings and AutoGossip_Settings.debugAcc) and true or false

            local a, b = (rest or ""):match("^(%S*)%s*(.-)$")
            if a == "f" then a = "c" end
            if a == "" then
                if showHelperUsage then
                    Print("Usage: /fgo armtest <key>")
                    Print("   or: /fgo armtest <mode> <key>")
                    Print("Example: /fgo armtest c XAB")
                end
                return
            end

            local mode = nil
            local key = nil
            if a == "x" or a == "m" or a == "c" or a == "d" then
                mode = a
                key = (b or ""):match("^(%S+)")
            else
                if ns and type(ns.MacroXCMD_GetMode) == "function" then
                    mode = ns.MacroXCMD_GetMode()
                end
                mode = mode or "x"
                key = a
            end

            key = tostring(key or "")
            if key == "" then
                if showHelperUsage then
                    Print("Usage: /fgo armtest <mode> <key>")
                end
                return
            end

            local ok, why = ns.MacroXCMD_ArmClickButtonWithMarker(mode, key)
            if ok then
                Print("Armed (with marker) for /fgo " .. tostring(mode) .. " " .. tostring(key))
            else
                Print("Armtest failed: " .. tostring(why))
            end
            return
        end

        if cmd == "mk" or cmd == "mkmacro" then
            local a, b = (rest or ""):match("^(%S*)%s*(.-)$")
            if a == "f" then a = "c" end
            if not (ns and type(ns.MacroXCMD_MakeClickMacro) == "function") then
                Print("Macro command module not loaded.")
                return
            end

            local showHelperUsage = (AutoGossip_Settings and AutoGossip_Settings.debugAcc) and true or false

            if a == "" then
                if showHelperUsage then
                    Print("Usage: /fgo mk <key> [macroName]")
                    Print("   or: /fgo mk <mode> <key> [macroName]")
                    Print("Example: /fgo mk c XAB")
                end
                return
            end

            local mode = nil
            local key = nil
            local macroName = nil

            if a == "x" or a == "m" or a == "c" or a == "d" then
                mode = a
                key, macroName = (b or ""):match("^(%S+)%s*(.-)$")
                key = key or ""
            else
                key = a
                macroName = b
            end

            macroName = (macroName or ""):gsub("^%s+", ""):gsub("%s+$", "")
            if macroName == "" then
                macroName = nil
            end

            local ok, why, finalName, clickBody
            if mode then
                ok, why, finalName, clickBody = ns.MacroXCMD_MakeClickMacroMode(mode, key, macroName)
            else
                ok, why, finalName, clickBody = ns.MacroXCMD_MakeClickMacro(key, macroName)
            end

            if ok then
                Print("Macro '" .. tostring(finalName) .. "' " .. tostring(why) .. ": " .. tostring(clickBody))
            else
                if clickBody and clickBody ~= "" then
                    Print("Cannot make macro: " .. tostring(why) .. ". You can still create it manually with: " .. tostring(clickBody))
                else
                    Print("Cannot make macro: " .. tostring(why))
                end
            end
            return
        end

        if cmd == "scripterrors" or cmd == "script" then
            -- Keep /fgo script working, but route through Macro CMD so it stays editable.
            if ns and ns.MacroXCMD_HandleSlashMode then
                ns.MacroXCMD_HandleSlashMode("d", "script")
                return
            end
            ToggleCVar("ScriptErrors", "ScriptErrors")
            return
        end

        if cmd == "chromie" or cmd == "chromietime" or cmd == "ct" then
            InitSV()
            if not IsChromieTimeAvailableToPlayer() then
                return
            end
            local enabled, optionID, name, supported = GetChromieTimeInfo()
            if not supported then
                return
            elseif not enabled then
                Print("Chromie Time: OFF")
            else
                local suffix = ""
                if type(name) == "string" and name ~= "" then
                    suffix = " (" .. name .. ")"
                elseif type(optionID) == "number" then
                    suffix = " (" .. tostring(optionID) .. ")"
                end
                Print("Chromie Time: ON" .. suffix)
            end
            if AutoGossipOptions and AutoGossipOptions.UpdateChromieLabel then
                AutoGossipOptions.UpdateChromieLabel()
            end
            EnsureChromieIndicator()
            UpdateChromieIndicator()
            return
        end

        if cmd == "ctoff" then
            -- Silent unless in a rested area.
            if not IsPlayerResting() then
                return
            end

            local ok, why = TryDisableChromieTime()
            if ok then
                Print("Chromie Time: disable requested")
            else
                if why == "unavailable" then
                    Print("Chromie Time: N/A")
                elseif why == "no-disable-func" or why == "no-api" then
                    Print("Chromie Time: can't disable via API (talk to Chromie)")
                end
            end

            if AutoGossipOptions and AutoGossipOptions.UpdateChromieLabel then
                AutoGossipOptions.UpdateChromieLabel()
            end
            EnsureChromieIndicator()
            UpdateChromieIndicator()
            return
        end

        if cmd == "hs" or cmd == "hearth" then
            local dest = (rest or ""):lower()

            local function GetCooldownRemaining(itemID)
                if not (GetItemCooldown and GetTime) then
                    return 0
                end
                local s, d = GetItemCooldown(tonumber(itemID) or 0)
                s = tonumber(s) or 0
                d = tonumber(d) or 0
                if s <= 0 or d <= 0 then
                    return 0
                end
                local rem = (s + d) - (GetTime() or 0)
                if rem < 0 then rem = 0 end
                return rem
            end

            local function PrintHSMessage(itemID, onReadyText, onCdFmt)
                local rem = GetCooldownRemaining(itemID)
                if rem > 1 then
                    Print(string.format(onCdFmt, rem / 60))
                else
                    Print(tostring(onReadyText))
                end
            end

            if dest == "garrison" then
                PrintHSMessage(110560, "Hearthing to Garrison", "Hearthing to Garrison in %d mins")
                return
            end
            if dest == "dalaran" then
                PrintHSMessage(140192, "Hearthing to Dalaran", "Hearthing to Dalaran in %d mins")
                return
            end
            if dest == "dornogal" then
                PrintHSMessage(243056, "Portal to Dornogal Opening", "Portal to Dornogal in %d mins")
                return
            end
            if dest == "whistle" then
                PrintHSMessage(230850, "Yay! Off To A Delve", "Ride to a Delve in %d mins")
                return
            end

            if dest == "loc" or dest == "location" then
                local bind = (GetBindLocation and GetBindLocation()) or ""
                local zone = ""
                if GetRealZoneText then
                    zone = GetRealZoneText() or ""
                end
                if zone == "" and GetZoneText then
                    zone = GetZoneText() or ""
                end

                bind = tostring(bind or "")
                zone = tostring(zone or "")

                if bind == "" and ns and ns.Hearth and type(ns.Hearth.GetCurrentDisplayText) == "function" then
                    local b2, z2 = ns.Hearth.GetCurrentDisplayText()
                    bind = tostring(b2 or bind)
                    zone = tostring(z2 or zone)
                end

                local msg = "|cFFFFD707Home Set To " .. bind
                if zone ~= "" then
                    msg = msg .. ", " .. zone
                end
                Print(msg)
                return
            end
            if dest == "hearth" or dest == "" then
                local useID = 6948
                local bind = ""
                local zone = ""

                if ns and ns.Hearth then
                    if type(ns.Hearth.GetCurrentDisplayText) == "function" then
                        bind, zone = ns.Hearth.GetCurrentDisplayText()
                    else
                        bind = (GetBindLocation and GetBindLocation()) or ""
                    end

                    if type(ns.Hearth.EnsureInit) == "function" then
                        local db = ns.Hearth.EnsureInit()
                        if type(db) == "table" then
                            local sel = tonumber(db.selectedUseItemID)
                            if sel and sel > 0 then
                                useID = sel
                            end
                        end
                    end
                else
                    bind = (GetBindLocation and GetBindLocation()) or ""
                end

                bind = tostring(bind or "")
                zone = tostring(zone or "")

                local to = bind
                if to == "" then
                    to = zone
                elseif zone ~= "" then
                    to = to .. ", " .. zone
                end

                local rem = GetCooldownRemaining(useID)
                if rem > 1 then
                    Print(string.format("Hearthing in %d mins to %s", rem / 60, to))
                else
                    Print(string.format("Hearthing to %s", to))
                end
                return
            end

            Print("Usage: /fgo hs hearth|loc|garrison|dalaran|dornogal|whistle")
            return
        end
    end

    if msg:lower() == "petbattle" then
        -- Force-enable pet battle "Prepare yourself!" auto-accept (macro-friendly; no prints).
        InitSV()
        AutoGossip_Settings.autoAcceptPetPrepareAcc = true
        return
    end

    local n = tonumber(msg)
    if n then
        ToggleUI(n)
        return
    end
    if msg == "list" then
        PrintCurrentOptions()
        return
    end

    -- Fallback: treat unknown /fgo <key> as a d-mode Macro CMD entry.
    -- This enables README-style macros like: /fgo logout
    if ns and type(ns.MacroXCMD_RunAuto) == "function" then
        if ns.MacroXCMD_RunAuto(msg) then
            return
        end
    end
    if ns and ns.MacroXCMD_HandleSlashMode then
        ns.MacroXCMD_HandleSlashMode("d", msg)
        return
    end

    Print("/fgo           - open/toggle window")
    Print("/fgo <id>      - open window + set option id")
    Print("/fgo list      - print current gossip options")
    Print("/fgo petbattle - force-enable pet battle auto-accept")
    Print("/fgo x ...     - exclusion macros (old /fgo m behavior)")
    Print("/fgo m ...     - macros (no character boxes)")
    Print("/fgo c ...     - faction macros (Both + Alliance/Horde)")
    Print("/fgo d ...     - other macros (everything not in x/m/c)")
    Print("/fgo hm ...    - housing macros (see 'Home' tab)")
    Print("/fgo hs ...    - hearth status helper (used by 'Macros' tab macros)")
    Print("/fgo script    - toggle ScriptErrors (used by 'Macros' tab macros)")
    Print("/fgo scope     - show all /fgo commands (copy/edit)")
    Print("/fgo loot      - toggle Auto Loot")
    Print("/fgo mouse     - toggle Loot Under Mouse")
    Print("/fgo trade     - toggle Block Trades")
    Print("/fgo friend    - toggle Friendly Names")
    Print("/fgo bars      - toggle ActionBar Lock")
    Print("/fgo bagrev    - toggle Bag Sort Reverse")
    Print("/fgo token     - print WoW Token price")
    Print("/fgo setup     - apply common setup CVars")
    Print("/fgo fish      - apply fishing prep CVars")
    Print("/fgo chromie   - print Chromie Time status")
    Print("/fgo ctoff     - attempt to disable Chromie Time (rested areas only)")
end

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("GOSSIP_SHOW")
frame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
frame:RegisterEvent("LFG_PROPOSAL_SHOW")
frame:RegisterEvent("LFG_PROPOSAL_UPDATE")
frame:RegisterEvent("LFG_PROPOSAL_FAILED")
frame:RegisterEvent("LFG_PROPOSAL_SUCCEEDED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PET_BATTLE_OPENING_START")
frame:RegisterEvent("PET_BATTLE_CLOSE")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_LEVEL_UP")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("QUEST_LOG_UPDATE")
frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        InitSV()
        SetupChromieSelectionTracking()
        DeduplicateUserRulesAgainstDb()

        -- Macro CMD: pre-arm secure /click buttons so user macros work without a prep step.
        if ns and type(ns.MacroXCMD_ArmAllClickButtons) == "function" then
            pcall(ns.MacroXCMD_ArmAllClickButtons)
        end
        local talkXpop = ns and (ns.TalkXPOP or ns.Popup) or nil
        if talkXpop and type(talkXpop.Setup) == "function" then
            talkXpop.Setup()
        end

        if (AutoGossip_UI and AutoGossip_UI.chromieFrameEnabled) and IsChromieTimeAvailableToPlayer() then
            EnsureChromieIndicator()
            UpdateChromieIndicator()
        else
            ForceHideChromieIndicator()
        end
        return
    end

    if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_LEVEL_UP" or event == "ZONE_CHANGED_NEW_AREA" then
        InitSV()
        SetupChromieSelectionTracking()

        -- Macro CMD: arm per-character secure /click buttons once we have full player context.
        if ns and type(ns.MacroXCMD_ArmAllClickButtons) == "function" then
            pcall(ns.MacroXCMD_ArmAllClickButtons)
        end
        if AutoGossipOptions and AutoGossipOptions.UpdateChromieLabel then
            AutoGossipOptions.UpdateChromieLabel()
        else
            if (AutoGossip_UI and AutoGossip_UI.chromieFrameEnabled) and IsChromieTimeAvailableToPlayer() then
                EnsureChromieIndicator()
                UpdateChromieIndicator()
            else
                ForceHideChromieIndicator()
            end
        end
        return
    end

    if event == "QUEST_LOG_UPDATE" then
        InitSV()
        SetupChromieSelectionTracking()
        if AutoGossipOptions and AutoGossipOptions.UpdateChromieLabel then
            AutoGossipOptions.UpdateChromieLabel()
        else
            if (AutoGossip_UI and AutoGossip_UI.chromieFrameEnabled) and IsChromieTimeAvailableToPlayer() then
                EnsureChromieIndicator()
                UpdateChromieIndicator()
            end
        end
        return
    end

    if event == "PET_BATTLE_OPENING_START" then
        InitSV()
        local talkXpop = ns and (ns.TalkXPOP or ns.Popup) or nil
        if talkXpop and type(talkXpop.OnPetBattleOpeningStart) == "function" then
            talkXpop.OnPetBattleOpeningStart()
        end
        return
    end
    if event == "PET_BATTLE_CLOSE" then
        local talkXpop = ns and (ns.TalkXPOP or ns.Popup) or nil
        if talkXpop and type(talkXpop.OnPetBattleClose) == "function" then
            talkXpop.OnPetBattleClose()
        end
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        InitSV()

        -- Macro CMD: if secure button arming was blocked in combat, retry now.
        if ns and type(ns.MacroXCMD_ArmAllClickButtons) == "function" then
            pcall(ns.MacroXCMD_ArmAllClickButtons)
        end
        if queueOverlayPendingHide then
            HideQueueOverlay()
        end
        ShowQueueOverlayIfNeeded()
        return
    end

    if event == "LFG_PROPOSAL_SHOW" then
        -- Start a new proposal session.
        queueOverlayProposalToken = (queueOverlayProposalToken or 0) + 1
        queueOverlayDismissedToken = 0
        InitSV()
        ShowQueueOverlayIfNeeded()
        return
    end

    if event == "LFG_PROPOSAL_UPDATE" then
        -- Some edge cases (e.g., /reload mid-proposal) may not fire SHOW again.
        if (queueOverlayProposalToken or 0) == 0 and HasActiveLfgProposal() then
            queueOverlayProposalToken = 1
            queueOverlayDismissedToken = 0
        end
        InitSV()
        ShowQueueOverlayIfNeeded()
        return
    end
    if event == "LFG_PROPOSAL_FAILED" or event == "LFG_PROPOSAL_SUCCEEDED" then
        queueOverlayProposalToken = 0
        queueOverlayDismissedToken = 0
        HideQueueOverlay()
        return
    end

    if event == "GOSSIP_SHOW" or event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
        InitSV()

        -- Debug: print NPC header + options list.
        if AutoGossip_Settings and AutoGossip_Settings.debugAcc then
            PrintDebugOptionsOnShow()
        end
        if AutoGossip_UI and AutoGossip_UI.printOnShow then
            -- Helpful when building rules.
            PrintCurrentOptions()
        end

        if AutoGossipOptions and AutoGossipOptions:IsShown() and AutoGossipOptions.UpdateFromInput then
            AutoGossipOptions:UpdateFromInput()
        end
        if AutoGossipOptions and AutoGossipOptions:IsShown() and AutoGossipOptions.RefreshOptionsList then
            AutoGossipOptions:RefreshOptionsList()
        end
        TryAutoSelect()
    end
end)
