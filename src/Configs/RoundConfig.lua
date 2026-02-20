--[[
	RoundConfig.lua

	Description:
		Configuration for the round system including timers, player requirements,
		and debug settings.
--]]

local RunService = game:GetService("RunService")
local TableHelper = shared("TableHelper")

local isStudio = RunService:IsStudio()

return TableHelper:DeepFreeze({
	-- Debug settings
	DEBUG_MODE = isStudio and true, -- Allow starting with 1 player instead of MIN_PLAYERS_TO_START (only in Studio)
	DEBUG_SKIP_MAP_LOADING = false, -- Use default test map
	DEBUG_LOG_STATE_CHANGES = true, -- Print state transitions to output

	-- Player requirements
	MIN_PLAYERS_TO_START = 2,
	MAX_PLAYERS_PER_ROUND = 11,

	-- Phase durations (seconds)
	Timers = {
		WAITING_COUNTDOWN = 10, -- Time after min players reached before starting
		MAP_LOADING_TIMEOUT = 10, -- Max time to wait for map load
		SPAWNING_DURATION = 5,
		MODIFIER_SETUP_DURATION = 3, -- Warning phase before effects
		AIMING_DURATION = 5,
		REVEALING_DURATION = 2,
		LAUNCHING_DURATION = 0.5, -- Brief delay after applying forces
		MODIFIER_RESOLUTION_DURATION = 2, -- Effect execution phase
		RESOLUTION_TIMEOUT = 10, -- Max time waiting for physics to settle
		ROUND_END_DURATION = 5,
		INTERMISSION_DURATION = 5,
	},

	-- Aim settings
	AIM_POWER_MIN = 1,
	AIM_POWER_MAX = 10,
	DEFAULT_AIM_DIRECTION = Vector3.new(0, 0, 1), -- Forward
	DEFAULT_AIM_POWER = 3,
	AIM_SUBMIT_GRACE_PERIOD = 1, -- Seconds to wait for aim submissions after timer ends

	-- Launch physics
	LAUNCH_FORCE_MULTIPLIER = 6.75, -- Power * this = velocity magnitude

	-- Surface physics (applied to map parts)
	SLIPPERY_FRICTION = 0.04, -- Low friction for ice-like sliding
	SLIPPERY_ELASTICITY = 0.3, -- Lower elasticity for less bounce on surfaces

	-- Curling stone physics settings
	CURLING_DECAY_RATE = 0.993, -- Per-frame velocity multiplier (lower = more friction feel)
	CURLING_MIN_SPEED = 0.28, -- Below this speed, stop completely (prevents drifting)

	-- Collision settings (for custom momentum transfer)
	COLLISION_COOLDOWN = 0.15, -- Seconds between collision responses with same player
	COLLISION_MIN_SPEED = 1.0, -- Minimum relative speed to trigger collision response
	CURLING_COLLISION_RESTITUTION = 0.8, -- Lower = more energy absorbed, less bouncy

	-- Physics box settings (standardized player body during rounds)
	PHYSICS_BOX_TEMPLATE = "Hitbox", -- Optional: name of Part in ServerStorage to use as hitbox base (e.g. "CustomHitbox")
	PHYSICS_BOX_SIZE = Vector3.new(3.5, 5, 3.5), -- Size of the cube
	PHYSICS_BOX_DENSITY = 25, -- Higher density for heavier, more substantial feel
	PHYSICS_BOX_FRICTION = 0.05, -- Low friction on player boxes
	PHYSICS_BOX_ELASTICITY = 0.3, -- Lower elasticity for less bouncy collisions
	PHYSICS_BOX_COLOR = Color3.fromRGB(255, 255, 255), -- Default white (skin covers it)

	-- Lobby settings
	LOBBY_SPAWN_POSITION = Vector3.new(125.528, 165, -34.834), -- Where players spawn in lobby
	LOBBY_SPAWN_SIZE = Vector3.new(32, 1, 12), -- Size of the spawn area in the lobby
	
	-- Server switch popup settings
	SWITCH_SERVER_TIMEOUT = 90, -- Seconds in Waiting before showing popup
	SWITCH_SERVER_COOLDOWN = 120, -- Seconds before showing popup again after clicking Stay
})
