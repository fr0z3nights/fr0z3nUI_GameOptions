local _, ns = ...

ns.db = ns.db or {}
ns.db.rules = ns.db.rules or {}

-- XP06 database pack
-- Add rules like:
-- ns.db.rules[123456] = ns.db.rules[123456] or {}
-- ns.db.rules[123456].__meta = { zone = "Zone, Continent", npc = "NPC Name" }
-- ns.db.rules[123456][98765] = { text = [[Option text]], type = "" }
-- (Per-rule overrides still supported: zoneName/zone, npcName/npc)

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



SetZone("Frostifre Ridge, Draenor")

	local t = NPC("Gargra", 87122)
    t[42881] = { text = "Let's do this!", mount = true, type = "", }

    local t = NPC("Senior Peon II", 86775)
    t[43217] = { text = "Gazlowe needs you.", type = "", close = true }					-- What We Got (34824) Senior Peon II (86775)

    local t = NPC("Skaggit", 80225)
    t[42535] = { text = "Get the peons back to work.", type = "", close = true }		-- What We Got (34824) Skaggit (80225)

SetZone("Gorgrond, Draenor")

    local t = NPC("Cymre Brightblade", 83837)
    t[42651] = { text = "Let's do battle!", mount = true, type = "", }

SetZone("Nagrand, Draenor")

    local t = NPC("Tarr the Terrible", 87110)
    t[42882] = { text = "Let's do this!", mount = true, type = "", }

SetZone("Shadowmoon Valley, Draenor")

    local t = NPC("Ashlei", 87124)
    t[43294] = { text = "Let's do this!", mount = true, type = "" }

    local t = NPC("Baros Alexston", 79243)
    t[43035] = { text = "We have everything we need. It's time to build the garrison.", type = "" }

SetZone("Talador, Draenor")

    local t = NPC("Taralune", 87125)
    t[42883] = { text = "Let's do this!", mount = true, type = "" }

SetZone("Spires of Arak, Draenor")

    local t = NPC("Kuro'ak <Innkeeper>", 86386)
    t[43234] = { text = "Let me browse your goods.", type = "" }

    local t = NPC("Skytalon Meshaal", 84498)
    t[42904] = { text = "Show me where I can fly.", type = "" }

    local t = NPC("Vesharr", 87123)
    t[43292] = { text = "Lets do battle!", mount = true, type = "" }

SetZone("Garrison, Draenor")

    local t = NPC("Assistant Brightstone", 84455)
    t[42666] = { text = "Time to get back to work.", type = "", close = true }					-- Keeping it Together (35176) Assistant Brightstone (84455)

    local t = NPC("Rachelle Black", 81348)
    t[42786] = { text = "Let me browse your goods.", type = "" }								-- Vendor Rachelle Black (81348)

    local t = NPC("Shelly Hamby", 81441)
    t[42677] = { text = "Gather Shelly's report.", type = "", close = true }					-- Keeping it Together (35176) Shelly Hamby (81441)

    -- System/helper entry (not tied to real gossip). Used as a toggle in the Talk tab.
    -- NOTE: This uses a fake NPC ID so it will never match real gossip.
    local t = NPC("Garrison Mission Table", -32000)
    t[1] = { text = "Auto-start first mission (tutorial quest)", type = "" }


