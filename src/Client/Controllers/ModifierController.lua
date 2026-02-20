--[[
	ModifierController.lua

	Description:
		Client-side controller for modifier visual effects.
		Handles warning indicators, meteor animations, impact effects, etc.
--]]

-- Root --
local ModifierController = {}

-- Roblox Services --
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

-- Dependencies --
local ClientDataStream = shared("ClientDataStream")
local PromiseWaitForDataStream = shared("PromiseWaitForDataStream")
local GetRemoteEvent = shared("GetRemoteEvent")

-- Remotes --
local MeteorWarningEvent = GetRemoteEvent("MeteorWarning")
local MeteorImpactEvent = GetRemoteEvent("MeteorImpact")
local MeteorResolveEvent = GetRemoteEvent("MeteorResolve")
local ArrowWarningEvent = GetRemoteEvent("ArrowWarning")
local ArrowResolveEvent = GetRemoteEvent("ArrowResolve")

-- Assets --
local Assets = ReplicatedStorage:WaitForChild("Assets")
local MeteorTemplate = Assets:WaitForChild("Meteor")

-- Constants --
local WARNING_INDICATOR_HEIGHT = 0.4
local WARNING_COLOR = Color3.fromRGB(255, 251, 0)
local IMPACT_COLOR = Color3.fromRGB(255, 150, 50)
local METEOR_SPAWN_HEIGHT = 100

-- Private Variables --
local _ActiveIndicators = {}
local _Connections = {}
local _PendingMeteorTargets = {}
local _PendingImpactRadius = 6
local _ActiveMeteors = {}

-- Arrow Trap State --
local _PendingArrowData = {}
local _ActiveArrowIndicators = {}
local _ActiveArrows = {}
local _CachedArrowTemplate = nil
local _CachedMapName = nil
local _CachedPlatformBounds = nil -- {Center, SizeX, SizeZ}

-- Internal Functions --

local function DebugLog(...)
	print("[ModifierController]", ...)
end

-- Creates a warning indicator circle on the ground
local function CreateWarningIndicator(position, radius)
	local indicator = Instance.new("Part")
	indicator.Name = "MeteorWarning"
	indicator.Shape = Enum.PartType.Cylinder
	indicator.Size = Vector3.new(WARNING_INDICATOR_HEIGHT, radius * 2, radius * 2)
	local heightOffset = Vector3.new(0, 2, 0)
	indicator.CFrame = CFrame.new(position + heightOffset) * CFrame.Angles(0, 0, math.rad(90))
	indicator.Anchored = true
	indicator.CanCollide = false
	indicator.CanTouch = false
	indicator.Material = Enum.Material.Neon
	indicator.Color = WARNING_COLOR
	indicator.Transparency = 0
	indicator.CastShadow = false
	indicator.Parent = Workspace

	-- Pulsing animation
	local tweenInfo = TweenInfo.new(
		0.5,
		Enum.EasingStyle.Sine,
		Enum.EasingDirection.InOut,
		-1, -- Repeat forever
		true -- Reverse
	)

	local tween = TweenService:Create(indicator, tweenInfo, {
		Color = Color3.fromRGB(255, 115, 0),
		Size = Vector3.new(WARNING_INDICATOR_HEIGHT, radius * 2.2, radius * 2.2),
	})
	tween:Play()

	table.insert(_ActiveIndicators, indicator)
	return indicator
end

-- Forward declaration for CreateImpactEffect (assigned below)
local CreateImpactEffect = nil

-- Creates a visual meteor that falls from the sky
local function CreateFallingMeteor(targetPosition, impactRadius, meteorInterval, travelTime, index)
	task.delay((index - 1) * meteorInterval, function()
		local meteor = MeteorTemplate:Clone()
		meteor.Name = "VisualMeteor"

		-- Track this meteor for cleanup
		table.insert(_ActiveMeteors, meteor)

		-- Position at spawn height above target
		local spawnPos = targetPosition + Vector3.new(0, METEOR_SPAWN_HEIGHT, 0)
		meteor:PivotTo(CFrame.new(spawnPos))
		meteor.Parent = Workspace

		-- Enable all particle emitters while falling
		local particleEmitters = {}
		for _, descendant in ipairs(meteor:GetDescendants()) do
			if descendant:IsA("ParticleEmitter") then
				descendant.Enabled = true
				table.insert(particleEmitters, descendant)
			end
		end

		-- Tween falling animation (use server-provided travel time for sync)
		local tweenInfo = TweenInfo.new(
			travelTime,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.In
		)

		local endPos = targetPosition
		local tween = TweenService:Create(meteor.PrimaryPart or meteor:FindFirstChildWhichIsA("BasePart"), tweenInfo, {
			CFrame = CFrame.new(endPos)
		})

		tween:Play()
		tween.Completed:Connect(function()
			-- Disable particles and clean up
			for _, emitter in ipairs(particleEmitters) do
				emitter.Enabled = false
			end
			Debris:AddItem(meteor, 0.1)

			-- Create impact effect immediately when this meteor lands
			CreateImpactEffect(targetPosition, impactRadius)

			-- Remove warning indicator at this position
			for i = #_ActiveIndicators, 1, -1 do
				local indicator = _ActiveIndicators[i]
				if indicator.Parent then
					local indicatorPos = indicator.Position
					local distance = (Vector3.new(indicatorPos.X, 0, indicatorPos.Z) - Vector3.new(targetPosition.X, 0, targetPosition.Z)).Magnitude
					if distance < impactRadius + 5 then -- Small tolerance for position matching
						indicator:Destroy()
						table.remove(_ActiveIndicators, i)
						break
					end
				end
			end
		end)
	end)
end

-- Creates impact visual effect with particles and explosion
CreateImpactEffect = function(position, radius)
	-- Spawn meteor particles at impact point
	local meteor = MeteorTemplate:FindFirstChild("MeteorParticles"):Clone()
	meteor:PivotTo(CFrame.new(position))
	meteor.Parent = Workspace

	-- Find and emit particles (search for ParticleEmitter descendants)
	for _, descendant in ipairs(meteor:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") then
			descendant:Emit(50)
		end
	end

	-- Clean up meteor model after particles finish
	Debris:AddItem(meteor, 2)

	-- Create explosion visual (expanding sphere)
	local explosion = Instance.new("Part")
	explosion.Name = "MeteorExplosion"
	explosion.Shape = Enum.PartType.Ball
	explosion.Size = Vector3.new(1, 1, 1)
	explosion.Position = position
	explosion.Anchored = true
	explosion.CanCollide = false
	explosion.Material = Enum.Material.Neon
	explosion.Color = IMPACT_COLOR
	explosion.Transparency = 0.3
	explosion.Parent = Workspace

	-- Expand and fade animation
	local tweenInfo = TweenInfo.new(
		0.4,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)

	local tween = TweenService:Create(explosion, tweenInfo, {
		Size = Vector3.new(radius * 2, radius * 2, radius * 2),
		Transparency = 1,
	})

	tween:Play()
	tween.Completed:Connect(function()
		explosion:Destroy()
	end)

	-- Expanding ring effect on ground
	local ring = Instance.new("Part")
	ring.Name = "ImpactRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.2, 1, 1)
	ring.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	ring.Anchored = true
	ring.CanCollide = false
	ring.Material = Enum.Material.Neon
	ring.Color = IMPACT_COLOR
	ring.Transparency = 0
	ring.Parent = Workspace

	local ringTweenInfo = TweenInfo.new(
		0.5,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)

	local ringTween = TweenService:Create(ring, ringTweenInfo, {
		Size = Vector3.new(0.2, radius * 3, radius * 3),
		Transparency = 1,
	})

	ringTween:Play()
	ringTween.Completed:Connect(function()
		ring:Destroy()
	end)

	-- -- Screen shake (simple camera effect)
	-- local camera = Workspace.CurrentCamera
	-- if camera then
	-- 	task.spawn(function()
	-- 		for _ = 1, 5 do
	-- 			local offset = Vector3.new(
	-- 				math.random(-10, 10) / 100,
	-- 				math.random(-10, 10) / 100,
	-- 				0
	-- 			)
	-- 			camera.CFrame = camera.CFrame * CFrame.new(offset)
	-- 			task.wait(0.03)
	-- 		end
	-- 	end)
	-- end
end

-- Clears all warning indicators and pending meteor data
local function ClearWarningIndicators()
	for _, indicator in ipairs(_ActiveIndicators) do
		if indicator.Parent then
			indicator:Destroy()
		end
	end
	_ActiveIndicators = {}

	-- Clear pending meteor data
	_PendingMeteorTargets = {}
	_PendingImpactRadius = 6

	-- Destroy any active visual meteors
	for _, meteor in ipairs(_ActiveMeteors) do
		if meteor.Parent then
			meteor:Destroy()
		end
	end
	_ActiveMeteors = {}
end

-- ==================== ARROW TRAP FUNCTIONS ====================

-- Clips a line segment to platform bounds, returns clipped origin and length
local function ClipArrowToPlataform(origin, direction, length)
	if not _CachedPlatformBounds then
		return origin, length
	end

	local platformCenter = _CachedPlatformBounds.Center
	local halfX = _CachedPlatformBounds.SizeX / 2
	local halfZ = _CachedPlatformBounds.SizeZ / 2

	-- Platform bounds in world space
	local minX = platformCenter.X - halfX
	local maxX = platformCenter.X + halfX
	local minZ = platformCenter.Z - halfZ
	local maxZ = platformCenter.Z + halfZ

	-- Parametric line: P(t) = origin + direction * t, where t goes from 0 to length
	-- Find t values where line intersects each boundary
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
		-- Line is parallel to X boundaries
		if origin.X < minX or origin.X > maxX then
			return nil, 0 -- Completely outside
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
		-- Line is parallel to Z boundaries
		if origin.Z < minZ or origin.Z > maxZ then
			return nil, 0 -- Completely outside
		end
	end

	-- Check if there's a valid segment
	if tMin >= tMax then
		return nil, 0 -- No intersection
	end

	-- Calculate clipped origin and length
	local clippedOrigin = origin + direction * tMin
	local clippedLength = tMax - tMin

	return clippedOrigin, clippedLength
end

-- Creates a rectangular warning zone along the arrow path (clipped to platform)
local function CreateArrowWarningZone(origin, direction, length, width)
	-- Clip to platform bounds
	local clippedOrigin, clippedLength = ClipArrowToPlataform(origin, direction, length)
	if not clippedOrigin or clippedLength <= 0 then
		return nil -- Zone is completely outside platform
	end

	-- Calculate center of clipped zone
	local center = clippedOrigin + direction * (clippedLength / 2)

	-- Place on platform surface (use platform top Y position)
	if _CachedPlatformBounds then
		local platformTopY = _CachedPlatformBounds.Center.Y + (_CachedPlatformBounds.SizeY / 2) + 0.15
		center = Vector3.new(center.X, platformTopY, center.Z)
	end

	-- Create warning zone part (rectangular box)
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
	--highlight.OutlineColor = Color3.new(1, 0, 0)
	highlight.OutlineTransparency = 1
	highlight.FillTransparency = 1
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillColor = Color3.new(0.494117, 0, 0)
	highlight.Parent = zone

	-- Orient to face arrow direction (X axis along arrow path)
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
		-1, -- Repeat forever
		true -- Reverse
	)

	local tween = TweenService:Create(highlight, tweenInfo, {
		FillTransparency = 0.5,
	})
	tween:Play()

	table.insert(_ActiveArrowIndicators, zone)
	return zone
end

-- Spawns a visual arrow at its origin (stationary, waiting for resolve)
local function SpawnArrowAtOrigin(arrowData)
	-- Get the arrow template
	if not _CachedArrowTemplate then
		DebugLog("No arrow template cached, skipping visual")
		return nil
	end

	local arrow = _CachedArrowTemplate:Clone()
	arrow.Name = "VisualArrow"

	-- Position at origin, facing travel direction
	local origin = arrowData.Origin
	local direction = arrowData.Direction

	-- Rotation offset to correct arrow model orientation (90 degrees X, 90 degrees Y)
	local rotationOffset = CFrame.Angles(math.rad(270), math.rad(90), 0)

	-- Create CFrame facing direction with rotation offset
	local startCFrame = CFrame.lookAt(origin, origin + direction) * rotationOffset
	arrow:PivotTo(startCFrame)
	arrow.Parent = Workspace

	table.insert(_ActiveArrows, arrow)
	return arrow
end

-- Animates an arrow from origin to end
local function AnimateArrow(arrow, arrowData, arrowInterval, travelTime, index)
	task.delay((index - 1) * arrowInterval, function()
		if not arrow or not arrow.Parent then
			return
		end

		local origin = arrowData.Origin
		local direction = arrowData.Direction
		local endPoint = arrowData.EndPoint

		-- Rotation offset to correct arrow model orientation
		local rotationOffset = CFrame.Angles(math.rad(270), math.rad(90), 0)

		-- Enable particle effects (if any)
		for _, descendant in ipairs(arrow:GetDescendants()) do
			if descendant:IsA("ParticleEmitter") then
				descendant.Enabled = true
			end
		end

		-- Animate entire model using PivotTo each frame
		local startTime = tick()
		local connection
		connection = game:GetService("RunService").RenderStepped:Connect(function()
			local elapsed = tick() - startTime
			local alpha = math.min(elapsed / travelTime, 1)

			-- Lerp position from start to end
			local currentPos = origin:Lerp(endPoint, alpha)
			local currentCFrame = CFrame.lookAt(currentPos, currentPos + direction) * rotationOffset
			arrow:PivotTo(currentCFrame)

			-- Check if animation is complete
			if alpha >= 1 then
				connection:Disconnect()

				-- Disable particles
				for _, descendant in ipairs(arrow:GetDescendants()) do
					if descendant:IsA("ParticleEmitter") then
						descendant.Enabled = false
					end
				end
				Debris:AddItem(arrow, 0.1)
			end
		end)
	end)
end

-- Clears all arrow warning indicators and state
local function ClearArrowIndicators()
	for _, indicator in ipairs(_ActiveArrowIndicators) do
		if indicator.Parent then
			indicator:Destroy()
		end
	end
	_ActiveArrowIndicators = {}

	-- Clear pending arrow data
	_PendingArrowData = {}

	-- Destroy any active visual arrows
	for _, arrow in ipairs(_ActiveArrows) do
		if arrow.Parent then
			arrow:Destroy()
		end
	end
	_ActiveArrows = {}

	-- Clear cached template reference
	_CachedArrowTemplate = nil
	_CachedMapName = nil
	_CachedPlatformBounds = nil
end

-- Handles arrow warning from server
local function OnArrowWarning(arrowData, mapName)
	DebugLog("Arrow warning received -", #arrowData, "traps for map:", mapName)

	ClearArrowIndicators()

	-- Cache the arrow template and platform bounds from the map
	_CachedMapName = mapName
	local mapInstance = Workspace:FindFirstChild(mapName)
	if mapInstance then
		_CachedArrowTemplate = mapInstance:FindFirstChild("ArrowTemplate")
		if not _CachedArrowTemplate then
			DebugLog("Warning: No ArrowTemplate found in map")
		end

		-- Get platform bounds for clipping warning zones
		local platform = mapInstance:FindFirstChild("Platform")
		if platform then
			local cframe, size = platform:GetBoundingBox()
			_CachedPlatformBounds = {
				Center = cframe.Position,
				SizeX = size.X,
				SizeY = size.Y,
				SizeZ = size.Z,
			}
			DebugLog("Platform bounds cached - Center:", cframe.Position, "Size:", size)
		else
			DebugLog("Warning: No Platform found in map")
			_CachedPlatformBounds = nil
		end
	else
		DebugLog("Warning: Map not found in workspace:", mapName)
	end

	-- Create warning zones for each arrow path (clipped to platform)
	for _, data in ipairs(arrowData) do
		CreateArrowWarningZone(data.Origin, data.Direction, data.ZoneLength, data.ZoneWidth)
	end

	-- Spawn arrows at their origin positions (stationary)
	for _, data in ipairs(arrowData) do
		SpawnArrowAtOrigin(data)
	end

	-- Store for resolve phase
	_PendingArrowData = arrowData
end

-- Handles arrow resolve phase - animate the already-spawned arrows
local function OnArrowResolve(arrowInterval, travelTime)
	DebugLog("Arrow resolve started - animating", #_ActiveArrows, "arrows with travel time:", travelTime)

	-- Animate the already-spawned arrows
	for index, arrow in ipairs(_ActiveArrows) do
		local arrowData = _PendingArrowData[index]
		if arrow and arrowData then
			AnimateArrow(arrow, arrowData, arrowInterval, travelTime, index)
		end
	end

	-- Clear warning indicators after a short delay (first arrow fires)
	task.delay(0.2, function()
		for _, indicator in ipairs(_ActiveArrowIndicators) do
			if indicator.Parent then
				indicator:Destroy()
			end
		end
		_ActiveArrowIndicators = {}
	end)
end

-- ==================== METEOR FUNCTIONS ====================

-- Handles meteor warning from server
local function OnMeteorWarning(targetPositions, impactRadius)
	DebugLog("Meteor warning received -", #targetPositions, "targets")

	ClearWarningIndicators()

	-- Create warning indicators at each target
	for _, pos in ipairs(targetPositions) do
		CreateWarningIndicator(pos, impactRadius)
	end

	-- Store target positions for meteor spawning during resolve phase
	_PendingMeteorTargets = targetPositions
	_PendingImpactRadius = impactRadius
end

-- Handles meteor resolve phase - spawn falling visual meteors
local function OnMeteorResolve(meteorInterval, travelTime)
	DebugLog("Meteor resolve started - spawning", #_PendingMeteorTargets, "meteors with travel time:", travelTime)

	-- Spawn falling visual meteors (use server-provided travel time for knockback sync)
	for index, targetPos in ipairs(_PendingMeteorTargets) do
		CreateFallingMeteor(targetPos, _PendingImpactRadius, meteorInterval, travelTime, index)
	end
end

-- Handles meteor impact from server (currently unused - client handles visuals and cleanup)
local function OnMeteorImpact(_position, _radius)
	-- Note: Impact visual and indicator cleanup are now handled by CreateFallingMeteor
	-- when the tween completes. This handler is kept for potential future use.
end

-- Cleanup all connections and effects
local function Cleanup()
	ClearWarningIndicators()

	for _, connection in ipairs(_Connections) do
		if connection.Connected then
			connection:Disconnect()
		end
	end
	_Connections = {}
end

-- API Functions --

-- Initializers --
function ModifierController:Init()
	DebugLog("Initializing...")

	-- Connect to remote events (Meteor)
	table.insert(_Connections, MeteorWarningEvent.OnClientEvent:Connect(OnMeteorWarning))
	table.insert(_Connections, MeteorResolveEvent.OnClientEvent:Connect(OnMeteorResolve))
	table.insert(_Connections, MeteorImpactEvent.OnClientEvent:Connect(OnMeteorImpact))

	-- Connect to remote events (Arrow Trap)
	table.insert(_Connections, ArrowWarningEvent.OnClientEvent:Connect(OnArrowWarning))
	table.insert(_Connections, ArrowResolveEvent.OnClientEvent:Connect(OnArrowResolve))

	-- Listen for state changes to cleanup on round end
	PromiseWaitForDataStream(ClientDataStream.RoundState):andThen(function(roundState)
		table.insert(_Connections, roundState.State:Changed(function(newState)
			if newState == "Waiting" or newState == "RoundEnd" then
				ClearWarningIndicators()
				ClearArrowIndicators()
			end
		end))
	end)

	DebugLog("Initialized")
end

-- Return Module --
return ModifierController
