--[[
	KillFeedController.lua

	Description:
		Listens for player eliminations and renders kill-feed messages in HUD.
--]]

-- Root --
local KillFeedController = {}

-- Roblox Services --
local Players = game:GetService("Players")

-- Dependencies --
local ClientDataStream = shared("ClientDataStream")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Constants --
local ENTRY_LIFETIME = 4
local MAX_ENTRIES = 6
local SKULL_ICON = "rbxassetid://124432953529217"

-- Private Variables --
local _MainFrame = nil
local _Template = nil
local _NextLayoutOrder = 1
local _LastAliveByUserId = {} -- userId -> bool

-- Private Functions --
local function GetDisplayName(playersData, userId)
	local data = playersData[userId] or playersData[tostring(userId)] or playersData[tonumber(userId)]
	return (data and data.DisplayName and data.DisplayName ~= "" and data.DisplayName)
		or ("Player " .. tostring(userId))
end

local function BuildFeedEntryData(victimUserId, victimData, playersData)
	local victimName = GetDisplayName(playersData, victimUserId)
	local eliminatedBy = victimData.EliminatedBy

	if eliminatedBy == "Disconnect" then
		return nil
	end

	local attackerUserId = tostring(eliminatedBy)
	local isSlip = eliminatedBy == nil
		or eliminatedBy == "Fall"
		or eliminatedBy == "Death"
		or eliminatedBy == "Slip"
		or attackerUserId == tostring(victimUserId)

	if isSlip then
		return {
			Message = "slipped off",
			Player1 = {
				Name = victimName,
				UserId = victimUserId,
			},
			Player2 = {
				Name = "",
				Image = SKULL_ICON,
			},
		}
	end

	return {
		Message = "knocked off",
		Player1 = {
			Name = GetDisplayName(playersData, attackerUserId),
			UserId = attackerUserId,
		},
		Player2 = {
			Name = victimName,
			UserId = victimUserId,
		},
	}
end

local function TrimOldEntries()
	if not _MainFrame then
		return
	end

	local entries = {}
	for _, child in ipairs(_MainFrame:GetChildren()) do
		if child:IsA("GuiObject") and child ~= _Template then
			table.insert(entries, child)
		end
	end

	if #entries <= MAX_ENTRIES then
		return
	end

	table.sort(entries, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)

	local toRemove = #entries - MAX_ENTRIES
	for index = 1, toRemove do
		entries[index]:Destroy()
	end
end

local function FillPlayerSection(container, playerData)
	if not container or not playerData then
		return
	end

	local playerName = container:FindFirstChild("PlayerName", true)
	if not playerName then
		playerName = container:FindFirstChildWhichIsA("TextLabel", true)
	end
	if playerName and playerName:IsA("TextLabel") then
		playerName.Text = playerData.Name or ""
	end

	local imageLabel = container:FindFirstChildWhichIsA("ImageLabel", true)
	if imageLabel then
		imageLabel.Image = ""
		if playerData.Image then
			imageLabel.Image = playerData.Image
		else
			local numericUserId = tonumber(playerData.UserId)
			if numericUserId then
				imageLabel.Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=100&h=100", numericUserId)
			end
		end
	end
end

local function AddFeedEntry(entryData)
	if not _Template or not _MainFrame then
		return
	end

	local entry = _Template:Clone()
	entry.Name = "Entry_" .. tostring(_NextLayoutOrder)
	entry.Visible = true
	entry.LayoutOrder = _NextLayoutOrder
	_NextLayoutOrder += 1

	local textLabel = entry:FindFirstChild("TextLabel")
	if textLabel and textLabel:IsA("TextLabel") then
		textLabel.Text = entryData.Message or ""
	end

	FillPlayerSection(entry:FindFirstChild("Player1"), entryData.Player1)
	FillPlayerSection(entry:FindFirstChild("Player2"), entryData.Player2)

	entry.Parent = _MainFrame
	TrimOldEntries()

	task.delay(ENTRY_LIFETIME, function()
		if entry.Parent then
			entry:Destroy()
		end
	end)
end

local function ClearFeed()
	if not _MainFrame then
		return
	end

	for _, child in ipairs(_MainFrame:GetChildren()) do
		if child:IsA("GuiObject") and child ~= _Template then
			child:Destroy()
		end
	end
end

local function ProcessPlayerChanges(playersData)
	for userId, newData in pairs(playersData) do
		if _LastAliveByUserId[userId] == true and newData.IsAlive == false then
			local entryData = BuildFeedEntryData(userId, newData, playersData)
			if entryData then
				AddFeedEntry(entryData)
			end
		end
	end

	_LastAliveByUserId = {}
	for userId, data in pairs(playersData) do
		_LastAliveByUserId[userId] = data.IsAlive == true
	end
end

-- Initializers --
function KillFeedController:Init()
	task.defer(function()
		task.wait(1)

		local hudGui = PlayerGui:WaitForChild("HUD", 15)
		if not hudGui then
			warn("[KillFeedController] HUD not found in PlayerGui")
			return
		end

		_MainFrame = hudGui:FindFirstChild("RightFrame")
		_Template = _MainFrame and _MainFrame:FindFirstChild("_Template") or nil
		if not _MainFrame or not _Template then
			warn("[KillFeedController] KillFeed UI not found in HUD.RightFrame")
			return
		end

		_Template.Visible = false

		local roundState = ClientDataStream.RoundState
		if not roundState then
			warn("[KillFeedController] RoundState not found")
			return
		end

		local playersData = roundState.Players:Read() or {}
		for userId, data in pairs(playersData) do
			_LastAliveByUserId[userId] = data.IsAlive == true
		end

		roundState.Players:Changed(function()
			ProcessPlayerChanges(roundState.Players:Read() or {})
		end)

		roundState.State:Changed(function(newState)
			if newState == "Waiting" or newState == "Spawning" then
				ClearFeed()
				_NextLayoutOrder = 1
			end
		end)
	end)
end

-- Return Module --
return KillFeedController
