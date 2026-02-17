--[[
	PrizeWheelService.lua

	Description:
		Handles prize wheel spins, daily free spin grants, progressive rewards,
		and purchase grants for additional spins.
--]]

-- Root --
local PrizeWheelService = {}

-- Dependencies --
local DataStream = shared("DataStream")
local DataService = shared("DataService")
local PrizeWheelConfig = shared("PrizeWheelConfig")
local SkinsConfig = shared("SkinsConfig")
local CollectionsService = shared("CollectionsService")
local MonetizationService = shared("MonetizationService")
local MonetizationProducts = shared("MonetizationProducts")
local GetRemoteFunction = shared("GetRemoteFunction")
local PlayerAddedHelper = shared("PlayerAddedHelper")

-- Remote Functions --
local GetPrizeWheelStatusRemote = GetRemoteFunction("GetPrizeWheelStatus")
local RequestPrizeWheelSpinRemote = GetRemoteFunction("RequestPrizeWheelSpin")

-- Constants --
local FREE_SPIN_COOLDOWN_SECONDS = 60 * 10
local BUY_ONE_SPIN_SKU = "PrizeWheelSpin1"
local BUY_FIVE_SPINS_SKU = "PrizeWheelSpin5"

-- Private Variables --
local _Prizes = PrizeWheelConfig.Prizes or {}
local _ProgressivePrizes = PrizeWheelConfig.ProgressivePrizes or {}
local _ProgressiveVersion = PrizeWheelConfig.ProgressiveVersion or 1

local _TotalChance = 0
local _CumulativeChance = {}
local _RewardRng = Random.new()

-- Internal Functions --
local function EnsurePrizeWheelData(stored)
	if not stored.PrizeWheel then
		stored.PrizeWheel = {
			LastSpin = 0,
			ProgressiveTier = 1,
			ProgressiveSpins = 0,
			ProgressiveVersion = _ProgressiveVersion,
		}
	end

	local wheel = stored.PrizeWheel
	if wheel.LastSpin == nil then
		wheel.LastSpin = 0
	end
	if wheel.ProgressiveTier == nil then
		wheel.ProgressiveTier = 1
	end
	if wheel.ProgressiveSpins == nil then
		wheel.ProgressiveSpins = 0
	end
	if wheel.ProgressiveVersion == nil then
		wheel.ProgressiveVersion = _ProgressiveVersion
	end

	return wheel
end

local function NormalizeText(value)
	if type(value) ~= "string" then
		return ""
	end
	return string.lower((value:gsub("[%s%p_]+", "")))
end

local function ParseAmountFromDisplayName(displayName)
	if type(displayName) ~= "string" then
		return nil
	end

	local numberString = displayName:gsub("[^%d]", "")
	if numberString == "" then
		return nil
	end

	return tonumber(numberString)
end

local function ResolveCoinAmount(rewardConfig)
	if type(rewardConfig.Amount) == "number" then
		return rewardConfig.Amount
	end
	if type(rewardConfig.Coins) == "number" then
		return rewardConfig.Coins
	end

	return ParseAmountFromDisplayName(rewardConfig.DisplayName)
end

local function ResolveSkinId(rewardConfig)
	if type(rewardConfig.SkinId) == "string" then
		return rewardConfig.SkinId
	end
	if type(rewardConfig.Id) == "string" then
		return rewardConfig.Id
	end

	local normalizedRewardName = NormalizeText(rewardConfig.DisplayName)
	if normalizedRewardName == "" then
		return nil
	end

	for skinId, skinConfig in pairs(SkinsConfig.Skins) do
		if NormalizeText(skinId) == normalizedRewardName then
			return skinId
		end
		if skinConfig and NormalizeText(skinConfig.DisplayName) == normalizedRewardName then
			return skinId
		end
	end

	return nil
end

local function ResolveMutationId(rewardConfig)
	if type(rewardConfig.MutationId) == "string" and SkinsConfig.Mutations[rewardConfig.MutationId] then
		return rewardConfig.MutationId
	end
	if type(rewardConfig.Id) == "string" and SkinsConfig.Mutations[rewardConfig.Id] then
		return rewardConfig.Id
	end

	local normalized = NormalizeText(rewardConfig.DisplayName)
	if normalized == "" then
		return nil
	end

	for mutationId, mutationConfig in pairs(SkinsConfig.Mutations) do
		if NormalizeText(mutationId) == normalized then
			return mutationId
		end
		if mutationConfig and NormalizeText(mutationConfig.Name) == normalized then
			return mutationId
		end
	end

	if normalized:find("gold") then
		return "Golden"
	end

	return nil
end

local function EnsureSkinWithMutation(stored, skinId, mutationId)
	local collected = stored.Skins.Collected:Read() or {}
	local existingEntry = nil
	local existingIndex = nil

	for index, entry in ipairs(collected) do
		if entry.SkinId == skinId then
			existingEntry = entry
			existingIndex = index
			break
		end
	end

	if existingEntry then
		existingEntry.Mutations = existingEntry.Mutations or {}
		if table.find(existingEntry.Mutations, mutationId) == nil then
			table.insert(existingEntry.Mutations, mutationId)
			collected[existingIndex] = existingEntry
			stored.Skins.Collected = collected
			return true
		end
		return false
	end

	table.insert(collected, {
		SkinId = skinId,
		Mutations = { mutationId },
	})
	stored.Skins.Collected = collected
	return true
end

local function GrantMutationReward(player, rewardConfig)
	local stored = DataStream.Stored[player]
	if not stored then
		return false
	end

	local mutationId = ResolveMutationId(rewardConfig)
	if not mutationId or not SkinsConfig.Mutations[mutationId] then
		return false
	end

	local preferredSkinId = ResolveSkinId(rewardConfig)
	local collected = stored.Skins.Collected:Read() or {}

	if preferredSkinId and SkinsConfig.Skins[preferredSkinId] then
		if EnsureSkinWithMutation(stored, preferredSkinId, mutationId) then
			return true
		end
	end

	for _, entry in ipairs(collected) do
		if SkinsConfig.Skins[entry.SkinId] and EnsureSkinWithMutation(stored, entry.SkinId, mutationId) then
			return true
		end
	end

	local equippedSkin = stored.Skins.Equipped:Read() or SkinsConfig.DEFAULT_SKIN
	if SkinsConfig.Skins[equippedSkin] then
		return EnsureSkinWithMutation(stored, equippedSkin, mutationId)
	end

	return false
end

local function GrantReward(player, rewardConfig, sourceSku)
	if not rewardConfig then
		return false
	end

	local rewardType = rewardConfig.Type

	if rewardType == "Coins" then
		local amount = ResolveCoinAmount(rewardConfig)
		if not amount or amount <= 0 then
			return false
		end

		local success = CollectionsService:GiveCurrency(
			player,
			"Coins",
			amount,
			Enum.AnalyticsEconomyTransactionType.Gameplay.Name,
			sourceSku
		)
		return success == true
	end

	if rewardType == "Skin" then
		local skinId = ResolveSkinId(rewardConfig)
		if not skinId or not SkinsConfig.Skins[skinId] then
			return false
		end

		local stored = DataStream.Stored[player]
		if not stored then
			return false
		end

		return EnsureSkinWithMutation(stored, skinId, "Normal")
	end

	if rewardType == "Mutation" then
		return GrantMutationReward(player, rewardConfig)
	end

	return false
end

local function BuildStatus(player, now)
	local stored = DataStream.Stored[player]
	if not stored then
		return nil
	end

	local wheel = EnsurePrizeWheelData(stored)

	now = now or os.time()

	return {
		SpinsLeft = stored.Spins:Read() or 0,
		LastSpin = wheel.LastSpin:Read() or 0,
		ProgressiveTier = wheel.ProgressiveTier:Read() or 1,
		ProgressiveSpins = wheel.ProgressiveSpins:Read() or 0,
		Now = now,
	}
end

local function ResetProgressiveIfNeeded(wheelStream)
	local storedVersion = wheelStream.ProgressiveVersion:Read() or 0
	if storedVersion >= _ProgressiveVersion then
		return
	end

	wheelStream.ProgressiveTier = 1
	wheelStream.ProgressiveSpins = 0
	wheelStream.ProgressiveVersion = _ProgressiveVersion
end

local function GrantDailySpin(stored, wheelStream, now)
	local spinsLeft = stored.Spins:Read() or 0
	local lastSpin = wheelStream.LastSpin:Read() or 0

	if spinsLeft <= 0 and (now - lastSpin) >= FREE_SPIN_COOLDOWN_SECONDS then
		spinsLeft += 1
		stored.Spins = spinsLeft
	end

	return spinsLeft
end

local function RollStandardReward()
	if #_Prizes == 0 then
		return nil, nil
	end

	if _TotalChance <= 0 then
		local randomIndex = _RewardRng:NextInteger(1, #_Prizes)
		return randomIndex, _Prizes[randomIndex]
	end

	local roll = _RewardRng:NextNumber(0, _TotalChance)
	for index, reward in ipairs(_Prizes) do
		if roll <= _CumulativeChance[index] then
			return index, reward
		end
	end

	return #_Prizes, _Prizes[#_Prizes]
end

local function GetProgressiveReward(wheelStream)
	local totalTiers = #_ProgressivePrizes
	if totalTiers <= 0 then
		return nil
	end

	local tier = wheelStream.ProgressiveTier:Read() or 1
	tier = math.clamp(tier, 1, totalTiers)

	local tierData = _ProgressivePrizes[tier]
	local requiredSpins = tierData and tierData.RequiredSpins or 0
	if requiredSpins <= 0 then
		return nil
	end

	local progressiveSpins = wheelStream.ProgressiveSpins:Read() or 0
	progressiveSpins += 1

	if progressiveSpins >= requiredSpins then
		wheelStream.ProgressiveSpins = 0
		if tier < totalTiers then
			wheelStream.ProgressiveTier = tier + 1
		else
			wheelStream.ProgressiveTier = tier
		end
		return tierData
	end

	wheelStream.ProgressiveSpins = progressiveSpins
	wheelStream.ProgressiveTier = tier
	return nil
end

local function GetRewardIndexForAnimation(rewardConfig)
	if not rewardConfig or #_Prizes == 0 then
		return 1
	end

	for index, reward in ipairs(_Prizes) do
		if reward == rewardConfig then
			return index
		end
	end

	local targetName = NormalizeText(rewardConfig.DisplayName)
	for index, reward in ipairs(_Prizes) do
		if NormalizeText(reward.DisplayName) == targetName then
			return index
		end
	end

	return _RewardRng:NextInteger(1, #_Prizes)
end

local function ProcessPurchase(receiptInfo, player)
	local oneSpinConfig = MonetizationProducts:GetProductConfig(BUY_ONE_SPIN_SKU)
	local fiveSpinConfig = MonetizationProducts:GetProductConfig(BUY_FIVE_SPINS_SKU)

	local spinsToGrant = 0
	if oneSpinConfig and receiptInfo.ProductId == oneSpinConfig.DevProductId then
		spinsToGrant = 1
	elseif fiveSpinConfig and receiptInfo.ProductId == fiveSpinConfig.DevProductId then
		spinsToGrant = 5
	end

	if spinsToGrant <= 0 then
		return false
	end

	local stored = DataStream.Stored[player]
	if not stored then
		return false
	end

	local currentSpins = stored.Spins:Read() or 0
	stored.Spins = currentSpins + spinsToGrant
	return true
end

local function RequestSpin(player)
	local stored = DataStream.Stored[player]
	if not stored then
		return { Success = false, Error = "Data not loaded" }
	end

	local wheel = EnsurePrizeWheelData(stored)

	local now = os.time()

	ResetProgressiveIfNeeded(wheel)
	local spinsLeft = GrantDailySpin(stored, wheel, now)

	if spinsLeft <= 0 then
		return {
			Success = false,
			Error = "No spins left",
			Status = BuildStatus(player, now),
		}
	end

	stored.Spins = spinsLeft - 1
	wheel.LastSpin = now

	local rewardConfig = GetProgressiveReward(wheel)
	local isProgressive = rewardConfig ~= nil
	local rewardIndex = nil

	if not rewardConfig then
		rewardIndex, rewardConfig = RollStandardReward()
	end

	if not rewardConfig then
		stored.Spins = spinsLeft
		return { Success = false, Error = "No rewards configured", Status = BuildStatus(player, now) }
	end

	local sourceSku = isProgressive and "PrizeWheel_Progressive" or "PrizeWheel_Standard"
	local rewardGranted = GrantReward(player, rewardConfig, sourceSku)
	if not rewardGranted then
		stored.Spins = spinsLeft
		return {
			Success = false,
			Error = "Failed to grant reward",
			Status = BuildStatus(player, now),
		}
	end

	if rewardIndex == nil then
		rewardIndex = GetRewardIndexForAnimation(rewardConfig)
	end

	return {
		Success = true,
		RewardIndex = rewardIndex,
		RewardName = rewardConfig.DisplayName or "Reward",
		RewardData = rewardConfig,
		IsProgressive = isProgressive,
		Status = BuildStatus(player, now),
	}
end

-- API Functions --
function PrizeWheelService:GetStatus(player)
	local stored = DataStream.Stored[player]
	if not stored then
		return nil
	end

	local wheel = EnsurePrizeWheelData(stored)
	local now = os.time()
	ResetProgressiveIfNeeded(wheel)
	GrantDailySpin(stored, wheel, now)
	return BuildStatus(player, now)
end

-- Initializers --
function PrizeWheelService:Init()
	for index, reward in ipairs(_Prizes) do
		local chance = tonumber(reward.Chance) or 0
		if chance < 0 then
			chance = 0
		end

		_TotalChance += chance
		_CumulativeChance[index] = _TotalChance
	end

	local oneSpinConfig = MonetizationProducts:GetProductConfig(BUY_ONE_SPIN_SKU)
	if oneSpinConfig and type(oneSpinConfig.DevProductId) == "number" and oneSpinConfig.DevProductId > 0 then
		MonetizationService:RegisterPurchaseHandler(oneSpinConfig.DevProductId, ProcessPurchase)
	else
		warn("[PrizeWheelService] Missing or invalid DevProductId for SKU:", BUY_ONE_SPIN_SKU)
	end

	local fiveSpinConfig = MonetizationProducts:GetProductConfig(BUY_FIVE_SPINS_SKU)
	if fiveSpinConfig and type(fiveSpinConfig.DevProductId) == "number" and fiveSpinConfig.DevProductId > 0 then
		MonetizationService:RegisterPurchaseHandler(fiveSpinConfig.DevProductId, ProcessPurchase)
	else
		warn("[PrizeWheelService] Missing or invalid DevProductId for SKU:", BUY_FIVE_SPINS_SKU)
	end

	GetPrizeWheelStatusRemote.OnServerInvoke = function(player)
		return self:GetStatus(player)
	end

	RequestPrizeWheelSpinRemote.OnServerInvoke = function(player)
		return RequestSpin(player)
	end

	PlayerAddedHelper:OnPlayerAdded(function(player)
		DataService:OnPlayerDataLoaded(player, function()
			local stored = DataStream.Stored[player]
			if not stored then
				return
			end

			local wheel = EnsurePrizeWheelData(stored)
			ResetProgressiveIfNeeded(wheel)
			GrantDailySpin(stored, wheel, os.time())
		end)
	end)
end

-- Return Module --
return PrizeWheelService
