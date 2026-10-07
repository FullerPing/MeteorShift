--!strict
-- Fixed product grants and receipt idempotency. Random draws, eggs, mineral odds
-- and Core Shards never enter this path. Covered by tests/Purchases.spec.

local Config = require(script.Parent.Config)
local Levels = require(script.Parent.Levels)
local Pets = require(script.Parent.Pets)

local Purchases = {}
local Rules = Config.Monetization

export type Grant = { cash: number, leveled: { [string]: number } }

-- A meteor's weight is multiplied by the share of its ore a hit yields at the player's level
-- (Levels.oreYield) before averaging bar prices: a fraction of a hit contributes less to the
-- estimated income. This is a quote from line capacity, independent of live stock.
function Purchases.averageBarPrice(level: number): number
	local total, value = 0, 0
	for _, id in Config.Meteor.TypeOrder do
		local meteor = Config.Meteor.Types[id]
		local weight = meteor.Weight * Levels.oreYield(level, meteor.Ore)
		total += weight
		value += weight * Config.Home.BarPrices[meteor.Ore]
	end
	return if total > 0 then value / total else Config.Home.BarPrices.iron
end

function Purchases.cashGrant(minutes: number, barsPerSecond: number, averageBarPrice: number, saleMultiplier: number, floor: number, ceiling: number): number
	local cap = math.max(ceiling, 0)
	local income = minutes * 60 * barsPerSecond * averageBarPrice * saleMultiplier
	return math.floor(math.clamp(income, math.min(math.max(floor, 0), cap), cap))
end

function Purchases.oreMultiplier(hasPass: boolean, oreBoostLeft: number?): number
	local pass = if hasPass then Rules.OreMult else 1
	local boost = if (oreBoostLeft or 0) > 0 then Rules.OreRush.Multiplier else 1
	return math.max(pass, boost)
end

-- Mutates only the fixed gameplay award. Session cosmetics and calling a meteor
-- are server-side effects; CallMeteor first grants a credit that the caller may use.
function Purchases.grant(data: any, key: string, cash: number?): Grant?
	local result: Grant = { cash = 0, leveled = {} }
	if key == "TipJar" then
		return result
	elseif key == "PocketChange" or key == "CashBundle" then
		if not cash or cash ~= cash or cash <= 0 or cash == math.huge then
			return nil
		end
		result.cash = math.floor(cash)
		data.cash += result.cash
	elseif key == "PetTreat" or key == "PetFeast" then
		local seen: { [string]: boolean } = {}
		for _, petId in data.pets.equipped do
			local entry = data.pets.owned[petId]
			if entry and not seen[petId] then
				seen[petId] = true
				if Pets.addXp(entry, Rules.PetXp[key]) > 0 then
					result.leveled[petId] = entry.level
				end
			end
		end
	elseif key == "Overclock" or key == "MiniOverclock" then
		local duration = if key == "Overclock" then Rules.Overclock.Duration else Rules.MiniOverclock.Duration
		data.overclockLeft = (data.overclockLeft or 0) + duration
	elseif key == "OreRush" then
		data.oreBoostLeft = (data.oreBoostLeft or 0) + Rules.OreRush.Duration
	elseif key == "CallMeteor" then
		data.credits.callMeteor = (data.credits.callMeteor or 0) + 1
	else
		return nil
	end
	return result
end

-- A failed save keeps the grant and id together in memory; retrying saves again
-- without granting twice. Callers serialize this transaction per profile.
function Purchases.receipt(data: any?, purchaseId: string, grant: () -> boolean, save: () -> boolean): (boolean, boolean)
	if not data or purchaseId == "" then
		return false, false
	end
	local fresh = table.find(data.receipts, purchaseId) == nil
	if fresh then
		if not grant() then
			return false, false
		end
		table.insert(data.receipts, purchaseId)
	end
	return save(), fresh
end

return Purchases
