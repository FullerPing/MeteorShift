--!strict
-- What a debris rock pays by the ore field it stands in (Config.Debris.Fields). A rock outside a field, or in an
-- unknown one, is plain filler: Config.Debris.Hp hits and the default ore at Config.Debris.YieldFraction.

local Debris = require(script.Parent.Config.Debris)
local Pickaxes = require(script.Parent.Config.Pickaxes)
local FieldTravel = require(script.Parent.FieldTravel)
local Income = require(script.Parent.Income)

local DebrisField = {}

export type Reward = Debris.Reward

-- The reward of the field named `id`, or nil for filler
function DebrisField.reward(id: any): Debris.Reward?
	local field = FieldTravel.find(id)
	return if field then field.Reward else nil
end

-- Hits a rock takes to break for the player it is sized for
function DebrisField.hits(reward: Debris.Reward?): number
	return if reward then reward.Hp else Debris.Hp
end

-- Cash a cash rock pays: its seconds of the breaker's expected income, between its floor and its ceiling
-- (a share of the next rebirth's cost). The seconds are for the Basic Pickaxe's swing and shrink with the
-- breaker's `swing`, since a faster pickaxe breaks the rock sooner (without that, the fast top tiers made a
-- field pay 2.5x the meteors). Zero for any other kind of rock.
function DebrisField.cash(reward: Debris.Reward?, perSecond: number, rebirthCost: number, swing: number?): number
	if not reward or reward.Kind ~= "Cash" then
		return 0
	end
	local base = Pickaxes[1].Swing
	local speed = math.clamp((swing or base) / base, 0, 1)
	return Income.grant((reward.Seconds or 0) * speed, perSecond, reward.CashFloor or 0, rebirthCost * (reward.CeilingShare or 0))
end

-- How much of a full payout a rock is worth to its breaker: rocks are sized for one random active player's
-- pickaxe (`maxHp` = hits × that Power), so a rock sized for a weaker pickaxe than the breaker's pays only
-- that fraction (a veteran one-shotting newcomer rocks earns proportionally). Never more than 1.
function DebrisField.sizedShare(maxHp: number, hits: number, breakerPower: number): number
	local full = hits * breakerPower
	if not (full > 0 and full < math.huge and maxHp >= 0) then
		return 1
	end
	return math.min(1, maxHp / full)
end

-- The ore and per-hit multiplier a rock drops, with `yieldShare` the part of a full hit the player's level
-- lets an ore rock's ore yield (Levels.oreYield). A cash rock drops no ore; filler drops the default ore.
function DebrisField.ore(reward: Debris.Reward?, yieldShare: number): (string?, number)
	if reward and reward.Kind == "Cash" then
		return nil, 0
	elseif reward and reward.Ore then
		return reward.Ore, (reward.OreMult or Debris.YieldFraction) * yieldShare
	end
	return Debris.Ore, Debris.YieldFraction
end

-- Seconds until a broken rock comes back: a roll in RespawnMin..RespawnMax (`roll` in 0..1), shortened when
-- more than RespawnCrowd players share the server
function DebrisField.respawnSeconds(players: number, roll: number): number
	local base = Debris.RespawnMin + (Debris.RespawnMax - Debris.RespawnMin) * roll
	return math.max(Debris.RespawnFloor, base / math.max(1, players / Debris.RespawnCrowd))
end

return DebrisField
