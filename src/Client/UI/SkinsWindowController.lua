--[[
	SkinsWindowController.lua

	Description:
		Manages the SkinsWindow UI - populates grid with unlocked skins,
		handles skin selection/preview, and equipping.
--]]

-- Root --
local SkinsWindowController = {}

-- Dependencies --
local OnLocalPlayerStoredDataStreamLoaded = shared("OnLocalPlayerStoredDataStreamLoaded")
local UIController = shared("UIController")
local SkinsConfig = shared("SkinsConfig")
local GetRemoteEvent = shared("GetRemoteEvent")
local RoundConfig = shared("RoundConfig")

-- Remote Events --
local EquipSkinRemoteEvent = GetRemoteEvent("EquipSkin")

-- Private Variables --
local _ScreenGui = nil
local _SkinGrid = nil
local _PreviewPanel = nil
local _PreviewImage = nil
local _EquipButton = nil
local _RarityLabel = nil
local _SkinNameLabel = nil
local _MutationLabel = nil
local _SkinCardTemplate = nil
local _SkinCards = {} -- keyed by "skinId_mutation"
local _SelectedSkinId = nil
local _SelectedMutation = nil
local _EquippedSkinId = nil
local _EquippedMutation = nil
local _IsSetup = false
local _PlayerStoredDataStream = nil

-- Internal Functions --

local function DebugLog(...)
	if RoundConfig.DEBUG_LOG_STATE_CHANGES then
		print("[SkinsWindowController]", ...)
	end
end

-- Generates a unique key for skin+mutation combo
local function GetCardKey(skinId, mutation)
	return skinId .. "_" .. mutation
end

-- Gets the icon for a skin from config
local function GetSkinIcon(skinId)
	local skinConfig = SkinsConfig.Skins[skinId]
	if skinConfig and skinConfig.Icon then
		return skinConfig.Icon
	end
	return nil
end

-- Updates equipped indicators on all cards
local function UpdateEquippedIndicators()
	local equippedKey = GetCardKey(_EquippedSkinId, _EquippedMutation or "Normal")
	for cardKey, card in pairs(_SkinCards) do
		local equippedIcon = card:FindFirstChild("EquippedIcon")
		if equippedIcon then
			equippedIcon.Visible = (cardKey == equippedKey)
		end
	end
end

-- Updates the preview panel with selected skin
local function UpdatePreview(skinId, mutation)
	_SelectedSkinId = skinId
	_SelectedMutation = mutation or "Normal"
	local skinConfig = SkinsConfig.Skins[skinId]
	if not skinConfig then
		return
	end

	-- Update skin name label
	_SkinNameLabel.Text = skinConfig.DisplayName

	-- Update mutation label if it exists
	local mutationConfig = SkinsConfig.Mutations[_SelectedMutation]
	if _MutationLabel and mutationConfig then
		if _SelectedMutation == "Normal" then
			_MutationLabel.Visible = false
		else
			_MutationLabel.Text = mutationConfig.Name
			_MutationLabel.TextColor3 = mutationConfig.Color
			_MutationLabel.Visible = true
		end
	end

	local rarity = SkinsConfig.Rarities[skinConfig.Rarity]
	if rarity then
		_RarityLabel.Text = rarity.Name
		_RarityLabel.TextColor3 = rarity.Color
		_PreviewPanel.BackgroundColor3 = rarity.Color
	end

	-- Update preview image
	local icon = GetSkinIcon(skinId)
	if _PreviewImage and icon then
		_PreviewImage.Image = icon
	end

	-- Update equip button
	if skinId == _EquippedSkinId and _SelectedMutation == _EquippedMutation then
		_EquipButton.TextLabel.Text = "Equipped"
		_EquipButton.ImageColor3 = Color3.fromRGB(100, 100, 100)
	else
		_EquipButton.TextLabel.Text = "Equip"
		_EquipButton.ImageColor3 = Color3.fromRGB(80, 200, 80)
	end
end

-- Updates a skin card's visual properties
local function UpdateSkinCard(card, skinId, mutation)
	local skinConfig = SkinsConfig.Skins[skinId]
	if not skinConfig then
		return
	end
	mutation = mutation or "Normal"

	-- Set background color based on rarity
	local mutationConfig = SkinsConfig.Mutations[mutation]
	local rarity = SkinsConfig.Rarities[skinConfig.Rarity]
	if rarity then
		card.ImageColor3 = rarity.Color
	end

	-- Set name label (show mutation for non-Normal variants)
	local nameLabel = card:FindFirstChild("SkinName") or card:FindFirstChild("NameLabel")
	if nameLabel then
		if mutation == "Normal" then
			nameLabel.Text = skinConfig.DisplayName
		else
			nameLabel.Text = skinConfig.DisplayName .. " (" .. mutationConfig.Name .. ")"
		end
	end

	-- Update equipped indicator
	local equippedKey = GetCardKey(_EquippedSkinId, _EquippedMutation or "Normal")
	local cardKey = GetCardKey(skinId, mutation)
	local equippedIcon = card:FindFirstChild("EquippedIcon")
	if equippedIcon then
		equippedIcon.Visible = (cardKey == equippedKey)
	end
end

-- Creates a skin card for the grid
local function CreateSkinCard(skinId, mutation)
	local skinConfig = SkinsConfig.Skins[skinId]
	if not skinConfig then
		return nil
	end
	mutation = mutation or "Normal"

	local cardKey = GetCardKey(skinId, mutation)
	local card = _SkinCardTemplate:Clone()
	card.Name = cardKey
	card.Visible = true

	-- Setup icon preview
	local preview = card:FindFirstChild("Preview")
	if preview then
		local imageLabel = preview:FindFirstChild("ImageLabel")
		if imageLabel then
			local icon = GetSkinIcon(skinId)
			if icon then
				imageLabel.Image = icon
			end
		end
	end

	-- Update visual properties (background color, name, etc.)
	UpdateSkinCard(card, skinId, mutation)

	-- Setup click handler
	card.MouseButton1Click:Connect(function()
		UpdatePreview(skinId, mutation)
	end)

	card.Parent = _SkinGrid
	_SkinCards[cardKey] = card

	return card
end

-- Populates the grid with unlocked skins (optimized - only creates/removes as needed)
local function PopulateGrid()
	-- Get skins data from DataStream
	if not _PlayerStoredDataStream then
		return
	end

	-- Read from Collections.Skins
	local ownedSkins = {}
	if _PlayerStoredDataStream.Collections and _PlayerStoredDataStream.Collections.Skins then
		ownedSkins = _PlayerStoredDataStream.Collections.Skins:Read() or {}
	end
	_EquippedSkinId = _PlayerStoredDataStream.Skins.Equipped:Read() or SkinsConfig.DEFAULT_SKIN
	_EquippedMutation = _PlayerStoredDataStream.Skins.EquippedMutation:Read() or "Normal"

	-- Build set of unlocked skin+mutation combos from Collections format
	-- Collections format: { ["SkinId_Mutation"] = count }
	local unlockedSet = {}
	for itemId, count in pairs(ownedSkins) do
		if count >= 1 then
			-- Parse "SkinId_MutationId" format
			local skinId, mutationId = string.match(itemId, "^(.+)_([^_]+)$")
			if skinId and mutationId and SkinsConfig.Skins[skinId] then
				local cardKey = GetCardKey(skinId, mutationId)
				unlockedSet[cardKey] = { SkinId = skinId, Mutation = mutationId }
			end
		end
	end

	-- Remove cards for combos no longer unlocked
	for cardKey, card in pairs(_SkinCards) do
		if not unlockedSet[cardKey] then
			card:Destroy()
			_SkinCards[cardKey] = nil
		end
	end

	-- Sort by mutation sort order first, then rarity, then name
	local sortedCombos = {}
	for cardKey, data in pairs(unlockedSet) do
		table.insert(sortedCombos, { Key = cardKey, SkinId = data.SkinId, Mutation = data.Mutation })
	end

	table.sort(sortedCombos, function(a, b)
		local configA = SkinsConfig.Skins[a.SkinId]
		local configB = SkinsConfig.Skins[b.SkinId]
		local rarityA = SkinsConfig.Rarities[configA.Rarity]
		local rarityB = SkinsConfig.Rarities[configB.Rarity]
		local mutationA = SkinsConfig.Mutations[a.Mutation] or SkinsConfig.Mutations.Normal
		local mutationB = SkinsConfig.Mutations[b.Mutation] or SkinsConfig.Mutations.Normal

		
		-- Sort by rarity (higher rarity first)
		if rarityA.SortOrder ~= rarityB.SortOrder then
			return rarityA.SortOrder > rarityB.SortOrder
		end
		-- Then by mutation first (higher mutation sort order = rarer = first)
		if mutationA.SortOrder ~= mutationB.SortOrder then
			return mutationA.SortOrder > mutationB.SortOrder
		end
		-- Then alphabetically by skin name
		return a.SkinId < b.SkinId
	end)

	-- Create or update cards
	for index, combo in ipairs(sortedCombos) do
		local cardKey = combo.Key
		local card = _SkinCards[cardKey]
		if card then
			-- Update existing card
			UpdateSkinCard(card, combo.SkinId, combo.Mutation)
		else
			-- Create new card
			card = CreateSkinCard(combo.SkinId, combo.Mutation)
		end
	end

	-- Select equipped skin by default if nothing selected
	local selectedKey = _SelectedSkinId and GetCardKey(_SelectedSkinId, _SelectedMutation or "Normal")
	if not selectedKey or not _SkinCards[selectedKey] then
		local equippedKey = GetCardKey(_EquippedSkinId, _EquippedMutation)
		if _SkinCards[equippedKey] then
			UpdatePreview(_EquippedSkinId, _EquippedMutation)
		elseif sortedCombos[1] then
			UpdatePreview(sortedCombos[1].SkinId, sortedCombos[1].Mutation)
		end
	end

	UpdateEquippedIndicators()
end

-- Sets up UI references and handlers
local function SetupUI(screenGui)
	if _IsSetup then
		return
	end

	_ScreenGui = screenGui
	local mainFrame = _ScreenGui:WaitForChild("MainFrame")
	local contentArea = mainFrame:WaitForChild("ContentArea")

	-- Preview panel references
	_PreviewPanel = contentArea:WaitForChild("PreviewPanel")
	_PreviewImage = _PreviewPanel:WaitForChild("ImageLabel")
	_EquipButton = _PreviewPanel:WaitForChild("EquipButton")
	_RarityLabel = _PreviewPanel:WaitForChild("Rarity")
	_SkinNameLabel = _PreviewPanel:WaitForChild("SkinName")
	_MutationLabel = _PreviewPanel:FindFirstChild("MutationLabel") -- Optional

	-- Grid references
	_SkinGrid = contentArea:WaitForChild("SkinGrid")
	_SkinCardTemplate = _SkinGrid:FindFirstChild("_Template")
	if _SkinCardTemplate then
		_SkinCardTemplate.Visible = false
	end

	-- Equip button handler
	_EquipButton.MouseButton1Click:Connect(function()
		local isEquipped = _SelectedSkinId == _EquippedSkinId and _SelectedMutation == _EquippedMutation
		if _SelectedSkinId and not isEquipped then
			EquipSkinRemoteEvent:FireServer(_SelectedSkinId, _SelectedMutation or "Normal")
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

	OnLocalPlayerStoredDataStreamLoaded(function(PlayerStoredDataStream)
		_PlayerStoredDataStream = PlayerStoredDataStream

		UIController:WhenScreenGuiReady("SkinsWindow", function(screenGui)
			SetupUI(screenGui)

			-- Listen for skin changes
			_PlayerStoredDataStream.Skins.Equipped:Changed(function(newEquipped)
				_EquippedSkinId = newEquipped
				UpdateEquippedIndicators()

				-- Update equip button if viewing this skin+mutation combo
				local isNowEquipped = _SelectedSkinId == _EquippedSkinId and _SelectedMutation == _EquippedMutation
				if isNowEquipped then
					_EquipButton.TextLabel.Text = "Equipped"
					_EquipButton.ImageColor3 = Color3.fromRGB(100, 100, 100)
				end
			end)

			_PlayerStoredDataStream.Skins.EquippedMutation:Changed(function(newMutation)
				_EquippedMutation = newMutation
				UpdateEquippedIndicators()

				-- Update equip button if viewing this skin+mutation combo
				local isNowEquipped = _SelectedSkinId == _EquippedSkinId and _SelectedMutation == _EquippedMutation
				if isNowEquipped then
					_EquipButton.TextLabel.Text = "Equipped"
					_EquipButton.ImageColor3 = Color3.fromRGB(100, 100, 100)
				end
			end)

			-- Listen for collection changes (new skins unlocked)
			if _PlayerStoredDataStream.Collections and _PlayerStoredDataStream.Collections.Skins then
				_PlayerStoredDataStream.Collections.Skins:Changed(function()
					PopulateGrid()
				end)
			end

			-- Initial population
			PopulateGrid()
		end)
	end)
end

-- Return Module --
return SkinsWindowController
