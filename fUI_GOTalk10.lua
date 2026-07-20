local _, ns = ...

ns.db = ns.db or {}
ns.db.rules = ns.db.rules or {}

-- XP10 database pack
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

SetZone("Amirdrassil, Dragon Isles")

    t = NPC("Elder Verdantbark", { 251316, })
    t[137249] = { text = "<Present throwing stones to Elder Verdantbark.>" }	-- Awaken the Ancient Protector (88927) Elder Verdantbark (251316)

    t = NPC("First Arcanist Thalyssra", { 250853, })
    t[135657] = { text = "Tell Shandris what has transpired." }	-- Children of the Stars (88923) First Arcanist Thalyssra (250853)

    t = NPC("Lor'themar Theron", { 240335, })
    t[135655] = { text = "Tell Shandris what has transpired." }	-- Children of the Stars (88923) Lor'themar Theron (240335)

    t = NPC("Magister Umbric", { 253613, })
    t[135656] = { text = "Tell Shandris what has transpired." }	-- Children of the Stars (88923) Magister Umbric (253613)

    t = NPC("Malastral", { 255687, })
    t[137236] = { text = "Give me the banner and I will gather the wisps." }	-- Awaken the Ancient of Lore (88937) Malastral (255687)

SetZone("The Forbidden Reach, Dragon Isles")

    t = NPC("Zone NPCs", { 184165, 182610, 182611, })
    t[51921] = { text = "Come with me. I will get you to safety." }	-- Halp! (65071)		Little Ko (184165)
    t[51849] = { text = "Come with me. I will get you to safety." }	-- Final Orders (65100)	Scalecommander Viridia (182610)
    t[51850] = { text = "<Relay what Nozdormu told you.>" }			-- Final Orders (65100)	Scalecommander Sarkareth (182611)

SetZone("The Waking Shores, Dragon Isles")

	t = NPC("Danielle Anglers", { 191150, })
	t[107425] = { text = "Train me in Fishing." }

	t = NPC("Grun Ashbeard", { 187261, })
	t.__meta.stopIfQuestAvailable = { 70028, }                                                     		  -- Waits for Quest Accepted (First NPCID Only)
	t[107293] = { text = "Train me in Mining." }

	t = NPC("Head Chef Stacks", { 198094, })
	t.__meta.stopIfQuestAvailable = { 72250, }                                                     		  -- Waits for Quest Accepted (First NPCID Only)
	t[107418] = { text = "Can you, um... teach me how to cook?" }

	t = NPC("Tixxa Mixxa", { 192490, })
	t[34833] = { text = "Show me where I can fly." }

	t = NPC("Toninaar", { 192558, })
	t[56062] = { text = "Train me in Fishing." }


