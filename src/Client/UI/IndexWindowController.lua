--[[
	IndexWindowController.lua

	Description:
		Manages the IndexWindow UI - displays ALL skins as a collection index.
		Shows collected skins normally, uncollected skins "blacked out".
		Includes mutation variant filtering via sidebar tabs.
--]]

-- Root --
local IndexWindowController = {}

-- Dependencies --
local OnLocalPlayerStoredDataStreamLoaded = shared("OnLocalPlayerStoredDataStreamLoaded")
local UIController = shared("UIController")
local SkinsConfig = shared("SkinsConfig")
local TitlesConfig = shared("TitlesConfig")
local RoundConfig = shared("RoundConfig")
local GetRemoteEvent = shared("GetRemoteEvent")

-- Private Variables --
local _ScreenGui = nil
local _GridArea = nil
local _CardTemplate = nil
local _IndexCards = {} -- { [skinId] = card }
local _SelectedMutation = "Normal"
local _SelectedTopTab = "Skins"

-- Titles Variables
local _SkinsContent = nil
local _TitlesContent = nil
local _TitlesGridArea = nil
local _TitleCardTemplate = nil
local _TitleCards = {} -- { [titleId] = card }
local _EquipTitleRemoteEvent = nil

-- UI References
local _Header = nil
local _CountLabel = nil
local _IndexTitle = nil
local _IndexSubtitle = nil
local _Sidebar = nil
local _BottomBar = nil
local _ProgressBarFill = nil
local _ProgressCount = nil
local _MilestoneLabel = nil
local _TopTabs = nil

local _IsSetup = false
local _PlayerStoredDataStream = nil

-- Cached config counts (computed once on first use)
local _CachedSkinCount = nil
local _CachedMutationCount = nil
local _CachedCollectionLookup = nil -- { [skinId] = { [mutation] = true } }
local _CachedMutationCounts = nil -- { [mutation] = count }
local _CachedSortedSkinIds = nil -- Pre-sorted skin IDs array

-- Constants
local LOCKED_COLOR = Color3.fromRGB(80, 80, 80)

-- Sidebar tab configuration
local SIDEBAR_TABS = {
	{ name = "NormalTab", mutation = "Normal" },
	{ name = "LavaTab", mutation = "Lava" },
	{ name = "GoldenTab", mutation = "Golden" },
	{ name = "DiamondTab", mutation = "Diamond" },
	{ name = "RainbowTab", mutation = "Rainbow" },
	{ name = "GalaxyTab", mutation = "Galaxy" },
}

-- Internal Functions --

local function DebugLog(...)
	if RoundConfig.DEBUG_LOG_STATE_CHANGES then
		print("[IndexWindowController]", ...)
	end
end

-- Helper to safely get collected skins data
local function GetCollectedData()
	if _PlayerStoredDataStream and _PlayerStoredDataStream.Skins then
		return _PlayerStoredDataStream.Skins.Collected:Read() or {}
	end
	return {}
end

-- Invalidates collection cache (call when collected data changes)
local function InvalidateCollectionCache()
	_CachedCollectionLookup = nil
	_CachedMutationCounts = nil
end

-- Builds efficient lookup structures for collection data (lazy cached)
local function BuildCollectionLookup()
	if _CachedCollectionLookup then
		return _CachedCollectionLookup, _CachedMutationCounts
	end

	_CachedCollectionLookup = {}
	_CachedMutationCounts = {}

	-- Initialize mutation counts
	for mutation in pairs(SkinsConfig.Mutations) do
		_CachedMutationCounts[mutation] = 0
	end

	for _, entry in ipairs(GetCollectedData()) do
		_CachedCollectionLookup[entry.SkinId] = {}
		for _, mutation in ipairs(entry.Mutations) do
			_CachedCollectionLookup[entry.SkinId][mutation] = true
			_CachedMutationCounts[mutation] = _CachedMutationCounts[mutation] + 1
		end
	end

	return _CachedCollectionLookup, _CachedMutationCounts
end

-- Gets the icon for a skin from config
local function GetSkinIcon(skinId)
	local skinConfig = SkinsConfig.Skins[skinId]
	if skinConfig and skinConfig.Icon then
		return skinConfig.Icon
	end
	return nil
end

local function FindPreviewImage(card)
	return card:FindFirstChild("PreviewIcon", true)
		or card:FindFirstChild("ImageLabel", true)
		or card:FindFirstChild("ItemImage", true)
end

local function IsImageObject(instance)
	return instance and (instance:IsA("ImageLabel") or instance:IsA("ImageButton"))
end

-- Checks if a skin+mutation combo is collected (O(1) lookup)
local function IsCollected(skinId, mutation)
	local lookup = BuildCollectionLookup()
	return lookup[skinId] and lookup[skinId][mutation] or false
end

-- Gets count of collected skins for a specific mutation (O(1) lookup)
local function GetCollectedMutationCount(mutation)
	local _, counts = BuildCollectionLookup()
	return counts[mutation] or 0
end

-- Gets total number of skins defined in config (cached)
local function GetTotalSkinCount()
	if not _CachedSkinCount then
		_CachedSkinCount = 0
		for _ in pairs(SkinsConfig.Skins) do
			_CachedSkinCount = _CachedSkinCount + 1
		end
	end
	return _CachedSkinCount
end

-- Gets total mutation count (cached)
local function GetTotalMutationCount()
	if not _CachedMutationCount then
		_CachedMutationCount = 0
		for _ in pairs(SkinsConfig.Mutations) do
			_CachedMutationCount = _CachedMutationCount + 1
		end
	end
	return _CachedMutationCount
end

-- Gets sorted skin IDs by rarity (cached, since SkinsConfig is static)
local function GetSortedSkinIds()
	if _CachedSortedSkinIds then
		return _CachedSortedSkinIds
	end

	_CachedSortedSkinIds = {}
	for skinId in pairs(SkinsConfig.Skins) do
		table.insert(_CachedSortedSkinIds, skinId)
	end

	table.sort(_CachedSortedSkinIds, function(a, b)
		local configA = SkinsConfig.Skins[a]
		local configB = SkinsConfig.Skins[b]
		local rarityA = SkinsConfig.Rarities[configA.Rarity]
		local rarityB = SkinsConfig.Rarities[configB.Rarity]

		if rarityA.SortOrder ~= rarityB.SortOrder then
			return rarityA.SortOrder > rarityB.SortOrder -- Higher rarity first
		end
		return a < b -- Alphabetical
	end)

	return _CachedSortedSkinIds
end

-- Gets total count of all possible skin+mutation combos (for header display)
local function GetTotalPossibleCount()
	return GetTotalSkinCount() * GetTotalMutationCount()
end

-- Gets total collected across all mutations (for header display)
local function GetTotalCollectedCount()
	local count = 0
	for _, entry in ipairs(GetCollectedData()) do
		count = count + #entry.Mutations
	end
	return count
end

-- Applies blacked out effect for uncollected skins
local function ApplyLockedEffect(card)
	local previewContainer = card:FindFirstChild("ItemViewport") or FindPreviewImage(card)
	if previewContainer and previewContainer:IsA("GuiObject") then
		-- Check if overlay already exists
		local existingOverlay = previewContainer:FindFirstChild("LockedOverlay")
		if not existingOverlay then
			local overlay = Instance.new("Frame")
			overlay.Name = "LockedOverlay"
			overlay.Size = UDim2.new(1, 0, 1, 0)
			overlay.BackgroundColor3 = Color3.new(0, 0, 0)
			overlay.BackgroundTransparency = 0.2
			overlay.ZIndex = 10
			overlay.Parent = previewContainer

			local UICorner = Instance.new("UICorner")
			UICorner.CornerRadius = UDim.new(0, 12)
			UICorner.Parent = overlay
		end
	end

	local previewImage = FindPreviewImage(card)
	if IsImageObject(previewImage) then
		previewImage.ImageColor3 = LOCKED_COLOR
	end

	-- Gray out text labels
	local itemName = card:FindFirstChild("ItemName")
	if itemName then
		itemName.TextColor3 = LOCKED_COLOR
	end

	local rarityLabel = card:FindFirstChild("RarityLabel")
	if rarityLabel then
		rarityLabel.TextColor3 = LOCKED_COLOR
	end

	local defaultLabel = card:FindFirstChild("DefaultLabel")
	if defaultLabel then
		defaultLabel.TextColor3 = LOCKED_COLOR
	end
end

-- Removes locked effect (for collected skins)
local function RemoveLockedEffect(card)
	local previewContainer = card:FindFirstChild("ItemViewport") or FindPreviewImage(card)
	if previewContainer then
		local overlay = previewContainer:FindFirstChild("LockedOverlay")
		if overlay then
			overlay:Destroy()
		end
	end

	local previewImage = FindPreviewImage(card)
	if IsImageObject(previewImage) then
		previewImage.ImageColor3 = Color3.fromRGB(255, 255, 255)
	end
end

-- Creates an index card for a skin
local function CreateIndexCard(skinId)
	local skinConfig = SkinsConfig.Skins[skinId]
	if not skinConfig then
		return nil
	end

	local card = _CardTemplate:Clone()
	card.Name = skinId
	card.Visible = true

	-- Set item name
	local itemName = card:FindFirstChild("ItemName")
	if itemName then
		itemName.Text = skinConfig.DisplayName
	end

	-- Set rarity label
	local rarityLabel = card:FindFirstChild("RarityLabel")
	if rarityLabel then
		local rarity = SkinsConfig.Rarities[skinConfig.Rarity]
		if rarity then
			rarityLabel.Text = rarity.Name
			rarityLabel.TextColor3 = rarity.Color
		end
	end

	-- Set mutation label (DefaultLabel)
	local defaultLabel = card:FindFirstChild("DefaultLabel")
	if defaultLabel then
		local mutation = SkinsConfig.Mutations[_SelectedMutation]
		if mutation then
			defaultLabel.Text = mutation.Name
			defaultLabel.TextColor3 = mutation.Color
		end
	end

	-- Setup image preview
	local previewImage = FindPreviewImage(card)
	local icon = GetSkinIcon(skinId)
	if IsImageObject(previewImage) and icon then
		previewImage.Image = icon
		previewImage.ImageColor3 = Color3.fromRGB(255, 255, 255)
	end

	-- Apply locked effect if not collected
	local isCollected = IsCollected(skinId, _SelectedMutation)
	if not isCollected then
		ApplyLockedEffect(card)
	end

	card.Parent = _GridArea
	_IndexCards[skinId] = card

	return card
end

-- Updates progress bar and count
local function UpdateProgress()
	local totalCollected = GetTotalCollectedCount()
	local totalPossible = GetTotalPossibleCount()

	-- Header shows total collected / total possible in game
	if _CountLabel then
		_CountLabel.Text = totalCollected .. "/" .. totalPossible
	end

	-- Bottom bar shows mutation-specific progress:
	-- How many skins with this mutation variant collected out of total skins
	local totalSkinCount = GetTotalSkinCount()
	local mutationCollected = GetCollectedMutationCount(_SelectedMutation)

	if _ProgressCount then
		_ProgressCount.Text = mutationCollected .. "/" .. totalSkinCount
	end

	if _ProgressBarFill then
		local ratio = totalSkinCount > 0 and (mutationCollected / totalSkinCount) or 0
		_ProgressBarFill.Size = UDim2.new(ratio, 0, 1, 0)
	end

	if _MilestoneLabel then
		local mutation = SkinsConfig.Mutations[_SelectedMutation]
		local mutationName = mutation and mutation.Name or _SelectedMutation
		_MilestoneLabel.Text = mutationName .. " Brainrots collected"
	end

	if _IndexSubtitle then
		_IndexSubtitle.Text = "All Brainrots"
	end
end

-- Populates grid with all skins
local function PopulateGrid()
	-- Clear existing cards
	for _, card in pairs(_IndexCards) do
		card:Destroy()
	end
	_IndexCards = {}

	-- Create cards for each skin (using cached sorted order)
	local sortedSkins = GetSortedSkinIds()
	for index, skinId in ipairs(sortedSkins) do
		local card = CreateIndexCard(skinId)
		if card then
			card.LayoutOrder = index
		end
	end

	UpdateProgress()
end

-- Updates sidebar tab visuals
local function UpdateSidebarTabs()
	if not _Sidebar then
		return
	end

	for _, tabInfo in ipairs(SIDEBAR_TABS) do
		local tab = _Sidebar:FindFirstChild(tabInfo.name)
		if tab then
			-- Visual feedback for selected tab
			if tabInfo.mutation == _SelectedMutation then
				tab.BackgroundTransparency = 0
			else
				tab.BackgroundTransparency = 0.3
			end
		end
	end
end

-- Handles sidebar tab click
local function OnMutationTabClicked(mutation)
	_SelectedMutation = mutation
	UpdateSidebarTabs()
	PopulateGrid()
	DebugLog("Selected mutation:", mutation)
end

-- Sets up sidebar tab click handlers
local function SetupSidebarTabs()
	if not _Sidebar then
		DebugLog("Sidebar not found!")
		return
	end

	for _, tabInfo in ipairs(SIDEBAR_TABS) do
		local tab = _Sidebar:FindFirstChild(tabInfo.name)
		if tab then
			tab.MouseButton1Click:Connect(function()
				OnMutationTabClicked(tabInfo.mutation)
			end)
		end
	end

	UpdateSidebarTabs()
end

-- Creates a title card for the titles grid
local function CreateTitleCard(titleId, titleConfig, isEquipped, isUnlocked)
	if not _TitleCardTemplate then
		return nil
	end

	local card = _TitleCardTemplate:Clone()
	card.Name = titleId
	card.Visible = true

	local lockedColor = Color3.fromRGB(138, 138, 138)

	-- Set title label
	local textContainer = card:FindFirstChild("TextContainer")
	if textContainer then
		local titleLabel = textContainer:FindFirstChild("TitleLabel")
		if titleLabel then
			titleLabel.Text = titleConfig.DisplayName
			titleLabel.TextColor3 = isUnlocked and titleConfig.Color or lockedColor
		end

		local subtitleLabel = textContainer:FindFirstChild("SubtitleLabel")
		if subtitleLabel then
			subtitleLabel.Text = titleConfig.Description or ""
		end
	end

	-- Apply locked color to the card frame if not unlocked
	if not isUnlocked then
		card.BackgroundColor3 = lockedColor
	end

	-- Configure equip button
	local equipButton = card:FindFirstChild("EquipButton")
	if equipButton then
		if not isUnlocked then
			equipButton.Text = "Locked"
			equipButton.BackgroundColor3 = lockedColor
		elseif isEquipped then
			equipButton.Text = "Equipped"
			equipButton.BackgroundColor3 = Color3.fromRGB(200, 80, 80)
		else
			equipButton.Text = "Equip"
			equipButton.BackgroundColor3 = Color3.fromRGB(80, 200, 80)

			-- Only connect handler for equippable (unlocked & not equipped) buttons
			equipButton.MouseButton1Click:Connect(function()
				if _EquipTitleRemoteEvent then
					_EquipTitleRemoteEvent:FireServer(titleId)
				end
			end)
		end
	end

	card.Parent = _TitlesGridArea
	_TitleCards[titleId] = card

	return card
end

-- Populates the titles grid with all titles
local function PopulateTitlesGrid()
	if not _TitleCardTemplate then
		return
	end

	-- Clear existing cards
	for _, card in pairs(_TitleCards) do
		card:Destroy()
	end
	_TitleCards = {}

	-- Get unlocked titles and equipped title from player data
	local unlocked = {}
	local equipped = nil
	if _PlayerStoredDataStream and _PlayerStoredDataStream.Titles then
		unlocked = _PlayerStoredDataStream.Titles.Unlocked:Read() or {}
		equipped = _PlayerStoredDataStream.Titles.Equipped:Read()
	end

	-- Collect all titles and sort them (unlocked first, then locked)
	local sortedTitles = {}
	for titleId, titleConfig in pairs(TitlesConfig.Titles) do
		local isUnlocked = table.find(unlocked, titleId) ~= nil
		table.insert(sortedTitles, {
			id = titleId,
			config = titleConfig,
			isUnlocked = isUnlocked,
		})
	end

	table.sort(sortedTitles, function(a, b)
		-- Unlocked (1) before locked (2)
		local orderA = a.isUnlocked and 1 or 2
		local orderB = b.isUnlocked and 1 or 2
		if orderA ~= orderB then
			return orderA < orderB
		end
		-- Alphabetical by display name within same unlock status
		return a.config.DisplayName < b.config.DisplayName
	end)

	-- Create cards for all titles
	for index, titleData in ipairs(sortedTitles) do
		local isEquipped = equipped == titleData.id
		local card = CreateTitleCard(titleData.id, titleData.config, isEquipped, titleData.isUnlocked)
		if card then
			card.LayoutOrder = index
		end
	end

	DebugLog("Populated titles grid with", #sortedTitles, "titles")
end

-- Switches between Skins and Titles tabs
local function SwitchToTab(tabName)
	_SelectedTopTab = tabName

	if tabName == "Skins" then
		if _SkinsContent then
			_SkinsContent.Visible = true
		end
		if _TitlesContent then
			_TitlesContent.Visible = false
		end
		if _Sidebar then
			_Sidebar.Visible = true
		end
		PopulateGrid()
	elseif tabName == "Titles" then
		if _SkinsContent then
			_SkinsContent.Visible = false
		end
		if _TitlesContent then
			_TitlesContent.Visible = true
		end
		if _Sidebar then
			_Sidebar.Visible = false
		end
		PopulateTitlesGrid()
	end

	DebugLog("Selected top tab:", tabName)
end

-- Sets up top tabs (Skins/Titles)
local function SetupTopTabs()
	if not _TopTabs then
		return
	end

	local skinsTab = _TopTabs:FindFirstChild("SkinsTopTab")
	local titlesTab = _TopTabs:FindFirstChild("TitlesTopTab")

	if skinsTab then
		skinsTab.MouseButton1Click:Connect(function()
			SwitchToTab("Skins")
		end)
	end

	if titlesTab then
		titlesTab.MouseButton1Click:Connect(function()
			SwitchToTab("Titles")
		end)
	end
end

-- Sets up UI references
local function SetupUI(screenGui)
	if _IsSetup then
		return
	end

	_ScreenGui = screenGui
	local mainFrame = _ScreenGui:WaitForChild("MainFrame")
	local skinsContent = mainFrame:WaitForChild("SkinsContent")

	-- Header references
	_Header = skinsContent:FindFirstChild("Header")
	if _Header then
		_CountLabel = _Header:FindFirstChild("CountLabel")
		_IndexTitle = _Header:FindFirstChild("IndexTitle")
		_IndexSubtitle = _Header:FindFirstChild("IndexSubtitle")
	end

	-- Sidebar references (Sidebar is child of MainFrame, not Content)
	_Sidebar = mainFrame:FindFirstChild("Sidebar")

	-- Grid references
	_GridArea = skinsContent:WaitForChild("GridArea")
	_CardTemplate = _GridArea:FindFirstChild("_Template")
	if _CardTemplate then
		_CardTemplate.Visible = false
	end

	-- Bottom bar references
	_BottomBar = skinsContent:FindFirstChild("BottomBar")
	if _BottomBar then
		local progressBarBg = _BottomBar:FindFirstChild("ProgressBarBg")
		if progressBarBg then
			_ProgressBarFill = progressBarBg:FindFirstChild("ProgressBarFill")
		end
		_ProgressCount = _BottomBar:FindFirstChild("ProgressCount")
		_MilestoneLabel = _BottomBar:FindFirstChild("MilestoneLabel")
	end

	-- Top tabs references
	_TopTabs = mainFrame:FindFirstChild("TopTabs")

	-- Content area references (for tab switching)
	_SkinsContent = mainFrame:FindFirstChild("SkinsContent")
	_TitlesContent = mainFrame:FindFirstChild("TitlesContent")

	-- Set default visibility (Skins visible, Titles hidden)
	if _SkinsContent then
		_SkinsContent.Visible = true
	end

	-- TitlesContent grid references
	if _TitlesContent then
		_TitlesGridArea = _TitlesContent:FindFirstChild("GridArea")
		if _TitlesGridArea then
			_TitleCardTemplate = _TitlesGridArea:FindFirstChild("_Template")
			if _TitleCardTemplate then
				_TitleCardTemplate.Visible = false
			end
		end
		_TitlesContent.Visible = false -- Start with titles hidden
	end

	-- Initialize remote event for equipping titles
	_EquipTitleRemoteEvent = GetRemoteEvent("EquipTitle")

	-- Setup tab handlers
	SetupSidebarTabs()
	SetupTopTabs()

	_IsSetup = true
	DebugLog("UI setup complete")
end

-- API Functions --

function IndexWindowController:Refresh()
	PopulateGrid()
end

-- Initializers --
function IndexWindowController:Init()
	DebugLog("Initializing...")

	OnLocalPlayerStoredDataStreamLoaded(function(PlayerStoredDataStream)
		_PlayerStoredDataStream = PlayerStoredDataStream

		UIController:WhenScreenGuiReady("IndexWindow", function(screenGui)
			SetupUI(screenGui)

			-- Listen for collection changes
			_PlayerStoredDataStream.Skins.Collected:Changed(function()
				InvalidateCollectionCache()
				PopulateGrid()
			end)

			-- Listen for title changes
			_PlayerStoredDataStream.Titles.Equipped:Changed(function()
				if _SelectedTopTab == "Titles" then
					PopulateTitlesGrid()
				end
			end)

			_PlayerStoredDataStream.Titles.Unlocked:Changed(function()
				if _SelectedTopTab == "Titles" then
					PopulateTitlesGrid()
				end
			end)

			-- Initial population
			PopulateGrid()
		end)
	end)
end

-- Return Module --
return IndexWindowController
