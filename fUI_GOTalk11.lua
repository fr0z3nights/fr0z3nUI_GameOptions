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

	t = NPC("Clixi Fastfare", {224884,})
	t[122682] = { text = "Show me where I can fly." }

SetZone("K'aresh, Khaz Algar")

	t = NPC("Adarus Duskblaze", {236907, 246325})
	t[134065] = { text = "Can you tell me where Umbric's apprentice went?", close = true }
	t[133876] = { text = "<Report on Leona's success in harvesting Ramon'ta's void essence.>", close = true }
	t[132974] = { text = "Are you ready, Adarus?", close = true }

	t = NPC("Magister Umbric", 248153)
	t[134092] = { text = "<Listen to Leona's report.>", close = true }

