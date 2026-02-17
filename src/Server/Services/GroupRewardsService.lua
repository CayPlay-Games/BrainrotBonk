--[[
	GroupRewardsService.lua

	Description:
		Handles group membership rewards.
		Players who join the Roblox group receive:
		- Exclusive crate (auto-opens with random skin from exclusive pool)
		- "Certified Bonker" title
		- 1.1x cash multiplier on all currency earned
--]]

-- Root --
local GroupRewardsService = {}

-- Roblox Services --
local Players = game:GetService("Players")

-- Dependencies --
local DataStream = shared("DataStream")
local DataService = shared("DataService")
local GroupRewardsConfig = shared("GroupRewardsConfig")
local SkinsConfig = shared("SkinsConfig")
local SkinBoxesConfig = shared("SkinBoxesConfig")
local GetRemoteEvent = shared("GetRemoteEvent")
local CollectionsService = shared("CollectionsService")

-- Remote Events --
local SkinBoxResultRemoteEvent = GetRemoteEvent("SkinBoxResult")

-- Private Variables --
local _GroupMemberCache = {} -- { [UserId] = boolean }

-- Internal Functions --
local function CheckGroupMembership(player)
	local userId = player.UserId

	-- Return cached result if available
	if _GroupMemberCache[userId] ~= nil then
		return _GroupMemberCache[userId]
	end

	local success, result = pcall(function()
		return player:IsInGroup(GroupRewardsConfig.GROUP_ID)
	end)

	if success then
		_GroupMemberCache[userId] = result
		return result
	else
		warn("[GroupRewardsService] Failed to check group membership:", result)
		return false
	end
end

-- Awards a skin to the player using Collections
local function AwardSkin(player, skinId, mutation)
	mutation = mutation or "Normal"

	if not SkinsConfig.Skins[skinId] then
		warn("[GroupRewardsService] Skin not found in config:", skinId)
		return false
	end

	local itemId = skinId .. "_" .. mutation
	local success = CollectionsService:GiveItem(player, "Skins", itemId, 1)
	return success
end

-- Grants all group rewards to a player
local function GrantGroupRewards(player)
	local stored = DataStream.Stored[player]
	if not stored then
		warn("[GroupRewardsService] No stored data for", player.Name)
		return
	end

	-- Always ensure title is unlocked for group members
	local titleId = GroupRewardsConfig.TITLE_ID
	local success, response = CollectionsService:GiveItem(player, "Titles", titleId, 1)
	print("[GroupRewardsService]", player.Name, "title awarded:", success, "titleId:", titleId, "response:", response)

	-- Check if already received one-time rewards
	local hasReceived = stored.ReceivedGroupRewards:Read()
	if hasReceived then
		return
	end

	-- TODO READD and test joining process
	-- -- Roll skin from exclusive crate
	-- local crateId = GroupRewardsConfig.CRATE_ID
	-- local skinId, mutation = SkinBoxesConfig:RollSkin(crateId)
	-- if not skinId then
	-- 	warn("[GroupRewardsService] Failed to roll skin from crate:", crateId)
	-- 	return
	-- end

	-- -- Award the rolled skin
	-- AwardSkin(player, skinId, mutation)

	-- Mark as received
	stored.ReceivedGroupRewards = true
	--DebugLog(player.Name, "granted all group rewards - rolled skin:", skinId)

	-- Trigger crate opening animation on client
	-- SkinBoxResultRemoteEvent:FireClient(player, {
	-- 	Success = true,
	-- 	BoxId = crateId,
	-- 	SkinId = skinId,
	-- 	Mutation = mutation,
	-- })
end

-- Handles player joining
local function OnPlayerAdded(player)
	-- Wait for profile data to be fully loaded (not just DataStream existence)
	DataService:OnPlayerDataLoaded(player, function()
		local isInGroup = CheckGroupMembership(player)
		print("[GroupRewardsService]", player.Name, "group check:", isInGroup, "groupId:", GroupRewardsConfig.GROUP_ID)
		if isInGroup then
			GrantGroupRewards(player)
		end
	end)
end

-- Handles player leaving
local function OnPlayerRemoving(player)
	_GroupMemberCache[player.UserId] = nil
end

-- API Functions --

function GroupRewardsService:IsPlayerInGroup(player)
	return CheckGroupMembership(player)
end

function GroupRewardsService:GetCashMultiplier(player)
	if CheckGroupMembership(player) then
		return GroupRewardsConfig.CASH_MULTIPLIER
	end
	return 1.0
end

-- Initializers --
function GroupRewardsService:Init()

	Players.PlayerAdded:Connect(OnPlayerAdded)
	Players.PlayerRemoving:Connect(OnPlayerRemoving)

	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(OnPlayerAdded, player)
	end
end

-- Return Module --
return GroupRewardsService
