--!strict
-- Rebirth rules (spec §8.3, "Relocate the Colony"), from Config.Rebirth:
--
--   cost         cash needed for the next rebirth after `rebirths` of them:
--                BaseCost × CostGrowth^rebirths ($10M, $100M, $1B, ...)
--   multiplier   the permanent bar sale multiplier `rebirths` give:
--                CashMult^rebirths (x1, x2, x4, x8, ...), multiplicative
--
-- A missing or negative count reads as no rebirths. Pure functions, covered by
-- tests/Rebirth.spec; RebirthService, EconomyService and the client all use them.

local Config = require(script.Parent.Config.Rebirth)

local Rebirth = {}

local function count(rebirths: number?): number
	return math.max(0, math.floor(rebirths or 0))
end

function Rebirth.cost(rebirths: number?): number
	return Config.BaseCost * Config.CostGrowth ^ count(rebirths)
end

function Rebirth.multiplier(rebirths: number?): number
	return Config.CashMult ^ count(rebirths)
end

return Rebirth
