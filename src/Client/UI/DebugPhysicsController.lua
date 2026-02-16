--[[
	DebugPhysicsController.lua

	Description:
		Debug UI for tweaking physics values at runtime.
		Toggle with semicolon key (;).
--]]

-- Root --
local DebugPhysicsController = {}

-- Roblox Services --
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

-- Dependencies --
local ClientDataStream = shared("ClientDataStream")
local GetRemoteEvent = shared("GetRemoteEvent")

-- Remote Events --
local UpdateDebugPhysicsRemoteEvent = GetRemoteEvent("UpdateDebugPhysics")
local ForceEndRoundRemoteEvent = GetRemoteEvent("ForceEndRound")

-- Object References --
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Constants --
local TOGGLE_KEY = Enum.KeyCode.Semicolon

local PHYSICS_SETTINGS = {
	{ Key = "LAUNCH_FORCE_MULTIPLIER", Label = "Launch Force", Min = 1, Max = 20, Default = 6 },
	{ Key = "SLIPPERY_FRICTION", Label = "Slippery Friction", Min = 0, Max = 2, Default = 0.05 },
	{ Key = "SLIPPERY_ELASTICITY", Label = "Slippery Elasticity", Min = 0, Max = 1, Default = 0.3 },
	{ Key = "CURLING_MIN_SPEED", Label = "Curling Min Speed", Min = 0.1, Max = 2, Default = 0.3 },
	{ Key = "COLLISION_COOLDOWN", Label = "Collision Cooldown", Min = 0, Max = 1, Default = 0.15 },
	{ Key = "COLLISION_MIN_SPEED", Label = "Collision Min Speed", Min = 0, Max = 5, Default = 1.0 },
	{ Key = "CURLING_COLLISION_RESTITUTION", Label = "Collision Restitution", Min = 0, Max = 1, Default = 0.6 },
	{ Key = "PHYSICS_BOX_SIZE_X", Label = "Box Size X", Min = 1, Max = 10, Default = 3.5 },
	{ Key = "PHYSICS_BOX_SIZE_Y", Label = "Box Size Y", Min = 1, Max = 10, Default = 5 },
	{ Key = "PHYSICS_BOX_SIZE_Z", Label = "Box Size Z", Min = 1, Max = 10, Default = 3.5 },
	{ Key = "PHYSICS_BOX_DENSITY", Label = "Box Density", Min = 1, Max = 100, Default = 25 },
	{ Key = "PHYSICS_BOX_FRICTION", Label = "Box Friction", Min = 0, Max = 2, Default = 0.05 },
	{ Key = "PHYSICS_BOX_ELASTICITY", Label = "Box Elasticity", Min = 0, Max = 1, Default = 0.4 },
}

-- Private Variables --
local _ScreenGui = nil
local _MainFrame = nil
local _Sliders = {}
local _IsVisible = false

-- Internal Functions --
local function CreateScreenGui()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "DebugPhysicsWindow"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 100
	screenGui.Enabled = false
	screenGui.Parent = PlayerGui
	return screenGui
end

local function CreateMainFrame(parent)
	local frame = Instance.new("Frame")
	frame.Name = "MainFrame"
	frame.Size = UDim2.new(0, 320, 0, 500)
	frame.Position = UDim2.new(1, -340, 0.5, -250)
	frame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
	frame.BorderSizePixel = 0
	frame.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(60, 60, 70)
	stroke.Thickness = 2
	stroke.Parent = frame

	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 40)
	title.BackgroundTransparency = 1
	title.Text = "Debug Physics"
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextSize = 18
	title.Font = Enum.Font.GothamBold
	title.Parent = frame

	-- Scrolling Frame
	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Name = "ScrollFrame"
	scrollFrame.Size = UDim2.new(1, -20, 1, -140)
	scrollFrame.Position = UDim2.new(0, 10, 0, 45)
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.ScrollBarThickness = 6
	scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 110)
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, #PHYSICS_SETTINGS * 60)
	scrollFrame.Parent = frame

	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 5)
	listLayout.Parent = scrollFrame

	-- Force End Round Button
	local forceEndButton = Instance.new("TextButton")
	forceEndButton.Name = "ForceEndButton"
	forceEndButton.Size = UDim2.new(1, -20, 0, 35)
	forceEndButton.Position = UDim2.new(0, 10, 1, -85)
	forceEndButton.BackgroundColor3 = Color3.fromRGB(200, 120, 60)
	forceEndButton.Text = "Force End Round"
	forceEndButton.TextColor3 = Color3.new(1, 1, 1)
	forceEndButton.TextSize = 14
	forceEndButton.Font = Enum.Font.GothamBold
	forceEndButton.Parent = frame

	local forceEndCorner = Instance.new("UICorner")
	forceEndCorner.CornerRadius = UDim.new(0, 6)
	forceEndCorner.Parent = forceEndButton

	-- Reset Button
	local resetButton = Instance.new("TextButton")
	resetButton.Name = "ResetButton"
	resetButton.Size = UDim2.new(1, -20, 0, 35)
	resetButton.Position = UDim2.new(0, 10, 1, -45)
	resetButton.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
	resetButton.Text = "Reset to Defaults"
	resetButton.TextColor3 = Color3.new(1, 1, 1)
	resetButton.TextSize = 14
	resetButton.Font = Enum.Font.GothamBold
	resetButton.Parent = frame

	local resetCorner = Instance.new("UICorner")
	resetCorner.CornerRadius = UDim.new(0, 6)
	resetCorner.Parent = resetButton

	return frame, scrollFrame, resetButton, forceEndButton
end

local function CreateSliderRow(parent, setting, index)
	local row = Instance.new("Frame")
	row.Name = setting.Key
	row.Size = UDim2.new(1, -10, 0, 55)
	row.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
	row.LayoutOrder = index
	row.Parent = parent

	local rowCorner = Instance.new("UICorner")
	rowCorner.CornerRadius = UDim.new(0, 4)
	rowCorner.Parent = row

	-- Label
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.new(1, -10, 0, 20)
	label.Position = UDim2.new(0, 5, 0, 2)
	label.BackgroundTransparency = 1
	label.Text = setting.Label
	label.TextColor3 = Color3.fromRGB(200, 200, 200)
	label.TextSize = 12
	label.Font = Enum.Font.Gotham
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = row

	-- Slider Background
	local sliderBg = Instance.new("Frame")
	sliderBg.Name = "SliderBg"
	sliderBg.Size = UDim2.new(1, -70, 0, 16)
	sliderBg.Position = UDim2.new(0, 5, 0, 24)
	sliderBg.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
	sliderBg.Parent = row

	local sliderBgCorner = Instance.new("UICorner")
	sliderBgCorner.CornerRadius = UDim.new(0, 4)
	sliderBgCorner.Parent = sliderBg

	-- Slider Fill
	local sliderFill = Instance.new("Frame")
	sliderFill.Name = "Fill"
	sliderFill.Size = UDim2.new(0.5, 0, 1, 0)
	sliderFill.BackgroundColor3 = Color3.fromRGB(80, 160, 255)
	sliderFill.Parent = sliderBg

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 4)
	fillCorner.Parent = sliderFill

	-- Value Input
	local valueBox = Instance.new("TextBox")
	valueBox.Name = "ValueBox"
	valueBox.Size = UDim2.new(0, 55, 0, 20)
	valueBox.Position = UDim2.new(1, -60, 0, 22)
	valueBox.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
	valueBox.Text = tostring(setting.Default)
	valueBox.TextColor3 = Color3.new(1, 1, 1)
	valueBox.TextSize = 12
	valueBox.Font = Enum.Font.GothamMedium
	valueBox.ClearTextOnFocus = false
	valueBox.Parent = row

	local valueCorner = Instance.new("UICorner")
	valueCorner.CornerRadius = UDim.new(0, 4)
	valueCorner.Parent = valueBox

	return {
		Row = row,
		SliderBg = sliderBg,
		Fill = sliderFill,
		ValueBox = valueBox,
		Setting = setting,
	}
end

local function UpdateSliderVisual(slider, value)
	local setting = slider.Setting
	local normalized = (value - setting.Min) / (setting.Max - setting.Min)
	normalized = math.clamp(normalized, 0, 1)
	slider.Fill.Size = UDim2.new(normalized, 0, 1, 0)
	slider.ValueBox.Text = string.format("%.2f", value)
end

local function GetValueFromPosition(slider, posX)
	local setting = slider.Setting
	local normalized = math.clamp(posX, 0, 1)
	return setting.Min + (setting.Max - setting.Min) * normalized
end

local function SetupSliderInteraction(slider)
	local dragging = false

	local function UpdateFromMouse()
		local mousePos = UserInputService:GetMouseLocation()
		local sliderPos = slider.SliderBg.AbsolutePosition
		local sliderSize = slider.SliderBg.AbsoluteSize
		local relativeX = (mousePos.X - sliderPos.X) / sliderSize.X
		local value = GetValueFromPosition(slider, relativeX)
		UpdateSliderVisual(slider, value)
		UpdateDebugPhysicsRemoteEvent:FireServer(slider.Setting.Key, value)
	end

	slider.SliderBg.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			UpdateFromMouse()
		end
	end)

	slider.SliderBg.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			UpdateFromMouse()
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)

	slider.ValueBox.FocusLost:Connect(function()
		local value = tonumber(slider.ValueBox.Text)
		if value then
			value = math.clamp(value, slider.Setting.Min, slider.Setting.Max)
			UpdateSliderVisual(slider, value)
			UpdateDebugPhysicsRemoteEvent:FireServer(slider.Setting.Key, value)
		else
			-- Revert to current value
			local debugPhysics = ClientDataStream.DebugPhysics
			if debugPhysics then
				local current = debugPhysics[slider.Setting.Key]:Read()
				UpdateSliderVisual(slider, current or slider.Setting.Default)
			end
		end
	end)
end

local function ResetToDefaults()
	for _, slider in pairs(_Sliders) do
		local defaultValue = slider.Setting.Default
		UpdateSliderVisual(slider, defaultValue)
		UpdateDebugPhysicsRemoteEvent:FireServer(slider.Setting.Key, defaultValue)
	end
end

local function SyncFromDataStream()
	local debugPhysics = ClientDataStream.DebugPhysics
	if not debugPhysics then return end

	for _, slider in pairs(_Sliders) do
		local value = debugPhysics[slider.Setting.Key]:Read()
		if value then
			UpdateSliderVisual(slider, value)
		end
	end
end

local function ToggleVisibility()
	_IsVisible = not _IsVisible
	_ScreenGui.Enabled = _IsVisible

	if _IsVisible then
		SyncFromDataStream()
	end
end

local function SetupKeyToggle()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode == TOGGLE_KEY then
			ToggleVisibility()
		end
	end)
end

-- Initializers --
function DebugPhysicsController:Init()
	_ScreenGui = CreateScreenGui()
	local mainFrame, scrollFrame, resetButton, forceEndButton = CreateMainFrame(_ScreenGui)
	_MainFrame = mainFrame

	for i, setting in ipairs(PHYSICS_SETTINGS) do
		local slider = CreateSliderRow(scrollFrame, setting, i)
		_Sliders[setting.Key] = slider
		SetupSliderInteraction(slider)
	end

	resetButton.MouseButton1Click:Connect(ResetToDefaults)
	forceEndButton.MouseButton1Click:Connect(function()
		ForceEndRoundRemoteEvent:FireServer()
	end)
	SetupKeyToggle()

	-- Sync when DataStream values change
	task.defer(function()
		local debugPhysics = ClientDataStream.DebugPhysics
		if debugPhysics then
			for _, setting in ipairs(PHYSICS_SETTINGS) do
				debugPhysics[setting.Key]:Changed(function(newValue)
					if _Sliders[setting.Key] then
						UpdateSliderVisual(_Sliders[setting.Key], newValue)
					end
				end)
			end
		end
	end)
end

-- Return Module --
return DebugPhysicsController
