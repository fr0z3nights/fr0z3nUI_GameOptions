local _, ns = ...

ns.db = ns.db or {}
ns.db.rules = ns.db.rules or {}

-- XP11 database pack
-- Add rules like:
-- ns.db.rules[123456] = ns.db.rules[123456] or {}
-- ns.db.rules[123456][98765] = { zone = "Zone, Continent", npc = "NPC Name", text = [[Option text]] }
-- (Aliases also supported: zone / npc)
-- Optional: set defaults once per NPC bucket:
-- ns.db.rules[123456].__meta = { zone = "Zone, Continent", npc = "NPC Name" }
-- ns.db.rules[123456][98765] = { text = [[Option text]] }

-- Helpers so you can set a zone header and avoid repeating zone/npc fields.
local CURRENT_ZONE

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
SetZone("Dornogal, Khaz Algar")

    local t = NPC("Brann Bronzebeard", 206017)
    t[123770] = { text = "I'd like to join the reinforcements. \r\n|cFFFF0000 <Skip the level-up campaign.> |r" }
    t[123771] = { text = "I'd like to join the reinforcements. \r\n|cFFFF0000 <Skip the level-up campaign.> |r" }

    local t = NPC("Delver's Guide", 227675)
    t[123493] = { text = "<Review information on your current delve progress.>" }

    local t = NPC("Ronesh", 212370)
    t[121503] = { text = "I want to browse your goods." }


SetZone("Hallowfall, Khaz Algar")

    local t = NPC("Aliya Hillhelm", 220293)
    t[121536] = { text = "(Delve) I'll get your pigs back and make those fungarians pay for this." }

    local t = NPC("Chef Dinaire", 220354)
    t[121539] = { text = "(Delve) I love scavenger hunts AND treasure. I'm in!" }
    t[121541] = { text = "(Delve) Go get the treasure while I handle whatever is about to attack us." }

    local t = NPC("Lamplighter Havrik Chayvn", 220585)
    t[121408] = { text = "(Delve) I'll go deeper in and stop the nerubian ritual." }

    local t = NPC("Zah'ran", 248927)
    t[135013] = { text = "Show me." }

SetZone("Azj-Kahet, Khaz Algar")

    local t = NPC("Weaver's Instructions", 220462)
    t[121566] = { text = "(Delve) <Close the scroll and take the Weaver's web grappling hook.>" }


