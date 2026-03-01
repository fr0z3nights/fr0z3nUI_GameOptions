local _, ns = ...

ns.db = ns.db or {}
ns.db.rules = ns.db.rules or {}

-- XP06 database pack
-- Add rules like:
-- ns.db.rules[123456] = ns.db.rules[123456] or {}
-- ns.db.rules[123456].__meta = { zone = "Zone, Continent", npc = "NPC Name" }
-- ns.db.rules[123456][98765] = { text = [[Option text]], type = "" }
-- (Per-rule overrides still supported: zoneName/zone, npcName/npc)

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


SetZone("Gorgrond, Draenor")

    local t = NPC( 83837, "Cymre Brightblade")
    t[42651] = { text = "Let's do battle!", xpop = { which = "GOSSIP_CONFIRM", containsAny = { "Come at me!" }, within = 3, }, type = "", }

SetZone("Shadowmoon Valley, Draenor")

    local t = NPC(79243, "Baros Alexston")
    t[43035] = { text = "We have everything we need. It's time to build the garrison.", type = "" }

SetZone("Talador, Draenor")

    local t = NPC(87125, "Taralune")
    t[42883] = { text = "Let's do this!", type = "" }

SetZone("Garrison, Draenor")

    -- System/helper entry (not tied to real gossip). Used as a toggle in the Talk tab.
    -- NOTE: This uses a fake NPC ID so it will never match real gossip.
    local t = NPC(-32000, "Garrison Mission Table")
    t[1] = { text = "Auto-start first mission (tutorial quest)", type = "" }

