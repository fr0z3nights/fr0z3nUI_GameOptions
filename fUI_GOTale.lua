---@diagnostic disable: undefined-global

local addonName, ns = ...
if type(ns) ~= "table" then
    ns = {}
end

-- Tale (Edit/Add) non-UI logic.
-- Kept separate from TaleUI so the UI layer can stay thin.

ns.Tale = ns.Tale or {}

function ns.Tale.InitSV()
    if ns and type(ns._InitSV) == "function" then
        ns._InitSV()
    end
end

function ns.Tale.Print(msg)
    if ns and type(ns._Print) == "function" then
        ns._Print(msg)
        return
    end
    print("|cff00ccff[FGO]|r " .. tostring(msg))
end
