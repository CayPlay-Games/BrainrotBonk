--[[
	DailyRewardService.lua

	Description:
		Handles daily reward claims and distributes rewards.
		Players can claim one reward per day with a 24-hour cooldown.
		After Day 7, the cycle resets to Day 1 and a new Day 7 skin is put on the track.
--]]

-- Root --
local DailyRewardService = {}

-- Roblox Services --

-- Dependencies --
local DataStream = shared("DataStream")
local DailyRewardConfig = shared("DailyRewardConfig")
local SkinsConfig = shared("SkinsConfig")
local CollectionsService = shared("CollectionsService")
local GetRemoteEvent = shared("GetRemoteEvent")
local GetRemoteFunction = shared("GetRemoteFunction")

-- Remote Events/Functions --
local GetDailyRewardStatusRemote = GetRemoteFunction("GetDailyRewardStatus")
local ClaimDailyRewardRemote = GetRemoteEvent("ClaimDailyReward")
local DailyRewardClaimedRemote = GetRemoteEvent("DailyRewardClaimed")

-- Constants --
local TOTAL_DAYS = 7

-- Internal Functions --

-- Gets the Day 7 skin for a given cycle
local function GetDay7Skin(cycleCount)
	local skins = DailyRewardConfig.Day7Skins
	local skinCount = #skins

	if skinCount == 0 then
		return nil, nil
	end

	-- Wrap cycle count to available skins
	local skinIndex = ((cycleCount - 1) % skinCount) + 1
	local skinData = skins[skinIndex]

	return skinData.SkinId, skinData.Mutation
end

-- Awards a skin to the player using Collections
local function AwardSkin(player, skinId, mutation)
	mutation = mutation or "Normal"

	-- Check if skin exists in config
	if not SkinsConfig.Skins[skinId] then
		warn("[DailyRewardService] Skin not found in config:", skinId)
		return false
	end

	-- Check if mutation exists in config
	if not SkinsConfig.Mutations[mutation] then
		warn("[DailyRewardService] Mutation not found in config:", mutation)
		mutation = "Normal"
	end

	local itemId = skinId .. "_" .. mutation
	local success = CollectionsService:GiveItem(player, "Skins", itemId, 1)
	if success then
		print("[DailyRewardService]", player.Name, "awarded skin:", skinId, "with mutation:", mutation)
	end
	return success
end

-- Calculates time remaining until next claim
local function GetTimeUntilClaim(lastClaimTime)
	if lastClaimTime == 0 then
		return 0 -- Never claimed, can claim now
	end

	local currentTime = os.time()
	local timeSinceClaim = currentTime - lastClaimTime
	local timeRemaining = DailyRewardConfig.CLAIM_COOLDOWN - timeSinceClaim

	return math.max(0, timeRemaining)
end

-- Checks if player can claim
local function CanClaim(player)
	local stored = DataStream.Stored[player]
	if not stored then
		return false
	end

	local dailyRewards = stored.DailyRewards
	local lastClaimTime = dailyRewards.LastClaimTime:Read() or 0

	return GetTimeUntilClaim(lastClaimTime) == 0
end

-- API Functions --

-- Returns the current reward status for a player
function DailyRewardService:GetRewardStatus(player)
	local stored = DataStream.Stored[player]
	if not stored then
		return nil
	end

	local dailyRewards = stored.DailyRewards
	local currentDay = dailyRewards.CurrentDay:Read() or 1
	local lastClaimTime = dailyRewards.LastClaimTime:Read() or 0
	local cycleCount = dailyRewards.CycleCount:Read() or 1

	local timeUntilClaim = GetTimeUntilClaim(lastClaimTime)
	local canClaim = timeUntilClaim == 0

	-- Get current cycle's Day 7 skin
	local day7SkinId, day7Mutation = GetDay7Skin(cycleCount)
	local day7SkinName = nil
	if day7SkinId and SkinsConfig.Skins[day7SkinId] then
		day7SkinName = SkinsConfig.Skins[day7SkinId].DisplayName
	end

	return {
		CurrentDay = currentDay,
		CanClaim = canClaim,
		TimeUntilClaim = timeUntilClaim,
		CycleCount = cycleCount,
		Day7SkinId = day7SkinId,
		Day7SkinName = day7SkinName,
		Day7Mutation = day7Mutation,
	}
end

-- Claims the current day's reward
function DailyRewardService:ClaimReward(player)
	local stored = DataStream.Stored[player]
	if not stored then
		return false, "Data not loaded"
	end

	-- Check cooldown
	if not CanClaim(player) then
		return false, "Cooldown not complete"
	end

	local dailyRewards = stored.DailyRewards
	local currentDay = dailyRewards.CurrentDay:Read() or 1
	local cycleCount = dailyRewards.CycleCount:Read() or 1

	-- Get reward for current day
	local rewardData = DailyRewardConfig.Days[currentDay]
	if not rewardData then
		return false, "Invalid day"
	end

	local rewardGiven = nil

	-- Award based on reward type
	if rewardData.Type == "Coins" then
		local success = CollectionsService:GiveCurrency(
			player,
			"Coins",
			rewardData.Amount,
			Enum.AnalyticsEconomyTransactionType.Gameplay.Name,
			"DailyReward_Day" .. currentDay
		)
		if success then
			rewardGiven = { Type = "Coins", Amount = rewardData.Amount }
			print("[DailyRewardService]", player.Name, "claimed Day", currentDay, "- Coins:", rewardData.Amount)
		end
	elseif rewardData.Type == "Spins" then
		local currentSpins = stored.Spins:Read() or 0
		stored.Spins = currentSpins + rewardData.Amount
		rewardGiven = { Type = "Spins", Amount = rewardData.Amount }
		print("[DailyRewardService]", player.Name, "claimed Day", currentDay, "- Spins:", rewardData.Amount)
	elseif rewardData.Type == "Skin" then
		-- Day 7 skin reward
		local skinId, mutation = GetDay7Skin(cycleCount)
		if skinId then
			AwardSkin(player, skinId, mutation)
			rewardGiven = { Type = "Skin", SkinId = skinId, Mutation = mutation }
			print("[DailyRewardService]", player.Name, "claimed Day 7 skin:", skinId, mutation)
		end
	end

	if not rewardGiven then
		return false, "Failed to award reward"
	end

	-- Update daily rewards data
	local nextDay = currentDay + 1
	local newCycleCount = cycleCount

	if nextDay > TOTAL_DAYS then
		-- Completed cycle, reset to day 1 and increment cycle
		nextDay = 1
		newCycleCount = cycleCount + 1
	end

	dailyRewards.CurrentDay = nextDay
	dailyRewards.LastClaimTime = os.time()
	dailyRewards.CycleCount = newCycleCount

	return true, rewardGiven
end

-- Initializers --
function DailyRewardService:Init()
	print("[DailyRewardService] Initializing...")

	-- Handle status requests
	GetDailyRewardStatusRemote.OnServerInvoke = function(player)
		return self:GetRewardStatus(player)
	end

	-- Handle claim requests
	ClaimDailyRewardRemote.OnServerEvent:Connect(function(player)
		local success, result = self:ClaimReward(player)

		-- Notify client of result
		DailyRewardClaimedRemote:FireClient(player, {
			Success = success,
			Reward = success and result or nil,
			Error = not success and result or nil,
			Status = self:GetRewardStatus(player),
		})
	end)

	print("[DailyRewardService] Ready")
end

-- Return Module --
return DailyRewardService
