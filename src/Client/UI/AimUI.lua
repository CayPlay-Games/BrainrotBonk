--[[
	AimUI.lua

	Description:
		UI for the aiming phase - shows power bar and instructions.
--]]

-- Root --
local AimUI = {}

-- Roblox Services --
local Players = game:GetService("Players")
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
local _InstructionsLabel = nil
local _RenderConnection = nil
local _IsVisible = false

-- Internal Functions --

local function CreateUI()
	if _ScreenGui then return end

	-- Main ScreenGui
	_ScreenGui = Instance.new("ScreenGui")
	_ScreenGui.Name = "AimUI"
	_ScreenGui.ResetOnSpawn = false
	_ScreenGui.IgnoreGuiInset = true
	_ScreenGui.DisplayOrder = 10
	_ScreenGui.Enabled = false
	_ScreenGui.Parent = PlayerGui

	-- Container at bottom center
	local container = Instance.new("Frame")
	container.Name = "Container"
	container.Size = UDim2.new(0, 400, 0, 100)
	container.Position = UDim2.new(0.5, -200, 1, -150)
	container.BackgroundTransparency = 1
	container.Parent = _ScreenGui

	-- Power label
	_PowerLabel = Instance.new("TextLabel")
	_PowerLabel.Name = "PowerLabel"
	_PowerLabel.Size = UDim2.new(1, 0, 0, 30)
	_PowerLabel.Position = UDim2.new(0, 0, 0, 0)
	_PowerLabel.BackgroundTransparency = 1
	_PowerLabel.Font = Enum.Font.GothamBold
	_PowerLabel.TextSize = 24
	_PowerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	_PowerLabel.TextStrokeTransparency = 0.5
	_PowerLabel.Text = "Power 5"
	_PowerLabel.Parent = container

	-- Power bar background
	local powerBarBg = Instance.new("Frame")
	powerBarBg.Name = "PowerBarBg"
	powerBarBg.Size = UDim2.new(0, 320, 0, 40)
	powerBarBg.Position = UDim2.new(0.5, -160, 0, 35)
	powerBarBg.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	powerBarBg.BorderSizePixel = 0
	powerBarBg.Parent = container

	local bgCorner = Instance.new("UICorner")
	bgCorner.CornerRadius = UDim.new(0, 8)
	bgCorner.Parent = powerBarBg

	-- Power bar segments container
	_PowerFrame = Instance.new("Frame")
	_PowerFrame.Name = "PowerFrame"
	_PowerFrame.Size = UDim2.new(1, -16, 1, -16)
	_PowerFrame.Position = UDim2.new(0, 8, 0, 8)
	_PowerFrame.BackgroundTransparency = 1
	_PowerFrame.Parent = powerBarBg

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = _PowerFrame

	-- Create segments
	local segmentWidth = (320 - 16 - (POWER_BAR_SEGMENTS - 1) * 4) / POWER_BAR_SEGMENTS
	for i = 1, POWER_BAR_SEGMENTS do
		local segment = Instance.new("Frame")
		segment.Name = "Segment" .. i
		segment.LayoutOrder = i -- Ensure correct ordering in UIListLayout
		segment.Size = UDim2.new(0, segmentWidth, 1, 0)
		segment.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
		segment.BorderSizePixel = 0
		segment.Parent = _PowerFrame

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 4)
		corner.Parent = segment

		_PowerSegments[i] = segment
	end

	-- Q/E buttons
	local qButton = Instance.new("TextLabel")
	qButton.Name = "QButton"
	qButton.Size = UDim2.new(0, 40, 0, 40)
	qButton.Position = UDim2.new(0.5, -200, 0, 35)
	qButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	qButton.Font = Enum.Font.GothamBold
	qButton.TextSize = 24
	qButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	qButton.Text = "Q"
	qButton.Parent = container

	local qCorner = Instance.new("UICorner")
	qCorner.CornerRadius = UDim.new(0, 8)
	qCorner.Parent = qButton

	local eButton = Instance.new("TextLabel")
	eButton.Name = "EButton"
	eButton.Size = UDim2.new(0, 40, 0, 40)
	eButton.Position = UDim2.new(0.5, 160, 0, 35)
	eButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	eButton.Font = Enum.Font.GothamBold
	eButton.TextSize = 24
	eButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	eButton.Text = "E"
	eButton.Parent = container

	local eCorner = Instance.new("UICorner")
	eCorner.CornerRadius = UDim.new(0, 8)
	eCorner.Parent = eButton

	-- Instructions
	_InstructionsLabel = Instance.new("TextLabel")
	_InstructionsLabel.Name = "Instructions"
	_InstructionsLabel.Size = UDim2.new(1, 0, 0, 20)
	_InstructionsLabel.Position = UDim2.new(0, 0, 0, 80)
	_InstructionsLabel.BackgroundTransparency = 1
	_InstructionsLabel.Font = Enum.Font.Gotham
	_InstructionsLabel.TextSize = 14
	_InstructionsLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	_InstructionsLabel.Text = "Drag or A/D to rotate • Q/E to adjust power"
	_InstructionsLabel.Parent = container
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

	CreateUI()
	_ScreenGui.Enabled = true

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
	print("[AimUI] Initializing...")

	-- Pre-create the UI
	CreateUI()

	-- Listen for round state changes
	task.defer(function()
		task.wait(1) -- Wait for DataStream

		local roundState = ClientDataStream.RoundState
		if roundState then
			roundState.State:Changed(function(newState, oldState)
				if newState == "Aiming" then
					Show()
				elseif oldState == "Aiming" then
					Hide()
				end
			end)

			-- Check current state
			if roundState.State:Read() == "Aiming" then
				Show()
			end
		end
	end)
end

-- Return Module --
return AimUI
