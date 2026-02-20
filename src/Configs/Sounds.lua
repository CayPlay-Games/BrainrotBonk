--[[
    Sounds.lua
    Author(s): arcoorio

    Description:
        Static configuration for sounds.
--]]

-- Root --
local Sounds = {}

-- Buffs Configurations --
Sounds.Config = {
	-- Music
	Default = {
		SoundId = "rbxassetid://132748936249883",
		IsLooped = true,
		DefaultVolume = 0.5,
		DefaultSpeed = 1,
	},

	-- Ambient

	-- SFX
	TempSuccess = {
		SoundId = "rbxassetid://3997124966",
	},
	ShovelDigTick = {
		SoundId = "rbxassetid://88442833509532",
	},
	DigProgressHit = {
		SoundId = "rbxassetid://114672147284831",
	},

	MouseHover = {
		SoundId = "rbxassetid://18856494234",
	},
	MouseClick = {
		SoundId = "rbxassetid://18202483174",
	},

	RockPileAppear = {
		SoundId = "rbxassetid://1741599172",
	},

	RockMining1 = {
		SoundId = "rbxassetid://9125869504",
	},

	RockMining2 = {
		SoundId = "rbxassetid://107752385945612",
	},

	ShovelEquip = {
		SoundId = "rbxassetid://133255687571677",
	},

	Notification = {
		SoundId = "rbxassetid://17582299860",
	},

	-- Lucky Block SFX
	LuckyBlockUse = {
		SoundId = "rbxassetid://132173082718180",
	},
	LuckyBlockLand = {
		SoundId = "rbxassetid://6607427522",
	},
	LuckyBlockShake = {
		SoundId = "rbxassetid://9125677840",
	},
	LuckyBlockOpen = {
		SoundId = "rbxassetid://7768888198",
	},
	LuckyBlockTick = {
		SoundId = "rbxassetid://6895079853",
	},
	LuckyBlockReveal = {
		SoundId = "rbxassetid://73743814975286",
	},
}

-- API Functions --
function Sounds:Get(SoundName: string)
	return Sounds.Config[SoundName]
end

-- Return Module --
return Sounds
