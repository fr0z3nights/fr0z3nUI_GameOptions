local _, ns = ...

ns.db = ns.db or {}
ns.db.rules = ns.db.rules or {}

-- XP09 database pack
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

-- SHADOWLANDS

SetZone("Oribos, Shadowlands")

    local t = NPC(168252, "Protector Captain")
    t[53754] = { text = "Where am I? Have I escaped the Maw?", type = "" }

   local t = NPC( 167425, "Overseer Kah-Delen")
   t[131497] = { text = "I've been here before. <Skip the level up campaign and unlock world content.>", xpop = { which = "GOSSIP_CONFIRM", containsAny = { "are you sure", "cannot be undone" }, within = 3, }, type = "", }


