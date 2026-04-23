local _, ns = ...

ns.db = ns.db or {}
ns.db.rules = ns.db.rules or {}

-- XPEV database pack
-- Add rules like:
-- ns.db.rules[123456] = ns.db.rules[123456] or {}
-- ns.db.rules[123456].__meta = { zone = "Zone, Continent", npc = "NPC Name" }
-- ns.db.rules[123456][98765] = { text = [[Option text]] }
--   pcn = "Name-Realm"   -- only if you are this character
--   pcn = {"Name-Realm", "Alt-Realm"} -- only if you are ANY of these characters

local CURRENT_ZONE


local t
local function SetZone(zone)
	CURRENT_ZONE = zone
end

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

local function TalkCacheSeen(key)
	if ns and ns.Talk and type(ns.Talk.CacheGet) == "function" then
		return ns.Talk.CacheGet(key) and true or false
	end
	return false
end





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
SetZone("Darkmoon Island")

	t = NPC("Darkmoon Faire Mystic Mage", 54334)
	t.__meta.stopIfQuestAvailable = { 7905 }                                                        -- First NPCID, Stops Gossip until quest is accepted
	t[40457] = { text = "Take me to the faire...", xpop = { which = "GOSSIP_CONFIRM", containsAny = { "Travel to the faire staging area" }, within = 3, }, }

    t = NPC("Jeremy Feasel", { 67370 })
    t[41758] = { text = "I challenge you to a pet battle!" }	-- Darkmoon Pet Battle! (32175) Jeremy Feasel (67370)

    t = NPC("Christoph VonFeasel", { 85519 })
    t[42667] = { text = "I challenge you to a pet battle!" }	-- A New Darkmoon Challenger! (36471) Christoph VonFeasel (85519)

SetZone("Timewalking")

   t = NPC("Mistweaver Xia", 118828)
   t.__meta.stopIfQuestAvailable = { 86560, }                                                                       -- First NPCID, Stops Gossip until quest is accepted
   t.__meta.stopIfQuestTurnIn = { 86560, 45563, }                                                                   -- First NPCID, Stops Gossip until quest is accepted
   t[46752] = { text = "I would like to buy from you." }

SetZone("Nablegarden")

   t = NPC("Noblegarden Merchant", 32837)
   t.__meta.stopIfQuestAvailable = { 13503, }                                                                       -- First NPCID, Stops Gossip until quest is accepted
   t.__meta.stopIfQuestTurnIn = { 13503, }                                                                          -- First NPCID, Stops Gossip until quest is accepted
   t[37187] = { text = "I want to browse your goods." }

   t = NPC("Noblegarden Vendor", 124617)
   t.__meta.stopIfQuestAvailable = { 13502, }                                                                       -- First NPCID, Stops Gossip until quest is accepted
   t.__meta.stopIfQuestTurnIn = { 13502, }                                                                          -- First NPCID, Stops Gossip until quest is accepted
   t[37187] = { text = "I want to browse your goods." }

   t = NPC("Emmery Fiske", 216129)
   t[121089] = { text = "Zinnia sent me...", qil = 79323, close = true }

   t = NPC("Tethris Dewgazer", 217147)
	t[120851] = { prio = 10, text = "Sylnaria sent me...", qil = 79576, close = true }	-- A Fowl Concoction (79576) Tethris Dewgazer (217147)


