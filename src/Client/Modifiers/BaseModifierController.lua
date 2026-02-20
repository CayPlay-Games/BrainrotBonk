--[[
	BaseModifierController.lua

	Description:
		Base class for client-side modifier controllers.
		Defines the interface that all client modifier controllers must implement.
		Provides common utilities for visual effect management.
--]]

-- Root --
local BaseModifierController = {}
BaseModifierController.__index = BaseModifierController

function BaseModifierController.new(modifierConfig)
	local self = setmetatable({}, BaseModifierController)

	self.Config = modifierConfig or {}
	self._mapInstance = nil
	self._isActive = false
	self._connections = {}

	return self
end

-- Lifecycle Methods (override in subclasses) --

-- Called when modifier is activated, receives map instance
function BaseModifierController:Start(mapInstance)
	self._mapInstance = mapInstance
	self._isActive = true
end

-- Called during warning/setup phase - show indicators/zones
function BaseModifierController:OnWarning(...)
	-- Override in subclasses
end

-- Called during resolve phase - play animations/effects
function BaseModifierController:OnResolve(...)
	-- Override in subclasses
end

-- Called when modifier is deactivated (round end, cleanup)
function BaseModifierController:Cleanup()
	self._isActive = false

	-- Disconnect all connections
	for _, connection in ipairs(self._connections) do
		if connection.Connected then
			connection:Disconnect()
		end
	end
	self._connections = {}

	-- Override in subclasses for custom cleanup
end

-- Utility Methods --

function BaseModifierController:IsActive()
	return self._isActive
end

function BaseModifierController:GetMapInstance()
	return self._mapInstance
end

function BaseModifierController:GetConfig()
	return self.Config
end

function BaseModifierController:AddConnection(connection)
	table.insert(self._connections, connection)
end

return BaseModifierController
