local _, ns = ...

ns.db = ns.db or {}
ns.db.rules = ns.db.rules or {}

-- XP07 database pack
-- Add rules like:
-- ns.db.rules[123456] = ns.db.rules[123456] or {}
-- ns.db.rules[123456].__meta = { zone = "Zone, Continent", npc = "NPC Name" }
-- ns.db.rules[123456][98765] = { text = [[Option text]] }
--   pcn = "Name-Realm"   -- only if you are this character
--   pcn = {"Name-Realm", "Alt-Realm"} -- only if you are ANY of these characters

local CURRENT_ZONE

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

SetZone("Dalaran, Broken Isles")

	t = NPC("Holgar Stormaxe", 4311)
	t.__meta.stopIfQuestAvailable = { 44281, }                                  -- Quest Accept before Gossip (First NPCID)
	t.__meta.stopIfQuestTurnIn = { 43926, }                               		-- Quest TurnIn before Gossip (First NPCID)
	t[47485] = { text = "I've heard this tale before... <Skip>", xpop = { which = "GOSSIP_CONFIRM", containsAny = { "Are you sure" }, within = 3, } }

	t = NPC("Manapoof", 121602)
	t[47010] = { prio = 10, text = "Stratholme", qil = {86839, 86841,} }
	t[47009] = { prio = 09, text = "Gnomeregan", pcn = "Shadowspiner-Dath'Remar" }
--  t[47007] = { prio = 09, text = "Wailing Caverns?" }
--  t[47008] = { prio = 09, text = "Deadmines?" }
--  t[47011] = { prio = 09, text = "Blackrock Depths!" }

SetZone("Highmountain, Broken Isles")

	t = MAP("Dungeon: Neltharion's Lair", 1472)
   	t[49796] = { text = "I am ready." }
   	t[49828] = { text = "I am ready to go." }

	t = NPC("Navarrogg", 151643)
	t[51054] = { text = "I am ready to go." }

	t = NPC("Spiritwalker Ebonhorn", 151641)
	t[51053] = { text = "I'm investigating unusual magical activity in the area.", qil = 55374 }



