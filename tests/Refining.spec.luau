--!strict
-- Spec for Server.Lib.Refining, the pure production-line simulation shared by
-- the online tick and offline catch-up. All cases use level-1 stations
-- (hopper/collector capacity 2000, conveyor rate 0.3 ore/s, refinery rate
-- 0.25 ore/s) from Config.Home.Stations as they stand today.

return function(t: any)
	local Refining = require(t.lib.Refining)

	local function freshData(hopper: { [string]: number }, bin: { [string]: number })
		return {
			line = 1,
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

	t.test("a speed multiplier (Refinery Overclock) doubles the whole line, conveyor included", function()
		local data = freshData({ iron = 1000 }, {})
		local _, n = Refining.run(data, 40, 2)
		-- min(conveyor 0.3, refinery 0.25) * 2 = 0.5/s * 40 = 20 (was 12: only the refinery sped up)
		t.eq(n, 20)
		t.eq(Refining.refineryRate(data, 2), Refining.refineryRate(data) * 2)
		t.eq(Refining.lineRate(data, 2), Refining.lineRate(data) * 2)
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

	t.test("saved refinery priority selects the preferred waiting ore", function()
		local data: any = freshData({ iron = 6, frost = 4, crystal = 3 }, {})
		data.refinePriority = { "crystal", "frost", "iron" }
		local made, n, blocked = Refining.run(data, 12)
		t.eq(n, 3)
		t.eq(made.crystal, 3)
		t.eq(made.iron, nil)
		t.eq(made.frost, nil)
		t.eq(blocked, nil)
		t.eq(data.hopper.crystal, nil)
		t.eq(data.hopper.iron, 6)
		t.eq(data.hopper.frost, 4)
		t.eq(data.refinePriority[1], "crystal")
	end)

	t.test("depleted priorities fall through while conserving every ore and bar", function()
		local data: any = freshData({ iron = 6, frost = 4, crystal = 3 }, { frost = 2 })
		data.refinePriority = { "crystal", "frost", "iron" }
		local made, n, blocked = Refining.run(data, 40)
		t.eq(n, 10)
		t.eq(made.crystal, 3)
		t.eq(made.frost, 4)
		t.eq(made.iron, 3)
		t.eq(data.hopper.iron, 3)
		t.eq(data.hopper.frost, nil)
		t.eq(data.hopper.crystal, nil)
		t.eq(data.bin.crystal, 3)
		t.eq(data.bin.frost, 6)
		t.eq(data.bin.iron, 3)
		t.eq(blocked, nil)
	end)

	t.test("collector room limits priority output without consuming other ores", function()
		local data: any = freshData({ iron = 6, crystal = 3 }, { iron = 1998 })
		data.refinePriority = { "crystal" }
		local made, n, blocked = Refining.run(data, 40)
		t.eq(n, 2)
		t.eq(made.crystal, 2)
		t.eq(made.iron, nil)
		t.eq(data.hopper.crystal, 1)
		t.eq(data.hopper.iron, 6)
		t.eq(data.bin.iron, 1998)
		t.eq(data.bin.crystal, 2)
		t.eq(data.progress, 0)
		t.eq(blocked, "collector")
	end)

	t.test("online ticks and offline catch-up obey the same saved preference", function()
		local online: any = freshData({ iron = 6, frost = 4, crystal = 3 }, {})
		local offline: any = freshData({ iron = 6, frost = 4, crystal = 3 }, {})
		online.refinePriority = { "crystal", "frost", "iron" }
		offline.refinePriority = { "crystal", "frost", "iron" }
		for _ = 1, 4 do Refining.run(online, 10) end
		Refining.run(offline, 40)
		for _, data in { online, offline } do
			t.eq(data.bin.crystal, 3)
			t.eq(data.bin.frost, 4)
			t.eq(data.bin.iron, 3)
			t.eq(data.hopper.iron, 3)
			t.eq(data.hopper.frost, nil)
			t.eq(data.hopper.crystal, nil)
			t.eq(data.progress, 0)
		end
	end)

	t.test("malformed saved preferences safely normalize before production", function()
		local data: any = freshData({ iron = 6, frost = 4, crystal = 3 }, {})
		data.refinePriority = { "frost", "frost", 9, "unknown" }
		local made, n = Refining.run(data, 12)
		t.eq(n, 3)
		t.eq(made.frost, 3)
		t.eq(made.iron, nil)
		t.eq(data.hopper.frost, 1)
		t.eq(#data.refinePriority, 4)
	end)

	t.test("unconfigured future ore stock refines in deterministic fallback order", function()
		local data = freshData({ zeta = 3, amber = 2 }, {})
		local made, n = Refining.run(data, 12)
		t.eq(n, 3)
		t.eq(made.amber, 2)
		t.eq(made.zeta, 1)
		t.eq(data.hopper.amber, nil)
		t.eq(data.hopper.zeta, 2)
	end)

	t.test("the refinery runs at full speed whatever the player's level", function()
		local low = { line = 1, hopper = { crystal = 5 }, bin = {}, level = 1 }
		local high = { line = low.line, hopper = { crystal = 5 }, bin = {}, level = 50 }
		local _, lowBars = Refining.run(low, 20)
		local _, highBars = Refining.run(high, 20)
		t.eq(lowBars, highBars)
		t.ok(lowBars > 0)
	end)

	t.test("an Efficient Line multiplier speeds the line up", function()
		local function data() return { line = 1, hopper = { iron = 1000 }, bin = {} } end
		t.near(Refining.lineRate(data(), 1, 1.2), Refining.lineRate(data(), 1, 1) * 1.2, 1e-9)
	end)
end
