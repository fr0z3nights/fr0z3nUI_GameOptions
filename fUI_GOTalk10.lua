local _, ns = ...

ns.db = ns.db or {}
ns.db.rules = ns.db.rules or {}

-- XP10 database pack
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

SetZone("Amirdrassil, Dragon Isles")

    t = NPC("Elder Verdantbark", { 251316, })
    t[137249] = { text = "<Present throwing stones to Elder Verdantbark.>" }	-- Awaken the Ancient Protector (88927) Elder Verdantbark (251316)

	t = NPC("First Arcanist Thalyssra", { 250853, })
    t[135657] = { text = "Tell Shandris what has transpired." }	-- Children of the Stars (88923) First Arcanist Thalyssra (250853)

    t = NPC("Lor'themar Theron", { 240335, })
    t[135655] = { text = "Tell Shandris what has transpired." }	-- Children of the Stars (88923) Lor'themar Theron (240335)

    t = NPC("Magister Umbric", { 253613, })
    t[135656] = { text = "Tell Shandris what has transpired." }	-- Children of the Stars (88923) Magister Umbric (253613)

    t = NPC("Malastral", { 255687, })
    t[137236] = { text = "Give me the banner and I will gather the wisps." }	-- Awaken the Ancient of Lore (88937) Malastral (255687)

SetZone("Thaldraszus, Dragon Isles")

	t = MAP("Vault of the Incarnates", { 2119, })
	t[107543] = { text = "We have need of your aid." }
	t[107544] = { text = "Carry me into battle." }
	t[107545] = { text = "Carry me into battle." }
	t[107546] = { text = "We have need of your aid." }
	t[107548] = { text = "<You gently prod the dragon awake.>" }
	t[107549] = { text = "Carry me into battle." }
	t[107550] = { text = "We have need of your aid." }
	t[107551] = { text = "Carry me into battle." }
	t[107552] = { text = "We have need of your aid." }
	t[107553] = { text = "Carry me into battle." }
	
    t[ 55981] = { text = "Begin the assault.", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "This will begin the assault" }, within = 3, }, }

SetZone("The Azure Span, Dragon Isles")

	t = MAP("The Azure Vault Dungeon", { 2074, 2075, 2076, })
	t[56056] = { text = "Proceed onward." }
	t[56247] = { text = "Proceed onward." }
	t[56248] = { text = "Proceed onward." }
	t[56250] = { text = "Proceed onward." }
	t[56250] = { text = "Proceed onward." }
	t[56251] = { text = "Proceed onward." }

	t = NPC("Tattukiaka", { 199448, })
	t[107742] = { text = "Let's see what you have on offer." }	-- Awaken the Ancient Protector (88927) Tattukiaka (199448)

SetZone("The Forbidden Reach, Dragon Isles")

    t = NPC("Zone NPCs", { 184165, 182610, 182611, })
    t[51921] = { text = "Come with me. I will get you to safety." }	-- Halp! (65071)		Little Ko (184165)
    t[51849] = { text = "Come with me. I will get you to safety." }	-- Final Orders (65100)	Scalecommander Viridia (182610)
    t[51850] = { text = "<Relay what Nozdormu told you.>" }			-- Final Orders (65100)	Scalecommander Sarkareth (182611)

SetZone("The Waking Shores, Dragon Isles")

	t = NPC("Danielle Anglers", { 191150, })
	t[107425] = { text = "Train me in Fishing." }

	t = NPC("Grun Ashbeard", { 187261, })
	t.__meta.stopIfQuestAvailable = { 70028, }                                                     		  -- Waits for Quest Accepted (First NPCID Only)
	t[107293] = { text = "Train me in Mining." }

	t = NPC("Head Chef Stacks", { 198094, })
	t.__meta.stopIfQuestAvailable = { 72250, }                                                     		  -- Waits for Quest Accepted (First NPCID Only)
	t[107418] = { text = "Can you, um... teach me how to cook?" }

	t = NPC("Tixxa Mixxa", { 192490, })
	t[34833] = { text = "Show me where I can fly." }

	t = NPC("Toninaar", { 192558, })
	t[56062] = { text = "Train me in Fishing." }


