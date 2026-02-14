--[[
	PhysicsUtil.lua 
	Author(s): arcoorio
	Created: 2026-02-13 22:05

	Description:
		No description specified.

--]]

-- Root --
local PhysicsUtil = {}

-- Roblox Services --

-- Dependencies --

-- Constants --

-- Private Variables --

-- Public Variables --

-- Object References --

-- Applies a horizontal launch impulse so collision response remains physics-driven.
function PhysicsUtil:ApplyLaunchImpulse(RootPart, Direction, Speed)
	if not RootPart then
		return
	end

	if typeof(Direction) ~= "Vector3" or Direction.Magnitude < 0.001 then
		return
	end

	local FlatDirection = Vector3.new(Direction.X, 0, Direction.Z)
	if FlatDirection.Magnitude < 0.001 then
		return
	end

	local Mass = RootPart.AssemblyMass
	RootPart:ApplyImpulse(FlatDirection.Unit * Speed * Mass)
end

-- Applies dt-scaled horizontal drag and returns true when the body is settled.
function PhysicsUtil:ApplyHorizontalDrag(RootPart, DeltaTime, DragPerSecond, SettleSpeed)
	if not RootPart then
		return true
	end

	DeltaTime = math.max(DeltaTime or 0, 0)
	DragPerSecond = math.max(DragPerSecond or 0, 0)
	SettleSpeed = math.max(SettleSpeed or 0, 0)

	local CurrentVelocity = RootPart.AssemblyLinearVelocity
	local HorizontalVelocity = Vector3.new(CurrentVelocity.X, 0, CurrentVelocity.Z)
	local Speed = HorizontalVelocity.Magnitude

	if Speed <= SettleSpeed then
		if Speed > 0.001 then
			RootPart.AssemblyLinearVelocity = Vector3.new(0, CurrentVelocity.Y, 0)
		end
		return true
	end

	local NewSpeed = math.max(0, Speed - (DragPerSecond * DeltaTime))
	if NewSpeed <= SettleSpeed then
		RootPart.AssemblyLinearVelocity = Vector3.new(0, CurrentVelocity.Y, 0)
		return true
	end

	local NewHorizontalVelocity = HorizontalVelocity.Unit * NewSpeed
	RootPart.AssemblyLinearVelocity = Vector3.new(NewHorizontalVelocity.X, CurrentVelocity.Y, NewHorizontalVelocity.Z)

	return false
end

return PhysicsUtil
