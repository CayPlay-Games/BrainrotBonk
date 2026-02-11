--[[
	RankHelper.lua

	Description:
		Shared helper functions for rank calculations.
		Used by both server (RankService) and client (RankWindowController).
--]]

-- Root --
local RankHelper = {}

-- Dependencies --
local RankConfig = shared("RankConfig")

-- API Functions --

-- Calculate rank index from XP (0 = unranked)
function RankHelper:CalculateRankFromXP(xp)
	local rankIndex = 0
	for i, rank in ipairs(RankConfig.Ranks) do
		if xp >= rank.XPRequired then
			rankIndex = i
		else
			break
		end
	end
	return rankIndex
end

-- Get rank info by index
function RankHelper:GetRankInfo(rankIndex)
	if rankIndex <= 0 then
		return { Index = 0, Name = "Unranked", XPRequired = 0, Reward = nil }
	end
	local rank = RankConfig.Ranks[rankIndex]
	if not rank then
		return { Index = 0, Name = "Unranked", XPRequired = 0, Reward = nil }
	end
	return {
		Index = rankIndex,
		Name = rank.Name,
		XPRequired = rank.XPRequired,
		Reward = rank.Reward,
	}
end

-- Get XP progress info for display
function RankHelper:GetXPProgress(currentXP)
	local currentRank = self:CalculateRankFromXP(currentXP)
	local prevXP = currentRank > 0 and RankConfig.Ranks[currentRank].XPRequired or 0
	local nextRank = RankConfig.Ranks[currentRank + 1]
	local nextXP = nextRank and nextRank.XPRequired or prevXP

	return {
		CurrentXP = currentXP,
		PrevXP = prevXP,
		NextXP = nextXP,
		CurrentRankIndex = currentRank,
		IsMaxRank = currentRank >= #RankConfig.Ranks,
	}
end

-- Convert reward to display text
function RankHelper:GetRewardText(reward)
	if not reward then return "Unknown" end

	if reward.Type == "Title" then
		return "S1 " .. reward.Id .. " Title"
	elseif reward.Type == "Currency" then
		return reward.Amount .. " Coins"
	elseif reward.Type == "Aura" then
		return reward.Id .. " Aura"
	elseif reward.Type == "Spins" then
		return reward.Amount .. " Spins"
	elseif reward.Type == "Skin" then
		return reward.Id .. " Skin"
	elseif reward.Type == "Multiple" then
		local texts = {}
		for _, r in ipairs(reward.Rewards) do
			table.insert(texts, self:GetRewardText(r))
		end
		return table.concat(texts, ", ")
	end

	return "Unknown"
end

-- Get total number of ranks
function RankHelper:GetTotalRanks()
	return #RankConfig.Ranks
end

-- Get tier name from rank name (e.g., "Bronze 5" -> "Bronze", "Grandmaster" -> "Grandmaster")
function RankHelper:GetTierFromRankName(rankName)
	-- Split by space and take first part
	local tier = rankName:match("^(%S+)")
	return tier or rankName
end

-- Get gradient for a rank by index
function RankHelper:GetRankGradient(rankIndex)
	if rankIndex <= 0 then return nil end

	local rank = RankConfig.Ranks[rankIndex]
	if not rank then return nil end

	local tier = self:GetTierFromRankName(rank.Name)
	return RankConfig.TierGradients[tier]
end

-- Return Module --
return RankHelper
