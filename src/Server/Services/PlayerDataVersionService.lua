--[[
    PlayerDataVersionService.lua

    Description:
        No description provided.

--]]

-- Root --
local PlayerDataVersionService = {}

-- Roblox Services --

-- Dependencies --

-- Object References --

-- Constants --
local PLAYER_DATA_VERSION_KEY = "_VERSION"

-- Private Variables --
local _VersionHandlers = {

	--// VERSION 1 - [RELEASE] Default first initial data
	function(Player) end,
}

-- Public Variables --

-- Internal Functions --

-- API Functions --
function PlayerDataVersionService:UpdatePlayerData(Player, ProfileData)
	local CurrentVersion = ProfileData[PLAYER_DATA_VERSION_KEY] or 0
	local TargetVersion = #_VersionHandlers

	--// @todo implement promise in here
	if CurrentVersion < TargetVersion then
		local NextVersionId = CurrentVersion + 1
		for VersionId = NextVersionId, TargetVersion do
			_VersionHandlers[VersionId](Player)
			ProfileData[PLAYER_DATA_VERSION_KEY] = TargetVersion
		end
	end
end

-- Initializers --
function PlayerDataVersionService:Init() end

-- Return Module --
return PlayerDataVersionService
