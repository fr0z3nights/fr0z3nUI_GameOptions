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

	t = NPC("Brillin the Beauty", { 122690, })
	t[ 47954] = { text = "Let me browse your goods.", }  												-- Innkeeper Brillin the Beauty (122690)
	t[109539] = { text = "Make this inn your home.", xpop = { which = "GOSSIP_CONFIRM", containsAll = { "do you want to make", "your new home" }, within = 3, }, prio = -10, noAuto = true }

	t = NPC("Examiner Alerinda", { 122701, })
	t[ 49309] = { text = "Train me in Archaeology.", }  												-- Examiner Alerinda (122701)

	t = NPC("Jahden Fla", { 122704, })
	t[ 48297] = { text = "Train me in Herbalism.", }  													-- Jahden Fla (122704)

	t = NPC("Manapoof", 147642)
	t[47010] = { prio = 10, text = "Stratholme", qil = {86839, 86841,} }
	t[47009] = { prio = 09, text = "Gnomeregan", pcn = "Shadowspiner-Dath'Remar" }
--	t[47007] = { prio = 09, text = "Wailing Caverns?" }
--	t[47008] = { prio = 09, text = "Deadmines?" }
--	t[47011] = { prio = 09, text = "Blackrock Depths!" }

	t = NPC("Pin'jin the Patient", { 122700, })
	t[ 50268] = { text = "Train me in Tailoring.", }  													-- Pin'jin the Patient (122700)

	t = NPC("Princess Talanji", { 135440, })
	t[ 47851] = { text = "Take me to King Rastakhan.", }  												-- Rastakhan (46930) Princess Talanji (135440)

	t = NPC("Secott the Goldsmith", { 122694, })
	t[ 49216] = { text = "Train me in Mining.", }  													-- Secott the Goldsmith (122694)

	t = NPC("Shuga Blastcaps", {131840,})
	t.__meta.stopIfQuestAvailable = {55031,53783,53937,}												-- First NPCID, Stops Gossip until quest is accepted
	t.__meta.stopIfQuestTurnIn = {55031,53833,53937,}													-- First NPCID, Stops Gossip until quest is accepted
	local VIEW_GOSSIP_STATE = GetCharacterCacheKey("NPC131840")
	t[50086] = { prio = 09, text = "Train Engineering", when = function() return GetViewGossipState(VIEW_GOSSIP_STATE) == "Opt1" end, cacheKey = VIEW_GOSSIP_STATE, cacheValue = "Opt2" }
	t[50087] = { prio = 09, text = "Open Vendor", when = function() return GetViewGossipState(VIEW_GOSSIP_STATE) == "Opt2" end, cacheKey = VIEW_GOSSIP_STATE, cacheValue = "Opt1" }

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

