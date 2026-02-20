--[[
	ElectroTubDeathEffect.lua

	Description:
		Death effect for ElectroTub map.
		Flashes the player's actual skin with a black texture and electric particles
		to simulate electrocution.
--]]

-- Roblox Services --
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Dependencies --
local BaseDeathEffect = shared("BaseDeathEffect")
local SoundController = shared("SoundController")
local ModelHelper = shared("ModelHelper")

-- Assets --
local ParticleEmittersFolder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("ParticleEmitters")

-- Root --
local ElectroTubDeathEffect = setmetatable({}, { __index = BaseDeathEffect })
ElectroTubDeathEffect.__index = ElectroTubDeathEffect

-- Constructor --
function ElectroTubDeathEffect.new(config)
	local self = setmetatable(BaseDeathEffect.new(config), ElectroTubDeathEffect)
	return self
end

function ElectroTubDeathEffect:_CreateElectricParticles(position)
	local electrifiedTemplate = ParticleEmittersFolder:FindFirstChild("Electrified")
	if not electrifiedTemplate then
		return nil
	end

	local electrifiedModel = electrifiedTemplate:Clone()
	electrifiedModel:PivotTo(CFrame.new(position))
	electrifiedModel.Parent = Workspace

	for _, emitter in ipairs(electrifiedModel:GetDescendants()) do
		if emitter:IsA("ParticleEmitter") then
			emitter:Emit(50)
		end
	end

	table.insert(self._createdParts, electrifiedModel)
	return electrifiedModel
end

function ElectroTubDeathEffect:Play(skinData, duration, playerName)
	if not skinData then return end

	local settings = self.Settings
	local flashCount = settings.FlashCount or 5
	local flashInterval = settings.FlashInterval or 0.15
	local shakeAmplitude = settings.ShakeAmplitude or 0.3

	local centerPos = skinData.Position

	-- Find the actual physics box and skin model in workspace
	local physicsBox = playerName and Workspace:FindFirstChild(playerName)
	local skinModel = physicsBox and physicsBox:FindFirstChild("Skin")

	-- SFX
	SoundController:PlaySoundAtPosition("SFX", "ElectroTubDeath", centerPos, {})

	-- Create electric particle emitters
	local electricEmitter = self:_CreateElectricParticles(centerPos)

	if skinModel then
		-- Collect actual skin parts for shake effect
		local skinParts = {}
		for _, part in ipairs(skinModel:GetDescendants()) do
			if part:IsA("BasePart") then
				table.insert(skinParts, {
					part = part,
					originalCFrame = part.CFrame,
				})
			end
		end

		-- Flash animation on the actual skin using texture swap
		task.spawn(function()
			local originalTextures = nil

			for i = 1, flashCount do
				-- Alternate between blackout and normal
				local isBlack = i % 2 == 0

				if isBlack then
					originalTextures = ModelHelper:BlackoutModel(skinModel)
				elseif originalTextures then
					ModelHelper:RestoreTextures(originalTextures)
					originalTextures = nil
				end

				-- Apply shake
				for _, data in ipairs(skinParts) do
					if data.part.Parent then
						local shakeOffset = Vector3.new(
							(math.random() - 0.5) * shakeAmplitude,
							(math.random() - 0.5) * shakeAmplitude,
							(math.random() - 0.5) * shakeAmplitude
						)
						data.part.CFrame = data.originalCFrame + shakeOffset
					end
				end

				task.wait(flashInterval)
			end

			-- Final charred state - apply black texture permanently
			ModelHelper:BlackoutModel(skinModel)

			-- Reset positions
			for _, data in ipairs(skinParts) do
				if data.part.Parent then
					data.part.CFrame = data.originalCFrame
				end
			end

			-- Stop particles after flashing
			task.delay(0.3, function()
				if electricEmitter.Parent then
					local emitterChild = electricEmitter:FindFirstChildOfClass("ParticleEmitter")
					if emitterChild then
						emitterChild.Rate = 0
					end
				end
			end)

			-- Fade out the actual skin after a moment
			task.delay(0.5, function()
				local fadeInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad)
				for _, data in ipairs(skinParts) do
					if data.part.Parent then
						local tween = TweenService:Create(data.part, fadeInfo, {
							Transparency = 1,
						})
						tween:Play()
					end
				end
			end)
		end)
	end

	-- Debris cleanup as fallback
	Debris:AddItem(electricEmitter, duration + 1)
end

-- Return Module --
return ElectroTubDeathEffect
