--[[
	LeaderboardService.lua

	Description:
		Manages biweekly leaderboards with kills, rounds played, and cash categories.
		Handles period transitions, OrderedDataStore updates, and reward distribution.
--]]

-- Root --
local LeaderboardService = {}

-- Roblox Services --
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

-- Dependencies --
local DataStream = shared("DataStream")
local LeaderboardConfig = shared("LeaderboardConfig")
local SkinsConfig = shared("SkinsConfig")
local GetSafeDataStoreName = shared("GetSafeDataStoreName")
local FormatHelper = shared("FormatHelper")
local CollectionsService = shared("CollectionsService")

-- Private Variables --
local _PendingUpdates = {} -- userId -> { category -> value }
local _LastUpdateTime = {} -- userId -> category -> timestamp
local _CachedLeaderboards = {} -- category_periodId -> { data, timestamp }
local _CachedPeriodId = nil -- cached period ID string
local _PeriodCacheTime = 0 -- timestamp when period was cached
local _LastPeriodCheck = {} -- userId -> timestamp for debouncing CheckAndResetPeriod
local _NameCache = {} -- userId -> displayName
local PERIOD_DURATION_SECONDS = LeaderboardConfig.PERIOD_DURATION_DAYS * 86400

-- Build category config lookup table at load time
local _CategoryConfigLookup = {}
for _, config in ipairs(LeaderboardConfig.Categories) do
	_CategoryConfigLookup[config.Id] = config
end

-- Internal Functions --
local function GetCurrentPeriodId()
	local now = os.time()
	if _CachedPeriodId and now - _PeriodCacheTime < 3600 then
		return _CachedPeriodId
	end

	-- Calculate elapsed time from start and determine period number
	local elapsed = now - LeaderboardConfig.PERIOD_START_TIMESTAMP
	local periodNumber = math.floor(elapsed / PERIOD_DURATION_SECONDS) + 1

	-- Format: "P001", "P002", etc.
	_CachedPeriodId = string.format("P%03d", periodNumber)
	_PeriodCacheTime = now
	return _CachedPeriodId
end

local function GetLeaderboardStore(category, periodId)
	local storeName = GetSafeDataStoreName(string.format("Leaderboard_%s_%s", category, periodId))
	return DataStoreService:GetOrderedDataStore(storeName)
end

local function GetPendingRewardsStore()
	local storeName = GetSafeDataStoreName(LeaderboardConfig.PENDING_REWARDS_STORE)
	return DataStoreService:GetDataStore(storeName)
end

local function GetProcessedPeriodsStore()
	local storeName = GetSafeDataStoreName(LeaderboardConfig.PROCESSED_PERIODS_STORE)
	return DataStoreService:GetDataStore(storeName)
end

local function IsPeriodProcessed(periodId)
	local store = GetProcessedPeriodsStore()
	local success, result = pcall(function()
		return store:GetAsync(periodId)
	end)
	return success and result == true
end

local function MarkPeriodProcessed(periodId)
	local store = GetProcessedPeriodsStore()
	pcall(function()
		store:SetAsync(periodId, true)
	end)
end

local function GetCategoryConfig(categoryId)
	return _CategoryConfigLookup[categoryId]
end

local function GetDisplayName(userId)
	if _NameCache[userId] then
		return _NameCache[userId]
	end
	local success, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local displayName = success and ("@" .. name) or "Unknown"
	_NameCache[userId] = displayName
	return displayName
end

local function FindSurfaceGui(instance)
	local surfaceGui = instance:FindFirstChildOfClass("SurfaceGui")
	if not surfaceGui and instance:IsA("Model") and instance.PrimaryPart then
		surfaceGui = instance.PrimaryPart:FindFirstChildOfClass("SurfaceGui")
	end
	if not surfaceGui then
		surfaceGui = instance:FindFirstChildWhichIsA("SurfaceGui", true)
	end
	return surfaceGui
end

local function CheckAndResetPeriod(player)
	local now = tick()
	local userId = player.UserId
	if _LastPeriodCheck[userId] and now - _LastPeriodCheck[userId] < 1 then
		return -- Already checked this second
	end
	_LastPeriodCheck[userId] = now

	local stored = DataStream.Stored[player]
	if not stored then return end

	local currentPeriod = GetCurrentPeriodId()
	local playerPeriod = stored.Leaderboard.CurrentPeriodId:Read() or ""

	if playerPeriod ~= currentPeriod then
		-- New period - reset stats
		stored.Leaderboard.PeriodStats.Kills = 0
		stored.Leaderboard.PeriodStats.RoundsPlayed = 0
		stored.Leaderboard.PeriodStats.CashEarned = 0
		stored.Leaderboard.CurrentPeriodId = currentPeriod
	end
end

-- Update OrderedDataStore entry (debounced)
local function QueueDataStoreUpdate(player, category, value)
	local userId = player.UserId
	local now = tick()

	_LastUpdateTime[userId] = _LastUpdateTime[userId] or {}
	local lastUpdate = _LastUpdateTime[userId][category] or 0

	if now - lastUpdate < LeaderboardConfig.UPDATE_DEBOUNCE then
		-- Queue for later
		_PendingUpdates[userId] = _PendingUpdates[userId] or {}
		_PendingUpdates[userId][category] = value
		return
	end

	-- Update immediately
	_LastUpdateTime[userId][category] = now
	local periodId = GetCurrentPeriodId()

	task.spawn(function()
		local store = GetLeaderboardStore(category, periodId)

		local success, err = pcall(function()
			store:SetAsync(tostring(userId), value)
		end)

		if not success then
			warn("[LeaderboardService] Failed to update", category, "for", userId, ":", err)
		end
	end)
end

-- Flush pending updates for a player
local function FlushPendingUpdates(userId)
	local pending = _PendingUpdates[userId]
	if not pending then return end

	local periodId = GetCurrentPeriodId()

	for category, value in pairs(pending) do
		task.spawn(function()
			local store = GetLeaderboardStore(category, periodId)

			pcall(function()
				store:SetAsync(tostring(userId), value)
			end)
		end)
	end

	_PendingUpdates[userId] = nil
	_LastUpdateTime[userId] = nil
	_LastPeriodCheck[userId] = nil
end

-- API Functions --

-- Increment kill count for player
function LeaderboardService:IncrementKills(player, amount)
	amount = amount or 1

	local stored = DataStream.Stored[player]
	if not stored then return end

	CheckAndResetPeriod(player)

	-- Update lifetime stats
	local totalKills = stored.Stats.TotalKills:Read() or 0
	stored.Stats.TotalKills = totalKills + amount

	-- Update period stats
	local periodKills = stored.Leaderboard.PeriodStats.Kills:Read() or 0
	local newValue = periodKills + amount
	stored.Leaderboard.PeriodStats.Kills = newValue

	-- Queue OrderedDataStore update
	QueueDataStoreUpdate(player, "Kills", newValue)
end

-- Increment rounds played for player
function LeaderboardService:IncrementRoundsPlayed(player, amount)
	amount = amount or 1

	local stored = DataStream.Stored[player]
	if not stored then return end

	CheckAndResetPeriod(player)

	-- Update lifetime stats
	local totalRounds = stored.Stats.TotalRoundsPlayed:Read() or 0
	stored.Stats.TotalRoundsPlayed = totalRounds + amount

	-- Update period stats
	local periodRounds = stored.Leaderboard.PeriodStats.RoundsPlayed:Read() or 0
	local newValue = periodRounds + amount
	stored.Leaderboard.PeriodStats.RoundsPlayed = newValue

	-- Queue OrderedDataStore update
	QueueDataStoreUpdate(player, "Rounds", newValue)
end

-- Add cash earned for leaderboard tracking
function LeaderboardService:AddCashEarned(player, amount)
	local stored = DataStream.Stored[player]
	if not stored then return end

	CheckAndResetPeriod(player)

	-- Update period stats (lifetime is tracked in Stats.CurrenciesGained.Coins)
	local periodCash = stored.Leaderboard.PeriodStats.CashEarned:Read() or 0
	local newValue = periodCash + amount
	stored.Leaderboard.PeriodStats.CashEarned = newValue

	-- Queue OrderedDataStore update
	QueueDataStoreUpdate(player, "Cash", newValue)
end

function LeaderboardService:GetTop(category, count, periodId)
	periodId = periodId or GetCurrentPeriodId()
	count = count or LeaderboardConfig.MAX_DISPLAY_ENTRIES

	local cacheKey = category .. "_" .. periodId
	local cached = _CachedLeaderboards[cacheKey]
	if cached and tick() - cached.timestamp < LeaderboardConfig.CACHE_EXPIRY then
		return cached.data
	end

	local store = GetLeaderboardStore(category, periodId)
	local success, pages = pcall(function()
		return store:GetSortedAsync(false, count)
	end)

	if not success then
		warn("[LeaderboardService] Failed to fetch", category, "leaderboard:", pages)
		return {}
	end

	local currentPage = pages:GetCurrentPage()
	local results = {}

	for rank, entry in ipairs(currentPage) do
		table.insert(results, {
			Rank = rank,
			UserId = tonumber(entry.key),
			Value = entry.value,
			FormattedValue = FormatHelper:FormatNumber(entry.value),
		})
	end

	-- Cache results
	_CachedLeaderboards[cacheKey] = {
		data = results,
		timestamp = tick(),
	}

	return results
end

-- Get player's rank in a category
function LeaderboardService:GetPlayerRank(player, category)
	local periodId = GetCurrentPeriodId()
	local store = GetLeaderboardStore(category, periodId)

	local success, rank = pcall(function()
		return store:GetRankAsync(tostring(player.UserId))
	end)

	if success and rank then
		return rank + 1 -- GetRankAsync returns 0-indexed
	end

	return nil
end

function LeaderboardService:GetTimeRemaining()
	local now = os.time()

	-- Calculate elapsed time from start
	local elapsed = now - LeaderboardConfig.PERIOD_START_TIMESTAMP

	-- Time into current period
	local timeIntoPeriod = elapsed % PERIOD_DURATION_SECONDS

	-- Remaining time in current period
	return PERIOD_DURATION_SECONDS - timeIntoPeriod
end

function LeaderboardService:AwardLeaderboardSkin(player, skinId, mutation, periodId)
	mutation = mutation or "Normal"

	local stored = DataStream.Stored[player]
	if not stored then return false end

	if not SkinsConfig.Skins[skinId] then
		warn("[LeaderboardService] Skin not found in SkinsConfig:", skinId)
		return false
	end

	local itemId = skinId .. "_" .. mutation
	local success = CollectionsService:GiveItem(player, "Skins", itemId, 1)

	-- Track that reward was claimed for this period
	if success and periodId then
		local claimed = stored.Leaderboard.RewardsClaimed:Read() or {}
		if not table.find(claimed, periodId) then
			table.insert(claimed, periodId)
			stored.Leaderboard.RewardsClaimed = claimed
		end
	end
	return success
end

-- Queue reward for offline player
function LeaderboardService:QueueOfflineReward(userId, skinReward, periodId, category, rank)
	local store = GetPendingRewardsStore()

	pcall(function()
		local pending = store:GetAsync(tostring(userId)) or {}
		table.insert(pending, {
			SkinId = skinReward.SkinId,
			Mutation = skinReward.Mutation,
			PeriodId = periodId,
			Category = category,
			Rank = rank,
			Timestamp = os.time(),
		})
		store:SetAsync(tostring(userId), pending)
	end)
end

-- Check and deliver pending rewards on player join
function LeaderboardService:CheckPendingRewards(player)
	local store = GetPendingRewardsStore()

	local success, pending = pcall(function()
		return store:GetAsync(tostring(player.UserId))
	end)

	if success and pending and #pending > 0 then
		for _, reward in ipairs(pending) do
			self:AwardLeaderboardSkin(player, reward.SkinId, reward.Mutation, reward.PeriodId)
		end
		pcall(function()
			store:RemoveAsync(tostring(player.UserId))
		end)
	end
end

local _NextRefreshTime = 0
local _InitializedBoards = {} -- board -> true (tracks boards that have had title set)

local function UpdateSharedTimer(timeRemaining)
	local timers = CollectionService:GetTagged(LeaderboardConfig.TIMER_TAG)
	local refreshIn = math.max(0, math.ceil(_NextRefreshTime - tick()))

	for _, timer in ipairs(timers) do
		local surfaceGui = FindSurfaceGui(timer)
		if surfaceGui then
			-- Update period reset timer
			local timeLabel = surfaceGui:FindFirstChild("TimeRemaining", true)
				or surfaceGui:FindFirstChild("Time", true)
				or surfaceGui:FindFirstChild("Countdown", true)
			if timeLabel and timeLabel:IsA("TextLabel") then
				timeLabel.Text = "Leaderboards reset in " .. FormatHelper:FormatTime(timeRemaining)
			end

			-- Update refresh countdown (optional separate label)
			local refreshLabel = surfaceGui:FindFirstChild("RefreshIn", true)
				or surfaceGui:FindFirstChild("NextRefresh", true)
			if refreshLabel and refreshLabel:IsA("TextLabel") then
				refreshLabel.Text = "Refreshing in " .. tostring(refreshIn) .. "s"
			end
		end
	end
end

local function PopulateTitle(board, categoryConfig)
	local titlePart = board:FindFirstChild("Title")
	if not titlePart then return end

	local surfaceGui = FindSurfaceGui(titlePart)
	if not surfaceGui then return end

	local textLabel = surfaceGui:FindFirstChildOfClass("TextLabel")
	if not textLabel then return end

	textLabel.Text = categoryConfig.DisplayName or categoryConfig.Id

	local gradient = textLabel:FindFirstChildOfClass("UIGradient")
	if gradient and categoryConfig.TitleGradient then
		gradient.Color = categoryConfig.TitleGradient
	end

	local stroke = textLabel:FindFirstChildOfClass("UIStroke")
	if stroke and categoryConfig.TitleGradient then
		local keypoints = categoryConfig.TitleGradient.Keypoints
		local lastColor = keypoints[#keypoints].Value
		stroke.Color = FormatHelper:DarkenColor(lastColor, 70)
	end
end

local _AvatarCache = {} -- userId -> thumbnailUrl

local DEFAULT_ROW_COLOR = Color3.fromRGB(125, 125, 125)

-- Helper to update a single row with entry data
local function UpdateRow(row, rank, entry)
	row.Visible = true
	row.LayoutOrder = rank

	-- Apply rank gradient for top 3, default gray for others
	local rankGradient = LeaderboardConfig.RankGradients[rank]
	local gradient = row:FindFirstChildOfClass("UIGradient")

	if rankGradient then
		row.BackgroundColor3 = Color3.new(1, 1, 1) -- White for gradient to display properly
		if gradient then
			gradient.Enabled = true
			gradient.Color = rankGradient
		end
	else
		row.BackgroundColor3 = DEFAULT_ROW_COLOR
		if gradient then
			gradient.Enabled = false
		end
	end

	-- Set rank number
	local rankLabel = row:FindFirstChild("Rank", true) or row:FindFirstChild("RankLabel", true)
	if rankLabel and rankLabel:IsA("TextLabel") then
		rankLabel.Text = tostring(rank)
	end

	-- Set player name
	local nameLabel = row:FindFirstChild("Name", true)
		or row:FindFirstChild("PlayerName", true)
		or row:FindFirstChild("Username", true)
	if nameLabel and nameLabel:IsA("TextLabel") then
		nameLabel.Text = entry.DisplayName or "Unknown"
	end

	-- Set value
	local valueLabel = row:FindFirstChild("Value", true)
		or row:FindFirstChild("Score", true)
		or row:FindFirstChild("Amount", true)
	if valueLabel and valueLabel:IsA("TextLabel") then
		valueLabel.Text = entry.FormattedValue or tostring(entry.Value)
	end

	-- Set avatar image (cached)
	local avatarImage = row:FindFirstChild("Avatar", true)
		or row:FindFirstChild("PlayerImage", true)
		or row:FindFirstChild("Thumbnail", true)
	if avatarImage and avatarImage:IsA("ImageLabel") then
		local userId = entry.UserId
		if userId then
			if _AvatarCache[userId] then
				avatarImage.Image = _AvatarCache[userId]
			else
				task.spawn(function()
					local success, result = pcall(function()
						return Players:GetUserThumbnailAsync(
							userId,
							Enum.ThumbnailType.HeadShot,
							Enum.ThumbnailSize.Size100x100
						)
					end)
					if success then
						_AvatarCache[userId] = result
						avatarImage.Image = result
					end
				end)
			end
		end
	end
end

local function PopulateBoard(board, data, categoryId)
	-- Only set up title once per board
	if not _InitializedBoards[board] then
		local categoryConfig = GetCategoryConfig(categoryId)
		if categoryConfig then
			PopulateTitle(board, categoryConfig)
		end
		_InitializedBoards[board] = true
	end

	local surfaceGui = FindSurfaceGui(board)
	if not surfaceGui then
		warn("[LeaderboardService] No SurfaceGui found on board:", board:GetFullName())
		return
	end

	local entriesContainer = surfaceGui:FindFirstChild("Entries", true)
		or surfaceGui:FindFirstChild("LeaderboardEntries", true)
		or surfaceGui:FindFirstChild("List", true)

	if not entriesContainer then
		warn("[LeaderboardService] No entries container found on board:", board.Name)
		return
	end

	local template = entriesContainer:FindFirstChild("_Template")
		or entriesContainer:FindFirstChild("Template")

	if not template then
		warn("[LeaderboardService] No template found in entries container:", board.Name)
		return
	end

	-- Collect existing rows (for pooling)
	local existingRows = {}
	for _, child in ipairs(entriesContainer:GetChildren()) do
		if child:IsA("Frame") and child ~= template and not child.Name:match("^_") then
			table.insert(existingRows, child)
		end
	end

	-- Populate entries using pooled rows
	for rank, entry in ipairs(data) do
		local row = existingRows[rank]
		if not row then
			-- Need to clone a new row
			row = template:Clone()
			row.Name = "Entry_" .. rank
			row.Parent = entriesContainer
		end
		UpdateRow(row, rank, entry)
	end

	-- Hide excess rows instead of destroying (for reuse next refresh)
	for i = #data + 1, #existingRows do
		existingRows[i].Visible = false
	end
end

-- Refresh all leaderboard boards
function LeaderboardService:RefreshAllBoards()
	_NextRefreshTime = tick() + LeaderboardConfig.BOARD_REFRESH_INTERVAL
	local boards = CollectionService:GetTagged(LeaderboardConfig.BOARD_TAG)
	local periodId = GetCurrentPeriodId()
	local timeRemaining = self:GetTimeRemaining()


	for _, board in ipairs(boards) do
		local category = board:GetAttribute("Category")
		if category then
			local data = self:GetTop(category, LeaderboardConfig.MAX_DISPLAY_ENTRIES, periodId)

			for _, entry in ipairs(data) do
				if not entry.DisplayName then
					entry.DisplayName = GetDisplayName(entry.UserId)
				end
			end

			PopulateBoard(board, data, category)
		else
			warn("[LeaderboardService] Board missing Category attribute:", board:GetFullName())
		end
	end

	UpdateSharedTimer(timeRemaining)
end

-- Distribute period rewards to top 3 players (called at period end)
function LeaderboardService:DistributePeriodRewards(periodId)
	for _, categoryConfig in ipairs(LeaderboardConfig.Categories) do
		local category = categoryConfig.Id
		local top3 = self:GetTop(category, 3, periodId)
		for rank = 1, math.min(3, #top3) do
			local entry = top3[rank]
			local skinReward = categoryConfig.Prizes[rank]

			if skinReward and entry then
				local player = Players:GetPlayerByUserId(entry.UserId)

				if player then
					-- Award skin immediately
					self:AwardLeaderboardSkin(player, skinReward.SkinId, skinReward.Mutation, periodId)
				else
					-- Queue for next login
					self:QueueOfflineReward(entry.UserId, skinReward, periodId, category, rank)
				end
			end
		end
	end
end

-- Initializers --
function LeaderboardService:Init()
	-- Check for missed period transitions on startup
	task.spawn(function()
		local currentPeriod = GetCurrentPeriodId()
		local periodNumber = tonumber(currentPeriod:match("P(%d+)"))

		if periodNumber and periodNumber > 1 then
			local previousPeriod = string.format("P%03d", periodNumber - 1)
			if not IsPeriodProcessed(previousPeriod) then
				self:DistributePeriodRewards(previousPeriod)
				MarkPeriodProcessed(previousPeriod)
			end
		end
	end)

	-- Check for pending rewards when player data loads
	DataStream.PlayerStreamAdded:Connect(function(schemaName, player)
		if schemaName == "Stored" then
			task.defer(function()
				CheckAndResetPeriod(player)
				self:CheckPendingRewards(player)
			end)
		end
	end)

	-- Flush pending updates on player leave
	Players.PlayerRemoving:Connect(function(player)
		FlushPendingUpdates(player.UserId)
	end)

	-- Handle boards that stream in later
	CollectionService:GetInstanceAddedSignal(LeaderboardConfig.BOARD_TAG):Connect(function(board)
		local category = board:GetAttribute("Category")
		if category then
			local periodId = GetCurrentPeriodId()
			local timeRemaining = self:GetTimeRemaining()
			local data = self:GetTop(category, LeaderboardConfig.MAX_DISPLAY_ENTRIES, periodId)

			-- Resolve display names (cached)
			for _, entry in ipairs(data) do
				if not entry.DisplayName then
					entry.DisplayName = GetDisplayName(entry.UserId)
				end
			end

			PopulateBoard(board, data, category)
			UpdateSharedTimer(timeRemaining)
		end
	end)

	-- Combined update loop for saves, board refreshes, and timer
	task.spawn(function()
		self:RefreshAllBoards()

		local lastSaveTime = tick()
		local lastRefreshTime = tick()
		local lastKnownPeriod = GetCurrentPeriodId()

		while true do
			task.wait(1)

			local now = tick()
			local timeRemaining = self:GetTimeRemaining()

			-- Update timer display every second
			UpdateSharedTimer(timeRemaining)

			if timeRemaining <= 10 or timeRemaining >= PERIOD_DURATION_SECONDS - 5 then
				_CachedPeriodId = nil
				_PeriodCacheTime = 0
			end

			local currentPeriod = GetCurrentPeriodId()

			if currentPeriod ~= lastKnownPeriod then
				local alreadyProcessed = IsPeriodProcessed(lastKnownPeriod)

				if not alreadyProcessed or LeaderboardConfig.TESTING_MODE then
					self:DistributePeriodRewards(lastKnownPeriod)
					MarkPeriodProcessed(lastKnownPeriod)
				end

				-- Reset period stats for all online players
				for _, player in ipairs(Players:GetPlayers()) do
					local stored = DataStream.Stored[player]
					if stored then
						stored.Leaderboard.PeriodStats.Kills = 0
						stored.Leaderboard.PeriodStats.RoundsPlayed = 0
						stored.Leaderboard.PeriodStats.CashEarned = 0
						stored.Leaderboard.CurrentPeriodId = currentPeriod
					end
				end

				-- Clear leaderboard cache so boards show fresh data
				table.clear(_CachedLeaderboards)

				lastKnownPeriod = currentPeriod
			end

			-- Periodic save
			if now - lastSaveTime >= LeaderboardConfig.SAVE_INTERVAL then
				lastSaveTime = now
				for _, player in ipairs(Players:GetPlayers()) do
					local stored = DataStream.Stored[player]
					if stored then
						local stats = stored.Leaderboard.PeriodStats
						local kills = stats.Kills:Read() or 0
						local rounds = stats.RoundsPlayed:Read() or 0
						local cash = stats.CashEarned:Read() or 0

						if kills > 0 then
							QueueDataStoreUpdate(player, "Kills", kills)
						end
						if rounds > 0 then
							QueueDataStoreUpdate(player, "Rounds", rounds)
						end
						if cash > 0 then
							QueueDataStoreUpdate(player, "Cash", cash)
						end
					end
				end
			end

			-- Periodic board refresh
			if now - lastRefreshTime >= LeaderboardConfig.BOARD_REFRESH_INTERVAL then
				lastRefreshTime = now
				self:RefreshAllBoards()
			end
		end
	end)

end

-- Return Module --
return LeaderboardService
