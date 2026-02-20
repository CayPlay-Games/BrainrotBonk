--[[
	ButtonEffects.lua

	Description:
		Provides uniform hover effects for UI buttons.
		Adds scale animation and hover and click sound to ImageButton and TextButton instances.
--]]

-- Root --
local ButtonEffects = {}

-- Roblox Services --
local TweenService = game:GetService("TweenService")

-- Dependencies --
local SoundController = shared("SoundController")

-- Constants --
local HOVER_SCALE = 1.05
local NORMAL_SCALE = 1.0
local TWEEN_INFO_HOVER = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_INFO_UNHOVER = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

-- Private Variables --
local _SetupButtons = {}

-- Private Functions --
local function IsTemplateButton(button)
	local name = button.Name
	return name == "_Template" or name == "Template"
end

-- API Functions --
function ButtonEffects:SetupButton(button, options)
	if not button or not button:IsA("GuiButton") then
		return
	end

	-- Skip template buttons
	if IsTemplateButton(button) then
		return
	end

	if _SetupButtons[button] then
		return
	end
	_SetupButtons[button] = true

	options = options or {}
	local playSound = options.playSound ~= false
	local hoverScale = options.scale or HOVER_SCALE

	-- Get or create UIScale
	local uiScale = button:FindFirstChildOfClass("UIScale")
	if not uiScale then
		uiScale = Instance.new("UIScale")
		uiScale.Name = "HoverUIScale"
		uiScale.Scale = NORMAL_SCALE
		uiScale.Parent = button
	end

	-- Store original scale for buttons that already had UIScale
	local originalScale = uiScale.Scale

	-- Hover enter
	button.MouseEnter:Connect(function()
		-- Skip if button is inactive
		if not button.Active then
			return
		end

		if playSound then
			SoundController:PlaySound("SFX", "MouseHover")
		end

		local targetScale = originalScale * hoverScale
		local tween = TweenService:Create(uiScale, TWEEN_INFO_HOVER, { Scale = targetScale })
		tween:Play()
	end)

	-- Hover exit
	button.MouseLeave:Connect(function()
		local tween = TweenService:Create(uiScale, TWEEN_INFO_UNHOVER, { Scale = originalScale })
		tween:Play()
	end)

	-- Click sound
	button.MouseButton1Click:Connect(function()
		if playSound then
			SoundController:PlaySound("SFX", "MouseClick")
		end
	end)

	button.Destroying:Connect(function()
		_SetupButtons[button] = nil
	end)
end

function ButtonEffects:SetupAllButtons(container, options)
	if not container then
		return
	end

	for _, descendant in container:GetDescendants() do
		if descendant:IsA("GuiButton") then
			self:SetupButton(descendant, options)
		end
	end
end

function ButtonEffects:SetupDynamicButtons(container, options)
	if not container then
		return
	end

	-- Setup existing buttons
	self:SetupAllButtons(container, options)

	-- Setup future buttons
	container.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("GuiButton") then
			self:SetupButton(descendant, options)
		end
	end)
end

return ButtonEffects
