--!strict
-- Meteor types (spec §8.1): which type comes next and what each player gets from it.
--
-- Every type is the same event (spec §5) with the ore, the required pickaxe tier,
-- one twist and the multipliers swapped (Config.Meteor.Types). The rules around them:
--
--   pick           weighted odds (Iron 60, Ice 25, Crystal 15), but a type can only come
--                  up when at least 25% of active players meet its tier; otherwise it
--                  drops to the next type down (Iron always can)
--   underTier      true when your pickaxe is below the meteor's tier. Everyone mines the
--                  meteor's own ore; under tier it scales with your pickaxe: slower the
--                  more tiers short you are (underTierPowerMult), and each meteor type
--                  above your best one is worth 3x the type below (underTierWorth): to a
--                  tier 1 pickaxe Ice pays 3 Iron meteors, Crystal 9. Each hit pays that
--                  multiple of a hit on your own ore, in the meteor's ore (underTierYield),
--                  up to that multiple of your own meteor's haul (underTierCap). Nobody is
--                  locked out
--   missed         what an under-tier player missed (full-speed mining), and missedHint,
--                  the results line for it
--   resonanceMult  Crystal twist: +20% Mining Power per extra hitter on a node, max +60%
--   refreezeHp     Ice twist: a node nobody has hit for 5 s regains 2% of max HP per second
--   shardPoolMult  the type's shard pool ×, scaled down when meteors come faster than the
--                  default interval (private servers)
--
-- Pure functions only (the caller passes the roll, the tiers and the clocks), so the
-- rules are covered by tests/MeteorTypes.spec.

local Meteor = require(script.Parent.Config.Meteor)
local Home = require(script.Parent.Config.Home)
local Pickaxes = require(script.Parent.Config.Pickaxes)
local Balance = require(script.Parent.Config.Balance)
local Format = require(script.Parent.Format)

type MeteorType = Meteor.MeteorType

export type Missed = {
	tier: number, -- pickaxe tier the meteor's ore needs
	ore: string, -- ore id (Config.Home.OreNames has its display name)
	barPrice: number,
}

local Types = Meteor.Types
local TypeOrder = Meteor.TypeOrder

local MeteorTypes = {}

-- True when at least EligibleShare of the active players' pickaxes meet the type's tier.
-- With nobody active, no type is (pick still falls back to the lowest one).
local function eligible(meteorType: MeteorType, activeTiers: { number }): boolean
	if #activeTiers == 0 then
		return false
	end
	local meeting = 0
	for _, tier in activeTiers do
		if tier >= meteorType.RequiredTier then
			meeting += 1
		end
	end
	return meeting >= Meteor.EligibleShare * #activeTiers
end

-- The next meteor type for a lobby with these active pickaxe tiers. `roll` is uniform
-- in [0, 1) (math.random() on the server); it lands in the types' Weight bands in
-- TypeOrder, then an ineligible pick drops down TypeOrder until one is eligible.
function MeteorTypes.pick(activeTiers: { number }, roll: number): MeteorType
	local total = 0
	for _, id in TypeOrder do
		total += Types[id].Weight
	end

	local target = roll * total
	local index = #TypeOrder
	local bandEnd = 0
	for i, id in TypeOrder do
		bandEnd += Types[id].Weight
		if target < bandEnd then
			index = i
			break
		end
	end

	while index > 1 and not eligible(Types[TypeOrder[index]], activeTiers) do
		index -= 1
	end
	return Types[TypeOrder[index]]
end

-- True when this pickaxe tier is below the meteor's, so it mines slowly.
function MeteorTypes.underTier(pickaxeTier: number, meteorType: MeteorType): boolean
	return pickaxeTier < meteorType.RequiredTier
end

-- How many tiers this pickaxe is below the meteor's (0 at or above it).
function MeteorTypes.tiersShort(pickaxeTier: number, meteorType: MeteorType): number
	return math.max(meteorType.RequiredTier - pickaxeTier, 0)
end

-- Multiplier on an under-tier hit's Mining Power: `power` per hit every `swingSeconds`
-- clears a crust node of `nodeHp` in Meteor.UnderTier.NodeSecondsPerTier x `tiersShort`
-- seconds. Never above 1, so a node that is quicker than that anyway (a big lobby's)
-- isn't sped up.
function MeteorTypes.underTierPowerMult(power: number, swingSeconds: number, nodeHp: number, tiersShort: number): number
	if power <= 0 or tiersShort <= 0 then
		return 1
	end
	local slowPower = nodeHp * swingSeconds / (Meteor.UnderTier.NodeSecondsPerTier * tiersShort)
	return math.min(slowPower / power, 1)
end

-- TypeOrder index of the best type this pickaxe mines at full speed.
local function bestIndex(pickaxeTier: number): number
	for i = #TypeOrder, 1, -1 do
		if Types[TypeOrder[i]].RequiredTier <= pickaxeTier then
			return i
		end
	end
	return 1
end

-- The ore of the best type this pickaxe mines at full speed.
function MeteorTypes.bestOre(pickaxeTier: number): string
	return Types[TypeOrder[bestIndex(pickaxeTier)]].Ore
end

-- How many types up TypeOrder this meteor is from the best one this pickaxe mines at
-- full speed (tier 1 on Crystal: 2). 0 at or above its tier.
function MeteorTypes.typesAbove(pickaxeTier: number, meteorType: MeteorType): number
	local index = table.find(TypeOrder, meteorType.Id) or 1
	return math.max(index - bestIndex(pickaxeTier), 0)
end

-- What this meteor is worth to the pickaxe against one of its own best type:
-- Meteor.UnderTier.TypeMult per type above (tier 1 on Ice: 3, on Crystal: 9). 1 at or
-- above its tier.
function MeteorTypes.underTierWorth(pickaxeTier: number, meteorType: MeteorType): number
	return Meteor.UnderTier.TypeMult ^ MeteorTypes.typesAbove(pickaxeTier, meteorType)
end

-- Ore a pickaxe and a backpack of `capacity` bring home from a meteor active for
-- `seconds`, mining at full speed: Shared.Pacing's ore rate (a full backpack per trip,
-- Config.Balance's hit share and trip time) over that time.
function MeteorTypes.meteorHaul(pickaxeTier: number, capacity: number, seconds: number): number
	local pickaxe = Pickaxes[pickaxeTier] or Pickaxes[1]
	if capacity <= 0 or pickaxe.OrePerHit <= 0 then
		return 0
	end
	local fillSeconds = capacity / pickaxe.OrePerHit * pickaxe.Swing / Balance.HitsPerMinuteShare
	return capacity / (fillSeconds + Balance.TripSeconds) * seconds
end

-- Multiplier on a pickaxe's ore per hit from this meteor: 1 at or above its tier. Under
-- it, the meteor's ore worth underTierWorth x the same hit on bestOre, by bar price (a
-- Basic Pickaxe on Crystal: 9 x $5 / $3K). Never above 1.
function MeteorTypes.underTierYield(pickaxeTier: number, meteorType: MeteorType): number
	if not MeteorTypes.underTier(pickaxeTier, meteorType) then
		return 1
	end
	local price = Home.BarPrices[meteorType.Ore] or 0
	if price <= 0 then
		return 0
	end
	local own = Home.BarPrices[MeteorTypes.bestOre(pickaxeTier)] or 0
	return math.min(MeteorTypes.underTierWorth(pickaxeTier, meteorType) * own / price, 1)
end

-- The most of the meteor's ore an under-tier pickaxe takes from one meteor: worth
-- underTierWorth x what the pickaxe and a backpack of `capacity` bring home from one
-- meteor of their own best type (meteorHaul over this meteor's cooling timer). Swinging
-- nonstop reaches it before the meteor cools. math.huge at or above the meteor's tier.
function MeteorTypes.underTierCap(pickaxeTier: number, capacity: number, meteorType: MeteorType): number
	if not MeteorTypes.underTier(pickaxeTier, meteorType) then
		return math.huge
	end
	local price = Home.BarPrices[meteorType.Ore] or 0
	if price <= 0 then
		return 0
	end
	local own = Home.BarPrices[MeteorTypes.bestOre(pickaxeTier)] or 0
	local haul = MeteorTypes.meteorHaul(pickaxeTier, capacity, meteorType.ActiveDuration)
	return MeteorTypes.underTierWorth(pickaxeTier, meteorType) * haul * own / price
end

-- What an under-tier player missed on this meteor, full-speed mining ("Tier 5 pickaxe
-- mines Crystal at full speed: $3K bars"), or nil when their pickaxe met its tier.
function MeteorTypes.missed(pickaxeTier: number, meteorType: MeteorType): Missed?
	if pickaxeTier >= meteorType.RequiredTier then
		return nil
	end
	return {
		tier = meteorType.RequiredTier,
		ore = meteorType.Ore,
		barPrice = Home.BarPrices[meteorType.Ore] or 0,
	}
end

-- The results panel's upgrade hint for what was missed: "Tier 5 pickaxe mines
-- Crystal at full speed: $3K bars".
function MeteorTypes.missedHint(missed: Missed): string
	local oreName = Home.OreNames[missed.ore] or missed.ore
	return string.format("Tier %d pickaxe mines %s at full speed: %s bars", missed.tier, oreName, Format.cash(missed.barPrice))
end

-- Resonance: Mining Power multiplier for each of the players currently on one node.
function MeteorTypes.resonanceMult(hittersOnNode: number): number
	local resonance = Meteor.Twists.Resonance
	local extra = math.max(hittersOnNode - 1, 0)
	return 1 + math.min(resonance.BonusPerExtra * extra, resonance.MaxBonus)
end

-- Refreeze: a node's HP after `dt` seconds, given how long nobody has hit it.
-- Regenerates only once idle for IdleSeconds, never past max; a broken node stays broken.
function MeteorTypes.refreezeHp(hp: number, maxHp: number, idleSeconds: number, dt: number): number
	if hp <= 0 then
		return 0
	end
	local refreeze = Meteor.Twists.Refreeze
	if idleSeconds < refreeze.IdleSeconds then
		return hp
	end
	return math.min(hp + refreeze.RegenPerSecond * maxHp * dt, maxHp)
end

-- The type's shard pool multiplier, scaled down in proportion when meteors come
-- faster than the default interval (a 2-minute interval on a 4-minute default pays
-- half), so a group can't farm shards by speeding up the schedule.
function MeteorTypes.shardPoolMult(meteorType: MeteorType, intervalSeconds: number, defaultInterval: number): number
	if intervalSeconds >= defaultInterval then
		return meteorType.ShardMult
	end
	return meteorType.ShardMult * math.max(intervalSeconds, 0) / defaultInterval
end

return MeteorTypes
