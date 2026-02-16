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
local RoundConfig = shared("RoundConfig")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Constants --
local ENTRY_LIFETIME = 4
local MAX_ENTRIES = 6

-- Private Variables --
local _MainFrame = nil
local _Template = nil
local _NextLayoutOrder = 1
local _LastPlayersSnapshot = {} -- userId -> { IsAlive, EliminatedBy, DisplayName }

local function DebugLog(...)
	if RoundConfig.DEBUG_LOG_STATE_CHANGES then
		print("[KillFeedController]", ...)
	end
end

local function CopyPlayersSnapshot(playersData)
	local snapshot = {}
	for userId, data in pairs(playersData) do
		snapshot[userId] = {
			IsAlive = data.IsAlive,
			EliminatedBy = data.EliminatedBy,
			DisplayName = data.DisplayName,
		}
	end
	return snapshot
end

local function GetDisplayName(playersData, userId, fallback)
	local data = playersData[userId]
	if data and data.DisplayName and data.DisplayName ~= "" then
		return data.DisplayName
	end
	return fallback or ("Player " .. tostring(userId))
end

local function BuildFeedMessage(victimUserId, victimData, playersData)
	local victimName = GetDisplayName(playersData, victimUserId, victimData.DisplayName)
	local eliminatedBy = victimData.EliminatedBy

	if eliminatedBy == nil or eliminatedBy == "Fall" or eliminatedBy == "Death" or eliminatedBy == "Slip" then
		return string.format("%s slipped off.", victimName)
	end

	if eliminatedBy == "Disconnect" then
		return nil
	end

	local attackerUserId = tostring(eliminatedBy)
	if attackerUserId == victimUserId then
		return string.format("%s slipped off.", victimName)
	end

	local attackerData = playersData[attackerUserId]
	if attackerData then
		local attackerName = GetDisplayName(playersData, attackerUserId, "Player")
		return string.format("%s knocked off %s.", attackerName, victimName)
	end

	return string.format("%s slipped off.", victimName)
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

local function AddFeedEntry(text)
	if not _Template or not _MainFrame then
		return
	end

	local entry = _Template:Clone()
	entry.Name = "Entry_" .. tostring(_NextLayoutOrder)
	entry.Visible = true
	entry.LayoutOrder = _NextLayoutOrder
	_NextLayoutOrder += 1

	local textLabel = entry:FindFirstChildOfClass("TextLabel") or entry
	if textLabel and textLabel:IsA("TextLabel") then
		textLabel.Text = text
	end

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
		local oldData = _LastPlayersSnapshot[userId]
		if oldData and oldData.IsAlive == true and newData.IsAlive == false then
			local message = BuildFeedMessage(userId, newData, playersData)
			if message then
				AddFeedEntry(message)
				DebugLog("Added feed entry:", message)
			end
		end
	end

	_LastPlayersSnapshot = CopyPlayersSnapshot(playersData)
end

local function SetupUI()
	local hudGui = PlayerGui:WaitForChild("HUD", 15)
	if not hudGui then
		warn("[KillFeedController] HUD not found in PlayerGui")
		return false
	end

	_MainFrame = hudGui:FindFirstChild("RightFrame")
	if not _MainFrame then
		warn("[KillFeedController] MainFrame not found in HUD")
		return false
	end

	_Template = _MainFrame:FindFirstChild("_Template")
	if not _Template then
		warn("[KillFeedController] _Template not found in HUD.RightFrame")
		return false
	end

	_Template.Visible = false
	return true
end

-- Initializers --
function KillFeedController:Init()
	DebugLog("Initializing...")

	task.defer(function()
		task.wait(1)

		if not SetupUI() then
			return
		end

		local roundState = ClientDataStream.RoundState
		if not roundState then
			warn("[KillFeedController] RoundState not found")
			return
		end

		local playersData = roundState.Players:Read() or {}
		_LastPlayersSnapshot = CopyPlayersSnapshot(playersData)

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
