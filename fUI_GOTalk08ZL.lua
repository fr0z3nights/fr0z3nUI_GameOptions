---@diagnostic disable: undefined-global

local _, ns = ...

ns.db = ns.db or {}
ns.db.rules = ns.db.rules or {}

-- XP08ZZ database pack
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

SetZone("Dazar'alor, Zandalar")

   local t = NPC("Brillin the Beauty", { 122690, })
   t[ 47954] = { text = "Let me browse your goods.", type = "", }     													-- Innkeeper Brillin the Beauty (122690)

   local t = NPC("Examiner Alerinda", { 122701, })
   t[ 49309] = { text = "Train me in Archaeology.", type = "", }     													-- Examiner Alerinda (122701)

   local t = NPC("Pin'jin the Patient", { 122700, })
   t[ 50268] = { text = "Train me in Tailoring.", type = "", }     														-- Pin'jin the Patient (122700)

   local t = NPC("Princess Talanji", { 135440, })
   t[ 47851] = { text = "Take me to King Rastakhan.", type = "", }     													-- Rastakhan (46930) Princess Talanji (135440)

   local t = NPC("Secott the Goldsmith", { 122694, })
   t[ 49216] = { text = "Train me in Mining.", type = "", }     														-- Secott the Goldsmith (122694)


