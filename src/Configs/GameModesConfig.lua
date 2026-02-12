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
			-- Mode-specific settings
			Settings = {
				ShrinkPercentage = 0.10, -- 10% shrink per round
				MinimumScale = 0.5, -- Don't shrink below 50%
				ShrinkDuration = 1.5, -- Seconds for shrink animation
				ShrinkEasing = "Quad", -- TweenService easing style
			},
		},
		-- Future modes can be added here:
		-- Survival = { ... },
		-- KingOfTheHill = { ... },
	},
})
