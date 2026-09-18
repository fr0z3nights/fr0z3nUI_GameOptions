---@diagnostic disable: undefined-global

local _, ns = ...

ns.db = ns.db or {}
ns.db.rules = ns.db.rules or {}

-- XP08ZZ database pack
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

SetZone("Dazar'alor, Zandalar")

	t = NPC("Brillin the Beauty <Innkeeper>", { 122690, })
	t[ 47954] = { text = "Vendor.", prSel = "Opening Vendor, Shift+Click to bypass for Hearth", }
	t[109539] = { text = "Hearth.", xpop = { which = "GOSSIP_CONFIRM", containsAll = { "do you want to make", "your new home" }, within = 3, }, prio = -10, noAuto = true }

	t = NPC("Chronicler Grazzul", {130901,})
	local VIEW_GOSSIP_STATE = GetCharacterCacheKey("NPC130901")
	t[ 50902] = { prio = 09, text = "Inscription", when = function() return GetViewGossipState(VIEW_GOSSIP_STATE) == "Opt1" end, cacheKey = VIEW_GOSSIP_STATE, cacheValue = "Opt2" }
	t[ 50903] = { prio = 09, text = "Vendor.", when = function() return GetViewGossipState(VIEW_GOSSIP_STATE) == "Opt2" end, cacheKey = VIEW_GOSSIP_STATE, cacheValue = "Opt1" }

	t = NPC("Clever Kumali", {122703,})
	local VIEW_GOSSIP_STATE = GetCharacterCacheKey("NPC122703")
	t[ 48736] = { prio = 09, text = "Alchemy", when = function() return GetViewGossipState(VIEW_GOSSIP_STATE) == "Opt1" end, cacheKey = VIEW_GOSSIP_STATE, cacheValue = "Opt2" }
	t[ 48737] = { prio = 09, text = "Vendor.", when = function() return GetViewGossipState(VIEW_GOSSIP_STATE) == "Opt2" end, cacheKey = VIEW_GOSSIP_STATE, cacheValue = "Opt1" }

	t = NPC("Forgemaster Zak'aal", {127112,})
	local VIEW_GOSSIP_STATE = GetCharacterCacheKey("NPC127112")
	t[ 48112] = { prio = 09, text = "Blacksmithing", when = function() return GetViewGossipState(VIEW_GOSSIP_STATE) == "Opt1" end, cacheKey = VIEW_GOSSIP_STATE, cacheValue = "Opt2" }
	t[ 48113] = { prio = 09, text = "Vendor.", when = function() return GetViewGossipState(VIEW_GOSSIP_STATE) == "Opt2" end, cacheKey = VIEW_GOSSIP_STATE, cacheValue = "Opt1" }

	t = NPC("Examiner Alerinda", { 122701, })
	t[ 49309] = { text = "Train me in Archaeology.", }  												-- Examiner Alerinda (122701)

	t = NPC("Jahden Fla", { 122704, })
	t[ 48297] = { text = "Train me in Herbalism.", }  													-- Jahden Fla (122704)

	t = NPC("Manapoof", 147642)
	t[ 47010] = { prio = 10, text = "Stratholme", qil = {86839, 86841,} }
	t[ 47009] = { prio = 09, text = "Gnomeregan", pcn = "Shadowspiner-Dath'Remar" }
--	t[ 47007] = { prio = 09, text = "Wailing Caverns?" }
--	t[ 47008] = { prio = 09, text = "Deadmines?" }
--	t[ 47011] = { prio = 09, text = "Blackrock Depths!" }

	t = NPC("Pin'jin the Patient", { 122700, })
	local VIEW_GOSSIP_STATE = GetCharacterCacheKey("NPC122700")
	t[ 50268] = { prio = 09, text = "Tailoring", when = function() return GetViewGossipState(VIEW_GOSSIP_STATE) == "Opt1" end, cacheKey = VIEW_GOSSIP_STATE, cacheValue = "Opt2" }
	t[ 50269] = { prio = 09, text = "Vendor.", when = function() return GetViewGossipState(VIEW_GOSSIP_STATE) == "Opt2" end, cacheKey = VIEW_GOSSIP_STATE, cacheValue = "Opt1" }

	t = NPC("Princess Talanji", { 135440, })
	t[ 47851] = { text = "Take me to King Rastakhan.", }  												-- Rastakhan (46930) Princess Talanji (135440)

	t = NPC("Rana the Cutta", {122699,})
	local VIEW_GOSSIP_STATE = GetCharacterCacheKey("NPC122699")
	t[ 49357] = { prio = 09, text = "Skinning", when = function() return GetViewGossipState(VIEW_GOSSIP_STATE) == "Opt1" end, cacheKey = VIEW_GOSSIP_STATE, cacheValue = "Opt2" }
	t[ 49358] = { prio = 09, text = "Vendor.", when = function() return GetViewGossipState(VIEW_GOSSIP_STATE) == "Opt2" end, cacheKey = VIEW_GOSSIP_STATE, cacheValue = "Opt1" }

	t = NPC("Secott the Goldsmith", { 122694, })
	local VIEW_GOSSIP_STATE = GetCharacterCacheKey("NPC122694")
	t[ 49216] = { prio = 09, text = "Mining", when = function() return GetViewGossipState(VIEW_GOSSIP_STATE) == "Opt1" end, cacheKey = VIEW_GOSSIP_STATE, cacheValue = "Opt2" }
	t[ 49217] = { prio = 09, text = "Vendor.", when = function() return GetViewGossipState(VIEW_GOSSIP_STATE) == "Opt2" end, cacheKey = VIEW_GOSSIP_STATE, cacheValue = "Opt1" }

	t = NPC("Shuga Blastcaps", {131840,})
	t.__meta.stopIfQuestAvailable = {55031,53783,53937,}												-- First NPCID, Stops Gossip until quest is accepted
	t.__meta.stopIfQuestTurnIn = {55031,53833,53937,}													-- First NPCID, Stops Gossip until quest is accepted
	local VIEW_GOSSIP_STATE = GetCharacterCacheKey("NPC131840")
	t[ 50086] = { prio = 09, text = "Train Engineering", when = function() return GetViewGossipState(VIEW_GOSSIP_STATE) == "Opt1" end, cacheKey = VIEW_GOSSIP_STATE, cacheValue = "Opt2" }
	t[ 50087] = { prio = 09, text = "Open Vendor", when = function() return GetViewGossipState(VIEW_GOSSIP_STATE) == "Opt2" end, cacheKey = VIEW_GOSSIP_STATE, cacheValue = "Opt1" }

	t = NPC("Xanjo (122698)", {122698,})
	local VIEW_GOSSIP_STATE = GetCharacterCacheKey("NPC122698")
	t[ 50266] = { prio = 09, text = "Leatherworking", when = function() return GetViewGossipState(VIEW_GOSSIP_STATE) == "Opt1" end, cacheKey = VIEW_GOSSIP_STATE, cacheValue = "Opt2" }
	t[ 50267] = { prio = 09, text = "Vendor.", when = function() return GetViewGossipState(VIEW_GOSSIP_STATE) == "Opt2" end, cacheKey = VIEW_GOSSIP_STATE, cacheValue = "Opt1" }

SetZone("Nazmir, Zandalar")

	t = MAP("Dungeon: The Underrot", {1042,})
	t[49426] = { text = "Exit", xpop = { which = "GOSSIP_CONFIRM", containsAll = { "are you sure" }, within = 3, } }

SetZone("Voldun, Zandalar")

	t = MAP("Dungeon: Temple of Sethraliss", 1043)
	t[48126] = { text = "We will restore you!", xpop = { which = "GOSSIP_CONFIRM", containsAll = { "are you sure" }, within = 3, } }

	t = MAP("Dungeon: Kings Rest", 1004)
	t[48892] = { text = "I'd like the spirits to guide me.", }

SetZone("Zuldazar, Zandalar")

	t = MAP("RAID: Battle of Dazar'alor", {1358,1357,1352,1364,})
	t[52078] = { text = "We're ready. Lead on!", manual = true, xpop = { which = "GOSSIP_CONFIRM", containsAll = { "are you sure" }, within = 3, } }
	t[50638] = { text = "Tell us what you remember."}	-- Horde to Alliance transition
	t[50645] = { text = "After them!"}	-- Horde Jaina Chase
	t[50607] = { text = "I'm ready to leave", xpop = { which = "GOSSIP_CONFIRM", containsAll = { "are you sure" }, within = 3, } }

