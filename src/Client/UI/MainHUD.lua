--[[
	MainHUD.lua

	Description:
		Main game HUD - connects to Studio-created UI from ReplicatedStorage.
		Handles round status updates, button clicks, and AFK toggle.
--]]

-- Root --
local MainHUD = {}

-- Roblox Services --
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Dependencies --
local ClientDataStream = shared("ClientDataStream")
local OnLocalPlayerStoredDataStreamLoaded = shared("OnLocalPlayerStoredDataStreamLoaded")
local RoundConfig = shared("RoundConfig")
local GetRemoteEvent = shared("GetRemoteEvent")

-- Remote Events --
local ToggleAFKRemoteEvent = GetRemoteEvent("ToggleAFK")

-- Object References --
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Constants --
local STATUS_MESSAGES = {
	Waiting = "Waiting for players...",
	MapLoading = "Loading map...",
	Spawning = "Get ready!",
	Aiming = "Revealing aims in %d...",
	Revealing = "Revealing aims...",
	Launching = "Launch!",
	Resolution = "Round in progress!",
	RoundEnd = "Round over!",
}

-- Private Variables --
local _ScreenGui = nil
local _TopBanner = nil
local _StatusText = nil
local _RoundLabel = nil
local _RoundText = nil
local _CurrencyDisplay = nil
local _AFKButton = nil
local _SpectateButton = nil
local _SettingsButton = nil
local _PickMapButton = nil
local _PatchNotesButton = nil
local _IsAFK = false
local _PlayerStoredDataStream = nil

-- Internal Functions --

local function DebugLog(...)
	if RoundConfig.DEBUG_LOG_STATE_CHANGES then
		print("[MainHUD]", ...)
	end
end

-- Updates AFK button visual state
local function UpdateAFKButtonVisual()
	if not _AFKButton then return end

	-- Update button text and color
	if _IsAFK then
		_AFKButton.Text = "AFK"
		_AFKButton.BackgroundColor3 = Color3.fromRGB(255, 80, 80) -- Red when AFK
	else
		_AFKButton.Text = "Go AFK?"
		_AFKButton.BackgroundColor3 = Color3.fromRGB(80, 200, 80) -- Green when active
	end

	-- Toggle child TextLabel visibility (visible when AFK, hidden when not)
	local textLabel = _AFKButton:FindFirstChildWhichIsA("TextLabel")
	if textLabel then
		textLabel.Visible = _IsAFK
	end
end

-- Updates AFK button visibility based on round state
local function UpdateAFKButtonVisibility(state)
	if not _AFKButton then return end
	-- Only show AFK button during Waiting or RoundEnd
	local canToggleAFK = (state == "Waiting" or state == "RoundEnd")
	_AFKButton.Visible = canToggleAFK
end

-- Clones UI from ReplicatedStorage and gets references
local function SetupUI()
	if _ScreenGui then return end

	-- Clone HUD from ReplicatedStorage/UI
	local uiFolder = ReplicatedStorage:WaitForChild("UI")
	local hudTemplate = uiFolder:WaitForChild("HUD")
	_ScreenGui = hudTemplate:Clone()
	_ScreenGui.Parent = PlayerGui

	local topFrame = _ScreenGui.TopFrame
	_TopBanner = topFrame.TopBanner
	_StatusText = _TopBanner.TextLabel
	_RoundLabel = topFrame.RoundLabel
	_RoundText = _RoundLabel.TextLabel

	local leftFrame = _ScreenGui.LeftFrame
	local buttonGrid = leftFrame.ButtonGrid
	_CurrencyDisplay = leftFrame.CurrencyDisplay
	_AFKButton = leftFrame.AFKButton

	local bottomLeft = _ScreenGui.BottomLeftFrame
	_SpectateButton = bottomLeft.SpectateButton
	_SettingsButton = bottomLeft.SettingsButton

	local bottomRight = _ScreenGui.BottomRightFrame
	_PatchNotesButton = bottomRight.PatchNotesButton
	_PickMapButton = bottomRight.PickMapButton

	local topRight = _ScreenGui.TopRightFrame

	-- Hook up menu button clicks

	-- Top right buttons
	topRight.RankButton.MouseButton1Click:Connect(function()
		DebugLog("Rank clicked")
		local UIController = shared("UIController")
		UIController:ToggleWindow("RankWindow")
	end)
	buttonGrid.PenguinButton.MouseButton1Click:Connect(function()
		DebugLog("Penguin clicked")
		local UIController = shared("UIController")
		UIController:ToggleWindow("SkinsWindow")
	end)

	buttonGrid.ShopButton.MouseButton1Click:Connect(function()
		DebugLog("Shop clicked")
	end)

	buttonGrid.IndexButton.MouseButton1Click:Connect(function()
		DebugLog("Index clicked")
		local UIController = shared("UIController")
		UIController:ToggleWindow("IndexWindow")
	end)

	buttonGrid.QuestsButton.MouseButton1Click:Connect(function()
		DebugLog("Quests clicked")
	end)

	-- AFK button toggle - request toggle from server
	_AFKButton.MouseButton1Click:Connect(function()
		DebugLog("AFK button clicked, requesting toggle")
		ToggleAFKRemoteEvent:FireServer()
	end)

	-- Bottom left buttons
	_SpectateButton.MouseButton1Click:Connect(function()
		DebugLog("Spectate clicked")
	end)

	_SettingsButton.MouseButton1Click:Connect(function()
		DebugLog("Settings clicked")
	end)

	-- Bottom right buttons
	_PickMapButton.MouseButton1Click:Connect(function()
		DebugLog("Pick Map clicked")
	end)

	_PatchNotesButton.MouseButton1Click:Connect(function()
		DebugLog("Patch Notes clicked")
	end)

	DebugLog("UI setup complete")
end

-- Updates the status display based on round state
local function UpdateStatus(state, roundNumber, timeRemaining)
	if not _StatusText then return end

	local message = STATUS_MESSAGES[state] or state

	-- For Waiting state, show countdown if active, otherwise waiting message
	if state == "Waiting" then
		if timeRemaining and timeRemaining > 0 then
			message = string.format("Game starting in %d...", math.ceil(timeRemaining))
		else
			message = "Waiting for players..."
		end
	-- For Aiming state, show countdown
	elseif state == "Aiming" and timeRemaining then
		message = string.format(STATUS_MESSAGES.Aiming, math.ceil(timeRemaining))
	end

	_StatusText.Text = message

	if _RoundText and roundNumber then
		_RoundText.Text = "Round " .. roundNumber
	end

	if _RoundLabel then
		_RoundLabel.Visible = (state ~= "Waiting")
	end

	-- Update AFK button visibility based on state
	UpdateAFKButtonVisibility(state)
end

-- API Functions --

function MainHUD:SetCurrency(amount)
	if _CurrencyDisplay then
		-- Find the Amount label inside CurrencyDisplay to update
		local amountLabel = _CurrencyDisplay:FindFirstChild("Amount")
		if amountLabel then
			amountLabel.Text = tostring(amount)
		end
	end
end

function MainHUD:IsAFK()
	return _IsAFK
end

-- Initializers --
function MainHUD:Init()
	DebugLog("Initializing...")

	SetupUI()

	-- Listen for currency changes (Stored data)
	OnLocalPlayerStoredDataStreamLoaded(function(PlayerStoredDataStream)
		_PlayerStoredDataStream = PlayerStoredDataStream

		-- Set initial value
		local coins = _PlayerStoredDataStream.Collections.Currencies.Coins:Read() or 0
		MainHUD:SetCurrency(coins)

		-- Listen for changes
		_PlayerStoredDataStream.Collections.Currencies.Coins:Changed(function(newAmount)
			MainHUD:SetCurrency(newAmount)
			DebugLog("Currency updated to:", newAmount)
		end)
	end)

	-- Session and RoundState data (not Stored, use ClientDataStream directly)
	task.defer(function()
		task.wait(1)

		-- Listen for AFK status changes from DataStream
		local sessionData = ClientDataStream.Session
		if sessionData and sessionData.IsAFK then
			_IsAFK = sessionData.IsAFK:Read() or false
			UpdateAFKButtonVisual()
			sessionData.IsAFK:Changed(function(newAFK)
				_IsAFK = newAFK
				UpdateAFKButtonVisual()
				DebugLog("AFK status changed to:", newAFK)
			end)
		end

		local roundState = ClientDataStream.RoundState
		if roundState then
			UpdateStatus(roundState.State:Read(), roundState.RoundNumber:Read(), roundState.TimeRemaining:Read())

			roundState.State:Changed(function(newState)
				UpdateStatus(newState, roundState.RoundNumber:Read(), roundState.TimeRemaining:Read())
			end)

			roundState.RoundNumber:Changed(function(newRoundNumber)
				UpdateStatus(roundState.State:Read(), newRoundNumber, roundState.TimeRemaining:Read())
			end)

			roundState.TimeRemaining:Changed(function(newTimeRemaining)
				UpdateStatus(roundState.State:Read(), roundState.RoundNumber:Read(), newTimeRemaining)
			end)
		end
	end)
end

-- Return Module --
return MainHUD
