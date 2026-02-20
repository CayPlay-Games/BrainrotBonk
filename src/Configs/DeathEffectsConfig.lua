--[[
	DeathEffectsConfig.lua

	Description:
		Configuration for map-dependent death effects.
		Defines visual effects that play when a player is eliminated before returning to lobby.
--]]

local TableHelper = shared("TableHelper")

return TableHelper:DeepFreeze({
	-- Default effect duration if not specified
	DEFAULT_EFFECT_DURATION = 1.5,

	-- Effect definitions
	Effects = {
		SaladSpinner = {
			DisplayName = "Blended",
			Duration = 2.5,

			Settings = {
				PartCount = 15,           -- Number of pieces to generate
				PartSizeMin = 0.3,        -- Minimum piece size
				PartSizeMax = 0.8,        -- Maximum piece size
				ScatterForce = 50,        -- Initial velocity magnitude
				ScatterUpwardBias = 0.4,  -- Upward component (0-1)
				SpinSpeed = 20,           -- Angular velocity for spinning
				FadeDelay = 1.5,          -- Seconds before fade starts
				FadeDuration = 1.0,       -- Seconds to fade out
				ParticleEmitCount = 30,   -- Particles per burst
			},
		},

		ElectroTub = {
			DisplayName = "Electrocuted",
			Duration = 2.0,

			Settings = {
				FlashCount = 5,           -- Number of black flashes
				FlashInterval = 0.15,     -- Seconds between flashes
				ElectricColor = Color3.fromRGB(255, 255, 100),
				CharredColor = Color3.fromRGB(30, 30, 30),
				ParticleDensity = 20,     -- Electric particles per second
				ShakeAmplitude = 0.3,     -- Visual shake amount
			},
		},

		Default = {
			DisplayName = "Eliminated",
			Duration = 1.0,

			Settings = {
				FadeOutDuration = 0.8,
			},
		},
	},
})
