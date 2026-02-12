--[[
	OpenWindowPrompt.lua

	Description:
		Creates a ProximityPrompt on parts tagged "OpenWindow".
		Opens the window specified by the "WindowName" attribute.
--]]

local OpenWindowPrompt = {}
OpenWindowPrompt.__index = OpenWindowPrompt

-- Dependencies --
local UIController = shared("UIController")

function OpenWindowPrompt.new(part)
	local self = setmetatable({}, OpenWindowPrompt)

	self._part = part
	self._windowName = part:GetAttribute("WindowName")

	if not self._windowName then
		warn("[OpenWindowPrompt] Part missing 'WindowName' attribute:", part:GetFullName())
		return self
	end

	-- Create ProximityPrompt
	self._prompt = Instance.new("ProximityPrompt")
	self._prompt.ActionText = "Open"
	self._prompt.ObjectText = self._windowName
	self._prompt.HoldDuration = 0
	self._prompt.MaxActivationDistance = 10
	self._prompt.Parent = part

	-- Handle trigger
	self._connection = self._prompt.Triggered:Connect(function()
		UIController:OpenWindow(self._windowName)
	end)

	return self
end

function OpenWindowPrompt:Destroy()
	if self._connection then
		self._connection:Disconnect()
	end
	if self._prompt then
		self._prompt:Destroy()
	end
end

return OpenWindowPrompt
