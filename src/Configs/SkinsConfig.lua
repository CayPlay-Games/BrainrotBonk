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
			KeyframeSequences = {
				Idle = "rbxassetid://131516360936386",
				Walk = "rbxassetid://127026223662741",
			},
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

	Rare = {
		CappuccinoAssassino = {
			DisplayName = "Cappuccino Assassino",
			Description = "Cappuccino Assassino Skin",
			Rarity = Rarities.Rare.Name,
			ModelName = "CappuccinoAssassino",
			Icon = "rbxassetid://78907462743918",
		},
		BrrBrrPatapim = {
			DisplayName = "Brr Brr Patapim",
			Description = "Brr Brr Patapim Skin",
			Rarity = Rarities.Rare.Name,
			ModelName = "BrrBrrPatapim",
			Icon = "rbxassetid://72546639386572",
		},
		AvocadiniGuffo = {
			DisplayName = "Avocadini Guffo",
			Description = "Avocadini Guffo Skin",
			Rarity = Rarities.Rare.Name,
			ModelName = "AvocadiniGuffo",
			Icon = "rbxassetid://76742828511811",
			KeyframeSequences = {
				Idle = "rbxassetid://102820787617428",
				Walk = "rbxassetid://138762612908285",
			},
		},
		TrulimeroTrulicina = {
			DisplayName = "Trulimero Trulicina",
			Description = "Trulimero Trulicina Skin",
			Rarity = Rarities.Rare.Name,
			ModelName = "TrulimeroTrulicina",
			Icon = "rbxassetid://129902898843375",
		},
		BambiniCrostini = {
			DisplayName = "Bambini Crostini",
			Description = "Bambini Crostini Skin",
			Rarity = Rarities.Rare.Name,
			ModelName = "BambiniCrostini",
			Icon = "rbxassetid://123596596749903",
		},
		BananitoDelfinito = {
			DisplayName = "Bananito Delfinito",
			Description = "Bananito Delfinito Skin",
			Rarity = Rarities.Rare.Name,
			ModelName = "BananitoDelfinito",
			Icon = "rbxassetid://91207034524958",
		},
		BrrBicusDicus = {
			DisplayName = "Brr Bicus Dicus",
			Description = "Brr Bicus Dicus Skin",
			Rarity = Rarities.Rare.Name,
			ModelName = "BrrBicusDicus",
			Icon = "rbxassetid://127967015382596",
		},

	},

	Epic = {
		StrawberrelliFlamingelli = {
			DisplayName = "Strawberrelli Flamingelli",
			Description = "Strawberrelli Flamingelli Skin",
			Rarity = Rarities.Epic.Name,
			ModelName = "StrawberrelliFlamingelli",
			Icon = "rbxassetid://113926903554922",
		},
		GlorboFruttodrillo = {
			DisplayName = "Glorbo Fruttodrillo",
			Description = "Glorbo Fruttodrillo Skin",
			Rarity = Rarities.Epic.Name,
			ModelName = "GlorboFruttodrillo",
			Icon = "rbxassetid://113771785621066",
		},
		LioneloCactuseli = {
			DisplayName = "Lionelo Cactuseli",
			Description = "Lionelo Cactuseli Skin",
			Rarity = Rarities.Epic.Name,
			ModelName = "LioneloCactuseli",
			Icon = "rbxassetid://105090869186690",
		},
		ChefCrabracadabra = {
			DisplayName = "Chef Crabracadabra",
			Description = "Chef Crabracadabra Skin",
			Rarity = Rarities.Epic.Name,
			ModelName = "ChefCrabracadabra",
			Icon = "rbxassetid://115832073112337",
		},
		BalerinaCapucina = {
			DisplayName = "Balerina Capucina",
			Description = "Balerina Capucina Skin",
			Rarity = Rarities.Epic.Name,
			ModelName = "BalerinaCapucina",
			Icon = "rbxassetid://116491799841976",
		},
		ChimpanziniBananini = {
			DisplayName = "Chimpanzini Bananini",
			Description = "Chimpanzini Bananini Skin",
			Rarity = Rarities.Epic.Name,
			ModelName = "ChimpanziniBananini",
			Icon = "rbxassetid://125783544143079",
		},
		BurbaloniLoliloli = {
			DisplayName = "Burbaloni Loliloli",
			Description = "Burbaloni Loliloli Skin",
			Rarity = Rarities.Epic.Name,
			ModelName = "BurbaloniLoliloli",
			Icon = "rbxassetid://80805326984040",
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
		GorilloWatermelondrillo = {
			DisplayName = "Gorillo Watermelondrillo",
			Description = "Gorillo Watermelondrillo Skin",
			Rarity = Rarities.Legendary.Name,
			ModelName = "GorilloWatermelondrillo",
			Icon = "rbxassetid://124646689610484",
		},
		ZibraZubraZibralini = {
			DisplayName = "Zibra Zubra Zibralini",
			Description = "Zibra Zubra Zibralini Skin",
			Rarity = Rarities.Legendary.Name,
			ModelName = "ZibraZubraZibralini",
			Icon = "rbxassetid://115477615149453",
		},
		CavalloVirtuoso = {
			DisplayName = "Cavallo Virtuoso",
			Description = "Cavallo Virtuoso Skin",
			Rarity = Rarities.Legendary.Name,
			ModelName = "CavalloVirtuoso",
			Icon = "rbxassetid://75613931756356",
		},
		BombombiniGusini = {
			DisplayName = "Bombombini Gusini",
			Description = "Bombombini Gusini Skin",
			Rarity = Rarities.Legendary.Name,
			ModelName = "BombombiniGusini",
			Icon = "rbxassetid://114711505279918",
		},
		RhinoToasterino = {
			DisplayName = "Rhino Toasterino",
			Description = "Rhino Toasterino Skin",
			Rarity = Rarities.Legendary.Name,
			ModelName = "RhinoToasterino",
			Icon = "rbxassetid://107810388259902",
		},
		OrangutiniAnanassini = {
			DisplayName = "Orangutini Ananassini",
			Description = "Orangutini Ananassini Skin",
			Rarity = Rarities.Legendary.Name,
			ModelName = "OrangutiniAnanassini",
			Icon = "rbxassetid://109201046735600",
		},
		FrigoCamelo = {
			DisplayName = "Frigo Camelo",
			Description = "Frigo Camelo Skin",
			Rarity = Rarities.Legendary.Name,
			ModelName = "FrigoCamelo",
			Icon = "rbxassetid://130244863318554",
		},
	},

	Mythic = {
		ElefantoCocofanto = {
			DisplayName = "Elefanto Cocofanto",
			Description = "Elefanto Cocofanto Skin",
			Rarity = Rarities.Mythic.Name,
			ModelName = "ElefantoCocofanto",
			Icon = "rbxassetid://117804360550074",
		},
		NyanCat = {
			DisplayName = "Nyan Cat",
			Description = "Nyan Cat Skin",
			Rarity = Rarities.Mythic.Name,
			ModelName = "NyanCat",
			Icon = "rbxassetid://103338713461942",
		},
		GirafaCelestre = {
			DisplayName = "Girafa Celestre",
			Description = "Girafa Celestre Skin",
			Rarity = Rarities.Mythic.Name,
			ModelName = "GirafaCelestre",
			Icon = "rbxassetid://117032815846218",
		},
		Mateo = {
			DisplayName = "Mateo",
			Description = "Mateo Skin",
			Rarity = Rarities.Mythic.Name,
			ModelName = "Mateo",
			Icon = "rbxassetid://130414360847377",
		},
		TralaleroTralala = {
			DisplayName = "Tralalero Tralala",
			Description = "Tralalero Tralala Skin",
			Rarity = Rarities.Mythic.Name,
			ModelName = "TralaleroTralala",
			Icon = "rbxassetid://115075607828467",
		},
		OdinDinDinDun = {
			DisplayName = "Odin Din Din Dun",
			Description = "Odin Din Din Dun Skin",
			Rarity = Rarities.Mythic.Name,
			ModelName = "OdinDinDinDun",
			Icon = "rbxassetid://136995309060586",
		},
		OrcaleroOrcala = {
			DisplayName = "Orcalero Orcala",
			Description = "Orcalero Orcala Skin",
			Rarity = Rarities.Mythic.Name,
			ModelName = "OrcaleroOrcala",
			Icon = "rbxassetid://116154370625377",
		},
	},
	Secret = {
		LaVaccaSaturnoSaturnita = {
			DisplayName = "La Vacca Saturno Saturnita",
			Description = "La Vacca Saturno Saturnita Skin",
			Rarity = Rarities.Secret.Name,
			ModelName = "LaVaccaSaturnoSaturnita",
			Icon = "rbxassetid://139181455567640",
		},
		LaGrandeCombinasion = {
			DisplayName = "La Grande Combinasion",
			Description = "La Grande Combinasion Skin",
			Rarity = Rarities.Secret.Name,
			ModelName = "LaGrandeCombinasion",
			Icon = "rbxassetid://118607505428213",
		},
		TriplitoTralaleritos = {
			DisplayName = "Triplito Tralaleritos",
			Description = "Triplito Tralaleritos Skin",
			Rarity = Rarities.Secret.Name,
			ModelName = "TriplitoTralaleritos",
			Icon = "rbxassetid://87986446165545",
		},
		PotHotspot = {
			DisplayName = "Pot Hotspot",
			Description = "Pot Hotspot Skin",
			Rarity = Rarities.Secret.Name,
			ModelName = "PotHotspot",
			Icon = "rbxassetid://99233871242588",
		},
		TorrtuginniDragonfrutini = {
			DisplayName = "Torrtuginni Dragonfrutini",
			Description = "Torrtuginni Dragonfrutini Skin",
			Rarity = Rarities.Secret.Name,
			ModelName = "TorrtuginniDragonfrutini",
			Icon = "rbxassetid://83406172379553",
		},
		ChicleteiraBicicleteira = {
			DisplayName = "Chicleteira Bicicleteira",
			Description = "Chicleteira Bicicleteira Skin",
			Rarity = Rarities.Secret.Name,
			ModelName = "ChicleteiraBicicleteira",
			Icon = "rbxassetid://78115972219337",
		},
		SixSeven = {
			DisplayName = "6 7",
			Description = "6 7 Skin",
			Rarity = Rarities.Secret.Name,
			ModelName = "SixSeven",
			Icon = "rbxassetid://95884412237636",
		},
	}
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
