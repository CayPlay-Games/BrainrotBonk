--[[
	LeaderboardConfig.lua

	Description:
		Configuration for the biweekly leaderboard system.
		Defines categories, prizes, and period settings.
--]]

local TableHelper = shared("TableHelper")

-- TESTING: Set to true to make period end shortly after server start
local TESTING_MODE = false
local TESTING_PERIOD_SECONDS = 60

-- Period duration
local PERIOD_DURATION_DAYS = 14
local PERIOD_DURATION_SECONDS = PERIOD_DURATION_DAYS * 86400

local PERIOD_START_TIMESTAMP
if TESTING_MODE then
	-- Set start so we're TESTING_PERIOD_SECONDS away from period end
	PERIOD_START_TIMESTAMP = os.time() - (PERIOD_DURATION_SECONDS - TESTING_PERIOD_SECONDS)
else
	-- Production: Feb 17, 2025 00:00:00 UTC
	PERIOD_START_TIMESTAMP = 1739750400
end

-- Gradient colors for top 3 ranks
local RankGradients = {
	[1] = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 215, 0)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 160, 0)),
	}),
	[2] = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(192, 192, 192)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(140, 140, 150)),
	}),
	[3] = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(205, 127, 50)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(139, 90, 43)),
	}),
}

return TableHelper:DeepFreeze({
	-- CollectionService tags for world boards
	BOARD_TAG = "Leaderboard",
	TIMER_TAG = "LeaderboardTimer",

	-- How often to refresh world boards
	BOARD_REFRESH_INTERVAL = 60,

	-- Period duration in days
	PERIOD_DURATION_DAYS = PERIOD_DURATION_DAYS,

	-- Starting point for period calculation (Unix timestamp)
	PERIOD_START_TIMESTAMP = PERIOD_START_TIMESTAMP,

	-- Testing mode - skips "already processed" check for rewards
	TESTING_MODE = TESTING_MODE,

	-- How often to save to OrderedDataStore
	SAVE_INTERVAL = 300, -- 5 minutes

	-- Debounce time for individual stat writes
	UPDATE_DEBOUNCE = 30,

	-- Cache expiry for leaderboard data
	CACHE_EXPIRY = 5,

	-- Maximum entries to display
	MAX_DISPLAY_ENTRIES = 18,

	-- Gradients for top 3 row styling
	RankGradients = RankGradients,

	-- Leaderboard categories
	Categories = {
		{
			Id = "Kills",
			DisplayName = "Most Eliminations",
			ShortName = "Eliminations",
			TitleGradient = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 0, 0)),
			}),
			Prizes = {
				[1] = { SkinId = "KillsChampion", Mutation = "Golden" },
				[2] = { SkinId = "KillsChampion", Mutation = "Normal" },
				[3] = { SkinId = "KillsChampion", Mutation = "Normal" },
			},
		},
		{
			Id = "Rounds",
			DisplayName = "Most Rounds Played",
			ShortName = "Rounds",
			TitleGradient = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 183, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 123, 200)),
			}),
			Prizes = {
				[1] = { SkinId = "RoundsChampion", Mutation = "Golden" },
				[2] = { SkinId = "RoundsChampion", Mutation = "Normal" },
				[3] = { SkinId = "RoundsChampion", Mutation = "Normal" },
			},
		},
		{
			Id = "Cash",
			DisplayName = "Most Cash Earned",
			ShortName = "Cash",
			TitleGradient = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 215, 0)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 160, 0)),
			}),
			Prizes = {
				[1] = { SkinId = "CashChampion", Mutation = "Golden" },
				[2] = { SkinId = "CashChampion", Mutation = "Normal" },
				[3] = { SkinId = "CashChampion", Mutation = "Normal" },
			},
		},
	},

	-- DataStore key prefix for pending offline rewards
	PENDING_REWARDS_STORE = "LeaderboardPendingRewards",

	-- DataStore key prefix for tracking processed periods
	PROCESSED_PERIODS_STORE = "LeaderboardProcessedPeriods",
})
