local _, ns = ...

ns.db = ns.db or {}
ns.db.rules = ns.db.rules or {}

-- XP01EK database pack
-- Add rules like:
-- ns.db.rules[123456] = ns.db.rules[123456] or {}
-- ns.db.rules[123456].__meta = { zone = "Zone, Continent", npc = "NPC Name" }
-- ns.db.rules[123456][98765] = { text = [[Option text]], type = "", prio = 0, xpop = { which = "GOSSIP_CONFIRM", containsAll = {"are you sure", "cannot be undone"}, within = 3 } }
-- (Per-rule overrides still supported: zoneName/zone, npcName/npc)

-- Helpers so you can set a zone header and avoid repeating zone/npc fields.
local CURRENT_ZONE

local function SetZone(zone)
   CURRENT_ZONE = zone
end

local function NPC(npcID, npcName)
   ns.db.rules[npcID] = ns.db.rules[npcID] or {}
   ns.db.rules[npcID].__meta = { zone = CURRENT_ZONE, npc = npcName }
   return ns.db.rules[npcID]
end

-- Convenience helper: write one set of option rules to multiple NPC IDs.
-- Example:
-- local t = NPCs({111, 222}, "Same NPC")
-- t[12345] = { text = "...", type = "" }
local function NPCs(npcIDs, npcName)
   if type(npcIDs) ~= "table" then
      npcIDs = { npcIDs }
   end

   local targets = {}
   for _, id in ipairs(npcIDs) do
      targets[#targets + 1] = NPC(id, npcName)
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

-- EASTERN KINGDOMS

SetZone("Blasted Lands, Eastern Kingdoms")

   local t = NPC(88206, "Zidormi")
   t[42958] = { text = "Show me the Blasted Lands before the invasion", type = "" }

SetZone("Eversong Woods, Eastern Kingdoms")

   local t = NPC(236149, "Innkeeper Kalarin")
   t[132744] = { text = "Have you seen anything strange recently?", type = "", prio = 10 }   -- Rational Explanation (86624)
   t[137854] = { text = "Let me browse your goods.", type = "", prio = -5 }
   t[137856] = { text = "HOLD SHIFT TO BIND HEARTHSTONE MANUALLY", xpop = { which = "GOSSIP_CONFIRM", containsAll = { "do you want to make", "your new home" }, within = 3, }, type = "", prio = -10, noAuto = true }

   local t = NPCs({236716, 242433, 236610, }, "Arator")
   t[136284] = { text = "<Skip conversation> What now?", type = "" }    --                               Arator (236716)
   t[133785] = { text = "<Skip conversation> What now?", type = "" }    --                               Arator (242433)
   t[132886] = { text = "<Stay silent.>", type = "" }                   -- Following the Root (86643)    Arator (236610)

   local t = NPCs({207283, }, "Delvers' Supplies")
   t[122661] = { text = "<View goods and repair gear.>", type = "", prio = 10,  }
   t[135011] = { text = "<View companion supplies.>", type = "", prio = -10,  }

   local t = NPCs({242099, }, "Valeera Sanguinar")
   t[136049] = { text = "I'm Ready.", type = "" }

   local t = NPCs({241654, }, "High Exarch Turalyon")
   t[132931] = { text = "I'm Ready.", type = "" }

   local t = NPCs({236743, 236903, }, "Orweyna")
   t[133725] = { text = "Let's follow the trail you found.", type = "" }
   t[132833] = { text = "I'm read when you are.", type = "" }

   local t = NPCs({242568, 244840, 239457, 239406, 239405, 245004, 251539, 251540, 251543, 251542, 542849, 542850, 258559, 258560, 258561, 258562, 258563, 258564, 258565, 258566, }, "Zone Quest NPCs")
   t[133913] = { text = "What problems ail the people of Tranquillien?", type = "" }                              -- Rational Explanation (86624)  Matron Narsilla (242568)      KILLED
   t[133888] = { text = "Have there been any issues around town lately?", type = "" }                             -- Rational Explanation (86624)  Quartermaster Lymel (244840)
   t[132706] = { text = "Have you seen anything suspicious lately?", type = "" }                                  -- Rational Explanation (86624)  Guard Captain Leonic (239457) KILLED
   t[132894] = { text = "You've had scouts go missing?", type = "" }                                              -- Rational Explanation (86624)  Ranger Belonis (239406)
   t[132741] = { text = "We need to speak to Lord Antenorian", type = "" }                                        -- The First to Know (90907)     Secretary Faloria (239405)    KILLED
   t[134001] = { text = "Lie to Lord Antenorian about how much you know.", type = "" }                            -- The First to Know (90907)     Lord Antenorian (245004)      DELVE BOSS
   t[132680] = { text = "I'll cover your escape.", type = "" }                                                    -- What's Left (86639)           Magistrix Silanna (251539)
   t[132652] = { text = "<Instruct the defender to go to the Runestone Shan'dor, where it is safe.>", type = "" } -- What's Left (86639)           Apprentice Erilla (251540)
   t[132684] = { text = "<Instruct the defender to go to the Runestone Shan'dor, where it is safe.>", type = "" } -- What's Left (86639)           Trainee Solamine (251543)
   t[135781] = { text = "<Instruct the defender to go to the Runestone Shan'dor, where it is safe.>", type = "" } -- What's Left (86639)           Outrunner Alarion (251542)
   t[133889] = { text = "<Place Bonecarapace Fangs into the vase.>", type = "" }                                  -- Gods Before Us (86644)        Ritual Vase (542849)
   t[133890] = { text = "<Place Bloodvein Clot into the vase.>", type = "" }                                      -- Gods Before Us (86644)        Ritual Vase (542850)
   t[137985] = { text = "Stop! The Amani are not the real threat here", type = "" }                               -- Light Guide Us (86648)        Eversong Farstrider (258559)
   t[137986] = { text = "Stop! The Amani are not the real threat here", type = "" }                               -- Light Guide Us (86648)        Eversong Spellbreaker (258560)
   t[137987] = { text = "Stop! The Amani are not the real threat here", type = "" }                               -- Light Guide Us (86648)        Eversong Arch Magister (258561)
   t[137988] = { text = "Stop! The Amani are not the real threat here", type = "" }                               -- Light Guide Us (86648)        Blessed Lightbringer (258562)
   t[137989] = { text = "Stop! The Amani are not the real threat here", type = "" }                               -- Light Guide Us (86648)        Veteran Blood Knight (258563)
   t[137990] = { text = "Stop! The Amani are not the real threat here", type = "" }                               -- Light Guide Us (86648)        Blessed Lightbringer (258564)
   t[137991] = { text = "Stop! The Amani are not the real threat here", type = "" }                               -- Light Guide Us (86648)        Eversong Magister (258565)
   t[137992] = { text = "Stop! The Amani are not the real threat here", type = "" }                               -- Light Guide Us (86648)        Veteran Blood Knight (258566)

SetZone("Stormwind City, Eastern Kingdoms")

   local t = NPCs({ 246155, 246154 }, "Suspicious Citizen")
   t[134631] = { text = "Are you talking about the Twilight's Blade?", type = "" }
   t[134634] = { text = "Are you talking about the Twilight's Blade?", type = "" }

   local t = NPC( 171789, "High Inquisitor Whitemane")
   t[52725] = { text = "I have heard this tale before. <Skip the Maw introduction. Oribos awaits.>", xpop = { which = "GOSSIP_CONFIRM", containsAny = { "are you sure", "cannot be undone" }, within = 3, }, type = "", }

   local t = NPC( 150122, "Honor Hold Mage")
   t[50005] = { text = "I must report to the Dark Portal.", type = "" }

   local t = NPC( 149626, "Vanguard Battlemage")
   t[51033] = { text = "I must help Khadgar. Send me to the Blasted Lands!", type = "" }

SetZone("Quel'Thalas, Eastern Kingdoms")

   local t = NPC(237278, "Lady Liadrin")
   t[132924] = { text = "Nothing will get past me!", type = "" }

   local t = NPC(237255, "High Exarch Turalyon")
   t[133285] = { text = "Let's drive this threat back!", type = "" }

   local t = NPC(236959, "Arator")
   t[132388] = { text = "Your father sent me to find you.", type = "" }

   local t = NPC(240240, "Alonsus Faol")
   t[138693] = { text = "<Tell Alonsus you are ready to go to Light's Hope.>", type = "" }                        -- Relic's of Light's Hope (86839) Alonsus Faol (240240)

   local t = NPCs({ 240156, 240125, 240075, 240074, 237211, 236657, 236789, }, "Zone Quest NPCs")
   t[132686] = { text = "Arator and I will see you safely to the boats.", type = "" }                             -- Unknown Quest (XXXXX)   Scared Civilian (240156)
   t[132670] = { text = "Arator and I will see you safely to the boats.", type = "" }                             -- Unknown Quest (XXXXX)   Scared Civilian (240125)
   t[132655] = { text = "Arator and I will see you safely to the boats.", type = "" }                             -- Unknown Quest (XXXXX)   Scared Civilian (240075)
   t[132654] = { text = "Arator and I will see you safely to the boats.", type = "" }                             -- Unknown Quest (XXXXX)   Scared Civilian (240074)
   t[132513] = { text = "The Vanguard rallies at Sunstrider Rise.", type = "" }                                   -- Unknown Quest (XXXXX)   Sunstrider Mage (237211)
   t[132514] = { text = "The Vanguard rallies at Sunstrider Rise.", type = "" }                                   -- Unknown Quest (XXXXX)   Sunstrider Scout (236657)
   t[132515] = { text = "The Vanguard rallies at Sunstrider Rise.", type = "" }                                   -- Unknown Quest (XXXXX)   Sunstrider Scout (236789)

SetZone("Silvermoon City, Eastern Kingdoms")

   local t = NPC(248629, "General Amias Bellamy")
   t[135224] = { text = "<Offer Greeting.>", type = "" }

   local t = NPCs({ 244644, }, "Arator")
   t[133853] = { text = "Alonsus Faol asks that we meet him at the Sunwell.", type = "" }                         -- Meet at the Sunwell (86837)   Arator (244644)
   t[133856] = { text = "Let's go.", type = "" }                                                                  -- Meet at the Sunwell (86837)   Arator (244644)

   local t = NPC(239630, "Innkeeper Jovia")
   -- When multiple rules match, higher prio wins.
   t[134012] = { text = "The Alliance will be staying here temporarily. Lodgings will be needed.", type = "", prio = 10 }
   t[132667] = { text = "Let me browse your goods.", type = "", prio = -5 }
   t[132668] = { text = "HOLD SHIFT TO BIND HEARTHSTONE MANUALLY", xpop = { which = "GOSSIP_CONFIRM", containsAll = { "do you want to make", "your new home" }, within = 3, }, type = "", prio = -10, noAuto = true }

   local t = NPC(242381, "Valeera Sanguinar")
   t[133099] = { text = "Lor'themar will need the services of the Reliquary", type = "" }

   local t = NPCs({ 239664, 239639, 239673, 240940, }, "Paved in Ash")
   t[134010] = { text = "The Alliance will be stay here temporarily.", type = "" }
   t[134011] = { text = "The Alliance will be staying longer than expected. We'll need your Stormwind portal to remain.", type = "" }
   t[134013] = { text = "The Alliance will be stay here temporarily.", type = "" }
   t[134014] = { text = "The Alliance will be staying longer than expected.", type = "" }

   local t = NPC(235787, "Lor'themar Theron")
   t[132632] = { text = "<Skip conversation> I expect you'll sort things out.", type = "" }
   t[134143] = { text = "What now?", type = "" }                                                -- Fractured (86650)

SetZone("Tirisfal Glades, Eastern Kingdoms")

   local t = NPC(141488, "Zidormi")
   t[49018] = { text = "Can you show me what Tirisfal Glades was like before the Battle for Lordaeron.", type = "" }

SetZone("Westfall, Eastern Kingdoms")

   local t = NPC(523, "Thor")
   t[32677] = { text = "I need a ride.", type = "" }

SetZone("Twilight Highlands, Eastern Kingdoms")

    -- 12.0.0 Prepatch
   local t = NPCs({ 248230, 248229, 248228 }, "Restlass Neophyte")
   t[135794] = { text = "<Challenge the cultist to a \"sparring match.\"", type = "" }




