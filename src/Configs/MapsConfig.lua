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
			GameMode = "Classic",
		},
		-- Fake maps for testing roulette animation (remove when real maps are added)
		IcyPeaks = {
			DisplayName = "Icy Peaks",
			MinPlayers = 2,
			MaxPlayers = 12,
			GameMode = "Classic",
		},
		VolcanicRing = {
			DisplayName = "Volcanic Ring",
			MinPlayers = 2,
			MaxPlayers = 12,
			GameMode = "Classic",
		},
		CloudPlatform = {
			DisplayName = "Cloud Platform",
			MinPlayers = 2,
			MaxPlayers = 12,
			GameMode = "Classic",
		},
		NeonCity = {
			DisplayName = "Neon City",
			MinPlayers = 2,
			MaxPlayers = 12,
			GameMode = "Classic",
		},
		AncientTemple = {
			DisplayName = "Ancient Temple",
			MinPlayers = 2,
			MaxPlayers = 12,
			GameMode = "Classic",
		},
		SpaceStation = {
			DisplayName = "Space Station",
			MinPlayers = 2,
			MaxPlayers = 12,
			GameMode = "Classic",
		},
		JungleRuins = {
			DisplayName = "Jungle Ruins",
			MinPlayers = 2,
			MaxPlayers = 12,
			GameMode = "Classic",
		},
	},

	-- Default map to load if none specified
	DEFAULT_MAP = "TestArena",

	-- ServerStorage path where map models are stored
	MAPS_FOLDER_NAME = "Maps",
})
