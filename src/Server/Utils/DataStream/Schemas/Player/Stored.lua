return {
	_VERSION = 3,

	Collections = {
		Currencies = {
			Coins = 100000,
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
		Equipped = "FluriFlura", -- Currently equipped skin ID
		EquippedMutation = "Normal", -- Which mutation variant is equipped
		Collected = { -- Skins collected (unlocked if any mutation exists for skin)
			{ SkinId = "FluriFlura", Mutations = { "Normal", "Golden" } },
			{ SkinId = "TimCheese", Mutations = { "Normal" } },
			{ SkinId = "LiriliLarila", Mutations = { "Normal" } },
			{ SkinId = "TalpaDiFero", Mutations = { "Normal" } },
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

	Stats = {
		CurrenciesGained = {
			Coins = 0, -- Total coins earned (lifetime)
		},
	},

	Spins = 0, -- Number of spins available
	PrizeWheel = {
		LastSpin = 0, -- os.time() of last wheel spin
		ProgressiveTier = 1, -- Current progressive reward tier index
		ProgressiveSpins = 0, -- Spins accumulated toward current progressive tier
		ProgressiveVersion = 1, -- Config version used for progressive reset
	},

	DailyRewards = {
		CurrentDay = 1, -- Current day to claim (1-7)
		LastClaimTime = 0, -- os.time() of last claim (0 = never claimed)
		CycleCount = 1, -- Which cycle we're on (determines Day 7 skin)
	},

	Quests = {
		LastDailyReset = 0, -- os.time() when daily quest progress was last reset
		LastWeeklyReset = 0, -- os.time() when weekly quest progress was last reset
		Progress = {}, -- { [QuestId] = number }
		Claimed = {}, -- { [QuestId] = true }
	},

	-- Monetization tracking
	PurchaseReceiptsProcessed = {}, -- { [PurchaseId] = true } - prevents duplicate processing
	Monetization = {
		TotalRobuxSpent = 0, -- Lifetime Robux spent
		ProductsBought = {}, -- { [ProductIdString] = count }
	},

	-- Group membership rewards
	ReceivedGroupRewards = false, -- True if player received group membership rewards

	-- Badges earned (array of badge IDs)
	Badges = {},
}
