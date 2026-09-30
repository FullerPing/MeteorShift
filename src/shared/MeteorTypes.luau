--!strict
-- Meteor types (spec §8.1): which type comes next and what each player gets from it.
--
-- Every type is the same event (spec §5) with the ore, the required pickaxe tier,
-- one twist and the multipliers swapped (Config.Meteor.Types). The rules around them:
--
--   pick           weighted odds (Iron 60, Ice 25, Crystal 15), but a type can only come
--                  up when at least 25% of active players meet its tier; otherwise it
--                  drops to the next type down (Iron always can)
--   oreFor         your own pickaxe decides your ore: the meteor's ore at ×1 if you meet
--                  its tier, else the best ore you can extract at ×1.25. Nobody is locked
--                  out, and being near veterans never gives a better ore than you could
--                  mine alone
--   missed         what an under-tier player missed, and missedHint, the results line for it
--   resonanceMult  Crystal twist: +20% Mining Power per extra hitter on a node, max +60%
--   refreezeHp     Ice twist: a node nobody has hit for 5 s regains 2% of max HP per second
--   shardPoolMult  the type's shard pool ×, scaled down when meteors come faster than the
--                  default interval (private servers)
--
-- Pure functions only (the caller passes the roll, the tiers and the clocks), so the
-- rules are covered by tests/MeteorTypes.spec.

local Meteor = require(script.Parent.Config.Meteor)
local Home = require(script.Parent.Config.Home)
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

-- The ore a pickaxe tier mines from this meteor, and its quantity multiplier.
function MeteorTypes.oreFor(pickaxeTier: number, meteorType: MeteorType): (string, number)
	if pickaxeTier >= meteorType.RequiredTier then
		return meteorType.Ore, 1
	end
	for i = #TypeOrder, 1, -1 do
		local best = Types[TypeOrder[i]]
		if best.RequiredTier <= pickaxeTier then
			return best.Ore, Meteor.ConsolationMult
		end
	end
	-- Only reachable with a tier below every type's; the lowest type's ore then
	return Types[TypeOrder[1]].Ore, Meteor.ConsolationMult
end

-- What an under-tier player missed on this meteor ("Tier 5 pickaxe mines Crystal:
-- $3K bars"), or nil when their pickaxe met its tier.
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
-- Crystal: $3K bars".
function MeteorTypes.missedHint(missed: Missed): string
	local oreName = Home.OreNames[missed.ore] or missed.ore
	return string.format("Tier %d pickaxe mines %s: %s bars", missed.tier, oreName, Format.cash(missed.barPrice))
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
