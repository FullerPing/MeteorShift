--!strict
-- Spec for Shared.Pacing, the economy pacing model (docs/guide/balance.md). The checkpoints are
-- the targets of the rebased economy: a first session of about 45 minutes ends in the first
-- rebirth, and the rebirths after it keep coming at a steady pace (rebirth cost grows as fast
-- as the multiplier it pays). Dollar amounts are in the game's own numbers.

return function(t: any)
	local Pacing = require(t.shared.Pacing)
	local Combo = require(t.shared.Combo)
	local Config = require(t.shared.Config)

	local result = Pacing.simulate(4 * 3600)
	local at30 = Pacing.sampleAt(result, 30 * 60)
	local at35 = Pacing.sampleAt(result, 35 * 60)

	t.test("the model is deterministic and reports a cycle of about five minutes", function()
		local again = Pacing.simulate(4 * 3600)
		t.eq(#again.purchases, #result.purchases)
		t.eq(again.samples[#again.samples].earned, result.samples[#result.samples].earned)
		t.ok(result.cycle > 4 * 60 and result.cycle < 6 * 60, "cycle " .. result.cycle)
	end)

	-- A fresh player's loadout, the way Economy:ExpectedIncome reads it from a profile
	local function fresh(overrides: any?): any
		local Pets = require(t.shared.Pets)
		local stations = Config.Home.Stations
		local input: any = {
			orePerHit = Config.Pickaxes[1].OrePerHit,
			swing = Config.Pickaxes[1].Swing,
			capacity = Config.Backpacks[1].Capacity,
			level = 1,
			pets = Pets.bonuses(Pets.fresh()),
			lineRate = math.min(stations.conveyor.Levels[1].Rate :: number, stations.refinery.Levels[1].Rate :: number),
			saleMult = 1,
		}
		for key, value in overrides or {} do
			input[key] = value
		end
		return input
	end

	t.test("expected income of a fresh loadout is the model's own income at the start", function()
		local income = Pacing.expectedIncome(fresh())
		t.ok(income.perSecond > 0, "positive")
		t.near(income.perSecond * 60, result.samples[1].incomePerMinute, 1e-6)
	end)

	t.test("expected income scales with the sale multiplier and with a bigger loadout", function()
		local base = Pacing.expectedIncome(fresh()).perSecond
		t.near(Pacing.expectedIncome(fresh({ saleMult = 2.5 })).perSecond, base * 2.5, 1e-9)
		-- with a line wide enough that mining is the limit, more mining means more income
		local open = Pacing.expectedIncome(fresh({ lineRate = 1e6 })).perSecond
		t.ok(Pacing.expectedIncome(fresh({ lineRate = 1e6, capacity = Config.Backpacks[1].Capacity * 4 })).perSecond > open, "a bigger backpack")
		t.ok(Pacing.expectedIncome(fresh({ lineRate = 1e6, swing = Config.Pickaxes[1].Swing / 2 })).perSecond > open, "a faster swing")
		t.ok(Pacing.expectedIncome(fresh({ lineRate = 1e6, orePerHit = Config.Pickaxes[1].OrePerHit * 3 })).perSecond > open, "more ore per hit")
	end)

	t.test("expected income is held back by the slower of mining and the line", function()
		local slowLine = Pacing.expectedIncome(fresh({ lineRate = 0.001 }))
		t.eq(slowLine.limit, "line")
		t.near(slowLine.bars, 0.001, 1e-12)
		local fastLine = Pacing.expectedIncome(fresh({ lineRate = 1e6 }))
		t.eq(fastLine.limit, "mining")
		t.near(fastLine.bars, fastLine.mining, 1e-12)
		t.ok(fastLine.perSecond > slowLine.perSecond, "a wider line earns more")
		t.eq(Pacing.expectedIncome(fresh({ orePerHit = 0 })).perSecond, 0, "no ore, no income")
	end)

	t.test("lifetime sales reach the Steel price within one cycle of the first meteor cycle ending", function()
		local steel = result.earnedAt.pickaxe2
		t.ok(steel ~= nil, "Steel never in reach")
		t.ok(steel >= Config.Meteor.FirstCountdown, "before the first meteor: " .. tostring(steel))
		t.ok(steel <= result.firstCycleEnd + result.cycle, "later than one cycle after the first: " .. tostring(steel))
	end)

	-- Owner, 2026-10-19: the first meteor cycle used to hand a new player the Drill Pick outright
	t.test("the Drill Pick is bought 8 to 10 minutes in, after the first meteor cycle", function()
		local drill = nil
		for _, purchase in result.purchases do
			if purchase.id == "pickaxe3" then
				drill = purchase.time
				break
			end
		end
		t.ok(drill ~= nil, "Drill Pick never bought")
		t.ok((drill :: number) >= result.firstCycleEnd, "before the first cycle ended: " .. tostring(drill))
		t.ok((drill :: number) >= 8 * 60 and (drill :: number) <= 10 * 60, "Drill Pick at " .. tostring(drill) .. " s")
	end)

	t.test("by 15 minutes the player owns Steel and the Drill Pick, so Ice meteors pay", function()
		local at15 = Pacing.sampleAt(result, 15 * 60)
		t.ok(at15.owned.pickaxe >= 3, "pickaxe tier " .. at15.owned.pickaxe)
	end)

	t.test("by 30 minutes the Meteorite Pick is owned, so Crystal meteors pay", function()
		t.ok(at30.owned.pickaxe >= 5, "pickaxe tier " .. at30.owned.pickaxe)
	end)

	t.test("the first rebirth lands between 10 and 20 minutes in", function()
		local run = Pacing.simulate(2 * 3600, { rebirths = 1 })
		local first = run.rebirthTimes[1]
		t.ok(first ~= nil, "no rebirth in two hours")
		t.ok(first >= 10 * 60 and first <= 20 * 60, "first rebirth at " .. tostring(first and first / 60) .. " min")
	end)

	-- Owner, 2026-10-22: faster laps. The first pays for the gear ramp; from the second they lengthen to the fourth. After
	-- that a lap that buys a newly opened gear tier runs long and the one after it short, about 14 minutes on average
	t.test("laps lengthen from the second rebirth to the fourth, then average about 14 minutes", function()
		local run = Pacing.simulate(8 * 3600, { rebirths = 24 })
		t.ok(#run.rebirthTimes >= 24, "only " .. #run.rebirthTimes .. " rebirths in eight hours")
		local lap, previous = {}, 0
		for index = 1, 24 do
			lap[index] = run.rebirthTimes[index] - previous
			previous = run.rebirthTimes[index]
		end
		t.ok(lap[2] < lap[3] and lap[3] < lap[4], "laps two to four get longer")
		local sum = 0
		for index = 5, 24 do
			sum += lap[index]
			t.ok(lap[index] >= 8 * 60 and lap[index] <= 22 * 60, "lap " .. index .. " took " .. math.floor(lap[index] / 60) .. " min")
		end
		local average = sum / 20 / 60
		t.ok(average >= 12 and average <= 16, string.format("laps 5 to 24 average %.1f min", average))
	end)

	t.test("every gear tier is bought within a lap of the rank that opens it", function()
		local Levels = require(t.shared.Levels)
		local run = Pacing.simulate(8 * 3600, { rebirths = 24 })
		for _, kind in { "pickaxe", "backpack" } do
			for tier = 7, #Config.Pickaxes do
				local opens = run.rebirthTimes[Levels.evolveRebirths(tier)]
				local bought
				for _, purchase in run.purchases do
					if purchase.id == kind .. tier then bought = purchase.time; break end
				end
				t.ok(bought ~= nil, kind .. " " .. tier .. " never bought")
				t.ok((bought :: number) - opens <= 22 * 60, kind .. " " .. tier .. " bought " .. math.floor(((bought :: number) - opens) / 60) .. " min after it opened")
			end
		end
	end)

	t.test("rebirths keep a steady pace: each comes within 22 minutes of the one before", function()
		local run = Pacing.simulate(4 * 3600, { rebirths = 5 })
		t.ok(#run.rebirthTimes >= 5, "only " .. #run.rebirthTimes .. " rebirths in four hours")
		for index = 2, 5 do
			local gap = run.rebirthTimes[index] - run.rebirthTimes[index - 1]
			t.ok(gap <= 22 * 60, "rebirth " .. index .. " took " .. math.floor(gap / 60) .. " min")
		end
	end)

	t.test("each rebirth makes the model's cash prices dearer by Rebirth.priceMult", function()
		local Rebirth = require(t.shared.Rebirth)
		local Price = require(t.shared.Price)
		local run = Pacing.simulate(4 * 3600, { rebirths = 3 })
		t.ok(#run.rebirthTimes >= 3, "only " .. #run.rebirthTimes .. " rebirths in four hours")
		local base = Config.Home.Line.Costs[2]
		local first, afterThird
		for _, purchase in run.purchases do
			if purchase.id == "line2" then
				first = first or purchase
				if purchase.time > run.rebirthTimes[3] then
					afterThird = afterThird or purchase
				end
			end
		end
		t.ok(first ~= nil and afterThird ~= nil, "line level 2 is bought before and after the third rebirth")
		t.eq((first :: any).cost, base)
		t.eq((afterThird :: any).cost, Price.scaled(base, Rebirth.priceMult(3)))
	end)

	t.test("gear tiers survive a rebirth in the model, so a lap starts with the pickaxe it ended with", function()
		local run = Pacing.simulate(3 * 3600, { rebirths = 2 })
		t.ok(#run.rebirthTimes >= 2, "needs two rebirths")
		local before = Pacing.sampleAt(run, run.rebirthTimes[1] - 1)
		local after = Pacing.sampleAt(run, run.rebirthTimes[1] + 60)
		t.ok(after.owned.pickaxe >= before.owned.pickaxe, "pickaxe tier " .. before.owned.pickaxe .. " fell to " .. after.owned.pickaxe)
		t.ok(after.owned.backpack >= before.owned.backpack, "backpack tier fell")
	end)

	t.test("once the Drill Pick unlocks Ice meteors, the Plasma Pick is affordable within 3 hours", function()
		local plasma = result.earnedAt.pickaxe4
		t.ok(plasma ~= nil and plasma <= 3 * 3600, "Plasma in reach at " .. tostring(plasma))
		local bought
		for _, purchase in result.purchases do
			if purchase.id == "pickaxe4" then
				bought = purchase.time
			end
		end
		t.ok(bought ~= nil and bought <= 3 * 3600, "Plasma bought at " .. tostring(bought))
	end)

	t.test("by 30 minutes the backpack is tier 3 or better", function()
		t.ok(at30.owned.backpack >= 3, "backpack tier " .. at30.owned.backpack)
	end)

	t.test("by 30 minutes a production line upgrade is bought", function()
		t.ok(at30.owned.line >= 2, "line level " .. at30.owned.line)
	end)

	t.test("sales cover the gear owned (no free lunch), and millions come within the hour", function()
		t.ok(at30.earned >= 100e3, "earned by 30 min: " .. at30.earned)
		local at60 = Pacing.sampleAt(result, 60 * 60)
		t.ok(at60.earned >= 1e6, "earned by 60 min: " .. at60.earned)
	end)

	t.test("nothing is bought before it can be paid for", function()
		for _, purchase in result.purchases do
			t.ok(purchase.cashAfter >= 0, purchase.id .. " overspent")
		end
	end)

	t.test("a level 1 line's 2-hour offline cap is worth about $90K at most", function()
		local cap = Pacing.offlineCap()
		t.ok(cap > 80e3 and cap <= 95e3, "offline cap " .. cap)
	end)

	t.test("a longer session never earns less than a shorter one", function()
		local short = Pacing.sampleAt(result, 3600).earned
		local long = Pacing.sampleAt(result, 7200).earned
		t.ok(long > short)
	end)

	t.test("the optional fixed-level Drillbot reports its three exact level 5 perks", function()
		local run = Pacing.simulate(0, { drillbotLevel = 5 })
		t.near(run.petBonuses.miner, 0.25 + 0.15 * 4 / 9, 1e-12)
		t.near(run.petBonuses.swift, 0.08 + 0.12 * 4 / 9, 1e-12)
		t.near(run.petBonuses.yield, 0.10 + 0.10 * 4 / 9, 1e-12)
		for _, role in { "hauler", "pack", "merchant", "sprint", "vault", "crit", "scholar", "shards" } do
			t.eq(run.petBonuses[role], 0, "Drillbot does not invent a " .. role .. " perk")
		end
	end)

	t.test("Drillbot ore includes Swift, Yield and direct-hopper Miner during the fill portion", function()
		local pickaxe, backpack = Config.Pickaxes[3], Config.Backpacks[2]
		local swift = 0.08 + 0.12 * 4 / 9
		local yield = 0.10 + 0.10 * 4 / 9
		local miner = 0.25 + 0.15 * 4 / 9
		for _, quantity in { 1, Config.Debris.YieldFraction } do
			local perHit = pickaxe.OrePerHit * quantity * Config.Meteor.Types.Iron.YieldMult * (1 + yield)
			-- each fill climbs a fresh mining combo (Shared.Combo)
			local hits = Combo.fillHits(backpack.Capacity, perHit)
			local fillSeconds = hits * pickaxe.Swing * (1 - swift) / Config.Balance.HitsPerMinuteShare
			-- During filling, each owner's landed hit corresponds to 1 / hit-share miner swings.
			local petOre = perHit * miner * hits / Config.Balance.HitsPerMinuteShare
			local expected = (backpack.Capacity + petOre) / (fillSeconds + Config.Balance.TripSeconds)
			t.near(Pacing.oreRate(3, 2, quantity, 5), expected, 1e-10)
			t.ok(Pacing.oreRate(3, 2, quantity, 5) > Pacing.oreRate(3, 2, quantity), "all three perks improve supply")
		end
	end)

	t.test("an inactive owner supplies no player or pet ore", function()
		t.eq(Pacing.oreRate(1, 1, 0, 5), 0)
		t.eq(Pacing.oreRate(1, 1, 0), 0)
	end)

	t.test("the optional Drillbot changes first-rebirth time deterministically while the default stays pet-free", function()
		local free = Pacing.simulate(2 * 3600, { rebirths = 1 })
		local paid = Pacing.simulate(2 * 3600, { rebirths = 1, drillbotLevel = 5 })
		local again = Pacing.simulate(2 * 3600, { rebirths = 1, drillbotLevel = 5 })
		t.ok(free.rebirthTimes[1] and paid.rebirthTimes[1], "both players reach their first rebirth")
		-- The inherited greedy policy seeks income payback, not minimum rebirth time.
		t.ok(paid.rebirthTimes[1] ~= free.rebirthTimes[1], "the pet treatment reaches the rebirth simulation")
		t.eq(again.rebirthTimes[1], paid.rebirthTimes[1], "pet run is deterministic")
		t.eq(again.samples[#again.samples].earned, paid.samples[#paid.samples].earned)
		for _, role in Config.Pets.RoleOrder do t.eq(free.petBonuses[role], 0, "default run has no pets") end
	end)

	t.test("shard income buys a Meteor Egg about every 5 minutes, a Crystal every 20, an Aurora every 45", function()
		local perMinute = Config.Balance.ShardsPerMeteor / Pacing.cycleSeconds() * 60
		local targets = { meteorEgg = { 4, 6 }, crystalEgg = { 17, 23 }, auroraEgg = { 40, 50 } }
		for _, egg in Config.Pets.Eggs do
			local band = targets[egg.Id]
			if band then
				local minutes = egg.Cost / perMinute
				t.ok(minutes >= band[1] and minutes <= band[2], string.format("%s every %.1f min", egg.Id, minutes))
			end
		end
	end)
end
