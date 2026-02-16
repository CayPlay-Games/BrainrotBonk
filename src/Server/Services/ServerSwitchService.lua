--[[
	ServerSwitchService.lua

	Description:
		Handles server switch requests from clients.
		Teleports players to a new server instance when requested.
--]]

-- Root --
local ServerSwitchService = {}

-- Roblox Services --
local TeleportService = game:GetService("TeleportService")

-- Dependencies --
local GetRemoteEvent = shared("GetRemoteEvent")

-- Remote Events --
local SwitchServerRemoteEvent = GetRemoteEvent("SwitchServer")

-- Internal Functions --
local function OnSwitchServerRequest(player)
	local success, err = pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, { player })
	end)

	if not success then
		warn("[ServerSwitchService] Failed to teleport player:", player.Name, "-", err)
	end
end

-- Initializers --
function ServerSwitchService:Init()
	SwitchServerRemoteEvent.OnServerEvent:Connect(OnSwitchServerRequest)
end

-- Return Module --
return ServerSwitchService
