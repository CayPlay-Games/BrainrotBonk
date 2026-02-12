--[[
	SpectateController.lua

	Description:
		Handles camera positioning and cycling through spectate points on maps.
		Spectate points are Parts in the map's "Spectate" folder with "Location" attributes.
--]]

-- Root --
local SpectateController = {}

-- Roblox Services --
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

-- Dependencies --
local RoundConfig = shared("RoundConfig")

-- Object References --
local LocalPlayer = Players.LocalPlayer
local CurrentCamera = Workspace.CurrentCamera

-- Constants --
local CAMERA_TWEEN_INFO = TweenInfo.new(
	0.5, -- Duration
	Enum.EasingStyle.Quad,
	Enum.EasingDirection.Out
)

-- Private Variables --
local _IsSpectating = false
local _SpectatePoints = {} -- Array of Parts from Spectate folder
local _CurrentPointIndex = 1
local _CurrentTween = nil
local _OriginalCameraType = nil
local _OriginalCameraSubject = nil

-- Internal Functions --

local function DebugLog(...)
	if RoundConfig.DEBUG_LOG_STATE_CHANGES then
		print("[SpectateController]", ...)
	end
end

-- Retrieves and sorts spectate points from CurrentMap
local function GetSpectatePoints()
	local currentMap = Workspace:FindFirstChild("CurrentMap")
	if not currentMap then
		DebugLog("No CurrentMap found")
		return {}
	end

	local spectateFolder = currentMap:FindFirstChild("Spectate")
	if not spectateFolder then
		DebugLog("No Spectate folder found in map")
		return {}
	end

	local points = {}
	for _, child in spectateFolder:GetChildren() do
		if child:IsA("BasePart") then
			table.insert(points, child)
		end
	end

	-- Sort by name (assumes numbered parts: 1, 2, 3...)
	table.sort(points, function(a, b)
		local numA = tonumber(a.Name) or 999
		local numB = tonumber(b.Name) or 999
		return numA < numB
	end)

	DebugLog("Found", #points, "spectate points")
	return points
end

-- Smooth camera transition to a point
local function TweenCameraToPoint(point)
	if _CurrentTween then
		_CurrentTween:Cancel()
	end

	_CurrentTween = TweenService:Create(
		CurrentCamera,
		CAMERA_TWEEN_INFO,
		{ CFrame = point.CFrame }
	)
	_CurrentTween:Play()
end

-- Stores camera state before spectating
local function SaveOriginalCameraState()
	_OriginalCameraType = CurrentCamera.CameraType
	_OriginalCameraSubject = CurrentCamera.CameraSubject
end

-- Restores camera after spectating
local function RestoreOriginalCameraState()
	CurrentCamera.CameraType = _OriginalCameraType or Enum.CameraType.Custom

	local character = LocalPlayer.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			CurrentCamera.CameraSubject = humanoid
		end
	end
end

-- API Functions --

-- Starts spectating from the first point
function SpectateController:StartSpectating()
	if _IsSpectating then
		return false
	end

	_SpectatePoints = GetSpectatePoints()
	if #_SpectatePoints == 0 then
		warn("[SpectateController] No spectate points found")
		return false
	end

	SaveOriginalCameraState()

	_IsSpectating = true
	_CurrentPointIndex = 1

	CurrentCamera.CameraType = Enum.CameraType.Scriptable
	TweenCameraToPoint(_SpectatePoints[_CurrentPointIndex])

	DebugLog("Started spectating")
	return true
end

-- Stops spectating and restores camera
function SpectateController:StopSpectating()
	if not _IsSpectating then
		return
	end

	_IsSpectating = false

	if _CurrentTween then
		_CurrentTween:Cancel()
		_CurrentTween = nil
	end

	RestoreOriginalCameraState()

	_SpectatePoints = {}
	_CurrentPointIndex = 1

	DebugLog("Stopped spectating")
end

-- Cycles to the next spectate point
function SpectateController:NextPoint()
	if not _IsSpectating or #_SpectatePoints == 0 then
		return
	end

	_CurrentPointIndex = _CurrentPointIndex + 1
	if _CurrentPointIndex > #_SpectatePoints then
		_CurrentPointIndex = 1 -- Wrap around
	end

	TweenCameraToPoint(_SpectatePoints[_CurrentPointIndex])
	DebugLog("Moved to point", _CurrentPointIndex)
end

-- Cycles to the previous spectate point
function SpectateController:PreviousPoint()
	if not _IsSpectating or #_SpectatePoints == 0 then
		return
	end

	_CurrentPointIndex = _CurrentPointIndex - 1
	if _CurrentPointIndex < 1 then
		_CurrentPointIndex = #_SpectatePoints -- Wrap around
	end

	TweenCameraToPoint(_SpectatePoints[_CurrentPointIndex])
	DebugLog("Moved to point", _CurrentPointIndex)
end

-- Returns the Location attribute of the current spectate point
function SpectateController:GetCurrentLocation()
	if not _IsSpectating or #_SpectatePoints == 0 then
		return nil
	end

	local currentPoint = _SpectatePoints[_CurrentPointIndex]
	return currentPoint:GetAttribute("Location") or "Location " .. _CurrentPointIndex
end

-- Returns whether currently spectating
function SpectateController:IsSpectating()
	return _IsSpectating
end

-- Returns total number of spectate points
function SpectateController:GetPointCount()
	return #_SpectatePoints
end

-- Initializers --
function SpectateController:Init()
	DebugLog("Initializing...")
	-- No automatic initialization needed - controlled by SpectateWindowController
end

-- Return Module --
return SpectateController
