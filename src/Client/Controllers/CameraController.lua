--[[
	CameraController.lua

	Description:
		Handles camera behavior for physics box characters during rounds.
		Sets camera subject to HumanoidRootPart and uses standard Roblox camera controls.
--]]

-- Root --
local CameraController = {}

-- Roblox Services --
local Players = game:GetService("Players")

-- Dependencies --
local ClientDataStream = shared("ClientDataStream")
local RoundConfig = shared("RoundConfig")

-- Object References --
local LocalPlayer = Players.LocalPlayer
local CurrentCamera = workspace.CurrentCamera

-- Private Variables --
local _IsInRound = false

-- Internal Functions --

local function DebugLog(...)
	if RoundConfig.DEBUG_LOG_STATE_CHANGES then
		print("[CameraController]", ...)
	end
end

-- Sets up camera to follow the physics box with standard Roblox controls
local function SetupRoundCamera()
	local character = LocalPlayer.Character
	if not character then return end

	-- Physics box characters have no Humanoid - use HumanoidRootPart directly
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp then
		CurrentCamera.CameraSubject = hrp
		CurrentCamera.CameraType = Enum.CameraType.Custom
		DebugLog("Camera subject set to HumanoidRootPart")
	end
end

-- Starts round camera mode
local function StartRoundCamera()
	if _IsInRound then return end
	_IsInRound = true

	DebugLog("Starting round camera")
	SetupRoundCamera()
end

-- Stops round camera mode (restore default)
local function StopRoundCamera()
	if not _IsInRound then return end
	_IsInRound = false

	DebugLog("Stopping round camera")

	-- Restore default camera behavior
	CurrentCamera.CameraType = Enum.CameraType.Custom
	local character = LocalPlayer.Character
	if character then
		-- Try humanoid first (normal character), fallback to HumanoidRootPart
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			CurrentCamera.CameraSubject = humanoid
		else
			local hrp = character:FindFirstChild("HumanoidRootPart")
			if hrp then
				CurrentCamera.CameraSubject = hrp
			end
		end
	end
end

-- API Functions --

function CameraController:IsInRoundCamera()
	return _IsInRound
end

-- Returns the camera's look direction projected onto the XZ plane (for aiming)
function CameraController:GetAimDirection()
	local lookVector = CurrentCamera.CFrame.LookVector
	-- Project onto XZ plane (remove Y component) and normalize
	local flatDirection = Vector3.new(lookVector.X, 0, lookVector.Z)
	if flatDirection.Magnitude < 0.01 then
		return Vector3.new(0, 0, 1) -- Default forward if looking straight up/down
	end
	return flatDirection.Unit
end

-- Initializers --
function CameraController:Init()
	DebugLog("Initializing...")

	-- Listen for round state changes
	task.defer(function()
		task.wait(1) -- Wait for DataStream

		local roundState = ClientDataStream.RoundState
		if roundState then
			roundState.State:Changed(function(newState)
				-- Start camera when entering round phases
				local roundPhases = {
					Spawning = true,
					Aiming = true,
					Revealing = true,
					Launching = true,
					Resolution = true,
				}

				if roundPhases[newState] and not _IsInRound then
					StartRoundCamera()
				elseif newState == "Waiting" or newState == "RoundEnd" then
					StopRoundCamera()
				end
			end)

			-- Check current state
			local currentState = roundState.State:Read()
			if currentState ~= "Waiting" and currentState ~= "RoundEnd" then
				StartRoundCamera()
			end
		end
	end)

	-- Handle character changes (respawns, physics box creation)
	LocalPlayer.CharacterAdded:Connect(function()
		if _IsInRound then
			task.wait(0.1) -- Brief delay for character to fully load
			SetupRoundCamera()
		end
	end)
end

-- Return Module --
return CameraController
