--[[
    Example.lua

    Description:
        Example object

--]]

-- Root --
local Example = {}
Example.__index = Example

-- Roblox Services --

-- Dependencies --

-- Object References --

-- Constants --

-- Private Variables --

-- Public Variables --

-- Internal Functions --

-- API Functions --

-- Constructor --
function Example.new()
	local self = setmetatable({}, Example)

	return self
end

-- Return Module --
return Example
