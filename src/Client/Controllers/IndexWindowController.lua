--[[
	IndexWindowController.lua

	Description:
		Manages the IndexWindow UI - displays ALL skins as a collection index.
		Shows collected skins normally, uncollected skins "blacked out".
		Includes mutation variant filtering via sidebar tabs.
--]]

-- Root --
local IndexWindowController = {}

-- Roblox Services --
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Dependencies --
local ClientDataStream = shared("ClientDataStream")
local SkinsConfig = shared("SkinsConfig")
local RoundConfig = shared("RoundConfig")
local ViewportHelper = shared("ViewportHelper")

-- Object References --
local LocalPlayer = Players.LocalPlayer
local PlayerGui
local SkinsFolder

-- Private Variables --
local _ScreenGui = nil
local _GridArea = nil
local _CardTemplate = nil
local _IndexCards = {} -- { [skinId] = card }
local _SelectedMutation = "Normal"
local _SelectedTopTab = "Skins"

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

-- Sidebar tab configuration
local SIDEBAR_TABS = {
	{ name = "NormalTab", mutation = "Normal" },
	{ name = "GoldTab", mutation = "Gold" },
	{ name = "DiamondTab", mutation = "Diamond" },
	{ name = "RainbowTab", mutation = "Rainbow" },
}

-- Internal Functions --

local function DebugLog(...)
	if RoundConfig.DEBUG_LOG_STATE_CHANGES then
		print("[IndexWindowController]", ...)
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

-- Checks if a skin+mutation combo is collected
local function IsCollected(skinId, mutation)
	local stored = ClientDataStream.Stored
	if not stored or not stored.Skins then return false end

	local collected = stored.Skins.Collected:Read() or {}
	for _, entry in ipairs(collected) do
		if entry.SkinId == skinId then
			return table.find(entry.Mutations, mutation) ~= nil
		end
	end
	return false
end

-- Gets count of collected skins for a specific mutation (for future filtered progress)
local function _GetCollectedCount(mutation)
	local stored = ClientDataStream.Stored
	if not stored or not stored.Skins then return 0 end

	local collected = stored.Skins.Collected:Read() or {}
	local count = 0
	for _, entry in ipairs(collected) do
		if table.find(entry.Mutations, mutation) then
			count = count + 1
		end
	end
	return count
end

-- Gets total count of all possible skin+mutation combos
local function GetTotalCount()
	local skinCount = 0
	for _ in pairs(SkinsConfig.Skins) do
		skinCount = skinCount + 1
	end

	local mutationCount = 0
	for _ in pairs(SkinsConfig.Mutations) do
		mutationCount = mutationCount + 1
	end

	return skinCount * mutationCount
end

-- Gets total collected across all mutations
local function GetTotalCollectedCount()
	local stored = ClientDataStream.Stored
	if not stored or not stored.Skins then return 0 end

	local collected = stored.Skins.Collected:Read() or {}
	local count = 0
	for _, entry in ipairs(collected) do
		count = count + #entry.Mutations
	end
	return count
end

-- Applies blacked out effect for uncollected skins
local function ApplyLockedEffect(card)
	local viewport = card:FindFirstChild("ItemViewport")
	if viewport then
		-- Check if overlay already exists
		local existingOverlay = viewport:FindFirstChild("LockedOverlay")
		if not existingOverlay then
			local overlay = Instance.new("Frame")
			overlay.Name = "LockedOverlay"
			overlay.Size = UDim2.new(1, 0, 1, 0)
			overlay.BackgroundColor3 = Color3.new(0, 0, 0)
			overlay.BackgroundTransparency = 0.2
			overlay.ZIndex = 10
			overlay.Parent = viewport
		end
	end

	-- Gray out text labels
	local itemName = card:FindFirstChild("ItemName")
	if itemName then
		itemName.TextColor3 = Color3.fromRGB(80, 80, 80)
	end

	local rarityLabel = card:FindFirstChild("RarityLabel")
	if rarityLabel then
		rarityLabel.TextColor3 = Color3.fromRGB(80, 80, 80)
	end

	local defaultLabel = card:FindFirstChild("DefaultLabel")
	if defaultLabel then
		defaultLabel.TextColor3 = Color3.fromRGB(80, 80, 80)
	end
end

-- Removes locked effect (for collected skins)
local function RemoveLockedEffect(card)
	local viewport = card:FindFirstChild("ItemViewport")
	if viewport then
		local overlay = viewport:FindFirstChild("LockedOverlay")
		if overlay then
			overlay:Destroy()
		end
	end
end

-- Displays a skin model in the viewport
local function DisplaySkinInViewport(viewport, skinId, camera)
	-- Clear existing models
	for _, child in viewport:GetChildren() do
		if child:IsA("Model") then
			child:Destroy()
		end
	end

	local skinConfig = SkinsConfig.Skins[skinId]
	if not skinConfig then return nil end

	local previewModel = SkinsFolder:FindFirstChild(skinConfig.ModelName)
	if not previewModel then return nil end

	local clone = ViewportHelper.DisplayModel(viewport, previewModel, camera)
	return clone
end

-- Creates an index card for a skin
local function CreateIndexCard(skinId)
	local skinConfig = SkinsConfig.Skins[skinId]
	if not skinConfig then return nil end

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

	-- Setup viewport preview
	local viewport = card:FindFirstChild("ItemViewport")
	if viewport then
		local camera = SetupViewportCamera(viewport)
		DisplaySkinInViewport(viewport, skinId, camera)
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
	local total = GetTotalCount()

	-- Both header and bottom bar show total collected / total possible
	if _ProgressCount then
		_ProgressCount.Text = totalCollected .. "/" .. total
	end

	if _CountLabel then
		_CountLabel.Text = totalCollected .. "/" .. total
	end

	if _ProgressBarFill then
		local ratio = total > 0 and (totalCollected / total) or 0
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

	-- Get all skins and sort them
	local sortedSkins = {}
	for skinId in pairs(SkinsConfig.Skins) do
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

	-- Create cards for each skin
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
	if not _Sidebar then return end

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

	DebugLog("Setting up sidebar tabs, Sidebar children:")
	for _, child in _Sidebar:GetChildren() do
		DebugLog("  -", child.Name, child.ClassName)
	end

	for _, tabInfo in ipairs(SIDEBAR_TABS) do
		local tab = _Sidebar:FindFirstChild(tabInfo.name)
		if tab then
			DebugLog("Found tab:", tabInfo.name)
			tab.MouseButton1Click:Connect(function()
				OnMutationTabClicked(tabInfo.mutation)
			end)
		else
			DebugLog("Tab not found:", tabInfo.name)
		end
	end

	UpdateSidebarTabs()
end

-- Sets up top tabs (Skins/Titles)
local function SetupTopTabs()
	if not _TopTabs then return end

	local skinsTab = _TopTabs:FindFirstChild("SkinsTopTab")
	local titlesTab = _TopTabs:FindFirstChild("TitlesTopTab")

	if skinsTab then
		skinsTab.MouseButton1Click:Connect(function()
			_SelectedTopTab = "Skins"
			-- TODO: Switch to skins view
			DebugLog("Selected top tab: Skins")
		end)
	end

	if titlesTab then
		titlesTab.MouseButton1Click:Connect(function()
			_SelectedTopTab = "Titles"
			-- TODO: Switch to titles view
			DebugLog("Selected top tab: Titles")
		end)
	end
end

-- Sets up UI references
local function SetupUI()
	if _IsSetup then return end

	PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
	SkinsFolder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Skins")

	_ScreenGui = PlayerGui:WaitForChild("IndexWindow")
	local mainFrame = _ScreenGui:WaitForChild("MainFrame")
	local content = mainFrame:WaitForChild("Content")

	-- Debug: Log Content children
	DebugLog("Content children:")
	for _, child in content:GetChildren() do
		DebugLog("  -", child.Name, child.ClassName)
	end

	-- Header references
	_Header = content:FindFirstChild("Header")
	if _Header then
		_CountLabel = _Header:FindFirstChild("CountLabel")
		_IndexTitle = _Header:FindFirstChild("IndexTitle")
		_IndexSubtitle = _Header:FindFirstChild("IndexSubtitle")
	end

	-- Sidebar references (Sidebar is child of MainFrame, not Content)
	_Sidebar = mainFrame:FindFirstChild("Sidebar")

	-- Grid references
	_GridArea = content:WaitForChild("GridArea")
	_CardTemplate = _GridArea:FindFirstChild("_Template")
	if _CardTemplate then
		_CardTemplate.Visible = false
	end

	-- Bottom bar references
	_BottomBar = content:FindFirstChild("BottomBar")
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

	task.defer(function()
		task.wait(1)

		SetupUI()

		-- Listen for collection changes
		local stored = ClientDataStream.Stored
		if stored and stored.Skins then
			stored.Skins.Collected:Changed(function()
				PopulateGrid()
			end)
		end

		-- Initial population
		PopulateGrid()
	end)
end

-- Return Module --
return IndexWindowController
