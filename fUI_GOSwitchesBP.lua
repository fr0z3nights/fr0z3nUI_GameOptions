local _, ns = ...
ns = ns or {}

ns.SwitchesBP = ns.SwitchesBP or {}
local BP = ns.SwitchesBP

local function InitSV()
    if ns and type(ns._InitSV) == "function" then
        ns._InitSV()
    end
end

local function IsEnabled()
    InitSV()
    if not (AutoGossip_Settings and AutoGossip_CharSettings) then
        return false
    end
    if not (AutoGossip_Settings.petWalkEnabledAcc and true or false) then
        return false
    end
    if AutoGossip_CharSettings.petWalkDisabledChar and true or false then
        return false
    end
    return true
end

local function NormalizeMode(m)
    if m == "favorite" or m == "specific" or m == "random" then
        return m
    end
    return "random"
end

local function GetMode()
    InitSV()
    return NormalizeMode(AutoGossip_Settings and AutoGossip_Settings.petWalkModeAcc)
end

local function GetDelay()
    InitSV()
    local d = tonumber(AutoGossip_Settings and AutoGossip_Settings.petWalkDelayAcc)
    if type(d) ~= "number" then
        return 1.0
    end
    if d < 0 then
        return 0
    end
    if d > 10 then
        return 10
    end
    return d
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

local function GetSummonedGUID()
    return SafeCall(C_PetJournal and C_PetJournal.GetSummonedPetGUID)
end

local function IsInPetBattle()
    local fn = C_PetBattles and C_PetBattles.IsInBattle
    if type(fn) ~= "function" then
        return false
    end
    local ok, v = pcall(fn)
    if not ok then
        return false
    end
    return v and true or false
end

local function CanSummonNow()
    if not IsEnabled() then
        return false
    end

    if not (C_PetJournal and (C_PetJournal.SummonPetByGUID or C_PetJournal.SummonRandomPet)) then
        return false
    end

    if IsInPetBattle() then
        return false
    end

    if UnitAffectingCombat and UnitAffectingCombat("player") then
        return false
    end

    if InCombatLockdown and InCombatLockdown() then
        return false
    end

    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then
        return false
    end

    if UnitOnTaxi and UnitOnTaxi("player") then
        return false
    end

    if IsMounted and IsMounted() then
        return false
    end

    if IsFalling and IsFalling() then
        return false
    end

    if UnitCastingInfo and UnitCastingInfo("player") then
        return false
    end

    if UnitChannelInfo and UnitChannelInfo("player") then
        return false
    end

    if GetUnitSpeed and (GetUnitSpeed("player") or 0) > 0 then
        return false
    end

    local summoned = GetSummonedGUID()
    if type(summoned) == "string" and summoned ~= "" then
        return false
    end

    return true
end

local function GetPetNameByGUID(guid)
    if type(guid) ~= "string" or guid == "" then
        return nil
    end
    if not (C_PetJournal and C_PetJournal.GetPetInfoByPetID) then
        return nil
    end

    local petID, speciesID, isOwned, customName, level, favorite
    petID, speciesID, isOwned, customName, level, favorite = SafeCall(C_PetJournal.GetPetInfoByPetID, guid)

    if type(customName) == "string" and customName ~= "" then
        return customName
    end

    if not (C_PetJournal and C_PetJournal.GetPetInfoBySpeciesID) then
        return nil
    end

    local speciesName = SafeCall(C_PetJournal.GetPetInfoBySpeciesID, speciesID)
    if type(speciesName) == "string" and speciesName ~= "" then
        return speciesName
    end

    return nil
end

local function PickFavoritePetGUID()
    if not (C_PetJournal and C_PetJournal.GetNumPets and C_PetJournal.GetPetInfoByIndex) then
        return nil
    end

    local numPets = SafeCall(C_PetJournal.GetNumPets)
    numPets = tonumber(numPets) or 0
    if numPets <= 0 then
        return nil
    end

    for i = 1, numPets do
        local petID, speciesID, isOwned, customName, level, favorite, isRevoked
        petID, speciesID, isOwned, customName, level, favorite, isRevoked = SafeCall(C_PetJournal.GetPetInfoByIndex, i)

        if petID and isOwned and (favorite and true or false) then
            return petID
        end
    end

    return nil
end

local function TrySummon(reason)
    if not CanSummonNow() then
        return false
    end

    InitSV()

    local mode = GetMode()
    local specificGUID = AutoGossip_Settings and AutoGossip_Settings.petWalkSpecificGUIDAcc

    if mode == "specific" then
        if type(specificGUID) == "string" and specificGUID ~= "" and C_PetJournal and C_PetJournal.SummonPetByGUID then
            SafeCall(C_PetJournal.SummonPetByGUID, specificGUID)
            return true
        end

        -- Fallback: if specific is not set/valid, behave like favorite.
        mode = "favorite"
    end

    if mode == "favorite" then
        local fav = PickFavoritePetGUID()
        if type(fav) == "string" and fav ~= "" and C_PetJournal and C_PetJournal.SummonPetByGUID then
            SafeCall(C_PetJournal.SummonPetByGUID, fav)
            return true
        end

        -- Fallback: if no favorite exists, behave like random.
        mode = "random"
    end

    if mode == "random" and C_PetJournal and C_PetJournal.SummonRandomPet then
        SafeCall(C_PetJournal.SummonRandomPet)
        return true
    end

    return false
end

local pendingTimer
local lastAttemptAt = 0

local function GetTimeNow()
    return (GetTime and GetTime()) or 0
end

local function CancelPending()
    if pendingTimer and pendingTimer.Cancel then
        pendingTimer:Cancel()
    end
    pendingTimer = nil
end

local function ScheduleSummon(reason, delay)
    if not IsEnabled() then
        CancelPending()
        return
    end

    delay = tonumber(delay)
    if type(delay) ~= "number" then
        delay = GetDelay()
    end
    if delay < 0 then
        delay = 0
    end

    CancelPending()

    if not (C_Timer and C_Timer.NewTimer) then
        TrySummon(reason)
        return
    end

    pendingTimer = C_Timer.NewTimer(delay, function()
        pendingTimer = nil

        local now = GetTimeNow()
        if now - (lastAttemptAt or 0) < 1.0 then
            return
        end
        lastAttemptAt = now

        TrySummon(reason)
    end)
end

local function MaybeDismissOnStealth()
    InitSV()
    if not IsEnabled() then
        return
    end

    if not (AutoGossip_Settings and AutoGossip_Settings.petWalkDismissOnStealthAcc) then
        return
    end

    if not (IsStealthed and IsStealthed()) then
        return
    end

    local summoned = GetSummonedGUID()
    if type(summoned) ~= "string" or summoned == "" then
        return
    end

    if C_PetJournal and C_PetJournal.DismissPet then
        SafeCall(C_PetJournal.DismissPet)
        return
    end

    if C_PetJournal and C_PetJournal.SummonPetByGUID then
        -- SummonPetByGUID toggles: summoned pet => dismiss.
        SafeCall(C_PetJournal.SummonPetByGUID, summoned)
    end
end

function BP.OnSettingsChanged()
    -- Keep things responsive when toggles change.
    if not IsEnabled() then
        CancelPending()
        if BP.UpdatePetWalkFloatButton then
            BP.UpdatePetWalkFloatButton()
        end
        return
    end
    ScheduleSummon("settings", 0.15)

    if BP.UpdatePetWalkFloatButton then
        BP.UpdatePetWalkFloatButton()
    end
end

-- ============================================================================
-- Floating Pet Walk button (text-only, draggable; styled like Reload UI float)
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

    local function GetUI()
        InitSV()
        return rawget(_G, "AutoGame_UI") or rawget(_G, "AutoGossip_UI")
    end

    local function IsFloatEnabled()
        local ui = GetUI()
        if not ui then
            return false
        end
        return (ui.petWalkFloatEnabled and true or false)
    end

    local function IsLocked()
        local ui = GetUI()
        if not ui then
            return false
        end
        return (ui.petWalkFloatLocked and true or false)
    end

    local function IsFloatPosAccountWideOutsideChar()
        local ui = GetUI()
        if type(ui) ~= "table" then
            return true
        end
        if ui.petWalkFloatPosAccOutsideChar == nil then
            ui.petWalkFloatPosAccOutsideChar = true
        end
        return (ui.petWalkFloatPosAccOutsideChar and true or false)
    end

    local function EnsurePosTbl(t)
        if type(t) ~= "table" then
            t = {}
        end
        if type(t.point) ~= "string" or t.point == "" then t.point = "TOP" end
        if type(t.relativePoint) ~= "string" or t.relativePoint == "" then t.relativePoint = t.point end
        t.x = tonumber(t.x) or 0
        t.y = tonumber(t.y) or -140
        return t
    end

    local function CopyPosTbl(src)
        if type(src) ~= "table" then
            return { point = "TOP", relativePoint = "TOP", x = 0, y = -140 }
        end
        return {
            point = src.point,
            relativePoint = src.relativePoint,
            x = src.x,
            y = src.y,
        }
    end

    local function EnsureAccFloatPosStore(ui)
        ui.petWalkFloatPos = EnsurePosTbl(ui.petWalkFloatPos)
        return ui.petWalkFloatPos
    end

    local function EnsureCharFloatPosStore(fallbackPos)
        if type(AutoGossip_CharSettings.petWalkFloatPosChar) ~= "table" then
            AutoGossip_CharSettings.petWalkFloatPosChar = CopyPosTbl(fallbackPos)
        else
            local t = AutoGossip_CharSettings.petWalkFloatPosChar
            if t.point == nil and t.relativePoint == nil and t.x == nil and t.y == nil then
                AutoGossip_CharSettings.petWalkFloatPosChar = CopyPosTbl(fallbackPos)
            end
        end
        AutoGossip_CharSettings.petWalkFloatPosChar = EnsurePosTbl(AutoGossip_CharSettings.petWalkFloatPosChar)
        return AutoGossip_CharSettings.petWalkFloatPosChar
    end

    local function GetActiveFloatPosStore()
        local ui = GetUI()
        if type(ui) ~= "table" then
            return nil
        end
        if IsFloatPosAccountWideOutsideChar() then
            return EnsureAccFloatPosStore(ui)
        end

        local accPos = EnsureAccFloatPosStore(ui)
        return EnsureCharFloatPosStore(accPos)
    end

    local function SetActiveFloatPos(point, relativePoint, x, y)
        local t = GetActiveFloatPosStore()
        if type(t) ~= "table" then
            return
        end
        t.point = point
        t.relativePoint = relativePoint
        t.x = x
        t.y = y
    end

    local function ApplySavedPosition(frame)
        local ui = GetUI()
        if not (ui and frame and frame.SetPoint) then
            return
        end

        local p = GetActiveFloatPosStore() or ui.petWalkFloatPos
        if type(p) ~= "table" then
            return
        end
        local point = type(p.point) == "string" and p.point or "TOP"
        local relPoint = type(p.relativePoint) == "string" and p.relativePoint or point
        local x = tonumber(p.x) or 0
        local y = tonumber(p.y) or -140

        frame:ClearAllPoints()
        frame:SetPoint(point, UIParent, relPoint, x, y)
    end

    local function GetStateColor()
        -- Red: account disabled (Button 1)
        if not (AutoGossip_Settings and AutoGossip_Settings.petWalkEnabledAcc and true or false) then
            return "ffff0000", "acc-off"
        end
        -- Green: char enabled (Button 2, inverted legacy disable flag)
        if not (AutoGossip_CharSettings and AutoGossip_CharSettings.petWalkDisabledChar and true or false) then
            return "ff00ff00", "char-on"
        end
        -- Orange: char disabled (Button 2)
        return "ffff8000", "char-off"
    end

    local function UpdateLabel()
        if not (btn and btn._label and btn._label.SetText) then
            return
        end
        local color, _ = GetStateColor()
        btn._label:SetText("|c" .. color .. "Pet Walk|r")
    end

    local function ApplyTextSize()
        if not (btn and btn._label and btn._label.SetFont) then
            return
        end
        local ui = GetUI()
        local want = ui and tonumber(ui.petWalkFloatTextSize)
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

    local function DismissPetNow()
        local summoned = GetSummonedGUID()
        if type(summoned) ~= "string" or summoned == "" then
            return
        end
        if C_PetJournal and C_PetJournal.DismissPet then
            SafeCall(C_PetJournal.DismissPet)
            return
        end
        if C_PetJournal and C_PetJournal.SummonPetByGUID then
            -- SummonPetByGUID toggles: summoned pet => dismiss.
            SafeCall(C_PetJournal.SummonPetByGUID, summoned)
        end
    end

    function BP.EnsurePetWalkFloatButton()
        if btn and btn.SetText then
            return btn
        end
        if not (CreateFrame and UIParent) then
            return nil
        end

        btn = CreateFrame("Button", "FGO_FloatingPetWalkButton", UIParent)
        btn:SetSize(90, 18)
        btn:SetClampedToScreen(true)
        btn:SetFrameStrata("DIALOG")
        btn:EnableMouse(true)
        btn:SetMovable(true)
        btn:RegisterForDrag("RightButton")

        local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetAllPoints(btn)
        fs:SetJustifyH("CENTER")
        fs:SetJustifyV("MIDDLE")
        btn._label = fs

        ApplyTextSize()
        ApplySavedPosition(btn)
        UpdateLabel()

        btn:SetScript("OnClick", function(_, mouseButton)
            InitSV()

            if mouseButton == "RightButton" then
                if IsLocked() then
                    DismissPetNow()
                end
                return
            end

            if mouseButton ~= "LeftButton" then
                return
            end

            if not (AutoGossip_Settings and AutoGossip_Settings.petWalkEnabledAcc and true or false) then
                return
            end

            AutoGossip_CharSettings.petWalkDisabledChar = not (AutoGossip_CharSettings.petWalkDisabledChar and true or false)
            UpdateLabel()
            BP.OnSettingsChanged()
        end)

        btn:SetScript("OnDragStart", function(self)
            if IsLocked() then
                return
            end
            if self and self.StartMoving then
                self:StartMoving()
            end
        end)
        btn:SetScript("OnDragStop", function(self)
            if self and self.StopMovingOrSizing then
                self:StopMovingOrSizing()
            end

            if IsLocked() then
                ApplySavedPosition(self)
                return
            end

            local point, _, relPoint, x, y = self:GetPoint(1)
            SetActiveFloatPos(point, relPoint, x, y)
        end)

        btn:SetScript("OnEnter", function(self)
            if not GameTooltip then
                return
            end
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText("|cff00ccff[FGO]|r Pet Walk")

            local _, state = GetStateColor()
            if state == "acc-off" then
                GameTooltip:AddLine("Account is OFF.", 1, 1, 1, true)
            else
                local onChar = not (AutoGossip_CharSettings and AutoGossip_CharSettings.petWalkDisabledChar and true or false)
                GameTooltip:AddLine("Left-click: " .. (onChar and "disable" or "enable"), 1, 1, 1, true)
            end

            if IsLocked() then
                GameTooltip:AddLine("Right-click: dismiss pet", 1, 1, 1, true)
            else
                GameTooltip:AddLine("Right-drag: move", 1, 1, 1, true)
            end

            Tooltip_ApplyFontDelta(GameTooltip, -1, "FGO_PetWalkFloat")
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function()
            if GameTooltip then
                Tooltip_RestoreFonts(GameTooltip, "FGO_PetWalkFloat")
                GameTooltip:Hide()
            end
        end)

        return btn
    end

    function BP.UpdatePetWalkFloatButton()
        InitSV()
        if IsFloatEnabled() then
            local b = BP.EnsurePetWalkFloatButton()
            if b and b.Show then
                ApplySavedPosition(b)
                ApplyTextSize()
                UpdateLabel()
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
            BP.UpdatePetWalkFloatButton()
        end
    end

    local f = _G.CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:RegisterEvent("VARIABLES_LOADED")
    f:SetScript("OnEvent", OnEvent)
end

-- ============================================================================
-- Config popout
-- ============================================================================

local configPopup

local function EnsureConfigPopup()
    if configPopup or not UIParent or not CreateFrame then
        return configPopup
    end

    local p = CreateFrame("Frame", "FGO_PetWalkConfigPopup", UIParent, "BackdropTemplate")
    p:SetSize(360, 220)
    do
        local main = _G and rawget(_G, "AutoGameOptions")
        if main and main.IsShown and main:IsShown() then
            -- Overlap by 8px to remove the visible gap caused by 4px backdrop insets on both frames.
            p:SetPoint("TOPLEFT", main, "TOPRIGHT", -8, 0)
        else
            p:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end
    end
    p:SetFrameStrata("DIALOG")
    p:SetClampedToScreen(true)
    p:Hide()

    p:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        tile = true,
        tileSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    p:SetBackdropColor(0, 0, 0, 0.85)

    do
        local closeBtn = CreateFrame("Button", nil, p, "UIPanelCloseButton")
        closeBtn:SetPoint("TOPRIGHT", p, "TOPRIGHT", -6, -6)
        if closeBtn.SetFrameLevel then
            closeBtn:SetFrameLevel((p.GetFrameLevel and p:GetFrameLevel() or 0) + 20)
        end
        closeBtn:SetScript("OnClick", function() if p and p.Hide then p:Hide() end end)
        p._closeBtn = closeBtn
    end

    p.title = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    p.title:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -6)
    p.title:SetText("Pet Walk Config")
    do
        local fontPath, fontSize, fontFlags = p.title:GetFont()
        if fontPath and fontSize then
            p.title:SetFont(fontPath, fontSize + 2, fontFlags)
        end
    end

    do
        local tabBarBG = CreateFrame("Frame", nil, p, "BackdropTemplate")
        tabBarBG:SetPoint("TOPLEFT", p, "TOPLEFT", 4, -4)
        tabBarBG:SetPoint("TOPRIGHT", p, "TOPRIGHT", -4, -4)
        tabBarBG:SetHeight(26)
        tabBarBG:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            tile = true,
            tileSize = 16,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
        tabBarBG:SetBackdropColor(0, 0, 0, 0.92)
        tabBarBG:SetFrameLevel((p.GetFrameLevel and p:GetFrameLevel() or 0) + 1)
        p._tabBarBG = tabBarBG

        -- Keep the title above the bar background.
        if p.title and p.title.SetParent then
            p.title:SetParent(tabBarBG)
            p.title:ClearAllPoints()
            p.title:SetPoint("LEFT", tabBarBG, "LEFT", 8, 0)
        end
    end

    local btnMode = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    btnMode:SetSize(330, 22)
    btnMode:SetPoint("TOP", p, "TOP", 0, -40)
    p.btnMode = btnMode

    local btnSpecific = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    btnSpecific:SetSize(160, 22)
    btnSpecific:SetPoint("TOPLEFT", btnMode, "BOTTOMLEFT", 0, -10)
    btnSpecific:SetText("Use Current Pet")
    p.btnSpecific = btnSpecific

    local specificLabel = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    specificLabel:SetPoint("LEFT", btnSpecific, "RIGHT", 10, 0)
    specificLabel:SetJustifyH("LEFT")
    specificLabel:SetText("Specific: (none)")
    p.specificLabel = specificLabel

    local btnDelay = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    btnDelay:SetSize(160, 22)
    btnDelay:SetPoint("TOPLEFT", btnSpecific, "BOTTOMLEFT", 0, -10)
    p.btnDelay = btnDelay

    local btnStealth = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    btnStealth:SetSize(160, 22)
    btnStealth:SetPoint("LEFT", btnDelay, "RIGHT", 10, 0)
    p.btnStealth = btnStealth

    -- OSD/Lock/Input/XY row (copied from Mount Up patterns)
    local SPLIT_W, SPLIT_H = 90, 18

    local function GetFontColorRGB(colorObj, fallbackR, fallbackG, fallbackB)
        if colorObj and type(colorObj.GetRGB) == "function" then
            local r, g, b = colorObj:GetRGB()
            if type(r) == "number" and type(g) == "number" and type(b) == "number" then
                return r, g, b
            end
        end
        if type(colorObj) == "table" and type(colorObj.r) == "number" and type(colorObj.g) == "number" and type(colorObj.b) == "number" then
            return colorObj.r, colorObj.g, colorObj.b
        end
        return fallbackR, fallbackG, fallbackB
    end

    local function SetSegGreenGreyFS(fs, label, enabled)
        if not (fs and fs.SetText) then
            return
        end
        if enabled then
            fs:SetText("|cff00ff00" .. label .. "|r")
        else
            fs:SetText("|cff888888" .. label .. "|r")
        end
    end

    local function CreateTextToggleButton(parent, width, height)
        local b = CreateFrame("Button", nil, parent)
        b:SetSize(width, height)
        b:EnableMouse(true)
        if parent and parent.GetFrameLevel and b.SetFrameLevel then
            b:SetFrameLevel((parent:GetFrameLevel() or 0) + 10)
        end
        local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("CENTER", b, "CENTER", 0, 0)
        b._fs = fs
        return b
    end

    local function MakeBorderlessHoverBox(parent, width, height)
        local host = CreateFrame("Frame", nil, parent)
        host:SetSize(width, height)

        local bg = CreateFrame("Frame", nil, host, "BackdropTemplate")
        bg:SetAllPoints(host)
        bg:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            tile = true,
            tileSize = 16,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        bg:SetBackdropColor(1, 1, 1, 0.0)
        host._bg = bg

        local eb = CreateFrame("EditBox", nil, host)
        eb:SetAllPoints(host)
        eb:SetFontObject("GameFontHighlightSmall")
        eb:SetAutoFocus(false)
        eb:SetJustifyH("CENTER")
        eb:SetJustifyV("MIDDLE")
        eb:EnableMouse(true)
        eb:SetTextInsets(2, 2, 1, 1)
        host.eb = eb

        host:SetScript("OnEnter", function()
            if host._bg and host._bg.SetBackdropColor then
                host._bg:SetBackdropColor(1, 1, 1, 0.12)
            end
        end)
        host:SetScript("OnLeave", function()
            if host._bg and host._bg.SetBackdropColor then
                host._bg:SetBackdropColor(1, 1, 1, 0.0)
            end
        end)

        eb:SetScript("OnEnter", function()
            if host._bg and host._bg.SetBackdropColor then
                host._bg:SetBackdropColor(1, 1, 1, 0.12)
            end
        end)
        eb:SetScript("OnLeave", function()
            if host._bg and host._bg.SetBackdropColor then
                host._bg:SetBackdropColor(1, 1, 1, 0.0)
            end
        end)

        return host
    end

    local osdRow = CreateFrame("Frame", nil, p)
    osdRow:SetSize(SPLIT_W, SPLIT_H)
    osdRow:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 12, 12)
    p.osdRow = osdRow

    local splitOSDLock = CreateFrame("Button", nil, osdRow, "UIPanelButtonTemplate")
    splitOSDLock:SetSize(SPLIT_W, SPLIT_H)
    splitOSDLock:SetPoint("LEFT", osdRow, "LEFT", 0, 0)
    splitOSDLock:SetText("")
    p.splitOSDLock = splitOSDLock

    local fsOSD = splitOSDLock:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fsOSD:SetPoint("CENTER", splitOSDLock, "LEFT", math.floor(SPLIT_W / 4), 0)
    fsOSD:SetJustifyH("CENTER")
    p.fsOSD = fsOSD

    local fsLock = splitOSDLock:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fsLock:SetPoint("CENTER", splitOSDLock, "RIGHT", -math.floor(SPLIT_W / 4), 0)
    fsLock:SetJustifyH("CENTER")
    p.fsLock = fsLock

    local sizeBox = MakeBorderlessHoverBox(p, 25, 18)
    sizeBox:SetPoint("LEFT", osdRow, "RIGHT", 6, 0)
    p.sizeBox = sizeBox

    local xyBtn = CreateTextToggleButton(p, 26, 18)
    xyBtn:SetPoint("LEFT", sizeBox, "RIGHT", 6, 0)
    p.xyBtn = xyBtn

    local function SanitizeDigits(text)
        text = tostring(text or "")
        text = text:gsub("%D+", "")
        if #text > 2 then
            text = text:sub(1, 2)
        end
        return text
    end

    local function GetUI()
        InitSV()
        return rawget(_G, "AutoGame_UI") or rawget(_G, "AutoGossip_UI")
    end

    local function IsFloatPosAccountWideOutsideChar()
        local ui = GetUI()
        if type(ui) ~= "table" then
            return true
        end
        if ui.petWalkFloatPosAccOutsideChar == nil then
            ui.petWalkFloatPosAccOutsideChar = true
        end
        return (ui.petWalkFloatPosAccOutsideChar and true or false)
    end

    local function RefreshXYBtn()
        InitSV()
        local acc = IsFloatPosAccountWideOutsideChar()
        if xyBtn and xyBtn._fs and xyBtn._fs.SetText and xyBtn._fs.SetTextColor then
            xyBtn._fs:SetText("XY")
            if acc then
                local r, g, b = GetFontColorRGB(rawget(_G, "GREEN_FONT_COLOR"), 0.20, 1.00, 0.20)
                xyBtn._fs:SetTextColor(r, g, b, 1)
            else
                xyBtn._fs:SetTextColor(0.70, 0.70, 0.70, 1)
            end
        end
    end

    local function RefreshFromSV()
        InitSV()

        local mode = GetMode()
        local modeText = (mode == "random" and "Random") or (mode == "favorite" and "Favorites") or "Specific"
        btnMode:SetText("Mode: " .. modeText)

        local delay = GetDelay()
        btnDelay:SetText(string.format("Delay: %.1fs", delay))

        local stealthOn = (AutoGossip_Settings and AutoGossip_Settings.petWalkDismissOnStealthAcc) and true or false
        if stealthOn then
            btnStealth:SetText("Stealth: |cff00ccffDismiss|r")
        else
            btnStealth:SetText("Stealth: |cff888888Keep|r")
        end

        local guid = AutoGossip_Settings and AutoGossip_Settings.petWalkSpecificGUIDAcc
        local name = GetPetNameByGUID(guid)
        if type(name) == "string" and name ~= "" then
            specificLabel:SetText("Specific: " .. name)
        elseif type(guid) == "string" and guid ~= "" then
            specificLabel:SetText("Specific: (set)")
        else
            specificLabel:SetText("Specific: (none)")
        end

        local ui = GetUI()
        local floatOn = (ui and ui.petWalkFloatEnabled) and true or false
        local locked = (ui and ui.petWalkFloatLocked) and true or false
        local size = (ui and tonumber(ui.petWalkFloatTextSize)) or 12

        SetSegGreenGreyFS(fsOSD, "OSD", floatOn)
        SetSegGreenGreyFS(fsLock, "Lock", locked)

        if sizeBox and sizeBox.eb and not sizeBox.eb:HasFocus() then
            sizeBox.eb:SetText(string.format("%02d", math.floor(size + 0.5)))
        end

        RefreshXYBtn()
    end

    p.RefreshFromSV = RefreshFromSV

    btnMode:SetScript("OnClick", function()
        InitSV()
        local m = GetMode()
        if m == "random" then
            m = "favorite"
        elseif m == "favorite" then
            m = "specific"
        else
            m = "random"
        end
        AutoGossip_Settings.petWalkModeAcc = m
        RefreshFromSV()
        BP.OnSettingsChanged()
    end)

    btnSpecific:SetScript("OnClick", function()
        InitSV()
        local guid = GetSummonedGUID()
        if type(guid) ~= "string" or guid == "" then
            return
        end
        AutoGossip_Settings.petWalkSpecificGUIDAcc = guid
        AutoGossip_Settings.petWalkModeAcc = "specific"
        RefreshFromSV()
        BP.OnSettingsChanged()
    end)

    btnDelay:SetScript("OnClick", function()
        InitSV()
        local d = GetDelay()
        if d <= 0.5 then
            d = 1.0
        elseif d <= 1.0 then
            d = 2.0
        else
            d = 0.5
        end
        AutoGossip_Settings.petWalkDelayAcc = d
        RefreshFromSV()
        BP.OnSettingsChanged()
    end)

    btnStealth:SetScript("OnClick", function()
        InitSV()
        AutoGossip_Settings.petWalkDismissOnStealthAcc = not (AutoGossip_Settings.petWalkDismissOnStealthAcc and true or false)
        RefreshFromSV()
        MaybeDismissOnStealth()
    end)

    xyBtn:RegisterForClicks("LeftButtonUp")
    xyBtn:SetScript("OnClick", function()
        InitSV()
        local ui = GetUI()
        if type(ui) ~= "table" then
            return
        end
        if ui.petWalkFloatPosAccOutsideChar == nil then
            ui.petWalkFloatPosAccOutsideChar = true
        end
        ui.petWalkFloatPosAccOutsideChar = not (ui.petWalkFloatPosAccOutsideChar and true or false)
        RefreshFromSV()
        if BP and BP.UpdatePetWalkFloatButton then
            BP.UpdatePetWalkFloatButton()
        end
    end)
    xyBtn:SetScript("OnEnter", function(self)
        if not (GameTooltip and GameTooltip.SetOwner and GameTooltip.SetText) then
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if IsFloatPosAccountWideOutsideChar() then
            GameTooltip:SetText("XY: Account\nOSD position is saved account-wide.\nClick to switch to character positioning.")
        else
            GameTooltip:SetText("XY: Character\nOSD position is saved per character.\nClick to switch to account-wide positioning.")
        end
        GameTooltip:Show()
    end)
    xyBtn:SetScript("OnLeave", function()
        if GameTooltip and GameTooltip.Hide then
            GameTooltip:Hide()
        end
    end)

    splitOSDLock:RegisterForClicks("LeftButtonUp")
    splitOSDLock:SetScript("OnClick", function(self)
        InitSV()
        local ui = GetUI()
        if type(ui) ~= "table" then
            return
        end

        local clickLeft = true
        if GetCursorPosition and self and self.GetLeft and self.GetEffectiveScale and self.GetWidth then
            local x = GetCursorPosition()
            local scale = self:GetEffectiveScale() or 1
            x = x / scale
            local left = self:GetLeft() or 0
            local relX = x - left
            clickLeft = (relX <= (self:GetWidth() / 2))
        end

        if clickLeft then
            ui.petWalkFloatEnabled = not (ui.petWalkFloatEnabled and true or false)
        else
            ui.petWalkFloatLocked = not (ui.petWalkFloatLocked and true or false)
        end

        RefreshFromSV()
        if BP.UpdatePetWalkFloatButton then
            BP.UpdatePetWalkFloatButton()
        end
    end)

    sizeBox.eb:SetMaxLetters(2)
    sizeBox.eb:SetScript("OnTextChanged", function(self)
        if not self:HasFocus() then
            return
        end
        local t = SanitizeDigits(self:GetText())
        if t ~= self:GetText() then
            self:SetText(t)
            self:SetCursorPosition(#t)
        end
    end)
    sizeBox.eb:SetScript("OnEditFocusLost", function(self)
        InitSV()
        local ui = GetUI()
        if type(ui) ~= "table" then
            return
        end
        local n = tonumber(SanitizeDigits(self:GetText()))
        if type(n) ~= "number" then
            n = tonumber(ui.petWalkFloatTextSize) or 12
        end
        if n < 8 then n = 8 end
        if n > 24 then n = 24 end
        ui.petWalkFloatTextSize = n
        RefreshFromSV()
        if BP.UpdatePetWalkFloatButton then
            BP.UpdatePetWalkFloatButton()
        end
    end)

    p:SetScript("OnShow", function()
        local function HideOther(name)
            local f = _G and rawget(_G, name)
            if f and f.IsShown and f:IsShown() and f.Hide then
                f:Hide()
            end
        end

        -- Enforce: only one config popout open at a time.
        HideOther("FGO_MountUpConfigPopup")
        HideOther("FGO_ChromieConfigPopup")

        if p.RefreshFromSV then
            p.RefreshFromSV()
        end
    end)

    configPopup = p
    return configPopup
end

function BP.OpenPetWalkConfigPopup()
    local p = EnsureConfigPopup()
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
                p:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 8, 0)
            else
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

BP.GetPetWalkConfigPopupFrame = function()
    return configPopup or (_G and rawget(_G, "FGO_PetWalkConfigPopup"))
end

-- ============================================================================
-- Runtime loop
-- ============================================================================

do
    local f = CreateFrame("Frame")

    local lastMoving = false
    local movePollElapsed = 0
    local periodicElapsed = 0

    local function IsMoving()
        return (GetUnitSpeed and (GetUnitSpeed("player") or 0) > 0) and true or false
    end

    local function OnEvent(_, event)
        if event == "PLAYER_LOGIN" or event == "VARIABLES_LOADED" then
            InitSV()
            ScheduleSummon(event, 2.0)
            return
        end

        if event == "UPDATE_STEALTH" then
            MaybeDismissOnStealth()
            if IsEnabled() and (not (IsStealthed and IsStealthed())) then
                ScheduleSummon(event, GetDelay())
            end
            return
        end

        if event == "PLAYER_REGEN_ENABLED" then
            ScheduleSummon(event, GetDelay())
            return
        end

        if event == "PLAYER_CONTROL_GAINED" or event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_MOUNT_DISPLAY_CHANGED" or event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then
            ScheduleSummon(event, 2.0)
            return
        end

        if event == "PET_JOURNAL_LIST_UPDATE" then
            if IsEnabled() then
                ScheduleSummon(event, GetDelay())
            end
            return
        end
    end

    f:RegisterEvent("PLAYER_LOGIN")
    f:RegisterEvent("VARIABLES_LOADED")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("PLAYER_CONTROL_GAINED")
    f:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
    f:RegisterEvent("PLAYER_REGEN_ENABLED")
    f:RegisterEvent("PLAYER_ALIVE")
    f:RegisterEvent("PLAYER_UNGHOST")
    f:RegisterEvent("UPDATE_STEALTH")
    f:RegisterEvent("PET_JOURNAL_LIST_UPDATE")
    f:SetScript("OnEvent", OnEvent)

    f:SetScript("OnUpdate", function(_, elapsed)
        if not IsEnabled() then
            lastMoving = false
            movePollElapsed = 0
            periodicElapsed = 0
            return
        end

        elapsed = elapsed or 0
        movePollElapsed = movePollElapsed + elapsed
        periodicElapsed = periodicElapsed + elapsed

        if movePollElapsed >= 0.25 then
            movePollElapsed = 0
            local moving = IsMoving()
            if lastMoving and (not moving) then
                ScheduleSummon("move_stop", GetDelay())
            end
            lastMoving = moving
        end

        if periodicElapsed >= 4.0 then
            periodicElapsed = 0
            if not pendingTimer then
                -- If we're idle (not moving) and have no pet, try periodically.
                ScheduleSummon("periodic", GetDelay())
            end
        end
    end)
end
