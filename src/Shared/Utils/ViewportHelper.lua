--[[
	ViewportHelper.lua

	Description:
		Utility for working with ViewportFrames.
		Calculates optimal camera distance for models of varying sizes.
--]]

local ViewportHelper = {}

-- Default settings
local DEFAULT_FOV = 50
local DEFAULT_PADDING = 1.2 -- 20% padding around the model

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
-- @param camera: The camera (optional, will create if not provided)
-- @return clone: The cloned model in the viewport
-- @return camera: The camera used
function ViewportHelper.DisplayModel(viewport, model, camera)
	-- Create camera if not provided
	if not camera then
		camera = viewport:FindFirstChildOfClass("Camera")
		if not camera then
			camera = Instance.new("Camera")
			camera.FieldOfView = DEFAULT_FOV
			camera.Parent = viewport
			viewport.CurrentCamera = camera
		end
	end

	-- Clone and parent model
	local clone = model:Clone()
	clone.Parent = viewport

	-- Calculate distance and position
	local distance = ViewportHelper.CalculateDistance(clone, camera.FieldOfView)

	-- Set camera at origin
	camera.CFrame = CFrame.new(0, 0, 0)

	-- Position model in front of camera
	clone:PivotTo(CFrame.new(0, 0, -distance))

	return clone, camera
end

return ViewportHelper
