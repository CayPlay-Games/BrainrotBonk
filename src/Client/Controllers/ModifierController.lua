--[[
	ModifierController.lua

	Description:
		Client-side orchestrator for modifier visual effects.
		Routes events to specialized modifier controllers based on active modifier.
--]]

-- Root --
local ModifierController = {}

-- Roblox Services --
local Workspace = game:GetService("Workspace")

-- Dependencies --
local ClientDataStream = shared("ClientDataStream")
local PromiseWaitForDataStream = shared("PromiseWaitForDataStream")
local GetRemoteEvent = shared("GetRemoteEvent")
local ModifiersConfig = shared("ModifiersConfig")

-- Remotes --
local MeteorWarningEvent = GetRemoteEvent("MeteorWarning")
local MeteorResolveEvent = GetRemoteEvent("MeteorResolve")
local ArrowWarningEvent = GetRemoteEvent("ArrowWarning")
local ArrowResolveEvent = GetRemoteEvent("ArrowResolve")

-- Private Variables --
local _Connections = {}
local _CurrentController = nil
local _CurrentModifierId = nil

-- Internal Functions --

local function DebugLog(...)
	print("[ModifierController]", ...)
end

-- Dynamically loads a modifier controller module
local function LoadModifierController(modifierId)
	local moduleName = modifierId .. "ModifierController"
	local success, controllerModule = pcall(function()
		return shared(moduleName)
	end)

	if success and controllerModule then
		return controllerModule
	else
		DebugLog("Warning: Could not load controller module:", moduleName)
		return nil
	end
end

-- Gets the modifier config for a given ID
local function GetModifierConfig(modifierId)
	return ModifiersConfig.Modifiers[modifierId]
end

-- Activates a modifier controller for the given modifier
local function ActivateModifier(modifierId, mapInstance)
	-- Clean up previous controller
	if _CurrentController then
		_CurrentController:Cleanup()
		_CurrentController = nil
	end

	if not modifierId then
		_CurrentModifierId = nil
		return
	end

	-- Load the controller module
	local ControllerClass = LoadModifierController(modifierId)
	if not ControllerClass then
		DebugLog("No controller available for modifier:", modifierId)
		_CurrentModifierId = nil
		return
	end

	-- Get config and create controller instance
	local config = GetModifierConfig(modifierId)
	_CurrentController = ControllerClass.new(config)
	_CurrentModifierId = modifierId

	-- Start the controller with map instance
	_CurrentController:Start(mapInstance)
	DebugLog("Activated controller for:", modifierId)
end

-- Cleans up the current modifier controller
local function CleanupCurrentController()
	if _CurrentController then
		_CurrentController:Cleanup()
		_CurrentController = nil
		_CurrentModifierId = nil
	end
end

-- API Functions --

-- Initializers --
function ModifierController:Init()
	DebugLog("Initializing...")

	-- Meteor Shower events
	table.insert(_Connections, MeteorWarningEvent.OnClientEvent:Connect(function(targetPositions, impactRadius)
		if _CurrentController and _CurrentModifierId == "MeteorShower" then
			_CurrentController:OnWarning(targetPositions, impactRadius)
		end
	end))

	table.insert(_Connections, MeteorResolveEvent.OnClientEvent:Connect(function(meteorInterval, travelTime)
		if _CurrentController and _CurrentModifierId == "MeteorShower" then
			_CurrentController:OnResolve(meteorInterval, travelTime)
		end
	end))

	-- Arrow Trap events
	table.insert(_Connections, ArrowWarningEvent.OnClientEvent:Connect(function(arrowData, mapName)
		-- Arrow warning includes map name, so we can activate controller here if needed
		if not _CurrentController or _CurrentModifierId ~= "ArrowTrap" then
			-- Auto-activate for arrow events if not already active
			local mapInstance = Workspace:FindFirstChild(mapName)
			ActivateModifier("ArrowTrap", mapInstance)
		end
		if _CurrentController and _CurrentModifierId == "ArrowTrap" then
			_CurrentController:OnWarning(arrowData, mapName)
		end
	end))

	table.insert(_Connections, ArrowResolveEvent.OnClientEvent:Connect(function(arrowInterval, travelTime)
		if _CurrentController and _CurrentModifierId == "ArrowTrap" then
			_CurrentController:OnResolve(arrowInterval, travelTime)
		end
	end))

	-- Listen for round state changes to manage modifier lifecycle
	PromiseWaitForDataStream(ClientDataStream.RoundState):andThen(function(roundState)
		-- Listen for modifier changes
		table.insert(_Connections, roundState.ModifierData:Changed(function(modifierData)
			if modifierData and modifierData.ModifierId then
				local mapInstance = Workspace:FindFirstChild(roundState.MapName:Get() or "")
				ActivateModifier(modifierData.ModifierId, mapInstance)
			else
				CleanupCurrentController()
			end
		end))

		-- Cleanup on round end
		table.insert(_Connections, roundState.State:Changed(function(newState)
			if newState == "Waiting" or newState == "RoundEnd" then
				CleanupCurrentController()
			end
		end))
	end)

	DebugLog("Initialized")
end

-- Return Module --
return ModifierController
