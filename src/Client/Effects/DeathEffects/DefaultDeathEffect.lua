--[[
	DefaultDeathEffect.lua

	Description:
		Simple fade-out death effect for maps without specific effects.
		Fades the actual skin model away.
--]]

-- Roblox Services --
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

-- Dependencies --
local BaseDeathEffect = shared("BaseDeathEffect")

-- Root --
local DefaultDeathEffect = setmetatable({}, { __index = BaseDeathEffect })
DefaultDeathEffect.__index = DefaultDeathEffect

-- Constructor --
function DefaultDeathEffect.new(config)
	local self = setmetatable(BaseDeathEffect.new(config), DefaultDeathEffect)
	return self
end

function DefaultDeathEffect:Play(skinData, duration, playerName)
	if not skinData then return end
	-- Play the simple fade effect on the actual skin
	local fadeOutDuration = self.Settings.FadeOutDuration or 0.8

	local physicsBox = playerName and Workspace:FindFirstChild(playerName)
	local skinModel = physicsBox and physicsBox:FindFirstChild("Skin")

	if skinModel then
		local tweenInfo = TweenInfo.new(fadeOutDuration, Enum.EasingStyle.Quad)

		for _, part in ipairs(skinModel:GetDescendants()) do
			if part:IsA("BasePart") then
				local tween = TweenService:Create(part, tweenInfo, {
					Transparency = 1,
				})
				tween:Play()
			end
		end
	end
end

-- Return Module --
return DefaultDeathEffect
