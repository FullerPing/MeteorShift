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

	t.test("the model is deterministic and reports a cycle of about seven minutes", function()
		local again = Pacing.simulate(4 * 3600)
		t.eq(#again.purchases, #result.purchases)
		t.eq(again.samples[#again.samples].earned, result.samples[#result.samples].earned)
		t.ok(result.cycle > 6 * 60 and result.cycle < 8 * 60, "cycle " .. result.cycle)
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

	t.test("the first rebirth lands between 40 and 60 minutes in", function()
		local run = Pacing.simulate(2 * 3600, { rebirths = 1 })
		local first = run.rebirthTimes[1]
		t.ok(first ~= nil, "no rebirth in two hours")
		t.ok(first >= 40 * 60 and first <= 60 * 60, "first rebirth at " .. tostring(first and first / 60) .. " min")
	end)

	t.test("rebirths keep a steady pace: each comes within 45 minutes of the one before", function()
		local run = Pacing.simulate(4 * 3600, { rebirths = 5 })
		t.ok(#run.rebirthTimes >= 5, "only " .. #run.rebirthTimes .. " rebirths in four hours")
		for index = 2, 5 do
			local gap = run.rebirthTimes[index] - run.rebirthTimes[index - 1]
			t.ok(gap <= 45 * 60, "rebirth " .. index .. " took " .. math.floor(gap / 60) .. " min")
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
		t.ok(at60.earned >= 2e6, "earned by 60 min: " .. at60.earned)
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
end
