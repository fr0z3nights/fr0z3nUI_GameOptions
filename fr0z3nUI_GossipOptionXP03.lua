local _, ns = ...

ns.db = ns.db or {}
ns.db.rules = ns.db.rules or {}

-- XP03 database pack
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

-- NORTHREND

--SetZone("Dornogal, Khaz Algar")

   -- Delver's Guide
        --local t = NPC(227675, "Delver's Guide")
        --t[123493] = { text = "<Review information on your current delve progress.>", type = "" }


