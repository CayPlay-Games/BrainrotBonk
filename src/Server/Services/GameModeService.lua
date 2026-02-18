--[[
	GameModeService.lua

	Description:
		Manages game mode lifecycle and hook invocations.
		Connects to RoundService signals and delegates to active game mode.
--]]

-- Root --
local GameModeService = {}

-- Dependencies --
local Signal = shared("Signal")
local GameModesConfig = shared("GameModesConfig")
local RoundService = shared("RoundService")
local MapService = shared("MapService")
local MapsConfig = shared("MapsConfig")

-- Game Mode Modules
local ClassicMode = shared("ClassicMode")
local DeathMatchMode = shared("DeathMatchMode")

-- Game modes registry
local GameModes = {
	Classic = ClassicMode,
	DeathMatch = DeathMatchMode,
}

-- Private Variables --
local _ActiveMode = nil -- Current active game mode instance
local _ActiveModeId = nil -- Current mode ID string
local _RoundNumber = 0 -- Track round number for modes

-- Public Signals --
GameModeService.ModeActivated = Signal.new() -- (modeId, modeInstance)
GameModeService.ModeDeactivated = Signal.new() -- (modeId)

-- Internal Functions --

local function DebugLog(...)
	print("[GameModeService]", ...)
end

-- Gets the game mode ID for a map
local function GetMapGameMode(mapId)
	local mapConfig = MapsConfig.Maps[mapId]
	if mapConfig and mapConfig.GameMode then
		return mapConfig.GameMode
	end
	return GameModesConfig.DEFAULT_MODE
end

-- Creates/activates a game mode instance
local function ActivateMode(modeId)
	-- Deactivate current mode if any
	if _ActiveMode then
		if _ActiveMode.OnDeactivate then
			_ActiveMode:OnDeactivate()
		end
		GameModeService.ModeDeactivated:Fire(_ActiveModeId)
	end

	-- Get mode configuration
	local modeConfig = GameModesConfig.Modes[modeId]
	if not modeConfig then
		warn("[GameModeService] Unknown game mode:", modeId)
		modeId = GameModesConfig.DEFAULT_MODE
		modeConfig = GameModesConfig.Modes[modeId]
	end

	-- Get mode module
	local ModeModule = GameModes[modeId]
	if not ModeModule then
		warn("[GameModeService] No module found for mode:", modeId)
		return false
	end

	-- Create mode instance
	_ActiveMode = ModeModule.new(modeConfig.Settings)
	_ActiveModeId = modeId

	-- Call activation hook
	if _ActiveMode.OnActivate then
		_ActiveMode:OnActivate()
	end

	DebugLog("Activated mode:", modeId)
	GameModeService.ModeActivated:Fire(modeId, _ActiveMode)
	return true
end

-- Deactivates the current mode
local function DeactivateMode()
	if _ActiveMode then
		if _ActiveMode.OnDeactivate then
			_ActiveMode:OnDeactivate()
		end
		GameModeService.ModeDeactivated:Fire(_ActiveModeId)
		_ActiveMode = nil
		_ActiveModeId = nil
		_RoundNumber = 0
	end
end

-- Invokes a hook on the active mode if it exists
local function InvokeHook(hookName, ...)
	if _ActiveMode and _ActiveMode[hookName] then
		_ActiveMode[hookName](_ActiveMode, ...)
	end
end

-- API Functions --

function GameModeService:GetActiveMode()
	return _ActiveMode, _ActiveModeId
end

function GameModeService:GetModeConfig(modeId)
	return GameModesConfig.Modes[modeId]
end

function GameModeService:GetCurrentRoundNumber()
	return _RoundNumber
end

-- Initializers --
function GameModeService:Init()
	DebugLog("Initializing...")

	-- Connect to RoundService.StateChanged
	RoundService.StateChanged:Connect(function(newState, oldState)
		-- Activate mode when entering Spawning from MapLoading (or direct from Waiting if preloaded)
		if newState == "Spawning" and (oldState == "MapLoading" or oldState == "Waiting") then
			local mapId = MapService:GetCurrentMapId()
			local modeId = GetMapGameMode(mapId)
			ActivateMode(modeId)
			_RoundNumber = 1

			local mapInstance = MapService:GetCurrentMapInstance()
			if mapInstance then
				InvokeHook("OnMapLoaded", mapInstance)
			else
				warn("[GameModeService] Map instance is nil when entering Spawning state")
			end
		end

		-- Track round transitions (ModifierResolution only occurs between rounds)
		if newState == "ModifierResolution" then
			-- Round ended - invoke OnRoundEnd for previous round
			InvokeHook("OnRoundEnd", _RoundNumber)
			_RoundNumber = _RoundNumber + 1
		elseif newState == "Aiming" then
			-- Round starting (first round and subsequent rounds)
			InvokeHook("OnRoundStart", _RoundNumber)
		end

		-- Deactivate mode when round ends
		if newState == "RoundEnd" then
			InvokeHook("OnMapUnloading")
			DeactivateMode()
		end

		-- General state change hook
		InvokeHook("OnStateChanged", newState, oldState)
	end)

	-- Connect to PlayerEliminated
	RoundService.PlayerEliminated:Connect(function(player, eliminatedBy)
		InvokeHook("OnPlayerEliminated", player, eliminatedBy)
	end)

	DebugLog("Initialized - listening for round events")
end

-- Return Module --
return GameModeService
