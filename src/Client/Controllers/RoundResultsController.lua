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

-- Private Variables --
-- Public Variables --

-- Internal Functions --
local function CalculateXPBreakdown(results)
	local breakdown = {}
	local totalXP = 0

	-- Completed round XP
	if results.Completed then
		local xp = XPRewards.PlayGame
		table.insert(breakdown, {
			Reason = "Round Completed",
			XP = xp,
		})
		totalXP = totalXP + xp
	end

	-- Elimination XP
	local eliminations = results.Eliminations or 0
	if eliminations > 0 then
		local xp = XPRewards.Kill * eliminations
		table.insert(breakdown, {
			Reason = string.format("Eliminations (x%d)", eliminations),
			XP = xp,
		})
		totalXP = totalXP + xp
	end

	-- Placement XP
	local placement = results.Placement
	if placement == 1 then
		local xp = XPRewards.Place1st
		table.insert(breakdown, {
			Reason = "1st Place",
			XP = xp,
		})
		totalXP = totalXP + xp
	elseif placement == 2 then
		local xp = XPRewards.Place2nd
		table.insert(breakdown, {
			Reason = "2nd Place",
			XP = xp,
		})
		totalXP = totalXP + xp
	elseif placement == 3 then
		local xp = XPRewards.Place3rd
		table.insert(breakdown, {
			Reason = "3rd Place",
			XP = xp,
		})
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
end

-- API Functions --
-- Initializers --
function RoundResultsController:Init()
	RoundResultsEvent.OnClientEvent:Connect(OnRoundResults)
end

function RoundResultsController:Start() end

-- Return Module --
return RoundResultsController
