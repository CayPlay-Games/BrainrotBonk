--[[
	TitlesConfig.lua

	Description:
		Configuration for player titles.
		Titles are displayed above player names in overhead displays.
--]]

local TableHelper = shared("TableHelper")

return TableHelper:DeepFreeze({
	-- Default title (nil = no title displayed)
	DEFAULT_TITLE = nil,

	-- Available titles
	Titles = {
		Newbie = {
			DisplayName = "Newbie",
			Description = "The Default Title",
			Color = Color3.fromRGB(200, 200, 200),
		},
		Veteran = {
			DisplayName = "Veteran",
			Description = "A Seasoned Player",
			Color = Color3.fromRGB(80, 150, 255),
		},
		Champion = {
			DisplayName = "Champion",
			Description = "Victorious in Battle",
			Color = Color3.fromRGB(255, 215, 0),
		},
		Legend = {
			DisplayName = "Legend",
			Description = "A True Master",
			Color = Color3.fromRGB(255, 100, 255),
		},
		CertifiedBonker = {
			DisplayName = "Certified Bonker",
			Description = "Join the game group!",
			Color = Color3.fromRGB(0, 200, 255),
		},

		-- Rank tier titles
		Bronze = {
			DisplayName = "Bronze",
			Description = "Reached Bronze rank",
			Color = Color3.fromRGB(205, 127, 50),
		},
		Silver = {
			DisplayName = "Silver",
			Description = "Reached Silver rank",
			Color = Color3.fromRGB(192, 192, 200),
		},
		Gold = {
			DisplayName = "Gold",
			Description = "Reached Gold rank",
			Color = Color3.fromRGB(255, 215, 0),
		},
		Platinum = {
			DisplayName = "Platinum",
			Description = "Reached Platinum rank",
			Color = Color3.fromRGB(150, 200, 220),
		},
		Emerald = {
			DisplayName = "Emerald",
			Description = "Reached Emerald rank",
			Color = Color3.fromRGB(80, 200, 120),
		},
		Diamond = {
			DisplayName = "Diamond",
			Description = "Reached Diamond rank",
			Color = Color3.fromRGB(180, 230, 255),
		},
		Master = {
			DisplayName = "Master",
			Description = "Reached Master rank",
			Color = Color3.fromRGB(180, 100, 220),
		},
		Grandmaster = {
			DisplayName = "Grandmaster",
			Description = "Reached Grandmaster rank",
			Color = Color3.fromRGB(200, 50, 50),
		},
	},
})
