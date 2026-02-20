--[[
	ModifierService.lua

	Description:
		Orchestrates map modifier selection, lifecycle, and execution.
		Manages modifier roll, setup, resolution, and cleanup.
--]]

-- Root --
local ModifierService = {}

-- Roblox Services --
local Players = game:GetService("Players")

-- Dependencies --
local Signal = shared("Signal")
local DataStream = shared("DataStream")
local MapsConfig = shared("MapsConfig")
local ModifiersConfig = shared("ModifiersConfig")

-- Modifier Modules (loaded on init)
local ModifierModules = {}

-- Private Variables --
local _CurrentModifierModule = nil    -- The modifier module class (e.g., MeteorShowerModifier)
local _CurrentModifierInstance = nil  -- The active modifier instance
local _CurrentModifierConfig = nil    -- Config for current map's modifier
local _CurrentMapId = nil             -- Current map ID
local _IsActiveThisRound = false      -- Whether modifier activated this round

-- Public Signals --
ModifierService.ModifierActivated = Signal.new()    -- (modifierId, modifierConfig)
ModifierService.ModifierSetupStarted = Signal.new() -- (modifierId)
ModifierService.ModifierResolved = Signal.new()     -- (modifierId)
ModifierService.ModifierCleanedUp = Signal.new()    -- (modifierId)

-- Internal Functions --

local function DebugLog(...)
	print("[ModifierService]", ...)
end

-- Loads all modifier modules from Modifiers folder
local function LoadModifierModules()
	for modifierId in pairs(ModifiersConfig.Modifiers) do
		local success, module = pcall(function()
			return shared(modifierId .. "Modifier")
		end)

		if success and module then
			ModifierModules[modifierId] = module
			DebugLog("Loaded modifier module:", modifierId)
		else
			warn("[ModifierService] Failed to load modifier module:", modifierId)
		end
	end
end

-- Updates DataStream with current modifier state
local function UpdateDataStream()
	if _CurrentModifierConfig and _IsActiveThisRound then
		DataStream.RoundState.ActiveModifier = {
			Id = _CurrentModifierConfig.Id,
			DisplayName = _CurrentModifierConfig.DisplayName,
			Description = _CurrentModifierConfig.Description,
		}
	else
		DataStream.RoundState.ActiveModifier = nil
	end
end

-- API Functions --

-- Called when map loads to set up the modifier for this map
function ModifierService:OnMapLoaded(mapId, mapInstance)
	_CurrentMapId = mapId
	_IsActiveThisRound = false

	local mapConfig = MapsConfig.Maps[mapId]
	if not mapConfig or not mapConfig.Modifier then
		DebugLog("No modifier configured for map:", mapId)
		_CurrentModifierConfig = nil
		_CurrentModifierModule = nil
		_CurrentModifierInstance = nil
		return
	end

	local modifierDef = mapConfig.Modifier
	local modifierConfig = ModifiersConfig.Modifiers[modifierDef.Id]

	if not modifierConfig then
		warn("[ModifierService] Unknown modifier ID:", modifierDef.Id)
		_CurrentModifierConfig = nil
		_CurrentModifierModule = nil
		_CurrentModifierInstance = nil
		return
	end

	local modifierModule = ModifierModules[modifierDef.Id]
	if not modifierModule then
		warn("[ModifierService] No module loaded for modifier:", modifierDef.Id)
		_CurrentModifierConfig = nil
		_CurrentModifierModule = nil
		_CurrentModifierInstance = nil
		return
	end

	-- Store config with chance from map definition
	_CurrentModifierConfig = {
		Id = modifierConfig.Id,
		DisplayName = modifierConfig.DisplayName,
		Description = modifierConfig.Description,
		Settings = modifierConfig.Settings,
		Chance = modifierDef.Chance,
	}
	_CurrentModifierModule = modifierModule

	-- Create instance and initialize
	_CurrentModifierInstance = modifierModule.new(modifierConfig.Settings)
	_CurrentModifierInstance:Start(mapInstance)

	DebugLog("Modifier ready for map:", mapId, "Modifier:", modifierDef.Id, "Chance:", modifierDef.Chance)
end

-- Called each round to roll for modifier activation
-- Returns true if modifier should activate this round
function ModifierService:RollForModifier()
	_IsActiveThisRound = false

	if not _CurrentModifierConfig or not _CurrentModifierInstance then
		return false
	end

	local roll = math.random()
	local chance = _CurrentModifierConfig.Chance or 0

	if roll <= chance then
		_IsActiveThisRound = true
		DebugLog("Modifier roll SUCCESS:", _CurrentModifierConfig.Id, "Roll:", roll, "Chance:", chance)
		UpdateDataStream()
		ModifierService.ModifierActivated:Fire(_CurrentModifierConfig.Id, _CurrentModifierConfig)
		return true
	else
		DebugLog("Modifier roll FAILED:", _CurrentModifierConfig.Id, "Roll:", roll, "Chance:", chance)
		UpdateDataStream()
		return false
	end
end

-- Returns whether modifier is active this round
function ModifierService:IsActiveThisRound()
	return _IsActiveThisRound
end

-- Called by RoundService during ModifierSetup state
function ModifierService:ExecuteSetup()
	if not _CurrentModifierInstance or not _IsActiveThisRound then
		return
	end

	DebugLog("Executing modifier setup:", _CurrentModifierConfig.Id)
	DataStream.RoundState.ModifierPhase = "Setup"
	ModifierService.ModifierSetupStarted:Fire(_CurrentModifierConfig.Id)

	_CurrentModifierInstance:Setup()
end

-- Called by RoundService during ModifierResolution state
-- Returns the duration needed for the resolve phase
function ModifierService:ExecuteResolve()
	if not _CurrentModifierInstance or not _IsActiveThisRound then
		return 0
	end

	DebugLog("Executing modifier resolve:", _CurrentModifierConfig.Id)
	DataStream.RoundState.ModifierPhase = "Resolve"

	_CurrentModifierInstance:Resolve()
	ModifierService.ModifierResolved:Fire(_CurrentModifierConfig.Id)

	-- Return the duration needed for this modifier to complete
	return _CurrentModifierInstance:GetResolveDuration()
end

-- Gets the resolve duration for the current modifier
function ModifierService:GetResolveDuration()
	if not _CurrentModifierInstance or not _IsActiveThisRound then
		return 0
	end
	return _CurrentModifierInstance:GetResolveDuration()
end

-- Called when round ends to cleanup
function ModifierService:OnRoundEnd()
	if _CurrentModifierInstance and _IsActiveThisRound then
		DebugLog("Cleaning up modifier for round end")
		_CurrentModifierInstance:Cleanup()
	end

	_IsActiveThisRound = false
	DataStream.RoundState.ActiveModifier = nil
	DataStream.RoundState.ModifierPhase = nil
end

-- Called when map unloads to fully cleanup
function ModifierService:OnMapUnload()
	if _CurrentModifierInstance then
		_CurrentModifierInstance:Cleanup()
		local oldId = _CurrentModifierConfig and _CurrentModifierConfig.Id
		if oldId then
			ModifierService.ModifierCleanedUp:Fire(oldId)
		end
	end

	_CurrentModifierInstance = nil
	_CurrentModifierModule = nil
	_CurrentModifierConfig = nil
	_CurrentMapId = nil
	_IsActiveThisRound = false
	DataStream.RoundState.ActiveModifier = nil
	DataStream.RoundState.ModifierPhase = nil
end

-- Gets the current modifier config (if any)
function ModifierService:GetCurrentModifierConfig()
	return _CurrentModifierConfig
end

-- Gets the current modifier instance (if any)
function ModifierService:GetCurrentModifierInstance()
	return _CurrentModifierInstance
end

-- Initializers --
function ModifierService:Init()
	DebugLog("Initializing...")

	-- Initialize DataStream fields
	DataStream.RoundState.ActiveModifier = nil
	DataStream.RoundState.ModifierPhase = nil

	-- Load all modifier modules
	LoadModifierModules()

	DebugLog("Initialized")
end

-- Return Module --
return ModifierService
