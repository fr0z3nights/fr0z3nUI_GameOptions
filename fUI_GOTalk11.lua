local _, ns = ...

ns.db = ns.db or {}
ns.db.rules = ns.db.rules or {}

-- XP11 database pack
-- Add rules like:
-- ns.db.rules[123456] = ns.db.rules[123456] or {}
-- ns.db.rules[123456][98765] = { zone = "Zone, Continent", npc = "NPC Name", text = [[Option text]], type = "" }
-- (Aliases also supported: zone / npc)
-- Optional: set defaults once per NPC bucket:
-- ns.db.rules[123456].__meta = { zone = "Zone, Continent", npc = "NPC Name" }
-- ns.db.rules[123456][98765] = { text = [[Option text]], type = "" }

-- Helpers so you can set a zone header and avoid repeating zone/npc fields.
local CURRENT_ZONE

local function SetZone(zone)
    CURRENT_ZONE = zone
end

local function NPC(npcID, npcName)
    ns.db.rules[npcID] = ns.db.rules[npcID] or {}
    ns.db.rules[npcID].__meta = { zone = CURRENT_ZONE, npc = npcName }
    return ns.db.rules[npcID]
end

-- Convenience helper: write one set of option rules to multiple NPC IDs.
-- Example:
-- local t = NPCs({111, 222}, "Same NPC")
-- t[12345] = { text = "...", type = "" }
local function NPCs(npcIDs, npcName)
    if type(npcIDs) ~= "table" then
        npcIDs = { npcIDs }
    end

    local targets = {}
    for _, id in ipairs(npcIDs) do
        targets[#targets + 1] = NPC(id, npcName)
    end

    return setmetatable({}, {
        __index = function(_, key)
            local t = targets[1]
            return t and t[key]
        end,
        __newindex = function(_, key, value)
            for _, t in ipairs(targets) do
                t[key] = value
            end
        end,
    })
end

-- KHAZ ALGAR

SetZone("Dornogal, Khaz Algar")

    local t = NPC(206017, "Brann Bronzebeard")
    t[123770] = { text = "I'd like to join the reinforcements. \r\n|cFFFF0000 <Skip the level-up campaign.> |r", type = "" }
    t[123771] = { text = "I'd like to join the reinforcements. \r\n|cFFFF0000 <Skip the level-up campaign.> |r", type = "" }

    local t = NPC(227675, "Delver's Guide")
    t[123493] = { text = "<Review information on your current delve progress.>", type = "" }

    local t = NPC(212370, "Ronesh")
    t[121503] = { text = "I want to browse your goods.", type = "" }


SetZone("Hallowfall, Khaz Algar")

    local t = NPC(220293, "Aliya Hillhelm")
    t[121536] = { text = "(Delve) I'll get your pigs back and make those fungarians pay for this.", type = "" }

    local t = NPC(220354, "Chef Dinaire")
    t[121539] = { text = "(Delve) I love scavenger hunts AND treasure. I'm in!", type = "" }
    t[121541] = { text = "(Delve) Go get the treasure while I handle whatever is about to attack us.", type = "" }

    local t = NPC(220585, "Lamplighter Havrik Chayvn")
    t[121408] = { text = "(Delve) I'll go deeper in and stop the nerubian ritual.", type = "" }

    local t = NPC(248927, "Zah'ran")
    t[135013] = { text = "Show me.", type = "" }

SetZone("Azj-Kahet, Khaz Algar")

    local t = NPC(220462, "Weaver's Instructions")
    t[121566] = { text = "(Delve) <Close the scroll and take the Weaver's web grappling hook.>", type = "" }


