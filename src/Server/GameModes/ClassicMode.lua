--[[
	ClassicMode.lua

	Description:
		Classic game mode - map shrinks by a percentage at the end of each round.
		Shrinking happens after Resolution state, before the next Aiming state.
--]]

-- Roblox Services --
local TweenService = game:GetService("TweenService")

-- Dependencies --
local BaseGameMode = shared("BaseGameMode")
local MapService = shared("MapService")

-- Root --
local ClassicMode = setmetatable({}, { __index = BaseGameMode })
ClassicMode.__index = ClassicMode

-- Internal Functions --

local function DebugLog(...)
	print("[ClassicMode]", ...)
end

function ClassicMode.new(settings)
	local self = setmetatable(BaseGameMode.new(settings), ClassicMode)

	-- Mode state
	self._currentScale = 1.0
	self._mapInstance = nil
	self._originalPivot = nil
	self._shrinkableDescendants = {}

	-- Settings with defaults
	self._shrinkPercentage = settings.ShrinkPercentage or 0.10
	self._minimumScale = settings.MinimumScale or 0.5
	self._shrinkDuration = settings.ShrinkDuration or 1.5
	self._shrinkEasing = settings.ShrinkEasing or "Quad"

	return self
end

-- Store map reference and original state
function ClassicMode:OnMapLoaded(mapInstance)
	if not mapInstance then
		warn("[ClassicMode] OnMapLoaded called with nil mapInstance")
		return
	end

	self._mapInstance = mapInstance
	self._currentScale = 1.0

	-- Store original pivot point (center of map)
	self._originalPivot = mapInstance:GetPivot()

	-- Cache all shrinkable parts (only Platform model and its descendants)
	self._shrinkableDescendants = {}

	local platform = mapInstance:FindFirstChild("Platform")
	if platform then
		-- Include the Platform itself if it's a BasePart
		if platform:IsA("BasePart") then
			table.insert(self._shrinkableDescendants, {
				Part = platform,
				OriginalSize = platform.Size,
				OriginalCFrame = platform.CFrame,
			})
		end

		-- Include all BasePart descendants of Platform
		for _, descendant in ipairs(platform:GetDescendants()) do
			if descendant:IsA("BasePart") then
				table.insert(self._shrinkableDescendants, {
					Part = descendant,
					OriginalSize = descendant.Size,
					OriginalCFrame = descendant.CFrame,
				})
			end
		end
	else
		warn("[ClassicMode] No 'Platform' model found in map")
	end

	DebugLog("Map loaded, cached", #self._shrinkableDescendants, "shrinkable parts")
end

-- Shrink the map at the end of each round
function ClassicMode:OnRoundEnd(roundNumber)
	if not self._mapInstance then
		return
	end

	-- Calculate new scale
	local newScale = self._currentScale * (1 - self._shrinkPercentage)

	-- Don't shrink below minimum
	if newScale < self._minimumScale then
		DebugLog("Already at minimum scale, not shrinking further")
		return
	end

	DebugLog("Shrinking map from", string.format("%.0f%%", self._currentScale * 100), "to", string.format("%.0f%%", newScale * 100))

	-- Perform the shrink animation
	self:_AnimateShrink(newScale)

	self._currentScale = newScale
end

-- Animate shrinking all parts
function ClassicMode:_AnimateShrink(targetScale)
	local tweenInfo = TweenInfo.new(
		self._shrinkDuration,
		Enum.EasingStyle[self._shrinkEasing] or Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)

	local mapPivot = self._originalPivot

	for _, data in ipairs(self._shrinkableDescendants) do
		local part = data.Part
		if not part or not part.Parent then
			continue
		end

		-- Calculate new size (only scale X and Z, keep Y unchanged to maintain thickness)
		local newSize = Vector3.new(
			data.OriginalSize.X * targetScale,
			data.OriginalSize.Y,
			data.OriginalSize.Z * targetScale
		)

		-- Calculate new position relative to map center (only scale X and Z to prevent sinking)
		local originalOffset = data.OriginalCFrame.Position - mapPivot.Position
		local scaledOffset = Vector3.new(
			originalOffset.X * targetScale,
			originalOffset.Y, -- Keep Y unchanged
			originalOffset.Z * targetScale
		)
		local newPosition = mapPivot.Position + scaledOffset

		-- Create new CFrame preserving rotation
		local newCFrame = CFrame.new(newPosition) * (data.OriginalCFrame - data.OriginalCFrame.Position)

		-- Anchor part temporarily for tweening
		local wasAnchored = part.Anchored
		part.Anchored = true

		-- Tween size and position
		local tween = TweenService:Create(part, tweenInfo, {
			Size = newSize,
			CFrame = newCFrame,
		})

		tween:Play()

		-- Restore anchored state after tween
		if not wasAnchored then
			tween.Completed:Connect(function()
				part.Anchored = false
			end)
		end
	end
end

-- Cleanup on deactivation
function ClassicMode:OnDeactivate()
	self._mapInstance = nil
	self._shrinkableDescendants = {}
	self._currentScale = 1.0
	DebugLog("Deactivated")
end

return ClassicMode
