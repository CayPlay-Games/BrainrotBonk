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
			KeyframeSequences = {
				Idle = "rbxassetid://120971938846420",
				Walk = "rbxassetid://83432739236330",
			},
		},
		TimCheese = {
			DisplayName = "Tim Cheese",
			Description = "Tim Cheese Skin",
			Rarity = Rarities.Common.Name,
			ModelName = "TimCheese",
			Icon = "rbxassetid://92645762618340",
			KeyframeSequences = {
				Idle = "rbxassetid://86348273989347",
				Walk = "rbxassetid://106404853990555",
			},
			
		},
		TalpaDiFero = {
			DisplayName = "Talpa Di Fero",
			Description = "Talpa Di Fero Skin",
			Rarity = Rarities.Common.Name,
			ModelName = "TalpaDiFero",
			Icon = "rbxassetid://111490342757660",
			KeyframeSequences = {
				Idle = "rbxassetid://89864724190456",
				Walk = "rbxassetid://96081223658637",
			},
		},
		SvininaBombardino = {
			DisplayName = "Svinina Bombardino",
			Description = "Svinina Bombardino Skin",
			Rarity = Rarities.Common.Name,
			ModelName = "SvininaBombardino",
			Icon = "rbxassetid://80425791301275",
			KeyframeSequences = {
				Idle = "rbxassetid://79352899422395",
				Walk = "rbxassetid://113655292285969",
			},
		},
		PipiKiwi = {
			DisplayName = "Pipi Kiwi",
			Description = "Pipi Kiwi Skin",
			Rarity = Rarities.Common.Name,
			ModelName = "PipiKiwi",
			Icon = "rbxassetid://114153312275482",
			-- KeyframeSequences = {
			-- 	Idle = "rbxassetid://11111111",
			-- 	Walk = "rbxassetid://11111111",
			-- },
		},
	},
	Uncommon = {
		BanditoBobrito = {
			DisplayName = "Bandito Bobrito",
			Description = "Bandito Bobrito Skin",
			Rarity = Rarities.Uncommon.Name,
			ModelName = "BanditoBobrito",
			Icon = "rbxassetid://74683246369815",
			KeyframeSequences = {
				Idle = "rbxassetid://139496909160914",
				Walk = "rbxassetid://100894031703721",
			},
		},
		BonecaAmbalabu = {
			DisplayName = "Boneca Ambalabu",
			Description = "Boneca Ambalabu Skin",
			Rarity = Rarities.Uncommon.Name,
			ModelName = "BonecaAmbalabu",
			Icon = "rbxassetid://81353631051142",
			KeyframeSequences = {
				Idle = "rbxassetid://118387631710622",
				Walk = "rbxassetid://91423826769103",
			},
		},
		CactoHipopotamo = {
			DisplayName = "Cacto Hipopotamo",
			Description = "Cacto Hipopotamo Skin",
			Rarity = Rarities.Uncommon.Name,
			ModelName = "CactoHipopotamo",
			Icon = "rbxassetid://133237059758349",
			KeyframeSequences = {
				Idle = "rbxassetid://125472246714890",
				Walk = "rbxassetid://96198845585504",
			},
		},
		TricTracBarabum = {
			DisplayName = "Tric Trac Barabum",
			Description = "Tric Trac Barabum Skin",
			Rarity = Rarities.Uncommon.Name,
			ModelName = "TricTracBarabum",
			Icon = "rbxassetid://70888904779271",
			KeyframeSequences = {
				Idle = "rbxassetid://82143507368589",
				Walk = "rbxassetid://81292628834198",
			},
		},
		TatatataSahur = {
			DisplayName = "Tatatata Sahur",
			Description = "Tatatata Sahur Skin",
			Rarity = Rarities.Uncommon.Name,
			ModelName = "TatatataSahur",
			Icon = "rbxassetid://123019866938509",
			KeyframeSequences = {
				Idle = "rbxassetid://123686186041471",
				Walk = "rbxassetid://71189167787158",
			},
		},
		GangsterFootera = {
			DisplayName = "Gangster Footera",
			Description = "Gangster Footera Skin",
			Rarity = Rarities.Uncommon.Name,
			ModelName = "GangsterFootera",
			Icon = "rbxassetid://104716293717297",
			KeyframeSequences = {
				Idle = "rbxassetid://115295263680159",
				Walk = "rbxassetid://101945039484336",
			},
		},
		TrippiTroppi = {
			DisplayName = "Trippi Troppi",
			Description = "Trippi Troppi Skin",
			Rarity = Rarities.Uncommon.Name,
			ModelName = "TrippiTroppi",
			Icon = "rbxassetid://139488764717715",
			KeyframeSequences = {
				Idle = "rbxassetid://135559380377952",
				Walk = "rbxassetid://117345603865181",
			},
		},
	},

	Rare = {
		CappuccinoAssassino = {
			DisplayName = "Cappuccino Assassino",
			Description = "Cappuccino Assassino Skin",
			Rarity = Rarities.Rare.Name,
			ModelName = "CappuccinoAssassino",
			Icon = "rbxassetid://78907462743918",
			KeyframeSequences = {
				Idle = "rbxassetid://96422749344999",
				Walk = "rbxassetid://96870282490761",
			},
		},
		BrrBrrPatapim = {
			DisplayName = "Brr Brr Patapim",
			Description = "Brr Brr Patapim Skin",
			Rarity = Rarities.Rare.Name,
			ModelName = "BrrBrrPatapim",
			Icon = "rbxassetid://72546639386572",
			KeyframeSequences = {
				Idle = "rbxassetid://91576339516554",
				Walk = "rbxassetid://100795399080498",
			},
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
			KeyframeSequences = {
				Idle = "rbxassetid://115267414688609",
				Walk = "rbxassetid://124345279337057",
			},
		},
		BambiniCrostini = {
			DisplayName = "Bambini Crostini",
			Description = "Bambini Crostini Skin",
			Rarity = Rarities.Rare.Name,
			ModelName = "BambiniCrostini",
			Icon = "rbxassetid://123596596749903",
			KeyframeSequences = {
				Idle = "rbxassetid://140348463857066",
				Walk = "rbxassetid://133879691545321",
			},
		},
		BananitoDelfinito = {
			DisplayName = "Bananito Delfinito",
			Description = "Bananito Delfinito Skin",
			Rarity = Rarities.Rare.Name,
			ModelName = "BananitoDelfinito",
			Icon = "rbxassetid://91207034524958",
			KeyframeSequences = {
				Idle = "rbxassetid://133715981664840",
				Walk = "rbxassetid://82585146469430",
			},
		},
		BrrBicusDicus = {
			DisplayName = "Brr Bicus Dicus",
			Description = "Brr Bicus Dicus Skin",
			Rarity = Rarities.Rare.Name,
			ModelName = "BrrBicusDicus",
			Icon = "rbxassetid://127967015382596",
			KeyframeSequences = {
				Idle = "rbxassetid://86065687295212",
				Walk = "rbxassetid://81906586585329",
			},
		},

	},

	Epic = {
		StrawberrelliFlamingelli = {
			DisplayName = "Strawberrelli Flamingelli",
			Description = "Strawberrelli Flamingelli Skin",
			Rarity = Rarities.Epic.Name,
			ModelName = "StrawberrelliFlamingelli",
			Icon = "rbxassetid://113926903554922",
			KeyframeSequences = {
				Idle = "rbxassetid://136501496691682",
				Walk = "rbxassetid://73252987606026",
			},
		},
		GlorboFruttodrillo = {
			DisplayName = "Glorbo Fruttodrillo",
			Description = "Glorbo Fruttodrillo Skin",
			Rarity = Rarities.Epic.Name,
			ModelName = "GlorboFruttodrillo",
			Icon = "rbxassetid://113771785621066",
			KeyframeSequences = {
				Idle = "rbxassetid://112592584886915",
				Walk = "rbxassetid://129839684102657",
			},
		},
		LioneloCactuseli = {
			DisplayName = "Lionelo Cactuseli",
			Description = "Lionelo Cactuseli Skin",
			Rarity = Rarities.Epic.Name,
			ModelName = "LioneloCactuseli",
			Icon = "rbxassetid://105090869186690",
			KeyframeSequences = {
				Idle = "rbxassetid://83606715572070",
				Walk = "rbxassetid://124970626753043",
			},
		},
		ChefCrabracadabra = {
			DisplayName = "Chef Crabracadabra",
			Description = "Chef Crabracadabra Skin",
			Rarity = Rarities.Epic.Name,
			ModelName = "ChefCrabracadabra",
			Icon = "rbxassetid://115832073112337",
			KeyframeSequences = {
				Idle = "rbxassetid://87677415734552",
				Walk = "rbxassetid://98627258336948",
			},
		},
		BalerinaCapucina = {
			DisplayName = "Balerina Capucina",
			Description = "Balerina Capucina Skin",
			Rarity = Rarities.Epic.Name,
			ModelName = "BalerinaCapucina",
			Icon = "rbxassetid://116491799841976",
			KeyframeSequences = {
				Idle = "rbxassetid://118012985273361",
				Walk = "rbxassetid://134999561598679",
			},
		},
		ChimpanziniBananini = {
			DisplayName = "Chimpanzini Bananini",
			Description = "Chimpanzini Bananini Skin",
			Rarity = Rarities.Epic.Name,
			ModelName = "ChimpanziniBananini",
			Icon = "rbxassetid://125783544143079",
			KeyframeSequences = {
				Idle = "rbxassetid://133015480135776",
				Walk = "rbxassetid://100451191990988",
			},
		},
		BurbaloniLoliloli = {
			DisplayName = "Burbaloni Loliloli",
			Description = "Burbaloni Loliloli Skin",
			Rarity = Rarities.Epic.Name,
			ModelName = "BurbaloniLoliloli",
			Icon = "rbxassetid://80805326984040",
			KeyframeSequences = {
				Idle = "rbxassetid://85016104478285",
				Walk = "rbxassetid://130512841998582",
			},
		},

	},
	
	Legendary = {
		KarkerkarKurkur = {
			DisplayName = "Karkerkar Kurkur",
			Description = "Karkerkar Kurkur Skin",
			Rarity = Rarities.Legendary.Name,
			ModelName = "KarkerkarKurkur",
			Icon = "rbxassetid://104922524760568",
			KeyframeSequences = {
				Idle = "rbxassetid://140242225751586",
				Walk = "rbxassetid://71113969548451",
			},
		},
		GorilloWatermelondrillo = {
			DisplayName = "Gorillo Watermelondrillo",
			Description = "Gorillo Watermelondrillo Skin",
			Rarity = Rarities.Legendary.Name,
			ModelName = "GorilloWatermelondrillo",
			Icon = "rbxassetid://124646689610484",
			KeyframeSequences = {
				Idle = "rbxassetid://73461033882974",
				Walk = "rbxassetid://114766218625224",
			},
		},
		ZibraZubraZibralini = {
			DisplayName = "Zibra Zubra Zibralini",
			Description = "Zibra Zubra Zibralini Skin",
			Rarity = Rarities.Legendary.Name,
			ModelName = "ZibraZubraZibralini",
			Icon = "rbxassetid://115477615149453",
			KeyframeSequences = {
				Idle = "rbxassetid://129949912443499",
				Walk = "rbxassetid://129390168869157",
			},
		},
		CavalloVirtuoso = {
			DisplayName = "Cavallo Virtuoso",
			Description = "Cavallo Virtuoso Skin",
			Rarity = Rarities.Legendary.Name,
			ModelName = "CavalloVirtuoso",
			Icon = "rbxassetid://75613931756356",
			KeyframeSequences = {
				Idle = "rbxassetid://106664039135926",
				Walk = "rbxassetid://76257502008888",
			},
		},
		BombombiniGusini = {
			DisplayName = "Bombombini Gusini",
			Description = "Bombombini Gusini Skin",
			Rarity = Rarities.Legendary.Name,
			ModelName = "BombombiniGusini",
			Icon = "rbxassetid://114711505279918",
			KeyframeSequences = {
				Idle = "rbxassetid://114175290284549",
				Walk = "rbxassetid://114175290284549",
			},
		},
		RhinoToasterino = {
			DisplayName = "Rhino Toasterino",
			Description = "Rhino Toasterino Skin",
			Rarity = Rarities.Legendary.Name,
			ModelName = "RhinoToasterino",
			Icon = "rbxassetid://107810388259902",
			KeyframeSequences = {
				Idle = "rbxassetid://80020952300118",
				Walk = "rbxassetid://110035560315340",
			},
		},
		OrangutiniAnanassini = {
			DisplayName = "Orangutini Ananassini",
			Description = "Orangutini Ananassini Skin",
			Rarity = Rarities.Legendary.Name,
			ModelName = "OrangutiniAnanassini",
			Icon = "rbxassetid://109201046735600",
			KeyframeSequences = {
				Idle = "rbxassetid://82540318286365",
				Walk = "rbxassetid://81082328872954",
			},
		},
		FrigoCamelo = {
			DisplayName = "Frigo Camelo",
			Description = "Frigo Camelo Skin",
			Rarity = Rarities.Legendary.Name,
			ModelName = "FrigoCamelo",
			Icon = "rbxassetid://130244863318554",
			KeyframeSequences = {
				Idle = "rbxassetid://86222387240301",
				Walk = "rbxassetid://111172665897524",
			},
		},
	},

	Mythic = {
		ElefantoCocofanto = {
			DisplayName = "Elefanto Cocofanto",
			Description = "Elefanto Cocofanto Skin",
			Rarity = Rarities.Mythic.Name,
			ModelName = "ElefantoCocofanto",
			Icon = "rbxassetid://117804360550074",
			KeyframeSequences = {
				Idle = "rbxassetid://128184906553401",
				Walk = "rbxassetid://115058047411363",
			},
		},
		NyanCat = {
			DisplayName = "Nyan Cat",
			Description = "Nyan Cat Skin",
			Rarity = Rarities.Mythic.Name,
			ModelName = "NyanCat",
			Icon = "rbxassetid://103338713461942",
			KeyframeSequences = {
				Idle = "rbxassetid://91715237758205",
				Walk = "rbxassetid://123640975400235",
			},
		},
		GirafaCelestre = {
			DisplayName = "Girafa Celestre",
			Description = "Girafa Celestre Skin",
			Rarity = Rarities.Mythic.Name,
			ModelName = "GirafaCelestre",
			Icon = "rbxassetid://117032815846218",
			KeyframeSequences = {
				Idle = "rbxassetid://113718275728829",
				Walk = "rbxassetid://117982366782740",
			},
		},
		Mateo = {
			DisplayName = "Mateo",
			Description = "Mateo Skin",
			Rarity = Rarities.Mythic.Name,
			ModelName = "Mateo",
			Icon = "rbxassetid://130414360847377",
			KeyframeSequences = {
				Idle = "rbxassetid://95876332418915",
				Walk = "rbxassetid://101174957978368",
			},
		},
		TralaleroTralala = {
			DisplayName = "Tralalero Tralala",
			Description = "Tralalero Tralala Skin",
			Rarity = Rarities.Mythic.Name,
			ModelName = "TralaleroTralala",
			Icon = "rbxassetid://115075607828467",
			KeyframeSequences = {
				Idle = "rbxassetid://74906068282773",
				Walk = "rbxassetid://128289372283092",
			},
		},
		OdinDinDinDun = {
			DisplayName = "Odin Din Din Dun",
			Description = "Odin Din Din Dun Skin",
			Rarity = Rarities.Mythic.Name,
			ModelName = "OdinDinDinDun",
			Icon = "rbxassetid://136995309060586",
			KeyframeSequences = {
				Idle = "rbxassetid://97721155280856",
				Walk = "rbxassetid://128451967983331",
			},
		},
		OrcaleroOrcala = {
			DisplayName = "Orcalero Orcala",
			Description = "Orcalero Orcala Skin",
			Rarity = Rarities.Mythic.Name,
			ModelName = "OrcaleroOrcala",
			Icon = "rbxassetid://116154370625377",
			KeyframeSequences = {
				Idle = "rbxassetid://76870438404326",
				Walk = "rbxassetid://107503193100972",
			},
		},
	},
	Secret = {
		LaVaccaSaturnoSaturnita = {
			DisplayName = "La Vacca Saturno Saturnita",
			Description = "La Vacca Saturno Saturnita Skin",
			Rarity = Rarities.Secret.Name,
			ModelName = "LaVaccaSaturnoSaturnita",
			Icon = "rbxassetid://139181455567640",
			KeyframeSequences = {
				Idle = "rbxassetid://134421029856566",
				Walk = "rbxassetid://102579698107055",
			},
		},
		LaGrandeCombinasion = {
			DisplayName = "La Grande Combinasion",
			Description = "La Grande Combinasion Skin",
			Rarity = Rarities.Secret.Name,
			ModelName = "LaGrandeCombinasion",
			Icon = "rbxassetid://118607505428213",
			KeyframeSequences = {
				Idle = "rbxassetid://115069083582036",
				Walk = "rbxassetid://135181682426636",
			},
		},
		TriplitoTralaleritos = {
			DisplayName = "Triplito Tralaleritos",
			Description = "Triplito Tralaleritos Skin",
			Rarity = Rarities.Secret.Name,
			ModelName = "TriplitoTralaleritos",
			Icon = "rbxassetid://87986446165545",
			KeyframeSequences = {
				Idle = "rbxassetid://70775514535073",
				Walk = "rbxassetid://107475480762025",
			},
		},
		PotHotspot = {
			DisplayName = "Pot Hotspot",
			Description = "Pot Hotspot Skin",
			Rarity = Rarities.Secret.Name,
			ModelName = "PotHotspot",
			Icon = "rbxassetid://99233871242588",
			KeyframeSequences = {
				Idle = "rbxassetid://131641999705027",
				Walk = "rbxassetid://80300082282013",
			},
		},
		TorrtuginniDragonfrutini = {
			DisplayName = "Torrtuginni Dragonfrutini",
			Description = "Torrtuginni Dragonfrutini Skin",
			Rarity = Rarities.Secret.Name,
			ModelName = "TorrtuginniDragonfrutini",
			Icon = "rbxassetid://83406172379553",
			KeyframeSequences = {
				Idle = "rbxassetid://87713858699363",
				Walk = "rbxassetid://131929340038435",
			},
		},
		ChicleteiraBicicleteira = {
			DisplayName = "Chicleteira Bicicleteira",
			Description = "Chicleteira Bicicleteira Skin",
			Rarity = Rarities.Secret.Name,
			ModelName = "ChicleteiraBicicleteira",
			Icon = "rbxassetid://78115972219337",
			KeyframeSequences = {
				Idle = "rbxassetid://78700542784367",
				Walk = "rbxassetid://82256130164629",
			},
		},
		SixSeven = {
			DisplayName = "6 7",
			Description = "6 7 Skin",
			Rarity = Rarities.Secret.Name,
			ModelName = "SixSeven",
			Icon = "rbxassetid://95884412237636",
			KeyframeSequences = {
				Idle = "rbxassetid://120568575068578",
				Walk = "rbxassetid://100376783802964",
			},
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
