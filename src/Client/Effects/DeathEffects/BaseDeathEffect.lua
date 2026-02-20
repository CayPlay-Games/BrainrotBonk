--[[
	BaseDeathEffect.lua

	Description:
		Base class for client-side death effects.
		Provides common utilities for creating and cleaning up effect parts.
--]]

-- Root --
local BaseDeathEffect = {}
BaseDeathEffect.__index = BaseDeathEffect

-- Roblox Services --
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

-- Constructor --
function BaseDeathEffect.new(config)
	local self = setmetatable({}, BaseDeathEffect)

	self.Config = config or {}
	self.Settings = config.Settings or {}
	self._createdParts = {}
	self._connections = {}

	return self
end

-- Creates a part for effects, tracking it for cleanup
function BaseDeathEffect:CreatePart(properties)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false

	for key, value in pairs(properties or {}) do
		part[key] = value
	end

	part.Parent = Workspace
	table.insert(self._createdParts, part)

	return part
end

function BaseDeathEffect:CreateTween(instance, tweenInfo, properties)
	local tween = TweenService:Create(instance, tweenInfo, properties)
	return tween
end

function BaseDeathEffect:ScheduleCleanup(instance, delay)
	Debris:AddItem(instance, delay)
end

function BaseDeathEffect:Play(skinData, duration)
	-- Subclasses implement this
end

-- Cleanup all created parts and connections
function BaseDeathEffect:Cleanup()
	-- Destroy all created parts
	for _, part in ipairs(self._createdParts) do
		if part and part.Parent then
			part:Destroy()
		end
	end
	self._createdParts = {}

	-- Disconnect connections
	for _, conn in ipairs(self._connections) do
		if conn.Connected then
			conn:Disconnect()
		end
	end
	self._connections = {}
end

-- Return Module --
return BaseDeathEffect
