--[[
	RobuxShopConfig.lua

	Description:
		Client/server shared config for Robux shop offers.
		Each offer points at a Monetization Product SKU and defines its grant payload.
--]]

local TableHelper = shared("TableHelper")

return TableHelper:DeepFreeze({
	-- Example:
	-- UIProductSKUByFrameName = {
	-- 	SPINS_1 = "PrizeWheelSpin1",
	-- 	COINS_1 = "CoinsPack1",
	-- }

	UIProductSKUByFrameName = {
		-- Spins section
		SPINS_1 = "PrizeWheelSpin1",
		SPINS_2 = "PrizeWheelSpin5",
		-- SPINS_3 = "SpinSku3", -- TODO: create SKU/config, then map

		-- Currency section
		COINS_1 = "CoinsPack1",
		-- COINS_2 = "CoinSku2", -- TODO: create SKU/config, then map
		-- COINS_3 = "CoinSku3", -- TODO: create SKU/config, then map

		-- Top-level cards
		-- VIP = "VipSku", -- TODO: create SKU/config, then map
		-- EXCLUSIVE_LUCKY_BLOCK = "LuckyBlockSku", -- TODO: create SKU/config, then map
		-- ["2X_BONKCOIN"] = "2xBonkcoinSku", -- TODO: create SKU/config, then map
		-- ARROW_CUSTOMIZATION = "ArrowSku", -- TODO: create SKU/config, then map
	},
})
