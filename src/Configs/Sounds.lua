--[[
    Sounds.lua
    Author(s): arcoorio

    Description:
        Static configuration for sounds.
--]]

-- Root --
local Sounds = {}

-- Buffs Configurations --
Sounds.Config = {
	-- Music
	Default = {
		SoundId = "rbxassetid://132748936249883",
		IsLooped = true,
		DefaultVolume = 0.5,
		DefaultSpeed = 1,
	},

	-- Ambient

	-- SFX
	TempSuccess = {
		SoundId = "rbxassetid://3997124966",
	},
	ShovelDigTick = {
		SoundId = "rbxassetid://88442833509532",
	},
	DigProgressHit = {
		SoundId = "rbxassetid://114672147284831",
	},

	MouseHover = {
		SoundId = "rbxassetid://18856494234",
	},
	MouseClick = {
		SoundId = "rbxassetid://18202483174",
	},

	RockPileAppear = {
		SoundId = "rbxassetid://1741599172",
	},

	RockMining1 = {
		SoundId = "rbxassetid://9125869504",
	},

	RockMining2 = {
		SoundId = "rbxassetid://107752385945612",
	},

	ShovelEquip = {
		SoundId = "rbxassetid://133255687571677",
	},

	Notification = {
		SoundId = "rbxassetid://17582299860",
	},

	-- Lucky Block SFX
	LuckyBlockUse = {
		SoundId = "rbxassetid://76024600586073",
	},
	LuckyBlockLand = {
		SoundId = "rbxassetid://6607427522",
	},
	LuckyBlockShake = {
		SoundId = "rbxassetid://9125677840",
	},
	LuckyBlockOpen = {
		SoundId = "rbxassetid://7768888198",
	},
	LuckyBlockTick = {
		SoundId = "rbxassetid://6895079853",
	},
	LuckyBlockReveal = {
		SoundId = "rbxassetid://4757565956",
	},

	-- Skin SFX
	FluriFlura = {
		SoundId = "rbxassetid://72170332385958",
	},
	LiriliLarila = {
		SoundId = "rbxassetid://103801170706013",
	},
	TimCheese = {
		SoundId = "rbxassetid://110746146935369",
	},
	TalpaDiFero = {
		SoundId = "rbxassetid://99086786630079",
	},
	SvininaBombardino = {
		SoundId = "rbxassetid://81361393901087",
	},
	PipiKiwi = {
		SoundId = "rbxassetid://78526637722167",
	},
	BanditoBobrito = {
		SoundId = "rbxassetid://137424152814465",
	},
	BonecaAmbalabu = {
		SoundId = "rbxassetid://95526722233240",
	},
	CactoHipopotamo = {
		SoundId = "rbxassetid://75625787331849",
	},
	TricTracBarabum = {
		SoundId = "rbxassetid://129060617428644",
	},
	TatatataSahur = {
		SoundId = "rbxassetid://119591828669046",
	},
	GangsterFootera = {
		SoundId = "rbxassetid://74440735184624",
	},
	TrippiTroppi = {
		SoundId = "rbxassetid://93742743087587",
	},
	CappuccinoAssassino = {
		SoundId = "rbxassetid://76530672691189",
	},
	BrrBrrPatapim = {
		SoundId = "rbxassetid://133309305901949",
	},
	AvocadiniGuffo = {
		SoundId = "rbxassetid://77534236910900",
	},
	TrulimeroTrulicina = {
		SoundId = "rbxassetid://104911190548459",
	},
	BambiniCrostini = {
		SoundId = "rbxassetid://133772763262636",
	},
	BananitoDelfinito = {
		SoundId = "rbxassetid://100962597448808",
	},
	BrrBicusDicus = {
		SoundId = "rbxassetid://138228435357957",
	},
	StrawberrelliFlamingelli = {
		SoundId = "rbxassetid://121385220046157",
	},
	GlorboFruttodrillo = {
		SoundId = "rbxassetid://137966008500848",
	},
	LioneloCactuseli = {
		SoundId = "rbxassetid://137648505810929",
	},
	ChefCrabracadabra = {
		SoundId = "rbxassetid://116111720107645",
	},
	BalerinaCapucina = {
		SoundId = "rbxassetid://131576013989436",
	},
	ChimpanziniBananini = {
		SoundId = "rbxassetid://111681288980174",
	},
	BurbaloniLoliloli = {
		SoundId = "rbxassetid://132522217286230",
	},
	KarkerkarKurkur = {
		SoundId = "rbxassetid://125776093695080",
	},
	GorilloWatermelondrillo = {
		SoundId = "rbxassetid://91798137531539",
	},
	ZibraZubraZibralini = {
		SoundId = "rbxassetid://97556318541799",
	},
	CavalloVirtuoso = {
		SoundId = "rbxassetid://134636783401291",
	},
	BombombiniGusini = {
		SoundId = "rbxassetid://133338979919517",
	},
	RhinoToasterino = {
		SoundId = "rbxassetid://88599201450484",
	},
	OrangutiniAnanassini = {
		SoundId = "rbxassetid://112149559020243",
	},
	FrigoCamelo = {
		SoundId = "rbxassetid://136871186386842",
	},
	ElefantoCocofanto = {
		SoundId = "rbxassetid://73530770949393",
	},
	NyanCat = {
		SoundId = "rbxassetid://88974647548982",
	},
	GirafaCelestre = {
		SoundId = "rbxassetid://73286409617836",
	},
	Mateo = {
		SoundId = "rbxassetid://96772181798752",
	},
	TralaleroTralala = {
		SoundId = "rbxassetid://117987388988728",
	},
	OdinDinDinDun = {
		SoundId = "rbxassetid://91288143503848",
	},
	OrcaleroOrcala = {
		SoundId = "rbxassetid://70574783668882",
	},
	LaVaccaSaturnoSaturnita = {
		SoundId = "rbxassetid://116271324433632",
	},
	LaGrandeCombinasion = {
		SoundId = "rbxassetid://107106303688699",
	},
	TriplitoTralaleritos = {
		SoundId = "rbxassetid://88157432782425",
	},
	PotHotspot = {
		SoundId = "rbxassetid://130139040816037",
	},
	TorrtuginniDragonfrutini = {
		SoundId = "rbxassetid://133504892201844",
	},
	ChicleteiraBicicleteira = {
		SoundId = "rbxassetid://101487900491492",
	},
	SixSeven = {
		SoundId = "rbxassetid://88780152475615",
	},
}

-- API Functions --
function Sounds:Get(SoundName: string)
	return Sounds.Config[SoundName]
end

-- Return Module --
return Sounds
