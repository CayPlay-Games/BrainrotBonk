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
	Mythic = {
		Name = "Mythic",
		Color = Color3.fromRGB(255, 50, 150),
		SortOrder = 6,
	},
	Secret = {
		Name = "Secret",
		Color = Color3.fromRGB(255, 40, 40),
		SortOrder = 7,
	},
}

-- Mutation variants for skins
local Mutations = {
	Normal = {
		Name = "Default",
		Color = Color3.fromRGB(255, 255, 255),
		SortOrder = 1,
	},
	Lava = {
		Name = "Lava",
		Color = Color3.fromRGB(255, 80, 20),
		SortOrder = 2,
	},
	Gold = {
		Name = "Golden",
		Color = Color3.fromRGB(255, 200, 50),
		SortOrder = 3,
	},
	Diamond = {
		Name = "Diamond",
		Color = Color3.fromRGB(100, 200, 255),
		SortOrder = 4,
	},
	Rainbow = {
		Name = "Rainbow",
		Color = Color3.fromRGB(255, 100, 255),
		SortOrder = 5,
	},
	Galaxy = {
		Name = "Galaxy",
		Color = Color3.fromRGB(120, 80, 200),
		SortOrder = 6,
	},
}

return TableHelper:DeepFreeze({
	-- Folder name in ServerStorage containing skin models
	SKINS_FOLDER_NAME = "Skins",

	-- Default skin applied to all players (until unlock system)
	DEFAULT_SKIN = "Fluriflura",

	-- Rarity definitions
	Rarities = Rarities,

	-- Mutation variants
	Mutations = Mutations,

	-- Available skins
	Skins = {
		Fluriflura = {
			DisplayName = "Fluriflura",
			Description = "Fluriflura Skin",
			Rarity = "Common",
			-- Model name in ServerStorage.Skins
			ModelName = "Fluriflura",
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
