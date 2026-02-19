--[[
	SkinBoxesConfig.lua

	Description:
		Configuration for skin boxes (eggs) sold in the Skin Shop.
		Each box contains weighted skins that are randomly rolled on purchase.
		Skins reference SkinsConfig by SkinId.
--]]

local SkinBoxesConfig = {}

-- Mutation roll chances (must add up to 100)
-- When a skin is rolled, a separate roll determines the mutation
SkinBoxesConfig.MutationChances = {
	{ Mutation = "Normal", Weight = 70 },   -- 70% chance
	{ Mutation = "Lava", Weight = 12 },     -- 12% chance
	{ Mutation = "Golden", Weight = 10 },   -- 10% chance
	{ Mutation = "Diamond", Weight = 5 },   -- 5% chance
	{ Mutation = "Rainbow", Weight = 2 },   -- 2% chance
	{ Mutation = "Galaxy", Weight = 1 },    -- 1% chance
}

-- Skin boxes available for purchase
-- SkinId must match a key in SkinsConfig.Skins
SkinBoxesConfig.Boxes = {
	CommonBox = {
		DisplayName = "Common Box",
		LayoutOrder = 1,
		RobuxPrice = 9,
		CoinsPrice = 75,
		Icon = "rbxassetid://136117318813027",
		Skins = {
			{ SkinId = "LiriliLarila", Weight = 31 },
			{ SkinId = "PipiKiwi", Weight = 26 },
			{ SkinId = "FluriFlura", Weight = 23 },
			{ SkinId = "TimCheese", Weight = 11 },
			{ SkinId = "TalpaDiFero", Weight = 5 },
			{ SkinId = "SvininaBombardino", Weight = 4 },
		},
	},
	UncommonBox = {
		DisplayName = "Uncommon Box",
		LayoutOrder = 2,
		RobuxPrice = 15,
		CoinsPrice = 150,
		Icon = "rbxassetid://136117318813027",
		Skins = {
			{ SkinId = "TatatataSahur", Weight = 31 },
			{ SkinId = "BanditoBobrito", Weight = 26 },
			{ SkinId = "TricTracBarabum", Weight = 23 },
			{ SkinId = "CactoHipopotamo", Weight = 11 },
			{ SkinId = "BonecaAmbalabu", Weight = 5 },
			{ SkinId = "GangsterFootera", Weight = 3 },
			{ SkinId = "TrippiTroppi", Weight = 1 },
		},
	},
	RareBox = {
		DisplayName = "Rare Box",
		LayoutOrder = 3,
		RobuxPrice = 19,
		CoinsPrice = 400,
		Icon = "rbxassetid://136117318813027",
		Skins = {
			{ SkinId = "BambiniCrostini", Weight = 31 },
			{ SkinId = "BrrBicusDicus", Weight = 26 },
			{ SkinId = "AvocadiniGuffo", Weight = 23 },
			{ SkinId = "BrrBrrPatapim", Weight = 11 },
			{ SkinId = "TrulimeroTrulicina", Weight = 5 },
			{ SkinId = "BananitoDelfinito", Weight = 3 },
			{ SkinId = "CappuccinoAssassino", Weight = 1 },
		},
	},
	EpicBox = {
		DisplayName = "Epic Box",
		LayoutOrder = 4,
		RobuxPrice = 25,
		CoinsPrice = 600,
		Icon = "rbxassetid://136117318813027",
		Skins = {
			{ SkinId = "BurbaloniLoliloli", Weight = 31 },
			{ SkinId = "ChimpanziniBananini", Weight = 26 },
			{ SkinId = "BalerinaCapucina", Weight = 23 },
			{ SkinId = "LioneloCactuseli", Weight = 11 },
			{ SkinId = "GlorboFruttodrillo", Weight = 5 },
			{ SkinId = "ChefCrabracadabra", Weight = 3 },
			{ SkinId = "StrawberrelliFlamingelli", Weight = 1 },
		},
	},
	LegendaryBox = {
		DisplayName = "Legendary Box",
		LayoutOrder = 5,
		RobuxPrice = 39,
		CoinsPrice = 1050,
		Icon = "rbxassetid://136117318813027",
		Skins = {
			{ SkinId = "ZibraZubraZibralini", Weight = 31 },
			{ SkinId = "OrangutiniAnanassini", Weight = 26 },
			{ SkinId = "FrigoCamelo", Weight = 23 },
			{ SkinId = "GorilloWatermelondrillo", Weight = 11 },
			{ SkinId = "BombombiniGusini", Weight = 5 },
			{ SkinId = "CavalloVirtuoso", Weight = 3 },
			{ SkinId = "RhinoToasterino", Weight = 1 },
		},
	},
	MythicBox = {
		DisplayName = "Mythic Box",
		LayoutOrder = 6,
		RobuxPrice = 55,
		CoinsPrice = 1700,
		Icon = "rbxassetid://136117318813027",
		Skins = {
			{ SkinId = "ElefantoCocofanto", Weight = 31 },
			{ SkinId = "Mateo", Weight = 26 },
			{ SkinId = "GirafaCelestre", Weight = 23 },
			{ SkinId = "OdinDinDinDun", Weight = 11 },
			{ SkinId = "TralaleroTralala", Weight = 5 },
			{ SkinId = "OrcaleroOrcala", Weight = 3 },
			{ SkinId = "NyanCat", Weight = 1 },
		},
	},
	SecretBox = {
		DisplayName = "Secret Box",
		LayoutOrder = 7,
		RobuxPrice = 79,
		CoinsPrice = 2800,
		Icon = "rbxassetid://136117318813027",
		Skins = {
			{ SkinId = "ChicleteiraBicicleteira", Weight = 31 },
			{ SkinId = "TorrtuginniDragonfrutini", Weight = 26 },
			{ SkinId = "PotHotspot", Weight = 23 },
			{ SkinId = "TriplitoTralaleritos", Weight = 11 },
			{ SkinId = "LaGrandeCombinasion", Weight = 5 },
			{ SkinId = "LaVaccaSaturnoSaturnita", Weight = 3 },
			{ SkinId = "SixSeven", Weight = 1 },
		},
	},
	-- Group exclusive crate - awarded to group members
	GroupExclusive = {
		DisplayName = "Certified Bonker Crate",
		Tier = 3,
		NotPurchasable = true, -- Cannot be bought in shop
		Icon = "rbxassetid://136117318813027",
		Skins = {
			{ SkinId = "TrippiTroppi", Weight = 34 },
			{ SkinId = "GangsterFootera", Weight = 33 },
			{ SkinId = "TricTracBarabum", Weight = 33 },
		},
	},
}

-- Helper to calculate total weight for a box
function SkinBoxesConfig:GetTotalWeight(boxId)
	local box = self.Boxes[boxId]
	if not box then return 0 end
	local total = 0
	for _, skin in ipairs(box.Skins) do
		total = total + skin.Weight
	end
	return total
end

-- Helper to get odds as percentage for a specific skin in a box
function SkinBoxesConfig:GetOdds(boxId, skinId)
	local box = self.Boxes[boxId]
	if not box then return 0 end
	local total = self:GetTotalWeight(boxId)
	if total == 0 then return 0 end
	for _, skin in ipairs(box.Skins) do
		if skin.SkinId == skinId then
			return (skin.Weight / total) * 100
		end
	end
	return 0
end

-- Helper to roll a random mutation based on MutationChances
function SkinBoxesConfig:RollMutation()
	return "Normal"
	-- -- TODO: MUTATIONS ARE ON HOLD FOR NOW
	-- local total = 0
	-- for _, entry in ipairs(self.MutationChances) do
	-- 	total = total + entry.Weight
	-- end

	-- local roll = math.random(1, total)
	-- local accumulated = 0

	-- for _, entry in ipairs(self.MutationChances) do
	-- 	accumulated = accumulated + entry.Weight
	-- 	if roll <= accumulated then
	-- 		return entry.Mutation
	-- 	end
	-- end

	-- return "Normal" -- Fallback
end

-- Helper to roll a random skin from a box (weighted)
-- Returns: skinId, mutation
function SkinBoxesConfig:RollSkin(boxId)
	local box = self.Boxes[boxId]
	if not box then return nil, nil end

	local total = self:GetTotalWeight(boxId)
	if total == 0 then return nil, nil end

	local roll = math.random(1, total)
	local accumulated = 0

	for _, skin in ipairs(box.Skins) do
		accumulated = accumulated + skin.Weight
		if roll <= accumulated then
			local mutation = self:RollMutation()
			print(string.format("Rolled skin '%s' with mutation '%s' from box '%s'", skin.SkinId, mutation, boxId))
			return skin.SkinId, mutation
		end
	end

	-- Fallback (should never reach)
	local skinId = box.Skins[1] and box.Skins[1].SkinId
	return skinId, "Normal"
end

return SkinBoxesConfig
