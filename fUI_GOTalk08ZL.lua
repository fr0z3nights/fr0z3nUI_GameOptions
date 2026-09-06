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
--  t[47007] = { prio = 09, text = "Wailing Caverns?" }
--  t[47008] = { prio = 09, text = "Deadmines?" }
--  t[47011] = { prio = 09, text = "Blackrock Depths!" }

t = NPC("Pin'jin the Patient", { 122700, })
   t[ 50268] = { text = "Train me in Tailoring.", }  													-- Pin'jin the Patient (122700)

   t = NPC("Princess Talanji", { 135440, })
   t[ 47851] = { text = "Take me to King Rastakhan.", }  												-- Rastakhan (46930) Princess Talanji (135440)

   t = NPC("Secott the Goldsmith", { 122694, })
   t[ 49216] = { text = "Train me in Mining.", }  													-- Secott the Goldsmith (122694)

SetZone("Voldun, Zandalar")

	t = MAP("Dungeon: Temple of Sethraliss", 1043)
   	t[48126] = { text = "We will restore you!", xpop = { which = "GOSSIP_CONFIRM", containsAll = { "are you sure" }, within = 3, } }

	t = MAP("Dungeon: Kings Rest", 1004)
   	t[48892] = { text = "I'd like the spirits to guide me.", }