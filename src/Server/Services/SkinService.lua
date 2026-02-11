--[[
	SkinService.lua

	Description:
		Manages player physics boxes and cosmetic skins during rounds.
		Creates standardized physics bodies for fair gameplay.
		Skins are welded to the physics box (massless, cosmetic only).
--]]

-- Root --
local SkinService = {}

-- Roblox Services --
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Dependencies --
local RoundConfig = shared("RoundConfig")
local SkinsConfig = shared("SkinsConfig")
local DataStream = shared("DataStream")
local GetRemoteEvent = shared("GetRemoteEvent")

-- Remote Events --
local EquipSkinRemoteEvent = GetRemoteEvent("EquipSkin")

-- Constants --
local SKINS_FOLDER = ReplicatedStorage:FindFirstChild("Assets"):FindFirstChild(SkinsConfig.SKINS_FOLDER_NAME)

-- Private Variables --
-- Stores original HumanoidDescription for each player to restore later
local _OriginalDescriptions = {} -- Player -> HumanoidDescription

-- Internal Functions --

local function DebugLog(...)
	if RoundConfig.DEBUG_LOG_STATE_CHANGES then
		print("[SkinService]", ...)
	end
end

-- Creates the standardized physics box model
local function CreatePhysicsBox(player, spawnCFrame)
	local physicsBox = Instance.new("Model")
	physicsBox.Name = player.Name

	-- Create the main physics body (cube)
	local rootPart = Instance.new("Part")
	rootPart.Name = "HumanoidRootPart"
	rootPart.Size = RoundConfig.PHYSICS_BOX_SIZE
	rootPart.Color = RoundConfig.PHYSICS_BOX_COLOR
	rootPart.Material = Enum.Material.SmoothPlastic
	rootPart.TopSurface = Enum.SurfaceType.Smooth
	rootPart.BottomSurface = Enum.SurfaceType.Smooth
	rootPart.CanCollide = true
	rootPart.Anchored = false
	rootPart.CFrame = spawnCFrame

	-- Set physics properties (high friction so it doesn't slide on its own - LinearVelocity controls movement)
	rootPart.CustomPhysicalProperties = PhysicalProperties.new(
		RoundConfig.PHYSICS_BOX_DENSITY, -- Density
		1, -- Friction (high - we control movement via LinearVelocity)
		RoundConfig.SLIPPERY_ELASTICITY, -- Elasticity for collisions
		100, -- FrictionWeight
		1 -- ElasticityWeight
	)

	rootPart.Parent = physicsBox

	-- Set primary part for pivoting
	physicsBox.PrimaryPart = rootPart

	return physicsBox
end

-- Clones a skin model from ServerStorage
local function CloneSkinModel(skinId)
	local skinConfig = SkinsConfig.Skins[skinId]
	if not skinConfig then
		warn("[SkinService] Skin not found:", skinId)
		return nil
	end

	if not SKINS_FOLDER then
		warn("[SkinService] Skins folder not found in ServerStorage")
		return nil
	end

	local skinTemplate = SKINS_FOLDER:FindFirstChild(skinConfig.ModelName)
	if not skinTemplate then
		warn("[SkinService] Skin model not found:", skinConfig.ModelName)
		return nil
	end

	return skinTemplate:Clone()
end

-- API Functions --

-- Creates a physics box character for the player
-- Returns the physics box model
function SkinService:CreatePhysicsCharacter(player, spawnCFrame)
	local character = player.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			-- Store original description for later restoration
			local success, description = pcall(function()
				return humanoid:GetAppliedDescription()
			end)
			if success and description then
				_OriginalDescriptions[player] = description:Clone()
				DebugLog("Stored original description for", player.Name)
			end
		end
	end

	-- Create the physics box
	local physicsBox = CreatePhysicsBox(player, spawnCFrame)
	physicsBox.Parent = workspace

	-- Set as player's character
	player.Character = physicsBox

	DebugLog("Created physics character for", player.Name)
	return physicsBox
end

-- Attaches a cosmetic skin to the physics box
function SkinService:AttachSkin(physicsBox, skinId)
	skinId = skinId or SkinsConfig.DEFAULT_SKIN

	local skinModel = CloneSkinModel(skinId)
	if not skinModel then
		DebugLog("No skin model found, using plain box")
		return false
	end

	local rootPart = physicsBox:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		warn("[SkinService] Physics box missing HumanoidRootPart")
		skinModel:Destroy()
		return false
	end

	local skinPrimaryPart = skinModel.PrimaryPart
	if not skinPrimaryPart then
		warn("[SkinService] Skin model missing PrimaryPart")
		skinModel:Destroy()
		return false
	end

	-- Make all skin parts massless and non-collidable
	for _, part in ipairs(skinModel:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Massless = true
		end
	end

	-- Position skin so Floor attachment aligns with bottom of physics box
	local boxBottomY = -RoundConfig.PHYSICS_BOX_SIZE.Y / 2
	local floorAttachment = skinModel:FindFirstChild("Floor", true)

	if floorAttachment and floorAttachment:IsA("Attachment") then
		-- Use Floor attachment to determine offset, rotate 180 to face correct direction
		local floorOffset = floorAttachment.Position
		skinModel:PivotTo(rootPart.CFrame * CFrame.new(-floorOffset.X, boxBottomY - floorOffset.Y, -floorOffset.Z) * CFrame.Angles(0, math.pi, 0))
	else
		-- Fallback: assume pivot is at feet, rotate 180 to face correct direction
		skinModel:PivotTo(rootPart.CFrame * CFrame.new(0, boxBottomY, 0) * CFrame.Angles(0, math.pi, 0))
	end

	-- Single weld from skin's PrimaryPart to physics box root
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = rootPart
	weld.Part1 = skinPrimaryPart
	weld.Parent = rootPart

	-- Parent skin to physics box
	skinModel.Name = "Skin"
	skinModel.Parent = physicsBox

	DebugLog("Attached skin", skinId, "to physics box")
	return true
end

-- Restores the player's original character
function SkinService:RestoreOriginalCharacter(player)
	local description = _OriginalDescriptions[player]

	-- Respawn the player with their original character
	player:LoadCharacter()

	-- Wait for new character
	local newCharacter = player.Character or player.CharacterAdded:Wait()
	local newHumanoid = newCharacter:WaitForChild("Humanoid", 5)
	local newHRP = newCharacter:WaitForChild("HumanoidRootPart", 5)

	-- Apply original description if we have it
	if newHumanoid and description then
		pcall(function()
			newHumanoid:ApplyDescription(description)
		end)
	end

	-- Move to lobby position
	if newHRP then
		newHRP.CFrame = CFrame.new(RoundConfig.LOBBY_SPAWN_POSITION)
	end

	_OriginalDescriptions[player] = nil
	DebugLog("Restored original character for", player.Name)
end

-- Gets the skin ID for a player from their stored data
function SkinService:GetPlayerSkin(player)
	local stored = DataStream.Stored[player]
	if stored then
		local equipped = stored.Skins.Equipped:Read()
		if equipped and SkinsConfig.Skins[equipped] then
			return equipped
		end
	end
	return SkinsConfig.DEFAULT_SKIN
end

-- Cleanup when player leaves
local function OnPlayerRemoving(player)
	_OriginalDescriptions[player] = nil
end

-- Initializers --
function SkinService:Init()
	DebugLog("Initializing...")

	if not SKINS_FOLDER then
		warn("[SkinService] Skins folder not found! Create ServerStorage." .. SkinsConfig.SKINS_FOLDER_NAME)
	else
		local skinCount = 0
		for _ in pairs(SkinsConfig.Skins) do
			skinCount = skinCount + 1
		end
		DebugLog("Found", skinCount, "skins in config")
	end

	-- Handle EquipSkin remote event
	EquipSkinRemoteEvent.OnServerEvent:Connect(function(player, skinId)
		-- Validate skin exists
		if not SkinsConfig.Skins[skinId] then
			DebugLog(player.Name, "tried to equip invalid skin:", skinId)
			return
		end

		-- Validate player owns skin (has any mutation collected)
		local stored = DataStream.Stored[player]
		if not stored then return end

		local collected = stored.Skins.Collected:Read() or {}
		local ownskin = false
		for _, entry in ipairs(collected) do
			if entry.SkinId == skinId then
				ownskin = true
				break
			end
		end

		if not ownskin then
			DebugLog(player.Name, "tried to equip unowned skin:", skinId)
			return
		end

		-- Equip the skin
		stored.Skins.Equipped = skinId
		DebugLog(player.Name, "equipped skin:", skinId)
	end)

	Players.PlayerRemoving:Connect(OnPlayerRemoving)
end

-- Return Module --
return SkinService
