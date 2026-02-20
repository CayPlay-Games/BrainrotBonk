--[[
	MapEffectsController.lua

	Description:
		Client-side controller for map ambient effects.
		Dynamically loads per-map effect modules and manages their lifecycle.
		Uses server-provided timing for deterministic sync across clients.
--]]

-- Root --
local MapEffectsController = {}

-- Roblox Services --
local Workspace = game:GetService("Workspace")

-- Dependencies --
local GetRemoteEvent = shared("GetRemoteEvent")

-- Remotes --
local MapEffectStartedEvent = GetRemoteEvent("MapEffectStarted")
local MapEffectStoppedEvent = GetRemoteEvent("MapEffectStopped")

-- Private Variables --
local _ActiveModule = nil
local _ActiveMapId = nil

-- Internal Functions --
local function TryLoadMapEffectModule(mapId)
	local success, result = pcall(function()
		return shared(mapId .. "Effects")
	end)

	if success and result then
		return result
	end

	return nil
end

local function StopActiveModule()
	if _ActiveModule then
		local success, err = pcall(function()
			_ActiveModule:Stop()
		end)

		if not success then
			warn("[MapEffectsController] Error stopping module:", err)
		end

		_ActiveModule = nil
		_ActiveMapId = nil
	end
end

-- Handles MapEffectStarted event from server
local function OnMapEffectStarted(data)
	-- Stop any existing effects
	StopActiveModule()

	-- Try to load the per-map effect module
	local effectModule = TryLoadMapEffectModule(data.mapId)
	if not effectModule then
		return
	end

	-- Get the map instance from workspace (wait for replication)
	local mapInstance = Workspace:WaitForChild("CurrentMap", 5)
	if not mapInstance then
		warn("[MapEffectsController] CurrentMap not found in Workspace after 5s timeout")
		return
	end

	-- Start the effect module
	_ActiveModule = effectModule
	_ActiveMapId = data.mapId

	local success, err = pcall(function()
		effectModule:Start(mapInstance, data.startServerTime)
	end)

	if not success then
		warn("[MapEffectsController] Error starting effect module:", err)
		_ActiveModule = nil
		_ActiveMapId = nil
	end
end

-- Handles MapEffectStopped event from server
local function OnMapEffectStopped(mapId)
	if _ActiveMapId == mapId then
		StopActiveModule()
	end
end

-- API Functions --
-- Initializers --
function MapEffectsController:Init()
	MapEffectStartedEvent.OnClientEvent:Connect(OnMapEffectStarted)
	MapEffectStoppedEvent.OnClientEvent:Connect(OnMapEffectStopped)
end

-- Return Module --
return MapEffectsController
