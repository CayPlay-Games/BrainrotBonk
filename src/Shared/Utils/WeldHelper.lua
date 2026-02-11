local WeldHelper = {}

function WeldHelper:WeldParts(Part0, Part1)
	local WeldConstaint = Instance.new("WeldConstraint")

	WeldConstaint.Part0 = Part0
	WeldConstaint.Part1 = Part1
	WeldConstaint.Parent = Part0

	return WeldConstaint
end

return WeldHelper
