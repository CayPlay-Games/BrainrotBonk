local MathHelper = {}

function MathHelper:Lerp(A: number, B: number, D: number): number
	return A + ((B - A) * D)
end

return MathHelper
