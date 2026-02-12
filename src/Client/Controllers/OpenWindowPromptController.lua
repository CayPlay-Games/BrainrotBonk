--[[
	OpenWindowPromptController.lua

	Description:
		Initializes the Binder for OpenWindowPrompt.
		Automatically creates ProximityPrompts on parts tagged "OpenWindow".
--]]

-- Root --
local OpenWindowPromptController = {}

-- Dependencies --
local Binder = shared("Binder")
local OpenWindowPrompt = shared("OpenWindowPrompt")
local RoundConfig = shared("RoundConfig")

-- Private Variables --
local _Binder = nil

-- Internal Functions --

local function DebugLog(...)
	if RoundConfig.DEBUG_LOG_STATE_CHANGES then
		print("[OpenWindowPromptController]", ...)
	end
end

-- Initializers --
function OpenWindowPromptController:Init()
	DebugLog("Initializing...")

	_Binder = Binder.new("OpenWindow", OpenWindowPrompt)
	_Binder:Run()

	DebugLog("Binder active for 'OpenWindow' tag")
end

-- Return Module --
return OpenWindowPromptController
