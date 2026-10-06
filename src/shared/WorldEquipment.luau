--!strict
-- Read-only presentation for local world displays. Purchases remain server-side.
local Config = require(script.Parent.Config)
local Gear = require(script.Parent.Gear)
local WorldEquipment = {}

local function finite(value: any): boolean
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function tiers(kind: string): any
	assert(kind == "pickaxe" or kind == "backpack", "Unknown equipment kind")
	return if kind == "pickaxe" then Config.Pickaxes else Config.Backpacks
end

local function cleanTier(kind: string, value: any): number
	return if finite(value) then math.clamp(math.floor(value), 1, #tiers(kind)) else 1
end

local function levels(kind: string, tier: number, saved: any): any
	local settings = if kind == "pickaxe" then Config.Gear.Pickaxe else Config.Gear.Backpack
	local fresh = Gear.levelsForTier(tier)
	local out: any = {}
	for _, stat in settings.Stats do
		local value = if type(saved) == "table" then saved[stat] else nil
		out[stat] = if finite(value) and value >= 1 then math.clamp(math.floor(value), 1, Gear.cap(tier)) else fresh
	end
	return out
end

local function effective(value: any, fallback: number): number
	return if finite(value) and value > 0 then value else fallback
end

function WorldEquipment.wall(kind: string, currentTier: any): { any }
	local current = cleanTier(kind, currentTier)
	local rows = {}
	for _, item in tiers(kind) do
		table.insert(rows, {
			tier = item.Tier, name = item.Name,
			status = if item.Tier == current then "CURRENT" elseif item.Tier < current then "UNLOCKED" else "LOCKED",
		})
	end
	return rows
end

function WorldEquipment.current(kind: string, state: any): any
	local snapshot = if type(state) == "table" then state else {}
	local tier = cleanTier(kind, snapshot[kind .. "Tier"])
	local item = tiers(kind)[tier]
	local stats = levels(kind, tier, snapshot[kind .. "Stats"])
	if kind == "backpack" then
		return { tier = tier, name = item.Name, stats = {
			capacity = effective(snapshot.capacity, Gear.capacity(tier, stats)),
		} }
	end
	local pick = Gear.pickaxe(tier, stats)
	return { tier = tier, name = item.Name, stats = {
		power = pick.Power, swing = effective(snapshot.swing, pick.Swing),
		reach = effective(snapshot.reach, pick.Reach), critChance = pick.CritChance,
		orePerHit = pick.OrePerHit,
	} }
end

return WorldEquipment
