--[[
	QuestService.lua

	Description:
		Foundational quest service.
		Tracks quest progress, handles reward claims, and exposes remotes for clients.
--]]

-- Root --
local QuestService = {}

-- Dependencies --
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local DataStream = shared("DataStream")
local DataService = shared("DataService")
local QuestsConfig = shared("QuestsConfig")
local CollectionsService = shared("CollectionsService")
local GetRemoteEvent = shared("GetRemoteEvent")
local GetRemoteFunction = shared("GetRemoteFunction")
local PlayerAddedHelper = shared("PlayerAddedHelper")

-- Remotes --
local GetQuestStatusRemote = GetRemoteFunction("GetQuestStatus")
local ClaimQuestRewardRemote = GetRemoteEvent("ClaimQuestReward")
local QuestStatusUpdatedRemote = GetRemoteEvent("QuestStatusUpdated")

-- Constants --
local DEFAULT_DAILY_RESET_SECONDS = 24 * 60 * 60
local DEFAULT_WEEKLY_RESET_SECONDS = 7 * 24 * 60 * 60

-- Private Variables --
local _QuestById = {}
local _PlaytimeTrackers = {}
local _PlaytimeHeartbeatConnection = nil

-- Internal Functions --
local function _IsQuestEnabled(quest)
	return quest and quest.Enabled ~= false
end

local function _OrganizeQuestsById()
	table.clear(_QuestById)

	for _, quest in ipairs(QuestsConfig.Quests or {}) do
		if type(quest.Id) == "string" then
			_QuestById[quest.Id] = quest
		end
	end
end

local function _GetQuestData(stored)
	if not stored.Quests then
		stored.Quests = {
			LastDailyReset = 0,
			LastWeeklyReset = 0,
			Progress = {},
			Claimed = {},
		}
	end

	local quests = stored.Quests
	if quests.LastDailyReset == nil then
		quests.LastDailyReset = 0
	end

	if quests.LastWeeklyReset == nil then
		quests.LastWeeklyReset = 0
	end

	if quests.Progress == nil then
		quests.Progress = {}
	end

	if quests.Claimed == nil then
		quests.Claimed = {}
	end

	return quests
end

local function _ResetDailyQuestsIfNeeded(questsStream, now)
	local resetSeconds = QuestsConfig.DAILY_RESET_SECONDS or DEFAULT_DAILY_RESET_SECONDS
	local lastReset = questsStream.LastDailyReset:Read() or 0

	if lastReset > 0 and (now - lastReset) < resetSeconds then
		return false
	end

	local claimed = questsStream.Claimed:Read() or {}
	local progress = questsStream.Progress:Read() or {}

	for _, quest in ipairs(QuestsConfig.Quests or {}) do
		if quest.IsDaily and _IsQuestEnabled(quest) then
			claimed[quest.Id] = nil
			progress[quest.Id] = 0
		end
	end

	questsStream.Claimed = claimed
	questsStream.Progress = progress
	questsStream.LastDailyReset = now

	return true
end

local function _ResetWeeklyQuestsIfNeeded(questsStream, now)
	local resetSeconds = QuestsConfig.WEEKLY_RESET_SECONDS or DEFAULT_WEEKLY_RESET_SECONDS
	local lastReset = questsStream.LastWeeklyReset:Read() or 0

	if lastReset > 0 and (now - lastReset) < resetSeconds then
		return false
	end

	local claimed = questsStream.Claimed:Read() or {}
	local progress = questsStream.Progress:Read() or {}

	for _, quest in ipairs(QuestsConfig.Quests or {}) do
		if quest.IsWeekly and _IsQuestEnabled(quest) then
			claimed[quest.Id] = nil
			progress[quest.Id] = 0
		end
	end

	questsStream.Claimed = claimed
	questsStream.Progress = progress
	questsStream.LastWeeklyReset = now

	return true
end

local function _ResetQuestProgressIfNeeded(questsStream, now)
	_ResetDailyQuestsIfNeeded(questsStream, now)
	_ResetWeeklyQuestsIfNeeded(questsStream, now)
end

local function _BuildStatus(player, now)
	local stored = DataStream.Stored[player]
	if not stored then
		return nil
	end

	local quests = _GetQuestData(stored)
	now = now or os.time()
	_ResetQuestProgressIfNeeded(quests, now)

	local progress = quests.Progress:Read() or {}
	local claimed = quests.Claimed:Read() or {}
	local statusQuests = {}

	for _, quest in ipairs(QuestsConfig.Quests or {}) do
		if not _IsQuestEnabled(quest) then
			continue
		end

		local current = math.max(0, tonumber(progress[quest.Id]) or 0)
		local goal = math.max(1, tonumber(quest.Goal) or 1)
		local complete = current >= goal
		local isClaimed = claimed[quest.Id] == true

		table.insert(statusQuests, {
			Id = quest.Id,
			DisplayName = quest.DisplayName or quest.Id,
			Description = quest.Description or "",
			Goal = goal,
			Progress = current,
			IsComplete = complete,
			IsClaimed = isClaimed,
			Reward = quest.Reward,
			ProgressKey = quest.ProgressKey,
			IsDaily = quest.IsDaily == true,
			IsWeekly = quest.IsWeekly == true,
		})
	end

	return {
		Now = now,
		LastDailyReset = quests.LastDailyReset:Read() or now,
		LastWeeklyReset = quests.LastWeeklyReset:Read() or now,
		Quests = statusQuests,
	}
end

local function _FireStatusUpdated(player)
	local status = _BuildStatus(player, os.time())
	if status then
		QuestStatusUpdatedRemote:FireClient(player, status)
	end
end

local function _GrantReward(player, questId)
	local quest = _QuestById[questId]
	if not quest or type(quest.Reward) ~= "table" then
		return false, "Invalid quest reward"
	end

	if quest.Reward.Type == "Coins" then
		local amount = tonumber(quest.Reward.Amount) or 0
		if amount <= 0 then
			return false, "Invalid coin amount"
		end

		local success = CollectionsService:GiveCurrency(
			player,
			"Coins",
			amount,
			Enum.AnalyticsEconomyTransactionType.Gameplay.Name,
			"Quest_" .. questId
		)

		if success ~= true then
			return false, "Failed to grant currency"
		end

		return true
	end

	if quest.Reward.Type == "Spins" then
		local amount = tonumber(quest.Reward.Amount) or 0
		if amount <= 0 then
			return false, "Invalid spin amount"
		end

		local stored = DataStream.Stored[player]
		if not stored then
			return false, "Data not loaded"
		end

		local currentSpins = stored.Spins:Read() or 0
		stored.Spins = currentSpins + amount
		return true
	end

	return false, "Unsupported reward type"
end

local function _BeginPlaytimeTracking(player)
	_PlaytimeTrackers[player] = _PlaytimeTrackers[player] or {
		Seconds = 0,
	}
end

local function _StopPlaytimeTracking(player)
	_PlaytimeTrackers[player] = nil
end

local function _EnsurePlaytimeHeartbeat()
	if _PlaytimeHeartbeatConnection then
		return
	end

	_PlaytimeHeartbeatConnection = RunService.Heartbeat:Connect(function(deltaTime)
		for player, tracker in pairs(_PlaytimeTrackers) do
			if player.Parent ~= Players then
				_StopPlaytimeTracking(player)
				continue
			end

			if not DataStream.Stored[player] then
				continue
			end

			tracker.Seconds += deltaTime
			if tracker.Seconds >= 60 then
				local minutes = math.floor(tracker.Seconds / 60)
				tracker.Seconds -= (minutes * 60)
				QuestService:IncrementProgressByKey(player, "PlayMinutes", minutes)
			end
		end
	end)
end

-- API Functions --
function QuestService:GetStatus(player)
	return _BuildStatus(player, os.time())
end

function QuestService:IncrementProgress(player, questId, amount)
	local stored = DataStream.Stored[player]
	if not stored then
		return false
	end

	local quest = _QuestById[questId]
	if not _IsQuestEnabled(quest) then
		return false
	end

	local quests = _GetQuestData(stored)
	_ResetQuestProgressIfNeeded(quests, os.time())

	local progress = quests.Progress:Read() or {}
	local goal = math.max(1, tonumber(quest.Goal) or 1)
	local current = math.max(0, tonumber(progress[questId]) or 0)
	local nextAmount = math.max(1, tonumber(amount) or 1)
	local nextValue = math.min(goal, current + nextAmount)

	if nextValue == current then
		return false
	end

	progress[questId] = nextValue
	quests.Progress = progress

	_FireStatusUpdated(player)

	return true
end

function QuestService:IncrementProgressByKey(player, progressKey, amount)
	if type(progressKey) ~= "string" then
		return false
	end

	local stored = DataStream.Stored[player]
	if not stored then
		return false
	end

	local quests = _GetQuestData(stored)
	_ResetQuestProgressIfNeeded(quests, os.time())
	local progress = quests.Progress:Read() or {}
	local nextAmount = math.max(1, tonumber(amount) or 1)

	local changed = false
	for _, quest in ipairs(QuestsConfig.Quests or {}) do
		if quest.ProgressKey == progressKey and _IsQuestEnabled(quest) then
			local goal = math.max(1, tonumber(quest.Goal) or 1)
			local current = math.max(0, tonumber(progress[quest.Id]) or 0)
			local nextValue = math.min(goal, current + nextAmount)

			if nextValue ~= current then
				progress[quest.Id] = nextValue
				changed = true
			end
		end
	end

	if changed then
		quests.Progress = progress
		_FireStatusUpdated(player)
	end

	return changed
end

function QuestService:ClaimQuest(player, questId)
	local stored = DataStream.Stored[player]
	if not stored then
		return false, "Data not loaded"
	end

	local quest = _QuestById[questId]
	if not _IsQuestEnabled(quest) then
		return false, "Unknown quest"
	end

	local quests = _GetQuestData(stored)
	_ResetQuestProgressIfNeeded(quests, os.time())

	local claimed = quests.Claimed:Read() or {}
	if claimed[questId] == true then
		return false, "Already claimed"
	end

	local progress = quests.Progress:Read() or {}
	local current = math.max(0, tonumber(progress[questId]) or 0)
	local goal = math.max(1, tonumber(quest.Goal) or 1)

	if current < goal then
		return false, "Quest incomplete"
	end

	local granted, grantError = _GrantReward(player, questId)
	if granted ~= true then
		return false, grantError or "Reward grant failed"
	end

	claimed[questId] = true
	quests.Claimed = claimed

	_FireStatusUpdated(player)

	return true
end

-- Initializers --
function QuestService:Init()
	_OrganizeQuestsById()
	_EnsurePlaytimeHeartbeat()

	GetQuestStatusRemote.OnServerInvoke = function(player)
		return self:GetStatus(player)
	end

	ClaimQuestRewardRemote.OnServerEvent:Connect(function(player, questId)
		if type(questId) ~= "string" then
			return
		end

		local success, errorMessage = self:ClaimQuest(player, questId)
		if not success then
			warn("[QuestService] Claim failed:", player.Name, questId, errorMessage)
		end
	end)

	PlayerAddedHelper:OnPlayerAdded(function(player)
		DataService:OnPlayerDataLoaded(player, function()
			local stored = DataStream.Stored[player]
			if not stored then
				return
			end

			local quests = _GetQuestData(stored)
			_ResetQuestProgressIfNeeded(quests, os.time())
			_BeginPlaytimeTracking(player)
			_FireStatusUpdated(player)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		_StopPlaytimeTracking(player)
	end)
end

-- Return Module --
return QuestService
