---@diagnostic disable: undefined-global

local addonName, ns = ...
if type(ns) ~= "table" then
    ns = {}
end

local didInit = false
local didRegister = false
local applyTimer = nil
local pendingReason = nil
local pendingAfterCombat = false

local function InitSV()
    if ns and type(ns._InitSV) == "function" then
        ns._InitSV()
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

local function GetBoolSetting(key, defaultValue)
    local s = GetSettings()
    if not s then
        return defaultValue and true or false
    end
    local v = s[key]
    if type(v) ~= "boolean" then
        return defaultValue and true or false
    end
    return v
end

local function GetTableSetting(key)
    local s = GetSettings()
    if not s then
        return nil
    end
    local v = s[key]
    if type(v) ~= "table" then
        return nil
    end
    return v
end

local function DebugPrint(msg)
    if not GetBoolSetting("actionBarDebugAcc", false) then
        return
    end
    print("|cff00ccff[FGO]|r ActionBar: " .. tostring(msg))
end

local function SyncGlobals()
    local s = GetSettings()
    local isMain = (type(s) == "table" and s.actionBarMainAcc) and true or false
    _G.FGO_AB_MAIN = isMain
end

ns.ActionBar_SyncGlobals = SyncGlobals

local function InCombat()
    if InCombatLockdown and InCombatLockdown() then
        return true
    end
    if UnitAffectingCombat then
        return UnitAffectingCombat("player") and true or false
    end
    return false
end

local function SafeGetMacroIndexByName(name)
    if type(name) ~= "string" or name == "" then
        return 0
    end
    if not GetMacroIndexByName then
        return 0
    end
    local ok, idx = pcall(GetMacroIndexByName, name)
    if not ok then
        return 0
    end
    if type(idx) ~= "number" then
        return 0
    end
    return idx
end

local function EnsureMacro(entry)
    if type(entry) ~= "table" then
        return 0, "invalid-entry"
    end

    local name = entry.name
    if type(name) ~= "string" or name == "" then
        return 0, "missing-name"
    end

    local idx = SafeGetMacroIndexByName(name)
    local body = entry.body

    if idx and idx > 0 then
        if type(body) == "string" and body ~= "" and EditMacro then
            local currentBody = ""
            if GetMacroInfo then
                local ok, _, _, b = pcall(GetMacroInfo, idx)
                if ok and type(b) == "string" then
                    currentBody = b
                end
            end
            if currentBody ~= body then
                local icon = entry.icon
                pcall(EditMacro, idx, name, icon, body)
                DebugPrint("Updated macro: " .. name)
            end
        end
        return idx, "ok"
    end

    if type(body) ~= "string" or body == "" or not CreateMacro then
        return 0, "missing-macro"
    end

    local perChar = entry.perChar and true or false
    local icon = entry.icon
    local ok, newIndex = pcall(CreateMacro, name, icon, body, perChar)
    if not ok then
        return 0, "create-failed"
    end

    if type(newIndex) ~= "number" then
        newIndex = SafeGetMacroIndexByName(name)
    end

    if type(newIndex) == "number" and newIndex > 0 then
        DebugPrint("Created macro: " .. name)
        return newIndex, "created"
    end

    return 0, "create-unknown"
end

local function NormalizeSlot(slot)
    slot = tonumber(slot)
    if not slot then
        return nil
    end
    slot = math.floor(slot)
    if slot < 1 or slot > 180 then
        return nil
    end
    return slot
end

local function CanPlaceIntoSlot(slot, desiredMacroIndex)
    if not (GetActionInfo and type(slot) == "number") then
        return false, "no-api"
    end

    local actionType, id = GetActionInfo(slot)

    if not actionType then
        return true, "empty"
    end

    if actionType == "macro" and tonumber(id) == tonumber(desiredMacroIndex) then
        return true, "already"
    end

    if GetBoolSetting("actionBarOverwriteAcc", false) then
        return true, "overwrite"
    end

    return false, "occupied"
end

local function PlaceMacroInSlot(macroIndex, slot)
    if not (macroIndex and macroIndex > 0 and slot) then
        return false, "invalid"
    end
    if not (PickupMacro and PlaceAction and ClearCursor) then
        return false, "no-api"
    end

    local ok1 = pcall(PickupMacro, macroIndex)
    if not ok1 then
        ClearCursor()
        return false, "pickup-failed"
    end

    local ok2 = pcall(PlaceAction, slot)
    ClearCursor()

    if not ok2 then
        return false, "place-failed"
    end

    return true, "placed"
end

local function ApplyLayout(reason)
    InitSV()

    if not GetBoolSetting("actionBarEnabledAcc", false) then
        return
    end

    if InCombat() then
        pendingAfterCombat = true
        DebugPrint("Blocked by combat; will retry")
        return
    end

    pendingAfterCombat = false

    local layout = GetTableSetting("actionBarLayoutAcc")
    if not layout then
        return
    end

    local placed = 0
    local skipped = 0

    for _, entry in ipairs(layout) do
        local slot = NormalizeSlot(entry and entry.slot)
        if slot then
            local macroIndex, status = EnsureMacro(entry)
            if macroIndex and macroIndex > 0 then
                local okSlot, why = CanPlaceIntoSlot(slot, macroIndex)
                if okSlot then
                    if why == "already" then
                        skipped = skipped + 1
                    else
                        local okPlace, placeWhy = PlaceMacroInSlot(macroIndex, slot)
                        if okPlace then
                            placed = placed + 1
                        else
                            skipped = skipped + 1
                            DebugPrint(string.format("Slot %d: %s (%s)", slot, entry.name or "?", placeWhy))
                        end
                    end
                else
                    skipped = skipped + 1
                    DebugPrint(string.format("Slot %d: skip (%s)", slot, why))
                end
            else
                skipped = skipped + 1
                DebugPrint(string.format("Slot %d: macro '%s' (%s)", slot, tostring(entry and entry.name), status))
            end
        end
    end

    if GetBoolSetting("actionBarDebugAcc", false) then
        DebugPrint(string.format("Apply (%s): placed=%d skipped=%d", tostring(reason or "manual"), placed, skipped))
    end
end

local function QueueApply(reason)
    pendingReason = reason or "queued"

    if applyTimer and applyTimer.Cancel then
        applyTimer:Cancel()
        applyTimer = nil
    end

    if C_Timer and C_Timer.NewTimer then
        applyTimer = C_Timer.NewTimer(0.35, function()
            applyTimer = nil
            local r = pendingReason
            pendingReason = nil
            ApplyLayout(r)
        end)
    else
        ApplyLayout(pendingReason)
        pendingReason = nil
    end
end

local eventFrame = CreateFrame("Frame")

local function OnEvent(self, event, ...)
    if event == "PLAYER_REGEN_ENABLED" then
        if pendingAfterCombat then
            QueueApply("regen")
        end
        return
    end

    QueueApply(event)
end

eventFrame:SetScript("OnEvent", OnEvent)

function ns.ActionBar_ApplyNow(reason)
    QueueApply(reason or "manual")
end

function ns.ApplyActionBarSetting(force)
    if not force and didInit then
        return
    end
    didInit = true

    InitSV()

    SyncGlobals()

    local enabled = GetBoolSetting("actionBarEnabledAcc", false)

    if enabled and not didRegister then
        didRegister = true
        eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
        eventFrame:RegisterEvent("UPDATE_BINDINGS")
        eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        QueueApply("enable")
        return
    end

    if (not enabled) and didRegister then
        didRegister = false
        eventFrame:UnregisterAllEvents()
        pendingAfterCombat = false
    end
end

-- Kick once on load so enabling via SavedVariables works.
if C_Timer and C_Timer.After then
    C_Timer.After(0, function()
        SyncGlobals()
        ns.ApplyActionBarSetting(true)
    end)
end
