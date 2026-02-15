--[[
	GameModesConfig.lua

	Description:
		Configuration for game modes including mode definitions and settings.
		Each map can specify which game mode it uses via the GameMode property.
--]]

local TableHelper = shared("TableHelper")

return TableHelper:DeepFreeze({
	-- Default game mode if map doesn't specify one
	DEFAULT_MODE = "Classic",

	-- Game mode definitions
	Modes = {
		Classic = {
			DisplayName = "Classic",
			Description = "Map shrinks after each round",
			Settings = {
				ShrinkPercentage = 0.10,
				MinimumScale = 0.5,
				ShrinkDuration = 1.5,
				ShrinkEasing = "Quad",
			},
		},
		DeathMatch = {
			DisplayName = "Death Match",
			Description = "Last player standing wins",
			Settings = {},
		},
	},
})
