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

-- Returns: true (known), false (not known), nil (unknown/not ready)
local function KnowsFishingClassicOrMidnight()
   if ns and ns.Profs and ns.Profs.KnowsFishingClassicOrMidnight then
      return ns.Profs.KnowsFishingClassicOrMidnight()
   end

   -- Fishing tiers (category IDs) based on the modern Professions UI.
   -- Classic Fishing category is typically 1100; Midnight Fishing is 2159.
   local function TierKnown(categoryID)
      if not (C_TradeSkillUI and type(C_TradeSkillUI.GetCategoryInfo) == "function") then
         return nil
      end
      local cat = C_TradeSkillUI.GetCategoryInfo(categoryID)
      local lvl = cat and cat.skillLineCurrentLevel
      if type(lvl) ~= "number" then
         return nil
      end
      if lvl > 0 then
         return true
      end
      if lvl == 0 then
         return false
      end
      return nil
   end

   local classic = TierKnown(1100)
   local midnight = TierKnown(2159)
   if classic == true or midnight == true then
      return true
   end
   if classic == false and midnight == false then
      return false
   end

   -- Fallback: if Fishing shows up as a secondary profession with rank info, use it.
   if type(GetProfessions) == "function" and type(GetProfessionInfo) == "function" then
      local _, _, _, fish = GetProfessions()
      if fish == nil then
         return nil
      end
      local _, _, rank = GetProfessionInfo(fish)
      if type(rank) == "number" then
         if rank > 0 then
            return true
         end
         if rank == 0 then
            return false
         end
      end
   end

   return nil
end

-- Returns: true (known), false (not known), nil (unknown/not ready)
local function KnowsFishingMidnight()
   if ns and ns.Profs and ns.Profs.KnowsFishingMidnight then
      return ns.Profs.KnowsFishingMidnight()
   end

   if not (C_TradeSkillUI and type(C_TradeSkillUI.GetCategoryInfo) == "function") then
      return nil
   end
   local cat = C_TradeSkillUI.GetCategoryInfo(2159)
   local lvl = cat and cat.skillLineCurrentLevel
   if type(lvl) ~= "number" then
      return nil
   end
   if lvl > 0 then
      return true
   end
   if lvl == 0 then
      return false
   end
   return nil
end

-- Memoized wrapper: `when` conditions for multiple options can be evaluated back-to-back.
-- If the professions APIs become ready between calls, results can "flip" mid-evaluation.
-- Memoizing per gossip-open session keeps answers stable within one show, but refreshes
-- immediately across manual close/re-open.
local _midnightMemoSession, _midnightMemoVal
local function KnowsFishingMidnightMemo()
   local sess = (ns and tonumber(ns.GossipSession)) or 0
   if sess == _midnightMemoSession then
      return _midnightMemoVal
   end
   local v = KnowsFishingMidnight()
   _midnightMemoSession, _midnightMemoVal = sess, v
   return v
end

-- EASTERN KINGDOMS

SetZone("Blasted Lands, Eastern Kingdoms")

   local t = NPC(88206, "Zidormi")
   t[42958] = { text = "Show me the Blasted Lands before the invasion", type = "" }

SetZone("Burning Steppes, Eastern Kingdoms")

   local t = NPC(237508, "Arator")
   t[136312] = { text = "<Ask Arator how he is doing.>", type = "" }

   local t = NPC(246863, "Alonsus Faol")
   t[138705] = { text = "Let's get started. <Skip the conversation.>", type = "" }

   local t = NPC(248250, "Kudran Wildhammer")
   t[134709] = { text = "What happened?", type = "" }

SetZone("Eversong Woods, Eastern Kingdoms")
      --
      local t = NPCs({251540, }, "Apprentice Erilla")
      t[132652] = { text = " - <Instruct the defender to go to the Runestone Shan'dor...>", type = "" }      -- What's Left (86639)                Apprentice Erilla (251540)

      local t = NPCs({236716, 242433, 236610, }, "Arator")
      t[136284] = { text = "<Skip conversation> What now?", type = "" }    --                               Arator (236716)
      t[133785] = { text = "<Skip conversation> What now?", type = "" }    --                               Arator (242433)
      t[132886] = { text = "<Stay silent.>", type = "" }                   -- Following the Root (86643)    Arator (236610)

      local t = NPCs({238112, }, "Brutish Follower")
      t[132313] = { text = "<Explain situation and ask to spar.>", type = "" }                               -- Training Arc (86998)               Brutish Follower (238112)

      local t = NPCs({240532, }, "Grand Magister Rommath")
      t[132750] = { text = "Begin the ritual.", type = "" }

      local t = NPCs({239457, }, "Guard Captain Leonic")
      t[132706] = { text = " - Have you seen anything suspicious lately?", type = "" }                       -- Rational Explanation (86624)       Guard Captain Leonic (239457) KILLED

      local t = NPCs({241654, }, "High Exarch Turalyon")
      t[132931] = { text = "I'm Ready.", type = "" }

      local t = NPC(236149, "Innkeeper Kalarin")
      t[132744] = { text = "Have you seen anything strange recently?", type = "", prio = 10 }                -- Rational Explanation (86624)
      t[137854] = { text = "Let me browse your goods.", type = "", prio = -5 }
      t[137856] = { text = "HOLD SHIFT TO BIND HEARTHSTONE MANUALLY", xpop = { which = "GOSSIP_CONFIRM", containsAll = { "do you want to make", "your new home" }, within = 3, }, type = "", prio = -10, noAuto = true }

      local t = NPCs({245285, }, "Instructor Thalendir")
      t[134484] = { text = "<Give Recommendation.>", type = "" }                                             -- How to Train Your Protege (91301)  Instructor Thalendir (245285)

      local t = NPCs({247085, }, "Jesthenis Sunstriker")
      t[134482] = { text = "I am ready to fight.", type = "" }                                               -- A Test of Blood (91291)            Jesthenis Sunstriker (247085)

      local t = NPCs({246557, }, "Kyltus Bloodburn")
      t[134090] = { text = "<Pick the one that showed the most courage.>", type = "" }                       -- How to Train Your Protege (91301)  Kyltus Bloodburn (246557)

      local t = NPCs({245004, }, "Lord Antenorian")
      t[134001] = { text = " - Lie to Lord Antenorian about how much you know.", type = "" }                 -- The First to Know (90907)          Lord Antenorian (245004)      DELVE BOSS

      local t = NPCs({242688, }, "Luna")
      t[133262] = { text = "<Pet Luma.>", type = "" }                                                        -- Thief at Bark (90544)              Luna (242688)
      t[137322] = { text = "<Pet Luma.>", type = "" }                                                        -- Thief at Bark (90544)              Luna (242688)

      local t = NPCs({251539, }, "Magistrix Silanna")
      t[132680] = { text = " - I'll cover your escape.", type = "" }                                         -- What's Left (86639)                Magistrix Silanna (251539)

      local t = NPCs({242568, }, "Matron Narsilla")
      t[133913] = { text = "What problems ail the people of Tranquillien?", type = "" }                      -- Rational Explanation (86624)       Matron Narsilla (242568)      KILLED

      local t = NPCs({247800, }, "Melandria")
      t[38266] = { text = "Train Me.", type = "", when = function() return KnowsFishingMidnightMemo() ~= true end }  -- Fishing Trainer  Melandria (247800)
      t[38267] = { text = "Show Me Your Goods", type = "", when = function() return KnowsFishingMidnightMemo() == true end } -- Fishing Trainer  Melandria (247800)

      local t = NPCs({236743, 236903, 236704, }, "Orweyna")
      t[133725] = { text = "Let's follow the trail you found.", type = "" }
      t[132833] = { text = "I'm ready when you are.", type = "" }
      t[135559] = { text = "I'm ready, Lets go!", type = "" }                                                -- The Root Cause (86899)             Orweyna (236704)

      local t = NPCs({251542, }, "Outrunner Alarion")
      t[135781] = { text = " - <Instruct the defender to go to the Runestone Shan'dor...>", type = "" }      -- What's Left (86639)                Outrunner Alarion (251542)

      local t = NPCs({244840, }, "Quartermaster Lymel")
      t[133888] = { text = "Have there been any issues around town lately?", type = "" }                     -- Rational Explanation (86624)       Quartermaster Lymel (244840)

      local t = NPCs({239406, }, "Ranger Belonis")
      t[132894] = { text = "You've had scouts go missing?", type = "" }                                      -- Rational Explanation (86624)       Ranger Belonis (239406)

      local t = NPCs({248307, }, "Ranger Valsarin")
      t[134809] = { text = "Saddle me up!", type = "" }                                                      -- Strider Stampede (91347)           Ranger Valsarin (248307)

      local t = NPCs({239405, }, "Secretary Faloria")
      t[132741] = { text = " - We need to speak to Lord Antenorian", type = "" }                             -- The First to Know (90907)          Secretary Faloria (239405)    KILLED

      local t = NPCs({251405, }, "Sheri")
      t[136683] = { text = "I would like to see your wares", type = "", prio = 10, }                        -- Sheri (251405)

      local t = NPCs({252156, }, "Solwin Brightstitch")
      t[135911] = { text = "I'm ready for anything!", type = "" }                                           -- Clothes Make the Man (91389)       Solwin Brightstitch (252156)

      local t = NPCs({249337, }, "Talandra Dawnsprite")
      t[136372] = { text = " - Very well.", type = "" }                                                     -- Flowers for Amalthea (92025)       Talandra Dawnsprite (249337)

      local t = NPCs({251543, }, "Trainee Solamine")
      t[132684] = { text = " - <Instruct the defender to go to the Runestone Shan'dor...>", type = "" }     -- What's Left (86639)                Trainee Solamine (251543)

      local t = NPCs({242099, }, "Valeera Sanguinar")
      t[136049] = { text = "I'm Ready.", type = "" }

      local t = NPCs({245745, }, "Valdekar Solaar")
      t[134361] = { text = "<Hand over the fish.>", type = "" }                                 -- A Fish! (91271) Valdekar Solaar (245745)   

      local t = NPC(249211, "Zul'jan")
      t[135099] = { text = "Return to Zul'Aman", type = "", }                                               -- The Line Must be Drawn Here (86710) Zul'jan (249211)

      local t = NPCs({207283, }, "Unknown NPC")
      t[122661] = { text = "<View goods and repair gear.>", type = "", prio = 10,  }
      t[135011] = { text = "<View companion supplies.>", type = "", prio = -10,  }

      local t = NPCs({253050, 253054, 254710, }, "Quest: House Call")
      t[136353] = { text = "Something is watching you.", type = "" }                                        -- House Call (92024)    Stained Tool Rack (253050)
      t[136354] = { text = "Something is watching you.", type = "" }                                        -- House Call (92024)    Suspicious Urn (253054)
      t[136355] = { text = "Something is watching you.", type = "" }                                        -- House Call (92024)    Well-Loved Tome (254710)

      local t = NPCs({249436, 249437, 249426, }, "Quest: Suspicious Sundries")
      t[136321] = { text = "I would like to see your wares", type = "", prio = 10, }                        -- Suspicious Sundries (92023) Vehn Sorrelstride (249439)
      t[136322] = { text = "I would like to see your wares", type = "", prio = 10, }                        -- Suspicious Sundries (92023) Nara Fadebranch (249437)
      t[136323] = { text = "I would like to see your wares", type = "", prio = 10, }                        -- Suspicious Sundries (92023) Limien Bountcask (249426)

      local t = NPCs({ 248060, 248058, 248059, }, "Quest: Familiar Faces in Peril")
      t[134652] = { text = "Get to safety.", type = "" }                                                    -- Familiar Faces in Peril (91495)     Apothecary Enith (248060)
      t[134653] = { text = "Get to safety.", type = "" }                                                    -- Familiar Faces in Peril (91495)     Ranger Vedoran (248058)
      t[134654] = { text = "Get to safety.", type = "" }                                                    -- Familiar Faces in Peril (91495)     Apprentice Varnis (248059)

      local t = NPCs({542849, 542850, }, "Quest: Gods Before Us")
      t[133889] = { text = "<Place Bonecarapace Fangs into the vase.>", type = "" }                         -- Gods Before Us (86644)             Ritual Vase (542849)
      t[133890] = { text = "<Place Bloodvein Clot into the vase.>", type = "" }                             -- Gods Before Us (86644)             Ritual Vase (542850)

      local t = NPCs({258559, 258560, 258561, 258562, 258563, 258564,  }, "Quest: Light Guide Us")
      t[137985] = { text = "Stop! The Amani are not the real threat here", type = "" }                      -- Light Guide Us (86648)             Eversong Farstrider (258559)
      t[137986] = { text = "Stop! The Amani are not the real threat here", type = "" }                      -- Light Guide Us (86648)             Eversong Spellbreaker (258560)
      t[137987] = { text = "Stop! The Amani are not the real threat here", type = "" }                      -- Light Guide Us (86648)             Eversong Arch Magister (258561)
      t[137988] = { text = "Stop! The Amani are not the real threat here", type = "" }                      -- Light Guide Us (86648)             Blessed Lightbringer (258562)
      t[137989] = { text = "Stop! The Amani are not the real threat here", type = "" }                      -- Light Guide Us (86648)             Veteran Blood Knight (258563)
      t[137990] = { text = "Stop! The Amani are not the real threat here", type = "" }                      -- Light Guide Us (86648)             Blessed Lightbringer (258564)
      t[137991] = { text = "Stop! The Amani are not the real threat here", type = "" }                      -- Light Guide Us (86648)             Eversong Magister (258565)
      t[137992] = { text = "Stop! The Amani are not the real threat here", type = "" }                      -- Light Guide Us (86648)             Veteran Blood Knight (258566)

SetZone("Hammerfall, Eastern Kingdoms")

   local t = NPCs({ 240747, }, "Alonsus Faol")
   t[132918] = { text = "<Tell Alonsus you are ready to go to the Burning Steppes.>", type = "" }        -- One Final Relic (86822)             Alonsus Faol (240747)

   local t = NPCs({ 238101, 238081, }, "Quest: A Humble Servant")
   t[135301] = { text = "You don't feel like you have better things to do?", type = "" }                 -- A Humble Servant (91000)            Sunwalker Malu (238101)
   t[135304] = { text = "Taking a break?", type = "" }                                                   -- A Humble Servant (91000)            Sunwalker Nadura (238081)

   local t = NPCs({ 232033, 232036, 232031, 232035, 232037, }, "Quest: Resupplying Our Suppliers")
   t[134006] = { text = "Dezco sent these supplies for you.", type = "" }                                -- Resupplying Our Suppliers (86846)   Jun'ha (232033)
   t[134008] = { text = "Dezco sent these supplies for you.", type = "" }                                -- Resupplying Our Suppliers (86846)   Tunkk (232036)
   t[134003] = { text = "Dezco sent these supplies for you.", type = "" }                                -- Resupplying Our Suppliers (86846)   Slagg (232031)
   t[138704] = { text = "Dezco sent these supplies for you.", type = "" }                                -- Resupplying Our Suppliers (86846)   Keena (232035)
   t[134042] = { text = "Dezco sent these supplies for you.", type = "" }                                -- Resupplying Our Suppliers (86846)   Mu'uta (232037)

SetZone("Harandar, Eastern Kingdoms")

   local t = NPCs({ 237343, 237345, 237787, 250363, }, "Halduron Brightwing")
   t[133774] = { text = "Let's head down.", type = "" }                                                           -- To Har'athir (86900)    Halduron Brightwing (237343)
   t[133792] = { text = "Let's go.", type = "" }                                                                  -- The Council Assembles (86929) Halduron Brightwing (237345)
   t[138702] = { text = "<Hand Halduron the glimmering bag of seeds.>", type = "" }                               -- Seeds of the Rift (86944) Halduron Brightwing (237787)
   t[135501] = { text = "I am ready.", type = "" }                                                                -- Tell the People What You Have Seen (86890) Halduron Brightwing (250363)

   local t = NPCs({ 237210, 253343 }, "Orweyna")
   t[131842] = { text = "<Take in the view.>", type = "" }                                                        -- To Har'athir (86900) Orweyna (237210)
   t[136444] = { text = "<Hand Orweyna the Fragment of Revelation.>", type = "" }                                 -- Down the Rootways (86912) Orweyna (253343)

   local t = NPC(240407, "Naynar")
   t[132852] = { text = "What can you tell me about the Rift of Aln", type = "", prio = 10 }                      -- Watch the Den (86864) Naynar (240407)
   t[132730] = { text = "Can I see the Renown items you have for sale?", type = "", prio = -5 }

   local t = NPC(240404, "Innkeeper Yinaa")
   t[132851] = { text = "What can you tell me about the Rift of Aln", type = "", prio = 10 }                      -- Watch the Den (86864) Innkeeper Yinaa (240404)
   t[132728] = { text = "I'd like to browse your goods.", type = "", prio = -5 }
   t[132729] = { text = "HOLD SHIFT TO BIND HEARTHSTONE MANUALLY", xpop = { which = "GOSSIP_CONFIRM", containsAll = { "do you want to make", "your new home" }, within = 3, }, type = "", prio = -10, noAuto = true }

   local t = NPCs({ 237209, 241045, }, "Ku'paal")
   t[132537] = { text = "We are froemds of Orweyna and we are here to help.", type = "" }                         -- To Har'athir (86900) Ku'paal (237209)
   t[132858] = { text = "What can you tell me about the Rift of Aln", type = "", }                                -- Watch the Den (86864) Ku'paal (241045)

   local t = NPCs({ 255056, }, "Doecha")
   t[133777] = { text = "What can you tell me about the Rift of Aln?", type = "" }                                -- Watch the Den (86864) Doecha (255056)

   local t = NPCs({ 240225, 244126, }, "Eonka")
   t[132714] = { text = "<Ask if they have Lightbloom in their village.>", type = ""}                             -- The Traveling Flowers (86956) Eonka (240225)
   t[133712] = { text = "Are you still feeling well?", type = ""}                                                 -- Seeds of the Rift (86944) Eonka (244126)

   local t = NPCs({ 237866, 237865, }, "To Har'athir NPCs")
   t[133721] = { text = "It's safe to return to the village.", type = "" }                                        -- To Har'athir (86900)          Oorla (237866)
   t[133726] = { text = "It's safe to return to the village.", type = "" }                                        -- To Har'athir (86900)          Danul (237865)

   local t = NPCs({ 237837, }, "Zur'ashar Kassameh")
   t[131932] = { text = "I am ready to begin the trials.", type = "" }                                            -- Echoes and Memories (86911)   Zur'ashar Kassameh (237837)

   local t = NPCs({ 243930, 240238, 240239, }, "The Traveling Flowers NPCs")
   t[133684] = { text = "<Ask if they have Lightbloom in their village.>", type = "" }                            -- The Traveling Flowers (86956) Keem (243930) DEAD
   t[132713] = { text = "<Ask if they have Lightbloom in their village.>", type = "" }                            -- The Traveling Flowers (86956) Teetem (240238) DEAD
   t[132927] = { text = "<Ask if they have Lightbloom in their village.>", type = "" }                            -- The Traveling Flowers (86956) Rizam (240239) DEAD

   local t = NPCs({ 241690, 241655, }, "Alndust in Right Hands NPCs")
   t[132939] = { text = "This Alndust will protect you from the Lightbloom so we can fight them.", type = "", }   -- Alndust in Right Hands (86882) Eager Volunteer (241690)
   t[132933] = { text = "What happened here?", type = "", }                                                       -- Alndust in Right Hands (86882) Hannan (241655)

SetZone("Quel'Thalas, Eastern Kingdoms")

   local t = NPC(237278, "Lady Liadrin")
   t[132924] = { text = "Nothing will get past me!", type = "" }

   local t = NPC(237255, "High Exarch Turalyon")
   t[133285] = { text = "Let's drive this threat back!", type = "" }

   local t = NPCs({ 236959, 237502, }, "Arator")
   t[132388] = { text = "Your father sent me to find you.", type = "" }                                           -- My Son (89271) Arator (236959)
   t[136469] = { text = "Let's get back to Silvermoon.", type = "" }

   local t = NPCs({ 236789, 240240, 251355, }, "Alonsus Faol")
   t[132515] = { text = "The Vanguard rallies at Sunstrider Rise.", type = "" }                                   -- Champions of Quel'Danas (68770)  Alonsus Faol (236789)
   t[138693] = { text = "<Tell Alonsus you are ready to go to Light's Hope.>", type = "" }                        -- Relic's of Light's Hope (86839) Alonsus Faol (240240)
   t[135480] = { text = "<Tell Alonsus you are ready to go to Hammerfall.>", type = "" }                          -- The Sunwalker Path (86845) Alonsus Faol (251355)

   local t = NPCs({ 240156, 240125, 240075, 240074, }, "Scared Civilian")
   t[132686] = { text = "Arator and I will see you safely to the boats.", type = "" }                             -- Unknown Quest (XXXXX)         Scared Civilian (240156)
   t[132670] = { text = "Arator and I will see you safely to the boats.", type = "" }                             -- Unknown Quest (XXXXX)         Scared Civilian (240125)
   t[132655] = { text = "Arator and I will see you safely to the boats.", type = "" }                             -- Unknown Quest (XXXXX)         Scared Civilian (240075)
   t[132654] = { text = "Arator and I will see you safely to the boats.", type = "" }                             -- Unknown Quest (XXXXX)         Scared Civilian (240074)

   local t = NPCs({ 237211, 236657, }, "Zone Quest NPCs")
   t[132513] = { text = "The Vanguard rallies at Sunstrider Rise.", type = "" }                                   -- Champions of Quel'Danas (68770)  Faerin Lothar (237211)
   t[132514] = { text = "The Vanguard rallies at Sunstrider Rise.", type = "" }                                   -- Champions of Quel'Danas (68770)  Lathraxion (236657)

   local t = NPCs({ 248323, 248326, 248322, 248321, 239623, }, "Relinquishing Relics NPCs")
   t[134818] = { text = "I have a relic to sustain you. It's Mara Fordragon's prayer book.", type = "" }          -- Relinquishing Relics (86902)  Taelia Fordragon (248323)
   t[134855] = { text = "Vindicator Maraad found peace and strength from this...", type = "" }                    -- Relinquishing Relics (86902)  Valunei (248326)
   t[134853] = { text = "Take this sword. It has a great deal of Light within it...", type = "" }                 -- Relinquishing Relics (86902)  Salandria (248322)
   t[134854] = { text = "This is Uther's kit from his work as a healer...", type = "" }                           -- Relinquishing Relics (86902)  Mehlar Dawnblade (248321)
   t[136038] = { text = "<Give Velen the remaining relics to distribute.>", type = "" }                           -- Relinquishing Relics (86902)  Prophet Velen (239623)

SetZone("Silvermoon City, Eastern Kingdoms")

   local t = NPC(248629, "General Amias Bellamy")
   t[135224] = { text = "<Offer Greeting.>", type = "" }                                                          -- Paved in Ash (86735) General Amias Bellamy (248629)

   local t = NPCs({ 244644, 237510, }, "Arator")
   t[133853] = { text = "Alonsus Faol asks that we meet him at the Sunwell.", type = "" }                         -- Meet at the Sunwell (86837)   Arator (244644)
   t[133856] = { text = "Let's go.", type = "" }                                                                  -- Meet at the Sunwell (86837)   Arator (244644)
   t[133121] = { text = "I'm ready!", type = "" }                                                                 -- A Bulwark Remade (86833)      Arator (237510)
   t[136685] = { text = "What will you do next?", type = "" }                                                     -- A Bulwark Remade (86833)      Arator (237510)

   local t = NPC( 249270, "Grand Magister Rommath")
   t[135139] = { text = "<Explain that Lor'themar wants to see Umbric freed.>", type = "" }                       -- You Know This Evil? (91967) Grand Magister Rommath (249270)
   t[135140] = { text = "<Explain how Umbric is reaserching a way into the Voidstorm>", type = "" }               -- You Know This Evil? (91967) Grand Magister Rommath (249270)

   local t = NPCs({ 249289, }, "Anduin Wrynn")
   t[135179] = { text = "<Explain that Lor'Themar wants to see Umbric freed.>", type = "" }                       -- You Know This Evil? (91967) Anduin Wrynn (249289)
   t[135178] = { text = "<Explain how Umbric is reaserching a way into the Voidstorm>", type = "" }               -- You Know This Evil? (91967) Anduin Wrynn (249289)

   local t = NPC(235787, "Lor'themar Theron")
   t[132632] = { text = "<Skip conversation> I expect you'll sort things out.", type = "" }                       -- Unknown Quest (XXXXX) Lor'themar Theron (235787)
   t[134143] = { text = "What now?", type = "" }                                                                  -- Fractured (86650) Lor'themar Theron (235787)

   local t = NPCs({ 249268, }, "Lothraxion")
   t[135157] = { text = "<Explain that Lor'Themar wants to see Umbric freed.>", type = "" }                       -- You Know This Evil? (91967) Lothraxion (249268)
   t[135156] = { text = "<Explain how Umbric is reaserching a way into the Voidstorm>", type = "" }               -- You Know This Evil? (91967) Lothraxion (249268)

   local t = NPC(241458, "Lothene")
   t[133298] = { text = "I have a bag full of creature parts ...", type = "", prio = 10 }                         -- Five Finger Discount (89204) Lothene (241458)
   t[133299] = { text = "What do you have for sale?", type = "", prio = -5 }

   local t = NPC(241455, "Belil")
   t[133290] = { text = "I've never seen a rock in my life...", type = "", prio = 10 }                            -- Five Finger Discount (89204) Belil (241455)
   t[133293] = { text = "Train me in Mining", type = "", prio = -5 }

   local t = NPC(239630, "Innkeeper Jovia")
   t[134012] = { text = "The Alliance will be staying here temporarily. Lodgings will be needed.", type = "", prio = 10 }
   t[132666] = { text = "Lor'themar has allowed us to stay for now...", type = "", prio = 9 } -- Paved in Ash (86735) Innkeeper Jovia (239630)
   t[132667] = { text = "Let me browse your goods.", type = "", prio = -5 }
   t[132668] = { text = "HOLD SHIFT TO BIND HEARTHSTONE MANUALLY", xpop = { which = "GOSSIP_CONFIRM", containsAll = { "do you want to make", "your new home" }, within = 3, }, type = "", prio = -10, noAuto = true }

   local t = NPC(242381, "Valeera Sanguinar")
   t[133099] = { text = "Lor'themar will need the services of the Reliquary", type = "" }

   local t = NPC(239664, "Banker Ceera")
   t[132676] = { text = "Lor'themar has requested that we be allowed...", type = "", prio = 10 }  -- Paved in Ash (86735) Ceera (239664)
   t[132677] = { text = "I would like to check my deposit box.", type = "", prio = -10 }

   local t = NPC(239639, "Skymaster Skyles")
   t[132674] = { text = "Lor'themar has requested that we be allowed...", type = "", prio = 10 }  -- Paved in Ash (86735) Skymaster Skyles (239639)
   t[132675] = { text = "Show me where I can fly.", type = "", prio = -10 }

   local t = NPC(239673, "Magistrix Narinth")
   t[132678] = { text = "Lor'themar has has allowed us to stay in the city...", type = "", prio = 10 }  -- Paved in Ash (86735) Magistrix Narinth (239673)
   
   local t = NPC(253468, "Drathen")
   t.__meta.stopIfQuestAvailable = 92869  -- questID to block gossip options until accepted
   t.__meta.stopIfQuestTurnIn = 92869     -- questID to block gossip options while ready to turn in
   t[136540] = { text = "Train me.", type = "" }

   local t = NPCs({ 249174, 248630, 248826, }, "Deepening Shadows NPCs")
   t[135112] = { text = "<Explain the events of the Sunwell.>", type = "" }                                    -- Deepening Shadows (91854) Sin'dorei Vendor (249174)
   t[135203] = { text = "Why are you seizing people?", type = "" }                                             -- Deepening Shadows (91854) Commander Venei Lightblood (248630)
   t[135204] = { text = "Arresting citizens is not why the Vanguard are here.", type = "" }                    -- Deepening Shadows (91854) Commander Venei Lightblood (248630)
   t[135052] = { text = "Hail the victories of the Vanguard and Sin'dorei you have seen so far.", type = "" }  -- Deepening Shadows (91854) Doomsayer (248826)

   local t = NPCs({ 248628, }, "War Chaplain Senn")
   t[135148] = { text = "<Explain that Lor'Themar wants to see Umbric freed.>", type = "" }                    -- You Know This Evil? (91967) War Chaplain Senn (248628)
   t[135147] = { text = "<Explain how Umbric is reaserching a way into the Voidstorm>", type = "" }            -- You Know This Evil? (91967) War Chaplain Senn (248628)
   t[135149] = { text = "<Ask how they would enter the Voidstorm without Umbric's help.>", type = "" }         -- You Know This Evil? (91967) War Chaplain Senn (248628)

   local t = NPCs({ 247647, }, "Gaari")
   t[135588] = { text = "Mr. Brightstitch isn't accepting more work right now.", type = "" }                   -- Mad to Measure (91386) Gaari (247647)

   local t = NPCs({ 244471, 244469, 244470, 244472, }, "Murder Row NPCs")
   t[133938] = { text = [[My employer sent me to purchase some "special" reagents]], type = "" }               -- Murder Row: Acting the Part (90819) Miss Len'dali (244471)
   t[133942] = { text = "My employer asked me to look for some unique mana wyrms.", type = "" }                -- Murder Row: Acting the Part (90819) Denorin (244469)
   t[133942] = { text = "My employer asked me to look for some unique mana wyrms.", type = "" }                -- Murder Row: Acting the Part (90819) Denorin (244469)
   t[133946] = { text = "Where can I get more of these?", type = "" }                                          -- Murder Row: Acting the Part (90819) Thiel (244470)
   t[133969] = { text = "I'm looking to purchase more of these?", type = "" }                                  -- Murder Row: Acting the Part (90819) Vira Bloodsong (244472)

   local t = NPCs({ 241425, }, "Row Rat")
   t[132989] = { text = "I'm looking for Jaeth. Do you know where he is?", type = "" }                         -- Stir the Nest (89202) Row Rat (241425)

   local t = NPCs({ 241399, }, "Jaeth")
   t[132992] = { text = "<Lay the documents on the table...>", type = "" }                                     -- Mutual Benefit (89203) Jaeth (241399)

   local t = NPCs({ 242200, }, "Lendranil")
   t[133247] = { text = "I have some very specific upgrade needs for these gloves...", type = "" }             -- Five Finger Discount (89204) Lendranil (242200)

   local t = NPCs({ 241490, }, "Magister Dawnblaze")
   t[133545] = { text = "We killed Aradis and freed the people he too from Murder Row.", type = "" }           -- What We're Owed (89208) Magister Dawnblaze (241490)

   local t = NPCs({ 244474, }, "Tarelin")
   t[134044] = { text = "I'm picking up a shipment for Zaen.", type = "" }                                     -- Murder Row: Harbored Secrets (90821) Tarelin (244474)

SetZone("Stormwind City, Eastern Kingdoms")

   local t = NPC( 171789, "High Inquisitor Whitemane")
   t[52725] = { text = "I have heard this tale before. <Skip the Maw introduction. Oribos awaits.>", xpop = { which = "GOSSIP_CONFIRM", containsAny = { "are you sure", "cannot be undone" }, within = 3, }, type = "", }

   local t = NPC( 54334, "Darkmoon Faire Mystic Mage")
   t.__meta.stopIfQuestAvailable = 7905  -- questID to block gossip options until accepted
   t[40457] = { text = "Take me to the faire staging area.", xpop = { which = "GOSSIP_CONFIRM", containsAny = { "Travel to the faire staging area" }, within = 3, }, type = "", }

   local t = NPC( 150122, "Honor Hold Mage")
   t[50005] = { text = "I must report to the Dark Portal.", type = "" }

   local t = NPC( 149626, "Vanguard Battlemage")
   t[51033] = { text = "I must help Khadgar. Send me to the Blasted Lands!", type = "" }

   local t = NPCs({ 246155, 246154, }, "Zone Quest NPCs")
   t[134631] = { text = "Are you talking about the Twilight's Blade?", type = "" }
   t[134634] = { text = "Are you talking about the Twilight's Blade?", type = "" }

SetZone("Tirisfal Glades, Eastern Kingdoms")

   local t = NPC(237602, "Alonsus Faol")
   t[132903] = { text = "<Tell Alonsus you are ready to return to Silvermoon.>", type = "" }                         -- Unknown Quest (XXXXX) Alonsus Faol (237602)

   local t = NPC(141488, "Zidormi")
   t[49018] = { text = "Can you show me what Tirisfal Glades was like before the Battle for Lordaeron.", type = "" } -- No Quest (XXXXX) Zidormi (141488)

SetZone("Twilight Highlands, Eastern Kingdoms")

    -- 12.0.0 Prepatch
   local t = NPCs({ 248230, 248229, 248228 }, "Restlass Neophyte")
   t[135794] = { text = "<Challenge the cultist to a \"sparring match.\"", type = "" }

SetZone("Westfall, Eastern Kingdoms")

   local t = NPC(523, "Thor")
   t[32677] = { text = "I need a ride.", type = "" }

SetZone("Zul'Aman, Eastern Kingdoms")

   local t = NPCs({ 245646, }, "Zul'jan")
   t[134133] = { text = "Are you okay, Zul'jan", type = "" }                           -- Broken Bridges (91062) Zul'jan (245646)

   local t = NPCs({ 236659, 240215, 240216, 253980, 241306, }, "Zul'jarra")
   t[138031] = { text = "<Skip the forest times meeting.>", type = "" }                -- Isolation (86723) Zul'jarra (236659)
   t[134140] = { text = "<Enter the Den of Nalorakk with Zul'jarra>", type = "" }      -- Den of Nalorakk: Unforgiven (91958) Zul'jarra (240215)
   t[138171] = { text = "What is next?", type = "" }                                   -- Den of Nalorakk: Unforgiven (91958) Zul'jarra (240215)
   t[132827] = { text = "Is there nothing we can do?", type = "" }                     -- Hash'ey Away (86683) Zul'jarra (240216)
   t[135208] = { text = "I am ready to battle Mor'duun", type = "" }                   -- Blade Shattered (86692) Zul'jarra (253980)
   t[134131] = { text = "<Start the celebration.>", type = "" }                        -- De Legend of de Hash'ey (86693) Zul'jarra (241306)

   local t = NPCs({ 616377, 616428, 246409, }, "Den of Nalorakk")
   t[135009] = { text = "<Meditate on the sound of the flames.>", type = "" }      -- Den of Nalorakk Dungeon  Ethereal Pyre (616377)
   t[135010] = { text = "<Meditate on the sound of the flames.>", type = "" }      -- Den of Nalorakk Dungeon  Ethereal Pyre (616428)
   t[136468] = { text = "<Leave Nalorakk's Den.>", type = "" }                     -- Den of Nalorakk Dungeon  Zul'jarra (246409)

   local t = NPCs({ 244591, }, "Vun'zarah")
   t[134081] = { text = "Do you know anything that will help us speak to Jan'alai?", type = "" }      -- Coals of a Dead Loa (86661) Vun'zarah (244591)

   local t = NPCs({ 236590, 236591, 237301, }, "Important Amani NPCs")
   t[132579] = { text = "Zul'jan sent me to find you.", type = "" }                    -- Important Amani (86719)       Elder Doru (236590)
   t[132582] = { text = "Zul'jan sent me to find you.", type = "" }                    -- Important Amani (86719)       Torundo the Grizzled (236591)
   t[132584] = { text = "It is time to evacuate, Loa Speaker Kinduru", type = "" }     -- Important Amani (86719)       Loa Speaker Kinduru (237301)

   local t = NPCs({ 245589, 244562, 244479, }, "Left in the Shadows NPCs")
   t[132891] = { text = "<Request lightwood report.>", type = "" }                     -- Left in the Shadows (86652)   Lilaju (245589)
   t[135286] = { text = "Where are the shamans?", type = "" }                          -- Left in the Shadows (86652)   Tak'lejo (244562)
   t[133822] = { text = "I will hel Zul'jarra", type = "" }                            -- Left in the Shadows (86652)   Loa Speaker Kinduru (244479)

   local t = NPCs({ 250068, }, "Loa Speaker Tobul")
   t[135472] = { text = "How do we speak to Halazzi?", type = "" }                     -- Halazzi's Guide (92084)       Loa Speaker Tobul (250068)

   local t = NPCs({ 245512, }, "Loa Speaker Brek")
   t[134196] = { text = "Where is Jan'alai?", type = "" }                              -- The Flames Rise Higher (90772) Loa Speaker Brek (245512)

   local t = NPCs({ 245664, }, "Lilaju")
   t[134139] = { text = "We will, But we need to speak to Nalorakk to do so", type = "" } -- Den of Nalorakk: Waking de Bear (86682) Lilaju (245664)





