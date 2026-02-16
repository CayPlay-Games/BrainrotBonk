--[[
	PrizeWheelWindowController.lua

	Description:
		Manages the PrizeWheelWindow UI, spin requests, wheel animation,
		progressive reward progress, and spin purchases.
--]]

-- Root --
local PrizeWheelWindowController = {}

-- Roblox Services --
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

-- Dependencies --
local PrizeWheelConfig = shared("PrizeWheelConfig")
local MonetizationProducts = shared("MonetizationProducts")
local MonetizationController = shared("MonetizationController")
local OnLocalPlayerStoredDataStreamLoaded = shared("OnLocalPlayerStoredDataStreamLoaded")
local UIController = shared("UIController")
local GetRemoteFunction = shared("GetRemoteFunction")

-- Remotes --
local GetPrizeWheelStatusRemote = GetRemoteFunction("GetPrizeWheelStatus")
local RequestPrizeWheelSpinRemote = GetRemoteFunction("RequestPrizeWheelSpin")

-- Constants --
local FREE_SPIN_COOLDOWN_SECONDS = 24 * 60 * 60
local BUY_ONE_SPIN_SKU = "PrizeWheelSpin1"
local BUY_FIVE_SPINS_SKU = "PrizeWheelSpin5"
local SPIN_DURATION = 2.6
local SPIN_FULL_TURNS = 4
local IDLE_SPIN_DEGREES_PER_SECOND = 8

local WHEEL_SEGMENT_POSITION_RADIUS = 0.35

-- Private Variables --
local _ScreenGui = nil
local _MainFrame = nil
local _Wheel = nil
local _WheelContent = nil
local _WheelTemplate = nil
local _ProgressiveFrame = nil
local _ProgressiveTemplate = nil
local _Sidebar = nil
local _SidebarTemplate = nil
local _SpinButton = nil
local _SpinButtonTextLabel = nil
local _NextSpinLabel = nil

local _ProgressiveCards = {}
local _TimerConnection = nil
local _CurrentWheelRotation = 0
local _IsSpinning = false
local _IsSetup = false

local _State = {
	SpinsLeft = 0,
	LastSpin = 0,
	Now = os.time(),
	ProgressiveTier = 1,
	ProgressiveSpins = 0,
	LastRewardName = "",
}

-- Internal Functions --
local function GetTextLabel(guiObject)
	if not guiObject then
		return nil
	end

	if guiObject:IsA("TextLabel") or guiObject:IsA("TextButton") then
		return guiObject
	end

	return guiObject:FindFirstChild("TextLabel", true)
end

local function GetDirectChildTextLabel(guiObject)
	if not guiObject then
		return nil
	end

	local child = guiObject:FindFirstChild("TextLabel")
	if child and child:IsA("TextLabel") then
		return child
	end

	return nil
end

local function SetLabelText(guiObject, text)
	local label = GetTextLabel(guiObject)
	if label then
		label.Text = text
	end
end

local function SetButtonText(button, text)
	if not button then
		return
	end

	if button:IsA("TextButton") then
		button.Text = text
	end
	SetLabelText(button, text)
end

local function FormatTime(seconds)
	local remaining = math.max(0, math.floor(seconds))
	local hours = math.floor(remaining / 3600)
	local minutes = math.floor((remaining % 3600) / 60)
	local secs = remaining % 60
	return string.format("%02d:%02d:%02d", hours, minutes, secs)
end

local function GetSpinButtonText()
	if _IsSpinning then
		return "Spinning..."
	end
	if (_State.SpinsLeft or 0) <= 0 then
		return "No Spins"
	end
	return "Spin [" .. _State.SpinsLeft .. "]"
end

local function UpdateSpinButtonState()
	if not _SpinButton then
		return
	end

	SetButtonText(_SpinButton, GetSpinButtonText())

	if _SpinButton:IsA("GuiButton") then
		_SpinButton.Active = not _IsSpinning
	end
end

local function UpdateNextSpinText()
	if not _NextSpinLabel then
		return
	end

	if (_State.SpinsLeft or 0) > 0 then
		SetLabelText(_NextSpinLabel, "")
		return
	end

	local now = os.time()
	local lastSpin = _State.LastSpin or 0
	local remaining = FREE_SPIN_COOLDOWN_SECONDS - (now - lastSpin)
	if remaining <= 0 then
		SetLabelText(_NextSpinLabel, "Free spin ready!")
	else
		SetLabelText(_NextSpinLabel, "Free spin in " .. FormatTime(remaining))
	end
end

local function ApplyPrizeVisuals(card, rewardConfig)
	local icon = card:FindFirstChild("PreviewIcon", true)
	if icon and icon:IsA("ImageLabel") then
		icon.Image = rewardConfig.Icon or ""
	end

	local displayName = card:FindFirstChild("DisplayName", true)
	if displayName and displayName:IsA("TextLabel") then
		displayName.Text = rewardConfig.DisplayName or "Reward"
		if rewardConfig.Color then
			displayName.TextColor3 = rewardConfig.Color
		end
	end

	local chanceLabel = card:FindFirstChild("ChanceLabel", true)
	if chanceLabel and chanceLabel:IsA("TextLabel") then
		local chance = tonumber(rewardConfig.Chance) or 0
		chanceLabel.Text = string.format("%d%%", chance)
	end
end

local function PopulateWheel()
	if not _WheelContent or not _WheelTemplate then
		return
	end

	for _, child in ipairs(_WheelContent:GetChildren()) do
		if child ~= _WheelTemplate and string.sub(child.Name, 1, 11) == "PrizeSlice_" then
			child:Destroy()
		end
	end

	local prizes = PrizeWheelConfig.Prizes or {}
	local total = #prizes
	if total <= 0 then
		return
	end

	local segmentStep = 360 / total
	for index, rewardConfig in ipairs(prizes) do
		local card = _WheelTemplate:Clone()
		card.Name = "PrizeSlice_" .. index
		card.Visible = true

		local angle = (index - 1) * segmentStep - 90
		local radians = math.rad(angle)
		card.AnchorPoint = Vector2.new(0.5, 0.5)
		card.Position = UDim2.fromScale(
			0.5 + math.cos(radians) * WHEEL_SEGMENT_POSITION_RADIUS,
			0.5 + math.sin(radians) * WHEEL_SEGMENT_POSITION_RADIUS
		)
		card.Rotation = angle + 90

		ApplyPrizeVisuals(card, rewardConfig)

		card.Parent = _WheelContent
	end
end

local function BuildProgressiveCard(index, rewardConfig)
	if not _ProgressiveTemplate or not _ProgressiveFrame then
		return
	end

	local card = _ProgressiveTemplate:Clone()
	card.Name = "Progressive_" .. index
	card.LayoutOrder = index
	card.Visible = true

	local displayName = card:FindFirstChild("DisplayName", true)
	if displayName and displayName:IsA("TextLabel") then
		displayName.Text = rewardConfig.DisplayName or "Reward"
		if rewardConfig.Color then
			displayName.TextColor3 = rewardConfig.Color
		end
	end

	local required = rewardConfig.RequiredSpins or 0
	local requiredLabel = card:FindFirstChild("RequiredSpins", true)
	if requiredLabel and requiredLabel:IsA("TextLabel") then
		requiredLabel.Text = required .. " spins"
	end

	card.Parent = _ProgressiveFrame
	_ProgressiveCards[index] = card
end

local function PopulateProgressive()
	if not _ProgressiveFrame or not _ProgressiveTemplate then
		return warn("Frame or template is nil")
	end

	for _, child in ipairs(_ProgressiveFrame:GetChildren()) do
		if child ~= _ProgressiveTemplate and string.sub(child.Name, 1, 12) == "Progressive_" then
			child:Destroy()
		end
	end
	table.clear(_ProgressiveCards)

	for index, rewardConfig in ipairs(PrizeWheelConfig.ProgressivePrizes or {}) do
		BuildProgressiveCard(index, rewardConfig)
	end
end

local function UpdateProgressiveProgress()
	for index, card in pairs(_ProgressiveCards) do
		local config = PrizeWheelConfig.ProgressivePrizes[index]
		local requiredSpins = (config and config.RequiredSpins) or 1
		local tier = _State.ProgressiveTier or 1
		local spins = _State.ProgressiveSpins or 0

		local progressValue = 0
		local statusText = requiredSpins .. " spins"

		if tier > index then
			progressValue = 1
			statusText = "Unlocked"
		elseif tier == index then
			progressValue = math.clamp(spins / math.max(requiredSpins, 1), 0, 1)
			statusText = string.format("%d / %d spins", spins, requiredSpins)
		else
			statusText = "Locked"
		end

		local requiredLabel = card:FindFirstChild("RequiredSpins", true)
		if requiredLabel and requiredLabel:IsA("TextLabel") then
			requiredLabel.Text = statusText
		end

		local progressFrame = card:FindFirstChild("Progress", true)
		local bar = progressFrame and progressFrame:FindFirstChild("Bar")
		if bar and bar:IsA("Frame") then
			bar.Size = UDim2.new(progressValue, 0, 1, 0)
		end
	end
end

local function ResolveProductPriceText(sku)
	local config = MonetizationProducts:GetProductConfig(sku)
	if not config then
		return "R$?"
	end

	local cost = config.IdealRobuxCost
	if type(cost) ~= "number" then
		return "R$?"
	end

	return "R$" .. tostring(cost)
end

local function HookPurchaseButton(button, sku)
	button.MouseButton1Click:Connect(function()
		if _IsSpinning then
			return
		end
		MonetizationController:PromptPurchase(sku)
	end)
end

local function PopulateSidebar()
	if not _Sidebar or not _SidebarTemplate then
		return warn("Frame or template is nil")
	end

	for _, child in ipairs(_Sidebar:GetChildren()) do
		if child ~= _SidebarTemplate and string.sub(child.Name, 1, 8) == "BuyPack_" then
			child:Destroy()
		end
	end

	local entries = {
		{
			Name = "BuyPack_1",
			Text = "x1 Spin",
			SKU = BUY_ONE_SPIN_SKU,
		},
		{
			Name = "BuyPack_5",
			Text = "x5 Spins",
			SKU = BUY_FIVE_SPINS_SKU,
		},
	}

	for index, entry in ipairs(entries) do
		local item = _SidebarTemplate:Clone()
		item.Name = entry.Name
		item.LayoutOrder = index
		item.Visible = true

		local textLabel = GetDirectChildTextLabel(item)
		if textLabel and textLabel:IsA("TextLabel") then
			textLabel.Text = entry.Text
		end

		local buyButton = item:FindFirstChild("BuyButton", true)
		if buyButton and buyButton:IsA("GuiButton") then
			local buyLabel = GetDirectChildTextLabel(buyButton)
			if buyLabel then
				buyLabel.Text = ResolveProductPriceText(entry.SKU)
			else
				SetButtonText(buyButton, ResolveProductPriceText(entry.SKU))
			end
			HookPurchaseButton(buyButton, entry.SKU)
		end

		item.Parent = _Sidebar
	end
end

local function ResolveValue(nextValue, fallbackValue)
	if nextValue == nil then
		return fallbackValue
	end
	return nextValue
end

local function ApplyStatus(status)
	if not status then
		return
	end

	_State.SpinsLeft = ResolveValue(status.SpinsLeft, _State.SpinsLeft)
	_State.LastSpin = ResolveValue(status.LastSpin, _State.LastSpin)
	_State.Now = ResolveValue(status.Now, _State.Now)
	_State.ProgressiveTier = ResolveValue(status.ProgressiveTier, _State.ProgressiveTier)
	_State.ProgressiveSpins = ResolveValue(status.ProgressiveSpins, _State.ProgressiveSpins)

	UpdateSpinButtonState()
	UpdateNextSpinText()
	UpdateProgressiveProgress()
end

local function RefreshStatus()
	local success, status = pcall(function()
		return GetPrizeWheelStatusRemote:InvokeServer()
	end)

	if success and status then
		ApplyStatus(status)
	end
end

local function SpinWheelToIndex(index, totalCount, onComplete)
	if not _Wheel or totalCount <= 0 then
		_IsSpinning = false
		UpdateSpinButtonState()
		return
	end

	local segmentStep = 360 / totalCount
	local startRotation = _CurrentWheelRotation % 360
	local desired = (360 - (((index - 1) * segmentStep) % 360)) % 360
	local delta = (desired - startRotation) % 360
	local targetRotation = _CurrentWheelRotation + (360 * SPIN_FULL_TURNS) + delta

	local tween = TweenService:Create(
		_Wheel,
		TweenInfo.new(SPIN_DURATION, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		{ Rotation = targetRotation }
	)

	local completedConnection
	completedConnection = tween.Completed:Connect(function()
		if completedConnection then
			completedConnection:Disconnect()
		end

		_CurrentWheelRotation = targetRotation
		_IsSpinning = false
		UpdateSpinButtonState()

		if onComplete then
			onComplete()
		end
	end)

	tween:Play()
end

local function OnSpinClicked()
	if _IsSpinning then
		return
	end
	if (_State.SpinsLeft or 0) <= 0 then
		return
	end

	_IsSpinning = true
	UpdateSpinButtonState()

	local ok, response = pcall(function()
		return RequestPrizeWheelSpinRemote:InvokeServer()
	end)

	if not ok or not response or response.Success ~= true then
		_IsSpinning = false
		UpdateSpinButtonState()
		if response and response.Status then
			ApplyStatus(response.Status)
		else
			RefreshStatus()
		end
		return
	end

	local rewardIndex = response.RewardIndex or math.random(1, math.max(#(PrizeWheelConfig.Prizes or {}), 1))
	local totalRewards = math.max(#(PrizeWheelConfig.Prizes or {}), 1)

	SpinWheelToIndex(rewardIndex, totalRewards, function()
		_State.LastRewardName = response.RewardName or ""
		if response.Status then
			ApplyStatus(response.Status)
		else
			RefreshStatus()
		end
	end)
end

local function ConnectDataStream()
	OnLocalPlayerStoredDataStreamLoaded(function(stored)
		_State.SpinsLeft = stored.Spins:Read() or 0
		UpdateSpinButtonState()
		UpdateNextSpinText()

		stored.Spins:Changed(function(newSpins)
			_State.SpinsLeft = newSpins or 0
			UpdateSpinButtonState()
			UpdateNextSpinText()
		end)

		local wheel = stored.PrizeWheel
		if not wheel then
			RefreshStatus()
			return
		end

		_State.LastSpin = wheel.LastSpin:Read() or 0
		_State.ProgressiveTier = wheel.ProgressiveTier:Read() or 1
		_State.ProgressiveSpins = wheel.ProgressiveSpins:Read() or 0
		UpdateNextSpinText()
		UpdateProgressiveProgress()

		wheel.LastSpin:Changed(function(value)
			_State.LastSpin = value or 0
			UpdateNextSpinText()
		end)

		wheel.ProgressiveTier:Changed(function(value)
			_State.ProgressiveTier = value or 1
			UpdateProgressiveProgress()
		end)

		wheel.ProgressiveSpins:Changed(function(value)
			_State.ProgressiveSpins = value or 0
			UpdateProgressiveProgress()
		end)
	end)
end

local function StartTimerLoop()
	if _TimerConnection then
		_TimerConnection:Disconnect()
		_TimerConnection = nil
	end

	local lastTick = 0
	_TimerConnection = RunService.Heartbeat:Connect(function(deltaTime)
		if _Wheel and _ScreenGui and _ScreenGui.Enabled and not _IsSpinning then
			_CurrentWheelRotation += IDLE_SPIN_DEGREES_PER_SECOND * deltaTime
			_Wheel.Rotation = _CurrentWheelRotation
		end

		local now = tick()
		if now - lastTick < 1 then
			return
		end
		lastTick = now
		UpdateNextSpinText()
	end)
end

local function SetupUI(screenGui)
	if _IsSetup then
		return
	end

	_ScreenGui = screenGui
	_MainFrame = _ScreenGui:WaitForChild("MainFrame")

	_Wheel = _MainFrame:FindFirstChild("Wheel")
	_WheelContent = _Wheel and _Wheel:FindFirstChild("Content")
	_WheelTemplate = _WheelContent and _WheelContent:FindFirstChild("_Template")
	if _WheelTemplate then
		_WheelTemplate.Visible = false
	end

	_ProgressiveFrame = _MainFrame:FindFirstChild("ProgressivePrizes")
	_ProgressiveTemplate = _ProgressiveFrame and _ProgressiveFrame:FindFirstChild("_Template")
	if _ProgressiveTemplate then
		_ProgressiveTemplate.Visible = false
	end

	_Sidebar = _MainFrame:FindFirstChild("Sidebar")
	_SidebarTemplate = _Sidebar and _Sidebar:FindFirstChild("_Template")
	if _SidebarTemplate then
		_SidebarTemplate.Visible = false
	end

	_SpinButton = _MainFrame:FindFirstChild("SpinButton")
	_SpinButtonTextLabel = _SpinButton and _SpinButton:FindFirstChild("TextLabel", true)
	_NextSpinLabel = _MainFrame:FindFirstChild("NextSpin", true)

	local closeButton = _MainFrame:FindFirstChild("CloseButton")
	if closeButton and closeButton:IsA("GuiButton") then
		closeButton.MouseButton1Click:Connect(function()
			UIController:CloseWindow("PrizeWheelWindow")
		end)
	end

	if _SpinButton and _SpinButton:IsA("GuiButton") then
		_SpinButton.MouseButton1Click:Connect(OnSpinClicked)
	end

	if _Wheel then
		_CurrentWheelRotation = _Wheel.Rotation
	end

	if _SpinButtonTextLabel then
		_SpinButtonTextLabel.Text = GetSpinButtonText()
	end

	_ScreenGui:GetPropertyChangedSignal("Enabled"):Connect(function()
		if _ScreenGui.Enabled then
			PopulateProgressive()
			PopulateSidebar()
			RefreshStatus()
		end
	end)

	PopulateWheel()
	PopulateProgressive()
	PopulateSidebar()
	UpdateProgressiveProgress()
	UpdateSpinButtonState()
	UpdateNextSpinText()
	RefreshStatus()
	StartTimerLoop()

	_IsSetup = true
end

-- API Functions --
function PrizeWheelWindowController:Refresh()
	RefreshStatus()
end

-- Initializers --
function PrizeWheelWindowController:Init()
	ConnectDataStream()

	UIController:WhenScreenGuiReady("PrizeWheelWindow", function(screenGui)
		SetupUI(screenGui)
	end)
end

-- Return Module --
return PrizeWheelWindowController
