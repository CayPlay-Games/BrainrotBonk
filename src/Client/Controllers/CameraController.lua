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
local PromiseWaitForDataStream = shared("PromiseWaitForDataStream")

-- Object References --
local LocalPlayer = Players.LocalPlayer
local CurrentCamera = workspace.CurrentCamera

-- Private Variables --
local _IsInRound = false
local _CameraSetupSuccessful = false

-- Internal Functions --

local function DebugLog(...)
	if RoundConfig.DEBUG_LOG_STATE_CHANGES then
		print("[CameraController]", ...)
	end
end

-- Checks if the local player is participating and alive in the current round
local function IsLocalPlayerInRound()
	local roundState = ClientDataStream.RoundState
	if not roundState then
		return false
	end
	local players = roundState.Players:Read() or {}
	local localUserId = tostring(LocalPlayer.UserId)
	local playerData = players[localUserId]
	return playerData ~= nil and playerData.IsAlive == true
end

-- Sets up camera to follow the physics box with standard Roblox controls
-- Returns true if successful, false otherwise
local function SetupRoundCamera()
	local character = LocalPlayer.Character
	if not character then
		DebugLog("SetupRoundCamera failed: No character")
		_CameraSetupSuccessful = false
		return false
	end

	-- Physics box characters have no Humanoid - use HumanoidRootPart directly
	-- Use WaitForChild with timeout to handle replication delay
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		-- Try waiting briefly for HRP to replicate
		hrp = character:WaitForChild("HumanoidRootPart", 2)
	end

	if hrp then
		CurrentCamera.CameraSubject = hrp
		CurrentCamera.CameraType = Enum.CameraType.Custom
		_CameraSetupSuccessful = true
		DebugLog("Camera subject set to HumanoidRootPart:", character.Name)
		return true
	else
		DebugLog("SetupRoundCamera failed: No HumanoidRootPart in", character.Name)
		_CameraSetupSuccessful = false
		return false
	end
end

-- Starts round camera mode
local function StartRoundCamera()
	if _IsInRound then
		-- Already in round mode, but check if setup was successful
		if not _CameraSetupSuccessful then
			DebugLog("Retrying camera setup (was in round but setup failed)")
			SetupRoundCamera()
		end
		return
	end
	_IsInRound = true

	DebugLog("Starting round camera")
	SetupRoundCamera()
end

-- Stops round camera mode (restore default)
local function StopRoundCamera()
	if not _IsInRound then
		return
	end
	_IsInRound = false
	_CameraSetupSuccessful = false

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
	PromiseWaitForDataStream(ClientDataStream.RoundState):andThen(function(roundState)
		local roundPhases = {
			Spawning = true,
			Aiming = true,
			Revealing = true,
			Launching = true,
			Resolution = true,
		}

		-- Helper to check and start camera if conditions are met
		local function TryStartRoundCamera()
			local currentState = roundState.State:Read()
			if not roundPhases[currentState] then
				return
			end
			if not IsLocalPlayerInRound() then
				return
			end

			if not _IsInRound then
				StartRoundCamera()
			elseif not _CameraSetupSuccessful then
				-- Already in round but setup failed, retry
				DebugLog("Retrying camera setup from TryStartRoundCamera")
				SetupRoundCamera()
			end
		end

		roundState.State:Changed(function(newState)
			-- Start camera when entering round phases (only if player is in the round)
			if roundPhases[newState] and not _IsInRound and IsLocalPlayerInRound() then
				StartRoundCamera()
			elseif newState == "Waiting" or newState == "RoundEnd" then
				StopRoundCamera()
			end
		end)

		-- Also listen for Players changes (player might be added after state change)
		roundState.Players:Changed(function()
			TryStartRoundCamera()
		end)

		-- Check current state (only if player is in the round)
		TryStartRoundCamera()
	end)

	-- Handle character changes (respawns, physics box creation)
	LocalPlayer.CharacterAdded:Connect(function(character)
		DebugLog("CharacterAdded:", character.Name)
		task.wait(0.1) -- Brief delay for character to fully load

		if _IsInRound then
			-- Already in round mode, update camera subject to new character
			DebugLog("In round mode, setting up camera for new character")
			SetupRoundCamera()
		elseif IsLocalPlayerInRound() then
			-- Player was added to round, start round camera
			DebugLog("Player in round, starting round camera")
			StartRoundCamera()
		end
	end)
end

-- Return Module --
return CameraController
