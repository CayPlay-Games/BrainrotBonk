--[[
	DebugPhysics.lua

	Description:
		Global DataStream schema for runtime-modifiable physics values.
		Allows tweaking physics settings via debug UI without restarting.
		Values apply to the next round of gameplay.
--]]

return {
	-- Launch physics
	LAUNCH_FORCE_MULTIPLIER = 6,

	-- Surface physics (applied to map parts)
	SLIPPERY_FRICTION = 0.05,
	SLIPPERY_ELASTICITY = 0.3,

	-- Curling stone physics
	CURLING_MIN_SPEED = 0.3,

	-- Collision settings
	COLLISION_COOLDOWN = 0.15,
	COLLISION_MIN_SPEED = 1.0,
	CURLING_COLLISION_RESTITUTION = 0.6,

	-- Physics box settings (Vector3 split into components for DataStream)
	PHYSICS_BOX_SIZE_X = 3.5,
	PHYSICS_BOX_SIZE_Y = 5,
	PHYSICS_BOX_SIZE_Z = 3.5,
	PHYSICS_BOX_DENSITY = 25,
	PHYSICS_BOX_FRICTION = 0.05,
	PHYSICS_BOX_ELASTICITY = 0.4,
}
