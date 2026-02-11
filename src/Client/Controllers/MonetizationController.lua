--[[
    MonetizationController.lua

    Description:
        No description provided.

--]]

-- Root --
local MonetizationController = {}

-- Roblox Services --
local MarketplaceService = game:GetService("MarketplaceService")
local CommerceService = game:GetService("CommerceService")
local Players = game:GetService("Players")

-- Dependencies --
local MonetizationProducts = shared("MonetizationProducts")
local GetRemoteEvent = shared("GetRemoteEvent")
local Signal = shared("Signal")
local Promise = shared("Promise")

-- Object References --
local ReceiptProcessedRemoteEvent = GetRemoteEvent("ReceiptProcessedRemoteEvent")

local LocalPlayer = Players.LocalPlayer

-- Constants --
local MAX_GET_PRODUCT_INFO_RETRIES = 4
local RETRY_DELAY = 2

-- Private Variables --
local _CachedProductInfo = {}
local _PurchasePromptActive = false

-- Public Variables --
MonetizationController.PromptActiveChanged = Signal.new()
MonetizationController.ProductInfoCachedAdded = Signal.new()

-- Internal Functions --

-- Internal Functions --
local function ReceiptProcessed(ReceiptInfo)
	local DevProductSKU = MonetizationProducts:GetProductSKUForDevProductId(ReceiptInfo.ProductId)
	if not DevProductSKU then
		warn(`Could not find DevProductSKU for ProductId '{ReceiptInfo.ProductId}'`)
		return
	end

	local GroupId = MonetizationProducts:GetProductGroup(DevProductSKU)

	--// Do stuff here
end

local function FetchProductInfo(ProductSKU)
	local Success, ProductInfo = false, nil
	local CurrentRetryDelay = RETRY_DELAY

	local FetchFunction

	local ProductType = MonetizationProducts:GetProductType(ProductSKU)
	local ProductConfig = MonetizationProducts:GetProductConfig(ProductSKU)

	if ProductType == "DevProducts" then
		FetchFunction = function()
			return MarketplaceService:GetProductInfo(ProductConfig.DevProductId, Enum.InfoType.Product)
		end
	elseif ProductType == "AssetProducts" then
		FetchFunction = function()
			return MarketplaceService:GetProductInfo(ProductConfig.AssetProductId, Enum.InfoType.Asset)
		end
	elseif ProductType == "CommerceProducts" then
		FetchFunction = function()
			return CommerceService:GetCommerceProductInfoAsync(ProductConfig.CommerceProductId)
		end
	else
		warn(`Unknown ProductType {ProductType}`)
		return
	end

	--// Retry loop with pcall for safety
	for Attempt = 1, MAX_GET_PRODUCT_INFO_RETRIES do
		local CallSuccess, Result = pcall(FetchFunction)

		if CallSuccess then
			ProductInfo = Result
			Success = true
			break
		else
			warn("Failed to fetch product info for", ProductType, ProductSKU, "Attempt:", Attempt, "Error:", Result)
			if Attempt < MAX_GET_PRODUCT_INFO_RETRIES then
				task.wait(CurrentRetryDelay)
				CurrentRetryDelay = CurrentRetryDelay * 2 --// Exponential backoff
			end
		end
	end

	if Success and ProductInfo then
		_CachedProductInfo[ProductSKU] = ProductInfo
		MonetizationController.ProductInfoCachedAdded:Fire(ProductSKU, ProductInfo)
	else
		warn(
			"Failed to fetch product info for",
			ProductType,
			"after",
			MAX_GET_PRODUCT_INFO_RETRIES,
			"attempts:",
			ProductSKU
		)
	end
end

local function HandlePromptFinished()
	if _PurchasePromptActive then
		_PurchasePromptActive = false

		MonetizationController.PromptActiveChanged:Fire(false)
	end
end

-- API Functions --
function MonetizationController:GetProductInfoPromise(ProductSKU)
	local CacheAddedConnection

	return Promise.new(function(resolve, reject)
		local CachedInfo = _CachedProductInfo[ProductSKU]
		if CachedInfo then
			resolve(CachedInfo)
			return
		end

		CacheAddedConnection = MonetizationController.ProductInfoCachedAdded:Connect(function(SKU, ProductInfo)
			if SKU == ProductSKU then
				if ProductInfo then
					resolve(ProductInfo)
				else
					reject("Failed to fetch product info for " .. ProductSKU)
				end
			end
		end)

		task.defer(FetchProductInfo, ProductSKU)
	end):finally(function()
		if CacheAddedConnection then
			CacheAddedConnection:Disconnect()
		end
	end)
end

function MonetizationController:PromptPurchase(ProductSKU)
	if _PurchasePromptActive then
		return
	end

	_PurchasePromptActive = true
	MonetizationController.PromptActiveChanged:Fire(true)

	local ProductType = MonetizationProducts:GetProductType(ProductSKU)
	local ProductConfig = MonetizationProducts:GetProductConfig(ProductSKU)

	if ProductType == "DevProducts" then
		MarketplaceService:PromptProductPurchase(LocalPlayer, ProductConfig.DevProductId)
	elseif ProductType == "AssetProducts" then
		MarketplaceService:PromptPurchase(LocalPlayer, ProductConfig.AssetProductId)
	elseif ProductType == "CommerceProducts" then
		CommerceService:PromptCommerceProductPurchase(LocalPlayer, ProductConfig.CommerceProductId)
	else
		warn(`Unknown ProductType {ProductType}`)
		return
	end
end

function MonetizationController:GetProductInfoViewData(ProductType, ProductInfo)
	--[[
		Name
		Icon
		DisplayPrice
	--]]

	if ProductType == "AssetProducts" then
		return {
			Name = ProductInfo.Name,
			Icon = `rbxthumb://type=Asset&id={ProductInfo.AssetId}&w=420&h=420`,
			DisplayPrice = ProductInfo.PriceInRobux == nil and "Off-Sale" or `{ProductInfo.PriceInRobux}`,
		}
	elseif ProductType == "CommerceProducts" then
		return {
			Name = ProductInfo.Item.Name,
			Icon = `rbxassetid://{ProductInfo.Item.IconImageAssetId}`,
			DisplayPrice = ProductInfo.Item.DisplayPrice,
		}
	elseif ProductType == "DevProducts" then
		return {
			Name = ProductInfo.DisplayName,
			Icon = `rbxassetid://{ProductInfo.IconImageAssetId}`,
			DisplayPrice = ProductInfo.IsForSale == nil and "Off-Sale" or `{ProductInfo.PriceInRobux}`,
		}
	else
		warn(`ProductType not yet handlded {ProductType}`)
	end

	return {}
end

-- Initializers --
function MonetizationController:Init()
	ReceiptProcessedRemoteEvent.OnClientEvent:Connect(ReceiptProcessed)
	MarketplaceService.PromptProductPurchaseFinished:Connect(HandlePromptFinished)
	MarketplaceService.PromptPurchaseFinished:Connect(HandlePromptFinished)
end

-- Return Module --
return MonetizationController
