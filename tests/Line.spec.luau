--!strict
-- Spec for Shared.Line: the production line's single level.
return function(t: any)
	local Line = require(t.shared.Line)
	local Config = require(t.shared.Config)
	local Levels = require(t.shared.Levels)
	local Rebirth = require(t.shared.Rebirth)
	local Home = Config.Home

	t.test("every station has a row for every line level", function()
		t.eq(Line.max(), #Home.Line.Costs)
		for _, id in Home.StationOrder do
			t.eq(#Home.Stations[id].Levels, Line.max(), id)
		end
	end)

	t.test("each line level raises every station", function()
		for level = 2, Line.max() do
			for _, id in Home.StationOrder do
				local before, after = Line.station(id, level - 1), Line.station(id, level)
				local key = if before.Rate then "Rate" else "Capacity"
				t.ok((after :: any)[key] > (before :: any)[key], id .. " at level " .. level)
			end
		end
	end)

	t.test("level 1 is free, the levels after it cost their table price with rebirth inflation", function()
		t.eq(Line.cost(1), nil)
		t.eq(Line.cost(Line.max() + 1), nil)
		t.eq(Line.cost(2), Home.Line.Costs[2])
		t.eq(Line.cost(2, Rebirth.priceMult(2)), Home.Line.Costs[2] * require(t.shared.Config.Rebirth).PriceGrowth ^ 2)
	end)

	t.test("plan buys in a row until the wanted count, the cash, a level gate or the top", function()
		local c2, c3 = Line.cost(2) :: number, Line.cost(3) :: number
		local count, total, stop = Line.plan(1, 1, 1e12, 99)
		t.eq(count, 1); t.eq(total, c2); t.eq(stop, nil)
		count, total, stop = Line.plan(1, 5, c2 + c3, 99)
		t.eq(count, 2); t.eq(total, c2 + c3); t.eq(stop, "cash")
		count, total, stop = Line.plan(1, 99, 1e12, 99)
		t.eq(count, Line.max() - 1); t.eq(stop, "max")
		count, _, stop = Line.plan(Line.max(), 1, 1e12, 99)
		t.eq(count, 0); t.eq(stop, "max")
		-- level 5 needs a player level; a level-1 player stops before it
		t.ok(Levels.evolveLevel(5) > 1, "line level 5 is gated")
		count, _, stop = Line.plan(1, 99, 1e12, 1)
		t.eq(count, 3); t.eq(stop, "level")
	end)

	t.test("clean keeps saved levels legal", function()
		t.eq(Line.clean(3), 3)
		t.eq(Line.clean(3.7), 3)
		t.eq(Line.clean(0), 1)
		t.eq(Line.clean(99), Line.max())
		t.eq(Line.clean(nil), 1)
		t.eq(Line.clean(0 / 0), 1)
	end)

	t.test("old profiles keep the best of their four station levels", function()
		t.eq(Line.fromStations({ hopper = 5, conveyor = 6, refinery = 7, collector = 4 }), 7)
		t.eq(Line.fromStations({ hopper = 2 }), 2)
		t.eq(Line.fromStations(nil), 1)
		t.eq(Line.fromStations({ refinery = 40 }), Line.max())
	end)
end
