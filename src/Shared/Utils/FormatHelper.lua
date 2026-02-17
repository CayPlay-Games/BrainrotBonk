--[[
	FormatHelper.lua

	Description:
		Utility functions for formatting values, times, and colors.
--]]

local FormatHelper = {}

-- Format seconds as DD:HH:MM:SS
function FormatHelper:FormatTime(seconds: number): string
	local days = math.floor(seconds / 86400)
	local hours = math.floor((seconds % 86400) / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	local secs = seconds % 60

	return string.format("%02d:%02d:%02d:%02d", days, hours, minutes, secs)
end

-- Format large numbers with K/M suffix (e.g. 1500 -> "1.5K")
function FormatHelper:FormatNumber(value: number): string
	if value >= 1000000 then
		return string.format("%.1fM", value / 1000000)
	elseif value >= 1000 then
		return string.format("%.1fK", value / 1000)
	else
		return tostring(value)
	end
end

-- Format number with commas (e.g. 1000000 -> "1,000,000")
function FormatHelper:FormatNumberWithCommas(value: number): string
	local formatted = tostring(math.floor(value))
	while true do
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
		if k == 0 then
			break
		end
	end
	return formatted
end

-- Darken a Color3 by reducing its Value in HSV
function FormatHelper:DarkenColor(color: Color3, amount: number): Color3
	local h, s, v = color:ToHSV()
	v = math.max(0, v - (amount / 255))
	return Color3.fromHSV(h, s, v)
end

-- Lighten a Color3 by increasing its Value in HSV
function FormatHelper:LightenColor(color: Color3, amount: number): Color3
	local h, s, v = color:ToHSV()
	v = math.min(1, v + (amount / 255))
	return Color3.fromHSV(h, s, v)
end

return FormatHelper
