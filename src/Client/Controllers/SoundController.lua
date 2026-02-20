--[[
	SoundController.lua

	Description:
		Handles playing client-side SFX for UI and game events.

--]]

-- Root --
local SoundController = {}

-- Roblox Services --
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local Workspace = game:GetService("Workspace")

-- Dependencies --
local SoundsConfig = shared("SoundsConfig")

-- Object References --

-- Constants --
local DEFAULT_VOLUME = 1
local DEFAULT_PLAYBACK_SPEED = 1

-- Private Variables --
local _MasterVolume = 1
local _IsMuted = false
local _SoundCache = {}

-- Public Variables --

-- Internal Functions --
local function GetOrCreateSound(soundName)
	if _SoundCache[soundName] then
		return _SoundCache[soundName]
	end

	local assetId = SoundsConfig[soundName]
	if not assetId then
		warn("[SoundController] Sound not found in config: " .. tostring(soundName))
		return nil
	end

	local sound = Instance.new("Sound")
	sound.SoundId = assetId
	sound.Name = soundName

	_SoundCache[soundName] = sound

	return sound
end

local function PreloadSounds()
	local assets = {}
	for soundName, assetId in pairs(SoundsConfig) do
		local sound = Instance.new("Sound")
		sound.SoundId = assetId
		sound.Name = soundName
		_SoundCache[soundName] = sound
		table.insert(assets, sound)
	end

	task.spawn(function()
		ContentProvider:PreloadAsync(assets)
	end)
end

-- API Functions --
function SoundController:PlaySFX(soundName, options)
	if _IsMuted then
		return
	end

	local templateSound = GetOrCreateSound(soundName)
	if not templateSound then
		return
	end

	options = options or {}
	local volume = (options.Volume or DEFAULT_VOLUME) * _MasterVolume
	local playbackSpeed = options.PlaybackSpeed or DEFAULT_PLAYBACK_SPEED
	local position = options.Position

	local sound = templateSound:Clone()
	sound.Volume = volume
	sound.PlaybackSpeed = playbackSpeed

	if position then
		local part = Instance.new("Part")
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Transparency = 1
		part.Size = Vector3.new(0.1, 0.1, 0.1)
		part.Position = position
		part.Parent = Workspace

		sound.Parent = part
		sound:Play()

		sound.Ended:Once(function()
			part:Destroy()
		end)
	else
		sound.Parent = SoundService
		sound:Play()

		sound.Ended:Once(function()
			sound:Destroy()
		end)
	end
end

function SoundController:SetMasterVolume(volume)
	_MasterVolume = math.clamp(volume, 0, 1)
end

function SoundController:GetMasterVolume()
	return _MasterVolume
end

function SoundController:SetMuted(muted)
	_IsMuted = muted
end

function SoundController:IsMuted()
	return _IsMuted
end

-- Initializers --
function SoundController:Init()
	PreloadSounds()
end

function SoundController:Start() end

-- Return Module --
return SoundController
