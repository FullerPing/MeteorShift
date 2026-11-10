--!strict
-- Spec for Shared.Price's price inflation: the server charges and the client shows the same rounded cash.
return function(t: any)
	local Price = require(t.shared.Price)
	local Rebirth = require(t.shared.Rebirth)
	local Config = require(t.shared.Config)

	t.test("scaled multiplies a cash price and rounds to whole cash", function()
		t.eq(Price.scaled(2000, 1), 2000)
		t.eq(Price.scaled(2000, 3), 6000)
		t.eq(Price.scaled(0.5, 3), 2)
		t.eq(Price.scaled(0, 9), 0)
	end)

	t.test("a line level costs its table price times the player's price inflation", function()
		local line2 = Config.Home.Line.Costs[2]
		t.eq(Price.scaled(line2, Rebirth.priceMult(0)), line2)
		t.eq(Price.scaled(line2, Rebirth.priceMult(2)), line2 * require(t.shared.Config.Rebirth).PriceGrowth ^ 2)
	end)

	t.test("scaled prices stay whole and finite at Legacy ranks", function()
		local cost = Config.Home.Line.Costs[8]
		for _, rebirths in { 0, 5, 16, 17, 30 } do
			local price = Price.scaled(cost, Rebirth.priceMult(rebirths))
			t.eq(price, math.floor(price), "rank " .. rebirths)
			t.ok(price < math.huge, "rank " .. rebirths)
		end
	end)
end
