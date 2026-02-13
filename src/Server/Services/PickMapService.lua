--[[
	PickMapService.lua

	Description:
		Manages the Robux map queue for players to pick the next map.
		Players purchase a DevProduct to add their chosen map to the queue.
		RoundService checks this queue before random map selection.
		Queue is session-only (clears on server restart).
--]]

-- Root --
local PickMapService = {}

-- Roblox Services --
local Players = game:GetService("Players")

-- Dependencies --
local DataStream = shared("DataStream")
local MapsConfig = shared("MapsConfig")
local MonetizationService = shared("MonetizationService")
local GetRemoteEvent = shared("GetRemoteEvent")
local GetRemoteFunction = shared("GetRemoteFunction")

-- Remote Events/Functions --
local GetMapQueueStatusRemote = GetRemoteFunction("GetMapQueueStatus")
local SelectMapForPurchaseRemote = GetRemoteEvent("SelectMapForPurchase")

-- Private Variables --
local _MapQueue = {} -- { { MapId = "Blender", PlayerId = 123, PlayerName = "User" }, ... }
local _PendingPurchases = {} -- { [PlayerId] = MapId } - tracks map selection before purchase

-- Internal Functions --

-- Updates the DataStream with current queue for client display
local function UpdateQueueDataStream()
	local queueData = {}
	for _, entry in ipairs(_MapQueue) do
		table.insert(queueData, {
			MapId = entry.MapId,
			PlayerName = entry.PlayerName,
		})
	end
	DataStream.RoundState.MapQueue = queueData
end

-- Adds a map to the queue
local function AddToQueue(player, mapId)
	local mapConfig = MapsConfig.Maps[mapId]
	if not mapConfig then
		warn("[PickMapService] Invalid map ID:", mapId)
		return false
	end

	table.insert(_MapQueue, {
		MapId = mapId,
		PlayerId = player.UserId,
		PlayerName = player.DisplayName,
	})

	UpdateQueueDataStream()
	return true
end

-- Handles the purchase receipt for PickMap product
local function OnPickMapPurchase(receiptInfo, player)
	local mapId = _PendingPurchases[player.UserId]

	if not mapId then
		warn("[PickMapService] No pending map for player:", player.Name)
		return false
	end

	if not MapsConfig.Maps[mapId] then
		warn("[PickMapService] Invalid pending map:", mapId, "for player:", player.Name)
		_PendingPurchases[player.UserId] = nil
		return false
	end

	-- Add to queue
	local success = AddToQueue(player, mapId)

	-- Clear pending regardless of success
	_PendingPurchases[player.UserId] = nil

	return success
end

-- Cleanup when player leaves
local function OnPlayerRemoving(player)
	-- Clear any pending purchase
	_PendingPurchases[player.UserId] = nil

	-- Note: We don't remove their queued maps - they paid for it
	-- The queue entry still shows their name even if they left
end

-- API Functions --

-- Returns the current queue for display
function PickMapService:GetQueue()
	return _MapQueue
end

-- Returns the queue formatted for client display
function PickMapService:GetQueueStatus()
	local queueData = {}
	for _, entry in ipairs(_MapQueue) do
		local mapConfig = MapsConfig.Maps[entry.MapId]
		table.insert(queueData, {
			MapId = entry.MapId,
			MapName = mapConfig and mapConfig.DisplayName or entry.MapId,
			PlayerName = entry.PlayerName,
		})
	end
	return queueData
end

-- Sets the pending map for a player (called before purchase prompt)
function PickMapService:SetPendingPurchase(player, mapId)
	if not MapsConfig.Maps[mapId] then
		warn("[PickMapService] Invalid map ID:", mapId)
		return false
	end

	_PendingPurchases[player.UserId] = mapId
	return true
end

-- Pops and returns the next map from the queue (called by RoundService)
function PickMapService:PopNextMap()
	if #_MapQueue == 0 then
		return nil
	end

	local entry = table.remove(_MapQueue, 1)
	UpdateQueueDataStream()

	return entry
end

-- Checks if queue has maps
function PickMapService:HasQueuedMaps()
	return #_MapQueue > 0
end

-- Initializers --
function PickMapService:Init()
	-- Register purchase handler for PickMap product
	local MapProducts = shared("MapProducts")
	local pickMapProduct = MapProducts.PickMap

	if pickMapProduct and pickMapProduct.DevProductId and pickMapProduct.DevProductId > 0 then
		MonetizationService:RegisterPurchaseHandler(pickMapProduct.DevProductId, OnPickMapPurchase)
	else
		warn("[PickMapService] PickMap DevProductId not set - purchases will not work until configured")
	end

	-- Handle queue status requests
	GetMapQueueStatusRemote.OnServerInvoke = function()
		return self:GetQueueStatus()
	end

	-- Handle map selection before purchase
	SelectMapForPurchaseRemote.OnServerEvent:Connect(function(player, mapId)
		self:SetPendingPurchase(player, mapId)
	end)

	-- Cleanup on player leaving
	Players.PlayerRemoving:Connect(OnPlayerRemoving)

	-- Initialize DataStream queue
	UpdateQueueDataStream()
end

-- Return Module --
return PickMapService
