--[[
	SkinsWindowController.lua

	Description:
		Manages the SkinsWindow UI - populates grid with unlocked skins,
		handles skin selection/preview, and equipping.
--]]

-- Root --
local SkinsWindowController = {}

-- Roblox Services --
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Dependencies --
local ClientDataStream = shared("ClientDataStream")
local SkinsConfig = shared("SkinsConfig")
local GetRemoteEvent = shared("GetRemoteEvent")
local RoundConfig = shared("RoundConfig")
local ViewportHelper = shared("ViewportHelper")

-- Remote Events --
local EquipSkinRemoteEvent = GetRemoteEvent("EquipSkin")

-- Object References --
local LocalPlayer = Players.LocalPlayer
local PlayerGui --= LocalPlayer:WaitForChild("PlayerGui")
local SkinsFolder --= ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Skins")

-- Private Variables --
local _ScreenGui = nil
local _SkinGrid = nil
local _PreviewPanel = nil
local _PreviewViewport = nil
local _EquipButton = nil
local _RarityLabel = nil
local _SkinNameLabel = nil
local _SkinCardTemplate = nil
local _SkinCards = {}
local _SelectedSkinId = nil
local _EquippedSkinId = nil
local _CurrentPreviewModel = nil
local _IsSetup = false

-- Internal Functions --

local function DebugLog(...)
	if RoundConfig.DEBUG_LOG_STATE_CHANGES then
		print("[SkinsWindowController]", ...)
	end
end

-- Creates a ViewportFrame camera for skin preview
local function SetupViewportCamera(viewport)
	local camera = Instance.new("Camera")
	camera.FieldOfView = 50
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	return camera
end

-- Displays a skin model in the viewport
local function DisplaySkinInViewport(viewport, skinId, camera)
	-- Clear existing models
	for _, child in viewport:GetChildren() do
		if child:IsA("Model") then
			child:Destroy()
		end
	end

	-- Get skin preview model
	local skinConfig = SkinsConfig.Skins[skinId]
	if not skinConfig then return nil end

	local previewModel = SkinsFolder:FindFirstChild(skinConfig.ModelName)
	if not previewModel then return nil end

	-- Use ViewportHelper to display with auto-calculated distance
	local clone = ViewportHelper.DisplayModel(viewport, previewModel, camera)
	return clone
end

-- Updates equipped indicators on all cards
local function UpdateEquippedIndicators()
	for skinId, card in pairs(_SkinCards) do
		local equippedIcon = card:FindFirstChild("EquippedIcon")
		if equippedIcon then
			equippedIcon.Visible = (skinId == _EquippedSkinId)
		end
	end
end

-- Updates the preview panel with selected skin
local function UpdatePreview(skinId)
	_SelectedSkinId = skinId
	local skinConfig = SkinsConfig.Skins[skinId]
	if not skinConfig then return end

	-- Update labels
	_SkinNameLabel.Text = skinConfig.DisplayName

	local rarity = SkinsConfig.Rarities[skinConfig.Rarity]
	if rarity then
		_RarityLabel.Text = rarity.Name
		_RarityLabel.TextColor3 = rarity.Color
		_PreviewPanel.BackgroundColor3 = rarity.Color
		print("Rarity color:", rarity.Color)
		print(rarity)
	end

	-- Update viewport
	if _CurrentPreviewModel then
		_CurrentPreviewModel:Destroy()
	end
	_CurrentPreviewModel = DisplaySkinInViewport(_PreviewViewport, skinId, _PreviewViewport.CurrentCamera)

	-- Update equip button
	if skinId == _EquippedSkinId then
		_EquipButton.Text = "Equipped"
		_EquipButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
	else
		_EquipButton.Text = "Equip"
		_EquipButton.BackgroundColor3 = Color3.fromRGB(80, 200, 80)
	end
end

-- Updates a skin card's visual properties
local function UpdateSkinCard(card, skinId)
	local skinConfig = SkinsConfig.Skins[skinId]
	if not skinConfig then return end

	-- Set background color based on rarity
	local rarity = SkinsConfig.Rarities[skinConfig.Rarity]
	if rarity then
		card.BackgroundColor3 = rarity.Color
	end

	-- Set name label
	local nameLabel = card:FindFirstChild("SkinName") or card:FindFirstChild("NameLabel")
	if nameLabel then
		nameLabel.Text = skinConfig.DisplayName
	end

	-- Update equipped indicator
	local equippedIcon = card:FindFirstChild("EquippedIcon")
	if equippedIcon then
		equippedIcon.Visible = (skinId == _EquippedSkinId)
	end
end

-- Creates a skin card for the grid
local function CreateSkinCard(skinId)
	local skinConfig = SkinsConfig.Skins[skinId]
	if not skinConfig then return nil end

	local card = _SkinCardTemplate:Clone()
	card.Name = skinId
	card.Visible = true

	-- Setup viewport preview
	local viewport = card:FindFirstChild("SkinViewport")
	if viewport then
		local camera = SetupViewportCamera(viewport)
		DisplaySkinInViewport(viewport, skinId, camera)
	end

	-- Update visual properties (background color, name, etc.)
	UpdateSkinCard(card, skinId)

	-- Setup click handler
	card.MouseButton1Click:Connect(function()
		UpdatePreview(skinId)
	end)

	card.Parent = _SkinGrid
	_SkinCards[skinId] = card

	return card
end

-- Populates the grid with unlocked skins (optimized - only creates/removes as needed)
local function PopulateGrid()
	-- Get unlocked skins from DataStream
	local stored = ClientDataStream.Stored
	if not stored then return end

	local unlocked = stored.Skins.Unlocked:Read() or {}
	_EquippedSkinId = stored.Skins.Equipped:Read() or SkinsConfig.DEFAULT_SKIN

	-- Build set of currently unlocked skins
	local unlockedSet = {}
	for _, skinId in ipairs(unlocked) do
		if SkinsConfig.Skins[skinId] then
			unlockedSet[skinId] = true
		end
	end

	-- Remove cards for skins no longer unlocked
	for skinId, card in pairs(_SkinCards) do
		if not unlockedSet[skinId] then
			card:Destroy()
			_SkinCards[skinId] = nil
		end
	end

	-- Sort skins by rarity then name for layout order
	local sortedSkins = {}
	for skinId in pairs(unlockedSet) do
		table.insert(sortedSkins, skinId)
	end

	table.sort(sortedSkins, function(a, b)
		local configA = SkinsConfig.Skins[a]
		local configB = SkinsConfig.Skins[b]
		local rarityA = SkinsConfig.Rarities[configA.Rarity]
		local rarityB = SkinsConfig.Rarities[configB.Rarity]

		if rarityA.SortOrder ~= rarityB.SortOrder then
			return rarityA.SortOrder > rarityB.SortOrder -- Higher rarity first
		end
		return a < b -- Alphabetical
	end)

	-- Create or update cards
	for index, skinId in ipairs(sortedSkins) do
		local card = _SkinCards[skinId]
		if card then
			-- Update existing card
			UpdateSkinCard(card, skinId)
			card.LayoutOrder = index
		else
			-- Create new card
			card = CreateSkinCard(skinId)
			if card then
				card.LayoutOrder = index
			end
		end
	end

	-- Select equipped skin by default if nothing selected
	if not _SelectedSkinId or not _SkinCards[_SelectedSkinId] then
		if _EquippedSkinId and _SkinCards[_EquippedSkinId] then
			UpdatePreview(_EquippedSkinId)
		elseif sortedSkins[1] then
			UpdatePreview(sortedSkins[1])
		end
	end

	UpdateEquippedIndicators()
end

-- Sets up UI references and handlers
local function SetupUI()
	if _IsSetup then return end

	PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
	SkinsFolder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Skins")

	_ScreenGui = PlayerGui:WaitForChild("SkinsWindow")
	local mainFrame = _ScreenGui:WaitForChild("MainFrame")
	local contentArea = mainFrame:WaitForChild("ContentArea")

	-- Preview panel references
	_PreviewPanel = contentArea:WaitForChild("PreviewPanel")
	_PreviewViewport = _PreviewPanel:WaitForChild("PreviewViewport")
	_EquipButton = _PreviewPanel:WaitForChild("EquipButton")
	_RarityLabel = _PreviewPanel:WaitForChild("Rarity")
	_SkinNameLabel = _PreviewPanel:WaitForChild("SkinName")

	-- Setup preview viewport camera
	SetupViewportCamera(_PreviewViewport)

	-- Grid references
	_SkinGrid = contentArea:WaitForChild("SkinGrid")
	_SkinCardTemplate = _SkinGrid:FindFirstChild("_Template")
	if _SkinCardTemplate then
		_SkinCardTemplate.Visible = false
	end

	-- Equip button handler
	_EquipButton.MouseButton1Click:Connect(function()
		if _SelectedSkinId and _SelectedSkinId ~= _EquippedSkinId then
			EquipSkinRemoteEvent:FireServer(_SelectedSkinId)
		end
	end)

	_IsSetup = true
	DebugLog("UI setup complete")
end

-- API Functions --

function SkinsWindowController:Refresh()
	PopulateGrid()
end

-- Initializers --
function SkinsWindowController:Init()
	DebugLog("Initializing...")

	-- Wait for DataStream
	task.defer(function()
		task.wait(1)

		SetupUI()

		-- Listen for equipped skin changes
		local stored = ClientDataStream.Stored
		if stored and stored.Skins then
			stored.Skins.Equipped:Changed(function(newEquipped)
				_EquippedSkinId = newEquipped
				UpdateEquippedIndicators()

				-- Update equip button if viewing this skin
				if _SelectedSkinId == newEquipped then
					_EquipButton.Text = "Equipped"
					_EquipButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
				end
			end)

			-- Initial population
			PopulateGrid()
		end
	end)
end

-- Return Module --
return SkinsWindowController
