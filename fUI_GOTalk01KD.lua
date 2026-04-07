---@diagnostic disable: undefined-global

local _, ns = ...

ns.db = ns.db or {}
ns.db.rules = ns.db.rules or {}

-- XP01KD database pack
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
SetZone("The Barrens, Kalimdor")

    local t = NPC("Crysa", 115286)
    t[47298] = { text = "Think you can take me in a pet battle? Let's fight!", xpop = { which = "GOSSIP_CONFIRM", containsAny = { "Let's rumble!" }, within = 3, }, }

SetZone("Darkshore, Kalimdor")

    -- Zidormi
    local t = NPC("Zidormi", 141489)
    t[49022] = { text = "Can you show me what Darkshore was like before the battle?" }

SetZone("Orgrimmar, Kalimdor")

   local t = NPC("Image of Lady Liadrin", 241677)
   t[133523] = { text = "Please summon me to the Isle of Quel'Danas." }

   local t = NPC("Nathanos Blightcaller", 135205)
   t[ 49081] = { text = "I have heard this story before. <Skip>", xpop = { which = "GOSSIP_CONFIRM", containsAny = { "Are you sure?" }, within = 3, },  }					-- Shadowlands: A Chilling Summons (61874) Nathanos Blightcaller (135205)

   local t = NPC("Nazgrim", 171791)
   t[ 52728] = { text = "I have heard this tale before. <Skip>", xpop = { which = "GOSSIP_CONFIRM", containsAny = { "Are you sure?" }, within = 3, },  }					-- Shadowlands: A Chilling Summons (61874) Nazgrim (171791)

   local t = NPC("Suspicious Citizen", { 246157, 248174 })
   t[134631] = { text = "Are you talking about the Twilight's Blade?" }
   t[134634] = { text = "Are you talking about the Twilight's Blade?" }

   local t = NPC("Trading Post", { 185473, 185472 })
   t[107825] = { text = "I'd like to see what you have to offer this month." }		-- Zen'kala (185473)
   t[107826] = { text = "I'd like to see what you have to offer this month." }		-- Shiri (185472)

SetZone("Razorwind Shores, Kalimdor")

    local t = NPC("Rotha", 254687)
    t[137156] = { text = "I'd like to upgrade my house." }
    t[137155] = { text = "I'd like to upgrade my house." }
    t[137153] = { text = "Let's do this!" }
    t[137154] = { text = "I'll be back." }

    local t = NPC("Spirit Healer", 6491)
    t[29005] = { text = "Return me to life.", xpop = { which = "GOSSIP_CONFIRM", containsAny = { "If you find your corpse", "If you return to your corpse", "return to your corpse", "lose experience", "resurrection sickness" }, within = 3, } }

SetZone("Tanaris, Kalimdor")

    local t = NPC("Time Transit Device", { 209437, 209438, 209439, 209441, 209442, 209443, })
    t[40865] = { prio = 10, text = "Bronze Dragonshrine" }
    t[40863] = { prio = 04, text = "Azure Dragonshrine" }
    t[40862] = { prio = 06, text = "Emerald Dragonshrine" }
    t[40860] = { prio = 08, text = "Obsidian Dragonshrine" }
    t[40857] = { prio = 02, text = "Ruby Dragonshrine" }
    t[40856] = { prio = 00, text = "Entryway of Time" }

SetZone("Uldum, Kalimdor")

    local t = NPC("Zidormi", 162419)
    t[51282] = { text = "Can you show me what Uldum was like during the time of the Cataclysm?" }






