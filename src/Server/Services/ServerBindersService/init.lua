--[[
    ClientBindersController.lua
    Author: Philippe-Olivier Thibault
    Date: 2024-03

    Description:
        Easily store and create Binders for client use
--]]

local ServerBindersService = {}

local Binder = shared("Binder")

function ServerBindersService:Init()
	for _, FocusedInstance in pairs(script:GetDescendants()) do
		if FocusedInstance.ClassName == "ModuleScript" then
			local TagName = FocusedInstance.Name
			local BinderFunction = require(FocusedInstance)
			Binder.new(TagName, BinderFunction):Run()
		end
	end
end

return ServerBindersService
