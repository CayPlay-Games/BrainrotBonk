--[[
	RobuxShopConfig.lua

	Description:
		Client/server shared config for Robux shop offers.
		Each offer points at a Monetization Product SKU and defines its grant payload.
--]]

local TableHelper = shared("TableHelper")

return TableHelper:DeepFreeze({
	Offers = {
		{
			Id = "CoinsPack1",
			ProductSKU = "CoinsPack1",
			DisplayName = "Starter Coin Pack",
			Description = "+10 Coins",
			LayoutOrder = 1,
			Reward = {
				Type = "Currency",
				CurrencyId = "Coins",
				Amount = 10,
			},
		},
	},
})
