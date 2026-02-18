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
local MeteorImpactEvent = GetRemoteEvent("MeteorImpact")
local MeteorResolveEvent = GetRemoteEvent("MeteorResolve")

-- Root --
local MeteorShowerModifier = setmetatable({}, { __index = BaseModifier })
MeteorShowerModifier.__index = MeteorShowerModifier

-- Internal Functions --

local function DebugLog(...)
	print("[MeteorShowerModifier]", ...)
end

function MeteorShowerModifier.new(settings)
	local self = setmetatable(BaseModifier.new(settings), MeteorShowerModifier)

	-- State
	self._targetPositions = {}
	self._connections = {}

	return self
end

function MeteorShowerModifier:Init(mapInstance)
	BaseModifier.Init(self, mapInstance)
	DebugLog("Initialized for map:", mapInstance and mapInstance.Name or "unknown")
end

-- Setup phase: Calculate target positions and send warnings to clients
function MeteorShowerModifier:Setup()
	DebugLog("Setup - calculating meteor targets")

	-- Re-activate for this round (Cleanup sets _isActive to false)
	self._isActive = true

	-- Get alive players
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

	-- Get platform bounds for random positioning
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
			DebugLog("Platform bounds - Center:", platformCenter, "Extents:", platformExtentsX, platformExtentsZ)
		else
			-- Fallback to map pivot
			platformCenter = mapInstance:GetPivot().Position
			DebugLog("No Platform found, using map pivot:", platformCenter)
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
			-- Random position within platform extents (with some margin)
			local margin = 0.8 -- Use 80% of platform to avoid edges
			targetPos = platformCenter + Vector3.new(
				(math.random() * 2 - 1) * platformExtentsX * margin,
				0,
				(math.random() * 2 - 1) * platformExtentsZ * margin
			)
		end

		table.insert(self._targetPositions, targetPos)
	end

	-- Send warning to all clients
	local impactRadius = self.Settings.ImpactRadius or 6
	MeteorWarningEvent:FireAllClients(self._targetPositions, impactRadius)

	DebugLog("Setup complete -", #self._targetPositions, "meteor targets calculated")
end

-- Resolve phase: Spawn meteors and apply effects
function MeteorShowerModifier:Resolve()
	DebugLog("Resolve - spawning meteors")

	local meteorInterval = self.Settings.MeteorInterval or 0.4
	local meteorSpeed = self.Settings.MeteorSpeed or 80
	local spawnHeight = 100
	local impactRadius = self.Settings.ImpactRadius or 6
	local knockbackForce = self.Settings.KnockbackForce or 50

	-- Calculate travel time (distance / speed)
	local travelTime = spawnHeight / meteorSpeed

	-- Notify clients to start spawning visual meteors (include travel time for sync)
	MeteorResolveEvent:FireAllClients(meteorInterval, travelTime)

	-- Spawn meteors with intervals (server handles timing and knockback, client handles visuals)
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

				-- Use target position as impact point
				local impactPos = targetPos
				DebugLog("Meteor impact at", impactPos, "radius:", impactRadius, "force:", knockbackForce)

				-- Apply knockback to nearby players
				self:ApplyImpactKnockback(impactPos, impactRadius, knockbackForce)

				-- Notify clients for visual effects
				MeteorImpactEvent:FireAllClients(impactPos, impactRadius)
			end)
		end)
	end
end

-- Apply knockback to players within impact radius
function MeteorShowerModifier:ApplyImpactKnockback(impactPos, radius, force)
	DebugLog("Checking knockback - Impact:", impactPos, "Radius:", radius, "Force:", force)

	for _, player in ipairs(Players:GetPlayers()) do
		local isAlive = RoundService:IsPlayerAlive(player)
		DebugLog("Player:", player.Name, "IsAlive:", isAlive)

		if isAlive then
			local character = player.Character
			DebugLog("Character:", character and character.Name or "nil")

			if character then
				local hrp = character:FindFirstChild("HumanoidRootPart")
				DebugLog("HRP:", hrp and hrp.Position or "nil")

				if hrp then
					-- Use horizontal distance only (ignore Y difference)
					local playerPos = hrp.Position
					local horizontalDist = Vector3.new(playerPos.X - impactPos.X, 0, playerPos.Z - impactPos.Z).Magnitude
					DebugLog("Horizontal distance:", horizontalDist, "vs radius:", radius)

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
						local forceMultiplier = 1 - (distanceRatio * 0.5) -- Range: 1.0 at center, 0.5 at edge
						local scaledForce = force * forceMultiplier

						-- Apply horizontal knockback
						local horizontalKnockback = direction * scaledForce

						-- Add strong upward component for dramatic launch
						local upwardForce = scaledForce * 0.5

						-- Set velocity directly for more consistent knockback
						local newVelocity = Vector3.new(
							horizontalKnockback.X,
							upwardForce,
							horizontalKnockback.Z
						)
						hrp.AssemblyLinearVelocity = newVelocity

						DebugLog("Applied knockback to", player.Name, "Force:", scaledForce, "NewVel:", newVelocity)
					else
						DebugLog("Player", player.Name, "too far from impact")
					end
				end
			end
		end
	end
end

-- Calculate the actual duration needed for all meteors to resolve
function MeteorShowerModifier:GetResolveDuration()
	local meteorCount = self.Settings.MeteorCount or 8
	local meteorInterval = self.Settings.MeteorInterval or 0.4
	local meteorSpeed = self.Settings.MeteorSpeed or 80
	local spawnHeight = 100

	-- Time for last meteor to spawn + time for it to fall
	local lastMeteorSpawnTime = (meteorCount - 1) * meteorInterval
	local travelTime = spawnHeight / meteorSpeed

	-- Add a small buffer for safety
	local totalDuration = lastMeteorSpawnTime + travelTime + 0.5

	DebugLog("Calculated resolve duration:", totalDuration, "seconds")
	return totalDuration
end

function MeteorShowerModifier:Cleanup()
	DebugLog("Cleanup")

	-- Disconnect all connections
	for _, connection in ipairs(self._connections) do
		if connection.Connected then
			connection:Disconnect()
		end
	end
	self._connections = {}

	-- Clear state
	self._targetPositions = {}

	BaseModifier.Cleanup(self)
end

return MeteorShowerModifier
