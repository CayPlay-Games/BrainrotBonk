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
local RoundConfig = shared("RoundConfig")

-- Object References --
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Constants --
local STATUS_MESSAGES = {
	Waiting = "Waiting for players...",
	MapLoading = "Loading map...",
	Spawning = "Get ready!",
	Aiming = "Aim your shot!",
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

-- Internal Functions --

local function DebugLog(...)
	if RoundConfig.DEBUG_LOG_STATE_CHANGES then
		print("[MainHUD]", ...)
	end
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

	-- Hook up menu button clicks
	buttonGrid.PenguinButton.MouseButton1Click:Connect(function()
		DebugLog("Penguin clicked")
	end)

	buttonGrid.ShopButton.MouseButton1Click:Connect(function()
		DebugLog("Shop clicked")
	end)

	buttonGrid.IndexButton.MouseButton1Click:Connect(function()
		DebugLog("Index clicked")
	end)

	buttonGrid.QuestsButton.MouseButton1Click:Connect(function()
		DebugLog("Quests clicked")
	end)

	-- AFK button toggle
	_AFKButton.MouseButton1Click:Connect(function()
		_IsAFK = not _IsAFK
		DebugLog("AFK toggled:", _IsAFK)
		-- TODO: Update visual state and notify server
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
local function UpdateStatus(state, roundNumber)
	if not _StatusText then return end

	local message = STATUS_MESSAGES[state] or state
	_StatusText.Text = message

	if _RoundText and roundNumber then
		_RoundText.Text = "Round " .. roundNumber
	end

	if _RoundLabel then
		_RoundLabel.Visible = (state ~= "Waiting")
	end
end

-- API Functions --

function MainHUD:SetCurrency(amount)
	if _CurrencyDisplay then
		-- Find the TextLabel inside CurrencyDisplay to update
		local amountLabel = _CurrencyDisplay:FindFirstChild("TextLabel")
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

	task.defer(function()
		task.wait(1)

		local roundState = ClientDataStream.RoundState
		if roundState then
			UpdateStatus(roundState.State:Read(), roundState.RoundNumber:Read())

			roundState.State:Changed(function(newState)
				UpdateStatus(newState, roundState.RoundNumber:Read())
			end)

			roundState.RoundNumber:Changed(function(newRoundNumber)
				UpdateStatus(roundState.State:Read(), newRoundNumber)
			end)
		end
	end)
end

-- Return Module --
return MainHUD
