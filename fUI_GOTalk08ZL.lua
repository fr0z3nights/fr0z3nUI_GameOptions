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