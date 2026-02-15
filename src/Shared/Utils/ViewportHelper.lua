--[[
	ViewportHelper.lua

	Description:
		Utility for working with ViewportFrames.
		Provides camera management, model display, and viewport clearing.
--]]

local ViewportHelper = {}

-- Default settings
local DEFAULT_FOV = 50
local DEFAULT_PADDING = 1.2 -- 20% padding around the model

-- Clears all models and parts from a viewport (preserves camera)
function ViewportHelper.Clear(viewport)
	for _, child in viewport:GetChildren() do
		if child:IsA("Model") or child:IsA("BasePart") then
			child:Destroy()
		end
	end
end

-- Gets or creates a camera for a viewport
-- Always sets CurrentCamera and resets CFrame to origin
function ViewportHelper.GetCamera(viewport, fov)
	fov = fov or DEFAULT_FOV
	local camera = viewport:FindFirstChildOfClass("Camera")
	if not camera then
		camera = Instance.new("Camera")
		camera.FieldOfView = fov
		camera.Parent = viewport
	end
	viewport.CurrentCamera = camera
	camera.CFrame = CFrame.new(0, 0, 0)
	return camera
end

-- Calculates the distance needed to fit a model in a viewport
-- @param model: The model to calculate distance for
-- @param fov: Camera field of view (optional, defaults to 50)
-- @param padding: Multiplier for extra space around model (optional, defaults to 1.2)
-- @return distance: The distance to place the model from camera
function ViewportHelper.CalculateDistance(model, fov, padding)
	fov = fov or DEFAULT_FOV
	padding = padding or DEFAULT_PADDING

	-- Get model bounding box
	local _, size = model:GetBoundingBox()

	-- Use the largest dimension to ensure model fits
	local maxSize = math.max(size.X, size.Y, size.Z)

	-- Calculate distance using FOV trigonometry
	-- distance = (size / 2) / tan(FOV / 2)
	local halfFovRad = math.rad(fov / 2)
	local distance = (maxSize / 2) / math.tan(halfFovRad)

	-- Apply padding
	return distance * padding
end

-- Sets up a model in a viewport with automatic distance calculation
-- @param viewport: The ViewportFrame
-- @param model: The model to display (will be cloned)
-- @param clearFirst: Whether to clear existing models first (optional, defaults to true)
-- @return clone: The cloned model in the viewport
-- @return camera: The camera used
-- @return distance: The calculated distance
function ViewportHelper.DisplayModel(viewport, model, clearFirst)
	if clearFirst ~= false then
		ViewportHelper.Clear(viewport)
	end

	local camera = ViewportHelper.GetCamera(viewport)
	local clone = model:Clone()
	clone.Parent = viewport

	local distance = ViewportHelper.CalculateDistance(clone, camera.FieldOfView)
	clone:PivotTo(CFrame.new(0, 0, -distance))

	return clone, camera, distance
end

return ViewportHelper
