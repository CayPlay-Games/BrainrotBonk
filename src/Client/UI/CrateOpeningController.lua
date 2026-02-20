--[[
	CrateOpeningController.lua

	Description:
		Manages the crate opening animation after purchasing a skin box.
		Shows crate icon, plays roulette animation through possible skins,
		and reveals the result.
--]]

local CrateOpeningController = {}

-- Roblox Services --
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

-- Dependencies --
local GetRemoteEvent = shared("GetRemoteEvent")
local UIController = shared("UIController")
local SkinBoxesConfig = shared("SkinBoxesConfig")
local SkinsConfig = shared("SkinsConfig")
local ViewportHelper = shared("ViewportHelper")
local SoundController = shared("SoundController")
local ModelHelper = shared("ModelHelper")

-- Remote Events --
local SkinBoxResultRemoteEvent = GetRemoteEvent("SkinBoxResult")

-- Animation Constants --
local MIN_CYCLES = 27
local MAX_CYCLES = 30
local ANIMATION_SPEED = 0.1
local SCALE_MIN = 0.001
local SCALE_MAX = 1
local ROTATION_SPEED = 30 -- Degrees per second

-- Confetti Constants --
local CONFETTI_COUNT = 50
local CONFETTI_COLORS = {
	Color3.fromRGB(255, 0, 0),
	Color3.fromRGB(255, 165, 0),
	Color3.fromRGB(255, 255, 0),
	Color3.fromRGB(0, 255, 0),
	Color3.fromRGB(0, 150, 255),
	Color3.fromRGB(150, 0, 255),
	Color3.fromRGB(255, 100, 200),
}

-- Hype Text Constants --
local HYPE_TEXTS = { "Wow", "Neat", "Holy Sigma!", "Skibidi", "Sigma", "Drippy", "GOAT", "BIG W" }
local HYPE_COLORS = {
	Color3.fromRGB(255, 255, 0),
	Color3.fromRGB(0, 255, 255),
	Color3.fromRGB(255, 0, 255),
	Color3.fromRGB(0, 255, 100),
	Color3.fromRGB(255, 100, 0),
	Color3.fromRGB(100, 200, 255),
}

-- State Machine --
local STATE_IDLE = "Idle"
local STATE_WAITING_CLICK = "WaitingClick"
local STATE_ANIMATING = "Animating"
local STATE_REVEALING = "Revealing"

-- Private Variables --
local _ScreenGui, _Background, _CrateContainer, _Icon, _ClickPrompt
local _RouletteContainer, _SkinViewport, _SkinName, _ClosePrompt
local _Results, _ResultsNew, _ResultsDuplicate, _ResultsRefund
local _SkinsFolder
local _CurrentState = STATE_IDLE
local _PendingResult = nil
local _ClickConnection = nil
local _RotationConnection = nil
local _SkipConnection = nil
local _SkipRequested = false
local _WinnerModel = nil
local _IsSetup = false

-- Forward Declarations --
local Close, WaitForClick, RevealWinner

-- Confetti Effect --
local function SpawnConfetti(parent)
	for _ = 1, CONFETTI_COUNT do
		local confetti = Instance.new("Frame")
		confetti.Size = UDim2.fromOffset(math.random(8, 14), math.random(8, 14))
		confetti.AnchorPoint = Vector2.new(0.5, 0.5)
		confetti.Position = UDim2.fromScale(0.5, 0.5)
		confetti.BackgroundColor3 = CONFETTI_COLORS[math.random(1, #CONFETTI_COLORS)]
		confetti.BorderSizePixel = 0
		confetti.Rotation = math.random(0, 360)
		confetti.Parent = parent

		local angle = math.rad(math.random(0, 360))
		local distance = math.random(300, 600)
		local endX = 0.5 + math.cos(angle) * (distance / parent.AbsoluteSize.X)
		local endY = 0.5 + math.sin(angle) * (distance / parent.AbsoluteSize.Y)

		local tween = TweenService:Create(confetti, TweenInfo.new(
			math.random(80, 120) / 100,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out
		), {
			Position = UDim2.fromScale(endX, endY),
			Rotation = confetti.Rotation + math.random(-180, 180),
			BackgroundTransparency = 1,
		})

		tween:Play()
		tween.Completed:Connect(function()
			confetti:Destroy()
		end)
	end
end

-- Hype Text Effect --
local function SpawnHypeText(parent)
	task.spawn(function()
		while _CurrentState == STATE_REVEALING do
			local label = Instance.new("TextLabel")
			label.Text = HYPE_TEXTS[math.random(1, #HYPE_TEXTS)]
			label.Font = Enum.Font.GothamBold
			label.TextSize = math.random(28, 40)
			label.TextColor3 = HYPE_COLORS[math.random(1, #HYPE_COLORS)]
			label.TextStrokeColor3 = Color3.new(0, 0, 0)
			label.TextStrokeTransparency = 0
			label.BackgroundTransparency = 1
			label.Size = UDim2.fromOffset(200, 50)
			label.AnchorPoint = Vector2.new(0.5, 0.5)
			label.Rotation = math.random(-15, 15)

			-- Start near center with some randomness
			local startX = 0.5 + (math.random(-20, 20) / 100)
			local startY = 0.5 + (math.random(-20, 20) / 100)
			label.Position = UDim2.fromScale(startX, startY)
			label.Parent = parent

			-- Random outward direction
			local angle = math.rad(math.random(0, 360))
			local distance = math.random(150, 300)
			local endX = startX + math.cos(angle) * (distance / parent.AbsoluteSize.X)
			local endY = startY + math.sin(angle) * (distance / parent.AbsoluteSize.Y)

			local tween = TweenService:Create(label, TweenInfo.new(
				2,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.Out
			), {
				Position = UDim2.fromScale(endX, endY),
				TextTransparency = 1,
				TextStrokeTransparency = 1,
			})

			tween:Play()
			tween.Completed:Wait()
			label:Destroy()
		end
	end)
end

-- Model Helpers --
local function GetSkinModel(skinId, mutation)
	mutation = mutation or "Normal"
	local skinConfig = SkinsConfig.Skins[skinId]
	if not skinConfig then return nil end

	local skinFolder = _SkinsFolder:FindFirstChild(skinConfig.ModelName)
	if skinFolder and skinFolder:IsA("Folder") then
		local model = skinFolder:FindFirstChild(mutation)
		if model then return model end
		if mutation ~= "Normal" then
			model = skinFolder:FindFirstChild("Normal")
			if model then return model end
		end
	end

	return _SkinsFolder:FindFirstChild(skinConfig.ModelName)
end

local function ScaleModel(model, scale)
	if model.ScaleTo then
		model:ScaleTo(scale)
	end
end

-- Roulette Animation --
local function GetSpeedMultiplier(cycleIndex, totalCycles)
	local progress = cycleIndex / totalCycles
	return 5 * progress ^ 3 + 0.1
end

local function PlayRouletteAnimation(boxId, resultSkinId, resultMutation)
	local boxConfig = SkinBoxesConfig.Boxes[boxId]
	if not boxConfig or #boxConfig.Skins == 0 then
		return
	end

	-- Find result index
	local resultIndex = 1
	for i, skinEntry in ipairs(boxConfig.Skins) do
		if skinEntry.SkinId == resultSkinId then
			resultIndex = i
			break
		end
	end

	local skinCount = #boxConfig.Skins
	local totalCycles = math.random(MIN_CYCLES, MAX_CYCLES) + resultIndex

	-- UI state
	_CrateContainer.Visible = false
	_RouletteContainer.Visible = true
	_ClosePrompt.Visible = false
	_SkinName.Text = "???"

	ViewportHelper.Clear(_SkinViewport)
	local camera = ViewportHelper.GetCamera(_SkinViewport)

	-- Pre-cache models
	local cachedModels, cachedDistances, cachedTextures = {}, {}, {}
	for index, skinEntry in ipairs(boxConfig.Skins) do
		local skinModel = GetSkinModel(skinEntry.SkinId, "Normal")
		if skinModel then
			local clone = skinModel:Clone()
			clone.Parent = _SkinViewport
			cachedDistances[index] = ViewportHelper.CalculateDistance(clone, camera.FieldOfView)
			cachedTextures[index] = ModelHelper:BlackoutModel(clone)
			ScaleModel(clone, SCALE_MIN)
			cachedModels[index] = clone
		end
	end

	-- Set up skip detection
	_SkipRequested = false
	_SkipConnection = _Background.MouseButton1Click:Connect(function()
		_SkipRequested = true
	end)

	-- Helper to clean up and reveal
	local function skipToReveal()
		if _SkipConnection then
			_SkipConnection:Disconnect()
			_SkipConnection = nil
		end

		local winnerModel = cachedModels[resultIndex]
		if winnerModel then
			-- Show only winner model at full scale
			for _, model in pairs(cachedModels) do
				model.Parent = nil
			end
			winnerModel.Parent = _SkinViewport
			winnerModel:PivotTo(CFrame.new(0, 0, -cachedDistances[resultIndex]))
			ScaleModel(winnerModel, SCALE_MAX)

			-- Clean up non-winner models
			for idx, model in pairs(cachedModels) do
				if idx ~= resultIndex then
					model:Destroy()
				end
			end

			RevealWinner(resultSkinId, winnerModel, cachedTextures[resultIndex], cachedDistances[resultIndex])
		end
	end

	-- Animation loop
	for i = 1, totalCycles do
		-- Check for skip request
		if _SkipRequested then
			skipToReveal()
			return
		end

		local isFinal = (i == totalCycles)
		local showIndex = isFinal and resultIndex or ((i - 1) % skinCount) + 1
		local previewModel = cachedModels[showIndex]

		if not previewModel then continue end

		-- Show only current model
		for _, model in pairs(cachedModels) do
			model.Parent = nil
		end
		previewModel.Parent = _SkinViewport
		previewModel:PivotTo(CFrame.new(0, 0, -cachedDistances[showIndex]))

		-- Calculate timing
		local speedMultiplier = GetSpeedMultiplier(i, totalCycles)
		local scaleTime = ANIMATION_SPEED * 0.4 * speedMultiplier
		local steps = math.max(3, math.floor(scaleTime / 0.016))

		-- SFX
		SoundController:PlaySound("SFX", "LuckyBlockTick")

		-- Scale up
		for step = 1, steps do
			if _SkipRequested then
				skipToReveal()
				return
			end
			local t = step / steps
			ScaleModel(previewModel, SCALE_MIN + (SCALE_MAX - SCALE_MIN) * t)
			task.wait(scaleTime / steps)
		end

		if isFinal then
			if _SkipConnection then
				_SkipConnection:Disconnect()
				_SkipConnection = nil
			end
			task.wait(1)
			for idx, model in pairs(cachedModels) do
				if idx ~= resultIndex then
					model:Destroy()
				end
			end
			RevealWinner(resultSkinId, previewModel, cachedTextures[resultIndex], cachedDistances[resultIndex])
			return
		else
			-- Scale down
			for step = 1, steps do
				if _SkipRequested then
					skipToReveal()
					return
				end
				local t = step / steps
				ScaleModel(previewModel, SCALE_MAX - (SCALE_MAX - SCALE_MIN) * t)
				task.wait(scaleTime / steps)
			end
		end
	end
end

-- Reveal Winner --
RevealWinner = function(skinId, model, originalTextures, distance)
	_CurrentState = STATE_REVEALING
	_WinnerModel = model

	if originalTextures then
		ModelHelper:RestoreTextures(originalTextures)
	end

	SoundController:PlaySound("SFX", "LuckyBlockReveal")
	task.delay(1.5, function()
		SoundController:PlaySound("SFX", skinId)
	end)
	SpawnConfetti(_ScreenGui)
	SpawnHypeText(_ScreenGui)

	-- Start rotating the model
	local rotation = 0
	_RotationConnection = RunService.RenderStepped:Connect(function(dt)
		if _WinnerModel and _WinnerModel.Parent then
			rotation = rotation + ROTATION_SPEED * dt
			_WinnerModel:PivotTo(CFrame.new(0, 0, -distance) * CFrame.Angles(0, math.rad(rotation), 0))
		end
	end)

	local skinConfig = SkinsConfig.Skins[skinId]
	if skinConfig then
		_SkinName.Text = skinConfig.DisplayName
		local rarity = SkinsConfig.Rarities[skinConfig.Rarity]
		if rarity then
			_SkinName.TextColor3 = rarity.Color
		end
	else
		_SkinName.Text = skinId
	end

	-- Show results
	if _PendingResult and _PendingResult.IsNew then
		_ResultsNew.Visible = true
		_ResultsDuplicate.Visible = false
	elseif _PendingResult then
		_ResultsNew.Visible = false
		_ResultsDuplicate.Visible = true
		_ResultsRefund.Text = "+" .. tostring(_PendingResult.RefundAmount)
	end
	_Results.Visible = true

	_ClosePrompt.Visible = true
	_ClosePrompt.Text = "Click to close"

	WaitForClick(Close)
end

-- Click Handler --
WaitForClick = function(callback)
	if _ClickConnection then
		_ClickConnection:Disconnect()
	end

	_ClickConnection = _Background.MouseButton1Click:Connect(function()
		if _ClickConnection then
			_ClickConnection:Disconnect()
			_ClickConnection = nil
		end
		callback()
	end)
end

-- Show/Close --
local function ShowCrateOpening(boxId, resultSkinId, resultMutation, isNew, refundAmount)
	if not _IsSetup then
		return
	end

	_CurrentState = STATE_WAITING_CLICK
	_PendingResult = { BoxId = boxId, SkinId = resultSkinId, Mutation = resultMutation, IsNew = isNew, RefundAmount = refundAmount or 0 }

	UIController:CloseAllWindows()
	UIController:ShowOverlay()

	_ScreenGui.Enabled = true
	_Background.Visible = true
	_CrateContainer.Visible = true
	_RouletteContainer.Visible = false
	_ClosePrompt.Visible = false
	_Results.Visible = false
	_ResultsNew.Visible = false
	_ResultsDuplicate.Visible = false

	ViewportHelper.Clear(_SkinViewport)

	local boxConfig = SkinBoxesConfig.Boxes[boxId]
	if boxConfig and boxConfig.Icon then
		_Icon.Image = boxConfig.Icon
	end

	_ClickPrompt.Text = "Click to open!"
	_ClickPrompt.Visible = true
	_SkinName.Text = ""
	_SkinName.TextColor3 = Color3.new(1, 1, 1)

	WaitForClick(function()
		if _PendingResult then
			_CurrentState = STATE_ANIMATING
			_ClickPrompt.Visible = false
			SoundController:PlaySound("SFX", "LuckyBlockUse")
			PlayRouletteAnimation(_PendingResult.BoxId, _PendingResult.SkinId, _PendingResult.Mutation)
		end
	end)
end

Close = function()

	_CurrentState = STATE_IDLE
	_PendingResult = nil
	_WinnerModel = nil
	_SkipRequested = false

	if _ClickConnection then
		_ClickConnection:Disconnect()
		_ClickConnection = nil
	end

	if _SkipConnection then
		_SkipConnection:Disconnect()
		_SkipConnection = nil
	end

	if _RotationConnection then
		_RotationConnection:Disconnect()
		_RotationConnection = nil
	end

	UIController:HideOverlay()

	_ScreenGui.Enabled = false
	_Background.Visible = false
	_CrateContainer.Visible = false
	_RouletteContainer.Visible = false
	_ClosePrompt.Visible = false
	_Results.Visible = false

	_Icon.Image = ""
	ViewportHelper.Clear(_SkinViewport)
end

-- Setup --
local function SetupUI(screenGui)
	if _IsSetup then return end

	local assets = ReplicatedStorage:WaitForChild("Assets")
	_SkinsFolder = assets:WaitForChild("Skins")

	_ScreenGui = screenGui
	_ScreenGui.Enabled = false

	_Background = _ScreenGui:WaitForChild("Background")
	_CrateContainer = _ScreenGui:WaitForChild("CrateContainer")
	_Icon = _CrateContainer:WaitForChild("Icon")
	_ClickPrompt = _CrateContainer:WaitForChild("ClickPrompt")
	_RouletteContainer = _ScreenGui:WaitForChild("RouletteContainer")
	_SkinViewport = _RouletteContainer:WaitForChild("SkinViewport")
	_SkinName = _RouletteContainer:WaitForChild("SkinName")
	_ClosePrompt = _ScreenGui:WaitForChild("ClosePrompt")
	_Results = _ScreenGui:WaitForChild("Results")
	_ResultsNew = _Results:WaitForChild("New")
	_ResultsDuplicate = _Results:WaitForChild("Duplicate")
	_ResultsRefund = _ResultsDuplicate:WaitForChild("Refund")

	ViewportHelper.GetCamera(_SkinViewport)

	_IsSetup = true
end

-- Public API --
function CrateOpeningController:Show(boxId, resultSkinId, resultMutation, isNew, refundAmount)
	ShowCrateOpening(boxId, resultSkinId, resultMutation, isNew, refundAmount)
end

function CrateOpeningController:Close()
	Close()
end

function CrateOpeningController:IsOpen()
	return _CurrentState ~= STATE_IDLE
end

function CrateOpeningController:Init()

	UIController:WhenScreenGuiReady("CrateOpening", function(screenGui)
		SetupUI(screenGui)

		SkinBoxResultRemoteEvent.OnClientEvent:Connect(function(result)
			if result.Success then
				ShowCrateOpening(result.BoxId, result.SkinId, result.Mutation, result.IsNew, result.RefundAmount)
			else
				warn("[CrateOpeningController] Purchase failed:", result.Reason)
			end
		end)
	end)
end

return CrateOpeningController
