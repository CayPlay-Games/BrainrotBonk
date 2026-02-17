return {
	_VERSION = 6,

	Collections = {
		Currencies = {
			Coins = 100000,
		},
		Titles = {
			Newbie = 1, -- Default title owned
		},
		Skins = {
			-- Format: SkinId_MutationId = 1
			FluriFlura_Normal = 1,
			FluriFlura_Golden = 1,
			TimCheese_Normal = 1,
			LiriliLarila_Normal = 1,
			TalpaDiFero_Normal = 1,
		},
	},

	Skins = {
		Equipped = "FluriFlura", -- Currently equipped skin ID
		EquippedMutation = "Normal", -- Which mutation variant is equipped
	},

	Titles = {
		Equipped = "Newbie", -- Currently equipped title ID (nil = no title)
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
		-- Lifetime stats for leaderboard tracking
		TotalKills = 0, -- Lifetime player-caused eliminations
		TotalRoundsPlayed = 0, -- Lifetime rounds completed
	},

	-- Biweekly leaderboard tracking
	Leaderboard = {
		-- Current period stats (reset every 2 weeks)
		PeriodStats = {
			Kills = 0,
			RoundsPlayed = 0,
			CashEarned = 0,
		},
		-- Period identifier to detect resets (format: "2024-BW07")
		CurrentPeriodId = "",
		-- Track rewards already claimed (array of period IDs)
		RewardsClaimed = {},
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
