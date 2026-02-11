return {
	_VERSION = 2,

	Collections = {
		Currencies = {
			StepShards = 0,
			Momentum = 0,
		},
	},

	Stats = {
		CurrenciesGained = {
			StepShards = 0,
			Momentum = 0,
		},
		TotalStepsTaken = 0,
		TotalDistanceTraveled = 0,
		HighestCheckpointReached = 0,
		TotalRunsCompleted = 0,
		TotalCashouts = 0,
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
		Unlocked = { "Fluriflura", "GoldenFluriflura" }, -- Array of unlocked skin names
	},

	Titles = {
		Equipped = "Newbie", -- Currently equipped title ID (nil = no title)
		Unlocked = { "Newbie" }, -- Array of unlocked title IDs
	},
}
