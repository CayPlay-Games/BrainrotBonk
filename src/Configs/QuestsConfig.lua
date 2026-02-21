--[[
	QuestsConfig.lua

	Description:
		Base quest definitions used by QuestService.
		This is intentionally small so gameplay systems can hook into it incrementally.
--]]

local TableHelper = shared("TableHelper")

return TableHelper:DeepFreeze({
	-- Daily quests reset every 24h from the player's first daily quest initialization.
	DAILY_RESET_SECONDS = 24 * 60 * 60,
	WEEKLY_RESET_SECONDS = 7 * 24 * 60 * 60,

	Quests = {
		-- Daily
		{
			Id = "Daily_Knockouts_5",
			DisplayName = "Get 5 Knockouts!",
			Description = "Eliminate 5 players.",
			Goal = 5,
			ProgressKey = "Eliminations",
			Reward = { Type = "Coins", Icon = "rbxassetid://77415160916986", Amount = 300 },
			IsDaily = true,
		},
		{
			Id = "Daily_PlayMinutes_10",
			DisplayName = "Play for 10 Minutes!",
			Description = "Stay in-game for 10 minutes.",
			Goal = 10,
			ProgressKey = "PlayMinutes",
			Reward = { Type = "Spins", Icon = "rbxassetid://129315303403075", Amount = 1 },
			IsDaily = true,
		},
		{
			Id = "Daily_WinRounds_3",
			DisplayName = "Win 3 Rounds!",
			Description = "Place 1st in 3 rounds.",
			Goal = 3,
			ProgressKey = "RoundsWon",
			Reward = { Type = "Spins", Icon = "rbxassetid://129315303403075", Amount = 1 },
			IsDaily = true,
		},
		{
			Id = "Daily_PlayRounds_5",
			DisplayName = "Play 5 Rounds!",
			Description = "Complete 5 rounds.",
			Goal = 5,
			ProgressKey = "RoundsPlayed",
			Reward = { Type = "Coins", Icon = "rbxassetid://88203938574568", Amount = 500 },
			IsDaily = true,
		},

		-- Weekly
		{
			Id = "Weekly_Knockouts_20",
			DisplayName = "Get 20 Knockouts!",
			Description = "Eliminate 20 players this week.",
			Goal = 20,
			ProgressKey = "Eliminations",
			Reward = { Type = "Coins", Icon = "rbxassetid://112695884143780", Amount = 1500 },
			IsWeekly = true,
		},
		{
			Id = "Weekly_PlayMinutes_60",
			DisplayName = "Play for 60 Minutes!",
			Description = "Stay in-game for 60 minutes this week.",
			Goal = 60,
			ProgressKey = "PlayMinutes",
			Reward = { Type = "Spins", Icon = "rbxassetid://131716603406642", Amount = 3 },
			IsWeekly = true,
		},
		{
			Id = "Weekly_WinRounds_25",
			DisplayName = "Win 25 Rounds!",
			Description = "Place 1st in 25 rounds this week.",
			Goal = 25,
			ProgressKey = "RoundsWon",
			Reward = { Type = "Spins", Icon = "rbxassetid://129315303403075", Amount = 5 },
			IsWeekly = true,
		},
		{
			Id = "Weekly_PlayRounds_100",
			DisplayName = "Play 100 Rounds!",
			Description = "Complete 100 rounds this week.",
			Goal = 100,
			ProgressKey = "RoundsPlayed",
			Reward = { Type = "Coins", Icon = "rbxassetid://129315303403075", Amount = 4000 },
			IsWeekly = true,
		},
		{
			Id = "Weekly_RollBlocks_X",
			DisplayName = "Roll X Blocks",
			Description = "Disabled until block rolling tracking is ready.",
			Goal = 100,
			ProgressKey = "BlocksRolled",
			Reward = { Type = "Coins", Icon = "rbxassetid://112695884143780", Amount = 5000 },
			IsWeekly = true,
			Enabled = false,
		},
	},
})
