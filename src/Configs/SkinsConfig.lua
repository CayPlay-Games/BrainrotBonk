--[[
	SkinsConfig.lua

	Description:
		Configuration for player skins (brain rot skins).
		Skins are custom character models applied during rounds.
--]]

local TableHelper = shared("TableHelper")

-- Rarity definitions
local Rarities = {
	Common = {
		Name = "Common",
		Color = Color3.fromRGB(187, 137, 1),
		SortOrder = 1,
	},
	Uncommon = {
		Name = "Uncommon",
		Color = Color3.fromRGB(80, 200, 80),
		SortOrder = 2,
	},
	Rare = {
		Name = "Rare",
		Color = Color3.fromRGB(80, 150, 255),
		SortOrder = 3,
	},
	Epic = {
		Name = "Epic",
		Color = Color3.fromRGB(180, 80, 255),
		SortOrder = 4,
	},
	Legendary = {
		Name = "Legendary",
		Color = Color3.fromRGB(255, 180, 0),
		SortOrder = 5,
	},
}

return TableHelper:DeepFreeze({
	-- Folder name in ServerStorage containing skin models
	SKINS_FOLDER_NAME = "Skins",

	-- Default skin applied to all players (until unlock system)
	DEFAULT_SKIN = "Fluriflura",

	-- Rarity definitions
	Rarities = Rarities,

	-- Available skins
	Skins = {
		Fluriflura = {
			DisplayName = "Fluriflura",
			Description = "Fluriflura Skin",
			Rarity = "Common",
			-- Model name in ServerStorage.Skins
			ModelName = "Fluriflura",
		},
		GoldenFluriflura = {
			DisplayName = "Golden Fluriflura",
			Description = "Golden Fluriflura Skin",
			Rarity = "Legendary",
			-- Model name in ServerStorage.Skins
			ModelName = "GoldenFluriflura",
		},
		-- Add more skins here as they're created:
		-- Skibidi = {
		-- 	DisplayName = "Skibidi",
		-- 	Description = "Skibidi toilet skin",
		-- 	Rarity = "Rare",
		-- 	ModelName = "Skibidi",
		-- },
	},
})
