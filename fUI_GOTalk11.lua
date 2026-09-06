local _, ns = ...

ns.db = ns.db or {}
ns.db.rules = ns.db.rules or {}

--   pcn = "Name-Realm"   -- only if you are this character
--   pcn = {"Name-Realm", "Alt-Realm"} -- only if you are ANY of these characters
local H = ns.TalkDB
local t
local SetZone, NPC, MAP = H.SetZone, H.NPC, H.MAP
local TalkCacheSeen, GetCharacterCacheKey = H.TalkCacheSeen, H.GetCharacterCacheKey
local GetViewGossipState = H.GetViewGossipState

SetZone("Azj-Kahet, Khaz Algar")

	t = NPC("Weaver's Instructions", 220462)
	t[121566] = { text = "(Delve) <Close the scroll and take the Weaver's web grappling hook.>" }

SetZone("Dornogal, Khaz Algar")

	t = NPC("Brann Bronzebeard", 206017)
	t[123770] = { text = "I'd like to join the reinforcements. \r\n|cFFFF0000 <Skip the level-up campaign.> |r" }
	t[123771] = { text = "I'd like to join the reinforcements. \r\n|cFFFF0000 <Skip the level-up campaign.> |r" }

	t = NPC("Breem", {212369,})
	t[120910] = { text = "Show me where I can fly." }

	t = NPC("Delver's Guide", 227675)
	t[123493] = { text = "<Review information on your current delve progress.>" }

	t = NPC("Ronesh", 212370)
	t[121503] = { text = "I want to browse your goods." }

    t = NPC("Skymaster Sunwing", 16189)
    t[34101] = { text = "I'd like to fly back to Silvermoon City." }

	SetZone("Hallowfall, Khaz Algar")

	t = NPC("Aliya Hillhelm", 220293)
	t[121536] = { text = "(Delve) I'll get your pigs back and make those fungarians pay for this." }

	t = NPC("Chef Dinaire", 220354)
	t[121539] = { text = "(Delve) I love scavenger hunts AND treasure. I'm in!" }
	t[121541] = { text = "(Delve) Go get the treasure while I handle whatever is about to attack us." }

	t = NPC("Lamplighter Havrik Chayvn", 220585)
	t[121408] = { text = "(Delve) I'll go deeper in and stop the nerubian ritual." }

	t = NPC("Zah'ran", 248927)
	t[135013] = { text = "Show me." }

SetZone("The Ringing Deeps, Khaz Algar")

	t = NPC("Aberee", {225588,})
	t[123394] = { text = "What happened here?" }
	t[123393] = { text = "Thanks for the info." }

	t = NPC("Clive DelGizmo", {216311,})
	t.__meta.stopIfQuestAvailable = { 83766, }															-- First NPCID, Stops Gossip until quest is accepted
	t.__meta.stopIfQuestTurnIn = { 83766, }																-- First NPCID, Stops Gossip until quest is accepted
	t[122698] = { text = "What do you have for sale?" }

	t = NPC("\"Conspiracy Theory\" Binni", {232473,})
	t[124900] = { text = "What are all these spies trying to find?" }
	t[124901] = { text = "Pamsy?" }

	t = NPC("Fishcan", {218948,})
	t[124437] = { text = "Please teach me how to fish." }

	t = NPC("Glizza", {232453,232547})
	t[124962] = { text = "Pamsy sent me. The Pump Station's safe!" }
	t[124930] = { text = "I'm sorry, Glizza." }

	t = NPC("Clixi Fastfare", {224884,})
	t[122682] = { text = "Show me where I can fly." }

	t = NPC("Greedy Turncoat", {225768,})
	t[132096] = { text = "You're spying for Gallywix, admit it!" }

	t = NPC("Ishqikle", {227710,})
	t[123396] = { text = "What's the job here?" }
	t[123395] = { text = "Thanks for the info." }

	t = NPC("Keeble", {228138,})
	t[124904] = { text = "Can you tell us what's going on here in Gutterville.", prio = 10, }
	t[132770] = { text = "What do you have for sale?.", prio = 01, }

	t = NPC("Keets", {232454,232546,})
	t[124963] = { text = "Pamsy sent me. The Pump Station's safe!." }
	t[124929] = { text = "Somebody Should!." }

	t = NPC("Razi", {232455,232545,})
	t[124964] = { text = "Pamsy sent me. The Pump Station's safe!." }
	t[124928] = { text = "That's awful." }

	t = NPC("Sparring Squireling", {229938,})
	t[124386] = { text = "Challenge the squire to a sparring match." }

	t = NPC("Tollbooth Entrepreneur", {225536,})
	t[124980] = { text = "We'd like to go to the mining camp." }

	t = NPC("Trella", {227711,})
	t[123398] = { text = "What can you tell me about the Darkfuse?" }
	t[123397] = { text = "Thanks for the info." }

	t = NPC("Zirdo", {232836,228017,225590,})
	t[124999] = { text = "I'd like to learn more about the process here." }
	t[123518] = { text = "<Begin the tour.>" }
	t[125018] = { text = "<Continue the tour.>" }

SetZone("K'aresh, Khaz Algar")

	t = NPC("Adarus Duskblaze", {236907, 246325})
	t[134065] = { text = "Can you tell me where Umbric's apprentice went?", close = true }
	t[133876] = { text = "<Report on Leona's success in harvesting Ramon'ta's void essence.>", close = true }
	t[132974] = { text = "Are you ready, Adarus?", close = true }

	t = NPC("Magister Umbric", 248153)
	t[134092] = { text = "<Listen to Leona's report.>", close = true }

SetZone("Undermine, Khaz Algar")

	t = NPC("Baxx the Purveyor", {237703,})
    t[131873] = { text = "Begin pet battle.", prio = 10, mount = true, close = true,}
	t[131874] = { text = "Want to trade some pet charms?", prio = -9, close = true }

	t = NPC("Creech", {237718,})
    t[131878] = { text = "Begin pet battle.", prio = 10, mount = true, close = true,}
	t[131879] = { text = "Want to trade some pet charms?", prio = -9, close = true }

	t = NPC("Prezly Wavecutter", {237712,})
    t[131876] = { text = "Begin pet battle.", prio = 10, mount = true, close = true,}
	t[131877] = { text = "Want to trade some pet charms?", prio = -9, close = true }

