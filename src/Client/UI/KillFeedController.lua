--[[
	KillFeedController.lua

	Description:
		Displays live elimination feed entries in HUD.RightFrame.
		- Knockout: Player1 knocked out Player2
		- Slip/Suicide: Player1 slipped off
--]]

-- Root --
local KillFeedController = {}

-- Roblox Services --
local Players = game:GetService("Players")

-- Dependencies --
local ClientDataStream = shared("ClientDataStream")
local RoundConfig = shared("RoundConfig")

-- Object References --
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Constants --
local ENTRY_LIFETIME = 7
local MAX_ENTRIES = 6
local FALLBACK_SKULL_IMAGE = "rbxassetid://124432953529217"

-- Private Variables --
local _HUD = nil
local _RightFrame = nil
local _Template = nil
local _DefaultPlayer2Image = nil
local _Entries = {}
local _LastPlayersSnapshot = {}
local _ProcessedEliminations = {}
local _EntrySerial = 0

-- Internal Functions --
local function DebugLog(...)
	if RoundConfig.DEBUG_LOG_STATE_CHANGES then
		print("[KillFeedController]", ...)
	end
end

local function CopyPlayersSnapshot(playersTable)
	local copied = {}
	for userId, data in pairs(playersTable or {}) do
		copied[tostring(userId)] = {
			IsAlive = data.IsAlive,
			EliminatedBy = data.EliminatedBy,
			DisplayName = data.DisplayName,
		}
	end
	return copied
end

local function GetDisplayName(userId, playersSnapshot)
	local key = tostring(userId)
	local fromRoundState = playersSnapshot and playersSnapshot[key]
	if fromRoundState and fromRoundState.DisplayName and fromRoundState.DisplayName ~= "" then
		return fromRoundState.DisplayName
	end

	local numericUserId = tonumber(key)
	if numericUserId then
		local player = Players:GetPlayerByUserId(numericUserId)
		if player then
			return player.DisplayName
		end
	end

	return "Player " .. key
end

local function GetHeadshot(userId)
	local numericUserId = tonumber(userId)
	if not numericUserId then
		return ""
	end

	local success, image = pcall(function()
		return Players:GetUserThumbnailAsync(numericUserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
	end)

	if success and image then
		return image
	end

	return ""
end

local function SetPlayerSlot(slotFrame, userId, displayName, overrideImage)
	if not slotFrame then
		return
	end

	if slotFrame:IsA("ImageLabel") or slotFrame:IsA("ImageButton") then
		if overrideImage ~= nil then
			slotFrame.Image = overrideImage
		elseif userId ~= nil then
			slotFrame.Image = GetHeadshot(userId)
		end
	end

	local nameLabel = slotFrame:FindFirstChild("PlayerName")
	if nameLabel and nameLabel:IsA("TextLabel") then
		nameLabel.Text = displayName or ""
	end
end

local function DestroyEntry(entry)
	for index, existing in ipairs(_Entries) do
		if existing == entry then
			table.remove(_Entries, index)
			break
		end
	end

	if entry and entry.Parent then
		entry:Destroy()
	end
end

local function TrimOldEntries()
	while #_Entries > MAX_ENTRIES do
		local oldest = table.remove(_Entries, 1)
		if oldest and oldest.Parent then
			oldest:Destroy()
		end
	end
end

local function ResetFeedState()
	for _, entry in ipairs(_Entries) do
		if entry and entry.Parent then
			entry:Destroy()
		end
	end
	table.clear(_Entries)
	table.clear(_ProcessedEliminations)
end

local function PushFeedEntry(actorUserId, targetUserId, isSlip, playersSnapshot)
	if not _Template or not _RightFrame then
		return
	end

	_EntrySerial += 1

	local entry = _Template:Clone()
	entry.Name = "Entry_" .. tostring(_EntrySerial)
	entry.Visible = true
	entry.LayoutOrder = -_EntrySerial

	local player1Frame = entry:FindFirstChild("Player1")
	local player2Frame = entry:FindFirstChild("Player2")
	local actionLabel = entry:FindFirstChild("TextLabel")

	local actorName = GetDisplayName(actorUserId, playersSnapshot)
	SetPlayerSlot(player1Frame, actorUserId, actorName)

	if isSlip then
		local skullImage = _DefaultPlayer2Image or FALLBACK_SKULL_IMAGE
		SetPlayerSlot(player2Frame, nil, "", skullImage)
		if actionLabel and actionLabel:IsA("TextLabel") then
			actionLabel.Text = "slipped off"
		end
	else
		local targetName = GetDisplayName(targetUserId, playersSnapshot)
		SetPlayerSlot(player2Frame, targetUserId, targetName)
		if actionLabel and actionLabel:IsA("TextLabel") then
			actionLabel.Text = "knocked out"
		end
	end

	entry.Parent = _RightFrame
	table.insert(_Entries, entry)
	TrimOldEntries()

	task.delay(ENTRY_LIFETIME, function()
		if entry and entry.Parent then
			DestroyEntry(entry)
		end
	end)
end

local function HandlePlayersChanged(newPlayersSnapshot)
	for userId, newData in pairs(newPlayersSnapshot) do
		local oldData = _LastPlayersSnapshot[userId]
		local wasAlive = oldData and oldData.IsAlive == true
		local isAlive = newData and newData.IsAlive == true

		if wasAlive and not isAlive then
			local eliminatedBy = tostring(newData.EliminatedBy or "Slip")
			local eventKey = tostring(userId) .. "|" .. eliminatedBy

			if not _ProcessedEliminations[eventKey] then
				_ProcessedEliminations[eventKey] = true

				local attackerUserId = tonumber(eliminatedBy)
				if attackerUserId and tostring(attackerUserId) ~= tostring(userId) then
					PushFeedEntry(attackerUserId, tonumber(userId) or userId, false, newPlayersSnapshot)
				else
					PushFeedEntry(tonumber(userId) or userId, nil, true, newPlayersSnapshot)
				end
			end
		end
	end

	_LastPlayersSnapshot = CopyPlayersSnapshot(newPlayersSnapshot)
end

local function SetupUI()
	if _Template and _RightFrame and _HUD then
		return true
	end

	_HUD = PlayerGui:WaitForChild("HUD", 30)
	if not _HUD then
		warn("[KillFeedController] HUD not found in PlayerGui")
		return false
	end

	_RightFrame = _HUD:WaitForChild("RightFrame", 30)
	if not _RightFrame then
		warn("[KillFeedController] RightFrame not found in HUD")
		return false
	end

	_Template = _RightFrame:FindFirstChild("_Template")
	if not _Template then
		warn("[KillFeedController] _Template not found in RightFrame")
		return false
	end

	local player2Frame = _Template:FindFirstChild("Player2")
	if player2Frame and (player2Frame:IsA("ImageLabel") or player2Frame:IsA("ImageButton")) then
		_DefaultPlayer2Image = player2Frame.Image
	end

	_Template.Visible = false

	for _, child in ipairs(_RightFrame:GetChildren()) do
		if child:IsA("GuiObject") and child ~= _Template then
			child:Destroy()
		end
	end

	return true
end

-- Initializers --
function KillFeedController:Init()
	DebugLog("Initializing...")

	task.defer(function()
		if not SetupUI() then
			return
		end

		local roundState = ClientDataStream.RoundState
		if not roundState or not roundState.Players then
			warn("[KillFeedController] RoundState.Players not available")
			return
		end

		_LastPlayersSnapshot = CopyPlayersSnapshot(roundState.Players:Read() or {})

		roundState.Players:Changed(function()
			HandlePlayersChanged(roundState.Players:Read() or {})
		end)

		if roundState.State then
			roundState.State:Changed(function(newState)
				if newState == "Waiting" or newState == "Spawning" then
					ResetFeedState()
				end
			end)
		end
	end)
end

-- Return Module --
return KillFeedController
