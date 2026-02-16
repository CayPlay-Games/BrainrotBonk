--[[
	GroupRewardsConfig.lua

	Description:
		Configuration for group membership rewards.
		Players who join the Roblox group receive exclusive rewards.
--]]

local TableHelper = shared("TableHelper")

return TableHelper:DeepFreeze({
	-- Roblox Group ID
	GROUP_ID = 1048030758,

	-- Cash multiplier for group members
	CASH_MULTIPLIER = 1.1, -- 10% bonus

	-- Exclusive crate reward (auto-opened on join)
	CRATE_ID = "GroupExclusive",

	-- Title reward
	TITLE_ID = "CertifiedBonker",

	-- Chat tag settings
	CHAT_TAG = "Certified Bonker",
	CHAT_TAG_COLOR = Color3.fromRGB(0, 200, 255),
})
