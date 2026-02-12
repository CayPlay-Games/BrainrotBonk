--[[
	BaseGameMode.lua

	Description:
		Base class for game modes. Defines the interface that all game modes
		should implement. Provides default no-op implementations.
--]]

local BaseGameMode = {}
BaseGameMode.__index = BaseGameMode

function BaseGameMode.new(settings)
	local self = setmetatable({}, BaseGameMode)
	self.Settings = settings or {}
	return self
end

-- Lifecycle hooks (override in subclasses)
function BaseGameMode:OnActivate()
	-- Called when this mode becomes active
end

function BaseGameMode:OnDeactivate()
	-- Called when this mode is deactivated
end

-- Round lifecycle hooks
function BaseGameMode:OnRoundStart(roundNumber)
	-- Called at the start of each round (beginning of Aiming phase)
end

function BaseGameMode:OnRoundEnd(roundNumber)
	-- Called at the end of each round (after Resolution, before next Aiming)
end

function BaseGameMode:OnPlayerEliminated(player, eliminatedBy)
	-- Called when a player is eliminated
end

function BaseGameMode:OnStateChanged(newState, oldState)
	-- Called on every state transition
end

function BaseGameMode:OnMapLoaded(mapInstance)
	-- Called when the map is loaded
end

function BaseGameMode:OnMapUnloading()
	-- Called before the map is unloaded
end

return BaseGameMode
