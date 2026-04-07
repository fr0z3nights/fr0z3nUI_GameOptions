local _, ns = ...

ns.db = ns.db or {}
ns.db.rules = ns.db.rules or {}

-- XPEV database pack
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
SetZone("Darkmoon Island")

	local t = NPC("Darkmoon Faire Mystic Mage", 54334)
	t.__meta.stopIfQuestAvailable = { 7905 }                                                        -- First NPCID, Stops Gossip until quest is accepted
	t[40457] = { text = "Take me to the faire...", xpop = { which = "GOSSIP_CONFIRM", containsAny = { "Travel to the faire staging area" }, within = 3, }, }

    local t = NPC("Jeremy Feasel", { 67370 })
    t[41758] = { text = "I challenge you to a pet battle!" }	-- Darkmoon Pet Battle! (32175) Jeremy Feasel (67370)

    local t = NPC("Christoph VonFeasel", { 85519 })
    t[42667] = { text = "I challenge you to a pet battle!" }	-- A New Darkmoon Challenger! (36471) Christoph VonFeasel (85519)



