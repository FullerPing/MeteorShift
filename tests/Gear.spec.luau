--!strict
-- Spec for Shared.Gear: one pickaxe and one backpack, each with a level that restarts at 1 with every tier
-- (tier t has LevelsPerTier x t levels).

return function(t: any)
	local Gear = require(t.shared.Gear)
	local MiningPower = require(t.shared.MiningPower)
	local Config = require(t.shared.Config)
	local LPT = Config.Gear.LevelsPerTier
	local pickaxeSettings = Config.Gear.Pickaxe
	local last = LPT * #Config.Pickaxes

	-- the price before inflation and rounding: the tier's LevelCost shared among its levels, each
	-- LevelGrowth^(1 / tier) dearer than the one before
	local function unscaled(kind: string, tier: number, level: number): number
		local list: any = if kind == "pickaxe" then Config.Pickaxes else Config.Backpacks
		local step = Config.Gear.LevelGrowth ^ (1 / tier)
		local total = (step ^ (Gear.cap(tier) - 1) - 1) / (step - 1)
		return list[tier].LevelCost * step ^ (level - 1) / total
	end

	t.test("every tier starts over at level 1", function()
		for tier = 1, #Config.Pickaxes do
			t.eq(Gear.levelsForTier(tier), 1)
		end
	end)

	t.test("a fresh item of each tier matches the tier table", function()
		for tier, item in Config.Pickaxes do
			local pickaxe = Gear.pickaxe(tier, Gear.levelsForTier(tier))
			t.eq(pickaxe.Tier, tier)
			t.near(pickaxe.Swing, item.Swing, 1e-9, "swing, tier " .. tier)
			t.near(pickaxe.Damage, item.Damage, 1e-6, "damage, tier " .. tier)
			t.eq(pickaxe.OrePerHit, item.OrePerHit)
			t.near(pickaxe.Power, MiningPower.power(tier), 1e-9, "power, tier " .. tier)
		end
		for tier, item in Config.Backpacks do
			t.near(Gear.capacity(tier, Gear.levelsForTier(tier)), item.Capacity, 1e-6, "capacity, tier " .. tier)
		end
	end)

	t.test("levels grow Power, speed and capacity smoothly and never past the next tier's value", function()
		for _, tier in { 1, 2, 3 } do
			local previous = nil
			for level = 1, Gear.cap(tier) do
				local pickaxe = Gear.pickaxe(tier, level)
				if previous then
					t.ok(pickaxe.Power > previous.Power, "power rises at tier " .. tier .. " level " .. level)
					t.ok(pickaxe.Swing < previous.Swing, "swing shortens at tier " .. tier .. " level " .. level)
				end
				previous = pickaxe
			end
			local top = Gear.pickaxe(tier, Gear.cap(tier))
			t.ok(top.Power < MiningPower.power(tier + 1) and top.Power > MiningPower.power(tier))
			t.ok(Gear.capacity(tier, Gear.cap(tier)) < Config.Backpacks[tier + 1].Capacity)
		end
	end)

	t.test("reach and crit grow with the level and carry across tiers", function()
		local low = Gear.pickaxe(1, 1)
		t.eq(low.Reach, Config.Meteor.MineRange)
		t.eq(low.CritChance, 0)
		-- tier 3 starts where tier 2 ends (20 tier-1 levels in), then a level of it is worth a third
		local third = Gear.pickaxe(3, 16)
		t.near(third.Reach, Config.Meteor.MineRange + 25 * pickaxeSettings.ReachPerLevel, 1e-9)
		t.near(third.CritChance, 25 * pickaxeSettings.CritPerLevel, 1e-9)
		t.near(Gear.pickaxe(2, 1).Reach, Config.Meteor.MineRange + LPT * pickaxeSettings.ReachPerLevel, 1e-9)
		t.ok(Gear.pickaxe(2, 1).Reach > Gear.pickaxe(1, LPT).Reach, "a new tier reaches further than the last level of the one before")
		-- reach stops growing at ReachMax; crit keeps growing
		local top = Gear.pickaxe(#Config.Pickaxes, last)
		t.near(top.Reach, Config.Meteor.MineRange + pickaxeSettings.ReachMax, 1e-9)
		t.ok(top.CritChance > Gear.pickaxe(8, LPT * 8).CritChance)
	end)

	t.test("the tier caps the level and each tier has more levels than the one before", function()
		t.eq(Gear.cap(1), LPT)
		t.eq(Gear.cap(3), 3 * LPT)
		t.ok(Gear.canLevel("pickaxe", 1, LPT - 1))
		t.ok(not Gear.canLevel("pickaxe", 1, LPT))
		t.ok(Gear.canLevel("pickaxe", 2, LPT))
		t.ok(not Gear.canLevel("pickaxe", 2, 2 * LPT))
		t.ok(not Gear.canLevel("pickaxe", #Config.Pickaxes, last), "nothing past the last level")
	end)

	t.test("prices rise with the level inside a tier and end with the last one", function()
		for tier = 1, #Config.Pickaxes do
			local before = 0
			for level = 1, Gear.cap(tier) - 1 do
				local price = Gear.price("pickaxe", tier, level)
				t.ok(price ~= nil and price >= before, "price rises at tier " .. tier .. " level " .. level)
				before = price :: number
			end
		end
		t.eq(Gear.price("pickaxe", #Config.Pickaxes, last), nil)
		t.eq(Gear.price("pickaxe", 1, 1), 45, "tier 1's first level kept its old price")
		t.eq(Gear.price("backpack", 1, 1), 37)
	end)

	t.test("a tier's levels together cost its LevelCost, and every tier's levels cost more than the last", function()
		for _, kind in { "pickaxe", "backpack" } do
			local list: any = if kind == "pickaxe" then Config.Pickaxes else Config.Backpacks
			local before = 0
			for tier = 1, #list do
				local sum = 0
				for level = 1, Gear.cap(tier) - 1 do sum += Gear.price(kind, tier, level) :: number end
				-- past ~1e16 a double's step exceeds $1, so allow a relative rounding error too
				local slack = math.max(Gear.cap(tier), list[tier].LevelCost * 1e-12)
				t.ok(math.abs(sum - list[tier].LevelCost) <= slack, kind .. " tier " .. tier .. " levels cost " .. sum)
				t.ok(sum > before, kind .. " tier " .. tier .. " levels cost more than the tier before")
				before = sum
			end
		end
	end)

	t.test("every tier is dearer to evolve into than the one before", function()
		for _, list in { Config.Pickaxes, Config.Backpacks } do
			for tier = 3, #list do
				t.ok(list[tier].Cost > list[tier - 1].Cost, list[tier].Name)
			end
		end
	end)

	t.test("price inflation multiplies the cash price and 1 or nil leave it alone", function()
		for _, spot in { { 1, 1 }, { 1, 5 }, { 3, 17 }, { 8, 41 }, { 16, 100 } } do
			local tier, level = spot[1], spot[2]
			t.eq(Gear.price("pickaxe", tier, level, 3), math.floor(unscaled("pickaxe", tier, level) * 3 + 0.5))
			t.eq(Gear.price("pickaxe", tier, level, 1), Gear.price("pickaxe", tier, level))
			t.eq(Gear.price("pickaxe", tier, level, nil), Gear.price("pickaxe", tier, level))
		end
	end)

	t.test("evolving needs the level at the cap and quotes the next tier's price", function()
		local early = Gear.evolution("pickaxe", 1, LPT - 1)
		t.ok(early ~= nil and not early.ready)
		local ready = Gear.evolution("pickaxe", 1, LPT)
		t.ok(ready ~= nil and ready.ready)
		t.eq((ready :: any).tier, 2)
		t.eq((ready :: any).cost, Config.Pickaxes[2].Cost)
		t.eq((ready :: any).shards, Config.Pickaxes[2].Shards)
		t.eq((Gear.evolution("pickaxe", 1, LPT, 3) :: any).cost, Config.Pickaxes[2].Cost * 3)
		t.eq(Gear.evolution("pickaxe", #Config.Pickaxes, last), nil)
		local pack = Gear.evolution("backpack", 1, LPT)
		t.ok(pack ~= nil and pack.ready)
	end)

	t.test("the bundle cost is the tier's levels plus the evolve price", function()
		local expected = Config.Pickaxes[2].Cost
		for level = 1, LPT - 1 do
			expected += Gear.price("pickaxe", 1, level) :: number
		end
		t.eq(Gear.bundleCost("pickaxe", 2), expected)
		t.eq(Gear.bundleCost("pickaxe", 1), Config.Pickaxes[1].Cost)
		t.eq(Gear.bundleCost("pickaxe", 99), 0)
		local scaled = math.floor(Config.Pickaxes[2].Cost * 3 + 0.5)
		for level = 1, LPT - 1 do
			scaled += Gear.price("pickaxe", 1, level, 3) :: number
		end
		t.eq(Gear.bundleCost("pickaxe", 2, 3), scaled)
		local third = Config.Pickaxes[3].Cost
		for level = 1, 2 * LPT - 1 do
			third += Gear.price("pickaxe", 2, level) :: number
		end
		t.eq(Gear.bundleCost("pickaxe", 3), third, "a tier's bundle covers all the levels of the tier before")
	end)

	t.test("a saved level is cleaned into 1 to the tier's cap and a missing one starts fresh", function()
		t.eq(Gear.cleanLevel(2, 999), Gear.cap(2))
		t.eq(Gear.cleanLevel(2, -4), 1)
		t.eq(Gear.cleanLevel(2, 7.9), 7)
		t.eq(Gear.cleanLevel(3, nil), Gear.levelsForTier(3))
		t.eq(Gear.cleanLevel(2, "x"), Gear.levelsForTier(2))
		t.eq(Gear.cleanLevel(1, 0 / 0), 1)
		t.eq(Gear.cleanLevel(1, math.huge), Gear.levelsForTier(1))
	end)

	t.test("bulk takes as many levels as cash and the tier cap allow, one price at a time", function()
		local price1 = Gear.price("pickaxe", 1, 1) :: number
		local price2 = Gear.price("pickaxe", 1, 2) :: number
		local count, total, allowed = Gear.bulk("pickaxe", 1, 1, price1 + price2 + 0.5, 10)
		t.eq(count, 2)
		t.near(total, price1 + price2, 1e-9)
		t.eq(allowed, 9) -- tier 1 caps the level at 10
		local none, zero, _, allowedTotal = Gear.bulk("pickaxe", 1, 1, 0, 10)
		t.eq(none, 0)
		t.eq(zero, 0)
		t.ok(allowedTotal > price1)
		local atCap = { Gear.bulk("pickaxe", 1, Gear.cap(1), 1e12, 10) }
		t.eq(atCap[1], 0)
		t.eq(atCap[3], 0)
		t.eq((Gear.bulk("pickaxe", 1, 1, 1e12, 3)), 3)
		local second = { Gear.bulk("pickaxe", 2, 1, 1e12, 99) }
		t.eq(second[1], 2 * LPT - 1, "tier 2 has twice the levels to buy")
		t.eq(second[3], 2 * LPT - 1)
	end)

	t.test("bulk with price inflation totals the scaled single prices", function()
		local expected = 0
		for level = 1, 4 do
			expected += Gear.price("pickaxe", 1, level, 9) :: number
		end
		local count, total = Gear.bulk("pickaxe", 1, 1, 1e15, 4, 9)
		t.eq(count, 4)
		t.eq(total, expected)
		local fewer = Gear.bulk("pickaxe", 1, 1, (Gear.price("pickaxe", 1, 1, 9) :: number) - 1, 4, 9)
		t.eq(fewer, 0)
	end)
end
