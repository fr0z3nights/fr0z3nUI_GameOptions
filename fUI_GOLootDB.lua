-- LootIt data DB (built-in tables)
-- - Addon aliases / currency aliases
-- - Suppress seeds (for the Suppress popout)

local addonName, ns = ...
if type(ns) ~= "table" then ns = {} end

local LI = (ns and ns.LootIt) or {}
ns.LootIt = LI
fr0z3nUI_LootIt = LI
LI.ADDON = LI.ADDON or addonName

local addonIgnoredItemIDs = {}

local function NormalizeAddonAliasSeeds(aliases)
    local ignored = {}
    if type(aliases) ~= "table" then
        return ignored
    end

    for itemID, entry in pairs(aliases) do
        if type(entry) == "table" then
            local text = entry.text or entry.alias or entry.name
            if type(text) == "string" and text ~= "" then
                aliases[itemID] = text
            else
                aliases[itemID] = nil
            end

            if entry.ignore == true then
                ignored[itemID] = true
            end
        end
    end

    return ignored
end

fr0z3nUI_LootItDB = fr0z3nUI_LootItDB or {}

fr0z3nUI_LootIt_AddonAliases = fr0z3nUI_LootIt_AddonAliases or {
    [116415] = "TW Token", -- Timewarped Badge
    [ 67151] = "Poseidus", -- Reins of Poseidus
    [ 71096] = { text = "DM Test", ignore = true }, -- ignore state lives with the alias seed
  -- Add itemID aliases here (not currencies).
}

addonIgnoredItemIDs = NormalizeAddonAliasSeeds(fr0z3nUI_LootIt_AddonAliases)

-- Built-in currency aliases shipped with the addon.
-- Keyed by currencyID; values are display-only text (link remains the original currency).
fr0z3nUI_LootIt_AddonCurrencyAliases = fr0z3nUI_LootIt_AddonCurrencyAliases or {
  [1166] = "TW Token", -- Timewarped Badge
}

-- Built-in suppress seeds shipped with the addon.
-- These are *not* saved as rules; they are toggled on/off via the LootIt DB.
-- Each entry is a case-insensitive substring match.
fr0z3nUI_LootIt_AddonSuppressSeeds = fr0z3nUI_LootIt_AddonSuppressSeeds or {

--  12  Midnight
    { key = "X12:AmaniDef",         text = "Amani Defender says" },
    { key = "X12:AmaniQtermstr",    text = "Amani Quartermaster says" },
    { key = "X12:Erinye",           text = "Er'inye says" },
    { key = "X12:Eshaye",           text = "Eshaye says" },
    { key = "X12:Juljarra",         text = "Jul'jarra says" },
    { key = "X12:Juljan",           text = "Jul'jan says" },
    { key = "X12:Junka",            text = "Jun'ka says" },
    { key = "X12:KulamaraFierce",   text = "Kul'amara the Fierce says" },
    { key = "X12:RngrCptnLilatha",  text = "Ranger Captain Lilatha says" },
    { key = "X12:SlvrmnCitzn",      text = "Silvermoon Citizen says" },
    { key = "X12:ThalassianProf",   text = "Thalassian Professor says" },
    { key = "X12:TwilightInv",      text = "Twilight Invader says" },
    { key = "X12:UniverstyUndrgrd", text = "University Undergraduate says" },
    { key = "X12:Valeera",          text = "Valeera Sanguinar says" },
    { key = "X12:Zei'ka",           text = "Zei'ka says" },
    { key = "X12:Zuljarra",         text = "Zul'jarra says" },
--  10  Dragonflight
    { key = "X10:ArchmageKhadgar",  text = "Archmage Khadgar says" },
    { key = "X10:BoneboltHunter",   text = "Bonebolt Hunter" },
    { key = "X10:ClawFighter",      text = "Claw Fighter" },
    { key = "X10:EminentEarthshpr", text = "Eminent Earthshaper yells" },
    { key = "X10:Kalecgos",         text = "Kalecgos says" },
    { key = "X10:Kalecgos",         text = "Kalecgos yells" },
    { key = "X10:QuarryEarthshapr", text = "Quarry Earthshaper yells" },
    { key = "X10:Sindragosa",       text = "Sindragosa says" },
    { key = "X10:TarasekLooter",    text = "Tarasek Looter says" },
    { key = "X10:TelashGreywing",   text = "Telash Greywing yells" },
    { key = "X10:TrickclawMystic",  text = "Trickclaw Mystic" },
    { key = "X10:UnrulyTextbook",   text = "Unruly Textbook says" },
    { key = "X10:ProfessorMaxdorm", text = "Professor Maxdormu says" },
    { key = "X10:Malinor",          text = "Malinor says" },
    { key = "X10:ProfessorIchstrz", text = "Professor Ichistrasz says" },
    { key = "X10:ProfessorMystakr", text = "Professor Mystakria says" },
    { key = "X10:EchoOfDoragosa",   text = "Echo of Doragosa" },
    { key = "X10:MelidrussaChlwrn", text = "Melidrussa Chillworn says" },
    { key = "X10:MajordomoSelistr", text = "Majordomo Selistra" },
    { key = "X10:KokiaBlazehoof",   text = "Kokia Blazehoof yells" },
    { key = "X10:Tricktotem",       text = "Tricktotem says" },
    { key = "X10:CaptiveTuskarr",   text = "Captive Tuskarr says" },
    { key = "X10:RiraHackclaw",     text = "Rira Hackclaw says" },
    { key = "X10:CruelBonecrusher", text = "Cruel Bonecrusher" },
    { key = "X10:Gobstabber",       text = "Gobstabber" },
    { key = "X10:Gutstabber",       text = "Gutstabber" },
    { key = "X10:DecatriarchWrthy", text = "Decatriarch Wratheye" },
    { key = "X10:Bertinuat",        text = "Bertinuat says" },
    { key = "X10:Sentiu",           text = "Sentiu says" },
    { key = "X10:Japukitat",        text = "Japukitat says" },
    { key = "X10:SkulkingGutstbbr", text = "Skulking Gutstabber" },
    { key = "X10:BrackenhideShapr", text = "Brackenhide Shaper says" },
    { key = "X10:BloodthirstyCub",  text = "Bloodthirsty Cub" },
    { key = "X10:DefierDraghar",    text = "Defier Draghar says" },
--  07  Legion
    { key = "X07:PBEnvBert",        text = "Environeer Bert says" },
    { key = "X07:PBWinLitHlp",      text = "Winter's Little Helper says" },
--  06  Draenor
    { key = "X06:PBTaralune",       text = "Taralune says" },
    { key = "X06:PhilHinbrd",       text = "Phillip Hillenbrand says" },
    { key = "X06:StphnHckln",       text = "Stephen Hicklin says" },
--  05  Mists of Pandaria
    { key = "X05:DGStormbring",     text = "Stormbringers react to your presence" },
    { key = "X05:DGSnowdrift",      text = "Master Snowdrift yells" },
    { key = "X05:PBAki",            text = "Aki the Chosen says" },
    { key = "X05:PBAnthea",         text = "Anthea says" },
    { key = "X05:PBBrightblade",    text = "Cymre Brightblade says" },
    { key = "X05:PBBurning",        text = "Burning Pandaren Spirit says" },
    { key = "X05:PBGargra",         text = "Gargra says" },
    { key = "X05:PBHyuna",          text = "Hyuna of the Shrines says" },
    { key = "X05:PBMoruk",          text = "Mo'ruk says" },
    { key = "X05:PBSeekerZusshi",   text = "Seeker Zusshi says" },
    { key = "X05:PBThundering",     text = "Thundering Pandaren Spirit says" },
    { key = "X05:TIChiji",          text = "Chi-ji yells" },
    { key = "X05:TIEmpShaohao",     text = "Emperor Shaohao yells" },
    { key = "X05:TINiuzao",         text = "Niuzao yells" },
    { key = "X05:TIOrdos",          text = "Ordos yells" },
    { key = "X05:TIXuen",           text = "Xuen yells" },
    { key = "X05:TIYulon",          text = "Yu'lon yells" },
--  02  Outland
    { key = "X05:BloodwarderFlcnr", text = "Bloodwarder Falconer yells" },
    { key = "X05:Ordinary",         text = "Ordinary yells" },
    { key = "X05:DGUnderbog01",     text = "Underbog Lurker" },
    { key = "X05:DGUnderbog02",     text = "Bog Giant" },
    { key = "X05:DGUnderbog03",     text = "Wrathfin Warrior" },
    { key = "X05:DGUnderbog04",     text = "Murkblood" },
    { key = "X05:DGShatteredHand",  text = "Shattered Hand" },
    { key = "X05:DGShadowmoonAdpt", text = "Shadowmoon Adept" },
    { key = "X05:DGShadowmoonChnl", text = "Shadowmoon Channeler" },
    { key = "X05:DGShadowmnTechn",  text = "Shadowmoon Technician" },
    { key = "X05:PBNarrok",         text = "Narrok says" },
    { key = "X05:EtherealCrptRadr", text = "Ethereal Crypt Raider becomes enraged" },
--  01  Eastern Kingdoms
    { key = "X01:JaneyAnship",      text = "Janey Anship says" },
    { key = "X01:LisanPierce",      text = "Lisan Pierce says" },
    { key = "X01:PBDeizaPlaguehrn", text = "Deiza Plaguehorn says" },
    { key = "X01:PBDDarkhammer",    text = "Durin Darkhammer says" },
    { key = "X01:PBEricDavidson",   text = "Eric Davidson says" },
    { key = "X01:PBKDarkhammer",    text = "Kortas Darkhammer says" },
    { key = "X01:PBStevenLisbane",  text = "Steven Lisbane says" },
    { key = "X01:Suzanne",          text = "Suzanne says" },
    { key = "X01:Channel",          text = "Changed Channel" },
--  00  Event 
    { key = "DMF:PBJeremy",         text = "Jeremy Feasel says" },
    { key = "DMF:PBChristoph",      text = "Christoph VonFeasel says" },
    { key = "DMF:Morja",            text = "Morja says" },
--  Addon
    { key = "ANG:Awake",            text = "Is awake. To temporarily disable" },
    { key = "ANG:Config",           text = "To access the configuration menu," },
    { key = "ANG:Thank",            text = "Thank you for using Angleur" },
    { key = "ANG:Visual",           text = "the Visual Button." },
    { key = "CRM:CurrentRealm2",    text = "Connected Realm:" },
    { key = "DJK:NoJunk",           text = "No junk items to destroy" },
    { key = "ELV:LuaError",         text = "ElvUI: Lua error recieved." },
    { key = "FGO:125466",           text = "125466" },
    { key = "ERG:RecGearCmbt",      text = "Cannot recommend gear while in combat" },
    { key = "ERG:RecGearCmbt",      text = "Cannot recommend gear while in combat" },
    { key = "GMT:0Upgrades",        text = "0 upgrade(s)" },
    { key = "GMT:NoUpgrades",       text = "no upgrades to equip" },
    { key = "SLH:LootBindAprv",     text = "Auto Approved Loot Bind" },
    { key = "SLH:LootBindNTrf",     text = "Auto Approved Performing this action" },
    { key = "SLH:LUAErrors",        text = "Auto Approved Ignoring Too Many Lua Errors" },
    { key = "VMB:Version",          text = "Vamoose's Endeavors v" },
    { key = "VND:WindowNotOpen",    text = "Merchant window is not open." },
    { key = "XAN:Loaded",           text = "] loaded" },
    { key = "ZYG:ActvGuide",        text = "Activated guide:" },
    { key = "ZYG:GoldGuide",        text = "Gold Guide:" },
    { key = "ZYG:GuidesLoad",       text = "guides are loaded" },
--  Blizzard
    { key = "BLZ:Discovery",        text = "You have made a new discovery" },
    { key = "BLZ:FindPlayer",       text = "Cannot find player" },
    { key = "BLZ:Finesse",          text = "Your Finesse helps you gather something extra" },
    { key = "BLZ:HouseXP",          text = "House XP increased" },
    { key = "BLZ:LootSpecSetTo",    text = "Loot Specialization set to" },
    { key = "BLZ:NLAway",           text = "You are no longer Away" },
    { key = "BLZ:NLRested",         text = "You are no longer Rested" },
    { key = "BLZ:Responsibly",      text = "Remember to act responsibly, protect" },
    { key = "BLZ:RServicesDC",      text = "Blizzard services" },

}

LI.AddonLinkAliases = fr0z3nUI_LootIt_AddonAliases
fr0z3nUI_LootIt_AddonIgnoredItemIDs = addonIgnoredItemIDs
LI.AddonIgnoredItemIDs = addonIgnoredItemIDs
LI.AddonCurrencyAliases = fr0z3nUI_LootIt_AddonCurrencyAliases
LI.AddonSuppressSeeds = fr0z3nUI_LootIt_AddonSuppressSeeds



--    { item = 163497,  note = "Wicker Pup" },

