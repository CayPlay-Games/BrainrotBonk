local RoundConfig = shared("RoundConfig")

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

function ModelHelper:SendPlayerToLobby(Player)
	if Player and Player.Character then
		-- Get the offset from lobby spawn
		local randomOffset = Vector3.new(
			math.random(-RoundConfig.LOBBY_SPAWN_SIZE.X / 2, RoundConfig.LOBBY_SPAWN_SIZE.X / 2),
			0,
			math.random(-RoundConfig.LOBBY_SPAWN_SIZE.Z / 2, RoundConfig.LOBBY_SPAWN_SIZE.Z / 2)
		)
		Player.Character:PivotTo(CFrame.new(RoundConfig.LOBBY_SPAWN_POSITION + randomOffset))
	end
end
return ModelHelper
