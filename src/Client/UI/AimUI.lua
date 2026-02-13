--[[
	AimUI.lua

	Description:
		UI for the aiming phase - shows power bar and instructions.
		Connects to Studio-created UI from ReplicatedStorage.
--]]

-- Root --
local AimUI = {}

-- Roblox Services --
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Dependencies --
local ClientDataStream = shared("ClientDataStream")
local RoundConfig = shared("RoundConfig")

-- Object References --
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Constants --
local POWER_BAR_SEGMENTS = 10

-- Private Variables --
local _ScreenGui = nil
local _PowerFrame = nil
local _PowerSegments = {}
local _PowerLabel = nil
local _QButton = nil
local _EButton = nil
local _RenderConnection = nil
local _IsVisible = false

-- Internal Functions --

local function DebugLog(...)
	if RoundConfig.DEBUG_LOG_STATE_CHANGES then
		print("[AimUI]", ...)
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

-- Clones UI from ReplicatedStorage and gets references
local function SetupUI()
	if _ScreenGui then return end

	-- Clone AimUI from ReplicatedStorage/UI
	local uiFolder = ReplicatedStorage:WaitForChild("UI")
	local aimUITemplate = uiFolder:WaitForChild("AimUI")
	_ScreenGui = aimUITemplate:Clone()
	_ScreenGui.Enabled = false
	_ScreenGui.Parent = PlayerGui

	-- Get references
	local container = _ScreenGui.Container
	_PowerLabel = container.PowerLabel

	local powerBarBg = container.PowerBarBg
	_PowerFrame = powerBarBg.PowerFrame

	-- Get segment references
	for i = 1, POWER_BAR_SEGMENTS do
		local segment = _PowerFrame:FindFirstChild("Segment" .. i)
		if segment then
			_PowerSegments[i] = segment
		end
	end

	-- Get Q/E button references and add click handlers
	_QButton = container:FindFirstChild("QButton")
	_EButton = container:FindFirstChild("EButton")

	if _QButton then
		_QButton.MouseButton1Click:Connect(function()
			local AimController = shared("AimController")
			if AimController and AimController:IsAiming() then
				AimController:AdjustPower(-1)
			end
		end)
	end

	if _EButton then
		_EButton.MouseButton1Click:Connect(function()
			local AimController = shared("AimController")
			if AimController and AimController:IsAiming() then
				AimController:AdjustPower(1)
			end
		end)
	end

	DebugLog("UI setup complete")
end

local function UpdatePowerDisplay(power)
	if not _PowerLabel then return end

	-- Update label
	_PowerLabel.Text = "Power " .. power

	-- Calculate color based on current power (all active segments same color)
	local powerRatio = (power - 1) / (POWER_BAR_SEGMENTS - 1) -- 0 to 1
	local activeColor
	if powerRatio < 0.5 then
		-- Green to Yellow
		local t = powerRatio * 2
		activeColor = Color3.fromRGB(
			math.floor(255 * t),
			200,
			math.floor(100 * (1 - t))
		)
	else
		-- Yellow to Red
		local t = (powerRatio - 0.5) * 2
		activeColor = Color3.fromRGB(
			255,
			math.floor(200 * (1 - t) + 80 * t),
			0
		)
	end

	-- Update segments
	for i, segment in ipairs(_PowerSegments) do
		if i <= power then
			segment.BackgroundColor3 = activeColor
		else
			segment.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
		end
	end
end

local function Show()
	if _IsVisible then return end
	_IsVisible = true

	SetupUI()
	_ScreenGui.Enabled = true

	-- Defensive: ensure old connection is cleaned up
	if _RenderConnection then
		_RenderConnection:Disconnect()
		_RenderConnection = nil
	end

	-- Start updating power display
	_RenderConnection = RunService.RenderStepped:Connect(function()
		local AimController = shared("AimController")
		if AimController and AimController:IsAiming() then
			UpdatePowerDisplay(AimController:GetCurrentPower())
		end
	end)
end

local function Hide()
	if not _IsVisible then return end
	_IsVisible = false

	if _ScreenGui then
		_ScreenGui.Enabled = false
	end

	if _RenderConnection then
		_RenderConnection:Disconnect()
		_RenderConnection = nil
	end
end

-- API Functions --

function AimUI:Show()
	Show()
end

function AimUI:Hide()
	Hide()
end

function AimUI:IsVisible()
	return _IsVisible
end

-- Initializers --
function AimUI:Init()
	DebugLog("Initializing...")

	-- Pre-setup the UI
	SetupUI()

	-- Listen for round state changes
	task.defer(function()
		task.wait(1) -- Wait for DataStream

		local roundState = ClientDataStream.RoundState
		if roundState then
			roundState.State:Changed(function(newState, oldState)
				if newState == "Aiming" and IsLocalPlayerInRound() then
					Show()
				elseif oldState == "Aiming" or newState == "Waiting" or newState == "RoundEnd" then
					Hide()
				end
			end)

			-- Check current state (only if player is in the round)
			if roundState.State:Read() == "Aiming" and IsLocalPlayerInRound() then
				Show()
			end
		end
	end)
end

-- Return Module --
return AimUI
