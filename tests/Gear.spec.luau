--!strict
-- Spec for Shared.Gear: one pickaxe and one backpack, leveled by stat and evolved by tier.

return function(t: any)
	local Gear = require(t.shared.Gear)
	local MiningPower = require(t.shared.MiningPower)
	local Config = require(t.shared.Config)
	local LPT = Config.Gear.LevelsPerTier

	t.test("a fresh item of each tier matches the tier table", function()
		for tier, item in Config.Pickaxes do
			local pickaxe = Gear.pickaxe(tier, Gear.freshPickaxeStats(tier))
			t.eq(pickaxe.Tier, tier)
			t.near(pickaxe.Swing, item.Swing, 1e-9, "swing, tier " .. tier)
			t.near(pickaxe.Damage, item.Damage, 1e-6, "damage, tier " .. tier)
			t.eq(pickaxe.OrePerHit, item.OrePerHit)
			t.near(pickaxe.Power, MiningPower.power(tier), 1e-9, "power, tier " .. tier)
		end
		for tier, item in Config.Backpacks do
			t.near(Gear.capacity(tier, Gear.freshBackpackStats(tier)), item.Capacity, 1e-6, "capacity, tier " .. tier)
		end
	end)

	t.test("levels grow Power, speed and capacity smoothly and never past the next tier's value", function()
		local previous = nil
		for level = 1, LPT * #Config.Pickaxes do
			local pickaxe = Gear.pickaxe(1, { power = level, speed = level, reach = 1, crit = 1 })
			if previous then
				t.ok(pickaxe.Power > previous.Power, "power rises at level " .. level)
				t.ok(pickaxe.Swing < previous.Swing, "swing shortens at level " .. level)
			end
			previous = pickaxe
		end
		-- the last level of a tier sits just under the next tier's first level
		local top = Gear.pickaxe(1, { power = LPT, speed = LPT, reach = 1, crit = 1 })
		t.ok(top.Power < MiningPower.power(2) and top.Power > MiningPower.power(1))
		t.ok(Gear.capacity(1, { capacity = LPT }) < Config.Backpacks[2].Capacity)
	end)

	t.test("reach and crit are linear and carry across tiers", function()
		local low = Gear.pickaxe(1, { power = 1, speed = 1, reach = 1, crit = 1 })
		t.eq(low.Reach, Config.Meteor.MineRange)
		t.eq(low.CritChance, 0)
		local high = Gear.pickaxe(8, { power = 1, speed = 1, reach = 41, crit = 41 })
		t.near(high.Reach, Config.Meteor.MineRange + 40 * Config.Gear.Pickaxe.ReachPerLevel, 1e-9)
		t.near(high.CritChance, 40 * Config.Gear.Pickaxe.CritPerLevel, 1e-9)
	end)

	t.test("the tier caps the stat level", function()
		t.eq(Gear.cap(1), LPT)
		t.eq(Gear.cap(3), 3 * LPT)
		t.ok(Gear.canLevel("pickaxe", 1, LPT - 1))
		t.ok(not Gear.canLevel("pickaxe", 1, LPT))
		t.ok(Gear.canLevel("pickaxe", 2, LPT))
		t.ok(not Gear.canLevel("pickaxe", #Config.Pickaxes, LPT * #Config.Pickaxes), "nothing past the last level")
	end)

	t.test("prices rise with the level and end with the last one", function()
		local last = 0
		for level = 1, LPT * #Config.Pickaxes - 1 do
			local price = Gear.price("pickaxe", "power", level)
			t.ok(price ~= nil and price > last, "price rises at level " .. level)
			last = price :: number
		end
		t.eq(Gear.price("pickaxe", "power", LPT * #Config.Pickaxes), nil)
		t.eq(Gear.price("pickaxe", "nonsense", 1), nil)
		t.eq(Gear.price("backpack", "capacity", 1), Config.Gear.Backpack.Cost.capacity.Base)
	end)

	t.test("evolving needs the Gate stat at the cap and quotes the next tier's price", function()
		local early = Gear.evolution("pickaxe", 1, { power = LPT - 1, speed = 1, reach = 1, crit = 1 })
		t.ok(early ~= nil and not early.ready)
		local ready = Gear.evolution("pickaxe", 1, { power = LPT, speed = 1, reach = 1, crit = 1 })
		t.ok(ready ~= nil and ready.ready)
		t.eq((ready :: any).tier, 2)
		t.eq((ready :: any).cost, Config.Pickaxes[2].Cost)
		t.eq((ready :: any).shards, Config.Pickaxes[2].Shards)
		-- only the Gate stat matters, so a lagging Speed doesn't block it
		t.ok(Gear.evolution("pickaxe", 1, { power = LPT, speed = 1, reach = 1, crit = 1 }).ready)
		t.eq(Gear.evolution("pickaxe", #Config.Pickaxes, Gear.freshPickaxeStats(#Config.Pickaxes)), nil)
		local pack = Gear.evolution("backpack", 1, { capacity = LPT })
		t.ok(pack ~= nil and pack.ready)
	end)

	t.test("the bundle cost is the Gate stat's levels plus the evolve price", function()
		local expected = Config.Pickaxes[2].Cost
		for level = 1, LPT - 1 do
			expected += Gear.price("pickaxe", "power", level) :: number
		end
		t.eq(Gear.bundleCost("pickaxe", 2), expected)
		t.eq(Gear.bundleCost("pickaxe", 1), Config.Pickaxes[1].Cost)
		t.eq(Gear.bundleCost("pickaxe", 99), 0)
	end)

	t.test("saved stats are cleaned into 1 to the tier's cap and missing ones filled", function()
		local stats = Gear.cleanPickaxeStats(2, { power = 999, speed = -4, reach = 7.9 })
		t.eq(stats.power, Gear.cap(2))
		t.eq(stats.speed, 1)
		t.eq(stats.reach, 7)
		t.eq(stats.crit, Gear.levelsForTier(2), "missing stat starts like a fresh tier-2 item")
		local pack = Gear.cleanBackpackStats(1, nil)
		t.eq(pack.capacity, 1)
		t.eq(Gear.cleanBackpackStats(3, { capacity = 5 }).capacity, 5)
	end)
end
