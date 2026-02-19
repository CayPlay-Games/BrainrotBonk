--[[
	AimService.lua

	Description:
		Manages player arrow equipment.
		Validates ownership and handles equip requests.
		Provides equipped arrow info for reveal phase.
--]]

-- Root --
local AimService = {}

-- Dependencies --
local ArrowsConfig = shared("ArrowsConfig")
local DataStream = shared("DataStream")
local GetRemoteEvent = shared("GetRemoteEvent")

-- Remote Events --
local EquipArrowRemoteEvent = GetRemoteEvent("EquipArrow")

-- Internal Functions --
-- API Functions --
function AimService:GetPlayerArrow(player)
	local stored = DataStream.Stored[player]
	if stored and stored.Arrows then
		local equipped = stored.Arrows.Equipped:Read()
		if equipped and ArrowsConfig.Arrows[equipped] then
			return equipped
		end
	end
	return ArrowsConfig.DEFAULT_ARROW
end

function AimService:PlayerOwnsArrow(player, arrowId)
	if arrowId == ArrowsConfig.DEFAULT_ARROW then
		return true
	end

	local stored = DataStream.Stored[player]
	if not stored then
		return false
	end

	local ownedArrows = stored.Collections and stored.Collections.Arrows and stored.Collections.Arrows:Read() or {}
	return (ownedArrows[arrowId] or 0) >= 1
end

-- Initializers --
function AimService:Init()
	EquipArrowRemoteEvent.OnServerEvent:Connect(function(player, arrowId)
		-- Validate arrow exists
		if not ArrowsConfig.Arrows[arrowId] then
			return
		end

		local stored = DataStream.Stored[player]
		if not stored then
			return
		end

		-- Validate player owns this arrow
		if not self:PlayerOwnsArrow(player, arrowId) then
			return
		end

		-- Equip the arrow
		stored.Arrows.Equipped = arrowId
	end)
end

-- Return Module --
return AimService
