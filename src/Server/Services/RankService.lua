--[[
	RankService.lua

	Description:
		Manages the rank progression system.
		Awards XP for game actions and gives rewards when players reach new ranks.
--]]

-- Root --
local RankService = {}

-- Roblox Services --

-- Dependencies --
local RankConfig = shared("RankConfig")
local RankHelper = shared("RankHelper")
local DataStream = shared("DataStream")
local RoundConfig = shared("RoundConfig")
local BadgeService = shared("BadgeService")
local CollectionsService = shared("CollectionsService")

-- Private Variables --

-- Internal Functions --

local function DebugLog(...)
	if RoundConfig.DEBUG_LOG_STATE_CHANGES then
		print("[RankService]", ...)
	end
end

-- Give a single reward to a player
local function GiveSingleReward(player, reward)
	local stored = DataStream.Stored[player]
	if not stored then return end

	if reward.Type == "Title" then
		local success = CollectionsService:GiveItem(player, "Titles", reward.Id, 1)
		if success then
			DebugLog(player.Name, "unlocked title:", reward.Id)
		end

	elseif reward.Type == "Currency" then
		local current = stored.Collections.Currencies.Coins:Read() or 0
		stored.Collections.Currencies.Coins = current + reward.Amount
		DebugLog(player.Name, "received", reward.Amount, "Coins")

	elseif reward.Type == "Skin" then
		local itemId = reward.Id .. "_Normal"
		local success = CollectionsService:GiveItem(player, "Skins", itemId, 1)
		if success then
			DebugLog(player.Name, "unlocked skin:", reward.Id)
		end

	elseif reward.Type == "Spins" then
		local current = stored.Spins:Read() or 0
		stored.Spins = current + reward.Amount
		DebugLog(player.Name, "received", reward.Amount, "Spins")

	elseif reward.Type == "Aura" then
		local unlocked = stored.Auras.Unlocked:Read() or {}
		if not table.find(unlocked, reward.Id) then
			table.insert(unlocked, reward.Id)
			stored.Auras.Unlocked = unlocked
			DebugLog(player.Name, "unlocked aura:", reward.Id)
		end
	end
end

-- Give rank reward (handles single and multiple rewards)
local function GiveRankReward(player, reward)
	if reward.Type == "Multiple" then
		for _, subReward in ipairs(reward.Rewards) do
			GiveSingleReward(player, subReward)
		end
	else
		GiveSingleReward(player, reward)
	end
end

-- API Functions --

-- Award XP to a player
function RankService:AwardXP(player, amount)
	local stored = DataStream.Stored[player]
	if not stored then return end

	-- Add XP
	local currentXP = stored.Rank.XP:Read() or 0
	local newXP = currentXP + amount
	stored.Rank.XP = newXP

	DebugLog(player.Name, "earned", amount, "Total:", newXP)

	-- Check for rank ups
	local newRank = RankHelper:CalculateRankFromXP(newXP)
	local lastRewarded = stored.Rank.LastRankRewarded:Read() or 0

	-- Give rewards for all newly achieved ranks
	if newRank > lastRewarded then
		for i = lastRewarded + 1, newRank do
			local rankData = RankConfig.Ranks[i]
			DebugLog(player.Name, "reached rank:", rankData.Name)
			GiveRankReward(player, rankData.Reward)
			BadgeService:CheckRankBadges(player, i)
		end

		-- Update last rewarded
		stored.Rank.LastRankRewarded = newRank
	end
end

-- Get player's current rank info
function RankService:GetPlayerRank(player)
	local stored = DataStream.Stored[player]
	if not stored then
		return { Index = 0, Name = "Unranked", XP = 0 }
	end

	local xp = stored.Rank.XP:Read() or 0
	local rankIndex = RankHelper:CalculateRankFromXP(xp)

	return {
		Index = rankIndex,
		Name = rankIndex > 0 and RankConfig.Ranks[rankIndex].Name or "Unranked",
		XP = xp,
	}
end

-- Get XP needed for next rank
function RankService:GetXPForNextRank(player)
	local stored = DataStream.Stored[player]
	if not stored then return nil end

	local xp = stored.Rank.XP:Read() or 0
	local currentRank = RankHelper:CalculateRankFromXP(xp)

	if currentRank >= #RankConfig.Ranks then
		return nil -- Already at max rank
	end

	return RankConfig.Ranks[currentRank + 1].XPRequired
end

-- Initializers --
function RankService:Init()
	DebugLog("Initializing...")

	-- Validate player rewards on join (in case of missed rewards)
	DataStream.PlayerStreamAdded:Connect(function(schemaName, player)
		if schemaName == "Stored" then
			task.defer(function()
				local stored = DataStream.Stored[player]
				if not stored then return end

				local xp = stored.Rank.XP:Read() or 0
				local currentRank = RankHelper:CalculateRankFromXP(xp)
				local lastRewarded = stored.Rank.LastRankRewarded:Read() or 0

				-- Give any missed rewards
				if currentRank > lastRewarded then
					DebugLog(player.Name, "catching up on", currentRank - lastRewarded, "missed rank rewards")
					for i = lastRewarded + 1, currentRank do
						local rankData = RankConfig.Ranks[i]
						GiveRankReward(player, rankData.Reward)
						BadgeService:CheckRankBadges(player, i)
					end
					stored.Rank.LastRankRewarded = currentRank
				end
			end)
		end
	end)

	DebugLog("Initialized")
end

-- Return Module --
return RankService
