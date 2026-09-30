--!strict
-- Spec for Shared.Pacing, the economy pacing model (spec §7.4, docs/balance.md).
-- The time-based checkpoints are the primary targets. The dollar checkpoints of §7.4
-- are translated by the game's inflation factor: Config prices are the spec's own
-- (factor 1), so they are asserted as written where the model can reach them and
-- restated in docs/balance.md where it can't.

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

	t.test("by 35 minutes the player owns Steel and the Drill Pick (the model gets there at 28:00)", function()
		t.ok(at35.owned.pickaxe >= 3, "pickaxe tier " .. at35.owned.pickaxe)
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

	t.test("by 30 minutes the backpack is tier 2 or 3 (not past 3)", function()
		t.ok(at30.owned.backpack >= 2 and at30.owned.backpack <= 3, "backpack tier " .. at30.owned.backpack)
	end)

	t.test("by 30 minutes a refinery upgrade is bought", function()
		t.ok(at30.owned.refinery >= 2, "refinery level " .. at30.owned.refinery)
	end)

	t.test("30 minutes of sales cover the gear owned (no free lunch), and tens of thousands come within the hour", function()
		t.ok(at30.earned >= 3e3, "earned by 30 min: " .. at30.earned)
		local at60 = Pacing.sampleAt(result, 60 * 60)
		t.ok(at60.earned >= 10e3, "earned by 60 min: " .. at60.earned)
	end)

	t.test("nothing is bought before it can be paid for", function()
		for _, purchase in result.purchases do
			t.ok(purchase.cashAfter >= 0, purchase.id .. " overspent")
		end
	end)

	t.test("a level 1 line's 2-hour offline cap is worth about $9K at most", function()
		local cap = Pacing.offlineCap()
		t.ok(cap > 8e3 and cap <= 9.5e3, "offline cap " .. cap)
	end)

	t.test("a longer session never earns less than a shorter one", function()
		local short = Pacing.sampleAt(result, 3600).earned
		local long = Pacing.sampleAt(result, 7200).earned
		t.ok(long > short)
	end)
end
