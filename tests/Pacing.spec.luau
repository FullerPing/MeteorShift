--!strict
-- Spec for Shared.Pacing, the economy pacing model (docs/balance.md). The checkpoints are
-- the targets of the rebased economy: a first session of about 45 minutes ends in the first
-- rebirth, and the rebirths after it keep coming at a steady pace (rebirth cost grows as fast
-- as the multiplier it pays). Dollar amounts are in the game's own numbers.

return function(t: any)
	local Pacing = require(t.shared.Pacing)
	local Config = require(t.shared.Config)

	local result = Pacing.simulate(4 * 3600)
	local at30 = Pacing.sampleAt(result, 30 * 60)
	local at35 = Pacing.sampleAt(result, 35 * 60)

	t.test("the model is deterministic and reports a cycle of about six minutes", function()
		local again = Pacing.simulate(4 * 3600)
		t.eq(#again.purchases, #result.purchases)
		t.eq(again.samples[#again.samples].earned, result.samples[#result.samples].earned)
		t.ok(result.cycle > 5 * 60 and result.cycle < 7 * 60, "cycle " .. result.cycle)
	end)

	t.test("lifetime sales reach the Steel price within one cycle of the first meteor cycle ending", function()
		local steel = result.earnedAt.pickaxe2
		t.ok(steel ~= nil, "Steel never in reach")
		t.ok(steel >= Config.Meteor.FirstCountdown, "before the first meteor: " .. tostring(steel))
		t.ok(steel <= result.firstCycleEnd + result.cycle, "later than one cycle after the first: " .. tostring(steel))
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

	t.test("laps lengthen from the first rebirth to the fourth, then stay level", function()
		local run = Pacing.simulate(6 * 3600, { rebirths = 8 })
		t.ok(#run.rebirthTimes >= 8, "only " .. #run.rebirthTimes .. " rebirths in six hours")
		local lap, previous = {}, 0
		for index = 1, 8 do
			lap[index] = run.rebirthTimes[index] - previous
			previous = run.rebirthTimes[index]
		end
		t.ok(lap[1] < lap[2] and lap[2] < lap[3] and lap[3] < lap[4], "the first four laps get longer")
		for index = 5, 8 do
			t.ok(lap[index] >= 18 * 60 and lap[index] <= 32 * 60, "lap " .. index .. " took " .. math.floor(lap[index] / 60) .. " min")
		end
	end)

	t.test("rebirths keep a steady pace: each comes within 30 minutes of the one before", function()
		local run = Pacing.simulate(4 * 3600, { rebirths = 5 })
		t.ok(#run.rebirthTimes >= 5, "only " .. #run.rebirthTimes .. " rebirths in four hours")
		for index = 2, 5 do
			local gap = run.rebirthTimes[index] - run.rebirthTimes[index - 1]
			t.ok(gap <= 30 * 60, "rebirth " .. index .. " took " .. math.floor(gap / 60) .. " min")
		end
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

	t.test("by 30 minutes a refinery upgrade is bought", function()
		t.ok(at30.owned.refinery >= 2, "refinery level " .. at30.owned.refinery)
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
			local fillSeconds = backpack.Capacity / perHit * pickaxe.Swing * (1 - swift) / Config.Balance.HitsPerMinuteShare
			local playerRate = backpack.Capacity / (fillSeconds + Config.Balance.TripSeconds)
			-- During filling, each owner's landed hit corresponds to 1 / hit-share miner swings.
			local expected = playerRate * (1 + miner / Config.Balance.HitsPerMinuteShare)
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
end
