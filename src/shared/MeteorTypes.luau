--!strict
-- Meteor types (spec §8.1): which type comes next and the twist math.
--
-- Every type is the same event (spec §5) with the ore, one twist and the multipliers
-- swapped (Config.Meteor.Types):
--
--   pick           weighted odds (Iron 60, Ice 25, Crystal 15)
--   resonanceMult  Crystal twist: +20% Mining Power per extra hitter on a node, max +60%
--   refreezeHp     Ice twist: a node nobody has hit for 5 s regains 2% of max HP per second
--   shardPoolMult  the type's shard pool x, scaled down when meteors come faster than the
--                  default interval (private servers)
--   golden         the golden variant of a type (Config.Hooks.GoldenMeteor): same Id and twist, its
--                  ore pays PayMult times, gold crust and ore chunks
--
-- Pure functions only, so the rules are covered by tests/MeteorTypes.spec.

local Meteor = require(script.Parent.Config.Meteor)
local Hooks = require(script.Parent.Config.Hooks)

type MeteorType = Meteor.MeteorType

local Types = Meteor.Types
local TypeOrder = Meteor.TypeOrder

local MeteorTypes = {}

-- The next meteor type: `roll` is uniform in [0, 1) (math.random() on the server) and
-- lands in the types' Weight bands in TypeOrder. Everyone mines the type's own ore; what a
-- player's level yields in full is Shared.Levels.oreYield (a fraction below it, never nothing), so
-- no lobby is stuck on one type and nobody is locked out.
function MeteorTypes.pick(roll: number): MeteorType
	local total = 0
	for _, id in TypeOrder do
		total += Types[id].Weight
	end
	local target = roll * total
	local bandEnd = 0
	for _, id in TypeOrder do
		bandEnd += Types[id].Weight
		if target < bandEnd then
			return Types[id]
		end
	end
	return Types[TypeOrder[#TypeOrder]]
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

local GOLD_CRUST = { Color3.fromRGB(196, 150, 46), Color3.fromRGB(222, 176, 66), Color3.fromRGB(170, 128, 36) }

-- A golden copy of `meteorType`: it keeps its Id (so every effect keyed by type still works), its
-- name gets "Golden", and its ore pays Config.Hooks.GoldenMeteor.PayMult times per hit.
function MeteorTypes.golden(meteorType: MeteorType): MeteorType
	local copy = table.clone(meteorType)
	copy.DisplayName = "Golden " .. meteorType.DisplayName
	copy.YieldMult = meteorType.YieldMult * Hooks.GoldenMeteor.PayMult
	copy.CrustColors = GOLD_CRUST
	copy.OreColor = Color3.fromRGB(255, 226, 120)
	copy.Golden = true
	return copy
end

return MeteorTypes
