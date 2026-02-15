--[[
	DeathMatchMode.lua

	Description:
		Death Match game mode - last player standing wins.
		Unlike Classic mode, the map does not shrink between rounds.
--]]

local BaseGameMode = shared("BaseGameMode")

local DeathMatchMode = setmetatable({}, { __index = BaseGameMode })
DeathMatchMode.__index = DeathMatchMode

function DeathMatchMode.new(settings)
	return setmetatable(BaseGameMode.new(settings), DeathMatchMode)
end

return DeathMatchMode
