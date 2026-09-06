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

    t = NPC("7th Legion Magus", 137066)
    t[48276] = { text = "The local authority has given us permission" }

    t = NPC("\"Cap'n\" Byron Mehlsack", 136052)
    t[49167] = { text = "Train me." }

    t = NPC("Cyrus Crestfall", 122370)
   	t.__meta.stopIfQuestAvailable = { 52194, }                                                         -- First NPCID, Stops Gossip until quest is accepted
    t[48242] = { text = "<Shake his hand.>" }
    t[48244] = { text = "I am ready to set sail." }

    t = NPC("Declan Senal", 136096)
    t[48295] = { text = "Train me in Herbalism." }

    t = NPC("Jane Hudson", 136106)
    t[49164] = { text = "Train me in Archaeology." }

    t = NPC("Myra Cabot", 136091)
    t[48761] = { text = "Train me in Mining" }

    t = NPC("Wesley Rockhold", 135153)
    t[48279] = { text = "Let me browse your goods" }

SetZone("Nazjatar, Kul Tiras")

    t = NPC("Lady Jaina Proudmoore", 150101)
    t[49509] = { text = "Jaina, can you show us the area around the palace?" }


