local addonName, ns = ...
ns = ns or {}

local SANITY_VERSION = "260306-001"

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
    if print then
        print("|cff00ccff[FGO]|r " .. SafeToString(msg))
    end
end

-- Expose helpers for split-out modules.
ns.IsSecretString = IsSecretString
ns.SafeToString = SafeToString
local frame = CreateFrame("Frame")

-- Chromie Time was split out to fUI_GOSwitchesCT.lua
local InitSV
local function GetSwitchesCT()
    return ns and ns.SwitchesCT
end

local function SetupChromieSelectionTracking()
    local CT = GetSwitchesCT()
    if CT and CT.SetupChromieSelectionTracking then
        return CT.SetupChromieSelectionTracking()
    end
end

local function GetChromieTimeInfo()
    local CT = GetSwitchesCT()
    if CT and CT.GetChromieTimeInfo then
        return CT.GetChromieTimeInfo()
    end
    return false, nil, nil, false
end

local IsChromieTimeAvailableToPlayer = function()
    local CT = GetSwitchesCT()
    if CT and CT.IsChromieTimeAvailableToPlayer then
        return CT.IsChromieTimeAvailableToPlayer()
    end
    return false
end

local function TryDisableChromieTime()
    local CT = GetSwitchesCT()
    if CT and CT.TryDisableChromieTime then
        return CT.TryDisableChromieTime()
    end
    return false, "no-module"
end

local function GetChromieTimeDisplayText()
    local CT = GetSwitchesCT()
    if CT and CT.GetChromieTimeDisplayText then
        return CT.GetChromieTimeDisplayText()
    end
    return "Chromie Time\nN/A"
end

local UpdateChromieIndicator = function()
    local CT = GetSwitchesCT()
    if CT and CT.UpdateChromieIndicator then
        return CT.UpdateChromieIndicator()
    end
end

local EnsureChromieIndicator = function()
    local CT = GetSwitchesCT()
    if CT and CT.EnsureChromieIndicator then
        return CT.EnsureChromieIndicator()
    end
end

local function ForceHideChromieIndicator()
    local CT = GetSwitchesCT()
    if CT and CT.ForceHideChromieIndicator then
        return CT.ForceHideChromieIndicator()
    end
    local named = _G and rawget(_G, "FGO_ChromieIndicator")
    if named and named.Hide then
        named:Hide()
    end
end

local chromieConfigPopup
local function OpenChromieConfigPopup()
    local CT = GetSwitchesCT()
    if CT and CT.OpenChromieConfigPopup then
        return CT.OpenChromieConfigPopup()
    end
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

    -- Minimum number of gossip options required before the Print-on-show feature prints.
    -- Default 2 preserves the legacy behavior of skipping single-option NPCs.
    if type(AutoGossip_UI.printOnShowMinOptions) ~= "number" then
        AutoGossip_UI.printOnShowMinOptions = 2
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

    -- Floating Reload UI button (Switches)
    if type(AutoGossip_UI.reloadFloatEnabled) ~= "boolean" then
        AutoGossip_UI.reloadFloatEnabled = false
    end
    if type(AutoGossip_UI.reloadFloatTextSize) ~= "number" then
        AutoGossip_UI.reloadFloatTextSize = 12
    end
    if type(AutoGossip_UI.reloadFloatPos) ~= "table" then
        AutoGossip_UI.reloadFloatPos = { point = "TOP", relativePoint = "TOP", x = 0, y = -120 }
    end

    -- Floating Mount Up button (Mount Up popout)
    if type(AutoGossip_UI.mountUpFloatEnabled) ~= "boolean" then
        AutoGossip_UI.mountUpFloatEnabled = false
    end
    if type(AutoGossip_UI.mountUpFloatLocked) ~= "boolean" then
        AutoGossip_UI.mountUpFloatLocked = false
    end
    if type(AutoGossip_UI.mountUpFloatTextSize) ~= "number" then
        AutoGossip_UI.mountUpFloatTextSize = 12
    end
    if type(AutoGossip_UI.mountUpFloatPos) ~= "table" then
        AutoGossip_UI.mountUpFloatPos = { point = "TOP", relativePoint = "TOP", x = 0, y = -140 }
    end

    -- Mount Up float position mode: account-wide (outside Preferred Scope) by default.
    if type(AutoGossip_UI.mountUpFloatPosAccOutsideScope) ~= "boolean" then
        AutoGossip_UI.mountUpFloatPosAccOutsideScope = true
    end

    -- Pet Walk (battle pets)
    if type(AutoGossip_Settings.petWalkEnabledAcc) ~= "boolean" then
        AutoGossip_Settings.petWalkEnabledAcc = true
    end
    if type(AutoGossip_CharSettings.petWalkDisabledChar) ~= "boolean" then
        AutoGossip_CharSettings.petWalkDisabledChar = false
    end
    if type(AutoGossip_Settings.petWalkModeAcc) ~= "string" then
        AutoGossip_Settings.petWalkModeAcc = "random"
    end
    if type(AutoGossip_Settings.petWalkDelayAcc) ~= "number" then
        AutoGossip_Settings.petWalkDelayAcc = 1.0
    end
    if type(AutoGossip_Settings.petWalkDismissOnStealthAcc) ~= "boolean" then
        AutoGossip_Settings.petWalkDismissOnStealthAcc = true
    end

    -- Mount Up (auto mount)
    if type(AutoGossip_Settings.mountUpEnabledAcc) ~= "boolean" then
        -- Default ON (account): character must still enable via per-character flag.
        AutoGossip_Settings.mountUpEnabledAcc = true
    end
    -- Per-character gate. Default OFF (disabled) so it doesn't surprise on every toon.
    -- Migration: older builds used mountUpDisabledChar.
    if type(AutoGossip_CharSettings.mountUpEnabledChar) ~= "boolean" then
        if type(AutoGossip_CharSettings.mountUpDisabledChar) == "boolean" then
            AutoGossip_CharSettings.mountUpEnabledChar = not (AutoGossip_CharSettings.mountUpDisabledChar and true or false)
        else
            AutoGossip_CharSettings.mountUpEnabledChar = false
        end
    end
    if type(AutoGossip_Settings.mountUpModeAcc) ~= "string" then
        AutoGossip_Settings.mountUpModeAcc = "smart"
    end
    if type(AutoGossip_Settings.mountUpDelayAcc) ~= "number" then
        AutoGossip_Settings.mountUpDelayAcc = 1.0
    end
    -- Preferred mount per situation (always-smart picker): Flying/Ground/Water.
    if type(AutoGossip_Settings.mountUpPreferredMountIDFlyingAcc) ~= "number" then
        AutoGossip_Settings.mountUpPreferredMountIDFlyingAcc = 0
    end
    if type(AutoGossip_Settings.mountUpPreferredMountIDGroundAcc) ~= "number" then
        AutoGossip_Settings.mountUpPreferredMountIDGroundAcc = 0
    end
    if type(AutoGossip_Settings.mountUpPreferredMountIDAquaticAcc) ~= "number" then
        AutoGossip_Settings.mountUpPreferredMountIDAquaticAcc = 0
    end

    -- Mount Up preferred scope (profile) for preferred mounts (per-character selection).
    -- Scopes: faction/guild/class/race are account-wide stores; character is per-character.
    if type(AutoGossip_CharSettings.mountUpPreferredScope) ~= "string" then
        AutoGossip_CharSettings.mountUpPreferredScope = "character"
    end
    if type(AutoGossip_Settings.mountUpPreferredMountIDsScopes) ~= "table" then
        AutoGossip_Settings.mountUpPreferredMountIDsScopes = {}
    end
    if type(AutoGossip_CharSettings.mountUpPreferredMountIDsChar) ~= "table" then
        AutoGossip_CharSettings.mountUpPreferredMountIDsChar = {}
    end

    -- Legacy key (older builds) used a single preferred mount.
    if type(AutoGossip_Settings.mountUpPreferredMountIDAcc) ~= "number" then
        AutoGossip_Settings.mountUpPreferredMountIDAcc = 0
    end
    do
        local old = tonumber(AutoGossip_Settings.mountUpPreferredMountIDAcc) or 0
        if old > 0 then
            local anyNew = (tonumber(AutoGossip_Settings.mountUpPreferredMountIDFlyingAcc) or 0)
                + (tonumber(AutoGossip_Settings.mountUpPreferredMountIDGroundAcc) or 0)
                + (tonumber(AutoGossip_Settings.mountUpPreferredMountIDAquaticAcc) or 0)
            if anyNew == 0 then
                AutoGossip_Settings.mountUpPreferredMountIDGroundAcc = old
            end
        end
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

    if type(AutoGossip_Settings.autoAcceptTalkUpConfirmAcc) ~= "boolean" then
        -- Default ON: used for talk rules that explicitly opt into confirmation popups (e.g. "Are you sure? This Action cannot be undone.").
        AutoGossip_Settings.autoAcceptTalkUpConfirmAcc = true
    end

    -- Legacy compat: older builds used this name for the Whitemane skip confirm.
    -- If it's present and false, honor it by disabling the generic feature too.
    if AutoGossip_Settings.autoAcceptWhitemaneSkipAcc == false then
        AutoGossip_Settings.autoAcceptTalkUpConfirmAcc = false
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

-- Expose a couple of internals so helper modules (e.g. TalkUP) can share SV init + printing.
ns._InitSV = InitSV
ns._Print = Print

-- Professions/skill-tier cache moved to fUI_GOSituatePF.lua

-- Popup handling moved to fUI_GOTalkUP.lua

-- Queue accept overlay moved to fUI_GOSwitchesQA.lua
local function GetSwitchesQA()
    return ns and ns.SwitchesQA
end

local function GetQueueAcceptState()
    local QA = GetSwitchesQA()
    if QA and QA.GetQueueAcceptState then
        return QA.GetQueueAcceptState()
    end
    return "off"
end

local function SetQueueAcceptState(state)
    local QA = GetSwitchesQA()
    if QA and QA.SetQueueAcceptState then
        return QA.SetQueueAcceptState(state)
    end
end

local function IsQueueAcceptEnabled()
    local QA = GetSwitchesQA()
    if QA and QA.IsQueueAcceptEnabled then
        return QA.IsQueueAcceptEnabled()
    end
    return GetQueueAcceptState() ~= "off"
end

HideQueueOverlay = function()
    local QA = GetSwitchesQA()
    if QA and QA.HideQueueOverlay then
        return QA.HideQueueOverlay()
    end
end

local function ShowQueueOverlayIfNeeded()
    local QA = GetSwitchesQA()
    if QA and QA.ShowQueueOverlayIfNeeded then
        return QA.ShowQueueOverlayIfNeeded()
    end
end

local function GetNpcIDFromGuid(guid)
    if type(guid) ~= "string" then
        return nil
    end
    if IsSecretString(guid) then
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

-- Expose core gossip helpers for split-out modules.
ns.GetCurrentNpcID = GetCurrentNpcID
ns.GetCurrentNpcName = GetCurrentNpcName
ns.CloseGossipWindow = CloseGossipWindow
ns.GetCurrentZoneName = GetCurrentZoneName
ns.GetCurrentContinentName = GetCurrentContinentName

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

-- Expose disable helpers (used by gossip engine module).
ns.IsDisabled = IsDisabled
ns.IsDisabledAccOnChar = IsDisabledAccOnChar
ns.IsDisabledDB = IsDisabledDB
ns.IsDisabledDBOnChar = IsDisabledDBOnChar

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

-- Helpers (Talk tab -> Draenor -> Garrison)
local GARRISON_MISSION_TABLE_HELPER_NPC_ID = -32000
local GARRISON_MISSION_TABLE_HELPER_OPTION_ID = 1

local function PlayerIsOnQuestID(questID)
    questID = tonumber(questID)
    if not questID then return false end
    if C_QuestLog and type(C_QuestLog.IsOnQuest) == "function" then
        local ok, on = pcall(C_QuestLog.IsOnQuest, questID)
        return ok and on and true or false
    end
    -- Fallbacks for edge timing / API inconsistencies.
    if C_QuestLog and type(C_QuestLog.GetLogIndexForQuestID) == "function" then
        local ok, idx = pcall(C_QuestLog.GetLogIndexForQuestID, questID)
        if ok and type(idx) == "number" and idx > 0 then
            return true
        end
    end
    if type(GetQuestLogIndexByID) == "function" then
        local ok, idx = pcall(GetQuestLogIndexByID, questID)
        if ok and type(idx) == "number" and idx > 0 then
            return true
        end
    end
    return false
end

local function QuestIsCompleted(questID)
    questID = tonumber(questID)
    if not questID then
        return false
    end

    if C_QuestLog and type(C_QuestLog.IsQuestFlaggedCompleted) == "function" then
        local ok, done = pcall(C_QuestLog.IsQuestFlaggedCompleted, questID)
        return ok and done and true or false
    end

    if type(IsQuestFlaggedCompleted) == "function" then
        local ok, done = pcall(IsQuestFlaggedCompleted, questID)
        return ok and done and true or false
    end

    return false
end

local function QuestReadyForTurnIn(questID)
    questID = tonumber(questID)
    if not questID then
        return false
    end

    if C_QuestLog and type(C_QuestLog.ReadyForTurnIn) == "function" then
        local ok, ready = pcall(C_QuestLog.ReadyForTurnIn, questID)
        return ok and ready and true or false
    end

    return false
end

-- Forward declarations.
local GetDbNpcTable
local LookupNpcBucket

local function MaybeAutoStartFirstGarrisonMissionTableQuest()
    -- Gate behind Talk-tab toggle (DB rule disable) so it appears in the list like normal gossip entries.
    if IsDisabledDB(GARRISON_MISSION_TABLE_HELPER_NPC_ID, GARRISON_MISSION_TABLE_HELPER_OPTION_ID) then
        return
    end
    if IsDisabledDBOnChar(GARRISON_MISSION_TABLE_HELPER_NPC_ID, GARRISON_MISSION_TABLE_HELPER_OPTION_ID) then
        return
    end

    if not (C_Garrison and type(C_Garrison.GetGarrisonInfo) == "function") then
        return
    end

    InitSV()
    AutoGossip_CharSettings = AutoGossip_CharSettings or {}
    if AutoGossip_CharSettings.isFirstGarrisonMissionSent then
        return
    end

    local garrisonLevel = C_Garrison.GetGarrisonInfo(2)
    if garrisonLevel ~= 1 then
        return
    end

    local faction = UnitFactionGroup and UnitFactionGroup("player") or nil
    local questID
    if faction == "Alliance" then
        questID = 34775
    elseif faction == "Horde" then
        questID = 34692
    end
    if not questID or not PlayerIsOnQuestID(questID) then
        return
    end

    local function DoIt()
        if GarrisonMissionTutorialFrame and GarrisonMissionTutorialFrame.Hide then
            pcall(GarrisonMissionTutorialFrame.Hide, GarrisonMissionTutorialFrame)
        end

        if not (C_Garrison and type(C_Garrison.GetAvailableMissions) == "function" and type(C_Garrison.GetFollowers) == "function") then
            return
        end
        local missions = C_Garrison.GetAvailableMissions(1) or {}
        local followers = C_Garrison.GetFollowers(1) or {}
        if type(missions) ~= "table" or type(followers) ~= "table" then
            return
        end
        if #followers == 0 then
            return
        end

        local followerID = followers[1] and followers[1].followerID or nil
        if not followerID then
            return
        end

        for _, mission in pairs(missions) do
            if type(mission) == "table" and not mission.inProgress and mission.missionID then
                if type(C_Garrison.AddFollowerToMission) == "function" then
                    pcall(C_Garrison.AddFollowerToMission, mission.missionID, followerID)
                end
                if type(C_Garrison.StartMission) == "function" then
                    pcall(C_Garrison.StartMission, mission.missionID)
                end
                if type(C_Garrison.CloseMissionNPC) == "function" then
                    pcall(C_Garrison.CloseMissionNPC)
                end
                if type(HideUIPanel) == "function" and _G.GarrisonMissionFrame then
                    pcall(HideUIPanel, _G.GarrisonMissionFrame)
                end

                AutoGossip_CharSettings.isFirstGarrisonMissionSent = true
                break
            end
        end
    end

    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(0.5, DoIt)
    else
        DoIt()
    end
end

GetDbNpcTable = function(npcID)
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

-- Expose rule presence helpers for split-out modules.
ns.HasDbRule = HasDbRule
ns.HasRule = HasRule

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

ns.LookupRuleEntry = LookupRuleEntry

LookupNpcBucket = function(db, npcID)
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

ns.LookupNpcBucket = LookupNpcBucket

-- Gossip engine moved into fUI_GOTalk.lua (ns.Talk.*). Keep thin delegates here for event wiring.
local function TryAutoSelect()
    local Talk = ns and ns.Talk
    if Talk and type(Talk.TryAutoSelect) == "function" then
        return Talk.TryAutoSelect()
    end
    return false, "no-module"
end

local function ScheduleGossipRetry()
    local Talk = ns and ns.Talk
    if Talk and type(Talk.ScheduleGossipRetry) == "function" then
        return Talk.ScheduleGossipRetry()
    end
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

    local texturesPanel = CreateFrame("Frame", nil, f)
    texturesPanel:SetAllPoints()
    texturesPanel:Hide()
    f.texturesPanel = texturesPanel

    local editPanel = CreateFrame("Frame", nil, f)
    editPanel:SetAllPoints()
    editPanel:Hide()
    f.editPanel = editPanel

    local togglesPanel = CreateFrame("Frame", nil, f)
    togglesPanel:SetAllPoints()
    togglesPanel:Hide()
    f.togglesPanel = togglesPanel

    local tabardPanel = CreateFrame("Frame", nil, f)
    tabardPanel:SetAllPoints()
    tabardPanel:Hide()
    f.tabardPanel = tabardPanel

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

    local TAB_COUNT = 8
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
        -- Tab order: 1 Macro, 2 Macro CMD, 3 Situate, 4 Switches, 5 Tabard, 6 Tale, 7 Talk, 8 Textures
        if f.macrosPanel then f.macrosPanel:SetShown(tabID == 1) end
        if f.macroPanel then f.macroPanel:SetShown(tabID == 2) end
        if f.actionBarPanel then f.actionBarPanel:SetShown(tabID == 3) end
        if f.togglesPanel then f.togglesPanel:SetShown(tabID == 4) end
        if f.tabardPanel then f.tabardPanel:SetShown(tabID == 5) end
        if f.editPanel then f.editPanel:SetShown(tabID == 6) end
        if f.browserPanel then f.browserPanel:SetShown(tabID == 7) end
        if f.texturesPanel then f.texturesPanel:SetShown(tabID == 8) end

        if tabID == 2 and f.UpdateMacroButtons then
            f.UpdateMacroButtons()
        end
        if tabID == 3 and f.UpdateSituateButtons then
            f.UpdateSituateButtons()
        end
        if tabID == 4 and f.UpdateToggleButtons then
            f.UpdateToggleButtons()
        end
        if tabID == 8 and f.UpdateTexturesUI then
            f.UpdateTexturesUI()
        end

        StyleTab(f.tab1, tabID == 1)
        StyleTab(f.tab2, tabID == 2)
        StyleTab(f.tab3, tabID == 3)
        StyleTab(f.tab4, tabID == 4)
        StyleTab(f.tab5, tabID == 5)
        StyleTab(f.tab6, tabID == 6)
        StyleTab(f.tab7, tabID == 7)
        StyleTab(f.tab8, tabID == 8)

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
    tab5:SetText("Tabard")
    tab5:SetPoint("LEFT", tab4, "RIGHT", TAB_OVERLAP_X, 0)
    tab5:SetScript("OnClick", function(self) f:SelectTab(self:GetID()) end)
    tab5:SetHeight(22)
    SizeTabToText(tab5, 18, 70)
    f.tab5 = tab5

    local tab6 = CreateFrame("Button", "$parentTab6", f, "UIPanelButtonTemplate")
    tab6:SetID(6)
    tab6:SetText("Tale")
    tab6:SetPoint("LEFT", tab5, "RIGHT", TAB_OVERLAP_X, 0)
    tab6:SetScript("OnClick", function(self) f:SelectTab(self:GetID()) end)
    tab6:SetHeight(22)
    SizeTabToText(tab6, 18, 70)
    f.tab6 = tab6

    local tab7 = CreateFrame("Button", "$parentTab7", f, "UIPanelButtonTemplate")
    tab7:SetID(7)
    tab7:SetText("Talk")
    tab7:SetPoint("LEFT", tab6, "RIGHT", TAB_OVERLAP_X, 0)
    tab7:SetScript("OnClick", function(self) f:SelectTab(self:GetID()) end)
    tab7:SetHeight(22)
    SizeTabToText(tab7, 18, 70)
    f.tab7 = tab7

    local tab8 = CreateFrame("Button", "$parentTab8", f, "UIPanelButtonTemplate")
    tab8:SetID(8)
    tab8:SetText("Textures")
    tab8:SetPoint("LEFT", tab7, "RIGHT", TAB_OVERLAP_X, 0)
    tab8:SetScript("OnClick", function(self) f:SelectTab(self:GetID()) end)
    tab8:SetHeight(22)
    SizeTabToText(tab8, 18, 70)
    f.tab8 = tab8

    -- Initialize first tab styling + z-order.
    StyleTab(tab1, true)
    StyleTab(tab2, false)
    StyleTab(tab3, false)
    StyleTab(tab4, false)
    StyleTab(tab5, false)
    StyleTab(tab6, false)
    StyleTab(tab7, false)
    StyleTab(tab8, false)
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

        local mu = (_G and rawget(_G, "FGO_MountUpConfigPopup"))
        if mu and mu.Hide then
            mu:Hide()
        end

        local pw = (_G and rawget(_G, "FGO_PetWalkConfigPopup"))
        if pw and pw.Hide then
            pw:Hide()
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

    -- Tabard tab content
    do
        local panel = tabardPanel
        local tabard = _G and rawget(_G, "fr0z3nUI_GameOptionsTabard")
        if panel and tabard and type(tabard.BuildTab) == "function" then
            tabard.BuildTab(panel, {
                EnsureDB = function() InitSV() end,
                GetDB = function() return AutoGossip_Settings end,
                GetCharDB = function() return AutoGossip_CharSettings end,
                Clamp = function(v, minV, maxV)
                    v = tonumber(v) or 0
                    minV = tonumber(minV)
                    maxV = tonumber(maxV)
                    if minV and v < minV then v = minV end
                    if maxV and v > maxV then v = maxV end
                    return v
                end,
                SetCheckBoxText = function(cb, text)
                    if cb and cb.Text and cb.Text.SetText then
                        cb.Text:SetText(text)
                    end
                end,
            })
        end
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

    -- Textures tab content
    do
        local panel = f.texturesPanel
        if panel and ns and ns.TexturesUI_Build then
            local UpdateUI = function() end
            UpdateUI = ns.TexturesUI_Build(f, panel, {
                InitSV = InitSV,
                Print = Print,
            }) or UpdateUI
            f.UpdateTexturesUI = function()
                UpdateUI()
            end
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
                    GetChromieConfigPopupFrame = (ns and ns.SwitchesCT and ns.SwitchesCT.GetChromieConfigPopupFrame) or nil,
                    EnsureReloadFloatButton = ns and ns.EnsureReloadFloatButton,
                    UpdateReloadFloatButton = ns and ns.UpdateReloadFloatButton,
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
            AutoGossipOptions:SelectTab(6)
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

local function PrintCurrentOptions(debounce)
    local Talk = ns and ns.Talk
    if Talk and type(Talk.PrintCurrentOptions) == "function" then
        return Talk.PrintCurrentOptions(debounce)
    end
end

local function PrintDebugOptionsOnShow(skipOptionLines)
    local Talk = ns and ns.Talk
    if Talk and type(Talk.PrintDebugOptionsOnShow) == "function" then
        return Talk.PrintDebugOptionsOnShow(skipOptionLines)
    end
end

SLASH_FROZENGAMEOPTIONS1 = "/fgo"
---@diagnostic disable-next-line: duplicate-set-field
SlashCmdList["FROZENGAMEOPTIONS"] = function(msg)
    if IsSecretString(msg) then
        return
    end
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
                "/fgo hs loc                - print your home zone + continent",
                "/fgo hs garrison           - garrison hearth status",
                "/fgo hs dalaran            - dalaran hearth status",
                "/fgo hs dornogal           - dornogal portal status",
                "/fgo hs arcantina          - arcantina hearth status",
                "/fgo hs whistle            - delve whistle status",
                "",
                "/fgo script                - toggle ScriptErrors",
                "/fgo loot                  - toggle Auto Loot",
                "/fgo mouse                 - toggle Loot Under Mouse",
                    "/fgo clickmove             - toggle Click2Move (autointeract)",
                "/fgo mountequip            - warn if mount equipment slot empty",
                "/fgo mu acc               - toggle Mount Up (Account)",
                "/fgo mu on                - enable Mount Up (Character)",
                "/fgo mu son               - enable Mount Up (Character, silent)",
                "/fgo mu off               - disable Mount Up (Character)",
                "/fgo mu soff              - disable Mount Up (Character, silent)",
                "/fgo mu sw                - toggle Mount Up (Character)",
                "/fgo mountupon            - alias for /fgo mu on",
                "/fgo mountupoff           - alias for /fgo mu off",
                "/fgo vault                 - toggle Great Vault window",
                "/fgo trade                 - toggle Block Trades",
                "/fgo friend                - toggle Friendly Names",
                "/fgo bars                  - toggle ActionBar Lock",
                "/fgo situate b50            - force-apply Situate for slot 50",
                "/fgo bagrev                - toggle Bag Sort Reverse",
                    "/fgo sharpen               - toggle always sharpen (ResampleAlwaysSharpen)",
                    "/fgo whispin               - set whispers to inline (whisperMode)",
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

        -- Textures module maintenance commands.
        -- Keeps UI opening on plain /fgo, but allows /fgo textures migrate reset, etc.
        if cmd == "textures" or cmd == "texture" then
            if ns and ns.Textures and type(ns.Textures.HandleSlash) == "function" then
                ns.Textures.HandleSlash(rest)
            else
                Print("Textures module not loaded.")
            end
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
                ["sharpen"] = true,
                ["whispin"] = true,
                ["mountequip"] = true,
                ["mu"] = true,
                ["mountup"] = true,
                ["mountupon"] = true,
                ["mountupoff"] = true,
                ["mountupconfig"] = true,
                ["chromie"] = true,
                ["chromietime"] = true,
                ["ct"] = true,
                ["ctoff"] = true,

                -- Macro CMD keys that would otherwise be mis-parsed as mode glue.
                -- Example: /fgo mouse would become /fgo m ouse without this.
                ["mouse"] = true,
                ["clickmove"] = true,
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
                Print("Sanity: " .. tostring(SANITY_VERSION))
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

        if cmd == "situate" then
            local a = (rest or ""):match("^(%S+)") or ""
            a = (a or ""):gsub("^%s+", ""):gsub("%s+$", "")
            if a == "" then
                Print("Usage: /fgo situate b50")
                return
            end

            local slot = nil
            local low = a:lower()
            if low:sub(1, 1) == "b" then
                slot = tonumber(low:sub(2))
            else
                slot = tonumber(low)
            end

            if not slot then
                Print("Usage: /fgo situate b50")
                return
            end

            if not (ns and type(ns.ActionBar_ApplySlotNow) == "function") then
                Print("Situate module not loaded.")
                return
            end

            local ok = ns.ActionBar_ApplySlotNow(slot, true)
            if ok then
                Print("Situate: applied slot " .. tostring(slot))
            else
                Print("Situate: invalid slot (1-180)")
            end
            return
        end

        if cmd == "mountequip" then
            if not (C_MountJournal and type(C_MountJournal.GetAppliedMountEquipmentID) == "function") then
                return
            end
            local id = C_MountJournal.GetAppliedMountEquipmentID()
            if not id or tonumber(id) == 0 then
                local msg = "WARNING: Mount equipment slot is EMPTY!"
                if WrapTextInColorCode then
                    msg = WrapTextInColorCode(msg, "ffff8000")
                end
                Print(msg)
            end
            return
        end

        if cmd == "mu" then
            InitSV()

            local sub, subarg = (rest or ""):match("^(%S*)%s*(.-)$")
            sub = (sub or ""):lower()
            subarg = (subarg or ""):lower()

            local function MU_SettingsChanged()
                if ns and ns.SwitchesMU and ns.SwitchesMU.OnSettingsChanged then
                    ns.SwitchesMU.OnSettingsChanged()
                end
            end

            local function MU_PrintAcc()
                local onAcc = (AutoGossip_Settings.mountUpEnabledAcc and true or false)
                Print("|cff00ccffMount Up|r: " .. (onAcc and "ON" or "OFF") .. " ACC")
            end

            local function MU_PrintChar()
                local onChar = (AutoGossip_CharSettings.mountUpEnabledChar and true or false)
                local status = onChar and "Enabled" or "Disabled"
                if WrapTextInColorCode then
                    if onChar then
                        status = WrapTextInColorCode(status, "ff00ff00")
                    else
                        status = WrapTextInColorCode(status, "ffff8000")
                    end
                end
                Print("|cff00ccffMount Up|r " .. status)
            end

            if sub == "" then
                Print("Usage: /fgo mu acc|on|son|off|soff|sw|types|mounted|preferred")
                return
            end

            if sub == "types" then
                if ns and ns.SwitchesMU and ns.SwitchesMU.DebugDumpMountTypes then
                    ns.SwitchesMU.DebugDumpMountTypes()
                end
                return
            end

            if sub == "mounted" then
                if ns and ns.SwitchesMU and ns.SwitchesMU.DebugPrintMountedMountType then
                    ns.SwitchesMU.DebugPrintMountedMountType()
                end
                return
            end

            if sub == "preferred" then
                if ns and ns.SwitchesMU and ns.SwitchesMU.DebugPrintPreferredMounts then
                    ns.SwitchesMU.DebugPrintPreferredMounts()
                end
                return
            end

            if sub == "acc" then
                AutoGossip_Settings.mountUpEnabledAcc = not (AutoGossip_Settings.mountUpEnabledAcc and true or false)
                MU_PrintAcc()
                MU_SettingsChanged()
                return
            end

            if sub == "on" or sub == "son" then
                AutoGossip_CharSettings.mountUpEnabledChar = true
                if sub == "on" then
                    MU_PrintChar()
                end
                MU_SettingsChanged()
                return
            end

            if sub == "off" or sub == "soff" then
                AutoGossip_CharSettings.mountUpEnabledChar = false
                if sub == "off" then
                    MU_PrintChar()
                end
                MU_SettingsChanged()
                return
            end

            if sub == "sw" then
                AutoGossip_CharSettings.mountUpEnabledChar = not (AutoGossip_CharSettings.mountUpEnabledChar and true or false)
                MU_PrintChar()
                MU_SettingsChanged()
                return
            end

            Print("Usage: /fgo mu acc|on|son|off|soff|sw|types|mounted|preferred")
            return
        end

        if cmd == "mountup" or cmd == "mountupon" or cmd == "mountupoff" or cmd == "mountupconfig" then
            InitSV()

            local function MU_SettingsChanged()
                if ns and ns.SwitchesMU and ns.SwitchesMU.OnSettingsChanged then
                    ns.SwitchesMU.OnSettingsChanged()
                end
            end

            if cmd == "mountupconfig" then
                Print("Mount Up: use the Config button in /fgo (Switches tab).")
                return
            end

            -- Back-compat:
            --  /fgo mountup    -> /fgo mu acc
            --  /fgo mountupon  -> /fgo mu on
            --  /fgo mountupoff -> /fgo mu off
            if cmd == "mountup" then
                AutoGossip_Settings.mountUpEnabledAcc = not (AutoGossip_Settings.mountUpEnabledAcc and true or false)
                local on = (AutoGossip_Settings.mountUpEnabledAcc and true or false)
                Print("Mount Up: " .. (on and "ON" or "OFF") .. " ACC")
                MU_SettingsChanged()
                return
            end

            if cmd == "mountupon" then
                AutoGossip_CharSettings.mountUpEnabledChar = true
                MU_PrintChar()
                MU_SettingsChanged()
                return
            end

            if cmd == "mountupoff" then
                AutoGossip_CharSettings.mountUpEnabledChar = false
                MU_PrintChar()
                MU_SettingsChanged()
                return
            end
            return
        end

        if cmd == "vault" then
            local loadOk = false
            if C_AddOns and type(C_AddOns.LoadAddOn) == "function" then
                loadOk = pcall(C_AddOns.LoadAddOn, "Blizzard_WeeklyRewards")
            elseif type(LoadAddOn) == "function" then
                loadOk = pcall(LoadAddOn, "Blizzard_WeeklyRewards")
            end

            local f = _G and _G["WeeklyRewardsFrame"]
            if not (loadOk and f) then
                -- Silent on failure (e.g., UI blocked / missing frame).
                return
            end

            if f.IsShown and f:IsShown() then
                if HideUIPanel then
                    HideUIPanel(f)
                elseif f.Hide then
                    f:Hide()
                end
            else
                if ShowUIPanel then
                    ShowUIPanel(f)
                elseif f.Show then
                    f:Show()
                end
            end
            return
        end

        if cmd == "clickmove" then
            ToggleCVar("autointeract", "Click2Move")
            return
        end

        if cmd == "sharpen" then
            local o = false
            if GetCVarBool then
                o = GetCVarBool("ResampleAlwaysSharpen") and true or false
            elseif GetCVar then
                o = tostring(GetCVar("ResampleAlwaysSharpen") or "0") == "1"
            elseif C_CVar and C_CVar.GetCVar then
                o = tostring(C_CVar.GetCVar("ResampleAlwaysSharpen") or "0") == "1"
            end

            SetCVarSafe("ResampleAlwaysSharpen", o and "0" or "1")
            Print("Sharper " .. (o and "Off" or "On"))
            return
        end

        if cmd == "whispin" then
            SetCVarSafe("whisperMode", "inline")
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

            if dest == "arcantina" then
                PrintHSMessage(253629, "Arcantina Time!", "Arcantina Time in %d mins")
                return
            end

            if dest == "loc" or dest == "location" then
                -- Mirror legacy macro behavior: /run HearthZone:GetZone()
                if _G.HearthZone and type(_G.HearthZone.GetZone) == "function" then
                    _G.HearthZone:GetZone()
                    return
                end
                if ns and ns.Hearth and type(ns.Hearth.GetHomeZoneContinentText) == "function" then
                    local txt = tostring(ns.Hearth.GetHomeZoneContinentText() or "")
                    if txt ~= "" then
                        Print("|cFFFFD707Home Set To |r" .. txt)
                    end
                end
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

            Print("Usage: /fgo hs hearth|loc|garrison|dalaran|dornogal|arcantina|whistle")
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
        PrintCurrentOptions(false)
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
    Print("/fgo clickmove - toggle Click2Move")
    Print("/fgo mountequip - warn if mount equipment slot empty")
    Print("/fgo mu ...    - Mount Up (auto mount) controls")
    Print("/fgo vault     - toggle Great Vault window")
    Print("/fgo trade     - toggle Block Trades")
    Print("/fgo friend    - toggle Friendly Names")
    Print("/fgo bars      - toggle ActionBar Lock")
    Print("/fgo bagrev    - toggle Bag Sort Reverse")
    Print("/fgo sharpen   - toggle always sharpen")
    Print("/fgo whispin   - set whispers to inline")
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
frame:RegisterEvent("SKILL_LINES_CHANGED")
frame:RegisterEvent("TRADE_SKILL_SHOW")
frame:RegisterEvent("TRADE_SKILL_DATA_SOURCE_CHANGED")
frame:RegisterEvent("TRADE_SKILL_LIST_UPDATE")
frame:RegisterEvent("PLAYER_LEVEL_UP")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("QUEST_LOG_UPDATE")
frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        InitSV()
        firstAutoSelectSinceLogin = true
        SetupChromieSelectionTracking()
        DeduplicateUserRulesAgainstDb()

        if ns.Profs and ns.Profs.RefreshTrackedSkillTiers then
            ns.Profs.RefreshTrackedSkillTiers(true)
        end

        do
            local tabard = _G and rawget(_G, "fr0z3nUI_GameOptionsTabard")
            if tabard and type(tabard.Init) == "function" then
                pcall(tabard.Init, AutoGossip_Settings, AutoGossip_CharSettings)
            end
        end

        -- Macro CMD: pre-arm secure /click buttons so user macros work without a prep step.
        if ns and type(ns.MacroXCMD_ArmAllClickButtons) == "function" then
            pcall(ns.MacroXCMD_ArmAllClickButtons)
        end
        local talkUP = ns and ns.TalkUP or nil
        if talkUP and type(talkUP.Setup) == "function" then
            talkUP.Setup()
        end

        if (AutoGossip_UI and AutoGossip_UI.chromieFrameEnabled) and IsChromieTimeAvailableToPlayer() then
            EnsureChromieIndicator()
            UpdateChromieIndicator()
        else
            ForceHideChromieIndicator()
        end
        return
    end

    if event == "SKILL_LINES_CHANGED" or event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_DATA_SOURCE_CHANGED" or event == "TRADE_SKILL_LIST_UPDATE" then
        if ns.Profs and ns.Profs.RefreshTrackedSkillTiers then
            ns.Profs.RefreshTrackedSkillTiers(false)
        end
        return
    end

    if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_LEVEL_UP" or event == "ZONE_CHANGED_NEW_AREA" then
        InitSV()
        SetupChromieSelectionTracking()

        if event == "PLAYER_ENTERING_WORLD" then
            firstAutoSelectSinceLogin = true
        end

        if event == "PLAYER_ENTERING_WORLD" then
            if ns.Profs and ns.Profs.RefreshTrackedSkillTiers then
                ns.Profs.RefreshTrackedSkillTiers(true)
            end
        end

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
        local talkUP = ns and ns.TalkUP or nil
        if talkUP and type(talkUP.OnPetBattleOpeningStart) == "function" then
            talkUP.OnPetBattleOpeningStart()
        end
        return
    end
    if event == "PET_BATTLE_CLOSE" then
        local talkUP = ns and ns.TalkUP or nil
        if talkUP and type(talkUP.OnPetBattleClose) == "function" then
            talkUP.OnPetBattleClose()
        end
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        InitSV()

        -- Macro CMD: if secure button arming was blocked in combat, retry now.
        if ns and type(ns.MacroXCMD_ArmAllClickButtons) == "function" then
            pcall(ns.MacroXCMD_ArmAllClickButtons)
        end
        local QA = GetSwitchesQA()
        if QA and QA.OnPlayerRegenEnabled then
            QA.OnPlayerRegenEnabled()
        else
            ShowQueueOverlayIfNeeded()
        end
        return
    end

    if event == "LFG_PROPOSAL_SHOW" then
        local QA = GetSwitchesQA()
        if QA and QA.OnLfgProposalShow then
            QA.OnLfgProposalShow()
        else
            InitSV()
            ShowQueueOverlayIfNeeded()
        end
        return
    end

    if event == "LFG_PROPOSAL_UPDATE" then
        local QA = GetSwitchesQA()
        if QA and QA.OnLfgProposalUpdate then
            QA.OnLfgProposalUpdate()
        else
            InitSV()
            ShowQueueOverlayIfNeeded()
        end
        return
    end
    if event == "LFG_PROPOSAL_FAILED" or event == "LFG_PROPOSAL_SUCCEEDED" then
        local QA = GetSwitchesQA()
        if QA and QA.OnLfgProposalEnded then
            QA.OnLfgProposalEnded()
        else
            HideQueueOverlay()
        end
        return
    end

    if event == "GOSSIP_SHOW" or event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
        if event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
            -- Only run gossip auto-select for interaction types that actually present gossip options.
            -- If enums aren't available (older clients), keep legacy behavior.
            local it = arg1
            if type(it) == "number" and type(Enum) == "table" and type(Enum.PlayerInteractionType) == "table" then
                local t = Enum.PlayerInteractionType
                local isGossip = (t.Gossip ~= nil and it == t.Gossip)
                local isQuest = (t.QuestGiver ~= nil and it == t.QuestGiver)
                local isGarrisonMission = false
                if t.GarrisonMissionNPC ~= nil or t.GarrisonMission ~= nil then
                    isGarrisonMission = (t.GarrisonMissionNPC ~= nil and it == t.GarrisonMissionNPC)
                        or (t.GarrisonMission ~= nil and it == t.GarrisonMission)
                else
                    -- Numeric fallback only when enum is missing.
                    isGarrisonMission = (it == 32)
                end

                if not (isGossip or isQuest) then
                    if isGarrisonMission then
                        pcall(MaybeAutoStartFirstGarrisonMissionTableQuest)
                    end
                    return
                end
            end
        end
        InitSV()

        -- Per-gossip-open session stamp (used by DB packs to memoize stable answers
        -- within a single show, without leaking across manual close/re-open).
        if ns then
            ns.GossipSession = (tonumber(ns.GossipSession) or 0) + 1
        end

        local debugOn = (AutoGossip_Settings and AutoGossip_Settings.debugAcc) and true or false
        local printOnShow = (AutoGossip_UI and AutoGossip_UI.printOnShow) and true or false

        -- Printing behavior:
        -- - Debug mode already provides detailed "Gossip:" traces via TryAutoSelect.
        -- - Print-on-show is for rule-building (green highlighting + location).
        -- To avoid duplicate OID lines, only print one list when both toggles are enabled.
        if debugOn then
            PrintDebugOptionsOnShow(printOnShow)
        end
        if printOnShow then
            PrintCurrentOptions(true)
        end

        if AutoGossipOptions and AutoGossipOptions:IsShown() and AutoGossipOptions.UpdateFromInput then
            AutoGossipOptions:UpdateFromInput()
        end
        if AutoGossipOptions and AutoGossipOptions:IsShown() and AutoGossipOptions.RefreshOptionsList then
            AutoGossipOptions:RefreshOptionsList()
        end
        -- Pre-arm gossip engine state so first-run doesn’t fail on nil timestamps.
        do
            local Talk = ns and ns.Talk
            if Talk and type(Talk.EnsureEngineInitialized) == "function" then
                pcall(Talk.EnsureEngineInitialized)
            end
        end

        local ok, why
        do
            local callOk, a, b = pcall(TryAutoSelect)
            if callOk then
                ok, why = a, b
            else
                ok, why = false, "error"
                if debugOn then
                    Print("Gossip: TryAutoSelect ERROR: " .. SafeToString(a))
                end
            end
        end
        if debugOn then
            Print("Gossip: TryAutoSelect => ok=" .. tostring(ok and true or false) .. " why=" .. tostring(why))
        end
        -- Sometimes gossip data isn't ready on the first frame (empty options / missing NPC ID).
        -- Retry very shortly so auto-select works without requiring the user to toggle the UI.
        if not ok and (why == "no-npc" or why == "no-options" or why == "no-api") then
            ScheduleGossipRetry()
        end

    end
end)
