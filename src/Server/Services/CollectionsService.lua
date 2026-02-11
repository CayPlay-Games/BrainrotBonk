--[[
    CollectionsService.lua

    Description:
        No description provided.

--]]

-- Root --
local CollectionsService = {}

-- Roblox Services --
local AnalyticsService = game:GetService("AnalyticsService")

-- Dependencies --
local DataStream = shared("DataStream")
local Collections = shared("Collections")
local Promise = shared("Promise")

-- Object References --

-- Constants --

-- Private Variables --

-- Public Variables --

-- Internal Functions --

-- API Functions --
function CollectionsService:GiveItem(Player, CollectionId, ItemId, Amount, Options)
	Amount = Amount or 1
	Options = Options or {}

	local RequestPromise = Promise.new(function(Resolve, Reject)
		local IsCollectionIdValid = Collections:GetConfig(CollectionId)
		if IsCollectionIdValid == nil then
			return Reject(`{CollectionId} is not a valid collection id`)
		end

		local IsItemIdValid = Collections:GetItemConfig(CollectionId, ItemId)
		if IsItemIdValid == nil then
			return Reject(`{ItemId} is not a valid item id for collection {CollectionId}`)
		end

		if CollectionId == "Currencies" then
			return Reject("Use function 'GiveCurrency' instead.")
		end

		local PlayerDataStream = DataStream.Stored[Player]
		local PlayerCollectionsDataStream = PlayerDataStream.Collections

		--// Generic item
		local CurrentAmount = PlayerCollectionsDataStream[CollectionId][ItemId]:Read() or 0
		PlayerCollectionsDataStream[CollectionId][ItemId] = CurrentAmount + Amount

		return Resolve({
			ItemIndex = ItemId,
		})
	end)

	local Success, Response = RequestPromise:await()

	if Success ~= true then
		warn(Response)
	end

	return Success, Response
end

function CollectionsService:GetItemOwnedCount(Player, CollectionId, ItemId)
	local RequestPromise = Promise.new(function(Resolve, Reject)
		local IsCollectionIdValid = Collections:GetConfig(CollectionId)
		if IsCollectionIdValid == nil then
			return Reject(`{CollectionId} is not a valid collection id`)
		end

		local IsItemIdValid = Collections:GetItemConfig(CollectionId, ItemId)
		if IsItemIdValid == nil then
			return Reject(`{ItemId} is not a valid item id for collection {CollectionId}`)
		end

		local PlayerDataStream = DataStream.Stored[Player]
		local PlayerCollectionsDataStream = PlayerDataStream.Collections

		local ItemOwnedCount = PlayerCollectionsDataStream[CollectionId][ItemId]:Read() or 0

		return Resolve(ItemOwnedCount)
	end)

	local Success, Response = RequestPromise:await()

	if Success ~= true then
		warn(Response)
	end

	return Success, Response
end

function CollectionsService:RemoveItem(Player, CollectionId, ItemId, Amount)
	Amount = Amount or 1

	local RequestPromise = Promise.new(function(Resolve, Reject)
		local IsCollectionIdValid = Collections:GetConfig(CollectionId)
		if IsCollectionIdValid == nil then
			return Reject(`{CollectionId} is not a valid collection id`)
		end

		local IsItemIdValid = Collections:GetItemConfig(CollectionId, ItemId)
		if IsItemIdValid == nil then
			return Reject(`{ItemId} is not a valid item id for collection {CollectionId}`)
		end

		if CollectionId == "Currencies" then
			return Reject("Use function 'SpendCurrency' instead.")
		end

		local PlayerCollectionsDataStream = DataStream.Stored[Player].Collections

		if CollectionId == "Towers" then
			local TowerUniqueId = ItemId
			PlayerCollectionsDataStream.Towers[TowerUniqueId] = nil
		else
			--// Generic item
			local CurrentAmount = PlayerCollectionsDataStream[CollectionId][ItemId]:Read() or 0
			if Amount > CurrentAmount then
				return Reject("Not enough items.")
			end

			local NewAmount = CurrentAmount - Amount
			if NewAmount > 0 then
				PlayerCollectionsDataStream[CollectionId][ItemId] = NewAmount
			else
				PlayerCollectionsDataStream[CollectionId][ItemId] = nil
			end
		end

		return Resolve()
	end)

	local Success, Response = RequestPromise:await()

	if Success ~= true then
		warn(Response)
	end

	return Success, Response
end

function CollectionsService:GiveCurrency(Player, CurrencyId, Amount, TransactionType, ItemSku)
	local RequestPromise = Promise.new(function(Resolve, Reject)
		local IsCurrencyIdValid = Collections:GetItemConfig("Currencies", CurrencyId)
		if IsCurrencyIdValid == nil then
			return Reject(`{CurrencyId} is not a valid currency id`)
		end

		local PlayerDataStream = DataStream.Stored[Player]
		local PlayerCurrenciesDataStream = PlayerDataStream.Collections.Currencies

		local CurrentBalance = PlayerCurrenciesDataStream[CurrencyId]:Read() or 0
		local NewBalance = CurrentBalance + Amount
		PlayerCurrenciesDataStream[CurrencyId] = NewBalance

		if not TransactionType then
			return Reject("No transaction type provided.")
		end
		if not ItemSku then
			return Reject("No item sku provided.")
		end

		--// Stored Stats
		local CurrenciesGainedDataStream = PlayerDataStream.Stats.CurrenciesGained
		local CurrentValue = CurrenciesGainedDataStream[CurrencyId]:Read() or 0
		CurrenciesGainedDataStream[CurrencyId] = CurrentValue + Amount

		return Resolve({
			NewBalance = NewBalance,
		})
	end)

	local Success, Response = RequestPromise:await()

	if Success then
		local NewBalance = Response.NewBalance

		AnalyticsService:LogEconomyEvent(
			Player,
			Enum.AnalyticsEconomyFlowType.Source,
			CurrencyId,
			Amount,
			NewBalance,
			TransactionType,
			ItemSku
		)
	else
		warn(Response)
	end

	return Success, Response
end

function CollectionsService:SpendCurrency(Player, CurrencyId, Amount, TransactionType, SourceSKU)
	local RequestPromise = Promise.new(function(Resolve, Reject)
		local IsCurrencyIdValid = Collections:GetItemConfig("Currencies", CurrencyId)
		if IsCurrencyIdValid == nil then
			return Reject(`{CurrencyId} is not a valid currency id`)
		end

		local PlayerCurrenciesDataStream = DataStream.Stored[Player].Collections.Currencies

		local CurrentBalance = PlayerCurrenciesDataStream[CurrencyId]:Read() or 0
		if CurrentBalance < Amount then
			local CurrencyConfig = Collections:GetItemConfig("Currencies", CurrencyId)
			return Reject(`Not enough {CurrencyConfig.DisplayName}!`)
		end

		--// Success! Spend currency.
		local NewBalance = CurrentBalance - Amount
		PlayerCurrenciesDataStream[CurrencyId] = NewBalance

		return Resolve({
			NewBalance = NewBalance,
		})
	end)

	local Success, Response = RequestPromise:await()

	if Success then
		local NewBalance = Response.NewBalance

		AnalyticsService:LogEconomyEvent(
			Player,
			Enum.AnalyticsEconomyFlowType.Sink,
			CurrencyId,
			Amount,
			NewBalance,
			TransactionType,
			SourceSKU
		)
	else
		warn(Response)
	end

	return Success, Response
end

function CollectionsService:GiveItemReward(Player, ItemData, TransactionType, SourceSKU)
	if ItemData.CollectionId == "Currencies" then
		CollectionsService:GiveCurrency(Player, ItemData.ItemId, ItemData.Amount, TransactionType, SourceSKU)
	else
		CollectionsService:GiveItem(Player, ItemData.CollectionId, ItemData.ItemId, ItemData.Amount, ItemData.Options)
	end
end

function CollectionsService:GiveItemRewards(Player, ItemRewards, TransactionType, SourceSKU)
	for _, ItemData in pairs(ItemRewards) do
		CollectionsService:GiveItemReward(Player, ItemData, TransactionType, SourceSKU)
	end
end

-- Initializers --

-- Return Module --
return CollectionsService
