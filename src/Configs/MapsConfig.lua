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
		ElectroTub = {
			DisplayName = "Electro Tub",
			GameMode = "Classic",
		},
		Castle = {
			DisplayName = "Castle",
			GameMode = "DeathMatch",
		},
		Volcano = {
			DisplayName = "Volcano",
			GameMode = "DeathMatch",
			Modifier = {
				Id = "MeteorShower",
				Chance = 1.0, -- 100% chance for testing, adjust later
			},
		},
		SaladSpinner = {
			DisplayName = "Salad Spinner",
			GameMode = "DeathMatch",
		},
		SoupPot = {
			DisplayName = "Soup Pot",
			GameMode = "DeathMatch",
		},
		IcyMountains = {
			DisplayName = "Icy Mountains",
			GameMode = "Classic",
		},
		TrafficJam = {
			DisplayName = "Traffic Jam",
			GameMode = "Classic",
		},
		JungleTemple = {
			DisplayName = "Jungle Temple",
			GameMode = "Classic",
		},
	},

	-- Default map to load if none specified
	DEFAULT_MAP = nil,--"ElectroTub",

	-- ServerStorage path where map models are stored
	MAPS_FOLDER_NAME = "Maps",

	-- Universal price for picking any map (Robux)
	PICK_MAP_PRICE = 19,
})
