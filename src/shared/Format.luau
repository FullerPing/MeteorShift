--!strict
-- All number formatting goes through here so UI never prints raw numbers (spec §7.5).

local Format = {}

-- Rebirth price inflation and the cash multiplier push late-game numbers past a decillion, so the
-- table runs to the vigintillion (1e63); anything larger reads as the largest value it can show.
local SUFFIXES = {
	"", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc",
	"Ud", "Dd", "Td", "Qad", "Qid", "Sxd", "Spd", "Ocd", "Nod", "Vg",
}
local LARGEST = 999.4 * 10 ^ (3 * (#SUFFIXES - 1)) -- "999Vg": rounds to three digits, never four

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
	local abs = math.min(math.abs(n), LARGEST)
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

-- A per-second rate: Format.number would floor 0.5 to "0", so small rates keep a decimal. 0.5 -> "0.5", 12 -> "12"
function Format.rate(n: number): string
	if n ~= n or n <= 0 then
		return "0"
	end
	if n >= 10 then
		return Format.number(n)
	end
	return trimZeros(string.format("%.1f", n))
end

-- 125 -> "2:05"
function Format.time(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

return Format
