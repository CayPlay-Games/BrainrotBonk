return {
	_VERSION = 3,

	Collections = {
		Currencies = {
			Coins = 0,
		},
	},

	Upgrades = {
		StartingSteps = 0,
		StepEfficiency = 0,
		JumpCostReduction = 0,
		JumpHeight = 0,
	},

	Level = {
		Current = 1,
		XP = 0,
	},

	Cosmetics = {},

	Skins = {
		Equipped = "Fluriflura", -- Currently equipped skin ID
		EquippedMutation = "Normal", -- Which mutation variant is equipped
		Collected = { -- Skins collected (unlocked if any mutation exists for skin)
			{ SkinId = "Fluriflura", Mutations = { "Normal", "Gold" } },
		},
	},

	Titles = {
		Equipped = "Newbie", -- Currently equipped title ID (nil = no title)
		Unlocked = { "Newbie" }, -- Array of unlocked title IDs
	},

	Auras = {
		Equipped = nil, -- Currently equipped aura ID (nil = none)
		Unlocked = {}, -- Array of unlocked aura IDs
	},

	Rank = {
		XP = 0, -- Total XP earned (rank calculated from this)
		LastRankRewarded = 0, -- Highest rank index that rewards have been given for
	},

	Spins = 0, -- Number of spins available
}
