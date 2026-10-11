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

	t.test("a station level costs its table price times the player's price inflation", function()
		local hopper2 = Config.Home.Stations.hopper.Levels[2].Cost
		t.eq(Price.scaled(hopper2, Rebirth.priceMult(0)), hopper2)
		t.eq(Price.scaled(hopper2, Rebirth.priceMult(2)), hopper2 * 9)
	end)

	t.test("scaled prices stay whole and finite at Legacy ranks", function()
		local cost = Config.Home.Stations.conveyor.Levels[8].Cost
		for _, rebirths in { 0, 5, 16, 17, 30 } do
			local price = Price.scaled(cost, Rebirth.priceMult(rebirths))
			t.eq(price, math.floor(price), "rank " .. rebirths)
			t.ok(price < math.huge, "rank " .. rebirths)
		end
	end)
end
