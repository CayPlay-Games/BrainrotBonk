--[[
	SaladSpinnerDeathEffect.lua

	Description:
		Death effect for SaladSpinner map.
		Creates a burst of smaller parts using the skin's colors
		to simulate being "blended".
--]]

-- Roblox Services --
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Dependencies --
local BaseDeathEffect = shared("BaseDeathEffect")

-- Assets --
local ParticleEmittersFolder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("ParticleEmitters")

-- Root --
local SaladSpinnerDeathEffect = setmetatable({}, { __index = BaseDeathEffect })
SaladSpinnerDeathEffect.__index = SaladSpinnerDeathEffect

-- Constructor --
function SaladSpinnerDeathEffect.new(config)
	local self = setmetatable(BaseDeathEffect.new(config), SaladSpinnerDeathEffect)
	return self
end

local function HideModel(model)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Transparency = 1
		end
	end
end

function SaladSpinnerDeathEffect:_CreateParticleBurst(position)
	local redTemplate = ParticleEmittersFolder:FindFirstChild("Red")
	if not redTemplate then
		return nil
	end

	local redModel = redTemplate:Clone()
	redModel:PivotTo(CFrame.new(position))
	redModel.Parent = Workspace

	for _, emitter in ipairs(redModel:GetDescendants()) do
		if emitter:IsA("ParticleEmitter") then
			emitter:Emit(50)
		end
	end

	Debris:AddItem(redModel, 2)
	table.insert(self._createdParts, redModel)
	return redModel
end

-- Play the blending effect
function SaladSpinnerDeathEffect:Play(skinData, duration, playerName)
	if not skinData then return end

	local settings = self.Settings
	local partCount = settings.PartCount or 15
	local partSizeMin = settings.PartSizeMin or 0.3
	local partSizeMax = settings.PartSizeMax or 0.8
	local scatterForce = settings.ScatterForce or 25
	local upwardBias = settings.ScatterUpwardBias or 0.4
	local spinSpeed = settings.SpinSpeed or 20
	local fadeDelay = settings.FadeDelay or 1.5
	local fadeDuration = settings.FadeDuration or 1.0

	local centerPos = skinData.Position

	-- Find the actual physics box and skin model in workspace
	local physicsBox = playerName and Workspace:FindFirstChild(playerName)
	local skinModel = physicsBox and physicsBox:FindFirstChild("Skin")

	if skinModel then
		HideModel(skinModel)
	end

	-- Check if this is the local player
	local localPlayer = Players.LocalPlayer
	local isLocalPlayer = localPlayer and localPlayer.Name == playerName
	local cameraSubjectPart = nil

	-- Create scattered pieces
	local createdParts = {}
	for i = 1, partCount do
		local size = math.random() * (partSizeMax - partSizeMin) + partSizeMin

		local piece = self:CreatePart({
			Name = "BlendPiece",
			Size = Vector3.new(size, size, size),
			Color = Color3.new(0.505882, 0.031372, 0.031372),
			Material = Enum.Material.SmoothPlastic,
			Position = centerPos + Vector3.new(
				(math.random() - 0.5) * 2,
				math.random() * 1.5,
				(math.random() - 0.5) * 2
			),
			Anchored = false,
			CanCollide = true,
		})

		-- Apply scatter velocity
		local direction = Vector3.new(
			math.random() - 0.5,
			upwardBias + math.random() * (1 - upwardBias),
			math.random() - 0.5
		).Unit

		piece.AssemblyLinearVelocity = direction * scatterForce
		piece.AssemblyAngularVelocity = Vector3.new(
			(math.random() - 0.5) * spinSpeed,
			(math.random() - 0.5) * spinSpeed,
			(math.random() - 0.5) * spinSpeed
		)

		-- Use first piece as camera subject
		if i == 1 then
			cameraSubjectPart = piece
		end

		table.insert(createdParts, piece)

		-- Schedule fade out
		task.delay(fadeDelay, function()
			if piece.Parent then
				local tweenInfo = TweenInfo.new(fadeDuration, Enum.EasingStyle.Quad)
				local tween = TweenService:Create(piece, tweenInfo, {
					Transparency = 1,
				})
				tween:Play()
			end
		end)

		-- Debris cleanup as fallback
		Debris:AddItem(piece, duration + 1)
	end

	-- Set camera subject to one of the pieces for local player
	if isLocalPlayer and cameraSubjectPart then
		local camera = Workspace.CurrentCamera
		if camera then
			camera.CameraSubject = cameraSubjectPart
		end
	end

	-- Add particle burst at center
	self:_CreateParticleBurst(centerPos)
end

-- Return Module --
return SaladSpinnerDeathEffect
