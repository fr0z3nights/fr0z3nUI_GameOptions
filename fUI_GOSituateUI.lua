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

local function GetActiveLoadoutKey()
    local classTag = GetPlayerClassTag()
    local specID = GetActiveSpecID()
    local name = GetActiveLoadoutName()
    if not (classTag and specID and name) then
        return nil
    end
    name = name:gsub("%s+", " ")
    return tostring(classTag) .. ":" .. tostring(specID) .. ":" .. tostring(name)
end

local function GetActiveSpecLabel()
    if not (GetSpecialization and GetSpecializationInfo) then
        return nil
    end
    local specIndex = GetSpecialization()
    if not specIndex then
        return nil
    end

    local ok, specID, specName = pcall(GetSpecializationInfo, specIndex)
    if not ok then
        return nil
    end
    if type(specID) ~= "number" then
        return nil
    end
    if type(specName) ~= "string" or specName == "" then
        specName = "Spec"
    end
    return specName .. " (" .. tostring(specID) .. ")"
end

local function EnsureLayoutArray()
    InitSV()
    local s = GetSettings()
    if not s then
        return {}
    end

    local specID = GetActiveSpecID()
    if specID then
        if type(s.actionBarLayoutBySpecAcc) ~= "table" then
            s.actionBarLayoutBySpecAcc = {}
        end
        if type(s.actionBarLayoutBySpecAcc[specID]) ~= "table" then
            s.actionBarLayoutBySpecAcc[specID] = {}
        end
        local t = s.actionBarLayoutBySpecAcc[specID]
        if t[1] == nil and next(t) ~= nil then
            s.actionBarLayoutBySpecAcc[specID] = {}
        end
        return s.actionBarLayoutBySpecAcc[specID]
    end

    -- Fallback (no spec API): legacy global layout.
    if type(s.actionBarLayoutAcc) ~= "table" then
        s.actionBarLayoutAcc = {}
    end
    if s.actionBarLayoutAcc[1] == nil and next(s.actionBarLayoutAcc) ~= nil then
        s.actionBarLayoutAcc = {}
    end
    return s.actionBarLayoutAcc
end

local function EnsureSharedClassLayoutArray()
    InitSV()
    local s = GetSettings()
    if not s then
        return {}
    end
    local classTag = GetPlayerClassTag() or "UNKNOWN"
    if type(s.actionBarLayoutByClassAcc) ~= "table" then
        s.actionBarLayoutByClassAcc = {}
    end
    if type(s.actionBarLayoutByClassAcc[classTag]) ~= "table" then
        s.actionBarLayoutByClassAcc[classTag] = {}
    end
    local t = s.actionBarLayoutByClassAcc[classTag]
    if t[1] == nil and next(t) ~= nil then
        s.actionBarLayoutByClassAcc[classTag] = {}
    end
    return s.actionBarLayoutByClassAcc[classTag]
end

local function EnsureSharedAccountLayoutArray()
    InitSV()
    local s = GetSettings()
    if not s then
        return {}
    end
    if type(s.actionBarLayoutSharedAcc) ~= "table" then
        s.actionBarLayoutSharedAcc = {}
    end
    local t = s.actionBarLayoutSharedAcc
    if t[1] == nil and next(t) ~= nil then
        s.actionBarLayoutSharedAcc = {}
    end
    return s.actionBarLayoutSharedAcc
end

local function EnsureLoadoutLayoutArray()
    InitSV()
    local s = GetSettings()
    if not s then
        return {}
    end
    local key = GetActiveLoadoutKey()
    if not key then
        return {}
    end
    if type(s.actionBarLayoutByLoadoutAcc) ~= "table" then
        s.actionBarLayoutByLoadoutAcc = {}
    end
    if type(s.actionBarLayoutByLoadoutAcc[key]) ~= "table" then
        s.actionBarLayoutByLoadoutAcc[key] = {}
    end
    local t = s.actionBarLayoutByLoadoutAcc[key]
    if t[1] == nil and next(t) ~= nil then
        s.actionBarLayoutByLoadoutAcc[key] = {}
    end
    return s.actionBarLayoutByLoadoutAcc[key]
end

local function GetSharedClassLayoutArrayReadOnly()
    InitSV()
    local s = GetSettings()
    if not s then
        return nil
    end
    local classTag = GetPlayerClassTag() or "UNKNOWN"
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

local function GetLayoutArrayReadOnlyBySpec(specID)
    InitSV()
    local s = GetSettings()
    if not s then
        return nil
    end
    if not specID then
        local legacy = rawget(s, "actionBarLayoutAcc")
        if type(legacy) ~= "table" then
            return nil
        end
        return legacy
    end
    local bySpec = rawget(s, "actionBarLayoutBySpecAcc")
    if type(bySpec) ~= "table" then
        return nil
    end
    local t = bySpec[specID]
    if type(t) ~= "table" then
        return nil
    end
    return t
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

local function SetAcc2StateText(btn, label, enabled)
    if enabled then
        btn:SetText(label .. ": |cff00ccffON ACC|r")
    else
        btn:SetText(label .. ": |cffff0000OFF ACC|r")
    end
end

local function SetAcc2StateTextYellow(btn, label, enabled)
    if enabled then
        btn:SetText(label .. ": |cffffff00ON ACC|r")
    else
        btn:SetText(label .. ": |cff888888OFF ACC|r")
    end
end

local function SetEnableOnlyText(btn, enabled)
    if enabled then
        btn:SetText("|cffffff00Enable|r")
    else
        btn:SetText("|cff888888Enable|r")
    end
end

local function SetStateTextYellowNoOff(btn, label, enabled)
    if enabled then
        btn:SetText(label .. ": |cffffff00ON|r")
    else
        btn:SetText("|cff888888" .. label .. "|r")
    end
end

local function SetAlwaysText(btn, enabled)
    if enabled then
        btn:SetText("|cffffff00Always|r")
    else
        btn:SetText("|cff888888Always|r")
    end
end

local function SetClearText(btn, enabled)
    if enabled then
        btn:SetText("|cffffff00Clear|r")
    else
        btn:SetText("|cff888888Clear|r")
    end
end

local function SetRemoveText(btn, enabled)
    if enabled then
        btn:SetText("|cffffff00Remove|r")
    else
        btn:SetText("|cff888888Remove|r")
    end
end

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

local function SafeMacroIndexByName(name)
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

local function Trim(s)
    if type(s) ~= "string" then
        return ""
    end
    return s:gsub("^%s+", ""):gsub("%s+$", "")
end

local function GetSpellIDFromText(text)
    text = Trim(text)
    if text == "" then
        return nil
    end
    local n = tonumber(text)
    if n then
        n = math.floor(n)
        if n > 0 then
            return n
        end
    end
    if GetSpellInfo then
        local ok, _, _, _, _, _, id = pcall(GetSpellInfo, text)
        if ok and type(id) == "number" and id > 0 then
            return id
        end
    end
    return nil
end

local function GetEntryKind(entry)
    local k = entry and entry.kind
    if k == "spell" or k == "macro" then
        return k
    end
    return "macro"
end

local function FindActionSlotFromFocus(focus)
    local function TryGetSlot(obj)
        if not obj then
            return nil
        end

        if obj.GetAction then
            local ok, a = pcall(obj.GetAction, obj)
            if ok and type(a) == "number" then
                return a
            end
        end

        if obj.GetActionID then
            local ok, a = pcall(obj.GetActionID, obj)
            if ok and type(a) == "number" then
                return a
            end
        end

        if obj.GetActionId then
            local ok, a = pcall(obj.GetActionId, obj)
            if ok and type(a) == "number" then
                return a
            end
        end

        if obj.GetAttribute then
            local a = obj:GetAttribute("action")
            if type(a) == "number" then
                return a
            end
            if type(a) == "string" then
                local n = tonumber(a)
                if n then
                    return n
                end
            end

            local a2 = obj:GetAttribute("actionID") or obj:GetAttribute("actionId") or obj:GetAttribute("actionid")
            if type(a2) == "number" then
                return a2
            end
            if type(a2) == "string" then
                local n = tonumber(a2)
                if n then
                    return n
                end
            end

            local page = obj:GetAttribute("actionpage") or obj:GetAttribute("actionPage") or obj:GetAttribute("state-page") or obj:GetAttribute("page")
            local btn = obj:GetAttribute("button") or obj:GetAttribute("btn")
            page = tonumber(page)
            btn = tonumber(btn)
            if not btn and obj.GetID then
                local ok, id = pcall(obj.GetID, obj)
                if ok then
                    btn = tonumber(id)
                end
            end
            if page and btn and page > 0 and btn > 0 and btn <= 12 then
                return ((page - 1) * 12) + btn
            end
        end

        if type(obj.action) == "number" then
            return obj.action
        end

        if obj.GetPagedID then
            local ok, id = pcall(obj.GetPagedID, obj)
            if ok and type(id) == "number" then
                return id
            end
        end

        if ActionButton_CalculateAction then
            local ok, id = pcall(ActionButton_CalculateAction, obj)
            if ok and type(id) == "number" then
                return id
            end
        end

        return nil
    end

    local obj = focus
    for _ = 1, 8 do
        local slot = TryGetSlot(obj)
        if slot then
            return slot
        end
        if not (obj and obj.GetParent) then
            break
        end
        obj = obj:GetParent()
    end
    return nil
end

-- Optional helper used by the Toggles tab (kept for backward compatibility).
function ns.ActionBarUI_CreateToggleButton(parent, anchorButton, gapY, btnW, btnH)
    if not (CreateFrame and parent) then
        return nil, function() end
    end

    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(btnW or 260, btnH or 22)
    if anchorButton then
        btn:SetPoint("TOP", anchorButton, "BOTTOM", 0, -(gapY or 10))
    else
        btn:SetPoint("TOP", parent, "TOP", 0, -64)
    end

    local function Update()
        InitSV()
        local on = GetBoolSetting("actionBarEnabledAcc", false)
        SetAcc2StateText(btn, "Situate", on)
    end

    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:SetScript("OnClick", function(_, mouseButton)
        InitSV()
        local s = GetSettings()
        if not s then
            return
        end
        if mouseButton == "RightButton" then
            if ns and ns.ActionBar_ApplyNow then
                ns.ActionBar_ApplyNow("manual")
            end
            return
        end
        s.actionBarEnabledAcc = not (s.actionBarEnabledAcc and true or false)
        if ns and ns.ApplyActionBarSetting then
            ns.ApplyActionBarSetting(true)
        end
        Update()
    end)

    Update()
    return btn, Update
end

function ns.SituateUI_Build(panel)
    if not (panel and CreateFrame) then
        return function() end
    end

    InitSV()

    local selectedIndex = nil -- index into displayRows
    local isLoadingFields = false

    local displayRows = {}
    local barExpanded = {}
    local slotExpanded = {}
    for b = 1, 15 do
        barExpanded[b] = true
    end

    -- The list always shows the effective merged layout.
    -- This setting controls where Add/Override writes entries.
    local targetScope = "spec" -- "spec" | "loadout" | "class" | "account"

    -- Secondary scope under Account.
    -- Two toggles controlled by small buttons shown only when Target=Account:
    -- - Expansion: if ON, writes to Account(Expansion)
    -- - Profession: if ON, writes to Account(Expansion+Profession)
    --   (Profession implies Expansion; turning Expansion off also turns Profession off.)
    local accountExpansionOn = false
    local accountProfessionOn = false
    local targetProfessionKey = nil -- only meaningful when accountProfessionOn == true

    local viewSpecIndex = nil -- nil => active spec
    local specList = nil
    local function BuildSpecList()
        if specList ~= nil then
            return specList
        end
        specList = {}
        if not (GetNumSpecializations and GetSpecializationInfo) then
            return specList
        end
        local n = GetNumSpecializations() or 0
        for i = 1, n do
            local ok, specID, specName = pcall(GetSpecializationInfo, i)
            if ok and type(specID) == "number" then
                specList[#specList + 1] = { id = specID, name = (type(specName) == "string" and specName ~= "") and specName or ("Spec " .. tostring(i)) }
            end
        end
        return specList
    end

    local function GetActiveSpecIndexInList(activeSpecID)
        local list = BuildSpecList()
        for i = 1, #list do
            if list[i].id == activeSpecID then
                return i
            end
        end
        return nil
    end

    local function GetViewingSpecID()
        local activeSpecID = GetActiveSpecID()
        if not activeSpecID then
            return nil
        end
        if not viewSpecIndex then
            return activeSpecID
        end
        local list = BuildSpecList()
        local e = list[viewSpecIndex]
        if e and type(e.id) == "number" then
            return e.id
        end
        return activeSpecID
    end

    local function IsViewingActiveSpec()
        local activeSpecID = GetActiveSpecID()
        if not activeSpecID then
            return true
        end
        return (GetViewingSpecID() == activeSpecID) and true or false
    end

    local GetCurrentZoneMapID
    local GetCurrentExpansionKey
    local GetKnownProfessionKeys

    local function EnsureTargetProfessionKey()
        local profs = (type(GetKnownProfessionKeys) == "function") and GetKnownProfessionKeys() or nil
        if type(profs) ~= "table" or #profs == 0 then
            targetProfessionKey = nil
            return nil
        end

        if not targetProfessionKey then
            targetProfessionKey = profs[1]
            return targetProfessionKey
        end

        for i = 1, #profs do
            if profs[i] == targetProfessionKey then
                return targetProfessionKey
            end
        end

        targetProfessionKey = profs[1]
        return targetProfessionKey
    end

    local function CanEditTarget()
        if targetScope == "class" then
            return true
        end
        if targetScope == "account" then
            if not accountExpansionOn then
                return true
            end

            local expKey = GetCurrentExpansionKey and GetCurrentExpansionKey() or nil
            if not expKey then
                return false
            end

            if not accountProfessionOn then
                return true
            end

            return (EnsureTargetProfessionKey() ~= nil)
        end
        if targetScope == "loadout" then
            return IsViewingActiveSpec() and (GetActiveLoadoutKey() ~= nil)
        end
        -- spec target: allow editing the currently viewed spec
        return true
    end

    local function CanEditScope(scope)
        if scope == "account" or scope == "class" then
            return true
        end
        if scope == "expansion" then
            return (GetCurrentExpansionKey and GetCurrentExpansionKey() ~= nil)
        end
        if scope == "profession" then
            local expKey = GetCurrentExpansionKey and GetCurrentExpansionKey() or nil
            if not expKey then
                return false
            end
            return (EnsureTargetProfessionKey() ~= nil)
        end
        if scope == "zone" then
            return (GetCurrentZoneMapID() ~= nil)
        end
        if scope == "loadout" then
            return IsViewingActiveSpec() and (GetActiveLoadoutKey() ~= nil)
        end
        -- spec scope: allow editing the currently viewed spec
        return true
    end

    local function GetZoneLabel(mapID)
        mapID = tonumber(mapID)
        if mapID and mapID > 0 and C_Map and type(C_Map.GetMapInfo) == "function" then
            local ok, info = pcall(C_Map.GetMapInfo, mapID)
            if ok and type(info) == "table" then
                local name = Trim(info.name or "")
                if name ~= "" then
                    return name
                end
            end
        end
        return mapID and ("Map " .. tostring(mapID)) or "Unknown"
    end

    GetCurrentZoneMapID = function()
        if not (C_Map and type(C_Map.GetBestMapForUnit) == "function") then
            return nil
        end

        local ok, mapID = pcall(C_Map.GetBestMapForUnit, "player")
        if not ok or type(mapID) ~= "number" or mapID <= 0 then
            return nil
        end

        -- Group open-world zones by their Continent/expansion landmass where possible
        -- (e.g., Dragon Isles / Khaz Algar). Keep dungeons/instances specific.
        if C_Map.GetMapInfo and Enum and Enum.UIMapType then
            local cur = mapID
            for _ = 1, 12 do
                local okInfo, info = pcall(C_Map.GetMapInfo, cur)
                if not okInfo or type(info) ~= "table" then
                    break
                end

                local mapType = info.mapType
                local parent = tonumber(info.parentMapID) or 0

                if mapType == Enum.UIMapType.Dungeon then
                    return cur
                end
                if mapType == Enum.UIMapType.Continent then
                    return cur
                end
                if not parent or parent <= 0 then
                    break
                end
                cur = parent
            end
        end

        return mapID
    end

    local function GetExpansionLabel(expansionKey)
        expansionKey = tostring(expansionKey or "")
        if expansionKey == "easternkingdoms" then
            return "Eastern Kingdoms"
        end
        if expansionKey == "kalimdor" then
            return "Kalimdor"
        end
        if expansionKey == "outland" then
            return "Outland"
        end
        if expansionKey == "northrend" then
            return "Northrend"
        end
        if expansionKey == "pandaria" then
            return "Pandaria"
        end
        if expansionKey == "draenor" then
            return "Draenor"
        end
        if expansionKey == "brokenisles" then
            return "Broken Isles"
        end
        if expansionKey == "kultiras" then
            return "Kul Tiras"
        end
        if expansionKey == "zandalar" then
            return "Zandalar"
        end
        if expansionKey == "shadowlands" then
            return "Shadowlands"
        end
        if expansionKey == "dragonisles" then
            return "Dragon Isles"
        end
        if expansionKey == "khazalgar" then
            return "Khaz Algar"
        end
        if expansionKey == "midnight" then
            return "Midnight"
        end
        return expansionKey ~= "" and expansionKey or "Unknown"
    end

    GetCurrentExpansionKey = function()
        if not (C_Map and type(C_Map.GetBestMapForUnit) == "function") then
            return nil
        end

        local ok, mapID = pcall(C_Map.GetBestMapForUnit, "player")
        if not ok or type(mapID) ~= "number" or mapID <= 0 then
            return nil
        end

        if C_Map.GetMapInfo and Enum and Enum.UIMapType then
            local cur = mapID
            for _ = 1, 12 do
                local okInfo, info = pcall(C_Map.GetMapInfo, cur)
                if not okInfo or type(info) ~= "table" then
                    break
                end

                local mapType = info.mapType
                local parent = tonumber(info.parentMapID) or 0

                if mapType == Enum.UIMapType.Continent then
                    local name = tostring(info.name or "")
                    local low = name:lower()
                    if low:find("eastern kingdoms", 1, true) then
                        return "easternkingdoms"
                    end
                    if low:find("kalimdor", 1, true) then
                        return "kalimdor"
                    end
                    if low:find("outland", 1, true) then
                        return "outland"
                    end
                    if low:find("northrend", 1, true) then
                        return "northrend"
                    end
                    if low:find("pandaria", 1, true) then
                        return "pandaria"
                    end
                    if low:find("draenor", 1, true) then
                        return "draenor"
                    end
                    if low:find("broken isles", 1, true) then
                        return "brokenisles"
                    end
                    if low:find("kul tiras", 1, true) then
                        return "kultiras"
                    end
                    if low:find("zandalar", 1, true) then
                        return "zandalar"
                    end
                    if low:find("shadowlands", 1, true) then
                        return "shadowlands"
                    end
                    if low:find("dragon isles", 1, true) then
                        return "dragonisles"
                    end
                    if low:find("khaz algar", 1, true) then
                        return "khazalgar"
                    end
                    if low:find("midnight", 1, true) then
                        return "midnight"
                    end
                    return nil
                end

                if not parent or parent <= 0 then
                    break
                end
                cur = parent
            end
        end

        return nil
    end

    local function SpellKnownAny(list)
        if type(list) ~= "table" then
            return false
        end
        for i = 1, #list do
            local sid = tonumber(list[i])
            if sid and sid > 0 then
                if IsSpellKnown then
                    local ok, known = pcall(IsSpellKnown, sid)
                    if ok and known then
                        return true
                    end
                end
                if IsPlayerSpell then
                    local ok, known = pcall(IsPlayerSpell, sid)
                    if ok and known then
                        return true
                    end
                end
            end
        end
        return false
    end

    local PROF_SPELLS = {
        Mining = { 2575, 265757, 265840, 265841, 265843, 265844, 265845, 265846, 265847, 265848, 265849, 309325, 374627, 433321, 471013 },
        Herbalism = { 2366, 265825, 265756, 265819, 265820, 265821, 265822, 265823, 265824, 265826, 309312, 374626, 433320, 471012 },
        Skinning = { 8613, 265861, 265761, 265869, 265870, 265871, 265872, 265873, 265874, 265875, 265876, 309318, 374633, 433327, 471019 },
    }

    -- Prefer the professions API so the Profession button works for crafting professions too.
    -- We store keys as strings; when possible, use canonical English keys derived from skillLine.
    local SKILLLINE_TO_PROFKEY = {
        [171] = "Alchemy",
        [164] = "Blacksmithing",
        [333] = "Enchanting",
        [202] = "Engineering",
        [182] = "Herbalism",
        [773] = "Inscription",
        [755] = "Jewelcrafting",
        [165] = "Leatherworking",
        [186] = "Mining",
        [393] = "Skinning",
        [197] = "Tailoring",
    }

    local function AddUniqueKey(out, key)
        key = Trim(tostring(key or ""))
        if key == "" then
            return
        end
        for i = 1, #out do
            if out[i] == key then
                return
            end
        end
        out[#out + 1] = key
    end

    GetKnownProfessionKeys = function()
        local out = {}

        if type(GetProfessions) == "function" and type(GetProfessionInfo) == "function" then
            local p1, p2 = GetProfessions()
            local indices = { p1, p2 }
            for i = 1, #indices do
                local idx = indices[i]
                if idx then
                    local ok, name, _, _, _, _, skillLine = pcall(GetProfessionInfo, idx)
                    if ok then
                        local key = SKILLLINE_TO_PROFKEY[tonumber(skillLine or 0)] or Trim(tostring(name or ""))
                        AddUniqueKey(out, key)
                    end
                end
            end

            if #out > 1 then
                table.sort(out, function(a, b) return tostring(a):lower() < tostring(b):lower() end)
            end
            if #out > 0 then
                return out
            end
        end

        -- Fallback: spell-based detection (gathering only) for very old clients / API breakage.
        if SpellKnownAny(PROF_SPELLS.Mining) then AddUniqueKey(out, "Mining") end
        if SpellKnownAny(PROF_SPELLS.Herbalism) then AddUniqueKey(out, "Herbalism") end
        if SpellKnownAny(PROF_SPELLS.Skinning) then AddUniqueKey(out, "Skinning") end
        return out
    end

    local function EnsureExpansionLayoutArray(expansionKey)
        expansionKey = tostring(expansionKey or "")
        if expansionKey == "" then
            return {}
        end
        InitSV()
        local s = GetSettings()
        if not s then
            return {}
        end
        if type(s.actionBarLayoutByExpansionAcc) ~= "table" then
            s.actionBarLayoutByExpansionAcc = {}
        end
        if type(s.actionBarLayoutByExpansionAcc[expansionKey]) ~= "table" then
            s.actionBarLayoutByExpansionAcc[expansionKey] = {}
        end
        local t = s.actionBarLayoutByExpansionAcc[expansionKey]
        if t[1] == nil and next(t) ~= nil then
            s.actionBarLayoutByExpansionAcc[expansionKey] = {}
        end
        return s.actionBarLayoutByExpansionAcc[expansionKey]
    end

    local function GetExpansionLayoutArrayReadOnly(expansionKey)
        expansionKey = tostring(expansionKey or "")
        if expansionKey == "" then
            return nil
        end
        InitSV()
        local s = GetSettings()
        if not s then
            return nil
        end
        local byExp = rawget(s, "actionBarLayoutByExpansionAcc")
        if type(byExp) ~= "table" then
            return nil
        end
        local t = byExp[expansionKey]
        if type(t) ~= "table" then
            return nil
        end
        return t
    end

    local function EnsureExpansionProfessionLayoutArray(expansionKey, professionKey)
        expansionKey = tostring(expansionKey or "")
        professionKey = tostring(professionKey or "")
        if expansionKey == "" or professionKey == "" then
            return {}
        end
        InitSV()
        local s = GetSettings()
        if not s then
            return {}
        end
        if type(s.actionBarLayoutByExpansionProfessionAcc) ~= "table" then
            s.actionBarLayoutByExpansionProfessionAcc = {}
        end
        if type(s.actionBarLayoutByExpansionProfessionAcc[expansionKey]) ~= "table" then
            s.actionBarLayoutByExpansionProfessionAcc[expansionKey] = {}
        end
        local byProf = s.actionBarLayoutByExpansionProfessionAcc[expansionKey]
        if type(byProf[professionKey]) ~= "table" then
            byProf[professionKey] = {}
        end
        local t = byProf[professionKey]
        if t[1] == nil and next(t) ~= nil then
            byProf[professionKey] = {}
        end
        return byProf[professionKey]
    end

    local function GetExpansionProfessionLayoutArrayReadOnly(expansionKey, professionKey)
        expansionKey = tostring(expansionKey or "")
        professionKey = tostring(professionKey or "")
        if expansionKey == "" or professionKey == "" then
            return nil
        end
        InitSV()
        local s = GetSettings()
        if not s then
            return nil
        end
        local byExp = rawget(s, "actionBarLayoutByExpansionProfessionAcc")
        if type(byExp) ~= "table" then
            return nil
        end
        local byProf = byExp[expansionKey]
        if type(byProf) ~= "table" then
            return nil
        end
        local t = byProf[professionKey]
        if type(t) ~= "table" then
            return nil
        end
        return t
    end

    local function EnsureZoneLayoutArray(mapID)
        mapID = tonumber(mapID)
        if not mapID or mapID <= 0 then
            return {}
        end
        InitSV()
        local s = GetSettings()
        if not s then
            return {}
        end
        if type(s.actionBarLayoutByZoneAcc) ~= "table" then
            s.actionBarLayoutByZoneAcc = {}
        end
        if type(s.actionBarLayoutByZoneAcc[mapID]) ~= "table" then
            s.actionBarLayoutByZoneAcc[mapID] = {}
        end
        local t = s.actionBarLayoutByZoneAcc[mapID]
        if t[1] == nil and next(t) ~= nil then
            s.actionBarLayoutByZoneAcc[mapID] = {}
        end
        return s.actionBarLayoutByZoneAcc[mapID]
    end

    local function GetZoneLayoutArrayReadOnly(mapID)
        mapID = tonumber(mapID)
        if not mapID or mapID <= 0 then
            return nil
        end
        InitSV()
        local s = GetSettings()
        if not s then
            return nil
        end
        local byZone = rawget(s, "actionBarLayoutByZoneAcc")
        if type(byZone) ~= "table" then
            return nil
        end
        local t = byZone[mapID]
        if type(t) ~= "table" then
            return nil
        end
        return t
    end

    local function GetSharedAccountLayoutArrayReadOnly()
        InitSV()
        local s = GetSettings()
        if not s then
            return nil
        end
        local t = rawget(s, "actionBarLayoutSharedAcc")
        if type(t) ~= "table" then
            return nil
        end
        return t
    end

    local function GetLoadoutLayoutArrayReadOnly(loadoutKey)
        InitSV()
        local s = GetSettings()
        if not s then
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

    local function EnsureSpecLayoutArrayFor(specID)
        InitSV()
        local s = GetSettings()
        if not s then
            return {}
        end

        if specID then
            if type(s.actionBarLayoutBySpecAcc) ~= "table" then
                s.actionBarLayoutBySpecAcc = {}
            end
            if type(s.actionBarLayoutBySpecAcc[specID]) ~= "table" then
                s.actionBarLayoutBySpecAcc[specID] = {}
            end
            local t = s.actionBarLayoutBySpecAcc[specID]
            if t[1] == nil and next(t) ~= nil then
                s.actionBarLayoutBySpecAcc[specID] = {}
            end
            return s.actionBarLayoutBySpecAcc[specID]
        end

        -- Fallback (no spec API): legacy global layout.
        if type(s.actionBarLayoutAcc) ~= "table" then
            s.actionBarLayoutAcc = {}
        end
        if s.actionBarLayoutAcc[1] == nil and next(s.actionBarLayoutAcc) ~= nil then
            s.actionBarLayoutAcc = {}
        end
        return s.actionBarLayoutAcc
    end

    local function GetTargetLayoutArray()
        if targetScope == "account" then
            if not accountExpansionOn then
                return EnsureSharedAccountLayoutArray()
            end

            local expKey = GetCurrentExpansionKey and GetCurrentExpansionKey() or nil
            if not expKey then
                return nil
            end

            if not accountProfessionOn then
                return EnsureExpansionLayoutArray(expKey)
            end

            local pk = EnsureTargetProfessionKey()
            if not pk then
                return nil
            end
            return EnsureExpansionProfessionLayoutArray(expKey, pk)
        elseif targetScope == "zone" then
            return EnsureZoneLayoutArray(GetCurrentZoneMapID())
        elseif targetScope == "class" then
            return EnsureSharedClassLayoutArray()
        elseif targetScope == "loadout" then
            if not IsViewingActiveSpec() then
                return nil
            end
            if not GetActiveLoadoutKey() then
                return nil
            end
            return EnsureLoadoutLayoutArray()
        else
            return EnsureSpecLayoutArrayFor(GetViewingSpecID())
        end
    end

    local function GetEffectiveLayoutRows()
        InitSV()
        local s = GetSettings()
        if not s then
            return {}
        end

        local viewingSpecID = GetViewingSpecID()
        local activeSpecID = GetActiveSpecID()

        local account = GetSharedAccountLayoutArrayReadOnly()
        local expKey = GetCurrentExpansionKey and GetCurrentExpansionKey() or nil
        local expansionT = expKey and GetExpansionLayoutArrayReadOnly(expKey) or nil
        local profBySlot = {}
        local profUnslotted = {}
        if expKey then
            local profs = GetKnownProfessionKeys and GetKnownProfessionKeys() or nil
            if type(profs) == "table" and #profs > 0 then
                for _, pk in ipairs(profs) do
                    local t = GetExpansionProfessionLayoutArrayReadOnly(expKey, pk)
                    if type(t) == "table" then
                        for _, e in ipairs(t) do
                            local slot = NormalizeSlot(e and e.slot)
                            if slot then
                                profBySlot[slot] = { entry = e, professionKey = pk }
                            else
                                profUnslotted[#profUnslotted + 1] = { entry = e, professionKey = pk }
                            end
                        end
                    end
                end
            end
        end
        local classT = GetSharedClassLayoutArrayReadOnly()
        local specT = GetLayoutArrayReadOnlyBySpec(viewingSpecID)

        local loadout = nil
        local loadoutKey = nil
        if viewingSpecID and activeSpecID and viewingSpecID == activeSpecID then
            loadoutKey = GetActiveLoadoutKey()
            if loadoutKey then
                loadout = GetLoadoutLayoutArrayReadOnly(loadoutKey)
            end
        end

        local chosenBySlot = {}
        local function consider(scopeName, entry, expansionKey, professionKey)
            if type(entry) ~= "table" then
                return
            end
            local slot = NormalizeSlot(entry.slot)
            if not slot then
                return
            end
            chosenBySlot[slot] = {
                slot = slot,
                entry = entry,
                sourceScope = scopeName,
                sourceExpansionKey = expansionKey,
                sourceProfessionKey = professionKey,
            }
        end

        -- lowest -> highest precedence
        if type(account) == "table" then
            for _, e in ipairs(account) do consider("account", e) end
        end
        if type(expansionT) == "table" then
            for _, e in ipairs(expansionT) do consider("expansion", e, expKey) end
        end
        for slot = 1, 180 do
            local pe = profBySlot[slot]
            if pe and pe.entry then
                consider("profession", pe.entry, expKey, pe.professionKey)
            end
        end
        if type(classT) == "table" then
            for _, e in ipairs(classT) do consider("class", e) end
        end
        if type(specT) == "table" then
            for _, e in ipairs(specT) do consider("spec", e) end
        end
        if type(loadout) == "table" then
            for _, e in ipairs(loadout) do consider("loadout", e) end
        end

        local out = {}
        for slot = 1, 180 do
            local row = chosenBySlot[slot]
            if row then
                out[#out + 1] = row
            end
        end

        local function appendUnslotted(scopeName, t)
            if type(t) ~= "table" then
                return
            end
            for _, e in ipairs(t) do
                if type(e) == "table" and not NormalizeSlot(e.slot) then
                    out[#out + 1] = { slot = nil, entry = e, sourceScope = scopeName }
                end
            end
        end

        appendUnslotted("account", account)
        appendUnslotted("expansion", expansionT)
        for i = 1, #profUnslotted do
            local pe = profUnslotted[i]
            if pe and type(pe.entry) == "table" then
                out[#out + 1] = {
                    slot = nil,
                    entry = pe.entry,
                    sourceScope = "profession",
                    sourceExpansionKey = expKey,
                    sourceProfessionKey = pe.professionKey,
                }
            end
        end
        appendUnslotted("class", classT)
        appendUnslotted("spec", specT)
        appendUnslotted("loadout", loadout)

        return out
    end

    local function GetSelectedRow()
        if not selectedIndex then
            return nil
        end
        return displayRows[selectedIndex]
    end

    local function FindIndexByEntryRef(entryRef)
        if not entryRef then
            return nil
        end
        for i = 1, #displayRows do
            local r = displayRows[i]
            if r and (r.entry == entryRef or r.bestEntry == entryRef) then
                return i
            end
        end
        return nil
    end

    -- Hint (top)
    local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOP", panel, "TOP", 0, -32)
    hint:SetJustifyH("CENTER")
    hint:SetText("Place existing macros/spells into action slots. Slot range: 1-180. Applying is blocked in combat.")

    local specHint = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    specHint:SetPoint("TOP", hint, "BOTTOM", 0, -6)
    specHint:SetJustifyH("CENTER")

    local btnSpecPrev = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnSpecPrev:SetSize(26, 18)
    btnSpecPrev:SetPoint("RIGHT", specHint, "LEFT", -10, 0)
    btnSpecPrev:SetText("<")

    local btnSpecNext = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnSpecNext:SetSize(26, 18)
    btnSpecNext:SetPoint("LEFT", specHint, "RIGHT", 10, 0)
    btnSpecNext:SetText(">")

    local function UpdateSpecHint()
        local activeSpecID = GetActiveSpecID()
        local parts = {}

        if activeSpecID then
            local activeLabel = GetActiveSpecLabel() or tostring(activeSpecID)
            local viewingSpecID = GetViewingSpecID()

            local viewLabel = activeLabel
            if viewingSpecID ~= activeSpecID then
                local list = BuildSpecList()
                for i = 1, #list do
                    if list[i].id == viewingSpecID then
                        viewLabel = (list[i].name or "Spec") .. " (" .. tostring(viewingSpecID) .. ")"
                        break
                    end
                end
            end

            if viewingSpecID == activeSpecID then
                parts[#parts + 1] = "Viewing: Active"
            else
                parts[#parts + 1] = "Viewing: " .. tostring(viewLabel)
                parts[#parts + 1] = "Active: " .. tostring(activeLabel)
            end

            if viewingSpecID == activeSpecID then
                local loadoutName = GetActiveLoadoutName()
                if loadoutName then
                    parts[#parts + 1] = "Loadout: " .. tostring(loadoutName)
                else
                    parts[#parts + 1] = "Loadout: (none)"
                end
            end
        else
            parts[#parts + 1] = "No spec API"
        end

        local tgt = targetScope
        if tgt == "account" then
            parts[#parts + 1] = "Target: Account"

            if accountExpansionOn then
                local expKey = GetCurrentExpansionKey and GetCurrentExpansionKey() or nil
                parts[#parts + 1] = "Expansion: " .. (expKey and tostring(GetExpansionLabel(expKey)) or "(unknown)")
            end

            if accountProfessionOn then
                local pk = EnsureTargetProfessionKey()
                parts[#parts + 1] = "Profession: " .. (pk and tostring(pk) or "(none)")
            end
        elseif tgt == "class" then
            parts[#parts + 1] = "Target: Class"
        elseif tgt == "loadout" then
            parts[#parts + 1] = "Target: Loadout"
        else
            parts[#parts + 1] = "Target: Spec"
        end

        specHint:SetText(table.concat(parts, " | "))

        if GetActiveSpecID() and #BuildSpecList() > 1 then
            btnSpecPrev:Show()
            btnSpecNext:Show()
        else
            btnSpecPrev:Hide()
            btnSpecNext:Hide()
        end
    end

    local function CycleSpec(delta)
        local activeSpecID = GetActiveSpecID()
        if not activeSpecID then
            return
        end
        local list = BuildSpecList()
        if #list <= 1 then
            viewSpecIndex = nil
            UpdateSpecHint()
            return
        end

        local activeIndex = GetActiveSpecIndexInList(activeSpecID) or 1

        local function step(idx)
            idx = idx + delta
            if idx < 1 then idx = #list end
            if idx > #list then idx = 1 end
            return idx
        end

        if not viewSpecIndex then
            local nextIndex = step(activeIndex)
            if nextIndex == activeIndex then
                viewSpecIndex = nil
            else
                viewSpecIndex = nextIndex
            end
        else
            local nextIndex = step(viewSpecIndex)
            if nextIndex == activeIndex then
                viewSpecIndex = nil
            else
                viewSpecIndex = nextIndex
            end
        end
        selectedIndex = nil
        UpdateSpecHint()
    end

    btnSpecPrev:SetScript("OnClick", function() CycleSpec(-1) end)
    btnSpecNext:SetScript("OnClick", function() CycleSpec(1) end)

    -- Top buttons
    local BTN_W, BTN_H = 90, 22
    local BTN_GAP = 8

    local root = panel.GetParent and panel:GetParent() or nil
    local reloadBtn = root and rawget(root, "_reloadBtn") or nil
    if reloadBtn and reloadBtn.GetSize then
        local w, h = reloadBtn:GetSize()
        w = tonumber(w)
        h = tonumber(h)
        if w and w > 0 then BTN_W = w end
        if h and h > 0 then BTN_H = h end
    end

    local btnEnabled = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnEnabled:SetSize(BTN_W, BTN_H)
    btnEnabled:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -32)

    local btnScope = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnScope:SetSize(BTN_W, BTN_H)
    btnScope:SetPoint("TOPLEFT", btnEnabled, "BOTTOMLEFT", 0, -BTN_GAP)

    -- Account sub-scope buttons (only shown when Target=Account)
    local btnAccExpansion = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnAccExpansion:SetSize(95, BTN_H)
    btnAccExpansion:SetPoint("LEFT", btnScope, "RIGHT", 6, 0)
    btnAccExpansion:Hide()

    local btnAccProfession = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnAccProfession:SetSize(120, BTN_H)
    btnAccProfession:SetPoint("LEFT", btnAccExpansion, "RIGHT", 6, 0)
    btnAccProfession:Hide()

    local btnApply = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnApply:SetSize(BTN_W, BTN_H)
    btnApply:SetText("Apply All")

    local btnUseHover = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnUseHover:SetSize(BTN_W, BTN_H)
    btnUseHover:SetText("Hover Fill")

    local btnUseCursor = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnUseCursor:SetSize(BTN_W, BTN_H)
    btnUseCursor:SetText("Cursor Fill")

    local btnDetect = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnDetect:SetSize(BTN_W, BTN_H)

    local btnOverwrite = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnOverwrite:SetSize(BTN_W, BTN_H)

    local btnDebug = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnDebug:SetSize(BTN_W, BTN_H)

    -- Bottom row is right-aligned to Reload UI.
    if reloadBtn and reloadBtn.GetObjectType then
        btnDebug:SetPoint("RIGHT", reloadBtn, "LEFT", -BTN_GAP, 0)
    else
        btnDebug:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -12, 12)
    end
    btnOverwrite:SetPoint("RIGHT", btnDebug, "LEFT", -BTN_GAP, 0)
    btnDetect:SetPoint("RIGHT", btnOverwrite, "LEFT", -BTN_GAP, 0)
    btnUseHover:SetPoint("RIGHT", btnDetect, "LEFT", -BTN_GAP, 0)
    btnUseCursor:SetPoint("RIGHT", btnUseHover, "LEFT", -BTN_GAP, 0)

    local hoverText = panel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    hoverText:SetPoint("BOTTOMLEFT", btnUseHover, "TOPLEFT", 0, 6)
    hoverText:SetJustifyH("LEFT")
    hoverText:SetText("Hover: -")


    local detectorOn = false
    local hoverSlot, hoverType, hoverId = nil, nil, nil
    local lastHoverKey = nil
    local detectorFrame = CreateFrame("Frame")
    detectorFrame:Hide()

    local function SetDetectorButtonText()
        SetStateTextYellowNoOff(btnDetect, "Detector", detectorOn)
    end

    local function UpdateHoverText()
        if not hoverSlot then
            hoverText:SetText("Hover: -")
            return
        end
        local parts = { "Hover: " .. tostring(hoverSlot) }
        if hoverType then
            parts[#parts + 1] = tostring(hoverType)
        end
        if hoverId ~= nil then
            parts[#parts + 1] = tostring(hoverId)
        end
        hoverText:SetText(table.concat(parts, " "))
    end

    local function RefreshHoverNow()
        local focus = GetMouseFocus and GetMouseFocus() or nil
        local slot = FindActionSlotFromFocus(focus)
        slot = NormalizeSlot(slot)

        if not slot then
            hoverSlot, hoverType, hoverId = nil, nil, nil
            lastHoverKey = nil
            UpdateHoverText()
            return
        end

        local aType, aId = nil, nil
        if GetActionInfo then
            aType, aId = GetActionInfo(slot)
        end
        local key = tostring(slot) .. ":" .. tostring(aType) .. ":" .. tostring(aId)
        if key == lastHoverKey then
            return
        end
        lastHoverKey = key

        hoverSlot, hoverType, hoverId = slot, aType, aId
        UpdateHoverText()
    end

    detectorFrame:SetScript("OnUpdate", function(self, elapsed)
        self._acc = (self._acc or 0) + (elapsed or 0)
        if self._acc < 0.06 then
            return
        end
        self._acc = 0
        RefreshHoverNow()
    end)

    -- Placements list (right)
    local listArea = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    listArea:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -10, -106)
    listArea:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -10, 50)
    listArea:SetWidth(340)
    listArea:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        tile = true,
        tileSize = 16,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    listArea:SetBackdropColor(0, 0, 0, 0.25)

    local listTitle = listArea:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    listTitle:SetPoint("TOPLEFT", listArea, "TOPLEFT", 6, -6)
    listTitle:SetText("Placements")

    local btnAdd = CreateFrame("Button", nil, listArea, "UIPanelButtonTemplate")
    btnAdd:SetSize(60, 20)
    btnAdd:SetPoint("TOPRIGHT", listArea, "TOPRIGHT", -6, -4)
    btnAdd:SetText("Add")

    local btnDel = CreateFrame("Button", nil, listArea, "UIPanelButtonTemplate")
    btnDel:SetSize(60, 20)
    btnDel:ClearAllPoints()
    btnDel:SetPoint("TOPRIGHT", listArea, "TOPRIGHT", -6, -4)
    btnDel:SetText("Del")

    local btnAlways = CreateFrame("Button", nil, listArea, "UIPanelButtonTemplate")
    btnAlways:SetSize(70, 20)
    SetAlwaysText(btnAlways, false)
    btnAlways:Hide()

    local empty = listArea:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    empty:SetPoint("CENTER", listArea, "CENTER", 0, 0)
    empty:SetText("No entries")

    local scroll = CreateFrame("ScrollFrame", nil, listArea, "FauxScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", listArea, "TOPLEFT", 4, -28)
    scroll:SetPoint("BOTTOMRIGHT", listArea, "BOTTOMRIGHT", -4, 4)

    local ROW_H = 18
    local ROWS = 14
    local rows = {}

    HideFauxScrollBarAndEnableWheel(scroll, ROW_H)

    for i = 1, ROWS do
        local row = CreateFrame("Button", nil, listArea)
        row:SetHeight(ROW_H)
        row:SetPoint("TOPLEFT", listArea, "TOPLEFT", 8, -30 - (i - 1) * ROW_H)
        row:SetPoint("TOPRIGHT", listArea, "TOPRIGHT", -8, -30 - (i - 1) * ROW_H)

        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(row)
        bg:Hide()
        row.bg = bg

        local rightFs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        rightFs:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        rightFs:SetJustifyH("RIGHT")
        rightFs:SetWordWrap(false)
        row.rightText = rightFs

        local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("LEFT", row, "LEFT", 0, 0)
        fs:SetPoint("RIGHT", rightFs, "LEFT", -6, 0)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(false)
        row.text = fs

        row:Hide()
        rows[i] = row
    end

    -- Editor area (left)
    local editArea = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    editArea:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -106)
    editArea:SetPoint("BOTTOMRIGHT", listArea, "BOTTOMLEFT", -10, 0)
    editArea:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        tile = true,
        tileSize = 16,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    editArea:SetBackdropColor(0, 0, 0, 0)

    local editTitle = editArea:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    editTitle:SetPoint("TOPLEFT", editArea, "TOPLEFT", 6, -6)
    editTitle:SetText("")

    local status = editArea:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    status:SetPoint("TOPRIGHT", editArea, "TOPRIGHT", -6, -6)
    status:SetJustifyH("RIGHT")
    status:SetText("")

    local function CreateLabel(text, anchor, x, y)
        local fs = editArea:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", x or 0, y or -6)
        fs:SetText(text)
        return fs
    end

    local selectedSlot = nil
    local selectedKind = "macro" -- "macro" | "spell"
    local selectedValue = "" -- macroName or spellID/name text
    local selectedMacroScope = nil -- nil | "acc" | "char" (only meaningful when selectedKind=="macro")
    local selectedMacroIndex = nil -- macro index in the macro list (1..MAX_ACCOUNT+MAX_CHARACTER)
    local selectedMacroRemember = false
    local pendingAlwaysOverwrite = false
    local pendingClearElsewhere = false
    local pendingRemoveOutsideExpansion = false

    local RefreshButtons

    local labelSlot = editArea:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    labelSlot:SetPoint("TOPLEFT", editArea, "TOPLEFT", 8, -12)
    labelSlot:SetText("Slot")

    local btnSlot = CreateFrame("Button", nil, editArea, "UIPanelButtonTemplate")
    btnSlot:SetSize(100, 20)
    btnSlot:SetPoint("LEFT", labelSlot, "RIGHT", 8, 0)
    btnSlot:SetText("Select slot")

    local slotPickInfo = editArea:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    slotPickInfo:SetPoint("LEFT", btnSlot, "RIGHT", 10, 0)
    slotPickInfo:SetJustifyH("LEFT")
    slotPickInfo:SetText("")

    local btnPickMacro = CreateFrame("Button", nil, editArea, "UIPanelButtonTemplate")
    btnPickMacro:SetSize(90, 20)
    btnPickMacro:SetPoint("TOPLEFT", labelSlot, "BOTTOMLEFT", 0, -10)
    btnPickMacro:SetText("Macro")

    local btnPickSpell = CreateFrame("Button", nil, editArea, "UIPanelButtonTemplate")
    btnPickSpell:SetSize(90, 20)
    btnPickSpell:SetPoint("LEFT", btnPickMacro, "RIGHT", 8, 0)
    btnPickSpell:SetText("Spell")

    local dropBox = CreateFrame("Button", nil, editArea, "BackdropTemplate")
    dropBox:SetSize(140, 20)
    dropBox:SetPoint("LEFT", btnPickSpell, "RIGHT", 8, 0)
    dropBox:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        tile = true,
        tileSize = 16,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    dropBox:SetBackdropColor(0, 0, 0, 0.25)
    dropBox:EnableMouse(true)

    local dropText = dropBox:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    dropText:SetPoint("CENTER", dropBox, "CENTER", 0, 0)
    dropText:SetText("Drop here")

    local pickedText = editArea:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    pickedText:SetPoint("TOPLEFT", btnPickMacro, "BOTTOMLEFT", 0, -8)
    pickedText:SetJustifyH("LEFT")
    pickedText:SetText("Selected: -")

    -- Always belongs with the selection controls (not the placements header).
    btnAlways:ClearAllPoints()
    btnAlways:SetParent(editArea)
    btnAlways:SetSize(70, BTN_H)
    btnAlways:SetPoint("TOPLEFT", pickedText, "BOTTOMLEFT", 0, -10)
    btnAlways:Show()

    btnAlways:SetScript("OnEnter", function()
        if not GameTooltip then
            return
        end
        GameTooltip:SetOwner(btnAlways, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Always overwrite", 1, 1, 1, true)
        GameTooltip:AddLine("When ON, this entry can overwrite an occupied slot (unless protected by a higher-scope entry).", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btnAlways:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    local btnClear = CreateFrame("Button", nil, editArea, "UIPanelButtonTemplate")
    btnClear:SetSize(60, BTN_H)
    btnClear:SetPoint("LEFT", btnAlways, "RIGHT", 8, 0)
    SetClearText(btnClear, false)
    btnClear:Show()

    btnClear:SetScript("OnEnter", function()
        if not GameTooltip then
            return
        end
        GameTooltip:SetOwner(btnClear, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Clear elsewhere", 1, 1, 1, true)
        GameTooltip:AddLine("When ON, the same macro/spell will be removed from other slots after it is placed here.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btnClear:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    -- Add belongs with the selection controls.
    btnAdd:ClearAllPoints()
    btnAdd:SetParent(editArea)
    btnAdd:SetSize(BTN_W, BTN_H)
    btnAdd:SetPoint("LEFT", btnClear, "RIGHT", 8, 0)

    local btnRemove = CreateFrame("Button", nil, editArea, "UIPanelButtonTemplate")
    btnRemove:SetSize(70, BTN_H)
    btnRemove:SetPoint("LEFT", btnAdd, "RIGHT", 8, 0)
    SetRemoveText(btnRemove, false)
    btnRemove:Hide()

    btnRemove:SetScript("OnEnter", function()
        if not GameTooltip then
            return
        end
        GameTooltip:SetOwner(btnRemove, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Remove (outside expansion)", 1, 1, 1, true)
        GameTooltip:AddLine("When ON, this slot is cleared whenever you are not in this expansion's zones.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btnRemove:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    -- Apply belongs in the panel bottom-left corner.
    btnApply:ClearAllPoints()
    btnApply:SetParent(panel)
    btnApply:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 12, 12)

    local btnRemember = CreateFrame("Button", nil, editArea, "UIPanelButtonTemplate")
    do
        local w, h = 90, 22
        if btnApply and btnApply.GetSize then
            local aw, ah = btnApply:GetSize()
            if tonumber(aw) and tonumber(ah) then
                w, h = aw, ah
            end
        end
        btnRemember:SetSize(w, h)
    end
    btnRemember:SetPoint("LEFT", btnAdd, "RIGHT", 8, 0)
    btnRemember:Hide()

    local function SetRememberButtonText(on)
        if on then
            btnRemember:SetText("Remember: |cffffff00ON|r")
        else
            btnRemember:SetText("Remember: |cff888888OFF|r")
        end
    end

    local function GetRememberTable()
        InitSV()
        local s = GetSettings()
        if type(s) ~= "table" then
            return nil
        end
        local t = rawget(s, "actionBarRememberMacrosAcc")
        if type(t) ~= "table" then
            t = {}
            s.actionBarRememberMacrosAcc = t
        end
        return t
    end

    local function UpdateRememberButton()
        if selectedKind ~= "macro" then
            btnRemember:Hide()
            return
        end
        local name = Trim(selectedValue or "")
        if name == "" or selectedMacroScope ~= "char" then
            btnRemember:Hide()
            return
        end

        local t = GetRememberTable()
        selectedMacroRemember = (t and type(t[name]) == "table") and true or false
        SetRememberButtonText(selectedMacroRemember)
        btnRemember:Show()
    end

    local function UpdatePickedText()
        if selectedKind == "spell" then
            local raw = Trim(selectedValue or "")
            local sid = GetSpellIDFromText(raw)
            local name = nil

            if (not sid or sid <= 0) and raw ~= "" and GetSpellInfo then
                -- If we stored a spell name string, resolve it.
                local ok, resolvedName, _, _, _, _, resolvedId = pcall(GetSpellInfo, raw)
                if ok and type(resolvedId) == "number" and resolvedId > 0 then
                    sid = math.floor(resolvedId)
                    if type(resolvedName) == "string" and resolvedName ~= "" then
                        name = resolvedName
                    end
                end
            end

            if sid and sid > 0 then
                if (not name or name == "") and C_Spell and C_Spell.GetSpellInfo then
                    local ok, info = pcall(C_Spell.GetSpellInfo, sid)
                    if ok and type(info) == "table" and type(info.name) == "string" and info.name ~= "" then
                        name = info.name
                    end
                end

                if (not name or name == "") and GetSpellInfo then
                    local ok, resolvedName = pcall(GetSpellInfo, sid)
                    if ok and type(resolvedName) == "string" and resolvedName ~= "" then
                        name = resolvedName
                    end
                end

                if name and name ~= "" then
                    pickedText:SetText(string.format("Selected: %s (%s)", tostring(name), tostring(sid)))
                else
                    pickedText:SetText(string.format("Selected: %s", tostring(sid)))
                end
            else
                pickedText:SetText("Selected: -")
            end
        else
            local v = Trim(selectedValue or "")
            if v ~= "" then
                pickedText:SetText("Selected: " .. v)
            else
                pickedText:SetText("Selected: -")
            end
        end
    end

    local function SetStatusForSelection()
        local slot = NormalizeSlot(selectedSlot)
        if not slot then
            status:SetText("")
            return
        end
        local valueText = Trim(selectedValue or "")
        local macroState = ""
        if selectedKind == "spell" then
            local sid = GetSpellIDFromText(valueText)
            macroState = sid and "spell ok" or "spell missing"
        else
            local idx = SafeMacroIndexByName(valueText)
            macroState = (idx and idx > 0) and "macro ok" or "macro missing"
        end
        local slotState = ""
        if GetActionInfo then
            local t = GetActionInfo(slot)
            slotState = (t and "slot occupied") or "slot empty"
        end
        status:SetText(slotState .. " / " .. macroState)
    end

    local function SetSelectedSlot(slot)
        slot = NormalizeSlot(slot)
        selectedSlot = slot
        if slot then
            btnSlot:SetText("Slot " .. tostring(slot))
        else
            btnSlot:SetText("Select slot")
        end
        slotPickInfo:SetText("")
        UpdatePickedText()
        SetStatusForSelection()
        UpdateRememberButton()
    end

    local function SetSelectedMacro(name, scope, macroIndex)
        selectedKind = "macro"
        selectedValue = Trim(name or "")

        selectedMacroScope = scope
        selectedMacroIndex = macroIndex
        selectedMacroRemember = false

        UpdatePickedText()
        SetStatusForSelection()
        UpdateRememberButton()
    end

    local function SetSelectedSpell(spellID)
        selectedKind = "spell"
        selectedValue = tostring(spellID or "")
        selectedMacroScope = nil
        selectedMacroIndex = nil
        selectedMacroRemember = false
        UpdatePickedText()
        SetStatusForSelection()
        UpdateRememberButton()
    end

    local function ClearSelectionFields()
        selectedIndex = nil
        selectedKind = "macro"
        selectedValue = ""
        selectedMacroScope = nil
        selectedMacroIndex = nil
        selectedMacroRemember = false
        pendingRemoveOutsideExpansion = false
        SetSelectedSlot(nil)
        UpdatePickedText()
        SetStatusForSelection()
        UpdateRememberButton()
    end

    btnRemember:SetScript("OnClick", function()
        if selectedKind ~= "macro" or selectedMacroScope ~= "char" then
            return
        end
        local name = Trim(selectedValue or "")
        if name == "" then
            return
        end

        local t = GetRememberTable()
        if not t then
            return
        end

        if t[name] then
            t[name] = nil
            selectedMacroRemember = false
            SetRememberButtonText(false)
            return
        end

        local icon, body = nil, ""
        if selectedMacroIndex and GetMacroInfo then
            local ok, n, ic, bd = pcall(GetMacroInfo, selectedMacroIndex)
            if ok and type(n) == "string" and n ~= "" then
                icon = ic
                if type(bd) == "string" then
                    body = bd
                end
            end
        end

        t[name] = {
            icon = icon,
            body = body,
        }
        selectedMacroRemember = true
        SetRememberButtonText(true)
    end)

    local function FindSelectedEntryRef()
        local row = GetSelectedRow()
        if row and row.entry then
            return row.entry
        end
        return nil
    end

    local function GetOrCreateTargetEntryForSlot(slot)
        slot = NormalizeSlot(slot)
        if not slot then
            return nil
        end
        local row = GetSelectedRow()
        if row and row.entry and row.sourceScope == targetScope and NormalizeSlot(row.entry.slot) == slot then
            if targetScope == "loadout" and not IsViewingActiveSpec() then
                return nil
            end
            return row.entry
        end

        local layout = GetTargetLayoutArray()
        if type(layout) ~= "table" then
            return nil
        end
        for _, e in ipairs(layout) do
            if type(e) == "table" and NormalizeSlot(e.slot) == slot then
                return e
            end
        end
        local e = { slot = slot, kind = selectedKind, value = selectedValue, name = selectedValue }
        layout[#layout + 1] = e
        return e
    end

    local function WriteSelectionToTarget()
        if not CanEditTarget() then
            status:SetText("Target not editable")
            return false
        end
        local slot = NormalizeSlot(selectedSlot)
        if not slot then
            status:SetText("Pick a slot")
            return false
        end

        local entry = GetOrCreateTargetEntryForSlot(slot)
        if not entry then
            status:SetText("Cannot write to target")
            return false
        end

        entry.slot = slot
        entry.kind = selectedKind
        entry.value = tostring(selectedValue or "")
        entry.name = tostring(selectedValue or "")

        entry.alwaysOverwrite = pendingAlwaysOverwrite and true or nil
        entry.clearElsewhere = pendingClearElsewhere and true or nil

        if targetScope == "account" and accountExpansionOn then
            entry.removeOutsideExpansion = pendingRemoveOutsideExpansion and true or nil
        else
            entry.removeOutsideExpansion = nil
        end

        if panel._ActionBarUI_RefreshList then
            panel:_ActionBarUI_RefreshList()
        end

        return true
    end

    -- Slot selector: click button, then click an action button.
    local slotPickMode = false
    local slotPickFrame = CreateFrame("Frame")
    slotPickFrame:Hide()

    local function CompleteSlotPick(slot)
        slot = NormalizeSlot(slot)
        if not slot then
            return false
        end
        slotPickMode = false
        slotPickFrame:Hide()
        slotPickFrame:UnregisterAllEvents()
        slotPickInfo:SetText("")
        SetSelectedSlot(slot)
        if RefreshButtons then
            RefreshButtons()
        end
        return true
    end

    local function TryPickSlotFromMouseFocus()
        local focus = GetMouseFocus and GetMouseFocus() or nil
        local slot = FindActionSlotFromFocus(focus)
        if CompleteSlotPick(slot) then
            return true
        end
        return false
    end

    local function EnsureSlotPickHooksInstalled()
        if slotPickFrame._fgoHooksInstalled then
            return
        end
        slotPickFrame._fgoHooksInstalled = true

        if not hooksecurefunc then
            return
        end

        -- Most action buttons (including bar addons) ultimately execute UseAction(slot).
        hooksecurefunc("UseAction", function(slot, ...)
            if slotPickMode then
                CompleteSlotPick(slot)
            end
        end)

        -- Extra coverage for drag/drop flows.
        hooksecurefunc("PickupAction", function(slot, ...)
            if slotPickMode then
                CompleteSlotPick(slot)
            end
        end)
        hooksecurefunc("PlaceAction", function(slot, ...)
            if slotPickMode then
                CompleteSlotPick(slot)
            end
        end)

        -- Fallback: some buttons may not call UseAction directly; try reading attributes from the clicked secure button.
        hooksecurefunc("SecureActionButton_OnClick", function(self, ...)
            if not slotPickMode then
                return
            end
            local slot = FindActionSlotFromFocus(self)
            if not slot then
                local focus = GetMouseFocus and GetMouseFocus() or nil
                slot = FindActionSlotFromFocus(focus)
            end
            CompleteSlotPick(slot)
        end)
    end

    slotPickFrame:SetScript("OnEvent", function()
        if not slotPickMode then
            return
        end
        if TryPickSlotFromMouseFocus() then
            return
        end
        if C_Timer and C_Timer.After then
            C_Timer.After(0, function()
                if slotPickMode then
                    TryPickSlotFromMouseFocus()
                end
            end)
        end
    end)

    btnSlot:SetScript("OnClick", function()
        if slotPickMode then
            slotPickMode = false
            slotPickFrame:Hide()
            slotPickFrame:UnregisterAllEvents()
            slotPickInfo:SetText("")
            return
        end
        slotPickMode = true
        slotPickInfo:SetText("Click an action button to select slot")
        EnsureSlotPickHooksInstalled()
        slotPickFrame:RegisterEvent("GLOBAL_MOUSE_DOWN")
        slotPickFrame:Show()
    end)

    -- Macro/Spell picker (true side popout; not overlaying the tab content)
    local rootFrame = panel.GetParent and panel:GetParent() or panel
    local pickerFrame = CreateFrame("Frame", nil, rootFrame, "BackdropTemplate")
    pickerFrame:SetWidth(260)

    local function PositionPicker()
        pickerFrame:ClearAllPoints()

        local w = (pickerFrame.GetWidth and pickerFrame:GetWidth()) or 260
        w = tonumber(w) or 260

        local uiW = (UIParent and UIParent.GetWidth and UIParent:GetWidth()) or 0
        uiW = tonumber(uiW) or 0

        local rootLeft = (rootFrame and rootFrame.GetLeft and rootFrame:GetLeft())
        local rootRight = (rootFrame and rootFrame.GetRight and rootFrame:GetRight())

        local canLeft = (type(rootLeft) == "number") and (rootLeft - w) > 0
        local canRight = (type(rootRight) == "number") and uiW > 0 and (rootRight + w) < uiW

        -- Prefer opening on the left side (matches the editor controls),
        -- but fall back to right if there's not enough room.
        -- Offsets are 0 to remove any visible gap; top/bottom anchoring matches window height.
        if canLeft or not canRight then
            pickerFrame:SetPoint("TOPRIGHT", rootFrame, "TOPLEFT", 0, 0)
            pickerFrame:SetPoint("BOTTOMRIGHT", rootFrame, "BOTTOMLEFT", 0, 0)
        else
            pickerFrame:SetPoint("TOPLEFT", rootFrame, "TOPRIGHT", 0, 0)
            pickerFrame:SetPoint("BOTTOMLEFT", rootFrame, "BOTTOMRIGHT", 0, 0)
        end
    end

    PositionPicker()
    if pickerFrame.SetClampedToScreen then
        pickerFrame:SetClampedToScreen(true)
    end
    if rootFrame and rootFrame.GetFrameStrata and pickerFrame.SetFrameStrata then
        pickerFrame:SetFrameStrata(rootFrame:GetFrameStrata())
    end
    if rootFrame and rootFrame.GetFrameLevel and pickerFrame.SetFrameLevel then
        pickerFrame:SetFrameLevel((rootFrame:GetFrameLevel() or 0) + 20)
    end
    pickerFrame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        tile = true,
        tileSize = 16,
    })
    pickerFrame:SetBackdropColor(0, 0, 0, 0.85)
    pickerFrame:Hide()

    local pickerTitle = pickerFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    pickerTitle:SetPoint("TOPLEFT", pickerFrame, "TOPLEFT", 6, -6)
    pickerTitle:SetText("")

    local pickerClose = CreateFrame("Button", nil, pickerFrame, "UIPanelCloseButton")
    pickerClose:SetPoint("TOPRIGHT", pickerFrame, "TOPRIGHT", 2, 2)

    local pickerEmpty = pickerFrame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    pickerEmpty:SetPoint("CENTER", pickerFrame, "CENTER", 0, 0)
    pickerEmpty:SetText("No items")

    local pickerScroll = CreateFrame("ScrollFrame", nil, pickerFrame, "FauxScrollFrameTemplate")
    pickerScroll:SetPoint("TOPLEFT", pickerFrame, "TOPLEFT", 4, -48)
    pickerScroll:SetPoint("BOTTOMRIGHT", pickerFrame, "BOTTOMRIGHT", -4, 4)

    local PICK_ROW_H = 18
    local PICK_ROW_Y = 50 -- rows start at y = -PICK_ROW_Y
    local pickerRows = {}
    local pickerItems = {}
    local pickerMode = nil -- "macro" | "spell"

    local function GetPlayerClassColorHex()
        local classFile = nil
        if UnitClass then
            local _, cls = UnitClass("player")
            classFile = cls
        end

        local c = nil
        if classFile and C_ClassColor and C_ClassColor.GetClassColor then
            local ok, cc = pcall(C_ClassColor.GetClassColor, classFile)
            if ok and cc then
                c = cc
            end
        end
        if (not c) and classFile and RAID_CLASS_COLORS then
            c = RAID_CLASS_COLORS[classFile]
        end

        local function Hex2(n)
            n = tonumber(n) or 0
            if n <= 1 then
                n = math.floor(n * 255 + 0.5)
            end
            if n < 0 then n = 0 end
            if n > 255 then n = 255 end
            return string.format("%02X", n)
        end

        local r, g, b = 1, 1, 1
        if c then
            r = c.r or r
            g = c.g or g
            b = c.b or b
        end

        return "FF" .. Hex2(r) .. Hex2(g) .. Hex2(b)
    end

    local PLAYER_CLASS_HEX = GetPlayerClassColorHex()

    local spellFilter = "all" -- "all" | "general" | "class"

    local spellFilterBtn = CreateFrame("Button", nil, pickerFrame, "UIPanelButtonTemplate")
    spellFilterBtn:SetSize(86, 18)
    spellFilterBtn:SetPoint("TOPLEFT", pickerTitle, "BOTTOMLEFT", 0, -4)
    spellFilterBtn:Hide()

    local ONE_BUTTON_ASSISTANT_SPELLID = 1229376
    local assistantSpellID = nil
    local assistantBtn = CreateFrame("Button", nil, pickerFrame, "UIPanelButtonTemplate")
    assistantBtn:SetSize(86, 18)
    assistantBtn:SetPoint("LEFT", spellFilterBtn, "RIGHT", 6, 0)
    assistantBtn:SetText("Assistant")
    assistantBtn:Hide()
    assistantBtn:Disable()

    assistantBtn:SetScript("OnEnter", function()
        if not GameTooltip then return end
        GameTooltip:SetOwner(assistantBtn, "ANCHOR_RIGHT")
        GameTooltip:SetText("Assistant")
        GameTooltip:AddLine("Quick-picks the 'One Button Assistant' spell if it is in your spellbook.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    assistantBtn:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    local function SetSpellFilterButtonText()
        if spellFilter == "general" then
            spellFilterBtn:SetText("General")
        elseif spellFilter == "class" then
            spellFilterBtn:SetText("Class")
        else
            spellFilterBtn:SetText("All")
        end
    end
    SetSpellFilterButtonText()

    spellFilterBtn:SetScript("OnClick", function()
        if spellFilter == "all" then
            spellFilter = "general"
        elseif spellFilter == "general" then
            spellFilter = "class"
        else
            spellFilter = "all"
        end
        SetSpellFilterButtonText()
        if pickerMode == "spell" then
            pickerItems = BuildSpellItems()
            RefreshPicker()
        end
    end)

    if pickerFrame.SetClipsChildren then
        pickerFrame:SetClipsChildren(true)
    end

    HideFauxScrollBarAndEnableWheel(pickerScroll, PICK_ROW_H)

    local function EnsurePickerRows(n)
        n = tonumber(n) or 0
        if n < 1 then
            n = 1
        end
        for i = #pickerRows + 1, n do
            local r = CreateFrame("Button", nil, pickerFrame)
            r:SetHeight(PICK_ROW_H)
            r:SetPoint("TOPLEFT", pickerFrame, "TOPLEFT", 8, -PICK_ROW_Y - (i - 1) * PICK_ROW_H)
            r:SetPoint("TOPRIGHT", pickerFrame, "TOPRIGHT", -8, -PICK_ROW_Y - (i - 1) * PICK_ROW_H)

            local bg = r:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints(r)
            bg:Hide()
            r._zebraBg = bg

            local fs = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            fs:SetPoint("LEFT", r, "LEFT", 0, 0)
            fs:SetPoint("RIGHT", r, "RIGHT", 0, 0)
            fs:SetJustifyH("LEFT")
            fs:SetWordWrap(false)
            r.text = fs

            r:Hide()
            pickerRows[i] = r
        end
    end

    local function GetPickerDisplayCount()
        local h = (pickerFrame.GetHeight and pickerFrame:GetHeight()) or 0
        h = tonumber(h) or 0

        -- Rows begin at y=-PICK_ROW_Y; keep a small bottom pad.
        local usable = h - (PICK_ROW_Y + 6)
        local n = math.floor((usable > 0 and usable or 0) / PICK_ROW_H)
        if n < 8 then
            n = 8
        end
        return n
    end

    local function BuildMacroItems()
        local out = {}
        if not (GetNumMacros and GetMacroInfo) then
            return out
        end
        local maxAcc = tonumber(rawget(_G, "MAX_ACCOUNT_MACROS")) or 120
        local maxChar = tonumber(rawget(_G, "MAX_CHARACTER_MACROS")) or 18

        for i = 1, (maxAcc + maxChar) do
            local ok2, name = pcall(GetMacroInfo, i)
            if ok2 and type(name) == "string" and name ~= "" then
                local scopeTag = (i > maxAcc) and "C" or "A"
                local isChar = (i > maxAcc) and true or false
                local displayName = name
                if isChar then
                    displayName = "|c" .. tostring(PLAYER_CLASS_HEX) .. tostring(name) .. "|r"
                end
                out[#out + 1] = {
                    label = string.format("[%s] %s", scopeTag, displayName),
                    macroName = name,
                    macroIndex = i,
                    isCharacter = isChar,
                    sortName = tostring(name),
                }
            end
        end

        table.sort(out, function(a, b)
            local an = tostring(a.sortName or ""):lower()
            local bn = tostring(b.sortName or ""):lower()
            if an ~= bn then
                return an < bn
            end
            if (a.isCharacter and true or false) ~= (b.isCharacter and true or false) then
                return (a.isCharacter and true or false)
            end
            return (tonumber(a.macroIndex) or 0) < (tonumber(b.macroIndex) or 0)
        end)
        return out
    end

    local function BuildSpellItems()
        local out = {}
        local seen = {}
        assistantSpellID = nil

        local function IsPassiveSpellID(sid)
            sid = tonumber(sid)
            if not sid or sid <= 0 then
                return false
            end

            if C_Spell and type(C_Spell.IsSpellPassive) == "function" then
                local ok, isPassive = pcall(C_Spell.IsSpellPassive, sid)
                if ok then
                    return isPassive and true or false
                end
            end
            if type(IsPassiveSpell) == "function" then
                local ok, isPassive = pcall(IsPassiveSpell, sid)
                if ok then
                    return isPassive and true or false
                end
            end
            if type(IsSpellPassive) == "function" then
                local ok, isPassive = pcall(IsSpellPassive, sid)
                if ok then
                    return isPassive and true or false
                end
            end

            return false
        end

        local function IsGeneralCategory(cat)
            cat = tostring(cat or "")
            cat = cat:lower()
            return cat == "general" or cat:find("general", 1, true) ~= nil
        end

        local function AddSpellID(sid, category, flyoutName)
            sid = tonumber(sid)
            if not sid or sid <= 0 or seen[sid] then
                return
            end
            seen[sid] = true

            if IsPassiveSpellID(sid) then
                return
            end

            local name = nil
            if C_Spell and C_Spell.GetSpellInfo then
                local ok, info = pcall(C_Spell.GetSpellInfo, sid)
                if ok and type(info) == "table" then
                    name = info.name
                end
            end
            if (not name or name == "") and GetSpellInfo then
                local ok2, spellName = pcall(GetSpellInfo, sid)
                if ok2 then
                    name = spellName
                end
            end

            local baseName = tostring(name or "")
            if baseName == "" then
                baseName = tostring(sid)
            end

            if sid == ONE_BUTTON_ASSISTANT_SPELLID then
                assistantSpellID = sid
            end

            local cat = IsGeneralCategory(category) and "general" or "class"
            if spellFilter ~= "all" and spellFilter ~= cat then
                return
            end

            local coloredName = baseName
            if cat == "class" then
                coloredName = "|c" .. tostring(PLAYER_CLASS_HEX) .. tostring(baseName) .. "|r"
            end

            local fly = Trim(flyoutName or "")
            local labelName = coloredName
            if fly ~= "" then
                labelName = tostring(fly) .. ": " .. tostring(coloredName)
            end

            out[#out + 1] = {
                label = string.format("%s (%s)", tostring(labelName), tostring(sid)),
                spellID = sid,
                sortName = baseName,
                flyoutName = fly ~= "" and fly or nil,
                category = cat,
            }
        end

        local function AddFlyoutSpells(flyoutID, category)
            flyoutID = tonumber(flyoutID)
            if not flyoutID or flyoutID <= 0 then
                return
            end

            if type(GetFlyoutInfo) ~= "function" or type(GetFlyoutSlotInfo) ~= "function" then
                return
            end

            local ok, flyoutName, _, numSlots = pcall(GetFlyoutInfo, flyoutID)
            if not ok then
                return
            end
            numSlots = tonumber(numSlots) or 0
            if numSlots <= 0 then
                return
            end

            for slot = 1, numSlots do
                local ok2, spellID = pcall(GetFlyoutSlotInfo, flyoutID, slot)
                if ok2 and spellID then
                    AddSpellID(spellID, category, flyoutName)
                end
            end
        end

        local BOOKTYPE_SPELL = (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or "spell"

        local function CallMaybeArg(fn, arg)
            if type(fn) ~= "function" then
                return nil
            end
            local ok, r = pcall(fn, arg)
            if ok then
                return r
            end
            ok, r = pcall(fn)
            if ok then
                return r
            end
            return nil
        end

        local function CallMaybeTwo(fn, a1, a2)
            if type(fn) ~= "function" then
                return nil
            end
            local ok, r = pcall(fn, a1, a2)
            if ok then
                return r
            end
            ok, r = pcall(fn, a1)
            if ok then
                return r
            end
            ok, r = pcall(fn)
            if ok then
                return r
            end
            return nil
        end

        -- Modern Retail API (C_SpellBook)
        if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines and C_SpellBook.GetSpellBookSkillLineInfo and C_SpellBook.GetSpellBookItemInfo then
            local tabs = CallMaybeArg(C_SpellBook.GetNumSpellBookSkillLines, BOOKTYPE_SPELL)
            if not tabs then
                tabs = CallMaybeArg(C_SpellBook.GetNumSpellBookSkillLines)
            end
            tabs = tabs or 0
            for t = 1, tabs do
                local info = CallMaybeArg(C_SpellBook.GetSpellBookSkillLineInfo, t)
                if not info then
                    info = CallMaybeTwo(C_SpellBook.GetSpellBookSkillLineInfo, t, BOOKTYPE_SPELL)
                end
                if type(info) == "table" then
                    local skillName = rawget(info, "name") or rawget(info, "skillLineName")
                    local category = skillName
                    local offset = tonumber(info.itemIndexOffset) or 0
                    local num = tonumber(info.numSpellBookItems) or 0
                    for i = offset + 1, offset + num do
                        local item = CallMaybeTwo(C_SpellBook.GetSpellBookItemInfo, i, BOOKTYPE_SPELL)
                        if type(item) == "table" then
                            local itemType = rawget(item, "itemType")
                            local sid = rawget(item, "spellID") or rawget(item, "spellId") or rawget(item, "actionID") or rawget(item, "actionId")
                            local flyoutID = rawget(item, "flyoutID") or rawget(item, "flyoutId")

                            local enumType = Enum and Enum.SpellBookItemType or nil
                            local isSpell = false
                            local isFlyout = false
                            if enumType and itemType then
                                isSpell = (itemType == enumType.Spell) or (itemType == enumType.FutureSpell)
                                isFlyout = (itemType == enumType.Flyout)
                            else
                                -- Fallback for older shims/mappings:
                                -- PA maps SPELL=1, FUTURESPELL=2, PETACTION=3, FLYOUT=4
                                isSpell = (itemType == 1) or (itemType == 2) or (itemType == "SPELL") or (itemType == "FUTURESPELL")
                                isFlyout = (itemType == 4) or (itemType == "FLYOUT")
                            end

                            if sid and isSpell then
                                AddSpellID(sid, category)
                            elseif isFlyout then
                                AddFlyoutSpells(flyoutID or sid, category)
                            end
                        end
                    end
                end
            end
        elseif GetNumSpellTabs and GetSpellTabInfo and GetSpellBookItemInfo then
            -- Legacy API
            local tabs = GetNumSpellTabs() or 0
            for t = 1, tabs do
                local tabName, _, offset, numSpells = GetSpellTabInfo(t)
                offset = tonumber(offset) or 0
                numSpells = tonumber(numSpells) or 0
                for i = offset + 1, offset + numSpells do
                    local itemType, actionID, spellID = GetSpellBookItemInfo(i, "spell")
                    if itemType == "SPELL" then
                        AddSpellID(spellID or actionID, tabName)
                    elseif itemType == "FLYOUT" then
                        AddFlyoutSpells(actionID, tabName)
                    end
                end
            end
        end

        table.sort(out, function(a, b)
            local ag = tostring(a.flyoutName or ""):lower()
            local bg = tostring(b.flyoutName or ""):lower()
            if ag ~= bg then
                return ag < bg
            end

            local an = tostring(a.sortName or ""):lower()
            local bn = tostring(b.sortName or ""):lower()
            if an ~= bn then
                return an < bn
            end
            return (tonumber(a.spellID) or 0) < (tonumber(b.spellID) or 0)
        end)
        return out
    end

    local function RefreshPicker()
        pickerEmpty:SetShown(#pickerItems == 0)
        local displayCount = GetPickerDisplayCount()
        EnsurePickerRows(displayCount)
        if FauxScrollFrame_Update then
            FauxScrollFrame_Update(pickerScroll, #pickerItems, displayCount, PICK_ROW_H)
        end
        local offset = 0
        if FauxScrollFrame_GetOffset then
            offset = FauxScrollFrame_GetOffset(pickerScroll)
        end

        for i = 1, displayCount do
            local idx = offset + i
            local r = pickerRows[i]
            local it = pickerItems[idx]
            if not it then
                r:Hide()
                r:SetScript("OnClick", nil)
                r:SetScript("OnEnter", nil)
                r:SetScript("OnLeave", nil)
            else
                r:Show()
                if r._zebraBg then
                    r._zebraBg:Show()
                    if idx % 2 == 0 then
                        r._zebraBg:SetColorTexture(1, 1, 1, 0.03)
                    else
                        r._zebraBg:SetColorTexture(0, 0, 0, 0.03)
                    end
                end
                r.text:SetText(it.label)
                r:SetScript("OnClick", function()
                    if pickerMode == "spell" and it.spellID then
                        SetSelectedSpell(it.spellID)
                    elseif it.macroName then
                        SetSelectedMacro(it.macroName, (it.isCharacter and "char") or "acc", it.macroIndex)
                    end
                    pickerFrame:Hide()
                    if RefreshButtons then
                        RefreshButtons()
                    end
                end)

                r:SetScript("OnEnter", function()
                    if not (it and it.spellID and GameTooltip) then
                        return
                    end
                    GameTooltip:SetOwner(r, "ANCHOR_RIGHT")
                    if GameTooltip.SetSpellByID then
                        GameTooltip:SetSpellByID(it.spellID)
                    else
                        GameTooltip:SetText(tostring(it.label or it.spellID))
                    end
                    GameTooltip:AddLine("SpellID: " .. tostring(it.spellID), 1, 1, 1, true)
                    GameTooltip:Show()
                end)

                r:SetScript("OnLeave", function()
                    if GameTooltip then
                        GameTooltip:Hide()
                    end
                end)
            end
        end

        for i = displayCount + 1, #pickerRows do
            pickerRows[i]:Hide()
        end
    end

    pickerScroll:SetScript("OnVerticalScroll", function(self, offset)
        if FauxScrollFrame_OnVerticalScroll then
            FauxScrollFrame_OnVerticalScroll(self, offset, PICK_ROW_H, function() RefreshPicker() end)
        end
    end)

    pickerClose:SetScript("OnClick", function() pickerFrame:Hide() end)

    local function OpenPicker(mode)
        if pickerFrame:IsShown() and pickerMode == mode then
            pickerFrame:Hide()
            return
        end

        pickerMode = mode
        PositionPicker()
        if mode == "spell" then
            pickerTitle:SetText("Pick Spell")
            spellFilterBtn:Show()
            assistantBtn:Show()
            pickerItems = BuildSpellItems()

            local known = false
            if type(IsSpellKnown) == "function" then
                local ok, k = pcall(IsSpellKnown, ONE_BUTTON_ASSISTANT_SPELLID)
                known = ok and k and true or false
            end
            if known or (assistantSpellID and assistantSpellID > 0) then
                assistantBtn:Enable()
            else
                assistantBtn:Disable()
            end
        else
            pickerTitle:SetText("Pick Macro")
            spellFilterBtn:Hide()
            assistantBtn:Hide()
            pickerItems = BuildMacroItems()
        end
        pickerFrame:Show()
        RefreshPicker()
    end

    assistantBtn:SetScript("OnClick", function()
        if pickerMode ~= "spell" then
            return
        end

        local sid = ONE_BUTTON_ASSISTANT_SPELLID

        local okKnown = true
        local known = true
        if type(IsSpellKnown) == "function" then
            okKnown, known = pcall(IsSpellKnown, sid)
            known = okKnown and known and true or false
        end

        if not known then
            -- Still allow selection; the UI will show missing/unknown if it's truly unavailable.
        end

        SetSelectedSpell(sid)
        pickerFrame:Hide()
        if RefreshButtons then
            RefreshButtons()
        end
    end)

    pickerFrame:SetScript("OnSizeChanged", function()
        if pickerFrame and pickerFrame.IsShown and pickerFrame:IsShown() then
            RefreshPicker()
        end
    end)

    btnPickMacro:SetScript("OnClick", function() OpenPicker("macro") end)
    btnPickSpell:SetScript("OnClick", function() OpenPicker("spell") end)

    local function LoadFields()
        isLoadingFields = true
        local row = GetSelectedRow()
        if row and row.entry then
            SetSelectedSlot(row.entry.slot)
            local kind = GetEntryKind(row.entry)
            local v = row.entry.value
            if type(v) ~= "string" or v == "" then
                v = row.entry.name
            end
            if kind == "spell" then
                SetSelectedSpell(GetSpellIDFromText(v) or v)
            else
                SetSelectedMacro(v)
            end

            pendingAlwaysOverwrite = (row.entry.alwaysOverwrite and true or false)
            pendingClearElsewhere = (row.entry.clearElsewhere and true or false)
            pendingRemoveOutsideExpansion = (row.entry.removeOutsideExpansion and true or false)
        elseif row and row.slot then
            SetSelectedSlot(row.slot)
            selectedValue = ""
            selectedKind = "macro"
            UpdatePickedText()
            SetStatusForSelection()

            pendingAlwaysOverwrite = false
            pendingClearElsewhere = false
            pendingRemoveOutsideExpansion = false
        else
            SetSelectedSlot(nil)
            selectedValue = ""
            selectedKind = "macro"
            UpdatePickedText()
            SetStatusForSelection()

            pendingAlwaysOverwrite = false
            pendingClearElsewhere = false
            pendingRemoveOutsideExpansion = false
        end
        isLoadingFields = false
    end

    RefreshButtons = function()
        InitSV()
        local s = GetSettings()
        local on = (s and s.actionBarEnabledAcc) and true or false
        SetEnableOnlyText(btnEnabled, on)

        local ov = (s and s.actionBarOverwriteAcc) and true or false
        SetStateTextYellowNoOff(btnOverwrite, "Overwrite", ov)

        local dbg = (s and s.actionBarDebugAcc) and true or false
        SetStateTextYellowNoOff(btnDebug, "Debug", dbg)

        local canEdit = CanEditTarget()

        local row = GetSelectedRow()
        local canDelete = (row and row.entry) and true or false
        local hasSlot = NormalizeSlot(selectedSlot) ~= nil
        local alwaysOn = false
        local canAlways = false
        local clearOn = false
        local canClear = false
        local removeOn = false
        local canRemove = false
        local showRemove = (targetScope == "account" and accountExpansionOn) and true or false
        if row and row.entry then
            alwaysOn = (row.entry.alwaysOverwrite and true or false)
            canAlways = (row.sourceScope ~= nil) and CanEditScope(row.sourceScope)

            clearOn = (row.entry.clearElsewhere and true or false)
            canClear = (row.sourceScope ~= nil) and CanEditScope(row.sourceScope)

            removeOn = (row.entry.removeOutsideExpansion and true or false)
            canRemove = (row.sourceScope == "expansion" or row.sourceScope == "profession") and CanEditScope(row.sourceScope)
        elseif hasSlot and canEdit then
            alwaysOn = pendingAlwaysOverwrite
            canAlways = true

            clearOn = pendingClearElsewhere
            canClear = true

            removeOn = pendingRemoveOutsideExpansion
            canRemove = showRemove and true or false
        end

        btnAdd:SetEnabled(canEdit)
        btnDel:SetEnabled(canEdit and canDelete)
        btnAlways:SetEnabled(canAlways)
        SetAlwaysText(btnAlways, alwaysOn)
        btnClear:SetEnabled(canClear)
        SetClearText(btnClear, clearOn)

        btnRemove:SetShown(showRemove)
        if showRemove then
            btnRemove:SetEnabled(canRemove)
            SetRemoveText(btnRemove, removeOn)
        end

        -- Prevent overlap with Remember when Remove is shown.
        if btnRemember and btnRemember.ClearAllPoints and btnRemember.SetPoint then
            btnRemember:ClearAllPoints()
            if showRemove then
                btnRemember:SetPoint("LEFT", btnRemove, "RIGHT", 8, 0)
            else
                btnRemember:SetPoint("LEFT", btnAdd, "RIGHT", 8, 0)
            end
        end
        btnApply:SetEnabled(true)
        btnUseHover:SetEnabled(canEdit)
        btnUseCursor:SetEnabled(canEdit)
        if btnSlot.SetEnabled then btnSlot:SetEnabled(canEdit) end
        btnPickMacro:SetEnabled(canEdit and hasSlot)
        btnPickSpell:SetEnabled(canEdit and hasSlot)

        if pickerFrame:IsShown() and not (canEdit and hasSlot) then
            pickerFrame:Hide()
        end
    end

    btnEnabled:SetScript("OnClick", function()
        InitSV()
        local s = GetSettings()
        if not s then
            return
        end
        s.actionBarEnabledAcc = not (s.actionBarEnabledAcc and true or false)
        if ns and ns.ApplyActionBarSetting then
            ns.ApplyActionBarSetting(true)
        end
        RefreshButtons()
    end)

    btnOverwrite:SetScript("OnClick", function()
        InitSV()
        local s = GetSettings()
        if not s then
            return
        end
        s.actionBarOverwriteAcc = not (s.actionBarOverwriteAcc and true or false)
        RefreshButtons()
    end)

    btnDebug:SetScript("OnClick", function()
        InitSV()
        local s = GetSettings()
        if not s then
            return
        end
        s.actionBarDebugAcc = not (s.actionBarDebugAcc and true or false)
        RefreshButtons()
    end)

    btnApply:SetScript("OnClick", function()
        if ns and ns.ActionBar_ApplyNow then
            ns.ActionBar_ApplyNow("ui")
        end
    end)

    btnEnabled:SetScript("OnEnter", function()
        if not GameTooltip then return end
        GameTooltip:SetOwner(btnEnabled, "ANCHOR_RIGHT")
        GameTooltip:SetText("Enabled")
        GameTooltip:AddLine("Toggles automatic applying of placements.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btnEnabled:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    btnOverwrite:SetScript("OnEnter", function()
        if not GameTooltip then return end
        GameTooltip:SetOwner(btnOverwrite, "ANCHOR_RIGHT")
        GameTooltip:SetText("Overwrite")
        GameTooltip:AddLine("ON: allows replacing occupied action slots.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btnOverwrite:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    btnDebug:SetScript("OnEnter", function()
        if not GameTooltip then return end
        GameTooltip:SetOwner(btnDebug, "ANCHOR_RIGHT")
        GameTooltip:SetText("Debug")
        GameTooltip:AddLine("Prints debug info when applying placements.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btnDebug:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    btnUseHover:SetScript("OnEnter", function()
        if not GameTooltip then return end
        GameTooltip:SetOwner(btnUseHover, "ANCHOR_RIGHT")
        GameTooltip:SetText("Hover Fill")
        GameTooltip:AddLine("Copies detected action slot into Slot.", 1, 1, 1, true)
        GameTooltip:AddLine("If hovering a macro/spell, also fills Type + Value.", 1, 1, 1, true)
        GameTooltip:AddLine("Requires Detector ON and hovering a bar button.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btnUseHover:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    btnUseCursor:SetScript("OnEnter", function()
        if not GameTooltip then return end
        GameTooltip:SetOwner(btnUseCursor, "ANCHOR_RIGHT")
        GameTooltip:SetText("Cursor Fill")
        GameTooltip:AddLine("Use Blizzard's Macro or Spellbook UI:", 1, 1, 1, true)
        GameTooltip:AddLine("1) Drag a macro/spell onto your cursor", 1, 1, 1, true)
        GameTooltip:AddLine("2) Click Cursor Fill to set Type + Value", 1, 1, 1, true)
        GameTooltip:AddLine("Then press Add to write it to the list.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btnUseCursor:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    btnAdd:SetScript("OnEnter", function()
        if not GameTooltip then return end
        GameTooltip:SetOwner(btnAdd, "ANCHOR_RIGHT")
        GameTooltip:SetText("Add")
        GameTooltip:AddLine("Saves the selected Slot + Type + Value into the placements list.", 1, 1, 1, true)
        GameTooltip:AddLine("Does not apply anything to your action bars.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btnAdd:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    btnApply:SetScript("OnEnter", function()
        if not GameTooltip then return end
        GameTooltip:SetOwner(btnApply, "ANCHOR_RIGHT")
        GameTooltip:SetText("Apply All")
        GameTooltip:AddLine("Applies ALL placements now (merged from Account/Class/Spec/Loadout).", 1, 1, 1, true)
        GameTooltip:AddLine("Does not change the saved list.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btnApply:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    btnDetect:SetScript("OnClick", function()
        detectorOn = not detectorOn
        if detectorOn then
            detectorFrame:Show()
            RefreshHoverNow()
        else
            detectorFrame:Hide()
            hoverSlot, hoverType, hoverId = nil, nil, nil
            lastHoverKey = nil
            UpdateHoverText()
        end
        SetDetectorButtonText()
    end)

    btnDetect:SetScript("OnEnter", function()
        if not GameTooltip then
            return
        end
        GameTooltip:SetOwner(btnDetect, "ANCHOR_RIGHT")
        GameTooltip:SetText("Slot Detector")
        GameTooltip:AddLine("ON: reads the underlying action slot from the bar button you are hovering.", 1, 1, 1, true)
        GameTooltip:AddLine("Works with Blizzard bars and most bar addons (e.g. Bartender) that use action slots.", 1, 1, 1, true)
        GameTooltip:AddLine("Use 'Hover Slot' to fill the Slot field of the selected entry.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btnDetect:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    btnUseHover:SetScript("OnClick", function()
        if not CanEditTarget() then
            status:SetText("Target not editable")
            return
        end
        if not hoverSlot then
            status:SetText("Hover a bar button first")
            return
        end
        SetSelectedSlot(hoverSlot)

        if hoverType == "macro" and hoverId and GetMacroInfo then
            local ok, name = pcall(GetMacroInfo, hoverId)
            if ok and type(name) == "string" and name ~= "" then
                SetSelectedMacro(name)
            end
        elseif hoverType == "spell" and hoverId then
            SetSelectedSpell(hoverId)
        end

        status:SetText("Press Add to write")
    end)

    btnUseCursor:SetScript("OnClick", function()
        if not CanEditTarget() then
            status:SetText("Target not editable")
            return
        end
        if not GetCursorInfo then
            status:SetText("Cursor API missing")
            return
        end

        local function FillFromCursor()
            local cType, cId = GetCursorInfo()
            if not cType then
                status:SetText("Drag a macro/spell onto cursor")
                return false
            end

            if cType == "macro" and cId and GetMacroInfo then
                local ok, name = pcall(GetMacroInfo, cId)
                if ok and type(name) == "string" and name ~= "" then
                    SetSelectedMacro(name)
                else
                    status:SetText("Macro missing")
                    return false
                end
            elseif cType == "spell" and cId then
                SetSelectedSpell(cId)
            elseif cType == "mount" and cId and C_MountJournal and C_MountJournal.GetMountInfoByID then
                local ok, _, spellID = pcall(C_MountJournal.GetMountInfoByID, cId)
                if ok and spellID then
                    SetSelectedSpell(spellID)
                else
                    status:SetText("Mount spell missing")
                    return false
                end
            else
                status:SetText("Unsupported cursor: " .. tostring(cType))
                return false
            end

            status:SetText("Press Add to write")
            return true
        end

        local ok = FillFromCursor()
        if ClearCursor then
            ClearCursor()
        end
        return ok
    end)

    dropBox:SetScript("OnEnter", function()
        if not GameTooltip then return end
        GameTooltip:SetOwner(dropBox, "ANCHOR_RIGHT")
        GameTooltip:SetText("Drop here")
        GameTooltip:AddLine("Drag a macro/spell/mount here from Blizzard UI.", 1, 1, 1, true)
        GameTooltip:AddLine("This only selects; press Add to write.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    dropBox:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    dropBox:SetScript("OnReceiveDrag", function()
        if not CanEditTarget() then
            status:SetText("Target not editable")
            if ClearCursor then ClearCursor() end
            return
        end
        if not (GetCursorInfo and ClearCursor) then
            status:SetText("Cursor API missing")
            return
        end
        -- Reuse the same cursor parsing logic as Cursor Fill by simulating a click.
        if btnUseCursor and btnUseCursor.Click then
            btnUseCursor:Click()
        else
            -- fallback: just clear cursor
            ClearCursor()
        end
    end)

    dropBox:SetScript("OnMouseUp", function()
        if not CanEditTarget() then
            status:SetText("Target not editable")
            if ClearCursor then ClearCursor() end
            return
        end
        if btnUseCursor and btnUseCursor.Click then
            btnUseCursor:Click()
        end
    end)


    local function RefreshList()
        -- Build display rows:
        -- - Always show Bars 1-15
        -- - Bars are collapsible
        -- - Slots always shown (even empty)
        -- - Slots with lower-precedence entries can expand to show them (collapsed by default)

        local viewingSpecID = GetViewingSpecID()
        local activeSpecID = GetActiveSpecID()

        local account = GetSharedAccountLayoutArrayReadOnly()
        local expKey = GetCurrentExpansionKey and GetCurrentExpansionKey() or nil
        local expansionT = expKey and GetExpansionLayoutArrayReadOnly(expKey) or nil
        local profBySlot = {}
        local profUnslotted = {}
        if expKey then
            local profs = GetKnownProfessionKeys and GetKnownProfessionKeys() or nil
            if type(profs) == "table" and #profs > 0 then
                for _, pk in ipairs(profs) do
                    local t = GetExpansionProfessionLayoutArrayReadOnly(expKey, pk)
                    if type(t) == "table" then
                        for _, e in ipairs(t) do
                            if type(e) == "table" then
                                local slot = NormalizeSlot(e.slot)
                                if slot then
                                    profBySlot[slot] = { entry = e, scope = "profession", expansionKey = expKey, professionKey = pk }
                                else
                                    profUnslotted[#profUnslotted + 1] = { entry = e, scope = "profession", expansionKey = expKey, professionKey = pk }
                                end
                            end
                        end
                    end
                end
            end
        end
        local classT = GetSharedClassLayoutArrayReadOnly()
        local specT = GetLayoutArrayReadOnlyBySpec(viewingSpecID)

        local loadout = nil
        if viewingSpecID and activeSpecID and viewingSpecID == activeSpecID then
            local loadoutKey = GetActiveLoadoutKey()
            if loadoutKey then
                loadout = GetLoadoutLayoutArrayReadOnly(loadoutKey)
            end
        end

        local bySlot = {}
        local unslotted = {}
        local function addList(scopeName, t, expansionKey, professionKey)
            if type(t) ~= "table" then
                return
            end
            for _, e in ipairs(t) do
                if type(e) == "table" then
                    local slot = NormalizeSlot(e.slot)
                    if slot then
                        bySlot[slot] = bySlot[slot] or {}
                        bySlot[slot][#bySlot[slot] + 1] = { entry = e, scope = scopeName, expansionKey = expansionKey, professionKey = professionKey }
                    else
                        unslotted[#unslotted + 1] = { entry = e, scope = scopeName, expansionKey = expansionKey, professionKey = professionKey }
                    end
                end
            end
        end

        -- highest -> lowest precedence for display/expand
        addList("loadout", loadout)
        addList("spec", specT)
        addList("class", classT)
        for slot = 1, 180 do
            local pe = profBySlot[slot]
            if pe and pe.entry then
                bySlot[slot] = bySlot[slot] or {}
                bySlot[slot][#bySlot[slot] + 1] = pe
            end
        end
        for i = 1, #profUnslotted do
            unslotted[#unslotted + 1] = profUnslotted[i]
        end
        addList("expansion", expansionT, expKey)
        addList("account", account)

        -- Always hide the old empty placeholder (list is pre-populated).
        empty:Hide()

        wipe(displayRows)

        local function ScopeTag(scope)
            return (scope == "loadout" and "L") or (scope == "spec" and "S") or (scope == "class" and "C") or (scope == "profession" and "P") or (scope == "expansion" and "E") or (scope == "account" and "A") or "?"
        end

        for bar = 1, 15 do
            displayRows[#displayRows + 1] = { rowType = "bar", bar = bar }
            if barExpanded[bar] then
                for pos = 1, 12 do
                    local slot = (bar - 1) * 12 + pos
                    local list = bySlot[slot] or {}
                    local best = list[1]
                    local bestEntry = best and best.entry or nil
                    local bestScope = best and best.scope or nil
                    local bestExpKey = best and best.expansionKey or nil
                    local bestProfKey = best and best.professionKey or nil
                    displayRows[#displayRows + 1] = {
                        rowType = "slot",
                        bar = bar,
                        pos = pos,
                        slot = slot,
                        all = list,
                        bestEntry = bestEntry,
                        entry = bestEntry,
                        sourceScope = bestScope,
                        sourceExpansionKey = bestExpKey,
                        sourceProfessionKey = bestProfKey,
                    }
                    if slotExpanded[slot] and #list > 1 then
                        for j = 2, #list do
                            displayRows[#displayRows + 1] = {
                                rowType = "override",
                                slot = slot,
                                entry = list[j].entry,
                                sourceScope = list[j].scope,
                                sourceExpansionKey = list[j].expansionKey,
                                sourceProfessionKey = list[j].professionKey,
                            }
                        end
                    end
                end
            end
        end

        if #unslotted > 0 then
            if barExpanded[0] == nil then
                barExpanded[0] = false
            end
            displayRows[#displayRows + 1] = { rowType = "bar", bar = 0, label = "Unslotted" }
            if barExpanded[0] then
                for i = 1, #unslotted do
                    displayRows[#displayRows + 1] = {
                        rowType = "override",
                        slot = nil,
                        entry = unslotted[i].entry,
                        sourceScope = unslotted[i].scope,
                        sourceExpansionKey = unslotted[i].expansionKey,
                        sourceProfessionKey = unslotted[i].professionKey,
                        unslotted = true,
                    }
                end
            end
        end

        if selectedIndex and (selectedIndex < 1 or selectedIndex > #displayRows) then
            selectedIndex = nil
        end

        if FauxScrollFrame_Update then
            FauxScrollFrame_Update(scroll, #displayRows, ROWS, ROW_H)
        end

        local offset = 0
        if FauxScrollFrame_GetOffset then
            offset = FauxScrollFrame_GetOffset(scroll)
        end

        local function GetSpellNameByID(spellID)
            spellID = tonumber(spellID)
            if not spellID or spellID <= 0 then
                return nil
            end
            if C_Spell and C_Spell.GetSpellInfo then
                local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
                if ok and type(info) == "table" and type(info.name) == "string" and info.name ~= "" then
                    return info.name
                end
            end
            if GetSpellInfo then
                local ok, name = pcall(GetSpellInfo, spellID)
                if ok and type(name) == "string" and name ~= "" then
                    return name
                end
            end
            return nil
        end

        local function FormatEntryValue(entry)
            if not entry then
                return ""
            end
            local kind = GetEntryKind(entry)
            local raw = ""
            if kind == "spell" then
                raw = Trim(entry.value or entry.spell or entry.spellID or entry.spellId or entry.name or "")
                local sid = tonumber(rawget(entry, "spellID") or rawget(entry, "spellId")) or GetSpellIDFromText(raw)
                if sid then
                    local name = Trim(GetSpellNameByID(sid) or "")
                    if name == "" then
                        -- Fall back to any non-numeric text we have.
                        if raw ~= "" and not tonumber(raw) then
                            name = raw
                        else
                            name = tostring(sid)
                        end
                    end
                    return string.format("%s (%d)", name, sid)
                end
                return raw
            end
            raw = Trim(entry.value or entry.name or "")
            return raw
        end

        for i = 1, ROWS do
            local idx = offset + i
            local row = rows[i]
            local r = displayRows[idx]
            if not r then
                row:Hide()
            else
                row:Show()

                local zebra = (idx % 2) == 0
                row.bg:SetShown(zebra or (selectedIndex == idx))
                if selectedIndex == idx then
                    row.bg:SetColorTexture(0.2, 0.6, 1, 0.18)
                else
                    row.bg:SetColorTexture(1, 1, 1, zebra and 0.05 or 0)
                end

                if r.rowType == "bar" then
                    local label
                    if r.label then
                        label = r.label
                    elseif r.bar == 0 then
                        label = "Unslotted"
                    else
                        label = string.format("Bar %02d", tonumber(r.bar) or 0)
                    end
                    local open = barExpanded[r.bar] and true or false
                    row.text:SetText(string.format("%s %s", open and "[-]" or "[+]", label))
                    row.text:SetTextColor(0.75, 0.85, 1, 1)
                    row.rightText:SetText("")
                    row:RegisterForClicks("LeftButtonUp")
                    row:SetScript("OnClick", function()
                        barExpanded[r.bar] = not (barExpanded[r.bar] and true or false)
                        RefreshList()
                    end)
                elseif r.rowType == "override" then
                    local entry = r.entry
                    local slotTxt = "?"
                    if entry and entry.slot then
                        local n = tonumber(entry.slot)
                        if n then
                            slotTxt = string.format("%03d", n)
                        else
                            slotTxt = tostring(entry.slot)
                        end
                    end
                    local kind = entry and GetEntryKind(entry) or "macro"
                    local value = FormatEntryValue(entry)
                    if value == "" then value = "(empty)" end
                    local kindTag = (kind == "spell") and "S" or "M"
                    row.text:SetText(string.format("      %s:  %s", slotTxt, value))
                    row.rightText:SetText(string.format("[%s][%s]", ScopeTag(r.sourceScope), kindTag))
                    row.text:SetTextColor(0.75, 0.75, 0.75, 1)
                    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                    row:SetScript("OnClick", function(_, btn)
                        if btn == "RightButton" and r.slot and slotExpanded[r.slot] then
                            slotExpanded[r.slot] = false
                            RefreshList()
                            return
                        end
                        selectedIndex = idx
                        RefreshButtons()
                        RefreshList()
                        LoadFields()
                    end)
                else
                    local entry = r.bestEntry
                    local slotTxt = string.format("%03d", tonumber(r.slot) or 0)
                    local kind = entry and GetEntryKind(entry) or "macro"
                    local value = FormatEntryValue(entry)
                    if entry and value == "" then
                        value = "(empty)"
                    end
                    local srcTag = entry and ScopeTag(r.sourceScope) or "-"

                    local extra = ""
                    local list = r.all or {}
                    if #list > 1 then
                        if slotExpanded[r.slot] then
                            extra = string.format(" (-%d)", #list - 1)
                        else
                            extra = string.format(" (+%d)", #list - 1)
                        end
                    end

                    -- Indent so the ':' aligns with the end of "Bar 01".
                    row.text:SetText(string.format("      %s:  %s%s", slotTxt, value, extra))
                    if entry then
                        local kindTag = (kind == "spell") and "S" or "M"
                        row.rightText:SetText(string.format("[%s][%s]", srcTag, kindTag))
                    else
                        row.rightText:SetText("")
                    end
                    if not entry then
                        row.text:SetTextColor(0.67, 0.67, 0.67, 1)
                    else
                        row.text:SetTextColor(1, 1, 1, 1)
                    end
                    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                    row:SetScript("OnClick", function(_, btn)
                        if btn == "RightButton" and #list > 1 then
                            slotExpanded[r.slot] = not (slotExpanded[r.slot] and true or false)
                            RefreshList()
                            return
                        end
                        selectedIndex = idx
                        SetSelectedSlot(r.slot)
                        RefreshButtons()
                        RefreshList()
                        LoadFields()
                    end)
                end
            end
        end
    end

    panel._ActionBarUI_RefreshList = RefreshList

    scroll:SetScript("OnVerticalScroll", function(self, offset)
        if FauxScrollFrame_OnVerticalScroll then
            FauxScrollFrame_OnVerticalScroll(self, offset, ROW_H, function()
                RefreshList()
            end)
        end
    end)

    btnAdd:SetScript("OnClick", function()
        if not CanEditTarget() then
            status:SetText("Target not editable")
            return
        end
        local ok = WriteSelectionToTarget()
        if not ok then
            RefreshButtons()
            RefreshList()
            return
        end

        status:SetText("Added")
        ClearSelectionFields()
        pendingAlwaysOverwrite = false
        pendingClearElsewhere = false
        pendingRemoveOutsideExpansion = false
        RefreshButtons()
        RefreshList()
    end)

    btnAlways:SetScript("OnClick", function()
        local row = GetSelectedRow()
        if row and row.entry and row.sourceScope then
            if not CanEditScope(row.sourceScope) then
                status:SetText("Scope not editable")
                return
            end
            row.entry.alwaysOverwrite = not (row.entry.alwaysOverwrite and true or false)
            pendingAlwaysOverwrite = (row.entry.alwaysOverwrite and true or false)
            RefreshButtons()
            RefreshList()
            status:SetText(row.entry.alwaysOverwrite and "Always overwrite: ON" or "Always overwrite: OFF")
            return
        end

        if not CanEditTarget() then
            status:SetText("Target not editable")
            return
        end
        if not NormalizeSlot(selectedSlot) then
            status:SetText("Pick a slot")
            return
        end

        pendingAlwaysOverwrite = not pendingAlwaysOverwrite
        RefreshButtons()
        status:SetText(pendingAlwaysOverwrite and "Always overwrite (pending): ON" or "Always overwrite (pending): OFF")
    end)

    btnClear:SetScript("OnClick", function()
        local row = GetSelectedRow()
        if row and row.entry and row.sourceScope then
            if not CanEditScope(row.sourceScope) then
                status:SetText("Scope not editable")
                return
            end

            row.entry.clearElsewhere = not (row.entry.clearElsewhere and true or false)
            pendingClearElsewhere = (row.entry.clearElsewhere and true or false)
            RefreshButtons()
            RefreshList()
            status:SetText(row.entry.clearElsewhere and "Clear elsewhere: ON" or "Clear elsewhere: OFF")
            return
        end

        if not CanEditTarget() then
            status:SetText("Target not editable")
            return
        end
        if not NormalizeSlot(selectedSlot) then
            status:SetText("Pick a slot")
            return
        end

        pendingClearElsewhere = not pendingClearElsewhere
        RefreshButtons()
        status:SetText(pendingClearElsewhere and "Clear elsewhere (pending): ON" or "Clear elsewhere (pending): OFF")
    end)

    btnRemove:SetScript("OnClick", function()
        local row = GetSelectedRow()
        if row and row.entry and row.sourceScope then
            if row.sourceScope ~= "expansion" and row.sourceScope ~= "profession" then
                status:SetText("Remove only applies to expansion entries")
                return
            end
            if not CanEditScope(row.sourceScope) then
                status:SetText("Scope not editable")
                return
            end

            row.entry.removeOutsideExpansion = not (row.entry.removeOutsideExpansion and true or false)
            pendingRemoveOutsideExpansion = (row.entry.removeOutsideExpansion and true or false)
            RefreshButtons()
            RefreshList()
            status:SetText(row.entry.removeOutsideExpansion and "Remove outside expansion: ON" or "Remove outside expansion: OFF")
            return
        end

        if not CanEditTarget() then
            status:SetText("Target not editable")
            return
        end
        if not NormalizeSlot(selectedSlot) then
            status:SetText("Pick a slot")
            return
        end

        pendingRemoveOutsideExpansion = not pendingRemoveOutsideExpansion
        RefreshButtons()
        status:SetText(pendingRemoveOutsideExpansion and "Remove outside expansion (pending): ON" or "Remove outside expansion (pending): OFF")
    end)

    btnDel:SetScript("OnClick", function()
        local row = GetSelectedRow()
        if not (row and row.entry and row.sourceScope) then
            return
        end

        -- Delete from the row's actual source scope.
        local sourceList = nil
        if row.sourceScope == "account" then
            sourceList = EnsureSharedAccountLayoutArray()
        elseif row.sourceScope == "expansion" then
            sourceList = EnsureExpansionLayoutArray(row.sourceExpansionKey or (GetCurrentExpansionKey and GetCurrentExpansionKey() or nil))
        elseif row.sourceScope == "profession" then
            local expKey = row.sourceExpansionKey or (GetCurrentExpansionKey and GetCurrentExpansionKey() or nil)
            local pk = row.sourceProfessionKey
            if expKey and pk then
                sourceList = EnsureExpansionProfessionLayoutArray(expKey, pk)
            end
        elseif row.sourceScope == "zone" then
            sourceList = EnsureZoneLayoutArray(GetCurrentZoneMapID())
        elseif row.sourceScope == "class" then
            sourceList = EnsureSharedClassLayoutArray()
        elseif row.sourceScope == "loadout" then
            sourceList = EnsureLoadoutLayoutArray()
        else
            sourceList = EnsureSpecLayoutArrayFor(GetViewingSpecID())
        end

        if type(sourceList) ~= "table" then
            return
        end

        for i = #sourceList, 1, -1 do
            if sourceList[i] == row.entry then
                table.remove(sourceList, i)
                break
            end
        end

        selectedIndex = nil
        RefreshButtons()
        RefreshList()
        LoadFields()
    end)

    local UpdateScopeButton

    local function UpdateAccountSubButtons()
        local show = (targetScope == "account") and true or false
        btnAccExpansion:SetShown(show)
        btnAccProfession:SetShown(show)

        if not show then
            return
        end

        local expKey = GetCurrentExpansionKey and GetCurrentExpansionKey() or nil
        local expLabel = expKey and tostring(GetExpansionLabel(expKey)) or "Unknown"

        btnAccExpansion:SetText(accountExpansionOn and "Expansion: ON" or "Expansion: OFF")

        if accountProfessionOn then
            local pk = EnsureTargetProfessionKey()
            btnAccProfession:SetText("Profession: " .. tostring(pk or "(none)"))
        else
            btnAccProfession:SetText("Profession: OFF")
        end

        btnAccExpansion._expLabel = expLabel
    end

    local function UpdateAll()
        UpdateScopeButton()
        UpdateAccountSubButtons()
        UpdateSpecHint()
        SetDetectorButtonText()
        RefreshButtons()
        RefreshList()
        LoadFields()
    end

    UpdateScopeButton = function()
        if targetScope == "account" then
            btnScope:SetText("Account")
        elseif targetScope == "loadout" then
            btnScope:SetText("Loadout")
        elseif targetScope == "class" then
            btnScope:SetText("Class")
        else
            btnScope:SetText("Spec") -- Default target scope
        end
    end

    btnAccExpansion:SetScript("OnClick", function()
        if targetScope ~= "account" then
            return
        end

        accountExpansionOn = not accountExpansionOn
        if not accountExpansionOn then
            accountProfessionOn = false
            targetProfessionKey = nil
        end

        selectedIndex = nil
        UpdateAll()
    end)

    btnAccExpansion:SetScript("OnEnter", function()
        if not GameTooltip then return end
        GameTooltip:SetOwner(btnAccExpansion, "ANCHOR_RIGHT")
        GameTooltip:SetText("Account: Expansion")
        GameTooltip:AddLine("When ON, Account writes to the current expansion (landmass).", 1, 1, 1, true)
        GameTooltip:AddLine("Current: " .. tostring(btnAccExpansion._expLabel or "Unknown"), 1, 1, 1, true)
        GameTooltip:AddLine("Turning this OFF also turns Profession OFF.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btnAccExpansion:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    btnAccProfession:SetScript("OnClick", function()
        if targetScope ~= "account" then
            return
        end

        -- Profession is nested under Expansion
        if not accountExpansionOn then
            accountExpansionOn = true
        end

        local expKey = GetCurrentExpansionKey and GetCurrentExpansionKey() or nil
        if not expKey then
            accountProfessionOn = false
            targetProfessionKey = nil
            selectedIndex = nil
            UpdateAll()
            return
        end

        local profs = (type(GetKnownProfessionKeys) == "function") and GetKnownProfessionKeys() or nil
        if type(profs) ~= "table" or #profs == 0 then
            accountProfessionOn = false
            targetProfessionKey = nil
            selectedIndex = nil
            UpdateAll()
            return
        end

        -- Cycle: OFF -> first -> next -> ... -> OFF
        if not accountProfessionOn then
            accountProfessionOn = true
            targetProfessionKey = profs[1]
        else
            local idx = 0
            for i = 1, #profs do
                if profs[i] == targetProfessionKey then
                    idx = i
                    break
                end
            end
            idx = idx + 1
            if idx < 1 or idx > #profs then
                accountProfessionOn = false
                targetProfessionKey = nil
            else
                accountProfessionOn = true
                targetProfessionKey = profs[idx]
            end
        end

        selectedIndex = nil
        UpdateAll()
    end)

    btnAccProfession:SetScript("OnEnter", function()
        if not GameTooltip then return end
        GameTooltip:SetOwner(btnAccProfession, "ANCHOR_RIGHT")
        GameTooltip:SetText("Account: Profession")
        GameTooltip:AddLine("When ON, Account writes to current expansion + selected profession.", 1, 1, 1, true)
        GameTooltip:AddLine("Click to cycle professions (and OFF).", 1, 1, 1, true)
        GameTooltip:AddLine("Profession implies Expansion.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btnAccProfession:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    btnScope:SetScript("OnClick", function()
        if targetScope == "spec" then
            targetScope = "loadout"
        elseif targetScope == "loadout" then
            targetScope = "class"
        elseif targetScope == "class" then
            targetScope = "account"
        else
            targetScope = "spec"
        end
        selectedIndex = nil
        UpdateScopeButton()
        UpdateAll()
    end)

    btnScope:SetScript("OnEnter", function()
        if not GameTooltip then return end
        GameTooltip:SetOwner(btnScope, "ANCHOR_RIGHT")
        GameTooltip:SetText("Target")
        GameTooltip:AddLine("Select where new entries/overrides are stored.", 1, 1, 1, true)
        GameTooltip:AddLine("The list always shows the effective merged layout.", 1, 1, 1, true)
        GameTooltip:AddLine("Account: shared across all characters.", 1, 1, 1, true)
        GameTooltip:AddLine("Use the Expansion/Profession buttons next to Target when Target=Account.", 1, 1, 1, true)
        GameTooltip:AddLine("Class: shared across all specs of this class.", 1, 1, 1, true)
        GameTooltip:AddLine("Spec: applies to the viewed spec.", 1, 1, 1, true)
        GameTooltip:AddLine("Loadout: applies to active loadout (active spec only).", 1, 1, 1, true)
        GameTooltip:AddLine("Precedence on same slot: Loadout > Spec > Class > Profession > Expansion > Account.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btnScope:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    panel:SetScript("OnHide", function()
        if detectorOn then
            detectorOn = false
            detectorFrame:Hide()
            hoverSlot, hoverType, hoverId = nil, nil, nil
            lastHoverKey = nil
            UpdateHoverText()
            SetDetectorButtonText()
        end
    end)

    UpdateAll()
    return UpdateAll
end

-- Back-compat alias (older core builds may still call this)
ns.ActionBarUI_Build = ns.SituateUI_Build
