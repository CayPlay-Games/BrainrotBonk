--[[
	ChatTagController.lua

	Description:
		Handles chat tag display for special players.
		Group members get a "[Certified Bonker]" tag prepended to their messages.
--]]

-- Root --
local ChatTagController = {}

-- Roblox Services --
local TextChatService = game:GetService("TextChatService")
local Players = game:GetService("Players")

-- Dependencies --
local GroupRewardsConfig = shared("GroupRewardsConfig")

-- Private Variables --
local _GroupMemberCache = {} -- { [UserId] = boolean }

-- Internal Functions --

local function DebugLog(...)
	print("[ChatTagController]", ...)
end

-- Checks if a player is in the group (with caching)
local function IsPlayerInGroup(player)
	local userId = player.UserId

	-- Return cached result if available
	if _GroupMemberCache[userId] ~= nil then
		return _GroupMemberCache[userId]
	end

	-- Check group membership
	local success, result = pcall(function()
		return player:IsInGroup(GroupRewardsConfig.GROUP_ID)
	end)

	if success then
		_GroupMemberCache[userId] = result
		return result
	else
		return false
	end
end

-- Formats a chat tag with color
local function FormatChatTag(tagText, tagColor)
	local r = math.floor(tagColor.R * 255)
	local g = math.floor(tagColor.G * 255)
	local b = math.floor(tagColor.B * 255)
	return string.format('<font color="rgb(%d,%d,%d)">[%s]</font> ', r, g, b, tagText)
end

-- Gets the player from a TextSource
local function GetPlayerFromTextSource(textSource)
	if not textSource then return nil end

	local userId = textSource.UserId
	if userId then
		return Players:GetPlayerByUserId(userId)
	end

	return nil
end

-- Initializers --
function ChatTagController:Init()
	DebugLog("Initializing...")

	-- Clean up cache when players leave
	Players.PlayerRemoving:Connect(function(player)
		_GroupMemberCache[player.UserId] = nil
	end)

	-- Set up chat callback for modifying incoming messages
	TextChatService.OnIncomingMessage = function(message)
		local properties = Instance.new("TextChatMessageProperties")

		-- Get the player who sent the message
		local player = GetPlayerFromTextSource(message.TextSource)
		if not player then
			return properties
		end

		-- Check if player is a group member (cached)
		if IsPlayerInGroup(player) then
			local tag = FormatChatTag(GroupRewardsConfig.CHAT_TAG, GroupRewardsConfig.CHAT_TAG_COLOR)
			properties.PrefixText = tag .. message.PrefixText
		end

		return properties
	end

	DebugLog("Initialized - Chat tags enabled for group members")
end

-- Return Module --
return ChatTagController
