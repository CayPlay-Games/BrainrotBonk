local TableHelper = shared("TableHelper")
local TitlesConfig = shared("TitlesConfig")

-- Build Items table from TitlesConfig
local Items = {}
for titleId, titleData in pairs(TitlesConfig.Titles) do
	Items[titleId] = {
		DisplayName = titleData.DisplayName,
		Description = titleData.Description,
		Color = titleData.Color,
	}
end

return TableHelper:DeepFreeze({
	DisplayName = "Titles",
	Icon = "",

	Items = Items,
})
