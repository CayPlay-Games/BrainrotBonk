--[[
	RoundResultsService.lua

	Description:
		Sends round results to clients at round end for XP display.
		Elimination counts are tracked by RoundService.
--]]

-- Root --
local RoundResultsService = {}

-- Dependencies --
local GetRemoteEvent = shared("GetRemoteEvent")
local RoundService = shared("RoundService")

-- Object References --
local RoundResultsEvent = GetRemoteEvent("RoundResults")

-- Internal Functions --
local function OnRoundEnded(_winner)
	local roundPlayersData = RoundService:GetRoundPlayersData()

	-- Send results to each participant
	for player, data in pairs(roundPlayersData) do
		if player and player.Parent then
			local results = {
				Completed = true,
				Eliminations = data.Eliminations,
				Placement = data.PlacementPosition,
			}
			RoundResultsEvent:FireClient(player, results)
		end
	end
end

-- Initializers --
function RoundResultsService:Init()
	RoundService.RoundEnded:Connect(OnRoundEnded)
end

-- Return Module --
return RoundResultsService
