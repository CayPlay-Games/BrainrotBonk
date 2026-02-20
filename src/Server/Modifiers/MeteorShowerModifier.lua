--[[
	MeteorShowerModifier.lua

	Description:
		Meteor shower modifier - spawns meteors that target player positions
		and apply knockback on impact.
--]]

-- Roblox Services --
local Players = game:GetService("Players")

-- Dependencies --
local BaseModifier = shared("BaseModifier")
local RoundService = shared("RoundService")
local GetRemoteEvent = shared("GetRemoteEvent")

-- Remotes --
local MeteorWarningEvent = GetRemoteEvent("MeteorWarning")
local MeteorResolveEvent = GetRemoteEvent("MeteorResolve")

-- Root --
local MeteorShowerModifier = setmetatable({}, { __index = BaseModifier })
MeteorShowerModifier.__index = MeteorShowerModifier

-- Constants --
-- Internal Functions --

function MeteorShowerModifier.new(settings)
	local self = setmetatable(BaseModifier.new(settings), MeteorShowerModifier)
	self._targetPositions = {}
	return self
end

function MeteorShowerModifier:Start(mapInstance)
	BaseModifier.Start(self, mapInstance)
end

function MeteorShowerModifier:Setup()
	self._isActive = true
	local alivePlayers = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if RoundService:IsPlayerAlive(player) then
			table.insert(alivePlayers, player)
		end
	end

	-- Calculate target positions
	self._targetPositions = {}
	local meteorCount = self.Settings.MeteorCount or 8
	local randomSpread = self.Settings.RandomSpread or 8
	local targetPlayers = self.Settings.TargetPlayers ~= false

	local mapInstance = self:GetMapInstance()
	local platformCenter = Vector3.zero
	local platformExtentsX = 30
	local platformExtentsZ = 30

	if mapInstance then
		local platform = mapInstance:FindFirstChild("Platform")
		if platform then
			-- Get the bounding box of the platform
			local cframe, size = platform:GetBoundingBox()
			platformCenter = cframe.Position
			platformExtentsX = size.X / 2
			platformExtentsZ = size.Z / 2
		else
			-- Fallback to map pivot
			platformCenter = mapInstance:GetPivot().Position
		end
	end

	for _ = 1, meteorCount do
		local targetPos

		if targetPlayers and #alivePlayers > 0 then
			-- Target a random alive player
			local targetPlayer = alivePlayers[math.random(1, #alivePlayers)]
			local character = targetPlayer.Character
			if character then
				local hrp = character:FindFirstChild("HumanoidRootPart")
				if hrp then
					targetPos = hrp.Position + Vector3.new(
						math.random(-randomSpread, randomSpread),
						0,
						math.random(-randomSpread, randomSpread)
					)
				end
			end
		end

		-- Fallback to random position within platform bounds
		if not targetPos then
			local margin = 0.8
			targetPos = platformCenter + Vector3.new(
				(math.random() * 2 - 1) * platformExtentsX * margin,
				0,
				(math.random() * 2 - 1) * platformExtentsZ * margin
			)
		end

		table.insert(self._targetPositions, targetPos)
	end

	local impactRadius = self.Settings.ImpactRadius or 6
	MeteorWarningEvent:FireAllClients(self._targetPositions, impactRadius)
end

function MeteorShowerModifier:Resolve()
	local meteorInterval = self.Settings.MeteorInterval or 0.4
	local meteorSpeed = self.Settings.MeteorSpeed or 80
	local spawnHeight = self.Settings.MeteorSpawnHeight or 100
	local impactRadius = self.Settings.ImpactRadius or 6
	local knockbackForce = self.Settings.KnockbackForce or 50

	local travelTime = spawnHeight / meteorSpeed
	MeteorResolveEvent:FireAllClients(meteorInterval, travelTime)

	-- Spawn meteors with intervals
	for index, targetPos in ipairs(self._targetPositions) do
		task.delay((index - 1) * meteorInterval, function()
			if not self:IsActive() then
				return
			end

			-- Schedule impact at calculated travel time
			task.delay(travelTime, function()
				if not self:IsActive() then
					return
				end
				local impactPos = targetPos
				self:ApplyImpactKnockback(impactPos, impactRadius, knockbackForce)
			end)
		end)
	end
end

function MeteorShowerModifier:ApplyImpactKnockback(impactPos, radius, force)
	for _, player in ipairs(Players:GetPlayers()) do
		local isAlive = RoundService:IsPlayerAlive(player)

		if isAlive then
			local character = player.Character

			if character then
				local hrp = character:FindFirstChild("HumanoidRootPart")
				if hrp then
					local playerPos = hrp.Position
					local horizontalDist = Vector3.new(playerPos.X - impactPos.X, 0, playerPos.Z - impactPos.Z).Magnitude

					if horizontalDist <= radius then
						-- Calculate knockback direction (away from impact, horizontal only)
						local direction = Vector3.new(playerPos.X - impactPos.X, 0, playerPos.Z - impactPos.Z)
						if direction.Magnitude > 0.01 then
							direction = direction.Unit
						else
							-- Player is at exact center, push in random direction
							local angle = math.random() * math.pi * 2
							direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
						end

						-- Scale force by distance (closer = stronger, but minimum 50%)
						local distanceRatio = horizontalDist / radius
						local forceMultiplier = 1 - (distanceRatio * 0.5)
						local scaledForce = force * forceMultiplier

						-- Apply knockback
						local horizontalKnockback = direction * scaledForce
						local upwardForce = scaledForce * 0.5
						local newVelocity = Vector3.new(
							horizontalKnockback.X,
							upwardForce,
							horizontalKnockback.Z
						)
						hrp.AssemblyLinearVelocity = newVelocity
					end
				end
			end
		end
	end
end

function MeteorShowerModifier:GetResolveDuration()
	local meteorCount = self.Settings.MeteorCount or 8
	local meteorInterval = self.Settings.MeteorInterval or 0.4
	local meteorSpeed = self.Settings.MeteorSpeed or 80
	local spawnHeight = self.Settings.MeteorSpawnHeight or 100

	-- Time for last meteor to spawn + time for it to fall
	local lastMeteorSpawnTime = (meteorCount - 1) * meteorInterval
	local travelTime = spawnHeight / meteorSpeed

	-- Add a small buffer for safety
	local totalDuration = lastMeteorSpawnTime + travelTime + 0.5

	return totalDuration
end

function MeteorShowerModifier:Cleanup()
	self._targetPositions = {}
	BaseModifier.Cleanup(self)
end

return MeteorShowerModifier
