--!strict
-- Fixed product grants and receipt idempotency. Random draws, eggs and mineral odds
-- never enter this path; Core Shards come only as the fixed ShardPacks. Covered by
-- tests/Purchases.spec.

local Config = require(script.Parent.Config)
local Gear = require(script.Parent.Gear)
local Income = require(script.Parent.Income)
local Levels = require(script.Parent.Levels)
local Pets = require(script.Parent.Pets)
local Price = require(script.Parent.Price)

local Purchases = {}
local Rules = Config.Monetization

export type Grant = {
	cash: number,
	leveled: { [string]: number },
	shards: number?, -- shard packs, and the shards a tier-up refunds
	evolved: boolean?, -- tier-ups: the item went up a tier (false when it had already passed it)
	tier: number?, -- tier-ups: the tier the item is on now
}

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
	return Income.grant(minutes * 60, barsPerSecond * averageBarPrice * saleMultiplier, floor, ceiling)
end

function Purchases.oreMultiplier(hasPass: boolean, oreBoostLeft: number?): number
	local pass = if hasPass then Rules.OreMult else 1
	local boost = if (oreBoostLeft or 0) > 0 then Rules.OreRush.Multiplier else 1
	return math.max(pass, boost)
end

-- Gives `xp` to each distinct equipped pet (a duplicated equipped entry counts once).
local function giveEquippedXp(data: any, xp: number, result: Grant)
	local seen: { [string]: boolean } = {}
	for _, petId in data.pets.equipped do
		local entry = data.pets.owned[petId]
		if entry and not seen[petId] then
			seen[petId] = true
			if Pets.addXp(entry, xp) > 0 then
				result.leveled[petId] = entry.level
			end
		end
	end
end

local function markFlag(data: any, name: string)
	if not data.flags then
		data.flags = {}
	end
	data.flags[name] = true
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
	elseif key == "PetMax" then
		local seen: { [string]: boolean } = {}
		for _, petId in data.pets.equipped do
			local entry = data.pets.owned[petId]
			if entry and not seen[petId] then
				seen[petId] = true
				if entry.level < Config.Pets.MaxLevel then
					entry.level, entry.xp = Config.Pets.MaxLevel, 0
					result.leveled[petId] = entry.level
				end
			end
		end
	elseif key == "PetSlot" then
		markFlag(data, "extraPetSlot")
	elseif key == "StarterPack" then
		if not cash or cash ~= cash or cash <= 0 or cash == math.huge then
			return nil
		end
		result.cash = math.floor(cash)
		data.cash += result.cash
		data.overclockLeft = (data.overclockLeft or 0) + Rules.StarterPack.Overclocks * Rules.MiniOverclock.Duration
		giveEquippedXp(data, Rules.StarterPack.PetXp, result)
		markFlag(data, "starterPack")
	elseif key == "Overclock" or key == "MiniOverclock" then
		local duration = if key == "Overclock" then Rules.Overclock.Duration else Rules.MiniOverclock.Duration
		data.overclockLeft = (data.overclockLeft or 0) + duration
	elseif key == "OreRush" then
		data.oreBoostLeft = (data.oreBoostLeft or 0) + Rules.OreRush.Duration
	elseif key == "CallMeteor" then
		data.credits.callMeteor = (data.credits.callMeteor or 0) + 1
	elseif key == "BossMeteor" then
		data.credits.bossMeteor = (data.credits.bossMeteor or 0) + 1
	elseif key == "RebirthKeep" then
		data.credits.rebirthKeep = (data.credits.rebirthKeep or 0) + 1
	elseif Rules.ShardPacks[key] then
		result.shards = Rules.ShardPacks[key]
		data.shards += result.shards
	else
		return nil
	end
	return result
end

-- Tier-up products (Rules.Products[key].Kind / From): evolves the item one tier, free of the
-- cash, shards and player level the shop asks for. If the item is no longer on the tier the
-- product skips from (it evolved meanwhile, or the id was prompted by hand), the buyer gets
-- the value of that evolve instead, at their rebirth price. nil for anything else.
function Purchases.gearSkip(data: any, key: string, priceMult: number): Grant?
	local product = Rules.Products[key]
	if not product or not product.Kind or not product.From then
		return nil
	end
	local list = if product.Kind == "pickaxe" then Config.Pickaxes else Config.Backpacks
	local tierKey = product.Kind .. "Tier"
	local tier = data[tierKey] or 1
	local result: Grant = { cash = 0, leveled = {}, shards = 0, evolved = false, tier = tier }
	if tier == product.From and list[tier + 1] then
		data[tierKey] = tier + 1
		data[product.Kind .. "Level"] = Gear.levelsForTier(tier + 1) -- every tier starts over at level 1
		result.evolved, result.tier = true, tier + 1
		return result
	end
	local target = list[product.From + 1]
	if not target then
		return nil
	end
	result.cash = Price.scaled(target.Cost, priceMult)
	result.shards = target.Shards
	data.cash += result.cash
	data.shards += result.shards
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
