--[[
	MapService.lua

	Description:
		Manages game map loading, unloading, and spawn point retrieval.
		Maps are stored in ServerStorage.Maps as Models/Folders with a SpawnPoints subfolder.
--]]

-- Root --
local MapService = {}

-- Roblox Services --
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

-- Dependencies --
local Promise = shared("Promise")
local MapsConfig = shared("MapsConfig")
local RoundConfig = shared("RoundConfig")

-- Constants --
local MAPS_FOLDER = ServerStorage:WaitForChild(MapsConfig.MAPS_FOLDER_NAME, 10)

-- Private Variables --
local _CurrentMapId = nil
local _CurrentMapInstance = nil

-- Internal Functions --

-- Debug logging
local function DebugLog(...)
	print("[MapService]", ...)
end

-- Applies slippery physics to all BaseParts in the map
local function ApplySlipperyPhysics(mapInstance)
	local slipperyProperties = PhysicalProperties.new(
		0.7, -- Density
		RoundConfig.SLIPPERY_FRICTION, -- Friction (low for ice-like sliding)
		RoundConfig.SLIPPERY_ELASTICITY, -- Elasticity (low bounce)
		100, -- FrictionWeight (max value, makes this friction dominate)
		1 -- ElasticityWeight
	)

	local partCount = 0
	for _, part in ipairs(mapInstance:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CustomPhysicalProperties = slipperyProperties
			partCount = partCount + 1
		end
	end

	DebugLog("Applied slippery physics to", partCount, "parts in", mapInstance.Name)
end

-- Extracts spawn points from a map's SpawnPoints folder
-- Returns array of CFrames sorted by spawn point name (1, 2, 3...)
local function ExtractSpawnPoints(mapInstance)
	local spawnPointsFolder = mapInstance:FindFirstChild("SpawnPoints")
	if not spawnPointsFolder then
		warn("[MapService] Map", mapInstance.Name, "has no SpawnPoints folder")
		return {}
	end

	local spawnPoints = {}
	for _, spawnPart in ipairs(spawnPointsFolder:GetChildren()) do
		if spawnPart:IsA("BasePart") then
			local index = tonumber(spawnPart.Name)
			if index then
				spawnPoints[index] = spawnPart.CFrame
			else
				-- Non-numeric name, append to end
				table.insert(spawnPoints, spawnPart.CFrame)
			end
		end
	end

	-- Convert sparse array to dense array
	local denseSpawnPoints = {}
	for i = 1, #spawnPoints + 100 do -- Check up to reasonable max
		if spawnPoints[i] then
			table.insert(denseSpawnPoints, spawnPoints[i])
		end
	end

	-- Add any non-indexed spawns
	for _, cf in ipairs(spawnPoints) do
		if typeof(cf) == "CFrame" then
			-- Already added via index
		end
	end

	DebugLog("Extracted", #denseSpawnPoints, "spawn points from", mapInstance.Name)
	return denseSpawnPoints
end

-- API Functions --

-- Loads a map by ID, returns Promise resolving to spawn points array
function MapService:LoadMap(mapId)
	mapId = mapId or MapsConfig.DEFAULT_MAP

	return Promise.new(function(resolve, reject)
		-- Validate map exists in config
		local mapConfig = MapsConfig.Maps[mapId]
		if not mapConfig then
			return reject("Map '" .. tostring(mapId) .. "' not found in MapsConfig")
		end

		-- Check if maps folder exists
		if not MAPS_FOLDER then
			return reject("Maps folder not found in ServerStorage. Expected: ServerStorage." .. MapsConfig.MAPS_FOLDER_NAME)
		end

		-- Find map template in ServerStorage
		local mapTemplate = MAPS_FOLDER:FindFirstChild(mapId)
		if not mapTemplate then
			return reject("Map model '" .. mapId .. "' not found in ServerStorage." .. MapsConfig.MAPS_FOLDER_NAME)
		end

		-- Unload current map if one exists
		if _CurrentMapInstance then
			self:UnloadCurrentMap()
		end

		-- Clone and parent to Workspace
		DebugLog("Loading map:", mapId)
		local mapClone = mapTemplate:Clone()
		mapClone.Name = "CurrentMap"
		mapClone.Parent = Workspace

		_CurrentMapId = mapId
		_CurrentMapInstance = mapClone

		-- Apply slippery physics to map surfaces
		ApplySlipperyPhysics(mapClone)

		-- Extract spawn points
		local spawnPoints = ExtractSpawnPoints(mapClone)

		if #spawnPoints == 0 then
			warn("[MapService] Map has no spawn points, generating fallback")
			-- Generate fallback circular spawn points
			for i = 1, 12 do
				local angle = (i - 1) * (2 * math.pi / 12)
				local radius = 20
				local pos = Vector3.new(math.cos(angle) * radius, 5, math.sin(angle) * radius)
				table.insert(spawnPoints, CFrame.new(pos))
			end
		end

		DebugLog("Map loaded successfully with", #spawnPoints, "spawn points")
		resolve(spawnPoints)
	end)
end

-- Unloads the current map
function MapService:UnloadCurrentMap()
	if _CurrentMapInstance then
		DebugLog("Unloading map:", _CurrentMapId)
		_CurrentMapInstance:Destroy()
		_CurrentMapInstance = nil
		_CurrentMapId = nil
	end
end

-- Gets the currently loaded map ID
function MapService:GetCurrentMapId()
	return _CurrentMapId
end

-- Gets the current map instance
function MapService:GetCurrentMapInstance()
	return _CurrentMapInstance
end

-- Gets a random map ID from available maps
function MapService:GetRandomMapId()
	local mapIds = {}
	for mapId in pairs(MapsConfig.Maps) do
		table.insert(mapIds, mapId)
	end

	if #mapIds == 0 then
		return MapsConfig.DEFAULT_MAP
	end

	return mapIds[math.random(1, #mapIds)]
end

-- Gets map config by ID
function MapService:GetMapConfig(mapId)
	return MapsConfig.Maps[mapId]
end

-- Initializers --
function MapService:Init()
	DebugLog("Initializing...")

	if not MAPS_FOLDER then
		warn("[MapService] Maps folder not found! Create ServerStorage." .. MapsConfig.MAPS_FOLDER_NAME)
	else
		local mapCount = 0
		for _ in pairs(MapsConfig.Maps) do
			mapCount = mapCount + 1
		end
		DebugLog("Found", mapCount, "maps in config")
	end
end

-- Return Module --
return MapService
