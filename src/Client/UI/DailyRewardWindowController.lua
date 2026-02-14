--[[
	DailyRewardWindowController.lua

	Description:
		Manages the DailyRewardWindow UI.
		Displays 7 days of rewards with claim button and countdown timer.
		Day 7 features a special skin reward that rotates each cycle.
--]]

-- Root --
local DailyRewardWindowController = {}

-- Roblox Services --
local RunService = game:GetService("RunService")

-- Dependencies --
local UIController = shared("UIController")
local DailyRewardConfig = shared("DailyRewardConfig")
local SkinsConfig = shared("SkinsConfig")
local GetRemoteEvent = shared("GetRemoteEvent")
local GetRemoteFunction = shared("GetRemoteFunction")

-- Object References --
local SkinsFolder = nil

-- Remote Events/Functions --
local GetDailyRewardStatusRemote = GetRemoteFunction("GetDailyRewardStatus")
local ClaimDailyRewardRemote = GetRemoteEvent("ClaimDailyReward")
local DailyRewardClaimedRemote = GetRemoteEvent("DailyRewardClaimed")

-- Constants --
local TOTAL_DAYS = 7

-- Private Variables --
local _ScreenGui = nil
local _MainFrame = nil
local _Timer = nil
local _DayFrames = {} -- { [dayNumber] = frame }
local _IsSetup = false
local _CurrentStatus = nil
local _TimerConnection = nil

-- Internal Functions --

-- Sets up the icon and amount for a day frame based on reward type
local function SetupDayIcon(frame, dayNumber, status)
	local icon = frame:FindFirstChild("Icon")
	local amountLabel = frame:FindFirstChild("Amount")

	local rewardData = DailyRewardConfig.Days[dayNumber]
	if not rewardData then
		return
	end

	-- Set amount label with "x" prefix
	if amountLabel then
		if rewardData.Amount then
			amountLabel.Text = "x" .. rewardData.Amount
			amountLabel.Visible = true
		else
			-- Skin rewards don't have an amount
			amountLabel.Text = ""
			amountLabel.Visible = false
		end
	end

	-- Set icon
	if not icon then
		return
	end

	if rewardData.Type == "Coins" or rewardData.Type == "Spins" then
		-- For Coins/Spins: Set image on ImageLabel
		if icon:IsA("ImageLabel") then
			local iconId = DailyRewardConfig.Icons[rewardData.Type]
			if iconId then
				icon.Image = iconId
			end
		end
	elseif rewardData.Type == "Skin" then
		local skinId = status and status.Day7SkinId
		local mutation = status and status.Day7Mutation or "Normal"

		if icon:IsA("ImageLabel") and skinId then
			-- Use skin's icon from config
			local skinConfig = SkinsConfig.Skins[skinId]
			if skinConfig and skinConfig.Icon then
				icon.Image = skinConfig.Icon
			end
		end
	end
end

-- Formats seconds into HH:MM:SS
local function FormatTime(seconds)
	seconds = math.max(0, math.floor(seconds))
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	local secs = seconds % 60
	return string.format("%02d:%02d:%02d", hours, minutes, secs)
end

-- Updates a single day frame's visual state
local function UpdateDayFrame(dayNumber, status)
	local frame = _DayFrames[dayNumber]
	if not frame then
		return
	end

	local statusButton = frame:FindFirstChild("StatusButton")
	local skinName = frame:FindFirstChild("SkinName") -- Only on Day 7

	-- Set up icon based on reward type
	SetupDayIcon(frame, dayNumber, status)

	local currentDay = status and status.CurrentDay or 1
	local canClaim = status and status.CanClaim or false

	-- Determine state: Claimed, Available, Countdown, or Locked
	local state = "Locked"
	if dayNumber < currentDay then
		state = "Claimed"
	elseif dayNumber == currentDay then
		state = canClaim and "Available" or "Countdown"
	end

	-- Update StatusButton appearance based on state
	if statusButton then
		if state == "Claimed" then
			statusButton.TextLabel.Text = "Claimed"
			statusButton.ImageColor3 = Color3.fromRGB(60, 60, 60)
			statusButton.Active = false
		elseif state == "Available" then
			statusButton.TextLabel.Text = "Claim!"
			statusButton.ImageColor3 = Color3.fromRGB(255, 255, 255)
			statusButton.Active = true
		elseif state == "Countdown" then
			statusButton.TextLabel.Text = "Next Reward"
			statusButton.ImageColor3 = Color3.fromRGB(200, 150, 50)
			statusButton.Active = false
		else -- Locked
			statusButton.TextLabel.Text = "Locked"
			statusButton.ImageColor3 = Color3.fromRGB(55, 55, 55)
			statusButton.Active = false
		end
	end

	-- Update Day 7 skin name if applicable
	if dayNumber == 7 and skinName and status then
		skinName.Text = status.Day7SkinName or "Special Skin"
	end

	-- Visual feedback for frame (dim locked/claimed, highlight available)
	if state == "Available" then
		frame.BackgroundTransparency = 0
	elseif state == "Claimed" then
		frame.BackgroundTransparency = 0.5
	else
		frame.BackgroundTransparency = 0.3
	end
end

-- Updates all day frames
local function UpdateAllDayFrames(status)
	for dayNumber = 1, TOTAL_DAYS do
		UpdateDayFrame(dayNumber, status)
	end
end

-- Updates the timer display
local function UpdateTimer(status)
	if not _Timer then
		return
	end

	if not status or status.CanClaim then
		_Timer.Text = "Reward ready!"
	else
		local timeRemaining = status.TimeUntilClaim or 0
		_Timer.Text = "Next reward in: " .. FormatTime(timeRemaining)
	end
end

-- Starts the timer update loop
local function StartTimerLoop()
	if _TimerConnection then
		_TimerConnection:Disconnect()
	end

	local lastUpdate = 0

	_TimerConnection = RunService.Heartbeat:Connect(function()
		-- Update once per second
		local now = tick()
		if now - lastUpdate < 1 then
			return
		end
		lastUpdate = now

		if not _CurrentStatus or _CurrentStatus.CanClaim then
			UpdateTimer(_CurrentStatus)
			return
		end

		-- Decrement time locally
		_CurrentStatus.TimeUntilClaim = math.max(0, (_CurrentStatus.TimeUntilClaim or 0) - 1)

		-- Check if timer reached zero
		if _CurrentStatus.TimeUntilClaim <= 0 then
			_CurrentStatus.CanClaim = true
			UpdateAllDayFrames(_CurrentStatus)
		end

		UpdateTimer(_CurrentStatus)
	end)
end

-- Requests status from server and updates UI
local function RefreshStatus()
	local status = GetDailyRewardStatusRemote:InvokeServer()
	if status then
		_CurrentStatus = status
		UpdateAllDayFrames(status)
		UpdateTimer(status)
	end
end

-- Handles claim button click
local function OnClaimClicked()
	if not _CurrentStatus or not _CurrentStatus.CanClaim then
		return
	end

	-- Disable claiming while processing
	_CurrentStatus.CanClaim = false
	UpdateAllDayFrames(_CurrentStatus)

	-- Send claim request to server
	ClaimDailyRewardRemote:FireServer()
end

-- Handles claim result from server
local function OnClaimResult(result)
	if result.Success then
		print("[DailyRewardWindowController] Claimed reward:", result.Reward and result.Reward.Type or "unknown")
	else
		warn("[DailyRewardWindowController] Claim failed:", result.Error)
	end

	-- Update with new status from server
	if result.Status then
		_CurrentStatus = result.Status
		UpdateAllDayFrames(_CurrentStatus)
		UpdateTimer(_CurrentStatus)
	else
		-- Fallback: request fresh status
		RefreshStatus()
	end
end

-- Sets up day frame references and handlers
local function SetupDayFrames()
	local _InnerFrame = _MainFrame:WaitForChild("InnerFrame")

	for dayNumber = 1, TOTAL_DAYS do
		local frameName = "Day" .. dayNumber
		local frame = _InnerFrame:FindFirstChild(frameName)

		if frame then
			_DayFrames[dayNumber] = frame

			-- Setup claim button handler
			local statusButton = frame:FindFirstChild("StatusButton")
			if statusButton then
				statusButton.MouseButton1Click:Connect(function()
					if dayNumber == (_CurrentStatus and _CurrentStatus.CurrentDay) then
						OnClaimClicked()
					end
				end)
			end
		else
			warn("[DailyRewardWindowController] Day frame not found:", frameName)
		end
	end
end

-- Sets up UI references
local function SetupUI(screenGui)
	if _IsSetup then
		return
	end

	_ScreenGui = screenGui
	_MainFrame = _ScreenGui:WaitForChild("MainFrame")
	_Timer = _MainFrame:FindFirstChild("Timer")

	SetupDayFrames()

	-- Listen for claim results
	DailyRewardClaimedRemote.OnClientEvent:Connect(OnClaimResult)

	-- Start timer loop
	StartTimerLoop()

	-- Initial status fetch
	RefreshStatus()

	_IsSetup = true
	print("[DailyRewardWindowController] UI setup complete")
end

-- API Functions --

-- Refreshes the UI with latest status from server
function DailyRewardWindowController:Refresh()
	RefreshStatus()
end

-- Returns current status
function DailyRewardWindowController:GetStatus()
	return _CurrentStatus
end

-- Initializers --
function DailyRewardWindowController:Init()
	print("[DailyRewardWindowController] Initializing...")

	UIController:WhenScreenGuiReady("DailyRewardWindow", function(screenGui)
		SetupUI(screenGui)
	end)
end

-- Return Module --
return DailyRewardWindowController
