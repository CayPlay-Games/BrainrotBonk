--[[
	TitleService.lua

	Description:
		Manages player titles and overhead displays.
		Creates BillboardGui above players showing name and title.
--]]

-- Root --
local TitleService = {}

-- Roblox Services --
local Players = game:GetService("Players")

-- Dependencies --
local RoundConfig = shared("RoundConfig")
local TitlesConfig = shared("TitlesConfig")
local DataStream = shared("DataStream")
local GetRemoteEvent = shared("GetRemoteEvent")
local PlayerAddedHelper = shared("PlayerAddedHelper")

-- Remote Events --
local EquipTitleRemoteEvent = GetRemoteEvent("EquipTitle")

-- Constants --
local BILLBOARD_OFFSET = Vector3.new(0, 3, 0)
local BILLBOARD_SIZE = UDim2.new(0, 100, 0, 50)
local BILLBOARD_MAX_DISTANCE = 100

-- Private Variables --
local _OverheadDisplays = {} -- Player -> BillboardGui

-- Internal Functions --

local function DebugLog(...)
	if RoundConfig.DEBUG_LOG_STATE_CHANGES then
		print("[TitleService]", ...)
	end
end

-- Creates the BillboardGui structure
local function CreateBillboardGui()
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "OverheadDisplay"
	billboard.Size = BILLBOARD_SIZE
	billboard.StudsOffset = BILLBOARD_OFFSET
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = BILLBOARD_MAX_DISTANCE

	-- Main frame
	local frame = Instance.new("Frame")
	frame.Name = "MainFrame"
	frame.Size = UDim2.new(1, 0, 1, 0)
	frame.BackgroundTransparency = 1
	frame.Parent = billboard

	-- Title label (top)
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "TitleLabel"
	titleLabel.Size = UDim2.new(1, 0, 0.5, 0)
	titleLabel.Position = UDim2.new(0, 0, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.FredokaOne
	titleLabel.TextScaled = true
	titleLabel.TextColor3 = Color3.new(1, 1, 1)
	titleLabel.TextStrokeTransparency = 0.5
	titleLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	titleLabel.Text = ""
	titleLabel.Visible = false
	titleLabel.Parent = frame

	-- Name label (bottom)
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
	nameLabel.Position = UDim2.new(0, 0, 0.5, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.FredokaOne
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.TextStrokeTransparency = 0.3
	nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	nameLabel.Text = ""
	nameLabel.Parent = frame

	return billboard
end

-- API Functions --

-- Gets the equipped title for a player
function TitleService:GetPlayerTitle(player)
	local stored = DataStream.Stored[player]
	if stored and stored.Titles then
		local equipped = stored.Titles.Equipped:Read()
		if equipped and TitlesConfig.Titles[equipped] then
			return equipped
		end
	end
	return TitlesConfig.DEFAULT_TITLE
end

-- Creates overhead display for a player
function TitleService:CreateOverheadDisplay(player)
	local character = player.Character
	if not character then return end

	local head = character:FindFirstChild("Head")
	if not head then return end

	-- Remove existing display if any
	local existingDisplay = _OverheadDisplays[player]
	if existingDisplay then
		existingDisplay:Destroy()
	end

	-- Create new BillboardGui
	local billboard = CreateBillboardGui()
	billboard.Adornee = head
	billboard.Parent = head

	_OverheadDisplays[player] = billboard

	-- Initial update
	self:UpdateOverheadDisplay(player)

	DebugLog("Created overhead display for", player.Name)
end

-- Updates display content for a player
function TitleService:UpdateOverheadDisplay(player)
	local billboard = _OverheadDisplays[player]
	if not billboard then return end

	local frame = billboard:FindFirstChild("MainFrame")
	if not frame then return end

	local nameLabel = frame:FindFirstChild("NameLabel")
	local titleLabel = frame:FindFirstChild("TitleLabel")

	-- Update name
	if nameLabel then
		nameLabel.Text = player.DisplayName
	end

	-- Update title
	if titleLabel then
		local stored = DataStream.Stored[player]
		local titleId = stored and stored.Titles and stored.Titles.Equipped:Read()

		if titleId and TitlesConfig.Titles[titleId] then
			local config = TitlesConfig.Titles[titleId]
			titleLabel.Text = config.DisplayName
			titleLabel.TextColor3 = config.Color
			titleLabel.Visible = true
		else
			titleLabel.Text = ""
			titleLabel.Visible = false
		end
	end
end

-- Removes overhead display for a player
function TitleService:RemoveOverheadDisplay(player)
	local billboard = _OverheadDisplays[player]
	if billboard then
		billboard:Destroy()
		_OverheadDisplays[player] = nil
		DebugLog("Removed overhead display for", player.Name)
	end
end

-- Initializers --
function TitleService:Init()
	DebugLog("Initializing...")

	-- Handle EquipTitle remote event
	EquipTitleRemoteEvent.OnServerEvent:Connect(function(player, titleId)
		-- Allow nil to unequip
		if titleId ~= nil and not TitlesConfig.Titles[titleId] then
			DebugLog(player.Name, "tried to equip invalid title:", titleId)
			return
		end

		local stored = DataStream.Stored[player]
		if not stored then return end

		-- Validate player owns title (if not nil)
		if titleId ~= nil then
			local unlocked = stored.Titles.Unlocked:Read()
			if not unlocked or not table.find(unlocked, titleId) then
				DebugLog(player.Name, "tried to equip unowned title:", titleId)
				return
			end
		end

		-- Equip the title
		stored.Titles.Equipped = titleId
		self:UpdateOverheadDisplay(player)
		DebugLog(player.Name, "equipped title:", titleId or "none")
	end)

	-- Listen for player data loaded
	DataStream.PlayerStreamAdded:Connect(function(schemaName, player)
		if schemaName == "Stored" then
			task.defer(function()
				-- Listen for title changes
				local stored = DataStream.Stored[player]
				if stored and stored.Titles then
					stored.Titles.Equipped:Changed(function()
						self:UpdateOverheadDisplay(player)
					end)
				end

				-- Create display if character exists
				if player.Character then
					self:CreateOverheadDisplay(player)
				end
			end)
		end
	end)

	-- Handle character spawning
	PlayerAddedHelper:OnPlayerAdded(function(player)
		player.CharacterAdded:Connect(function(character)
			-- Wait for Head
			local head = character:WaitForChild("Head", 5)
			if head then
				-- Small delay to ensure data is ready
				task.wait(0.1)
				self:CreateOverheadDisplay(player)
			end
		end)

		-- Create for existing character
		if player.Character then
			local head = player.Character:FindFirstChild("Head")
			if head then
				self:CreateOverheadDisplay(player)
			end
		end
	end)

	-- Handle player leaving
	Players.PlayerRemoving:Connect(function(player)
		self:RemoveOverheadDisplay(player)
	end)

	DebugLog("Initialized")
end

-- Return Module --
return TitleService
