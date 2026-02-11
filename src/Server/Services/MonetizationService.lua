--[[
    MonetizationService.lua

    Description:
        No description provided.

--]]

-- Root --
local MonetizationService = {}

-- Roblox Services --
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

-- Dependencies --
local DataStream = shared("DataStream")
local GetRemoteEvent = shared("GetRemoteEvent")

-- Object References --
local ReceiptProcessedRemoteEvent = GetRemoteEvent("ReceiptProcessedRemoteEvent")

-- Constants --
local GIFTING_SKU_PREFIX = "Gift_"

-- Private Variables --
local _PurchaseHandlers = {}

-- Public Variables --

-- Internal Functions --
local function LoadPurchaseHandlers()
	--// Load here
end

local function ProcessReceipt(ReceiptInfo)
	local Success, Result = pcall(function()
		local Player = Players:GetPlayerByUserId(ReceiptInfo.PlayerId)
		if not Player then
			error("Could not find player!")
		end

		local StoredPlayerData = DataStream.Stored[Player]:Read()
		if not StoredPlayerData then
			error("Could not find player DataStream!")
		end

		local IsPurchased = StoredPlayerData.PurchaseReceiptsProcessed[ReceiptInfo.PurchaseId]
		if IsPurchased then
			return true
		end

		local PurchaseHandlerFunction = _PurchaseHandlers[ReceiptInfo.ProductId]
		if not PurchaseHandlerFunction then
			error(`No purchase handler defined for product ID '{ReceiptInfo.ProductId}'`)
		end

		local HandlerSucceeded, HandlerResult = pcall(PurchaseHandlerFunction, ReceiptInfo, Player)
		if not HandlerSucceeded then
			error(
				`Grant purchase handler errored while processing purchase from '{Player.Name}' of product ID '{ReceiptInfo.ProductId}': {HandlerResult}`
			)
		end

		local DidHandlerGrantPurchase = HandlerResult == true
		if not DidHandlerGrantPurchase then
			error(
				`Handler did not grant purchase for '{Player.Name}' with product ID '{ReceiptInfo.ProductId}': {HandlerResult}`
			)
			return nil
		end

		local PlayerDataStream = DataStream.Stored[Player]
		PlayerDataStream.PurchaseReceiptsProcessed[ReceiptInfo.PurchaseId] = true
		PlayerDataStream.Monetization.TotalRobuxSpent += (ReceiptInfo.CurrencySpent or 0)

		local ProductIdString = tostring(ReceiptInfo.ProductId)
		local CurrentBoughtCount = PlayerDataStream.Monetization.ProductsBought:Read()[ProductIdString]
		if CurrentBoughtCount ~= nil then
			PlayerDataStream.Monetization.ProductsBought[ProductIdString] += 1
		else
			PlayerDataStream.Monetization.ProductsBought[ProductIdString] = 1
		end

		ReceiptProcessedRemoteEvent:FireClient(Player, ReceiptInfo)

		return true
	end)

	if not Success then
		local ErrorMessage = Result
		warn(`[ProcessReceipt]: {ErrorMessage}`)

		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local DidGrantPurchase = Result == true
	return if DidGrantPurchase
		then Enum.ProductPurchaseDecision.PurchaseGranted
		else Enum.ProductPurchaseDecision.NotProcessedYet
end

-- API Functions --

-- Initializers --
function MonetizationService:Init()
	MarketplaceService.ProcessReceipt = ProcessReceipt

	task.defer(LoadPurchaseHandlers)
end

-- Return Module --
return MonetizationService
