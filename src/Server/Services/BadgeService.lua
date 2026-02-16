--[[
	BadgeService.lua

	Description:
		Handles badge awards for players.
--]]

-- Root --
local BadgeService = {}

-- Roblox Services --
local BadgeServiceRoblox = game:GetService("BadgeService")
local Players = game:GetService("Players")

-- Dependencies --
local DataStream = shared("DataStream")
local BadgesConfig = shared("BadgesConfig")

-- Internal Functions --
local function AwardBadge(player, badgeId)
	if badgeId == 0 then
		return false
	end

	local stored = DataStream.Stored[player]
	if not stored then return false end

	local badges = stored.Badges:Read() or {}

	-- Check if player already has this badge
	if table.find(badges, badgeId) then
		return false
	end

	-- Check if badge exists and is enabled
	local success, badgeInfo = pcall(function()
		return BadgeServiceRoblox:GetBadgeInfoAsync(badgeId)
	end)

	if success and badgeInfo.IsEnabled then
		BadgeServiceRoblox:AwardBadgeAsync(player.UserId, badgeId)
		table.insert(badges, badgeId)
		stored.Badges = badges
		return true
	end

	return false
end

local function IsTeamMember(player)
	return table.find(BadgesConfig.TEAM_MEMBER_IDS, player.UserId) ~= nil
end

local function CheckPlayTheGameBadge(player)
	AwardBadge(player, BadgesConfig.PLAY_THE_GAME)
end

local function CheckRankBadges(player, rankIndex)
	local badgeKey = BadgesConfig.RANK_INDEX_TO_BADGE[rankIndex]
	if badgeKey then
		local badgeId = BadgesConfig[badgeKey]
		if badgeId then
			AwardBadge(player, badgeId)
		end
	end
end

local function AwardMeetTeamMemberToAll()
	for _, player in ipairs(Players:GetPlayers()) do
		if not IsTeamMember(player) then
			AwardBadge(player, BadgesConfig.MEET_TEAM_MEMBER)
		end
	end
end

local function CheckMeetTeamMemberBadge(player)
	if IsTeamMember(player) then
		AwardMeetTeamMemberToAll()
		return
	end

	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		if IsTeamMember(otherPlayer) then
			AwardBadge(player, BadgesConfig.MEET_TEAM_MEMBER)
			return
		end
	end
end

local function OnPlayerAdded(player)
	-- TODO - make promisse-based
	local stored = DataStream.Stored[player]
	if not stored then
		local startTime = tick()
		while not DataStream.Stored[player] and tick() - startTime < 10 do
			task.wait(0.5)
		end
		stored = DataStream.Stored[player]
		if not stored then
			warn("[BadgeService] Player data not loaded for:", player.Name)
			return
		end
	end

	CheckPlayTheGameBadge(player)
	CheckMeetTeamMemberBadge(player)
end

-- API Functions --
function BadgeService:CheckRankBadges(player, rankIndex)
	CheckRankBadges(player, rankIndex)
end
function BadgeService:IsTeamMember(player)
	return IsTeamMember(player)
end

-- Initializers --
function BadgeService:Init()
	Players.PlayerAdded:Connect(OnPlayerAdded)

	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(OnPlayerAdded, player)
	end
end

-- Return Module --
return BadgeService
