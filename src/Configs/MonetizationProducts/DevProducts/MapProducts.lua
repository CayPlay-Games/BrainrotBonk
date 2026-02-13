--[[
	MapProducts.lua

	Description:
		DevProduct configuration for map picking feature.
		Single product for all map selections (map tracked server-side).
--]]

local TableHelper = shared("TableHelper")
local MapsConfig = shared("MapsConfig")

return TableHelper:DeepFreeze({
	PickMap = {
		DisplayName = "Pick Next Map",
		Icon = "",
		LayoutOrder = 1,

		IdealRobuxCost = MapsConfig.PICK_MAP_PRICE,
		DevProductId = 3535867378,
	},
})
