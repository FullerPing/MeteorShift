--!strict
-- Economy pacing model (spec §7.4, Week 5 balancing; docs/guide/balance.md).
--
-- Simulates a fresh player's first sessions from Config alone: no mineral index or
-- quantity passes. By default there are no pets; Options.drillbotLevel equips one
-- fixed-level Drillbot. The first meteor comes after Meteor.FirstCountdown, then one
-- per full event cycle. Every player mines every type; the player level sets how much of an
-- ore a hit yields (Shared.Levels.oreYield) and which gear tiers can be bought.
-- The player mines active meteors and debris between them, walks home with a full
-- backpack, and sells every Balance.SellInterval seconds.
--
--   ore rate     = backpack / (backpack / ore-per-hit x swing / HitsPerMinuteShare + TripSeconds)
--   ore supply   = time-weighted meteor rate and debris rate (debris pays YieldFraction of a hit)
--   line rate    = min(conveyor, refinery) at the line level    (same as Server.Lib.Refining)
--   income       = min(ore supply, line rate) x blended bar price (meteor ore and debris iron)
--   Drillbot     = Yield scales ore, Swift shortens swings, Miner supplies direct-hopper
--                  ore while filling the backpack, with a target always in reach.
--                  It is inactive during trips and grants no XP, shards or mineral rolls.
--
-- A pickaxe or backpack tier is bought as a bundle (Shared.Gear.bundleCost): the Gate stat's
-- levels up to the tier cap, then the evolve price. Speed, Reach and Crit levels are the
-- player's own side budget and don't move income in the model.
--
-- Purchases are greedy: whenever the player sells, of the next pickaxe, backpack and production
-- line levels (Shared.Line) that their player level and rebirths allow (Config.Levels) and that
-- raise income, the one with the shortest payback (cost / income gained) is chosen, and the
-- player saves up for it if it is out of reach. Shards buy nothing here (Colony Perks are not modeled). The line level also
-- raises the hopper and collection post, which only matter for offline income (spec §6.4, `offlineCap`).
--
-- Ice and Crystal (expected value, no dice): types come up by Weight. A hit yields
-- Levels.oreYield of its ore at the player's level, and every ore refines at full speed at
-- its full bar price. Ice's Refreeze and HP multiplier are ignored (they cost crowd time,
-- not the player's ore); Crystal's Resonance likewise, and so are the engagement hooks
-- (their ore jackpots are EV-neutral by design: Shared.Hooks.oreBase).
-- A modeled Drillbot keeps its selected level after rebirth.
--
-- Every level gained opens a Supply Crate (Shared.Hooks.crate); the model pays its expected cash,
-- Hooks.crateExpectedSeconds of the line's income at the time.
--
-- Core Shards come from every finished meteor at Balance.ShardsPerMeteor (the floor plus an
-- average share of the bonus pool, over the meteors that crack).
--
-- Rebirth (spec §8.3, optional, `Options.rebirths`): once cash covers Shared.Rebirth.cost the
-- player relocates: cash, the production line and carried stock reset, the
-- pickaxe and backpack tiers and shards stay, every sale pays
-- Rebirth.multiplier and every cash price is Rebirth.priceMult times dearer.
-- With `Options.paybackLimit` the player only buys what pays itself back within that many
-- seconds, so cash can pile up for the rebirth instead of going into slow upgrades.
-- Pure functions, cheap enough to call from a spec (about 3,600 steps for two hours).

local Config = require(script.Parent.Config)
local Rebirth = require(script.Parent.Rebirth)
local Gear = require(script.Parent.Gear)
local Hooks = require(script.Parent.Hooks)
local Combo = require(script.Parent.Combo)
local Levels = require(script.Parent.Levels)
local Line = require(script.Parent.Line)
local Pets = require(script.Parent.Pets)
local Worlds = require(script.Parent.Worlds)

local Pacing = {}

export type Owned = {
	pickaxe: number,
	backpack: number,
	line: number, -- production line level (Shared.Line)
}

export type Purchase = {
	time: number,
	id: string, -- "pickaxe2", "backpack3", "line2", ...
	name: string,
	cost: number,
	shards: number,
	cashAfter: number,
}

export type Options = {
	rebirths: number?, -- most rebirths the player takes (default 0)
	paybackLimit: number?, -- seconds; skip upgrades that take longer than this to pay back
	drillbotLevel: number?, -- one equipped Drillbot, fixed at this level for the whole run
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
	petBonuses: Pets.Bonuses, -- the fixed pet treatment; all zero in the default free run
}

local Balance = Config.Balance
local Iron = Config.Meteor.Types.Iron
local BarPrice = Config.Home.BarPrices[Iron.Ore]

-- The ore of the rocks mined between meteors: the world's base ore (iron in World 1, nebula in Nebula Rift)
local function debrisPrice(world: number?): number
	local base = Config.Meteor.Types[Config.Meteor.WorldTypeOrder[world or 1][1]]
	return Config.Home.BarPrices[base.Ore] or BarPrice
end

-- XP a player earns per finished meteor in the model (an average player; tests/Levels.spec)
local XP_PER_METEOR = 70

-- Player level after `meteors` finished meteors
local function levelAfter(meteors: number): number
	return Levels.clean(1, meteors * XP_PER_METEOR).level
end

-- Ore mined from a meteor at a player level: the average bar price of what a hit yields and
-- the share of a full hit it yields on average. Meteor types come up by weight, everyone
-- mines all of them, and a hit of an ore above the player's level pays only a fraction of it
-- (Shared.Levels.oreYield). Each world has its own schedule (Config.Meteor.WorldTypeOrder).
local function meteorMix(level: number, world: number?): (number, number)
	local total, price, yield = 0, 0, 0
	for _, id in Config.Meteor.WorldTypeOrder[world or 1] do
		local type = Config.Meteor.Types[id]
		local fraction = Levels.oreYield(level, type.Ore)
		total += type.Weight
		yield += type.Weight * fraction
		price += type.Weight * fraction * Config.Home.BarPrices[type.Ore]
	end
	return price / math.max(yield, 1e-12), yield / total
end

-- Seconds from one impact to the next: the event, its end phase, cleanup, then the countdown.
function Pacing.cycleSeconds(): number
	return Config.Meteor.ImpactDuration
		+ Iron.ActiveDuration
		+ math.max(Config.Meteor.CrackedDuration, Config.Meteor.CooledDuration)
		+ Config.Meteor.CleanupDuration
		+ Config.Meteor.Countdown
end

local function bonusesFor(drillbotLevel: number?): Pets.Bonuses
	local saved: Pets.Saved = { owned = {}, equipped = {} }
	if drillbotLevel then
		saved.owned.drillbot = { level = drillbotLevel, xp = 0 }
		table.insert(saved.equipped, "drillbot")
	end
	return Pets.bonuses(saved)
end

-- Ore per second for a pickaxe that yields `orePerHit` (before pets) at `swing` seconds a swing and a
-- backpack of `capacity`. `bonuses` supplies the Yield and Miner pets; Swift is already in `swing`.
local function oreRateOf(orePerHit: number, swing: number, capacity: number, bonuses: Pets.Bonuses): number
	local perHit = Pets.oreYield(orePerHit, bonuses.yield)
	if perHit <= 0 then return 0 end
	-- every fill starts a fresh mining combo (Shared.Combo) after the trip home
	local fillSeconds = Combo.fillHits(capacity, perHit) * swing / Balance.HitsPerMinuteShare
	-- Recent validated hits keep the miner active while filling; trips have no target.
	-- NodeService:PetHit applies Yield to pet ore too, without a backpack detour.
	local petOre = perHit * bonuses.miner / swing * fillSeconds
	return (capacity + petOre) / (fillSeconds + Balance.TripSeconds)
end

local function oreRate(pickaxeTier: number, backpackTier: number, yield: number, bonuses: Pets.Bonuses): number
	local pickaxe = Config.Pickaxes[pickaxeTier]
	return oreRateOf(pickaxe.OrePerHit * yield * Iron.YieldMult, pickaxe.Swing * (1 - bonuses.swift), Config.Backpacks[backpackTier].Capacity, bonuses)
end

-- Ore per second delivered to the hopper, trips included. `yield` scales the ore source.
function Pacing.oreRate(pickaxeTier: number, backpackTier: number, yield: number, drillbotLevel: number?): number
	return oreRate(pickaxeTier, backpackTier, yield, bonusesFor(drillbotLevel))
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
local function averageSupply(owned: Owned, cycle: number, level: number, bonuses: Pets.Bonuses, world: number?): (number, number)
	local meteorPrice, meteorYield = meteorMix(level, world)
	local meteor = oreRate(owned.pickaxe, owned.backpack, meteorYield, bonuses) * Iron.ActiveDuration
	local debris = oreRate(owned.pickaxe, owned.backpack, Config.Debris.YieldFraction, bonuses)
		* Balance.DebrisActivityShare
		* (cycle - Iron.ActiveDuration)
	local price = (meteor * meteorPrice + debris * debrisPrice(world)) / (meteor + debris)
	return (meteor + debris) / cycle, price
end

local function lineRate(owned: Owned): number
	return math.min(Line.station("conveyor", owned.line).Rate :: number, Line.station("refinery", owned.line).Rate :: number)
end

-- Cash per second in the long run
local function income(owned: Owned, cycle: number, level: number, mult: number, bonuses: Pets.Bonuses, world: number?): number
	local supply, price = averageSupply(owned, cycle, level, bonuses, world)
	return math.min(supply, lineRate(owned)) * price * (mult or 1)
end

export type IncomeInput = {
	orePerHit: number, -- ore of one hit on a full-yield node: the pickaxe's, with the 2x Ore pass or an Ore Rush applied
	swing: number, -- seconds between swings, a Swift pet included
	capacity: number, -- backpack capacity as played
	level: number, -- player level, which sets how much of an ore a hit yields
	pets: Pets.Bonuses,
	lineRate: number, -- bars per second the conveyor and refinery can make
	saleMult: number, -- every multiplier on a bar sale (Economy:SaleMultiplier)
	world: number?, -- the world being played (Config.Worlds), 1 by default
}

export type Income = {
	perSecond: number, -- expected cash per second of ordinary play
	bars: number, -- bars per second that actually reach the sale
	mining: number, -- bars per second the player's mining supplies
	line: number,
	limit: string, -- "mining" or "line": what holds the income back
}

-- A player's expected income from what they own right now, not what they earned so far. It is the
-- model's long-run `income` for one real loadout: meteors and debris time-weighted over a full event
-- cycle, capped by the production line, valued at the blended bar price and the sale multiplier.
-- It counts no bonuses (crates, field rocks), no rebirth plans and no time away.
function Pacing.expectedIncome(input: IncomeInput): Income
	local cycle = Pacing.cycleSeconds()
	local meteorPrice, meteorYield = meteorMix(input.level, input.world)
	local base = debrisPrice(input.world)
	local meteor = oreRateOf(input.orePerHit * meteorYield, input.swing, input.capacity, input.pets) * Iron.ActiveDuration
	local debris = oreRateOf(input.orePerHit * Config.Debris.YieldFraction, input.swing, input.capacity, input.pets)
		* Balance.DebrisActivityShare
		* (cycle - Iron.ActiveDuration)
	local ore = meteor + debris
	local mining = ore / cycle
	local price = if ore > 0 then (meteor * meteorPrice + debris * base) / ore else base
	local bars = math.min(mining, input.lineRate)
	return {
		perSecond = bars * price * input.saleMult,
		bars = bars,
		mining = mining,
		line = input.lineRate,
		limit = if mining <= input.lineRate then "mining" else "line",
	}
end

type Candidate = { id: string, name: string, cost: number, shards: number, apply: (Owned) -> () }

-- The next level of every track a player buys from.
local function candidates(owned: Owned, level: number, priceMult: number, rebirths: number): { Candidate }
	local out: { Candidate } = {}
	local pickaxe = Config.Pickaxes[owned.pickaxe + 1]
	if pickaxe and Levels.canEvolve(pickaxe.Tier, level, rebirths) then
		table.insert(out, {
			id = "pickaxe" .. pickaxe.Tier,
			name = pickaxe.Name,
			cost = Gear.bundleCost("pickaxe", pickaxe.Tier, priceMult),
			shards = pickaxe.Shards,
			apply = function(o: Owned)
				o.pickaxe += 1
			end,
		})
	end
	local backpack = Config.Backpacks[owned.backpack + 1]
	if backpack and Levels.canEvolve(backpack.Tier, level, rebirths) then
		table.insert(out, {
			id = "backpack" .. backpack.Tier,
			name = backpack.Name,
			cost = Gear.bundleCost("backpack", backpack.Tier, priceMult),
			shards = backpack.Shards,
			apply = function(o: Owned)
				o.backpack += 1
			end,
		})
	end
	local nextLine = owned.line + 1
	local lineCost = Line.cost(nextLine, priceMult)
	if lineCost and Levels.canEvolve(nextLine, level, rebirths) then
		table.insert(out, {
			id = "line" .. nextLine,
			name = Config.Home.Line.Name .. " level " .. nextLine,
			cost = lineCost,
			shards = 0,
			apply = function(o: Owned)
				o.line += 1
			end,
		})
	end
	return out
end

-- Runs the model for `horizon` seconds (default Balance.Horizon).
function Pacing.simulate(horizon: number?, options: Options?): Result
	local total = horizon or Balance.Horizon
	local maxRebirths = if options and options.rebirths then options.rebirths else 0
	local paybackLimit = if options and options.paybackLimit then options.paybackLimit else math.huge
	local petBonuses = bonusesFor(if options then options.drillbotLevel else nil)
	local rebirths, mult, priceMult = 0, 1, 1
	local world = 1 -- the model player moves to each world as soon as it opens (Shared.Worlds.reached)
	local step = Balance.StepSeconds
	local cycle = Pacing.cycleSeconds()
	local owned: Owned = { pickaxe = 1, backpack = 1, line = 1 }
	local cash, shards, earned = 0, 0, 0
	local hopperOre, hopperValue, bars, barsValue = 0, 0, 0, 0
	local result: Result = {
		purchases = {},
		affordableAt = {},
		earnedAt = {},
		samples = {},
		rebirthTimes = {},
		cycle = cycle,
		firstCycleEnd = Config.Meteor.FirstCountdown + cycle,
		petBonuses = table.clone(petBonuses),
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
			incomePerMinute = income(owned, cycle, levelAfter(meteorsCounted), mult, petBonuses, world) * 60,
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
		local level = levelAfter(meteorsCounted)
		local meteorPrice, meteorYield = meteorMix(level, world)
		local yield = if onMeteor then meteorYield else Config.Debris.YieldFraction * Balance.DebrisActivityShare
		local orePrice = if onMeteor then meteorPrice else debrisPrice(world)
		local hopperRoom = (Line.station("hopper", owned.line).Capacity :: number) - hopperOre
		local mined = math.min(oreRate(owned.pickaxe, owned.backpack, yield, petBonuses) * step, hopperRoom)
		hopperOre += mined
		hopperValue += mined * orePrice

		-- The line: limited by time, hopper stock and room at the collection post
		local room = (Line.station("collector", owned.line).Capacity :: number) - bars
		local made = math.max(math.min(lineRate(owned) * step, hopperOre, room), 0)
		local madeValue = if hopperOre > 0 then hopperValue * made / hopperOre else 0
		hopperOre -= made
		hopperValue -= madeValue
		bars += made
		barsValue += madeValue

		-- A finished meteor pays its shard floor
		local sinceFirst = time - (Config.Meteor.FirstCountdown + Config.Meteor.ImpactDuration + Iron.ActiveDuration)
		if sinceFirst >= 0 then
			local finished = math.floor(sinceFirst / cycle) + 1
			if finished > meteorsCounted then
				shards += (finished - meteorsCounted) * Balance.ShardsPerMeteor
				local levelBefore = levelAfter(meteorsCounted)
				meteorsCounted = finished
				local gained = levelAfter(meteorsCounted) - levelBefore
				if gained > 0 then
					-- the Supply Crates of the levels just gained
					local crate = gained * Hooks.crateExpectedSeconds() * lineRate(owned) * meteorPrice * mult
					cash += crate
					earned += crate
				end
			end
		end

		-- Home: sell, then shop
		if time >= nextSell then
			nextSell += Balance.SellInterval
			cash += barsValue * mult
			earned += barsValue * mult
			bars, barsValue = 0, 0
			for _, tier in Config.Pickaxes do
				local price = Gear.bundleCost("pickaxe", tier.Tier, priceMult)
				if price > 0 and earned >= price and result.earnedAt["pickaxe" .. tier.Tier] == nil then
					result.earnedAt["pickaxe" .. tier.Tier] = time
				end
			end
			for _, tier in Config.Backpacks do
				local price = Gear.bundleCost("backpack", tier.Tier, priceMult)
				if price > 0 and earned >= price and result.earnedAt["backpack" .. tier.Tier] == nil then
					result.earnedAt["backpack" .. tier.Tier] = time
				end
			end
			for _, item in candidates(owned, level, priceMult, rebirths) do
				if cash >= item.cost and shards >= item.shards and result.affordableAt[item.id] == nil then
					result.affordableAt[item.id] = time
				end
			end
			local bought = true
			while bought do
				bought = false
				local best: Candidate? = nil
				local bestPayback = math.huge
				local now = income(owned, cycle, level, mult, petBonuses, world)
				for _, item in candidates(owned, level, priceMult, rebirths) do
					if item.shards > shards then
						continue
					end
					local after = table.clone(owned)
					item.apply(after)
					local gain = income(after, cycle, level, mult, petBonuses, world) - now
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
				mult, priceMult = Rebirth.multiplier(rebirths), Rebirth.priceMult(rebirths)
				world = Worlds.reached(rebirths).Id
				table.insert(result.rebirthTimes, time)
				cash = 0
				-- the pickaxe and backpack keep their tiers (Lib.RebirthReset); the production line starts
				-- over (no Station Memory: the model buys no perks)
				owned.line = 1
				hopperOre, hopperValue, bars, barsValue = 0, 0, 0, 0
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
	local rate = lineRate({ pickaxe = 1, backpack = 1, line = 1 })
	local seconds = if hours then hours * 3600 else Config.Home.OfflineCap
	local bars = math.min(rate * seconds, Line.station("hopper", 1).Capacity :: number, Line.station("collector", 1).Capacity :: number)
	return bars * BarPrice
end

return Pacing
