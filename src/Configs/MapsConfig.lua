--[[
	MapsConfig.lua

	Description:
		Configuration for game maps including metadata and settings.
		Physical maps are stored in ServerStorage.Maps
--]]

local TableHelper = shared("TableHelper")

return TableHelper:DeepFreeze({
	-- Map definitions
	Maps = {
		TestArena = {
			DisplayName = "Test Arena",
			MinPlayers = 1,
			MaxPlayers = 12,
		},
	},

	-- Default map to load if none specified
	DEFAULT_MAP = "TestArena",

	-- ServerStorage path where map models are stored
	MAPS_FOLDER_NAME = "Maps",
})
