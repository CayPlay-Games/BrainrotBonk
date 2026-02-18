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

	-- Connect to remote events
	table.insert(_Connections, MeteorWarningEvent.OnClientEvent:Connect(OnMeteorWarning))
	table.insert(_Connections, MeteorResolveEvent.OnClientEvent:Connect(OnMeteorResolve))
	table.insert(_Connections, MeteorImpactEvent.OnClientEvent:Connect(OnMeteorImpact))

	-- Listen for state changes to cleanup on round end
	PromiseWaitForDataStream(ClientDataStream.RoundState):andThen(function(roundState)
		table.insert(_Connections, roundState.State:Changed(function(newState)
			if newState == "Waiting" or newState == "RoundEnd" then
				ClearWarningIndicators()
			end
		end))
	end)

	DebugLog("Initialized")
end

-- Return Module --
return ModifierController
