--[[
	RoundConfig.lua

	Description:
		Configuration for the round system including timers, player requirements,
		and debug settings.
--]]

local TableHelper = shared("TableHelper")

return TableHelper:DeepFreeze({
	-- Debug settings
	DEBUG_MODE = true, -- Allow starting with 1 player instead of MIN_PLAYERS_TO_START
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

	-- Curling stone physics settings
	SLIPPERY_ELASTICITY = 0.5, -- Moderate: momentum transfer without excessive bounce
	CURLING_DECAY_RATE = 0.99, -- Per-frame velocity multiplier (higher = longer slides)
	CURLING_MAX_FORCE = 100000, -- LinearVelocity max force (kept for reference)
	CURLING_MIN_SPEED = 0.5, -- Below this speed, stop completely (prevents drifting)
	ANGULAR_RESISTANCE = 10000, -- MaxTorque for rotation control (resists wild spinning)

	-- Physics box settings (standardized player body during rounds)
	PHYSICS_BOX_SIZE = Vector3.new(3.5, 5, 3.5), -- Size of the cube
	PHYSICS_BOX_DENSITY = 15, -- Mass/density of physics body (lighter for responsive collisions)
	PHYSICS_BOX_COLOR = Color3.fromRGB(255, 255, 255), -- Default white (skin covers it)

	-- Lobby settings
	LOBBY_SPAWN_POSITION = Vector3.new(125.528, 161.205, -34.834), -- Where players spawn in lobby
})
