--!strict
-- Spec for Shared.Rebirth (spec §8.3): what the next rebirth costs and the cash
-- multiplier a number of rebirths gives. Values are read from Config.Rebirth so a
-- retune doesn't break these cases; the shape (×CostGrowth per rebirth,
-- ×CashMult per rebirth, multiplicative) is what is checked.

return function(t: any)
	local Rebirth = require(t.shared.Rebirth)
	local Config = require(t.shared.Config.Rebirth)

	t.test("the first rebirth costs the first listed cost", function()
		t.eq(Rebirth.cost(0), Config.Costs[1])
	end)

	t.test("listed costs rise every rank and are whole cash amounts", function()
		for rebirths = 0, #Config.Costs - 1 do
			local cost = Rebirth.cost(rebirths)
			t.eq(cost, math.floor(cost), "rebirth " .. rebirths)
			if rebirths > 0 then t.ok(cost > Rebirth.cost(rebirths - 1), "rebirth " .. rebirths) end
		end
	end)

	t.test("past the list, Legacy ranks step up by FirstStep, then multiply the cost by Legacy.CostGrowth", function()
		local last = #Config.Costs
		t.near(Rebirth.cost(last), Config.Costs[last] * Config.Legacy.FirstStep, 1e-3)
		t.near(Rebirth.cost(last + 1) / Rebirth.cost(last), Config.Legacy.CostGrowth, 1e-9)
		t.near(Rebirth.cost(last + 3) / Rebirth.cost(last + 2), Config.Legacy.CostGrowth, 1e-9)
	end)

	t.test("no rebirths leaves cash at x1", function()
		t.eq(Rebirth.multiplier(0), 1)
	end)

	t.test("every listed rebirth multiplies the cash multiplier by CashMult", function()
		t.eq(Rebirth.multiplier(1), Config.CashMult)
		t.eq(Rebirth.multiplier(3), Config.CashMult ^ 3)
		t.eq(Rebirth.multiplier(6) / Rebirth.multiplier(5), Config.CashMult)
	end)

	t.test("Legacy ranks multiply by MultGrowth instead", function()
		local last = #Config.Costs
		t.near(Rebirth.multiplier(last + 1) / Rebirth.multiplier(last), Config.Legacy.MultGrowth, 1e-9)
		t.near(Rebirth.multiplier(last + 4) / Rebirth.multiplier(last + 3), Config.Legacy.MultGrowth, 1e-9)
	end)

	t.test("a missing or negative count reads as no rebirths", function()
		t.eq(Rebirth.multiplier(nil), 1)
		t.eq(Rebirth.cost(nil), Config.Costs[1])
		t.eq(Rebirth.multiplier(-2), 1)
	end)

	t.test("no rebirths leaves prices at x1 and every listed rebirth multiplies them by PriceGrowth", function()
		t.eq(Rebirth.priceMult(0), 1)
		t.eq(Rebirth.priceMult(1), Config.PriceGrowth)
		t.eq(Rebirth.priceMult(#Config.Costs), Config.PriceGrowth ^ #Config.Costs)
		t.eq(Rebirth.priceMult(6) / Rebirth.priceMult(5), Config.PriceGrowth)
	end)

	t.test("Legacy ranks multiply prices by Legacy.PriceGrowth, stay finite and keep rising", function()
		local last = #Config.Costs
		t.near(Rebirth.priceMult(last + 1) / Rebirth.priceMult(last), Config.Legacy.PriceGrowth, 1e-9)
		t.near(Rebirth.priceMult(last + 4) / Rebirth.priceMult(last + 3), Config.Legacy.PriceGrowth, 1e-9)
		local before = 0
		for rebirths = 0, 40 do
			local mult = Rebirth.priceMult(rebirths)
			t.ok(mult > before, "rank " .. rebirths)
			before = mult
		end
		t.ok(Rebirth.priceMult(200) < math.huge, "rank 200 is finite")
	end)

	t.test("prices lag the cash multiplier by the same ratio at every rank", function()
		local last = #Config.Costs
		for _, rebirths in { 1, 5, last, last + 1, last + 6 } do
			local ratio = Rebirth.multiplier(rebirths) / Rebirth.priceMult(rebirths)
			local expected = (Config.CashMult / Config.PriceGrowth) ^ math.min(rebirths, last)
			if rebirths > last then
				expected *= (Config.Legacy.MultGrowth / Config.Legacy.PriceGrowth) ^ (rebirths - last)
			end
			t.near(ratio / expected, 1, 1e-9, "rank " .. rebirths)
		end
	end)

	t.test("a missing or negative count leaves prices at x1", function()
		t.eq(Rebirth.priceMult(nil), 1)
		t.eq(Rebirth.priceMult(-3), 1)
	end)

	t.test("overstay shards grow with the cash earned beyond the cost, up to the cap", function()
		local cost = 1000
		t.eq(Rebirth.overstayShards(0, cost), 0)
		t.eq(Rebirth.overstayShards(-5, cost), 0)
		t.eq(Rebirth.overstayShards(cost, cost), Config.Overstay.PerDoubling)
		t.ok(Rebirth.overstayShards(3 * cost, cost) > Rebirth.overstayShards(cost, cost))
		t.eq(Rebirth.overstayShards(1e12 * cost, cost), Config.Overstay.Cap)
		t.eq(Rebirth.overstayShards(0 / 0, cost), 0)
	end)

	t.test("early ranks announce what they unlock", function()
		t.ok(Rebirth.unlock(1) ~= nil)
		t.eq(Rebirth.unlock(99), nil)
	end)
end
