---@diagnostic disable: undefined-global

local _, ns = ...

ns.db = ns.db or {}
ns.db.rules = ns.db.rules or {}

-- XP08KT database pack
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

SetZone("Boralus, Kul Tiras")

	t = NPC("7th Legion Magus", {137066,})
	t[48276] = { text = "The local authority has given us permission" }

	t = NPC("Alan Goyle", {136102,})
	t[49168] = { text = "Train Fishing" }

	t = NPC("\"Cap'n\" Byron Mehlsack", 136052)
	t[49167] = { text = "Train me." }

	t = NPC("Cyrus Crestfall", {122370,})
	t.__meta.stopIfQuestAvailable = { 52194, }                                                         -- First NPCID, Stops Gossip until quest is accepted
	t[48242] = { text = "<Shake his hand.>" }
	t[48244] = { text = "I am ready to set sail." }

	t = NPC("Camilla Darksky", {136061,})
	local VIEW_GOSSIP_STATE = GetCharacterCacheKey("NPC136061")
	t[48857] = { prio = 09, text = "Train Skinning", when = function() return GetViewGossipState(VIEW_GOSSIP_STATE) == "Opt1" end, cacheKey = VIEW_GOSSIP_STATE, cacheValue = "Opt2" }
	t[48858] = { prio = 09, text = "Open Vendor", when = function() return GetViewGossipState(VIEW_GOSSIP_STATE) == "Opt2" end, cacheKey = VIEW_GOSSIP_STATE, cacheValue = "Opt1" }

	t = NPC("Cassandra Brennor", {136063,})
	local VIEW_GOSSIP_STATE = GetCharacterCacheKey("NPC136063")
	t[49169] = { prio = 09, text = "Train Leatherworking", when = function() return GetViewGossipState(VIEW_GOSSIP_STATE) == "Opt1" end, cacheKey = VIEW_GOSSIP_STATE, cacheValue = "Opt2" }
	t[49170] = { prio = 09, text = "Open Vendor", when = function() return GetViewGossipState(VIEW_GOSSIP_STATE) == "Opt2" end, cacheKey = VIEW_GOSSIP_STATE, cacheValue = "Opt1" }

	t = NPC("Daniel Brinweaver", {136071,})
	local VIEW_GOSSIP_STATE = GetCharacterCacheKey("NPC136071")
	t[49171] = { prio = 09, text = "Train Tailoring", when = function() return GetViewGossipState(VIEW_GOSSIP_STATE) == "Opt1" end, cacheKey = VIEW_GOSSIP_STATE, cacheValue = "Opt2" }
	t[49172] = { prio = 09, text = "Open Vendor", when = function() return GetViewGossipState(VIEW_GOSSIP_STATE) == "Opt2" end, cacheKey = VIEW_GOSSIP_STATE, cacheValue = "Opt1" }

	t = NPC("Declan Senal", {136096,})
	local VIEW_GOSSIP_STATE = GetCharacterCacheKey("NPC136096")
	t[48295] = { prio = 09, text = "Train Herbalism", when = function() return GetViewGossipState(VIEW_GOSSIP_STATE) == "Opt1" end, cacheKey = VIEW_GOSSIP_STATE, cacheValue = "Opt2" }
	t[48296] = { prio = 09, text = "Open Vendor", when = function() return GetViewGossipState(VIEW_GOSSIP_STATE) == "Opt2" end, cacheKey = VIEW_GOSSIP_STATE, cacheValue = "Opt1" }

	t = NPC("Elric Whalgrene", {132228,})
	local VIEW_GOSSIP_STATE = GetCharacterCacheKey("NPC132228")
	t[48460] = { prio = 09, text = "Train Alchemy", when = function() return GetViewGossipState(VIEW_GOSSIP_STATE) == "Opt1" end, cacheKey = VIEW_GOSSIP_STATE, cacheValue = "Opt2" }
	t[48461] = { prio = 09, text = "Open Vendor", when = function() return GetViewGossipState(VIEW_GOSSIP_STATE) == "Opt2" end, cacheKey = VIEW_GOSSIP_STATE, cacheValue = "Opt1" }

	t = NPC("Emily Fairweather", {136041,})
	local VIEW_GOSSIP_STATE = GetCharacterCacheKey("NPC136041")
	t[49378] = { prio = 09, text = "Train Alchemy", when = function() return GetViewGossipState(VIEW_GOSSIP_STATE) == "Opt1" end, cacheKey = VIEW_GOSSIP_STATE, cacheValue = "Opt2" }
	t[49379] = { prio = 09, text = "Open Vendor", when = function() return GetViewGossipState(VIEW_GOSSIP_STATE) == "Opt2" end, cacheKey = VIEW_GOSSIP_STATE, cacheValue = "Opt1" }

	t = NPC("Grix \"Ironfists\" Barlow", {133536,})
	local VIEW_GOSSIP_STATE = GetCharacterCacheKey("NPC133536")
	t[48131] = { prio = 09, text = "Train Blacksmithing", when = function() return GetViewGossipState(VIEW_GOSSIP_STATE) == "Opt1" end, cacheKey = VIEW_GOSSIP_STATE, cacheValue = "Opt2" }
	t[48132] = { prio = 09, text = "Open Vendor", when = function() return GetViewGossipState(VIEW_GOSSIP_STATE) == "Opt2" end, cacheKey = VIEW_GOSSIP_STATE, cacheValue = "Opt1" }

	t = NPC("Jane Hudson", {136106,})
	local VIEW_GOSSIP_STATE = GetCharacterCacheKey("NPC136106")
	t[49164] = { prio = 09, text = "Train Archaeology", when = function() return GetViewGossipState(VIEW_GOSSIP_STATE) == "Opt1" end, cacheKey = VIEW_GOSSIP_STATE, cacheValue = "Opt2" }
	t[49165] = { prio = 09, text = "Open Vendor", when = function() return GetViewGossipState(VIEW_GOSSIP_STATE) == "Opt2" end, cacheKey = VIEW_GOSSIP_STATE, cacheValue = "Opt1" }

	t = NPC("Layla Evenkeel", {136059,})
	local VIEW_GOSSIP_STATE = GetCharacterCacheKey("NPC136059")
	t[49173] = { prio = 09, text = "Train Engineering", when = function() return GetViewGossipState(VIEW_GOSSIP_STATE) == "Opt1" end, cacheKey = VIEW_GOSSIP_STATE, cacheValue = "Opt2" }
	t[49174] = { prio = 09, text = "Open Vendor", when = function() return GetViewGossipState(VIEW_GOSSIP_STATE) == "Opt2" end, cacheKey = VIEW_GOSSIP_STATE, cacheValue = "Opt1" }

	t = NPC("Myra Cabot", {136091,})
	local VIEW_GOSSIP_STATE = GetCharacterCacheKey("NPC136091")
	t[48761] = { prio = 09, text = "Train Mining", when = function() return GetViewGossipState(VIEW_GOSSIP_STATE) == "Opt1" end, cacheKey = VIEW_GOSSIP_STATE, cacheValue = "Opt2" }
	t[48762] = { prio = 09, text = "Open Vendor", when = function() return GetViewGossipState(VIEW_GOSSIP_STATE) == "Opt2" end, cacheKey = VIEW_GOSSIP_STATE, cacheValue = "Opt1" }

	t = NPC("Samuel D. Colton III", {130368,})
	local VIEW_GOSSIP_STATE = GetCharacterCacheKey("NPC130368")
	t[48101] = { prio = 09, text = "Train Jewelcrafting", when = function() return GetViewGossipState(VIEW_GOSSIP_STATE) == "Opt1" end, cacheKey = VIEW_GOSSIP_STATE, cacheValue = "Opt2" }
	t[48102] = { prio = 09, text = "Open Vendor", when = function() return GetViewGossipState(VIEW_GOSSIP_STATE) == "Opt2" end, cacheKey = VIEW_GOSSIP_STATE, cacheValue = "Opt1" }

	t = NPC("Zooey Inksprocket", {130399,})
	local VIEW_GOSSIP_STATE = GetCharacterCacheKey("NPC130399")
	t[48105] = { prio = 09, text = "Train Inscription", when = function() return GetViewGossipState(VIEW_GOSSIP_STATE) == "Opt1" end, cacheKey = VIEW_GOSSIP_STATE, cacheValue = "Opt2" }
	t[48106] = { prio = 09, text = "Open Vendor", when = function() return GetViewGossipState(VIEW_GOSSIP_STATE) == "Opt2" end, cacheKey = VIEW_GOSSIP_STATE, cacheValue = "Opt1" }

	t = NPC("Wesley Rockhold", {135153,})
	t[48279] = { text = "Let me browse your goods" }

SetZone("Nazjatar, Kul Tiras")

	t = MAP("RAID: Eternal Palace, The", {1520,})
	t[51027] = { text = "Start", xpop = { which = "GOSSIP_CONFIRM", containsAll = { "start the encounter" }, within = 3, } }

	t = NPC("Jada", {154321,})
	local VIEW_GOSSIP_STATE = GetCharacterCacheKey("NPC154321")
	t[49905] = { prio = 09, text = "Train Engineering", when = function() return GetViewGossipState(VIEW_GOSSIP_STATE) == "Opt1" end, cacheKey = VIEW_GOSSIP_STATE, cacheValue = "Opt2" }
	t[49906] = { prio = 09, text = "Open Vendor", when = function() return GetViewGossipState(VIEW_GOSSIP_STATE) == "Opt2" end, cacheKey = VIEW_GOSSIP_STATE, cacheValue = "Opt1" }

	t = NPC("Lady Jaina Proudmoore", {150101,})
	t[49509] = { text = "Jaina, can you show us the area around the palace?" }


