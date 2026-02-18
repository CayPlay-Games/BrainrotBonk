--[[
	SpinningPart.lua

	Author(s): arc_gg

	Description:
		Binder for SpinningPart.
			- Object can be a Model/BasePart
			- Attributes:
				- Speed (number): Rotation speed in degrees per second (default: 90)
				- Axis (string): "X", "Y", or "Z" axis to rotate on (default: "Y")
--]]

-- Roblox Services --
local RunService = game:GetService("RunService")

-- Dependencies --
local Maid = shared("Maid")

-- Constants --
local DEFAULT_SPEED = 90
local DEFAULT_AXIS = "Y"

-- Private Functions --
local function GetSpeed(Object)
	local AttributeValue = Object:GetAttribute("Speed")
	if typeof(AttributeValue) == "number" then
		return AttributeValue
	end

	return DEFAULT_SPEED
end

local function GetAxis(Object)
	local AttributeValue = Object:GetAttribute("Axis")
	if typeof(AttributeValue) == "string" then
		local upper = AttributeValue:upper()
		if upper == "X" or upper == "Y" or upper == "Z" then
			return upper
		end
	end

	return DEFAULT_AXIS
end

local function GetRotationCFrame(Axis, Radians)
	if Axis == "X" then
		return CFrame.Angles(Radians, 0, 0)
	elseif Axis == "Z" then
		return CFrame.Angles(0, 0, Radians)
	else
		return CFrame.Angles(0, Radians, 0)
	end
end

-- Return Module --
return function(Object)
	local _Maid = Maid.new()
	local Speed = GetSpeed(Object)
	local Axis = GetAxis(Object)

	_Maid:GiveTask(Object:GetAttributeChangedSignal("Speed"):Connect(function()
		Speed = GetSpeed(Object)
	end))

	_Maid:GiveTask(Object:GetAttributeChangedSignal("Axis"):Connect(function()
		Axis = GetAxis(Object)
	end))

	_Maid:GiveTask(RunService.Heartbeat:Connect(function(DeltaTime)
		if not Object or not Object.Parent then
			return
		end

		local Radians = math.rad(Speed * DeltaTime)
		if Radians == 0 then
			return
		end

		local RotationCFrame = GetRotationCFrame(Axis, Radians)

		if Object:IsA("Model") then
			Object:PivotTo(Object:GetPivot() * RotationCFrame)
		elseif Object:IsA("BasePart") then
			Object.CFrame = Object.CFrame * RotationCFrame
		end
	end))

	return _Maid
end
