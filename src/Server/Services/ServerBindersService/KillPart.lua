--[[
	KillPart.lua

	Description:
		Server binder for map KillPart objects.
		Eliminates alive round entities (players/dummies) that touch the bound part.
--]]

-- Dependencies --
local Maid = shared("Maid")
local RoundService = shared("RoundService")

-- Return Module --
return function(Object)
	local _Maid = Maid.new()

	_Maid:GiveTask(Object.Touched:Connect(function(otherPart)
		local model = otherPart and otherPart:FindFirstAncestorOfClass("Model")
		if not model then
			return
		end

		local entity = RoundService:GetAliveEntityFromCharacter(model)
		if entity then
			RoundService:EliminatePlayer(entity, "Fall")
		end
	end))

	return _Maid
end
