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

-- Dependencies --
local BetterWarn = shared("BetterWarn")
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
		BetterWarn("Sound configuration must have a valid sound id!")
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

-- Initializers --
function SoundController:Init()
	for SoundGroupId, SoundGroup in _SoundGroups do
		SoundGroup.Name = SoundGroupId
		SoundGroup.Parent = SoundService
	end
end

-- Return Module --
return SoundController
