--[[
	SkinBoxProducts.lua

	Description:
		DevProduct configurations for skin box (egg) Robux purchases.
		Create these DevProducts in the Roblox Developer Dashboard and
		update the DevProductId values accordingly.
--]]

local TableHelper = shared("TableHelper")

return TableHelper:DeepFreeze({
	-- TODO: Create these DevProducts in Roblox Dashboard and update IDs
	ColorfulEgg = {
		DisplayName = "Colorful Egg",
		Icon = "",
		LayoutOrder = 1,
		IdealRobuxCost = 75,
		DevProductId = 0, -- Replace with actual DevProduct ID
	},
	PastelEgg = {
		DisplayName = "Pastel Egg",
		Icon = "",
		LayoutOrder = 2,
		IdealRobuxCost = 150,
		DevProductId = 0, -- Replace with actual DevProduct ID
	},
})
