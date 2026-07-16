---@diagnostic disable: undefined-global

local addonName, ns = ...
if type(ns) ~= "table" then
    ns = {}
end

-- ===== Instance Reset (moved from fUI_GOSwitchesIR.lua) =====
do
    ns.SwitchesIR = ns.SwitchesIR or {}
    local IR = ns.SwitchesIR

    local function InitSV_IR()
        if ns and type(ns._InitSV) == "function" then
            ns._InitSV()
        end

        if type(AutoGossip_Settings) == "table" then
            if AutoGossip_Settings.instanceResetEnabledAcc == nil then
                AutoGossip_Settings.instanceResetEnabledAcc = true
            end
        end
        if type(AutoGossip_CharSettings) == "table" then
            if AutoGossip_CharSettings.instanceResetEnabledChar == nil then
                AutoGossip_CharSettings.instanceResetEnabledChar = false
            end
        end
    end

    local function GetAccountEnabled()
        InitSV_IR()
        return (AutoGossip_Settings and AutoGossip_Settings.instanceResetEnabledAcc and true) or false
    end

    local function GetCharEnabled()
        InitSV_IR()
        return (AutoGossip_CharSettings and AutoGossip_CharSettings.instanceResetEnabledChar and true) or false
    end

    local function SetAccountEnabled(enabled)
        InitSV_IR()
        if type(AutoGossip_Settings) ~= "table" then
            return
        end
        AutoGossip_Settings.instanceResetEnabledAcc = (enabled and true) or false
    end

    local function SetCharEnabled(enabled)
        InitSV_IR()
        if type(AutoGossip_CharSettings) ~= "table" then
            return
        end
        AutoGossip_CharSettings.instanceResetEnabledChar = (enabled and true) or false
    end

    function IR.GetEffectiveEnabled()
        return GetCharEnabled()
    end

    function IR.GetText()
        return GetCharEnabled() and "|cff55ff55ON|r" or "|cffff5555OFF|r"
    end

    function IR.UpdateLDBText()
        if IR.LDB and type(IR.LDB) == "table" then
            IR.LDB.text = IR.GetText()
        end
    end

    function IR.ToggleAccountEnabled()
        SetAccountEnabled(not GetAccountEnabled())
        IR.UpdateLDBText()
    end

    function IR.ToggleCharEnabled()
        SetCharEnabled(not GetCharEnabled())
        IR.UpdateLDBText()
        if IR.UpdateUI and type(IR.UpdateUI) == "function" then
            IR.UpdateUI()
        end
    end

    function IR.OpenConfigPopup()
        -- Prefer the in-addon options window if present; fall back to Blizzard Interface Options.
        -- If the hosted helper is available, use it to create/select the window/tab.
        if type(_G.FGO_OpenOptionsTab) == "function" then
            pcall(_G.FGO_OpenOptionsTab, 4, true)
            return
        end
        if AutoGameOptions and type(AutoGameOptions.Show) == "function" then
            if AutoGameOptions:IsShown() then
                AutoGameOptions:Hide()
            end
            AutoGameOptions:Show()
            return
        end
        if type(InterfaceOptionsFrame_OpenToCategory) == "function" then
            pcall(InterfaceOptionsFrame_OpenToCategory, "GameOptions")
        end
    end

    function IR.OnSettingsChanged()
        IR.UpdateLDBText()
    end

    local function CreateLDB()
        if IR.LDB then
            return IR.LDB
        end

        if type(LibStub) ~= "table" then
            return nil
        end

        local ok, ldb = pcall(function()
            return LibStub:GetLibrary("LibDataBroker-1.1")
        end)
        if not ok or type(ldb) ~= "table" then
            return nil
        end

        IR.LDB = ldb:NewDataObject("Instance Reset", {
            type = "data source",
            text = IR.GetText(),
            icon = "Interface\\FriendsFrame\\SocialQueuing",
            iconCoords = {0.74609375, 0.79296875, 0.2265625, 0.421875},
            OnClick = function(_, button)
                if button == "LeftButton" then
                    IR.ToggleCharEnabled()
                    if IR.GetEffectiveEnabled() then
                        print("|cff00ccff[FGO] Instance|r  |cff55ff55Resets|r")
                    else
                        print("|cff00ccff[FGO] Instance|r  |cffff5555Disabled|r")
                    end
                elseif button == "RightButton" then
                    IR.OpenConfigPopup()
                end
            end,
            OnTooltipShow = function(tooltip)
                if tooltip.AddLine then
                    tooltip:AddLine("|cff0080FFInstance Reset|r")
                    tooltip:AddLine("Left-click to toggle Instance Reset.")
                    tooltip:AddLine("Right-click to open GameOptions.")
                end
            end,
        })

        return IR.LDB
    end

    local function OnEvent(self, event)
        if not IR.GetEffectiveEnabled() then
            IR.wasInInstance = IR.wasInInstance or false
            return
        end

        if event == "PLAYER_LOGIN" or event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_ENTERING_WORLD" then
            local inInstance = (IsInInstance() and true) or false
            local isGroup = (IsInGroup() and true) or false

            if IR.wasInInstance and not inInstance then
                if type(ResetInstances) == "function" then
                    ResetInstances()
                    print("|cff00ccff[FGO] Instance|r  |cff55ff55Reset Successful!|r")
                end
            end

            IR.wasInInstance = inInstance

            if not inInstance and not isGroup then
                if type(ResetInstances) == "function" then
                    ResetInstances()
                end
            end
        end
    end

    local function InitializeIR()
        if IR.initialized then
            return
        end
        IR.initialized = true

        local frame = CreateFrame("Frame")
        frame:RegisterEvent("PLAYER_LOGIN")
        frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
        frame:RegisterEvent("PLAYER_ENTERING_WORLD")
        frame:SetScript("OnEvent", OnEvent)

        CreateLDB()
        IR.UpdateLDBText()
    end

    InitializeIR()
end

-- ============================================================================
-- Floating Reload UI button (text-only, draggable)
-- ============================================================================

do
    local btn

    local function Tooltip_ApplyFontDelta(tt, delta, stashKey)
        if not (tt and tt.GetName and tt.NumLines) then
            return
        end
        local name = tt:GetName()
        if type(name) ~= "string" or name == "" then
            return
        end

        tt._fgoFontBackup = tt._fgoFontBackup or {}
        local stash = {}

        local n = tt:NumLines() or 0
        for i = 1, n do
            for _, side in ipairs({ "Left", "Right" }) do
                local fs = _G and _G[name .. "Text" .. side .. i]
                if fs and fs.GetFont and fs.SetFont then
                    local fontPath, fontSize, fontFlags = fs:GetFont()
                    if fontPath and type(fontSize) == "number" then
                        stash[#stash + 1] = { fs = fs, path = fontPath, size = fontSize, flags = fontFlags }
                        local newSize = fontSize + (tonumber(delta) or 0)
                        if newSize < 1 then newSize = 1 end
                        fs:SetFont(fontPath, newSize, fontFlags)
                    end
                end
            end
        end

        tt._fgoFontBackup[stashKey] = stash
    end

    local function Tooltip_RestoreFonts(tt, stashKey)
        local backup = tt and tt._fgoFontBackup and tt._fgoFontBackup[stashKey]
        if type(backup) ~= "table" then
            return
        end
        for _, rec in ipairs(backup) do
            if rec and rec.fs and rec.fs.SetFont then
                rec.fs:SetFont(rec.path, rec.size, rec.flags)
            end
        end
        tt._fgoFontBackup[stashKey] = nil
    end

    local function InitSV()
        if ns and type(ns._InitSV) == "function" then
            ns._InitSV()
        end
    end

    local function GetUI()
        InitSV()
        return rawget(_G, "AutoGossip_UI") or rawget(_G, "AutoGame_UI")
    end

    local function IsEnabled()
        local ui = GetUI()
        if not ui then
            return false
        end
        return (ui.reloadFloatEnabled and true or false)
    end

    local function ApplySavedPosition(frame)
        local ui = GetUI()
        if not (ui and type(ui.reloadFloatPos) == "table" and frame and frame.SetPoint) then
            return
        end

        local p = ui.reloadFloatPos
        local point = type(p.point) == "string" and p.point or "TOP"
        local relPoint = type(p.relativePoint) == "string" and p.relativePoint or point
        local x = tonumber(p.x) or 0
        local y = tonumber(p.y) or -120

        frame:ClearAllPoints()
        frame:SetPoint(point, UIParent, relPoint, x, y)
    end

    local function ApplyTextSize()
        if not (btn and btn._label and btn._label.SetFont) then
            return
        end
        local ui = GetUI()
        local want = ui and tonumber(ui.reloadFloatTextSize)
        if type(want) ~= "number" then
            return
        end
        if want < 8 then want = 8 end
        if want > 24 then want = 24 end
        local fontPath, _, fontFlags = btn._label:GetFont()
        if fontPath then
            btn._label:SetFont(fontPath, want, fontFlags)
        end
    end

    local function RunAltCommand()
        if InCombatLockdown and InCombatLockdown() then
            return
        end

        local runner = rawget(_G, "FQT_RunQuestXKeepListAbandonNoConfirm")
        if type(runner) == "function" then
            pcall(runner)
            return
        end

        if type(RunMacroText) == "function" then
            pcall(RunMacroText, "/fqt aaqs")
            return
        end

        if type(ChatFrame_OpenChat) == "function" then
            ChatFrame_OpenChat("/fqt aaqs")
            return
        end
    end

    local function GetCurrentMapID()
        if not (C_Map and type(C_Map.GetBestMapForUnit) == "function") then
            return nil
        end
        local ok, mapID = pcall(C_Map.GetBestMapForUnit, "player")
        if not ok then
            return nil
        end
        mapID = tonumber(mapID)
        if not mapID or mapID <= 0 then
            return nil
        end
        return math.floor(mapID)
    end

    function ns.EnsureReloadFloatButton()
        if btn and btn.SetText then
            return btn
        end

        if not (CreateFrame and UIParent) then
            return nil
        end

        btn = CreateFrame("Button", "FGO_FloatingReloadUIButton", UIParent)
        btn:SetSize(90, 18)
        btn:SetClampedToScreen(true)
        btn:SetFrameStrata("DIALOG")
        btn:EnableMouse(true)
        btn:SetMovable(true)
        btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        btn:RegisterForDrag("RightButton")

        local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetAllPoints(btn)
        fs:SetJustifyH("CENTER")
        fs:SetJustifyV("MIDDLE")
        fs:SetText("|cff00ccffReload UI|r")
        btn._label = fs

        ApplyTextSize()

        ApplySavedPosition(btn)

        local function SaveCurrentPosition(self)
            local ui = GetUI()
            if not ui then
                return
            end
            ui.reloadFloatPos = ui.reloadFloatPos or {}
            local point, _, relPoint, x, y = self:GetPoint(1)
            ui.reloadFloatPos.point = point
            ui.reloadFloatPos.relativePoint = relPoint
            ui.reloadFloatPos.x = x
            ui.reloadFloatPos.y = y
        end

        local function GetAnchorXY(self)
            if not self then
                return 0, 0
            end
            local _, _, _, x, y = self:GetPoint(1)
            x = tonumber(x) or 0
            y = tonumber(y) or 0
            return x, y
        end

        btn:SetScript("OnMouseDown", function(self, button)
            if button ~= "RightButton" or not self then
                return
            end
            self._fgoRightHold = true
            self._fgoDidDrag = nil
            self._fgoDragStartX, self._fgoDragStartY = GetAnchorXY(self)
            if self.StartMoving then
                self:StartMoving()
            end
        end)
        btn:SetScript("OnMouseUp", function(self, button)
            if button ~= "RightButton" or not self or not self._fgoRightHold then
                return
            end
            self._fgoRightHold = nil

            if self.StopMovingOrSizing then
                self:StopMovingOrSizing()
            end

            local sx = tonumber(self._fgoDragStartX) or 0
            local sy = tonumber(self._fgoDragStartY) or 0
            local ex, ey = GetAnchorXY(self)
            self._fgoDragStartX, self._fgoDragStartY = nil, nil

            local moved = (math.abs(ex - sx) > 1) or (math.abs(ey - sy) > 1) or (self._fgoDidDrag == true)
            if moved then
                self._fgoSuppressClick = true
                SaveCurrentPosition(self)
            end
            self._fgoDidDrag = nil
        end)
        btn:SetScript("OnClick", function(self, button)
            if self and self._fgoSuppressClick then
                self._fgoSuppressClick = nil
                return
            end
            if button == "RightButton" then
                if IsControlKeyDown and IsShiftKeyDown and IsControlKeyDown() and IsShiftKeyDown() then
                    RunAltCommand()
                end
                return
            end
            if button == "LeftButton" then
                local r = _G and _G["ReloadUI"]
                if type(r) == "function" then
                    r()
                end
            end
        end)
        btn:SetScript("OnDragStart", function(self)
            DebugReloadFloat("drag start")
            if self then
                self._fgoDidDrag = true
            end
        end)
        btn:SetScript("OnDragStop", function(self)
            DebugReloadFloat("drag stop")
            if self and self.StopMovingOrSizing then
                self:StopMovingOrSizing()
            end
            if self then
                if self._fgoDidDrag then
                    self._fgoSuppressClick = true
                end
                self._fgoDidDrag = nil
                self._fgoRightHold = nil
                SaveCurrentPosition(self)
            end
        end)

        btn:SetScript("OnEnter", function(self)
            if self and self._label and self._label.SetText then
                self._label:SetText("|cffffff00Reload UI|r")
            end
            if GameTooltip then
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText("|cff00ccff[FGO]|r Reload UI")
                GameTooltip:AddLine("Left-click: reload", 1, 1, 1, true)
                GameTooltip:AddLine("Right-drag: move", 1, 1, 1, true)
                local mapID = GetCurrentMapID()
                if mapID then
                    GameTooltip:AddLine("MapID: " .. tostring(mapID), 0.8, 0.8, 0.8, true)
                else
                    GameTooltip:AddLine("MapID: unknown", 0.8, 0.8, 0.8, true)
                end
                Tooltip_ApplyFontDelta(GameTooltip, -1, "FGO_ReloadFloat")
                GameTooltip:Show()
            end
        end)
        btn:SetScript("OnLeave", function(self)
            if self and self._label and self._label.SetText then
                self._label:SetText("|cff00ccffReload UI|r")
            end
            if GameTooltip then
                Tooltip_RestoreFonts(GameTooltip, "FGO_ReloadFloat")
                GameTooltip:Hide()
            end
        end)

        return btn
    end

    function ns.UpdateReloadFloatButton()
        InitSV()
        if IsEnabled() then
            local b = ns.EnsureReloadFloatButton()
            if b and b.Show then
                ApplySavedPosition(b)
                ApplyTextSize()
                b:Show()
            end
        else
            if btn and btn.Hide then
                btn:Hide()
            end
        end
    end

    local function OnEvent(_, event)
        if event == "PLAYER_LOGIN" or event == "VARIABLES_LOADED" then
            ns.UpdateReloadFloatButton()
        end
    end

    local f = _G.CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:RegisterEvent("VARIABLES_LOADED")
    f:SetScript("OnEvent", OnEvent)
end

-- ============================================================================
-- Floating Safari Hat toy button (text-only, draggable)
-- ============================================================================

do
    local btn

    local SAFARI_HAT_TOY_ID = 92738

    local function InitSV()
        if ns and type(ns._InitSV) == "function" then
            ns._InitSV()
        end
    end

    local function GetUI()
        InitSV()
        return rawget(_G, "AutoGossip_UI") or rawget(_G, "AutoGame_UI")
    end

    local function GetAcc()
        InitSV()
        return rawget(_G, "AutoGossip_Acc") or rawget(_G, "AutoGame_Acc")
    end

    local function GetCharSettings()
        InitSV()
        return rawget(_G, "AutoGossip_CharSettings") or rawget(_G, "AutoGame_CharSettings")
    end

    local function TrimSafe(s)
        if type(s) ~= "string" then
            return ""
        end
        return (s:gsub("^%s+", ""):gsub("%s+$", ""))
    end

    local function EnsureRulesTable()
        local a = GetAcc()
        if type(a) ~= "table" then
            return nil
        end
        if type(a.safariHatRulesAcc) ~= "table" then
            a.safariHatRulesAcc = {}
        end
        -- Back-compat: allow numeric-keyed list -> normalize into npcID-keyed map.
        -- (Only if someone manually edited SV.)
        local isArray = (a.safariHatRulesAcc[1] ~= nil)
        if isArray then
            local newMap = {}
            for i = 1, #a.safariHatRulesAcc do
                local e = a.safariHatRulesAcc[i]
                local npc = tonumber(e and e.npcID) or 0
                if npc > 0 then
                    newMap[tostring(npc)] = {
                        npcID = npc,
                        questID = tonumber(e.questID) or 0,
                        textSize = tonumber(e.textSize) or 12,
                        name = tostring(e.name or ""),
                        enabled = (e.enabled ~= false),
                    }
                end
            end
            a.safariHatRulesAcc = newMap
        end

        return a.safariHatRulesAcc
    end

    local function GetSeedRuleMap()
        local out = {}
        if type(ns) ~= "table" or type(ns.SafariHat_DB) ~= "table" then
            return out
        end
        for i = 1, #ns.SafariHat_DB do
            local e = ns.SafariHat_DB[i]
            if type(e) == "table" then
                local npc = tonumber(e.npcID) or 0
                if npc > 0 then
                    out[tostring(npc)] = {
                        npcID = npc,
                        questID = tonumber(e.questID) or 0,
                        textSize = tonumber(e.textSize) or 12,
                        name = tostring(e.name or ""),
                    }
                end
            end
        end
        return out
    end

    local function GetRuleEffective(npcID)
        npcID = tonumber(npcID) or 0
        if npcID <= 0 then
            return nil
        end
        local key = tostring(npcID)
        local t = EnsureRulesTable()
        local sv = (type(t) == "table") and t[key] or nil
        local seed = GetSeedRuleMap()[key]

        local out = {
            npcID = npcID,
            questID = seed and seed.questID or 0,
            textSize = seed and seed.textSize or 12,
            name = seed and seed.name or "",
            enabled = true,
            seeded = (seed ~= nil),
        }

        if type(sv) == "table" then
            if sv.enabled == false then
                out.enabled = false
            end
            if type(sv.questID) == "number" or type(sv.questID) == "string" then
                out.questID = tonumber(sv.questID) or out.questID
            end
            if type(sv.textSize) == "number" or type(sv.textSize) == "string" then
                out.textSize = tonumber(sv.textSize) or out.textSize
            end
            if type(sv.name) == "string" then
                out.name = sv.name
            end
        end

        -- If it's not seeded and not present in SV, it doesn't exist.
        if not out.seeded and type(sv) ~= "table" then
            return nil
        end

        return out
    end

    function ns.SafariHat_Upsert(questID, npcID, textSize, name)
        local npc = tonumber(npcID) or 0
        if npc <= 0 then
            return false, "Bad NPCID"
        end
        local q = tonumber(questID) or 0
        if q < 0 then q = 0 end
        local size = tonumber(textSize)
        if not size then size = 12 end
        if size < 8 then size = 8 end
        if size > 24 then size = 24 end
        local n = TrimSafe(tostring(name or ""))

        local t = EnsureRulesTable()
        if type(t) ~= "table" then
            return false, "Settings not loaded"
        end
        local key = tostring(npc)
        local prev = t[key]
        if type(prev) ~= "table" then
            prev = { enabled = true }
        end
        prev.npcID = npc
        prev.questID = q
        prev.textSize = size
        prev.name = n
        if prev.enabled == nil then prev.enabled = true end
        t[key] = prev
        return true
    end

    function ns.SafariHat_Remove(npcID)
        local npc = tonumber(npcID) or 0
        if npc <= 0 then
            return false
        end
        local key = tostring(npc)
        if GetSeedRuleMap()[key] ~= nil then
            return false, "Seeded"
        end
        local t = EnsureRulesTable()
        if type(t) ~= "table" then
            return false
        end
        t[key] = nil
        return true
    end

    function ns.SafariHat_SetEnabled(npcID, enabled)
        local npc = tonumber(npcID) or 0
        if npc <= 0 then
            return false, "Bad NPCID"
        end
        local key = tostring(npc)
        local t = EnsureRulesTable()
        if type(t) ~= "table" then
            return false, "Settings not loaded"
        end
        local v = t[key]
        if type(v) ~= "table" then
            -- For seeded entries, create an override entry.
            local seed = GetSeedRuleMap()[key]
            if not seed then
                return false, "Missing"
            end
            v = { npcID = npc, questID = seed.questID or 0, textSize = seed.textSize or 12, name = seed.name or "" }
        end
        v.enabled = enabled and true or false
        t[key] = v
        return true
    end

    function ns.SafariHat_List()
        local t = EnsureRulesTable()
        if type(t) ~= "table" then
            t = {}
        end
        local seedMap = GetSeedRuleMap()
        local out = {}

        for key, seed in pairs(seedMap) do
            local eff = GetRuleEffective(tonumber(key) or 0)
            if eff then
                out[#out + 1] = {
                    npcID = eff.npcID,
                    questID = eff.questID,
                    textSize = eff.textSize,
                    name = eff.name,
                    enabled = eff.enabled,
                    seeded = true,
                }
            else
                out[#out + 1] = {
                    npcID = seed.npcID,
                    questID = seed.questID,
                    textSize = seed.textSize,
                    name = seed.name,
                    enabled = true,
                    seeded = true,
                }
            end
        end

        for k, _ in pairs(t) do
            if type(k) == "string" and seedMap[k] == nil then
                local eff = GetRuleEffective(tonumber(k) or 0)
                if eff then
                    out[#out + 1] = {
                        npcID = eff.npcID,
                        questID = eff.questID,
                        textSize = eff.textSize,
                        name = eff.name,
                        enabled = eff.enabled,
                        seeded = false,
                    }
                end
            end
        end

        table.sort(out, function(a, b)
            local an = tostring(a.name or ""):lower()
            local bn = tostring(b.name or ""):lower()
            if an ~= bn then
                if an == "" then return false end
                if bn == "" then return true end
                return an < bn
            end
            return (tonumber(a.npcID) or 0) < (tonumber(b.npcID) or 0)
        end)
        return out
    end

    local function IsEnabledEffective()
        local ui = GetUI()
        if type(ui) ~= "table" then
            return false
        end
        if not (ui.safariHatFloatEnabledAcc and true or false) then
            return false
        end
        local ch = GetCharSettings()
        if type(ch) ~= "table" then
            return true
        end
        return (ch.safariHatFloatEnabledChar ~= false)
    end

    local function GetTargetNpcID()
        if not (UnitExists and UnitGUID) then
            return nil
        end
        if not UnitExists("target") then
            return nil
        end
        local guid = UnitGUID("target")
        if type(guid) ~= "string" then
            return nil
        end
        -- Retail: GUIDs may be "secret" values in tainted paths; any string
        -- operation (including strsplit) can error. Fail closed instead.
        local ok, _, _, _, _, _, npcID = pcall(strsplit, "-", guid)
        if not ok then
            return nil
        end
        return tonumber(npcID)
    end

    local function IsQuestCompleted(questID)
        questID = tonumber(questID)
        if not questID or questID <= 0 then
            return false
        end
        if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
            return (C_QuestLog.IsQuestFlaggedCompleted(questID) and true or false)
        end
        return false
    end

    local function GetActiveSafariEntry()
        local curNpc = GetTargetNpcID()
        if not curNpc or curNpc <= 0 then
            return nil
        end
        local eff = GetRuleEffective(curNpc)
        if not eff then
            return nil
        end
        if eff.enabled == false then
            return nil
        end
        return eff
    end

    local function ShouldShow()
        local entry = GetActiveSafariEntry()
        if not entry then
            return false
        end
        if (tonumber(entry.questID) or 0) > 0 and IsQuestCompleted(entry.questID) then
            return false
        end
        return true
    end

    local function ApplySavedPosition(frame)
        local ui = GetUI()
        if not (type(ui) == "table" and type(ui.safariHatFloatPos) == "table" and frame and frame.SetPoint) then
            return
        end

        local p = ui.safariHatFloatPos
        local point = type(p.point) == "string" and p.point or "TOP"
        local relPoint = type(p.relativePoint) == "string" and p.relativePoint or point
        local x = tonumber(p.x) or 0
        local y = tonumber(p.y) or -160

        frame:ClearAllPoints()
        frame:SetPoint(point, UIParent, relPoint, x, y)
    end

    local function ApplyTextSize(size)
        if not (btn and btn._label and btn._label.SetFont) then
            return
        end
        local want = tonumber(size)
        if type(want) ~= "number" then
            return
        end
        if want < 8 then want = 8 end
        if want > 24 then want = 24 end
        local fontPath, _, fontFlags = btn._label:GetFont()
        if fontPath then
            btn._label:SetFont(fontPath, want, fontFlags)
        end
    end

    function ns.EnsureSafariHatFloatButton()
        if btn and btn.SetText then
            return btn
        end

        if not (CreateFrame and UIParent) then
            return nil
        end

        btn = CreateFrame("Button", "FGO_FloatingSafariHatButton", UIParent, "SecureActionButtonTemplate")
        btn:SetSize(70, 18)
        btn:SetClampedToScreen(true)
        btn:SetFrameStrata("DIALOG")
        btn:EnableMouse(true)
        btn:SetMovable(true)
        btn:RegisterForDrag("RightButton")

        local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetAllPoints(btn)
        fs:SetJustifyH("CENTER")
        fs:SetJustifyV("MIDDLE")
        fs:SetText("|cff00ccffSafari|r")
        btn._label = fs

        ApplyTextSize(12)
        ApplySavedPosition(btn)

        -- Secure action: use toy via attributes.
        if btn.SetAttribute then
            btn:SetAttribute("type", "toy")
            btn:SetAttribute("toy", SAFARI_HAT_TOY_ID)
        end

        btn:RegisterForClicks("LeftButtonUp")
        btn:SetScript("PreClick", function(self, mouseButton)
            if mouseButton ~= "LeftButton" then
                return
            end
            local shiftFn = rawget(_G, "IsShiftKeyDown")
            local shift = (type(shiftFn) == "function" and shiftFn()) and true or false
            if not shift then
                return
            end

            local inCombatFn = rawget(_G, "InCombatLockdown")
            local inCombat = (type(inCombatFn) == "function" and inCombatFn()) and true or false

            local inPetBattle
            if rawget(_G, "C_PetBattles") and type(C_PetBattles.IsInBattle) == "function" then
                local ok, v = pcall(C_PetBattles.IsInBattle)
                if ok then
                    inPetBattle = v and true or false
                end
            end

            local usable, unusableReason
            if C_ToyBox and type(C_ToyBox.IsToyUsable) == "function" then
                local ok, u, r = pcall(C_ToyBox.IsToyUsable, SAFARI_HAT_TOY_ID)
                if ok then
                    usable = u and true or false
                    unusableReason = r
                end
            end

            local msg = "|cff00ccff[FGO]|r Safari click: toy=" .. tostring(SAFARI_HAT_TOY_ID) .. " combat=" .. tostring(inCombat)
            if inPetBattle ~= nil then
                msg = msg .. " petBattle=" .. tostring(inPetBattle)
            end
            if usable ~= nil then
                msg = msg .. " usable=" .. tostring(usable)
            end
            if unusableReason ~= nil then
                msg = msg .. " reason=" .. tostring(unusableReason)
            end

            local errs = rawget(_G, "UIErrorsFrame")
            if errs and type(errs.AddMessage) == "function" then
                errs:AddMessage(msg, 1, 0.82, 0, 1)
            end

            local chat = rawget(_G, "DEFAULT_CHAT_FRAME")
            if chat and type(chat.AddMessage) == "function" then
                chat:AddMessage(msg)
            else
                local p = rawget(_G, "print")
                if type(p) == "function" then p(msg) end
            end

            if self and self._label and self._label.SetText and rawget(_G, "C_Timer") and type(C_Timer.After) == "function" then
                self._label:SetText("|cff00ff00CLICK|r")
                C_Timer.After(0.35, function()
                    if btn and btn._label and btn._label.SetText then
                        btn._label:SetText("|cff00ccffSafari|r")
                    end
                end)
            end
        end)

        btn:SetScript("OnDragStart", function(self)
            if self and self.StartMoving then
                self:StartMoving()
            end
        end)

        btn:SetScript("OnDragStop", function(self)
            if self and self.StopMovingOrSizing then
                self:StopMovingOrSizing()
            end

            local ui = GetUI()
            if type(ui) ~= "table" then
                return
            end

            ui.safariHatFloatPos = ui.safariHatFloatPos or {}
            local point, _, relPoint, x, y = self:GetPoint(1)
            ui.safariHatFloatPos.point = point
            ui.safariHatFloatPos.relativePoint = relPoint
            ui.safariHatFloatPos.x = x
            ui.safariHatFloatPos.y = y
        end)

        btn:SetScript("OnEnter", function(self)
            if self and self._label and self._label.SetText then
                self._label:SetText("|cffffff00Safari|r")
            end
            if GameTooltip then
                local entry = GetActiveSafariEntry() or {}
                local wantNpc = tonumber(entry.npcID) or 0
                local wantName = tostring(entry.name or "")
                local questID = tonumber(entry.questID) or 0
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText("|cff00ccff[FGO]|r Safari Hat")
                GameTooltip:AddLine("Left-click: use Safari Hat toy", 1, 1, 1, true)
                GameTooltip:AddLine("Right-drag: move", 1, 1, 1, true)
                if wantNpc > 0 then
                    local s = "NPCID gate: " .. tostring(wantNpc)
                    if wantName ~= "" then
                        s = s .. " (" .. wantName .. ")"
                    end
                    GameTooltip:AddLine(s, 1, 1, 1, true)
                end
                if questID > 0 then
                    GameTooltip:AddLine("Quest gate: hide if completed (" .. tostring(questID) .. ")", 1, 1, 1, true)
                end
                GameTooltip:Show()
            end
        end)

        btn:SetScript("OnLeave", function(self)
            if self and self._label and self._label.SetText then
                self._label:SetText("|cff00ccffSafari|r")
            end
            if GameTooltip then
                GameTooltip:Hide()
            end
        end)

        return btn
    end

    function ns.UpdateSafariHatFloatButton()
        InitSV()
        local entry = GetActiveSafariEntry()
        if IsEnabledEffective() and entry and ShouldShow() then
            local b = ns.EnsureSafariHatFloatButton()
            if b and b.Show then
                ApplySavedPosition(b)
                ApplyTextSize(entry.textSize)
                b:Show()
            end
        else
            if btn and btn.Hide then
                btn:Hide()
            end
        end
    end

    local function OnEvent(_, event)
        if event == "PLAYER_LOGIN" or event == "VARIABLES_LOADED" or event == "PLAYER_TARGET_CHANGED" or event == "QUEST_LOG_UPDATE" or event == "QUEST_TURNED_IN" then
            ns.UpdateSafariHatFloatButton()
        end
    end

    local f = _G.CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:RegisterEvent("VARIABLES_LOADED")
    f:RegisterEvent("PLAYER_TARGET_CHANGED")
    f:RegisterEvent("QUEST_LOG_UPDATE")
    f:RegisterEvent("QUEST_TURNED_IN")
    f:SetScript("OnEvent", OnEvent)
end

-- ============================================================================
-- Action: ActionButtonUseKeyDown (3-state)
-- ============================================================================

do
    local function InitSV()
        if ns and type(ns._InitSV) == "function" then
            ns._InitSV()
        end
    end

    local function GetAcc()
        InitSV()
        return rawget(_G, "AutoGame_Settings") or rawget(_G, "AutoGossip_Settings")
    end

    local function GetChar()
        InitSV()
        return rawget(_G, "AutoGame_CharSettings") or rawget(_G, "AutoGossip_CharSettings")
    end

    local function Normalize()
        local acc = GetAcc()
        local ch = GetChar()
        if type(acc) ~= "table" or type(ch) ~= "table" then
            return
        end
        if type(acc.actionKeyDownAcc) ~= "boolean" then
            acc.actionKeyDownAcc = false
        end
        if type(ch.actionKeyDownMode) ~= "string" then
            ch.actionKeyDownMode = "acc"
        end
    end

    function ns.GetActionUseKeyDownState()
        Normalize()
        local acc = GetAcc()
        local ch = GetChar()
        if type(acc) ~= "table" or type(ch) ~= "table" then
            return "off"
        end
        if acc.actionKeyDownAcc then
            return "acc"
        end
        if ch.actionKeyDownMode == "on" then
            return "char"
        end
        return "off"
    end

    local function SetCVarSafe(name, value)
        if _G.C_CVar and _G.C_CVar.SetCVar then
            _G.C_CVar.SetCVar(name, value)
            return true
        end
        if _G.SetCVar then
            _G.SetCVar(name, value)
            return true
        end
        return false
    end

    function ns.ApplyActionUseKeyDownSetting()
        local state = ns.GetActionUseKeyDownState()
        local want = (state == "acc" or state == "char") and 1 or 0
        SetCVarSafe("ActionButtonUseKeyDown", want)
    end

    function ns.SetActionUseKeyDownState(state)
        Normalize()
        local acc = GetAcc()
        local ch = GetChar()
        if type(acc) ~= "table" or type(ch) ~= "table" then
            return
        end

        if state == "acc" then
            acc.actionKeyDownAcc = true
            ch.actionKeyDownMode = "acc"
        elseif state == "char" then
            acc.actionKeyDownAcc = false
            ch.actionKeyDownMode = "on"
        else
            acc.actionKeyDownAcc = false
            ch.actionKeyDownMode = "acc"
        end

        ns.ApplyActionUseKeyDownSetting()
    end

    local function OnEvent(_, event, arg1)
        if event == "ADDON_LOADED" and arg1 == addonName then
            Normalize()
            return
        end
        if event == "PLAYER_LOGIN" or event == "VARIABLES_LOADED" then
            ns.ApplyActionUseKeyDownSetting()
        end
    end

    local f = _G.CreateFrame("Frame")
    f:RegisterEvent("ADDON_LOADED")
    f:RegisterEvent("PLAYER_LOGIN")
    f:RegisterEvent("VARIABLES_LOADED")
    f:SetScript("OnEvent", OnEvent)
end

-- ============================================================================
-- NPC Name: nameplateShowFriendlyNPCs (3-state)
-- ============================================================================

do
    local function InitSV()
        if ns and type(ns._InitSV) == "function" then
            ns._InitSV()
        end
    end

    local function GetAcc()
        InitSV()
        return rawget(_G, "AutoGame_Settings") or rawget(_G, "AutoGossip_Settings")
    end

    local function GetChar()
        InitSV()
        return rawget(_G, "AutoGame_CharSettings") or rawget(_G, "AutoGossip_CharSettings")
    end

    local function Normalize()
        local acc = GetAcc()
        local ch = GetChar()
        if type(acc) ~= "table" or type(ch) ~= "table" then
            return
        end
        if type(acc.npcNameplatesAcc) ~= "boolean" then
            acc.npcNameplatesAcc = false
        end
        if type(ch.npcNameplatesMode) ~= "string" then
            ch.npcNameplatesMode = "acc"
        end
    end

    function ns.GetFriendlyNPCNameplatesSafe()
        if _G.C_CVar and _G.C_CVar.GetCVarBool then
            local ok, v = pcall(_G.C_CVar.GetCVarBool, "nameplateShowFriendlyNPCs")
            if ok then return v and true or false end
        end
        if _G.GetCVarBool then
            local ok, v = pcall(_G.GetCVarBool, "nameplateShowFriendlyNPCs")
            if ok then return v and true or false end
        end
        if _G.GetCVar then
            local ok, v = pcall(_G.GetCVar, "nameplateShowFriendlyNPCs")
            if ok and v ~= nil then
                v = tostring(v)
                return (v == "1" or v:lower() == "true")
            end
        end
        return nil
    end

    function ns.GetNPCNameplatesState()
        Normalize()
        local acc = GetAcc()
        local ch = GetChar()
        if type(acc) ~= "table" or type(ch) ~= "table" then
            return "off"
        end
        if acc.npcNameplatesAcc then
            return "acc"
        end
        if ch.npcNameplatesMode == "on" then
            return "char"
        end
        return "off"
    end

    local function SetCVarSafe(name, value)
        if _G.C_CVar and _G.C_CVar.SetCVar then
            _G.C_CVar.SetCVar(name, value)
            return true
        end
        if _G.SetCVar then
            _G.SetCVar(name, value)
            return true
        end
        return false
    end

    function ns.ApplyNPCNameplatesSetting()
        local state = ns.GetNPCNameplatesState()
        local want = (state == "acc" or state == "char") and 1 or 0
        SetCVarSafe("nameplateShowFriendlyNPCs", want)
    end

    function ns.SetNPCNameplatesState(state)
        Normalize()
        local acc = GetAcc()
        local ch = GetChar()
        if type(acc) ~= "table" or type(ch) ~= "table" then
            return
        end

        if state == "acc" then
            acc.npcNameplatesAcc = true
            ch.npcNameplatesMode = "acc"
        elseif state == "char" then
            acc.npcNameplatesAcc = false
            ch.npcNameplatesMode = "on"
        else
            acc.npcNameplatesAcc = false
            ch.npcNameplatesMode = "acc"
        end

        ns.ApplyNPCNameplatesSetting()
    end

    local function OnEvent(_, event, arg1)
        if event == "ADDON_LOADED" and arg1 == addonName then
            Normalize()
            return
        end
        if event == "PLAYER_LOGIN" or event == "VARIABLES_LOADED" then
            ns.ApplyNPCNameplatesSetting()
        end
    end

    local f = _G.CreateFrame("Frame")
    f:RegisterEvent("ADDON_LOADED")
    f:RegisterEvent("PLAYER_LOGIN")
    f:RegisterEvent("VARIABLES_LOADED")
    f:SetScript("OnEvent", OnEvent)
end

-- Switches module
-- Consolidates:
-- - fr0z3nUI_GameOptionsTutorial.lua
-- - fr0z3nUI_GameOptionsSwitchTooltip.lua
-- - fr0z3nUI_GameOptionsSwitchTooltipX.lua

-- ============================================================================
-- Tooltip Border (formerly SwitchTooltip)
-- ============================================================================

do
    local didInit = false
    local MIDNIGHT_FISHING_ITEM_ID = 262649
    local MIDNIGHT_FISHING_SKILL_LINE_ID = 2911

    local function InitSV()
        if ns and type(ns._InitSV) == "function" then
            ns._InitSV()
        end
    end

    local function GetSettings()
        InitSV()
        local acc = rawget(_G, "AutoGame_Settings") or rawget(_G, "AutoGossip_Settings")
        if type(acc) ~= "table" then
            return nil
        end
        return acc
    end

    local function IsHideEnabled()
        local acc = GetSettings()
        if not acc then
            return true
        end
        if type(acc.hideTooltipBorderAcc) ~= "boolean" then
            return true
        end
        return acc.hideTooltipBorderAcc
    end

    local function ApplyBorderState(tooltip)
        local nineSlice = tooltip and tooltip.NineSlice
        if not nineSlice then
            return
        end

        local hide = IsHideEnabled()

        -- When disabled, do not force any "show" state; leave Blizzard/default styling alone.
        if not hide then
            return
        end

        for _, regionName in ipairs({
            "TopEdge", "BottomEdge", "LeftEdge", "RightEdge",
            "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
        }) do
            local region = nineSlice[regionName]
            if region and region.SetAlpha then
                if region.__FGO_OrigAlpha == nil and region.GetAlpha then
                    region.__FGO_OrigAlpha = region:GetAlpha()
                end
                region:SetAlpha(0)
            end
        end
    end

    local function ExtractItemIDFromLink(link)
        if type(link) ~= "string" then
            return nil
        end
        local id = link:match("item:(%d+)")
        return tonumber(id)
    end

    local function ResolveTooltipItemID(tooltip, data)
        if type(data) == "table" then
            local dataID = tonumber(data.id)
            if dataID and dataID > 0 then
                return dataID
            end

            local dataLink = data.hyperlink or data.itemLink or data.link
            local linkedID = ExtractItemIDFromLink(dataLink)
            if linkedID then
                return linkedID
            end
        end

        if tooltip and tooltip.GetItem then
            local _, itemLink = tooltip:GetItem()
            local itemID = ExtractItemIDFromLink(itemLink)
            if itemID then
                return itemID
            end
        end

        return nil
    end

    local function ResolveMidnightFishingFromProfessionsList()
        if not (type(GetProfessions) == "function" and type(GetProfessionInfo) == "function") then
            return nil, nil
        end

        local p1, p2, p3, p4, p5 = GetProfessions()
        local indices = { p1, p2, p3, p4, p5 }
        for i = 1, 5 do
            local p = indices[i]
            if p ~= nil then
                local ok,
                    a1, a2, a3, a4, a5,
                    a6, a7, a8, a9, a10,
                    a11, a12, a13, a14, a15 = pcall(GetProfessionInfo, p)

                if ok then
                    local info = { a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15 }
                    local rank = tonumber(info[3])
                    local maxRank = tonumber(info[4])
                    local skillLine = tonumber(info[7])

                    if skillLine == MIDNIGHT_FISHING_SKILL_LINE_ID then
                        return rank or 0, maxRank or 300
                    end

                    for j = 1, 15 do
                        local v = info[j]
                        if type(v) == "string" and not (issecretvalue and issecretvalue(v)) then
                            local s = v:lower()
                            if s:find("midnight", 1, true) and s:find("fishing", 1, true) then
                                return rank or 0, maxRank or 300
                            end
                        end
                    end
                end
            end
        end

        return nil, nil
    end

    local function AddMidnightFishingSkillLine(tooltip)
        if not (tooltip and tooltip.AddLine and tooltip.AddDoubleLine) then
            return
        end

        local data = tooltip.GetTooltipData and tooltip:GetTooltipData() or nil
        local itemID = ResolveTooltipItemID(tooltip, data)
        if itemID ~= MIDNIGHT_FISHING_ITEM_ID then
            return
        end

        local currentSkill, maxSkill = ResolveMidnightFishingFromProfessionsList()
        currentSkill = tonumber(currentSkill) or 0
        maxSkill = tonumber(maxSkill) or 300

        local professions = C_Professions
        local getProfessionInfoBySkillLineID = professions and professions.GetProfessionInfoBySkillLineID
        if type(getProfessionInfoBySkillLineID) == "function" then
            local skillInfo = getProfessionInfoBySkillLineID(MIDNIGHT_FISHING_SKILL_LINE_ID)
            if type(skillInfo) == "table" then
                currentSkill = tonumber(skillInfo.skillLevel)
                    or tonumber(skillInfo.currentSkillLevel)
                    or tonumber(skillInfo.currentLevel)
                    or currentSkill
                maxSkill = tonumber(skillInfo.maxSkillLevel)
                    or tonumber(skillInfo.maxLevel)
                    or tonumber(skillInfo.maxSkill)
                    or maxSkill
            end
        end

        tooltip:AddLine(" ")
        tooltip:AddDoubleLine("Current Midnight Fishing:", currentSkill .. "/" .. maxSkill, 1, 0.82, 0, 1, 1, 1)
    end

    local function HookTooltipByName(globalName)
        local tt = _G and _G[globalName]
        if not (tt and tt.HookScript) then
            return
        end

        if tt.__FGO_TooltipBorderHooked then
            ApplyBorderState(tt)
            return
        end

        tt.__FGO_TooltipBorderHooked = true
        ApplyBorderState(tt)
        tt:HookScript("OnShow", ApplyBorderState)
    end

    local function HookAllKnownTooltips()
        for _, name in ipairs({
            "GameTooltip",
            "ItemRefTooltip",
            "ShoppingTooltip1",
            "ShoppingTooltip2",
            "ShoppingTooltip3",
            "WorldMapTooltip",
            "BattlePetTooltip",
            "FloatingBattlePetTooltip",
            "FloatingPetBattleAbilityTooltip",
            "EmbeddedItemTooltip",
        }) do
            HookTooltipByName(name)
        end
    end

    local function HookTooltipDataProcessor()
        if not (TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall) then
            return
        end
        if TooltipDataProcessor.__FGO_TooltipBorderHooked then
            return
        end
        TooltipDataProcessor.__FGO_TooltipBorderHooked = true

        if type(Enum) == "table" and type(Enum.TooltipDataType) == "table" then
            for _, tooltipDataType in pairs(Enum.TooltipDataType) do
                if type(tooltipDataType) == "number" then
                    TooltipDataProcessor.AddTooltipPostCall(tooltipDataType, ApplyBorderState)
                end
            end

            if type(Enum.TooltipDataType.Item) == "number" then
                TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, AddMidnightFishingSkillLine)
            end
        end
    end

    local function HookBackdropStyleFunctions()
        if not (_G and _G.hooksecurefunc) then
            return
        end
        if _G.__FGO_TooltipBorderBackdropHooked then
            return
        end
        _G.__FGO_TooltipBorderBackdropHooked = true

        local sharedSetBackdropStyle = _G and rawget(_G, "SharedTooltip_SetBackdropStyle")
        if type(sharedSetBackdropStyle) == "function" then
            _G.hooksecurefunc("SharedTooltip_SetBackdropStyle", function(tooltip)
                ApplyBorderState(tooltip)
            end)
        end

        local gameTooltipSetBackdropStyle = _G and rawget(_G, "GameTooltip_SetBackdropStyle")
        if type(gameTooltipSetBackdropStyle) == "function" then
            _G.hooksecurefunc("GameTooltip_SetBackdropStyle", function(tooltip)
                ApplyBorderState(tooltip)
            end)
        end
    end

    local function InitOnce()
        if didInit then
            return
        end
        didInit = true

        HookTooltipDataProcessor()
        HookBackdropStyleFunctions()
        HookAllKnownTooltips()
    end

    function ns.ApplyTooltipBorderSetting(force)
        InitOnce()

        -- Re-apply to existing tooltips immediately.
        if force then
            HookAllKnownTooltips()
        end
    end

    local function OnEvent(_, event, arg1)
        if event == "ADDON_LOADED" and arg1 == addonName then
            -- Initialize default if needed.
            if type(_G.AutoGossip_Settings) == "table" and type(_G.AutoGossip_Settings.hideTooltipBorderAcc) ~= "boolean" then
                _G.AutoGossip_Settings.hideTooltipBorderAcc = true
            end
            return
        end

        if event == "PLAYER_LOGIN" or event == "VARIABLES_LOADED" then
            InitOnce()
            ns.ApplyTooltipBorderSetting(true)
        end
    end

    local f = _G.CreateFrame("Frame")
    f:RegisterEvent("ADDON_LOADED")
    f:RegisterEvent("PLAYER_LOGIN")
    f:RegisterEvent("VARIABLES_LOADED")
    f:SetScript("OnEvent", OnEvent)
end

-- ============================================================================
-- TooltipX (formerly SwitchTooltipX)
-- ============================================================================

do
    local didInit = false
    local lastDebugAt = 0
    local lastDebugKey = nil

    local function GetSettings()
        if ns and type(ns._InitSV) == "function" then
            ns._InitSV()
        end
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

    local function GetStringSetting(key, defaultValue)
        local s = GetSettings()
        if not s then
            return defaultValue
        end
        local v = s[key]
        if type(v) ~= "string" or v == "" then
            return defaultValue
        end
        return v
    end

    local function NormalizeModifier(mod)
        mod = (mod or ""):upper()
        if mod == "CTRL" or mod == "CONTROL" then return "CTRL" end
        if mod == "ALT" then return "ALT" end
        if mod == "SHIFT" then return "SHIFT" end
        if mod == "NONE" or mod == "OFF" then return "NONE" end
        return "CTRL"
    end

    local function IsModifierDown()
        local mod = NormalizeModifier(GetStringSetting("tooltipXCombatModifierAcc", "CTRL"))
        if mod == "NONE" then
            return false
        end
        if mod == "ALT" then
            return IsAltKeyDown and IsAltKeyDown() or false
        elseif mod == "SHIFT" then
            return IsShiftKeyDown and IsShiftKeyDown() or false
        else
            return IsControlKeyDown and IsControlKeyDown() or false
        end
    end

    local function InCombat()
        if InCombatLockdown and InCombatLockdown() then
            return true
        end
        if UnitAffectingCombat then
            return UnitAffectingCombat("player") and true or false
        end
        return false
    end

    local function DebugLog(key, msg)
        if not GetBoolSetting("tooltipXDebugAcc", false) then
            return
        end
        local now = (GetTime and GetTime()) or 0
        if key and lastDebugKey == key and (now - (lastDebugAt or 0)) < 0.35 then
            return
        end
        if (now - (lastDebugAt or 0)) < 0.12 then
            return
        end
        lastDebugAt = now
        lastDebugKey = key
        print("|cff00ccff[FGO]|r TooltipX: " .. tostring(msg))
    end

    local function TooltipGetUnitToken(tooltip)
        if not (tooltip and tooltip.GetUnit) then
            return nil
        end
        local ok, _, unit = pcall(tooltip.GetUnit, tooltip)
        if not ok then
            return nil
        end
        -- NOTE: `tooltip:GetUnit()` can return a "secret string" unit token.
        -- Comparing secret strings (even to "") can throw/taint; treat it as opaque.
        if type(unit) ~= "string" then
            return nil
        end
        -- Retail 11.x+: secret string unit tokens cannot be passed to Unit* APIs from tainted execution.
        -- If it is secret, we must not call UnitIsUnit/UnitIsPlayer/UnitLevel/etc with it.
        if issecretvalue and issecretvalue(unit) then
            return nil
        end
        return unit
    end

    local function ShouldHideTooltipNow(tooltip)
        if not GetBoolSetting("tooltipXCombatHideAcc", false) then
            return false
        end

        if not InCombat() then
            return false
        end

        if IsModifierDown() then
            return false
        end

        local unit = TooltipGetUnitToken(tooltip)
        if unit then
            if GetBoolSetting("tooltipXCombatShowTargetAcc", true) and UnitIsUnit and UnitIsUnit(unit, "target") then
                return false
            end
            if GetBoolSetting("tooltipXCombatShowFocusAcc", false) and UnitIsUnit and UnitIsUnit(unit, "focus") then
                return false
            end
            if GetBoolSetting("tooltipXCombatShowMouseoverAcc", true) and UnitIsUnit and UnitIsUnit(unit, "mouseover") then
                return false
            end
            if GetBoolSetting("tooltipXCombatShowFriendlyPlayersAcc", false) and UnitIsPlayer and UnitIsFriend then
                if UnitIsPlayer(unit) and UnitIsFriend("player", unit) then
                    return false
                end
            end
        end

        return true
    end

    local function RestoreTooltipAlpha(tooltip)
        if not (tooltip and tooltip.SetAlpha) then return end

        if tooltip.__FGO_TooltipX_OrigAlpha ~= nil then
            tooltip:SetAlpha(tooltip.__FGO_TooltipX_OrigAlpha)
        end
        tooltip.__FGO_TooltipX_ForcedHidden = nil
    end

    local function ForceHideTooltip(tooltip)
        if not (tooltip and tooltip.SetAlpha and tooltip.GetAlpha) then return end

        if tooltip.__FGO_TooltipX_OrigAlpha == nil then
            local ok, a = pcall(tooltip.GetAlpha, tooltip)
            if ok then
                tooltip.__FGO_TooltipX_OrigAlpha = a
            else
                tooltip.__FGO_TooltipX_OrigAlpha = 1
            end
        end

        tooltip.__FGO_TooltipX_ForcedHidden = true
        tooltip:SetAlpha(0)
    end

    local function StripColorCodes(text)
        if type(text) ~= "string" then return nil end
        text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
        text = text:gsub("|r", "")
        return text
    end

    local function RestoreHiddenTooltipLines(tooltip)
        if not (tooltip and tooltip.NumLines and tooltip.GetName) then
            return
        end

        local tooltipName = tooltip:GetName()
        if not tooltipName then
            return
        end

        local num = tooltip:NumLines() or 0
        for i = 1, num do
            local left = _G[tooltipName .. "TextLeft" .. i]
            if left and left.__FGO_TooltipX_Hidden and left.Show then
                left.__FGO_TooltipX_Hidden = nil
                left:Show()
            end

            local right = _G[tooltipName .. "TextRight" .. i]
            if right and right.__FGO_TooltipX_Hidden and right.Show then
                right.__FGO_TooltipX_Hidden = nil
                right:Show()
            end
        end
    end

    local function HideQuestProgressLines(tooltip)
        if not GetBoolSetting("tooltipXCleanupAcc", false) then
            return
        end
        if GetBoolSetting("tooltipXCleanupCombatOnlyAcc", true) and not InCombat() then
            return
        end

        local mode = (GetStringSetting("tooltipXCleanupModeAcc", "strict") or "strict"):lower()
        if mode ~= "strict" and mode ~= "more" then
            mode = "strict"
        end

        if not (tooltip and tooltip.NumLines and tooltip.GetName) then
            return
        end

        local tooltipName = tooltip:GetName()
        if not tooltipName then
            return
        end

        local num = tooltip:NumLines() or 0
        local hiddenCount = 0
        for i = 1, num do
            local left = _G[tooltipName .. "TextLeft" .. i]
            if left and left.IsShown and left:IsShown() and left.GetText and left.Hide then
                local raw = left:GetText()
                local text = StripColorCodes(raw)
                if text then
                    -- Common quest objective pattern: "0/1 Kill X".
                    local isProgress = text:match("^%s*%d+%s*/%s*%d+%s+%S+")
                    if not isProgress and mode == "more" then
                        -- More permissive: also hide lines like "(0/1) ..." or "0/1" anywhere near the start.
                        isProgress = text:match("^%s*%(%s*%d+%s*/%s*%d+%s*%)%s*%S+")
                            or text:match("^%s*%d+%s*/%s*%d+%s*$")
                            or text:match("^%s*%d+%s*/%s*%d+%s+")
                    end

                    if isProgress then
                        left.__FGO_TooltipX_Hidden = true
                        left:Hide()
                        hiddenCount = hiddenCount + 1
                    end
                end
            end

            local right = _G[tooltipName .. "TextRight" .. i]
            if right and right.IsShown and right:IsShown() and right.GetText and right.Hide then
                local raw = right:GetText()
                local text = StripColorCodes(raw)
                if text then
                    local isProgress = text:match("^%s*%d+%s*/%s*%d+%s+%S+")
                    if not isProgress and mode == "more" then
                        isProgress = text:match("^%s*%(%s*%d+%s*/%s*%d+%s*%)%s*%S+")
                            or text:match("^%s*%d+%s*/%s*%d+%s*$")
                            or text:match("^%s*%d+%s*/%s*%d+%s+")
                    end

                    if isProgress then
                        right.__FGO_TooltipX_Hidden = true
                        right:Hide()
                        hiddenCount = hiddenCount + 1
                    end
                end
            end
        end

        if hiddenCount > 0 then
            DebugLog("cleanup:" .. tostring(mode), ("cleanup hid %d line(s) (%s)"):format(hiddenCount, mode))
        end
    end

    local function ApplyTooltipX(tooltip)
        if not tooltip then return end

        -- Always restore any previous line hides so toggling works without reload.
        RestoreHiddenTooltipLines(tooltip)

        -- Master enable: when OFF, TooltipX should be inert and undo any prior hiding.
        if not GetBoolSetting("tooltipXEnabledAcc", false) then
            if tooltip.__FGO_TooltipX_ForcedHidden then
                RestoreTooltipAlpha(tooltip)
            end
            return
        end

        if ShouldHideTooltipNow(tooltip) then
            DebugLog("hide:combat", "combat hide")
            ForceHideTooltip(tooltip)
            return
        end

        if tooltip.__FGO_TooltipX_ForcedHidden then
            RestoreTooltipAlpha(tooltip)
        end

        HideQuestProgressLines(tooltip)
    end

    local function HookTooltipByName(globalName)
        local tt = _G and _G[globalName]
        if not (tt and tt.HookScript) then
            return
        end

        if tt.__FGO_TooltipX_Hooked then
            ApplyTooltipX(tt)
            return
        end

        tt.__FGO_TooltipX_Hooked = true
        tt:HookScript("OnShow", ApplyTooltipX)
        tt:HookScript("OnHide", function(self)
            RestoreHiddenTooltipLines(self)
            if self.__FGO_TooltipX_ForcedHidden then
                RestoreTooltipAlpha(self)
            end
        end)

        ApplyTooltipX(tt)
    end

    local function HookAllKnownTooltips()
        for _, name in ipairs({
            "GameTooltip",
            "ItemRefTooltip",
            "ShoppingTooltip1",
            "ShoppingTooltip2",
            "ShoppingTooltip3",
            "WorldMapTooltip",
            "BattlePetTooltip",
            "FloatingBattlePetTooltip",
            "FloatingPetBattleAbilityTooltip",
            "EmbeddedItemTooltip",
        }) do
            HookTooltipByName(name)
        end
    end

    local function HookTooltipDataProcessor()
        if not (TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall) then
            return
        end
        if TooltipDataProcessor.__FGO_TooltipX_Hooked then
            return
        end
        TooltipDataProcessor.__FGO_TooltipX_Hooked = true

        if type(Enum) == "table" and type(Enum.TooltipDataType) == "table" then
            for _, tooltipDataType in pairs(Enum.TooltipDataType) do
                if type(tooltipDataType) == "number" then
                    TooltipDataProcessor.AddTooltipPostCall(tooltipDataType, ApplyTooltipX)
                end
            end
        end
    end

    local function InitOnce()
        if didInit then
            return
        end
        didInit = true

        HookTooltipDataProcessor()
        HookAllKnownTooltips()
    end

    function ns.ApplyTooltipXSetting(force)
        InitOnce()

        if force then
            HookAllKnownTooltips()
        end
    end

    local function ReapplyIfTooltipShown()
        if GameTooltip and GameTooltip.IsShown and GameTooltip:IsShown() then
            ApplyTooltipX(GameTooltip)
        end
    end

    local function OnEvent(_, event, arg1)
        if event == "ADDON_LOADED" and arg1 == addonName then
            -- Initialize defaults if needed.
            local s = GetSettings()
            if type(s) == "table" then
                if type(s.tooltipXEnabledAcc) ~= "boolean" then s.tooltipXEnabledAcc = false end
                if type(s.tooltipXCombatHideAcc) ~= "boolean" then s.tooltipXCombatHideAcc = false end
                if type(s.tooltipXCombatModifierAcc) ~= "string" then s.tooltipXCombatModifierAcc = "CTRL" end
                if type(s.tooltipXCombatShowTargetAcc) ~= "boolean" then s.tooltipXCombatShowTargetAcc = true end
                if type(s.tooltipXCombatShowFocusAcc) ~= "boolean" then s.tooltipXCombatShowFocusAcc = false end
                if type(s.tooltipXCombatShowMouseoverAcc) ~= "boolean" then s.tooltipXCombatShowMouseoverAcc = true end
                if type(s.tooltipXCombatShowFriendlyPlayersAcc) ~= "boolean" then s.tooltipXCombatShowFriendlyPlayersAcc = false end
                if type(s.tooltipXCleanupAcc) ~= "boolean" then s.tooltipXCleanupAcc = false end
                if type(s.tooltipXCleanupCombatOnlyAcc) ~= "boolean" then s.tooltipXCleanupCombatOnlyAcc = true end
                if type(s.tooltipXCleanupModeAcc) ~= "string" then s.tooltipXCleanupModeAcc = "strict" end
                if type(s.tooltipXDebugAcc) ~= "boolean" then s.tooltipXDebugAcc = false end
            end
            return
        end

        if event == "PLAYER_LOGIN" or event == "VARIABLES_LOADED" then
            InitOnce()
            ns.ApplyTooltipXSetting(true)
            return
        end

        if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
            -- Combat state changed; if a tooltip is currently visible, update it.
            ReapplyIfTooltipShown()
            return
        end
    end

    local f = _G.CreateFrame("Frame")
    f:RegisterEvent("ADDON_LOADED")
    f:RegisterEvent("PLAYER_LOGIN")
    f:RegisterEvent("VARIABLES_LOADED")
    f:RegisterEvent("PLAYER_REGEN_DISABLED")
    f:RegisterEvent("PLAYER_REGEN_ENABLED")
    f:SetScript("OnEvent", OnEvent)
end

-- ============================================================================
-- Tutorial suppression (formerly Tutorial)
-- ============================================================================

do
    local didApplyHide
    local pendingChanges

    local IsAddOnLoadedSafe = (_G.C_AddOns and rawget(_G.C_AddOns, "IsAddOnLoaded")) or rawget(_G, "IsAddOnLoaded")
    if IsAddOnLoadedSafe then
        -- kept for future use / compatibility
    end

    local function GetSettings()
        if ns and type(ns._InitSV) == "function" then
            ns._InitSV()
        end
        local acc = rawget(_G, "AutoGame_Settings") or rawget(_G, "AutoGossip_Settings")
        if type(acc) ~= "table" then
            return nil
        end
        return acc
    end

    local function GetTutorialEnabledEffective()
        local acc = GetSettings()
        if type(acc) == "table" and type(acc.tutorialEnabledAcc) == "boolean" then
            return acc.tutorialEnabledAcc
        end

        -- Back-compat: old versions stored tutorialOffAcc.
        if type(acc) == "table" and type(acc.tutorialOffAcc) == "boolean" then
            return (not acc.tutorialOffAcc)
        end

        return true
    end

    local function GetTutorialOffEffective()
        return not GetTutorialEnabledEffective()
    end

    local function ApplyMicroAlertsHook()
        -- Intentionally a no-op.
        -- Overwriting Blizzard globals (like MainMenuMicroButton_AreAlertsEnabled) is a common source of UI taint
        -- and can lead to blocked protected calls inside Blizzard_ActionBarController.
        -- The tutorial suppression in this addon relies on CVars instead.
        return
    end

    local function ApplyHideTutorials(force)
        if didApplyHide and not force then
            return
        end
        didApplyHide = true

        if not GetTutorialOffEffective() then
            return
        end

        if _G.C_CVar and _G.C_CVar.SetCVar then
            _G.C_CVar.SetCVar("showTutorials", 0)
            _G.C_CVar.SetCVar("showNPETutorials", 0)
            _G.C_CVar.SetCVar("hideAdventureJournalAlerts", 1)
        elseif _G.SetCVar then
            _G.SetCVar("showTutorials", 0)
            _G.SetCVar("showNPETutorials", 0)
            _G.SetCVar("hideAdventureJournalAlerts", 1)
        end

        local numTutorials = tonumber(rawget(_G, "NUM_LE_FRAME_TUTORIALS"))
        local numAccountTutorials = tonumber(rawget(_G, "NUM_LE_FRAME_TUTORIAL_ACCCOUNTS"))

        local lastInfoFrame
        if numTutorials and _G.C_CVar and _G.C_CVar.GetCVarBitfield then
            lastInfoFrame = _G.C_CVar.GetCVarBitfield("closedInfoFrames", numTutorials)
        end

        if pendingChanges or (not lastInfoFrame) then
            if numTutorials and _G.C_CVar and _G.C_CVar.SetCVarBitfield then
                for i = 1, numTutorials do
                    _G.C_CVar.SetCVarBitfield("closedInfoFrames", i, true)
                end
            end
            if numAccountTutorials and _G.C_CVar and _G.C_CVar.SetCVarBitfield then
                for i = 1, numAccountTutorials do
                    _G.C_CVar.SetCVarBitfield("closedInfoFramesAccountWide", i, true)
                end
            end
        end

        ApplyMicroAlertsHook()
    end

    local function ApplyShowTutorials()
        if _G.C_CVar and _G.C_CVar.SetCVar then
            _G.C_CVar.SetCVar("showTutorials", 1)
            _G.C_CVar.SetCVar("showNPETutorials", 1)
            _G.C_CVar.SetCVar("hideAdventureJournalAlerts", 0)
        elseif _G.SetCVar then
            _G.SetCVar("showTutorials", 1)
            _G.SetCVar("showNPETutorials", 1)
            _G.SetCVar("hideAdventureJournalAlerts", 0)
        end

        ApplyMicroAlertsHook()
    end

    function ns.ApplyTutorialSetting(force)
        if GetTutorialOffEffective() then
            ApplyHideTutorials(force)
        else
            ApplyShowTutorials()
        end
    end

    -- If you're in Exile's Reach and level 1 this cvar gets automatically enabled.
    if _G.hooksecurefunc then
        _G.hooksecurefunc("NPE_CheckTutorials", function()
            if not GetTutorialOffEffective() then
                return
            end
            if _G.C_PlayerInfo and _G.C_PlayerInfo.IsPlayerNPERestricted and _G.UnitLevel and _G.SetCVar then
                if _G.C_PlayerInfo.IsPlayerNPERestricted() and _G.UnitLevel("player") == 1 then
                    print("fr0z3nUI_GameOptions: Disabling NPE tutorial, please disregard Blizzard debug prints.")
                    _G.SetCVar("showTutorials", 0)
                end
            end
        end)
    end

    local function OnEvent(_, event, arg1)
        if event == "ADDON_LOADED" and arg1 == addonName then
            local tocVersion = select(4, _G.GetBuildInfo())
            local acc = GetSettings()
            if type(acc) == "table" and GetTutorialOffEffective() then
                if (not acc.tutorialBuild) or (acc.tutorialBuild < tocVersion) then
                    acc.tutorialBuild = tocVersion
                    pendingChanges = true
                end
            end
            return
        end

        if event == "PLAYER_LOGIN" or event == "VARIABLES_LOADED" then
            ns.ApplyTutorialSetting(false)
        end
    end

    local f = _G.CreateFrame("Frame")
    f:RegisterEvent("ADDON_LOADED")
    f:RegisterEvent("PLAYER_LOGIN")
    f:RegisterEvent("VARIABLES_LOADED")
    f:SetScript("OnEvent", OnEvent)
end
