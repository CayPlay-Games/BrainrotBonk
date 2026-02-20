--[[
	ArrowTrapModifierController.lua

	Description:
		Client-side controller for arrow trap modifier visuals.
		Handles warning zones, arrow spawning, and arrow animations.
--]]

-- Roblox Services --
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

-- Dependencies --
local BaseModifierController = shared("BaseModifierController")

-- Root --
local ArrowTrapModifierController = setmetatable({}, { __index = BaseModifierController })
ArrowTrapModifierController.__index = ArrowTrapModifierController

-- Constants --
local DEBUG_MODE = false
local IMPACT_COLOR = Color3.fromRGB(255, 150, 50)

-- Internal Functions --

local function DebugLog(...)
	if DEBUG_MODE then
		print("[ArrowTrapModifierController]", ...)
	end
end

function ArrowTrapModifierController.new(modifierConfig)
	local self = setmetatable(BaseModifierController.new(modifierConfig), ArrowTrapModifierController)

	-- Private state
	self._pendingArrowData = {}
	self._activeIndicators = {}
	self._activeArrows = {}
	self._arrowParticleEmitters = {} -- Cache particle emitters per arrow
	self._animationConnections = {} -- Track RenderStepped connections
	self._cachedArrowTemplate = nil
	self._cachedMapName = nil
	self._cachedPlatformBounds = nil

	return self
end

function ArrowTrapModifierController:Start(mapInstance)
	BaseModifierController.Start(self, mapInstance)
	DebugLog("Started for map:", mapInstance and mapInstance.Name or "unknown")
end

-- Clips a line segment to platform bounds, returns clipped origin and length
function ArrowTrapModifierController:_ClipArrowToPlatform(origin, direction, length)
	if not self._cachedPlatformBounds then
		return origin, length
	end

	local platformCenter = self._cachedPlatformBounds.Center
	local halfX = self._cachedPlatformBounds.SizeX / 2
	local halfZ = self._cachedPlatformBounds.SizeZ / 2

	-- Platform bounds in world space
	local minX = platformCenter.X - halfX
	local maxX = platformCenter.X + halfX
	local minZ = platformCenter.Z - halfZ
	local maxZ = platformCenter.Z + halfZ

	-- Parametric line: P(t) = origin + direction * t, where t goes from 0 to length
	local tMin = 0
	local tMax = length

	-- Check X boundaries
	if math.abs(direction.X) > 0.001 then
		local t1 = (minX - origin.X) / direction.X
		local t2 = (maxX - origin.X) / direction.X
		if t1 > t2 then t1, t2 = t2, t1 end
		tMin = math.max(tMin, t1)
		tMax = math.min(tMax, t2)
	else
		if origin.X < minX or origin.X > maxX then
			return nil, 0
		end
	end

	-- Check Z boundaries
	if math.abs(direction.Z) > 0.001 then
		local t1 = (minZ - origin.Z) / direction.Z
		local t2 = (maxZ - origin.Z) / direction.Z
		if t1 > t2 then t1, t2 = t2, t1 end
		tMin = math.max(tMin, t1)
		tMax = math.min(tMax, t2)
	else
		if origin.Z < minZ or origin.Z > maxZ then
			return nil, 0
		end
	end

	-- Check if there's a valid segment
	if tMin >= tMax then
		return nil, 0
	end

	-- Calculate clipped origin and length
	local clippedOrigin = origin + direction * tMin
	local clippedLength = tMax - tMin

	return clippedOrigin, clippedLength
end

-- Creates a rectangular warning zone along the arrow path (clipped to platform)
function ArrowTrapModifierController:_CreateArrowWarningZone(origin, direction, length, width)
	-- Clip to platform bounds
	local clippedOrigin, clippedLength = self:_ClipArrowToPlatform(origin, direction, length)
	if not clippedOrigin or clippedLength <= 0 then
		return nil
	end

	-- Calculate center of clipped zone
	local center = clippedOrigin + direction * (clippedLength / 2)

	-- Place on platform surface
	if self._cachedPlatformBounds then
		local platformTopY = self._cachedPlatformBounds.Center.Y + (self._cachedPlatformBounds.SizeY / 2) + 0.15
		center = Vector3.new(center.X, platformTopY, center.Z)
	end

	-- Create warning zone part
	local zone = Instance.new("Part")
	zone.Name = "ArrowWarning"
	zone.Size = Vector3.new(clippedLength, 0.3, width)
	zone.Anchored = true
	zone.CanCollide = false
	zone.CanTouch = false
	zone.Material = Enum.Material.Plastic
	zone.Color = IMPACT_COLOR
	zone.Transparency = 0
	zone.CastShadow = false

	-- Highlight
	local highlight = Instance.new("Highlight")
	highlight.OutlineTransparency = 1
	highlight.FillTransparency = 1
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillColor = Color3.new(0.494117, 0, 0)
	highlight.Parent = zone

	-- Orient to face arrow direction
	local right = direction
	local up = Vector3.new(0, 1, 0)
	local forward = right:Cross(up)
	if forward.Magnitude > 0.01 then
		forward = forward.Unit
	else
		forward = Vector3.new(0, 0, 1)
	end
	zone.CFrame = CFrame.fromMatrix(center, right, up, forward)
	zone.Parent = Workspace

	-- Pulsing animation on highlight fill
	local tweenInfo = TweenInfo.new(
		0.4,
		Enum.EasingStyle.Sine,
		Enum.EasingDirection.InOut,
		-1,
		true
	)

	local tween = TweenService:Create(highlight, tweenInfo, {
		FillTransparency = 0.5,
	})
	tween:Play()

	table.insert(self._activeIndicators, zone)
	return zone
end

-- Spawns a visual arrow at its origin (stationary, waiting for resolve)
function ArrowTrapModifierController:_SpawnArrowAtOrigin(arrowData, index)
	if not self._cachedArrowTemplate then
		DebugLog("No arrow template cached, skipping visual")
		return nil
	end

	local arrow = self._cachedArrowTemplate:Clone()
	arrow.Name = "VisualArrow"

	local origin = arrowData.Origin
	local direction = arrowData.Direction

	-- Rotation offset to correct arrow model orientation
	local rotationOffset = CFrame.Angles(math.rad(270), math.rad(90), 0)

	local startCFrame = CFrame.lookAt(origin, origin + direction) * rotationOffset
	arrow:PivotTo(startCFrame)
	arrow.Parent = Workspace

	-- Cache particle emitters for this arrow (avoid multiple GetDescendants calls)
	local emitters = {}
	for _, descendant in ipairs(arrow:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") then
			table.insert(emitters, descendant)
		end
	end
	self._arrowParticleEmitters[index] = emitters

	table.insert(self._activeArrows, arrow)
	return arrow
end

-- Animates an arrow from origin to end
function ArrowTrapModifierController:_AnimateArrow(arrow, arrowData, arrowInterval, travelTime, index)
	task.delay((index - 1) * arrowInterval, function()
		if not arrow or not arrow.Parent then
			return
		end

		local origin = arrowData.Origin
		local direction = arrowData.Direction
		local endPoint = arrowData.EndPoint

		local rotationOffset = CFrame.Angles(math.rad(270), math.rad(90), 0)

		-- Enable particle effects using cached emitters
		local emitters = self._arrowParticleEmitters[index] or {}
		for _, emitter in ipairs(emitters) do
			emitter.Enabled = true
		end

		-- Animate entire model using PivotTo each frame
		local startTime = tick()
		local connection
		connection = RunService.RenderStepped:Connect(function()
			local elapsed = tick() - startTime
			local alpha = math.min(elapsed / travelTime, 1)

			local currentPos = origin:Lerp(endPoint, alpha)
			local currentCFrame = CFrame.lookAt(currentPos, currentPos + direction) * rotationOffset
			arrow:PivotTo(currentCFrame)

			if alpha >= 1 then
				connection:Disconnect()

				-- Disable particle effects using cached emitters
				for _, emitter in ipairs(emitters) do
					emitter.Enabled = false
				end
				Debris:AddItem(arrow, 0.1)
			end
		end)

		-- Track connection for cleanup in case of early termination
		table.insert(self._animationConnections, connection)
	end)
end

-- Clears all arrow warning indicators and state
function ArrowTrapModifierController:_ClearIndicators()
	for _, indicator in ipairs(self._activeIndicators) do
		if indicator.Parent then
			indicator:Destroy()
		end
	end
	self._activeIndicators = {}

	self._pendingArrowData = {}

	-- Disconnect any active animation connections
	for _, connection in ipairs(self._animationConnections) do
		if connection.Connected then
			connection:Disconnect()
		end
	end
	self._animationConnections = {}

	for _, arrow in ipairs(self._activeArrows) do
		if arrow.Parent then
			arrow:Destroy()
		end
	end
	self._activeArrows = {}

	-- Clear cached particle emitters
	self._arrowParticleEmitters = {}

	self._cachedArrowTemplate = nil
	self._cachedMapName = nil
	self._cachedPlatformBounds = nil
end

-- Called when server sends ArrowWarning event
function ArrowTrapModifierController:OnWarning(arrowData, mapName)
	DebugLog("Warning received -", #arrowData, "traps for map:", mapName)

	self:_ClearIndicators()

	-- Cache the arrow template and platform bounds from the map
	self._cachedMapName = mapName
	local mapInstance = Workspace:FindFirstChild(mapName)
	if mapInstance then
		self._cachedArrowTemplate = mapInstance:FindFirstChild("ArrowTemplate")
		if not self._cachedArrowTemplate then
			DebugLog("Warning: No ArrowTemplate found in map")
		end

		-- Get platform bounds for clipping warning zones
		local platform = mapInstance:FindFirstChild("Platform")
		if platform then
			local cframe, size = platform:GetBoundingBox()
			self._cachedPlatformBounds = {
				Center = cframe.Position,
				SizeX = size.X,
				SizeY = size.Y,
				SizeZ = size.Z,
			}
			DebugLog("Platform bounds cached - Center:", cframe.Position, "Size:", size)
		else
			DebugLog("Warning: No Platform found in map")
			self._cachedPlatformBounds = nil
		end
	else
		DebugLog("Warning: Map not found in workspace:", mapName)
	end

	-- Create warning zones for each arrow path
	for _, data in ipairs(arrowData) do
		self:_CreateArrowWarningZone(data.Origin, data.Direction, data.ZoneLength, data.ZoneWidth)
	end

	-- Spawn arrows at their origin positions (stationary)
	for index, data in ipairs(arrowData) do
		self:_SpawnArrowAtOrigin(data, index)
	end

	-- Store for resolve phase
	self._pendingArrowData = arrowData
end

-- Called when server sends ArrowResolve event
function ArrowTrapModifierController:OnResolve(arrowInterval, travelTime)
	DebugLog("Resolve started - animating", #self._activeArrows, "arrows with travel time:", travelTime)

	-- Animate the already-spawned arrows
	for index, arrow in ipairs(self._activeArrows) do
		local arrowData = self._pendingArrowData[index]
		if arrow and arrowData then
			self:_AnimateArrow(arrow, arrowData, arrowInterval, travelTime, index)
		end
	end

	-- Clear warning indicators after a short delay
	task.delay(0.2, function()
		for _, indicator in ipairs(self._activeIndicators) do
			if indicator.Parent then
				indicator:Destroy()
			end
		end
		self._activeIndicators = {}
	end)
end

function ArrowTrapModifierController:Cleanup()
	DebugLog("Cleanup")
	self:_ClearIndicators()
	BaseModifierController.Cleanup(self)
end

return ArrowTrapModifierController
