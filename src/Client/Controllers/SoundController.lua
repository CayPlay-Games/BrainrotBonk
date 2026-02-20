--[[
    SoundController.lua
    Author(s): arcoorio

    Description:
        Dynamic controller for sounds.

--]]

-- Root --
local SoundController = {}

-- Roblox Services --
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

-- Dependencies --
local SoundsConfig = shared("Configs/Sounds")

-- Object References --

-- Constants --

-- Private Variables --
local _Sounds = {}
local _SoundGroups = {
	["SFX"] = Instance.new("SoundGroup"),
	["Music"] = Instance.new("SoundGroup"),
	["Ambient"] = Instance.new("SoundGroup"),
}

-- Public Variables --

-- Internal Functions --

-- API Functions --
function SoundController:AdjustGroupVolume(GroupName: string, NewVolume: number)
	local SoundGroup = _SoundGroups[GroupName]
	if not SoundGroup then
		return
	end

	if NewVolume then
		SoundGroup.Volume = NewVolume
	end
end

function SoundController:PlaySound(GroupName: string, SoundName: string, Configs: {})
	local SoundGroup = _SoundGroups[GroupName]
	if not SoundGroup then
		return
	end

	local SoundConfig = SoundsConfig:Get(SoundName)
	if not SoundConfig then
		return
	end

	if not SoundConfig.SoundId then
		warn("Sound configuration must have a valid sound id!")
		return
	end

	Configs = Configs or {}

	-- Cache the sound
	local SoundObject = _Sounds[SoundName]
	local DefaultSpeed = SoundConfig.DefaultSpeed or 1
	local DefaultVolume = SoundConfig.DefaultVolume or 1
	if not SoundObject then
		SoundObject = Instance.new("Sound")
		SoundObject.Name = SoundName
		SoundObject.SoundId = SoundConfig.SoundId
		SoundObject.Volume = DefaultVolume
		SoundObject.PlaybackSpeed = DefaultSpeed
		SoundObject.Looped = SoundConfig.IsLooped or false
		SoundObject.Parent = SoundGroup
		_Sounds[SoundName] = SoundObject
	end

	-- Speed is always set - no fading
	SoundObject.PlaybackSpeed = Configs.Speed or DefaultSpeed

	local FadeTime = Configs.Fade
	if FadeTime then
		SoundObject.Volume = 0
		SoundObject:Play()

		TweenService:Create(SoundObject, TweenInfo.new(FadeTime), { Volume = Configs.Volume or DefaultVolume }):Play()
	else
		SoundObject.Volume = Configs.Volume or DefaultVolume
		SoundObject:Play()
	end
end

function SoundController:StopSound(GroupName: string, SoundName: string, Configs: {})
	local SoundGroup = _SoundGroups[GroupName]
	if not SoundGroup then
		return
	end

	local SoundConfig = SoundsConfig:Get(SoundName)
	if not SoundConfig then
		return
	end

	local SoundObject = _Sounds[SoundName]
	if not SoundObject then
		return
	end

	local FadeTime = Configs.Fade
	if FadeTime then
		local FadeTween = TweenService:Create(SoundObject, TweenInfo.new(FadeTime), { Volume = 0 })
		FadeTween:Play()
		FadeTween.Completed:Wait()
		SoundObject:Stop()
	else
		SoundObject:Stop()
	end
end

function SoundController:PlaySoundAtPosition(GroupName: string, SoundName: string, Position: Vector3, Configs: {})
	local SoundGroup = _SoundGroups[GroupName]
	if not SoundGroup then
		return
	end

	local SoundConfig = SoundsConfig:Get(SoundName)
	if not SoundConfig then
		return
	end

	if not SoundConfig.SoundId then
		warn("Sound configuration must have a valid sound id!")
		return
	end

	Configs = Configs or {}

	-- Create a temporary part to hold the positional sound
	local SoundPart = Instance.new("Part")
	SoundPart.Name = "SoundEmitter_" .. SoundName
	SoundPart.Size = Vector3.new(1, 1, 1)
	SoundPart.Position = Position
	SoundPart.Anchored = true
	SoundPart.CanCollide = false
	SoundPart.CanTouch = false
	SoundPart.CanQuery = false
	SoundPart.Transparency = 1
	SoundPart.Parent = Workspace

	-- Create the sound with 3D spatial properties
	local DefaultSpeed = SoundConfig.DefaultSpeed or 1
	local DefaultVolume = SoundConfig.DefaultVolume or 1

	local SoundObject = Instance.new("Sound")
	SoundObject.Name = SoundName
	SoundObject.SoundId = SoundConfig.SoundId
	SoundObject.Volume = Configs.Volume or DefaultVolume
	SoundObject.PlaybackSpeed = Configs.Speed or DefaultSpeed
	SoundObject.Looped = false -- Positional sounds don't loop
	SoundObject.RollOffMode = Enum.RollOffMode.Linear
	SoundObject.RollOffMinDistance = Configs.MinDistance or 10
	SoundObject.RollOffMaxDistance = Configs.MaxDistance or 100
	SoundObject.SoundGroup = SoundGroup
	SoundObject.Parent = SoundPart

	SoundObject:Play()

	-- Clean up after sound finishes
	SoundObject.Ended:Once(function()
		SoundPart:Destroy()
	end)

	-- Fallback cleanup with Debris
	Debris:AddItem(SoundPart, (SoundConfig.Duration or 10) + 1)

	return SoundObject
end

-- Initializers --
function SoundController:Init()
	for SoundGroupId, SoundGroup in _SoundGroups do
		SoundGroup.Name = SoundGroupId
		SoundGroup.Parent = SoundService
	end
end

-- Return Module --
return SoundController
