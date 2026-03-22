local _, ns = ...

ns.db = ns.db or {}
ns.db.rules = ns.db.rules or {}

-- XP05 database pack
-- Add rules like:
-- ns.db.rules[123456] = ns.db.rules[123456] or {}
-- ns.db.rules[123456].__meta = { zone = "Zone, Continent", npc = "NPC Name" }
-- ns.db.rules[123456][98765] = { text = [[Option text]], type = "", xpop = { which = "GOSSIP_CONFIRM", containsAny = {"prepare yourself", "let's rumble"}, within = 3 } }
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
SetZone("Dread Wastes, Pandaria")

    local t = NPC("Kik'tik", 63501)
    t[40933] = { text = "I need to travel somewhere.", type = "", }

    local t = NPC("Flowing Pandaren Spirit", 68462)
    t[41935] = { text = "Another challenge?", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "Prepare yourself!" }, within = 3, }, type = "", }

    local t = NPC("Wastewalker Shu", 66739)
    t[41822] = { text = "Think you can take me in a pet battle? Let's fight!", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "Prepare yourself!" }, within = 3, }, type = "", }

SetZone("Jade Forest, Pandaria")

    local t = NPC("Hyuna", 66730)
    t[41814] = { text = "Think you can take me in a pet battle? Let's fight!", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "Let's do it!" }, within = 3, }, type = "", }

    local t = NPC("Whispering Pandaren Spirit", 68464)
    t[41953] = { text = "Another challenge?", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "Prepare yourself!" }, within = 3, }, type = "", }

SetZone("Krasarang Wilds, Pandaria")

    local t = NPC("Mo'ruk", 66733)
    t[41816] = { text = "Think you can take me in a pet battle? Let's fight!", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "Come at me!" }, within = 3, }, type = "", }

SetZone("Kun-Lai Summit, Pandaria")

    local t = NPC("Anthea", 176655)
    t[52501] = { text = "Let's rumble!", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "let's rumble", }, within = 3, }, type = "", }

    local t = NPC("Courageous Yon", 66738)
    t[41820] = { text = "Think you can take me in a pet battle? Let's fight!", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "You don't stand a chance!" }, within = 3, }, type = "", }

    local t = NPC("Puli the Even Handed <Innkeeper>", 62871)
    t[37168] = { text = "Let me browse your goods.", type = "", }

    local t = NPC("Thundering Pandaren Spirit", 68465)
    t[41955] = { text = "Another challenge?", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "prepare yourself" }, within = 3, }, type = "", }

SetZone("Townlong Steppes, Pandaria")

    local t = NPC("Burning Pandaren Spirit", 68463)
    t[41951] = { text = "Another challenge?", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "prepare yourself" }, within = 3, }, type = "", }

    local t = NPC("Seeker Zusshi", 66918)
    t[41155] = { text = "Think you can take me in a pet battle? Let's fight!", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "You don't stand a chance!" }, within = 3, }, type = "", }

SetZone("Vale of Eternal Blossoms, Pandaria")

    local t = NPC("Aki the Chosen", 66741)
    t[41824] = { text = "Think you can take me in a pet battle? Let's fight!", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "You're going down!" }, within = 3, }, type = "", }

SetZone("Valley of the Four Winds, Pandaria")

    local t = NPC("Farmer Nishi", 66734)
    t[41818] = { text = "Think you can take me in a pet battle? Let's fight!", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "Let's rumble!" }, within = 3, }, type = "", }


