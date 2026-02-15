local _, ns = ...
ns = ns or {}

-- Popup helpers (StaticPopup hooks).
-- Extracted from fr0z3nUI_GameOptions.lua so popup logic is isolated.

ns.Popup = ns.Popup or {}

local function InitSV()
    if ns and type(ns._InitSV) == "function" then
        ns._InitSV()
    end
end

local function Print(msg)
    if ns and type(ns._Print) == "function" then
        ns._Print(msg)
        return
    end
    print("|cff00ccff[FGO]|r " .. tostring(msg))
end

local function IsInPandaria()
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetMapInfo) then
        return false
    end
    local mapID = C_Map.GetBestMapForUnit("player")
    local safety = 0
    while mapID and safety < 20 do
        if mapID == 424 then
            return true
        end
        local info = C_Map.GetMapInfo(mapID)
        mapID = info and info.parentMapID or nil
        safety = safety + 1
    end
    return false
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

-- These are primarily for debugging context.
local petBattleOpenStartAt = 0
local petBattleOpenStartInPandaria = false

function ns.Popup.OnPetBattleOpeningStart()
    InitSV()
    petBattleOpenStartAt = GetTime and GetTime() or 0
    petBattleOpenStartInPandaria = IsInPandaria()
end

function ns.Popup.OnPetBattleClose()
    petBattleOpenStartAt = 0
    petBattleOpenStartInPandaria = false
end

local function TryAutoAcceptPetPreparePopup(which, text_arg1)
    InitSV()
    if not (AutoGossip_Settings and AutoGossip_Settings.autoAcceptPetPrepareAcc) then
        return
    end
    if which ~= "GOSSIP_CONFIRM" then
        return
    end

    local a1 = text_arg1 and tostring(text_arg1) or ""
    if a1 == "" then
        return
    end

    -- Retail has used multiple strings for the pet battle confirmation popup.
    -- So far we've only seen these on Pandaria pet battles.
    -- Example: "Prepare yourself!" and "Let's rumble!"
    local norm = a1:gsub("’", "'"):lower()
    local isPrepare = norm:find("prepare yourself", 1, true) ~= nil
    local isRumble = (norm:find("let's rumble", 1, true) ~= nil) or (norm:find("lets rumble", 1, true) ~= nil)

    if not (isPrepare or isRumble) then
        return
    end

    -- Extra safety: only accept these for Pandaria pet battles.
    if not (petBattleOpenStartInPandaria or IsInPandaria()) then
        return
    end

    -- Defer one frame so StaticPopup has finished setting up.
    if C_Timer and C_Timer.After then
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
                            Print("Auto-accepted: " .. a1)
                        end
                    end
                    return
                end
            end
        end)
    end
end

local petPopupDebugHooked = false

function ns.Popup.Setup()
    if petPopupDebugHooked then
        return
    end
    petPopupDebugHooked = true

    if hooksecurefunc and StaticPopup_Show then
        hooksecurefunc("StaticPopup_Show", function(which, text_arg1, text_arg2)
            InitSV()
            if not (AutoGossip_Settings and AutoGossip_Settings.debugPetPopupsAcc) then
                -- Debug can be off while auto-accept is on.
                TryAutoAcceptPetPreparePopup(which, text_arg1)
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

            TryAutoAcceptPetPreparePopup(which, text_arg1)
        end)
    end
end
