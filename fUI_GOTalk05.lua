local _, ns = ...

ns.db = ns.db or {}
ns.db.rules = ns.db.rules or {}

--   pcn = "Name-Realm"   -- only if you are this character
--   pcn = {"Name-Realm", "Alt-Realm"} -- only if you are ANY of these characters
-- Helpers so you can set a zone header and avoid repeating zone/npc fields.


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
SetZone("Dread Wastes, Pandaria")

    t = NPC("Kik'tik", 63501)
    t[40933] = { text = "I need to travel somewhere.", }

    t = NPC("Flowing Pandaren Spirit", 68462)
    t[41935] = { text = "Another challenge?", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "Prepare yourself!" }, within = 3, }, }

    t = NPC("Wastewalker Shu", 66739)
    t[41822] = { text = "Think you can take me in a pet battle? Let's fight!", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "Prepare yourself!" }, within = 3, }, }

SetZone("Jade Forest, Pandaria")

    t = NPC("Hyuna", 66730)
    t[41814] = { text = "Think you can take me in a pet battle? Let's fight!", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "Let's do it!" }, within = 3, }, }

    t = NPC("Whispering Pandaren Spirit", 68464)
    t[41953] = { text = "Another challenge?", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "Prepare yourself!" }, within = 3, }, }

SetZone("Krasarang Wilds, Pandaria")

    t = NPC("Mo'ruk", 66733)
    t[41816] = { text = "Think you can take me in a pet battle? Let's fight!", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "Come at me!" }, within = 3, }, }

SetZone("Kun-Lai Summit, Pandaria")

    t = NPC("Anthea", 176655)
    t[52501] = { text = "Let's rumble!", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "let's rumble", }, within = 3, }, }

    t = NPC("Courageous Yon", 66738)
    t[41820] = { text = "Think you can take me in a pet battle? Let's fight!", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "You don't stand a chance!" }, within = 3, }, }

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

    t = NPC("Seeker Zusshi", 66918)
    t[41155] = { text = "Think you can take me in a pet battle? Let's fight!", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "You don't stand a chance!" }, within = 3, }, }

SetZone("Vale of Eternal Blossoms, Pandaria")

    t = NPC("Aki the Chosen", 66741)
    t[41824] = { text = "Think you can take me in a pet battle? Let's fight!", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "You're going down!" }, within = 3, }, }

SetZone("Valley of the Four Winds, Pandaria")

    t = NPC("Farmer Nishi", 66734)
    t[41818] = { text = "Think you can take me in a pet battle? Let's fight!", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "Let's rumble!" }, within = 3, }, }


