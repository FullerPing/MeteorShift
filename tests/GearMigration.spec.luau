--!strict
-- Profile v6 to v7: four pickaxe stat levels and the backpack's capacity level become one level each (counted across
-- the whole game, as v7 did). v7 to v8: that level restarts at 1 with every tier.
return function(t: any)
	local Migration = require(t.lib.GearMigration)
	local Gear = require(t.shared.Gear)

	local function oldPrice(base: number, growth: number, level: number): number
		return math.floor(base * growth ^ (level - 1) + 0.5)
	end

	t.test("the Gate stat becomes the level and the old stat tables are gone", function()
		local data: any = {
			pickaxeTier = 1, backpackTier = 1, cash = 10,
			pickaxeStats = { power = 7, speed = 1, reach = 1, crit = 1 }, backpackStats = { capacity = 3 },
		}
		Migration.run(data)
		t.eq(data.pickaxeLevel, 7)
		t.eq(data.backpackLevel, 3)
		t.eq(data.pickaxeStats, nil)
		t.eq(data.backpackStats, nil)
	end)

	t.test("an out-of-range, missing or broken level is made legal", function()
		local high: any = { pickaxeTier = 2, backpackTier = 2, pickaxeStats = { power = 999 }, backpackStats = { capacity = 999 } }
		Migration.run(high)
		t.eq(high.pickaxeLevel, 20, "a tier-2 item's top level in the v7 count")
		t.eq(high.backpackLevel, 20)
		local broken: any = { pickaxeTier = 3, backpackTier = 3, pickaxeStats = { power = "x", speed = 0 / 0 }, backpackStats = {} }
		Migration.run(broken)
		t.eq(broken.pickaxeLevel, 21, "a fresh tier-3 item in the v7 count")
		t.eq(broken.backpackLevel, 21)
		local bare: any = { pickaxeTier = 1, backpackTier = 1, pickaxeStats = {} }
		t.eq(Migration.run(bare), 0)
		t.eq(bare.pickaxeLevel, 1)
	end)

	t.test("Speed, Reach and Crit levels above a fresh item's are refunded at the old prices", function()
		local data: any = {
			pickaxeTier = 1, backpackTier = 1, cash = 100,
			pickaxeStats = { power = 5, speed = 4, reach = 3, crit = 1 }, backpackStats = { capacity = 9 },
		}
		local expected = 0
		for level = 1, 3 do expected += oldPrice(40, 1.115, level) end
		for level = 1, 2 do expected += oldPrice(20, 1.11, level) end
		local refund = Migration.run(data)
		t.eq(refund, expected)
		t.eq(data.cash, 100 + expected)
		t.eq(data.pickaxeLevel, 5, "Power is not refunded, it is the level")
		t.eq(data.backpackLevel, 9, "capacity is not refunded either")
	end)

	t.test("levels a tier gives for free are not refunded, and stats past the cap are clamped", function()
		local free: any = { pickaxeTier = 3, backpackTier = 3, cash = 0, pickaxeStats = { power = 21, speed = 21, reach = 21, crit = 21 } }
		t.eq(Migration.run(free), 0)
		local over: any = { pickaxeTier = 1, backpackTier = 1, cash = 0, pickaxeStats = { power = 3, speed = 500, reach = 1, crit = 1 } }
		local expected = 0
		for level = 1, 9 do expected += oldPrice(40, 1.115, level) end -- the tier-1 cap is level 10
		t.eq(Migration.run(over), expected)
	end)

	t.test("running it again on a migrated profile changes nothing", function()
		local data: any = { pickaxeTier = 2, backpackTier = 2, cash = 50, pickaxeLevel = 14, backpackLevel = 12 }
		t.eq(Migration.run(data), 0)
		t.eq(data.cash, 50)
		t.eq(data.pickaxeLevel, 14)
		t.eq(data.backpackLevel, 12)
	end)

	t.test("v7 to v8: a level inside the tier keeps its share of the tier over the longer run", function()
		local data: any = { pickaxeTier = 1, backpackTier = 2, pickaxeLevel = 4, backpackLevel = 14 }
		Migration.toTierLevels(data)
		t.eq(data.pickaxeLevel, 4, "tier 1 still has ten levels")
		t.eq(data.backpackLevel, 7, "level 4 of 10 in tier 2 becomes level 7 of 20")
		local third: any = { pickaxeTier = 3, backpackTier = 3, pickaxeLevel = 21, backpackLevel = 25 }
		Migration.toTierLevels(third)
		t.eq(third.pickaxeLevel, 1, "a fresh item stays fresh")
		t.eq(third.backpackLevel, 13)
	end)

	t.test("v7 to v8: an item at its tier's cap is still at the cap and so can still evolve", function()
		local data: any = { pickaxeTier = 2, backpackTier = 5, pickaxeLevel = 20, backpackLevel = 50 }
		Migration.toTierLevels(data)
		t.eq(data.pickaxeLevel, Gear.cap(2))
		t.eq(data.backpackLevel, Gear.cap(5))
	end)

	t.test("v7 to v8: broken or out-of-range levels end up legal", function()
		local data: any = { pickaxeTier = 2, backpackTier = 3, pickaxeLevel = 999, backpackLevel = "x" }
		Migration.toTierLevels(data)
		t.eq(data.pickaxeLevel, Gear.cap(2))
		t.eq(data.backpackLevel, 1)
		local bare: any = {}
		Migration.toTierLevels(bare)
		t.eq(bare.pickaxeLevel, 1)
		t.eq(bare.backpackLevel, 1)
	end)
end
