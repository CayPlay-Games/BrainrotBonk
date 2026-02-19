--[[
	TrafficJamEffects.lua

	Description:
		Map effects for the Traffic Jam map.
		Spawns cars that travel in straight lines from spawn to end points,
		with collision detection to prevent same-lane rear-ends and intersection crashes.
--]]

-- Root --
local TrafficJamEffects = {}

-- Roblox Services --
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

-- Private Variables --
local _lanes = {} -- Each lane manages its own car spawning
local _updateConnection = nil
local _startServerTime = 0
local _random = nil -- Seeded Random for deterministic "random" delays 

-- Internal Functions --
-- Default lane settings (can be overridden via attributes on lane folder)
local DEFAULT_SPEED_MIN = 120 -- studs/second
local DEFAULT_SPEED_MAX = 180 -- studs/second
local DEFAULT_RESPAWN_DELAY_MIN = 0.5 -- seconds
local DEFAULT_RESPAWN_DELAY_MAX = 3.0 -- seconds
local INTERSECTION_BUFFER = 15 -- studs - buffer around intersection part
local CAR_LENGTH_BUFFER = 20 -- studs - minimum distance between cars in same lane

local function GetAllIntersectionTimes(lane, travelTime)
	if not lane.intersections or #lane.intersections == 0 then
		return {}
	end

	local speed = lane.distance / travelTime
	local times = {}

	for _, intersection in ipairs(lane.intersections) do
		table.insert(times, {
			enterTime = intersection.enterDist / speed,
			exitTime = intersection.exitDist / speed,
		})
	end

	return times
end

-- Check if two time ranges overlap
local function TimeRangesOverlap(enter1, exit1, enter2, exit2)
	return enter1 < exit2 and exit1 > enter2
end

-- Check if spawning would cause same-lane collision (rear-ending a slower car)
local function WouldCollideInSameLane(lane, spawnTime, travelTime)
	for _, otherCar in ipairs(lane.activeCars) do
		local otherEndTime = otherCar.spawnTime + otherCar.travelTime
		local myEndTime = spawnTime + travelTime

		-- Skip if other car will be gone before we spawn
		if spawnTime >= otherEndTime then
			continue
		end

		-- At my spawn time, where is the other car? (as distance along lane)
		local otherAlphaAtMySpawn = (spawnTime - otherCar.spawnTime) / otherCar.travelTime
		local gapAtSpawn = otherAlphaAtMySpawn * lane.distance

		if gapAtSpawn < CAR_LENGTH_BUFFER then
			return true -- Too close at spawn
		end

		-- If I'm faster, check if I'd catch up before either car exits
		if travelTime < otherCar.travelTime then
			local catchUpTime = (otherCar.travelTime * spawnTime - travelTime * otherCar.spawnTime)
				/ (otherCar.travelTime - travelTime)

			-- Would catch up while both are still on the road
			if catchUpTime > spawnTime and catchUpTime < math.min(myEndTime, otherEndTime) then
				return true
			end
		end
	end

	return false
end

local function WouldCollideAtIntersectionWithTimes(spawnTime, myTimes)
	if #myTimes == 0 then
		return false
	end

	-- Check against all active cars in all lanes (including same lane)
	for _, otherLane in ipairs(_lanes) do
		if otherLane.activeCars then
			for _, otherCar in ipairs(otherLane.activeCars) do
				local otherTimes = otherCar.intersectionTimes or {}

				for _, myTime in ipairs(myTimes) do
					local myEnterAbs = spawnTime + myTime.enterTime
					local myExitAbs = spawnTime + myTime.exitTime

					for _, otherTime in ipairs(otherTimes) do
						local otherEnterAbs = otherCar.spawnTime + otherTime.enterTime
						local otherExitAbs = otherCar.spawnTime + otherTime.exitTime

						if TimeRangesOverlap(myEnterAbs, myExitAbs, otherEnterAbs, otherExitAbs) then
							return true
						end
					end
				end
			end
		end
	end

	return false
end

local function SetupLane(laneFolder, vehicleTemplates)
	local spawnPart = laneFolder:FindFirstChild("Spawn")
	local endPart = laneFolder:FindFirstChild("End")

	if not spawnPart or not endPart then
		warn("[TrafficJamEffects] Lane missing Spawn or End part:", laneFolder.Name)
		return nil
	end

	local speedMin = laneFolder:GetAttribute("SpeedMin") or DEFAULT_SPEED_MIN
	local speedMax = laneFolder:GetAttribute("SpeedMax") or DEFAULT_SPEED_MAX
	local respawnDelayMin = laneFolder:GetAttribute("RespawnDelayMin") or DEFAULT_RESPAWN_DELAY_MIN
	local respawnDelayMax = laneFolder:GetAttribute("RespawnDelayMax") or DEFAULT_RESPAWN_DELAY_MAX

	local spawnCF = spawnPart.CFrame
	local endCF = endPart.CFrame
	local distance = (endCF.Position - spawnCF.Position).Magnitude

	-- Find all Intersection parts in this lane (supports multiple)
	local intersections = {}
	local laneDir = (endCF.Position - spawnCF.Position).Unit

	for _, child in ipairs(laneFolder:GetChildren()) do
		if child:IsA("BasePart") and child.Name:find("Intersection") then
			local toIntersection = child.Position - spawnCF.Position
			local projectedDist = toIntersection:Dot(laneDir)

			if projectedDist > 0 and projectedDist < distance then
				table.insert(intersections, {
					enterDist = math.max(0, projectedDist - INTERSECTION_BUFFER),
					exitDist = math.min(distance, projectedDist + INTERSECTION_BUFFER),
				})
			end
		end
	end

	local initialDelay = _random:NextNumber(0, respawnDelayMax)

	return {
		vehicleTemplates = vehicleTemplates,
		spawnCF = spawnCF,
		endCF = endCF,
		distance = distance,
		speedMin = speedMin,
		speedMax = speedMax,
		respawnDelayMin = respawnDelayMin,
		respawnDelayMax = respawnDelayMax,
		intersections = intersections,
		lookDir = laneDir, -- Cached direction for car rotation
		activeCars = {},
		nextSpawnTime = _startServerTime + initialDelay,
		pendingVehicle = nil,
		pendingTravelTime = nil,
	}
end

-- Makes a model non-collidable
local function MakeNonCollidable(model)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
		end
	end
end

-- API Functions --
function TrafficJamEffects:Start(mapInstance, startServerTime)
	-- Clean up any existing state first
	if _updateConnection then
		self:Stop()
	end

	_startServerTime = startServerTime
	-- Seed random with startServerTime so all clients get same sequence
	_random = Random.new(math.floor(startServerTime * 1000))

	-- Find the Effects folder in the map
	local effectsFolder = mapInstance:FindFirstChild("Effects")
	if not effectsFolder then
		warn("[TrafficJamEffects] No Effects folder found in map")
		return
	end

	-- Find the Vehicles folder and collect all vehicle templates
	local vehiclesFolder = effectsFolder:FindFirstChild("Vehicles")
	if not vehiclesFolder then
		warn("[TrafficJamEffects] No Vehicles folder found in Effects")
		return
	end

	local vehicleTemplates = {}
	for _, child in ipairs(vehiclesFolder:GetChildren()) do
		if child:IsA("Model") then
			-- Pre-process collision properties on templates (avoids GetDescendants per spawn)
			MakeNonCollidable(child)
			table.insert(vehicleTemplates, child)
		end
	end

	if #vehicleTemplates == 0 then
		warn("[TrafficJamEffects] No vehicle models found in Vehicles folder")
		return
	end

	-- Find the Lanes folder and set up all lanes inside it
	local lanesFolder = effectsFolder:FindFirstChild("Lanes")
	if not lanesFolder then
		warn("[TrafficJamEffects] No Lanes folder found in Effects")
		return
	end

	-- Set up all lanes found in the Lanes folder
	for _, laneFolder in ipairs(lanesFolder:GetChildren()) do
		if laneFolder:IsA("Folder") then
			local lane = SetupLane(laneFolder, vehicleTemplates)
			if lane then
				table.insert(_lanes, lane)
			end
		end
	end

	-- Start update loop
	_updateConnection = RunService.Heartbeat:Connect(function()
		local currentTime = Workspace:GetServerTimeNow()

		for _, lane in ipairs(_lanes) do
			-- Check if we need to spawn a new car
			if currentTime >= lane.nextSpawnTime then
				-- Pre-roll random values if not already done (to maintain sync)
				if not lane.pendingVehicle then
					local vehicleIndex = _random:NextInteger(1, #lane.vehicleTemplates)
					lane.pendingVehicle = lane.vehicleTemplates[vehicleIndex]
					local speed = _random:NextNumber(lane.speedMin, lane.speedMax)
					lane.pendingTravelTime = lane.distance / speed
				end

				-- Cache intersection times (used for both collision check and car data)
				local intersectionTimes = GetAllIntersectionTimes(lane, lane.pendingTravelTime)

				-- Check if spawning now would cause any collision
				local noSameLaneCollision = not WouldCollideInSameLane(lane, currentTime, lane.pendingTravelTime)
				local noIntersectionCollision = not WouldCollideAtIntersectionWithTimes(currentTime, intersectionTimes)
				if noSameLaneCollision and noIntersectionCollision then
					local carModel = lane.pendingVehicle:Clone()
					carModel.Parent = Workspace

					-- Add to active cars array
					table.insert(lane.activeCars, {
						model = carModel,
						spawnTime = currentTime,
						travelTime = lane.pendingTravelTime,
						intersectionTimes = intersectionTimes,
					})

					-- Schedule next spawn
					local delay = _random:NextNumber(lane.respawnDelayMin, lane.respawnDelayMax)
					lane.nextSpawnTime = currentTime + delay

					-- Clear pending data
					lane.pendingVehicle = nil
					lane.pendingTravelTime = nil
				end
				-- If would collide, keep pending data and try again next frame
			end

			-- Update all active cars in this lane
			for i = #lane.activeCars, 1, -1 do
				local car = lane.activeCars[i]
				local elapsed = currentTime - car.spawnTime
				local alpha = elapsed / car.travelTime

				if alpha >= 1 then
					-- Car reached end, despawn
					car.model:Destroy()
					table.remove(lane.activeCars, i)
				else
					-- Lerp position
					local pos = lane.spawnCF.Position:Lerp(lane.endCF.Position, alpha)
					car.model:PivotTo(CFrame.lookAt(pos, pos + lane.lookDir))
				end
			end
		end
	end)
end

function TrafficJamEffects:Stop()
	if _updateConnection then
		_updateConnection:Disconnect()
		_updateConnection = nil
	end

	for _, lane in ipairs(_lanes) do
		for _, car in ipairs(lane.activeCars) do
			if car.model then
				car.model:Destroy()
			end
		end
	end

	_lanes = {}
	_random = nil
end

-- Return Module --
return TrafficJamEffects
