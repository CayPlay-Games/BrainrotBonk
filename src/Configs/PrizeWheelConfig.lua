--[[
	PrizewheelConfig.lua

	Description:
		Configuration for prize wheel (6 MAX).
--]]

local TableHelper = shared("TableHelper")

return TableHelper:DeepFreeze({
	Prizes = {
		[1] = {
			Type = "Coins",
			DisplayName = "+75 Bonkcoins",
			Icon = "rbxassetid://77620024941395",
			Color = Color3.fromRGB(255, 255, 255),
			Chance = 32,
		},
		[2] = {
			Type = "Coins",
			DisplayName = "+150 Bonkcoins",
			Icon = "rbxassetid://77620024941395",
			Color = Color3.fromRGB(255, 255, 255),
			Chance = 28,
		},
		[3] = {
			Type = "Coins",
			DisplayName = "+200 Bonkcoins",
			Icon = "rbxassetid://115815120204674",
			Color = Color3.fromRGB(255, 255, 255),
			Chance = 21,
		},
		[4] = {
			Type = "Coins",
			DisplayName = "+400 Bonkcoins",
			Icon = "rbxassetid://88573938019178",
			Color = Color3.fromRGB(255, 255, 255),
			Chance = 15,
		},
		[5] = {
			Type = "Mutation",
			DisplayName = "Gold Mutation",
			Icon = "rbxassetid://139488764717715",
			Color = Color3.fromRGB(255, 255, 255),
			Chance = 1,
		},
		[6] = {
			Type = "Skin",
			DisplayName = "TrippiTroppi",
			Icon = "rbxassetid://139488764717715",
			Color = Color3.fromRGB(255, 255, 255),
			Chance = 1,
		},
	},

	ProgressivePrizes = {
		[1] = {
			Type = "Coins",
			DisplayName = "+1,000 Bonkcoins",
			Icon = "rbxassetid://88573938019178",
			Color = Color3.fromRGB(255, 255, 255),
			RequiredSpins = 50,
		},
		[2] = {
			Type = "Coins",
			DisplayName = "+2,500 Bonkcoins",
			Icon = "rbxassetid://88573938019178",
			Color = Color3.fromRGB(255, 255, 255),
			RequiredSpins = 100,
		},
		[3] = {
			Type = "Coins",
			DisplayName = "+5,000 Bonkcoins",
			Icon = "rbxassetid://88573938019178",
			Color = Color3.fromRGB(255, 255, 255),
			RequiredSpins = 250,
		},
	},
})
