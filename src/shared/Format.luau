--!strict
-- All number formatting goes through here so UI never prints raw numbers (spec §7.5).

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

local function trimZeros(s: string): string
	if string.find(s, "%.") then
		s = string.gsub(s, "0+$", "")
		s = string.gsub(s, "%.$", "")
	end
	return s
end

-- 3 significant digits with a suffix: 1234 -> "1.23K", 45600000 -> "45.6M"
function Format.number(n: number): string
	if n ~= n then
		return "0"
	end
	local sign = if n < 0 then "-" else ""
	local abs = math.abs(n)
	if abs < 1000 then
		return sign .. tostring(math.floor(abs))
	end

	local tier = math.min(math.floor(math.log10(abs) / 3), #SUFFIXES - 1)
	local value = abs / 10 ^ (tier * 3)
	-- Rounding can push 999.95K up to "1000K"; move to the next suffix instead.
	if value >= 999.5 and tier < #SUFFIXES - 1 then
		tier += 1
		value = abs / 10 ^ (tier * 3)
	end

	local text
	if value >= 100 then
		text = string.format("%d", math.floor(value + 0.5))
	elseif value >= 10 then
		text = trimZeros(string.format("%.1f", value))
	else
		text = trimZeros(string.format("%.2f", value))
	end
	return sign .. text .. SUFFIXES[tier + 1]
end

function Format.cash(n: number): string
	return "$" .. Format.number(n)
end

-- 125 -> "2:05"
function Format.time(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

return Format
