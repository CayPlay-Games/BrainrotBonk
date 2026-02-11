--[[
	RankConfig.lua

	Description:
		Configuration for the rank progression system.
		Defines XP rewards for game actions and rank thresholds with rewards.
--]]

local TableHelper = shared("TableHelper")

-- Tier gradients for rank cards (ColorSequence for UIGradient)
local TierGradients = {
	Bronze = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(139, 90, 43)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(205, 127, 50)),
	}),
	Silver = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 120, 130)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(192, 192, 200)),
	}),
	Gold = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(180, 130, 0)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 215, 0)),
	}),
	Platinum = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 120, 140)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 200, 220)),
	}),
	Emerald = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 100, 60)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 200, 120)),
	}),
	Diamond = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(100, 150, 200)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 230, 255)),
	}),
	Master = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(100, 50, 120)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 100, 220)),
	}),
	Grandmaster = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(150, 50, 50)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(200, 150, 50)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 50, 50)),
	}),
}

return TableHelper:DeepFreeze({
	-- Tier gradients for rank card backgrounds
	TierGradients = TierGradients,

	-- XP awarded for game actions
	XPRewards = {
		PlayGame = 50, -- Completing a round
		Kill = 75, -- Eliminating another player
		Place3rd = 75, -- 3rd place
		Place2nd = 125, -- 2nd place
		Place1st = 250, -- 1st place (winner)
	},

	-- Ranks in order (index = rank level)
	-- Reward Types: "Title", "Currency", "Aura", "Spins", "Skin"
	Ranks = {
		-- Bronze Tier
		{ Name = "Bronze 5", XPRequired = 100, Reward = { Type = "Title", Id = "Bronze" } },
		{ Name = "Bronze 4", XPRequired = 150, Reward = { Type = "Currency", Amount = 500 } },
		{ Name = "Bronze 3", XPRequired = 200, Reward = { Type = "Aura", Id = "Bronze" } },
		{ Name = "Bronze 2", XPRequired = 250, Reward = { Type = "Spins", Amount = 3 } },
		{ Name = "Bronze 1", XPRequired = 300, Reward = { Type = "Skin", Id = "Bronze" } },

		-- Silver Tier
		{ Name = "Silver 5", XPRequired = 400, Reward = { Type = "Title", Id = "Silver" } },
		{ Name = "Silver 4", XPRequired = 475, Reward = { Type = "Currency", Amount = 1000 } },
		{ Name = "Silver 3", XPRequired = 550, Reward = { Type = "Aura", Id = "Silver" } },
		{ Name = "Silver 2", XPRequired = 625, Reward = { Type = "Spins", Amount = 3 } },
		{ Name = "Silver 1", XPRequired = 700, Reward = { Type = "Skin", Id = "Silver" } },

		-- Gold Tier
		{ Name = "Gold 5", XPRequired = 1000, Reward = { Type = "Title", Id = "Gold" } },
		{ Name = "Gold 4", XPRequired = 1250, Reward = { Type = "Currency", Amount = 1500 } },
		{ Name = "Gold 3", XPRequired = 1500, Reward = { Type = "Aura", Id = "Gold" } },
		{ Name = "Gold 2", XPRequired = 1750, Reward = { Type = "Spins", Amount = 3 } },
		{ Name = "Gold 1", XPRequired = 2000, Reward = { Type = "Skin", Id = "Gold" } },

		-- Platinum Tier
		{ Name = "Platinum 5", XPRequired = 2500, Reward = { Type = "Title", Id = "Platinum" } },
		{ Name = "Platinum 4", XPRequired = 3000, Reward = { Type = "Currency", Amount = 2000 } },
		{ Name = "Platinum 3", XPRequired = 3500, Reward = { Type = "Aura", Id = "Platinum" } },
		{ Name = "Platinum 2", XPRequired = 4000, Reward = { Type = "Spins", Amount = 5 } },
		{ Name = "Platinum 1", XPRequired = 4500, Reward = { Type = "Skin", Id = "Platinum" } },

		-- Emerald Tier
		{ Name = "Emerald 5", XPRequired = 5000, Reward = { Type = "Title", Id = "Emerald" } },
		{ Name = "Emerald 4", XPRequired = 6000, Reward = { Type = "Currency", Amount = 2500 } },
		{ Name = "Emerald 3", XPRequired = 7000, Reward = { Type = "Aura", Id = "Emerald" } },
		{ Name = "Emerald 2", XPRequired = 8000, Reward = { Type = "Spins", Amount = 5 } },
		{ Name = "Emerald 1", XPRequired = 9000, Reward = { Type = "Skin", Id = "Emerald" } },

		-- Diamond Tier
		{ Name = "Diamond 5", XPRequired = 10000, Reward = { Type = "Title", Id = "Diamond" } },
		{ Name = "Diamond 4", XPRequired = 12500, Reward = { Type = "Currency", Amount = 5000 } },
		{ Name = "Diamond 3", XPRequired = 15000, Reward = { Type = "Aura", Id = "Diamond" } },
		{ Name = "Diamond 2", XPRequired = 17500, Reward = { Type = "Spins", Amount = 5 } },
		{ Name = "Diamond 1", XPRequired = 20000, Reward = { Type = "Skin", Id = "Diamond" } },

		-- Master Tier
		{ Name = "Master 5", XPRequired = 25000, Reward = { Type = "Title", Id = "Master" } },
		{ Name = "Master 4", XPRequired = 30000, Reward = { Type = "Currency", Amount = 10000 } },
		{ Name = "Master 3", XPRequired = 35000, Reward = { Type = "Aura", Id = "Master" } },
		{ Name = "Master 2", XPRequired = 40000, Reward = { Type = "Spins", Amount = 10 } },
		{ Name = "Master 1", XPRequired = 45000, Reward = { Type = "Skin", Id = "Master" } },

		-- Grandmaster (multiple rewards)
		{
			Name = "Grandmaster",
			XPRequired = 50000,
			Reward = {
				Type = "Multiple",
				Rewards = {
					{ Type = "Title", Id = "Grandmaster" },
					{ Type = "Aura", Id = "Grandmaster" },
					{ Type = "Skin", Id = "Grandmaster" },
				},
			},
		},
	},
})
