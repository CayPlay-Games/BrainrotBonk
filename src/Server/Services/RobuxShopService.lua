--[[
	RobuxShopService.lua

	Description:
		Registers Robux shop DevProduct receipt handlers and grants configured rewards.
--]]

-- Root --
local RobuxShopService = {}

-- Dependencies --
local CollectionsService = shared("CollectionsService")
local MonetizationProducts = shared("MonetizationProducts")
local MonetizationService = shared("MonetizationService")
local RobuxShopConfig = shared("RobuxShopConfig")

-- Internal Functions --
local function GrantOfferReward(player, offer)
	local reward = offer.Reward
	if not reward then
		return false
	end

	if reward.Type == "Currency" then
		local success = CollectionsService:GiveCurrency(
			player,
			reward.CurrencyId,
			reward.Amount,
			Enum.AnalyticsEconomyTransactionType.Shop.Name,
			offer.ProductSKU
		)
		return success == true
	end

	warn("[RobuxShopService] Unsupported reward type:", reward.Type, "for offer:", offer.Id)
	return false
end

local function RegisterOffer(offer)
	local sku = offer.ProductSKU
	if type(sku) ~= "string" or sku == "" then
		warn("[RobuxShopService] Missing ProductSKU for offer:", offer.Id)
		return
	end

	local productConfig = MonetizationProducts:GetProductConfig(sku)
	local productType = MonetizationProducts:GetProductType(sku)

	if not productConfig or productType ~= "DevProducts" then
		warn("[RobuxShopService] Offer SKU must be a DevProduct:", sku)
		return
	end

	local devProductId = productConfig.DevProductId
	if type(devProductId) ~= "number" or devProductId <= 0 then
		warn("[RobuxShopService] Invalid DevProductId for SKU:", sku)
		return
	end

	MonetizationService:RegisterPurchaseHandler(devProductId, function(receiptInfo, player)
		if receiptInfo.ProductId ~= devProductId then
			return false
		end
		return GrantOfferReward(player, offer)
	end)
end

-- Initializers --
function RobuxShopService:Init()
	for _, offer in ipairs(RobuxShopConfig.Offers or {}) do
		RegisterOffer(offer)
	end
end

-- Return Module --
return RobuxShopService
