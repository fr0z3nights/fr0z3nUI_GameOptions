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

SetZone("Dread Wastes, Pandaria")

    local t = NPC( 66739, "Wastewalker Shu")
    t[41822] = { text = "Think you can take me in a pet battle? Let's fight!", xpop = { which = "GOSSIP_CONFIRM", containsAny = { "Prepare yourself!" }, within = 3, }, type = "", }

SetZone("Krasarang Wilds, Pandaria")

    local t = NPC( 66733, "Mo'ruk")
    t[41816] = { text = "Think you can take me in a pet battle? Let's fight!", xpop = { which = "GOSSIP_CONFIRM", containsAny = { "Come at me!" }, within = 3, }, type = "", }

SetZone("Kun-Lai Summit, Pandaria")

    local t = NPC( 68465, "Thundering Pandaren Spirit")
    t[41955] = { text = "Another challenge?", xpop = { which = "GOSSIP_CONFIRM", containsAny = { "prepare yourself" }, within = 3, }, type = "", }

    local t = NPC(176655, "Anthea")
    t[52501] = { text = "Let's rumble!", xpop = { which = "GOSSIP_CONFIRM", containsAny = { "let's rumble", }, within = 3, }, type = "", }

SetZone("Townlong Steppes, Pandaria")

    local t = NPC( 68463, "Burning Pandaren Spirit")
    t[41951] = { text = "Another challenge?", xpop = { which = "GOSSIP_CONFIRM", containsAny = { "prepare yourself" }, within = 3, }, type = "", }

    local t = NPC( 66918, "Seeker Zusshi")
    t[41155] = { text = "Think you can take me in a pet battle? Let's fight!", xpop = { which = "GOSSIP_CONFIRM", containsAny = { "You don't stand a chance!" }, within = 3, }, type = "", }

SetZone("Vale of Eternal Blossoms, Pandaria")

    local t = NPC( 66741, "Aki the Chosen")
    t[41824] = { text = "Think you can take me in a pet battle? Let's fight!", xpop = { which = "GOSSIP_CONFIRM", containsAny = { "You're going down!" }, within = 3, }, type = "", }


