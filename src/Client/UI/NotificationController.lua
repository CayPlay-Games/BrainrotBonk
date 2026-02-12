--[[
	NotificationController.lua

	Description:
		Manages notification UI with custom logic per notification type.
		First notification: ChoosingMap - roulette animation showing map selection.
--]]

-- Root --
local NotificationController = {}

-- Roblox Services --
local TweenService = game:GetService("TweenService")

-- Dependencies --
local ClientDataStream = shared("ClientDataStream")
local UIController = shared("UIController")
local MapsConfig = shared("MapsConfig")
local RoundConfig = shared("RoundConfig")

-- Private Variables --
local _ChoosingMapGui = nil
local _RouletteScroller = nil
local _MapTemplate = nil
local _IsSetup = false

-- Constants --
local ROULETTE_ITEM_HEIGHT = 50 -- Height per map entry (pixels)
local ROULETTE_LOOPS = 3 -- How many times to loop through all maps
local ROULETTE_DURATION = 2.5 -- Total animation duration in seconds

-- Internal Functions --

local function DebugLog(...)
	if RoundConfig.DEBUG_LOG_STATE_CHANGES then
		print("[NotificationController]", ...)
	end
end

-- Gets a sorted list of maps
local function GetSortedMapList()
	local mapList = {}
	for mapId, mapConfig in pairs(MapsConfig.Maps) do
		table.insert(mapList, { Id = mapId, DisplayName = mapConfig.DisplayName })
	end
	table.sort(mapList, function(a, b)
		return a.DisplayName < b.DisplayName
	end)
	return mapList
end

-- Populates the RouletteScroller with map names
local function PopulateRoulette()
	-- Clear existing (except template)
	for _, child in _RouletteScroller:GetChildren() do
		if child:IsA("GuiObject") and child.Name ~= "_Template" then
			child:Destroy()
		end
	end

	local mapList = GetSortedMapList()

	-- Get item height from template
	local itemHeight = ROULETTE_ITEM_HEIGHT
	if _MapTemplate then
		itemHeight = _MapTemplate.AbsoluteSize.Y
		if itemHeight == 0 then
			itemHeight = ROULETTE_ITEM_HEIGHT -- Fallback if not rendered yet
		end
	end

	-- Create entries (multiple loops for roulette effect)
	local index = 0
	for _ = 1, ROULETTE_LOOPS + 1 do
		for _, mapData in ipairs(mapList) do
			local entry = _MapTemplate:Clone()
			entry.Name = mapData.Id
			entry.Visible = true
			entry.LayoutOrder = index

			-- Manually position each entry vertically
			entry.Position = UDim2.new(0, 0, 0, index * itemHeight)

			local textLabel = entry:FindFirstChildOfClass("TextLabel") or entry
			if textLabel then
				textLabel.Text = mapData.DisplayName
			end

			entry.Parent = _RouletteScroller
			index = index + 1
		end
	end
end

-- Plays roulette animation stopping on chosen map
local function PlayRouletteAnimation(chosenMapId)
	if not _RouletteScroller then return end

	local mapList = GetSortedMapList()

	-- Find index of chosen map
	local chosenIndex = 1
	for i, mapData in ipairs(mapList) do
		if mapData.Id == chosenMapId then
			chosenIndex = i
			break
		end
	end

	-- Calculate item height from actual template size + layout padding
	local itemHeight = ROULETTE_ITEM_HEIGHT
	if _MapTemplate then
		itemHeight = _MapTemplate.AbsoluteSize.Y
		-- Account for UIListLayout padding if present
		local layout = _RouletteScroller:FindFirstChildOfClass("UIListLayout")
		if layout then
			local padding = layout.Padding.Offset
			if layout.Padding.Scale > 0 then
				padding = padding + (layout.Padding.Scale * _RouletteScroller.AbsoluteSize.Y)
			end
			itemHeight = itemHeight + padding
		end
	end

	-- Calculate target scroll position
	-- Loop through maps ROULETTE_LOOPS times, then land on chosen map
	local totalMaps = #mapList
	local targetIndex = (ROULETTE_LOOPS * totalMaps) + chosenIndex - 1

	-- Center the chosen map in view (move scroller upward = negative Y)
	local viewHeight = _RouletteScroller.Parent.AbsoluteSize.Y
	local scrollOffset = (targetIndex * itemHeight) - (viewHeight / 2) + (itemHeight / 2)

	-- Animate with deceleration (Quint Out gives the slot machine feel)
	local tweenInfo = TweenInfo.new(
		ROULETTE_DURATION,
		Enum.EasingStyle.Quint,
		Enum.EasingDirection.Out
	)

	-- Reset position to top and animate upward (negative Y offset)
	_RouletteScroller.Position = UDim2.new(0, 0, 0, 0)
	local tween = TweenService:Create(_RouletteScroller, tweenInfo, {
		Position = UDim2.new(0, 0, 0, -scrollOffset)
	})
	tween:Play()

	DebugLog("Playing roulette for map:", chosenMapId, "itemHeight:", itemHeight, "target scroll:", scrollOffset)
end

-- Shows the ChoosingMap notification
local function ShowChoosingMapNotification(mapId)
	if not _ChoosingMapGui then return end

	PopulateRoulette()
	_ChoosingMapGui.Enabled = true

	-- Wait a frame for UI to render and AbsoluteSize to be calculated
	task.defer(function()
		-- Small delay before starting animation
		task.delay(0.3, function()
			PlayRouletteAnimation(mapId)
		end)
	end)

	-- Hide after animation completes
	task.delay(ROULETTE_DURATION + 2, function()
		_ChoosingMapGui.Enabled = false
	end)
end

-- Sets up ChoosingMap notification UI
local function SetupChoosingMapUI(screenGui)
	_ChoosingMapGui = screenGui
	local container = screenGui:WaitForChild("Container")
	local rouletteClip = container:WaitForChild("RouletteClip")
	_RouletteScroller = rouletteClip:WaitForChild("RouletteScroller")
	_MapTemplate = _RouletteScroller:FindFirstChild("_Template")

	if _MapTemplate then
		_MapTemplate.Visible = false
	end

	DebugLog("ChoosingMap UI setup complete")
end

-- API Functions --

function NotificationController:ShowChoosingMap(mapId)
	ShowChoosingMapNotification(mapId)
end

-- Initializers --
function NotificationController:Init()
	DebugLog("Initializing...")

	-- Setup ChoosingMap notification UI
	UIController:WhenScreenGuiReady("Notification_ChoosingMap", function(screenGui)
		SetupChoosingMapUI(screenGui)

		-- Listen for map selection changes
		local roundState = ClientDataStream.RoundState
		roundState.CurrentMapId:Changed(function(newMapId)
			if newMapId and newMapId ~= "" then
				ShowChoosingMapNotification(newMapId)
			end
		end)

		_IsSetup = true
	end)
end

-- Return Module --
return NotificationController
