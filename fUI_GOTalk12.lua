local _, ns = ...

ns.db = ns.db or {}
ns.db.rules = ns.db.rules or {}

--   pcn = "Name-Realm"   -- only if you are this character
--   pcn = {"Name-Realm", "Alt-Realm"} -- only if you are ANY of these characters
local CURRENT_ZONE

local t
local function SetZone(zone)
    CURRENT_ZONE = zone
end

local function PlayerHasQuestInLog(questID)
	questID = tonumber(questID)
	if not questID then
		return false
	end

	if C_QuestLog and type(C_QuestLog.IsOnQuest) == "function" then
		local ok, on = pcall(C_QuestLog.IsOnQuest, questID)
		if ok and on then
			return true
		end
	end

	if C_QuestLog and type(C_QuestLog.GetLogIndexForQuestID) == "function" then
		local ok, idx = pcall(C_QuestLog.GetLogIndexForQuestID, questID)
		return ok and type(idx) == "number" and idx > 0
	end

	if type(GetQuestLogIndexByID) == "function" then
		local ok, idx = pcall(GetQuestLogIndexByID, questID)
		return ok and type(idx) == "number" and idx > 0
	end

	return false
end

local function NormalizeRealmName(realm)
	realm = tostring(realm or "")
	realm = realm:gsub("%s+", "")
	realm = realm:gsub("%-+", "")
	return realm:lower()
end

local function PlayerIsCharacter(full)
	full = tostring(full or "")
	if full == "" then
		return false
	end

	local wantName, wantRealm = full:match("^([^%-]+)%-(.+)$")
	if not wantName then
		wantName = full
		wantRealm = nil
	end

	local name, realm
	if UnitName then
		name, realm = UnitName("player")
	end
	if not name then
		return false
	end

	if realm == nil then
		if GetNormalizedRealmName then
			realm = GetNormalizedRealmName()
		elseif GetRealmName then
			realm = GetRealmName()
		end
	end

	if tostring(name):lower() ~= tostring(wantName):lower() then
		return false
	end

	if wantRealm and wantRealm ~= "" then
		return NormalizeRealmName(realm) == NormalizeRealmName(wantRealm)
	end

	return true
end

local function TalkCacheSeen(key)
	if ns and ns.Talk and type(ns.Talk.CacheGet) == "function" then
		return ns.Talk.CacheGet(key) and true or false
	end
	return false
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

SetZone("Midnight Intro")

		t = NPC("Image of Lady Liadrin", 241677)
		t.__meta.stopIfQuestAvailable = { 91281, 88719, }                                                         -- First NPCID, Stops Gossip until quest is accepted
		t.__meta.stopIfQuestTurnIn = { 91281, }                                                            -- First NPCID, Stops Gossip until quest is accepted
		t[138201] = { prio = 10, text = "I have heard this tale before. <Skip>", xpop = { which = "GOSSIP_CONFIRM", containsAny = { "Are you sure" }, within = 3, }  }
		t[133523] = { prio = 05, text = "Please summon me to the Isle of Quel'Danas." }

SetZone("Eversong Woods, Eastern Kingdoms")

		t = MAP("Delve: The Shadow Enclave", 2502)
   		t[137580] = { text = "Use the mirrors to spread the light. Got it." }

   		t = NPC("Alesil Dawnblood", {252599, })
   		t[136288] = { text = "I'll defend the runestone" }      -- And Then They Came (92398) Alesil Dawnblood (252599)

   		t = NPC("Apprentice Erilla", {251540, })
   		t[132652] = { text = " - <Instruct the defender to go to the Runestone Shan'dor...>" }      -- What's Left (86639)                Apprentice Erilla (251540)

   		t = NPC("Arator", {236716, 242433, 236610, })
   		t[136284] = { text = "<Skip conversation> What now?" }    --                               Arator (236716)
   		t[133785] = { text = "<Skip conversation> What now?" }    --                               Arator (242433)
   		t[132886] = { text = "<Stay silent.>" }                   -- Following the Root (86643)    Arator (236610)

   		t = NPC("Arcanist Taemin", {249398, })
   		t[135184] = { text = "What's on your mind?" }                               -- A Ranger's Spirit (91385)     Arcanist Taemin (249398)

  		t = NPC("Archmage Aethas Sunreaver", {240285, })
   		local INTRO_SEEN = "GOTalk:136655:133788"
   		t[133788] = { prio = 10, text = "We have come to negotiate in peace.", when = function() return not TalkCacheSeen(INTRO_SEEN) end, cacheKey = INTRO_SEEN }
   		t[136655] = { prio = 10, text = "We don't have time for this <Skip>", when = function() return TalkCacheSeen(INTRO_SEEN) end }

   		t = NPC("Crusader Whitney", {242818, })
   		t[134237] = { text = "<Close the paladin's eyes.>" }

   		t = NPC("Grand Magister Rommath", {240532, })
   		t[132750] = { text = "Begin the ritual." }

   		t = NPC("Guard Captain Leonic", {239457, })
   		t[132706] = { text = " - Have you seen anything suspicious lately?" }                       -- Rational Explanation (86624)       Guard Captain Leonic (239457) KILLED

   		t = NPC("High Exarch Turalyon", {241654, })
   		t[132931] = { text = "I'm Ready." }

   		t = NPC("Innkeeper Kalarin", 236149)
   		t[132744] = { text = "Have you seen anything strange recently?", prio = 10 }                          -- Rational Explanation (86624)
   		t[137854] = { text = "Let me browse your goods.", prio = -5 }
   		t[137856] = { text = "HOLD SHIFT TO BIND HEARTHSTONE MANUALLY", xpop = { which = "GOSSIP_CONFIRM", containsAll = { "do you want to make", "your new home" }, within = 3, }, prio = -10, noAuto = true }

   		t = NPC("Instructor Thalendir", {245285, })
   		t[134484] = { text = "<Give Recommendation.>" }                                                       -- How to Train Your Protege (91301) Instructor Thalendir (245285)

   		t = NPC("Jesthenis Sunstriker", {247085, })
   		t[134482] = { text = "I am ready to fight." }                                                         -- A Test of Blood (91291) Jesthenis Sunstriker (247085)

   		t = NPC("Kyltus Bloodburn", {246557, })
   		t[134090] = { text = "<Pick the one that showed the most courage.>" }                                 -- How to Train Your Protege (91301) Kyltus Bloodburn (246557)

   		t = NPC("Lord Antenorian", {245004, })
   		t[134001] = { text = " - Lie to Lord Antenorian about how much you know." }                           -- The First to Know (90907) Lord Antenorian (245004)      DELVE BOSS

   		t = NPC("Luna", {242688, })
   		t[133262] = { text = "<Pet Luma.>" }                                                                  -- Thief at Bark (90544) Luna (242688)
   		t[137322] = { text = "<Pet Luma.>" }                                                                  -- Thief at Bark (90544) Luna (242688)

   		t = NPC("Mage Follower", {237890, 238112, 238113 })
   		t[132313] = { text = "<Explain situation and ask to spar.>" }                                         -- Training Arc (86998) Mage Follower (237890)

   		t = NPC("Magistrix Silanna", {251539, })
   		t[132680] = { text = " - I'll cover your escape." }                                                   -- What's Left (86639) Magistrix Silanna (251539)

   		t = NPC("Magistrix Umbric", {264067, })
   		t[139725] = { text = "Seems easy enough." }                                                           -- The Shadowed Spire (96228) Magistrix Umbric (264067)

   		t = NPC("Matron Narsilla", {242568, })
   		t[133913] = { text = "What problems ail the people of Tranquillien?" }                                -- Rational Explanation (86624) Matron Narsilla (242568)      KILLED

   		t = NPC("Melandria", {247800, })
   		t[38266] = { text = "Train Me.", prio = 0 }  -- Fishing Trainer  Melandria (247800)
   		t[38267] = { text = "Show Me Your Goods", prio = 5, print = "MidnightFishing" }                       -- Fishing Trainer  Melandria (247800)

   		t = NPC("Orweyna", {236743, 236903, 236704, })
   		t[133725] = { text = "Let's follow the trail you found." }
   		t[132833] = { text = "I'm ready when you are." }
   		t[135559] = { text = "I'm ready, Lets go!" }                                                          -- The Root Cause (86899)             Orweyna (236704)

   		t = NPC("Outrunner Alarion", {251542, })
   		t[135781] = { text = " - <Instruct the defender to go to the Runestone Shan'dor...>" }                -- What's Left (86639)                Outrunner Alarion (251542)

   		t = NPC("Quartermaster Lymel", {244840, })
   		t[133888] = { text = "Have there been any issues around town lately?" }                               -- Rational Explanation (86624)       Quartermaster Lymel (244840)

   		t = NPC("Ranger Belonis", {239406, })
   		t[132894] = { text = "You've had scouts go missing?" }                                                -- Rational Explanation (86624)       Ranger Belonis (239406)

   		t = NPC("Ranger Valsarin", {248307, })
   		t[134809] = { text = "Saddle me up!" }                                                                -- Strider Stampede (91347)           Ranger Valsarin (248307)

   		t = NPC("Salandria", {242893, })
   		t[135497] = { text = "I am ready to begin." }                                       				-- Interrogation (90552) Salandria (242893)

   		t = NPC("Secretary Faloria", {239405, })
   		t[132741] = { text = " - We need to speak to Lord Antenorian" }                                       -- The First to Know (90907)          Secretary Faloria (239405)    KILLED

   		t = NPC("Sheri", {251405, })
   		t[136683] = { text = "I would like to see your wares", prio = 10, }                                   -- Sheri (251405)

   		t = NPC("Skymaster Sunwing", {238480, })
   		t[34101] = { text = "I'd like to fly back to Silvermoon City", prio = 5, }                            -- Skymaster Sunwing (238480)

   		t = NPC("Solwin Brightstitch", {252156, })
   		t[135911] = { text = "I'm ready for anything!" }                                                      -- Clothes Make the Man (91389)       Solwin Brightstitch (252156)

   		t = NPC("Stone Vat", {587307, })
   		t[136681] = { text = "<Deposit 10 Bunches of Ripe Grapes into the vat." }                             -- () Stone Vat (587307)
   		t[136684] = { text = "<Deposit Packet of Instant Yeast into the vat." }                               -- () Stone Vat (587307)

   		t = NPC("Talandra Dawnsprite", {249337, })
   		t[136372] = { text = " - Very well." }                                                                -- Flowers for Amalthea (92025)       Talandra Dawnsprite (249337)

   		t = NPC("Trainee Solamine", {251543, })
   		t[132684] = { text = " - <Instruct the defender to go to the Runestone Shan'dor...>" }                -- What's Left (86639)                Trainee Solamine (251543)

   		t = NPC("Valeera Sanguinar", {242099, })
   		t[136049] = { text = "I'm Ready." }

   		t = NPC("Valdekar Solaar", {245745, })
   		t[134361] = { text = "<Hand over the fish.>" }                                                        -- A Fish! (91271) Valdekar Solaar (245745)   
   		t[134506] = { text = "<Hand over the fish.>" }                                                        -- A Fish! (91271) Valdekar Solaar (245745)   
   		t[134505] = { text = "<Hand over the fish.>" }                                                        -- A Fish! (91271) Valdekar Solaar (245745)   

   		t = NPC("Zul'jan", 249211)
   		t[135099] = { text = "Return to Zul'Aman", }                                                          -- The Line Must be Drawn Here (86710) Zul'jan (249211)

   		t = NPC("Unknown NPC", {207283, })
   		t[122661] = { text = "<View goods and repair gear.>", prio = 10,  }
   		t[135011] = { text = "<View companion supplies.>", prio = -10,  }

   		t = NPC("Quest: House Call", {253050, 253054, 254710, })
   		t[136353] = { text = "Something is watching you." }                                                   -- House Call (92024)    Stained Tool Rack (253050)
   		t[136354] = { text = "Something is watching you." }                                                   -- House Call (92024)    Suspicious Urn (253054)
   		t[136355] = { text = "Something is watching you." }                                                   -- House Call (92024)    Well-Loved Tome (254710)

   		t = NPC("Quest: Suspicious Sundries", {249436, 249437, 249426, })
   		t[136321] = { text = "I would like to see your wares", prio = 10, }                                   -- Suspicious Sundries (92023) Vehn Sorrelstride (249439)
   		t[136322] = { text = "I would like to see your wares", prio = 10, }                                   -- Suspicious Sundries (92023) Nara Fadebranch (249437)
   		t[136323] = { text = "I would like to see your wares", prio = 10, }                                   -- Suspicious Sundries (92023) Limien Bountcask (249426)

   		t = NPC("Quest: Familiar Faces in Peril", { 248060, 248058, 248059, })
   		t[134652] = { text = "Get to safety." }                                                               -- Familiar Faces in Peril (91495)     Apothecary Enith (248060)
   		t[134653] = { text = "Get to safety." }                                                               -- Familiar Faces in Peril (91495)     Ranger Vedoran (248058)
   		t[134654] = { text = "Get to safety." }                                                               -- Familiar Faces in Peril (91495)     Apprentice Varnis (248059)

   		t = NPC("Quest: Gods Before Us", {542849, 542850, })
   		t[133889] = { text = "<Place Bonecarapace Fangs into the vase.>", close = true }                      -- Gods Before Us (86644)             Ritual Vase (542849)
   		t[133890] = { text = "<Place Bloodvein Clot into the vase.>", close = true }                          -- Gods Before Us (86644)             Ritual Vase (542850)

   		t = NPC("Quest: Light Guide Us", {258559, 258560, 258561, 258562, 258563, 258564, 258565, 258566, })
   		t[137985] = { text = "Stop! The Amani are not the real threat here" }                                 -- Light Guide Us (86648)             Eversong Farstrider (258559)
   		t[137986] = { text = "Stop! The Amani are not the real threat here" }                                 -- Light Guide Us (86648)             Eversong Spellbreaker (258560)
   		t[137987] = { text = "Stop! The Amani are not the real threat here" }                                 -- Light Guide Us (86648)             Eversong Arch Magister (258561)
   		t[137988] = { text = "Stop! The Amani are not the real threat here" }                                 -- Light Guide Us (86648)             Blessed Lightbringer (258562)
   		t[137989] = { text = "Stop! The Amani are not the real threat here" }                                 -- Light Guide Us (86648)             Veteran Blood Knight (258563)
   		t[137990] = { text = "Stop! The Amani are not the real threat here" }                                 -- Light Guide Us (86648)             Blessed Lightbringer (258564)
   		t[137991] = { text = "Stop! The Amani are not the real threat here" }                                 -- Light Guide Us (86648)             Eversong Magister (258565)
   		t[137992] = { text = "Stop! The Amani are not the real threat here" }                                 -- Light Guide Us (86648)             Veteran Blood Knight (258566)

SetZone("Harandar, Eastern Kingdoms")

   		t = NPC("Akazi", { 253392, 253392, })
   		t[136773] = { text = "<Ask about mentoring Ketan.>" }                                                 -- A Hunter's Plight (92882) Akazi (253392)
   		t[136774] = { text = "<Accept the task.>" }                                                           -- A Hunter's Plight (92882) Akazi (253392)
   		t[136842] = { text = "<Present the Ka'dani spear.>" }                                                 -- A Hunter's Weapon (92884) Akazi (253392)

   		t = NPC("Altar of Innocence", { 588929, })
   		t[136716] = { prio = 05, text = "<Meditate here for a moment.>" }                                     -- Toy () Altar of Innocence (588929)

  		t = NPC("Altar of Wisdom", { 590789, 254116, })
   		t[136764] = { prio = 05, text = "<Meditate here for a moment.>" }                                     -- Toy () Altar of Wisdom (590789)
   		t[136767] = { prio = 10, text = "<Offer the old rolled up pillow...>", close = true }                 -- Toy () Elder Spirit (254116)

   		t = NPC("Ashayo", { 256441, 255763, })
   		t[137389] = { text = "Deal with the big ones. Got it." }                                              -- Down the Rootways (86912) Ashayo (256441)
   		t[137248] = { text = "Release the moths near Lightbloom patches." }                                   -- Down the Rootways (86912) Ashayo (255763)

   		t = NPC("Brakko", { 243178, 246208, 257287, })
   		t[135601] = { text = "<Ask if they want to join your new team.>", close = true }                      -- A Few Fun Guys (90617) Brakko (243178)
   		t[135664] = { text = "<Ask your new teammate to spar.>" }                                             -- What Doesn't Kill Them (90619) Brakko (246208)
   		t[136986] = { text = "Do you have any good ideas we could use for a team name?", close = true }       -- The Most Important Thing (91270) Brakko (257287)

   		t = NPC("Child-Like Spirit", { 254030, })
   		t[136724] = { text = "Who are you?" }                                          

   		t = NPC("Danul", { 237865, })
   		t[133726] = { text = "It's safe to return to the village." }                                          -- To Har'athir (86900)          Danul (237865)

   		t = NPC("Doecha", { 255056, })
   		t[133777] = { text = "What can you tell me about the Rift of Aln?" }                                  -- Watch the Den (86864) Doecha (255056)

   		t = NPC("Eager Volunteer", { 241690, })
   		t[132939] = { text = "This Alndust will protect you from the Lightbloom so we can fight them.", }     -- Alndust in Right Hands (86882) Eager Volunteer (241690)

   		t = NPC("En'liahn", { 244394, 244456, 244465,})
   		t[133898] = { text = "Let's go find your ritual site.", }                                             -- The Path Will Reveal Iteself (90830) En'liahn (244394)
   		t[133930] = { text = "The wards are placed. Let's begin.", }                                          -- As Her Voice Goes Silent (90832) En'liahn (244456)
   		t[134053] = { text = "Grim. I'm ready when you are.", }                                               -- The Final Rite (90833) En'liahn (244465)

   		t = NPC("Eonka", { 240225, 244126, })
   		t[132714] = { text = "<Ask if they have Lightbloom in their village.>" }                              -- The Traveling Flowers (86956) Eonka (240225)
   		t[133712] = { text = "Are you still feeling well?" }                                                  -- Seeds of the Rift (86944) Eonka (244126)

   		t = NPC("F'liks", { 254620, })
   		t[137324] = { text = "<Pick up the budling.>" }                                                       -- Re-Hydra-ted (92866) F'liks (254620)

   		t = NPC("Grumpy", { 253313, })
   		t[137323] = { text = "<Pick up the budling.>" }                                                       -- Re-Hydra-ted (92866) Grumpy (253313)

   		t = NPC("Halduron Brightwing", { 237343, 237345, 237787, 250363, })
   		t[133774] = { text = "Let's head down." }                                                             -- To Har'athir (86900)    Halduron Brightwing (237343)
   		t[133792] = { text = "Let's go." }                                                                    -- The Council Assembles (86929) Halduron Brightwing (237345)
   		t[138702] = { text = "<Hand Halduron the glimmering bag of seeds.>" }                                 -- Seeds of the Rift (86944) Halduron Brightwing (237787)
   		t[135501] = { text = "I am ready." }                                                                  -- Tell the People What You Have Seen (86890) Halduron Brightwing (250363)

   		t = NPC("Hannan", { 241655, })
   		t[132933] = { text = "What happened here?", }                                                         -- Alndust in Right Hands (86882) Hannan (241655)

   		t = NPC("Imhayo", { 242596, })
   		t[138674] = { text = "Let me browse your goods.", }                                                   -- Go Get Orweyna (90533) Imhayo (242596)

   		t = NPC("Innkeeper Yinaa", 240404)
   		t[132851] = { text = "What can you tell me about the Rift of Aln", prio = 10 }                        -- Watch the Den (86864) Innkeeper Yinaa (240404)
   		t[132728] = { text = "I'd like to browse your goods.", prio = -5 }
   		t[132729] = { text = "Make this inn your home.", xpop = { which = "GOSSIP_CONFIRM", containsAll = { "do you want to make", "your new home" }, within = 3, }, prio = -10, noAuto = true }

   		t = NPC("Keem", { 243930, })
   		t[133684] = { text = "<Ask if they have Lightbloom in their village.>" }                              -- The Traveling Flowers (86956) Keem (243930) DEAD

   		t = NPC("Ketan", { 254252, 255809, 253443, })
   		t[137250] = { text = "<Ask about Ketan's progress.>" }
   		t[137251] = { text = "<Ask about Ketan's progress.>" }
   		t[136855] = { text = "I am ready." }                                                                  -- A Hunter's Prey (92885) Ketan (254252)

   		t = NPC("Ku'paal", { 237209, 241045, })
   		t[132537] = { text = "We are froemds of Orweyna and we are here to help." }                           -- To Har'athir (86900) Ku'paal (237209)
   		t[132858] = { text = "What can you tell me about the Rift of Aln", }                                  -- Watch the Den (86864) Ku'paal (241045)

   		t = NPC("Mothkeeper Wew'tam", { 251259, })
   		t.__meta.stopIfQuestAvailable = { 92448, }   -- First NPCID, Stops Gossip until quest is accepted
   		t.__meta.stopIfQuestTurnIn = { 92448, }      -- First NPCID, Stops Gossip when turn in available
   		t[136981] = { text = "I have some Luminous Dust for trade." }                                         -- Vendor Mothkeeper Wew'tam (251259)

   		t = NPC("N'ala", { 254622, })
   		t[137321] = { text = "<Pick up the budling.>" }                                                       -- Re-Hydra-ted (92866) N'ala (254622)

   		t = NPC("Naynar", 240407)
   		t[132852] = { text = "What can you tell me about the Rift of Aln", prio = 10 }                        -- Watch the Den (86864) Naynar (240407)
   		t[132730] = { text = "Can I see the Renown items you have for sale?", prio = -5 }

   		t = NPC("Ney'leia", { 242684, })
   		t[133929] = { text = "I'm ready. Let's go." }                                                         -- Late Bloomers (90537) Ney'leia (242684)

   		t = NPC("Oorla", { 237866, })
   		t[133721] = { text = "It's safe to return to the village." }                                          -- To Har'athir (86900)          Oorla (237866)

   		t = NPC("Orweyna", { 237210, 253343, 242592, })
   		t[131842] = { text = "<Take in the view.>" }                                                          -- To Har'athir (86900) Orweyna (237210)
   		t[136444] = { text = "<Hand Orweyna the Fragment of Revelation.>" }                                   -- Down the Rootways (86912) Orweyna (253343)
   		t[133239] = { text = "<Explain Gazlowe's predicament to Orweyna.>" }                                  -- Go Get Orweyna (90533) Orweyna (242592)

   		t = NPC("Rizam", { 240239, })
   		t[132927] = { text = "<Ask if they have Lightbloom in their village.>" }                              -- The Traveling Flowers (86956) Rizam (240239) DEAD

   		t = NPC("Shao'mal", { 247640, })
   		t[134812] = { text = "<Begin the game.>" }                                                       -- Re-Hydra-ted (92866) Shao'mal (247640)

   		t = NPC("T'omm", { 254621, })
   		t[137325] = { text = "<Pick up the budling.>" }                                                       -- Re-Hydra-ted (92866) T'omm (254621)

   		t = NPC("Teetem", { 240238, })
   		t[132713] = { text = "<Ask if they have Lightbloom in their village.>" }                              -- The Traveling Flowers (86956) Teetem (240238) DEAD

   		t = NPC("Tuktuk", { 243181, 246210, 251715, 247252, })
   		t[135600] = { text = "<Ask if they want to join your new team.>", close = true }                      -- A Few Fun Guys (90617) Tuktuk (243181)
   		t[135663] = { text = "<Ask your new teammate to spar.>" }                                             -- What Doesn't Kill Them (90619) Tuktuk (246210)
   		t[136991] = { text = "Do you have any good ideas we could use for a team name?", close = true }       -- The Most Important Thing (91270) Tuktuk (251715)
   		t[136990] = { text = "I'm ready to choose a team name, Tuktuk." }                                     -- The Most Important Thing (91270) Tuktuk (251715)
   		t[135670] = { text = "The Fungal Fellowship.", close = true }                                         -- The Most Important Thing (91270) Tuktuk (251715)
   		t[136164] = { text = "No one starts ready. That's why we train" }                                     -- Mushrooming Confidence (92618) Tuktuk (247252)
   		t[136163] = { text = "You're right, Tuktuk won't be good enough..." }                                 -- Mushrooming Confidence (92618) Tuktuk (247252)
   		t[136162] = { text = "If you stay, you'll get soggy..." }                                             -- Mushrooming Confidence (92618) Tuktuk (247252)

   		t = NPC("Ziny", { 243180, 246211, 251723, })
   		t[135599] = { text = "<Ask if they want to join your new team.>", close = true }                      -- A Few Fun Guys (90617) Ziny (243180)
   		t[135666] = { text = "<Ask your new teammate to spar.>" }                                             -- What Doesn't Kill Them (90619) Ziny (246211)
   		t[136989] = { text = "Do you have any good ideas we could use for a team name?", close = true }       -- The Most Important Thing (91270) Ziny (251723)

   		t = NPC("Zur'ashar Kassameh", { 237837, })
   		t[131932] = { text = "I am ready to begin the trials." }                                              -- Echoes and Memories (86911)   Zur'ashar Kassameh (237837)

SetZone("Quel'Thalas, Eastern Kingdoms")
		--
   		t = NPC("Alonsus Faol", { 236789, 240240, 251355, })
   		t[132515] = { text = "The Vanguard rallies at Sunstrider Rise." }                                     -- Champions of Quel'Danas (68770)  Alonsus Faol (236789)
   		t[138693] = { text = "<Tell Alonsus you are ready to go to Light's Hope.>" }                          -- Relic's of Light's Hope (86839) Alonsus Faol (240240)
   		t[135480] = { text = "<Tell Alonsus you are ready to go to Hammerfall.>" }                            -- The Sunwalker Path (86845) Alonsus Faol (251355)

   		t = NPC("Arator", { 236959, 237502, })
   		t[132388] = { text = "Your father sent me to find you." }                                             -- My Son (89271) Arator (236959)
   		local INTRO_SEEN = "GOTalk:136469:134861"
   		t[134861] = { prio = 10, text = "What are you going to do with the shield?", when = function() return not TalkCacheSeen(INTRO_SEEN) end, cacheKey = INTRO_SEEN }
   		t[136469] = { prio = 10, text = "Let's get back to Silvermoon.", when = function() return TalkCacheSeen(INTRO_SEEN) end }

   		t = NPC("Belo'vir's Security Ward", { 651990, 651991, 651992, })
   		t[140404] = { text = "<Unravel the wards>" }                                                          -- Unravelling the Wards (96230) Belo'vir's Security Ward (651990)
   		t[140408] = { text = "<Unravel the wards>" }                                                          -- Unravelling the Wards (96230) Belo'vir's Security Ward (651991)
   		t[140406] = { text = "<Unravel the wards>" }                                                          -- Unravelling the Wards (96230) Belo'vir's Security Ward (651992)

  		t = NPC("Commander Koruth Mountainfist", { 247304, })
   		t[134577] = { text = "Are the warframes prepared, Commander?" }                                       -- Feeding the Flame (90777) Commander Koruth Mountainfist (247304)

   		t = NPC("Commander Venel Lightblood", { 247305, })
   		t[134511] = { text = "Let's give these recruits something to aspire to." }                            -- Feeding the Flame (90777) Commander Venel Lightblood (247305)

   		t = NPC("Faerin Lothar", { 237211, })
   		t[132513] = { text = "The Vanguard rallies at Sunstrider Rise." }                                     -- Champions of Quel'Danas (68770)  Faerin Lothar (237211)

   		t = NPC("Grand Magister Rommath", { 264068, 264066, 264070, })
   		t[139813] = { text = "I can do that." }                                                               -- Unravelling the Wards (96230)  Grand Magister Rommath (264068)
   		t[139847] = { text = "I am ready." }                                                                  -- The Omnium Reawakens (96233)  Grand Magister Rommath (264068)
   		t[139871] = { text = "Powerful runic enchantments? Count me in." }                                    -- Seeking Knowledge (96410)  Grand Magister Rommath (264070)
   		t[139890] = { text = "<Take the Omnium Folio from Rommath.>" }                                        -- Seeking Knowledge (96410)  Grand Magister Rommath (264070)

   		t = NPC("High Exarch Turalyon", 237255)
   		t[133285] = { text = "Let's drive this threat back!" }

   		t = NPC("Lady Liadrin", {237278, 247414})
   		t[132924] = { text = "Nothing will get past me!" }
   		t[133700] = { text = "How does the Sunwell fare, Liadrin?" }                                          -- Feeding the Flame (90777) Lady Liadrin (247414)

   		t = NPC("Lathraxion", { 236657, })
   		t[132514] = { text = "The Vanguard rallies at Sunstrider Rise." }                                     -- Champions of Quel'Danas (68770)  Lathraxion (236657)

   		t = NPC("Magister Umbric", { 235395, 234148, })
   		t[131939] = { text = "<Tell Umbric you'd like to enter Magiers' Terrace.>" }                          -- Magisters' Terrace: Homecoming (86543) Magister Umbric (235395)
   		t[135804] = { text = "<Tell Umbric you'd like to enter Magiers' Terrace.>" }                          -- Magisters' Terrace: Homecoming (86543) Magister Umbric (234148)

   		t = NPC("Mehlar Dawnblade", { 248321, })
   		t[134854] = { text = "This is Uther's kit from his work as a healer...", close = true }               -- Relinquishing Relics (86902)  Mehlar Dawnblade (248321)

   		t = NPC("Prophet Velen", { 239623, })
   		t[136038] = { text = "<Give Velen the remaining relics to distribute.>", close = true }               -- Relinquishing Relics (86902)  Prophet Velen (239623)

   		t = NPC("Salandria", { 248322, })
   		t[134853] = { text = "Take this sword. It has a great deal of Light within it...", close = true }     -- Relinquishing Relics (86902)  Salandria (248322)

   		t = NPC("Scared Civilian", { 240156, 240125, 240075, 240074, 240152, 240073, 240068, })
   		t[132686] = { text = "Arator and I will see you safely to the boats." }                               -- The Hour of Need (86805)   Scared Civilian (240156)
   		t[132670] = { text = "Arator and I will see you safely to the boats." }                               -- The Hour of Need (86805)   Scared Civilian (240125)
   		t[132655] = { text = "Arator and I will see you safely to the boats." }                               -- The Hour of Need (86805)   Scared Civilian (240075)
   		t[132654] = { text = "Arator and I will see you safely to the boats." }                               -- The Hour of Need (86805)   Scared Civilian (240074)
   		t[132685] = { text = "Arator and I will see you safely to the boats." }                               -- The Hour of Need (86805)   Scared Civilian (240152)
   		t[132656] = { text = "Arator and I will see you safely to the boats." }                               -- The Hour of Need (86805)   Scared Civilian (240073)
   		t[132653] = { text = "Arator and I will see you safely to the boats." }                               -- The Hour of Need (86805)   Scared Civilian (240068)

   		t = NPC("Taelia Fordragon", { 248323, })
   		t[134818] = { text = "I have a relic to sustain you. It's Mara Fordragon's ...", close = true }       -- Relinquishing Relics (86902)  Taelia Fordragon (248323)

   		t = NPC("Valunei", { 248326, })
   		t[134855] = { text = "Vindicator Maraad found peace and strength from this...", close = true }        -- Relinquishing Relics (86902)  Valunei (248326)

   		t = NPC("War Chaplain Senn", { 247306, })
   		t[134509] = { text = "Will you bless me, Chaplain?" }                                                 -- Feeding the Flame (90777) War Chaplain Senn (247306)

SetZone("Naigtal, Eastern Kingdoms")

   		t = NPC("Archmage Y'mera", { 266034, })
   		t[140098] = { text = "I found these crystals on ethereal devices ...", close = true }           -- Conductive Crystals (96569)  Archmage Y'mera (266034)

   		t = NPC("Coorina Brightblade", { 268804, })
   		t[140860] = { text = "I want to browse your goods."}           									-- Vendor  Coorina Brightblade (268804)

   		t = NPC("Kifaan", { 265559, })
   		t.__meta.stopIfQuestAvailable = { 96569, }                                                      -- Waits for Quest Accepted (First NPCID Only)
   		t.__meta.stopIfQuestTurnIn = { 96569, }                                                        	-- Waits for Quest Hand-Ins (First NPCID Only)
   		t[139928] = { text = "May I browse your wares?"}           										-- Vendor  Kifaan (265559)

		t = NPC("Encrypted Data Collator", { 266038, 266038, })
   		t[139982] = { text = "<Activate manual decryption.>"}                           						-- Data Decryption Disaster (96567) Encrypted Data Collator (266038)
   		t[140070] = { text = "<Smack the console with your weapon.>"}                           				-- Data Decryption Disaster (96567) Encrypted Data Collator (266038)

SetZone("Silvermoon City, Eastern Kingdoms")

   		t = NPC("Allari the Souleater", { 263524, })
   		t[139905] = { text = "Are you joining Riftblade Maella's strike team?", close = true}                           		-- Stalkers of the Stars (96049) Allari the Souleater (263524)

		t = NPC("Arator", { 244644, 237510, 240267, })
   		t[133853] = { text = "Alonsus Faol asks that we meet him at the Sunwell." }                           -- Meet at the Sunwell (86837)   Arator (244644)
   		t[133856] = { text = "Let's go." }                                                                    -- Meet at the Sunwell (86837)   Arator (244644)
   		t[133121] = { text = "I'm ready!" }                                                                   -- A Bulwark Remade (86833)      Arator (237510)
   		t[136685] = { text = "What will you do next?" }                                                       -- A Bulwark Remade (86833)      Arator (237510)
   		t[133560] = { text = "Let's go. (Start Scenario)" }                                                   -- The Battle of the Bridge (88769) Arator (240267)
   		local INTRO_SEEN = "GOTalk:136564:136565"
   		t[136565] = { prio = 10, text = "Let's discuss the plan in full", when = function() return not TalkCacheSeen(INTRO_SEEN) end, cacheKey = INTRO_SEEN }
   		t[136564] = { prio = 10, text = "I don't have time <Skip>", when = function() return TalkCacheSeen(INTRO_SEEN) end }

   		t = NPC("Archmage Y'mera", { 263519, })
   		t[140038] = { text = "I can help, but I'll need some help becoming invisible." }                         -- Veterams of the Great Dark (96703) Archmage Y'mera (263519)

		t = NPC("Anduin Wrynn", { 249289, })
   		t[135179] = { text = "<Explain that Lor'Themar wants to see Umbric freed.>" }                         -- You Know This Evil? (91967) Anduin Wrynn (249289)
   		t[135178] = { text = "<Explain how Umbric is reaserching a way into the Voidstorm>" }                 -- You Know This Evil? (91967) Anduin Wrynn (249289)

   		t = NPC("Astalor Bloodsworn", { 258221, })
   		t[135889] = { text = "I'm ready." }                                                                   -- Practical Magic (92178) Astalor Bloodsworn (258221)

   		t = NPC("Delver's Guide", 254565)
   		t[136916] = { text = "<Review information on your current delve progress.>" }                         -- Delver's Guide (254565)

   		t = NPC("General Amias Bellamy", { 248629, 250587, })
   		t[135224] = { text = "<Offer Greeting.>" }                                                            -- Paved in Ash (86735) General Amias Bellamy (248629)
   		t[135530] = { text = "Lor'themar requires a report." }                                                -- Rising Storm (92061) General Amias Bellamy (250587)

   		t = NPC("Baraat the Longshot", { 263520, })
   		t[139901] = { text = "Are you joining Riftblade Maella's strike team?", close = true}           		-- Veterans of the Great Dark (96703) Baraat the Longshot (263520)

   		t = NPC("Belath Dawnblade", { 263523, })
   		t[139484] = { text = "Riftblade Maella is ready. She awaits ...", close = true}           				-- Stalkers of the Stars (96049) Belath Dawnblade (263523)

		t = NPC("Belil", 241455)
   		t[133290] = { text = "I've never seen a rock in my life...", prio = 10 }                              -- Five Finger Discount (89204) Belil (241455)
   		t[133293] = { text = "Train me in Mining", prio = -5 }

   		t = NPC("Captain Fareeya", 268330)
   		t[140523] = { text = "Are you joining Riftblade Maella's strike team?", close = true}        			-- Veterans of the Great Dark (96703) Captain Fareeya (268330)

		t = NPC("Ceera <Banker>", 239664)
   		t[132676] = { text = "H Lor'themar has requested that we be allowed...", prio = 10 }                  -- Paved in Ash (86735) Ceera (239664)
   		t[134013] = { text = "A The Alliance will be staying here temporarily.", prio = 9 }                   -- Paved in Ash (86735) Ceera (239664)
   		t[132677] = { text = "I would like to check my deposit box.", prio = -10 }

   		t = NPC("Commander Tala'saan", { 263522, })
   		t[139483] = { text = "Riftblade Maella is ready. She awaits ...", close = true}                          -- Veterans of the Great Dark (96703) Commander Tala'saan (263522)

		t = NPC("Commander Venei Lightblood", { 248630, })
   		t[135203] = { text = "Why are you seizing people?" }                                                  -- Deepening Shadows (91854) Commander Venei Lightblood (248630)
   		t[135204] = { text = "Arresting citizens is not why the Vanguard are here." }                         -- Deepening Shadows (91854) Commander Venei Lightblood (248630)

   		t = NPC("Denorin", { 244469, })
   		t[133942] = { text = "My employer asked me to look for some unique mana wyrms." }                     -- Murder Row: Acting the Part (90819) Denorin (244469)
   		t[133942] = { text = "My employer asked me to look for some unique mana wyrms." }                     -- Murder Row: Acting the Part (90819) Denorin (244469)

   		t = NPC("Doomsayer", { 248826, })
   		t[135052] = { text = "Hail the victories of the Vanguard and Sin'dorei you have seen so far." }       -- Deepening Shadows (91854) Doomsayer (248826)

   		t = NPC("Drathen", 253468)
   		t.__meta.stopIfQuestAvailable = { 92869, }                                                            -- Waits for Quest Accepted (First NPCID Only)
   		t.__meta.stopIfQuestTurnIn = { 92868, 92869, }                                                        -- Waits for Quest Hand-Ins (First NPCID Only)
   		t[136540] = { text = "Train me." }

   		t = NPC("Gaari", { 247647, })
   		t[135588] = { text = "Mr. Brightstitch isn't accepting more work right now." }                        -- Mad to Measure (91386) Gaari (247647)

   		t = NPC("Galana", { 243352, })
   		t.__meta.stopIfQuestAvailable = { 93696, }                                                            -- Waits for Quest Accepted (First NPCID Only)
   		t.__meta.stopIfQuestTurnIn = { 93730, }                                                               -- Waits for Quest Hand-Ins (First NPCID Only)
   		t[138587] = { text = "Train me in Tailoring." }                                                       -- Tailoring Trainer Galana (243352)

   		t = NPC("Grand Magister Rommath", 249270)
   		t[135139] = { text = "<Explain that Lor'themar wants to see Umbric freed.>" }                         -- You Know This Evil? (91967) Grand Magister Rommath (249270)
   		t[135140] = { text = "<Explain how Umbric is reaserching a way into the Voidstorm>" }                 -- You Know This Evil? (91967) Grand Magister Rommath (249270)

   		t = NPC("Guard Captain Goldblade", 240936)
   		t[132828] = { text = "The Alliance will be staying..." }                                              -- Paved in Ash (86735) Guard Captain Goldblade (240936)

   		t = NPC("High Exarch Turalyon", 250580)
   		t[135523] = { text = "Lor'themar requires a report" }                                                 -- Rising Storm (92061) High Exarch Turalyon (250580)

   		t = NPC("Jaeth", { 241399, })
   		t[132992] = { text = "<Lay the documents on the table...>" }                                          -- Mutual Benefit (89203) Jaeth (241399)

   		t = NPC("Jovia <Innkeeper>", 239630)
   		t[134012] = { text = "The Alliance will be staying here temporarily. Lodgings will be needed.", prio = 10 }
   		t[132666] = { text = "Lor'themar has allowed us to stay for now...", prio = 9 }                       -- Paved in Ash (86735) Innkeeper Jovia (239630)
   		t[132667] = { text = "Let me browse your goods.", prio = -5 }
   		t[132668] = { text = "HOLD SHIFT TO BIND HEARTHSTONE MANUALLY", xpop = { which = "GOSSIP_CONFIRM", containsAll = { "do you want to make", "your new home" }, within = 3, }, prio = -10, noAuto = true }

   		t = NPC("Lendranil", { 242200, })
   		t[133247] = { text = "I have some very specific upgrade needs for these gloves..." }                  -- Five Finger Discount (89204) Lendranil (242200)

		t = NPC("Leona Darkstrider", { 263525, })
   		t[139507] = { text = "Grant me Spectral Sight and I will attune the Ward." }                  			-- Stalkers of the Stars (96049) Leona Darkstrider (263525)

   		t = NPC("Lor'themar Theron", 235787)
   		t[132632] = { text = "<Skip conversation> I expect you'll sort things out." }                         -- Unknown Quest (XXXXX) Lor'themar Theron (235787)
   		t[134143] = { text = "What now?" }                                                                    -- Fractured (86650) Lor'themar Theron (235787)

   		t = NPC("Lothene", 241458)
   		t[133298] = { text = "I have a bag full of creature parts ...", prio = 10 }                           -- Five Finger Discount (89204) Lothene (241458)
   		t[133299] = { text = "What do you have for sale?", prio = -5 }

   		t = NPC("Lothraxion", { 249268, })
   		t[135157] = { text = "<Explain that Lor'Themar wants to see Umbric freed.>" }                         -- You Know This Evil? (91967) Lothraxion (249268)
   		t[135156] = { text = "<Explain how Umbric is reaserching a way into the Voidstorm>" }                 -- You Know This Evil? (91967) Lothraxion (249268)

   		t = NPC("Magister Dawnblaze", { 241490, })
   		t[133545] = { text = "We killed Aradis and freed the people he too from Murder Row." }                -- What We're Owed (89208) Magister Dawnblaze (241490)

   		t = NPC("Magistrix Narinth", 239673)
   		t[132678] = { text = "H Lor'themar has has allowed us to stay in the city...", prio = 10 }            -- Paved in Ash (86735) Magistrix Narinth (239673)
   		t[134011] = { text = "A The Alliance will be staying longer than expected.", prio = 10 }              -- Paved in Ash (86735) Magistrix Narinth (239673)

   		t = NPC("Magistrix Nizara", 240940)
   		t[134014] = { text = "A The Alliance will be staying longer than expected.", prio = 10 }              -- Paved in Ash (86735) Magistrix Nizara (240940)
   		t[132845] = { text = "Let me browse your goods.", prio = -10 }                                        -- Quartermaster Magistrix Nizara (240940)

   		t = NPC("Maren Silverwing", 255473 )
   		t[139420] = { text = "I'd like to exchange Field Accolades for gear."  }                    			-- Murder Row: Acting the Part (90819) Miss Len'dali (244471)

   		t = NPC("Miss Len'dali", { 244471, })
   		t[133938] = { text = [[My employer sent me to purchase some "special" reagents]] }                    -- Murder Row: Acting the Part (90819) Miss Len'dali (244471)

   		t = NPC("Naleidea Rivergleam", { 242398, })
   		t.__meta.stopIfQuestTurnIn = { 93386, }                                                               -- Waits for Quest Hand-Ins (First NPCID Only)
  	 	t[138392] = { prio = 10, text = "Combine all of my Coffer Key Shards" }                               -- Coffer Keys
   		t[137442] = { prio = 01, text = "What does the Reliquary have to offer?" }                            -- Vendor Naleidea Rivergleam (242398)

   		t = NPC("Ranger Captain Lilatha", { 257411, })
   		t[139200] = { text = "<Show the Twilight's Blade missive" }                                           -- Torn Twilight Missive (95069) Ranger Captain Lilatha (957411)
   		t[139204] = { text = "I can do that.", close = true }                                                 -- Torn Twilight Missive (95069) Ranger Captain Lilatha (957411)

   		t = NPC("Reno Jackson", { 255103, })
   		t[137116] = { text = "Tell me what happened." }                                                       -- A Missing Member (39511) Riftblade Astre (249459)

   		t = NPC("Riftblade Astre", { 249459, })
   		t[135199] = { text = "I'll join you." }                                                               -- To Be Changed (91546) Riftblade Astre (249459)

   		t = NPC("Row Rat", { 241425, })
   		t[132989] = { text = "I'm looking for Jaeth. Do you know where he is?" }                              -- Stir the Nest (89202) Row Rat (241425)

   		t = NPC("Sin'dorei Vendor", { 249174, })
   		t[135112] = { text = "<Explain the events of the Sunwell.>" }                                         -- Deepening Shadows (91854) Sin'dorei Vendor (249174)

   		t = NPC("Skymaster Skyles", 239639)
   		t[132674] = { text = "H Lor'themar has requested that we be allowed...", prio = 10 }                  -- Paved in Ash (86735) Skymaster Skyles (239639)
   		t[134010] = { text = "A The Alliance will be staying here temporarily...", prio = 9 }                 -- Paved in Ash (86735) Skymaster Skyles (239639)
   		t[132675] = { text = "Show me where I can fly.", prio = -10 }

   		t = NPC("Tarelin", { 244474, })
   		t[134044] = { text = "I'm picking up a shipment for Zaen." }                                          -- Murder Row: Harbored Secrets (90821) Tarelin (244474)

   		t = NPC("Telemancer Astrandis", { 242399, })
   		t.__meta.stopIfQuestTurnIn = { 93385, }                                                               -- Waits for Quest Hand-Ins (First NPCID Only)
   		t[138619] = { text = "I wish to browse your wares." }                                                 -- Vendor Telemancer Astrandis (242399)

   		t = NPC("Thiel", { 244470, })
   		t[133946] = { text = "Where can I get more of these?" }                                               -- Murder Row: Acting the Part (90819) Thiel (244470)

   		t = NPC("Triam Dawnsetter", { 255476, })
   		t[138965] = { text = "What gear slots are available?" }                                               -- Murder Row: Acting the Part (90819) Thiel (244470)

   		t = NPC("Valeera Sanguinar", 242381)
   		t[133099] = { text = "Lor'themar will need the services of the Reliquary" }

   		t = NPC("Vaultkeeper Elysa", 239670)
   		t.__meta.stopIfQuestAvailable = { 93696, 94474, }                                                    -- Waits for Quest Accepted (First NPCID Only)
   		t.__meta.stopIfQuestTurnIn = { 93730, 94474, }                                                       -- Waits for Quest Hand-Ins (First NPCID Only)
   		t[37161] = { text = "I want to browse your goods" }

   		t = NPC("Vira Bloodsong", { 244472, })
   		t[133969] = { text = "I'm looking to purchase more of these?" }                                       -- Murder Row: Acting the Part (90819) Vira Bloodsong (244472)

   		t = NPC("War Chaplain Senn", { 248628, })
   		t[135148] = { text = "<Explain that Lor'Themar wants to see Umbric freed.>" }                         -- You Know This Evil? (91967) War Chaplain Senn (248628)
   		t[135147] = { text = "<Explain how Umbric is reaserching a way into the Voidstorm>" }                 -- You Know This Evil? (91967) War Chaplain Senn (248628)
   		t[135149] = { text = "<Ask how they would enter the Voidstorm without Umbric's help.>" }              -- You Know This Evil? (91967) War Chaplain Senn (248628)

SetZone("Voidspire, Eastern Kingdoms")

   		t = NPC("Arator", { 244297, })
   		t.__meta.stopIfQuestAvailable = { 90724, }                                                         -- First NPCID, Stops Gossip until quest is accepted
   		t.__meta.stopIfQuestTurnIn = { 88709, }                                                            -- First NPCID, Stops Gossip until quest is accepted
   		t[139331] = { text = "I am rady to return to Silvermoon" }                           -- The Broken Sky (90724) Arator (244297)

SetZone("Voidstorm, Eastern Kingdoms")

   		t = NPC("Alleria Windrunner", { 235521, 235502, 235763, })
   		t[132609] = { text = "<Ask Alleria how you can help.>" }                             -- The Far Far Frontier (86881) Alleria Windrunner (235521)
   		t[132795] = { text = "<Tell Alleria you're ready to claim the Mantle.>" }            -- The Mantle of Predation (86518) Alleria Windrunner (235502)
   		t[132672] = { text = "<Tell Alleria you're ready to enter Nexus-Point Xenas...>" }   -- Nexus-Point Xenas: Eclipse (86521) Alleria Windrunner (235763)

   		t = NPC("Ancient Tablet", { 616667, 616704, 616705, })
   		t[138319] = { text = "<Ask Alayshen what he thinks.>" }                              -- Buried in the Dark (92946) Ancient Tablet (616667)
   		t[138332] = { text = "<Ask Alayshen what he thinks.>" }                              -- Buried in the Dark (92946) Ancient Tablet (616704)
   		t[138333] = { text = "<Ask Alayshen what he thinks.>" }                              -- Buried in the Dark (92946) Ancient Tablet (616705)

   		t = NPC("Decimus", { 235607, 235392, 235653, 243276, 248583, 244948, 252853, 243907, })
   		t[132998] = { text = "<Apply force.>" }                                              -- Reliable Enemies (86536) Decimus (235607)
   		t[135469] = { text = "How did Xal'atath take control of the ethereals?" }            -- Reliable Enemies (86536) Decimus (235607)
   		t[132757] = { text = "Explain yourself." }                                           -- Post Mortem (86544) Decimus (235392)
   		t[132673] = { text = "Shut it down!" }                                               -- Nexus-Point Xenas: Eclipse (86521) Decimus (235653)
   		t[134880] = { text = "I am ready to begin!" }                                        -- Artifice of Agression (90915) Decimus (248583)
   		t[135125] = { text = "<Tell Decimus your favorite food is ripe, fresh fruit.>" }     -- Warmth for the Soul (90920) Decimus (248583)
   		t[135136] = { text = "<Tell Decimus you fear spiders.>" }                            -- Warmth for the Soul (90920) Decimus (248583)
   		t[135131] = { text = "<Tell Decimus you regret all the lives you could not save.>" } -- Warmth for the Soul (90920) Decimus (248583)
   		t[136300] = { text = "<Give Decimus the blade.>" }                                   -- Shepherd of Fear (90923) Decimus (252853)
   		t[136330] = { text = "I felt nothing.", close = true }                               -- The Wicked End (90924) Decimus (243907)

   		t = NPC("Fidoficus", { 246791, })
   		t[134827] = { text = "<Feed the delicious snack to Fidoficus.>" }                    -- Belly of the Beast (91380) Fidoficus (246791)

   		t = NPC("High Exarch Turalyon", { 239810, })
   		t[138593] = { text = "Let's move on. <Skip.>" }                                      -- Nothing Stands Forever (88706) High Exarch Turalyon (239810)

   		t = NPC("Hospitus", { 235701, })
   		t[135474] = { text = "What do you have for sale?" }                                  -- Innkeeper Hospitus (235701)
   		t[132668] = { text = "HOLD SHIFT TO BIND HEARTHSTONE MANUALLY", xpop = { which = "GOSSIP_CONFIRM", containsAll = { "do you want to make", "your new home" }, within = 3, }, prio = -10, noAuto = true }

   		t = NPC("Kifaan", { 244499, 244516, })
   		t[136789] = { text = "<Hand Kifaan the Interrogated Data to interpret.>" }           -- Fits of Lucidity (90844) Kifaan (244499)
   		t[136988] = { text = "<Encourage Kifaan to talk to his sister.>" }                   -- Bursting at the Seams (93396) Kifaan (244516)

   		t = NPC("Knight Anais", { 253594, })
   		t[136581] = { text = "I'm ready." }                                                  -- Strung Along (91148) Knight Anais (253594)

   		t = NPC("Lady Darkglen", { 241170, })
   		t[132555] = { text = "I'll find Hieron. Regroup with the others." }                  -- Vanished in the Void (86517) Lady Darkglen (241170)

   		t = NPC("Lothraxion", { 235522, 235725, })
   		t[132585] = { text = "Tell Lothraxion you're ready to survey the Voidstorm.>" }      -- The Far Far Frontier (86881) Lothraxion (235522)
   		t[132756] = { text = "<Ask how Lothraxion is doing.>" }                              -- Post Mortem (86544) Lothraxion (235725)

   		t = NPC("Matrean Dawnfall", { 236908, })
   		t[132965] = { text = "<Urge Matrean to give up his search and return ...>" }         -- Violent Conclusions (88708) Matrean Dawnfall (236908)

   		t = NPC("Magister Umbric", { 239828, 235698, 247668, })
   		t[133258] = { text = "Scrying platform?" }                                           -- Clarity of Purpose (88697) Magister Umbric (239828)
   		t[135019] = { text = "<Serve Hieron's tea.>" }                                       -- The Town Inside Me (91542) Magister Umbric (235698)
   		t[135182] = { text = "Astre and I will take care of the domanaar..." }               -- Stronger Than Before (91545) Magister Umbric (247668)
   		t[136913] = { text = "BE Allow me to handle this." }                                 -- To Be Changed (91546) Magister Umbric (235698)

   		t = NPC("Orin Straylight", { 254114, })
   		t[136761] = { text = "Where does this voice lead?" }                                 -- O Lonely Star (92603) Orin Straylight (254114)

   		t = NPC("Ravenia", { 246727, })
   		t[134864] = { text = "I slew the Den-Gorger while Fidoficus cowered in fear." }      -- Mighty and Superior (91382) Ravenia (246727)

   		t = NPC("Research Console", { 257042, })
   		t[137576] = { text = "Commune with the Console.>" }                                  -- Reaserching the Storm (93970) Research Console (257042)

   		t = NPC("Riftblade Maella", { 240538, 239349, 238531, 247595, })
   		t[132752] = { text = "<Ask for his report on the wilds.>" }                          -- Post-Mortem (86544) Riftblade Maella (240538)
   		t[132535] = { text = "<Hear the scouting report.>" }                                 -- Edge of the Abyss (86511) Riftblade Maella (239349)
   		t[132554] = { text = "Regroup with Alleria and Arator" }                             -- Vanished in the Void (86517) Riftblade Maella (238531)
   		t[135018] = { text = "<Serve Hieron's tea.>" }                                       -- The Town Inside Me (91542) Riftblade Maella (247595)

   		t = NPC("Riftwalker Hieron", { 239724, 238530, })
   		t[132751] = { text = "<Ask for his report on the wilds.>" }                          -- Post-Mortem (86544) Riftwalker Hieron (239724)
   		t[132556] = { text = "Darkglen and Maella are fine." }                               -- Vanished in the Void (86517) Riftwalker Hieron (238530)

   		t = NPC("Riftwalker Sideras", { 247594, })
   		t[135020] = { text = "<Serve Hieron's tea.>" }                                       -- The Town Inside Me (91542) Riftwalker Sideras (247594)

   		t = NPC("Venzilion the Reality Cracker", { 253322, })
   		t[137728] = { text = "<Enter Voidspire in Story Mode>", qil = 88709 }                -- The Voidspire (88709) Venzilion the Reality Cracker (253322)

   		t = NPC("Void Reasercher Anomander", { 248328, })
   		t[138232] = { text = "<Inquire about Anomander's reaserch.>", prio = 10 }            -- Domus Penumbra (86510) Void Reasercher Anomander (248328)
   		t[138438] = { text = "Can I see the Renown items you have for sale?", prio = -10 }   -- Quartermaster Void Reasercher Anomander (248328)

   		t = NPC("Ziadan", { 256901, })
   		t[138272] = { text = "<Tell them you are ready to deliver the final blow...>", }     -- Voidscar Arena: Clearing House (91606) Ziadan (256901)

SetZone("Zul'Aman, Eastern Kingdoms")

		t = MAP("Delve: Atal'Aman", 2535)
   		t[136385] = { text = "(Delve) I'll break the hexes and set your kin free." }
   		t[138496] = { text = "<Help me reach Spiritflayer Jin'Ma.>" }

		t = NPC("Altar of Blessings", { 237653, })
   		t[133887] = { text = "<Worship the loa.>" }                                          -- Blessings of the Loa (93792) Altar of Blessings (237653)

   		t = NPC("Assistant Grgl-Grgl", { 250292, })
   		t[137485] = { text = "King Mrgl-Mrgl is safe at the top of the temple." }            -- Following Suit (92166) Assistant Grgl-Grgl (250292)

   		t = NPC("Chel the Chip", { 241928, })
   		t.__meta.stopIfQuestAvailable = { 91932, 89507, }                                               -- First NPCID, Stops Gossip until quest is accepted
   		t[134905] = { text = "Let me browse your goods." }                                   -- Vendor Chel the Chip (241928)

   		t = NPC("Daki", { 253604, })
   		t[136586] = { text = "Head to Mixer Jamanga, He is making an anti-venom." }          -- Validating the Venom (91405) Daki (253604)

   		t = NPC("Dundun", { 251601, })
   		t[135092] = { text = "<Learn the ways of Abundance." }                               -- The Abundant Awakening (91932) Dundun (251601)

   		t = NPC("Eagletender Rhyd", { 254842, })
   		t[137198] = { text = "<Deliver the supplies.>" }                                     -- Shrine, Sealed, Delivered (93433) Eagletender Rhyd (254842)

   		t = NPC("Elder Doru", { 236590, })
   		t[132579] = { text = "Zul'jan sent me to find you." }                                -- Important Amani (86719)       Elder Doru (236590)

   		t = NPC("Elder Ren'zen", { 242464, })
   		t[133102] = { text = "Do you recognize this letter you sent?" }                      -- I Have a Permit (90481) Elder Ren'zen (242464)
   		t[133101] = { text = "I will let them know." }                                       -- I Have a Permit (90481) Elder Ren'zen (242464)

   		t = NPC("Elder Shimarra", { 254834, })
   		t[137196] = { text = "<Deliver the supplies.>" }                                     -- Shrine, Sealed, Delivered (93433) Elder Shimarra (254834)

   		t = NPC("Elder Thak", { 254830, })
   		t[137197] = { text = "<Deliver the supplies.>" }                                     -- Shrine, Sealed, Delivered (93433) Elder Thak (254830)

   		t = NPC("Elder Vu'lona", { 254828, })
   		t[137195] = { text = "<Deliver the supplies.>" }                                     -- Shrine, Sealed, Delivered (93433) Elder Vu'lona (254828)

   		t = NPC("Haz'kel", { 256027, })
   		t[137297] = { text = "Have you seen Kanza?" }                                        -- A Quiet Walk Interrupted (93178) Haz'kel (256027)

   		t = NPC("Kanza", { 254719, 258014, 258363, })
   		t[137771] = { text = "Your mother sent me to take you home.", close = true }         -- Childlike Devotion (93179) Kanza (254719)
   		t[137820] = { text = "I'll handle the stingers, Kanza." }                            -- Shrine Preparations (93180) Kanza (254719)
   		t[137830] = { text = "You'd like me to pick some mushrooms as well?", close = true } -- Shrine Preparations (93180) Kanza (258014)
   		t[137968] = { text = "Let's have a tea party.", close = true }                       -- Temple and a Teapot (93181) Kanza (258363)

   		t = NPC("Kel'vujo", { 253999, })
   		t[137655] = { text = "DH I may be \"blind,\" but I see you intend to betray me." }     -- Amani Honor (93096) Kel'vujo (253999)
   		t[137663] = { text = "HN Good luck fighting with your legs frozen to the ground." }    -- Amani Honor (93096) Kel'vujo (253999)
   		t[138683] = { text = "MK Your stance displays your traitorous intentions." }           -- Amani Honor (93096) Kel'vujo (253999)

   		t = NPC("Kovu", { 257807, })
   		t[137451] = { text = "<Tell Kovu to demonstrate his combat...>" }                    -- Got No Rhythm (93048) Kovu (257807)

   		t = NPC("Kulzi", { 237956, })
   		t[134375] = { text = "What would help them to remember?" }                           -- Demands Unmet (87267) Kulzi (237956)

   		t = NPC("Lilaju", { 245589, 245664, })
   		t[132891] = { text = "<Request lightwood report.>" }                                 -- Left in the Shadows (86652)   Lilaju (245589)
   		t[134139] = { text = "We will, But we need to speak to Nalorakk to do so" }          -- Den of Nalorakk: Waking de Bear (86682) Lilaju (245664)

   		t = NPC("Loa Speaker Brek", { 245512, })
   		t[134196] = { text = "Where is Jan'alai?" }                                          -- The Flames Rise Higher (90772) Loa Speaker Brek (245512)

   		t = NPC("Loa Speaker Kinduru", { 237301, 244479, })
   		t[132584] = { text = "It is time to evacuate, Loa Speaker Kinduru" }                 -- Important Amani (86719)       Loa Speaker Kinduru (237301)
   		t[133822] = { text = "I will hel Zul'jarra" }                                        -- Left in the Shadows (86652)   Loa Speaker Kinduru (244479)

   		t = NPC("Loa Speaker Sij'ta", { 246537, })
   		t[135825] = { text = "<Give Sij'ta the broken hexlord staff>" }                      -- Denial Denied (87317) Loa Speaker Sij'ta (246537)

   		t = NPC("Loa Speaker Tobul", { 250068, })
   		t[135472] = { text = "How do we speak to Halazzi?" }                                 -- Halazzi's Guide (92084)       Loa Speaker Tobul (250068)

   		t = NPC("Maisara Caverns", { 254381, })
   		t[136843] = { text = "Please take me to the entrance of Maisara Caverns" }           -- Maisara Caverns () Kul'amara the Fierce (254381)

   		t = NPC("Mixer Jamanga", { 247201, 247254, })
   		t[134564] = { text = "Can you make an anti-venom from these samples?" }              -- Validating the Venom (91405) Mixer Jamanga (247201)
   		t[134622] = { text = "What's going on here?" }                                       -- Seeking Shadra (91408) Mixer Jamanga (247254)

   		t = NPC("Namaji", { 240975, })
   		t[135138] = { text = "Go with Kagara to the festival", xpop = { which = "GOSSIP_CONFIRM", containsAny = { "Are you sure" }, within = 3, }, }  -- Love Triangle (89233) Namaji (240975)

   		t = NPC("Old Koko", { 255185, })
   		t[137130] = { text = "Train Me", }                                                   -- Fishing Trainer () Old Koko (255185)

   		t = NPC("Ri'kari", { 255907, })
   		t[137188] = { text = "<Tell Ri'kari you're ready...>" }                              -- The Final Exam (93051)   Ri'kari (255907)

   		t = NPC("Shim'dak", { 253037, })
   		t[39623] = { text = "Train Me.", prio = 0 }                                          -- Cooking Trainer  Shim'dak (253037)
   		t[39624] = { text = "Let me browse your ...", prio = 5, print = "MidnightCooking" }  -- Cooking Trainer  Shim'dak (253037)

   		t = NPC("Tak'lejo", { 244562, })
   		t[135286] = { text = "Where are the shamans?" }                                      -- Left in the Shadows (86652)   Tak'lejo (244562)

   		t = NPC("Torundo the Grizzled", { 236591, })
   		t[132582] = { text = "Zul'jan sent me to find you." }                                -- Important Amani (86719)       Torundo the Grizzled (236591)

   		t = NPC("Vun'zarah", { 244591, })
   		t[134081] = { text = "Do you know anything that will help us speak to Jan'alai?" }   -- Coals of a Dead Loa (86661) Vun'zarah (244591)
   		t[134561] = { text = "Halazzi has sent me to find a venom expert, Do you know of one?" }   -- Validating the Venom (91405) Vun'zarah (244591)

   		t = NPC("Warlord Akutu", { 238063, })
   		t[134247] = { text = "Sij'ta said this will help you." }                             -- Curse Cleanse (87254) Warlord Akutu (238063)

   		t = NPC("Witherbark Visitor", { 242392, })
   		t[133188] = { text = "Tell me a Witherbark story." }                                 -- A Witherbark Story (90483) Witherbark Visitor (242392)

   		t = NPC("Zul'jan", { 245646, })
   		t[134133] = { text = "Are you okay, Zul'jan" }                                       -- Broken Bridges (91062) Zul'jan (245646)

   		t = NPC("Zul'jarra", { 236659, 240215, 240216, 253980, 241306, 246409, })
   		t[138031] = { text = "<Skip the forest times meeting.>" }                            -- Isolation (86723) Zul'jarra (236659)
   		t[134140] = { text = "<Enter the Den of Nalorakk with Zul'jarra>" }                  -- Den of Nalorakk: Unforgiven (91958) Zul'jarra (240215)
   		t[138171] = { text = "What is next?" }                                               -- Den of Nalorakk: Unforgiven (91958) Zul'jarra (240215)
   		t[132827] = { text = "Is there nothing we can do?" }                                 -- Hash'ey Away (86683) Zul'jarra (240216)
   		t[135208] = { text = "I am ready to battle Mor'duun" }                               -- Blade Shattered (86692) Zul'jarra (253980)
   		t[134131] = { text = "<Start the celebration.>" }                                    -- De Legend of de Hash'ey (86693) Zul'jarra (241306)
   		t[136468] = { text = "<Leave Nalorakk's Den.>" }                                     -- Den of Nalorakk Dungeon  Zul'jarra (246409)

   		t = NPC("Zungam's Anvil", { 255504, })
   		t[137204] = { text = "<Repair Equipment.>" }                                         -- Repair () Zungam's Anvil (245646)

   		t = NPC("Dungeon: Den of Nalorakk", { 616377, 616428, })
   		t[135009] = { text = "<Meditate on the sound of the flames.>" }                      -- Den of Nalorakk Dungeon  Ethereal Pyre (616377)
   		t[135010] = { text = "<Meditate on the sound of the flames.>" }                      -- Den of Nalorakk Dungeon  Ethereal Pyre (616428)

   		t = NPC("Quest: Crab Clues", { 612366, 259329, })
   		t[137687] = { text = "Take note of this for Kahanea." }                              -- Crab Clues (93258) Suspicious Debris (612366)
   		t[137685] = { text = "Take note of this for Kahanea." }                              -- Crab Clues (93258) Crawler Corpse (259329)

   		t = NPC("Quest: Following Suit", { 617497, 617500, })
   		t[137476] = { text = "<Collect the knapsack.>" }                                     -- Following Suit (92166) Out of Place Knapsack (617497)
   		t[137477] = { text = "<Collect the papers.>" }                                       -- Following Suit (92166) Scattered Papers (617500)

