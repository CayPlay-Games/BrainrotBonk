local ModelHelper = {}

function ModelHelper:PivotToBottomOfPart(Model, TargetPart)
	local ModelSize = Model:GetExtentsSize()

	local NewCFrame = TargetPart.CFrame * CFrame.new(0, ModelSize.Y / 2 - TargetPart.Size.Y / 2, 0)

	Model:PivotTo(NewCFrame)
end

function ModelHelper:GetTotalMass(Model)
	local TotalMass = 0

	for _, Part in Model:GetDescendants() do
		if Part:IsA("BasePart") then
			TotalMass = TotalMass + Part.Mass
		end
	end

	return TotalMass
end

return ModelHelper
