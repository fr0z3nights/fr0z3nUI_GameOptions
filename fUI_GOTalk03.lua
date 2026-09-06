local _, ns = ...

ns.db = ns.db or {}
ns.db.rules = ns.db.rules or {}

-- XP03 database pack
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

SetZone("Crystalsong Forest, Northrend")

	t = NPC("Uda the Beast <Innkeeper>", {28791,})
	t[37158] = { text = "Let me browse your goods.", prio = -5 }
	t[37157] = { text = "HOLD SHIFT TO BIND HEARTHSTONE MANUALLY", xpop = { which = "GOSSIP_CONFIRM", containsAll = { "do you want to make", "your new home" }, within = 3, }, prio = -10, noAuto = true }

	t = NPC("Nearly Headless Jacob", {66636,})
	t[41230] = { text = "Think you can take me in a pet battle? Let's fight!", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "Come at me" }, within = 3, }, close = true,}

SetZone("Dragonblight, Northrend")

	t = NPC("Caregiver Mumik <Innkeeper>", {27174,})
	t[35931] = { text = "Let me browse your goods.", prio = -5 }
	t[35930] = { text = "HOLD SHIFT TO BIND HEARTHSTONE MANUALLY", xpop = { which = "GOSSIP_CONFIRM", containsAll = { "do you want to make", "your new home" }, within = 3, }, prio = -10, noAuto = true }

	t = NPC("Okrut Dragonwaste", {66638,})
	t[41232] = { text = "Think you can take me in a pet battle? Let's fight!", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "Let's do it" }, within = 3, }, close = true,}

SetZone("Howling Fjord, Northrend")

	t = NPC("Barracks Master Rhekku <Innkeeper>", {27125,})
	t[35047] = { text = "Let me browse your goods.", prio = -5 }
	t[35046] = { text = "HOLD SHIFT TO BIND HEARTHSTONE MANUALLY", xpop = { which = "GOSSIP_CONFIRM", containsAll = { "do you want to make", "your new home" }, within = 3, }, prio = -10, noAuto = true }

	t = NPC("Beegle Blastfuse", {66635,})
	t[41228] = { text = "Think you can take me in a pet battle? Let's fight!", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "You don't stand a chance" }, within = 3, }, close = true,}

SetZone("Icecrown, Northrend")

	t = NPC("Major Payne", {66675,})
	t[40769] = { text = "Think you can take me in a pet battle? Let's fight!", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "You're on" }, within = 3, }, close = true,}

SetZone("Zul'Drak, Northrend")

	t = NPC("Marissa Everwatch <Innkeeper>", {28791,})
	t[37168] = { text = "Let me browse your goods.", prio = -5 }
	t[37167] = { text = "HOLD SHIFT TO BIND HEARTHSTONE MANUALLY", xpop = { which = "GOSSIP_CONFIRM", containsAll = { "do you want to make", "your new home" }, within = 3, }, prio = -10, noAuto = true }

	t = NPC("Gutretch", {66639,})
	t[41234] = { text = "Think you can take me in a pet battle? Let's fight!", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "Bring it on" }, within = 3, }, close = true,}

	t = NPC("Maaka", 28624)
    t[36716] = { text = "Show me where I can fly." }


