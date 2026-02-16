--[[
	SpinningPart.lua

	Author(s): arc_gg

	Description:
		Binder for SpinningPart.
			- Object can be a Model/BasePart
--]]

-- Roblox Services --
local RunService = game:GetService("RunService")

-- Dependencies --
local Maid = shared("Maid")

-- Constants --
local DEFAULT_SPEED = 90

-- Private Functions --
local function GetSpeed(Object)
	local AttributeValue = Object:GetAttribute("Speed")
	if typeof(AttributeValue) == "number" then
		return AttributeValue
	end

	return DEFAULT_SPEED
end

-- Return Module --
return function(Object)
	local _Maid = Maid.new()
	local Speed = GetSpeed(Object)

	_Maid:GiveTask(Object:GetAttributeChangedSignal("Speed"):Connect(function()
		Speed = GetSpeed(Object)
	end))

	_Maid:GiveTask(RunService.Heartbeat:Connect(function(DeltaTime)
		if not Object or not Object.Parent then
			return
		end

		local Radians = math.rad(Speed * DeltaTime)
		if Radians == 0 then
			return
		end

		if Object:IsA("Model") then
			Object:PivotTo(Object:GetPivot() * CFrame.Angles(0, Radians, 0))
		elseif Object:IsA("BasePart") then
			Object.CFrame = Object.CFrame * CFrame.Angles(0, Radians, 0)
		end
	end))

	return _Maid
end
