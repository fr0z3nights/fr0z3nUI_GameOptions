local _, ns = ...

ns.db = ns.db or {}
ns.db.rules = ns.db.rules or {}

-- XP02 database pack
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

-- Reuse one variable throughout to avoid Lua's 200-active-locals limit in large packs.
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
--

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


SetZone("Hellfire Peninsula, Outland")

   	t = NPC("Floyd Pinkus <Innkeeper>", {16602,})
   	t[30613] = { text = "Let me browse your goods.", prio = -5 }
   	t[30612] = { text = "HOLD SHIFT TO BIND HEARTHSTONE MANUALLY", xpop = { which = "GOSSIP_CONFIRM", containsAll = { "do you want to make", "your new home" }, within = 3, }, prio = -10, noAuto = true }

	t = NPC("Nicki Tinytech", {66550,})
    t[41046] = { text = "Let's rumble!", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "You don't stand a chance" }, within = 3, }, close = true,}

SetZone("Nagrand, Outland")

	t = NPC("Narrok", {66552,})
    t[41751] = { text = "Let's rumble!", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "Bring it on" }, within = 3, }, close = true,}

SetZone("Shadowmoon Valley, Outland")

	t = NPC("Bloodknight Antari", {66557,})
    t[41753] = { text = "Let's rumble!", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "You don't stand a chance" }, within = 3, }, close = true,}

SetZone("Shattrath City, Outland")

   	t = NPC("Haelthol <Innkeeper>", {19232,})
   	t[35008] = { text = "Let me browse your goods.", prio = -5 }
   	t[35007] = { text = "HOLD SHIFT TO BIND HEARTHSTONE MANUALLY", xpop = { which = "GOSSIP_CONFIRM", containsAll = { "do you want to make", "your new home" }, within = 3, }, prio = -10, noAuto = true }

	t = NPC("Morulu The Elder", {66553,})
    t[40903] = { text = "Let's rumble!", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "Let's do it" }, within = 3, }, close = true,}

SetZone("Zangarmarsh, Outland")

   	t = NPC("Merajit <Innkeeper>", {18245,})
   	t[31892] = { text = "Let me browse your goods.", prio = -5 }
   	t[31891] = { text = "HOLD SHIFT TO BIND HEARTHSTONE MANUALLY", xpop = { which = "GOSSIP_CONFIRM", containsAll = { "do you want to make", "your new home" }, within = 3, }, prio = -10, noAuto = true }

	t = NPC("Ras'an", {66551,})
    t[40901] = { text = "Think you can take me in a pet battle? Let's fight!", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "Let's rumble" }, within = 3, }, close = true,}

