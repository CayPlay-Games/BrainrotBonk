--[[
    Queue.lua

    Description:
        Puts item in an ordered queue.

--]]

-- Root --

local Queue = {}
Queue.__index = Queue

-- Roblox Services --

-- Dependencies --
local Maid = require("./Maid")
local Signal = require("./Signal")

-- Object References --

-- Constants --

-- Private Variables --

-- Public Variables --

-- Internal Functions --

-- Constructor --
function Queue.new()
	local self = setmetatable({}, Queue)

	self.FocusedItem = nil
	self.ItemFocusChanged = Signal.new()

	self._Items = {}
	self._Maid = Maid.new()

	return self
end

-- Methods --
function Queue:AddItem(Item)
	table.insert(self._Items, Item)

	if not self.FocusedItem then
		self:NextItem()
	end
end

function Queue:AddItems(Items)
	for _, Item in pairs(Items) do
		table.insert(self._Items, Item)
	end

	if not self.FocusedItem then
		self:NextItem()
	end
end

function Queue:ClearItems()
	self._Items = {}
	self.FocusedItem = nil
	self.ItemFocusChanged:Fire(nil)
end

function Queue:NextItem()
	local NextItem = self._Items[1]
	if NextItem then
		table.remove(self._Items, 1)

		self.FocusedItem = NextItem
		self.ItemFocusChanged:Fire(NextItem)
	elseif not NextItem and self.FocusedItem ~= nil then
		self.FocusedItem = nil
		self.ItemFocusChanged:Fire(nil)
	end
end

function Queue:Destroy()
	self._Maid:DoCleaning()
end

return Queue
