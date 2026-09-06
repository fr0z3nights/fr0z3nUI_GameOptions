local _, ns = ...

ns.db = ns.db or {}
ns.db.rules = ns.db.rules or {}

-- XP06 database pack
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

SetZone("Frostifre Ridge, Draenor")

	t = NPC("Gargra", 87122)
    t[42881] = { text = "Let's do this!", mount = true, }

    t = NPC("Senior Peon II", 86775)
    t[43217] = { text = "Gazlowe needs you.", close = true }					-- What We Got (34824) Senior Peon II (86775)

    t = NPC("Skaggit", 80225)
    t[42535] = { text = "Get the peons back to work.", close = true }		-- What We Got (34824) Skaggit (80225)

SetZone("Gorgrond, Draenor")

    t = NPC("Cymre Brightblade", 83837)
    t[42651] = { text = "Let's do battle!", mount = true, }

SetZone("Nagrand, Draenor")

    t = NPC("Tarr the Terrible", 87110)
    t[42882] = { text = "Let's do this!", mount = true, }

SetZone("Shadowmoon Valley, Draenor")

    t = NPC("Ashlei", 87124)
    t[43294] = { text = "Let's do this!", mount = true }

    t = NPC("Baros Alexston", 79243)
    t[43035] = { text = "We have everything we need. It's time to build the garrison." }

SetZone("Talador, Draenor")

    t = NPC("Taralune", 87125)
    t[42883] = { text = "Let's do this!", mount = true }

SetZone("Spires of Arak, Draenor")

    t = NPC("Kuro'ak <Innkeeper>", 86386)
    t[43234] = { text = "Let me browse your goods." }

    t = NPC("Skytalon Meshaal", 84498)
    t[42904] = { text = "Show me where I can fly." }

    t = NPC("Vesharr", 87123)
    t[43292] = { text = "Lets do battle!", mount = true }

SetZone("Warspear, Draenor")

SetZone("Garrison, Draenor")

    t = NPC("Assistant Brightstone", 84455)
    t[42666] = { text = "Time to get back to work.", close = true }					-- Keeping it Together (35176) Assistant Brightstone (84455)

    t = NPC("Assistant Brightstone", 84455)
    t[42666] = { text = "Time to get back to work.", close = true }					-- Keeping it Together (35176) Assistant Brightstone (84455)

    t = NPC("Dungar Longdrink", 81103)												-- Alliance
    t[42834] = { text = "Show me where I can fly." }

    t = NPC("Rachelle Black", 81348)
    t[42786] = { text = "Let me browse your goods." }								-- Vendor Rachelle Black (81348)

    t = NPC("Shelly Hamby", 81441)
    t[42677] = { text = "Gather Shelly's report.", close = true }					-- Keeping it Together (35176) Shelly Hamby (81441)

    -- System/helper entry (not tied to real gossip). Used as a toggle in the Talk tab.
    -- NOTE: This uses a fake NPC ID so it will never match real gossip.
    t = NPC("Garrison Mission Table", -32000)
    t[1] = { text = "Auto-start first mission (tutorial quest)" }



