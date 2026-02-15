--[[
	PatchNotesWindowController.lua

	Description:
		Foundational controller for PatchNotesWindow.
		Provides open/close/toggle helpers and ensures the window is registered.
--]]

-- Root --
local PatchNotesWindowController = {}

-- Dependencies --
local UIController = shared("UIController")

-- Constants --
local WINDOW_NAME = "PatchNotesWindow"

function PatchNotesWindowController:Open()
	return UIController:OpenWindow(WINDOW_NAME)
end

function PatchNotesWindowController:Close()
	return UIController:CloseWindow(WINDOW_NAME)
end

function PatchNotesWindowController:Toggle()
	return UIController:ToggleWindow(WINDOW_NAME)
end

function PatchNotesWindowController:IsOpen()
	return UIController:IsWindowOpen(WINDOW_NAME)
end

function PatchNotesWindowController:Init()
	UIController:WhenScreenGuiReady(WINDOW_NAME, function()
		-- No additional setup needed yet.
	end)
end

return PatchNotesWindowController
