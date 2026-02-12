--[[
	DailyRewardConfig.lua

	Description:
		Configuration for the daily reward system.
		Defines rewards for each day (1-7) and rotating Day 7 skins.
--]]

local TableHelper = shared("TableHelper")

-- Debug settings
local DEBUG_MODE = true -- Set to false for production

return TableHelper:DeepFreeze({
	-- Time between claims (in seconds)
	CLAIM_COOLDOWN = DEBUG_MODE and 120 or 86400, -- 2 minutes (debug) or 24 hours (production)

	-- Icon asset IDs for reward types
	Icons = {
		Coins = "rbxassetid://15993201893",
		Spins = "rbxassetid://17449975508",
	},

	-- Rewards for each day
	-- Type: "Coins", "Spins", or "Skin"
	Days = {
		[1] = { Type = "Coins", Amount = 100 },
		[2] = { Type = "Coins", Amount = 150 },
		[3] = { Type = "Spins", Amount = 1 },
		[4] = { Type = "Coins", Amount = 200 },
		[5] = { Type = "Coins", Amount = 250 },
		[6] = { Type = "Spins", Amount = 2 },
		[7] = { Type = "Skin" }, -- Skin determined by cycle
	},

	-- Rotating Day 7 skins (cycles through based on CycleCount)
	-- Index wraps: cycle 1 = skin 1, cycle 2 = skin 2, etc.
	Day7Skins = {
		[1] = { SkinId = "KarkerkarKurkur", Mutation = "Normal" },
		-- Add more skins as they become available:
		-- [2] = { SkinId = "ChefPenguin", Mutation = "Normal" },
	},
})
