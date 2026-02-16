--[[
	PhysicsService.lua

	Description:
		Handles custom physics for curling-disc gameplay.
		Implements elastic collisions with momentum transfer.
		Works alongside Roblox physics for collision detection.
--]]

-- Root --
local PhysicsService = {}

-- Roblox Services --
local RunService = game:GetService("RunService")

-- Dependencies --
local RoundConfig = shared("RoundConfig")
local Signal = shared("Signal")
local DataStream = shared("DataStream")

-- Private Variables --
local _ActivePlayers = {} -- HRP -> { TouchConnection = Connection }
local _CollisionCooldowns = {} -- "id1_id2" -> timestamp

-- Signals --
PhysicsService.CollisionOccurred = nil

-- Internal Functions --

local function DebugLog(...)
	if RoundConfig.DEBUG_LOG_STATE_CHANGES then
		print("[PhysicsService]", ...)
	end
end

-- Gets a physics value from DebugPhysics DataStream (for runtime tuning)
local function GetDebugPhysics(key)
	local debugPhysics = DataStream.DebugPhysics
	if debugPhysics and debugPhysics[key] then
		return debugPhysics[key]:Read()
	end
	return nil
end

-- Get a unique identifier for an HRP
local function GetEntityId(hrp)
	local model = hrp.Parent
	if model then
		return model.Name
	end
	return tostring(hrp:GetDebugId())
end

-- Get a consistent collision key regardless of order
local function GetCollisionKey(id1, id2)
	if id1 < id2 then
		return id1 .. "_" .. id2
	else
		return id2 .. "_" .. id1
	end
end

-- Check if two entities are on collision cooldown
local function IsOnCooldown(id1, id2)
	local key = GetCollisionKey(id1, id2)
	local lastTime = _CollisionCooldowns[key]
	if lastTime and (tick() - lastTime) < (GetDebugPhysics("COLLISION_COOLDOWN") or 0.15) then
		return true
	end
	return false
end

-- Set collision cooldown between two entities
local function SetCooldown(id1, id2)
	local key = GetCollisionKey(id1, id2)
	_CollisionCooldowns[key] = tick()
end

-- Calculate elastic collision velocities for two objects
-- Uses conservation of momentum and kinetic energy
local function CalculateElasticCollision(pos1, vel1, mass1, pos2, vel2, mass2, restitution)
	-- Direction from object 1 to object 2 (horizontal only)
	local normal = (pos2 - pos1)
	normal = Vector3.new(normal.X, 0, normal.Z)

	if normal.Magnitude < 0.001 then
		return vel1, vel2 -- Objects at same position, no change
	end
	normal = normal.Unit

	-- Relative velocity along collision normal
	local relativeVel = vel1 - vel2
	local normalVel = relativeVel:Dot(normal)

	-- Don't resolve if objects are separating
	if normalVel < 0 then
		return vel1, vel2
	end

	-- Calculate impulse scalar using coefficient of restitution
	local totalMass = mass1 + mass2
	local impulse = (1 + restitution) * normalVel / totalMass

	-- Apply impulse to both objects
	local newVel1 = vel1 - (impulse * mass2) * normal
	local newVel2 = vel2 + (impulse * mass1) * normal

	return newVel1, newVel2
end

-- Handle collision between two physics boxes
local function HandleCollision(hrp1, hrp2)
	local id1 = GetEntityId(hrp1)
	local id2 = GetEntityId(hrp2)

	-- Check cooldown
	if IsOnCooldown(id1, id2) then
		return
	end

	-- Get current velocities
	local vel1 = hrp1.AssemblyLinearVelocity
	local vel2 = hrp2.AssemblyLinearVelocity

	-- Only horizontal velocities for curling physics
	local hVel1 = Vector3.new(vel1.X, 0, vel1.Z)
	local hVel2 = Vector3.new(vel2.X, 0, vel2.Z)

	-- Check if collision is significant (at least one moving fast enough)
	local relSpeed = (hVel1 - hVel2).Magnitude
	if relSpeed < (GetDebugPhysics("COLLISION_MIN_SPEED") or 1.0) then
		return
	end

	-- Get masses
	local mass1 = hrp1.AssemblyMass
	local mass2 = hrp2.AssemblyMass

	-- Calculate new velocities
	local restitution = GetDebugPhysics("CURLING_COLLISION_RESTITUTION") or 0.6
	local newVel1, newVel2 = CalculateElasticCollision(
		hrp1.Position, hVel1, mass1,
		hrp2.Position, hVel2, mass2,
		restitution
	)

	-- Apply new velocities (preserve vertical component)
	hrp1.AssemblyLinearVelocity = Vector3.new(newVel1.X, vel1.Y, newVel1.Z)
	hrp2.AssemblyLinearVelocity = Vector3.new(newVel2.X, vel2.Y, newVel2.Z)

	-- Set cooldown
	SetCooldown(id1, id2)

	-- Fire signal for effects/sounds
	local impactForce = relSpeed * (mass1 + mass2) / 2
	if PhysicsService.CollisionOccurred then
		PhysicsService.CollisionOccurred:Fire(hrp1.Parent, hrp2.Parent, impactForce)
	end

end

-- API Functions --

-- Registers a physics box for collision handling
function PhysicsService:RegisterPhysicsBox(hrp)
	if _ActivePlayers[hrp] then
		return -- Already registered
	end

	local connection = hrp.Touched:Connect(function(otherPart)
		-- Check if other part is another registered physics box
		if otherPart.Name == "HumanoidRootPart" and _ActivePlayers[otherPart] then
			HandleCollision(hrp, otherPart)
		end
	end)

	_ActivePlayers[hrp] = {
		TouchConnection = connection,
	}

end

-- Unregisters a physics box
function PhysicsService:UnregisterPhysicsBox(hrp)
	local data = _ActivePlayers[hrp]
	if data then
		if data.TouchConnection then
			data.TouchConnection:Disconnect()
		end
		_ActivePlayers[hrp] = nil
	end
end

-- Clears all registered physics boxes
function PhysicsService:ClearAll()
	for hrp, data in pairs(_ActivePlayers) do
		if data.TouchConnection then
			data.TouchConnection:Disconnect()
		end
	end
	_ActivePlayers = {}
	_CollisionCooldowns = {}
end

-- Gets count of active physics boxes
function PhysicsService:GetActiveCount()
	local count = 0
	for _ in pairs(_ActivePlayers) do
		count = count + 1
	end
	return count
end

-- Initializers --
function PhysicsService:Init()
	-- Create collision signal
	PhysicsService.CollisionOccurred = Signal.new()

	-- Periodically clean up old cooldowns
	RunService.Heartbeat:Connect(function()
		local now = tick()
		for key, timestamp in pairs(_CollisionCooldowns) do
			if (now - timestamp) > (GetDebugPhysics("COLLISION_COOLDOWN") or 0.15) * 2 then
				_CollisionCooldowns[key] = nil
			end
		end
	end)

end

-- Return Module --
return PhysicsService
