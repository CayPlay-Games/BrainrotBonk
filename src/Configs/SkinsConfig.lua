--[[
	SkinsConfig.lua

	Description:
		Configuration for player skins (brain rot skins).
		Skins are custom character models applied during rounds.
--]]

local TableHelper = shared("TableHelper")

return TableHelper:DeepFreeze({
	-- Folder name in ServerStorage containing skin models
	SKINS_FOLDER_NAME = "Skins",

	-- Default skin applied to all players (until unlock system)
	DEFAULT_SKIN = "Fluriflura",

	-- Available skins
	Skins = {
		Fluriflura = {
			DisplayName = "Fluriflura",
			Description = "Fluriflura Skin",
			-- Model name in ServerStorage.Skins
			ModelName = "Fluriflura",
		},
		-- Add more skins here as they're created:
		-- Skibidi = {
		-- 	DisplayName = "Skibidi",
		-- 	Description = "Skibidi toilet skin",
		-- 	ModelName = "Skibidi",
		-- },
	},
})
