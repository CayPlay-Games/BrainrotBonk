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

-- Awards a skin + mutation to the player
-- Returns: isNewSkin, isNewMutation
local function AwardSkin(player, skinId, mutation)
	mutation = mutation or "Normal"

	local stored = DataStream.Stored[player]
	if not stored then return false, false end

	-- Check if skin exists in config
	if not SkinsConfig.Skins[skinId] then
		DebugLog("Skin not found in config:", skinId)
		return false, false
	end

	-- Check if mutation exists in config
	if not SkinsConfig.Mutations[mutation] then
		DebugLog("Mutation not found in config:", mutation)
		mutation = "Normal"
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
		-- Already owns skin - check if mutation is new
		local hasMutation = false
		for _, existingMutation in ipairs(existingEntry.Mutations or {}) do
			if existingMutation == mutation then
				hasMutation = true
				break
			end
		end

		if hasMutation then
			-- Already has this mutation
			DebugLog(player.Name, "already owns skin:", skinId, "with mutation:", mutation)
			return false, false
		else
			-- Add new mutation to existing skin
			existingEntry.Mutations = existingEntry.Mutations or {}
			table.insert(existingEntry.Mutations, mutation)
			collected[existingIndex] = existingEntry
			stored.Skins.Collected = collected
			DebugLog(player.Name, "awarded new mutation:", mutation, "for skin:", skinId)
			return false, true
		end
	else
		-- Add new skin with the rolled mutation
		table.insert(collected, {
			SkinId = skinId,
			Mutations = { mutation },
		})
		stored.Skins.Collected = collected
		DebugLog(player.Name, "awarded new skin:", skinId, "with mutation:", mutation)
		return true, true
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

	-- Roll random skin and mutation
	local skinId, mutation = SkinBoxesConfig:RollSkin(boxId)
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
		return false, nil, nil
	end

	-- Award skin with mutation
	local isNewSkin, isNewMutation = AwardSkin(player, skinId, mutation)

	local statusText = isNewSkin and "(NEW SKIN!)" or (isNewMutation and "(NEW MUTATION!)" or "(duplicate)")
	print("[SkinShopService]", player.Name, "rolled", skinId, mutation, "from", boxId, statusText)

	return true, skinId, mutation
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
		local success, skinId, mutation = HandleCoinPurchase(player, boxId)

		-- Notify client of result (for future animation)
		if success and skinId then
			SkinBoxResultRemoteEvent:FireClient(player, {
				Success = true,
				BoxId = boxId,
				SkinId = skinId,
				Mutation = mutation,
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
