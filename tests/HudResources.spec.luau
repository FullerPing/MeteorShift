--!strict
-- Carried bar rows for the expanded foundry. Config fixtures keep future ore
-- types and sale rounding independent of the live game's tuning.

return function(t: any)
	local HudResources = require(t.shared.HudResources)
	local Home = require(t.shared.Config.Home)
	local home = {
		OreOrder = { "iron", "frost", "crystal" },
		BarPrices = { iron = 5, frost = 120, crystal = 3000 },
		OreNames = { iron = "Iron", frost = "Frost", crystal = "Crystal" },
	}

	t.test("mixed carried bars keep configured order and their sale multiplier", function()
		local rows = HudResources.bars({
			barInventory = { crystal = 1, iron = 10, frost = 2 },
			barValue = 4935,
		}, home)
		t.eq(#rows, 3)
		t.eq(rows[1].id, "iron")
		t.eq(rows[1].name, "Iron")
		t.eq(rows[1].amount, 10)
		t.eq(rows[1].value, 75)
		t.eq(rows[2].id, "frost")
		t.eq(rows[2].amount, 2)
		t.eq(rows[2].value, 360)
		t.eq(rows[3].id, "crystal")
		t.eq(rows[3].amount, 1)
		t.eq(rows[3].value, 4500)
	end)

	t.test("loading and aggregate-only snapshots leave configured rows empty", function()
		for _, state in { false, {}, { bars = 25, barValue = 1000 } } do
			local rows = HudResources.bars(if state == false then nil else state, home)
			t.eq(#rows, 3)
			for _, row in rows do
				t.eq(row.amount, 0)
				t.eq(row.value, 0)
			end
		end
	end)

	t.test("default configuration supplies all current bar types", function()
		local rows = HudResources.bars(nil)
		for i, id in Home.OreOrder do
			t.eq(rows[i].id, id)
			t.eq(rows[i].name, Home.OreNames[id] or id)
		end
	end)

	t.test("future configured types and unknown inventory keys appear once in stable order", function()
		local future = {
			OreOrder = { "iron", "frost", "iron", "solar" },
			BarPrices = { iron = 5, frost = 120, solar = 5000, amber = 50 },
			OreNames = { iron = "Iron", frost = "Frost", solar = "Solar", cobalt = "Cobalt" },
		}
		local rows = HudResources.bars({ barInventory = { zeta = 2, quartz = 4, solar = 1 } }, future)
		t.eq(#rows, 7)
		t.eq(rows[1].id, "iron")
		t.eq(rows[2].id, "frost")
		t.eq(rows[3].id, "solar")
		t.eq(rows[3].name, "Solar")
		t.eq(rows[3].amount, 1)
		t.eq(rows[3].value, 5000)
		t.eq(rows[4].id, "amber")
		t.eq(rows[4].name, "amber")
		t.eq(rows[4].amount, 0)
		t.eq(rows[5].id, "cobalt")
		t.eq(rows[6].id, "quartz")
		t.eq(rows[6].amount, 4)
		t.eq(rows[6].value, 0)
		t.eq(rows[7].id, "zeta")
	end)

	t.test("stored collection bars never inflate the carried sale rows", function()
		local rows = HudResources.bars({
			barInventory = { iron = 2 },
			collectorInventory = { frost = 100, crystal = 20 },
			line = { collector = { amount = 120 } },
			barValue = 15,
		}, home)
		t.eq(rows[1].amount, 2)
		t.eq(rows[1].value, 15)
		t.eq(rows[2].amount, 0)
		t.eq(rows[3].amount, 0)
	end)

	t.test("malformed amounts cannot make negative or nonfinite bar rows", function()
		local rows = HudResources.bars({
			barInventory = { iron = -4, frost = "12", crystal = math.huge, nan = 0 / 0, fractional = 2.5, [1] = 7 },
		}, home)
		t.eq(#rows, 5)
		t.eq(rows[1].amount, 0)
		t.eq(rows[2].amount, 0)
		t.eq(rows[3].amount, 0)
		t.eq(rows[4].id, "fractional")
		t.eq(rows[4].amount, 2.5)
		t.eq(rows[5].amount, 0)
		local invalid = HudResources.bars({ barInventory = "loading", barValue = math.huge }, home)
		t.eq(invalid[1].amount, 0)
		t.eq(invalid[1].value, 0)
	end)

	t.test("sale rounding gives remaining dollars to the largest shares", function()
		local equalPrices = {
			OreOrder = { "iron", "frost", "crystal" },
			BarPrices = { iron = 1, frost = 1, crystal = 1 },
			OreNames = {},
		}
		local rows = HudResources.bars({ barInventory = { iron = 1, frost = 2, crystal = 3 }, barValue = 5 }, equalPrices)
		t.eq(rows[1].value, 1)
		t.eq(rows[2].value, 2)
		t.eq(rows[3].value, 2)
		t.eq(rows[1].value + rows[2].value + rows[3].value, 5)
		local tied = HudResources.bars({ barInventory = { iron = 1, frost = 1, crystal = 1 }, barValue = 5 }, equalPrices)
		t.eq(tied[1].value, 2)
		t.eq(tied[2].value, 2)
		t.eq(tied[3].value, 1)
	end)

	t.test("missing sale totals use base prices but invalid totals cannot show revenue", function()
		local fallback = HudResources.bars({ barInventory = { iron = 2, frost = 1 } }, home)
		t.eq(fallback[1].value, 10)
		t.eq(fallback[2].value, 120)
		for _, value in { -10, "130", math.huge, 0 / 0 } do
			local rows = HudResources.bars({ barInventory = { iron = 2 }, barValue = value }, home)
			t.eq(rows[1].value, 0)
		end
	end)

	t.test("large finite sale totals keep floating point rounding from adding revenue", function()
		local rows = HudResources.bars({
			barInventory = { iron = 133381, frost = 800211, crystal = 19338 },
			barValue = 7844047418374569,
		}, home)
		t.eq(rows[1].value + rows[2].value + rows[3].value, 7844047418374569)
		for _, row in rows do
			t.ok(row.value >= 0)
		end
	end)

	t.test("rows are detached from the snapshot and configuration", function()
		local inventory = { iron = 2 }
		local state = { barInventory = inventory, barValue = 10 }
		local rows = HudResources.bars(state, home)
		rows[1].amount = 99
		rows[1].name = "Changed"
		t.eq(inventory.iron, 2)
		t.eq(home.OreNames.iron, "Iron")
		inventory.iron = 3
		t.eq(rows[1].amount, 99)
		t.eq(HudResources.bars(state, home)[1].amount, 3)
	end)

	t.test("backpack ore rows show only carried raw ore names and amounts", function()
		t.ok(type(HudResources.ores) == "function", "backpack ore row builder missing")
		local rows = HudResources.ores({
			backpack = { crystal = 3, iron = 8 },
			barInventory = { iron = 99, frost = 88, crystal = 77 },
			hopper = { frost = 66 },
			collectorInventory = { crystal = 55 },
			barValue = 123456,
		}, home)
		t.eq(#rows, 2, "uncarried configured ores stay hidden")
		t.eq(rows[1].id, "iron")
		t.eq(rows[1].name, "Iron")
		t.eq(rows[1].amount, 8)
		t.eq(rows[2].id, "crystal")
		t.eq(rows[2].name, "Crystal")
		t.eq(rows[2].amount, 3)
		for _, row in rows do t.eq((row :: any).value, nil, "raw ores have no sale value field") end
	end)

	t.test("backpack ore rows hide empty future types and keep carried ids in stable order", function()
		local future = {
			OreOrder = { "iron", "frost", "iron", "solar" },
			BarPrices = { iron = 5, frost = 120, solar = 5000, amber = 50 },
			OreNames = { iron = "Iron", frost = "Frost", solar = "Solar", cobalt = "Cobalt" },
		}
		local rows = HudResources.ores({
			backpack = { zeta = 2, quartz = 4, solar = 1, frost = 3 },
			barInventory = { barOnly = 12 },
			hopper = { hopperOnly = 34 },
			collectorInventory = { collectorOnly = 56 },
		}, future)
		t.eq(#rows, 4, "only positive carried types appear")
		for index, id in { "frost", "solar", "quartz", "zeta" } do
			t.eq(rows[index].id, id)
			t.eq((rows[index] :: any).value, nil)
		end
		t.eq(rows[1].name, "Frost")
		t.eq(rows[1].amount, 3)
		t.eq(rows[2].name, "Solar")
		t.eq(rows[2].amount, 1)
		t.eq(rows[3].name, "quartz")
		t.eq(rows[3].amount, 4)
		t.eq(rows[4].amount, 2)
	end)

	t.test("empty loading or invalid backpack stock produces an empty ore list", function()
		for _, state in { false, {}, { backpack = "loading" }, { backpack = { iron = 0, frost = 0, crystal = 0 } }, {
			barInventory = { iron = 10 }, hopper = { frost = 20 }, collectorInventory = { crystal = 30 },
		} } do
			local rows = HudResources.ores(if state == false then nil else state, home)
			t.eq(#rows, 0, "no carried ores means no inventory rows")
		end
		local malformed = HudResources.ores({ backpack = { iron = -4, frost = "12", crystal = math.huge, nan = 0 / 0, [1] = 7 } }, home)
		t.eq(#malformed, 0, "invalid counts cannot reveal configured or unknown ores")
	end)

	t.test("backpack ore rows detach their names and counts from the saved snapshot", function()
		local inventory = { iron = 2 }
		local rows = HudResources.ores({ backpack = inventory }, home)
		t.eq(#rows, 1, "only the carried ore is shown")
		rows[1].amount, rows[1].name = 99, "Changed"
		t.eq(inventory.iron, 2)
		t.eq(home.OreNames.iron, "Iron")
		inventory.iron = 3
		t.eq(rows[1].amount, 99)
		t.eq(HudResources.ores({ backpack = inventory }, home)[1].amount, 3)
	end)
end
