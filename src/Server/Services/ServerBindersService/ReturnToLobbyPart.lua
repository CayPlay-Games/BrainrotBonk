--[[
	ReturnToLobby.lua

	Description:
		Server binder for map ReturnToLobby objects.
		Brings players who fall off obby back to the lobby instead of allowing their character to die
--]]

-- Dependencies --
local Maid = shared("Maid")
local ModelHelper = shared("ModelHelper")

-- Return Module --
return function(Object)
	local _Maid = Maid.new()
	local debounce = {}

	_Maid:GiveTask(Object.Touched:Connect(function(otherPart)
		local character = otherPart.Parent
		local player = game.Players:GetPlayerFromCharacter(character)
		if player and not debounce[player] then
			debounce[player] = true
			ModelHelper:SendPlayerToLobby(player)
			task.delay(1, function()
				debounce[player] = nil
			end)
		end
	end))

	return _Maid
end
