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
local CollectionService = game:GetService("CollectionService")
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

-- Gets a physics value from DebugPhysics DataStream (for runtime tuning)
local function GetDebugPhysics(key)
	local debugPhysics = DataStream.DebugPhysics
	if debugPhysics and debugPhysics[key] then
		return debugPhysics[key]:Read()
	end
	return nil
end

-- Creates the standardized physics box model
local function CreatePhysicsBox(player, spawnCFrame)
	local physicsBox = Instance.new("Model")
	physicsBox.Name = player.Name

	-- Create the main physics body (box)
	local rootPart

	-- Check if a custom hitbox template is specified
	if RoundConfig.PHYSICS_BOX_TEMPLATE then
		local template = ServerStorage:FindFirstChild(RoundConfig.PHYSICS_BOX_TEMPLATE)
		if template and template:IsA("BasePart") then
			rootPart = template:Clone()
			DebugLog("Using custom hitbox template:", RoundConfig.PHYSICS_BOX_TEMPLATE)
		else
			warn("[SkinService] Custom hitbox template not found in ServerStorage:", RoundConfig.PHYSICS_BOX_TEMPLATE)
		end
	end

	-- Fallback to creating a new Part if no template or template not found
	if not rootPart then
		rootPart = Instance.new("Part")
		rootPart.Material = Enum.Material.SmoothPlastic
		rootPart.TopSurface = Enum.SurfaceType.Smooth
		rootPart.BottomSurface = Enum.SurfaceType.Smooth
	end

	-- Apply standard properties from config (overrides template properties)
	rootPart.Name = "HumanoidRootPart"
	rootPart.Size = Vector3.new(
		GetDebugPhysics("PHYSICS_BOX_SIZE_X") or 3.5,
		GetDebugPhysics("PHYSICS_BOX_SIZE_Y") or 5,
		GetDebugPhysics("PHYSICS_BOX_SIZE_Z") or 3.5
	)
	rootPart.Color = RoundConfig.PHYSICS_BOX_COLOR
	rootPart.CanCollide = true
	rootPart.Anchored = false
	rootPart.Transparency = 0.8
	rootPart.CFrame = spawnCFrame

	-- Set physics properties (low friction for curling-disc physics)
	rootPart.CustomPhysicalProperties = PhysicalProperties.new(
		GetDebugPhysics("PHYSICS_BOX_DENSITY") or 25, -- Density
		GetDebugPhysics("PHYSICS_BOX_FRICTION") or 0.05, -- Friction (low for ice-like sliding)
		GetDebugPhysics("PHYSICS_BOX_ELASTICITY") or 0.4, -- Elasticity for bouncy collisions
		1, -- FrictionWeight (low, let floor friction dominate)
		100 -- ElasticityWeight (high for consistent bounces)
	)

	-- Dampen rotation (resists slow drift but allows collision-based rotation)
	local angularVelocity = Instance.new("AngularVelocity")
	angularVelocity.Attachment0 = Instance.new("Attachment", rootPart)
	angularVelocity.AngularVelocity = Vector3.zero
	angularVelocity.MaxTorque = 5000
	angularVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	angularVelocity.Parent = rootPart

	rootPart.Parent = physicsBox

	-- Set primary part for pivoting
	physicsBox.PrimaryPart = rootPart

	return physicsBox
end

-- Clones a skin model from ServerStorage
local function CloneSkinModel(skinId, mutation)
	mutation = mutation or "Normal"

	local skinConfig = SkinsConfig.Skins[skinId]
	if not skinConfig then
		warn("[SkinService] Skin not found:", skinId)
		return nil
	end

	if not SKINS_FOLDER then
		warn("[SkinService] Skins folder not found in ServerStorage")
		return nil
	end

	-- Look for nested structure: Skins/Fluriflura/Normal
	local skinFolder = SKINS_FOLDER:FindFirstChild(skinConfig.ModelName)
	if skinFolder and skinFolder:IsA("Folder") then
		-- Try mutation-specific model
		local mutationModel = skinFolder:FindFirstChild(mutation)
		if mutationModel then
			return mutationModel:Clone()
		end

		-- Fallback to Normal if mutation missing
		if mutation ~= "Normal" then
			warn("[SkinService] Mutation not found:", mutation, "for", skinId, "- using Normal")
			local normalModel = skinFolder:FindFirstChild("Normal")
			if normalModel then
				return normalModel:Clone()
			end
		end

		warn("[SkinService] No mutations in folder:", skinConfig.ModelName)
		return nil
	end

	-- Legacy fallback: flat structure (backwards compatible)
	local legacyModel = SKINS_FOLDER:FindFirstChild(skinConfig.ModelName)
	if legacyModel and legacyModel:IsA("Model") then
		return legacyModel:Clone()
	end

	warn("[SkinService] Model not found:", skinConfig.ModelName)
	return nil
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
function SkinService:AttachSkin(physicsBox, skinId, mutation)
	skinId = skinId or SkinsConfig.DEFAULT_SKIN
	mutation = mutation or "Normal"

	local skinModel = CloneSkinModel(skinId, mutation)
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
	local boxBottomY = -(GetDebugPhysics("PHYSICS_BOX_SIZE_Y") or 5) / 2
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

	-- Store skinId as attribute for client-side animation lookup
	skinModel:SetAttribute("SkinId", skinId)

	-- Tag for client-side animation controller to detect
	CollectionService:AddTag(skinModel, "Skin")

	DebugLog("Attached skin", skinId, "to physics box")
	return true
end

-- Updates physics box properties from current debug values (for runtime tuning)
function SkinService:UpdatePhysicsBoxProperties(player)
	local character = player.Character
	if not character then return false end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart or not rootPart:IsA("Part") then return false end

	-- Update size
	local newSize = Vector3.new(
		GetDebugPhysics("PHYSICS_BOX_SIZE_X") or 3.5,
		GetDebugPhysics("PHYSICS_BOX_SIZE_Y") or 5,
		GetDebugPhysics("PHYSICS_BOX_SIZE_Z") or 3.5
	)
	rootPart.Size = newSize

	-- Update physics properties
	rootPart.CustomPhysicalProperties = PhysicalProperties.new(
		GetDebugPhysics("PHYSICS_BOX_DENSITY") or 25,
		GetDebugPhysics("PHYSICS_BOX_FRICTION") or 0.05,
		GetDebugPhysics("PHYSICS_BOX_ELASTICITY") or 0.4,
		1, -- FrictionWeight
		100 -- ElasticityWeight
	)

	-- Reposition skin to match new box size
	local skinModel = character:FindFirstChild("Skin")
	if skinModel then
		local skinPrimaryPart = skinModel.PrimaryPart or skinModel:FindFirstChildWhichIsA("BasePart")
		if skinPrimaryPart then
			local boxBottomY = -newSize.Y / 2
			local floorAttachment = skinModel:FindFirstChild("Floor", true)

			if floorAttachment and floorAttachment:IsA("Attachment") then
				local floorOffset = floorAttachment.Position
				skinModel:PivotTo(rootPart.CFrame * CFrame.new(-floorOffset.X, boxBottomY - floorOffset.Y, -floorOffset.Z) * CFrame.Angles(0, math.pi, 0))
			else
				skinModel:PivotTo(rootPart.CFrame * CFrame.new(0, boxBottomY, 0) * CFrame.Angles(0, math.pi, 0))
			end
		end
	end

	DebugLog("Updated physics box properties for", player.Name)
	return true
end

-- Restores the player's original character
function SkinService:RestoreOriginalCharacter(player)
	-- Check if player is still in the game
	if not player or not player.Parent then
		return
	end

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

-- Gets the mutation ID for a player from their stored data
function SkinService:GetPlayerSkinMutation(player)
	local stored = DataStream.Stored[player]
	if stored then
		local mutation = stored.Skins.EquippedMutation:Read()
		if mutation and SkinsConfig.Mutations[mutation] then
			return mutation
		end
	end
	return "Normal"
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
	EquipSkinRemoteEvent.OnServerEvent:Connect(function(player, skinId, mutation)
		mutation = mutation or "Normal"

		-- Validate skin exists
		if not SkinsConfig.Skins[skinId] then
			DebugLog(player.Name, "tried to equip invalid skin:", skinId)
			return
		end

		-- Validate mutation exists
		if not SkinsConfig.Mutations[mutation] then
			DebugLog(player.Name, "tried to equip invalid mutation:", mutation)
			return
		end

		-- Validate player owns this specific skin+mutation combo
		local stored = DataStream.Stored[player]
		if not stored then return end

		local itemId = skinId .. "_" .. mutation
		local ownedSkins = stored.Collections and stored.Collections.Skins and stored.Collections.Skins:Read() or {}
		local ownsMutation = (ownedSkins[itemId] or 0) >= 1

		if not ownsMutation then
			DebugLog(player.Name, "tried to equip unowned skin+mutation:", skinId, mutation)
			return
		end

		-- Equip the skin and mutation
		stored.Skins.Equipped = skinId
		stored.Skins.EquippedMutation = mutation
		DebugLog(player.Name, "equipped skin:", skinId, "mutation:", mutation)
	end)

	Players.PlayerRemoving:Connect(OnPlayerRemoving)
end

-- Return Module --
return SkinService
