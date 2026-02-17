---@diagnostic disable: undefined-global

local addonName, ns = ...
if type(ns) ~= "table" then
    ns = {}
end

-- Talk (Display/Browse) non-UI logic.
-- Kept separate from TalkUI so the UI layer can stay thin.

ns.Talk = ns.Talk or {}

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
