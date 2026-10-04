--!strict
-- Economy pacing model (spec §7.4, Week 5 balancing; docs/balance.md).
--
-- Simulates a fresh free player's first sessions from Config alone: no passes, no
-- rebirth, no mineral index. The first meteor comes after Meteor.FirstCountdown, the
-- next ones every full event cycle. Iron meteors only until the player's pickaxe meets
-- Ice's tier; from then on each meteor is worth its expected value (see meteorBarPrice).
-- The player mines the meteor while
-- it is active and debris between meteors, walks home with a full backpack, and
-- sells every Balance.SellInterval seconds.
--
--   ore rate     = backpack / (backpack / ore-per-hit x swing / HitsPerMinuteShare + TripSeconds)
--   ore supply   = time-weighted meteor rate and debris rate (debris pays YieldFraction of a hit)
--   line rate    = min(conveyor, refinery)    (same as Server.Lib.Refining)
--   income       = min(ore supply, line rate) x blended bar price (meteor ore and debris iron)
--
-- A pickaxe or backpack tier is bought as a bundle (Shared.Gear.bundleCost): the Gate stat's
-- levels up to the tier cap, then the evolve price. Speed, Reach and Crit levels are the
-- player's own side budget and don't move income in the model.
--
-- Purchases are greedy: whenever the player sells, of the next pickaxe, backpack, conveyor
-- and refinery levels that they hold the shards for and that raise income, the one with
-- the shortest payback (cost / income gained) is chosen, and the player saves up for it
-- if it is out of reach. Hopper and collection post levels are never bought: they only
-- matter for offline income (spec §6.4), which `offlineCap` covers.
--
-- Ice and Crystal (expected value, no dice): the schedule picks a type by Weight and a
-- type the crowd can't mine drops to the next one down (Meteor.TypeOrder). The lobby is
-- assumed to be all at the player's own pickaxe tier, so a type is eligible exactly when
-- the player's pickaxe meets its tier. Every meteor then pays the probability-weighted
-- bar price of its ore. Ice's Refreeze twist and HP multiplier are ignored (they cost the
-- crowd time, not the player's ore); Crystal's Resonance likewise.
--
-- Core Shards come from every finished meteor at Balance.ShardsPerMeteor (the floor plus an
-- average share of the bonus pool, over the meteors that crack).
--
-- Rebirth (spec §8.3, optional, `Options.rebirths`): once cash covers Shared.Rebirth.cost the
-- player relocates: cash, pickaxe, backpack, hopper, conveyor, collection post and carried
-- stock reset, the refinery level and shards stay, and every sale pays Rebirth.multiplier.
-- With `Options.paybackLimit` the player only buys what pays itself back within that many
-- seconds, so cash can pile up for the rebirth instead of going into slow upgrades.
-- Pure functions, cheap enough to call from a spec (about 3,600 steps for two hours).

local Config = require(script.Parent.Config)
local Rebirth = require(script.Parent.Rebirth)
local Gear = require(script.Parent.Gear)
local Levels = require(script.Parent.Levels)

local Pacing = {}

export type Owned = {
	pickaxe: number,
	backpack: number,
	hopper: number,
	conveyor: number,
	refinery: number,
	collector: number,
}

export type Purchase = {
	time: number,
	id: string, -- "pickaxe2", "backpack3", "refinery2", ...
	name: string,
	cost: number,
	shards: number,
	cashAfter: number,
}

export type Options = {
	rebirths: number?, -- most rebirths the player takes (default 0)
	paybackLimit: number?, -- seconds; skip upgrades that take longer than this to pay back
}

export type Sample = {
	time: number,
	rebirths: number,
	cash: number,
	shards: number,
	earned: number, -- total bar sales so far
	owned: Owned,
	lineRate: number,
	incomePerMinute: number,
}

export type Result = {
	purchases: { Purchase },
	affordableAt: { [string]: number }, -- first time the next level of a track was in reach
	earnedAt: { [string]: number }, -- first time lifetime sales reached a pickaxe's or backpack's price
	samples: { Sample },
	rebirthTimes: { number }, -- when each rebirth happened
	cycle: number, -- seconds from one impact to the next
	firstCycleEnd: number, -- when the first meteor's event cycle is over
}

local Balance = Config.Balance
local Iron = Config.Meteor.Types.Iron
local BarPrice = Config.Home.BarPrices[Iron.Ore]

-- XP a player earns per finished meteor in the model (an average player; tests/Levels.spec)
local XP_PER_METEOR = 70

-- Player level after `meteors` finished meteors
local function levelAfter(meteors: number): number
	return Levels.clean(1, meteors * XP_PER_METEOR).level
end

-- One ore mined from a meteor at a player level: the average bar price, and the average
-- refining cost in line units (1 / clearance, Shared.Levels). Meteor types come up by weight
-- and everyone mines all of them.
local function meteorMix(level: number): (number, number)
	local order = Config.Meteor.TypeOrder
	local total, price, cost = 0, 0, 0
	for _, id in order do
		local type = Config.Meteor.Types[id]
		total += type.Weight
		price += type.Weight * Config.Home.BarPrices[type.Ore]
		cost += type.Weight / Levels.clearance(level, type.Ore)
	end
	return price / total, cost / total
end

-- Seconds from one impact to the next: the event, its end phase, cleanup, then the countdown.
function Pacing.cycleSeconds(): number
	return Config.Meteor.ImpactDuration
		+ Iron.ActiveDuration
		+ math.max(Config.Meteor.CrackedDuration, Config.Meteor.CooledDuration)
		+ Config.Meteor.CleanupDuration
		+ Config.Meteor.Countdown
end

-- Ore per second a player brings home while mining, trips included. `yield` scales ore per hit.
function Pacing.oreRate(pickaxeTier: number, backpackTier: number, yield: number): number
	local pickaxe = Config.Pickaxes[pickaxeTier]
	local capacity = Config.Backpacks[backpackTier].Capacity
	local perHit = pickaxe.OrePerHit * yield * Iron.YieldMult
	local fillSeconds = capacity / perHit * pickaxe.Swing / Balance.HitsPerMinuteShare
	return capacity / (fillSeconds + Balance.TripSeconds)
end

-- Is a meteor active (minable) at this second of the run?
local function meteorActive(time: number, cycle: number): boolean
	local sinceFirst = time - (Config.Meteor.FirstCountdown + Config.Meteor.ImpactDuration)
	if sinceFirst < 0 then
		return false
	end
	return sinceFirst % cycle < Iron.ActiveDuration
end

-- Ore per second averaged over a whole cycle, and the blended bar price of that ore
-- (meteor and debris time weighted).
local function averageSupply(owned: Owned, cycle: number, level: number): (number, number, number)
	local meteor = Pacing.oreRate(owned.pickaxe, owned.backpack, 1) * Iron.ActiveDuration
	local debris = Pacing.oreRate(owned.pickaxe, owned.backpack, Config.Debris.YieldFraction)
		* Balance.DebrisActivityShare
		* (cycle - Iron.ActiveDuration)
	local meteorPrice, meteorCost = meteorMix(level)
	local price = (meteor * meteorPrice + debris * BarPrice) / (meteor + debris)
	local cost = (meteor * meteorCost + debris) / (meteor + debris)
	return (meteor + debris) / cycle, price, cost
end

local function lineRate(owned: Owned): number
	local stations = Config.Home.Stations
	return math.min(
		stations.conveyor.Levels[owned.conveyor].Rate :: number,
		stations.refinery.Levels[owned.refinery].Rate :: number
	)
end

-- Cash per second in the long run
local function income(owned: Owned, cycle: number, level: number, mult: number?): number
	local supply, price, cost = averageSupply(owned, cycle, level)
	return math.min(supply, lineRate(owned) / cost) * price * (mult or 1)
end

type Candidate = { id: string, name: string, cost: number, shards: number, apply: (Owned) -> () }

-- The next level of every track a player buys from.
local function candidates(owned: Owned): { Candidate }
	local out: { Candidate } = {}
	local pickaxe = Config.Pickaxes[owned.pickaxe + 1]
	if pickaxe then
		table.insert(out, {
			id = "pickaxe" .. pickaxe.Tier,
			name = pickaxe.Name,
			cost = Gear.bundleCost("pickaxe", pickaxe.Tier),
			shards = pickaxe.Shards,
			apply = function(o: Owned)
				o.pickaxe += 1
			end,
		})
	end
	local backpack = Config.Backpacks[owned.backpack + 1]
	if backpack then
		table.insert(out, {
			id = "backpack" .. backpack.Tier,
			name = backpack.Name,
			cost = Gear.bundleCost("backpack", backpack.Tier),
			shards = backpack.Shards,
			apply = function(o: Owned)
				o.backpack += 1
			end,
		})
	end
	for _, stationId in { "conveyor", "refinery" } do
		local station = Config.Home.Stations[stationId]
		local nextLevel = (owned :: any)[stationId] + 1
		local level = station.Levels[nextLevel]
		if level then
			table.insert(out, {
				id = stationId .. nextLevel,
				name = station.Name .. " level " .. nextLevel,
				cost = level.Cost,
				shards = level.Shards,
				apply = function(o: Owned)
					(o :: any)[stationId] += 1
				end,
			})
		end
	end
	return out
end

-- Runs the model for `horizon` seconds (default Balance.Horizon).
function Pacing.simulate(horizon: number?, options: Options?): Result
	local total = horizon or Balance.Horizon
	local maxRebirths = if options and options.rebirths then options.rebirths else 0
	local paybackLimit = if options and options.paybackLimit then options.paybackLimit else math.huge
	local rebirths, mult = 0, 1
	local step = Balance.StepSeconds
	local cycle = Pacing.cycleSeconds()
	local owned: Owned = { pickaxe = 1, backpack = 1, hopper = 1, conveyor = 1, refinery = 1, collector = 1 }
	local cash, shards, earned = 0, 0, 0
	local hopperOre, hopperValue, hopperCost, bars, barsValue = 0, 0, 0, 0, 0
	local result: Result = {
		purchases = {},
		affordableAt = {},
		earnedAt = {},
		samples = {},
		rebirthTimes = {},
		cycle = cycle,
		firstCycleEnd = Config.Meteor.FirstCountdown + cycle,
	}
	local nextSell, nextSample = Balance.SellInterval, 0
	local meteorsCounted = 0

	local function sample(time: number)
		table.insert(result.samples, {
			time = time,
			rebirths = rebirths,
			cash = cash,
			shards = shards,
			earned = earned,
			owned = table.clone(owned),
			lineRate = lineRate(owned),
			incomePerMinute = income(owned, cycle, levelAfter(meteorsCounted), mult) * 60,
		})
	end

	local time = 0
	while time <= total do
		if time >= nextSample then
			sample(time)
			nextSample += Balance.SampleInterval
		end

		-- Mining: ore into the hopper, capped by its capacity
		local onMeteor = meteorActive(time, cycle)
		local yield = if onMeteor then 1 else Config.Debris.YieldFraction * Balance.DebrisActivityShare
		local level = levelAfter(meteorsCounted)
		local meteorPrice, meteorCost = meteorMix(level)
		local orePrice = if onMeteor then meteorPrice else BarPrice
		local oreCost = if onMeteor then meteorCost else 1
		local hopperRoom = (Config.Home.Stations.hopper.Levels[owned.hopper].Capacity :: number) - hopperOre
		local mined = math.min(Pacing.oreRate(owned.pickaxe, owned.backpack, yield) * step, hopperRoom)
		hopperOre += mined
		hopperValue += mined * orePrice
		hopperCost += mined * oreCost

		-- The line: limited by time, hopper stock and room at the collection post
		local room = (Config.Home.Stations.collector.Levels[owned.collector].Capacity :: number) - bars
		local avgCost = if hopperOre > 0 then hopperCost / hopperOre else 1
		local made = math.max(math.min(lineRate(owned) * step / avgCost, hopperOre, room), 0)
		local madeValue = if hopperOre > 0 then hopperValue * made / hopperOre else 0
		local madeCost = if hopperOre > 0 then hopperCost * made / hopperOre else 0
		hopperOre -= made
		hopperValue -= madeValue
		hopperCost -= madeCost
		bars += made
		barsValue += madeValue

		-- A finished meteor pays its shard floor
		local sinceFirst = time - (Config.Meteor.FirstCountdown + Config.Meteor.ImpactDuration + Iron.ActiveDuration)
		if sinceFirst >= 0 then
			local finished = math.floor(sinceFirst / cycle) + 1
			if finished > meteorsCounted then
				shards += (finished - meteorsCounted) * Balance.ShardsPerMeteor
				meteorsCounted = finished
			end
		end

		-- Home: sell, then shop
		if time >= nextSell then
			nextSell += Balance.SellInterval
			cash += barsValue * mult
			earned += barsValue * mult
			bars, barsValue = 0, 0
			for _, tier in Config.Pickaxes do
				local price = Gear.bundleCost("pickaxe", tier.Tier)
				if price > 0 and earned >= price and result.earnedAt["pickaxe" .. tier.Tier] == nil then
					result.earnedAt["pickaxe" .. tier.Tier] = time
				end
			end
			for _, tier in Config.Backpacks do
				local price = Gear.bundleCost("backpack", tier.Tier)
				if price > 0 and earned >= price and result.earnedAt["backpack" .. tier.Tier] == nil then
					result.earnedAt["backpack" .. tier.Tier] = time
				end
			end
			for _, item in candidates(owned) do
				if cash >= item.cost and shards >= item.shards and result.affordableAt[item.id] == nil then
					result.affordableAt[item.id] = time
				end
			end
			local bought = true
			while bought do
				bought = false
				local best: Candidate? = nil
				local bestPayback = math.huge
				local now = income(owned, cycle, level, mult)
				for _, item in candidates(owned) do
					if item.shards > shards then
						continue
					end
					local after = table.clone(owned)
					item.apply(after)
					local gain = income(after, cycle, level, mult) - now
					if gain > 1e-9 and item.cost / gain <= paybackLimit and item.cost / gain < bestPayback then
						best, bestPayback = item, item.cost / gain
					end
				end
				if best and cash >= best.cost then
					cash -= best.cost
					shards -= best.shards
					best.apply(owned)
					table.insert(result.purchases, {
						time = time,
						id = best.id,
						name = best.name,
						cost = best.cost,
						shards = best.shards,
						cashAfter = cash,
					})
					bought = true
				end
			end
			if rebirths < maxRebirths and cash >= Rebirth.cost(rebirths) then
				rebirths += 1
				mult = Rebirth.multiplier(rebirths)
				table.insert(result.rebirthTimes, time)
				cash = 0
				owned.pickaxe, owned.backpack, owned.hopper, owned.conveyor, owned.collector = 1, 1, 1, 1, 1
				hopperOre, hopperValue, hopperCost, bars, barsValue = 0, 0, 0, 0, 0
			end
		end
		time += step
	end
	sample(total)
	return result
end

-- The snapshot at or before `time`.
function Pacing.sampleAt(result: Result, time: number): Sample
	local found = result.samples[1]
	for _, s in result.samples do
		if s.time <= time then
			found = s
		end
	end
	return found
end

-- Cash a level 1 line makes while its owner is away for the offline cap, limited by
-- the hopper's stock and the collection post's room (spec §6.4). Iron bars, no multipliers.
function Pacing.offlineCap(hours: number?): number
	local stations = Config.Home.Stations
	local rate = lineRate({ pickaxe = 1, backpack = 1, hopper = 1, conveyor = 1, refinery = 1, collector = 1 })
	local seconds = if hours then hours * 3600 else Config.Home.OfflineCap
	local bars = math.min(rate * seconds, stations.hopper.Levels[1].Capacity :: number, stations.collector.Levels[1].Capacity :: number)
	return bars * BarPrice
end

return Pacing
