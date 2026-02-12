--[[
	SkinShopService.lua

	Description:
		Handles skin box (egg) purchases from the Skin Shop.
		Validates purchases, rolls random skins, and awards to players.
--]]

-- Root --
local SkinShopService = {}

-- Roblox Services --
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

-- Dependencies --
local DataStream = shared("DataStream")
local SkinBoxesConfig = shared("SkinBoxesConfig")
local SkinsConfig = shared("SkinsConfig")
local CollectionsService = shared("CollectionsService")
local GetRemoteEvent = shared("GetRemoteEvent")
local RoundConfig = shared("RoundConfig")

-- Remote Events --
local PurchaseSkinBoxRemoteEvent = GetRemoteEvent("PurchaseSkinBox")
local SkinBoxResultRemoteEvent = GetRemoteEvent("SkinBoxResult")

-- Constants --
local CURRENCY_ID = "Coins"

-- Internal Functions --

local function DebugLog(...)
	if RoundConfig.DEBUG_LOG_STATE_CHANGES then
		print("[SkinShopService]", ...)
	end
end

-- Checks if player can afford a box with the given currency
local function CanAfford(player, boxId, currencyType)
	local box = SkinBoxesConfig.Boxes[boxId]
	if not box then return false end

	if currencyType == "Coins" then
		local stored = DataStream.Stored[player]
		if not stored then return false end

		local coins = stored.Collections.Currencies.Coins:Read() or 0
		return coins >= box.CoinsPrice
	end

	-- Robux is handled by MarketplaceService
	return true
end

-- Awards a skin to the player
-- Returns true if skin was new, false if already owned
local function AwardSkin(player, skinId)
	local stored = DataStream.Stored[player]
	if not stored then return false end

	-- Check if skin exists in config
	if not SkinsConfig.Skins[skinId] then
		DebugLog("Skin not found in config:", skinId)
		return false
	end

	local collected = stored.Skins.Collected:Read() or {}

	-- Check if player already owns this skin
	local existingEntry = nil
	local existingIndex = nil
	for i, entry in ipairs(collected) do
		if entry.SkinId == skinId then
			existingEntry = entry
			existingIndex = i
			break
		end
	end

	if existingEntry then
		-- Already owns skin - could add mutation in future
		DebugLog(player.Name, "already owns skin:", skinId)
		return false
	else
		-- Add new skin with Normal mutation
		table.insert(collected, {
			SkinId = skinId,
			Mutations = { "Normal" },
		})
		stored.Skins.Collected = collected
		DebugLog(player.Name, "awarded new skin:", skinId)
		return true
	end
end

-- Handles a coin purchase request
local function HandleCoinPurchase(player, boxId)
	local box = SkinBoxesConfig.Boxes[boxId]
	if not box then
		DebugLog("Invalid box ID:", boxId)
		return false, nil
	end

	-- Check and deduct currency
	local success, response = CollectionsService:SpendCurrency(
		player,
		CURRENCY_ID,
		box.CoinsPrice,
		Enum.AnalyticsEconomyTransactionType.Shop.Name,
		"SkinBox_" .. boxId
	)

	if not success then
		DebugLog("Failed to spend currency:", response)
		return false, nil
	end

	-- Roll random skin
	local skinId = SkinBoxesConfig:RollSkin(boxId)
	if not skinId then
		-- Refund if roll failed (shouldn't happen)
		CollectionsService:GiveCurrency(
			player,
			CURRENCY_ID,
			box.CoinsPrice,
			Enum.AnalyticsEconomyTransactionType.Shop.Name,
			"SkinBox_" .. boxId .. "_Refund"
		)
		DebugLog("Roll failed for box:", boxId)
		return false, nil
	end

	-- Award skin
	local isNew = AwardSkin(player, skinId)

	print("[SkinShopService]", player.Name, "rolled", skinId, "from", boxId, isNew and "(NEW!)" or "(duplicate)")

	return true, skinId
end

-- Handles purchase request from client
local function OnPurchaseRequest(player, boxId, currencyType)
	DebugLog(player.Name, "requesting purchase:", boxId, "with", currencyType)

	-- Validate box exists
	local box = SkinBoxesConfig.Boxes[boxId]
	if not box then
		DebugLog("Invalid box ID:", boxId)
		return
	end

	-- Validate currency type
	if currencyType ~= "Coins" and currencyType ~= "Robux" then
		DebugLog("Invalid currency type:", currencyType)
		return
	end

	if currencyType == "Coins" then
		-- Handle coin purchase directly
		local success, skinId = HandleCoinPurchase(player, boxId)

		-- Notify client of result (for future animation)
		if success and skinId then
			SkinBoxResultRemoteEvent:FireClient(player, {
				Success = true,
				BoxId = boxId,
				SkinId = skinId,
			})
		else
			SkinBoxResultRemoteEvent:FireClient(player, {
				Success = false,
				BoxId = boxId,
				Reason = "Purchase failed",
			})
		end
	elseif currencyType == "Robux" then
		-- TODO: Implement Robux purchase via DevProducts
		-- For now, just log that it was attempted
		DebugLog("Robux purchase not yet implemented for box:", boxId)
		SkinBoxResultRemoteEvent:FireClient(player, {
			Success = false,
			BoxId = boxId,
			Reason = "Robux purchases coming soon!",
		})
	end
end

-- Initializers --
function SkinShopService:Init()
	DebugLog("Initializing...")

	-- Handle purchase requests
	PurchaseSkinBoxRemoteEvent.OnServerEvent:Connect(OnPurchaseRequest)

	-- Count available boxes
	local boxCount = 0
	for _ in pairs(SkinBoxesConfig.Boxes) do
		boxCount = boxCount + 1
	end
	DebugLog("Loaded", boxCount, "skin boxes")
end

-- Return Module --
return SkinShopService
