--[[
	RoundConfig.lua

	Description:
		Configuration for the round system including timers, player requirements,
		and debug settings.
--]]

local TableHelper = shared("TableHelper")

return TableHelper:DeepFreeze({
	-- Debug settings
	DEBUG_MODE = false, -- Allow starting with 1 player instead of MIN_PLAYERS_TO_START
	DEBUG_SKIP_MAP_LOADING = false, -- Use default test map
	DEBUG_LOG_STATE_CHANGES = true, -- Print state transitions to output

	-- Player requirements
	MIN_PLAYERS_TO_START = 2,
	MAX_PLAYERS_PER_ROUND = 12,

	-- Phase durations (seconds)
	Timers = {
		WAITING_COUNTDOWN = 15, -- Time after min players reached before starting
		MAP_LOADING_TIMEOUT = 10, -- Max time to wait for map load
		SPAWNING_DURATION = 5,
		AIMING_DURATION = 5,
		REVEALING_DURATION = 2,
		LAUNCHING_DURATION = 0.5, -- Brief delay after applying forces
		RESOLUTION_TIMEOUT = 10, -- Max time waiting for physics to settle
		ROUND_END_DURATION = 5,
		INTERMISSION_DURATION = 5,
	},

	-- Aim settings
	AIM_POWER_MIN = 1,
	AIM_POWER_MAX = 10,
	DEFAULT_AIM_DIRECTION = Vector3.new(0, 0, 1), -- Forward
	DEFAULT_AIM_POWER = 5,
	AIM_SUBMIT_GRACE_PERIOD = 1, -- Seconds to wait for aim submissions after timer ends

	-- Launch physics
	LAUNCH_FORCE_MULTIPLIER = 6, -- Power * this = velocity magnitude

	-- Surface physics (applied to map parts)
	SLIPPERY_FRICTION = 0.05, -- Low friction for ice-like sliding
	SLIPPERY_ELASTICITY = 0.3, -- Lower elasticity for less bounce on surfaces

	-- Curling stone physics settings
	CURLING_DECAY_RATE = 0.993, -- Per-frame velocity multiplier (lower = more friction feel)
	CURLING_MAX_FORCE = 100000, -- LinearVelocity max force (kept for reference)
	CURLING_MIN_SPEED = 0.3, -- Below this speed, stop completely (prevents drifting)
	ANGULAR_RESISTANCE = 10000, -- MaxTorque for rotation control (resists wild spinning)

	-- Collision settings (for custom momentum transfer)
	COLLISION_COOLDOWN = 0.15, -- Seconds between collision responses with same player
	COLLISION_MIN_SPEED = 1.0, -- Minimum relative speed to trigger collision response
	CURLING_COLLISION_RESTITUTION = 0.6, -- Lower = more energy absorbed, less bouncy

	-- Physics box settings (standardized player body during rounds)
	PHYSICS_BOX_SIZE = Vector3.new(3.5, 5, 3.5), -- Size of the cube
	PHYSICS_BOX_DENSITY = 25, -- Higher density for heavier, more substantial feel
	PHYSICS_BOX_FRICTION = 0.05, -- Low friction on player boxes
	PHYSICS_BOX_ELASTICITY = 0.4, -- Lower elasticity for less bouncy collisions
	PHYSICS_BOX_COLOR = Color3.fromRGB(255, 255, 255), -- Default white (skin covers it)

	-- Lobby settings
	LOBBY_SPAWN_POSITION = Vector3.new(125.528, 161.205, -34.834), -- Where players spawn in lobby
})
