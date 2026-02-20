--[[
	UIController.lua

	Description:
		Manages window opening/closing with scale animations.
		Windows should have a MainFrame with UIScale and CloseButton.
--]]

-- Root --
local UIController = {}

-- Roblox Services --
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

-- Dependencies --
local RoundConfig = shared("RoundConfig")
local SoundController = shared("SoundController")

-- Object References --
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Constants --
local TWEEN_INFO_OPEN = TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local TWEEN_INFO_CLOSE = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local TWEEN_INFO_BLUR = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local BLUR_SIZE = 10

-- Private Variables --
local _OpenWindows = {} -- windowName -> true
local _WindowConfigs = {} -- windowName -> { ScreenGui, MainFrame, UIScale, CloseButton }
local _BlurEffect = nil
local _HUDScreenGui = nil
local _PendingCallbacks = {} -- windowName -> { callback1, callback2, ... }
local _ChildAddedConnection = nil

-- Internal Functions --

local function DebugLog(...)
	if RoundConfig.DEBUG_LOG_STATE_CHANGES then
		print("[UIController]", ...)
	end
end

-- Gets or creates the blur effect
local function GetOrCreateBlur()
	if _BlurEffect then
		return _BlurEffect
	end

	_BlurEffect = Instance.new("BlurEffect")
	_BlurEffect.Name = "UIControllerBlur"
	_BlurEffect.Size = 0
	_BlurEffect.Parent = Lighting

	return _BlurEffect
end

-- Gets the HUD ScreenGui reference
local function GetHUDScreenGui()
	if _HUDScreenGui then
		return _HUDScreenGui
	end
	_HUDScreenGui = PlayerGui:FindFirstChild("HUD")
	return _HUDScreenGui
end

-- Returns true if any window is open
local function AnyWindowOpen()
	for _ in pairs(_OpenWindows) do
		return true
	end
	return false
end

-- Shows blur and hides HUD
local function ShowOverlayEffects()
	-- Hide HUD
	local hud = GetHUDScreenGui()
	if hud then
		hud.Enabled = false
	end

	-- Show blur
	local blur = GetOrCreateBlur()
	local tween = TweenService:Create(blur, TWEEN_INFO_BLUR, { Size = BLUR_SIZE })
	tween:Play()
end

-- Hides blur and shows HUD
local function HideOverlayEffects()
	-- Show HUD
	local hud = GetHUDScreenGui()
	if hud then
		hud.Enabled = true
	end

	-- Hide blur
	local blur = GetOrCreateBlur()
	local tween = TweenService:Create(blur, TWEEN_INFO_BLUR, { Size = 0 })
	tween:Play()
end

local function SetupWindow(windowName)
	local screenGui = PlayerGui:FindFirstChild(windowName)
	if not screenGui then
		return nil
	end

	local mainFrame = screenGui:FindFirstChild("MainFrame")
	if not mainFrame then
		return nil
	end

	local uiScale = mainFrame:FindFirstChild("UIScale")
	local closeButton = mainFrame:FindFirstChild("CloseButton", true)

	-- Initialize scale to 0 (closed)
	if uiScale then
		uiScale.Scale = 0
	end
	screenGui.Enabled = false

	-- Setup close button
	if closeButton then
		closeButton.MouseEnter:Connect(function()
			SoundController:PlaySound("SFX", "MouseHover")
		end)

		closeButton.MouseButton1Click:Connect(function()
			SoundController:PlaySound("SFX", "MouseClick")
			UIController:CloseWindow(windowName)
		end)
	end

	_WindowConfigs[windowName] = {
		ScreenGui = screenGui,
		MainFrame = mainFrame,
		UIScale = uiScale,
		CloseButton = closeButton,
	}

	DebugLog("Window setup complete:", windowName)
	return _WindowConfigs[windowName]
end

-- Sets up the ChildAdded listener (only once)
local function EnsureChildAddedListener()
	if _ChildAddedConnection then
		return
	end

	_ChildAddedConnection = PlayerGui.ChildAdded:Connect(function(child)
		local callbacks = _PendingCallbacks[child.Name]
		if callbacks then
			_PendingCallbacks[child.Name] = nil
			for _, callback in ipairs(callbacks) do
				task.spawn(callback, child)
			end
		end
	end)
end

-- API Functions --

function UIController:WhenScreenGuiReady(windowName, callback)
	-- Try to find immediately
	local screenGui = PlayerGui:FindFirstChild(windowName)
	if screenGui then
		task.spawn(callback, screenGui)
		return
	end

	-- Queue callback for when child is added
	if not _PendingCallbacks[windowName] then
		_PendingCallbacks[windowName] = {}
	end
	table.insert(_PendingCallbacks[windowName], callback)

	EnsureChildAddedListener()
end

function UIController:OpenWindow(windowName)
	-- Get or setup window config
	local config = _WindowConfigs[windowName] or SetupWindow(windowName)
	if not config then
		warn("[UIController] Window not found:", windowName)
		return false
	end

	-- Already open?
	if _OpenWindows[windowName] then
		return true
	end

	DebugLog("Opening window:", windowName)

	-- Show overlay effects if this is the first window
	if not AnyWindowOpen() then
		ShowOverlayEffects()
	end

	-- Enable and animate in
	config.ScreenGui.Enabled = true
	_OpenWindows[windowName] = true

	if config.UIScale then
		config.UIScale.Scale = 0
		local tween = TweenService:Create(config.UIScale, TWEEN_INFO_OPEN, { Scale = 1 })
		tween:Play()
	end

	return true
end

function UIController:CloseWindow(windowName)
	local config = _WindowConfigs[windowName]
	if not config then
		return false
	end

	-- Not open?
	if not _OpenWindows[windowName] then
		return true
	end

	DebugLog("Closing window:", windowName)

	_OpenWindows[windowName] = nil

	-- Hide overlay effects if this was the last window
	if not AnyWindowOpen() then
		HideOverlayEffects()
	end

	if config.UIScale then
		local tween = TweenService:Create(config.UIScale, TWEEN_INFO_CLOSE, { Scale = 0 })
		tween:Play()
		local connection
		connection = tween.Completed:Connect(function()
			connection:Disconnect()
			config.ScreenGui.Enabled = false
		end)
	else
		config.ScreenGui.Enabled = false
	end

	return true
end

function UIController:IsWindowOpen(windowName)
	return _OpenWindows[windowName] == true
end

function UIController:ToggleWindow(windowName)
	if self:IsWindowOpen(windowName) then
		return self:CloseWindow(windowName)
	else
		return self:OpenWindow(windowName)
	end
end

function UIController:CloseAllWindows()
	for windowName in pairs(_OpenWindows) do
		self:CloseWindow(windowName)
	end
end

function UIController:ShowOverlay()
	ShowOverlayEffects()
end

function UIController:HideOverlay()
	HideOverlayEffects()
end

-- Initializers --
function UIController:Init()
	DebugLog("Initializing...")
	-- Pre-setup known windows
	SetupWindow("SkinsWindow")
	SetupWindow("IndexWindow")
	SetupWindow("RankWindow")
	SetupWindow("SkinShopWindow")
	SetupWindow("PrizeWheelWindow")
	SetupWindow("QuestsWindow")
end

-- Return Module --
return UIController
