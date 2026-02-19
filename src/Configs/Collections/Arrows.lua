local TableHelper = shared("TableHelper")
local ArrowsConfig = shared("ArrowsConfig")

-- Build Items table from ArrowsConfig
-- Each item is just the arrow ID (no mutations for arrows)
local Items = {}

for arrowId, arrowData in pairs(ArrowsConfig.Arrows) do
	Items[arrowId] = {
		DisplayName = arrowData.DisplayName,
		Description = arrowData.Description,
		Icon = arrowData.Icon,
	}
end

return TableHelper:DeepFreeze({
	DisplayName = "Arrows",
	Icon = "",

	Items = Items,
})
