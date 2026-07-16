---@diagnostic disable: undefined-global

local addonName, ns = ...
if type(ns) ~= "table" then
    ns = {}
end

-- ===== Great Vault LDB (progress lanes: Raid | Dungeon | World) =====
do
    ns.SwitchesLDB = ns.SwitchesLDB or {}
    local LDBMod = ns.SwitchesLDB
    local private = {}

    private.UpgradeTable = {
        -- Season 30
        ["12265"] = {Track = "Explorer", Rank = 1, MaxRank = 8, Ilvl = 98, MaxIlvl = 105},
        ["12266"] = {Track = "Explorer", Rank = 2, MaxRank = 8, Ilvl = 99, MaxIlvl = 105},
        ["12267"] = {Track = "Explorer", Rank = 3, MaxRank = 8, Ilvl = 100, MaxIlvl = 105},
        ["12268"] = {Track = "Explorer", Rank = 4, MaxRank = 8, Ilvl = 101, MaxIlvl = 105},
        ["12269"] = {Track = "Explorer", Rank = 5, MaxRank = 8, Ilvl = 102, MaxIlvl = 105},
        ["12270"] = {Track = "Explorer", Rank = 6, MaxRank = 8, Ilvl = 103, MaxIlvl = 105},
        ["12271"] = {Track = "Explorer", Rank = 7, MaxRank = 8, Ilvl = 104, MaxIlvl = 105},
        ["12272"] = {Track = "Explorer", Rank = 8, MaxRank = 8, Ilvl = 105, MaxIlvl = 105},

        ["12274"] = {Track = "Adventurer", Rank = 1, MaxRank = 8, Ilvl = 102, MaxIlvl = 118},
        ["12275"] = {Track = "Adventurer", Rank = 2, MaxRank = 8, Ilvl = 103, MaxIlvl = 118},
        ["12276"] = {Track = "Adventurer", Rank = 3, MaxRank = 8, Ilvl = 104, MaxIlvl = 118},
        ["12277"] = {Track = "Adventurer", Rank = 4, MaxRank = 8, Ilvl = 105, MaxIlvl = 118},
        ["12278"] = {Track = "Adventurer", Rank = 5, MaxRank = 8, Ilvl = 108, MaxIlvl = 118},
        ["12279"] = {Track = "Adventurer", Rank = 6, MaxRank = 8, Ilvl = 111, MaxIlvl = 118},
        ["12280"] = {Track = "Adventurer", Rank = 7, MaxRank = 8, Ilvl = 115, MaxIlvl = 118},
        ["12281"] = {Track = "Adventurer", Rank = 8, MaxRank = 8, Ilvl = 118, MaxIlvl = 118},

        ["12282"] = {Track = "Veteran", Rank = 1, MaxRank = 8, Ilvl = 108, MaxIlvl = 131},
        ["12283"] = {Track = "Veteran", Rank = 2, MaxRank = 8, Ilvl = 111, MaxIlvl = 131},
        ["12284"] = {Track = "Veteran", Rank = 3, MaxRank = 8, Ilvl = 115, MaxIlvl = 131},
        ["12285"] = {Track = "Veteran", Rank = 4, MaxRank = 8, Ilvl = 118, MaxIlvl = 131},
        ["12286"] = {Track = "Veteran", Rank = 5, MaxRank = 8, Ilvl = 121, MaxIlvl = 131},
        ["12287"] = {Track = "Veteran", Rank = 6, MaxRank = 8, Ilvl = 124, MaxIlvl = 131},
        ["12288"] = {Track = "Veteran", Rank = 7, MaxRank = 8, Ilvl = 128, MaxIlvl = 131},
        ["12289"] = {Track = "Veteran", Rank = 8, MaxRank = 8, Ilvl = 131, MaxIlvl = 131},

        ["12290"] = {Track = "Champion", Rank = 1, MaxRank = 8, Ilvl = 121, MaxIlvl = 144},
        ["12291"] = {Track = "Champion", Rank = 2, MaxRank = 8, Ilvl = 124, MaxIlvl = 144},
        ["12292"] = {Track = "Champion", Rank = 3, MaxRank = 8, Ilvl = 128, MaxIlvl = 144},
        ["12293"] = {Track = "Champion", Rank = 4, MaxRank = 8, Ilvl = 131, MaxIlvl = 144},
        ["12294"] = {Track = "Champion", Rank = 5, MaxRank = 8, Ilvl = 134, MaxIlvl = 144},
        ["12295"] = {Track = "Champion", Rank = 6, MaxRank = 8, Ilvl = 137, MaxIlvl = 144},
        ["12296"] = {Track = "Champion", Rank = 7, MaxRank = 8, Ilvl = 141, MaxIlvl = 144},
        ["12297"] = {Track = "Champion", Rank = 8, MaxRank = 8, Ilvl = 144, MaxIlvl = 144},

        ["12350"] = {Track = "Hero", Rank = 1, MaxRank = 8, Ilvl = 134, MaxIlvl = 157},
        ["12351"] = {Track = "Hero", Rank = 2, MaxRank = 8, Ilvl = 137, MaxIlvl = 157},
        ["12352"] = {Track = "Hero", Rank = 3, MaxRank = 8, Ilvl = 141, MaxIlvl = 157},
        ["12353"] = {Track = "Hero", Rank = 4, MaxRank = 8, Ilvl = 144, MaxIlvl = 157},
        ["12354"] = {Track = "Hero", Rank = 5, MaxRank = 8, Ilvl = 147, MaxIlvl = 157},
        ["12355"] = {Track = "Hero", Rank = 6, MaxRank = 8, Ilvl = 150, MaxIlvl = 157},
        ["13443"] = {Track = "Hero", Rank = 7, MaxRank = 8, Ilvl = 154, MaxIlvl = 157},
        ["13444"] = {Track = "Hero", Rank = 8, MaxRank = 8, Ilvl = 157, MaxIlvl = 157},

        ["12356"] = {Track = "Myth", Rank = 1, MaxRank = 8, Ilvl = 147, MaxIlvl = 170},
        ["12357"] = {Track = "Myth", Rank = 2, MaxRank = 8, Ilvl = 150, MaxIlvl = 170},
        ["12358"] = {Track = "Myth", Rank = 3, MaxRank = 8, Ilvl = 154, MaxIlvl = 170},
        ["12359"] = {Track = "Myth", Rank = 4, MaxRank = 8, Ilvl = 157, MaxIlvl = 170},
        ["12360"] = {Track = "Myth", Rank = 5, MaxRank = 8, Ilvl = 160, MaxIlvl = 170},
        ["12361"] = {Track = "Myth", Rank = 6, MaxRank = 8, Ilvl = 163, MaxIlvl = 170},
        ["13445"] = {Track = "Myth", Rank = 7, MaxRank = 8, Ilvl = 167, MaxIlvl = 170},
        ["13446"] = {Track = "Myth", Rank = 8, MaxRank = 8, Ilvl = 170, MaxIlvl = 170},

        -- Season 34
        ["12704"] = {Track = "Explorer", Rank = 1, MaxRank = 8, Ilvl = 245, MaxIlvl = 268},
        ["12762"] = {Track = "Explorer", Rank = 2, MaxRank = 8, Ilvl = 248, MaxIlvl = 268},
        ["12763"] = {Track = "Explorer", Rank = 3, MaxRank = 8, Ilvl = 252, MaxIlvl = 268},
        ["12764"] = {Track = "Explorer", Rank = 4, MaxRank = 8, Ilvl = 255, MaxIlvl = 268},
        ["12765"] = {Track = "Explorer", Rank = 5, MaxRank = 8, Ilvl = 258, MaxIlvl = 268},
        ["12766"] = {Track = "Explorer", Rank = 6, MaxRank = 8, Ilvl = 261, MaxIlvl = 268},
        ["12767"] = {Track = "Explorer", Rank = 7, MaxRank = 8, Ilvl = 265, MaxIlvl = 268},
        ["12768"] = {Track = "Explorer", Rank = 8, MaxRank = 8, Ilvl = 268, MaxIlvl = 268},

        ["12769"] = {Track = "Adventurer", Rank = 1, MaxRank = 6, Ilvl = 220, MaxIlvl = 237},
        ["12770"] = {Track = "Adventurer", Rank = 2, MaxRank = 6, Ilvl = 224, MaxIlvl = 237},
        ["12771"] = {Track = "Adventurer", Rank = 3, MaxRank = 6, Ilvl = 227, MaxIlvl = 237},
        ["12772"] = {Track = "Adventurer", Rank = 4, MaxRank = 6, Ilvl = 230, MaxIlvl = 237},
        ["12773"] = {Track = "Adventurer", Rank = 5, MaxRank = 6, Ilvl = 233, MaxIlvl = 237},
        ["12774"] = {Track = "Adventurer", Rank = 6, MaxRank = 6, Ilvl = 237, MaxIlvl = 237},

        ["12777"] = {Track = "Veteran", Rank = 1, MaxRank = 6, Ilvl = 233, MaxIlvl = 250},
        ["12778"] = {Track = "Veteran", Rank = 2, MaxRank = 6, Ilvl = 237, MaxIlvl = 250},
        ["12779"] = {Track = "Veteran", Rank = 3, MaxRank = 6, Ilvl = 240, MaxIlvl = 250},
        ["12780"] = {Track = "Veteran", Rank = 4, MaxRank = 6, Ilvl = 243, MaxIlvl = 250},
        ["12781"] = {Track = "Veteran", Rank = 5, MaxRank = 6, Ilvl = 246, MaxIlvl = 250},
        ["12782"] = {Track = "Veteran", Rank = 6, MaxRank = 6, Ilvl = 250, MaxIlvl = 250},

        ["12785"] = {Track = "Champion", Rank = 1, MaxRank = 6, Ilvl = 246, MaxIlvl = 263},
        ["12786"] = {Track = "Champion", Rank = 2, MaxRank = 6, Ilvl = 250, MaxIlvl = 263},
        ["12787"] = {Track = "Champion", Rank = 3, MaxRank = 6, Ilvl = 253, MaxIlvl = 263},
        ["12788"] = {Track = "Champion", Rank = 4, MaxRank = 6, Ilvl = 256, MaxIlvl = 263},
        ["12789"] = {Track = "Champion", Rank = 5, MaxRank = 6, Ilvl = 259, MaxIlvl = 263},
        ["12790"] = {Track = "Champion", Rank = 6, MaxRank = 6, Ilvl = 263, MaxIlvl = 263},

        ["12793"] = {Track = "Hero", Rank = 1, MaxRank = 6, Ilvl = 259, MaxIlvl = 276},
        ["12794"] = {Track = "Hero", Rank = 2, MaxRank = 6, Ilvl = 263, MaxIlvl = 276},
        ["12795"] = {Track = "Hero", Rank = 3, MaxRank = 6, Ilvl = 266, MaxIlvl = 276},
        ["12796"] = {Track = "Hero", Rank = 4, MaxRank = 6, Ilvl = 269, MaxIlvl = 276},
        ["12797"] = {Track = "Hero", Rank = 5, MaxRank = 6, Ilvl = 272, MaxIlvl = 276},
        ["12798"] = {Track = "Hero", Rank = 6, MaxRank = 6, Ilvl = 276, MaxIlvl = 276},

        ["12801"] = {Track = "Myth", Rank = 1, MaxRank = 6, Ilvl = 272, MaxIlvl = 289},
        ["12802"] = {Track = "Myth", Rank = 2, MaxRank = 6, Ilvl = 276, MaxIlvl = 289},
        ["12803"] = {Track = "Myth", Rank = 3, MaxRank = 6, Ilvl = 279, MaxIlvl = 289},
        ["12804"] = {Track = "Myth", Rank = 4, MaxRank = 6, Ilvl = 282, MaxIlvl = 289},
        ["12805"] = {Track = "Myth", Rank = 5, MaxRank = 6, Ilvl = 285, MaxIlvl = 289},
        ["12806"] = {Track = "Myth", Rank = 6, MaxRank = 6, Ilvl = 289, MaxIlvl = 289},
    }

    function private.StringSplit(str, sep)
        if sep == nil then
            sep = "%s"
        end
        if str == nil then
            return nil
        end
        str = str .. sep
        local pattern = ".-" .. sep
        local t = {}
        for match in string.gmatch(str, pattern) do
            match = string.gsub(match, sep, "")
            table.insert(t, match)
        end
        return t
    end

    function private.GetItemString(itemLink)
        if type(itemLink) ~= "string" then
            return nil
        end
        return select(3, strfind(itemLink, "|H(.+)|h"))
    end

    function private.GetBonusIds(itemLink)
        local numBonusIndex = 14
        local bonusIndex = 15

        local bonusIds = {}
        local itemString = private.GetItemString(itemLink)
        local split = private.StringSplit(itemString, ":")
        if not split then
            return bonusIds
        end

        local numBonus = tonumber(split[numBonusIndex]) or 0
        for i = bonusIndex, (bonusIndex + numBonus - 1) do
            table.insert(bonusIds, tostring(split[i]))
        end

        return bonusIds
    end

    function private.GetUpgradeInfo(itemLink)
        local bonusIds = private.GetBonusIds(itemLink)
        for _, bonusId in ipairs(bonusIds) do
            if private.UpgradeTable[bonusId] ~= nil then
                return private.UpgradeTable[bonusId]
            end
        end
        return nil
    end

    local function EnsureWeeklyRewardsLoaded()
        if type(C_WeeklyRewards) == "table" then
            return true
        end

        local ok = false
        if C_AddOns and type(C_AddOns.LoadAddOn) == "function" then
            ok = pcall(C_AddOns.LoadAddOn, "Blizzard_WeeklyRewards")
        elseif type(LoadAddOn) == "function" then
            ok = pcall(LoadAddOn, "Blizzard_WeeklyRewards")
        end

        return ok and type(C_WeeklyRewards) == "table"
    end

    local function ClampProgress(progress, threshold)
        progress = tonumber(progress) or 0
        threshold = tonumber(threshold) or 0
        if progress < 0 then progress = 0 end
        if threshold < 0 then threshold = 0 end
        if threshold > 0 and progress > threshold then
            progress = threshold
        end
        return progress, threshold
    end

    local function TierSortFunc(a, b)
        return (tonumber(a and a.index) or 0) < (tonumber(b and b.index) or 0)
    end

    local function CopyAndSortActivities(activities)
        local out = {}
        if type(activities) ~= "table" then
            return out
        end
        for i = 1, #activities do
            local row = activities[i]
            if type(row) == "table" then
                out[#out + 1] = row
            end
        end
        table.sort(out, TierSortFunc)
        return out
    end

    local function GetTierColorHex(activeTier, isFullyComplete)
        if isFullyComplete then
            return "ffb266ff" -- purple
        end
        if activeTier == 2 then
            return "ff00ff00" -- green
        end
        if activeTier == 3 then
            return "ff3399ff" -- blue
        end
        return "ffffffff" -- white/default
    end

    local function ComputeLanePair(activities)
        local tiers = CopyAndSortActivities(activities)
        if #tiers == 0 then
            return "-/-", "ff7f7f7f"
        end

        local completed = 0
        for i = 1, #tiers do
            local p, t = ClampProgress(tiers[i].progress, tiers[i].threshold)
            if t > 0 and p >= t then
                completed = completed + 1
            else
                break
            end
        end

        local activeTier = completed + 1
        if activeTier > #tiers then
            activeTier = #tiers
        end

        local active = tiers[activeTier]
        local p, t = ClampProgress(active and active.progress, active and active.threshold)
        local fullyComplete = (completed >= #tiers)

        if fullyComplete and t > 0 then
            p = t
        end

        return string.format("%d/%d", p, t), GetTierColorHex(activeTier, fullyComplete)
    end

    local function GetProgressText()
        if not EnsureWeeklyRewardsLoaded() then
            return "-/- | -/- | -/-"
        end

        local raid = C_WeeklyRewards.GetActivities and C_WeeklyRewards.GetActivities(Enum.WeeklyRewardChestThresholdType.Raid) or nil
        local dng = C_WeeklyRewards.GetActivities and C_WeeklyRewards.GetActivities(Enum.WeeklyRewardChestThresholdType.Activities) or nil
        local world = C_WeeklyRewards.GetActivities and C_WeeklyRewards.GetActivities(Enum.WeeklyRewardChestThresholdType.World) or nil

        local raidPair, raidColor = ComputeLanePair(raid)
        local dngPair, dngColor = ComputeLanePair(dng)
        local worldPair, worldColor = ComputeLanePair(world)

        return string.format("|c%s%s|r | |c%s%s|r | |c%s%s|r", raidColor, raidPair, dngColor, dngPair, worldColor, worldPair)
    end

    local function AddGvLines(tooltip, rewardTable)
        local threshold, progress, level
        local link, upgradeLink, ilvl, difficultyText
        local r, g, b

        table.sort(rewardTable, TierSortFunc)

        for tier, tierTable in ipairs(rewardTable) do
            threshold = tierTable.threshold
            progress = tierTable.progress
            level = tierTable.level
            progress = math.min(progress, threshold)

            link, upgradeLink = C_WeeklyRewards.GetExampleRewardItemHyperlinks(tierTable.id)

            local ilvlString = ""
            local upgradeInfo = private.GetUpgradeInfo(link)
            if upgradeInfo then
                ilvlString = string.format("%s %s/%s, %s->%s", upgradeInfo.Track, upgradeInfo.Rank, upgradeInfo.MaxRank, upgradeInfo.Ilvl, upgradeInfo.MaxIlvl)
            else
                ilvl = C_Item.GetDetailedItemLevelInfo(link)
                if ilvl then
                    ilvlString = string.format("Item Level %d", ilvl)
                else
                    ilvlString = "N/A"
                end
            end

            if progress == threshold then
                r, g, b = 0, 1, 0
            else
                r, g, b = 1, 1, 1
            end

            if tierTable.type == Enum.WeeklyRewardChestThresholdType.Raid then
                difficultyText = DifficultyUtil.GetDifficultyName(level)
                if not difficultyText then
                    difficultyText = "None"
                end
            elseif tierTable.type == Enum.WeeklyRewardChestThresholdType.Activities then
                local difficultyID = C_WeeklyRewards.GetDifficultyIDForActivityTier(tierTable.activityTierID)
                if difficultyID == DifficultyUtil.ID.DungeonHeroic then
                    difficultyText = "Heroic"
                else
                    difficultyText = string.format("+%d", level)
                end
            elseif tierTable.type == Enum.WeeklyRewardChestThresholdType.World then
                difficultyText = GREAT_VAULT_WORLD_TIER:format(level)
            elseif tierTable.type == Enum.WeeklyRewardChestThresholdType.RankedPvP then
                difficultyText = PVPUtil.GetTierName(level)
            end

            if not difficultyText then
                difficultyText = "???"
            end

            local leftText = string.format("Tier %d: %2d/%d", tier, progress, threshold)
            local rightText = string.format("%s (%s)", ilvlString, difficultyText)
            tooltip:AddDoubleLine(leftText, rightText, r, g, b, r, g, b)
        end
    end

    local function AddActivityHistory(tooltip, activityType, label, maxToShow)
        local levels = {}
        local activityProgress = C_WeeklyRewards.GetSortedProgressForActivity(activityType, true)
        for _, progress in ipairs(activityProgress) do
            for i = 1, progress.numPoints do
                table.insert(levels, progress.difficulty)
            end
        end
        local numToShow = math.min(maxToShow, #levels)
        local progStr = table.concat(levels, ", ", 1, numToShow)
        progStr = string.format("%d %s: %s", #levels, label, progStr)
        tooltip:AddLine(progStr, 1, 1, 1)
    end

    local function OnTooltipShow(tooltip)
        tooltip:AddLine("Great Vault")
        tooltip:AddLine(" ")

        local raid = C_WeeklyRewards.GetActivities(Enum.WeeklyRewardChestThresholdType.Raid)
        tooltip:AddLine("Raids")
        AddGvLines(tooltip, raid)
        tooltip:AddLine(" ")

        local dungeons = C_WeeklyRewards.GetActivities(Enum.WeeklyRewardChestThresholdType.Activities)
        tooltip:AddLine("Dungeons")
        AddGvLines(tooltip, dungeons)
        AddActivityHistory(tooltip, Enum.WeeklyRewardChestThresholdType.Activities, "Completed Keys", 8)
        tooltip:AddLine(" ")

        local world = C_WeeklyRewards.GetActivities(Enum.WeeklyRewardChestThresholdType.World)
        if #world > 0 then
            tooltip:AddLine("World")
            AddGvLines(tooltip, world)
            AddActivityHistory(tooltip, Enum.WeeklyRewardChestThresholdType.World, "World Events", 8)
            tooltip:AddLine(" ")
        end
    end

    local function ToggleVaultFrame()
        if not EnsureWeeklyRewardsLoaded() then
            return
        end

        local frame = _G and _G["WeeklyRewardsFrame"]
        if not frame then
            return
        end

        if frame.IsShown and frame:IsShown() then
            if HideUIPanel then
                HideUIPanel(frame)
            elseif frame.Hide then
                frame:Hide()
            end
        else
            if ShowUIPanel then
                ShowUIPanel(frame)
            elseif frame.Show then
                frame:Show()
            end
        end
    end

    function LDBMod.RefreshGreatVaultLDB()
        if type(LDBMod.GreatVaultLDB) == "table" then
            LDBMod.GreatVaultLDB.text = GetProgressText()
        end
    end

    local function EnsureLDB()
        if type(LDBMod.GreatVaultLDB) == "table" then
            return LDBMod.GreatVaultLDB
        end
        if type(LibStub) ~= "table" then
            return nil
        end

        local ok, ldb = pcall(function()
            return LibStub:GetLibrary("LibDataBroker-1.1")
        end)
        if not ok or type(ldb) ~= "table" then
            return nil
        end

        LDBMod.GreatVaultLDB = ldb:NewDataObject("FGO GreatVault", {
            type = "data source",
            text = GetProgressText(),
            icon = "Interface\\Icons\\Inv_misc_treasurechest04d",
            label = "Great Vault Progress",
            title = "Great Vault Progress",
            OnClick = function(_, button)
                if button == "LeftButton" then
                    ToggleVaultFrame()
                end
            end,
            OnTooltipShow = OnTooltipShow,
        })

        return LDBMod.GreatVaultLDB
    end

    local function QueueRefresh(delaySec)
        if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
            C_Timer.After(delaySec or 0, function()
                LDBMod.RefreshGreatVaultLDB()
            end)
        else
            LDBMod.RefreshGreatVaultLDB()
        end
    end

    local function OnEvent(_, event)
        if event == "PLAYER_LOGIN" then
            EnsureLDB()
            QueueRefresh(0)
            return
        end

        if event == "PLAYER_ENTERING_WORLD" then
            QueueRefresh(0.5)
            return
        end

        if event == "WEEKLY_REWARDS_UPDATE" then
            QueueRefresh(0)
            return
        end

        if event == "CHALLENGE_MODE_COMPLETED" or event == "QUEST_TURNED_IN" then
            QueueRefresh(0.25)
        end
    end

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_LOGIN")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("WEEKLY_REWARDS_UPDATE")
    frame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
    frame:RegisterEvent("QUEST_TURNED_IN")
    frame:SetScript("OnEvent", OnEvent)
end
