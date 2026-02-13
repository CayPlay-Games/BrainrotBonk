--[[
	AimController.lua

	Description:
		Handles player aiming during the Aiming phase.
		- Player rotates to face camera direction
		- Q/E to adjust power level
		- Visual arrow indicator for aim direction
		- Auto-submits aim when phase ends
		- Shows all player arrows during Revealing phase
--]]

-- Root --
local AimController = {}

-- Roblox Services --
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Dependencies --
local ClientDataStream = shared("ClientDataStream")
local GetRemoteEvent = shared("GetRemoteEvent")
local RoundConfig = shared("RoundConfig")

-- Object References --
local LocalPlayer = Players.LocalPlayer
local CurrentCamera = workspace.CurrentCamera
local SubmitAimRemoteEvent = GetRemoteEvent("SubmitAim")
local ArrowTemplate = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Arrow")

-- Constants --
local ARROW_BASE_SCALE_X = 1 -- Base X scale at minimum power
local ARROW_MAX_SCALE_X = 3 -- Max X scale at maximum power
local ARROW_OFFSET_DISTANCE = 2 -- Distance from HRP to arrow base
local ARROW_SIZE_MULTIPLIER = 0.4 -- 60% smaller than original
local ARROW_ROTATION_OFFSET = CFrame.Angles(0, math.rad(-90), 0) -- Rotate to face correct direction

-- Private Variables --
local _IsAiming = false
local _CurrentPower = RoundConfig.DEFAULT_AIM_POWER
local _CurrentDirection = Vector3.new(0, 0, 1) -- Forward
local _AimArrow = nil
local _RevealArrows = {} -- Player -> Arrow for reveal phase
local _InputConnection = nil
local _RenderConnection = nil
local _AimTimerThread = nil
local _HasSubmittedAim = false

-- Internal Functions --

local function DebugLog(...)
	if RoundConfig.DEBUG_LOG_STATE_CHANGES then
		print("[AimController]", ...)
	end
end

-- Checks if the local player is participating and alive in the current round
local function IsLocalPlayerInRound()
	local roundState = ClientDataStream.RoundState
	if not roundState then return false end
	local players = roundState.Players:Read() or {}
	local localUserId = tostring(LocalPlayer.UserId)
	local playerData = players[localUserId]
	return playerData ~= nil and playerData.IsAlive == true
end

-- Creates an arrow for a specific character
local function CreateArrowForCharacter(character)
	if not character then return nil end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil end

	-- Clone the arrow template
	local arrow = ArrowTemplate:Clone()
	arrow.Name = "AimArrow"
	arrow.Anchored = true
	arrow.CanCollide = false
	arrow.CastShadow = false
	arrow.Parent = character

	return arrow
end

-- Updates an arrow's position, rotation, and scale based on direction and power
local function UpdateArrowTransform(arrow, character, direction, power)
	if not arrow or not character then return end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	-- Calculate scale based on power (X direction)
	local powerRatio = (power - RoundConfig.AIM_POWER_MIN) / (RoundConfig.AIM_POWER_MAX - RoundConfig.AIM_POWER_MIN)
	local scaleX = ARROW_BASE_SCALE_X + powerRatio * (ARROW_MAX_SCALE_X - ARROW_BASE_SCALE_X)

	-- Calculate arrow size
	local baseSize = ArrowTemplate.Size * ARROW_SIZE_MULTIPLIER
	local arrowSizeX = baseSize.X * scaleX
	arrow.Size = Vector3.new(arrowSizeX, baseSize.Y, baseSize.Z)

	-- Position arrow in front of player, offset by half the arrow length so it scales outward
	local startPos = hrp.Position
	local dir = direction.Unit
	local outwardOffset = ARROW_OFFSET_DISTANCE + (arrowSizeX / 2)

	-- Arrow points in the aim direction, with rotation offset
	local arrowCFrame = CFrame.lookAt(startPos + dir * outwardOffset, startPos + dir * (outwardOffset + 10)) * ARROW_ROTATION_OFFSET
	arrow.CFrame = arrowCFrame
end

-- Creates the visual arrow indicator for local player
local function CreateAimArrow()
	if _AimArrow then
		_AimArrow:Destroy()
	end

	local character = LocalPlayer.Character
	_AimArrow = CreateArrowForCharacter(character)
end

-- Updates the arrow position and rotation to match aim direction
local function UpdateAimArrow()
	if not _AimArrow then return end

	local character = LocalPlayer.Character
	if not character then return end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	-- Calculate scale based on power (X direction)
	local powerRatio = (_CurrentPower - RoundConfig.AIM_POWER_MIN) / (RoundConfig.AIM_POWER_MAX - RoundConfig.AIM_POWER_MIN)
	local scaleX = ARROW_BASE_SCALE_X + powerRatio * (ARROW_MAX_SCALE_X - ARROW_BASE_SCALE_X)

	-- Calculate arrow size
	local baseSize = ArrowTemplate.Size * ARROW_SIZE_MULTIPLIER
	local arrowSizeX = baseSize.X * scaleX
	_AimArrow.Size = Vector3.new(arrowSizeX, baseSize.Y, baseSize.Z)

	-- Position arrow in front of player, offset by half the arrow length so it scales outward
	local startPos = hrp.Position
	local direction = _CurrentDirection.Unit
	local outwardOffset = ARROW_OFFSET_DISTANCE + (arrowSizeX / 2)

	-- Arrow points in the aim direction, with rotation offset
	local arrowCFrame = CFrame.lookAt(startPos + direction * outwardOffset, startPos + direction * (outwardOffset + 10)) * ARROW_ROTATION_OFFSET
	_AimArrow.CFrame = arrowCFrame
end

-- Destroys the aim arrow
local function DestroyAimArrow()
	if _AimArrow then
		_AimArrow:Destroy()
		_AimArrow = nil
	end
end

-- Updates aim direction based on camera look direction
local function UpdateAimFromCamera()
	local character = LocalPlayer.Character
	if not character then return end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	-- Get camera look direction, flattened to horizontal
	local cameraLook = CurrentCamera.CFrame.LookVector
	local flatLook = Vector3.new(cameraLook.X, 0, cameraLook.Z)

	-- Only update if we have a valid horizontal direction
	if flatLook.Magnitude > 0.01 then
		_CurrentDirection = flatLook.Unit

		-- Rotate character to face aim direction
		local pos = hrp.Position
		hrp.CFrame = CFrame.lookAt(pos, pos + _CurrentDirection)
	end
end

-- Adjusts power by delta (clamped to min/max)
local function AdjustPower(delta)
	if not _IsAiming then return end

	_CurrentPower = math.clamp(
		_CurrentPower + delta,
		RoundConfig.AIM_POWER_MIN,
		RoundConfig.AIM_POWER_MAX
	)

	DebugLog("Power:", _CurrentPower)
end

-- Submits the current aim to the server
local function SubmitAim()
	-- Verify player is still alive before submitting
	if not IsLocalPlayerInRound() then
		DebugLog("Cannot submit aim - player not in round or eliminated")
		return
	end
	DebugLog("Submitting aim - Direction:", _CurrentDirection, "Power:", _CurrentPower)
	SubmitAimRemoteEvent:FireServer(_CurrentDirection, _CurrentPower)
end

-- Starts the aiming mode
local function StartAiming()
	if _IsAiming then return end

	DebugLog("Starting aim mode")
	_IsAiming = true

	-- Reset to default power
	_CurrentPower = RoundConfig.DEFAULT_AIM_POWER

	-- Get initial direction from camera
	UpdateAimFromCamera()

	-- Create visual arrow
	CreateAimArrow()

	-- Setup input handling for power adjustment
	_InputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		-- Q to decrease power
		if input.KeyCode == Enum.KeyCode.Q then
			AdjustPower(-1)
		end

		-- E to increase power
		if input.KeyCode == Enum.KeyCode.E then
			AdjustPower(1)
		end
	end)

	-- Render loop to sync player rotation with camera
	_RenderConnection = RunService.RenderStepped:Connect(function()
		-- Update aim direction from camera
		UpdateAimFromCamera()

		-- Update arrow visual
		UpdateAimArrow()
	end)

	-- Start timer to submit aim when aiming phase ends
	_HasSubmittedAim = false
	_AimTimerThread = task.delay(RoundConfig.Timers.AIMING_DURATION, function()
		if _IsAiming and not _HasSubmittedAim then
			DebugLog("Aiming timer ended, submitting aim")
			SubmitAim()
			_HasSubmittedAim = true
		end
	end)
end

-- Stops the aiming mode
local function StopAiming()
	if not _IsAiming then return end

	DebugLog("Stopping aim mode")

	_IsAiming = false

	-- Cancel the aim timer if it hasn't fired yet
	if _AimTimerThread then
		task.cancel(_AimTimerThread)
		_AimTimerThread = nil
	end

	-- Cleanup input connection
	if _InputConnection then
		_InputConnection:Disconnect()
		_InputConnection = nil
	end

	-- Cleanup render connection
	if _RenderConnection then
		_RenderConnection:Disconnect()
		_RenderConnection = nil
	end

	-- Destroy arrow
	DestroyAimArrow()
end

-- Creates arrows for all players during the reveal phase
local function StartReveal()
	DebugLog("Starting reveal phase arrows")

	-- Get revealed aims from RoundState in ClientDataStream
	local roundState = ClientDataStream.RoundState
	if not roundState then
		warn("[AimController] RoundState not found in ClientDataStream")
		return
	end

	local revealedAims = roundState.RevealedAims:Read()
	if not revealedAims then return end

	-- Create arrow for each player with revealed aim
	for odometer, aimData in pairs(revealedAims) do
		-- Find the player's character by UserId
		local userId = tonumber(odometer)
		local player = Players:GetPlayerByUserId(userId)
		local character = nil

		if player then
			character = player.Character
		elseif userId and userId < 0 then
			-- Dummy player - model name is "Dummy_X" where X is absolute value of UserId
			local dummyModelName = "Dummy_" .. math.abs(userId)
			character = workspace:FindFirstChild(dummyModelName)
		end

		if character and aimData.Direction and aimData.Power then
			-- Reconstruct direction Vector3 from table
			local direction = Vector3.new(aimData.Direction.X, aimData.Direction.Y, aimData.Direction.Z)
			local power = aimData.Power

			local arrow = CreateArrowForCharacter(character)
			if arrow then
				UpdateArrowTransform(arrow, character, direction, power)
				_RevealArrows[character] = arrow
				DebugLog("Created reveal arrow for", character.Name)
			end
		end
	end
end

-- Destroys all reveal phase arrows
local function StopReveal()
	DebugLog("Stopping reveal phase arrows")

	for _, arrow in pairs(_RevealArrows) do
		if arrow then
			arrow:Destroy()
		end
	end
	_RevealArrows = {}
end

-- API Functions --

function AimController:GetCurrentPower()
	return _CurrentPower
end

function AimController:GetCurrentDirection()
	return _CurrentDirection
end

function AimController:IsAiming()
	return _IsAiming
end

function AimController:AdjustPower(delta)
	AdjustPower(delta)
end

-- Initializers --
function AimController:Init()
	DebugLog("Initializing...")

	-- Wait for ClientDataStream to be ready
	task.defer(function()
		-- Wait a moment for DataStream to initialize
		task.wait(1)

		-- Listen for round state changes
		local roundState = ClientDataStream.RoundState
		if roundState then
			local lastKnownState = roundState.State:Read()

			roundState.State:Changed(function(newState)
				-- Only react if the state actually changed
				if newState == lastKnownState then
					return
				end

				local previousState = lastKnownState
				lastKnownState = newState

				DebugLog("Round state changed:", previousState, "->", newState)

				-- Handle Aiming phase (only if player is in the round)
				if newState == "Aiming" and IsLocalPlayerInRound() then
					StartAiming()
				elseif previousState == "Aiming" and newState ~= "Aiming" then
					StopAiming()
				end

				-- Handle Revealing phase
				if newState == "Revealing" then
					StartReveal()
				elseif previousState == "Revealing" and newState ~= "Revealing" then
					StopReveal()
				end
			end)

			-- Check if we're already in aiming state (only if player is in the round)
			if lastKnownState == "Aiming" and IsLocalPlayerInRound() then
				StartAiming()
			elseif lastKnownState == "Revealing" then
				StartReveal()
			end
		else
			warn("[AimController] RoundState not found in ClientDataStream")
		end
	end)
end

-- Return Module --
return AimController
