--[[
	DeathEffectsService.lua

	Description:
		Server-side orchestration for map-dependent death effects.
		Fires events to clients when a player dies, allowing visual effects
		before returning them to lobby.
--]]

-- Root --
local DeathEffectsService = {}

-- Dependencies --
local Promise = shared("Promise")
local GetRemoteEvent = shared("GetRemoteEvent")
local DeathEffectsConfig = shared("DeathEffectsConfig")
local MapsConfig = shared("MapsConfig")
local MapService = shared("MapService")
local SkinsConfig = shared("SkinsConfig")
local SkinService = shared("SkinService")

-- Remotes --
local PlayerDeathEffectEvent = GetRemoteEvent("PlayerDeathEffect")

-- Internal Functions --
local function ExtractSkinData(physicsBox, player)
	local skinModel = physicsBox:FindFirstChild("Skin")
	if not skinModel then
		return nil
	end

	-- Get mutation color
	local mutation = SkinService:GetPlayerSkinMutation(player)
	local mutationConfig = SkinsConfig.Mutations[mutation]
	local mutationColor = mutationConfig and mutationConfig.Color or Color3.new(1, 1, 1)

	local pivot = physicsBox:GetPivot()
	return {
		MutationColor = mutationColor,
		Position = pivot.Position,
	}
end

local function PreparePhysicsBoxForEffect(physicsBox)
	local hrp = physicsBox:FindFirstChild("HumanoidRootPart")
	if hrp then
		hrp.Transparency = 1
		hrp.Anchored = true
	end
end

-- API Functions --
function DeathEffectsService:GetCurrentMapDeathEffectId()
	local mapId = MapService:GetCurrentMapId()
	if not mapId then
		return "Default"
	end

	local mapConfig = MapsConfig.Maps[mapId]
	if mapConfig and mapConfig.DeathEffectId then
		return mapConfig.DeathEffectId
	end

	return "Default"
end

function DeathEffectsService:GetEffectDuration()
	local effectId = self:GetCurrentMapDeathEffectId()
	local effectConfig = DeathEffectsConfig.Effects[effectId]

	if effectConfig and effectConfig.Duration then
		return effectConfig.Duration
	end

	return DeathEffectsConfig.DEFAULT_EFFECT_DURATION
end

function DeathEffectsService:PlayDeathEffect(player, physicsBox)
	return Promise.new(function(resolve)
		local effectId = self:GetCurrentMapDeathEffectId()
		local duration = self:GetEffectDuration()

		-- Small delay to let client visuals catch up with server collision detection
		task.wait(0.15)

		-- Check physics box still exists after delay
		if not physicsBox or not physicsBox.Parent then
			resolve()
			return
		end

		local skinData = ExtractSkinData(physicsBox, player)

		-- Prepare the physics box for effect (anchor but keep skin visible)
		PreparePhysicsBoxForEffect(physicsBox)

		-- Fire to all clients
		PlayerDeathEffectEvent:FireAllClients({
			PlayerId = player.UserId,
			PlayerName = player.Name,
			EffectId = effectId,
			SkinData = skinData,
			Duration = duration,
		})

		-- Wait for effect duration then resolve
		task.delay(duration, function()
			resolve()
		end)
	end)
end

-- Initializers --
function DeathEffectsService:Init()
	-- No initialization needed currently
end

-- Return Module --
return DeathEffectsService
