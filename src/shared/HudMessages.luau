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

-- Meteor ore and XP can be fractional. Keep small awards visible instead of
-- flooring them to zero; larger amounts use the normal compact number format.
local function awardText(amount: number): string
	if amount ~= amount or amount < 0 or amount >= math.huge then return "0" end
	if amount >= 1000 then return Format.number(amount) end
	local text = string.format("%.3f", amount)
	text = string.gsub(text, "0+$", "")
	return (string.gsub(text, "%.$", ""))
end

function Messages.meteorOutcome(cracked: boolean, ore: number): string
	return (if cracked then "Core cracked!" else "Cooled: core unbroken.") .. " Kept " .. awardText(ore) .. " ore."
end

-- Results.top is the core-hit podium bonus; overall contribution rank can
-- include crust-only miners and therefore is not the reward podium placement.
function Messages.meteorReward(shards: number, topBonus: number, topBonuses: { number }, xp: number?): string
	local blue = Color3.fromRGB(113, 205, 255)
	local text = tint(Format.number(shards), blue) .. (if shards == 1 then " shard received" else " shards received")
	if xp ~= nil then
		text ..= " · " .. tint("+" .. awardText(xp) .. " XP", Color3.fromRGB(255, 209, 102))
	end
	if topBonus <= 0 then return text end
	local podium = { Color3.fromRGB(255, 209, 102), Color3.fromRGB(204, 214, 224), Color3.fromRGB(212, 146, 97) }
	for place, bonus in topBonuses do
		if place <= 3 and bonus == topBonus then
			return text .. " (" .. tint("#" .. place, podium[place]) .. " " .. tint("+" .. Format.number(topBonus), blue) .. ")"
		end
	end
	return text
end

return Messages
