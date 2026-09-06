local _, ns = ...

ns.db = ns.db or {}
ns.db.rules = ns.db.rules or {}

-- XPEV database pack
-- Add rules like:
-- ns.db.rules[123456] = ns.db.rules[123456] or {}
-- ns.db.rules[123456].__meta = { zone = "Zone, Continent", npc = "NPC Name" }
-- ns.db.rules[123456][98765] = { text = [[Option text]] }
--   pcn = "Name-Realm"   -- only if you are this character
--   pcn = {"Name-Realm", "Alt-Realm"} -- only if you are ANY of these characters

local H = ns.TalkDB
local t
local SetZone, NPC, MAP = H.SetZone, H.NPC, H.MAP

SetZone("Everywhere")

   t = NPC("Delve-o-Bot 7001", {232267,})
   t[140192] = { text = "Take me to a Midnight delve please.", prio = 10, }
   t[140193] = { text = "Take me to a Khaz Algar delve please.", prio = 01, }

   t = NPC("Katy Stampwhistle", {132969,})
   t[48598] = { text = "I'd like to check my mail." }

   t = NPC("Child of Ohn'ahra", {191869,})
   t[55193] = { text = "I'd like to check my mail." }

   SetZone("Darkmoon Island")

    t = NPC("Christoph VonFeasel", { 85519 })
    t[42667] = { text = "I challenge you to a pet battle!" }						-- A New Darkmoon Challenger! (36471) Christoph VonFeasel (85519)

	t = NPC("Darkmoon Faire Mystic Mage", 54334)									-- Stormwind Mystic Mage
	t.__meta.stopIfQuestAvailable = { 7905, 7926, }									-- Quest Accept before Gossip (First NPCID)
	t[40457] = { text = "Take me to the faire...", xpop = { which = "GOSSIP_CONFIRM", containsAny = { "Travel to the faire staging area" }, within = 3, }, }

	t = NPC("Darkmoon Faire Mystic Mage", 55382)																	-- Orgrimmar Mystic Mage
	t.__meta.stopIfQuestAvailable = { 7905, 7926, }									-- Quest Accept before Gossip (First NPCID)
	t[40007] = { text = "Take me to the faire...", xpop = { which = "GOSSIP_CONFIRM", containsAny = { "Travel to the faire staging area" }, within = 3, }, }

    t = NPC("Jeremy Feasel", { 67370 })
    t[41758] = { text = "I challenge you to a pet battle!" }						-- Darkmoon Pet Battle! (32175) Jeremy Feasel (67370)

	t = NPC("Stamp Thunderhorn", 14845)
   	t.__meta.stopIfQuestAvailable = { 29509, 29513, }                           	-- Quest Accept before Gossip (First NPCID)
   	t.__meta.stopIfQuestTurnIn = { 29509, 29513, }                              	-- Quest TurnIn before Gossip (First NPCID)
	t[31263] = { text = "Mmm... food.", xvend = 15 }								-- A Delicious Recipe (29509) Stamp Thunderhorn (14845)
	-- fix xvend so it closes vendor windows after the timer period
SetZone("Timewalking")
--	01	Classic Timewalking Vendor
	t = NPC("Bobadormu", 234555) -- Vendor Only Not Quest Giver/Hand In 93607
	t.__meta.stopIfQuestAvailable = { 85947, 93607, }		-- LVL/MAX				-- Quest Accept before Gossip (First NPCID)
	t.__meta.stopIfQuestTurnIn = { 85947, 83285, }      	-- LVL/TKN				-- Quest TurnIn before Gossip (First NPCID)
	t[131294] = { text = "Let me browse your goods." }								-- Bobadormu (226162) Vendor Only
--	02	Outland Timewalking Vendor
	t = NPC("Cupri", 98685)
	t.__meta.stopIfQuestAvailable = { 85948, 93608, }		-- LVL/MAX          	-- Quest Accept before Gossip (First NPCID)
	t.__meta.stopIfQuestTurnIn = { 85948, 40168, }      	-- LVL/TKN          	-- Quest TurnIn before Gossip (First NPCID)
	t[46752] = { text = "I would like to buy from you." }							-- Cupri (98685)
--	03	Wrath Timewalking Vendor
	t = NPC("Auzin", 98690)
	t.__meta.stopIfQuestAvailable = { 85949, 93610, }		-- LVL/MAX          	-- Quest Accept before Gossip (First NPCID)
	t.__meta.stopIfQuestTurnIn = { 85949, 40173, }      	-- LVL/TKN          	-- Quest TurnIn before Gossip (First NPCID)
	t[44404] = { text = "I would like to buy from you." }							-- Auzin (98690)
--	04	Cataclysm Timewalking Vendor
	t = NPC("Kiatke", 101759)
	t.__meta.stopIfQuestAvailable = { 86556, 83359, }		-- LVL/MAX          	-- Quest Accept before Gossip (First NPCID)
	t.__meta.stopIfQuestTurnIn = { 86556, 40786, 40787, }   -- LVL/TKN          	-- Quest TurnIn before Gossip (First NPCID)
	t[46752] = { text = "I would like to buy from you." }							-- Kiatke (101759)
--	05	Pandaria Timewalking Vendor
	t = NPC("Mistweaver Xia", 118828)
	t.__meta.stopIfQuestAvailable = { 86560, 93612, }		-- LVL/MAX          	-- Quest Accept before Gossip (First NPCID)
	t.__meta.stopIfQuestTurnIn = { 86560, 45563, }      	-- LVL/TKN          	-- Quest TurnIn before Gossip (First NPCID)
	t[46752] = { text = "I would like to buy from you." }							-- Mistweaver Xia (118828)
--	06	Warlords Timewalking Vendor Alliance
	t = NPC("Tempra", 151955)
	t.__meta.stopIfQuestAvailable = { 86563, 93613, }		-- LVL/MAX          	-- Quest Accept before Gossip (First NPCID)
	t.__meta.stopIfQuestTurnIn = { 86563, 55498, }      	-- LVL/TKN          	-- Quest TurnIn before Gossip (First NPCID)
	t[49470] = { text = "I would like to buy from you" }							-- Tempra (151955)
--	06	Warlords Timewalking Vendor Horde
	t = NPC("Kronnus", 151987)
	t.__meta.stopIfQuestAvailable = { 86563, 93613, }		-- LVL/MAX          	-- Quest Accept before Gossip (First NPCID)
	t.__meta.stopIfQuestTurnIn = { 86563, 55499, }      	-- LVL/TKN          	-- Quest TurnIn before Gossip (First NPCID)
	t[49471] = { text = "I would like to buy from you" }							-- Kronnus (151987)
--	07	Legion Timewalking Vendor
	t = NPC("Aridormi", 180899)
	t.__meta.stopIfQuestAvailable = { 86564, 93614, }		-- LVL/MAX          	-- Quest Accept before Gossip (First NPCID)
	t.__meta.stopIfQuestTurnIn = { 86564, 64710, }      	-- LVL/TKN          	-- Quest TurnIn before Gossip (First NPCID)
	t[46752] = { text = "I would like to buy from you" }							-- Aridormi (180899)
--	08	Battle Timewalking Vendor Alliance
	t = NPC("Churbro", 238320)
	t.__meta.stopIfQuestAvailable = { 88808, 93627, }		-- LVL/MAX          	-- Quest Accept before Gossip (First NPCID)
	t.__meta.stopIfQuestTurnIn = { 88808, 89222, 89223, }	-- LVL/TKN          	-- Quest TurnIn before Gossip (First NPCID)
	t[46752] = { text = "I would like to buy from you" }							-- Churbro (238320)
--	09	Shadowlands Timewalking Vendor
	t = NPC("Collector Ta'steld", 252687)
	t.__meta.stopIfQuestAvailable = { 92647, 93628, }		-- LVL/MAX          	-- Quest Accept before Gossip (First NPCID)
	t.__meta.stopIfQuestTurnIn = { 92647, 92650, }      	-- LVL/TKN          	-- Quest TurnIn before Gossip (First NPCID)
	t[136178] = { text = "I would like to buy from you" }							-- Collector Ta'steld (252687)
--	10	Dragonflight Timewalking Vendor
	t = NPC("Xydan", 255019)
	t.__meta.stopIfQuestAvailable = { 93495, 93497, }		-- LVL/MAX          	-- Quest Accept before Gossip (First NPCID)
	t.__meta.stopIfQuestTurnIn = { 93495, 93852, }       	-- LVL/TKN          	-- Quest TurnIn before Gossip (First NPCID)
	t[137092] = { text = "I would like to buy from you" }							-- Xydan (255019)

SetZone("Nablegarden")

   t = NPC("Noblegarden Merchant", 32837)
   t.__meta.stopIfQuestAvailable = { 13503, }										-- Quest Accept before Gossip (First NPCID)
   t.__meta.stopIfQuestTurnIn = { 13503, }											-- Quest TurnIn before Gossip (First NPCID)
   t[37187] = { text = "I want to browse your goods." }

   t = NPC("Noblegarden Vendor", 124617)
   t.__meta.stopIfQuestAvailable = { 13502, }										-- Quest Accept before Gossip (First NPCID)
   t.__meta.stopIfQuestTurnIn = { 13502, }											-- Quest TurnIn before Gossip (First NPCID)
   t[37187] = { text = "I want to browse your goods." }

   t = NPC("Emmery Fiske", 216129)
   t[121089] = { text = "Zinnia sent me...", qil = 79323, close = true }

   t = NPC("Tethris Dewgazer", 217147)
	t[120851] = { prio = 10, text = "Sylnaria sent me...", qil = 79576, close = true }								-- A Fowl Concoction (79576) Tethris Dewgazer (217147)

