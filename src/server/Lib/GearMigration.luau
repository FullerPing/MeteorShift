--!strict
-- Profile v6 to v7: the pickaxe's four stat levels and the backpack's capacity level became one level
-- each. The Gate stat (Power, Capacity) is the new level. Speed, Reach and Crit levels above a fresh
-- item's were paid for, so their cash comes back at the prices they had (the old constants live here only).
-- Profile v7 to v8: the level used to count across the whole game (tier t held levels 10 x (t - 1) + 1
-- to 10 x t); it now restarts at 1 with every tier, which has 10 x t levels.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Gear = require(ReplicatedStorage.Shared.Gear)

local OLD_COST = {
	speed = { Base = 40, Growth = 1.115 },
	reach = { Base = 20, Growth = 1.11 },
	crit = { Base = 40, Growth = 1.11 },
}

local OLD_PER_TIER = 10 -- the v7 level counted this many levels per tier, across the game

local GearMigration = {}

-- v7 meaning of the level rules: a tier's first level and its cap
local function oldFresh(tier: number): number
	return OLD_PER_TIER * (math.max(tier, 1) - 1) + 1
end

local function oldCap(tier: number): number
	return OLD_PER_TIER * math.max(tier, 1)
end

local function oldClean(tier: number, saved: any): number
	local value = if type(saved) == "number" and saved == saved and math.abs(saved) < math.huge then saved else oldFresh(tier)
	return math.clamp(math.floor(value), 1, oldCap(tier))
end

local function whole(value: any): number?
	return if type(value) == "number" and value == value and math.abs(value) < math.huge then math.floor(value) else nil
end

-- Converts `data` in place and returns the cash refunded (0 for a profile already migrated).
function GearMigration.run(data: any): number
	local refund = 0
	local pickaxeStats, backpackStats = data.pickaxeStats, data.backpackStats
	local pickaxeTier, backpackTier = data.pickaxeTier or 1, data.backpackTier or 1
	if type(pickaxeStats) == "table" then
		data.pickaxeLevel = oldClean(pickaxeTier, pickaxeStats.power)
		local fresh = oldFresh(pickaxeTier)
		for stat, cost in OLD_COST do
			local owned = math.min(whole(pickaxeStats[stat]) or fresh, oldCap(pickaxeTier))
			for level = fresh, owned - 1 do
				refund += math.floor(cost.Base * cost.Growth ^ (level - 1) + 0.5)
			end
		end
	end
	if type(backpackStats) == "table" then
		data.backpackLevel = oldClean(backpackTier, backpackStats.capacity)
	end
	data.pickaxeStats, data.backpackStats = nil, nil
	if refund > 0 then
		data.cash = (data.cash or 0) + refund
	end
	return refund
end

local function restart(tier: number, saved: any): number
	local old = oldClean(tier, saved) - oldFresh(tier) + 1 -- 1 to 10 within the tier
	-- the same share of the tier, spread over its longer run; a tier that was at its cap still is
	if old >= OLD_PER_TIER then
		return Gear.cap(tier)
	end
	return Gear.cleanLevel(tier, 1 + (old - 1) * tier)
end

-- v7 to v8: converts the game-wide level of each item to its level within the tier. Run it once.
function GearMigration.toTierLevels(data: any)
	data.pickaxeLevel = restart(data.pickaxeTier or 1, data.pickaxeLevel)
	data.backpackLevel = restart(data.backpackTier or 1, data.backpackLevel)
end

return GearMigration
