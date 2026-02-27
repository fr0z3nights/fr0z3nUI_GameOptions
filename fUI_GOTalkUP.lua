---@diagnostic disable: undefined-global

local addonName, ns = ...
if type(ns) ~= "table" then
    ns = {}
end

-- TalkUP helpers (StaticPopup hooks).
-- Renamed from fr0z3nUI_GameOptionsPopup.lua / fUI_GOTalkXPOP.lua.

ns.TalkUP = ns.TalkUP or {}

local M = ns.TalkUP

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


local function TryAutoConfirmSelectedRulePopup(which, text_arg1, text_arg2, dialogText)
    InitSV()

    local dbg = AutoGossip_Settings and AutoGossip_Settings.debugPetPopupsAcc
    local function D(msg)
        if dbg then
            Print("TalkUP: " .. tostring(msg))
        end
    end

    -- Safety: only auto-confirm known gossip-ish confirmations.
    -- (Do NOT accept arbitrary popups by default.)
    local whichStr = tostring(which or "")
    if whichStr ~= "GOSSIP_CONFIRM" and whichStr ~= "CONFIRM_BINDER" then
        D("Skip popup (which=" .. whichStr .. ")")
        return
    end
    if not AutoGossip_Settings then return end

    local function GetNpcIDFromGuid(guid)
        if type(guid) ~= "string" then
            return nil
        end
        if IsSecretString and IsSecretString(guid) then
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

    local norm = text:gsub("’", "'"):lower()

    local function containsAll(list)
        if type(list) ~= "table" or #list == 0 then return true end
        for i = 1, #list do
            local needle = tostring(list[i] or "")
            if needle ~= "" then
                if norm:find(needle:gsub("’", "'"):lower(), 1, true) == nil then
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
                if norm:find(needle:gsub("’", "'"):lower(), 1, true) ~= nil then
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
        -- Back-compat: treat GOSSIP_CONFIRM as "any hearth/bind style confirm".
        return (expectedWhich == "GOSSIP_CONFIRM" and whichStr == "CONFIRM_BINDER")
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
            return (norm:find(requiredText:gsub("’", "'"):lower(), 1, true) ~= nil)
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

    local expectedWhich = tostring(xpop.which or "")
    if expectedWhich ~= whichStr then
        if not (expectedWhich == "GOSSIP_CONFIRM" and whichStr == "CONFIRM_BINDER") then
            D("Which mismatch: expected=" .. expectedWhich .. ", got=" .. whichStr)
            return
        end
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
            if IsSecretString and IsSecretString(guid) then
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
