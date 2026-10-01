

---@diagnostic disable: undefined-global

local addonName, ns = ...
if type(ns) ~= "table" then
    ns = {}
end

-- ============================================================================
-- Valeera AutoProfile
-- ============================================================================

do
    local Valeera = {}
    local valeeraFrame
    local valeeraHooked
    local valeeraApplyPending
    local valeeraPanel
    local SaveValeeraProfile
    local ScheduleValeeraApply

    local COMPANION_OPTIONS = {
        [140123] = true,
        [140126] = true,
        [140496] = true,
    }

    local function InitValeeraDB()
        if ns and type(ns._InitSV) == "function" then
            ns._InitSV()
        end

        AutoGame_Acc.valeeraProfiles = AutoGame_Acc.valeeraProfiles or {}
        AutoGame_Acc.valeeraEntryNames = AutoGame_Acc.valeeraEntryNames or {}
        AutoGame_Char.valeeraProfiles = AutoGame_Char.valeeraProfiles or {}
        AutoGame_Settings.valeera = AutoGame_Settings.valeera or {}

        -- Migrate the standalone addon's data once, without deleting its DB.
        local legacy = rawget(_G, "ValeeraAutoProfileDB")
        if legacy and not AutoGame_Acc.valeeraMigrated then
            if type(legacy.profiles) == "table" and next(AutoGame_Acc.valeeraProfiles) == nil then
                for name, profile in pairs(legacy.profiles) do
                    if type(name) == "string" and type(profile) == "table" then
                        AutoGame_Acc.valeeraProfiles[name] = {
                            role = tonumber(profile.role),
                            poisons = tonumber(profile.poisons or profile.poison),
                            combat = tonumber(profile.combat),
                            utility = tonumber(profile.utility),
                        }
                    end
                end
            end
            if not AutoGame_Acc.valeeraActive then
                AutoGame_Acc.valeeraActive = legacy.activeProfile
            end
            if type(legacy.charProfiles) == "table" then
                for key, profileName in pairs(legacy.charProfiles) do
                    if AutoGame_Char.valeeraProfiles[key] == nil then
                        AutoGame_Char.valeeraProfiles[key] = profileName
                    end
                end
            end
            if type(legacy.settings) == "table" then
                if type(AutoGame_Settings.valeera.autoGossip) ~= "boolean" then
                    AutoGame_Settings.valeera.autoGossip = legacy.settings.autoGossip
                end
                if type(AutoGame_Settings.valeera.autoClose) ~= "boolean" then
                    AutoGame_Settings.valeera.autoClose = legacy.settings.autoClose
                end
            end
            AutoGame_Acc.valeeraMigrated = true
        end

        if type(AutoGame_Settings.valeera.autoGossip) ~= "boolean" then
            AutoGame_Settings.valeera.autoGossip = false
        end
        if type(AutoGame_Settings.valeera.autoClose) ~= "boolean" then
            AutoGame_Settings.valeera.autoClose = false
        end
        if AutoGame_Settings.valeera.profileMode ~= "account"
            and AutoGame_Settings.valeera.profileMode ~= "character" then
            AutoGame_Settings.valeera.profileMode = "account"
        end
    end

    local function GetValeeraPlayerKey()
        local name = UnitName and UnitName("player") or "Unknown"
        local realm = GetNormalizedRealmName and GetNormalizedRealmName() or ""
        return tostring(name) .. "-" .. tostring(realm or "")
    end

    local function GetValeeraFrame()
        return rawget(_G, "DelvesCompanionConfigurationFrame")
    end

    local function GetValeeraSlots(frame)
        if not frame then
            return nil, nil, nil, nil
        end

        local roleSlot = frame.CompanionCombatRoleSlot or frame.RoleSlot or frame.CombatRoleSlot
        local poisonsSlot = frame.CompanionPoisonSlot or frame.CompanionCombatPoisonSlot or frame.PoisonSlot or frame.PoisonsSlot
        local combatSlot = frame.CompanionCombatTrinketSlot or frame.CombatTrinketSlot or frame.CombatSlot
        local utilitySlot = frame.CompanionUtilityTrinketSlot or frame.UtilityTrinketSlot or frame.UtilitySlot
        if roleSlot and poisonsSlot and combatSlot and utilitySlot then
            return roleSlot, poisonsSlot, combatSlot, utilitySlot
        end

        local candidates = {}
        local function AddCandidate(child)
            if child and child.selectionNodeID then
                candidates[#candidates + 1] = child
            end
        end

        local function ScanChildren(parent, depth)
            if not (parent and parent.GetChildren and depth > 0) then
                return
            end
            local children = { parent:GetChildren() }
            for _, child in ipairs(children) do
                AddCandidate(child)
                ScanChildren(child, depth - 1)
            end
        end
        ScanChildren(frame, 4)

        for _, candidate in ipairs(candidates) do
            local name = candidate.GetName and candidate:GetName() or ""
            name = tostring(name):lower()
            if not poisonsSlot and (name:find("poison", 1, true) or name:find("venom", 1, true)) then
                poisonsSlot = candidate
            elseif not utilitySlot and name:find("utility", 1, true) then
                utilitySlot = candidate
            elseif not roleSlot and name:find("role", 1, true) then
                roleSlot = candidate
            elseif not combatSlot and name:find("combat", 1, true) then
                combatSlot = candidate
            end
        end

        local remaining = {}
        for _, candidate in ipairs(candidates) do
            if candidate ~= roleSlot and candidate ~= poisonsSlot
                and candidate ~= combatSlot and candidate ~= utilitySlot then
                remaining[#remaining + 1] = candidate
            end
        end
        roleSlot = roleSlot or remaining[1]
        poisonsSlot = poisonsSlot or remaining[2]
        combatSlot = combatSlot or remaining[3]
        utilitySlot = utilitySlot or remaining[4]
        return roleSlot, poisonsSlot, combatSlot, utilitySlot
    end

    local function GetActiveValeeraProfile()
        InitValeeraDB()
        local key = GetValeeraPlayerKey()
        local mode = AutoGame_Settings.valeera.profileMode
        local name = mode == "character" and AutoGame_Char.valeeraProfiles[key] or AutoGame_Acc.valeeraActive
        return name, name and AutoGame_Acc.valeeraProfiles[name], key, mode
    end

    local function ValeeraDebug(message)
        InitValeeraDB()
        if AutoGame_Settings.valeera.debug then
            print("|cffff8000[fr0z3nUI Valeera]|r " .. tostring(message))
        end
    end

    local function ValeeraSlotDebug(slot)
        if not slot then
            return "missing"
        end
        local name = slot.GetName and slot:GetName() or "(unnamed)"
        return string.format(
            "%s node=%s config=%s",
            tostring(name),
            tostring(slot.selectionNodeID),
            tostring(slot.configID)
        )
    end

    local function GetValeeraEntryName(configID, entryID)
        entryID = tonumber(entryID)
        if not (configID and entryID and C_Traits and C_Traits.GetEntryInfo) then
            return nil
        end

        InitValeeraDB()
        local cachedName = AutoGame_Acc.valeeraEntryNames[tostring(entryID)]
        if type(cachedName) == "string" and cachedName ~= "" then
            return cachedName
        end

        local entryOK, entryInfo = pcall(C_Traits.GetEntryInfo, configID, entryID)
        if not entryOK or type(entryInfo) ~= "table" then
            return nil
        end
        local name = entryInfo.overrideName or entryInfo.name
        if not name and entryInfo.definitionID and C_Traits.GetDefinitionInfo then
            local definitionOK, definitionInfo = pcall(C_Traits.GetDefinitionInfo, entryInfo.definitionID)
            if definitionOK and type(definitionInfo) == "table" then
                name = definitionInfo.overrideName or definitionInfo.name
            end
        end
        if type(name) == "string" and name ~= "" then
            AutoGame_Acc.valeeraEntryNames[tostring(entryID)] = name
            return name
        end
        return nil
    end

    local function ResolveValeeraTraitEntry(configID, nodeInfo, entryID, savedName)
        entryID = tonumber(entryID)
        local entryIDs = nodeInfo and nodeInfo.entryIDs
        if not (entryID and type(entryIDs) == "table") then
            return entryID
        end

        for _, candidateID in ipairs(entryIDs) do
            if tonumber(candidateID) == entryID then
                return entryID
            end
        end

        savedName = savedName or AutoGame_Acc.valeeraEntryNames[tostring(entryID)]
        if type(savedName) ~= "string" or savedName == "" then
            return nil
        end
        for _, candidateID in ipairs(entryIDs) do
            local candidateName = GetValeeraEntryName(configID, candidateID)
            if candidateName == savedName then
                return tonumber(candidateID), candidateName
            end
        end
        return nil
    end

    local function ApplyValeeraProfile()
        local frame = GetValeeraFrame()
        if not (frame and frame.IsShown and frame:IsShown()) then
            return true
        end

        local profileName, profile, playerKey, profileMode = GetActiveValeeraProfile()
        if not profileName or not profile then
            return true
        end

        local roleSlot, poisonsSlot, combatSlot, utilitySlot = GetValeeraSlots(frame)
        local configID = roleSlot and roleSlot.configID
        configID = configID or (combatSlot and combatSlot.configID)
        configID = configID or (utilitySlot and utilitySlot.configID)
        if not configID and frame.GetChildren then
            local children = { frame:GetChildren() }
            for _, child in ipairs(children) do
                configID = child and child.configID
                if configID then break end
            end
        end
        local roleConfigID = (roleSlot and roleSlot.configID) or configID
        local poisonsConfigID = (poisonsSlot and poisonsSlot.configID) or configID
        local combatConfigID = (combatSlot and combatSlot.configID) or configID
        local utilityConfigID = (utilitySlot and utilitySlot.configID) or configID
        local roleNode = roleSlot and roleSlot.selectionNodeID
        local poisonsNode = poisonsSlot and poisonsSlot.selectionNodeID
        local combatNode = combatSlot and combatSlot.selectionNodeID
        local utilityNode = utilitySlot and utilitySlot.selectionNodeID
        ValeeraDebug("apply profile=" .. tostring(profileName))
        ValeeraDebug("role: " .. ValeeraSlotDebug(roleSlot))
        ValeeraDebug("poisons: " .. ValeeraSlotDebug(poisonsSlot))
        ValeeraDebug("combat: " .. ValeeraSlotDebug(combatSlot))
        ValeeraDebug("utility: " .. ValeeraSlotDebug(utilitySlot))
        ValeeraDebug("resolved configs role=" .. tostring(roleConfigID) .. " poisons=" .. tostring(poisonsConfigID) .. " combat=" .. tostring(combatConfigID) .. " utility=" .. tostring(utilityConfigID))
        if not (roleConfigID and poisonsConfigID and combatConfigID and utilityConfigID and roleNode and poisonsNode and combatNode and utilityNode) then
            ValeeraDebug("not ready: missing config or node")
            return false
        end

        local roleInfo = C_Traits.GetNodeInfo(roleConfigID, roleNode)
        local poisonsInfo = C_Traits.GetNodeInfo(poisonsConfigID, poisonsNode)
        local combatInfo = C_Traits.GetNodeInfo(combatConfigID, combatNode)
        local utilityInfo = C_Traits.GetNodeInfo(utilityConfigID, utilityNode)
        if not (roleInfo and poisonsInfo and combatInfo and utilityInfo) then
            ValeeraDebug("not ready: node info role=" .. tostring(roleInfo ~= nil) .. " poisons=" .. tostring(poisonsInfo ~= nil) .. " combat=" .. tostring(combatInfo ~= nil) .. " utility=" .. tostring(utilityInfo ~= nil))
            return false
        end

        local changedConfigs = {}
        local function ApplyTrait(configID, nodeID, nodeInfo, targetEntryID, profileIDKey, profileNameKey)
            targetEntryID = tonumber(targetEntryID)
            if not targetEntryID then
                return
            end
            if profileIDKey then
                local resolvedEntryID, resolvedName = ResolveValeeraTraitEntry(configID, nodeInfo, targetEntryID, profile[profileNameKey])
                if not resolvedEntryID then
                    ValeeraDebug("missing curio entry=" .. tostring(targetEntryID) .. " node=" .. tostring(nodeID))
                    return
                end
                if resolvedEntryID ~= targetEntryID then
                    profile[profileIDKey] = resolvedEntryID
                    profile[profileNameKey] = resolvedName or GetValeeraEntryName(configID, resolvedEntryID)
                    ValeeraDebug("updated curio entry=" .. tostring(targetEntryID) .. " to=" .. tostring(resolvedEntryID))
                    targetEntryID = resolvedEntryID
                elseif not profile[profileNameKey] then
                    profile[profileNameKey] = GetValeeraEntryName(configID, targetEntryID)
                end
            end
            local currentEntry = nodeInfo.activeEntry and nodeInfo.activeEntry.entryID
            ValeeraDebug("node=" .. tostring(nodeID) .. " current=" .. tostring(currentEntry) .. " target=" .. tostring(targetEntryID))
            if currentEntry ~= targetEntryID then
                C_Traits.SetSelection(configID, nodeID, targetEntryID)
                changedConfigs[configID] = true
                ValeeraDebug("changed node=" .. tostring(nodeID) .. " config=" .. tostring(configID))
            else
                ValeeraDebug("unchanged node=" .. tostring(nodeID))
            end
        end

        ApplyTrait(roleConfigID, roleNode, roleInfo, profile.role)
        ApplyTrait(poisonsConfigID, poisonsNode, poisonsInfo, profile.poisons, "poisons", "poisonsName")
        ApplyTrait(combatConfigID, combatNode, combatInfo, profile.combat, "combat", "combatName")
        ApplyTrait(utilityConfigID, utilityNode, utilityInfo, profile.utility, "utility", "utilityName")

        if next(changedConfigs) then
            for changedConfigID in pairs(changedConfigs) do
                C_Traits.CommitConfig(changedConfigID)
                ValeeraDebug("committed config=" .. tostring(changedConfigID))
            end
            local source = profileMode == "character" and "(Char)" or "(Global)"
            print("|cff00ff00[fr0z3nUI]|r Valeera profile '|cffffff00" .. profileName .. "|r' loaded " .. source)
            if AutoGame_Settings.valeera.autoClose and C_Timer and C_Timer.After then
                C_Timer.After(0.15, function()
                    if frame and frame.IsShown and frame:IsShown() then
                        HideUIPanel(frame)
                    end
                end)
            end
        end
        return true
    end

    local function DumpValeeraDebug()
        local frame = GetValeeraFrame()
        local profileName, profile = GetActiveValeeraProfile()
        local roleSlot, poisonsSlot, combatSlot, utilitySlot = GetValeeraSlots(frame)
        print("|cffff8000[fr0z3nUI Valeera]|r debug=" .. tostring(AutoGame_Settings.valeera.debug))
        print("  frame=" .. tostring(frame ~= nil) .. " shown=" .. tostring(frame and frame.IsShown and frame:IsShown()))
        print("  profile=" .. tostring(profileName) .. " role=" .. tostring(profile and profile.role) .. " poisons=" .. tostring(profile and profile.poisons) .. " combat=" .. tostring(profile and profile.combat) .. " utility=" .. tostring(profile and profile.utility))
        print("  role: " .. ValeeraSlotDebug(roleSlot))
        print("  poisons: " .. ValeeraSlotDebug(poisonsSlot))
        print("  combat: " .. ValeeraSlotDebug(combatSlot))
        print("  utility: " .. ValeeraSlotDebug(utilitySlot))
    end

    local function GetValeeraSlotEntry(slot, fallbackConfigID)
        if not slot or not slot.selectionNodeID then
            return nil
        end
        local info = C_Traits.GetNodeInfo(slot.configID or fallbackConfigID, slot.selectionNodeID)
        return info and info.activeEntry and tonumber(info.activeEntry.entryID)
    end

    -- Role entries have no spell/description in C_Traits data, so read the slot's own hover tooltip instead.
    local function GetValeeraSlotTooltipLabel(slot)
        if not (slot and slot.GetScript and GameTooltip) then
            return nil
        end
        local onEnter = slot:GetScript("OnEnter")
        if type(onEnter) ~= "function" then
            return nil
        end
        local label
        local ok = pcall(function()
            GameTooltip:SetOwner(slot, "ANCHOR_NONE")
            onEnter(slot)
        end)
        if ok and GameTooltip:IsShown() then
            local textLine = _G["GameTooltipTextLeft1"]
            local text = textLine and textLine.GetText and textLine:GetText()
            if type(text) == "string" and text ~= "" then
                label = text
            end
        end
        local onLeave = slot:GetScript("OnLeave")
        if type(onLeave) == "function" then
            pcall(onLeave, slot)
        end
        GameTooltip:Hide()
        return label
    end

    local function GetValeeraEntryLabel(slot, fallbackConfigID)
        local entryID = GetValeeraSlotEntry(slot, fallbackConfigID)
        if not entryID then
            return "-"
        end

        InitValeeraDB()
        local cachedName = AutoGame_Acc.valeeraEntryNames[tostring(entryID)]
        if type(cachedName) == "string" and cachedName ~= "" then
            return cachedName .. " (" .. tostring(entryID) .. ")"
        end

        local configID = slot and (slot.configID or fallbackConfigID)
        local name
        if configID and C_Traits.GetEntryInfo and C_Traits.GetDefinitionInfo then
            local entryOK, entryInfo = pcall(C_Traits.GetEntryInfo, configID, entryID)
            local definitionID = entryOK and entryInfo and entryInfo.definitionID
            if entryOK and type(entryInfo) == "table" then
                name = entryInfo.overrideName or entryInfo.name
            end
            if definitionID then
                local definitionOK, definitionInfo = pcall(C_Traits.GetDefinitionInfo, definitionID)
                if definitionOK and type(definitionInfo) == "table" then
                    name = name or definitionInfo.overrideName or definitionInfo.name or definitionInfo.description
                    local spellID = definitionInfo.spellID
                    if not name and spellID and C_Spell then
                        if type(C_Spell.GetSpellName) == "function" then
                            local spellOK, spellName = pcall(C_Spell.GetSpellName, spellID)
                            name = spellOK and spellName or nil
                        end
                        if not name and type(C_Spell.GetSpellInfo) == "function" then
                            local spellOK, spellInfo = pcall(C_Spell.GetSpellInfo, spellID)
                            name = spellOK and type(spellInfo) == "table" and spellInfo.name or nil
                        end
                    end
                end
            end
        end
        if not name then
            name = GetValeeraSlotTooltipLabel(slot)
        end
        if type(name) == "string" and name ~= "" then
            AutoGame_Acc.valeeraEntryNames[tostring(entryID)] = name
            return name .. " (" .. tostring(entryID) .. ")"
        end
        return tostring(entryID)
    end

    local function RefreshValeeraPanel()
        if not valeeraPanel then
            return
        end
        InitValeeraDB()

        local frame = GetValeeraFrame()
        local roleSlot, poisonsSlot, combatSlot, utilitySlot = GetValeeraSlots(frame)
        local configID = roleSlot and roleSlot.configID
        configID = configID or (poisonsSlot and poisonsSlot.configID)
        configID = configID or (combatSlot and combatSlot.configID)
        configID = configID or (utilitySlot and utilitySlot.configID)
        local role = GetValeeraEntryLabel(roleSlot, configID)
        local poisons = GetValeeraEntryLabel(poisonsSlot, configID)
        local combat = GetValeeraEntryLabel(combatSlot, configID)
        local utility = GetValeeraEntryLabel(utilitySlot, configID)

        valeeraPanel.current:SetText(string.format(
            "Role: %s\nPoison: %s\nCombat: %s\nUtility: %s",
            tostring(role or "-"), tostring(poisons or "-"),
            tostring(combat or "-"), tostring(utility or "-")
        ))
        local mode = AutoGame_Settings.valeera.profileMode
        local activeName = mode == "character" and AutoGame_Char.valeeraProfiles[GetValeeraPlayerKey()] or AutoGame_Acc.valeeraActive
        valeeraPanel.mode:SetText(mode == "character" and "Character Companion" or "Account Companion")
        valeeraPanel.active:SetText("Active: " .. tostring(activeName or "None"))
        if valeeraPanel.debug then
            valeeraPanel.debug:SetText("Debug: " .. (AutoGame_Settings.valeera.debug == true and "ON" or "OFF"))
        end

        local names = {}
        for name in pairs(AutoGame_Acc.valeeraProfiles) do
            names[#names + 1] = name
        end
        table.sort(names)
        for index, row in ipairs(valeeraPanel.profileRows) do
            local name = names[index]
            row:Hide()
            if name then
                row.name = name
                row.use:SetText(name)
                row:Show()
            end
        end
    end

    local function EnsureValeeraPanel()
        if valeeraPanel then
            RefreshValeeraPanel()
            return valeeraPanel
        end
        local frame = GetValeeraFrame()
        if not (frame and CreateFrame and UIParent) then
            return nil
        end

        valeeraPanel = CreateFrame("Frame", "FGO_ValeeraProfilePanel", UIParent, "BackdropTemplate")
        valeeraPanel:SetSize(294, 328)
        valeeraPanel:SetFrameStrata("DIALOG")
        valeeraPanel:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -8)
        if valeeraPanel.SetBackdrop then
            valeeraPanel:SetBackdrop({
                bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                tile = true,
                tileSize = 32,
            })
        end

        local function RemoveButtonBackground(button)
            local textures = {
                button.GetNormalTexture and button:GetNormalTexture(),
                button.GetPushedTexture and button:GetPushedTexture(),
                button.GetHighlightTexture and button:GetHighlightTexture(),
                button.GetDisabledTexture and button:GetDisabledTexture(),
                button.Left,
                button.Middle,
                button.Right,
            }
            for _, texture in ipairs(textures) do
                if texture and texture.Hide then
                    texture:Hide()
                end
            end
        end

        local title = valeeraPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOP", 0, -10)
        title:SetText("")

        valeeraPanel.mode = CreateFrame("Button", nil, valeeraPanel, "UIPanelButtonTemplate")
        valeeraPanel.mode:SetSize(170, 22)
        valeeraPanel.mode:SetPoint("TOP", 0, -7)
        RemoveButtonBackground(valeeraPanel.mode)
        valeeraPanel.mode:SetScript("OnClick", function()
            InitValeeraDB()
            AutoGame_Settings.valeera.profileMode = AutoGame_Settings.valeera.profileMode == "character" and "account" or "character"
            ScheduleValeeraApply()
            RefreshValeeraPanel()
        end)

        valeeraPanel.current = valeeraPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        valeeraPanel.current:SetPoint("TOPLEFT", 12, -38)
        valeeraPanel.current:SetJustifyH("LEFT")
        valeeraPanel.current:SetText("Current")

        valeeraPanel.active = valeeraPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        valeeraPanel.active:SetPoint("TOPLEFT", 12, -90)
        valeeraPanel.active:SetJustifyH("LEFT")

        local nameBox = CreateFrame("EditBox", nil, valeeraPanel, "InputBoxTemplate")
        nameBox:SetSize(130, 24)
        nameBox:SetPoint("TOPLEFT", 12, -112)
        nameBox:SetAutoFocus(false)
        nameBox:SetTextInsets(6, 6, 0, 0)
        nameBox:SetText("Default")
        valeeraPanel.nameBox = nameBox

        local saveButton = CreateFrame("Button", nil, valeeraPanel, "UIPanelButtonTemplate")
        saveButton:SetSize(75, 24)
        saveButton:SetPoint("LEFT", nameBox, "RIGHT", 5, 0)
        saveButton:SetText("Save")
        RemoveButtonBackground(saveButton)
        saveButton:SetScript("OnClick", function()
            local name = strtrim(nameBox:GetText() or "")
            if name ~= "" and SaveValeeraProfile then
                SaveValeeraProfile(name, AutoGame_Settings.valeera.profileMode)
                RefreshValeeraPanel()
            end
        end)

        valeeraPanel.profileRows = {}
        for index = 1, 5 do
            local row = CreateFrame("Frame", nil, valeeraPanel)
            row:SetSize(270, 25)
            row:SetPoint("TOPLEFT", 12, -142 - ((index - 1) * 26))
            row.background = row:CreateTexture(nil, "BACKGROUND")
            row.background:SetAllPoints()
            if index % 2 == 0 then
                row.background:SetColorTexture(1, 1, 1, 0.06)
            else
                row.background:SetColorTexture(0, 0, 0, 0.06)
            end
            row.use = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            row.use:SetSize(225, 23)
            row.use:SetPoint("LEFT")
            RemoveButtonBackground(row.use)
            row.use:SetScript("OnClick", function()
                if row.name and AutoGame_Acc.valeeraProfiles[row.name] then
                    if AutoGame_Settings.valeera.profileMode == "character" then
                        AutoGame_Char.valeeraProfiles[GetValeeraPlayerKey()] = row.name
                    else
                        AutoGame_Acc.valeeraActive = row.name
                    end
                    ScheduleValeeraApply()
                    RefreshValeeraPanel()
                end
            end)
            row.delete = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            row.delete:SetSize(35, 23)
            row.delete:SetPoint("RIGHT")
            row.delete:SetText("X")
            RemoveButtonBackground(row.delete)
            row.delete:SetScript("OnClick", function()
                if row.name then
                    AutoGame_Acc.valeeraProfiles[row.name] = nil
                    if AutoGame_Acc.valeeraActive == row.name then
                        AutoGame_Acc.valeeraActive = nil
                    end
                    RefreshValeeraPanel()
                end
            end)
            valeeraPanel.profileRows[index] = row
        end

        valeeraPanel.debug = CreateFrame("Button", nil, valeeraPanel, "UIPanelButtonTemplate")
        valeeraPanel.debug:SetSize(110, 20)
        valeeraPanel.debug:SetPoint("BOTTOM", 0, 8)
        RemoveButtonBackground(valeeraPanel.debug)
        valeeraPanel.debug:SetScript("OnClick", function()
            InitValeeraDB()
            AutoGame_Settings.valeera.debug = not (AutoGame_Settings.valeera.debug == true)
            RefreshValeeraPanel()
            DumpValeeraDebug()
        end)

        RefreshValeeraPanel()
        return valeeraPanel
    end

    ScheduleValeeraApply = function()
        if valeeraApplyPending or not (C_Timer and C_Timer.After) then
            return
        end
        valeeraApplyPending = true
        local attempts = 0
        local function TryApply()
            attempts = attempts + 1
            local ready = ApplyValeeraProfile()
            -- TRAIT_CONFIG_UPDATED can fire during CommitConfig while this scheduler is
            -- pending. Keep one delayed pass so late-created/refreshed slots are reconciled.
            if (ready and attempts >= 2) or attempts >= 20 then
                valeeraApplyPending = nil
            else
                C_Timer.After(0.1, TryApply)
            end
        end
        C_Timer.After(0, TryApply)
    end

    local function HookValeeraFrame()
        local frame = GetValeeraFrame()
        if frame and frame.HookScript and not valeeraHooked then
            frame:HookScript("OnShow", ScheduleValeeraApply)
            frame:HookScript("OnShow", function()
                local panel = EnsureValeeraPanel()
                if panel then
                    panel:Show()
                end
            end)
            frame:HookScript("OnHide", function()
                if valeeraPanel then
                    valeeraPanel:Hide()
                end
            end)
            valeeraHooked = true
        end
        if frame and frame.IsShown and frame:IsShown() then
            ScheduleValeeraApply()
            local panel = EnsureValeeraPanel()
            if panel then
                panel:Show()
            end
        end
    end

    local function IsValeeraGossipOption(option)
        if type(option) ~= "table" then
            return false
        end
        if COMPANION_OPTIONS[tonumber(option.gossipOptionID)] then
            return true
        end
        local name = type(option.name) == "string" and option.name:lower() or ""
        return name:find("companion", 1, true) ~= nil or name:find("begleiter", 1, true) ~= nil
    end

    local function AutoSelectValeeraGossip()
        InitValeeraDB()
        if not AutoGame_Settings.valeera.autoGossip or (IsShiftKeyDown and IsShiftKeyDown()) then
            return
        end
        if not (C_GossipInfo and type(C_GossipInfo.GetOptions) == "function") then
            return
        end
        local options = C_GossipInfo.GetOptions() or {}
        for _, option in ipairs(options) do
            if IsValeeraGossipOption(option) then
                if type(C_GossipInfo.SelectOption) == "function" then
                    C_GossipInfo.SelectOption(option.gossipOptionID)
                end
                return
            end
        end
    end

    SaveValeeraProfile = function(name, mode)
        local frame = GetValeeraFrame()
        if not (frame and frame.IsShown and frame:IsShown()) then
            print("|cffff0000[fr0z3nUI]|r Open the Companion Supplies window first.")
            return
        end
        local roleSlot, poisonsSlot, combatSlot, utilitySlot = GetValeeraSlots(frame)
        local configID = roleSlot and roleSlot.configID
        configID = configID or (poisonsSlot and poisonsSlot.configID)
        configID = configID or (combatSlot and combatSlot.configID)
        configID = configID or (utilitySlot and utilitySlot.configID)
        if not (roleSlot and poisonsSlot and combatSlot and utilitySlot
            and configID and roleSlot.selectionNodeID
            and poisonsSlot.selectionNodeID
            and combatSlot.selectionNodeID and utilitySlot.selectionNodeID) then
            print("|cffff0000[fr0z3nUI]|r Valeera abilities are not ready yet.")
            return
        end
        local function GetEntry(slot, fallbackConfigID)
            local nodeID = slot.selectionNodeID
            local info = C_Traits.GetNodeInfo(slot.configID or fallbackConfigID, nodeID)
            return info and info.activeEntry and tonumber(info.activeEntry.entryID)
        end
        local role, poisons, combat, utility = GetEntry(roleSlot, configID), GetEntry(poisonsSlot, configID), GetEntry(combatSlot, configID), GetEntry(utilitySlot, configID)
        if not (role and poisons and combat and utility) then
            print("|cffff0000[fr0z3nUI]|r Select an ability in all four Valeera slots first.")
            return
        end
        InitValeeraDB()
        AutoGame_Acc.valeeraProfiles[name] = {
            role = role,
            poisons = poisons,
            poisonsName = GetValeeraEntryName(poisonsSlot.configID or configID, poisons),
            combat = combat,
            combatName = GetValeeraEntryName(combatSlot.configID or configID, combat),
            utility = utility,
            utilityName = GetValeeraEntryName(utilitySlot.configID or configID, utility),
        }
        mode = mode or "account"
        if mode == "character" then
            AutoGame_Char.valeeraProfiles[GetValeeraPlayerKey()] = name
        else
            AutoGame_Acc.valeeraActive = name
        end
        ValeeraDebug("saved profile=" .. tostring(name) .. " role=" .. tostring(role) .. " poisons=" .. tostring(poisons) .. " combat=" .. tostring(combat) .. " utility=" .. tostring(utility))
        print("|cff00ff00[fr0z3nUI]|r Valeera profile '|cffffff00" .. name .. "|r' saved for " .. (mode == "character" and "this character." or "the account."))
    end

    local function ValeeraCommand(message)
        InitValeeraDB()
        local command, argument = tostring(message or ""):match("^(%S*)%s*(.-)$")
        command = command and command:lower() or ""
        argument = argument or ""
        local key = GetValeeraPlayerKey()

        if command == "save" and argument ~= "" then
            SaveValeeraProfile(argument, AutoGame_Settings.valeera.profileMode)
        elseif command == "list" then
            if not next(AutoGame_Acc.valeeraProfiles) then
                print("|cff00ff00[fr0z3nUI]|r No Valeera profiles saved.")
                return
            end
            print("|cff00ff00[fr0z3nUI]|r Valeera profiles:")
            for name in pairs(AutoGame_Acc.valeeraProfiles) do
                local tags = name == AutoGame_Acc.valeeraActive and " (Global)" or ""
                if AutoGame_Char.valeeraProfiles[key] == name then tags = tags .. " (Char)" end
                print("  |cffffff00" .. name .. "|r" .. tags)
            end
        elseif command == "use" and argument ~= "" then
            if AutoGame_Acc.valeeraProfiles[argument] then
                if AutoGame_Settings.valeera.profileMode == "character" then
                    AutoGame_Char.valeeraProfiles[key] = argument
                else
                    AutoGame_Acc.valeeraActive = argument
                end
                print("|cff00ff00[fr0z3nUI]|r Valeera " .. (AutoGame_Settings.valeera.profileMode == "character" and "character" or "account") .. " profile set to '" .. argument .. "'.")
                ScheduleValeeraApply()
            else
                print("|cffff0000[fr0z3nUI]|r Profile not found: " .. argument)
            end
        elseif command == "char" and argument ~= "" then
            if argument:lower() == "off" then
                AutoGame_Char.valeeraProfiles[key] = nil
            elseif AutoGame_Acc.valeeraProfiles[argument] then
                AutoGame_Char.valeeraProfiles[key] = argument
            else
                print("|cffff0000[fr0z3nUI]|r Profile not found: " .. argument)
                return
            end
            ScheduleValeeraApply()
        elseif command == "delete" and argument ~= "" then
            AutoGame_Acc.valeeraProfiles[argument] = nil
            if AutoGame_Acc.valeeraActive == argument then AutoGame_Acc.valeeraActive = nil end
            for playerKey, profileName in pairs(AutoGame_Char.valeeraProfiles) do
                if profileName == argument then AutoGame_Char.valeeraProfiles[playerKey] = nil end
            end
        elseif command == "off" then
            AutoGame_Acc.valeeraActive = nil
        elseif command == "autogossip" or command == "autoclose" then
            local setting = command == "autogossip" and "autoGossip" or "autoClose"
            AutoGame_Settings.valeera[setting] = not AutoGame_Settings.valeera[setting]
            print("|cff00ff00[fr0z3nUI]|r Valeera " .. setting .. ": " .. (AutoGame_Settings.valeera[setting] and "ON" or "OFF"))
        elseif command == "debug" then
            if argument == "on" then
                AutoGame_Settings.valeera.debug = true
            elseif argument == "off" then
                AutoGame_Settings.valeera.debug = false
            end
            DumpValeeraDebug()
        else
            print("|cff00ff00[fr0z3nUI]|r /vap save|use|char|list|delete|off|autogossip|autoclose|debug")
        end
    end

    SLASH_VAP1 = "/vap"
    SlashCmdList.VAP = ValeeraCommand

    valeeraFrame = CreateFrame("Frame")
    valeeraFrame:RegisterEvent("PLAYER_LOGIN")
    valeeraFrame:RegisterEvent("ADDON_LOADED")
    valeeraFrame:RegisterEvent("GOSSIP_SHOW")
    valeeraFrame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
    valeeraFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
    valeeraFrame:SetScript("OnEvent", function(_, event, addon)
        if event == "ADDON_LOADED" and addon ~= "Blizzard_DelvesCompanionConfiguration" then return end
        InitValeeraDB()
        HookValeeraFrame()
        if event == "GOSSIP_SHOW" then
            AutoSelectValeeraGossip()
        end
        if event ~= "PLAYER_LOGIN" then
            ScheduleValeeraApply()
        end
    end)

    HookValeeraFrame()
end

-- TalkUP helpers (StaticPopup hooks).
-- Renamed from fr0z3nUI_GameOptionsPopup.lua / fUI_GOTalkXPOP.lua.

ns.TalkUP = ns.TalkUP or {}

local M = ns.TalkUP

-- ============================================================================
local function InitSV()
    if ns and type(ns._InitSV) == "function" then
        ns._InitSV()
    end
end

-- Context from the gossip auto-selector so we can scope confirmations.
-- { npcID = number|string, optionID = number|string, at = number }
M._lastGossipSelection = M._lastGossipSelection or nil

function M.SetLastGossipSelection(npcID, optionID, entry)
    InitSV()
    local now = GetTime and GetTime() or 0

    local function CopyStringArray(t)
        if type(t) ~= "table" then return nil end
        local out = {}
        for i = 1, #t do
            local v = t[i]
            if v ~= nil then
                out[#out + 1] = tostring(v)
            end
        end
        return (#out > 0) and out or nil
    end

    local xpop = nil
    if type(entry) == "table" then
        if type(entry.xpop) == "table" then
            xpop = {
                which = tostring(entry.xpop.which or "GOSSIP_CONFIRM"),
                within = tonumber(entry.xpop.within) or 3,
                allowAny = (entry.xpop.allowAny == true) and true or false,
                setting = (type(entry.xpop.setting) == "string" and entry.xpop.setting ~= "") and entry.xpop.setting or nil,
                text = (type(entry.xpop.text) == "string") and entry.xpop.text or nil,
                containsAll = CopyStringArray(entry.xpop.containsAll),
                containsAny = CopyStringArray(entry.xpop.containsAny),
            }
        elseif entry.xpopConfirm == true then
            -- Legacy fallback: old builds used xpopConfirm=true for "cannot be undone" style confirmations.
            xpop = {
                which = "GOSSIP_CONFIRM",
                within = 3,
                allowAny = false,
                containsAll = { "are you sure", "cannot be undone" },
            }
        end
    end
    M._lastGossipSelection = {
        npcID = npcID,
        optionID = optionID,
        at = now,
        xpop = xpop,
    }
end

local function Print(msg)
    if ns and type(ns._Print) == "function" then
        ns._Print(msg)
        return
    end
    print("|cff00ccff[FGO]|r " .. tostring(msg))
end

local function GetPopupButtonText(btn)
    if type(btn) ~= "table" then
        return ""
    end
    if type(btn.GetText) == "function" then
        local ok, txt = pcall(btn.GetText, btn)
        if ok and type(txt) == "string" and txt ~= "" then
            return txt
        end
    end
    if type(btn.Text) == "table" and type(btn.Text.GetText) == "function" then
        local ok, txt = pcall(btn.Text.GetText, btn.Text)
        if ok and type(txt) == "string" and txt ~= "" then
            return txt
        end
    end
    return ""
end

local function GetPopupBodyText(popup)
    if type(popup) ~= "table" then
        return ""
    end
    if type(popup.GetText) == "function" then
        local ok, txt = pcall(popup.GetText, popup)
        if ok and type(txt) == "string" and txt ~= "" then
            return txt
        end
    end
    if type(popup.text) == "table" and type(popup.text.GetText) == "function" then
        local ok, txt = pcall(popup.text.GetText, popup.text)
        if ok and type(txt) == "string" and txt ~= "" then
            return txt
        end
    end
    return ""
end

local function DumpActivePopupDebug(which)
    local dbg = AutoGossip_Settings and (AutoGossip_Settings.debugPetPopupsAcc or AutoGossip_Settings.debugAcc)
    if not dbg then return end
    if not (which and C_Timer and C_Timer.After) then return end

    C_Timer.After(0, function()
        local seen = false
        for i = 1, 4 do
            local popup = _G["StaticPopup" .. i]
            if popup and popup.IsShown and popup:IsShown() and popup.which == which then
                seen = true
                local popupText = GetPopupBodyText(popup)
                local b1 = GetPopupButtonText(popup.button1)
                local b2 = GetPopupButtonText(popup.button2)
                Print(string.format(
                    "TalkUP: Popup dump: which=%s text=%s b1=%s b2=%s",
                    tostring(which),
                    tostring(popupText),
                    tostring(b1),
                    tostring(b2)
                ))
                break
            end
        end
        if not seen then
            Print("TalkUP: Popup dump: which=" .. tostring(which) .. " (no matching visible popup)")
        end
    end)
end

local function GetShortStack(skip)
    if not debugstack then
        return ""
    end
    local raw = debugstack((skip or 0) + 1, 12, 12) or ""
    local out = {}
    local n = 0
    for line in raw:gmatch("[^\n]+") do
        if not line:find("GetShortStack", 1, true) and not line:find("debugstack", 1, true) then
            n = n + 1
            out[#out + 1] = line
            if n >= 4 then
                break
            end
        end
    end
    return table.concat(out, " | ")
end

local function GetEntryPrintKey(entry)
    if type(entry) ~= "table" then
        return nil
    end
    local k = entry.print
    if k == nil then
        k = entry.Print
    end
    return k
end

local function GetCachedTier(categoryID)
    if ns and ns.Profs and type(ns.Profs.GetCachedTier) == "function" then
        return ns.Profs.GetCachedTier(categoryID)
    end
    return nil
end

local function GetCachedProfessionKey(professionKey)
    if ns and ns.Profs and type(ns.Profs.GetCachedProfessionKey) == "function" then
        return ns.Profs.GetCachedProfessionKey(professionKey)
    end
    return nil
end

local _lastHintKey, _lastHintAt = nil, 0
local function MaybePrintRuleHint(npcID, optionID, entry)
    local key = GetEntryPrintKey(entry)
    if key == nil then
        return
    end

    -- Table-form hint spec (more robust than string keys):
    -- { msg/text, tier/categoryID, profession/profKey }
    if type(key) == "table" then
        local msg = key.msg or key.text or key.print
        local tier = tonumber(key.tier or key.categoryID)
        local profKey = key.profKey or key.professionKey or key.profession or key.prof

        local knows = nil
        if tier ~= nil then
            knows = GetCachedTier(tier)
        end
        if knows == nil and profKey ~= nil then
            knows = GetCachedProfessionKey(profKey)
        end

        if knows ~= false then
            return
        end
        if type(msg) == "string" and msg ~= "" then
            Print(msg)
        end
        return
    end

    local now = (type(GetTime) == "function") and GetTime() or 0
    local hintKey = tostring(key)
    local spamKey = tostring(npcID) .. ":" .. tostring(optionID) .. ":" .. hintKey
    if spamKey == _lastHintKey and type(now) == "number" and (now - (_lastHintAt or 0)) < 1.0 then
        return
    end
    _lastHintKey, _lastHintAt = spamKey, now

    -- Profession-key hints (robust across trainers): print only if the cached known-profession set
    -- says you do NOT know that profession. Prefix required to avoid breaking generic string prints.
    do
        local prof = hintKey:match("^Prof:(.+)$")
        if prof then
            local knows = GetCachedProfessionKey(prof)
            if knows ~= false then
                return
            end
            Print("Train " .. tostring(prof))
            return
        end
    end

    if hintKey == "MidnightFishing" then
        local dbg = AutoGossip_Settings and AutoGossip_Settings.debugAcc
        if dbg and ns and ns.Talk and type(ns.Talk.PrintDebugOptionsOnShow) == "function" then
            -- Debug helper: dump live option IDs/text so mismatches can be fixed.
            ns.Talk.PrintDebugOptionsOnShow()
        end

        local knows = GetCachedTier(2159)
        if knows == nil and ns and ns.Profs and type(ns.Profs.KnowsFishingClassicOrMidnight) == "function" then
            knows = ns.Profs.KnowsFishingClassicOrMidnight()
        end

        if dbg then
            Print("Hint MidnightFishing: knows=" .. tostring(knows))
        end

        if knows == true then
            return
        end
        if knows == false then
            Print("Train Midnight Fishing")
        end
        return
    end

    if hintKey == "MidnightCooking" then
        local dbg = AutoGossip_Settings and AutoGossip_Settings.debugAcc
        if dbg and ns and ns.Talk and type(ns.Talk.PrintDebugOptionsOnShow) == "function" then
            -- Debug helper: dump live option IDs/text so mismatches can be fixed.
            ns.Talk.PrintDebugOptionsOnShow()
        end

        local knows = GetCachedTier(2156)
        if ns and ns.Profs and type(ns.Profs.KnowsCookingMidnight) == "function" then
            -- Do NOT trust cached=false here: if the player just trained, we want to
            -- immediately re-check and flip the cache to true.
            if knows ~= true then
                knows = ns.Profs.KnowsCookingMidnight()
            end
        end

        if dbg then
            Print("Hint MidnightCooking: knows=" .. tostring(knows))
        end

        if knows == true then
            return
        end
        if knows == false then
            local msg = "SKILL:  Midnight Cooking Missing"
            if type(WrapTextInColorCode) == "function" then
                msg = WrapTextInColorCode(msg, "ffff8000")
            end
            Print(msg)
        end
        return
    end

    -- Generic fallback: print the provided string.
    if hintKey ~= "" then
        Print(hintKey)
    end
end

-- Public hook for the gossip auto-selector.
M.MaybePrintRuleHint = MaybePrintRuleHint


local function TryAutoConfirmSelectedRulePopup(which, text_arg1, text_arg2, dialogText)
    InitSV()

    local dbg = AutoGossip_Settings and (AutoGossip_Settings.debugPetPopupsAcc or AutoGossip_Settings.debugAcc)
    local function D(msg)
        if dbg then
            Print("TalkUP: " .. tostring(msg))
        end
    end

    -- Safety: only auto-confirm known gossip-ish confirmations.
    -- (Do NOT accept arbitrary popups by default.)
    --
    -- Note: Spirit Healer resurrect confirmations can be shown as the "DEATH" or "XP_LOSS" popup
    -- on some clients/flows, even though they conceptually behave like a gossip confirm.
    local whichStr = tostring(which or "")
    if whichStr ~= "GOSSIP_CONFIRM" and whichStr ~= "CONFIRM_BINDER" and whichStr ~= "SPELL_CONFIRMATION_PROMPT" and whichStr ~= "DEATH" and whichStr ~= "XP_LOSS" then
        D("Skip popup (which=" .. whichStr .. ")")
        return
    end
    if not AutoGossip_Settings then return end

    local function GetNpcIDFromGuid(guid)
        if type(guid) ~= "string" then
            return nil
        end
        if (ns and type(ns.IsSecretString) == "function" and ns.IsSecretString(guid)) or (type(issecretvalue) == "function" and issecretvalue(guid)) then
            return nil
        end
        local _, _, _, _, _, npcID = strsplit("-", guid)
        return tonumber(npcID)
    end

    local function GetCurrentNpcID()
        local guid = (UnitGUID and (UnitGUID("npc") or UnitGUID("target")))
        local npcID = GetNpcIDFromGuid(guid)
        if npcID then
            return npcID
        end
        if C_PlayerInteractionManager and C_PlayerInteractionManager.GetInteractionTarget then
            local targetGuid = C_PlayerInteractionManager.GetInteractionTarget()
            npcID = GetNpcIDFromGuid(targetGuid)
            if npcID then
                return npcID
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

    local function MakeRuleKey(npcID, optionID)
        return tostring(npcID) .. ":" .. tostring(optionID)
    end

    local function IsDisabledTable(disabledDb, npcID, optionID)
        if type(disabledDb) ~= "table" then
            return false
        end
        local npcTable = disabledDb[npcID]
        if type(npcTable) == "table" and npcTable[optionID] then
            return true
        end
        return disabledDb[MakeRuleKey(npcID, optionID)] and true or false
    end

    local function TryHydrateXpopContext(ctx)
        if type(ctx) ~= "table" then
            return false
        end
        local npcID = ctx.npcID
        local optionID = ctx.optionID
        if npcID == nil or optionID == nil then
            return false
        end

        local function Consider(npcTable, disabled1, disabled2)
            local e = LookupRuleEntry(npcTable, optionID)
            if e == nil then return nil end
            if IsDisabledTable(disabled1, npcID, optionID) then return nil end
            if IsDisabledTable(disabled2, npcID, optionID) then return nil end
            return e
        end

        local entry = nil
        if AutoGossip_Char and type(AutoGossip_Char) == "table" then
            entry = Consider(AutoGossip_Char[npcID] or AutoGossip_Char[tostring(npcID)], AutoGossip_CharSettings and AutoGossip_CharSettings.disabled, nil)
        end
        if entry == nil and AutoGossip_Acc and type(AutoGossip_Acc) == "table" then
            entry = Consider(AutoGossip_Acc[npcID] or AutoGossip_Acc[tostring(npcID)], AutoGossip_Settings and AutoGossip_Settings.disabled, AutoGossip_CharSettings and AutoGossip_CharSettings.disabledAcc)
        end
        if entry == nil then
            local rules = ns and ns.db and ns.db.rules
            if type(rules) == "table" then
                entry = Consider(rules[npcID] or rules[tostring(npcID)], AutoGossip_Settings and AutoGossip_Settings.disabledDB, AutoGossip_CharSettings and AutoGossip_CharSettings.disabledDB)
            end
        end

        if entry ~= nil and type(M.SetLastGossipSelection) == "function" then
            pcall(M.SetLastGossipSelection, npcID, optionID, entry)
            return true
        end
        return false
    end

    -- Prefer the actual text passed to StaticPopup_Show (text args).
    -- StaticPopupDialogs[which].text can be a template/format string and won't necessarily contain
    -- the final rendered message (which is what we want to match against).
    local a1 = (text_arg1 ~= nil) and tostring(text_arg1) or ""
    local a2 = (text_arg2 ~= nil) and tostring(text_arg2) or ""

    local formattedDialogText = ""
    if type(dialogText) == "string" and dialogText ~= "" and string and string.format then
        -- Many popups (e.g. CONFIRM_BINDER) provide a format string + args.
        -- Build the rendered message so containsAny/containsAll can match what the user sees.
        local okF, v = pcall(string.format, dialogText, a1, a2)
        if okF and type(v) == "string" then
            formattedDialogText = v
        end
    end

    local text = ""
    -- If we successfully rendered a full sentence, prefer that.
    if formattedDialogText ~= "" and formattedDialogText:find("%s", 1, true) == nil then
        text = formattedDialogText
    elseif a1 ~= "" and a2 ~= "" then
        -- Some popups split message pieces into args; concatenate as a fallback.
        text = a1 .. " " .. a2
    elseif a1 ~= "" then
        text = a1
    elseif a2 ~= "" then
        text = a2
    elseif formattedDialogText ~= "" then
        text = formattedDialogText
    elseif type(dialogText) == "string" and dialogText ~= "" then
        text = dialogText
    end
    if text == "" then
        D("No popup text")
        return
    end

    D(string.format(
        "Popup debug: which=%s a1=%s a2=%s rendered=%s",
        whichStr,
        tostring(a1),
        tostring(a2),
        tostring(text)
    ))

    DumpActivePopupDebug(which)

    local norm = text:gsub("â€™", "'"):lower()

    local function IsSpiritHealerResPopupText()
        -- Conservative match: these phrases are strongly associated with Spirit Healer resurrect confirms.
        local needles = {
            "resurrection sickness",
            "lose experience",
            "return to your corpse",
            "find your corpse",
        }
        for i = 1, #needles do
            local n = needles[i]
            if n and n ~= "" and norm:find(n, 1, true) ~= nil then
                return true
            end
        end
        return false
    end

    local function containsAll(list)
        if type(list) ~= "table" or #list == 0 then return true end
        for i = 1, #list do
            local needle = tostring(list[i] or "")
            if needle ~= "" then
                if norm:find(needle:gsub("â€™", "'"):lower(), 1, true) == nil then
                    return false
                end
            end
        end
        return true
    end

    local function containsAny(list)
        if type(list) ~= "table" or #list == 0 then return true end
        for i = 1, #list do
            local needle = tostring(list[i] or "")
            if needle ~= "" then
                if norm:find(needle:gsub("â€™", "'"):lower(), 1, true) ~= nil then
                    return true
                end
            end
        end
        return false
    end

    local function BuildXpopFromEntry(entry)
        if type(entry) ~= "table" then
            return nil
        end
        if type(entry.xpop) == "table" then
            local function CopyStringArray(t)
                if type(t) ~= "table" then return nil end
                local out = {}
                for i = 1, #t do
                    local v = t[i]
                    if v ~= nil then
                        out[#out + 1] = tostring(v)
                    end
                end
                return (#out > 0) and out or nil
            end
            return {
                which = tostring(entry.xpop.which or "GOSSIP_CONFIRM"),
                within = tonumber(entry.xpop.within) or 3,
                allowAny = (entry.xpop.allowAny == true) and true or false,
                setting = (type(entry.xpop.setting) == "string" and entry.xpop.setting ~= "") and entry.xpop.setting or nil,
                text = (type(entry.xpop.text) == "string") and entry.xpop.text or nil,
                containsAll = CopyStringArray(entry.xpop.containsAll),
                containsAny = CopyStringArray(entry.xpop.containsAny),
            }
        end
        if entry.xpopConfirm == true then
            return {
                which = "GOSSIP_CONFIRM",
                within = 3,
                allowAny = false,
                containsAll = { "are you sure", "cannot be undone" },
            }
        end
        return nil
    end

    local function WhichMatches(xpopWhich)
        local expectedWhich = tostring(xpopWhich or "")
        if expectedWhich == whichStr then
            return true
        end
        -- Back-compat: treat GOSSIP_CONFIRM as a generic confirm bucket.
        if expectedWhich == "GOSSIP_CONFIRM" then
            if whichStr == "CONFIRM_BINDER" then
                return true
            end
            if whichStr == "SPELL_CONFIRMATION_PROMPT" then
                return true
            end
            -- Spirit Healer resurrect confirmation.
            if whichStr == "DEATH" then
                return true
            end
            if whichStr == "XP_LOSS" then
                return true
            end
        end
        return false
    end

    local function TextMatches(xpop)
        if type(xpop) ~= "table" then
            return false
        end
        if xpop.allowAny == true then
            return true
        end
        local requiredAll = xpop.containsAll
        local requiredAny = xpop.containsAny
        local requiredText = (type(xpop.text) == "string") and xpop.text or ""
        if requiredText ~= "" then
            return (norm:find(requiredText:gsub("â€™", "'"):lower(), 1, true) ~= nil)
        end
        local hasConstraints = (type(requiredAll) == "table" and #requiredAll > 0) or (type(requiredAny) == "table" and #requiredAny > 0)
        if not hasConstraints then
            return false
        end
        return containsAll(requiredAll) and containsAny(requiredAny)
    end

    -- Try to resolve xpop context. Prefer explicit last-selection context, but if it doesn't exist
    -- (e.g. because the UI called a cached SelectOption), resolve by scanning this NPC's rules.
    local ctx = M and M._lastGossipSelection or nil
    local xpop = ctx and ctx.xpop or nil
    if type(xpop) ~= "table" then
        local hydrated = TryHydrateXpopContext(ctx)
        ctx = M and M._lastGossipSelection or ctx
        xpop = ctx and ctx.xpop or nil
        if type(xpop) == "table" and hydrated then
            D("Hydrated xpop context")
        end
    end

    if type(xpop) ~= "table" then
        local npcID = (ctx and ctx.npcID) or GetCurrentNpcID()
        if npcID then
            local function ConsiderScope(scopeName, npcTable, disabled1, disabled2)
                if type(npcTable) ~= "table" then return false end
                for optID, entry in pairs(npcTable) do
                    if optID ~= "__meta" and type(entry) == "table" then
                        local optionID = tonumber(optID) or optID
                        if optionID ~= nil and not IsDisabledTable(disabled1, npcID, optionID) and not IsDisabledTable(disabled2, npcID, optionID) then
                            local candX = BuildXpopFromEntry(entry)
                            if candX and WhichMatches(candX.which) and TextMatches(candX) then
                                if type(M.SetLastGossipSelection) == "function" then
                                    pcall(M.SetLastGossipSelection, npcID, optionID, entry)
                                    ctx = M and M._lastGossipSelection or ctx
                                    xpop = ctx and ctx.xpop or nil
                                end
                                if type(xpop) == "table" then
                                    D("Resolved xpop from popup (" .. tostring(scopeName) .. "): npc=" .. tostring(npcID) .. " opt=" .. tostring(optionID))
                                    return true
                                end
                            end
                        end
                    end
                end
                return false
            end

            local resolved = false
            if AutoGossip_Char and type(AutoGossip_Char) == "table" then
                resolved = ConsiderScope("char", AutoGossip_Char[npcID] or AutoGossip_Char[tostring(npcID)], AutoGossip_CharSettings and AutoGossip_CharSettings.disabled, nil)
            end
            if (not resolved) and AutoGossip_Acc and type(AutoGossip_Acc) == "table" then
                resolved = ConsiderScope("acc", AutoGossip_Acc[npcID] or AutoGossip_Acc[tostring(npcID)], AutoGossip_Settings and AutoGossip_Settings.disabled, AutoGossip_CharSettings and AutoGossip_CharSettings.disabledAcc)
            end
            if not resolved then
                local rules = ns and ns.db and ns.db.rules
                if type(rules) == "table" then
                    resolved = ConsiderScope("db", rules[npcID] or rules[tostring(npcID)], AutoGossip_Settings and AutoGossip_Settings.disabledDB, AutoGossip_CharSettings and AutoGossip_CharSettings.disabledDB)
                end
            end
        end
    end

    if type(xpop) ~= "table" then
        -- Fallback: some resurrect confirmations can fire without any gossip option selection context.
        -- Keep this extremely narrow so we don't accept unrelated death/XP popups.
        local fallbackEnabled = (AutoGossip_Settings and (AutoGossip_Settings.autoAcceptTalkUpConfirmAcc or AutoGossip_Settings.autoAcceptWhitemaneSkipAcc)) and true or false
        if fallbackEnabled and (whichStr == "DEATH" or whichStr == "XP_LOSS") and IsSpiritHealerResPopupText() then
            if not (C_Timer and C_Timer.After) then
                return
            end

            C_Timer.After(0, function()
                for i = 1, 4 do
                    local popup = _G["StaticPopup" .. i]
                    if popup and popup.IsShown and popup:IsShown() and popup.which == which then
                        local ok = false
                        if popup.button1 and popup.button1.Click then
                            ok = pcall(popup.button1.Click, popup.button1)
                        elseif StaticPopup_OnClick then
                            ok = pcall(StaticPopup_OnClick, popup, 1)
                        end
                        if ok then
                            if AutoGossip_Settings and AutoGossip_Settings.debugPetPopupsAcc then
                                Print("Auto-confirmed talk popup (fallback)")
                            end
                            M._lastGossipSelection = nil
                        end
                        return
                    end
                end
            end)
            return
        end

        D("No xpop context")
        return
    end

    local enabled = (AutoGossip_Settings.autoAcceptTalkUpConfirmAcc or AutoGossip_Settings.autoAcceptWhitemaneSkipAcc) and true or false
    if type(xpop.setting) == "string" and xpop.setting ~= "" then
        enabled = enabled or (AutoGossip_Settings[xpop.setting] == true)
    end
    if not enabled then
        D("Disabled by settings")
        return
    end

    if not WhichMatches(xpop.which) then
        D("Which mismatch: expected=" .. tostring(xpop.which or "") .. ", got=" .. whichStr)
        return
    end

    local matched = TextMatches(xpop)

    if not matched then
        D("Text did not match (text='" .. norm .. "')")
        return
    end

    local at = ctx and tonumber(ctx.at) or 0

    -- Safety: only if it fires right after we selected the option.
    local within = tonumber(xpop.within) or 3
    if GetTime and at > 0 and (GetTime() - at) > within then
        D("Out of window: " .. tostring(GetTime() - at) .. "s > " .. tostring(within) .. "s")
        return
    end

    if not (C_Timer and C_Timer.After) then
        return
    end

    -- Defer one frame so StaticPopup has finished setting up.
    C_Timer.After(0, function()
        for i = 1, 4 do
            local popup = _G["StaticPopup" .. i]
            if popup and popup.IsShown and popup:IsShown() and popup.which == which then
                if dbg then
                    local popupText = GetPopupBodyText(popup)
                    local b1 = GetPopupButtonText(popup.button1)
                    local b2 = GetPopupButtonText(popup.button2)
                    Print(string.format(
                        "TalkUP: Popup match: which=%s text=%s b1=%s b2=%s",
                        tostring(which),
                        tostring(popupText),
                        tostring(b1),
                        tostring(b2)
                    ))
                end
                local ok = false
                if popup.button1 and popup.button1.Click then
                    ok = pcall(popup.button1.Click, popup.button1)
                elseif StaticPopup_OnClick then
                    ok = pcall(StaticPopup_OnClick, popup, 1)
                end
                if ok then
                    if AutoGossip_Settings and AutoGossip_Settings.debugPetPopupsAcc then
                        Print("Auto-confirmed talk popup")
                    end
                    -- Consume so unrelated future popups can't match stale context.
                    M._lastGossipSelection = nil
                end
                return
            end
        end
    end)
end

local petPopupDebugHooked = false
local gossipSelectHooked = false
local legacySelectHooked = false

function M.Setup()
    if petPopupDebugHooked then
        return
    end
    petPopupDebugHooked = true

    -- Capture manual gossip selections too so xpop confirmations can still be auto-accepted
    -- even when auto-select is blocked or when the matching rule is marked noAuto/manual.
    local function TryHookGossipSelect()
        if gossipSelectHooked then
            -- Still allow installing the legacy hook if it wasn't available yet.
            if legacySelectHooked then
                return
            end
        end
        if not (hooksecurefunc and C_GossipInfo and type(C_GossipInfo.SelectOption) == "function") then
            -- C_GossipInfo might not exist yet; we can still try the legacy hook.
            if hooksecurefunc and (not legacySelectHooked) and type(SelectGossipOption) == "function" then
                legacySelectHooked = true
                local dbg = AutoGossip_Settings and AutoGossip_Settings.debugPetPopupsAcc
                if dbg then
                    Print("TalkUP: Hooked SelectGossipOption")
                end
                hooksecurefunc("SelectGossipOption", function(arg1, arg2)
                    InitSV()
                    local idx = tonumber(arg1) or tonumber(arg2)
                    if not idx then return end
                    if not (C_GossipInfo and C_GossipInfo.GetOptions) then return end
                    local opts = C_GossipInfo.GetOptions() or {}
                    local opt = opts[idx]
                    local optionID = opt and (opt.gossipOptionID or opt.optionID or opt.id)
                    optionID = tonumber(optionID)
                    if not optionID then return end
                    if type(M.SetLastGossipSelection) ~= "function" then return end

                    local preferredNpcID = nil
                    local guid = (UnitGUID and (UnitGUID("npc") or UnitGUID("target")))
                    if type(guid) == "string" then
                        local _, _, _, _, _, npcID = strsplit("-", guid)
                        preferredNpcID = tonumber(npcID)
                    end

                    pcall(M.SetLastGossipSelection, preferredNpcID, optionID, nil)
                    local dbg = AutoGossip_Settings and AutoGossip_Settings.debugPetPopupsAcc
                    if dbg then
                        Print("TalkUP: Captured selection (legacy index): npc=" .. tostring(preferredNpcID) .. " opt=" .. tostring(optionID))
                    end
                end)
            end
            return
        end

        gossipSelectHooked = true

        local dbg = AutoGossip_Settings and AutoGossip_Settings.debugPetPopupsAcc
        if dbg then
            Print("TalkUP: Hooked C_GossipInfo.SelectOption")
        end

        local function GetNpcIDFromGuid(guid)
            if type(guid) ~= "string" then
                return nil
            end
            if (ns and type(ns.IsSecretString) == "function" and ns.IsSecretString(guid)) or (type(issecretvalue) == "function" and issecretvalue(guid)) then
                return nil
            end
            local _, _, _, _, _, npcID = strsplit("-", guid)
            return tonumber(npcID)
        end

        local function GetCurrentNpcID()
            local guid = (UnitGUID and (UnitGUID("npc") or UnitGUID("target")))
            local npcID = GetNpcIDFromGuid(guid)
            if npcID then
                return npcID
            end
            if C_PlayerInteractionManager and C_PlayerInteractionManager.GetInteractionTarget then
                local targetGuid = C_PlayerInteractionManager.GetInteractionTarget()
                npcID = GetNpcIDFromGuid(targetGuid)
                if npcID then
                    return npcID
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
            return (type(npcTable) == "table") and npcTable or nil
        end

        local function MakeRuleKey(npcID, optionID)
            return tostring(npcID) .. ":" .. tostring(optionID)
        end

        local function IsDisabledTable(disabledDb, npcID, optionID)
            if type(disabledDb) ~= "table" then
                return false
            end
            local npcTable = disabledDb[npcID]
            if type(npcTable) == "table" and npcTable[optionID] then
                return true
            end
            return disabledDb[MakeRuleKey(npcID, optionID)] and true or false
        end

        local function HasXpop(entry)
            if type(entry) ~= "table" then return false end
            if type(entry.xpop) == "table" then return true end
            if entry.xpopConfirm == true then return true end
            return false
        end

        local function FindEntryForOption(optionID, preferredNpcID)
            local dbg = AutoGossip_Settings and AutoGossip_Settings.debugPetPopupsAcc
            local function D(msg)
                if dbg then
                    Print("TalkUP: " .. tostring(msg))
                end
            end

            -- Prefer exact NPC bucket if we can resolve it.
            local function TryBucket(scopeName, npcID, npcTable, disabled1, disabled2)
                local e = LookupRuleEntry(npcTable, optionID)
                if e == nil then return nil end
                if npcID and disabled1 and IsDisabledTable(disabled1, npcID, optionID) then return nil end
                if npcID and disabled2 and IsDisabledTable(disabled2, npcID, optionID) then return nil end
                return { npcID = npcID, entry = e, scope = scopeName }
            end

            if preferredNpcID then
                if AutoGossip_Char and type(AutoGossip_Char) == "table" then
                    local npcTable = AutoGossip_Char[preferredNpcID] or AutoGossip_Char[tostring(preferredNpcID)]
                    local hit = TryBucket("char", preferredNpcID, npcTable, AutoGossip_CharSettings and AutoGossip_CharSettings.disabled, nil)
                    if hit then return hit end
                end
                if AutoGossip_Acc and type(AutoGossip_Acc) == "table" then
                    local npcTable = AutoGossip_Acc[preferredNpcID] or AutoGossip_Acc[tostring(preferredNpcID)]
                    local hit = TryBucket("acc", preferredNpcID, npcTable, AutoGossip_Settings and AutoGossip_Settings.disabled, AutoGossip_CharSettings and AutoGossip_CharSettings.disabledAcc)
                    if hit then return hit end
                end
                local dbNpc = GetDbNpcTable(preferredNpcID)
                local hit = TryBucket("db", preferredNpcID, dbNpc, AutoGossip_Settings and AutoGossip_Settings.disabledDB, AutoGossip_CharSettings and AutoGossip_CharSettings.disabledDB)
                if hit then return hit end
            end

            -- Fallback: scan all buckets for this optionID.
            -- Prefer entries that carry xpop metadata.
            local best = nil
            local bestHasX = false

            local function Consider(scopeName, npcID, npcTable, disabled1, disabled2)
                if type(npcTable) ~= "table" then return end
                local e = LookupRuleEntry(npcTable, optionID)
                if e == nil then return end
                if npcID and disabled1 and IsDisabledTable(disabled1, npcID, optionID) then return end
                if npcID and disabled2 and IsDisabledTable(disabled2, npcID, optionID) then return end

                local hx = HasXpop(e)
                if best == nil or (hx and not bestHasX) then
                    best = { npcID = npcID, entry = e, scope = scopeName }
                    bestHasX = hx
                end
            end

            if AutoGossip_Char and type(AutoGossip_Char) == "table" then
                for npcID, npcTable in pairs(AutoGossip_Char) do
                    if npcID ~= "__meta" then
                        local n = tonumber(npcID) or npcID
                        Consider("char", n, npcTable, AutoGossip_CharSettings and AutoGossip_CharSettings.disabled, nil)
                        if bestHasX then break end
                    end
                end
            end

            if not bestHasX and AutoGossip_Acc and type(AutoGossip_Acc) == "table" then
                for npcID, npcTable in pairs(AutoGossip_Acc) do
                    if npcID ~= "__meta" then
                        local n = tonumber(npcID) or npcID
                        Consider("acc", n, npcTable, AutoGossip_Settings and AutoGossip_Settings.disabled, AutoGossip_CharSettings and AutoGossip_CharSettings.disabledAcc)
                        if bestHasX then break end
                    end
                end
            end

            if not bestHasX then
                local rules = ns and ns.db and ns.db.rules
                if type(rules) == "table" then
                    for npcID, npcTable in pairs(rules) do
                        if type(npcTable) == "table" then
                            local n = tonumber(npcID) or npcID
                            Consider("db", n, npcTable, AutoGossip_Settings and AutoGossip_Settings.disabledDB, AutoGossip_CharSettings and AutoGossip_CharSettings.disabledDB)
                            if bestHasX then break end
                        end
                    end
                else
                    D("No ns.db.rules table")
                end
            end

            return best
        end

        local function NormalizeOptionID(v)
            if type(v) == "number" then
                return v
            end
            if type(v) == "string" then
                return tonumber(v)
            end
            if type(v) == "table" then
                local id = v.gossipOptionID or v.optionID or v.id or v.gossipOptionId
                if type(id) == "string" or type(id) == "number" then
                    return tonumber(id)
                end
            end
            return nil
        end

        hooksecurefunc(C_GossipInfo, "SelectOption", function(arg1, arg2)
            InitSV()
            local optionID = NormalizeOptionID(arg1) or NormalizeOptionID(arg2)
            if not optionID then
                local dbg = AutoGossip_Settings and AutoGossip_Settings.debugPetPopupsAcc
                if dbg then
                    Print("TalkUP: SelectOption hook could not parse optionID (arg1=" .. tostring(type(arg1)) .. ", arg2=" .. tostring(type(arg2)) .. ")")
                end
                return
            end

            local preferredNpcID = GetCurrentNpcID()
            local hit = FindEntryForOption(optionID, preferredNpcID)
            if type(M.SetLastGossipSelection) == "function" then
                local dbg = AutoGossip_Settings and AutoGossip_Settings.debugPetPopupsAcc
                if hit and hit.entry ~= nil then
                    if dbg then
                        Print("TalkUP: Captured selection (" .. tostring(hit.scope) .. "): npc=" .. tostring(hit.npcID) .. " opt=" .. tostring(optionID) .. " hasXpop=" .. tostring(HasXpop(hit.entry)))
                    end
                    pcall(M.SetLastGossipSelection, hit.npcID or preferredNpcID, optionID, hit.entry)
                    if preferredNpcID and ((hit.npcID or preferredNpcID) == preferredNpcID) then
                        pcall(MaybePrintRuleHint, hit.npcID or preferredNpcID, optionID, hit.entry)
                    end
                else
                    if dbg then
                        Print("TalkUP: Captured selection (no rule): npc=" .. tostring(preferredNpcID) .. " opt=" .. tostring(optionID))
                    end
                    -- Record the selection anyway so the popup handler can try to hydrate xpop context.
                    pcall(M.SetLastGossipSelection, preferredNpcID, optionID, nil)
                end
            end
        end)
    end

    TryHookGossipSelect()

    if hooksecurefunc and StaticPopup_Show then
        hooksecurefunc("StaticPopup_Show", function(which, text_arg1, text_arg2)
            InitSV()
            -- Load order safety: ensure gossip hook is installed before we attempt to use its context.
            TryHookGossipSelect()
            if not (AutoGossip_Settings and AutoGossip_Settings.debugPetPopupsAcc) then
                local dialogText = ""
                local dialog = (StaticPopupDialogs and which) and StaticPopupDialogs[which] or nil
                if dialog and dialog.text then
                    if type(dialog.text) == "function" then
                        local ok, val = pcall(dialog.text)
                        dialogText = ok and tostring(val or "") or ""
                    else
                        dialogText = tostring(dialog.text or "")
                    end
                end
                TryAutoConfirmSelectedRulePopup(which, text_arg1, text_arg2, dialogText)
                return
            end

            local whichStr = which and tostring(which) or "(nil)"
            local a1 = text_arg1 and tostring(text_arg1) or ""
            local a2 = text_arg2 and tostring(text_arg2) or ""
            local dialogText = ""
            local dialog = (StaticPopupDialogs and which) and StaticPopupDialogs[which] or nil
            if dialog and dialog.text then
                if type(dialog.text) == "function" then
                    local ok, val = pcall(dialog.text)
                    dialogText = ok and tostring(val or "") or ""
                else
                    dialogText = tostring(dialog.text or "")
                end
            end
            local stack = GetShortStack(2)
            if dialogText ~= "" then
                Print(string.format("StaticPopup: %s | text=%s | a1=%s | a2=%s", whichStr, dialogText, a1, a2))
            else
                Print(string.format("StaticPopup: %s | a1=%s | a2=%s", whichStr, a1, a2))
            end
            if stack ~= "" then
                Print("StaticPopup stack: " .. stack)
            end

            DumpActivePopupDebug(which)

            TryAutoConfirmSelectedRulePopup(which, text_arg1, text_arg2, dialogText)
        end)
    end

    -- Retry gossip hook on common events (some clients load C_GossipInfo late or swap tables after login).
    if CreateFrame then
        local f = CreateFrame("Frame")
        f:RegisterEvent("PLAYER_LOGIN")
        f:RegisterEvent("GOSSIP_SHOW")
        f:SetScript("OnEvent", function()
            TryHookGossipSelect()
        end)
    end
end
