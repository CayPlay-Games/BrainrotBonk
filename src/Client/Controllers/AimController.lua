--[[
	AimController.lua

	Description:
		Handles player aiming during the Aiming phase.
		- Player rotates to face camera direction
		- Q/E to adjust power level
		- Visual arrow indicator for aim direction
		- Auto-submits aim when phase ends
--]]

-- Root --
local AimController = {}

-- Roblox Services --
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- Dependencies --
local ClientDataStream = shared("ClientDataStream")
local GetRemoteEvent = shared("GetRemoteEvent")
local RoundConfig = shared("RoundConfig")

-- Object References --
local LocalPlayer = Players.LocalPlayer
local CurrentCamera = workspace.CurrentCamera
local SubmitAimRemoteEvent = GetRemoteEvent("SubmitAim")

-- Private Variables --
local _IsAiming = false
local _CurrentPower = RoundConfig.DEFAULT_AIM_POWER
local _CurrentDirection = Vector3.new(0, 0, 1) -- Forward
local _AimArrow = nil
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

-- Creates the visual arrow indicator
local function CreateAimArrow()
	if _AimArrow then
		_AimArrow:Destroy()
	end

	local character = LocalPlayer.Character
	if not character then return end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	-- Create arrow model
	local arrow = Instance.new("Model")
	arrow.Name = "AimArrow"

	-- Arrow shaft
	local shaft = Instance.new("Part")
	shaft.Name = "Shaft"
	shaft.Size = Vector3.new(0.3, 0.3, 3)
	shaft.Color = Color3.fromRGB(255, 255, 255)
	shaft.Material = Enum.Material.Neon
	shaft.Anchored = true
	shaft.CanCollide = false
	shaft.CastShadow = false
	shaft.Parent = arrow

	-- Arrow head
	local head = Instance.new("WedgePart")
	head.Name = "Head"
	head.Size = Vector3.new(0.6, 0.6, 0.8)
	head.Color = Color3.fromRGB(255, 255, 255)
	head.Material = Enum.Material.Neon
	head.Anchored = true
	head.CanCollide = false
	head.CastShadow = false
	head.Parent = arrow

	arrow.PrimaryPart = shaft
	arrow.Parent = character

	_AimArrow = arrow
end

-- Updates the arrow position and rotation to match aim direction
local function UpdateAimArrow()
	if not _AimArrow then return end

	local character = LocalPlayer.Character
	if not character then return end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local shaft = _AimArrow:FindFirstChild("Shaft")
	local head = _AimArrow:FindFirstChild("Head")
	if not shaft or not head then return end

	-- Position arrow in front of player
	local startPos = hrp.Position
	local direction = _CurrentDirection.Unit
	local arrowLength = 1.5 + (_CurrentPower / RoundConfig.AIM_POWER_MAX) * 2 -- Scale with power

	-- Arrow shaft
	local shaftLength = arrowLength
	shaft.Size = Vector3.new(0.3, 0.3, shaftLength)
	shaft.CFrame = CFrame.lookAt(startPos + direction * (shaftLength / 2 + 1.5), startPos + direction * 10)

	-- Arrow head at end of shaft
	head.CFrame = CFrame.lookAt(startPos + direction * (shaftLength + 1.5 + 0.4), startPos + direction * 10) * CFrame.Angles(0, 0, math.rad(90))

	-- Color based on power (green -> yellow -> red)
	local powerRatio = (_CurrentPower - RoundConfig.AIM_POWER_MIN) / (RoundConfig.AIM_POWER_MAX - RoundConfig.AIM_POWER_MIN)
	local color
	if powerRatio < 0.5 then
		-- Green to Yellow
		color = Color3.fromRGB(
			math.floor(255 * (powerRatio * 2)),
			255,
			0
		)
	else
		-- Yellow to Red
		color = Color3.fromRGB(
			255,
			math.floor(255 * (1 - (powerRatio - 0.5) * 2)),
			0
		)
	end
	shaft.Color = color
	head.Color = color
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

				if newState == "Aiming" then
					StartAiming()
				elseif previousState == "Aiming" and newState ~= "Aiming" then
					StopAiming()
				end
			end)

			-- Check if we're already in aiming state
			if lastKnownState == "Aiming" then
				StartAiming()
			end
		else
			warn("[AimController] RoundState not found in ClientDataStream")
		end
	end)
end

-- Return Module --
return AimController
