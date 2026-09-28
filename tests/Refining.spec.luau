--!strict
-- Spec for Server.Lib.Refining, the pure production-line simulation shared by
-- the online tick and offline catch-up. All cases use level-1 stations
-- (hopper/collector capacity 2000, conveyor rate 0.3 ore/s, refinery rate
-- 0.25 ore/s) from Config.Home.Stations as they stand today.

return function(t: any)
	local Refining = require(t.lib.Refining)

	local function freshData(hopper: { [string]: number }, bin: { [string]: number })
		return {
			stations = { hopper = 1, conveyor = 1, refinery = 1, collector = 1 },
			hopper = hopper,
			bin = bin,
			progress = 0,
		}
	end

	t.test("rate-limited by the slower station (refinery, not conveyor)", function()
		local data = freshData({ iron = 1000 }, {})
		local made, n, blocked = Refining.run(data, 40)
		-- lineRate = min(conveyor 0.3, refinery 0.25) = 0.25/s * 40s = 10
		t.eq(n, 10)
		t.eq(made.iron, 10)
		t.eq(blocked, nil)
	end)

	t.test("limited by hopper stock", function()
		local data = freshData({ iron = 3 }, {})
		local made, n, blocked = Refining.run(data, 1000)
		t.eq(n, 3)
		t.eq(made.iron, 3)
		t.eq(blocked, "hopper")
	end)

	t.test("stops when the collection post is full", function()
		local data = freshData({ iron = 1000 }, { iron = 1995 })
		local made, n, blocked = Refining.run(data, 40)
		-- room = 2000 - 1995 = 5, less than the 10 the line could otherwise make
		t.eq(n, 5)
		t.eq(made.iron, 5)
		t.eq(blocked, "collector")
		t.eq(data.bin.iron, 2000)
	end)
end
