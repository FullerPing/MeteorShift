--!strict
-- Spec for Shared.Rebirth (spec §8.3): what the next rebirth costs and the cash
-- multiplier a number of rebirths gives. Values are read from Config.Rebirth so a
-- retune doesn't break these cases; the shape (×CostGrowth per rebirth,
-- ×CashMult per rebirth, multiplicative) is what is checked.

return function(t: any)
	local Rebirth = require(t.shared.Rebirth)
	local Config = require(t.shared.Config.Rebirth)

	t.test("the first rebirth costs the base cost", function()
		t.eq(Rebirth.cost(0), Config.BaseCost)
	end)

	t.test("each later rebirth costs CostGrowth times the one before", function()
		t.eq(Rebirth.cost(1), Config.BaseCost * Config.CostGrowth)
		t.eq(Rebirth.cost(2), Config.BaseCost * Config.CostGrowth ^ 2)
		t.eq(Rebirth.cost(5) / Rebirth.cost(4), Config.CostGrowth)
	end)

	t.test("costs are whole cash amounts", function()
		for rebirths = 0, 8 do
			local cost = Rebirth.cost(rebirths)
			t.eq(cost, math.floor(cost), "rebirth " .. rebirths)
		end
	end)

	t.test("no rebirths leaves cash at x1", function()
		t.eq(Rebirth.multiplier(0), 1)
	end)

	t.test("every rebirth multiplies the cash multiplier by CashMult", function()
		t.eq(Rebirth.multiplier(1), Config.CashMult)
		t.eq(Rebirth.multiplier(3), Config.CashMult ^ 3)
		t.eq(Rebirth.multiplier(6) / Rebirth.multiplier(5), Config.CashMult)
	end)

	t.test("a missing or negative count reads as no rebirths", function()
		t.eq(Rebirth.multiplier(nil), 1)
		t.eq(Rebirth.cost(nil), Config.BaseCost)
		t.eq(Rebirth.multiplier(-2), 1)
	end)
end
