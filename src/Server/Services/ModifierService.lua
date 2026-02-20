--[[
	ModifierService.lua

	Description:
		Orchestrates map modifier selection, lifecycle, and execution.
		Manages modifier roll, setup, resolution, and cleanup.
--]]

-- Root --
local ModifierService = {}

-- Dependencies --
local Signal = shared("Signal")
local DataStream = shared("DataStream")
local MapsConfig = shared("MapsConfig")
local ModifiersConfig = shared("ModifiersConfig")

local ModifierModules = {}

-- Private Variables --
local _CurrentModifierInstance = nil  -- The active modifier instance
local _CurrentModifierConfig = nil    -- Config for current map's modifier
local _IsActiveThisRound = false      -- Whether modifier activated this round

-- Public Signals --
ModifierService.ModifierActivated = Signal.new()    -- (modifierId, modifierConfig)
ModifierService.ModifierSetupStarted = Signal.new() -- (modifierId)
ModifierService.ModifierResolved = Signal.new()     -- (modifierId)
ModifierService.ModifierCleanedUp = Signal.new()    -- (modifierId)

-- Constants --
-- Internal Functions --
local function LoadModifierModules()
	for modifierId in pairs(ModifiersConfig.Modifiers) do
		local success, module = pcall(function()
			return shared(modifierId .. "Modifier")
		end)

		if success and module then
			ModifierModules[modifierId] = module
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
	_IsActiveThisRound = false

	local mapConfig = MapsConfig.Maps[mapId]
	if not mapConfig or not mapConfig.Modifier then
		_CurrentModifierConfig = nil
		_CurrentModifierInstance = nil
		return
	end

	local modifierDef = mapConfig.Modifier
	local modifierConfig = ModifiersConfig.Modifiers[modifierDef.Id]

	if not modifierConfig then
		_CurrentModifierConfig = nil
		_CurrentModifierInstance = nil
		return
	end

	local modifierModule = ModifierModules[modifierDef.Id]
	if not modifierModule then
		_CurrentModifierConfig = nil
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

	-- Create instance and initialize
	_CurrentModifierInstance = modifierModule.new(modifierConfig.Settings)
	_CurrentModifierInstance:Start(mapInstance)
end


function ModifierService:RollForModifier()
	_IsActiveThisRound = false
	if not _CurrentModifierConfig or not _CurrentModifierInstance then
		return false
	end

	local roll = math.random()
	local chance = _CurrentModifierConfig.Chance or 0

	if roll <= chance then
		_IsActiveThisRound = true
		UpdateDataStream()
		ModifierService.ModifierActivated:Fire(_CurrentModifierConfig.Id, _CurrentModifierConfig)
		return true
	else
		UpdateDataStream()
		return false
	end
end

function ModifierService:IsActiveThisRound()
	return _IsActiveThisRound
end

function ModifierService:ExecuteSetup()
	if not _CurrentModifierInstance or not _IsActiveThisRound then
		return
	end
	DataStream.RoundState.ModifierPhase = "Setup"
	ModifierService.ModifierSetupStarted:Fire(_CurrentModifierConfig.Id)
	_CurrentModifierInstance:Setup()
end


function ModifierService:ExecuteResolve()
	if not _CurrentModifierInstance or not _IsActiveThisRound then
		return 0
	end

	DataStream.RoundState.ModifierPhase = "Resolve"
	_CurrentModifierInstance:Resolve()
	ModifierService.ModifierResolved:Fire(_CurrentModifierConfig.Id)

	return _CurrentModifierInstance:GetResolveDuration()
end

-- Gets the resolve duration for the current modifier
function ModifierService:GetResolveDuration()
	if not _CurrentModifierInstance or not _IsActiveThisRound then
		return 0
	end
	return _CurrentModifierInstance:GetResolveDuration()
end

function ModifierService:OnRoundEnd()
	if _CurrentModifierInstance and _IsActiveThisRound then
		_CurrentModifierInstance:Cleanup()
	end

	_IsActiveThisRound = false
	DataStream.RoundState.ActiveModifier = nil
	DataStream.RoundState.ModifierPhase = nil
end

function ModifierService:OnMapUnload()
	if _CurrentModifierInstance then
		_CurrentModifierInstance:Cleanup()
		local oldId = _CurrentModifierConfig and _CurrentModifierConfig.Id
		if oldId then
			ModifierService.ModifierCleanedUp:Fire(oldId)
		end
	end

	_CurrentModifierInstance = nil
	_CurrentModifierConfig = nil
	_IsActiveThisRound = false
	DataStream.RoundState.ActiveModifier = nil
	DataStream.RoundState.ModifierPhase = nil
end

function ModifierService:GetCurrentModifierConfig()
	return _CurrentModifierConfig
end

function ModifierService:GetCurrentModifierInstance()
	return _CurrentModifierInstance
end

-- Initializers --
function ModifierService:Init()
	DataStream.RoundState.ActiveModifier = nil
	DataStream.RoundState.ModifierPhase = nil
	LoadModifierModules()
end

-- Return Module --
return ModifierService
