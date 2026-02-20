--[[
	QuestController.lua

	Description:
		Handles quest networking/state and QuestsWindow UI behavior.
--]]

-- Root --
local QuestController = {}

-- Roblox Services --
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- Dependencies --
local UIController = shared("UIController")
local SoundController = shared("SoundController")
local QuestsConfig = shared("QuestsConfig")
local Signal = shared("Signal")
local GetRemoteEvent = shared("GetRemoteEvent")
local GetRemoteFunction = shared("GetRemoteFunction")
local OnLocalPlayerStoredDataStreamLoaded = shared("OnLocalPlayerStoredDataStreamLoaded")

-- Remotes --
local GetQuestStatusRemote = GetRemoteFunction("GetQuestStatus")
local ClaimQuestRewardRemote = GetRemoteEvent("ClaimQuestReward")
local QuestStatusUpdatedRemote = GetRemoteEvent("QuestStatusUpdated")

-- Public Variables --
QuestController.StatusUpdated = Signal.new()

-- Private Variables --
local _Status = nil
local _IsSetup = false
local _ScreenGui = nil
local _MainFrame = nil
local _Content = nil
local _Template = nil
local _TopTabs = nil
local _DailyTab = nil
local _WeeklyTab = nil
local _ResetTime = nil
local _SelectedTab = "Daily"
local _TimerConnection = nil
local _CachedQuestNotification = nil
local _HasClaimableQuest = false

local LocalPlayer = Players.LocalPlayer

-- Internal Functions --
local function _GetQuestNotification()
	if _CachedQuestNotification and _CachedQuestNotification.Parent then
		return _CachedQuestNotification
	end

	local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
	if not playerGui then
		return nil
	end

	local hud = playerGui:FindFirstChild("HUD")
	if not hud then
		return nil
	end

	local leftFrame = hud:FindFirstChild("LeftFrame")
	local buttonGrid = leftFrame and leftFrame:FindFirstChild("ButtonGrid")
	local questsButton = buttonGrid and buttonGrid:FindFirstChild("QuestsButton")
	local notification = questsButton and questsButton:FindFirstChild("Notification")

	if notification and notification:IsA("GuiObject") then
		_CachedQuestNotification = notification
		return notification
	end

	return nil
end

local function _AnyClaimableQuest(status)
	if not status or type(status.Quests) ~= "table" then
		return false
	end

	for _, quest in ipairs(status.Quests) do
		if quest.IsComplete == true and quest.IsClaimed ~= true then
			return true
		end
	end

	return false
end

local function _UpdateQuestNotification()
	local notification = _GetQuestNotification()
	if not notification then
		return
	end

	local isWindowOpen = _ScreenGui and _ScreenGui.Enabled == true
	notification.Visible = _HasClaimableQuest and not isWindowOpen
end

local function _GetTextLabel(guiObject)
	if not guiObject then
		return nil
	end

	if guiObject:IsA("TextLabel") or guiObject:IsA("TextButton") then
		return guiObject
	end

	return guiObject:FindFirstChild("TextLabel", true)
end

local function _SetLabelText(guiObject, text)
	local label = _GetTextLabel(guiObject)
	if label then
		label.Text = text
	end
end

local function _FormatTime(seconds)
	local remaining = math.max(0, math.floor(seconds))
	local hours = math.floor(remaining / 3600)
	local minutes = math.floor((remaining % 3600) / 60)
	local secs = remaining % 60
	return string.format("%02d:%02d:%02d", hours, minutes, secs)
end

local function _IsQuestInSelectedTab(quest)
	if _SelectedTab == "Daily" then
		return quest.IsDaily == true
	end
	return quest.IsWeekly == true
end

local function _GetResetSecondsForCurrentTab()
	if _SelectedTab == "Daily" then
		return QuestsConfig.DAILY_RESET_SECONDS or (24 * 60 * 60)
	end
	return QuestsConfig.WEEKLY_RESET_SECONDS or (7 * 24 * 60 * 60)
end

local function _GetLastResetForCurrentTab(status)
	if _SelectedTab == "Daily" then
		return tonumber(status.LastDailyReset) or 0
	end
	return tonumber(status.LastWeeklyReset) or 0
end

local function _GetRewardIcon(reward)
	if type(reward) ~= "table" then
		return ""
	end

	if type(reward.Icon) == "string" then
		return reward.Icon
	end

	return ""
end

local function _GetRewardAmountText(reward)
	if type(reward) ~= "table" then
		return ""
	end

	if type(reward.Amount) == "number" then
		return tostring(reward.Amount)
	end

	return ""
end

local function _UpdateTopTabVisuals()
	if _DailyTab then
		_DailyTab.Background.BackgroundColor3 = (_SelectedTab == "Daily") and Color3.fromRGB(255, 255, 255)
			or Color3.fromRGB(150, 150, 150)
	end
	if _WeeklyTab then
		_WeeklyTab.Background.BackgroundColor3 = (_SelectedTab == "Weekly") and Color3.fromRGB(255, 255, 255)
			or Color3.fromRGB(150, 150, 150)
	end
end

local function _UpdateResetTimeText()
	if not _ResetTime then
		return
	end

	if not _Status then
		_SetLabelText(_ResetTime, "Resets in 00:00:00")
		return
	end

	local resetSeconds = _GetResetSecondsForCurrentTab()
	local lastReset = _GetLastResetForCurrentTab(_Status)
	local elapsed = os.time() - lastReset
	_SetLabelText(_ResetTime, "Resets in " .. _FormatTime(resetSeconds - elapsed))
end

local function _ClearQuestEntries()
	if not _Content then
		return
	end

	for _, child in ipairs(_Content:GetChildren()) do
		if child ~= _Template and string.sub(child.Name, 1, 6) == "Quest_" then
			child:Destroy()
		end
	end
end

local function _PopulateQuestEntries()
	if not _Content or not _Template or not _Status or type(_Status.Quests) ~= "table" then
		return
	end

	_ClearQuestEntries()

	local layoutOrder = 0
	for _, quest in ipairs(_Status.Quests) do
		if _IsQuestInSelectedTab(quest) then
			layoutOrder += 1

			local card = _Template:Clone()
			card.Name = "Quest_" .. tostring(quest.Id)
			card.Visible = true
			card.LayoutOrder = layoutOrder

			local titleLabel = card:FindFirstChild("TitleLabel", true)
			if titleLabel and titleLabel:IsA("TextLabel") then
				titleLabel.Text = quest.DisplayName or tostring(quest.Id)
			end

			local progressFrame = card:FindFirstChild("Progress", true)
			local progressLabel = progressFrame and progressFrame:FindFirstChild("TextLabel")
			local progressBar = progressFrame and progressFrame:FindFirstChild("Bar")
			local goal = math.max(1, tonumber(quest.Goal) or 1)
			local current = math.max(0, tonumber(quest.Progress) or 0)
			local alpha = math.clamp(current / goal, 0, 1)

			if progressLabel and progressLabel:IsA("TextLabel") then
				progressLabel.Text = string.format("%d / %d", current, goal)
			end

			if progressBar then
				progressBar.Size = UDim2.new(alpha, 0, 1, 0)
			end

			local rewardFrame = card:FindFirstChild("Reward", true)
			local rewardIcon = rewardFrame and rewardFrame:FindFirstChild("PreviewIcon")
			local rewardText = rewardFrame and rewardFrame:FindFirstChild("TextLabel")

			if rewardIcon and rewardIcon:IsA("ImageLabel") then
				rewardIcon.Image = _GetRewardIcon(quest.Reward)
			end
			if rewardText and rewardText:IsA("TextLabel") then
				rewardText.Text = _GetRewardAmountText(quest.Reward)
			end

			local claimButton = card:FindFirstChild("ClaimButton", true)
			local isClaimable = quest.IsComplete == true and quest.IsClaimed ~= true
			local isClaimed = quest.IsClaimed == true

			if claimButton and claimButton:IsA("GuiButton") then
				if not isClaimed and not isClaimable then
					_SetLabelText(claimButton.TextLabel, "IN PROGRESS")
				else
					_SetLabelText(claimButton.TextLabel, isClaimed and "CLAIMED" or "CLAIM!")
				end

				claimButton.Background.BackgroundColor3 = isClaimable and Color3.fromRGB(255, 255, 255)
					or Color3.fromRGB(150, 150, 150)
				claimButton.Active = isClaimable

				claimButton.MouseEnter:Connect(function()
					SoundController:PlaySound("SFX", "MouseHover")
				end)

				claimButton.MouseButton1Click:Connect(function()
					SoundController:PlaySound("SFX", "MouseClick")

					if isClaimable then
						QuestController:RequestClaim(quest.Id)
					end
				end)
			end

			card.Parent = _Content
		end
	end
end

local function _ApplyStatus(status)
	if type(status) ~= "table" then
		return
	end

	_Status = status
	_HasClaimableQuest = _AnyClaimableQuest(status)
	QuestController.StatusUpdated:Fire(status)
	_PopulateQuestEntries()
	_UpdateResetTimeText()
	_UpdateQuestNotification()
end

local function _Refresh()
	local success, result = pcall(function()
		return GetQuestStatusRemote:InvokeServer()
	end)

	if success and result then
		_ApplyStatus(result)
	end
end

local function _SelectTab(tabName)
	if tabName ~= "Daily" and tabName ~= "Weekly" then
		return
	end

	_SelectedTab = tabName
	_UpdateTopTabVisuals()
	_PopulateQuestEntries()
	_UpdateResetTimeText()
end

local function _StartTimerLoop()
	if _TimerConnection then
		_TimerConnection:Disconnect()
		_TimerConnection = nil
	end

	local lastTick = 0
	_TimerConnection = RunService.Heartbeat:Connect(function()
		local now = tick()
		if now - lastTick < 1 then
			return
		end
		lastTick = now

		if not _ScreenGui or _ScreenGui.Enabled ~= true then
			return
		end

		_UpdateResetTimeText()
	end)
end

local function _SetupUI(screenGui)
	if _IsSetup then
		return
	end

	_ScreenGui = screenGui
	_MainFrame = screenGui:WaitForChild("MainFrame")
	_Content = _MainFrame:FindFirstChild("Content")
	_Template = _Content and _Content:FindFirstChild("_Template")
	_TopTabs = _MainFrame:FindFirstChild("TopTabs")
	_DailyTab = _TopTabs and _TopTabs:FindFirstChild("DailyTab")
	_WeeklyTab = _TopTabs and _TopTabs:FindFirstChild("WeeklyTab")
	_ResetTime = _MainFrame:FindFirstChild("ResetTime")

	if not _Content or not _Template then
		warn("[QuestController] Missing Content/_Template in QuestsWindow")
		return
	end

	_Template.Visible = false

	if _DailyTab and _DailyTab:IsA("GuiButton") then
		_DailyTab.MouseButton1Click:Connect(function()
			SoundController:PlaySound("SFX", "MouseClick")
			_SelectTab("Daily")
		end)
	end

	if _WeeklyTab and _WeeklyTab:IsA("GuiButton") then
		_WeeklyTab.MouseButton1Click:Connect(function()
			SoundController:PlaySound("SFX", "MouseClick")
			_SelectTab("Weekly")
		end)
	end

	local closeButton = _MainFrame:FindFirstChild("CloseButton")
	if closeButton and closeButton:IsA("GuiButton") then
		closeButton.MouseButton1Click:Connect(function()
			SoundController:PlaySound("SFX", "MouseClick")
			UIController:CloseWindow("QuestsWindow")
		end)
	end

	_UpdateTopTabVisuals()
	_PopulateQuestEntries()
	_UpdateResetTimeText()
	_StartTimerLoop()

	_ScreenGui:GetPropertyChangedSignal("Enabled"):Connect(function()
		if _ScreenGui.Enabled then
			_UpdateQuestNotification()
			_Refresh()
		else
			_UpdateQuestNotification()
		end
	end)

	_IsSetup = true
	_UpdateQuestNotification()
end

-- API Functions --
function QuestController:GetStatus()
	return _Status
end

function QuestController:GetQuest(questId)
	if not _Status or type(_Status.Quests) ~= "table" then
		return nil
	end

	for _, quest in ipairs(_Status.Quests) do
		if quest.Id == questId then
			return quest
		end
	end

	return nil
end

function QuestController:Refresh()
	_Refresh()
end

function QuestController:RequestClaim(questId)
	if type(questId) ~= "string" then
		return
	end

	ClaimQuestRewardRemote:FireServer(questId)
end

-- Initializers --
function QuestController:Init()
	QuestStatusUpdatedRemote.OnClientEvent:Connect(function(status)
		_ApplyStatus(status)
	end)

	OnLocalPlayerStoredDataStreamLoaded(function()
		_Refresh()
		_UpdateQuestNotification()
	end)

	UIController:WhenScreenGuiReady("QuestsWindow", function(screenGui)
		_SetupUI(screenGui)
	end)
end

-- Return Module --
return QuestController
