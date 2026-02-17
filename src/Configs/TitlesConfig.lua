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
	},
})
