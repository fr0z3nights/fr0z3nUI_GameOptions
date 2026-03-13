---@diagnostic disable: undefined-global

local addonName, ns = ...
if type(ns) ~= "table" then
    ns = {}
end

-- Talk (Display/Browse) non-UI logic.
-- Kept separate from TalkUI so the UI layer can stay thin.

ns.Talk = ns.Talk or {}

function ns.Talk.EnsureEngineInitialized()
    -- These are legacy globals used by the gossip engine + event wiring.
    -- First-run (fresh login) can hit nil timestamps; force sane defaults.
    lastSelectAt = tonumber(lastSelectAt) or 0
    lastAutoSelectAt = tonumber(lastAutoSelectAt) or 0
    if firstAutoSelectSinceLogin == nil then
        firstAutoSelectSinceLogin = true
    end

end

local function SafeToString(v)
    if ns and type(ns.SafeToString) == "function" then
        return ns.SafeToString(v)
    end
    return tostring(v)
end

local function IsSecretString(v)
    if ns and type(ns.IsSecretString) == "function" then
        return ns.IsSecretString(v)
    end
    return false
end

local function PrintPrefixed(msg)
    if ns and ns.Talk and type(ns.Talk.Print) == "function" then
        ns.Talk.Print(msg)
        return
    end
    if print then
        print("|cff00ccff[FGO]|r " .. SafeToString(msg))
    end
end

local function GetCurrentNpcID()
    if ns and type(ns.GetCurrentNpcID) == "function" then
        return ns.GetCurrentNpcID()
    end
    return nil
end

local function GetCurrentNpcName()
    if ns and type(ns.GetCurrentNpcName) == "function" then
        return ns.GetCurrentNpcName()
    end
    return nil
end

local function CloseGossipWindow()
    if ns and type(ns.CloseGossipWindow) == "function" then
        return ns.CloseGossipWindow()
    end
    if C_GossipInfo and C_GossipInfo.CloseGossip then
        return C_GossipInfo.CloseGossip()
    end
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

local gossipRetryToken = 0
local lastGossipEntriesDebugAt = 0
local lastGossipEntriesDebugKey = nil

local function GetGossipDisplayEntries()
    local entries = {}
    if not (C_GossipInfo and C_GossipInfo.GetOptions) then
        return entries
    end

    local options = C_GossipInfo.GetOptions() or {}
    for _, opt in ipairs(options) do
        local optionID = opt and opt.gossipOptionID
        if optionID then
            entries[#entries + 1] = { kind = "option", id = optionID, data = opt }
        end
    end

    return entries
end

local selectConfirmToken = 0
local lastConfirmSession = nil
local confirmTries = 0

local lastAutoSelectAttemptKey = nil
local lastAutoSelectAttemptAt = 0
local lastAutoSelectAttemptCount = 0

local function GetConfirmTryCount()
    local sess = ns and ns.GossipSession
    if sess ~= lastConfirmSession then
        lastConfirmSession = sess
        confirmTries = 0
    end
    confirmTries = confirmTries + 1
    return confirmTries
end

local function ComputeEntriesKey(npcID, entries)
    local parts = { tostring(npcID) }
    for _, g in ipairs(entries or {}) do
        parts[#parts + 1] = tostring(g.kind) .. ":" .. tostring(g.id)
    end
    return table.concat(parts, "|")
end

function ns.Talk.TryAutoSelect(isRetry)
    if ns and ns.Talk and type(ns.Talk.InitSV) == "function" then
        ns.Talk.InitSV()
    end
    if ns and ns.Talk and type(ns.Talk.EnsureEngineInitialized) == "function" then
        ns.Talk.EnsureEngineInitialized()
    end

    local debug = AutoGossip_Settings and AutoGossip_Settings.debugAcc
    local function Debug(msg)
        if debug then
            PrintPrefixed("Gossip: " .. SafeToString(msg))
        end
    end

    local function RuleAllowsAutoSelect(ruleEntry, npcID, optionID, gossipEntry)
        if type(ruleEntry) ~= "table" then
            return true
        end

        local pred = ruleEntry.when or ruleEntry.cond or ruleEntry.condition
        if pred == nil then
            return true
        end

        if type(pred) == "function" then
            local ok, ret = pcall(pred, npcID, optionID, gossipEntry, ruleEntry)
            if not ok then
                if debug then
                    Debug(
                        "Match ignored (condition error): "
                            .. tostring(npcID)
                            .. ":"
                            .. tostring(optionID)
                            .. " :: "
                            .. SafeToString(ret)
                    )
                end
                return false
            end
            return ret and true or false
        end

        -- Unknown condition type -> be safe and do not auto-select.
        if debug then
            Debug("Match ignored (condition invalid): " .. tostring(npcID) .. ":" .. tostring(optionID))
        end
        return false
    end

    if IsShiftKeyDown and IsShiftKeyDown() then
        Debug("Blocked (Shift held)")
        return false, "blocked"
    end
    -- When the options window is open, behave like Shift is held:
    -- don't auto-select while the user is inspecting/editing rules.
    if AutoGossipOptions and AutoGossipOptions.IsShown and AutoGossipOptions:IsShown() then
        -- Prefer IsVisible so a "shown but effectively invisible" frame (e.g. after /reload or bad strata)
        -- doesn't permanently disable auto-select until the user toggles the UI.
        local isVisible = true
        if AutoGossipOptions.IsVisible then
            isVisible = AutoGossipOptions:IsVisible() and true or false
        end
        local alpha = 1
        if AutoGossipOptions.GetEffectiveAlpha then
            alpha = tonumber(AutoGossipOptions:GetEffectiveAlpha()) or 1
        end

        if isVisible and alpha > 0.05 then
            Debug("Blocked (options window open)")
            return false, "blocked"
        end
    end
    if not (C_GossipInfo and C_GossipInfo.GetOptions and C_GossipInfo.SelectOption) then
        Debug("Blocked (missing C_GossipInfo APIs)")
        return false, "no-api"
    end

    local npcID = GetCurrentNpcID()
    if not npcID then
        Debug("Blocked (could not resolve NPC ID)")
        return false, "no-npc"
    end

    local now = (GetTime and GetTime()) or 0

    if not isRetry then
        if now - lastSelectAt < 0.25 then
            Debug("Blocked (debounce)")
            return false, "blocked"
        end
    end

    local function NoteLastGossipSelection(selectedNpcID, selectedOptionID, entry)
        -- This is used by the TalkUP module to scope StaticPopup auto-confirms
        -- to the specific gossip option we just selected.
        if ns and ns.TalkUP and type(ns.TalkUP.SetLastGossipSelection) == "function" then
            pcall(ns.TalkUP.SetLastGossipSelection, selectedNpcID, selectedOptionID, entry)
            return
        end
        ns = (type(ns) == "table") and ns or {}
        ns._lastGossipSelection = {
            npcID = selectedNpcID,
            optionID = selectedOptionID,
            at = now,
            entry = entry,
        }
    end

    local entries = GetGossipDisplayEntries()
    if #entries == 0 then
        Debug("No gossip entries")
        return false, "no-options"
    end

    -- Stable signature of the current gossip list; used to avoid repeatedly selecting
    -- the same option when the game returns you to the same gossip after selection.
    local entrySigParts = { tostring(npcID) }
    for _, g in ipairs(entries) do
        entrySigParts[#entrySigParts + 1] = tostring(g.kind) .. ":" .. tostring(g.id)
    end
    local entriesKey = table.concat(entrySigParts, "|")

    -- Debug helper: dump the entry list so DB authors can see the real IDs.
    if debug then
        local parts = { tostring(npcID) }
        for _, g in ipairs(entries) do
            parts[#parts + 1] = tostring(g.kind) .. ":" .. tostring(g.id)
        end
        local k = table.concat(parts, "|")
        if k ~= lastGossipEntriesDebugKey or (now - (lastGossipEntriesDebugAt or 0)) > 2 then
            lastGossipEntriesDebugKey = k
            lastGossipEntriesDebugAt = now

            Debug("Entries for NPC " .. tostring(npcID) .. ":")
            for i, g in ipairs(entries) do
                local label = tostring(i) .. ") " .. tostring(g.kind) .. " " .. tostring(g.id)
                local d = g and g.data
                if g.kind == "option" then
                    local txt = (d and (d.name or d.optionText or d.text))
                    if txt then
                        label = label .. " :: " .. SafeToString(txt)
                    end
                else
                    local title = d and d.title
                    if title then
                        label = label .. " :: " .. SafeToString(title)
                    end
                end
                Debug(label)
            end
        end
    end

    local function SelectEntry(entry, contextNpcID, contextEntriesKey, isFirstSelectSinceLogin)
        if not entry then
            return false
        end

        local function SelectNextFrame(fn, id, retryDelay)
            if not fn then
                return false
            end

            local function SameGossipStillOpen()
                local curNpcID = GetCurrentNpcID()
                if not curNpcID or curNpcID ~= contextNpcID then
                    return false
                end

                local curEntries = GetGossipDisplayEntries()
                if type(curEntries) ~= "table" or #curEntries == 0 then
                    return false
                end

                local parts = { tostring(curNpcID) }
                for _, g in ipairs(curEntries) do
                    parts[#parts + 1] = tostring(g.kind) .. ":" .. tostring(g.id)
                end
                local curKey = table.concat(parts, "|")
                return curKey == contextEntriesKey
            end

            -- On cold login / first interaction, selecting in the same frame as GOSSIP_SHOW
            -- can be ignored by the client. Debug printing incidentally delays enough to
            -- make it work, so we explicitly do a small guarded re-attempt sequence.
            if C_Timer and C_Timer.After then
                -- Always try immediately first (same event frame) to avoid timing/race issues
                -- where delayed calls get ignored unless debug printing slows execution down.
                if SameGossipStillOpen() then
                    pcall(fn, id)
                end

                local delays = { 0, 0.06, 0.18 }
                if isFirstSelectSinceLogin then
                    -- Older clients/first interaction sometimes need a longer settle.
                    delays[#delays + 1] = (retryDelay and retryDelay > 0) and retryDelay or 0.40
                    delays[#delays + 1] = 0.65
                end

                for _, d in ipairs(delays) do
                    C_Timer.After(d, function()
                        if SameGossipStillOpen() then
                            pcall(fn, id)
                        end
                    end)
                end
                return true
            end

            if SameGossipStillOpen() then
                return pcall(fn, id)
            end
            return false
        end

        if entry.kind == "option" then
            if not (C_GossipInfo and C_GossipInfo.SelectOption) then
                return false
            end
            return SelectNextFrame(C_GossipInfo.SelectOption, entry.id, 0.20)
        elseif entry.kind == "availableQuest" then
            if not (C_GossipInfo and C_GossipInfo.SelectAvailableQuest) then
                return false
            end
            return SelectNextFrame(C_GossipInfo.SelectAvailableQuest, entry.id, 0.20)
        elseif entry.kind == "activeQuest" then
            if not (C_GossipInfo and C_GossipInfo.SelectActiveQuest) then
                return false
            end
            return SelectNextFrame(C_GossipInfo.SelectActiveQuest, entry.id, 0.20)
        end
        return false
    end

    local function EntryWantsCloseOnly(ruleEntry)
        if type(ruleEntry) ~= "table" then
            return false
        end
        local a = ruleEntry.action or ruleEntry.cmd
        if type(a) ~= "string" then
            return false
        end
        a = a:lower()
        return (a == "close" or a == "closegossip" or a == "closewindow")
    end

    local function EntryWantsCloseAfterSelect(ruleEntry)
        if type(ruleEntry) ~= "table" then
            return false
        end
        if ruleEntry.close == true or ruleEntry.closeGossip == true or ruleEntry.closeWindow == true then
            return true
        end
        local a = ruleEntry.after or ruleEntry.post
        if type(a) ~= "string" then
            return false
        end
        a = a:lower()
        return (a == "close" or a == "closegossip" or a == "closewindow")
    end

    local function ScheduleFirstRunSelectConfirm(contextNpcID, contextEntriesKey)
        if not (C_Timer and C_Timer.After) then
            return
        end

        selectConfirmToken = (selectConfirmToken or 0) + 1
        local token = selectConfirmToken

        local function SameGossipStillOpen()
            local curNpcID = GetCurrentNpcID()
            if not curNpcID or curNpcID ~= contextNpcID then
                return false
            end
            local curEntries = GetGossipDisplayEntries()
            if type(curEntries) ~= "table" or #curEntries == 0 then
                return false
            end
            return ComputeEntriesKey(curNpcID, curEntries) == contextEntriesKey
        end

                local function CheckAfter(delay)
            C_Timer.After(delay, function()
                if token ~= selectConfirmToken then
                    return
                end
                if not SameGossipStillOpen() then
                    return
                end
                -- Still the exact same gossip list after a selection attempt on first-run.
                -- Client sometimes ignores the first attempt; re-run silently a limited number of times.
                if GetConfirmTryCount() > 3 then
                    return
                end
                if ns and ns.Talk and type(ns.Talk.TryAutoSelect) == "function" then
                    ns.Talk.TryAutoSelect(true)
                end
            end)
        end

        CheckAfter(0.22)
        CheckAfter(0.48)
    end

    local function ArmAutoSelectAttemptGuard(contextEntriesKey, optionID)
        local attemptKey = tostring(contextEntriesKey) .. ":" .. tostring(optionID)
        local now2 = (GetTime and GetTime()) or 0

        if attemptKey ~= lastAutoSelectAttemptKey or (now2 - (lastAutoSelectAttemptAt or 0)) > 2.0 then
            lastAutoSelectAttemptKey = attemptKey
            lastAutoSelectAttemptAt = now2
            lastAutoSelectAttemptCount = 0

            -- Legacy globals used for the generic loop guard.
            lastAutoSelectKey = contextEntriesKey
            lastAutoSelectOptionID = optionID
            lastAutoSelectAt = now2
        end

        lastAutoSelectAttemptCount = (tonumber(lastAutoSelectAttemptCount) or 0) + 1
        return lastAutoSelectAttemptCount
    end

    local function ShouldBlockRepeatAttempt(contextEntriesKey, optionID)
        if lastAutoSelectKey ~= contextEntriesKey or lastAutoSelectOptionID ~= optionID then
            return false
        end

        local now2 = (GetTime and GetTime()) or 0
        local since = now2 - (tonumber(lastAutoSelectAt) or 0)
        if since >= 2.0 then
            return false
        end

        -- Allow a small burst of retries when the client ignores the first select
        -- (common when timing is tight and debug printing “fixes” it).
        if since < 1.0 then
            local attemptKey = tostring(contextEntriesKey) .. ":" .. tostring(optionID)
            if attemptKey == lastAutoSelectAttemptKey and (tonumber(lastAutoSelectAttemptCount) or 0) < 3 then
                return false
            end
        end

        return true
    end

    local LookupNpcBucket = ns and ns.LookupNpcBucket
    local LookupRuleEntry = ns and ns.LookupRuleEntry
    local IsDisabled = ns and ns.IsDisabled
    local IsDisabledAccOnChar = ns and ns.IsDisabledAccOnChar
    local IsDisabledDB = ns and ns.IsDisabledDB
    local IsDisabledDBOnChar = ns and ns.IsDisabledDBOnChar

    -- Per-NPC quest gating (opt-in via NPC.__meta.stopIfQuestAvailable/TurnIn)
    --
    -- This is intentionally narrow: it only suppresses selecting "option" entries
    -- when a specific quest is being offered or is ready to turn in on that NPC.
    -- It does not auto-accept/turn-in quests.
    local function PlayerIsOnQuestID(questID)
        questID = tonumber(questID)
        if not questID then
            return false
        end

        if C_QuestLog and type(C_QuestLog.IsOnQuest) == "function" then
            local ok, on = pcall(C_QuestLog.IsOnQuest, questID)
            return ok and on and true or false
        end

        if C_QuestLog and type(C_QuestLog.GetLogIndexForQuestID) == "function" then
            local ok, idx = pcall(C_QuestLog.GetLogIndexForQuestID, questID)
            return ok and type(idx) == "number" and idx > 0
        end

        if type(GetQuestLogIndexByID) == "function" then
            local ok, idx = pcall(GetQuestLogIndexByID, questID)
            return ok and type(idx) == "number" and idx > 0
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

    local function GossipHasAvailableQuest(questID)
        questID = tonumber(questID)
        if not questID then
            return false
        end
        if not (C_GossipInfo and type(C_GossipInfo.GetAvailableQuests) == "function") then
            return false
        end
        for _, q in ipairs(C_GossipInfo.GetAvailableQuests() or {}) do
            local qid = tonumber((q and (q.questID or q.questId or q.id)) or (q and q[1]))
            if qid == questID then
                return true
            end
        end
        return false
    end

    local function GossipHasActiveQuest(questID)
        questID = tonumber(questID)
        if not questID then
            return false
        end
        if not (C_GossipInfo and type(C_GossipInfo.GetActiveQuests) == "function") then
            return false
        end
        for _, q in ipairs(C_GossipInfo.GetActiveQuests() or {}) do
            local qid = tonumber((q and (q.questID or q.questId or q.id)) or (q and q[1]))
            if qid == questID then
                return true
            end
        end
        return false
    end

    local function GossipActiveQuestIsTurnInReady(questID)
        questID = tonumber(questID)
        if not questID then
            return false
        end
        if not (C_GossipInfo and type(C_GossipInfo.GetActiveQuests) == "function") then
            return false
        end

        for _, q in ipairs(C_GossipInfo.GetActiveQuests() or {}) do
            local qid = tonumber((q and (q.questID or q.questId or q.id)) or (q and q[1]))
            if qid == questID then
                local isComplete = q and q.isComplete
                if isComplete == true or isComplete == 1 then
                    return true
                end
                if isComplete == nil and QuestReadyForTurnIn(questID) then
                    return true
                end
            end
        end

        return false
    end

    local function GetStopIfQuestAvailableSet(npcTable)
        if type(npcTable) ~= "table" then
            return nil
        end
        local meta = rawget(npcTable, "__meta")
        if type(meta) ~= "table" then
            return nil
        end
        local v = rawget(meta, "stopIfQuestAvailable")
        if v == nil then
            return nil
        end

        local set = {}
        if type(v) == "number" or type(v) == "string" then
            local q = tonumber(v)
            if q and q > 0 then
                set[q] = true
            end
            return next(set) and set or nil
        end

        if type(v) == "table" then
            for k, vv in pairs(v) do
                local q = tonumber(type(k) == "number" and vv or k)
                if q and q > 0 then
                    set[q] = true
                elseif vv == true then
                    local q2 = tonumber(k)
                    if q2 and q2 > 0 then
                        set[q2] = true
                    end
                end
            end
            return next(set) and set or nil
        end

        return nil
    end

    local function GetStopIfQuestTurnInSet(npcTable)
        if type(npcTable) ~= "table" then
            return nil
        end
        local meta = rawget(npcTable, "__meta")
        if type(meta) ~= "table" then
            return nil
        end

        local v = rawget(meta, "stopIfQuestTurnIn")
        if v == nil then
            v = rawget(meta, "stopIfQuestReadyForTurnIn")
        end
        if v == nil then
            return nil
        end

        local set = {}
        if type(v) == "number" or type(v) == "string" then
            local q = tonumber(v)
            if q and q > 0 then
                set[q] = true
            end
            return next(set) and set or nil
        end

        if type(v) == "table" then
            for k, vv in pairs(v) do
                local q = tonumber(type(k) == "number" and vv or k)
                if q and q > 0 then
                    set[q] = true
                elseif vv == true then
                    local q2 = tonumber(k)
                    if q2 and q2 > 0 then
                        set[q2] = true
                    end
                end
            end
            return next(set) and set or nil
        end

        return nil
    end

    local function MergeQuestSet(dst, src)
        if type(dst) ~= "table" or type(src) ~= "table" then
            return
        end
        for q in pairs(src) do
            dst[q] = true
        end
    end

    local function ShouldBlockOptionAutoSelectForNpc(targetNpcID)
        local mergedAvailable = {}
        local mergedTurnIn = {}

        if type(LookupNpcBucket) == "function" then
            MergeQuestSet(mergedAvailable, GetStopIfQuestAvailableSet(LookupNpcBucket(AutoGossip_Char, targetNpcID)) or {})
            MergeQuestSet(mergedTurnIn, GetStopIfQuestTurnInSet(LookupNpcBucket(AutoGossip_Char, targetNpcID)) or {})

            MergeQuestSet(mergedAvailable, GetStopIfQuestAvailableSet(LookupNpcBucket(AutoGossip_Acc, targetNpcID)) or {})
            MergeQuestSet(mergedTurnIn, GetStopIfQuestTurnInSet(LookupNpcBucket(AutoGossip_Acc, targetNpcID)) or {})
        end

        MergeQuestSet(mergedAvailable, GetStopIfQuestAvailableSet(GetDbNpcTable(targetNpcID)) or {})
        MergeQuestSet(mergedTurnIn, GetStopIfQuestTurnInSet(GetDbNpcTable(targetNpcID)) or {})

        if next(mergedAvailable) == nil and next(mergedTurnIn) == nil then
            return false, nil, nil
        end

        for questID in pairs(mergedAvailable) do
            if GossipHasAvailableQuest(questID)
                and (not GossipHasActiveQuest(questID))
                and (not PlayerIsOnQuestID(questID))
                and (not QuestIsCompleted(questID)) then
                return true, questID, "available"
            end
        end

        for questID in pairs(mergedTurnIn) do
            if GossipActiveQuestIsTurnInReady(questID) then
                return true, questID, "turnin"
            end
        end

        return false, nil, nil
    end

    local optionGate, optionGateQuestID, optionGateWhy = ShouldBlockOptionAutoSelectForNpc(npcID)
    if optionGate and debug then
        Debug("Auto-select suppressed (quest gate: " .. tostring(optionGateWhy) .. " questID=" .. tostring(optionGateQuestID) .. ")")
    end

    -- Prefer character rules over account rules, then DB pack.
    for _, scope in ipairs({ "char", "acc" }) do
        local db = (scope == "acc") and AutoGossip_Acc or AutoGossip_Char
        local npcTable = (type(LookupNpcBucket) == "function") and LookupNpcBucket(db, npcID) or nil
        if npcTable then
            local bestG, bestID, bestEntry, bestPrio
            for _, g in ipairs(entries) do
                local id = g and g.id
                if optionGate and g and g.kind == "option" then
                    -- Quest gate active: do not auto-select option entries.
                    -- This intentionally leaves the gossip open for manual quest accept/turn-in.
                else
                local ruleEntry = (id and type(LookupRuleEntry) == "function") and LookupRuleEntry(npcTable, id) or nil
                if ruleEntry ~= nil then
                    if type(IsDisabled) == "function" and IsDisabled(scope, npcID, id) then
                        Debug("Match blocked (" .. scope .. " disabled): " .. tostring(npcID) .. ":" .. tostring(id))
                    elseif scope == "acc" and type(IsDisabledAccOnChar) == "function" and IsDisabledAccOnChar(npcID, id) then
                        Debug("Match blocked (acc disabled on this char): " .. tostring(npcID) .. ":" .. tostring(id))
                    else
                        -- Manual-only rules: keep them for popup scoping, but do not auto-select.
                        if type(ruleEntry) == "table" then
                            local t = tostring(ruleEntry.type or "")
                            local noAuto = (ruleEntry.noAuto == true) or (ruleEntry.manual == true) or (t ~= "" and t:lower() == "manual")
                            if noAuto then
                                if debug then
                                    Debug("Match ignored (manual): " .. tostring(npcID) .. ":" .. tostring(id))
                                end
                                ruleEntry = nil
                            end
                        end

                        if ruleEntry ~= nil then
                            local pr = 0
                            if type(ruleEntry) == "table" then
                                if not RuleAllowsAutoSelect(ruleEntry, npcID, id, g) then
                                    if debug then
                                        Debug("Match ignored (condition false): " .. tostring(npcID) .. ":" .. tostring(id))
                                    end
                                    ruleEntry = nil
                                else
                                    pr = tonumber(ruleEntry.prio or ruleEntry.order or ruleEntry.priority) or 0
                                end
                            end

                            if ruleEntry ~= nil then
                                if bestG == nil or pr > (bestPrio or 0) then
                                    bestG, bestID, bestEntry, bestPrio = g, id, ruleEntry, pr
                                end
                                if debug then
                                    Debug(
                                        "Match ("
                                            .. scope
                                            .. ", "
                                            .. tostring(g.kind)
                                            .. ") prio="
                                            .. tostring(pr)
                                            .. ": "
                                            .. tostring(npcID)
                                            .. ":"
                                            .. tostring(id)
                                    )
                                end
                            end
                        end
                    end
                end
                end
            end

            if bestG and bestID then
                -- Loop guard: prevent infinite reselection loops when the game returns you
                -- to the same gossip list, but allow a small retry burst when the client
                -- ignores the first select.
                if bestG.kind == "option" and ShouldBlockRepeatAttempt(entriesKey, bestID) then
                    Debug("Blocked (repeat selection): " .. tostring(npcID) .. ":" .. tostring(bestID))
                    return false, "blocked"
                end

                lastSelectAt = now

                if EntryWantsCloseOnly(bestEntry) then
                    Debug(
                        "Closing gossip ("
                            .. scope
                            .. ", "
                            .. tostring(bestG.kind)
                            .. ") prio="
                            .. tostring(bestPrio or 0)
                            .. ": "
                            .. tostring(npcID)
                            .. ":"
                            .. tostring(bestID)
                    )
                    if C_Timer and C_Timer.After then
                        C_Timer.After(0, CloseGossipWindow)
                    else
                        CloseGossipWindow()
                    end
                    return true, "closed"
                end

                Debug(
                    "Selecting ("
                        .. scope
                        .. ", "
                        .. tostring(bestG.kind)
                        .. ") prio="
                        .. tostring(bestPrio or 0)
                        .. ": "
                        .. tostring(npcID)
                        .. ":"
                        .. tostring(bestID)
                )
                if bestG.kind == "option" then
                    NoteLastGossipSelection(npcID, bestID, bestEntry)
                end
                local isFirst = firstAutoSelectSinceLogin and true or false
                firstAutoSelectSinceLogin = false
                if bestG.kind == "option" then
                    local n = ArmAutoSelectAttemptGuard(entriesKey, bestID)
                    if (not isRetry) and n == 1 then
                        ScheduleFirstRunSelectConfirm(npcID, entriesKey)
                    end
                end

                if SelectEntry(bestG, npcID, entriesKey, isFirst) then
                    if EntryWantsCloseAfterSelect(bestEntry) then
                        local d = isFirst and 0.65 or 0.35
                        if C_Timer and C_Timer.After then
                            C_Timer.After(d, CloseGossipWindow)
                        else
                            CloseGossipWindow()
                        end
                    end
                    return true, "selected"
                end
                Debug("Select failed (" .. tostring(bestG.kind) .. "): " .. tostring(npcID) .. ":" .. tostring(bestID))
                return false, "blocked"
            end
        end
    end

    local dbNpc = GetDbNpcTable(npcID)
    if dbNpc then
        local bestG, bestID, bestEntry, bestPrio
        for _, g in ipairs(entries) do
            local id = g and g.id
            if optionGate and g and g.kind == "option" then
                -- Quest gate active: do not auto-select option entries.
            else
            local ruleEntry = (id and type(LookupRuleEntry) == "function") and LookupRuleEntry(dbNpc, id) or nil
            if ruleEntry ~= nil then
                if type(IsDisabledDB) == "function" and IsDisabledDB(npcID, id) then
                    Debug("DB match blocked (disabled): " .. tostring(npcID) .. ":" .. tostring(id))
                elseif type(IsDisabledDBOnChar) == "function" and IsDisabledDBOnChar(npcID, id) then
                    Debug("DB match blocked (disabled on this char): " .. tostring(npcID) .. ":" .. tostring(id))
                else
                    -- Manual-only DB rules: keep them for popup scoping, but do not auto-select.
                    if type(ruleEntry) == "table" then
                        local t = tostring(ruleEntry.type or "")
                        local noAuto = (ruleEntry.noAuto == true) or (ruleEntry.manual == true) or (t ~= "" and t:lower() == "manual")
                        if noAuto then
                            if debug then
                                Debug("DB match ignored (manual): " .. tostring(npcID) .. ":" .. tostring(id))
                            end
                            ruleEntry = nil
                        end
                    end

                    if ruleEntry ~= nil then
                        local pr = 0
                        if type(ruleEntry) == "table" then
                            if not RuleAllowsAutoSelect(ruleEntry, npcID, id, g) then
                                if debug then
                                    Debug("DB match ignored (condition false): " .. tostring(npcID) .. ":" .. tostring(id))
                                end
                                ruleEntry = nil
                            else
                                pr = tonumber(ruleEntry.prio or ruleEntry.order or ruleEntry.priority) or 0
                            end
                        end

                        if ruleEntry ~= nil then
                            if bestG == nil or pr > (bestPrio or 0) then
                                bestG, bestID, bestEntry, bestPrio = g, id, ruleEntry, pr
                            end
                            if debug then
                                Debug("DB match (" .. tostring(g.kind) .. ") prio=" .. tostring(pr) .. ": " .. tostring(npcID) .. ":" .. tostring(id))
                            end
                        end
                    end
                end
            end
            end
        end

        if bestG and bestID then
            -- Loop guard: prevent infinite reselection loops when the game returns you
            -- to the same gossip list, but allow a small retry burst when the client
            -- ignores the first select.
            if bestG.kind == "option" and ShouldBlockRepeatAttempt(entriesKey, bestID) then
                Debug("Blocked (repeat selection): " .. tostring(npcID) .. ":" .. tostring(bestID))
                return false, "blocked"
            end

            lastSelectAt = now

            if EntryWantsCloseOnly(bestEntry) then
                Debug(
                    "Closing gossip (DB, "
                        .. tostring(bestG.kind)
                        .. ") prio="
                        .. tostring(bestPrio or 0)
                        .. ": "
                        .. tostring(npcID)
                        .. ":"
                        .. tostring(bestID)
                )
                if C_Timer and C_Timer.After then
                    C_Timer.After(0, CloseGossipWindow)
                else
                    CloseGossipWindow()
                end
                return true, "closed"
            end

            Debug(
                "Selecting (DB, "
                    .. tostring(bestG.kind)
                    .. ") prio="
                    .. tostring(bestPrio or 0)
                    .. ": "
                    .. tostring(npcID)
                    .. ":"
                    .. tostring(bestID)
            )
            if bestG.kind == "option" then
                NoteLastGossipSelection(npcID, bestID, bestEntry)
            end
            local isFirst = firstAutoSelectSinceLogin and true or false
            firstAutoSelectSinceLogin = false
            if bestG.kind == "option" then
                local n = ArmAutoSelectAttemptGuard(entriesKey, bestID)
                if (not isRetry) and n == 1 then
                    ScheduleFirstRunSelectConfirm(npcID, entriesKey)
                end
            end

            if SelectEntry(bestG, npcID, entriesKey, isFirst) then
                if EntryWantsCloseAfterSelect(bestEntry) then
                    local d = isFirst and 0.65 or 0.35
                    if C_Timer and C_Timer.After then
                        C_Timer.After(d, CloseGossipWindow)
                    else
                        CloseGossipWindow()
                    end
                end
                return true, "selected"
            end
            Debug("Select failed (DB, " .. tostring(bestG.kind) .. "): " .. tostring(npcID) .. ":" .. tostring(bestID))
            return false, "blocked"
        end
    end

    Debug("No matching enabled rules")
    return false, "no-match"
end

function ns.Talk.ScheduleGossipRetry()
    if not (C_Timer and C_Timer.After) then
        return
    end

    if ns and ns.Talk and type(ns.Talk.EnsureEngineInitialized) == "function" then
        ns.Talk.EnsureEngineInitialized()
    end

    gossipRetryToken = (gossipRetryToken or 0) + 1
    local token = gossipRetryToken

    local function RetryAfter(delay)
        C_Timer.After(delay, function()
            if token ~= gossipRetryToken then
                return
            end
            if ns and ns.Talk and type(ns.Talk.TryAutoSelect) == "function" then
                ns.Talk.TryAutoSelect(true)
            end
        end)
    end

    -- Small staggered retries to handle cases where gossip info isn't ready on the first frame.
    RetryAfter(0)
    RetryAfter(0.12)
    -- Cold-login / first-interaction can take longer for NPC GUID/options to populate.
    RetryAfter(0.25)
    RetryAfter(0.45)
end

local lastPrintOnShowAt = 0
local lastPrintOnShowKey = nil
local PRINT_ON_SHOW_DEBOUNCE_WINDOW = 0.75

function ns.Talk.PrintCurrentOptions(debounce)
    if not (C_GossipInfo and C_GossipInfo.GetOptions) then
        PrintPrefixed("Gossip API not available")
        return
    end

    if ns and ns.Talk and type(ns.Talk.InitSV) == "function" then
        ns.Talk.InitSV()
    end
    local minOptions = tonumber(AutoGossip_UI and AutoGossip_UI.printOnShowMinOptions) or 2
    minOptions = math.floor(minOptions)
    if minOptions < 1 then
        minOptions = 1
    end

    local options = C_GossipInfo.GetOptions() or {}
    local optionCount = #options
    -- Avoid chat spam: by default, skip single-option NPCs.
    if optionCount < minOptions then
        return
    end

    local function GetPlayerContinentNameForHeader()
        if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetMapInfo) then
            return ""
        end
        local mapID = C_Map.GetBestMapForUnit("player")
        local safety = 0
        while mapID and safety < 30 do
            local info = C_Map.GetMapInfo(mapID)
            if not info then
                break
            end
            if Enum and Enum.UIMapType and info.mapType == Enum.UIMapType.Continent then
                local name = info.name or ""
                -- Some APIs/overrides may include commas in continent names; normalize to spaces.
                if type(name) == "string" and name:find(",", 1, true) then
                    name = name:gsub("%s*,%s*", " ")
                    name = name:gsub("%s%s+", " ")
                    name = name:gsub("^%s+", ""):gsub("%s+$", "")
                end
                return name
            end
            mapID = info.parentMapID
            safety = safety + 1
        end
        return ""
    end

    local function GetPlayerZoneNameForHeader()
        if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetMapInfo) then
            return ""
        end
        local mapID = C_Map.GetBestMapForUnit("player")
        local safety = 0
        while mapID and safety < 30 do
            local info = C_Map.GetMapInfo(mapID)
            if not info then
                break
            end
            if Enum and Enum.UIMapType and info.mapType == Enum.UIMapType.Zone then
                return info.name or ""
            end
            mapID = info.parentMapID
            safety = safety + 1
        end
        return ""
    end

    local function GetLocationTextForHeader()
        local zone = GetPlayerZoneNameForHeader()
        if zone == "" then
            zone = (GetRealZoneText and GetRealZoneText()) or ((GetZoneText and GetZoneText()) or "")
        end
        local continent = GetPlayerContinentNameForHeader()
        if zone ~= "" and continent ~= "" then
            return zone .. ", " .. continent
        end
        return zone ~= "" and zone or (continent ~= "" and continent or "")
    end

    local npcID = GetCurrentNpcID()
    local npcName = GetCurrentNpcName()
    if IsSecretString(npcName) then
        npcName = ""
    end
    npcName = npcName or ""

    -- Print-on-show is primarily used for building rules; if we don't have the NPC ID yet,
    -- skip so we don't double-print when the ID becomes available a fraction later.
    if debounce and not npcID then
        return
    end

    -- Debounce only for Print-on-show. Both GOSSIP_SHOW and
    -- PLAYER_INTERACTION_MANAGER_FRAME_SHOW can fire for the same interaction.
    if debounce then
        local ids = {}
        for _, opt in ipairs(options) do
            local optionID = opt and opt.gossipOptionID
            if optionID then
                ids[#ids + 1] = optionID
            end
        end
        table.sort(ids)
        local key = tostring(optionCount) .. ":" .. table.concat(ids, ",")

        local now = (GetTime and GetTime()) or 0
        if lastPrintOnShowKey == key and (now - (lastPrintOnShowAt or 0)) < PRINT_ON_SHOW_DEBOUNCE_WINDOW then
            return
        end
        lastPrintOnShowKey = key
        lastPrintOnShowAt = now
    end

    if npcID then
        PrintPrefixed(string.format("NPC:  %s (%d)", npcName, npcID))
    end

    do
        local locText = GetLocationTextForHeader()
        if IsSecretString(locText) then
            locText = ""
        end
        if type(locText) == "string" and locText ~= "" then
            PrintPrefixed("LOC:  " .. locText)
        end
    end

    local HasRule = ns and ns.HasRule
    local HasDbRule = ns and ns.HasDbRule
    local IsDisabled = ns and ns.IsDisabled
    local IsDisabledDB = ns and ns.IsDisabledDB
    local IsDisabledDBOnChar = ns and ns.IsDisabledDBOnChar

    for _, opt in ipairs(options) do
        if opt and opt.gossipOptionID then
            local optName = opt.name
            if IsSecretString(optName) then
                optName = ""
            end
            local optionID = opt.gossipOptionID
            local isSet = false
            if npcID and optionID then
                if type(HasRule) == "function" and type(IsDisabled) == "function" and HasRule("char", npcID, optionID) and (not IsDisabled("char", npcID, optionID)) then
                    isSet = true
                elseif type(HasRule) == "function" and type(IsDisabled) == "function" and HasRule("acc", npcID, optionID) and (not IsDisabled("acc", npcID, optionID)) then
                    isSet = true
                elseif type(HasDbRule) == "function" and type(IsDisabledDB) == "function" and type(IsDisabledDBOnChar) == "function" and HasDbRule(npcID, optionID) and (not IsDisabledDB(npcID, optionID)) and (not IsDisabledDBOnChar(npcID, optionID)) then
                    isSet = true
                end
            end

            if isSet then
                PrintPrefixed(string.format("OID:  |cff00ff00%d|r  %s", optionID, optName or ""))
            else
                PrintPrefixed(string.format("OID:  %d  %s", optionID, optName or ""))
            end
        end
    end
end

local lastDebugPrintAt = 0
local lastDebugPrintKey = nil

function ns.Talk.PrintDebugOptionsOnShow(skipOptionLines)
    if ns and ns.Talk and type(ns.Talk.InitSV) == "function" then
        ns.Talk.InitSV()
    end

    if not (C_GossipInfo and C_GossipInfo.GetOptions) then
        return
    end

    local options = C_GossipInfo.GetOptions() or {}

    local npcID = GetCurrentNpcID()
    local npcName = GetCurrentNpcName()
    if IsSecretString(npcName) then
        npcName = ""
    end
    npcName = npcName or ""

    -- Debounce: both GOSSIP_SHOW and PLAYER_INTERACTION_MANAGER_FRAME_SHOW can fire for the
    -- same interaction, which would otherwise print the same block twice.
    do
        local ids = {}
        for _, opt in ipairs(options) do
            local optionID = opt and opt.gossipOptionID
            if optionID then
                ids[#ids + 1] = optionID
            end
        end
        table.sort(ids)
        local key = tostring(npcID or "?") .. ":" .. tostring(#options) .. ":" .. table.concat(ids, ",")

        local now = (GetTime and GetTime()) or 0
        if lastDebugPrintKey == key and (now - (lastDebugPrintAt or 0)) < 0.20 then
            return
        end
        lastDebugPrintKey = key
        lastDebugPrintAt = now
    end

    if npcID then
        PrintPrefixed(string.format("%d: %s", npcID, npcName))
    else
        PrintPrefixed(string.format("?: %s", npcName))
    end

    -- When Print-on-show is enabled, avoid printing a second OID list.
    -- The Print-on-show block already prints OIDs (with green highlighting), so here we only emit the header.
    if skipOptionLines then
        return
    end

    for _, opt in ipairs(options) do
        local optionID = opt and opt.gossipOptionID
        if optionID then
            local text = opt.name
            if IsSecretString(text) then
                text = ""
            end
            if type(text) ~= "string" or text == "" then
                text = "(no text)"
            end
            PrintPrefixed(string.format("OID:  %d  %s", optionID, text))
        end
    end
end

function ns.Talk.InitSV()
    if ns and type(ns._InitSV) == "function" then
        ns._InitSV()
    end
end

function ns.Talk.Print(msg)
    if ns and type(ns._Print) == "function" then
        ns._Print(msg)
        return
    end
    print("|cff00ccff[FGO]|r " .. tostring(msg))
end
