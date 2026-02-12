--[[
	RoundService.lua

	Description:
		Manages the round lifecycle for the Knockout! game.
		Implements a state machine controlling all phases of gameplay.

	States:
		Waiting -> MapLoading -> Spawning -> Aiming -> Revealing -> Launching -> Resolution
		                                        ^                                    |
		                                        +-------- (if >1 alive) ------------+
		                                                       |
		                                        (if <=1 alive) -> RoundEnd -> Waiting
--]]

-- Root --
local RoundService = {}

-- Roblox Services --
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Dependencies --
local DataStream = shared("DataStream")
local Signal = shared("Signal")
local GetRemoteEvent = shared("GetRemoteEvent")
local RoundConfig = shared("RoundConfig")
local RankConfig = shared("RankConfig")
local RankService = shared("RankService")
local MapService = shared("MapService")
local MapsConfig = shared("MapsConfig")
local SkinService = shared("SkinService")

-- Object References --
local SubmitAimRemoteEvent = GetRemoteEvent("SubmitAim")
local ForceStartRoundRemoteEvent = GetRemoteEvent("ForceStartRound")
local ToggleAFKRemoteEvent = GetRemoteEvent("ToggleAFK")

-- Constants --
local States = {
	Waiting = "Waiting",
	MapLoading = "MapLoading",
	Spawning = "Spawning",
	Aiming = "Aiming",
	Revealing = "Revealing",
	Launching = "Launching",
	Resolution = "Resolution",
	RoundEnd = "RoundEnd",
}

-- Private Variables --
local _CurrentState = States.Waiting
local _RoundNumber = 0
local _TimerConnection = nil
local _TimeRemaining = 0
local _WaitingCheckConnection = nil
local _CountdownCheckConnection = nil

-- Players currently in the round (Player -> PlayerRoundData)
local _RoundPlayers = {}
-- Submitted aims (Player -> { Direction, Power })
local _SubmittedAims = {}
-- Alive players set
local _AlivePlayers = {}
-- KillPart touch connection
local _KillPartConnection = nil
-- Current map spawn points (array of CFrames)
local _CurrentSpawnPoints = {}
-- Dummy players for testing (DEBUG_MODE only)
local _DummyPlayers = {} -- DummyId -> { Character, Name, UserId }
local _NextDummyId = 1
-- Spawn directions for dummies (Dummy -> Vector3)
local _DummySpawnDirections = {}
-- Map loaded during countdown (for seamless transition)
local _MapLoadedDuringCountdown = false

-- Public Variables / Signals --
RoundService.StateChanged = Signal.new() -- (newState, oldState)
RoundService.PlayerEliminated = Signal.new() -- (player, eliminatedBy)
RoundService.RoundEnded = Signal.new() -- (winnerPlayer or nil)

-- Internal Functions --

-- Debug logging
local function DebugLog(...)
	if RoundConfig.DEBUG_LOG_STATE_CHANGES then
		print("[RoundService]", ...)
	end
end

-- Updates the DataStream with current round state
local function UpdateDataStream()
	local playersData = {}
	for player, data in pairs(_RoundPlayers) do
		playersData[tostring(player.UserId)] = {
			DisplayName = player.DisplayName,
			IsAlive = data.IsAlive,
			EliminatedBy = data.EliminatedBy,
			PlacementPosition = data.PlacementPosition,
		}
	end

	local aliveCount = 0
	for _ in pairs(_AlivePlayers) do
		aliveCount = aliveCount + 1
	end

	DataStream.RoundState.State = _CurrentState
	DataStream.RoundState.TimeRemaining = _TimeRemaining
	DataStream.RoundState.RoundNumber = _RoundNumber
	DataStream.RoundState.Players = playersData
	DataStream.RoundState.AliveCount = aliveCount
end

-- Clears the timer connection if it exists
local function ClearTimer()
	if _TimerConnection then
		_TimerConnection:Disconnect()
		_TimerConnection = nil
	end
end

-- Starts a countdown timer, calls callback on completion
local function StartTimer(duration, onComplete)
	ClearTimer()
	_TimeRemaining = duration

	local startTime = tick()
	_TimerConnection = RunService.Heartbeat:Connect(function()
		local elapsed = tick() - startTime
		_TimeRemaining = math.max(0, duration - elapsed)

		UpdateDataStream()

		if _TimeRemaining <= 0 then
			ClearTimer()
			if onComplete then
				onComplete()
			end
		end
	end)
end

-- Gets the count of alive players
local function GetAliveCount()
	local count = 0
	for _ in pairs(_AlivePlayers) do
		count = count + 1
	end
	return count
end

-- Sets up KillPart detection for the current map
local function SetupKillPartDetection()
	-- Clean up existing connection
	if _KillPartConnection then
		_KillPartConnection:Disconnect()
		_KillPartConnection = nil
	end

	-- Find KillPart in current map
	local currentMap = MapService:GetCurrentMapInstance()
	if not currentMap then
		DebugLog("No current map, skipping KillPart setup")
		return
	end

	local killPart = currentMap:FindFirstChild("KillPart", true)
	if not killPart then
		warn("[RoundService] Map has no KillPart - players cannot be eliminated by falling")
		return
	end

	DebugLog("Setting up KillPart detection")

	_KillPartConnection = killPart.Touched:Connect(function(otherPart)
		-- Find which player/dummy this part belongs to
		local model = otherPart:FindFirstAncestorOfClass("Model")
		if not model then return end

		-- Check all alive players/dummies
		for entity in pairs(_AlivePlayers) do
			if entity.Character == model then
				RoundService:EliminatePlayer(entity, "Fall")
				return
			end
		end
	end)
end

-- Cleans up KillPart detection
local function CleanupKillPartDetection()
	if _KillPartConnection then
		_KillPartConnection:Disconnect()
		_KillPartConnection = nil
	end
end

-- Creates a dummy player object for testing (DEBUG_MODE only)
local function CreateDummyPlayer(spawnCFrame)
	local dummyId = _NextDummyId
	_NextDummyId = _NextDummyId + 1

	-- Create a fake player-like object
	local dummy = {
		Name = "Dummy_" .. dummyId,
		DisplayName = "Dummy " .. dummyId,
		UserId = -dummyId, -- Negative to avoid conflicts with real players
		IsDummy = true,
		Character = nil,
	}

	-- Create physics box directly (similar to SkinService but simpler)
	local physicsBox = Instance.new("Model")
	physicsBox.Name = dummy.Name

	local rootPart = Instance.new("Part")
	rootPart.Name = "HumanoidRootPart"
	rootPart.Size = RoundConfig.PHYSICS_BOX_SIZE
	rootPart.Color = Color3.fromRGB(255, 100, 100) -- Red tint for dummies
	rootPart.Material = Enum.Material.SmoothPlastic
	rootPart.TopSurface = Enum.SurfaceType.Smooth
	rootPart.BottomSurface = Enum.SurfaceType.Smooth
	rootPart.CanCollide = true
	rootPart.Anchored = false
	rootPart.CFrame = spawnCFrame

	-- Set physics properties
	rootPart.CustomPhysicalProperties = PhysicalProperties.new(
		RoundConfig.PHYSICS_BOX_DENSITY,
		1, -- Friction
		RoundConfig.SLIPPERY_ELASTICITY,
		100,
		1
	)
	rootPart.Parent = physicsBox

	physicsBox.PrimaryPart = rootPart
	physicsBox.Parent = workspace

	dummy.Character = physicsBox
	_DummyPlayers[dummy] = true

	DebugLog("Created dummy player:", dummy.Name)
	return dummy
end

-- Cleans up a dummy player
local function CleanupDummy(dummy)
	if dummy.Character then
		dummy.Character:Destroy()
		dummy.Character = nil
	end
	_DummyPlayers[dummy] = nil
	_DummySpawnDirections[dummy] = nil
end

-- Cleans up all dummy players
local function CleanupAllDummies()
	for dummy in pairs(_DummyPlayers) do
		CleanupDummy(dummy)
	end
	_DummyPlayers = {}
end

-- Teleports a player to the lobby spawn
local function TeleportToLobby(player)
	local character = player.Character
	if not character then return end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp then
		-- Clear any velocity from the round
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
		hrp.CFrame = CFrame.new(RoundConfig.LOBBY_SPAWN_POSITION)
	end
end

-- Checks if enough non-AFK players are present to start
local function CanStartRound()
	local activeCount = 0
	for _, player in ipairs(Players:GetPlayers()) do
		local sessionData = DataStream.Session[player]
		local isAFK = sessionData and sessionData.IsAFK:Read() or false
		if not isAFK then
			activeCount = activeCount + 1
		end
	end
	if RoundConfig.DEBUG_MODE then
		return activeCount >= 1
	end
	return activeCount >= RoundConfig.MIN_PLAYERS_TO_START
end

-- Checks if AFK toggle is allowed (only during Waiting or RoundEnd)
local function CanToggleAFK()
	return _CurrentState == States.Waiting or _CurrentState == States.RoundEnd
end

-- Forward declaration for state transitions
local TransitionTo

-- State Entry Functions --

local function EnterWaiting()
	DebugLog("Entering Waiting state")

	-- Reset all round data
	_RoundPlayers = {}
	_SubmittedAims = {}
	_AlivePlayers = {}
	_TimeRemaining = 0

	-- Clear any revealed aims and winner
	DataStream.RoundState.RevealedAims = {}
	DataStream.RoundState.Winner = { UserId = nil, DisplayName = "" }
	DataStream.RoundState.CurrentMapId = nil
	DataStream.RoundState.CurrentMapName = ""

	UpdateDataStream()

	-- Clean up any existing connections
	if _WaitingCheckConnection then
		_WaitingCheckConnection:Disconnect()
		_WaitingCheckConnection = nil
	end
	if _CountdownCheckConnection then
		_CountdownCheckConnection:Disconnect()
		_CountdownCheckConnection = nil
	end

	-- Helper to start countdown with player monitoring
	local function StartCountdownWithMonitoring()
		DebugLog("Enough players, starting countdown")

		-- Delay map selection until 5 seconds before countdown ends
		local mapSelectionDelay = math.max(0, RoundConfig.Timers.WAITING_COUNTDOWN - 5)
		_MapLoadedDuringCountdown = false

		task.delay(mapSelectionDelay, function()
			-- Only proceed if still in Waiting state
			if _CurrentState ~= States.Waiting then return end
			if not CanStartRound() then return end

			-- Select map and show notification (triggers client roulette animation)
			local mapId = MapsConfig.DEFAULT_MAP
			local mapConfig = MapsConfig.Maps[mapId]
			DataStream.RoundState.CurrentMapId = mapId
			DataStream.RoundState.CurrentMapName = mapConfig and mapConfig.DisplayName or mapId
			DebugLog("Map selected, showing notification:", mapId)

			-- Delay map loading to let roulette animation play (3 seconds)
			task.delay(3, function()
				-- Only proceed if still in Waiting state
				if _CurrentState ~= States.Waiting then return end
				if not CanStartRound() then return end

				MapService:LoadMap(mapId):andThen(function(spawnPoints)
					_CurrentSpawnPoints = spawnPoints
					_MapLoadedDuringCountdown = true
					DebugLog("Map loaded during countdown:", mapId)
				end):catch(function(err)
					warn("[RoundService] Failed to load map during countdown:", err)
					_MapLoadedDuringCountdown = false
				end)
			end)
		end)

		StartTimer(RoundConfig.Timers.WAITING_COUNTDOWN, function()
			-- Clean up monitoring connection
			if _CountdownCheckConnection then
				_CountdownCheckConnection:Disconnect()
				_CountdownCheckConnection = nil
			end
			if CanStartRound() then
				if _MapLoadedDuringCountdown then
					-- Map already loaded, skip MapLoading state
					_MapLoadedDuringCountdown = false
					TransitionTo(States.Spawning)
				else
					-- Fallback to MapLoading if load failed
					TransitionTo(States.MapLoading)
				end
			else
				-- Not enough players, cleanup and restart
				if _MapLoadedDuringCountdown then
					MapService:UnloadCurrentMap()
					_CurrentSpawnPoints = {}
					_MapLoadedDuringCountdown = false
					DataStream.RoundState.CurrentMapId = nil
					DataStream.RoundState.CurrentMapName = ""
				end
				TransitionTo(States.Waiting)
			end
		end)

		-- Monitor player count during countdown
		_CountdownCheckConnection = RunService.Heartbeat:Connect(function()
			if _CurrentState ~= States.Waiting then
				_CountdownCheckConnection:Disconnect()
				_CountdownCheckConnection = nil
				return
			end

			-- If not enough players, cancel countdown, unload map, and restart waiting
			if not CanStartRound() then
				DebugLog("Not enough players, cancelling countdown")
				_CountdownCheckConnection:Disconnect()
				_CountdownCheckConnection = nil
				ClearTimer()

				-- Unload map if it was loaded during countdown
				if _MapLoadedDuringCountdown then
					MapService:UnloadCurrentMap()
					_CurrentSpawnPoints = {}
					_MapLoadedDuringCountdown = false
					DataStream.RoundState.CurrentMapId = nil
					DataStream.RoundState.CurrentMapName = ""
				end

				TransitionTo(States.Waiting)
			end
		end)
	end

	-- Check immediately
	if CanStartRound() then
		StartCountdownWithMonitoring()
	else
		-- Poll for players
		_WaitingCheckConnection = RunService.Heartbeat:Connect(function()
			if _CurrentState ~= States.Waiting then
				_WaitingCheckConnection:Disconnect()
				_WaitingCheckConnection = nil
				return
			end

			if CanStartRound() then
				_WaitingCheckConnection:Disconnect()
				_WaitingCheckConnection = nil
				StartCountdownWithMonitoring()
			end
		end)
	end
end

local function EnterMapLoading()
	DebugLog("Entering MapLoading state")

	-- Select a map (for now, use default; later can randomize or vote)
	local mapId = MapsConfig.DEFAULT_MAP

	-- Load the map via MapService
	MapService:LoadMap(mapId):andThen(function(spawnPoints)
		if _CurrentState ~= States.MapLoading then
			return -- State changed while loading, abort
		end

		_CurrentSpawnPoints = spawnPoints

		-- Update DataStream with map info
		local mapConfig = MapsConfig.Maps[mapId]
		DataStream.RoundState.CurrentMapId = mapId
		DataStream.RoundState.CurrentMapName = mapConfig and mapConfig.DisplayName or mapId

		DebugLog("Map loaded:", mapId, "with", #spawnPoints, "spawn points")
		TransitionTo(States.Spawning)
	end):catch(function(err)
		warn("[RoundService] Failed to load map:", err)
		-- Fallback: generate circular spawn points facing center
		_CurrentSpawnPoints = {}
		for i = 1, 12 do
			local angle = (i - 1) * (2 * math.pi / 12)
			local radius = 20
			local pos = Vector3.new(math.cos(angle) * radius, 5, math.sin(angle) * radius)
			_CurrentSpawnPoints[i] = CFrame.lookAt(pos, Vector3.new(0, pos.Y, 0))
		end
		DataStream.RoundState.CurrentMapId = "Fallback"
		DataStream.RoundState.CurrentMapName = "Fallback Arena"
		TransitionTo(States.Spawning)
	end)
end

local function EnterSpawning()
	DebugLog("Entering Spawning state")

	-- Start at round 1
	_RoundNumber = 1

	-- Get all non-AFK players to include in round
	local allPlayers = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local sessionData = DataStream.Session[player]
		local isAFK = sessionData and sessionData.IsAFK:Read() or false
		if not isAFK then
			table.insert(allPlayers, player)
		else
			DebugLog(player.DisplayName, "is AFK, skipping spawn")
		end
	end

	-- Shuffle spawn points for variety
	local shuffledSpawnPoints = {}
	for i, spawnCFrame in ipairs(_CurrentSpawnPoints) do
		shuffledSpawnPoints[i] = spawnCFrame
	end
	for i = #shuffledSpawnPoints, 2, -1 do
		local j = math.random(1, i)
		shuffledSpawnPoints[i], shuffledSpawnPoints[j] = shuffledSpawnPoints[j], shuffledSpawnPoints[i]
	end

	-- Initialize round players
	for i, player in ipairs(allPlayers) do
		_RoundPlayers[player] = {
			IsAlive = true,
			EliminatedBy = nil,
			PlacementPosition = nil,
		}
		_AlivePlayers[player] = true

		-- Determine spawn position
		local spawnCFrame = shuffledSpawnPoints[i]
		if not spawnCFrame then
			-- Fallback if not enough spawn points
			local angle = (i - 1) * (2 * math.pi / #allPlayers)
			local pos = Vector3.new(math.cos(angle) * 20, 5, math.sin(angle) * 20)
			spawnCFrame = CFrame.lookAt(pos, Vector3.new(0, pos.Y, 0))
		end

		-- Create physics box character at spawn position
		local physicsBox = SkinService:CreatePhysicsCharacter(player, spawnCFrame)

		-- Attach cosmetic skin to the physics box
		local skinId = SkinService:GetPlayerSkin(player)
		local mutation = SkinService:GetPlayerSkinMutation(player)
		SkinService:AttachSkin(physicsBox, skinId, mutation)
	end

	-- Spawn dummy player for testing in DEBUG_MODE
	if RoundConfig.DEBUG_MODE then
		local nextSpawnIndex = #allPlayers + 1
		local dummySpawnCFrame = shuffledSpawnPoints[nextSpawnIndex]
		if not dummySpawnCFrame then
			-- Fallback spawn position (opposite side of arena)
			local angle = math.pi -- 180 degrees from first player
			local pos = Vector3.new(math.cos(angle) * 15, 5, math.sin(angle) * 15)
			dummySpawnCFrame = CFrame.lookAt(pos, Vector3.new(0, pos.Y, 0))
		end

		local dummy = CreateDummyPlayer(dummySpawnCFrame)
		_RoundPlayers[dummy] = {
			IsAlive = true,
			EliminatedBy = nil,
			PlacementPosition = nil,
		}
		_AlivePlayers[dummy] = true

		-- Store spawn direction for auto-aim (LookVector from spawn CFrame)
		_DummySpawnDirections[dummy] = dummySpawnCFrame.LookVector

		DebugLog("Spawned dummy player for testing")
	end

	-- Setup KillPart detection for eliminations
	SetupKillPartDetection()

	UpdateDataStream()

	-- Brief delay then move to aiming
	StartTimer(RoundConfig.Timers.SPAWNING_DURATION, function()
		TransitionTo(States.Aiming)
	end)
end

local function EnterAiming()
	DebugLog("Entering Aiming state")

	-- Clear any previous aims
	_SubmittedAims = {}

	-- Auto-submit aims for dummy players immediately
	for entity in pairs(_AlivePlayers) do
		-- Dummies are Lua tables, real Players are userdata
		if type(entity) == "table" and entity.IsDummy then
			-- Use spawn direction if available, otherwise default
			local aimDirection = _DummySpawnDirections[entity] or RoundConfig.DEFAULT_AIM_DIRECTION
			_SubmittedAims[entity] = {
				Direction = aimDirection,
				Power = RoundConfig.DEFAULT_AIM_POWER,
			}
			DebugLog(entity.Name, "auto-submitted aim (dummy) direction:", aimDirection)
		end
	end

	-- Start aiming timer
	StartTimer(RoundConfig.Timers.AIMING_DURATION, function()
		-- Wait for all aims with grace period
		task.spawn(function()
			local graceStart = tick()
			local gracePeriod = RoundConfig.AIM_SUBMIT_GRACE_PERIOD

			-- Wait until all alive players have submitted or grace period ends
			while tick() - graceStart < gracePeriod do
				-- Check if all alive players have submitted
				local allSubmitted = true
				for player in pairs(_AlivePlayers) do
					if not _SubmittedAims[player] then
						allSubmitted = false
						break
					end
				end

				if allSubmitted then
					DebugLog("All aims received")
					break
				end

				task.wait(0.05)
			end

			-- Apply default aims for players who still didn't submit
			for player in pairs(_AlivePlayers) do
				if not _SubmittedAims[player] then
					DebugLog(player.DisplayName, "didn't submit aim, using default")
					_SubmittedAims[player] = {
						Direction = RoundConfig.DEFAULT_AIM_DIRECTION,
						Power = RoundConfig.DEFAULT_AIM_POWER,
					}
				end
			end

			TransitionTo(States.Revealing)
		end)
	end)
end

local function EnterRevealing()
	DebugLog("Entering Revealing state")

	-- Build revealed aims data for DataStream
	local revealedAims = {}
	for player, aim in pairs(_SubmittedAims) do
		if _AlivePlayers[player] then
			revealedAims[tostring(player.UserId)] = {
				Direction = { X = aim.Direction.X, Y = aim.Direction.Y, Z = aim.Direction.Z },
				Power = aim.Power,
			}
		end
	end

	DataStream.RoundState.RevealedAims = revealedAims

	-- Show aims for reveal duration
	StartTimer(RoundConfig.Timers.REVEALING_DURATION, function()
		TransitionTo(States.Launching)
	end)
end

local function EnterLaunching()
	DebugLog("Entering Launching state")

	-- Clear revealed aims from DataStream
	DataStream.RoundState.RevealedAims = {}

	-- Apply launch velocities directly via AssemblyLinearVelocity
	-- This lets Roblox physics handle collisions naturally
	for player, aim in pairs(_SubmittedAims) do
		if _AlivePlayers[player] then
			local character = player.Character
			if character then
				local hrp = character:FindFirstChild("HumanoidRootPart")
				if hrp then
					local velocityMagnitude = aim.Power * RoundConfig.LAUNCH_FORCE_MULTIPLIER
					local direction = aim.Direction.Unit
					-- Apply velocity directly (XZ only, preserve Y for gravity)
					hrp.AssemblyLinearVelocity = Vector3.new(
						direction.X * velocityMagnitude,
						hrp.AssemblyLinearVelocity.Y, -- Preserve vertical velocity
						direction.Z * velocityMagnitude
					)
					DebugLog(player.Name, "launched with velocity", velocityMagnitude)
				end
			end
		end
	end

	-- Brief delay then check resolution
	StartTimer(RoundConfig.Timers.LAUNCHING_DURATION, function()
		TransitionTo(States.Resolution)
	end)
end

local function EnterResolution()
	DebugLog("Entering Resolution state")

	local resolutionStartTime = tick()
	local decayRate = RoundConfig.CURLING_DECAY_RATE or 0.98
	local minSpeed = RoundConfig.CURLING_MIN_SPEED or 0.3

	-- Monitor until players settle or timeout
	local checkConnection
	checkConnection = RunService.Heartbeat:Connect(function()
		if _CurrentState ~= States.Resolution then
			checkConnection:Disconnect()
			return
		end

		local elapsed = tick() - resolutionStartTime

		-- Check win condition
		local aliveCount = GetAliveCount()
		if aliveCount <= 1 then
			checkConnection:Disconnect()
			TransitionTo(States.RoundEnd)
			return
		end

		-- Apply curling stone physics - decay velocity each frame
		-- Using AssemblyLinearVelocity so Roblox physics handles collisions naturally
		local allSettled = true
		for player in pairs(_AlivePlayers) do
			local character = player.Character
			if character then
				local hrp = character:FindFirstChild("HumanoidRootPart")
				if hrp then
					local currentVel = hrp.AssemblyLinearVelocity
					local horizontalVel = Vector3.new(currentVel.X, 0, currentVel.Z)
					local speed = horizontalVel.Magnitude

					if speed > minSpeed then
						-- Decay horizontal velocity (simulates ice friction)
						local newHorizontalVel = horizontalVel * decayRate
						hrp.AssemblyLinearVelocity = Vector3.new(
							newHorizontalVel.X,
							currentVel.Y, -- Preserve vertical velocity for gravity
							newHorizontalVel.Z
						)
						allSettled = false
					elseif speed > 0.01 then
						-- Stop horizontal movement when below minimum speed
						hrp.AssemblyLinearVelocity = Vector3.new(0, currentVel.Y, 0)
					end
				end
			end
		end

		-- If settled or timeout, go back to aiming or end round
		if allSettled or elapsed > RoundConfig.Timers.RESOLUTION_TIMEOUT then
			checkConnection:Disconnect()

			if aliveCount <= 1 then
				TransitionTo(States.RoundEnd)
			else
				-- Increment round number for next aiming phase
				_RoundNumber = _RoundNumber + 1
				TransitionTo(States.Aiming)
			end
		end
	end)
end

local function EnterRoundEnd()
	DebugLog("Entering RoundEnd state")

	-- Reset round number
	_RoundNumber = 0

	-- Determine winner
	local winner = nil
	for player in pairs(_AlivePlayers) do
		winner = player
		break
	end

	-- Update winner in DataStream
	if winner then
		DataStream.RoundState.Winner = {
			UserId = winner.UserId,
			DisplayName = winner.DisplayName,
		}

		-- Set winner's placement
		if _RoundPlayers[winner] then
			_RoundPlayers[winner].PlacementPosition = 1
		end

		DebugLog("Winner:", winner.DisplayName)
	else
		DebugLog("No winner (all eliminated)")
	end

	UpdateDataStream()
	RoundService.RoundEnded:Fire(winner)

	-- Cleanup KillPart detection
	CleanupKillPartDetection()

	-- After round end duration, go back to waiting
	StartTimer(RoundConfig.Timers.ROUND_END_DURATION, function()
		-- Unload the current map
		MapService:UnloadCurrentMap()
		_CurrentSpawnPoints = {}

		-- Restore original characters (removes physics box) and teleport to lobby
		-- Only for players still alive (eliminated players were already handled)
		for entity in pairs(_AlivePlayers) do
			if type(entity) == "table" and entity.IsDummy then
				CleanupDummy(entity)
			else
				SkinService:RestoreOriginalCharacter(entity)
				TeleportToLobby(entity)
			end
		end

		-- Cleanup any remaining dummies
		CleanupAllDummies()

		-- Intermission before next round
		DebugLog("Intermission...")
		task.delay(RoundConfig.Timers.INTERMISSION_DURATION, function()
			TransitionTo(States.Waiting)
		end)
	end)
end

-- State entry function mapping
local StateEntryFunctions = {
	[States.Waiting] = EnterWaiting,
	[States.MapLoading] = EnterMapLoading,
	[States.Spawning] = EnterSpawning,
	[States.Aiming] = EnterAiming,
	[States.Revealing] = EnterRevealing,
	[States.Launching] = EnterLaunching,
	[States.Resolution] = EnterResolution,
	[States.RoundEnd] = EnterRoundEnd,
}

-- Transitions to a new state
TransitionTo = function(newState)
	local oldState = _CurrentState
	_CurrentState = newState

	DebugLog("State transition:", oldState, "->", newState)

	UpdateDataStream()
	RoundService.StateChanged:Fire(newState, oldState)

	-- Execute state entry logic
	local entryFunc = StateEntryFunctions[newState]
	if entryFunc then
		entryFunc()
	end
end

-- API Functions --

-- Submits an aim for a player (called via remote event)
function RoundService:SubmitAim(player, direction, power)
	-- Validate state
	if _CurrentState ~= States.Aiming then
		warn("[RoundService] SubmitAim called outside of Aiming phase")
		return false
	end

	-- Validate player is alive
	if not _AlivePlayers[player] then
		warn("[RoundService] SubmitAim called by non-alive player")
		return false
	end

	-- Validate inputs
	if typeof(direction) ~= "Vector3" then
		warn("[RoundService] SubmitAim: Invalid direction type")
		return false
	end

	if type(power) ~= "number" then
		warn("[RoundService] SubmitAim: Invalid power type")
		return false
	end

	-- Clamp power
	power = math.clamp(power, RoundConfig.AIM_POWER_MIN, RoundConfig.AIM_POWER_MAX)

	-- Normalize direction (only use X and Z for horizontal movement)
	local flatDirection = Vector3.new(direction.X, 0, direction.Z)
	if flatDirection.Magnitude < 0.01 then
		flatDirection = RoundConfig.DEFAULT_AIM_DIRECTION
	end

	-- Store aim
	_SubmittedAims[player] = {
		Direction = flatDirection.Unit,
		Power = power,
	}

	DebugLog(player.DisplayName, "submitted aim - Power:", power)

	return true
end

-- Eliminates a player from the round
function RoundService:EliminatePlayer(player, eliminatedBy)
	if not _AlivePlayers[player] then
		return -- Already eliminated
	end

	DebugLog(player.DisplayName, "eliminated by:", eliminatedBy)

	-- Remove from alive players
	_AlivePlayers[player] = nil

	-- Update round player data
	if _RoundPlayers[player] then
		_RoundPlayers[player].IsAlive = false
		_RoundPlayers[player].EliminatedBy = eliminatedBy
		_RoundPlayers[player].PlacementPosition = GetAliveCount() + 1
	end

	-- Restore original character or cleanup dummy
	if type(player) == "table" and player.IsDummy then
		CleanupDummy(player)
	else
		SkinService:RestoreOriginalCharacter(player)
	end

	UpdateDataStream()
	RoundService.PlayerEliminated:Fire(player, eliminatedBy)

	-- Check if round should end (during active phases)
	local activePhases = {
		[States.Aiming] = true,
		[States.Revealing] = true,
		[States.Launching] = true,
		[States.Resolution] = true,
	}

	if GetAliveCount() <= 1 and activePhases[_CurrentState] then
		ClearTimer()
		TransitionTo(States.RoundEnd)
	end
end

-- Gets the current state
function RoundService:GetCurrentState()
	return _CurrentState
end

-- Gets if a player is currently alive in the round
function RoundService:IsPlayerAlive(player)
	return _AlivePlayers[player] == true
end

-- Toggles AFK status for a player
function RoundService:ToggleAFK(player)
	if not CanToggleAFK() then
		DebugLog(player.DisplayName, "tried to toggle AFK during", _CurrentState)
		return false
	end

	local sessionData = DataStream.Session[player]
	if not sessionData then
		warn("[RoundService] No session data for player:", player.DisplayName)
		return false
	end

	local currentAFK = sessionData.IsAFK:Read()
	local newAFK = not currentAFK
	sessionData.IsAFK = newAFK

	DebugLog(player.DisplayName, "AFK status:", newAFK)
	return true
end

-- Debug: Force start a round (only works if DEBUG_MODE is enabled)
function RoundService:ForceStartRound()
	if not RoundConfig.DEBUG_MODE then
		warn("[RoundService] ForceStartRound called but DEBUG_MODE is disabled")
		return false
	end

	if _CurrentState == States.Waiting then
		ClearTimer()
		if _WaitingCheckConnection then
			_WaitingCheckConnection:Disconnect()
			_WaitingCheckConnection = nil
		end
		TransitionTo(States.MapLoading)
		return true
	end

	return false
end

-- Initializers --
function RoundService:Init()
	DebugLog("Initializing...")

	-- Setup remote event handlers
	SubmitAimRemoteEvent.OnServerEvent:Connect(function(player, direction, power)
		self:SubmitAim(player, direction, power)
	end)

	-- Debug remote event
	if RoundConfig.DEBUG_MODE then
		ForceStartRoundRemoteEvent.OnServerEvent:Connect(function(player)
			DebugLog("ForceStartRound requested by", player.DisplayName)
			self:ForceStartRound()
		end)
	end

	-- AFK toggle remote event
	ToggleAFKRemoteEvent.OnServerEvent:Connect(function(player)
		self:ToggleAFK(player)
	end)

	-- Handle player leaving mid-round
	Players.PlayerRemoving:Connect(function(player)
		if _RoundPlayers[player] then
			self:EliminatePlayer(player, "Disconnect")
		end
	end)

	-- Handle character added (for respawns and death detection)
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			local humanoid = character:WaitForChild("Humanoid", 5)
			if humanoid then
				humanoid.Died:Connect(function()
					if _AlivePlayers[player] then
						self:EliminatePlayer(player, "Death")
					end
				end)
			end

		end)
	end)

	-- Handle players already in game
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			local humanoid = player.Character:FindFirstChild("Humanoid")
			if humanoid then
				humanoid.Died:Connect(function()
					if _AlivePlayers[player] then
						self:EliminatePlayer(player, "Death")
					end
				end)
			end
		end

		player.CharacterAdded:Connect(function(character)
			local humanoid = character:WaitForChild("Humanoid", 5)
			if humanoid then
				humanoid.Died:Connect(function()
					if _AlivePlayers[player] then
						self:EliminatePlayer(player, "Death")
					end
				end)
			end
		end)
	end

	-- Award XP when round ends
	self.RoundEnded:Connect(function(winner)
		-- Award XP to all players who participated
		for entity, data in pairs(_RoundPlayers) do
			-- Skip dummies
			if type(entity) == "table" and entity.IsDummy then
				continue
			end

			-- Award PlayGame XP for participating
			RankService:AwardXP(entity, RankConfig.XPRewards.PlayGame)

			-- Award placement XP
			local placement = data.PlacementPosition
			if placement == 1 then
				RankService:AwardXP(entity, RankConfig.XPRewards.Place1st)
			elseif placement == 2 then
				RankService:AwardXP(entity, RankConfig.XPRewards.Place2nd)
			elseif placement == 3 then
				RankService:AwardXP(entity, RankConfig.XPRewards.Place3rd)
			end
		end
	end)

	-- Start the round system (Eden only calls :Init(), not :Start())
	DebugLog("Starting round system...")
	task.defer(function()
		TransitionTo(States.Waiting)
	end)
end

-- Note: Eden framework only calls :Init(), not :Start()
-- The state machine is started via task.defer in :Init()

-- Return Module --
return RoundService
