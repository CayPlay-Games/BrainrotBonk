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

-- Constants --
-- Internal Functions --
function ArrowTrapModifier.new(settings)
	local self = setmetatable(BaseModifier.new(settings), ArrowTrapModifier)

	self._arrowSpawns = {} -- All available spawn points from map
	self._selectedSpawns = {} -- Spawns selected for this round

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
end

-- Setup phase: Select arrow traps and send warnings to clients
function ArrowTrapModifier:Setup()
	self._isActive = true

	-- Select random spawns based on TrapCount range settings
	self._selectedSpawns = {}
	local maxAvailable = #self._arrowSpawns
	local trapCountMin = self.Settings.TrapCountMin or 1
	local trapCountMax = self.Settings.TrapCountMax or 0

	if trapCountMax <= 0 or trapCountMax > maxAvailable then
		trapCountMax = maxAvailable
	end

	trapCountMin = math.max(0, math.min(trapCountMin, trapCountMax))
	local trapCount = math.random(trapCountMin, trapCountMax)

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
	ArrowWarningEvent:FireAllClients(arrowData, mapName)
end

-- Resolve phase: Fire arrows and apply knockback
function ArrowTrapModifier:Resolve()
	local arrowInterval = self.Settings.ArrowInterval or 0.5
	local arrowSpeed = self.Settings.ArrowSpeed or 60
	local zoneLength = self.Settings.ZoneLength or 100
	local zoneWidth = self.Settings.ZoneWidth or 4
	local knockbackForce = self.Settings.KnockbackForce or 40
	local originOffset = self.Settings.OriginOffset or 0

	local travelTime = zoneLength / arrowSpeed
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

function ArrowTrapModifier:SimulateArrowTravel(origin, direction, zoneLength, zoneWidth, speed, knockbackForce)
	local startTime = os.clock()
	local travelTime = zoneLength / speed

	local hitPlayers = {}
	local cachedPlayers = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if RoundService:IsPlayerAlive(player) then
			local character = player.Character
			local hrp = character and character:FindFirstChild("HumanoidRootPart")
			if hrp then
				table.insert(cachedPlayers, { Player = player, HRP = hrp })
			end
		end
	end

	local CHECK_INTERVAL = 0.033
	task.spawn(function()
		while true do
			if not self:IsActive() then
				break
			end

			local elapsed = os.clock() - startTime
			if elapsed >= travelTime then
				break
			end

			-- Calculate current arrow position
			local distanceTraveled = elapsed * speed
			local currentPos = origin + direction * distanceTraveled

			for _, cached in ipairs(cachedPlayers) do
				if hitPlayers[cached.Player] then
					continue
				end

				local hrp = cached.HRP
				if not hrp or not hrp.Parent then
					continue
				end

				-- Check if player is within arrow's hitbox
				local playerPos = hrp.Position
				local toPlayer = playerPos - currentPos

				-- Project onto arrow path to get perpendicular distance
				local alongPath = toPlayer:Dot(direction)
				local perpendicular = toPlayer - direction * alongPath
				local perpendicularDist = perpendicular.Magnitude

				local hitWindow = 4
				if perpendicularDist <= zoneWidth / 2 and math.abs(alongPath) <= hitWindow then
					self:ApplyArrowKnockback(hrp, direction, knockbackForce)
					hitPlayers[cached.Player] = true
				end
			end

			task.wait(CHECK_INTERVAL)
		end
	end)
end

function ArrowTrapModifier:ApplyArrowKnockback(hrp, direction, force)
	local horizontalDirection = Vector3.new(direction.X, 0, direction.Z)
	if horizontalDirection.Magnitude > 0.01 then
		horizontalDirection = horizontalDirection.Unit
	else
		horizontalDirection = Vector3.new(0, 0, 1)
	end

	local horizontalKnockback = horizontalDirection * force
	local upwardForce = force * 0.3

	local newVelocity = Vector3.new(
		horizontalKnockback.X,
		upwardForce,
		horizontalKnockback.Z
	)
	hrp.AssemblyLinearVelocity = newVelocity

end

function ArrowTrapModifier:GetResolveDuration()
	local trapCount = #self._selectedSpawns
	if trapCount == 0 then
		local trapCountMax = self.Settings.TrapCountMax or 0
		if trapCountMax <= 0 then
			trapCountMax = #self._arrowSpawns
		end
		trapCount = trapCountMax
	end

	local arrowInterval = self.Settings.ArrowInterval or 0.5
	local arrowSpeed = self.Settings.ArrowSpeed or 60
	local zoneLength = self.Settings.ZoneLength or 100

	local lastArrowFireTime = math.max(0, trapCount - 1) * arrowInterval
	local travelTime = zoneLength / arrowSpeed

	-- Add buffer for safety
	local totalDuration = lastArrowFireTime + travelTime + 0.5
	return totalDuration
end

function ArrowTrapModifier:Cleanup()
	self._selectedSpawns = {}
	BaseModifier.Cleanup(self)
end

return ArrowTrapModifier
