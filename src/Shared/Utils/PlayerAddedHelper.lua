--[[
    PlayerAddedHelper.lua

    Description:
        No description provided.

--]]

-- Root --
local PlayerAddedHelper = {}

-- Roblox Services --
local Players = game:GetService("Players")

-- Dependencies --
local Maid = shared("Maid")

-- Object References --

-- Constants --

-- Private Variables --
local PlayerMaidCache = {}

-- Public Variables --

-- Internal Functions --

-- API Functions --
function PlayerAddedHelper:OnPlayerAdded(callback: (player: Player) -> ())
	local PlayerAddedConnection
	PlayerAddedConnection = Players.PlayerAdded:Connect(callback)

	for _, player in pairs(Players:GetPlayers()) do
		task.spawn(function()
			callback(player)
		end)
	end

	return PlayerAddedConnection
end

function PlayerAddedHelper:OnCharacterAdded(callback: (character: Model, player: Player) -> ())
	self:OnPlayerAdded(function(player)
		local targetMaid = PlayerMaidCache[player]
		if not targetMaid then
			targetMaid = Maid.new()
			PlayerMaidCache[player] = targetMaid
		end

		targetMaid:GiveTask(player.CharacterAdded:Connect(function(character)
			callback(character, player)
		end))

		if player.Character then
			callback(player.Character, player)
		end
	end)
end

-- Initializers --
function PlayerAddedHelper:Init()
	Players.PlayerRemoving:Connect(function(player)
		local targetMaid = PlayerMaidCache[player]
		if targetMaid then
			targetMaid:Destroy()
			PlayerMaidCache[player] = nil
		end
	end)
end

-- Return Module --
return PlayerAddedHelper
