--[[
	SwitchServerController.lua

	Description:
		Shows a popup when:
		- Player count is below minimum required to start
		- Game has been stuck in Waiting state too long
		Players can switch to a new server or stay.
--]]

-- Root --
local SwitchServerController = {}

-- Roblox Services --
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Dependencies --
local ClientDataStream = shared("ClientDataStream")
local UIController = shared("UIController")
local RoundConfig = shared("RoundConfig")
local GetRemoteEvent = shared("GetRemoteEvent")

-- Remote Events --
local SwitchServerRemoteEvent = GetRemoteEvent("SwitchServer")

-- Constants --
local WINDOW_NAME = "SwitchServerWindow"
local WAITING_TIMEOUT = RoundConfig.SWITCH_SERVER_TIMEOUT or 90
local COOLDOWN_AFTER_STAY = RoundConfig.SWITCH_SERVER_COOLDOWN or 120
local MIN_PLAYERS = RoundConfig.MIN_PLAYERS_TO_START or 2

-- Private Variables --
local _WaitingStartTime = nil
local _LastStayTime = 0
local _WindowShown = false
local _JoinTime = tick()

-- Internal Functions --
local function GetActivePlayerCount()
	return #Players:GetPlayers()
end

local function ShouldShowWindow()
	if tick() - _LastStayTime < COOLDOWN_AFTER_STAY then
		return false
	end

	-- Don't show if not in Waiting state
	local roundState = ClientDataStream.RoundState
	if not roundState then return false end

	local state = roundState.State:Read()
	if state ~= "Waiting" then
		return false
	end

	-- Show if below minimum players (only after being in server for timeout period)
	if GetActivePlayerCount() < MIN_PLAYERS and (tick() - _JoinTime) > WAITING_TIMEOUT then
		return true
	end

	-- Show if been waiting too long
	if _WaitingStartTime and (tick() - _WaitingStartTime) > WAITING_TIMEOUT then
		return true
	end

	return false
end

local function ShowWindow()
	if _WindowShown then return end
	_WindowShown = true
	UIController:OpenWindow(WINDOW_NAME)
end

local function HideWindow()
	if not _WindowShown then return end
	_WindowShown = false
	UIController:CloseWindow(WINDOW_NAME)
end

local function OnYesClicked()
	SwitchServerRemoteEvent:FireServer()
end

local function OnStayClicked()
	_LastStayTime = tick()
	HideWindow()
end

local function SetupButtons(screenGui)
	local mainFrame = screenGui:FindFirstChild("MainFrame")
	if not mainFrame then return end

	local buttonContainer = mainFrame:FindFirstChild("ButtonContainer")
	if not buttonContainer then return end

	local yesButton = buttonContainer:FindFirstChild("YesButton")
	local stayButton = buttonContainer:FindFirstChild("StayButton")

	if yesButton then
		yesButton.MouseButton1Click:Connect(OnYesClicked)
	end

	if stayButton then
		stayButton.MouseButton1Click:Connect(OnStayClicked)
	end
end

local function OnStateChanged(newState)
	if newState == "Waiting" then
		_WaitingStartTime = tick()
	else
		_WaitingStartTime = nil
		HideWindow()
	end
end

local function CheckConditions()
	if ShouldShowWindow() then
		ShowWindow()
	end
end

-- Initializers --
function SwitchServerController:Init()
	UIController:WhenScreenGuiReady(WINDOW_NAME, function(screenGui)
		SetupButtons(screenGui)
	end)

	local roundState = ClientDataStream.RoundState
	if roundState then
		local currentState = roundState.State:Read()
		if currentState == "Waiting" then
			_WaitingStartTime = tick()
		end

		roundState.State:Changed(OnStateChanged)
	end
	RunService.Heartbeat:Connect(CheckConditions)
end

-- Return Module --
return SwitchServerController
