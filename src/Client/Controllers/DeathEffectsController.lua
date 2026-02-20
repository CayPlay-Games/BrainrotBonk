--[[
	DeathEffectsController.lua

	Description:
		Client-side orchestrator for death visual effects.
		Routes death events to specialized effect modules based on map.
--]]

-- Root --
local DeathEffectsController = {}

-- Dependencies --
local GetRemoteEvent = shared("GetRemoteEvent")
local DeathEffectsConfig = shared("DeathEffectsConfig")

-- Remotes --
local PlayerDeathEffectEvent = GetRemoteEvent("PlayerDeathEffect")

-- Private Variables --
local _ActiveEffects = {} -- PlayerId -> effect instance

-- Internal Functions --

-- Dynamically loads a death effect module
local function LoadDeathEffectModule(effectId)
	local moduleName = effectId .. "DeathEffect"
	local success, effectModule = pcall(function()
		return shared(moduleName)
	end)

	if success and effectModule then
		return effectModule
	end

	local defaultSuccess, defaultModule = pcall(function()
		return shared("DefaultDeathEffect")
	end)

	if defaultSuccess and defaultModule then
		return defaultModule
	end

	return nil
end

local function OnPlayerDeathEffect(data)
	local effectId = data.EffectId or "Default"
	local EffectModule = LoadDeathEffectModule(effectId)

	if not EffectModule then
		warn("[DeathEffectsController] Failed to load effect module:", effectId)
		return
	end

	-- Get effect config
	local effectConfig = DeathEffectsConfig.Effects[effectId]
		or DeathEffectsConfig.Effects.Default

	-- Create and play effect
	local effect = EffectModule.new(effectConfig)
	_ActiveEffects[data.PlayerId] = effect

	local success, err = pcall(function()
		effect:Play(data.SkinData, data.Duration, data.PlayerName)
	end)

	if not success then
		warn("[DeathEffectsController] Error playing effect:", err)
	end

	-- Cleanup after duration (with small buffer)
	task.delay(data.Duration + 0.5, function()
		if _ActiveEffects[data.PlayerId] == effect then
			local cleanupSuccess, cleanupErr = pcall(function()
				effect:Cleanup()
			end)

			if not cleanupSuccess then
				warn("[DeathEffectsController] Error cleaning up effect:", cleanupErr)
			end

			_ActiveEffects[data.PlayerId] = nil
		end
	end)
end

-- API Functions --
-- Initializers --
function DeathEffectsController:Init()
	PlayerDeathEffectEvent.OnClientEvent:Connect(OnPlayerDeathEffect)
end

-- Return Module --
return DeathEffectsController
