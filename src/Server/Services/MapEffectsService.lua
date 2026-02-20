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
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

-- Dependencies --
local GetRemoteEvent = shared("GetRemoteEvent")

-- Remotes --
local MapEffectStartedEvent = GetRemoteEvent("MapEffectStarted")
local MapEffectStoppedEvent = GetRemoteEvent("MapEffectStopped")

-- Constants --
local LATE_JOINER_DELAY = 1 -- Seconds to wait for client to load before sending effects
local LIGHTING_FOLDER = ServerStorage:FindFirstChild("Lighting")

-- Private Variables --
local _ActiveMapId = nil
local _ActiveStartTime = nil
local _DefaultLightingChildren = nil -- Cloned defaults, captured on first map load
local _CurrentMapLightingChildren = {} -- Track children added for current map

-- Internal Functions --
local function CaptureDefaultLighting()
	if _DefaultLightingChildren then return end

	_DefaultLightingChildren = {}
	for _, child in ipairs(Lighting:GetChildren()) do
		table.insert(_DefaultLightingChildren, child:Clone())
	end
end

local function ClearMapLightingChildren()
	for _, child in ipairs(_CurrentMapLightingChildren) do
		if child and child.Parent then
			child:Destroy()
		end
	end
	_CurrentMapLightingChildren = {}
end

local function ApplyMapLighting(mapId)
	ClearMapLightingChildren()

	if not LIGHTING_FOLDER then return end

	local mapLightingFolder = LIGHTING_FOLDER:FindFirstChild(mapId)
	if not mapLightingFolder then return end

	for _, child in ipairs(mapLightingFolder:GetChildren()) do
		local clone = child:Clone()
		clone.Parent = Lighting
		table.insert(_CurrentMapLightingChildren, clone)
	end
end

local function RestoreDefaultLighting()
	ClearMapLightingChildren()

	if not _DefaultLightingChildren then return end

	-- Clear any remaining non-default children
	for _, child in ipairs(Lighting:GetChildren()) do
		child:Destroy()
	end

	-- Restore defaults
	for _, defaultChild in ipairs(_DefaultLightingChildren) do
		local clone = defaultChild:Clone()
		clone.Parent = Lighting
	end
end

-- API Functions --
function MapEffectsService:OnMapLoaded(mapId)
	_ActiveMapId = mapId
	_ActiveStartTime = Workspace:GetServerTimeNow()

	-- Apply per-map lighting
	CaptureDefaultLighting()
	ApplyMapLighting(mapId)

	-- Notify all clients
	MapEffectStartedEvent:FireAllClients({
		mapId = mapId,
		startServerTime = _ActiveStartTime,
	})
end

function MapEffectsService:OnMapUnload()
	if _ActiveMapId then
		-- Notify all clients to stop effects
		MapEffectStoppedEvent:FireAllClients(_ActiveMapId)

		-- Restore default lighting
		RestoreDefaultLighting()

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
		task.delay(LATE_JOINER_DELAY, function()
			if player.Parent then -- Check player still in game
				self:SendActiveEffectsToPlayer(player)
			end
		end)
	end)
end

-- Return Module --
return MapEffectsService
