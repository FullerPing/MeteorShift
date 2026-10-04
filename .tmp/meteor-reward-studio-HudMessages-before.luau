--!strict
-- Notification copy and safe RichText spans shared by HUD callers.
local Format = require(script.Parent.Format)
local Messages = {}

local function escape(text: string): string
	local escaped = string.gsub(text, "&", "&amp;")
	escaped = string.gsub(escaped, "<", "&lt;")
	escaped = string.gsub(escaped, ">", "&gt;")
	escaped = string.gsub(escaped, '"', "&quot;")
	return escaped
end

local function tint(text: string, color: Color3): string
	local hex = string.format("#%02X%02X%02X", math.round(color.R * 255), math.round(color.G * 255), math.round(color.B * 255))
	return '<font color="' .. hex .. '">' .. escape(text) .. '</font>'
end

function Messages.toast(text: string, color: Color3?, highlighted: string?): string
	if color and highlighted and highlighted ~= "" then
		local first, last = string.find(text, highlighted, 1, true)
		if first and last then
			return escape(string.sub(text, 1, first - 1)) .. tint(highlighted, color) .. escape(string.sub(text, last + 1))
		end
	end
	return escape(text)
end

function Messages.sale(bars: number, cash: number): string
	return "Sold " .. Format.number(bars) .. (if bars == 1 then " bar " else " bars ")
		.. tint("+" .. string.lower(Format.cash(cash)), Color3.fromRGB(139, 240, 195))
end

return Messages

