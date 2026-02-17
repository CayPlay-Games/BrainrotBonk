--[[
	SkinAnimationController.lua

	Description:
		Manages Idle and Walk animation playback for skin models.
		- Loops Idle animation during Spawning, Aiming, Revealing, Resolution
		- Plays Walk animation during Launching phase
		- Smooth crossfade transitions between animations
		- Uses CollectionService "Skin" tag to detect when skins are added
--]]

-- Root --
local SkinAnimationController = {}

-- Roblox Services --
local CollectionService = game:GetService("CollectionService")

-- Dependencies --
local ClientDataStream = shared("ClientDataStream")
local PromiseWaitForDataStream = shared("PromiseWaitForDataStream")
local SkinsConfig = shared("SkinsConfig")

-- Constants --
local ANIMATION_FADE_TIME = 0.2
local SKIN_TAG = "Skin"

-- Private Variables --
local _ActiveAnimations = {} -- Character -> { IdleTrack, WalkTrack, CurrentTrack }
local _StateChangedConnection = nil
local _SkinAddedConnection = nil
local _SkinRemovedConnection = nil

-- Internal Functions --

-- Plays the Idle animation
local function PlayIdle(animData)
	if animData.CurrentTrack == animData.IdleTrack then
		return -- Already playing
	end

	if animData.CurrentTrack then
		animData.CurrentTrack:Stop(ANIMATION_FADE_TIME)
	end
	animData.IdleTrack:Play(ANIMATION_FADE_TIME)
	animData.CurrentTrack = animData.IdleTrack
end

-- Plays the Walk animation
local function PlayWalk(animData)
	if animData.CurrentTrack == animData.WalkTrack then
		return -- Already playing
	end

	if animData.CurrentTrack then
		animData.CurrentTrack:Stop(ANIMATION_FADE_TIME)
	end
	animData.WalkTrack:Play(ANIMATION_FADE_TIME)
	animData.CurrentTrack = animData.WalkTrack
end

-- Stops all animations
local function StopAll(animData)
	if animData.CurrentTrack then
		animData.CurrentTrack:Stop(ANIMATION_FADE_TIME)
		animData.CurrentTrack = nil
	end
end

-- Creates Animation instances from config asset IDs (works in live games)
local function CreateAnimationsFromConfig(skinModel)
	local skinId = skinModel:GetAttribute("SkinId")
	local skinConfig = skinId and SkinsConfig.Skins[skinId]

	if not skinConfig or not skinConfig.KeyframeSequences then
		return nil, nil
	end

	local configKF = skinConfig.KeyframeSequences
	if not configKF.Idle or not configKF.Walk then
		return nil, nil
	end

	-- Use asset IDs directly as Animation.AnimationId
	local idleAnim = Instance.new("Animation")
	idleAnim.AnimationId = configKF.Idle

	local walkAnim = Instance.new("Animation")
	walkAnim.AnimationId = configKF.Walk

	return idleAnim, walkAnim
end

-- Sets up animation tracks for a skin model
local function SetupSkinAnimations(skinModel)
	local character = skinModel.Parent
	if not character then
		warn("[SkinAnimationController] Skin has no parent")
		return nil
	end

	-- Already set up for this character
	if _ActiveAnimations[character] then
		warn("[SkinAnimationController] Animations already set up for character:", character:GetFullName())
		return _ActiveAnimations[character]
	end

	-- Wait for AnimationController to replicate (search by class since name may vary)
	local animController = skinModel:FindFirstChildOfClass("AnimationController")
	if not animController then
		warn("[SkinAnimationController] AnimationController not found in skin model:", skinModel:GetFullName())
		return nil
	end

	local animator = animController:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = animController
	end

	-- Get animations from config asset IDs
	local idleAnim, walkAnim = CreateAnimationsFromConfig(skinModel)
	if not idleAnim or not walkAnim then
		local skinId = skinModel:GetAttribute("SkinId") or "unknown"
		warn("[SkinAnimationController] No animations available for skin:", skinId)
		return nil
	end

	local idleTrack, walkTrack
	local success
	success, idleTrack = pcall(function()
		return animator:LoadAnimation(idleAnim)
	end)
	if not success then
		warn("[SkinAnimationController] Failed to load Idle animation:", idleAnim.AnimationId)
		return nil
	end

	success, walkTrack = pcall(function()
		return animator:LoadAnimation(walkAnim)
	end)
	if not success then
		warn("[SkinAnimationController] Failed to load Walk animation:", walkAnim.AnimationId)
		return nil
	end

	idleTrack.Looped = true
	walkTrack.Looped = true
	idleTrack.Priority = Enum.AnimationPriority.Action4
	walkTrack.Priority = Enum.AnimationPriority.Action4

	local animData = {
		Animator = animator,
		IdleTrack = idleTrack,
		WalkTrack = walkTrack,
		CurrentTrack = nil,
	}

	_ActiveAnimations[character] = animData
	return animData
end

-- Called when a skin is tagged and added
local function OnSkinAdded(skinModel)
	-- Spawn task since SetupSkinAnimations uses WaitForChild
	task.spawn(function()
		warn("[SkinAnimationController] Skin tag detected:", skinModel:GetFullName())

		local animData = SetupSkinAnimations(skinModel)
		if not animData then
			warn("[SkinAnimationController] Failed to setup animations for:", skinModel:GetFullName())
			return
		end

		warn("[SkinAnimationController] Animations setup successfully")

		-- Play appropriate animation based on current state
		local roundState = ClientDataStream.RoundState
		if not roundState then
			warn("[SkinAnimationController] RoundState not available yet")
			return
		end

		local currentState = roundState.State:Read()
		warn("[SkinAnimationController] Current state:", currentState)
		if currentState == "Launching" or currentState == "Resolution" then
			PlayWalk(animData)
		elseif currentState == "Spawning" or currentState == "Aiming" or currentState == "Revealing" then
			PlayIdle(animData)
		end
	end)
end

-- Called when a skin is untagged or removed
local function OnSkinRemoved(skinModel)
	local character = skinModel.Parent
	if character and _ActiveAnimations[character] then
		StopAll(_ActiveAnimations[character])
		_ActiveAnimations[character] = nil
	end
end

-- Cleans up all animation data
local function CleanupAllAnimations()
	for _, animData in pairs(_ActiveAnimations) do
		StopAll(animData)
	end
	table.clear(_ActiveAnimations)
end

-- Disconnects all event connections
local function Cleanup()
	if _StateChangedConnection then
		_StateChangedConnection:Disconnect()
		_StateChangedConnection = nil
	end
	if _SkinAddedConnection then
		_SkinAddedConnection:Disconnect()
		_SkinAddedConnection = nil
	end
	if _SkinRemovedConnection then
		_SkinRemovedConnection:Disconnect()
		_SkinRemovedConnection = nil
	end
	CleanupAllAnimations()
end

-- Handles state changes for all active characters
local function OnStateChanged(newState)
	for char, animData in pairs(_ActiveAnimations) do
		if char.Parent then
			if newState == "Launching" or newState == "Resolution" then
				PlayWalk(animData)
			elseif newState == "Spawning" or newState == "Aiming" or newState == "Revealing" then
				PlayIdle(animData)
			elseif newState == "RoundEnd" or newState == "Waiting" then
				StopAll(animData)
			end
		else
			_ActiveAnimations[char] = nil
		end
	end

	if newState == "RoundEnd" or newState == "Waiting" then
		CleanupAllAnimations()
	end
end

-- API Functions --

-- Initializers --
function SkinAnimationController:Init()
	-- Listen for skins being added/removed via CollectionService
	_SkinAddedConnection = CollectionService:GetInstanceAddedSignal(SKIN_TAG):Connect(OnSkinAdded)
	_SkinRemovedConnection = CollectionService:GetInstanceRemovedSignal(SKIN_TAG):Connect(OnSkinRemoved)

	-- Process any skins that already exist
	for _, skinModel in ipairs(CollectionService:GetTagged(SKIN_TAG)) do
		task.spawn(OnSkinAdded, skinModel)
	end

	-- Listen for round state changes
	PromiseWaitForDataStream(ClientDataStream.RoundState):andThen(function(roundState)
		local lastKnownState = roundState.State:Read()

		_StateChangedConnection = roundState.State:Changed(function(newState)
			if newState == lastKnownState then
				return
			end
			lastKnownState = newState

			OnStateChanged(newState)
		end)
	end)
end

function SkinAnimationController:Cleanup()
	Cleanup()
end

-- Return Module --
return SkinAnimationController
