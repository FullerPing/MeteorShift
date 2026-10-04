--!strict
-- Mining Power (spec §5.3): the hidden stat node and core HP run on.
--
-- Hits still show the pickaxe's big damage number and ore per hit still comes from
-- the pickaxe, but HP and contribution are counted in Mining Power, which grows only
-- ~1.25× per tier. A maxed veteran clears nodes ~8× faster than a newcomer, not ~900×.
--
--   power(tier)  = 1.25 ^ (tier − 1)
--   powerPerSec  = power(tier) / swingTime
--   serverPower  = max(sum of active players' powerPerSec, FloorPlayers basic pickaxes)
--   crustHP      = serverPower × 70 s × type HP mult (split across the crust nodes)
--   coreHP       = serverPower × 45 s × type HP mult
--
-- Pure functions only, so the math can be checked from the command bar.

local Meteor = require(script.Parent.Config.Meteor)
local Pickaxes = require(script.Parent.Config.Pickaxes)

local MiningPower = {}

function MiningPower.power(tier: number): number
	return Meteor.PowerGrowth ^ (tier - 1)
end

function MiningPower.perSecond(tier: number): number
	local pickaxe = Pickaxes[tier] or Pickaxes[1]
	return MiningPower.power(pickaxe.Tier) / pickaxe.Swing
end

-- The smallest meteor a server gets, so tiny lobbies still get a real one.
function MiningPower.floorPower(): number
	return Meteor.FloorPlayers * MiningPower.perSecond(1)
end

-- Total power per second of the given (active) players' pickaxe tiers, with the floor.
function MiningPower.serverPower(tiers: { number }): number
	local rates = {}
	for _, tier in tiers do
		table.insert(rates, MiningPower.perSecond(tier))
	end
	return MiningPower.serverPowerRates(rates)
end

-- The same from each player's own power per second (their leveled pickaxe's Power / Swing,
-- Shared.Gear), with the floor.
function MiningPower.serverPowerRates(rates: { number }): number
	local total = 0
	for _, rate in rates do
		total += rate
	end
	return math.max(total, MiningPower.floorPower())
end

-- HP of each crust node and of the core for a given server power.
function MiningPower.size(serverPower: number, crustNodes: number, hpMult: number): (number, number)
	local crustHp = serverPower * Meteor.CrustSeconds * hpMult / math.max(crustNodes, 1)
	local coreHp = serverPower * Meteor.CoreSeconds * hpMult
	return crustHp, coreHp
end

-- True when the power the meteor was sized for is more than 15% off the current one.
function MiningPower.shouldRescale(sizedPower: number, currentPower: number): boolean
	return math.abs(currentPower / sizedPower - 1) > Meteor.RescaleThreshold
end

-- Rescales a node to a new server power, keeping the same fraction done.
function MiningPower.rescale(hp: number, maxHp: number, ratio: number): (number, number)
	return hp * ratio, maxHp * ratio
end

return MiningPower
