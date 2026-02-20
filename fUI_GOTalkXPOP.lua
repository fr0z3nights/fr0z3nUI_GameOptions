---@diagnostic disable: undefined-global

local addonName, ns = ...
if type(ns) ~= "table" then
    ns = {}
end

-- TalkXPOP helpers (StaticPopup hooks).
-- Renamed from fr0z3nUI_GameOptionsPopup.lua.

ns.TalkXPOP = ns.TalkXPOP or {}
-- Back-compat: older code referenced ns.Popup
ns.Popup = ns.TalkXPOP

local M = ns.TalkXPOP

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


local function TryAutoConfirmSelectedRulePopup(which, text_arg1, dialogText)
    InitSV()
    if which ~= "GOSSIP_CONFIRM" then
        return
    end
    if not AutoGossip_Settings then return end
    local ctx = M and M._lastGossipSelection or nil
    local xpop = ctx and ctx.xpop or nil
    if type(xpop) ~= "table" then
        return
    end

    local enabled = (AutoGossip_Settings.autoAcceptTalkXpopConfirmAcc or AutoGossip_Settings.autoAcceptWhitemaneSkipAcc) and true or false
    if type(xpop.setting) == "string" and xpop.setting ~= "" then
        enabled = enabled or (AutoGossip_Settings[xpop.setting] == true)
    end
    if not enabled then
        return
    end

    if tostring(xpop.which or "") ~= tostring(which or "") then
        return
    end

    -- Prefer the actual text passed to StaticPopup_Show (text_arg1).
    -- StaticPopupDialogs[which].text can be a template/format string and won't necessarily contain
    -- the final rendered message (which is what we want to match against).
    local text = (text_arg1 ~= nil) and tostring(text_arg1) or ""
    if text == "" and type(dialogText) == "string" and dialogText ~= "" then
        text = dialogText
    end
    if text == "" then
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

    local matched = false
    if xpop.allowAny == true then
        matched = true
    else
        local requiredAll = xpop.containsAll
        local requiredAny = xpop.containsAny
        local requiredText = (type(xpop.text) == "string") and xpop.text or ""
        if requiredText ~= "" then
            matched = (norm:find(requiredText:gsub("’", "'"):lower(), 1, true) ~= nil)
        else
            -- If no explicit constraints were provided, do NOT auto-confirm (forces per-entry dialogue).
            local hasConstraints = (type(requiredAll) == "table" and #requiredAll > 0) or (type(requiredAny) == "table" and #requiredAny > 0)
            if hasConstraints then
                matched = containsAll(requiredAll) and containsAny(requiredAny)
            else
                matched = false
            end
        end
    end

    if not matched then
        return
    end

    local at = ctx and tonumber(ctx.at) or 0

    -- Safety: only if it fires right after we selected the option.
    local within = tonumber(xpop.within) or 3
    if GetTime and at > 0 and (GetTime() - at) > within then
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

function M.Setup()
    if petPopupDebugHooked then
        return
    end
    petPopupDebugHooked = true

    if hooksecurefunc and StaticPopup_Show then
        hooksecurefunc("StaticPopup_Show", function(which, text_arg1, text_arg2)
            InitSV()
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
                TryAutoConfirmSelectedRulePopup(which, text_arg1, dialogText)
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

            TryAutoConfirmSelectedRulePopup(which, text_arg1, dialogText)
        end)
    end
end
