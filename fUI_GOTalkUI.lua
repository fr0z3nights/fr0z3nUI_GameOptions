---@diagnostic disable: undefined-global

local addonName, ns = ...
if type(ns) ~= "table" then ns = {} end

-- Talk tab (formerly "Gossiping") UI.
-- Built from fr0z3nUI_GameOptions.lua to keep the main file slimmer.

function ns.TalkUI_Build(frame, panel, helpers)
    helpers = helpers or {}

    local f = frame
    local browserPanel = panel

    local InitSV = helpers.InitSV or function(...) end
    local HideFauxScrollBarAndEnableWheel = helpers.HideFauxScrollBarAndEnableWheel or function(...) end

    local IsDisabled = helpers.IsDisabled or function(...) return false end
    local IsDisabledDB = helpers.IsDisabledDB or function(...) return false end
    local IsDisabledDBOnChar = helpers.IsDisabledDBOnChar or function(...) return false end
    local IsDisabledAccOnChar = helpers.IsDisabledAccOnChar or function(...) return false end
    local SetDisabled = helpers.SetDisabled or function(...) end
    local SetDisabledDB = helpers.SetDisabledDB or function(...) end
    local SetDisabledDBOnChar = helpers.SetDisabledDBOnChar or function(...) end
    local SetDisabledAccOnChar = helpers.SetDisabledAccOnChar or function(...) end
    local DeleteRule = helpers.DeleteRule or function(...) end

    if not (f and browserPanel) then
        return function() end
    end

    -- Rules browser (all rules)
    InitSV()
    AutoGossip_UI.treeState = AutoGossip_UI.treeState or {}

    local function GetTreeExpanded(key, defaultValue)
        local v = AutoGossip_UI.treeState[key]
        if v == nil then
            return defaultValue and true or false
        end
        return v and true or false
    end

    local function SetTreeExpanded(key, expanded)
        AutoGossip_UI.treeState[key] = expanded and true or false
    end

    local browserArea = CreateFrame("Frame", nil, browserPanel, "BackdropTemplate")
    browserArea:SetPoint("TOPLEFT", browserPanel, "TOPLEFT", 10, -54)
    browserArea:SetPoint("BOTTOMRIGHT", browserPanel, "BOTTOMRIGHT", -10, 50)
    browserArea:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        tile = true,
        tileSize = 16,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    browserArea:SetBackdropColor(0, 0, 0, 0.25)
    f._browserArea = browserArea

    local browserHint = browserPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    browserHint:SetPoint("BOTTOMLEFT", browserPanel, "BOTTOMLEFT", 12, 28)
    browserHint:SetText("")
    browserHint:Hide()
    f._browserHint = browserHint

    local browserEmpty = browserArea:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    browserEmpty:SetPoint("CENTER", browserArea, "CENTER", 0, 0)
    browserEmpty:SetText("No rules found")
    f._browserEmpty = browserEmpty

    local browserScroll = CreateFrame("ScrollFrame", nil, browserArea, "FauxScrollFrameTemplate")
    browserScroll:SetPoint("TOPLEFT", browserArea, "TOPLEFT", 4, -4)
    browserScroll:SetPoint("BOTTOMRIGHT", browserArea, "BOTTOMRIGHT", -4, 4)
    f.browserScroll = browserScroll

    local BROW_ROW_H = 18
    local BROW_ROWS = 18
    local browRows = {}
    f._browRows = browRows

    HideFauxScrollBarAndEnableWheel(browserScroll, BROW_ROW_H)

    local function CollectAllRules()
        InitSV()
        local out = {}

        local function AddFrom(scope)
            local db = (scope == "acc") and AutoGossip_Acc or AutoGossip_Char
            if type(db) ~= "table" then
                return
            end
            for npcID, npcTable in pairs(db) do
                if type(npcTable) == "table" then
                    local defaultZoneName, defaultNpcName
                    if type(npcTable.__meta) == "table" then
                        defaultZoneName = npcTable.__meta.zoneName or npcTable.__meta.zone
                        defaultNpcName = npcTable.__meta.npcName or npcTable.__meta.npc
                    end

                    for optionID, data in pairs(npcTable) do
                        if optionID ~= "__meta" then
                            local numericID = tonumber(optionID) or optionID
                            local text = ""
                            local ruleType = ""
                            local zoneName = "Unknown"
                            local npcName = ""
                            if type(data) == "table" then
                                text = data.text or ""
                                ruleType = data.type or ""
                                zoneName = data.zoneName or data.zone or defaultZoneName or zoneName
                                npcName = data.npcName or data.npc or defaultNpcName or npcName
                            end
                            table.insert(out, {
                                scope = scope,
                                npcID = tonumber(npcID) or npcID,
                                optionID = numericID,
                                text = text,
                                ruleType = ruleType,
                                zone = zoneName,
                                npcName = npcName,
                                isDisabled = IsDisabled(scope, npcID, numericID),
                            })
                        end
                    end
                end
            end
        end

        AddFrom("char")
        AddFrom("acc")

        local rules = ns and ns.db and ns.db.rules
        if type(rules) == "table" then
            for npcID, npcTable in pairs(rules) do
                if type(npcTable) == "table" then
                    local defaultZoneName, defaultNpcName
                    if type(npcTable.__meta) == "table" then
                        defaultZoneName = npcTable.__meta.zoneName or npcTable.__meta.zone
                        defaultNpcName = npcTable.__meta.npcName or npcTable.__meta.npc
                    end

                    for optionID, data in pairs(npcTable) do
                        if optionID ~= "__meta" then
                            local numericID = tonumber(optionID) or optionID
                            local text = ""
                            local ruleType = ""
                            local zoneName = "Unknown"
                            local npcName = ""
                            if type(data) == "table" then
                                text = data.text or ""
                                ruleType = data.type or ""
                                zoneName = data.zoneName or data.zone or defaultZoneName or zoneName
                                npcName = data.npcName or data.npc or defaultNpcName or npcName
                            end
                            table.insert(out, {
                                scope = "db",
                                npcID = tonumber(npcID) or npcID,
                                optionID = numericID,
                                text = text,
                                ruleType = ruleType,
                                zone = zoneName,
                                npcName = npcName,
                                isDisabled = (IsDisabledDB(npcID, numericID) or IsDisabledDBOnChar(npcID, numericID)) and true or false,
                            })
                        end
                    end
                end
            end
        end

        return out
    end

    local function BuildVisibleTreeNodes(allRules)
        local function Trim(s)
            if type(s) ~= "string" then
                return ""
            end
            return (s:gsub("^%s+", ""):gsub("%s+$", ""))
        end

        local function SplitZoneContinent(zoneString)
            zoneString = Trim(zoneString)
            if zoneString == "" then
                return "Unknown", nil
            end

            -- Split on the last comma so e.g. "The Waking Shores, Dragon Isles" works.
            local zonePart, continentPart = zoneString:match("^(.*),%s*([^,]+)$")
            zonePart = Trim(zonePart)
            continentPart = Trim(continentPart)
            if zonePart ~= "" and continentPart ~= "" then
                return zonePart, continentPart
            end

            return zoneString, nil
        end

        -- continent -> zone -> npc -> rules
        local contMap = {}
        for _, r in ipairs(allRules) do
            local zoneString = (type(r.zone) == "string" and r.zone ~= "") and r.zone or "Unknown"
            local zone, continent = SplitZoneContinent(zoneString)
            continent = continent or "Unknown"

            contMap[continent] = contMap[continent] or {}
            contMap[continent][zone] = contMap[continent][zone] or {}

            local npcID = r.npcID
            contMap[continent][zone][npcID] = contMap[continent][zone][npcID] or { npcName = r.npcName or "", rules = {} }
            local npcBucket = contMap[continent][zone][npcID]
            if (npcBucket.npcName == "" or npcBucket.npcName == nil) and r.npcName and r.npcName ~= "" then
                npcBucket.npcName = r.npcName
            end
            table.insert(npcBucket.rules, r)
        end

        local continents = {}
        for continent in pairs(contMap) do
            table.insert(continents, continent)
        end
        table.sort(continents)

        local visible = {}
        for _, continent in ipairs(continents) do
            local contKey = "cont:" .. continent
            local contExpanded = GetTreeExpanded(contKey, true)
            table.insert(visible, { kind = "continent", key = contKey, label = continent, level = 0, expanded = contExpanded })

            if contExpanded then
                local zones = {}
                for zone in pairs(contMap[continent]) do
                    table.insert(zones, zone)
                end
                table.sort(zones)

                for _, zone in ipairs(zones) do
                    local zoneKey = "zone:" .. continent .. ":" .. zone
                    local zoneExpanded = GetTreeExpanded(zoneKey, true)
                    table.insert(visible, { kind = "zone", key = zoneKey, label = zone, level = 1, expanded = zoneExpanded, continent = continent, zone = zone })

                    if zoneExpanded then
                        local npcNameMap = {}
                        for npcID, npcBucket in pairs(contMap[continent][zone]) do
                            if type(npcBucket) == "table" then
                                local npcName = npcBucket.npcName
                                if type(npcName) ~= "string" or npcName == "" then
                                    npcName = "Unknown"
                                end
                                npcNameMap[npcName] = npcNameMap[npcName] or { npcName = npcName, npcIDs = {}, rules = {} }
                                table.insert(npcNameMap[npcName].npcIDs, npcID)
                                if type(npcBucket.rules) == "table" then
                                    for _, rule in ipairs(npcBucket.rules) do
                                        table.insert(npcNameMap[npcName].rules, rule)
                                    end
                                end
                            end
                        end

                        local npcNames = {}
                        for npcName in pairs(npcNameMap) do
                            table.insert(npcNames, npcName)
                        end
                        table.sort(npcNames)

                        for _, npcName in ipairs(npcNames) do
                            local npcBucket = npcNameMap[npcName]
                            table.sort(npcBucket.npcIDs, function(a, b) return (tonumber(a) or 0) < (tonumber(b) or 0) end)

                            local idParts = {}
                            for _, id in ipairs(npcBucket.npcIDs) do
                                idParts[#idParts + 1] = tostring(id)
                            end

                            local npcLabel = npcBucket.npcName .. "  (" .. table.concat(idParts, "/") .. ")"
                            local npcKey = "npc:" .. continent .. ":" .. zone .. ":" .. npcBucket.npcName .. ":" .. table.concat(idParts, "/")
                            local npcExpanded = GetTreeExpanded(npcKey, false)
                            table.insert(visible, { kind = "npc", key = npcKey, label = npcLabel, level = 2, expanded = npcExpanded, continent = continent, zone = zone, npcIDs = npcBucket.npcIDs, npcName = npcBucket.npcName })

                            if npcExpanded then
                                local byOption = {}
                                local function Ensure(optionID)
                                    local key = tostring(optionID)
                                    local e = byOption[key]
                                    if not e then
                                        e = {
                                            npcID = npcBucket.npcIDs and npcBucket.npcIDs[1] or nil,
                                            npcName = npcBucket.npcName or "",
                                            allNpcIDs = npcBucket.npcIDs or {},
                                            optionID = tonumber(optionID) or optionID,
                                            text = "",
                                            ruleType = "",
                                            hasChar = false,
                                            hasAcc = false,
                                            hasDb = false,
                                            disabledChar = false,
                                            disabledAcc = false,
                                            disabledDb = false,
                                            disabledDbAcc = false,
                                            disabledDbChar = false,
                                            _accNpcIDs = {},
                                            _charNpcIDs = {},
                                            _dbNpcIDs = {},
                                        }
                                        byOption[key] = e
                                    end
                                    return e
                                end

                                for _, rule in ipairs(npcBucket.rules) do
                                    local e = Ensure(rule.optionID)
                                    if (e.text == "" or e.text == nil) and type(rule.text) == "string" and rule.text ~= "" then
                                        e.text = rule.text
                                    end
                                    if (e.ruleType == "" or e.ruleType == nil) and type(rule.ruleType) == "string" and rule.ruleType ~= "" then
                                        e.ruleType = rule.ruleType
                                    end
                                    if rule.scope == "char" then
                                        e.hasChar = true
                                        e._charNpcIDs[rule.npcID] = true
                                        if rule.isDisabled then
                                            e.disabledChar = true
                                        end
                                    elseif rule.scope == "acc" then
                                        e.hasAcc = true
                                        e._accNpcIDs[rule.npcID] = true
                                        if rule.isDisabled then
                                            e.disabledAcc = true
                                        end
                                    elseif rule.scope == "db" then
                                        e.hasDb = true
                                        e._dbNpcIDs[rule.npcID] = true
                                        if rule.isDisabled then
                                            e.disabledDb = true
                                        end
                                    end
                                end

                                local entries = {}
                                for _, e in pairs(byOption) do
                                    local function SetToSortedList(set)
                                        local out = {}
                                        for id in pairs(set or {}) do
                                            table.insert(out, id)
                                        end
                                        table.sort(out, function(a, b) return (tonumber(a) or 0) < (tonumber(b) or 0) end)
                                        return out
                                    end

                                    e.accNpcIDs = SetToSortedList(e._accNpcIDs)
                                    e.charNpcIDs = SetToSortedList(e._charNpcIDs)
                                    e.dbNpcIDs = SetToSortedList(e._dbNpcIDs)
                                    e._accNpcIDs, e._charNpcIDs, e._dbNpcIDs = nil, nil, nil

                                    e.disabledDbAcc = false
                                    e.disabledDbChar = false
                                    if e.hasDb then
                                        for _, id in ipairs(e.dbNpcIDs or {}) do
                                            if IsDisabledDB(id, e.optionID) then
                                                e.disabledDbAcc = true
                                            end
                                            if IsDisabledDBOnChar(id, e.optionID) then
                                                e.disabledDbChar = true
                                            end
                                            if e.disabledDbAcc and e.disabledDbChar then
                                                break
                                            end
                                        end
                                    end
                                    e.disabledDb = (e.disabledDbAcc or e.disabledDbChar) and true or false

                                    -- For Account rules, Character button represents "disabled on this character".
                                    e.disabledAccOnChar = false
                                    if e.hasAcc then
                                        for _, id in ipairs(e.accNpcIDs or {}) do
                                            if IsDisabledAccOnChar(id, e.optionID) then
                                                e.disabledAccOnChar = true
                                                break
                                            end
                                        end
                                    end
                                    table.insert(entries, e)
                                end
                                table.sort(entries, function(a, b)
                                    return (tonumber(a.optionID) or 0) < (tonumber(b.optionID) or 0)
                                end)

                                for _, entry in ipairs(entries) do
                                    local text = entry.text
                                    if type(text) ~= "string" or text == "" then
                                        text = "(no text)"
                                    end
                                    local line = string.format("%s: %s", tostring(entry.optionID), text)
                                    table.insert(visible, {
                                        kind = "rule",
                                        level = 3,
                                        label = line,
                                        entry = entry,
                                    })
                                end
                            end
                        end
                    end
                end
            end
        end

        return visible
    end

    for i = 1, BROW_ROWS do
        local row = CreateFrame("Frame", nil, browserArea)
        row:SetHeight(BROW_ROW_H)
        row:SetPoint("TOPLEFT", browserArea, "TOPLEFT", 8, -6 - (i - 1) * BROW_ROW_H)
        row:SetPoint("TOPRIGHT", browserArea, "TOPRIGHT", -8, -6 - (i - 1) * BROW_ROW_H)

        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(row)
        bg:Hide()
        row.bg = bg

        local expBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        expBtn:SetSize(18, BROW_ROW_H - 2)
        expBtn:SetPoint("LEFT", row, "LEFT", 0, 0)
        expBtn:SetText("+")
        row.btnExpand = expBtn

        local del = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        del:SetSize(34, BROW_ROW_H - 2)
        del:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        del:SetText("Del")
        row.btnDel = del

        local btnCharToggle = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        btnCharToggle:SetSize(22, BROW_ROW_H - 2)
        btnCharToggle:SetPoint("RIGHT", del, "LEFT", -4, 0)
        btnCharToggle:SetText("C")
        row.btnCharToggle = btnCharToggle

        local btnAccToggle = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        btnAccToggle:SetSize(22, BROW_ROW_H - 2)
        btnAccToggle:SetPoint("RIGHT", btnCharToggle, "LEFT", -4, 0)
        btnAccToggle:SetText("A")
        row.btnAccToggle = btnAccToggle

        local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("LEFT", expBtn, "RIGHT", 6, 0)
        fs:SetPoint("RIGHT", btnAccToggle, "LEFT", -6, 0)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(false)
        row.text = fs

        local click = CreateFrame("Button", nil, row)
        click:SetPoint("TOPLEFT", expBtn, "TOPRIGHT", 0, 0)
        click:SetPoint("BOTTOMRIGHT", btnAccToggle, "BOTTOMLEFT", 0, 0)
        click:RegisterForClicks("LeftButtonUp")
        row.btnClick = click

        row:Hide()
        browRows[i] = row
    end

    function f:RefreshBrowserList()
        InitSV()
        local allRules = CollectAllRules()
        local nodes = BuildVisibleTreeNodes(allRules)
        self._browserNodes = nodes

        browserEmpty:SetShown(#nodes == 0)

        if FauxScrollFrame_Update then
            FauxScrollFrame_Update(browserScroll, #nodes, BROW_ROWS, BROW_ROW_H)
        end

        local offset = 0
        if FauxScrollFrame_GetOffset then
            offset = FauxScrollFrame_GetOffset(browserScroll)
        end

        for i = 1, BROW_ROWS do
            local idx = offset + i
            local row = browRows[i]
            local node = nodes[idx]

            if not node then
                row:Hide()
            else
                row:Show()

                local zebra = (idx % 2) == 0
                row.bg:SetShown(zebra)
                row.bg:SetColorTexture(1, 1, 1, zebra and 0.05 or 0)

                local indent = (node.level or 0) * 14
                row.btnExpand:ClearAllPoints()
                row.btnExpand:SetPoint("LEFT", row, "LEFT", indent, 0)

                if node.kind == "continent" or node.kind == "zone" or node.kind == "npc" then
                    row.btnExpand:Show()
                    row.btnExpand:SetText(node.expanded and "-" or "+")
                    row.btnAccToggle:Hide()
                    row.btnCharToggle:Hide()
                    row.btnDel:Hide()

                    row.text:SetText(node.label)
                    if node.kind == "continent" then
                        row.text:SetTextColor(0.8, 0.9, 1, 1)
                    elseif node.kind == "zone" then
                        row.text:SetTextColor(0.75, 0.85, 1, 1)
                    else
                        row.text:SetTextColor(1, 1, 1, 1)
                    end

                    row.btnExpand:SetScript("OnClick", function()
                        SetTreeExpanded(node.key, not node.expanded)
                        f:RefreshBrowserList()
                    end)
                    row.btnClick:SetScript("OnClick", function()
                        SetTreeExpanded(node.key, not node.expanded)
                        f:RefreshBrowserList()
                    end)
                else
                    -- rule
                    row.btnExpand:Hide()
                    row.btnDel:Show()
                    row.text:SetText(node.label)

                    local entry = node.entry
                    local optionID = entry and entry.optionID

                    local function SetScopeText(btn, label, state)
                        if state == "inactive" then
                            btn:SetText("|cffffff00" .. label .. "|r")
                        elseif state == "active" then
                            btn:SetText("|cff00ff00" .. label .. "|r")
                        elseif state == "disabled" then
                            btn:SetText("|cffff9900" .. label .. "|r")
                        else
                            btn:SetText("|cff666666" .. label .. "|r")
                        end
                    end

                    local function ConfigureDbProxyButton(btn, label, dbScope)
                        btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

                        local state
                        if dbScope == "acc" then
                            state = entry.disabledDbAcc and "disabled" or "active"
                        else
                            -- Character DB disable is effectively overridden if Account disables the DB rule.
                            state = (entry.disabledDbAcc or entry.disabledDbChar) and "disabled" or "active"
                        end
                        SetScopeText(btn, label, state)
                        btn:SetEnabled(true)

                        btn:SetScript("OnClick", function(_, mouseButton)
                            if mouseButton == "RightButton" then
                                return
                            end
                            InitSV()
                            local ids = entry.dbNpcIDs or {}
                            if dbScope == "acc" then
                                local newDisabled = not (entry.disabledDbAcc and true or false)
                                for _, id in ipairs(ids) do
                                    SetDisabledDB(id, optionID, newDisabled)
                                end
                            else
                                local newDisabled = not (entry.disabledDbChar and true or false)
                                for _, id in ipairs(ids) do
                                    SetDisabledDBOnChar(id, optionID, newDisabled)
                                end
                            end
                            f:RefreshBrowserList()
                            if f.RefreshRulesList then f:RefreshRulesList(f.currentNpcID) end
                        end)

                        btn:SetScript("OnEnter", function()
                            if not GameTooltip then
                                return
                            end
                            GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
                            if dbScope == "acc" then
                                GameTooltip:SetText("DB (Account)")
                                if entry.disabledDbAcc then
                                    GameTooltip:AddLine("State: Disabled", 1, 0.6, 0, true)
                                    GameTooltip:AddLine("Left-click: Enable DB rule", 1, 1, 1, true)
                                else
                                    GameTooltip:AddLine("State: Active", 0, 1, 0, true)
                                    GameTooltip:AddLine("Left-click: Disable DB rule", 1, 1, 1, true)
                                end
                            else
                                GameTooltip:SetText("DB (Character)")
                                if entry.disabledDbAcc then
                                    GameTooltip:AddLine("Disabled by Account.", 1, 0.6, 0, true)
                                    GameTooltip:AddLine("(Character override applies when Account is enabled)", 1, 1, 1, true)
                                elseif entry.disabledDbChar then
                                    GameTooltip:AddLine("State: Disabled on this character", 1, 0.6, 0, true)
                                    GameTooltip:AddLine("Left-click: Enable on this character", 1, 1, 1, true)
                                else
                                    GameTooltip:AddLine("State: Active on this character", 0, 1, 0, true)
                                    GameTooltip:AddLine("Left-click: Disable on this character", 1, 1, 1, true)
                                end
                            end
                            GameTooltip:Show()
                        end)
                        btn:SetScript("OnLeave", function()
                            if GameTooltip then GameTooltip:Hide() end
                        end)
                    end

                    local function CopyRuleData(data)
                        if type(data) ~= "table" then
                            return { text = "", type = "" }
                        end
                        return {
                            text = data.text or "",
                            type = data.type or "",
                            addedAt = data.addedAt,
                        }
                    end

                    local function ConvertCharToAccForIDs(npcIDs)
                        InitSV()
                        npcIDs = npcIDs or {}
                        for _, id in ipairs(npcIDs) do
                            local charNpc = AutoGossip_Char and AutoGossip_Char[id]
                            local charData = charNpc and (charNpc[optionID] or charNpc[tostring(optionID)])
                            if type(charData) == "table" then
                                AutoGossip_Acc[id] = AutoGossip_Acc[id] or {}
                                local accNpc = AutoGossip_Acc[id]
                                accNpc.__meta = (type(accNpc.__meta) == "table") and accNpc.__meta or {}
                                if type(charNpc.__meta) == "table" then
                                    if (not accNpc.__meta.zone) and (charNpc.__meta.zone or charNpc.__meta.zoneName) then
                                        accNpc.__meta.zone = charNpc.__meta.zone or charNpc.__meta.zoneName
                                    end
                                    if (not accNpc.__meta.npc) and (charNpc.__meta.npc or charNpc.__meta.npcName) then
                                        accNpc.__meta.npc = charNpc.__meta.npc or charNpc.__meta.npcName
                                    end
                                end
                                accNpc[optionID] = CopyRuleData(charData)
                                SetDisabled("acc", id, optionID, false)
                                SetDisabledAccOnChar(id, optionID, false)
                                DeleteRule("char", id, optionID)
                            end
                        end
                    end

                    local function ConvertAccToCharForIDs(npcIDs)
                        InitSV()
                        npcIDs = npcIDs or {}
                        for _, id in ipairs(npcIDs) do
                            local accNpc = AutoGossip_Acc and AutoGossip_Acc[id]
                            local accData = accNpc and (accNpc[optionID] or accNpc[tostring(optionID)])
                            if type(accData) == "table" then
                                AutoGossip_Char[id] = AutoGossip_Char[id] or {}
                                local charNpc = AutoGossip_Char[id]
                                charNpc.__meta = (type(charNpc.__meta) == "table") and charNpc.__meta or {}
                                if type(accNpc.__meta) == "table" then
                                    if (not charNpc.__meta.zone) and (accNpc.__meta.zone or accNpc.__meta.zoneName) then
                                        charNpc.__meta.zone = accNpc.__meta.zone or accNpc.__meta.zoneName
                                    end
                                    if (not charNpc.__meta.npc) and (accNpc.__meta.npc or accNpc.__meta.npcName) then
                                        charNpc.__meta.npc = accNpc.__meta.npc or accNpc.__meta.npcName
                                    end
                                end
                                charNpc[optionID] = CopyRuleData(accData)
                                SetDisabled("char", id, optionID, false)
                            end
                        end
                    end

                    local function ConfigureAccountButton()
                        row.btnAccToggle:RegisterForClicks("LeftButtonUp")

                        if entry.hasAcc then
                            local aState = entry.disabledAcc and "disabled" or "active"
                            SetScopeText(row.btnAccToggle, "A", aState)
                            row.btnAccToggle:SetEnabled(true)
                            row.btnAccToggle:SetScript("OnClick", function()
                                InitSV()
                                local newDisabled = not (entry.disabledAcc and true or false)
                                for _, id in ipairs(entry.accNpcIDs or {}) do
                                    SetDisabled("acc", id, optionID, newDisabled)
                                end
                                f:RefreshBrowserList()
                                if f.RefreshRulesList then f:RefreshRulesList(f.currentNpcID) end
                            end)

                            row.btnAccToggle:SetScript("OnEnter", function()
                                if not GameTooltip then
                                    return
                                end
                                GameTooltip:SetOwner(row.btnAccToggle, "ANCHOR_RIGHT")
                                GameTooltip:SetText("Account")
                                if entry.disabledAcc then
                                    GameTooltip:AddLine("State: Disabled", 1, 0.6, 0, true)
                                    GameTooltip:AddLine("Left-click: Enable (Account)", 1, 1, 1, true)
                                else
                                    GameTooltip:AddLine("State: Active", 0, 1, 0, true)
                                    GameTooltip:AddLine("Left-click: Disable (Account)", 1, 1, 1, true)
                                end
                                GameTooltip:AddLine("When Account is active, C controls 'disabled on this character'.", 1, 1, 1, true)
                                GameTooltip:Show()
                            end)
                            row.btnAccToggle:SetScript("OnLeave", function()
                                if GameTooltip then GameTooltip:Hide() end
                            end)
                        else
                            -- If only Character exists, clicking A converts/moves it to Account.
                            SetScopeText(row.btnAccToggle, "A", "inactive")
                            row.btnAccToggle:SetEnabled(entry.hasChar and true or false)
                            row.btnAccToggle:SetScript("OnClick", function()
                                if not entry.hasChar then
                                    return
                                end
                                ConvertCharToAccForIDs(entry.charNpcIDs)
                                f:RefreshBrowserList()
                                if f.RefreshRulesList then f:RefreshRulesList(f.currentNpcID) end
                            end)

                            row.btnAccToggle:SetScript("OnEnter", function()
                                if not GameTooltip then
                                    return
                                end
                                GameTooltip:SetOwner(row.btnAccToggle, "ANCHOR_RIGHT")
                                GameTooltip:SetText("Account")
                                if entry.hasChar then
                                    GameTooltip:AddLine("State: Inactive", 1, 1, 0, true)
                                    GameTooltip:AddLine("Left-click: Move/convert C -> A", 1, 1, 1, true)
                                    GameTooltip:AddLine("(Creates an Account rule and removes the Character rule)", 1, 1, 1, true)
                                else
                                    GameTooltip:AddLine("State: Inactive", 1, 1, 0, true)
                                    GameTooltip:AddLine("No Account or Character rule here.", 1, 1, 1, true)
                                end
                                GameTooltip:Show()
                            end)
                            row.btnAccToggle:SetScript("OnLeave", function()
                                if GameTooltip then GameTooltip:Hide() end
                            end)
                        end
                    end

                    local function ConfigureCharacterButton()
                        row.btnCharToggle:RegisterForClicks("LeftButtonUp")

                        -- If a real Character rule exists, C controls it (even if an Account rule also exists).
                        if entry.hasChar then
                            local cState = entry.disabledChar and "disabled" or "active"
                            SetScopeText(row.btnCharToggle, "C", cState)
                            row.btnCharToggle:SetEnabled(true)
                            row.btnCharToggle:SetScript("OnClick", function()
                                InitSV()
                                local newDisabled = not (entry.disabledChar and true or false)
                                for _, id in ipairs(entry.charNpcIDs or {}) do
                                    SetDisabled("char", id, optionID, newDisabled)
                                end
                                f:RefreshBrowserList()
                                if f.RefreshRulesList then f:RefreshRulesList(f.currentNpcID) end
                            end)

                            row.btnCharToggle:SetScript("OnEnter", function()
                                if not GameTooltip then
                                    return
                                end
                                GameTooltip:SetOwner(row.btnCharToggle, "ANCHOR_RIGHT")
                                GameTooltip:SetText("Character")
                                if entry.disabledChar then
                                    GameTooltip:AddLine("State: Disabled", 1, 0.6, 0, true)
                                    GameTooltip:AddLine("Left-click: Enable (Character)", 1, 1, 1, true)
                                else
                                    GameTooltip:AddLine("State: Active", 0, 1, 0, true)
                                    GameTooltip:AddLine("Left-click: Disable (Character)", 1, 1, 1, true)
                                end
                                GameTooltip:AddLine("Click A to move/convert to Account.", 1, 1, 1, true)
                                GameTooltip:Show()
                            end)
                            row.btnCharToggle:SetScript("OnLeave", function()
                                if GameTooltip then GameTooltip:Hide() end
                            end)
                        elseif entry.hasAcc then
                            if entry.disabledAcc then
                                -- Account rule exists but is disabled; allow enabling on this character by creating a Character copy.
                                SetScopeText(row.btnCharToggle, "C", "inactive")
                                row.btnCharToggle:SetEnabled(true)
                                row.btnCharToggle:SetScript("OnClick", function()
                                    ConvertAccToCharForIDs(entry.accNpcIDs)
                                    f:RefreshBrowserList()
                                    if f.RefreshRulesList then f:RefreshRulesList(f.currentNpcID) end
                                end)

                                row.btnCharToggle:SetScript("OnEnter", function()
                                    if not GameTooltip then
                                        return
                                    end
                                    GameTooltip:SetOwner(row.btnCharToggle, "ANCHOR_RIGHT")
                                    GameTooltip:SetText("Character")
                                    GameTooltip:AddLine("Account is disabled.", 1, 0.6, 0, true)
                                    GameTooltip:AddLine("Left-click: Enable on this character (creates Character rule)", 1, 1, 1, true)
                                    GameTooltip:AddLine("(Account stays disabled)", 1, 1, 1, true)
                                    GameTooltip:Show()
                                end)
                                row.btnCharToggle:SetScript("OnLeave", function()
                                    if GameTooltip then GameTooltip:Hide() end
                                end)
                            else
                                -- Character = "disabled on this character" for the Account rule.
                                local cDisabled = (entry.disabledAccOnChar and true or false)
                                SetScopeText(row.btnCharToggle, "C", cDisabled and "disabled" or "active")
                                row.btnCharToggle:SetEnabled(true)
                                row.btnCharToggle:SetScript("OnClick", function()
                                    InitSV()
                                    local newDisabled = not (entry.disabledAccOnChar and true or false)
                                    for _, id in ipairs(entry.accNpcIDs or {}) do
                                        SetDisabledAccOnChar(id, optionID, newDisabled)
                                    end
                                    f:RefreshBrowserList()
                                    if f.RefreshRulesList then f:RefreshRulesList(f.currentNpcID) end
                                end)

                                row.btnCharToggle:SetScript("OnEnter", function()
                                    if not GameTooltip then
                                        return
                                    end
                                    GameTooltip:SetOwner(row.btnCharToggle, "ANCHOR_RIGHT")
                                    GameTooltip:SetText("Character")
                                    if entry.disabledAccOnChar then
                                        GameTooltip:AddLine("State: Disabled on this character", 1, 0.6, 0, true)
                                        GameTooltip:AddLine("Left-click: Enable on this character", 1, 1, 1, true)
                                    else
                                        GameTooltip:AddLine("State: Active on this character", 0, 1, 0, true)
                                        GameTooltip:AddLine("Left-click: Disable on this character", 1, 1, 1, true)
                                    end
                                    GameTooltip:Show()
                                end)
                                row.btnCharToggle:SetScript("OnLeave", function()
                                    if GameTooltip then GameTooltip:Hide() end
                                end)
                            end
                        else
                            SetScopeText(row.btnCharToggle, "C", "inactive")
                            row.btnCharToggle:SetEnabled(false)
                            row.btnCharToggle:SetScript("OnClick", nil)

                            row.btnCharToggle:SetScript("OnEnter", function()
                                if not GameTooltip then
                                    return
                                end
                                GameTooltip:SetOwner(row.btnCharToggle, "ANCHOR_RIGHT")
                                GameTooltip:SetText("Character")
                                GameTooltip:AddLine("State: Inactive", 1, 1, 0, true)
                                GameTooltip:AddLine("No Character rule here.", 1, 1, 1, true)
                                GameTooltip:Show()
                            end)
                            row.btnCharToggle:SetScript("OnLeave", function()
                                if GameTooltip then GameTooltip:Hide() end
                            end)
                        end
                    end

                    local isAnyDisabled = (entry.disabledAcc or entry.disabledChar or entry.disabledDb or entry.disabledAccOnChar) and true or false
                    row.text:SetTextColor(isAnyDisabled and 0.67 or 1, isAnyDisabled and 0.67 or 1, isAnyDisabled and 0.67 or 1, 1)

                    local dbOnly = entry.hasDb and (not entry.hasAcc) and (not entry.hasChar)

                    -- Always show both scope buttons in the Rules tab.
                    row.btnAccToggle:Show()
                    row.btnCharToggle:Show()

                    -- Re-anchor buttons (fixed positions).
                    row.btnCharToggle:ClearAllPoints()
                    row.btnAccToggle:ClearAllPoints()
                    row.btnCharToggle:SetPoint("RIGHT", row.btnDel, "LEFT", -4, 0)
                    row.btnAccToggle:SetPoint("RIGHT", row.btnCharToggle, "LEFT", -4, 0)

                    -- Ensure text doesn't overlap buttons.
                    row.text:ClearAllPoints()
                    row.text:SetPoint("LEFT", row.btnExpand, "RIGHT", 6, 0)
                    row.text:SetPoint("RIGHT", row.btnAccToggle, "LEFT", -6, 0)
                    row.text:SetJustifyH("LEFT")
                    row.text:SetWordWrap(false)

                    if dbOnly then
                        -- Treat DB-only rules as active for both A and C; A/C toggles DB enable/disable in place.
                        ConfigureDbProxyButton(row.btnAccToggle, "A", "acc")
                        ConfigureDbProxyButton(row.btnCharToggle, "C", "char")
                    else
                        ConfigureAccountButton()
                        ConfigureCharacterButton()
                    end

                    if entry.hasAcc or entry.hasChar then
                        row.btnDel:Enable()
                        row.btnDel:SetText("Del")
                        row.btnDel:SetScript("OnClick", function()
                            InitSV()
                            if entry.hasAcc then
                                for _, id in ipairs(entry.accNpcIDs or {}) do
                                    DeleteRule("acc", id, optionID, true)
                                end
                            end
                            if entry.hasChar then
                                for _, id in ipairs(entry.charNpcIDs or {}) do
                                    DeleteRule("char", id, optionID, true)
                                end
                            end
                            f:RefreshBrowserList()
                            if f.RefreshRulesList then f:RefreshRulesList(f.currentNpcID) end
                        end)
                    else
                        row.btnDel:Disable()
                        row.btnDel:SetText("DB")
                        row.btnDel:SetScript("OnClick", nil)
                    end

                    -- Rules tab is toggle-only; clicking a rule row does not jump to the edit tab.
                    row.btnClick:SetScript("OnClick", nil)
                end
            end
        end
    end

    browserScroll:SetScript("OnVerticalScroll", function(self, offset)
        if FauxScrollFrame_OnVerticalScroll then
            FauxScrollFrame_OnVerticalScroll(self, offset, BROW_ROW_H, function()
                if f.RefreshBrowserList then
                    f:RefreshBrowserList()
                end
            end)
        end
    end)

    return function()
        if f and f.RefreshBrowserList then
            f:RefreshBrowserList()
        end
    end
end
