local _, ns = ...

ns.db = ns.db or {}
ns.db.rules = ns.db.rules or {}

-- XP10 database pack
-- Add rules like:
-- ns.db.rules[123456] = ns.db.rules[123456] or {}
-- ns.db.rules[123456].__meta = { zone = "Zone, Continent", npc = "NPC Name" }
-- ns.db.rules[123456][98765] = { text = [[Option text]] }
--   pcn = "Name-Realm"   -- only if you are this character
--   pcn = {"Name-Realm", "Alt-Realm"} -- only if you are ANY of these characters

local H = ns.TalkDB
local t
local SetZone, NPC, MAP = H.SetZone, H.NPC, H.MAP
local TalkCacheSeen, GetCharacterCacheKey = H.TalkCacheSeen, H.GetCharacterCacheKey
local GetViewGossipState = H.GetViewGossipState


SetZone("Amirdrassil, Dragon Isles")


    t = NPC("Elder Verdantbark", { 251316, })
    t[137249] = { text = "<Present throwing stones to Elder Verdantbark.>" }	-- Awaken the Ancient Protector (88927) Elder Verdantbark (251316)

	t = NPC("First Arcanist Thalyssra", { 250853, })
    t[135657] = { text = "Tell Shandris what has transpired." }	-- Children of the Stars (88923) First Arcanist Thalyssra (250853)

    t = NPC("Lor'themar Theron", { 240335, })
    t[135655] = { text = "Tell Shandris what has transpired." }	-- Children of the Stars (88923) Lor'themar Theron (240335)

    t = NPC("Magister Umbric", { 253613, })
    t[135656] = { text = "Tell Shandris what has transpired." }	-- Children of the Stars (88923) Magister Umbric (253613)

    t = NPC("Malastral", { 255687, })
    t[137236] = { text = "Give me the banner and I will gather the wisps." }	-- Awaken the Ancient of Lore (88937) Malastral (255687)


SetZone("Thaldraszus, Dragon Isles")


	t = MAP("Vault of the Incarnates", {2119,})
	t[107543] = { text = "We have need of your aid." }
	t[107544] = { text = "Carry me into battle." }
	t[107545] = { text = "Carry me into battle." }
	t[107546] = { text = "We have need of your aid." }
	t[107548] = { text = "<You gently prod the dragon awake.>" }
	t[107549] = { text = "Carry me into battle." }
	t[107550] = { text = "We have need of your aid." }
	t[107551] = { text = "Carry me into battle." }
	t[107552] = { text = "We have need of your aid." }
	t[107553] = { text = "Carry me into battle." }
	
    t[ 55981] = { text = "Begin the assault.", mount = true, xpop = { which = "GOSSIP_CONFIRM", containsAny = { "This will begin the assault" }, within = 3, }, }


SetZone("The Azure Span, Dragon Isles")


	t = MAP("The Azure Vault Dungeon", {2074,2075,2076,})
	t[ 56056] = { text = "Proceed onward." }
	t[ 56247] = { text = "Proceed onward." }
	t[ 56248] = { text = "Proceed onward." }
	t[ 56250] = { text = "Proceed onward." }
	t[ 56250] = { text = "Proceed onward." }
	t[ 56251] = { text = "Proceed onward." }

	t = NPC("Tattukiaka", { 199448, })
	t[107742] = { text = "Let's see what you have on offer." }	-- Awaken the Ancient Protector (88927) Tattukiaka (199448)


SetZone("The Forbidden Reach, Dragon Isles")


    t = NPC("Zone NPCs", { 184165,182610,182611, })
    t[ 51921] = { text = "Come with me. I will get you to safety." }	-- Halp! (65071)		Little Ko (184165)
    t[ 51849] = { text = "Come with me. I will get you to safety." }	-- Final Orders (65100)	Scalecommander Viridia (182610)
    t[ 51850] = { text = "<Relay what Nozdormu told you.>" }			-- Final Orders (65100)	Scalecommander Sarkareth (182611)


SetZone("The Waking Shores, Dragon Isles")


	t = NPC("Akxall", { 189262, })
	t[ 55289] = { text = "Why are there so few eggs here?" }

	t = NPC("Alexstrasza the Life-Binder", { 187290,185905, })
	t.__meta.stopIfQuestAvailable = {65795,}                                           				-- Waits for Quest Accepted (First NPCID Only)
	t.__meta.stopIfQuestTurnIn = { 65794,}                                   							-- Waits for Quest Hand-Ins (First NPCID Only)
	t[107094] = { text = "<Offer the rescued egg to Queen Alexstrasza.>" }
	t[ 55380] = { text = "I am ready." }

	t = NPC("Ambassador Fastrasz (Innkeeper)", { 193393, })
	t[ 55674] = { text = "I'm a new arrival with the Dragonscale Expedition." }
	t[ 55672] = { text = "Make this inn your home.", xpop = { which = "GOSSIP_CONFIRM", containsAll = { "do you want to make", "your new home" }, within = 3, }, prio = -10, noAuto = true }

	t = NPC("Andustrasza", { 193988, })
	t[ 56426] = { text = "Do you have any spare scraps of fabric?" }

	t = NPC("Bathoras", { 194805, })
	t[ 56408] = { text = "I have gathered the components for you." }

	t = NPC("Beleaguered Explorer", { 189089, })
	t[ 54942] = { text = "Go to the vault. You'll be safe there." }

	t = NPC("Boss Magor", { 189065, })
	t.__meta.stopIfQuestAvailable = {72302,72308,}                                           				-- Waits for Quest Accepted (First NPCID Only)
--	t.__meta.stopIfQuestTurnIn = { 96567, }                                   							-- Waits for Quest Hand-Ins (First NPCID Only)
	t[107564] = { text = "Show me your wares." }

	t = NPC("Cataloger Jakes", { 189226, })
	t.__meta.stopIfQuestAvailable = {70834,71036,}                                           				-- Waits for Quest Accepted (First NPCID Only)
--	t.__meta.stopIfQuestTurnIn = { 96567, }                                   							-- Waits for Quest Hand-Ins (First NPCID Only)
	t[56218] = { text = "Can I see the Renown items you have for sale?" }

	t = NPC("Celormu", { 198040, })
	t[107284] = { text = "I'd like to try the course to Skytop Observatory." }

	t = NPC("Danielle Anglers", { 191150, })
	t[107425] = { text = "Train me in Fishing." }

	t = NPC("Elementalist Taiyang", { 190352, })
	t[ 54908] = { text = "I'm ready." }

	t = NPC("Embassy Visitor Log", { 378435, })
	t[ 55746] = { text = "<Begin filling out the form.>" }
	t[ 55757] = { text = "Wrathion's BFF" }
	t[ 55762] = { text = "Precisely when I meant to." }
	t[ 55775] = { text = "My purpose is my own" }

	t = NPC("Estarastrasz", { 198595, })
	t[ 56429] = { text = "Do you have any spare scraps of fabric?" }

	t = NPC("Granpap Whiskers (Innkeeper)", { 187408, })
	t[ 56237] = { text = "Open Vendor.", prSel = "Opening Vendor, Shift+Click NPC to bind Hearth", }
	t[ 56238] = { text = "Make this inn your home.", xpop = { which = "GOSSIP_CONFIRM", containsAll = { "do you want to make", "your new home" }, within = 3, }, prio = -10, noAuto = true }

	t = NPC("Grun Ashbeard", { 187261, })
	t.__meta.stopIfQuestAvailable = {66112,70028,}														-- Waits for Quest Accepted (First NPCID Only)
	t.__meta.stopIfQuestTurnIn = { 66112, }																-- First NPCID, Stops Gossip when turn in available
	t[107293] = { text = "Train me in Mining." }

	t = NPC("Head Chef Stacks", { 198094, 193121, })
	t.__meta.stopIfQuestAvailable = {72250,}															-- Waits for Quest Accepted (First NPCID Only)
	t[107418] = { text = "Can you, um... teach me how to cook?" }

	t = NPC("Holthkastrasz", { 187292, })
	t[ 55363] = { text = "I'd like to go to the Ruby Lifeshrine." }

	t = NPC("Iyali", { 193500, })
	t[ 55294] = { text = "<Report whelp behavior.>" }
	t[106986] = { text = "One whelping called other proto-drakes to protect it.", prio = 1 }
	t[106988] = { text = "One whelping bit me and flew away.", prio = 2 }
	t[106987] = { text = "One whelpling enjoyed being petted.", prio = 3 }
	t[106990] = { text = "<Report more whelp behavior.>" }
	t[106995] = { text = "<Report more whelp behavior.>" }
	t[107710] = { text = "<Finish report.>" }
	t[106994] = { text = "<Finish report.>" }
	t[107291] = { text = "This creature is too injured. We need a researcher to help." }
	t[107292] = { text = "<Agree to Iyali's terms.>" }

	t = NPC("Kalendormu", { 198720, })
	t[107539] = { text = "Take me to the Obsidian Throne.", xpop = { which = "GOSSIP_CONFIRM", containsAll = { "are you certain", "cannot be undone" }, within = 3, }, }

	t = NPC("Ka'ro the Chopper", { 194471, })
	t[ 56153] = { text = "How goes the melon chopping?", }

	t = NPC("Left", { 190563, })
	t[ 55296] = { text = "What have you observed about the djaradin?" }

	t = NPC("Lithragosa", { 193364, })
	t[ 55584] = { text = "I'm ready. [Open Dragonriding Skill Track.]" }

	t = NPC("Lord Andestrasz", { 193287, })
	t[ 55643] = { text = "Tell me about skyriding." }

	t = NPC("Lyrastrasz", { 193991, })
	t[ 56427] = { text = "Do you have any spare scraps of fabric?" }

	t = NPC("Majordomo Selistra", { 193372,186795,187278, })
	t[ 55872] = { text = "How can I help defend against the djaradin?" }
	t[ 54941] = { text = "Take me with you to see the queen, please." }
	t[107159] = { text = "<Check in with the Majordomo.>" }

	t = NPC("Maribeth (Innkeeper)", { 187399, })
	t[ 56240] = { text = "Open Vendor.", prSel = "Opening Vendor, Shift+Click NPC to bind Hearth", }
	t[ 56241] = { text = "Make this inn your home.", xpop = { which = "GOSSIP_CONFIRM", containsAll = { "do you want to make", "your new home" }, within = 3, }, prio = -10, noAuto = true }

	t = NPC("Misty Catseye", { 198398, })
--	t.__meta.stopIfQuestAvailable = {72249,}														-- Waits for Quest Accepted (First NPCID Only)
--	t.__meta.stopIfQuestTurnIn = {72249,}																-- First NPCID, Stops Gossip when turn in available
	t[107413] = { text = "Train Jewelcrafting" }

	t = NPC("Mora Cloudwalker", { 190524, })
	t[107426] = { text = "Trainer", }

	t = NPC("Mother Elion", { 185904, })
	t[ 55258] = { text = "Why do you stay here, if you have no eggs to rear?" }

	t = NPC("Pathfinder Jeb", { 187700, })
	t[ 56098] = { text = "I want to browse your goods." }

	t = NPC("Rae'ana", { 188265, })
	t[ 56201] = { text = "I would like to see the supplies and items you have." }

	t = NPC("Rathestrasz", { 193995, })
	t[ 56424] = { text = "Do you have any spare scraps of fabric?" }

	t = NPC("Right", { 190564, })
	t[ 55298] = { text = "What have you observed about the djaradin?" }

	t = NPC("Scalecommander Emberthal", { 192795, })
	t.__meta.stopIfQuestAvailable = {66048,}														-- Waits for Quest Accepted (First NPCID Only)
	t.__meta.stopIfQuestTurnIn = {72241,}																-- First NPCID, Stops Gossip when turn in available
	t[107399] = { text = "Tell me of the dracthyr's origins." }

	t = NPC("Scout Francisco", { 190423, })
	t[ 55168] = { text = "Where is it now?" }

	t = NPC("Scout Ri'tal", { 190334, })
	t[ 55167] = { text = "Where is the orb now?" }

	t = NPC("Sendrax", { 193362,187406,190269, })
	t[ 55636] = { text = "Why aren't the dragons here to meet us?" }
	t[ 55637] = { text = "<Send the signal flare to alert the dragons of our arrival.>" }
	t[ 55900] = { text = "Tell me about the history of the djaradin." }
	t[ 55225] = { text = "What is happening here?" }
	t[ 55259] = { text = "I am ready." }

	t = NPC("Sweelin", { 187389, })
	t[ 55304] = { text = "Open Vendor.", prSel = "Opening Vendor, Shift+Click NPC to bind Hearth", }
	t[ 55303] = { text = "Make this inn your home.", xpop = { which = "GOSSIP_CONFIRM", containsAll = { "do you want to make", "your new home" }, within = 3, }, prio = -10, noAuto = true }

	t = NPC("Tallevia Mistsong", { 192484, })
	t[ 34833] = { text = "Show me where I can fly." }

	t = NPC("Talonstalker Kavia", { 188299, })
	t[ 55335] = { text = "What have you observed about the djaradin?" }

	t = NPC("Thomas Bright", { 192574, })
	t[ 55059] = { text = "What do you mean, \"high quality\"?"}
	t[ 55062] = { text = "What do you want to give Miguel?"}
	t[ 55066] = { text = "I will find these for you."}
--	t[ 55060] = { text = "I will use only the best reagents!", prio = 08, }

	t = NPC("Tirastrasza", { 198605, })
	t[ 56428] = { text = "Do you have any spare scraps of fabric?" }

	t = NPC("Tixxa Mixxa", { 192490, })
	t[ 34833] = { text = "Show me where I can fly." }

	t = NPC("Toninaar", { 192558, })
	t[ 56062] = { text = "Train me in Fishing." }

	t = NPC("Tyrgon", { 192298, })
	t[107424] = { text = "<Name proto-dragon whelp.>" }
	t[107419] = { random = true, text = "Lord Firegiggle", prSel = "Whelp named Lord Firegiggle" }
	t[107420] = { random = true, text = "Baron von Swoopenbite", prSel = "Whelp named Baron von Swoopenbite" }
	t[107421] = { random = true, text = "Mr. Nibbles", prSel = "Whelp named Mr. Nibbles" }
	t[107422] = { random = true, text = "Bob", prSel = "Whelp named Bob" }
	t[107423] = { random = true, text = "Toughscale", prSel = "Whelp named Toughscale" }

	t = NPC("Valdestrasz", { 193987, })
	t[ 56425] = { text = "Do you have any spare scraps of fabric?" }

	t = NPC("Veritistrasz", { 194076, })
	t[ 63853] = { text = "<Sit and look at the view.>" }
	t[ 63862] = { text = "<You are busy. Get up and leave.>" }

	t = NPC("Xius", { 189261, })
	t[ 55288] = { text = "What do you do here?" }

	t = NPC("Zahkrana", { 189260, })
	t[ 55290] = { text = "How do you care for these eggs?" }

	t = NPC("Veeno", { 192055, })
	t.__meta.stopIfQuestAvailable = {72249,}														-- Waits for Quest Accepted (First NPCID Only)
	t.__meta.stopIfQuestTurnIn = {72249,}																-- First NPCID, Stops Gossip when turn in available
	t[ 35961] = { text = "Train Enchanting" }

	t = NPC("Zayn Starmaker", { 192565, })
	t.__meta.stopIfQuestAvailable = {72249,}														-- Waits for Quest Accepted (First NPCID Only)
	t.__meta.stopIfQuestTurnIn = {72249,}																-- First NPCID, Stops Gossip when turn in available
	t[107294] = { text = "Train Tailoring" }

