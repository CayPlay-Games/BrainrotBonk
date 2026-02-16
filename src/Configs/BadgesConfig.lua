--[[
	BadgesConfig.lua

	Description:
		Configuration for game badges.
--]]

local TableHelper = shared("TableHelper")

return TableHelper:DeepFreeze({
	PLAY_THE_GAME = 975767678289334,

	-- Rank 1 badges (one per tier)
	RANK_BRONZE_1 = 1516916426087698,
	RANK_SILVER_1 = 3293152999022040,
	RANK_GOLD_1 = 3339736125179561,
	RANK_PLATINUM_1 = 0,
	RANK_EMERALD_1 = 0,
	RANK_DIAMOND_1 = 0,
	RANK_MASTER_1 = 0,
	RANK_GRANDMASTER = 0,

	MEET_TEAM_MEMBER = 335919504115778,

	TEAM_MEMBER_IDS = {
		-- Add team member user IDs here
		3227249514,
		381863,
		7160674252,
		2760321619,
		8982212592,
		254301387,
		384639097,
		2657540898

	},

	-- Map rank index to badge ID key
	-- Rank 1 in each tier is at index: 5, 10, 15, 20, 25, 30, 35, 41
	RANK_INDEX_TO_BADGE = {
		[5] = "RANK_BRONZE_1",
		[10] = "RANK_SILVER_1",
		[15] = "RANK_GOLD_1",
		[20] = "RANK_PLATINUM_1",
		[25] = "RANK_EMERALD_1",
		[30] = "RANK_DIAMOND_1",
		[35] = "RANK_MASTER_1",
		[41] = "RANK_GRANDMASTER",
	},
})
