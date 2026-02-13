--[[
	PickMapWindowController.lua

	Description:
		Manages the PickMapWindow UI.
		Displays available maps for Robux purchase and shows the active queue.
--]]

-- Root --
local PickMapWindowController = {}

-- Dependencies --
local UIController = shared("UIController")
local MapsConfig = shared("MapsConfig")
local MonetizationController = shared("MonetizationController")
local ClientDataStream = shared("ClientDataStream")
local GetRemoteEvent = shared("GetRemoteEvent")

-- Remote Events/Functions --
local SelectMapForPurchaseRemote = GetRemoteEvent("SelectMapForPurchase")

-- Private Variables --
local _ScreenGui = nil
local _MainFrame = nil
local _MapSection = nil
local _MapTemplate = nil
local _QueueBox = nil
local _QueueTemplate = nil
local _EmptyLabel = nil
local _IsSetup = false
local _MapCards = {} -- { [mapId] = cardInstance }
local _QueueEntries = {} -- Array of queue entry instances

-- Internal Functions --

-- Clears all queue entry instances
local function ClearQueueEntries()
	for _, entry in ipairs(_QueueEntries) do
		entry:Destroy()
	end
	_QueueEntries = {}
end

-- Updates the queue display from DataStream
local function UpdateQueueDisplay()
	if not _QueueBox or not _QueueTemplate then
		return
	end

	ClearQueueEntries()

	local roundState = ClientDataStream.RoundState
	if not roundState then
		return
	end

	local queueData = roundState.MapQueue:Read() or {}

	if #queueData == 0 then
		-- Show empty label
		if _EmptyLabel then
			_EmptyLabel.Visible = true
		end
	else
		-- Hide empty label and show entries
		if _EmptyLabel then
			_EmptyLabel.Visible = false
		end

		for i, entry in ipairs(queueData) do
			local mapConfig = MapsConfig.Maps[entry.MapId]
			local mapName = mapConfig and mapConfig.DisplayName or entry.MapId

			local queueEntry = _QueueTemplate:Clone()
			queueEntry.Name = "QueueEntry_" .. i
			queueEntry.Text = mapName .. " picked by " .. entry.PlayerName
			queueEntry.LayoutOrder = i
			queueEntry.Visible = true
			queueEntry.Parent = _QueueBox

			table.insert(_QueueEntries, queueEntry)
		end
	end
end

-- Handles map card click
local function OnMapClicked(mapId)
	-- Tell server which map we want to buy
	SelectMapForPurchaseRemote:FireServer(mapId)

	-- Prompt the Robux purchase
	MonetizationController:PromptPurchase("PickMap")
end

-- Creates a map card from the template
local function CreateMapCard(mapId, mapConfig)
	if not _MapTemplate then
		return nil
	end

	local card = _MapTemplate:Clone()
	card.Name = mapId
	card.Visible = true

	-- Set map name
	local mapName = card:FindFirstChild("MapName")
	if mapName then
		mapName.Text = mapConfig.DisplayName or mapId
	end

	-- Set price
	local priceTag = card:FindFirstChild("PriceTag")
	if priceTag then
		local priceText = priceTag:FindFirstChild("PriceText")
		if priceText then
			priceText.Text = tostring(MapsConfig.PICK_MAP_PRICE)
		end
	end

	-- Setup click handler
	local button = card
	if button:IsA("GuiButton") or button:FindFirstChildWhichIsA("GuiButton") then
		local clickTarget = button:IsA("GuiButton") and button or button:FindFirstChildWhichIsA("GuiButton")
		if clickTarget then
			clickTarget.MouseButton1Click:Connect(function()
				OnMapClicked(mapId)
			end)
		end
	else
		-- Make the card itself clickable via InputBegan
		card.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				OnMapClicked(mapId)
			end
		end)
	end

	card.Parent = _MapSection
	return card
end

-- Populates the map section with all available maps
local function PopulateMaps()
	if not _MapSection or not _MapTemplate then
		return
	end

	-- Clear existing map cards
	for _, card in pairs(_MapCards) do
		card:Destroy()
	end
	_MapCards = {}

	-- Create a card for each map
	local layoutOrder = 1
	for mapId, mapConfig in pairs(MapsConfig.Maps) do
		local card = CreateMapCard(mapId, mapConfig)
		if card then
			card.LayoutOrder = layoutOrder
			_MapCards[mapId] = card
			layoutOrder = layoutOrder + 1
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

	local innerFrame = _MainFrame:WaitForChild("InnerFrame")

	-- Map section
	_MapSection = innerFrame:WaitForChild("MapSection")
	_MapTemplate = _MapSection:FindFirstChild("_Template")
	if _MapTemplate then
		_MapTemplate.Visible = false
	end

	-- Queue section
	local queueSection = innerFrame:WaitForChild("QueueSection")
	_QueueBox = queueSection:WaitForChild("QueueBox")
	_QueueTemplate = _QueueBox:FindFirstChild("_Template")
	if _QueueTemplate then
		_QueueTemplate.Visible = false
	end
	_EmptyLabel = _QueueBox:FindFirstChild("EmptyLabel")

	-- Close button
	local closeButton = _MainFrame:FindFirstChild("CloseButton")
	if closeButton then
		closeButton.MouseButton1Click:Connect(function()
			UIController:CloseWindow("PickMapWindow")
		end)
	end

	-- Populate maps
	PopulateMaps()

	-- Initial queue update
	UpdateQueueDisplay()

	_IsSetup = true

	-- Listen for queue changes (defer to ensure DataStream is ready)
	task.defer(function()
		task.wait(0.5)
		local roundState = ClientDataStream.RoundState
		if roundState and roundState.MapQueue then
			roundState.MapQueue:Changed(function()
				UpdateQueueDisplay()
			end)
			-- Update again in case queue changed before listener was set
			UpdateQueueDisplay()
		end
	end)
end

-- API Functions --

-- Refreshes the queue display
function PickMapWindowController:RefreshQueue()
	UpdateQueueDisplay()
end

-- Initializers --
function PickMapWindowController:Init()
	UIController:WhenScreenGuiReady("PickMapWindow", function(screenGui)
		SetupUI(screenGui)
	end)
end

-- Return Module --
return PickMapWindowController
