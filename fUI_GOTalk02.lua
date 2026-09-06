local _, ns = ...

ns.db = ns.db or {}
ns.db.rules = ns.db.rules or {}

-- XP02 database pack
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

SetZone("Hellfire Peninsula, Outland")

   	t = NPC("Floyd Pinkus <Innkeeper>", {16602,})
   	t[30613] = { text = "Let me browse your goods.", prio = -5 }
   	t[30612] = { text = "HOLD SHIFT TO BIND HEARTHSTONE MANUALLY", xpop = { which = "GOSSIP_CONFIRM", containsAll = { "do you want to make", "your new home" }, within = 3, }, prio = -10, noAuto = true }

	t = NPC("Nicki Tinytech", {66550,})
    t[41046] = { text = "Let's rumble!", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "You don't stand a chance" }, within = 3, }, close = true,}

SetZone("Nagrand, Outland")

	t = NPC("Narrok", {66552,})
    t[41751] = { text = "Let's rumble!", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "Bring it on" }, within = 3, }, close = true,}

SetZone("Shadowmoon Valley, Outland")

	t = NPC("Bloodknight Antari", {66557,})
    t[41753] = { text = "Let's rumble!", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "You don't stand a chance" }, within = 3, }, close = true,}

SetZone("Shattrath City, Outland")

   	t = NPC("Haelthol <Innkeeper>", {19232,})
   	t[35008] = { text = "Let me browse your goods.", prio = -5 }
   	t[35007] = { text = "HOLD SHIFT TO BIND HEARTHSTONE MANUALLY", xpop = { which = "GOSSIP_CONFIRM", containsAll = { "do you want to make", "your new home" }, within = 3, }, prio = -10, noAuto = true }

	t = NPC("Morulu The Elder", {66553,})
    t[40903] = { text = "Let's rumble!", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "Let's do it" }, within = 3, }, close = true,}

SetZone("Zangarmarsh, Outland")

   	t = NPC("Merajit <Innkeeper>", {18245,})
   	t[31892] = { text = "Let me browse your goods.", prio = -5 }
   	t[31891] = { text = "HOLD SHIFT TO BIND HEARTHSTONE MANUALLY", xpop = { which = "GOSSIP_CONFIRM", containsAll = { "do you want to make", "your new home" }, within = 3, }, prio = -10, noAuto = true }

	t = NPC("Ras'an", {66551,})
    t[40901] = { text = "Think you can take me in a pet battle? Let's fight!", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "Let's rumble" }, within = 3, }, close = true,}

