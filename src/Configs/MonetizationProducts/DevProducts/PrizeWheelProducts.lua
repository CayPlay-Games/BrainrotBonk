--[[
	PrizeWheelProducts.lua

	Description:
		DevProduct configuration for prize wheel spin packs.
--]]

local TableHelper = shared("TableHelper")

return TableHelper:DeepFreeze({
	PrizeWheelSpin1 = {
		DisplayName = "Prize Wheel x1 Spin",
		Icon = "",
		LayoutOrder = 1,
		IdealRobuxCost = 99,
		DevProductId = 0, -- Replace with your actual DevProduct ID
	},

	PrizeWheelSpin5 = {
		DisplayName = "Prize Wheel x5 Spins",
		Icon = "",
		LayoutOrder = 2,
		IdealRobuxCost = 499,
		DevProductId = 0, -- Replace with your actual DevProduct ID
	},
})
