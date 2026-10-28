--!strict
-- Gear rules: one pickaxe and one backpack, each with a level that restarts at 1 with every tier
-- (tier t has LevelsPerTier x t levels) and is evolved by tier (Config.Gear explains the model). Pure functions over the saved level, covered by
-- tests/Gear.spec; the server and the shop both read them. Every cash price takes an optional
-- `priceMult` (Shared.Rebirth.priceMult): the price inflation a player's rebirths bring.
--
--   pickaxe(tier, level)   what the pickaxe does at this level: a Config.Pickaxes-shaped
--                          table (Tier, Name, Damage, Swing, OrePerHit, Color) plus Power
--                          (Mining Power per hit), Reach, CritChance and CritMult
--   capacity(tier, level)  the backpack's ore capacity
--   cap(tier)              the highest level the tier allows
--   price(kind, tier, level, priceMult?)  cash for the next level, nil at the game's last level
--   evolution(kind, tier, level, priceMult?)  what evolving to the next tier needs, and
--                          whether the level is at the cap yet
--   levelsForTier(tier)    level of a fresh item of that tier: always 1 (profile migration,
--                          rebirth, dev hooks)
--   cleanLevel(tier, saved) a saved level made legal

local Config = require(script.Parent.Config)

local Gear = {}

local Settings = Config.Gear
local LevelsPerTier = Settings.LevelsPerTier

local function tierCount(kind: string): number
	return #(if kind == "pickaxe" then Config.Pickaxes else Config.Backpacks)
end

-- Highest stat level the tier allows
function Gear.cap(tier: number): number
	return LevelsPerTier * math.max(tier, 1)
end

-- Level of a fresh item of this tier: every tier starts over at 1
function Gear.levelsForTier(tier: number): number
	return 1
end

-- How far along the whole game an item is, in the units one level of tier 1 is worth: tiers before
-- this one count LevelsPerTier each, and the tier's own levels share one LevelsPerTier between
-- them. Tier-1 levels are worth exactly one each; later tiers' levels are worth 1/tier.
local function depth(tier: number, level: number): number
	local t = math.max(tier, 1)
	return LevelsPerTier * (t - 1) + 1 + (math.clamp(level, 1, Gear.cap(t)) - 1) / t
end

-- Value of a tier-table column at a level: the tier's own value at its first level,
-- growing geometrically to the next tier's value. The last tier keeps its predecessor's ratio.
local function knot(kind: string, key: string, tier: number, level: number): number
	local list: any = if kind == "pickaxe" then Config.Pickaxes else Config.Backpacks
	local count = #list
	local index = math.clamp(tier, 1, count)
	local fraction = (math.clamp(level, 1, Gear.cap(index)) - 1) / Gear.cap(index)
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

-- Mining Power per hit at a tier and level: Meteor.PowerGrowth per tier, so the first level of
-- tier t is MiningPower.power(t).
function Gear.power(tier: number, level: number): number
	return Config.Meteor.PowerGrowth ^ ((depth(tier, level) - 1) / LevelsPerTier)
end

function Gear.pickaxe(tier: number, level: number): any
	local item = Config.Pickaxes[math.clamp(tier, 1, #Config.Pickaxes)]
	local pickaxe = Settings.Pickaxe
	return {
		Tier = item.Tier,
		Name = item.Name,
		Color = item.Color,
		OrePerHit = item.OrePerHit,
		-- the damage number is for show: it follows the level
		Damage = knot("pickaxe", "Damage", tier, level),
		Swing = knot("pickaxe", "Swing", tier, level),
		Power = Gear.power(tier, level),
		Reach = Config.Meteor.MineRange + math.min(pickaxe.ReachPerLevel * (depth(tier, level) - 1), pickaxe.ReachMax),
		CritChance = pickaxe.CritPerLevel * (depth(tier, level) - 1),
		CritMult = pickaxe.CritMult,
		Cost = item.Cost,
		Shards = item.Shards,
	}
end

function Gear.capacity(tier: number, level: number): number
	return knot("backpack", "Capacity", tier, level)
end

-- Cash for the next level, nil when the level is the game's last. The tier cap is
-- Gear.canLevel's business, so the shop can still show the price while it is locked. A tier's
-- levels together cost its row's LevelCost; each is LevelGrowth^(1 / tier) dearer than the one
-- before it, so a later tier's many levels climb as steeply as tier 1's ten.
function Gear.price(kind: string, tier: number, level: number, priceMult: number?): number?
	local count = tierCount(kind)
	if tier >= count and level >= Gear.cap(tier) then
		return nil
	end
	local t = math.clamp(tier, 1, count)
	local list: any = if kind == "pickaxe" then Config.Pickaxes else Config.Backpacks
	local step = Settings.LevelGrowth ^ (1 / t)
	local steps = Gear.cap(t) - 1 -- the levels bought inside the tier: 1 to cap - 1
	local total = (step ^ steps - 1) / (step - 1)
	local at = math.clamp(level, 1, Gear.cap(t)) - 1
	return math.floor(list[t].LevelCost * step ^ at / total * (priceMult or 1) + 0.5)
end

-- Whether the item can take its next level at this tier
function Gear.canLevel(kind: string, tier: number, level: number): boolean
	return level < Gear.cap(math.min(tier, tierCount(kind)))
end

export type Evolution = {
	tier: number, -- the tier it would become
	cost: number,
	shards: number,
	ready: boolean, -- the level is at the cap
}

-- What evolving to the next tier takes, nil at the top tier.
function Gear.evolution(kind: string, tier: number, level: number, priceMult: number?): Evolution?
	local list: any = if kind == "pickaxe" then Config.Pickaxes else Config.Backpacks
	local nextTier = list[tier + 1]
	if not nextTier then
		return nil
	end
	return {
		tier = nextTier.Tier,
		cost = math.floor(nextTier.Cost * (priceMult or 1) + 0.5),
		shards = nextTier.Shards,
		ready = level >= Gear.cap(tier),
	}
end

-- Total cash to take a fresh tier-`tier - 1` item to tier `tier`: its levels up to the cap,
-- plus the evolve price. The pacing model buys tiers as these bundles.
function Gear.bundleCost(kind: string, tier: number, priceMult: number?): number
	local list: any = if kind == "pickaxe" then Config.Pickaxes else Config.Backpacks
	local item = list[tier]
	if not item then
		return 0
	end
	local total = math.floor(item.Cost * (priceMult or 1) + 0.5)
	if tier <= 1 then
		return total
	end
	for level = Gear.levelsForTier(tier - 1), Gear.cap(tier - 1) - 1 do
		total += Gear.price(kind, tier - 1, level, priceMult) or 0
	end
	return total
end

-- How many levels a buy-more button can take, one at a time up to `limit`.
-- Returns (affordable count, their total price, allowed count, their total price): "allowed"
-- ignores cash (only the tier's level cap and the price table stop it) so a button can show
-- what it would cost.
function Gear.bulk(kind: string, tier: number, level: number, cash: number, limit: number, priceMult: number?): (number, number, number, number)
	local count, total, allowed, allowedTotal = 0, 0, 0, 0
	local current = level
	while allowed < limit and Gear.canLevel(kind, tier, current) do
		local price = Gear.price(kind, tier, current, priceMult)
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

-- A saved level clamped into 1 to the tier's cap; a missing or broken one starts like a
-- fresh item of the tier.
function Gear.cleanLevel(tier: number, saved: any): number
	local fresh = Gear.levelsForTier(tier)
	local value = if type(saved) == "number" and saved == saved and math.abs(saved) < math.huge then saved else fresh
	return math.clamp(math.floor(value), 1, Gear.cap(tier))
end

return Gear
