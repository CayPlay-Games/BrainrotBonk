local TableHelper = shared("TableHelper")
local SkinsConfig = shared("SkinsConfig")

-- Build Items table from SkinsConfig
-- Each item is a SkinId_Mutation combo (e.g., "FluriFlura_Normal", "FluriFlura_Golden")
local Items = {}

for skinId, skinData in pairs(SkinsConfig.Skins) do
	for mutationId, mutationData in pairs(SkinsConfig.Mutations) do
		local itemId = skinId .. "_" .. mutationId
		Items[itemId] = {
			DisplayName = skinData.DisplayName .. " (" .. mutationData.Name .. ")",
			SkinId = skinId,
			MutationId = mutationId,
			Rarity = skinData.Rarity,
			Icon = skinData.Icon,
		}
	end
end

return TableHelper:DeepFreeze({
	DisplayName = "Skins",
	Icon = "",

	Items = Items,
})
