--[[
    EntityIdTracker.lua

    Description:
        Use this object to get new unique IDs for whatever purpose you need.
        Good if you need quick, low-memory ids for non-important tasks.

--]]

-- Root --
local EntityIdTracker = {}
EntityIdTracker.__index = EntityIdTracker

-- Roblox Services --

-- Dependencies --

-- Object References --

-- Constants --

-- Private Variables --

-- Public Variables --

-- Internal Functions --

-- API Functions --
function EntityIdTracker:GetNextId()
	local GivenId = self._CurrentId
	self._CurrentId += 1

	return GivenId
end

function EntityIdTracker:Destroy()
	self.CurrentId = nil
end

-- Constructor --
function EntityIdTracker.new()
	local self = setmetatable({}, EntityIdTracker)

	self._CurrentId = 1

	return self
end

-- Return Module --
return EntityIdTracker
