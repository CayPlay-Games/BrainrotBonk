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
		Blender = {
			DisplayName = "Blender",
			MinPlayers = 4,
			MaxPlayers = 12,
			GameMode = "Classic",
		},
		ElectroTub = {
			DisplayName = "Electro Tub",
			MinPlayers = 4,
			MaxPlayers = 12,
			GameMode = "Classic",
		},
		-- Castle = {
		-- 	DisplayName = "Castle",
		-- 	MinPlayers = 4,
		-- 	MaxPlayers = 12,
		-- 	GameMode = "Classic",
		-- },

		Volcano = {
			DisplayName = "Volcano",
			MinPlayers = 4,
			MaxPlayers = 12,
			GameMode = "Classic",
		},
	},

	-- Default map to load if none specified
	DEFAULT_MAP = nil,--"ElectroTub",

	-- ServerStorage path where map models are stored
	MAPS_FOLDER_NAME = "Maps",
})
