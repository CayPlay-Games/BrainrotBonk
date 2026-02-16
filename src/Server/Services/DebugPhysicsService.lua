--[[
	DebugPhysicsService.lua

	Description:
		Handles debug physics value updates from clients.
		Allows runtime modification of physics settings for testing.
--]]

-- Root --
local DebugPhysicsService = {}

-- Dependencies --
local DataStream = shared("DataStream")
local GetRemoteEvent = shared("GetRemoteEvent")

-- Remote Events --
local UpdateDebugPhysicsRemoteEvent = GetRemoteEvent("UpdateDebugPhysics")

-- Valid keys that can be modified
local VALID_KEYS = {
	"LAUNCH_FORCE_MULTIPLIER",
	"SLIPPERY_FRICTION",
	"SLIPPERY_ELASTICITY",
	"CURLING_MIN_SPEED",
	"COLLISION_COOLDOWN",
	"COLLISION_MIN_SPEED",
	"CURLING_COLLISION_RESTITUTION",
	"PHYSICS_BOX_SIZE_X",
	"PHYSICS_BOX_SIZE_Y",
	"PHYSICS_BOX_SIZE_Z",
	"PHYSICS_BOX_DENSITY",
	"PHYSICS_BOX_FRICTION",
	"PHYSICS_BOX_ELASTICITY",
}

-- Internal Functions --
local function IsValidKey(key)
	for _, validKey in ipairs(VALID_KEYS) do
		if validKey == key then
			return true
		end
	end
	return false
end

local function OnUpdateDebugPhysics(player, key, value)
	if not IsValidKey(key) then
		warn("[DebugPhysicsService] Invalid key:", key, "from", player.Name)
		return
	end

	if type(value) ~= "number" then
		warn("[DebugPhysicsService] Invalid value type:", type(value), "from", player.Name)
		return
	end

	DataStream.DebugPhysics[key] = value
	print("[DebugPhysics]", player.Name, "set", key, "=", value)
end

-- Initializers --
function DebugPhysicsService:Init()
	UpdateDebugPhysicsRemoteEvent.OnServerEvent:Connect(OnUpdateDebugPhysics)
end

-- Return Module --
return DebugPhysicsService
