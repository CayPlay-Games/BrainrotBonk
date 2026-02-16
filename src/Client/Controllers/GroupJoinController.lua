--[[
	GroupJoinController.lua

	Description:
		Sets up ProximityPrompts on parts tagged "GroupReward" to prompt
		players to join the game's group.
--]]

-- Root --
local GroupJoinController = {}

-- Roblox Services --
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local GroupService = game:GetService("GroupService")

-- Dependencies --
local GroupRewardsConfig = shared("GroupRewardsConfig")

-- Private Variables --
local LocalPlayer = Players.LocalPlayer

-- Internal Functions --

local function DebugLog(...)
	print("[GroupJoinController]", ...)
end

-- Sets up a ProximityPrompt on a part
local function SetupPromptOnPart(part)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Join Group"
	prompt.ObjectText = "Group Rewards"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.Parent = part

	prompt.Triggered:Connect(function()
		pcall(function()
			GroupService:PromptJoinAsync(LocalPlayer, GroupRewardsConfig.GROUP_ID)
		end)
	end)
end

-- Initializers --
function GroupJoinController:Init()
	DebugLog("Initializing...")

	-- Setup prompts on existing tagged parts
	local taggedParts = CollectionService:GetTagged("GroupReward")
	for _, part in ipairs(taggedParts) do
		SetupPromptOnPart(part)
	end

	-- Handle parts tagged later
	CollectionService:GetInstanceAddedSignal("GroupReward"):Connect(SetupPromptOnPart)

	DebugLog("Initialized - Found", #taggedParts, "tagged parts")
end

-- Return Module --
return GroupJoinController
