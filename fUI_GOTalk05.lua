local _, ns = ...

ns.db = ns.db or {}
ns.db.rules = ns.db.rules or {}

--   pcn = "Name-Realm"   -- only if you are this character
--   pcn = {"Name-Realm", "Alt-Realm"} -- only if you are ANY of these characters
-- Helpers so you can set a zone header and avoid repeating zone/npc fields.

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

SetZone("Dread Wastes, Pandaria")

    t = NPC("Kik'tik", 63501)
    t[40933] = { text = "I need to travel somewhere.", }

    t = NPC("Flowing Pandaren Spirit", 68462)
    t[41935] = { text = "Another challenge?", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "Prepare yourself!" }, within = 3, }, }

    t = NPC("Wastewalker Shu", 66739)
    t[41822] = { text = "Think you can take me in a pet battle? Let's fight!", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "Prepare yourself!" }, within = 3, }, }

SetZone("Jade Forest, Pandaria")

    t = NPC("Ancient Statue", { 212182, 212183, 212184, 212186 })
    t[39082] = { text = "<Create a sketch of the statue piece.>", }
    t[39083] = { text = "<Create a sketch of the statue piece.>", }
    t[39808] = { text = "<Create a sketch of the statue piece.>", }
    t[40006] = { text = "<Create a sketch of the statue piece.>", }

    t = NPC("Chief Kah Kah", 56336)
    t[40464] = { text = "Will you help us?", close = true, }

    t = NPC("Grower Miao", 66980)
    t[40742] = { text = "Train me in Herbalism.", }

    t = NPC("Hyuna", 66730)
    t[41814] = { text = "Think you can take me in a pet battle? Let's fight!", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "Let's do it!" }, within = 3, }, }

    t = NPC("Kofa the Swift", 66219)
    t[40610] = { text = "What do you currently have for sale?", }

    t = NPC("Pandaren Volunteer", {65974, 67090,})
    t[41756] = { text = "You can go home now. I'll cover your back.", }
    t[41782] = { text = "You can go home now. I'll cover your back.", }

    t = NPC("Rivet Clutchpop", 55146)
    t[39686] = { text = "Quit messing around and use your knife!", }

    t = NPC("Sergeant Gorrok", {55162, 56477,} )
    t[39687] = { text = "We need to regroup, Sergeant!", }
    t[40186] = { text = "Nazgrim has assigned you...", close = true, }

    t = NPC("Shademaster Kiryn", {55141, 56478} )
    t[39490] = { text = "Snap out of it! You're alive!", }
    t[40187] = { text = "Nazgrim has assigned you", close = true, }

    t = NPC("Shokia", {55170, 56340,})
    t[39688] = { text = "On your feet!", }
    t[40184] = { text = "Nazgrim has assigned you...", close = true, }

    t = NPC("Stonebreaker Ruian", 66979)
    t[40741] = { text = "Train me in Mining.", }

    t = NPC("Trapper Ri", 66981)
    t[40743] = { text = "Train me in Skinning.", }

    t = NPC("Whispering Pandaren Spirit", 68464)
    t[41953] = { text = "Another challenge?", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "Prepare yourself!" }, within = 3, }, }

SetZone("Krasarang Wilds, Pandaria")

    t = NPC("Cranfur the Noodler", 62872)
    t[33557] = { prio = -5, text = "I would like to buy from you."}
    t[33558] = { prio = -9, text = "HOLD SHIFT TO BIND HEARTHSTONE MANUALLY", xpop = { which = "GOSSIP_CONFIRM", containsAll = { "do you want to make", "your new home" }, within = 3, }, noAuto = true }

    t = NPC("Mo'ruk", 66733)
    t[41816] = { text = "Think you can take me in a pet battle? Let's fight!", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "Come at me!" }, within = 3, }, }

SetZone("Kun-Lai Summit, Pandaria")

    t = NPC("Anthea", 176655)
    t[52501] = { text = "Let's rumble!", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "let's rumble", }, within = 3, }, }

    t = NPC("Courageous Yon", 66738)
    t[41820] = { text = "Think you can take me in a pet battle? Let's fight!", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "You don't stand a chance!" }, within = 3, }, }

    t = NPC("Elder Shiao", {63535,})
    t.__meta.stopIfQuestTurnIn = { 30515, }                                                               -- Waits for Quest Hand-Ins (First NPCID Only)
    t[41465] = { text = "We're here to save you and rebuild your village.", }   -- Horde

    t = NPC("Elder Tsulan", {63542,})
    t.__meta.stopIfQuestTurnIn = { 30514, }                                                               -- Waits for Quest Hand-Ins (First NPCID Only)
    t[41467] = { text = "I'm from the Alliance. We're here to save you and rebuild your village.", }   -- Alliance

    t = NPC("Farmhand Bo", {63754,})
    t[41284] = { text = "I'm from the Alliance. We're here to save you and rebuild your village.", }   -- Alliance

    t = NPC("Farmhand Ko", 63751)
    t[41283] = { text = "We're here to save you and rebuild your village.", }   -- Horde

    t = NPC("Full Flask", 61531)
    t[32394] = { text = "Let me browse your goods."}

    t = NPC("Master Lao", 61651)
    t[40512] = { text = "Please, sit and make yourself comfortable.", manual = true, }

    t = NPC("Puli the Even Handed <Innkeeper>", 62871)
    t[37168] = { text = "Let me browse your goods.", }

    t = NPC("Thundering Pandaren Spirit", 68465)
    t[41955] = { text = "Another challenge?", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "prepare yourself" }, within = 3, }, }

SetZone("Townlong Steppes, Pandaria")

    t = NPC("Burning Pandaren Spirit", 68463)
    t[41951] = { text = "Another challenge?", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "prepare yourself" }, within = 3, }, }

    t = NPC("Kali the Night Watcher", { 62874, })
    t[37168] = { prio = -6, text = "Let me browse your goods.", }
    t[37167] = { prio = -9, text = "HOLD SHIFT TO BIND HEARTHSTONE MANUALLY", xpop = { which = "GOSSIP_CONFIRM", containsAll = { "do you want to make", "your new home" }, within = 3, }, noAuto = true }

    t = NPC("Seeker Zusshi", 66918)
    t[41155] = { text = "Think you can take me in a pet battle? Let's fight!", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "You don't stand a chance!" }, within = 3, }, }

SetZone("Timeless Isle, Pandaria")

    t = NPC("Mistweaver Ku", 73306)
    t[41556] = { text = "What can I buy with timeless coins?", }

    t = NPC("Nostwin", 237817)
    t[131914] = { text = "Let me browse your goods.", }

SetZone("Vale of Eternal Blossoms, Pandaria")

    t = NPC("Aki the Chosen", 66741)
    t[41824] = { text = "Think you can take me in a pet battle? Let's fight!", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "You're going down!" }, within = 3, }, }

SetZone("Valley of the Four Winds, Pandaria")

    t = NPC("Farmer Nishi", 66734)
    t[41818] = { text = "Think you can take me in a pet battle? Let's fight!", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "Let's rumble!" }, within = 3, }, }


