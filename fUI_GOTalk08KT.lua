---@diagnostic disable: undefined-global

local _, ns = ...

ns.db = ns.db or {}
ns.db.rules = ns.db.rules or {}

-- XP08KT database pack
-- Add rules like:
-- ns.db.rules[123456] = ns.db.rules[123456] or {}
-- ns.db.rules[123456].__meta = { zone = "Zone, Continent", npc = "NPC Name" }
-- ns.db.rules[123456][98765] = { text = [[Option text]] }
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
SetZone("Boralus, Kul Tiras")

    local t = NPC("7th Legion Magus", 137066)
    t[48276] = { text = "The local authority has given us permission" }

    local t = NPC("\"Cap'n\" Byron Mehlsack", 136052)
    t[49167] = { text = "Train me." }

    local t = NPC("Cyrus Crestfall", 122370)
   	t.__meta.stopIfQuestAvailable = { 52194, }                                                         -- First NPCID, Stops Gossip until quest is accepted
    t[48242] = { text = "<Shake his hand.>" }

    local t = NPC("Declan Senal", 136096)
    t[48295] = { text = "Train me in Herbalism." }

    local t = NPC("Jane Hudson", 136106)
    t[49164] = { text = "Train me in Archaeology." }

    local t = NPC("Myra Cabot", 136091)
    t[48761] = { text = "Train me in Mining" }

    local t = NPC("Wesley Rockhold", 135153)
    t[48279] = { text = "Let me browse your goods" }


