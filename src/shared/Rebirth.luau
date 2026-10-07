--!strict
-- Rebirth rules (spec §8.3, "Relocate the Colony"), from Config.Rebirth:
--
--   cost         cash needed for the next rebirth after `rebirths` of them: the listed
--                Config.Rebirth.Costs for ranks 1 to 8, then ×Legacy.CostGrowth per rank
--   multiplier   the permanent bar sale multiplier `rebirths` give: CashMult^rebirths
--                (x1, x5, x25, ...) up to the last listed rank, then ×Legacy.MultGrowth per rank
--   overstayShards  shards for the cash earned after the rebirth was first affordable
--
-- A missing or negative count reads as no rebirths. Pure functions, covered by
-- tests/Rebirth.spec; RebirthService, EconomyService and the client all use them.

local Config = require(script.Parent.Config.Rebirth)

local Rebirth = {}

local function count(rebirths: number?): number
	return math.max(0, math.floor(rebirths or 0))
end

function Rebirth.cost(rebirths: number?): number
	local n = count(rebirths)
	local costs = Config.Costs
	if n < #costs then
		return costs[n + 1]
	end
	return costs[#costs] * Config.Legacy.CostGrowth ^ (n - #costs + 1)
end

function Rebirth.multiplier(rebirths: number?): number
	local n = count(rebirths)
	local listed = #Config.Costs
	if n <= listed then
		return Config.CashMult ^ n
	end
	return Config.CashMult ^ listed * Config.Legacy.MultGrowth ^ (n - listed)
end

-- Shards for the bar-sale cash earned since the rebirth became affordable (`overflow`),
-- against what it cost
function Rebirth.overstayShards(overflow: number, cost: number): number
	if overflow ~= overflow or overflow <= 0 or cost <= 0 then
		return 0
	end
	local settings = Config.Overstay
	return math.min(settings.Cap, math.floor(settings.PerDoubling * math.log(1 + overflow / cost, 2) + 0.5))
end

-- The one-line unlock text for the rank reached, or nil
function Rebirth.unlock(rank: number): string?
	return (Config.Unlocks :: { [number]: string })[rank]
end

return Rebirth
