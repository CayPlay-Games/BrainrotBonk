--[[
	SkinBoxesConfig.lua

	Description:
		Configuration for skin boxes (eggs) sold in the Skin Shop.
		Each box contains weighted skins that are randomly rolled on purchase.
		Skins reference SkinsConfig by SkinId.
--]]

local SkinBoxesConfig = {}

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
			{ SkinId = "Fluriflura", Weight = 100 },
		},
	},
	TestBoxTwo = {
		DisplayName = "Test Box Two",
		Tier = 2,
		LayoutOrder = 2,
		RobuxPrice = 150,
		CoinsPrice = 19,
		Skins = {
			{ SkinId = "Fluriflura", Weight = 100 },
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

-- Helper to roll a random skin from a box (weighted)
function SkinBoxesConfig:RollSkin(boxId)
	local box = self.Boxes[boxId]
	if not box then return nil end

	local total = self:GetTotalWeight(boxId)
	if total == 0 then return nil end

	local roll = math.random(1, total)
	local accumulated = 0

	for _, skin in ipairs(box.Skins) do
		accumulated = accumulated + skin.Weight
		if roll <= accumulated then
			return skin.SkinId
		end
	end

	-- Fallback (should never reach)
	return box.Skins[1] and box.Skins[1].SkinId
end

return SkinBoxesConfig
