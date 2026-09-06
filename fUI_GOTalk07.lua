local _, ns = ...

ns.db = ns.db or {}
ns.db.rules = ns.db.rules or {}

-- XP07 database pack
-- Add rules like:
-- ns.db.rules[123456] = ns.db.rules[123456] or {}
-- ns.db.rules[123456].__meta = { zone = "Zone, Continent", npc = "NPC Name" }
-- ns.db.rules[123456][98765] = { text = [[Option text]] }
--   pcn = "Name-Realm"   -- only if you are this character
--   pcn = {"Name-Realm", "Alt-Realm"} -- only if you are ANY of these characters

local H = ns.TalkDB
local t
local SetZone, NPC, MAP = H.SetZone, H.NPC, H.MAP
local TalkCacheSeen, GetCharacterCacheKey = H.TalkCacheSeen, H.GetCharacterCacheKey
local GetViewGossipState = H.GetViewGossipState

SetZone("Dalaran, Broken Isles")

	t = NPC("Archmage Khadgar", {90417,})
	t.__meta.stopIfQuestAvailable = { 45727, }                                  -- Quest Accept before Gossip (First NPCID)
	t.__meta.stopIfQuestTurnIn = { 45727, }                               		-- Quest TurnIn before Gossip (First NPCID)
	t[134576] = { text = "Argus Intro Skip", xpop = { which = "GOSSIP_CONFIRM", containsAny = { "Are you sure" }, within = 3, } }

	t = NPC("Holgar Stormaxe", 4311)
	t.__meta.stopIfQuestAvailable = { 44281, }                                  -- Quest Accept before Gossip (First NPCID)
	t.__meta.stopIfQuestTurnIn = { 43926, }                               		-- Quest TurnIn before Gossip (First NPCID)
	t[47485] = { text = "I've heard this tale before... <Skip>", xpop = { which = "GOSSIP_CONFIRM", containsAny = { "Are you sure" }, within = 3, } }

	t = NPC("Manapoof", 121602)
	t[47010] = { prio = 10, text = "Stratholme", qil = {86839, 86841,} }
	t[47009] = { prio = 09, text = "Gnomeregan", pcn = "Shadowspiner-Dath'Remar" }
--  t[47007] = { prio = 09, text = "Wailing Caverns?" }
--  t[47008] = { prio = 09, text = "Deadmines?" }
--  t[47011] = { prio = 09, text = "Blackrock Depths!" }

SetZone("Highmountain, Broken Isles")

	t = MAP("Dungeon: Neltharion's Lair", 1472)
   	t[49796] = { text = "I am ready." }
   	t[49828] = { text = "I am ready to go." }

	t = NPC("Navarrogg", 151643)
	t[51054] = { text = "I am ready to go." }

	t = NPC("Spiritwalker Ebonhorn", 151641)
	t[51053] = { text = "I'm investigating unusual magical activity in the area.", qil = 55374 }



