---@diagnostic disable: undefined-global

local _, ns = ...

ns.db = ns.db or {}
ns.db.rules = ns.db.rules or {}
ns.TalkDB = ns.TalkDB or {}

local H = ns.TalkDB
local Y, N = true, false

local function PlayerHasQuestInLog(questID)
	questID = tonumber(questID)
	if not questID then
		return false
	end

	if C_QuestLog and type(C_QuestLog.IsOnQuest) == "function" then
		local ok, on = pcall(C_QuestLog.IsOnQuest, questID)
		if ok and on then
			return true
		end
	end

	if C_QuestLog and type(C_QuestLog.GetLogIndexForQuestID) == "function" then
		local ok, idx = pcall(C_QuestLog.GetLogIndexForQuestID, questID)
		return ok and type(idx) == "number" and idx > 0
	end

	if type(GetQuestLogIndexByID) == "function" then
		local ok, idx = pcall(GetQuestLogIndexByID, questID)
		return ok and type(idx) == "number" and idx > 0
	end

	return false
end

local function NormalizeRealmName(realm)
	realm = tostring(realm or "")
	realm = realm:gsub("%s+", "")
	realm = realm:gsub("%-+", "")
	return realm:lower()
end

local function PlayerIsCharacter(full)
	full = tostring(full or "")
	if full == "" then
		return false
	end

	local wantName, wantRealm = full:match("^([^%-]+)%-(.+)$")
	if not wantName then
		wantName = full
		wantRealm = nil
	end

	local name, realm
	if UnitName then
		name, realm = UnitName("player")
	end
	if not name then
		return false
	end

	if realm == nil then
		if GetNormalizedRealmName then
			realm = GetNormalizedRealmName()
		elseif GetRealmName then
			realm = GetRealmName()
		end
	end

	if tostring(name):lower() ~= tostring(wantName):lower() then
		return false
	end

	if wantRealm and wantRealm ~= "" then
		return NormalizeRealmName(realm) == NormalizeRealmName(wantRealm)
	end

	return true
end

local function TalkCacheGet(key)
	if ns.Talk and type(ns.Talk.CacheGet) == "function" then
		return ns.Talk.CacheGet(key)
	end
	return nil
end

function H.TalkCacheSeen(key)
	return TalkCacheGet(key) and true or false
end

function H.GetCharacterCacheKey(prefix)
	local name = UnitName and UnitName("player") or nil
	local realm
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

function H.GetViewGossipState(cacheKey)
	local state = TalkCacheGet(cacheKey)
	if type(state) == "string" and state:match("^Opt[1-9]$") then
		return state
	end
	return "Opt1"
end

function H.SetZone(zone)
	H._currentZone = zone
end

function H.NPC(npcName, npcIDs)
	if (type(npcName) == "number" and type(npcIDs) == "string") or (type(npcName) == "table" and type(npcIDs) == "string") then
		npcName, npcIDs = npcIDs, npcName
	end

	if type(npcIDs) ~= "table" then
		npcIDs = { npcIDs }
	end

	local targets = {}
	for _, id in ipairs(npcIDs) do
		ns.db.rules[id] = ns.db.rules[id] or {}
		ns.db.rules[id].__meta = { zone = H._currentZone, npc = npcName }
		targets[#targets + 1] = ns.db.rules[id]
	end

	if #targets == 1 then
		return targets[1]
	end

	return setmetatable({}, {
		__index = function(_, key)
			local target = targets[1]
			return target and target[key]
		end,
		__newindex = function(_, key, value)
			for _, target in ipairs(targets) do
				target[key] = value
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

function H.MAP(npcName, mapIDs)
	if type(mapIDs) ~= "table" then
		mapIDs = { mapIDs }
	end

	local targets = {}
	for _, mapID in ipairs(mapIDs) do
		local key = MapRuleKey(mapID, npcName)
		if key then
			ns.db.rules[key] = ns.db.rules[key] or {}
			ns.db.rules[key].__meta = { zone = H._currentZone, npc = npcName, mapID = tonumber(mapID) }
			targets[#targets + 1] = ns.db.rules[key]
		end
	end

	if #targets == 1 then
		return targets[1]
	end

	return setmetatable({}, {
		__index = function(_, key)
			local target = targets[1]
			return target and target[key]
		end,
		__newindex = function(_, key, value)
			for _, target in ipairs(targets) do
				target[key] = value
			end
		end,
	})
end

H.PlayerHasQuestInLog = PlayerHasQuestInLog
H.PlayerIsCharacter = PlayerIsCharacter