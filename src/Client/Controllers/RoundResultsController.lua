--[[
	RoundResultsController.lua

	Description:
		Receives round results from server and displays XP earned.
		UI not yet implemented - prints results to output.
--]]

-- Root --
local RoundResultsController = {}

-- Roblox Services --

-- Dependencies --
local GetRemoteEvent = shared("GetRemoteEvent")
local RankConfig = shared("RankConfig")

-- Object References --
local RoundResultsEvent = GetRemoteEvent("RoundResults")

-- Constants --
local XPRewards = RankConfig.XPRewards
local PlacementInfo = {
	[1] = { Key = "Place1st", Label = "1st Place" },
	[2] = { Key = "Place2nd", Label = "2nd Place" },
	[3] = { Key = "Place3rd", Label = "3rd Place" },
}

-- Internal Functions --
local function CalculateXPBreakdown(results)
	local breakdown = {}
	local totalXP = 0

	-- Completed round XP
	if results.Completed then
		local xp = XPRewards.PlayGame
		table.insert(breakdown, { Reason = "Round Completed", XP = xp })
		totalXP = totalXP + xp
	end

	-- Elimination XP
	local eliminations = results.Eliminations or 0
	if eliminations > 0 then
		local xp = XPRewards.Kill * eliminations
		table.insert(breakdown, { Reason = string.format("Eliminations (x%d)", eliminations), XP = xp })
		totalXP = totalXP + xp
	end

	-- Placement XP
	local info = PlacementInfo[results.Placement]
	if info then
		local xp = XPRewards[info.Key]
		table.insert(breakdown, { Reason = info.Label, XP = xp })
		totalXP = totalXP + xp
	end

	return breakdown, totalXP
end

local function PrintResults(results)
	local breakdown, totalXP = CalculateXPBreakdown(results)

	print("========================================")
	print("           ROUND RESULTS")
	print("========================================")

	for _, entry in ipairs(breakdown) do
		print(string.format("  %-25s +%d XP", entry.Reason, entry.XP))
	end

	print("----------------------------------------")
	print(string.format("  %-25s +%d XP", "TOTAL", totalXP))
	print("========================================")
end

local function OnRoundResults(results)
	if type(results) ~= "table" then
		return
	end

	PrintResults(results)
	-- TODO: Display XP breakdown in UI
end

-- API Functions --
-- Initializers --
function RoundResultsController:Init()
	RoundResultsEvent.OnClientEvent:Connect(OnRoundResults)
end

function RoundResultsController:Start() end

-- Return Module --
return RoundResultsController
