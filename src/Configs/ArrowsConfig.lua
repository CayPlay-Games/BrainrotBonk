--[[
	ArrowsConfig.lua

	Description:
		Configuration for player arrows.
		Arrows are cosmetic indicators shown during the aiming reveal phase.
--]]

local TableHelper = shared("TableHelper")

-- Arrow definitions
local Arrows = {
	Default = {
		DisplayName = "Default Arrow",
		Description = "The standard arrow",
		ModelName = "Default",
		Icon = "rbxassetid://0",
	},
}

return TableHelper:DeepFreeze({
	-- Folder name in ReplicatedStorage/Assets containing arrow models
	ARROWS_FOLDER_NAME = "Arrows",

	-- Default arrow for all players
	DEFAULT_ARROW = "Default",

	-- Available arrows
	Arrows = Arrows,
})
