local _, ns = ...

ns.db = ns.db or {}
ns.db.rules = ns.db.rules or {}

-- XP01EK database pack
-- Add rules like:
-- ns.db.rules[123456] = ns.db.rules[123456] or {}
-- ns.db.rules[123456].__meta = { zone = "Zone, Continent", npc = "NPC Name" }
-- ns.db.rules[123456][98765] = { text = [[Option text]], prio = 0, xpop = { which = "GOSSIP_CONFIRM", containsAll = {"are you sure", "cannot be undone"}, within = 3 } }
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

-- Reuse one variable throughout to avoid Lua's 200-active-locals limit in large packs.
local t

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

SetZone("Arathi Highlands, Eastern Kingdoms")

   t = NPC("Zidormi", 141649)
   t[49008] = { text = "Can you show me what Arathi Highlands was like before war broke out?" }
   t[49009] = { text = "Can you return me to the Highlands during the Fourth War?" }

SetZone("Blasted Lands, Eastern Kingdoms")

   t = NPC("Zidormi", 88206)
   t[42958] = { text = "Show me the Blasted Lands before the invasion" }
   t[42959] = { text = "Take me back to the present" }

SetZone("Burning Steppes, Eastern Kingdoms")

   t = NPC("Arator", 237508)
   t[136312] = { text = "<Ask Arator how he is doing.>" }

   t = NPC("Alonsus Faol", 246863)
   local INTRO_SEEN = "GOTalk:246863:138706"
   t[138706] = { prio = 10, text = "What are we here for?", when = function() return not TalkCacheSeen(INTRO_SEEN) end, cacheKey = INTRO_SEEN }
   t[138705] = { prio = 10, text = "Let's get started. <Skip>", when = function() return TalkCacheSeen(INTRO_SEEN) end }

	t = NPC("Durin Darkhammer", {66520,})
   t[41779] = { text = "Think you can take me in a pet battle? Let's fight!", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "Bring it on" }, within = 2, }, close = true,}

   t = NPC("Kudran Wildhammer", 248250)
   t[134709] = { text = "What happened?" }

SetZone("Deadwind Pass, Eastern Kingdoms")

	t = NPC("Lydia Accoste", {66522,})
   t[41781] = { text = "Think you can take me in a pet battle? Let's fight!", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "Come at me" }, within = 2, }, close = true,}

SetZone("Dun Morogh, Eastern Kingdoms")

   t = NPC("Environeer Bert", 124617)
   t[47861] = { text = "Think you can take me in a pet battle? Let's fight!", xpop = { which = "GOSSIP_CONFIRM", containsAny = { "Let's rumble!" }, within = 3, }, }

SetZone("Duskwood, Eastern Kingdoms")

   t = NPC("Trelayne <Innkeeper>", {6790,})
   t[28159] = { text = "Let me browse your goods.", prio = -5 }
   t[28158] = { text = "HOLD SHIFT TO BIND HEARTHSTONE MANUALLY", xpop = { which = "GOSSIP_CONFIRM", containsAll = { "do you want to make", "your new home" }, within = 3, }, prio = -10, noAuto = true }

	t = NPC("Eric Davidson", {65655,})
   t[41186] = { text = "Think you can take me in a pet battle? Let's fight!", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "Come at me" }, within = 2, }, close = true,}

SetZone("Eastern Plaguelands, Eastern Kingdoms")

   t = NPC("Jessica Chambers <Innkeeper>", {43699,})
   t[31194] = { text = "Let me browse your goods.", prio = -5 }
   t[31193] = { text = "HOLD SHIFT TO BIND HEARTHSTONE MANUALLY", xpop = { which = "GOSSIP_CONFIRM", containsAll = { "do you want to make", "your new home" }, within = 3, }, prio = -10, noAuto = true }

	t = NPC("Deiza Plaguehorn", {66512,})
   t[41415] = { text = "Let's rumble!", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "You don't stand a chance" }, within = 2, }, close = true,}

SetZone("Elwynn Forest, Eastern Kingdoms")

   t = NPC("Farley <Innkeeper>", {295,})
   t[28606] = { text = "Let me browse your goods.", prio = -5 }
   t[28605] = { text = "HOLD SHIFT TO BIND HEARTHSTONE MANUALLY", xpop = { which = "GOSSIP_CONFIRM", containsAll = { "do you want to make", "your new home" }, within = 3, }, prio = -10, noAuto = true }

	t = NPC("Julia Stevens", {64330,})
   t[40127] = { text = "Think you can take me in a pet battle? Let's fight!", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "Let's rumble" }, within = 3, }, close = true,}

SetZone("Founder's Point, Eastern Kingdoms")

   t = NPC("High Tides Ren", { 255222, })
   t[137315] = { text = "Okay, lets see what you've got." }

   t = NPC("Jorvari Longmoor", { 255104, })
   t[137141] = { text = "I'd like to upgrade my house." }
   t[137143] = { text = "I'd like to upgrade my house." }
   t[137139] = { text = "Let's Do This!" }
   t[137142] = { text = "I'll be back." }

SetZone("Hammerfall, Eastern Kingdoms")

   t = NPC("Alonsus Faol", { 240747, })
   t[132918] = { text = "<Tell Alonsus you are ready to go to the Burning Steppes.>" }                   -- One Final Relic (86822)             Alonsus Faol (240747)

   t = NPC("Sunwalker Malu", { 238101, })
   t[135301] = { text = "You don't feel like you have better things to do?", close = true }              -- A Humble Servant (91000)            Sunwalker Malu (238101)

   t = NPC("Sunwalker Nadura", { 238081, })
   t[135304] = { text = "Taking a break?", close = true }                                                -- A Humble Servant (91000)            Sunwalker Nadura (238081)

   t = NPC("Jun'ha", { 232033, })
   t[134006] = { text = "Dezco sent these supplies for you.", prio = 10, close = true }                  -- Resupplying Our Suppliers (86846)   Jun'ha (232033)
   t[134005] = { text = "Let me browse your goods. ", prio = -10 }                                       -- Resupplying Our Suppliers (86846)   Jun'ha (232033)

   t = NPC("Tunkk", { 232036, })
   t[134008] = { text = "Dezco sent these supplies for you.", prio = 10, close = true }                  -- Resupplying Our Suppliers (86846)   Tunkk (232036)
   t[134007] = { text = "Let me browse your goods.", prio = -10 }                                        -- Resupplying Our Suppliers (86846)   Tunkk (232036)

   t = NPC("Slagg", { 232031, })
   t[134003] = { text = "Dezco sent these supplies for you.", prio = 10, close = true }                  -- Resupplying Our Suppliers (86846)   Slagg (232031)
   t[134004] = { text = "Train me in Cooking.", prio = -10 }                                             -- Resupplying Our Suppliers (86846)   Slagg (232031)

   t = NPC("Keena", { 232035, })
   t[138704] = { text = "Dezco sent these supplies for you.", prio = 10, close = true }                  -- Resupplying Our Suppliers (86846)   Keena (232035)
   t[138703] = { text = "Let me browse your goods.", prio = -10 }                                        -- Resupplying Our Suppliers (86846)   Keena (232035)

   t = NPC("Mu'uta", { 232037, })
   t[134042] = { text = "Dezco sent these supplies for you.",  prio = 10, close = true }                 -- Resupplying Our Suppliers (86846)   Mu'uta (232037)
   t[134041] = { text = "Let me browse your goods.",  prio = -10 }                                       -- Vendor Mu'uta (232037)

SetZone("The Hinterlands, Eastern Kingdoms")

   t = NPC("Keirnan <Innkeeper>", {43699,})
   t[28268] = { text = "Let me browse your goods.", prio = -5 }
   t[28267] = { text = "HOLD SHIFT TO BIND HEARTHSTONE MANUALLY", xpop = { which = "GOSSIP_CONFIRM", containsAll = { "do you want to make", "your new home" }, within = 3, }, prio = -10, noAuto = true }

	t = NPC("David Kosse", {66478,})
   t[41413] = { text = "Let's rumble!", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "Bring it on" }, within = 2, }, close = true,}

SetZone("Ironforge, Eastern Kingdoms")

   t = NPC("Gryth Thurden", {1573,})
   t[31711] = { text = "I need a ride." }                                                                -- Flight Master (00000) Gryth Thurden (1573)

SetZone("Redridge Mountains, Eastern Kingdoms")

   t = NPC("Brianna <Innkeeper>", {6727,})
   t[50737] = { text = "Let me browse your goods.", prio = -5 }
   t[50736] = { text = "HOLD SHIFT TO BIND HEARTHSTONE MANUALLY", xpop = { which = "GOSSIP_CONFIRM", containsAll = { "do you want to make", "your new home" }, within = 3, }, prio = -10, noAuto = true }

	t = NPC("Lindsay", {65651,})
   t[41184] = { text = "Think you can take me in a pet battle? Let's fight!", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "Let's rumble" }, within = 3, }, close = true,}

SetZone("Searing Gorge, Eastern Kingdoms")

   t = NPC("Velma Rockslide <Innkeeper>", {47942,})
   t[37168] = { text = "Let me browse your goods.", prio = -5 }
   t[37167] = { text = "HOLD SHIFT TO BIND HEARTHSTONE MANUALLY", xpop = { which = "GOSSIP_CONFIRM", containsAll = { "do you want to make", "your new home" }, within = 3, }, prio = -10, noAuto = true }

	t = NPC("Koras Darkhammer", {66515,})
   t[41417] = { text = "Think you can take me in a pet battle? Let's fight!", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "Prepare yourself" }, within = 2, }, close = true,}

SetZone("Stormwind City, Eastern Kingdoms")

   t = NPC("Archmage Khadgar", {193450,})
   t[55739] = { text = "<Ask Khadgar what happened.>" }                                                 -- Whispers on the Winds (66596) Archmage Khadgar (193450)

   t = NPC("Brundia Braidhammer", 242651)
   t[133249] = { text = "Let ne browse your goods." }

   t = NPC("High Inquisitor Whitemane", 171789)
   t[52725] = { text = "I have heard this tale before. <Skip the Maw introduction. Oribos awaits.>", xpop = { which = "GOSSIP_CONFIRM", containsAny = { "are you sure", "cannot be undone" }, within = 3, }, }

   t = NPC("Honor Hold Mage", 150122)
   t[50005] = { text = "I must report to the Dark Portal." }

   t = NPC("Lady Jaina Proudmoore", 120590)
   t[47616] = { prio = 10, text = "I've heard this tale before... <Skip>", xpop = { which = "GOSSIP_CONFIRM", containsAny = { "Are you sure" }, within = 3, } }
   t[47615] = { prio = 05, text = "I'm ready to set sail!" }

   t = NPC("Kiatke", 101759)
   t.__meta.stopIfQuestAvailable = { 86556, }                                                         -- First NPCID, Stops Gossip until quest is accepted
   t.__meta.stopIfQuestTurnIn = { 86556, 40786, 40787, }                                              -- Stops auto-select if any of these quests are turn-in ready
   t[ 45067] = { text = "I would like to buy from you." }                                             -- Vendor () Kiatke (101759)

   t = NPC("Loretta Banks", {165505,})
   t[ 54294] = { text = "I need a flight to The Skyfire." }                                           -- The Mission (29548) Loretta Banks (165505)

   t = NPC("Pathfinder Jeb", {189763,})
   t[ 55649] = { text = "We need explorers for an expedition..." }                                    -- Expeditionary Coordination (66589) Pathfinder Jeb (189763)

   t = NPC("Dervishian", {198401,})
   t[107417] = { text = "Scalecommander Azurathel would like you to meet him at the docks." }         -- Expeditionary Coordination (66589) Dervishian (198401)

   t = NPC("Thaelin Darkanvil", {189767,})
   t[ 55651] = { text = "We need artisans for an expedition to the Dragon Isles." }                    -- Expeditionary Coordination (66589) Thaelin Darkanvil (189767)

   t = NPC("Cataloger Wulferd", {189765,})
   t[ 55650] = { text = "We need scholars for an expedition to the Dragon Isles." }                    -- Expeditionary Coordination (66589) Cataloger Wulferd (189765)

   t = NPC("Recruiter Lee", {107934,})
   t.__meta.stopIfQuestAvailable = { 42782, }                                                         -- First NPCID, Stops Gossip until quest is accepted
   t.__meta.stopIfQuestTurnIn = { 40519, }                                                            -- First NPCID, Stops Gossip until quest is accepted
   t[ 47484] = { text = "I've heard this tale before... <Skip>", xpop = { which = "GOSSIP_CONFIRM", containsAny = { "Are you sure" }, within = 3, } }                                   -- To Be Prepared (42782) Recruiter Lee (107934)

   t = NPC("Sky Admiral Rogers", {66292,})
   t[ 40614] = { text = "I am ready to depart." }                                                     -- The Mission (29548) Sky Admiral Rogers (66292)

   t = NPC("Tawny Seabraid", 185468)
   t[107827] = { text = "I'd like to see what you have to off this month." }                          -- Venndor () Tawny Seabraid (185468)

   t = NPC("Vanguard Battlemage", 149626)
   t[51033] = { text = "I must help Khadgar. Send me to the Blasted Lands!" }

   t = NPC("Wilder Seabraid", 185467)
   t[107824] = { text = "I'd like to see what you have to off this month." }                          -- Venndor () Wilder Seabraid (185467)

   t = NPC("Zone Quest NPCs", { 246155, 246154, })
   t[134631] = { text = "Are you talking about the Twilight's Blade?" }
   t[134634] = { text = "Are you talking about the Twilight's Blade?" }

SetZone("Stranglethorn, Eastern Kingdoms")  -- Northern / Cape of

	t = NPC("Bill Buckler", {65656,})
   t[41216] = { text = "Think you can take me in a pet battle? Let's fight!", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "Prepare yourself" }, within = 2, }, close = true,}

   t = NPC("Livingston Marshal <Innkeeper>", {44019,})
   t[28159] = { text = "Let me browse your goods.", prio = -5 }
   t[28158] = { text = "HOLD SHIFT TO BIND HEARTHSTONE MANUALLY", xpop = { which = "GOSSIP_CONFIRM", containsAll = { "do you want to make", "your new home" }, within = 3, }, prio = -10, noAuto = true }

   t = NPC("Skindle <Innkeeper>", {6807,})
   t[125214] = { text = "Let me browse your goods.", prio = -5 }
   t[125215] = { text = "HOLD SHIFT TO BIND HEARTHSTONE MANUALLY", xpop = { which = "GOSSIP_CONFIRM", containsAll = { "do you want to make", "your new home" }, within = 3, }, prio = -10, noAuto = true }

	t = NPC("Steven Lisbane", {63194,})
   t[39601] = { text = "Let's rumble!", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "Let's rumble" }, within = 2, }, close = true,}

SetZone("Swamp of Sorrows, Eastern Kingdoms")

   t = NPC("Cap'n Geech <Innkeeper>", {47334,})
   t[37168] = { text = "Let me browse your goods.", prio = -5 }
   t[37167] = { text = "HOLD SHIFT TO BIND HEARTHSTONE MANUALLY", xpop = { which = "GOSSIP_CONFIRM", containsAll = { "do you want to make", "your new home" }, within = 3, }, prio = -10, noAuto = true }

   t = NPC("Verad <Innkeeper>", {47367,})
   t[37168] = { text = "Let me browse your goods.", prio = -5 }
   t[37167] = { text = "HOLD SHIFT TO BIND HEARTHSTONE MANUALLY", xpop = { which = "GOSSIP_CONFIRM", containsAll = { "do you want to make", "your new home" }, within = 3, }, prio = -10, noAuto = true }

	t = NPC("Everessa", {66518,})
   t[41777] = { text = "Think you can take me in a pet battle? Let's fight!", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "Let's do it" }, within = 2, }, close = true,}

SetZone("Tirisfal Glades, Eastern Kingdoms")

   t = NPC("Alonsus Faol", 237602)
   t[132903] = { text = "<Tell Alonsus you are ready to return to Silvermoon.>" }                     -- Unknown Quest (XXXXX) Alonsus Faol (237602)

   t = NPC("Zidormi", 141488)
   t[49018] = { text = "Can you show me what Tirisfal Glades was like before the Battle for Lordaeron." } -- No Quest (XXXXX) Zidormi (141488)
   t[49019] = { text = "Can you return me to the present time?" } -- No Quest (XXXXX) Zidormi (141488)

SetZone("Twilight Highlands, Eastern Kingdoms")

    -- 12.0.0 Prepatch
   t = NPC("Restlass Neophyte", { 248230, 248229, 248228 })
   t[135794] = { text = "<Challenge the cultist to a \"sparring match.\"" }

SetZone("Westfall, Eastern Kingdoms")

   t = NPC("Heather <Innkeeper>", {8931,})
   t[28159] = { text = "Let me browse your goods.", prio = -5 }
   t[28158] = { text = "HOLD SHIFT TO BIND HEARTHSTONE MANUALLY", xpop = { which = "GOSSIP_CONFIRM", containsAll = { "do you want to make", "your new home" }, within = 3, }, prio = -10, noAuto = true }

	t = NPC("Old MacDonald", {65648,})
   t[41437] = { text = "Think you can take me in a pet battle? Let's fight!", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "Let's rumble" }, within = 3, }, close = true,}

   t = NPC("Thor", 523)
   t[32677] = { text = "I need a ride." }

	t = MAP("Dungeon: Deadmines", 291)
   t[39500] = { prio = 10, text = "Portal 3"}
   t[39499] = { prio = 08, text = "Portal 2"}
   t[39498] = { prio = 06, text = "Portal 1"}





