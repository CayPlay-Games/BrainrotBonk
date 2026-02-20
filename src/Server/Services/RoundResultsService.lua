--[[
	RoundResultsService.lua

	Description:
		Tracks player eliminations during rounds and sends round results
		to clients at round end for XP display.
--]]

-- Root --
local RoundResultsService = {}

-- Roblox Services --
local Players = game:GetService("Players")

-- Dependencies --
local GetRemoteEvent = shared("GetRemoteEvent")
local RoundService = shared("RoundService")

-- Object References --
local RoundResultsEvent = GetRemoteEvent("RoundResults")

-- Constants --

-- Private Variables --
local _EliminationCounts = {} -- Player -> number

-- Public Variables --
-- Internal Functions --
local function ResetEliminationCounts()
	table.clear(_EliminationCounts)
end

local function IncrementEliminations(player, amount)
	if not player or not player:IsA("Player") then
		return
	end
	_EliminationCounts[player] = (_EliminationCounts[player] or 0) + (amount or 1)
end

local function OnPlayerEliminated(eliminatedPlayer, eliminatedBy)
	-- Only count player-caused eliminations
	-- eliminatedBy = UserId
	local eliminatorId = tonumber(eliminatedBy)
	if not eliminatorId then
		return
	end

	local eliminator = Players:GetPlayerByUserId(eliminatorId)
	if eliminator and eliminator ~= eliminatedPlayer then
		IncrementEliminations(eliminator, 1)
	end
end

local function OnRoundEnded(_winner)
	local roundPlayersData = RoundService:GetRoundPlayersData()

	-- Send results to each participant
	for player, data in pairs(roundPlayersData) do
		if player and player:IsA("Player") and player.Parent then
			local results = {
				Completed = true,
				Eliminations = _EliminationCounts[player] or 0,
				Placement = data.PlacementPosition, -- 1, 2, 3, or nil
			}
			RoundResultsEvent:FireClient(player, results)
		end
	end
	ResetEliminationCounts()
end

-- API Functions --
-- Initializers --
function RoundResultsService:Init()
	RoundService.PlayerEliminated:Connect(OnPlayerEliminated)
	RoundService.RoundEnded:Connect(OnRoundEnded)

	Players.PlayerRemoving:Connect(function(player)
		_EliminationCounts[player] = nil
	end)
end

function RoundResultsService:Start() end

-- Return Module --
return RoundResultsService
