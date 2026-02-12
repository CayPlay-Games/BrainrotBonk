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
	Golden = {
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
	DEFAULT_SKIN = "FluriFlura",

	-- Rarity definitions
	Rarities = Rarities,

	-- Mutation variants
	Mutations = Mutations,

	-- Available skins
	Skins = {
		--TODO: Perhaps sort into subtables by rarity
		-- ==================== --
		-- ====== COMMON ====== --
		-- ==================== --
		FluriFlura = {
			DisplayName = "Fluri Flura",
			Description = "Fluri Flura Skin",
			Rarity = "Common",
			ModelName = "FluriFlura",
		},
		LiriliLarila = {
			DisplayName = "Lirili Larila",
			Description = "Lirili Larila Skin",
			Rarity = "Common",
			ModelName = "LiriliLarila",
		},
		TimCheese = {
			DisplayName = "Tim Cheese",
			Description = "Tim Cheese Skin",
			Rarity = "Common",
			ModelName = "TimCheese",
		},
		TalpaDiFero = {
			DisplayName = "Talpa Di Fero",
			Description = "Talpa Di Fero Skin",
			Rarity = "Common",
			ModelName = "TalpaDiFero",
		},
		SvininaBombardino = {
			DisplayName = "Svinina Bombardino",
			Description = "Svinina Bombardino Skin",
			Rarity = "Common",
			ModelName = "SvininaBombardino",
		},
		PipiKiwi = {
			DisplayName = "Pipi Kiwi",
			Description = "Pipi Kiwi Skin",
			Rarity = "Common",
			ModelName = "PipiKiwi",
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
