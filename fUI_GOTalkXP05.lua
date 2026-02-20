local _, ns = ...

ns.db = ns.db or {}
ns.db.rules = ns.db.rules or {}

-- XP05 database pack
-- Add rules like:
-- ns.db.rules[123456] = ns.db.rules[123456] or {}
-- ns.db.rules[123456].__meta = { zone = "Zone, Continent", npc = "NPC Name" }
-- ns.db.rules[123456][98765] = { text = [[Option text]], type = "", xpop = { which = "GOSSIP_CONFIRM", containsAny = {"prepare yourself", "let's rumble"}, within = 3 } }
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

-- PANDARIA

SetZone("Kun-Lai Summit, Pandaria")

    local t = NPC( 68465, "Thundering Pandaren Spirit")
    t[41955] = { text = "Another challenge?", xpop = { which = "GOSSIP_CONFIRM", containsAny = { "prepare yourself" }, within = 3, }, type = "", }

    local t = NPC(176655, "Anthea")
    t[52501] = { text = "Let's rumble!", xpop = { which = "GOSSIP_CONFIRM", containsAny = { "let's rumble", }, within = 3, }, type = "", }

SetZone("Townlong Steppes, Pandaria")

    local t = NPC( 68463, "Burning Pandaren Spirit")
    t[41951] = { text = "Another challenge?", xpop = { which = "GOSSIP_CONFIRM", containsAny = { "prepare yourself" }, within = 3, }, type = "", }


