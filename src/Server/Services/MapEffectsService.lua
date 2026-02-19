--[[
	MapEffectsService.lua

	Description:
		Server-side orchestration for map ambient effects.
		Provides sync timing data to clients; clients handle rendering.
		Effects run continuously while a map is loaded.
--]]

-- Root --
local MapEffectsService = {}

-- Roblox Services --
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

-- Dependencies --
local GetRemoteEvent = shared("GetRemoteEvent")

-- Remotes --
local MapEffectStartedEvent = GetRemoteEvent("MapEffectStarted")
local MapEffectStoppedEvent = GetRemoteEvent("MapEffectStopped")

-- Private Variables --
local _ActiveMapId = nil
local _ActiveStartTime = nil

-- Internal Functions --

-- API Functions --

function MapEffectsService:OnMapLoaded(mapId, mapInstance)
	_ActiveMapId = mapId
	_ActiveStartTime = Workspace:GetServerTimeNow()


	-- Notify all clients
	MapEffectStartedEvent:FireAllClients({
		mapId = mapId,
		startServerTime = _ActiveStartTime,
	})
end

function MapEffectsService:OnMapUnload(mapId)
	if _ActiveMapId then
		-- Notify all clients to stop effects
		MapEffectStoppedEvent:FireAllClients(mapId)

		_ActiveMapId = nil
		_ActiveStartTime = nil
	end
end

function MapEffectsService:SendActiveEffectsToPlayer(player)
	if _ActiveMapId and _ActiveStartTime then
		MapEffectStartedEvent:FireClient(player, {
			mapId = _ActiveMapId,
			startServerTime = _ActiveStartTime,
		})
	end
end

-- Initializers --
function MapEffectsService:Init()
	-- Handle late joiners
	Players.PlayerAdded:Connect(function(player)
		task.delay(1, function()
			self:SendActiveEffectsToPlayer(player)
		end)
	end)
end

-- Return Module --
return MapEffectsService
