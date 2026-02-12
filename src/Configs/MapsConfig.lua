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
		-- Fake maps for testing roulette animation (remove when real maps are added)
		IcyPeaks = {
			DisplayName = "Icy Peaks",
			MinPlayers = 2,
			MaxPlayers = 12,
		},
		VolcanicRing = {
			DisplayName = "Volcanic Ring",
			MinPlayers = 2,
			MaxPlayers = 12,
		},
		CloudPlatform = {
			DisplayName = "Cloud Platform",
			MinPlayers = 2,
			MaxPlayers = 12,
		},
		NeonCity = {
			DisplayName = "Neon City",
			MinPlayers = 2,
			MaxPlayers = 12,
		},
		AncientTemple = {
			DisplayName = "Ancient Temple",
			MinPlayers = 2,
			MaxPlayers = 12,
		},
		SpaceStation = {
			DisplayName = "Space Station",
			MinPlayers = 2,
			MaxPlayers = 12,
		},
		JungleRuins = {
			DisplayName = "Jungle Ruins",
			MinPlayers = 2,
			MaxPlayers = 12,
		},
	},

	-- Default map to load if none specified
	DEFAULT_MAP = "TestArena",

	-- ServerStorage path where map models are stored
	MAPS_FOLDER_NAME = "Maps",
})
