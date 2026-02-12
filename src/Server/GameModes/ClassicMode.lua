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
	self._mapInstance = mapInstance
	self._currentScale = 1.0

	-- Store original pivot point (center of map)
	self._originalPivot = mapInstance:GetPivot()

	-- Cache all shrinkable parts (exclude KillPart, SpawnPoints, etc.)
	self._shrinkableDescendants = {}
	for _, descendant in ipairs(mapInstance:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local shouldShrink = true

			-- Exclude certain parts from shrinking
			if descendant.Name == "KillPart" then
				shouldShrink = false
			end

			-- Check if part is in SpawnPoints folder
			if descendant:FindFirstAncestor("SpawnPoints") then
				shouldShrink = false
			end

			if shouldShrink then
				table.insert(self._shrinkableDescendants, {
					Part = descendant,
					OriginalSize = descendant.Size,
					OriginalCFrame = descendant.CFrame,
				})
			end
		end
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

		-- Calculate new size
		local newSize = data.OriginalSize * targetScale

		-- Calculate new position relative to map center
		local originalOffset = data.OriginalCFrame.Position - mapPivot.Position
		local scaledOffset = originalOffset * targetScale
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
