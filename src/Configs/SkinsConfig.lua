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

local SkinsByRarity = {
	Common = {
		FluriFlura = {
			DisplayName = "Fluri Flura",
			Description = "Fluri Flura Skin",
			Rarity = Rarities.Common.Name,
			ModelName = "FluriFlura",
			Icon = "rbxassetid://112553947469095",
		},
		LiriliLarila = {
			DisplayName = "Lirili Larila",
			Description = "Lirili Larila Skin",
			Rarity = Rarities.Common.Name,
			ModelName = "LiriliLarila",
			Icon = "rbxassetid://136005818208298",
		},
		TimCheese = {
			DisplayName = "Tim Cheese",
			Description = "Tim Cheese Skin",
			Rarity = Rarities.Common.Name,
			ModelName = "TimCheese",
			Icon = "rbxassetid://92645762618340",
		},
		TalpaDiFero = {
			DisplayName = "Talpa Di Fero",
			Description = "Talpa Di Fero Skin",
			Rarity = Rarities.Common.Name,
			ModelName = "TalpaDiFero",
			Icon = "rbxassetid://111490342757660",
		},
		SvininaBombardino = {
			DisplayName = "Svinina Bombardino",
			Description = "Svinina Bombardino Skin",
			Rarity = Rarities.Common.Name,
			ModelName = "SvininaBombardino",
			Icon = "rbxassetid://80425791301275",
		},
		PipiKiwi = {
			DisplayName = "Pipi Kiwi",
			Description = "Pipi Kiwi Skin",
			Rarity = Rarities.Common.Name,
			ModelName = "PipiKiwi",
			Icon = "rbxassetid://114153312275482",
		},
	},
	Uncommon = {
		BanditoBobrito = {
			DisplayName = "Bandito Bobrito",
			Description = "Bandito Bobrito Skin",
			Rarity = Rarities.Uncommon.Name,
			ModelName = "BanditoBobrito",
			Icon = "rbxassetid://74683246369815",
		},
		BonecaAmbalabu = {
			DisplayName = "Boneca Ambalabu",
			Description = "Boneca Ambalabu Skin",
			Rarity = Rarities.Uncommon.Name,
			ModelName = "BonecaAmbalabu",
			Icon = "rbxassetid://81353631051142",
		},
		CactoHipopotamo = {
			DisplayName = "Cacto Hipopotamo",
			Description = "Cacto Hipopotamo Skin",
			Rarity = Rarities.Uncommon.Name,
			ModelName = "CactoHipopotamo",
			Icon = "rbxassetid://133237059758349",
		},
		TricTracBarabum = {
			DisplayName = "Tric Trac Barabum",
			Description = "Tric Trac Barabum Skin",
			Rarity = Rarities.Uncommon.Name,
			ModelName = "TricTracBarabum",
			Icon = "rbxassetid://70888904779271",
		},
		TatatataSahur = {
			DisplayName = "Tatatata Sahur",
			Description = "Tatatata Sahur Skin",
			Rarity = Rarities.Uncommon.Name,
			ModelName = "TatatataSahur",
			Icon = "rbxassetid://123019866938509",
		},
		GangsterFootera = {
			DisplayName = "Gangster Footera",
			Description = "Gangster Footera Skin",
			Rarity = Rarities.Uncommon.Name,
			ModelName = "GangsterFootera",
			Icon = "rbxassetid://104716293717297",
		},
		TrippiTroppi = {
			DisplayName = "Trippi Troppi",
			Description = "Trippi Troppi Skin",
			Rarity = Rarities.Uncommon.Name,
			ModelName = "TrippiTroppi",
			Icon = "rbxassetid://139488764717715",
		},
	},
	Legendary = {
		KarkerkarKurkur = {
			DisplayName = "Karkerkar Kurkur",
			Description = "Karkerkar Kurkur Skin",
			Rarity = Rarities.Legendary.Name,
			ModelName = "KarkerkarKurkur",
			Icon = "rbxassetid://104922524760568",
		},
	},
}

local Skins = {}
for _, RaritySkins in next, SkinsByRarity do
	for SkinId, SkinConfig in next, RaritySkins do
		Skins[SkinId] = SkinConfig
	end
end

return TableHelper:DeepFreeze({
	-- Folder name in ServerStorage containing skin models
	SKINS_FOLDER_NAME = "Skins",

	-- Default skin applied to all players
	DEFAULT_SKIN = "FluriFlura",

	-- Rarity definitions
	Rarities = Rarities,

	-- Mutation variants
	Mutations = Mutations,

	-- Available skins
	Skins = Skins,
	SkinsByRarity = SkinsByRarity,
})
