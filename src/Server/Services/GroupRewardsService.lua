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
local GroupRewardsConfig = shared("GroupRewardsConfig")
local SkinsConfig = shared("SkinsConfig")
local SkinBoxesConfig = shared("SkinBoxesConfig")
local GetRemoteEvent = shared("GetRemoteEvent")

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

-- Awards a skin to the player
local function AwardSkin(player, skinId, mutation)
	mutation = mutation or "Normal"

	local stored = DataStream.Stored[player]
	if not stored then return false end

	if not SkinsConfig.Skins[skinId] then
		warn("[GroupRewardsService] Skin not found in config:", skinId)
		return false
	end

	local collected = stored.Skins.Collected:Read() or {}

	-- Check if player already owns this skin
	for _, entry in ipairs(collected) do
		if entry.SkinId == skinId then
			-- Already owns skin, check for mutation
			if not table.find(entry.Mutations, mutation) then
				table.insert(entry.Mutations, mutation)
				stored.Skins.Collected = collected
			end
			return true
		end
	end

	-- Add new skin with the mutation
	table.insert(collected, {
		SkinId = skinId,
		Mutations = { mutation },
	})
	stored.Skins.Collected = collected
	return true
end

-- Awards a title to the player
local function AwardTitle(player, titleId)
	local stored = DataStream.Stored[player]
	if not stored then return false end

	local unlocked = stored.Titles.Unlocked:Read() or {}
	if not table.find(unlocked, titleId) then
		table.insert(unlocked, titleId)
		stored.Titles.Unlocked = unlocked
		return true
	end

	return false -- Already unlocked
end

-- Grants all group rewards to a player
local function GrantGroupRewards(player)
	local stored = DataStream.Stored[player]
	if not stored then return end

	-- Check if already received
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

	-- Award title
	AwardTitle(player, GroupRewardsConfig.TITLE_ID)

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
	-- Wait for data to be ready
	-- TODO - add promise-based waiting in DataStream
	local stored = DataStream.Stored[player]
	if not stored then
		-- Wait for data to load
		local startTime = tick()
		while not DataStream.Stored[player] and tick() - startTime < 10 do
			task.wait(0.5)
		end
		stored = DataStream.Stored[player]
		if not stored then
			warn("[GroupRewardsService] Player data not loaded for:", player.Name)
			return
		end
	end

	if CheckGroupMembership(player) then
		GrantGroupRewards(player)
	end
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
