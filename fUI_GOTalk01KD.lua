---@diagnostic disable: undefined-global

local _, ns = ...

ns.db = ns.db or {}
ns.db.rules = ns.db.rules or {}

-- XP01KD database pack
-- Add rules like:
-- ns.db.rules[123456] = ns.db.rules[123456] or {}
-- ns.db.rules[123456].__meta = { zone = "Zone, Continent", npc = "NPC Name" }
-- ns.db.rules[123456][98765] = { text = [[Option text]] }
--   pcn = "Name-Realm"   -- only if you are this character
--   pcn = {"Name-Realm", "Alt-Realm"} -- only if you are ANY of these characters

local CURRENT_ZONE

local function TalkCacheSeen(key)
	if ns and ns.Talk and type(ns.Talk.CacheGet) == "function" then
		return ns.Talk.CacheGet(key) and true or false
	end
	return false
end

local function TalkCacheGet(key)
	if ns and ns.Talk and type(ns.Talk.CacheGet) == "function" then
		return ns.Talk.CacheGet(key)
	end
	return nil
end

local function GetCharacterCacheKey(prefix)
	local name = UnitName and UnitName("player") or nil
	local realm = nil
	if GetNormalizedRealmName then
		realm = GetNormalizedRealmName()
	elseif GetRealmName then
		realm = GetRealmName()
	end
	local suffix = ""
	if name and name ~= "" then
		suffix = tostring(name)
	end
	if realm and realm ~= "" then
		if suffix ~= "" then
			suffix = suffix .. ":"
		end
		suffix = suffix .. tostring(realm)
	end
	if suffix == "" then
		return prefix
	end
	return prefix .. ":" .. suffix
end

local function GetViewGossipState(cacheKey)
	local state = TalkCacheGet(cacheKey)
	return state == "goods" and "goods" or "companion"
end

local function SetZone(zone)
    CURRENT_ZONE = zone
end


local t
local function NPC(npcName, npcIDs)
	-- Preferred layout:
	--   local t = NPC("Name", 123)
	--   local t = NPC("Name", { 111, 222 })
	--
	-- Back-compat still accepted:
	--   local t = NPC(123, "Name")
	if (type(npcName) == "number" and type(npcIDs) == "string") or (type(npcName) == "table" and type(npcIDs) == "string") then
		npcName, npcIDs = npcIDs, npcName
	end

	if type(npcIDs) ~= "table" then
		npcIDs = { npcIDs }
	end

	local targets = {}
	for _, id in ipairs(npcIDs) do
		ns.db.rules[id] = ns.db.rules[id] or {}
		ns.db.rules[id].__meta = { zone = CURRENT_ZONE, npc = npcName }
		targets[#targets + 1] = ns.db.rules[id]
	end

	if #targets == 1 then
		return targets[1]
	end

	return setmetatable({}, {
		__index = function(_, key)
			local t = targets[1]
			return t and t[key]
		end,
		__newindex = function(_, key, value)
			for _, t in ipairs(targets) do
				t[key] = value
			end
		end,
	})
end

local function NormalizeMapNpcName(name)
name = tostring(name or "")
name = name:gsub("^%s+", ""):gsub("%s+$", "")
name = name:lower()
name = name:gsub("[^%w]+", "_")
name = name:gsub("_+", "_")
name = name:gsub("^_+", ""):gsub("_+$", "")
if name == "" then
name = "unknown"
end
return name
end

local function MapRuleKey(mapID, npcName)
mapID = math.floor(tonumber(mapID) or 0)
if mapID <= 0 then
return nil
end
return "map:" .. tostring(mapID) .. ":" .. NormalizeMapNpcName(npcName)
end

local function MAP(npcName, mapIDs)
if type(mapIDs) ~= "table" then
mapIDs = { mapIDs }
end

local targets = {}
for _, mapID in ipairs(mapIDs) do
local key = MapRuleKey(mapID, npcName)
if key then
ns.db.rules[key] = ns.db.rules[key] or {}
ns.db.rules[key].__meta = { zone = CURRENT_ZONE, npc = npcName, mapID = tonumber(mapID) }
targets[#targets + 1] = ns.db.rules[key]
end
end

if #targets == 1 then
return targets[1]
end

return setmetatable({}, {
__index = function(_, key)
local t = targets[1]
return t and t[key]
end,
__newindex = function(_, key, value)
for _, t in ipairs(targets) do
t[key] = value
end
end,
})
end

SetZone("Ashenvale, Kalimdor")

   	t = NPC("Duras <Innkeeper>", {43606,})
   	t[48135] = { text = "Let me browse your goods.", prio = -5 }
   	t[48134] = { text = "HOLD SHIFT TO BIND HEARTHSTONE MANUALLY", xpop = { which = "GOSSIP_CONFIRM", containsAll = { "do you want to make", "your new home" }, within = 3, }, prio = -10, noAuto = true }

	t = NPC("Analynn", {66136,})
    t[40737] = { text = "Think you can take me in a pet battle? Let's fight!", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "Let's do it" }, within = 3, }, close = true,}

SetZone("Durotar, Kalimdor")

    t = NPC("General Nazgrim", 55054)
    t[41023] = { text = "I'm ready to go, General.", }

    t = NPC("Zunta", {66126,})
    t[41403] = { text = "Think you can take me in a pet battle? Let's fight!", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "Let's rumble" }, within = 3, }, close = true,}

SetZone("Darkshore, Kalimdor")

    t = NPC("Zidormi", 141489)
    t[49022] = { text = "Can you show me what Darkshore was like before the battle?" }
    t[49024] = { text = "Can you return me to the present time?" }

SetZone("Desolace, Kalimdor")

   	t = NPC("Dessina <Innkeeper>", {43872,})
   	t[00000] = { text = "Let me browse your goods.", prio = -5 }
   	t[35453] = { text = "HOLD SHIFT TO BIND HEARTHSTONE MANUALLY", xpop = { which = "GOSSIP_CONFIRM", containsAll = { "do you want to make", "your new home" }, within = 3, }, prio = -10, noAuto = true }

	t = NPC("Merda Stronghoof", {66372,})
    t[41022] = { text = "Think you can take me in a pet battle? Let's fight!", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "Let's rumble" }, within = 3, }, close = true,}

SetZone("Dustwallow Marsh, Kalimdor")

    t = NPC("Grazzle the Great", {66436,})
    t[41246] = { text = "Let's rumble!", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "Bring it on" }, within = 3, }, close = true,}

SetZone("Felwood, Kalimdor")

   	t = NPC("Teenycaugh <Innkeeper>", {48599,})
   	t[37168] = { text = "Let me browse your goods.", prio = -5 }
   	t[37167] = { text = "HOLD SHIFT TO BIND HEARTHSTONE MANUALLY", xpop = { which = "GOSSIP_CONFIRM", containsAll = { "do you want to make", "your new home" }, within = 3, }, prio = -10, noAuto = true }

	t = NPC("Zoltan", {66442,})
    t[41250] = { text = "Let's rumble!", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "Let's do it" }, within = 3, }, close = true,}

SetZone("Feralas, Kalimdor")

    t = MAP("Dungeon: Feralas", {240,})
    t[29281] = { prio = 10, text = "Thank you, Ironbark. We are ready for you to open the door."}

   	t = NPC("Chonk <Innkeeper>", {44376,})
   	t[35880] = { text = "Let me browse your goods.", prio = -5 }
   	t[35879] = { text = "HOLD SHIFT TO BIND HEARTHSTONE MANUALLY", xpop = { which = "GOSSIP_CONFIRM", containsAll = { "do you want to make", "your new home" }, within = 3, }, prio = -10, noAuto = true }

   t = NPC("Irela Moonfeather", {41383,})
   t[38509] = { text = "Show me where I can fly." }

	t = NPC("Traitor Gluk", {66352,})
    t[41017] = { text = "Think you can take me in a pet battle? Let's fight!", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "Come at me" }, within = 3, }, close = true,}

SetZone("Northern Barrens, Kalimdor")

    t = NPC("Crysa", 115286)
    t[47298] = { text = "Think you can take me in a pet battle? Let's fight!", xpop = { which = "GOSSIP_CONFIRM", containsAny = { "Let's rumble!" }, within = 3, }, }

    t = NPC("Dagra the Fierce", {66135,})
    t[41182] = { text = "Think you can take me in a pet battle? Let's fight!", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "Let's rumble" }, within = 3, }, close = true,}

SetZone("Moonglade, Kalimdor")

	t = NPC("Elena Flutterfly", {66412,})
    t[41258] = { text = "Let's rumble!", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "Let's rumble" }, within = 3, }, close = true,}

SetZone("Orgrimmar, Kalimdor")

   t = NPC("Doras", 3310)
   t[30402] = { prio = 10, text = "I need a flight to Hellscream's Fist", qil = 31853, }
   t[30395] = { prio = 05, text = "I need a ride.", }

   t = NPC("Nathanos Blightcaller", 135205)
   t[ 49081] = { text = "I have heard this story before. <Skip>", xpop = { which = "GOSSIP_CONFIRM", containsAny = { "Are you sure?" }, within = 3, },  }					-- Shadowlands: A Chilling Summons (61874) Nathanos Blightcaller (135205)

   t = NPC("Nazgrim", 171791)
   t[ 52728] = { text = "I have heard this tale before. <Skip>", xpop = { which = "GOSSIP_CONFIRM", containsAny = { "Are you sure?" }, within = 3, },  }					-- Shadowlands: A Chilling Summons (61874) Nazgrim (171791)

   t = NPC("Suspicious Citizen", { 246157, 248174 })
   t[134631] = { text = "Are you talking about the Twilight's Blade?" }
   t[134634] = { text = "Are you talking about the Twilight's Blade?" }

   t = NPC("Thrallmar Mage", {150131,})
   t[50005] = { text = "I must report to the Dark Portal" }

   t = NPC("Trading Post", { 185473, 185472 })
   t[107825] = { text = "I'd like to see what you have to offer this month." }		-- Zen'kala (185473)
   t[107826] = { text = "I'd like to see what you have to offer this month." }		-- Shiri (185472)

   t = NPC("Vanguard Battlemage", 149626)
   t[ 51034] = { text = "I must help Khadgar. Send me to the Blasted Lands!",  }					-- Warlords of Draenor: The Dark Portal (34398) Vanguard Battlemage (149626)

SetZone("Razorwind Shores, Kalimdor")

    t = NPC("Rotha", 254687)
    t[137156] = { text = "I'd like to upgrade my house." }
    t[137155] = { text = "I'd like to upgrade my house." }
    t[137153] = { text = "Let's do this!" }
    t[137154] = { text = "I'll be back." }

    t = NPC("Spirit Healer", 6491)
    t[29005] = { text = "Return me to life.", xpop = { which = "GOSSIP_CONFIRM", containsAny = { "If you find your corpse", "If you return to your corpse", "return to your corpse", "lose experience", "resurrection sickness" }, within = 3, } }

SetZone("Silithus, Kalimdor")

    t = NPC("Magni Bronzebeard", 136907)
    t[48175] = { text = "What does Azeroth want of me, Magni?" }        -- The Heart of Azeroth (51211) Magni Bronzebeard (136907)

    t = NPC("MOTHER", 152194)
    t[51120] = { text = "What have you discovered?", qil = 55533 }                      -- MOTHER Knows Best (55533) MOTHER (152194)
    t[51119] = { text = "I am ready to travel to Highmountain", qil = 55374 }           -- A Disturbance Beneath the Earth (55374) MOTHER (152194)
    t[51123] = { text = "Begin the activation sequence.", qil = 55618 }                 -- The Heart Forge (55618) MOTHER (152194)

    t = NPC("Spiritwalker Ebonhorn", 151964)
    t[49616] = { text = "Let's go meet Magni." }                                     -- A Friendly Face (55497) Spiritwalker Ebonhorn (151964)

    t = NPC("Zidormi", 128607)
    t[47635] = { text = "Can you return me to the present time?" }
    t[47634] = { text = "Can you show me what Silithus was like before the Wound in the World?" }

SetZone("Southern Barrens, Kalimdor")

   	t = NPC("Lhakadd <Innkeeper>", {44276,})
   	t[28148] = { text = "Let me browse your goods.", prio = -5 }
   	t[28147] = { text = "HOLD SHIFT TO BIND HEARTHSTONE MANUALLY", xpop = { which = "GOSSIP_CONFIRM", containsAll = { "do you want to make", "your new home" }, within = 3, }, prio = -10, noAuto = true }

	t = NPC("Kela Grimtotem", {66422,})
    t[41260] = { text = "Let's Rumble!", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "Let's do it" }, within = 3, }, close = true,}

SetZone("Stonetalon Mountains, Kalimdor")

   	t = NPC("Felonius Stark <Innkeeper>", {41892,})
   	t[38925] = { text = "Let me browse your goods.", prio = -5 }
   	t[38924] = { text = "HOLD SHIFT TO BIND HEARTHSTONE MANUALLY", xpop = { which = "GOSSIP_CONFIRM", containsAll = { "do you want to make", "your new home" }, within = 3, }, prio = -10, noAuto = true }

	t = NPC("Zonya the Sadist", {66137,})
    t[40812] = { text = "Think you can take me in a pet battle? Let's fight!", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "Bring it on" }, within = 3, }, close = true,}

SetZone("Tanaris, Kalimdor")

	t = MAP("Dungeon: Dire Maul", 219)
    t[31883] = {"Will you blow up that door now?"}

    t = NPC("Time Transit Device", { 209437, 209438, 209439, 209441, 209442, 209443, })
    t[40865] = { prio = 10, text = "Bronze Dragonshrine" }
    t[40863] = { prio = 04, text = "Azure Dragonshrine" }
    t[40862] = { prio = 06, text = "Emerald Dragonshrine" }
    t[40860] = { prio = 08, text = "Obsidian Dragonshrine" }
    t[40857] = { prio = 02, text = "Ruby Dragonshrine" }
    t[40856] = { prio = 00, text = "Entryway of Time" }

SetZone("Thousand Needles, Kalimdor")

   	t = NPC("Daisy <Innkeeper>", {40832,})
   	t[38546] = { text = "What drinks do you have?", prio = -5 }
   	t[38547] = { text = "HOLD SHIFT TO BIND HEARTHSTONE MANUALLY", xpop = { which = "GOSSIP_CONFIRM", containsAll = { "do you want to make", "your new home" }, within = 3, }, prio = -10, noAuto = true }

	t = NPC("Kela Grimtotem", {66452,})
    t[41248] = { text = "Let's Rumble!", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "Let's rumble" }, within = 3, }, close = true,}

SetZone("Uldum, Kalimdor")

    t = NPC("Zidormi", 162419)
    t[51282] = { text = "Can you show me what Uldum was like during the time of the Cataclysm?" }

SetZone("Winterspring, Kalimdor")

   	t = NPC("Vizzie <Innkeeper>", {11118,})
   	t[39133] = { text = "Let me browse your goods.", prio = -5 }
   	t[39132] = { text = "HOLD SHIFT TO BIND HEARTHSTONE MANUALLY", xpop = { which = "GOSSIP_CONFIRM", containsAll = { "do you want to make", "your new home" }, within = 3, }, prio = -10, noAuto = true }

	t = NPC("Zoltan", {66466,})
    t[41411] = { text = "Let's rumble!", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "Let's do it" }, within = 3, }, close = true,}





