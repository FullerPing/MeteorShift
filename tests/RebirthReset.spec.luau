--!strict
-- Rebirth empties the active mining loop while retaining permanent rewards.
return function(t: any)
	local Reset = require(t.lib.RebirthReset)
	local Template = require(t.lib.ProfileTemplate)
	local MineralIndex = require(t.shared.MineralIndex)
	local Index = require(t.shared.Config.Index)
	local Refining = require(t.lib.Refining)
	local function copy(value: any): any
		if type(value) ~= "table" then return value end
		local out = {}
		for key, entry in value do out[key] = copy(entry) end
		return out
	end
	local function profile(): any
		local data = copy(Template)
		data.cash, data.shards, data.pickaxeTier, data.backpackTier = 25e6, 87, 7, 6
		data.pickaxeStats = { power = 64, speed = 61, reach = 30, crit = 12 }
		data.backpackStats = { capacity = 55 }
		data.stations = { hopper = 5, conveyor = 6, refinery = 7, collector = 4 }
		data.backpack = { iron = 40, frost = 5 }
		data.hopper = { iron = 140, frost = 20 }
		data.bin, data.bars, data.decor = { frost = 30 }, { crystal = 12 }, { bench = true }
		data.progress, data.rebirths, data.lastSeen = 0.9, 3, 123
		data.refinePriority = { "frost", "iron" }
		for _, page in Index.Pages do
			for _, mineral in page.Minerals do data.index[mineral.Id] = 2 end
		end
		data.credits.callMeteor, data.overclockLeft = 2, 420
		data.receipts = { "already-paid" }
		data.tutorialStep, data.flags.tutorialDone, data.stats.barsSold = 11, true, 999
		return data
	end

	t.test("cash and equipment return to their starter values", function()
		local data = profile()
		Reset.apply(data, 1000)
		t.eq(data.cash, 0)
		t.eq(data.pickaxeTier, 1)
		t.eq(data.backpackTier, 1)
		for stat, level in Template.pickaxeStats do t.eq(data.pickaxeStats[stat], level, "pickaxe " .. stat) end
		t.eq(data.backpackStats.capacity, 1, "backpack capacity level")
		t.eq(data.lastSeen, 1000, "new offline checkpoint")
	end)

	t.test("only the refinery upgrade survives production reset", function()
		local data = profile()
		local stations = data.stations
		Reset.apply(data, 1000)
		t.eq(data.stations, stations, "station references stay valid")
		t.eq(data.stations.refinery, 7)
		for _, id in { "hopper", "conveyor", "collector" } do t.eq(data.stations[id], 1, id) end
	end)

	t.test("all held and stored inventories and decor are emptied in place", function()
		local data = profile()
		local held = {}
		for _, key in { "backpack", "hopper", "bin", "bars", "decor" } do held[key] = data[key] end
		Reset.apply(data, 1000)
		for key, old in held do
			t.eq(data[key], old, key .. " map remains the same object")
			t.eq(next(data[key]), nil, key .. " is empty")
		end
		t.eq(data.progress, 0, "no partial ore survives")
	end)

	t.test("core shards and every index bonus and title survive unchanged", function()
		local data = profile()
		local index, bonus, titles = data.index, MineralIndex.cashBonus(data.index), MineralIndex.titles(data.index)
		t.ok(bonus > 1, "fixture earned real index rewards")
		Reset.apply(data, 1000)
		t.eq(data.shards, 87)
		t.eq(data.index, index)
		t.eq(MineralIndex.cashBonus(data.index), bonus)
		local after = MineralIndex.titles(data.index)
		t.eq(#after, #titles)
		for i, title in titles do t.eq(after[i], title) end
	end)

	t.test("purchased value, preferences and lifetime history are retained", function()
		local data = profile()
		local kept = { "credits", "receipts", "flags", "stats", "refinePriority" }
		local old = {}
		for _, key in kept do old[key] = data[key] end
		Reset.apply(data, 1000)
		for _, key in kept do t.eq(data[key], old[key], key) end
		t.eq(data.credits.callMeteor, 2)
		t.eq(data.receipts[1], "already-paid")
		t.eq(data.overclockLeft, 420)
		t.eq(data.stats.barsSold, 999)
		t.eq(data.flags.tutorialDone, true)
		t.eq(data.tutorialStep, 11)
		t.eq(data.rebirths, 3, "service owns rebirth count")
		t.eq(data.version, Template.version)
	end)

	t.test("old partial production cannot produce bars after reset", function()
		local data = profile()
		Reset.apply(data, 1000)
		local made, count = Refining.run(data, 7200)
		t.eq(count, 0)
		t.eq(next(made), nil)
		t.eq(next(data.bin), nil)
		t.eq(data.progress, 0)
	end)

	t.test("repeated rebirth reset does not mutate the profile template or permanent rewards", function()
		local data = profile()
		Reset.apply(data, 1000)
		data.cash, data.hopper.iron, data.stations.hopper = 100e6, 50, 3
		Reset.apply(data, 2000)
		t.eq(data.cash, 0)
		t.eq(next(data.hopper), nil)
		t.eq(data.stations.hopper, 1)
		t.eq(data.stations.refinery, 7)
		t.eq(data.shards, 87)
		t.eq(Template.stations.refinery, 1)
		t.eq(next(Template.index), nil)
	end)

	t.test("colony perks and the overstay counter: perks survive, the counter clears", function()
		local data = profile()
		data.perks = { headStart = 2, stationMemory = 2, efficientLine = 3, offlineTraining = 1, petBond = 1 }
		data.overflow = 5e6
		Reset.apply(data, 1000)
		t.eq(data.perks.headStart, 2)
		t.eq(data.perks.efficientLine, 3)
		t.eq(data.perks.petBond, 1)
		t.eq(data.overflow, 0)
	end)

	t.test("Station Memory keeps a share of hopper, conveyor and collector levels but never the refinery rule", function()
		local data = profile()
		data.perks = { stationMemory = 2 } -- keeps 50% of the levels above 1
		Reset.apply(data, 1000)
		t.eq(data.stations.hopper, 3) -- 5: 1 + floor(4 x .5)
		t.eq(data.stations.conveyor, 3) -- 6: 1 + floor(5 x .5)
		t.eq(data.stations.collector, 2) -- 4: 1 + floor(3 x .5)
		t.eq(data.stations.refinery, 7, "the refinery always survives")
	end)

	t.test("Head Start rebuilds the gear at a higher tier, held to the player level", function()
		local Levels = require(t.shared.Levels)
		local data = profile()
		data.perks = { headStart = 4 }
		data.level = Levels.evolveLevel(5)
		Reset.apply(data, 1000)
		t.eq(data.pickaxeTier, 5)
		t.eq(data.backpackTier, 5)
		local low = profile()
		low.perks = { headStart = 4 }
		low.level = 1
		Reset.apply(low, 1000)
		t.eq(low.pickaxeTier, 4, "level 1 can only hold the tiers that are free")
	end)
end
