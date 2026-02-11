--[[
    Use this function to ensure we don't accidently modify the actual datastores in studio
--]]

local RunService = game:GetService("RunService")

local CurrentEnvironementType = shared("CurrentEnvironementType")

return function(DefaultDataStoreName)
	if RunService:IsStudio() then
		return `_STUDIO_{DefaultDataStoreName}`
	elseif CurrentEnvironementType ~= "Live" then
		return `NOT_LIVE_{DefaultDataStoreName}`
	else
		return DefaultDataStoreName
	end
end
