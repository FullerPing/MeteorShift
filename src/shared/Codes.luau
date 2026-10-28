--!strict
-- Pure rules for redeemable codes (Config.Codes): what the player typed, whether it can be redeemed, what it pays.
local Settings = require(script.Parent.Config.Codes)
local Income = require(script.Parent.Income)

export type Result = { status: string, key: string?, def: Settings.Code? }

local Codes = {}

-- "  welcome " -> "WELCOME"; nil when it is empty, too long, not text or has anything but letters, digits, - and _
function Codes.normalize(input: any): string?
	if type(input) ~= "string" then return nil end
	local text = string.upper((string.gsub(input, "^%s+", "")))
	text = string.gsub(text, "%s+$", "")
	if text == "" or #text > Settings.MaxLength or string.find(text, "[^A-Z0-9_%-]") then return nil end
	return text
end

local function finite(value: number): number
	if value ~= value or value == math.huge or value == -math.huge or value < 0 then return 0 end
	return value
end

-- status: "ok" (key and def are set), "empty" (nothing usable typed), "invalid" (no such code), "used", "expired"
function Codes.check(list: { [string]: Settings.Code }, redeemed: { [string]: boolean }, input: any, now: number): Result
	local key = Codes.normalize(input)
	if not key then return { status = "empty" } end
	local def = list[key]
	if not def or ((def.Minutes or 0) <= 0 and (def.Shards or 0) <= 0) then return { status = "invalid" } end
	if redeemed[key] then return { status = "used" } end
	if def.Expires and now >= def.Expires then return { status = "expired" } end
	return { status = "ok", key = key, def = def }
end

function Codes.reward(def: Settings.Code, perSecond: number, ceiling: number): { cash: number, shards: number }
	local cash = 0
	if (def.Minutes or 0) > 0 then
		cash = Income.grant((def.Minutes :: number) * 60, finite(perSecond), Settings.CashFloor, finite(ceiling))
	end
	return { cash = cash, shards = math.max(0, math.floor(def.Shards or 0)) }
end

return Codes
