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
	TestBoxOne = {
		DisplayName = "Test Box One",
		Tier = 1,
		LayoutOrder = 1,
		RobuxPrice = 75,
		CoinsPrice = 9,
		Skins = {
			{ SkinId = "PipiKiwi", Weight = 50 },
			{ SkinId = "SvininaBombardino", Weight = 50 },
		},
	},
	TestBoxTwo = {
		DisplayName = "Test Box Two",
		Tier = 2,
		LayoutOrder = 2,
		RobuxPrice = 150,
		CoinsPrice = 19,
		Skins = {
			{ SkinId = "BanditoBobrito", Weight = 14.2 },
			{ SkinId = "BonecaAmbalabu", Weight = 14.2 },
			{ SkinId = "CactoHipopotamo", Weight = 14.2 },
			{ SkinId = "TricTracBarabum", Weight = 14.2 },
			{ SkinId = "TatatataSahur", Weight = 14.2 },
			{ SkinId = "GangsterFootera", Weight = 14.2 },
			{ SkinId = "TrippiTroppi", Weight = 14.2 },
		},
	},
	-- Group exclusive crate - awarded to group members
	GroupExclusive = {
		DisplayName = "Certified Bonker Crate",
		Tier = 3,
		NotPurchasable = true, -- Cannot be bought in shop
		EggModel = "GroupExclusive",
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
