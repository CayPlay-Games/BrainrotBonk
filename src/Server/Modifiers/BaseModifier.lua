--[[
	BaseModifier.lua

	Description:
		Base class for map modifiers. Defines the interface that all modifiers
		must implement. Provides default no-op implementations.
--]]

local BaseModifier = {}
BaseModifier.__index = BaseModifier

function BaseModifier.new(settings)
	local self = setmetatable({}, BaseModifier)
	self.Settings = settings or {}
	self._mapInstance = nil
	self._isActive = false
	return self
end

-- Lifecycle Methods (override in subclasses) --

-- Called when modifier is activated, receives map instance
function BaseModifier:Start(mapInstance)
	self._mapInstance = mapInstance
	self._isActive = true
end

-- Called during ModifierSetup phase
-- Used to show warning indicators to players
function BaseModifier:Setup()
	-- Override to show warnings, target indicators, etc.
end

-- Called during ModifierResolution phase
-- Used to execute the actual modifier effects
function BaseModifier:Resolve()
	-- Override to apply effects, spawn hazards, etc.
end

-- Called when modifier is deactivated (round end, cleanup)
function BaseModifier:Cleanup()
	self._isActive = false
	-- Override to clean up any spawned objects, connections, etc.
end

-- Utility Methods --

-- Returns the duration needed for the Resolve phase to complete
-- Override in subclasses that need more time than the default
function BaseModifier:GetResolveDuration()
	local RoundConfig = shared("RoundConfig")
	return RoundConfig.Timers.MODIFIER_RESOLUTION_DURATION or 2
end

function BaseModifier:IsActive()
	return self._isActive
end

function BaseModifier:GetMapInstance()
	return self._mapInstance
end

function BaseModifier:GetSetting(key)
	return self.Settings[key]
end

return BaseModifier
