--[[
	SkinAnimationController.lua

	Description:
		Manages Idle and Walk animation playback for skin models.
		- Loops Idle animation during Spawning, Aiming, Revealing, Resolution
		- Plays Walk animation during Launching phase
		- Smooth crossfade transitions between animations
--]]

-- Root --
local SkinAnimationController = {}

-- Roblox Services --
local Players = game:GetService("Players")
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")

-- Dependencies --
local ClientDataStream = shared("ClientDataStream")
local PromiseWaitForDataStream = shared("PromiseWaitForDataStream")

-- Constants --
local ANIMATION_FADE_TIME = 0.2
-- Private Variables --
local _RegisteredKeyframes = {} -- KeyframeSequence -> ContentId (cache)
local _ActiveAnimations = {} -- Character -> { IdleTrack, WalkTrack, CurrentTrack }
local _StateChangedConnection = nil
local _ChildRemovedConnection = nil

-- Internal Functions --

-- Converts a KeyframeSequence to a playable Animation content ID
local function GetAnimationContentId(keyframeSequence)
	if _RegisteredKeyframes[keyframeSequence] then
		return _RegisteredKeyframes[keyframeSequence]
	end

	local contentId = KeyframeSequenceProvider:RegisterKeyframeSequence(keyframeSequence)
	_RegisteredKeyframes[keyframeSequence] = contentId
	return contentId
end

-- Creates Animation instance from KeyframeSequence
local function CreateAnimationFromKeyframes(keyframeSequence)
	local contentId = GetAnimationContentId(keyframeSequence)
	local animation = Instance.new("Animation")
	animation.AnimationId = contentId
	return animation
end

-- Sets up animation tracks for a skin model inside a character
local function SetupSkinAnimations(character)

	-- Find the Skin model inside the character (physics box)
	local skinModel = character:FindFirstChild("Skin")
	if not skinModel then
		return nil
	end

	-- Find AnimationController and Animator
	local animController = skinModel:FindFirstChildOfClass("AnimationController")
	if not animController then
		return nil
	end

	local animator = animController:FindFirstChildOfClass("Animator")
	if not animator then
		-- Create Animator if it doesn't exist
		animator = Instance.new("Animator")
		animator.Parent = animController
	end

	-- Find AnimSaves containing keyframe sequences
	local animSaves = skinModel:FindFirstChild("AnimSaves")
	if not animSaves then
		animSaves = skinModel:FindFirstChild("AnimSaves", true)
		if not animSaves then
			return nil
		end
	end

	local idleKF = animSaves:FindFirstChild("Idle")
	local walkKF = animSaves:FindFirstChild("Walk")


	if not idleKF or not idleKF:IsA("KeyframeSequence") then
		return nil
	end

	if not walkKF or not walkKF:IsA("KeyframeSequence") then
		return nil
	end

	idleKF.Loop = true
	walkKF.Loop = true

	local success, idleAnim, walkAnim
	success, idleAnim = pcall(function()
		return CreateAnimationFromKeyframes(idleKF)
	end)
	if not success then
		return nil
	end

	success, walkAnim = pcall(function()
		return CreateAnimationFromKeyframes(walkKF)
	end)
	if not success then
		return nil
	end

	-- Load animation tracks
	local idleTrack, walkTrack
	success, idleTrack = pcall(function()
		return animator:LoadAnimation(idleAnim)
	end)
	if not success then
		return nil
	end

	success, walkTrack = pcall(function()
		return animator:LoadAnimation(walkAnim)
	end)
	if not success then
		return nil
	end

	-- Configure looping and priority
	idleTrack.Looped = true
	walkTrack.Looped = true
	idleTrack.Priority = Enum.AnimationPriority.Action4
	walkTrack.Priority = Enum.AnimationPriority.Action4

	return {
		Animator = animator,
		IdleTrack = idleTrack,
		WalkTrack = walkTrack,
		CurrentTrack = nil,
	}
end

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

-- Scans workspace for all physics box characters and sets up animations
local function SetupAllCharacterAnimations()
	-- Get player list from RoundState
	local roundState = ClientDataStream.RoundState
	if not roundState then
		return
	end

	local players = roundState.Players:Read() or {}

	for odometerId, playerData in pairs(players) do
		if playerData.IsAlive then
			local userId = tonumber(odometerId)
			local player = Players:GetPlayerByUserId(userId)
			local character = nil

			if player then
				character = player.Character
			elseif userId and userId < 0 then
				-- Dummy player - model name is "Dummy_X" where X is absolute value of UserId
				local dummyModelName = "Dummy_" .. math.abs(userId)
				character = workspace:FindFirstChild(dummyModelName)
			end

			if character and not _ActiveAnimations[character] then
				local animData = SetupSkinAnimations(character)
				if animData then
					_ActiveAnimations[character] = animData
				end
			end
		end
	end
end

-- Cleans up animation data for a character
local function CleanupCharacter(character)
	local animData = _ActiveAnimations[character]
	if animData then
		StopAll(animData)
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
	if _ChildRemovedConnection then
		_ChildRemovedConnection:Disconnect()
		_ChildRemovedConnection = nil
	end
	CleanupAllAnimations()
end

-- Handles state changes for all active characters
local function OnStateChanged(newState)
	if newState == "Spawning" then
		task.wait(0.5)
		SetupAllCharacterAnimations()
	end

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
	PromiseWaitForDataStream(ClientDataStream.RoundState):andThen(function(roundState)
		local lastKnownState = roundState.State:Read()

		_StateChangedConnection = roundState.State:Changed(function(newState)
			if newState == lastKnownState then
				return
			end
			lastKnownState = newState

			OnStateChanged(newState)
		end)

		if lastKnownState == "Spawning" or lastKnownState == "Aiming" or lastKnownState == "Revealing" or lastKnownState == "Resolution" then
			SetupAllCharacterAnimations()
			for _, animData in pairs(_ActiveAnimations) do
				PlayIdle(animData)
			end
		elseif lastKnownState == "Launching" then
			SetupAllCharacterAnimations()
			for _, animData in pairs(_ActiveAnimations) do
				PlayWalk(animData)
			end
		end

		_ChildRemovedConnection = workspace.ChildRemoved:Connect(function(child)
			if _ActiveAnimations[child] then
				CleanupCharacter(child)
			end
		end)
	end)
end

function SkinAnimationController:Cleanup()
	Cleanup()
end

-- Return Module --
return SkinAnimationController
