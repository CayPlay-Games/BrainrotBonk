--[[
	MeteorShowerModifierController.lua

	Description:
		Client-side controller for meteor shower modifier visuals.
		Handles warning indicators, meteor animations, and impact effects.
--]]

-- Roblox Services --
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

-- Dependencies --
local BaseModifierController = shared("BaseModifierController")

-- Root --
local MeteorShowerModifierController = setmetatable({}, { __index = BaseModifierController })
MeteorShowerModifierController.__index = MeteorShowerModifierController

-- Constants --
local WARNING_INDICATOR_HEIGHT = 0.4
local WARNING_COLOR = Color3.fromRGB(255, 251, 0)
local IMPACT_COLOR = Color3.fromRGB(255, 150, 50)
local METEOR_SPAWN_HEIGHT = 100

-- Internal Functions --

local function DebugLog(...)
	print("[MeteorShowerModifierController]", ...)
end

function MeteorShowerModifierController.new(modifierConfig)
	local self = setmetatable(BaseModifierController.new(modifierConfig), MeteorShowerModifierController)

	-- Private state
	self._activeIndicators = {}
	self._pendingTargets = {}
	self._pendingRadius = 6
	self._activeMeteors = {}
	self._meteorTemplate = nil

	return self
end

function MeteorShowerModifierController:Start(mapInstance)
	BaseModifierController.Start(self, mapInstance)

	-- Cache meteor template
	local assets = ReplicatedStorage:WaitForChild("Assets")
	self._meteorTemplate = assets:WaitForChild("Meteor")

	DebugLog("Started for map:", mapInstance and mapInstance.Name or "unknown")
end

-- Creates a warning indicator circle on the ground
function MeteorShowerModifierController:_CreateWarningIndicator(position, radius)
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

	table.insert(self._activeIndicators, indicator)
	return indicator
end

-- Creates impact visual effect with particles and explosion
function MeteorShowerModifierController:_CreateImpactEffect(position, radius)
	-- Spawn meteor particles at impact point
	local meteorParticles = self._meteorTemplate:FindFirstChild("MeteorParticles")
	if meteorParticles then
		local particles = meteorParticles:Clone()
		particles:PivotTo(CFrame.new(position))
		particles.Parent = Workspace

		-- Find and emit particles
		for _, descendant in ipairs(particles:GetDescendants()) do
			if descendant:IsA("ParticleEmitter") then
				descendant:Emit(50)
			end
		end

		Debris:AddItem(particles, 2)
	end

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
end

-- Creates a visual meteor that falls from the sky
function MeteorShowerModifierController:_CreateFallingMeteor(targetPosition, impactRadius, meteorInterval, travelTime, index)
	task.delay((index - 1) * meteorInterval, function()
		if not self:IsActive() then
			return
		end

		local meteor = self._meteorTemplate:Clone()
		meteor.Name = "VisualMeteor"

		-- Track this meteor for cleanup
		table.insert(self._activeMeteors, meteor)

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

		-- Tween falling animation
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

			-- Create impact effect
			self:_CreateImpactEffect(targetPosition, impactRadius)

			-- Remove warning indicator at this position
			for i = #self._activeIndicators, 1, -1 do
				local indicator = self._activeIndicators[i]
				if indicator.Parent then
					local indicatorPos = indicator.Position
					local distance = (Vector3.new(indicatorPos.X, 0, indicatorPos.Z) - Vector3.new(targetPosition.X, 0, targetPosition.Z)).Magnitude
					if distance < impactRadius + 5 then
						indicator:Destroy()
						table.remove(self._activeIndicators, i)
						break
					end
				end
			end
		end)
	end)
end

-- Clears all warning indicators and meteor state
function MeteorShowerModifierController:_ClearIndicators()
	for _, indicator in ipairs(self._activeIndicators) do
		if indicator.Parent then
			indicator:Destroy()
		end
	end
	self._activeIndicators = {}

	-- Clear pending data
	self._pendingTargets = {}
	self._pendingRadius = 6

	-- Destroy any active visual meteors
	for _, meteor in ipairs(self._activeMeteors) do
		if meteor.Parent then
			meteor:Destroy()
		end
	end
	self._activeMeteors = {}
end

-- Called when server sends MeteorWarning event
function MeteorShowerModifierController:OnWarning(targetPositions, impactRadius)
	DebugLog("Warning received -", #targetPositions, "targets")

	-- Clear any previous warnings
	self:_ClearIndicators()

	-- Create warning indicators at each target
	for _, pos in ipairs(targetPositions) do
		self:_CreateWarningIndicator(pos, impactRadius)
	end

	-- Store for resolve phase
	self._pendingTargets = targetPositions
	self._pendingRadius = impactRadius
end

-- Called when server sends MeteorResolve event
function MeteorShowerModifierController:OnResolve(meteorInterval, travelTime)
	DebugLog("Resolve started - spawning", #self._pendingTargets, "meteors with travel time:", travelTime)

	-- Spawn falling visual meteors
	for index, targetPos in ipairs(self._pendingTargets) do
		self:_CreateFallingMeteor(targetPos, self._pendingRadius, meteorInterval, travelTime, index)
	end
end

function MeteorShowerModifierController:Cleanup()
	DebugLog("Cleanup")
	self:_ClearIndicators()
	BaseModifierController.Cleanup(self)
end

return MeteorShowerModifierController
