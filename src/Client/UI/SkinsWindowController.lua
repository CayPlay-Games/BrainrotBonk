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
local ArrowsConfig = shared("ArrowsConfig")
local GetRemoteEvent = shared("GetRemoteEvent")
local RoundConfig = shared("RoundConfig")

-- Remote Events --
local EquipSkinRemoteEvent = GetRemoteEvent("EquipSkin")
local EquipArrowRemoteEvent = GetRemoteEvent("EquipArrow")

-- Private Variables --
local _ScreenGui = nil
local _MainFrame = nil
local _SkinGrid = nil
local _PreviewPanel = nil
local _PreviewImage = nil
local _EquipButton = nil
local _RarityLabel = nil
local _SkinNameLabel = nil
local _MutationLabel = nil
local _SkinCardTemplate = nil
local _SkinCards = {} -- keyed by "skinId_mutation" for skins, or "arrowId" for arrows
local _SelectedSkinId = nil
local _SelectedMutation = nil
local _EquippedSkinId = nil
local _EquippedMutation = nil
local _IsSetup = false
local _PlayerStoredDataStream = nil

-- Tab State --
local _CurrentTab = "Skins" -- "Skins" or "Arrows"
local _Sidebar = nil
local _SkinsTabButton = nil
local _ArrowsTabButton = nil

-- Arrow State --
local _SelectedArrowId = nil
local _EquippedArrowId = nil

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

-- Gets the icon for an arrow from config
local function GetArrowIcon(arrowId)
	local arrowConfig = ArrowsConfig.Arrows[arrowId]
	if arrowConfig and arrowConfig.Icon then
		return arrowConfig.Icon
	end
	return nil
end

-- Updates tab button visuals to show which is active
local function UpdateTabVisuals()
	if not _SkinsTabButton or not _ArrowsTabButton then
		return
	end

	local activeColor = Color3.fromRGB(255, 255, 255)
	local inactiveColor = Color3.fromRGB(125, 125, 125)

	if _CurrentTab == "Skins" then
		_SkinsTabButton.ImageColor3 = activeColor
		_ArrowsTabButton.ImageColor3 = inactiveColor
	else
		_SkinsTabButton.ImageColor3 = inactiveColor
		_ArrowsTabButton.ImageColor3 = activeColor
	end

	local header = _MainFrame:FindFirstChild("Header")
	local titleImage = header and header:FindFirstChild("Title")
	local titleText = titleImage and titleImage:FindFirstChild("TextLabel")
	if titleText then
		titleText.Text = "Your " .. _CurrentTab
	end
	
end

-- Updates equipped indicators on all cards
local function UpdateEquippedIndicators()
	if _CurrentTab == "Skins" then
		local equippedKey = GetCardKey(_EquippedSkinId, _EquippedMutation or "Normal")
		for cardKey, card in pairs(_SkinCards) do
			local equippedIcon = card:FindFirstChild("EquippedIcon")
			if equippedIcon then
				equippedIcon.Visible = (cardKey == equippedKey)
			end
		end
	else
		-- Arrows tab
		for cardKey, card in pairs(_SkinCards) do
			local equippedIcon = card:FindFirstChild("EquippedIcon")
			if equippedIcon then
				equippedIcon.Visible = (cardKey == _EquippedArrowId)
			end
		end
	end
end

-- Updates the preview panel with selected skin
local function UpdateSkinPreview(skinId, mutation)
	_SelectedSkinId = skinId
	_SelectedMutation = mutation or "Normal"
	_SelectedArrowId = nil -- Clear arrow selection
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

-- Updates the preview panel with selected arrow
local function UpdateArrowPreview(arrowId)
	_SelectedArrowId = arrowId
	_SelectedSkinId = nil -- Clear skin selection
	_SelectedMutation = nil
	local arrowConfig = ArrowsConfig.Arrows[arrowId]
	if not arrowConfig then
		return
	end

	-- Update name label
	_SkinNameLabel.Text = arrowConfig.DisplayName

	-- Hide mutation label for arrows
	if _MutationLabel then
		_MutationLabel.Visible = false
	end

	-- Update preview image
	local icon = GetArrowIcon(arrowId)
	if _PreviewImage and icon then
		_PreviewImage.Image = icon
	end

	-- Update equip button
	if arrowId == _EquippedArrowId then
		_EquipButton.TextLabel.Text = "Equipped"
		_EquipButton.ImageColor3 = Color3.fromRGB(100, 100, 100)
	else
		_EquipButton.TextLabel.Text = "Equip"
		_EquipButton.ImageColor3 = Color3.fromRGB(80, 200, 80)
	end
end

-- Updates the preview panel (delegates to skin or arrow)
local function UpdatePreview(skinId, mutation)
	UpdateSkinPreview(skinId, mutation)
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

-- Creates an arrow card for the grid
local function CreateArrowCard(arrowId)
	local arrowConfig = ArrowsConfig.Arrows[arrowId]
	if not arrowConfig then
		return nil
	end

	local card = _SkinCardTemplate:Clone()
	card.Name = arrowId
	card.Visible = true

	-- Setup icon preview
	local preview = card:FindFirstChild("Preview")
	if preview then
		local imageLabel = preview:FindFirstChild("ImageLabel")
		if imageLabel then
			local icon = GetArrowIcon(arrowId)
			if icon then
				imageLabel.Image = icon
			end
		end
	end


	-- Set name label
	local nameLabel = card:FindFirstChild("SkinName") or card:FindFirstChild("NameLabel")
	if nameLabel then
		nameLabel.Text = arrowConfig.DisplayName
	end

	-- Update equipped indicator
	local equippedIcon = card:FindFirstChild("EquippedIcon")
	if equippedIcon then
		equippedIcon.Visible = (arrowId == _EquippedArrowId)
	end

	-- Setup click handler
	card.MouseButton1Click:Connect(function()
		UpdateArrowPreview(arrowId)
	end)

	card.Parent = _SkinGrid
	_SkinCards[arrowId] = card

	return card
end

-- Clears all cards from the grid
local function ClearGrid()
	for cardKey, card in pairs(_SkinCards) do
		card:Destroy()
	end
	_SkinCards = {}
end

-- Populates the grid with skins
local function PopulateSkinsGrid()
	-- Read from Collections.Skins
	local ownedSkins = {}
	if _PlayerStoredDataStream.Collections and _PlayerStoredDataStream.Collections.Skins then
		ownedSkins = _PlayerStoredDataStream.Collections.Skins:Read() or {}
	end
	_EquippedSkinId = _PlayerStoredDataStream.Skins.Equipped:Read() or SkinsConfig.DEFAULT_SKIN
	_EquippedMutation = _PlayerStoredDataStream.Skins.EquippedMutation:Read() or "Normal"

	-- Build set of unlocked skin+mutation combos from Collections format
	local unlockedSet = {}
	for itemId, count in pairs(ownedSkins) do
		if count >= 1 then
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

	-- Sort by rarity, mutation, then name
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

		if rarityA.SortOrder ~= rarityB.SortOrder then
			return rarityA.SortOrder < rarityB.SortOrder
		end
		if mutationA.SortOrder ~= mutationB.SortOrder then
			return mutationA.SortOrder < mutationB.SortOrder
		end
		return a.SkinId < b.SkinId
	end)

	-- Create or update cards
	for _, combo in ipairs(sortedCombos) do
		local cardKey = combo.Key
		local card = _SkinCards[cardKey]
		if card then
			UpdateSkinCard(card, combo.SkinId, combo.Mutation)
		else
			CreateSkinCard(combo.SkinId, combo.Mutation)
		end
	end

	-- Select equipped skin by default if nothing selected
	local selectedKey = _SelectedSkinId and GetCardKey(_SelectedSkinId, _SelectedMutation or "Normal")
	if not selectedKey or not _SkinCards[selectedKey] then
		local equippedKey = GetCardKey(_EquippedSkinId, _EquippedMutation)
		if _SkinCards[equippedKey] then
			UpdateSkinPreview(_EquippedSkinId, _EquippedMutation)
		elseif sortedCombos[1] then
			UpdateSkinPreview(sortedCombos[1].SkinId, sortedCombos[1].Mutation)
		end
	end
end

-- Populates the grid with arrows
local function PopulateArrowsGrid()
	-- Read from Collections.Arrows
	local ownedArrows = {}
	if _PlayerStoredDataStream.Collections and _PlayerStoredDataStream.Collections.Arrows then
		ownedArrows = _PlayerStoredDataStream.Collections.Arrows:Read() or {}
	end
	_EquippedArrowId = _PlayerStoredDataStream.Arrows.Equipped:Read() or ArrowsConfig.DEFAULT_ARROW

	-- Build set of unlocked arrows
	local unlockedSet = {}
	for arrowId, count in pairs(ownedArrows) do
		if count >= 1 and ArrowsConfig.Arrows[arrowId] then
			unlockedSet[arrowId] = true
		end
	end

	-- Remove cards for arrows no longer unlocked
	for cardKey, card in pairs(_SkinCards) do
		if not unlockedSet[cardKey] then
			card:Destroy()
			_SkinCards[cardKey] = nil
		end
	end

	-- Sort by rarity then name
	local sortedArrows = {}
	for arrowId in pairs(unlockedSet) do
		table.insert(sortedArrows, arrowId)
	end

	-- Create cards for arrows
	for _, arrowId in ipairs(sortedArrows) do
		if not _SkinCards[arrowId] then
			CreateArrowCard(arrowId)
		end
	end

	-- Select equipped arrow by default if nothing selected
	if not _SelectedArrowId or not _SkinCards[_SelectedArrowId] then
		if _SkinCards[_EquippedArrowId] then
			UpdateArrowPreview(_EquippedArrowId)
		elseif sortedArrows[1] then
			UpdateArrowPreview(sortedArrows[1])
		end
	end
end

-- Populates the grid based on current tab
local function PopulateGrid()
	if not _PlayerStoredDataStream then
		return
	end

	-- Clear grid when switching tabs (cards are incompatible between tabs)
	ClearGrid()

	if _CurrentTab == "Skins" then
		PopulateSkinsGrid()
	else
		PopulateArrowsGrid()
	end

	UpdateEquippedIndicators()
end

-- Sets up UI references and handlers
local function SetupUI(screenGui)
	if _IsSetup then
		return
	end

	_ScreenGui = screenGui
	_MainFrame = _ScreenGui:WaitForChild("MainFrame")
	local contentArea = _MainFrame:WaitForChild("ContentArea")

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

	-- Sidebar/tab references
	_Sidebar = _MainFrame:FindFirstChild("Sidebar")
	if _Sidebar then
		_SkinsTabButton = _Sidebar:FindFirstChild("Skins")
		_ArrowsTabButton = _Sidebar:FindFirstChild("ArrowsTab")
		print("[SkinsWindowController] Found Sidebar, SkinsTab:", _SkinsTabButton, "ArrowsTab:", _ArrowsTabButton)

		-- Tab click handlers
		if _SkinsTabButton then
			_SkinsTabButton.MouseButton1Click:Connect(function()
				if _CurrentTab ~= "Skins" then
					_CurrentTab = "Skins"
					UpdateTabVisuals()
					PopulateGrid()
				end
			end)
		end

		if _ArrowsTabButton then
			_ArrowsTabButton.MouseButton1Click:Connect(function()
				if _CurrentTab ~= "Arrows" then
					_CurrentTab = "Arrows"
					UpdateTabVisuals()
					PopulateGrid()
				end
			end)
		end

		-- Set initial tab visuals
		UpdateTabVisuals()
	else
		warn("[SkinsWindowController] Sidebar not found in ContentArea")
	end

	-- Equip button handler (handles both skins and arrows)
	_EquipButton.MouseButton1Click:Connect(function()
		if _CurrentTab == "Skins" then
			local isEquipped = _SelectedSkinId == _EquippedSkinId and _SelectedMutation == _EquippedMutation
			if _SelectedSkinId and not isEquipped then
				EquipSkinRemoteEvent:FireServer(_SelectedSkinId, _SelectedMutation or "Normal")
			end
		else
			-- Arrows tab
			local isEquipped = _SelectedArrowId == _EquippedArrowId
			if _SelectedArrowId and not isEquipped then
				EquipArrowRemoteEvent:FireServer(_SelectedArrowId)
			end
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
				if _CurrentTab == "Skins" then
					UpdateEquippedIndicators()

					-- Update equip button if viewing this skin+mutation combo
					local isNowEquipped = _SelectedSkinId == _EquippedSkinId and _SelectedMutation == _EquippedMutation
					if isNowEquipped then
						_EquipButton.TextLabel.Text = "Equipped"
						_EquipButton.ImageColor3 = Color3.fromRGB(100, 100, 100)
					end
				end
			end)

			_PlayerStoredDataStream.Skins.EquippedMutation:Changed(function(newMutation)
				_EquippedMutation = newMutation
				if _CurrentTab == "Skins" then
					UpdateEquippedIndicators()

					-- Update equip button if viewing this skin+mutation combo
					local isNowEquipped = _SelectedSkinId == _EquippedSkinId and _SelectedMutation == _EquippedMutation
					if isNowEquipped then
						_EquipButton.TextLabel.Text = "Equipped"
						_EquipButton.ImageColor3 = Color3.fromRGB(100, 100, 100)
					end
				end
			end)

			-- Listen for collection changes (new skins unlocked)
			if _PlayerStoredDataStream.Collections and _PlayerStoredDataStream.Collections.Skins then
				_PlayerStoredDataStream.Collections.Skins:Changed(function()
					if _CurrentTab == "Skins" then
						PopulateGrid()
					end
				end)
			end

			-- Listen for arrow changes
			if _PlayerStoredDataStream.Arrows then
				_PlayerStoredDataStream.Arrows.Equipped:Changed(function(newEquipped)
					_EquippedArrowId = newEquipped
					if _CurrentTab == "Arrows" then
						UpdateEquippedIndicators()

						-- Update equip button if viewing this arrow
						if _SelectedArrowId == _EquippedArrowId then
							_EquipButton.TextLabel.Text = "Equipped"
							_EquipButton.ImageColor3 = Color3.fromRGB(100, 100, 100)
						end
					end
				end)
			end

			-- Listen for collection changes (new arrows unlocked)
			if _PlayerStoredDataStream.Collections and _PlayerStoredDataStream.Collections.Arrows then
				_PlayerStoredDataStream.Collections.Arrows:Changed(function()
					if _CurrentTab == "Arrows" then
						PopulateGrid()
					end
				end)
			end

			-- Initial population
			PopulateGrid()
		end)
	end)
end

-- Return Module --
return SkinsWindowController
