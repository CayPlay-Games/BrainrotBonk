--[[
	ArrowTrapModifier.lua

	Description:
		Arrow trap modifier - fires arrows from predefined spawn points
		that push players in their path. Arrow movement is animated client-side.
--]]

-- Roblox Services --
local Players = game:GetService("Players")

-- Dependencies --
local BaseModifier = shared("BaseModifier")
local RoundService = shared("RoundService")
local GetRemoteEvent = shared("GetRemoteEvent")

-- Remotes --
local ArrowWarningEvent = GetRemoteEvent("ArrowWarning")
local ArrowResolveEvent = GetRemoteEvent("ArrowResolve")

-- Root --
local ArrowTrapModifier = setmetatable({}, { __index = BaseModifier })
ArrowTrapModifier.__index = ArrowTrapModifier

-- Internal Functions --

local function DebugLog(...)
	print("[ArrowTrapModifier]", ...)
end

function ArrowTrapModifier.new(settings)
	local self = setmetatable(BaseModifier.new(settings), ArrowTrapModifier)

	-- State
	self._arrowSpawns = {} -- All available spawn points from map
	self._selectedSpawns = {} -- Spawns selected for this round
	self._connections = {}

	return self
end

function ArrowTrapModifier:Start(mapInstance)
	BaseModifier.Start(self, mapInstance)

	-- Find and cache all arrow spawn points
	local spawnsFolder = mapInstance:FindFirstChild("ArrowSpawns")
	if spawnsFolder then
		for _, spawn in ipairs(spawnsFolder:GetChildren()) do
			if spawn:IsA("BasePart") then
				table.insert(self._arrowSpawns, spawn)
			end
		end
	end

	DebugLog("Initialized for map:", mapInstance and mapInstance.Name or "unknown", "with", #self._arrowSpawns, "arrow spawns")
end

-- Setup phase: Select arrow traps and send warnings to clients
function ArrowTrapModifier:Setup()
	DebugLog("Setup - selecting arrow traps")

	-- Re-activate for this round (Cleanup sets _isActive to false)
	self._isActive = true

	-- Select random spawns based on TrapCount range settings
	self._selectedSpawns = {}
	local maxAvailable = #self._arrowSpawns
	local trapCountMin = self.Settings.TrapCountMin or 1
	local trapCountMax = self.Settings.TrapCountMax or 0

	-- If max is 0 or greater than available, use all available spawns as max
	if trapCountMax <= 0 or trapCountMax > maxAvailable then
		trapCountMax = maxAvailable
	end

	-- Clamp min to valid range
	trapCountMin = math.max(0, math.min(trapCountMin, trapCountMax))

	-- Pick random count in range
	local trapCount = math.random(trapCountMin, trapCountMax)

	DebugLog("Selecting", trapCount, "traps from range [", trapCountMin, "-", trapCountMax, "]")

	-- Shuffle and select spawns
	local availableSpawns = table.clone(self._arrowSpawns)
	for _ = 1, trapCount do
		if #availableSpawns == 0 then
			break
		end
		local index = math.random(1, #availableSpawns)
		table.insert(self._selectedSpawns, availableSpawns[index])
		table.remove(availableSpawns, index)
	end

	-- Build arrow data for client
	local arrowData = {}
	local zoneLength = self.Settings.ZoneLength or 100
	local zoneWidth = self.Settings.ZoneWidth or 4
	local originOffset = self.Settings.OriginOffset or 0

	for _, spawn in ipairs(self._selectedSpawns) do
		local origin = spawn.Position + spawn.CFrame.LookVector * originOffset
		local direction = spawn.CFrame.LookVector
		local endPoint = origin + direction * zoneLength

		table.insert(arrowData, {
			Origin = origin,
			Direction = direction,
			EndPoint = endPoint,
			ZoneWidth = zoneWidth,
			ZoneLength = zoneLength,
		})
	end

	-- Get map name for client to find ArrowTemplate
	local mapInstance = self:GetMapInstance()
	local mapName = mapInstance and mapInstance.Name or ""

	-- Send warning to all clients
	ArrowWarningEvent:FireAllClients(arrowData, mapName)

	DebugLog("Setup complete -", #self._selectedSpawns, "arrow traps selected")
end

-- Resolve phase: Fire arrows and apply knockback
function ArrowTrapModifier:Resolve()
	DebugLog("Resolve - firing arrows")

	local arrowInterval = self.Settings.ArrowInterval or 0.5
	local arrowSpeed = self.Settings.ArrowSpeed or 60
	local zoneLength = self.Settings.ZoneLength or 100
	local zoneWidth = self.Settings.ZoneWidth or 4
	local knockbackForce = self.Settings.KnockbackForce or 40
	local originOffset = self.Settings.OriginOffset or 0

	-- Calculate travel time
	local travelTime = zoneLength / arrowSpeed

	-- Notify clients to start arrow animations
	ArrowResolveEvent:FireAllClients(arrowInterval, travelTime)

	-- Fire arrows with intervals
	for index, spawn in ipairs(self._selectedSpawns) do
		task.delay((index - 1) * arrowInterval, function()
			if not self:IsActive() then
				return
			end

			local origin = spawn.Position + spawn.CFrame.LookVector * originOffset
			local direction = spawn.CFrame.LookVector

			-- Simulate arrow travel and check for collisions
			self:SimulateArrowTravel(origin, direction, zoneLength, zoneWidth, arrowSpeed, knockbackForce)
		end)
	end
end

-- Simulate arrow traveling and check for player collisions
function ArrowTrapModifier:SimulateArrowTravel(origin, direction, zoneLength, zoneWidth, speed, knockbackForce)
	local startTime = tick()
	local travelTime = zoneLength / speed

	-- Track players already hit by this arrow
	local hitPlayers = {}

	-- Use a task to check collisions over time
	task.spawn(function()
		while true do
			if not self:IsActive() then
				break
			end

			local elapsed = tick() - startTime
			if elapsed >= travelTime then
				break
			end

			-- Calculate current arrow position
			local distanceTraveled = elapsed * speed
			local currentPos = origin + direction * distanceTraveled

			-- Check for player collisions
			for _, player in ipairs(Players:GetPlayers()) do
				if hitPlayers[player] then
					continue
				end
				if not RoundService:IsPlayerAlive(player) then
					continue
				end

				local character = player.Character
				if not character then
					continue
				end

				local hrp = character:FindFirstChild("HumanoidRootPart")
				if not hrp then
					continue
				end

				-- Check if player is within arrow's hitbox
				local playerPos = hrp.Position
				local toPlayer = playerPos - currentPos

				-- Project onto arrow path to get perpendicular distance
				local alongPath = toPlayer:Dot(direction)
				local perpendicular = toPlayer - direction * alongPath
				local perpendicularDist = perpendicular.Magnitude

				-- Check if within zone width and within small window along path
				local hitWindow = 4 -- studs ahead/behind current position to check
				if perpendicularDist <= zoneWidth / 2 and math.abs(alongPath) <= hitWindow then
					-- Apply knockback in arrow direction
					self:ApplyArrowKnockback(hrp, direction, knockbackForce)
					hitPlayers[player] = true
					DebugLog("Arrow hit player:", player.Name)
				end
			end

			task.wait() -- Check every frame
		end
	end)
end

-- Apply knockback to a player hit by an arrow
function ArrowTrapModifier:ApplyArrowKnockback(hrp, direction, force)
	-- Apply horizontal knockback in arrow direction
	local horizontalDirection = Vector3.new(direction.X, 0, direction.Z)
	if horizontalDirection.Magnitude > 0.01 then
		horizontalDirection = horizontalDirection.Unit
	else
		-- Arrow pointing straight up/down, use forward
		horizontalDirection = Vector3.new(0, 0, 1)
	end

	local horizontalKnockback = horizontalDirection * force

	-- Add slight upward component
	local upwardForce = force * 0.3

	local newVelocity = Vector3.new(
		horizontalKnockback.X,
		upwardForce,
		horizontalKnockback.Z
	)

	hrp.AssemblyLinearVelocity = newVelocity

	DebugLog("Applied knockback - Force:", force, "Velocity:", newVelocity)
end

-- Calculate the actual duration needed for all arrows to resolve
function ArrowTrapModifier:GetResolveDuration()
	-- Use selected spawns count (set during Setup), or estimate from max possible
	local trapCount = #self._selectedSpawns
	if trapCount == 0 then
		-- Fallback: estimate using max available
		local trapCountMax = self.Settings.TrapCountMax or 0
		if trapCountMax <= 0 then
			trapCountMax = #self._arrowSpawns
		end
		trapCount = trapCountMax
	end

	local arrowInterval = self.Settings.ArrowInterval or 0.5
	local arrowSpeed = self.Settings.ArrowSpeed or 60
	local zoneLength = self.Settings.ZoneLength or 100

	-- Time for last arrow to fire + time for it to travel full length
	local lastArrowFireTime = math.max(0, trapCount - 1) * arrowInterval
	local travelTime = zoneLength / arrowSpeed

	-- Add buffer for safety
	local totalDuration = lastArrowFireTime + travelTime + 0.5

	DebugLog("Calculated resolve duration:", totalDuration, "seconds for", trapCount, "traps")
	return totalDuration
end

function ArrowTrapModifier:Cleanup()
	DebugLog("Cleanup")

	-- Disconnect all connections
	for _, connection in ipairs(self._connections) do
		if connection.Connected then
			connection:Disconnect()
		end
	end
	self._connections = {}

	-- Clear state
	self._selectedSpawns = {}

	BaseModifier.Cleanup(self)
end

return ArrowTrapModifier
