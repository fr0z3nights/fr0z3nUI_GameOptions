local _, ns = ...

ns.db = ns.db or {}
ns.db.rules = ns.db.rules or {}

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

