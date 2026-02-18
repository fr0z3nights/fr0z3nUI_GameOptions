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
local didEnsureRememberedMacros = false

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

local function GetCharSettings()
    InitSV()
    local s = rawget(_G, "AutoGame_CharSettings") or rawget(_G, "AutoGossip_CharSettings")
    if type(s) ~= "table" then
        return nil
    end
    return s
end

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

local function GetPlayerClassTag()
    if not UnitClass then
        return nil
    end
    local ok, _, classTag = pcall(UnitClass, "player")
    if not ok then
        return nil
    end
    if type(classTag) ~= "string" or classTag == "" then
        return nil
    end
    return classTag
end

local function Trim(s)
    if type(s) ~= "string" then
        return ""
    end
    return s:gsub("^%s+", ""):gsub("%s+$", "")
end

local function GetActiveLoadoutName()
    if not (C_ClassTalents and C_ClassTalents.GetActiveConfigID) then
        return nil
    end
    local okCfg, configID = pcall(C_ClassTalents.GetActiveConfigID)
    if not okCfg or type(configID) ~= "number" then
        return nil
    end
    if C_Traits and C_Traits.GetConfigInfo then
        local okInfo, info = pcall(C_Traits.GetConfigInfo, configID)
        if okInfo and type(info) == "table" then
            local name = Trim(info.name)
            if name ~= "" then
                return name
            end
        end
    end
    return nil
end

local function GetActiveLoadoutKey(classTag, specID)
    if not (classTag and specID) then
        return nil
    end
    local name = GetActiveLoadoutName()
    if not name then
        return nil
    end
    name = name:gsub("%s+", " ")
    return tostring(classTag) .. ":" .. tostring(specID) .. ":" .. tostring(name)
end

local function GetActiveLayout()
    local s = GetSettings()
    if type(s) ~= "table" then
        return nil
    end

    local function ScopeRank(scope)
        if scope == "account" then
            return 1
        end
        if scope == "class" then
            return 2
        end
        if scope == "spec" then
            return 3
        end
        if scope == "loadout" then
            return 4
        end
        return 0
    end

    local function NormalizeSlot180(slot)
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

    local function GetSharedLayoutForAccount()
        local t = rawget(s, "actionBarLayoutSharedAcc")
        if type(t) ~= "table" then
            return nil
        end
        return t
    end

    local function GetSharedLayoutForClass(classTag)
        if not classTag then
            return nil
        end
        local byClass = rawget(s, "actionBarLayoutByClassAcc")
        if type(byClass) ~= "table" then
            return nil
        end
        local t = byClass[classTag]
        if type(t) ~= "table" then
            return nil
        end
        return t
    end

    local function GetSharedLayoutForLoadout(loadoutKey)
        if not loadoutKey then
            return nil
        end
        local byLoadout = rawget(s, "actionBarLayoutByLoadoutAcc")
        if type(byLoadout) ~= "table" then
            return nil
        end
        local t = byLoadout[loadoutKey]
        if type(t) ~= "table" then
            return nil
        end
        return t
    end

    local function Combine4(sharedAccount, sharedClass, spec, loadout)
        if type(sharedAccount) ~= "table" and type(sharedClass) ~= "table" and type(spec) ~= "table" and type(loadout) ~= "table" then
            return nil
        end
        local out = {}
        local loadoutSlots, specSlots, classSlots = {}, {}, {}

        if type(loadout) == "table" then
            for _, e in ipairs(loadout) do
                local slot = NormalizeSlot180(e and e.slot)
                if slot then
                    loadoutSlots[slot] = true
                end
            end
        end

        if type(spec) == "table" then
            for _, e in ipairs(spec) do
                local slot = NormalizeSlot180(e and e.slot)
                if slot then
                    specSlots[slot] = true
                end
            end
        end

        if type(sharedClass) == "table" then
            for _, e in ipairs(sharedClass) do
                local slot = NormalizeSlot180(e and e.slot)
                if slot then
                    classSlots[slot] = true
                end
            end
        end

        if type(sharedAccount) == "table" then
            for _, e in ipairs(sharedAccount) do
                local slot = NormalizeSlot180(e and e.slot)
                if not slot or (not classSlots[slot] and not specSlots[slot] and not loadoutSlots[slot]) then
                    out[#out + 1] = { entry = e, scope = "account" }
                end
            end
        end

        if type(sharedClass) == "table" then
            for _, e in ipairs(sharedClass) do
                local slot = NormalizeSlot180(e and e.slot)
                if not slot or (not specSlots[slot] and not loadoutSlots[slot]) then
                    out[#out + 1] = { entry = e, scope = "class" }
                end
            end
        end

        if type(spec) == "table" then
            for _, e in ipairs(spec) do
                local slot = NormalizeSlot180(e and e.slot)
                if not slot or not loadoutSlots[slot] then
                    out[#out + 1] = { entry = e, scope = "spec" }
                end
            end
        end

        if type(loadout) == "table" then
            for _, e in ipairs(loadout) do
                out[#out + 1] = { entry = e, scope = "loadout" }
            end
        end

        return out
    end

    local specID = GetActiveSpecID()
    local bySpec = rawget(s, "actionBarLayoutBySpecAcc")
    local classTag = GetPlayerClassTag()
    local sharedAccount = GetSharedLayoutForAccount()
    local sharedClass = GetSharedLayoutForClass(classTag)
    local loadoutKey = (specID and classTag) and GetActiveLoadoutKey(classTag, specID) or nil
    local sharedLoadout = GetSharedLayoutForLoadout(loadoutKey)

    local highestScopeRankBySlot = {}

    local function ConsiderHighest(list, scope)
        if type(list) ~= "table" then
            return
        end
        local r = ScopeRank(scope)
        for _, e in ipairs(list) do
            local slot = NormalizeSlot180(e and e.slot)
            if slot then
                local prev = highestScopeRankBySlot[slot] or 0
                if r > prev then
                    highestScopeRankBySlot[slot] = r
                end
            end
        end
    end

    ConsiderHighest(sharedAccount, "account")
    ConsiderHighest(sharedClass, "class")
    if type(bySpec) == "table" and specID and type(bySpec[specID]) == "table" then
        ConsiderHighest(bySpec[specID], "spec")
    end
    ConsiderHighest(sharedLoadout, "loadout")

    if type(bySpec) == "table" and specID and type(bySpec[specID]) == "table" then
        return Combine4(sharedAccount, sharedClass, bySpec[specID], sharedLoadout), specID, highestScopeRankBySlot
    end

    local legacy = rawget(s, "actionBarLayoutAcc")
    if type(legacy) == "table" then
        ConsiderHighest(legacy, "spec")
        return Combine4(sharedAccount, sharedClass, legacy, sharedLoadout), nil, highestScopeRankBySlot
    end

    return nil
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

local allowOverwriteThisApply = false

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

local function NormalizeMacroBody(body)
    if type(body) ~= "string" then
        return ""
    end
    -- Macro bodies are sensitive; keep comparison mostly exact but normalize CRLF.
    body = body:gsub("\r\n", "\n")
    return body
end

local function GetMacroLimits()
    local maxAcc = tonumber(rawget(_G, "MAX_ACCOUNT_MACROS")) or 120
    local maxChar = tonumber(rawget(_G, "MAX_CHARACTER_MACROS")) or 18
    return maxAcc, maxChar
end

local function FindMacroVersionsByName(name)
    if type(name) ~= "string" or name == "" then
        return nil, nil
    end
    if not (GetMacroInfo and GetNumMacros) then
        return nil, nil
    end

    local maxAcc, maxChar = GetMacroLimits()
    local acc, char = nil, nil

    for i = 1, (maxAcc + maxChar) do
        local ok, n, icon, body = pcall(GetMacroInfo, i)
        if ok and n == name then
            local info = {
                index = i,
                icon = icon,
                body = NormalizeMacroBody(body),
            }
            if i > maxAcc then
                char = info
            else
                acc = info
            end
        end
    end

    return acc, char
end

local macroConflictQueue = {}
local macroConflictSeen = {}
local macroConflictPopup = nil

local function EnsureMacroConflictPopup()
    if macroConflictPopup and macroConflictPopup.Show then
        return macroConflictPopup
    end

    if not (CreateFrame and UIParent) then
        return nil
    end

    local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    f:SetSize(760, 520)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(200)
    f:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        tile = true,
        tileSize = 16,
    })
    f:SetBackdropColor(0, 0, 0, 0.92)
    f:Hide()

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -10)
    title:SetJustifyH("LEFT")
    title:SetText("Macro Conflict")
    f._title = title

    local leftLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    leftLabel:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    leftLabel:SetText("Saved (Account SV)")

    local rightLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rightLabel:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -44)
    rightLabel:SetText("Current (In-Game)")
    rightLabel:SetJustifyH("RIGHT")

    local boxW = 360
    local boxH = 380
    local topY = -66

    local function BuildScrollBox(anchorPoint, xOff)
        local sf = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        sf:SetPoint("TOPLEFT", f, "TOPLEFT", xOff, topY)
        sf:SetSize(boxW, boxH)

        local eb = CreateFrame("EditBox", nil, sf)
        eb:SetMultiLine(true)
        eb:SetAutoFocus(false)
        eb:SetFontObject(ChatFontNormal)
        eb:SetWidth(boxW - 28)
        eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        eb:EnableMouse(true)
        eb:SetText("")
        eb:HighlightText(0, 0)

        sf:SetScrollChild(eb)
        return sf, eb
    end

    local leftSF, leftEB = BuildScrollBox("TOPLEFT", 10)
    local rightSF, rightEB = BuildScrollBox("TOPLEFT", 390)
    f._leftEB = leftEB
    f._rightEB = rightEB

    local info = f:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    info:SetPoint("TOPLEFT", leftSF, "BOTTOMLEFT", 0, -8)
    info:SetPoint("TOPRIGHT", rightSF, "BOTTOMRIGHT", 0, -8)
    info:SetJustifyH("LEFT")
    info:SetText("Choose which one to keep. The kept version updates the character macro and the Account SV.")
    info:SetWordWrap(true)

    local btnKeepSaved = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    btnKeepSaved:SetSize(170, 22)
    btnKeepSaved:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 10)
    btnKeepSaved:SetText("Keep Saved")
    f._btnKeepSaved = btnKeepSaved

    local btnKeepCurrent = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    btnKeepCurrent:SetSize(170, 22)
    btnKeepCurrent:SetPoint("LEFT", btnKeepSaved, "RIGHT", 10, 0)
    btnKeepCurrent:SetText("Keep Current")
    f._btnKeepCurrent = btnKeepCurrent

    macroConflictPopup = f
    return f
end

local function ApplyMacroBodyToIndex(index, name, icon, body)
    if not (EditMacro and index and name) then
        return false
    end
    body = NormalizeMacroBody(body)
    local ok = pcall(EditMacro, index, name, icon, body)
    return ok and true or false
end

local TryCreateRememberedCharacterMacro

local function ResolveMacroConflict(conflict, keepWhich)
    if type(conflict) ~= "table" then
        return
    end
    local name = conflict.name
    if type(name) ~= "string" or name == "" then
        return
    end

    local chooseSaved = (keepWhich == "saved")
    local chosenIcon = chooseSaved and conflict.savedIcon or conflict.currentIcon
    local chosenBody = chooseSaved and conflict.savedBody or conflict.currentBody
    chosenBody = NormalizeMacroBody(chosenBody)

    local s = GetSettings()
    if type(s) ~= "table" then
        return
    end
    local t = rawget(s, "actionBarRememberMacrosAcc")
    if type(t) ~= "table" then
        t = {}
        s.actionBarRememberMacrosAcc = t
    end
    t[name] = { icon = chosenIcon, body = chosenBody }

    -- If the user chose to keep the current in-game macro, do not touch it.
    -- We only update the Account SV so the mismatch is resolved for future startups.
    if keepWhich == "current" then
        return
    end

    -- Sync in-game macro: update character macro; create it if missing.
    local _, char = FindMacroVersionsByName(name)
    local charIndex = char and char.index
    if not charIndex then
        local okCreate = TryCreateRememberedCharacterMacro(name)
        if okCreate then
            _, char = FindMacroVersionsByName(name)
            charIndex = char and char.index
        end
    end
    if charIndex then
        ApplyMacroBodyToIndex(charIndex, name, chosenIcon, chosenBody)
    end
end

local function ShowNextMacroConflict()
    if InCombat() then
        return
    end

    local conflict = macroConflictQueue[1]
    if not conflict then
        return
    end

    local f = EnsureMacroConflictPopup()
    if not f then
        return
    end

    f._title:SetText("Macro Conflict: " .. tostring(conflict.name or "?"))
    if f._leftEB and f._leftEB.SetText then
        f._leftEB:SetText(tostring(conflict.savedBody or ""))
        if f._leftEB.SetCursorPosition then
            f._leftEB:SetCursorPosition(0)
        end
    end
    if f._rightEB and f._rightEB.SetText then
        f._rightEB:SetText(tostring(conflict.currentBody or ""))
        if f._rightEB.SetCursorPosition then
            f._rightEB:SetCursorPosition(0)
        end
    end

    f._btnKeepSaved:SetScript("OnClick", function()
        ResolveMacroConflict(conflict, "saved")
        table.remove(macroConflictQueue, 1)
        f:Hide()
        if C_Timer and C_Timer.After then
            C_Timer.After(0, ShowNextMacroConflict)
        else
            ShowNextMacroConflict()
        end
    end)

    f._btnKeepCurrent:SetScript("OnClick", function()
        ResolveMacroConflict(conflict, "current")
        table.remove(macroConflictQueue, 1)
        f:Hide()
        if C_Timer and C_Timer.After then
            C_Timer.After(0, ShowNextMacroConflict)
        else
            ShowNextMacroConflict()
        end
    end)

    f:Show()
end

local function QueueMacroConflict(name, savedIcon, savedBody, currentIcon, currentBody)
    if type(name) ~= "string" or name == "" then
        return
    end
    local key = name .. ":" .. tostring(savedBody or "") .. ":" .. tostring(currentBody or "")
    if macroConflictSeen[key] then
        return
    end
    macroConflictSeen[key] = true

    macroConflictQueue[#macroConflictQueue + 1] = {
        name = name,
        savedIcon = savedIcon,
        savedBody = NormalizeMacroBody(savedBody),
        currentIcon = currentIcon,
        currentBody = NormalizeMacroBody(currentBody),
    }

    if C_Timer and C_Timer.After then
        C_Timer.After(0, ShowNextMacroConflict)
    end
end

TryCreateRememberedCharacterMacro = function(name)
    if type(name) ~= "string" or name == "" then
        return false, "bad-name"
    end
    if not CreateMacro then
        return false, "no-create-macro"
    end

    local s = GetSettings()
    if type(s) ~= "table" then
        return false, "no-settings"
    end

    local t = rawget(s, "actionBarRememberMacrosAcc")
    if type(t) ~= "table" then
        return false, "no-remember-table"
    end

    local info = t[name]
    if type(info) ~= "table" then
        return false, "not-remembered"
    end

    local body = rawget(info, "body")
    if type(body) ~= "string" then
        body = ""
    end

    local icon = rawget(info, "icon")
    if type(icon) ~= "number" and type(icon) ~= "string" then
        icon = "INV_MISC_QUESTIONMARK"
    end

    -- Create as character macro (not account).
    local ok, idx = pcall(CreateMacro, name, icon, NormalizeMacroBody(body), true)
    if not ok or not idx then
        return false, "create-failed"
    end
    return true, "created"
end

local function EnsureRememberedAccountMacrosOnce(reason)
    if didEnsureRememberedMacros then
        return
    end

    -- Only on login/reload style startup.
    if not (reason == "enable" or reason == "PLAYER_ENTERING_WORLD" or reason == "PLAYER_LOGIN" or reason == "VARIABLES_LOADED") then
        return
    end

    didEnsureRememberedMacros = true

    local s = GetSettings()
    if type(s) ~= "table" then
        return
    end

    local t = rawget(s, "actionBarRememberMacrosAcc")
    if type(t) ~= "table" then
        return
    end

    for name, info in pairs(t) do
        if type(name) == "string" and name ~= "" and type(info) == "table" then
            local savedBody = NormalizeMacroBody(rawget(info, "body"))
            local savedIcon = rawget(info, "icon")

            local _, char = FindMacroVersionsByName(name)
            if not (char and char.index) then
                TryCreateRememberedCharacterMacro(name)
                _, char = FindMacroVersionsByName(name)
            end

            -- Compare remembered (SV) vs current in-game CHARACTER macro only.
            if char and NormalizeMacroBody(char.body) ~= savedBody then
                QueueMacroConflict(name, savedIcon, savedBody, char.icon, char.body)
            end
        end
    end
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

local function CanPlaceIntoSlot(slot, desiredKind, desiredId, entryAlwaysOverwrite, entryScopeRank, highestScopeRankForSlot)
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

    if allowOverwriteThisApply or GetBoolSetting("actionBarOverwriteAcc", false) then
        return true, "overwrite"
    end

    if entryAlwaysOverwrite then
        local highest = tonumber(highestScopeRankForSlot) or 0
        local mine = tonumber(entryScopeRank) or 0
        if highest > mine then
            return false, "protected"
        end
        return true, "always"
    end

    return false, "occupied"
end

local function GetSpecKeyForSV(specID)
    specID = tonumber(specID)
    if not specID then
        return "0"
    end
    specID = math.floor(specID)
    if specID < 0 then
        specID = 0
    end
    return tostring(specID)
end

local function ShouldUseOneTimeOverwrite(specID)
    if GetBoolSetting("actionBarOverwriteAcc", false) then
        return false
    end

    local cs = GetCharSettings()
    if not cs then
        return false
    end

    if type(cs.actionBarDidInitialApplyBySpec) ~= "table" then
        cs.actionBarDidInitialApplyBySpec = {}
    end

    local k = GetSpecKeyForSV(specID)
    return not (cs.actionBarDidInitialApplyBySpec[k] and true or false)
end

local function MarkInitialApplyDone(specID)
    local cs = GetCharSettings()
    if not cs then
        return
    end
    if type(cs.actionBarDidInitialApplyBySpec) ~= "table" then
        cs.actionBarDidInitialApplyBySpec = {}
    end
    local k = GetSpecKeyForSV(specID)
    cs.actionBarDidInitialApplyBySpec[k] = true
end

local function GetForceOverwriteFlag(specID)
    local cs = GetCharSettings()
    if not cs then
        return false
    end

    if cs.actionBarForceOverwriteNextApply then
        return true
    end

    local t = rawget(cs, "actionBarForceOverwriteNextApplyBySpec")
    if type(t) ~= "table" then
        return false
    end
    local k = GetSpecKeyForSV(specID)
    return (t[k] and true or false)
end

local function ClearForceOverwriteFlag(specID)
    local cs = GetCharSettings()
    if not cs then
        return
    end

    cs.actionBarForceOverwriteNextApply = false

    local t = rawget(cs, "actionBarForceOverwriteNextApplyBySpec")
    if type(t) ~= "table" then
        return
    end
    local k = GetSpecKeyForSV(specID)
    t[k] = nil
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

local function ClearSlot(slot)
    if not (PickupAction and ClearCursor) then
        return false
    end
    local ok = pcall(PickupAction, slot)
    ClearCursor()
    return ok and true or false
end

local function ClearOtherSlotsForAction(desiredKind, desiredId, keepSlot)
    if not (GetActionInfo and desiredKind and desiredId and keepSlot) then
        return 0
    end
    desiredId = tonumber(desiredId)
    if not desiredId then
        return 0
    end
    keepSlot = tonumber(keepSlot)
    if not keepSlot then
        return 0
    end

    local cleared = 0
    for slot = 1, 180 do
        if slot ~= keepSlot then
            local t, id = GetActionInfo(slot)
            if t == desiredKind and tonumber(id) == desiredId then
                if ClearSlot(slot) then
                    cleared = cleared + 1
                end
            end
        end
    end
    return cleared
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

    local specID = GetActiveSpecID()
    local forceOverwrite = GetForceOverwriteFlag(specID)
    local oneTimeOverwrite = forceOverwrite or ShouldUseOneTimeOverwrite(specID)
    allowOverwriteThisApply = oneTimeOverwrite or GetBoolSetting("actionBarOverwriteAcc", false)

    -- Remembered character macros: ensure character macros exist on initial login/reload only.
    EnsureRememberedAccountMacrosOnce(reason)

    local layout, _, highestScopeRankBySlot = GetActiveLayout()
    if not layout then
        return
    end

    local placed = 0
    local skipped = 0

    local function ScopeRankForRow(row)
        if not row then
            return 0
        end
        local scope = row.scope
        if scope == "account" then
            return 1
        end
        if scope == "class" then
            return 2
        end
        if scope == "spec" then
            return 3
        end
        if scope == "loadout" then
            return 4
        end
        return 0
    end

    for _, row in ipairs(layout) do
        local entry = row and row.entry or nil
        local slot = NormalizeSlot(entry and entry.slot)
        if slot then
            local kind = GetEntryKind(entry)
            local entryAlways = (entry and entry.alwaysOverwrite and true or false)
            local entryRank = ScopeRankForRow(row)
            local highestRankForSlot = (type(highestScopeRankBySlot) == "table") and highestScopeRankBySlot[slot] or nil

            local desiredId = nil
            local desiredLabel = nil
            if kind == "spell" then
                desiredId = ResolveSpellID(entry)
                desiredLabel = tostring(entry and (entry.spell or entry.spellID or entry.name) or "?")
                if not desiredId then
                    skipped = skipped + 1
                    DebugPrint(string.format("Slot %d: spell '%s' (missing)", slot, desiredLabel))
                else
                    local okSlot, why = CanPlaceIntoSlot(slot, "spell", desiredId, entryAlways, entryRank, highestRankForSlot)
                    if okSlot then
                        local placedOrAlready = false
                        if why == "already" then
                            skipped = skipped + 1
                            placedOrAlready = true
                        else
                            local okPlace, placeWhy = PlaceIntoSlot("spell", desiredId, slot)
                            if okPlace then
                                placed = placed + 1
                                placedOrAlready = true
                            else
                                skipped = skipped + 1
                                DebugPrint(string.format("Slot %d: spell %s (%s)", slot, tostring(desiredId), placeWhy))
                            end
                        end

                        if placedOrAlready and (entry and entry.clearElsewhere and true or false) then
                            local t, id = GetActionInfo(slot)
                            if t == "spell" and tonumber(id) == tonumber(desiredId) then
                                ClearOtherSlotsForAction("spell", desiredId, slot)
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
                    local okSlot, why = CanPlaceIntoSlot(slot, "macro", macroIndex, entryAlways, entryRank, highestRankForSlot)
                    if okSlot then
                        local placedOrAlready = false
                        if why == "already" then
                            skipped = skipped + 1
                            placedOrAlready = true
                        else
                            local okPlace, placeWhy = PlaceIntoSlot("macro", macroIndex, slot)
                            if okPlace then
                                placed = placed + 1
                                placedOrAlready = true
                            else
                                skipped = skipped + 1
                                DebugPrint(string.format("Slot %d: %s (%s)", slot, desiredLabel or "?", placeWhy))
                            end
                        end

                        if placedOrAlready and (entry and entry.clearElsewhere and true or false) then
                            local t, id = GetActionInfo(slot)
                            if t == "macro" and tonumber(id) == tonumber(macroIndex) then
                                ClearOtherSlotsForAction("macro", macroIndex, slot)
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

    if oneTimeOverwrite and placed > 0 then
        MarkInitialApplyDone(specID)
        if forceOverwrite then
            ClearForceOverwriteFlag(specID)
            DebugPrint("Forced apply complete; force flag cleared")
        else
            DebugPrint("Initial apply complete; one-time overwrite disabled for this spec")
        end
    end

    allowOverwriteThisApply = false

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
        -- If we queued macro conflict popups during combat, show them now.
        if C_Timer and C_Timer.After then
            C_Timer.After(0, function()
                if type(ShowNextMacroConflict) == "function" then
                    ShowNextMacroConflict()
                end
            end)
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
        -- Talent/loadout changes (Retail). Safe to register even if never fires.
        eventFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
        eventFrame:RegisterEvent("TRAIT_CONFIG_LIST_UPDATED")
        eventFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
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
