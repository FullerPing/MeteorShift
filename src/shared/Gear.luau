--!strict
-- Gear rules: one pickaxe and one backpack, leveled by stat and evolved by tier
-- (Config.Gear explains the model). Pure functions over the saved levels, covered by
-- tests/Gear.spec; the server and the shop both read them.
--
--   pickaxe(tier, stats)   what the pickaxe does at these levels: a Config.Pickaxes-shaped
--                          table (Tier, Name, Damage, Swing, OrePerHit, Color) plus Power
--                          (Mining Power per hit), Reach, CritChance and CritMult
--   capacity(tier, stats)  the backpack's ore capacity
--   cap(tier)              the highest level a stat can reach at this tier
--   price(kind, stat, level)  cash for the next level of a stat, nil at the cap or the end
--   evolution(kind, tier, stats)  what evolving to the next tier needs, and whether the
--                          Gate stat is at the cap yet
--   levelsForTier(tier)    stat levels of a fresh item of that tier (profile migration,
--                          rebirth, dev hooks)

local Config = require(script.Parent.Config)

local Gear = {}

export type PickaxeStats = { power: number, speed: number, reach: number, crit: number }
export type BackpackStats = { capacity: number }

local Settings = Config.Gear
local LevelsPerTier = Settings.LevelsPerTier

local function tierCount(kind: string): number
	return #(if kind == "pickaxe" then Config.Pickaxes else Config.Backpacks)
end

-- Highest stat level the tier allows
function Gear.cap(tier: number): number
	return LevelsPerTier * math.max(tier, 1)
end

-- Stat level of a fresh item of this tier
function Gear.levelsForTier(tier: number): number
	return LevelsPerTier * (math.max(tier, 1) - 1) + 1
end

-- Value of a tier-table column at a stat level: the tier's own value at its first level,
-- growing geometrically to the next tier's value. The last tier keeps its predecessor's ratio.
local function knot(kind: string, key: string, level: number): number
	local list: any = if kind == "pickaxe" then Config.Pickaxes else Config.Backpacks
	local count = #list
	local clamped = math.clamp(level, 1, LevelsPerTier * count)
	local index = math.min(math.floor((clamped - 1) / LevelsPerTier) + 1, count)
	local fraction = (clamped - Gear.levelsForTier(index)) / LevelsPerTier
	local here = list[index][key] :: number
	local ratio
	if index < count then
		ratio = (list[index + 1][key] :: number) / here
	elseif count > 1 then
		ratio = here / (list[index - 1][key] :: number)
	else
		ratio = 1
	end
	return here * ratio ^ fraction
end

-- Mining Power per hit at a Power level: Meteor.PowerGrowth per tier's worth of levels,
-- so the first level of tier t is MiningPower.power(t).
function Gear.power(level: number): number
	return Config.Meteor.PowerGrowth ^ ((math.max(level, 1) - 1) / LevelsPerTier)
end

function Gear.pickaxe(tier: number, stats: PickaxeStats): any
	local item = Config.Pickaxes[math.clamp(tier, 1, #Config.Pickaxes)]
	local pickaxe = Settings.Pickaxe
	local power = stats.power
	return {
		Tier = item.Tier,
		Name = item.Name,
		Color = item.Color,
		OrePerHit = item.OrePerHit,
		-- the damage number is for show: it follows Power
		Damage = knot("pickaxe", "Damage", power),
		Swing = knot("pickaxe", "Swing", stats.speed),
		Power = Gear.power(power),
		Reach = Config.Meteor.MineRange + pickaxe.ReachPerLevel * (stats.reach - 1),
		CritChance = pickaxe.CritPerLevel * (stats.crit - 1),
		CritMult = pickaxe.CritMult,
		Cost = item.Cost,
		Shards = item.Shards,
	}
end

function Gear.capacity(tier: number, stats: BackpackStats): number
	return knot("backpack", "Capacity", stats.capacity)
end

local function settingsFor(kind: string): any
	return if kind == "pickaxe" then Settings.Pickaxe else Settings.Backpack
end

-- Cash for a stat's next level, nil when the level is the game's last. The tier cap is
-- Gear.canLevel's business, so the shop can still show the price while it is locked.
function Gear.price(kind: string, stat: string, level: number): number?
	local cost = settingsFor(kind).Cost[stat]
	if not cost or level >= LevelsPerTier * tierCount(kind) then
		return nil
	end
	return math.floor(cost.Base * cost.Growth ^ (level - 1) + 0.5)
end

-- Whether the stat can take its next level at this tier
function Gear.canLevel(kind: string, tier: number, level: number): boolean
	return level < Gear.cap(tier) and level < LevelsPerTier * tierCount(kind)
end

export type Evolution = {
	tier: number, -- the tier it would become
	cost: number,
	shards: number,
	ready: boolean, -- the Gate stat is at the cap
}

-- What evolving to the next tier takes, nil at the top tier. `stats` is the item's levels.
function Gear.evolution(kind: string, tier: number, stats: { [string]: number }): Evolution?
	local list: any = if kind == "pickaxe" then Config.Pickaxes else Config.Backpacks
	local nextTier = list[tier + 1]
	if not nextTier then
		return nil
	end
	local gate = settingsFor(kind).Gate
	return {
		tier = nextTier.Tier,
		cost = nextTier.Cost,
		shards = nextTier.Shards,
		ready = (stats[gate] or 1) >= Gear.cap(tier),
	}
end

-- Total cash to take a fresh tier-`tier - 1` item to tier `tier`: the Gate stat's levels
-- up to the cap, plus the evolve price. The pacing model buys tiers as these bundles.
function Gear.bundleCost(kind: string, tier: number): number
	local list: any = if kind == "pickaxe" then Config.Pickaxes else Config.Backpacks
	local item = list[tier]
	if not item then
		return 0
	end
	local total = item.Cost
	if tier <= 1 then
		return total
	end
	local gate = settingsFor(kind).Gate
	for level = Gear.levelsForTier(tier - 1), Gear.cap(tier - 1) - 1 do
		total += Gear.price(kind, gate, level) or 0
	end
	return total
end

-- How many levels of one stat a buy-more button can take, one at a time up to `limit`.
-- Returns (affordable count, their total price, allowed count, their total price): "allowed"
-- ignores cash (only the tier's level cap and the price table stop it) so a button can show
-- what it would cost.
function Gear.bulk(kind: string, tier: number, stat: string, level: number, cash: number, limit: number): (number, number, number, number)
	local count, total, allowed, allowedTotal = 0, 0, 0, 0
	local current = level
	while allowed < limit and Gear.canLevel(kind, tier, current) do
		local price = Gear.price(kind, stat, current)
		if not price then
			break
		end
		allowed += 1
		allowedTotal += price
		if allowedTotal <= cash then
			count, total = allowed, allowedTotal
		end
		current += 1
	end
	return count, total, allowed, allowedTotal
end

-- A stats table for a fresh item of a tier
function Gear.freshPickaxeStats(tier: number): PickaxeStats
	local level = Gear.levelsForTier(tier)
	return { power = level, speed = level, reach = level, crit = level }
end

function Gear.freshBackpackStats(tier: number): BackpackStats
	return { capacity = Gear.levelsForTier(tier) }
end

-- Clamps saved stat levels into the legal range for the tier (1 to its cap), filling missing
-- ones with a fresh item's. Only the Gate stat has to reach the cap to evolve, so the others
-- can lag behind the tier.
function Gear.cleanPickaxeStats(tier: number, saved: any): PickaxeStats
	local fresh = Gear.freshPickaxeStats(tier)
	local out: any = {}
	for _, stat in Settings.Pickaxe.Stats do
		local value = if type(saved) == "table" and type(saved[stat]) == "number" then saved[stat] else fresh[stat]
		out[stat] = math.clamp(math.floor(value), 1, Gear.cap(tier)) -- a stat may lag behind the tier
	end
	return out
end

function Gear.cleanBackpackStats(tier: number, saved: any): BackpackStats
	local fresh = Gear.freshBackpackStats(tier)
	local value = if type(saved) == "table" and type(saved.capacity) == "number" then saved.capacity else fresh.capacity
	return { capacity = math.clamp(math.floor(value), 1, Gear.cap(tier)) }
end

return Gear
