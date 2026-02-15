--[[
	SettingsController.lua

	Description:
		Foundational controller for SettingsWindow.
		Provides open/close/toggle helpers and ensures the window is registered.
--]]

-- Root --
local SettingsController = {}

-- Dependencies --
local UIController = shared("UIController")

-- Constants --
local WINDOW_NAME = "SettingsWindow"

function SettingsController:Open()
	return UIController:OpenWindow(WINDOW_NAME)
end

function SettingsController:Close()
	return UIController:CloseWindow(WINDOW_NAME)
end

function SettingsController:Toggle()
	return UIController:ToggleWindow(WINDOW_NAME)
end

function SettingsController:IsOpen()
	return UIController:IsWindowOpen(WINDOW_NAME)
end

function SettingsController:Init()
	-- Register the ScreenGui with UIController when it appears in PlayerGui.
	UIController:WhenScreenGuiReady(WINDOW_NAME, function()
		-- No extra setup needed right now.
	end)
end

return SettingsController
