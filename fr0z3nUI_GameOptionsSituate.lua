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

local function GetActiveSpecID()
    if not (GetSpecialization and GetSpecializationInfo) then
        return nil
    end
    local specIndex = GetSpecialization()
    if not specIndex then
        return nil
    end
    local ok, specID = pcall(GetSpecializationInfo, specIndex)
    if not ok or type(specID) ~= "number" then
        return nil
    end
    return specID
end

local function GetActiveLayout()
    local s = GetSettings()
    if type(s) ~= "table" then
        return nil
    end

    local specID = GetActiveSpecID()
    local bySpec = rawget(s, "actionBarLayoutBySpecAcc")
    if type(bySpec) == "table" and specID and type(bySpec[specID]) == "table" then
        return bySpec[specID], specID
    end

    local legacy = rawget(s, "actionBarLayoutAcc")
    if type(legacy) == "table" then
        return legacy, nil
    end

    return nil
end

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
    print("|cff00ccff[FGO]|r Situate: " .. tostring(msg))
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

local function GetEntryKind(entry)
    local k = entry and entry.kind
    if k == "spell" or k == "macro" then
        return k
    end
    return "macro" -- legacy entries
end

local function ResolveSpellID(entry)
    if type(entry) ~= "table" then
        return nil
    end

    local spellID = tonumber(entry.spellID)
    if spellID then
        spellID = math.floor(spellID)
        if spellID > 0 then
            return spellID
        end
    end

    local spell = entry.spell
    if type(spell) == "number" then
        spellID = math.floor(spell)
        if spellID > 0 then
            return spellID
        end
    end
    if type(spell) == "string" then
        local name = spell:gsub("^%s+", ""):gsub("%s+$", "")
        if name ~= "" and GetSpellInfo then
            local ok, _, _, _, _, _, id = pcall(GetSpellInfo, name)
            if ok and type(id) == "number" and id > 0 then
                return id
            end
        end
    end

    local name = entry.name
    if type(name) == "string" then
        local trimmed = name:gsub("^%s+", ""):gsub("%s+$", "")
        local idNum = tonumber(trimmed)
        if idNum and idNum > 0 then
            return math.floor(idNum)
        end
        if trimmed ~= "" and GetSpellInfo then
            local ok, _, _, _, _, _, id = pcall(GetSpellInfo, trimmed)
            if ok and type(id) == "number" and id > 0 then
                return id
            end
        end
    end

    return nil
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

local function CanPlaceIntoSlot(slot, desiredKind, desiredId)
    if not (GetActionInfo and type(slot) == "number") then
        return false, "no-api"
    end

    local actionType, id = GetActionInfo(slot)

    if not actionType then
        return true, "empty"
    end

    if desiredKind == "macro" and actionType == "macro" and tonumber(id) == tonumber(desiredId) then
        return true, "already"
    end
    if desiredKind == "spell" and actionType == "spell" and tonumber(id) == tonumber(desiredId) then
        return true, "already"
    end

    if GetBoolSetting("actionBarOverwriteAcc", false) then
        return true, "overwrite"
    end

    return false, "occupied"
end

local function PickupExisting(kind, id)
    if kind == "macro" then
        if not PickupMacro then
            return false, "no-pickup-macro"
        end
        local ok = pcall(PickupMacro, id)
        if not ok then
            return false, "pickup-macro-failed"
        end
        return true, "picked"
    end

    if kind == "spell" then
        if C_Spell and C_Spell.PickupSpell then
            local ok = pcall(C_Spell.PickupSpell, id)
            if not ok then
                return false, "pickup-spell-failed"
            end
            return true, "picked"
        end
        if PickupSpell then
            local ok = pcall(PickupSpell, id)
            if not ok then
                return false, "pickup-spell-failed"
            end
            return true, "picked"
        end
        return false, "no-pickup-spell"
    end

    return false, "unknown-kind"
end

local function PlaceIntoSlot(kind, id, slot)
    if not (id and tonumber(id) and slot) then
        return false, "invalid"
    end
    if not (PlaceAction and ClearCursor) then
        return false, "no-api"
    end

    local okPick, pickWhy = PickupExisting(kind, id)
    if not okPick then
        if ClearCursor then
            ClearCursor()
        end
        return false, pickWhy
    end

    local okPlace = pcall(PlaceAction, slot)
    ClearCursor()

    if not okPlace then
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

    local layout = GetActiveLayout()
    if not layout then
        return
    end

    local placed = 0
    local skipped = 0

    for _, entry in ipairs(layout) do
        local slot = NormalizeSlot(entry and entry.slot)
        if slot then
            local kind = GetEntryKind(entry)

            local desiredId = nil
            local desiredLabel = nil
            if kind == "spell" then
                desiredId = ResolveSpellID(entry)
                desiredLabel = tostring(entry and (entry.spell or entry.spellID or entry.name) or "?")
                if not desiredId then
                    skipped = skipped + 1
                    DebugPrint(string.format("Slot %d: spell '%s' (missing)", slot, desiredLabel))
                else
                    local okSlot, why = CanPlaceIntoSlot(slot, "spell", desiredId)
                    if okSlot then
                        if why == "already" then
                            skipped = skipped + 1
                        else
                            local okPlace, placeWhy = PlaceIntoSlot("spell", desiredId, slot)
                            if okPlace then
                                placed = placed + 1
                            else
                                skipped = skipped + 1
                                DebugPrint(string.format("Slot %d: spell %s (%s)", slot, tostring(desiredId), placeWhy))
                            end
                        end
                    else
                        skipped = skipped + 1
                        DebugPrint(string.format("Slot %d: skip (%s)", slot, why))
                    end
                end
            else
                local name = entry and entry.name
                if type(name) == "string" then
                    name = name:gsub("^%s+", ""):gsub("%s+$", "")
                end
                desiredLabel = tostring(name)

                local macroIndex = (type(name) == "string" and name ~= "") and SafeGetMacroIndexByName(name) or 0
                if not (macroIndex and macroIndex > 0) then
                    skipped = skipped + 1
                    DebugPrint(string.format("Slot %d: macro '%s' (missing)", slot, desiredLabel))
                else
                    local okSlot, why = CanPlaceIntoSlot(slot, "macro", macroIndex)
                    if okSlot then
                        if why == "already" then
                            skipped = skipped + 1
                        else
                            local okPlace, placeWhy = PlaceIntoSlot("macro", macroIndex, slot)
                            if okPlace then
                                placed = placed + 1
                            else
                                skipped = skipped + 1
                                DebugPrint(string.format("Slot %d: %s (%s)", slot, desiredLabel or "?", placeWhy))
                            end
                        end
                    else
                        skipped = skipped + 1
                        DebugPrint(string.format("Slot %d: skip (%s)", slot, why))
                    end
                end
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
