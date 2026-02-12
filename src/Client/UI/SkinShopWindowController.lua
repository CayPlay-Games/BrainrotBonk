--[[
	SkinShopWindowController.lua

	Description:
		Manages the SkinShopWindow UI - populates skin boxes (eggs) for purchase,
		displays skin previews with odds, and handles purchase requests.
--]]

-- Root --
local SkinShopWindowController = {}

-- Roblox Services --
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Dependencies --
local OnLocalPlayerStoredDataStreamLoaded = shared("OnLocalPlayerStoredDataStreamLoaded")
local UIController = shared("UIController")
local SkinBoxesConfig = shared("SkinBoxesConfig")
local SkinsConfig = shared("SkinsConfig")
local GetRemoteEvent = shared("GetRemoteEvent")
local RoundConfig = shared("RoundConfig")
local ViewportHelper = shared("ViewportHelper")

-- Remote Events --
local PurchaseSkinBoxRemoteEvent = GetRemoteEvent("PurchaseSkinBox")

-- Object References --
local SkinsFolder = nil

-- Private Variables --
local _ScreenGui = nil
local _SkinBlocks = nil
local _BoxTemplate = nil
local _CurrencyAmount = nil
local _BoxCards = {} -- boxId -> card
local _IsSetup = false
local _PlayerStoredDataStream = nil

-- Internal Functions --

local function DebugLog(...)
	if RoundConfig.DEBUG_LOG_STATE_CHANGES then
		print("[SkinShopWindowController]", ...)
	end
end

-- Creates a viewport camera for skin preview
local function SetupViewportCamera(viewport)
	local camera = viewport:FindFirstChildOfClass("Camera")
	if not camera then
		camera = Instance.new("Camera")
		camera.FieldOfView = 50
		camera.Parent = viewport
		viewport.CurrentCamera = camera
	end
	return camera
end

-- Displays a skin model in a viewport
local function DisplaySkinInViewport(viewport, skinId)
	-- Clear existing models
	for _, child in viewport:GetChildren() do
		if child:IsA("Model") then
			child:Destroy()
		end
	end

	-- Get skin config and model
	local skinConfig = SkinsConfig.Skins[skinId]
	if not skinConfig then
		DebugLog("Skin not found in SkinsConfig:", skinId)
		return nil
	end

	local previewModel = SkinsFolder:FindFirstChild(skinConfig.ModelName)
	if not previewModel then
		DebugLog("Skin model not found:", skinConfig.ModelName)
		return nil
	end

	-- Setup camera and display model
	local camera = SetupViewportCamera(viewport)
	local clone = ViewportHelper.DisplayModel(viewport, previewModel, camera)
	return clone
end

-- Creates a skin preview card for a box's SkinsScroll
local function CreateSkinPreviewCard(skinEntry, boxId, skinTemplate, skinsScroll)
	local skinId = skinEntry.SkinId
	local skinConfig = SkinsConfig.Skins[skinId]

	local card = skinTemplate:Clone()
	card.Name = skinId
	card.Visible = true

	-- Set skin name
	local skinName = card:FindFirstChild("SkinName")
	if skinName then
		skinName.Text = skinConfig and skinConfig.DisplayName or skinId
	end

	-- Set odds percentage
	local odds = SkinBoxesConfig:GetOdds(boxId, skinId)
	local oddsLabel = card:FindFirstChild("Odds")
	if oddsLabel then
		oddsLabel.Text = string.format("%.1f%%", odds)
	end

	-- Set background color based on rarity
	if skinConfig then
		local rarity = SkinsConfig.Rarities[skinConfig.Rarity]
		if rarity then
			card.BackgroundColor3 = rarity.Color
		end
	end

	-- Setup viewport with skin model (ViewportFrame is inside SkinModel)
	local skinModel = card:FindFirstChild("SkinModel")
	local viewport = skinModel and skinModel:FindFirstChild("ViewportFrame") or card:FindFirstChild("ViewportFrame")
	if viewport then
		DisplaySkinInViewport(viewport, skinId)
	end

	card.Parent = skinsScroll
	return card
end

-- Populates skins scroll with skin preview cards
local function PopulateSkinsScroll(boxId, boxConfig, skinsScroll, skinTemplate)
	-- Clear existing skin cards (except template)
	for _, child in skinsScroll:GetChildren() do
		if child:IsA("GuiObject") and child ~= skinTemplate and child.Name ~= "_Template" and child.Name ~= "Template" then
			child:Destroy()
		end
	end

	-- Create card for each skin
	for index, skinEntry in ipairs(boxConfig.Skins) do
		local card = CreateSkinPreviewCard(skinEntry, boxId, skinTemplate, skinsScroll)
		if card then
			card.LayoutOrder = index
		end
	end
end

-- Helper to find a TextLabel in a button (searches common patterns)
local function FindPriceLabel(button)
	-- Try common names first
	local label = button:FindFirstChild("Price")
		or button:FindFirstChild("TextLabel")
		or button:FindFirstChild("PriceLabel")
		or button:FindFirstChild("Amount")

	-- Fall back to finding any TextLabel
	if not label then
		label = button:FindFirstChildOfClass("TextLabel")
	end

	-- Search one level deeper if still not found
	if not label then
		for _, child in button:GetChildren() do
			if child:IsA("Frame") or child:IsA("ImageLabel") then
				label = child:FindFirstChildOfClass("TextLabel")
				if label then break end
			end
		end
	end

	return label
end

-- Creates a box card for the SkinBlocks scroll
local function CreateBoxCard(boxId, boxConfig)
	if not _BoxTemplate then return nil end

	local card = _BoxTemplate:Clone()
	card.Name = boxId
	card.Visible = true
	card.LayoutOrder = boxConfig.LayoutOrder or 1

	DebugLog("Creating box card:", boxId, "DisplayName:", boxConfig.DisplayName, "Tier:", boxConfig.Tier)

	local inner = card:FindFirstChild("Inner")
	if not inner then
		DebugLog("Inner not found in box template")
		return card
	end

	-- Setup TopRow elements
	local topRow = inner:FindFirstChild("TopRow")
	if topRow then
		-- Tier badge (inside BoxPreview)
		local boxPreview = topRow:FindFirstChild("BoxPreview")
		if boxPreview then
			local tierBadge = boxPreview:FindFirstChild("TierBadge")
			if tierBadge then
				local tierLabel = tierBadge:FindFirstChild("TierLabel")
				if tierLabel then
					tierLabel.Text = "Tier " .. boxConfig.Tier
					DebugLog("Set tier to:", tierLabel.Text)
				else
					DebugLog("TierLabel not found in TierBadge")
				end
			else
				DebugLog("TierBadge not found in BoxPreview")
			end
		else
			DebugLog("BoxPreview not found in TopRow")
		end

		-- Skins scroll
		local skinsScroll = topRow:FindFirstChild("SkinsScroll")
		if skinsScroll then
			-- Try both "Template" and "_Template" for flexibility
			local skinTemplate = skinsScroll:FindFirstChild("Template") or skinsScroll:FindFirstChild("_Template")
			if skinTemplate then
				skinTemplate.Visible = false
				PopulateSkinsScroll(boxId, boxConfig, skinsScroll, skinTemplate)
				DebugLog("Populated", #boxConfig.Skins, "skins for", boxId)
			else
				DebugLog("Template not found in SkinsScroll")
			end
		else
			DebugLog("SkinsScroll not found in TopRow")
		end
	else
		DebugLog("TopRow not found in Inner")
	end

	-- Setup BottomRow elements
	local bottomRow = inner:FindFirstChild("BottomRow")
	if bottomRow then
		-- Egg name
		local eggName = bottomRow:FindFirstChild("EggName")
		if eggName then
			eggName.Text = boxConfig.DisplayName
			DebugLog("Set egg name to:", boxConfig.DisplayName)
		end

		-- Robux button
		local robuxButton = bottomRow:FindFirstChild("RobuxButton")
		if robuxButton then
			local priceLabel = FindPriceLabel(robuxButton)
			if priceLabel then
				priceLabel.Text = tostring(boxConfig.RobuxPrice)
				DebugLog("Set RobuxPrice to:", boxConfig.RobuxPrice)
			else
				DebugLog("Could not find price label in RobuxButton. Children:", #robuxButton:GetChildren())
			end
			robuxButton.MouseButton1Click:Connect(function()
				DebugLog("Robux purchase clicked for", boxId)
				PurchaseSkinBoxRemoteEvent:FireServer(boxId, "Robux")
			end)
		end

		-- Soft currency button (Coins)
		local softCurrencyButton = bottomRow:FindFirstChild("SoftCurrencyButton")
		if softCurrencyButton then
			local priceLabel = FindPriceLabel(softCurrencyButton)
			if priceLabel then
				priceLabel.Text = tostring(boxConfig.CoinsPrice)
				DebugLog("Set CoinsPrice to:", boxConfig.CoinsPrice)
			else
				DebugLog("Could not find price label in SoftCurrencyButton. Children:", #softCurrencyButton:GetChildren())
			end
			softCurrencyButton.MouseButton1Click:Connect(function()
				DebugLog("Coins purchase clicked for", boxId)
				PurchaseSkinBoxRemoteEvent:FireServer(boxId, "Coins")
			end)
		end
	else
		DebugLog("BottomRow not found in Inner")
	end

	card.Parent = _SkinBlocks
	_BoxCards[boxId] = card

	return card
end

-- Populates all box cards
local function PopulateBoxes()
	-- Clear existing box cards
	for boxId, card in pairs(_BoxCards) do
		card:Destroy()
	end
	_BoxCards = {}

	-- Create cards for each box
	for boxId, boxConfig in pairs(SkinBoxesConfig.Boxes) do
		CreateBoxCard(boxId, boxConfig)
	end

	DebugLog("Populated", #_BoxCards, "skin boxes")
end

-- Updates the currency display
local function UpdateCurrencyDisplay()
	if not _PlayerStoredDataStream or not _CurrencyAmount then return end

	local coins = _PlayerStoredDataStream.Collections.Currencies.Coins:Read() or 0
	_CurrencyAmount.Text = tostring(coins)
end

-- Sets up UI references
local function SetupUI(screenGui)
	if _IsSetup then return end

	SkinsFolder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Skins")

	_ScreenGui = screenGui
	local mainFrame = _ScreenGui:WaitForChild("MainFrame")

	-- SkinBlocks scroll
	_SkinBlocks = mainFrame:WaitForChild("SkinBlocks")
	_BoxTemplate = _SkinBlocks:FindFirstChild("_Template")
	if _BoxTemplate then
		_BoxTemplate.Visible = false
	end

	-- TopBar currency display
	local topBar = mainFrame:FindFirstChild("TopBar")
	if topBar then
		local currencyFrame = topBar:FindFirstChild("CurrencyFrame")
		if currencyFrame then
			_CurrencyAmount = currencyFrame:FindFirstChild("CurrencyAmount")
		end
	end

	_IsSetup = true
	DebugLog("UI setup complete")
end

-- API Functions --

function SkinShopWindowController:Refresh()
	PopulateBoxes()
	UpdateCurrencyDisplay()
end

-- Initializers --
function SkinShopWindowController:Init()
	DebugLog("Initializing...")

	OnLocalPlayerStoredDataStreamLoaded(function(PlayerStoredDataStream)
		_PlayerStoredDataStream = PlayerStoredDataStream

		UIController:WhenScreenGuiReady("SkinShopWindow", function(screenGui)
			SetupUI(screenGui)

			-- Listen for currency changes
			_PlayerStoredDataStream.Collections.Currencies.Coins:Changed(function()
				UpdateCurrencyDisplay()
			end)

			-- Initial population
			PopulateBoxes()
			UpdateCurrencyDisplay()
		end)
	end)
end

-- Return Module --
return SkinShopWindowController
