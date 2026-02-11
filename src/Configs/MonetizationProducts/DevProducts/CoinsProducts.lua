local TableHelper = shared("TableHelper")

local PACK_1_AMOUNT = 10

return TableHelper:DeepFreeze({
	CoinsPack1 = {
		DisplayName = `+{PACK_1_AMOUNT}`,
		Icon = "",
		GiveCurrencyAmount = `{PACK_1_AMOUNT}`,
		LayoutOrder = 1,

		IdealRobuxCost = 1,
		DevProductId = 5555555555,
		-- Gift_DevProductId = 5555555555,
	},
})
