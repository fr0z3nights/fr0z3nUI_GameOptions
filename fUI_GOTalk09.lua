local _, ns = ...

ns.db = ns.db or {}
ns.db.rules = ns.db.rules or {}

-- XP09 database pack
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

SetZone("Maldraxxus, Shadowlands")

    t = NPC("Vandellor", {176932})
	t[54479] = { text = "I'm ready to race." }

SetZone("Maldraxxus, Shadowlands")

    t = NPC("Fightlord San", {176915, 176918,})
	t[54481] = { text = "I'm ready to fight!" }
	t[54480] = { text = "Take me back down." }

    t = NPC("Wing Guard Alamar", 157540)
    t[34833] = { text = "Show me where I can fly." }

SetZone("Oribos, Shadowlands")

    t = NPC("Pathscribe Roh-Avonavi", 162666)
    t[52885] = { text = "Show me all my travel options." }

    t = NPC("Protector Captain", 168252)
    t[53754] = { text = "Where am I? Have I escaped the Maw?" }

   t = NPC("Overseer Kah-Delen", 167425)
   t[131497] = { text = "I've been here before. <Skip the level up campaign and unlock world content.>", xpop = { which = "GOSSIP_CONFIRM", containsAny = { "are you sure", "cannot be undone" }, within = 3, }, }


