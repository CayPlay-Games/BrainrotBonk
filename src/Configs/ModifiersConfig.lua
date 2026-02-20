--[[
	ModifiersConfig.lua

	Description:
		Configuration for map modifiers including definitions, settings, and timing.
		Each modifier defines its behavior parameters and visual/audio settings.
--]]

local TableHelper = shared("TableHelper")

return TableHelper:DeepFreeze({
	-- Phase durations (seconds)
	MODIFIER_SETUP_DURATION = 3,      -- Warning phase before effects
	MODIFIER_RESOLUTION_DURATION = 2,  -- Effect execution phase

	-- Modifier definitions
	Modifiers = {
		MeteorShower = {
			Id = "MeteorShower",
			DisplayName = "Meteor Shower",
			Description = "Meteors rain down from the sky!",

			-- Effect settings
			Settings = {
				MeteorCount = 3,                -- Number of meteors to spawn
				MeteorInterval = 0.4,           -- Seconds between meteor spawns
				MeteorSpeed = 40,               -- Studs per second fall speed
				ImpactRadius = 12,               -- Studs radius of knockback
				KnockbackForce = 30,            -- Force applied to players
				TargetPlayers = false,           -- Meteors target player positions
				RandomSpread = 8,               -- Random offset from target position
			},
		},

		ArrowTrap = {
			Id = "ArrowTrap",
			DisplayName = "Arrow Trap",
			Description = "Ancient traps fire arrows across the platform!",

			-- Effect settings
			Settings = {
				TrapCountMin = 1,               -- Minimum number of traps to activate per round
				TrapCountMax = 0,               -- Maximum traps (0 = use all available spawns)
				ArrowInterval = 0.5,            -- Seconds between trap activations
				ArrowSpeed = 120,                -- Studs per second arrow travel speed
				ZoneLength = 150,               -- How far the arrow danger zone extends
				ZoneWidth = 12,                  -- Width of the danger zone
				KnockbackForce = 80,            -- Force applied when hit by arrow
				OriginOffset = 0,               -- Offset from arrow pivot along direction (+ forward, - backward)
			},
		},
	},
})
