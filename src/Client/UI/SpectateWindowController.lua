--[[
	SpectateWindowController.lua

	Description:
		Manages the SpectateWindow UI for spectating active rounds.
		Shows/hides based on round state and player participation.
		Handles button interactions and keyboard shortcuts.
--]]

-- Root --
local SpectateWindowController = {}

-- Roblox Services --
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

-- Dependencies --
local ClientDataStream = shared("ClientDataStream")
local UIController = shared("UIController")
local RoundConfig = shared("RoundConfig")
local SpectateController = shared("SpectateController")
local PromiseWaitForDataStream = shared("PromiseWaitForDataStream")

-- Object References --
local LocalPlayer = Players.LocalPlayer

-- Private Variables --
local _ScreenGui = nil
local _MainFraem = nil
local _BackButton = nil
local _NextButton = nil
local _ExitButton = nil
local _LocationLabel = nil
local _IsSetup = false
local _InputConnection = nil
local _RoundStateConnection = nil
local _PlayersConnection = nil

-- Internal Functions --

local function DebugLog(...)
	if RoundConfig.DEBUG_LOG_STATE_CHANGES then
		print("[SpectateWindowController]", ...)
	end
end

-- Determines if a round is currently in progress
local function IsRoundActive()
	local roundState = ClientDataStream.RoundState
	if not roundState then
		return false
	end

	local state = roundState.State:Read()
	return state ~= "Waiting" and state ~= "RoundEnd"
end

-- Determines if local player is in the lobby (not participating in round)
local function IsPlayerInLobby()
	local roundState = ClientDataStream.RoundState
	if not roundState then
		return true
	end

	local players = roundState.Players:Read() or {}
	local localUserId = tostring(LocalPlayer.UserId)

	return players[localUserId] == nil
end

-- Returns true if player can spectate
local function CanSpectate()
	return IsRoundActive() and IsPlayerInLobby()
end

-- Updates the location text display
local function UpdateLocationLabel()
	if not _LocationLabel then
		return
	end

	local location = SpectateController:GetCurrentLocation()
	_LocationLabel.Text = location or "Unknown"
end

-- Starts spectate mode
local function StartSpectateMode()
	local success = SpectateController:StartSpectating()
	if not success then
		warn("[SpectateWindowController] Failed to start spectating - no spectate points found")
		return false
	end

	-- Show the window
	if _ScreenGui then
		_ScreenGui.Enabled = true
	end

	UpdateLocationLabel()

	-- Setup keyboard shortcuts
	_InputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end

		if input.KeyCode == Enum.KeyCode.Q then
			SpectateController:PreviousPoint()
			UpdateLocationLabel()
		elseif input.KeyCode == Enum.KeyCode.E then
			SpectateController:NextPoint()
			UpdateLocationLabel()
		end
	end)

	DebugLog("Spectate mode started")
	return true
end

-- Stops spectate mode
local function StopSpectateMode()
	SpectateController:StopSpectating()

	if _ScreenGui then
		_ScreenGui.Enabled = false
	end

	if _InputConnection then
		_InputConnection:Disconnect()
		_InputConnection = nil
	end

	DebugLog("Spectate mode stopped")
end

-- Sets up UI references and handlers
local function SetupUI(screenGui)
	if _IsSetup then
		return
	end

	_ScreenGui = screenGui
	_ScreenGui.Enabled = false -- Start hidden

	-- Get BottomBar references
	local _MainFrame = _ScreenGui:WaitForChild("MainFrame")

	local centerPanel = _MainFrame:WaitForChild("CenterPanel")
	local textSection = centerPanel:WaitForChild("TextSection")
	_LocationLabel = textSection:WaitForChild("Location")
	_ExitButton = centerPanel:WaitForChild("ExitButton")

	_BackButton = _MainFrame:WaitForChild("BackButton")
	_NextButton = _MainFrame:WaitForChild("NextButton")

	-- Button handlers
	_BackButton.MouseButton1Click:Connect(function()
		SpectateController:PreviousPoint()
		UpdateLocationLabel()
	end)

	_NextButton.MouseButton1Click:Connect(function()
		SpectateController:NextPoint()
		UpdateLocationLabel()
	end)

	_ExitButton.MouseButton1Click:Connect(function()
		StopSpectateMode()
	end)

	_IsSetup = true
	DebugLog("UI setup complete")
end

-- API Functions --

-- Toggles spectate mode on/off
function SpectateWindowController:ToggleSpectate()
	if SpectateController:IsSpectating() then
		StopSpectateMode()
	else
		if CanSpectate() then
			StartSpectateMode()
		else
			DebugLog("Cannot spectate - either round not active or player is in round")
		end
	end
end

-- Returns whether spectating is currently possible
function SpectateWindowController:CanSpectate()
	return CanSpectate()
end

-- Initializers --
function SpectateWindowController:Init()
	DebugLog("Initializing...")

	-- Wait for UIController to be ready
	UIController:WhenScreenGuiReady("SpectateWindow", function(screenGui)
		SetupUI(screenGui)
	end)

	-- Wait for ClientDataStream to be ready
	PromiseWaitForDataStream(ClientDataStream.RoundState):andThen(function(roundState)
		-- Listen for round state changes
		_RoundStateConnection = roundState.State:Changed(function(newState)
			-- Auto-stop spectating when round ends
			if newState == "Waiting" or newState == "RoundEnd" then
				if SpectateController:IsSpectating() then
					StopSpectateMode()
				end
			end
		end)

		DebugLog("Listening for round state changes")
	end)
end

-- Return Module --
return SpectateWindowController
