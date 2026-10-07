--!strict
-- Spec for Shared.Hooks: the engagement-hook rules. Values come from Config.Hooks.

return function(t: any)
	local Hooks = require(t.shared.Hooks)
	local Config = require(t.shared.Config)
	local Settings = Config.Hooks

	t.test("the jackpots are EV-neutral: the average swing pays exactly the base ore", function()
		local base = Hooks.oreBase()
		local mean = (1 - Settings.RichVein.Chance - Settings.SuperVein.Chance) * base
			+ Settings.RichVein.Chance * base * Settings.RichVein.Mult
			+ Settings.SuperVein.Chance * base * Settings.SuperVein.Mult
		local golden = 1 + Settings.GoldenMeteor.Chance * (Settings.GoldenMeteor.PayMult - 1)
		t.near(mean * golden, 1, 1e-9)
	end)

	t.test("vein rolls pick the band by roll", function()
		local base = Hooks.oreBase()
		local mult, kind = Hooks.vein(0.5)
		t.near(mult, base, 1e-9)
		t.eq(kind, nil)
		mult, kind = Hooks.vein(0)
		t.eq(kind, "super")
		t.near(mult, base * Settings.SuperVein.Mult, 1e-9)
		mult, kind = Hooks.vein(Settings.SuperVein.Chance + 1e-6)
		t.eq(kind, "rich")
		t.near(mult, base * Settings.RichVein.Mult, 1e-9)
	end)

	t.test("a golden node pays the breaker more than a contributor", function()
		t.eq(Hooks.goldenNodeOre(10, true), 10 * Settings.GoldenNode.Breaker)
		t.eq(Hooks.goldenNodeOre(10, false), 10 * Settings.GoldenNode.Contributor)
	end)

	t.test("shard crumbs drop under the chance and stay within range", function()
		t.eq(Hooks.shardCrumb(Settings.ShardCrumb.Chance + 0.01, 0.5), 0)
		t.eq(Hooks.shardCrumb(0, 0), Settings.ShardCrumb.Min)
		t.eq(Hooks.shardCrumb(0, 0.999999), Settings.ShardCrumb.Max)
	end)

	t.test("crate bands sum to 1 and cash is clamped between the floor and the ceiling", function()
		local total = 0
		for _, band in Settings.SupplyCrate do total += band.Chance end
		t.near(total, 1, 1e-9)
		local small = Hooks.crate(0.001, 1e9, 0, 0, 0)
		t.eq(small.kind, "cash")
		t.eq(small.cash, Settings.CrateFloor)
		local big = Hooks.crate(1e9, 5000, 0, 1, 0)
		t.eq(big.cash, 5000)
		local shards = Hooks.crate(10, 1e9, 0.999, 0, 0.999)
		t.eq(shards.cash, 0)
		t.eq(shards.shards, 30)
	end)

	t.test("welcome back is usually x1 and its bands cover every roll", function()
		t.eq(Hooks.welcomeBack(0), 1)
		t.eq(Hooks.welcomeBack(0.9), 1.5)
		t.eq(Hooks.welcomeBack(0.999), 3)
		t.eq(Hooks.welcomeBack(2), 1)
	end)

	t.test("mineral pity starts after AfterHits, steps up and caps", function()
		local pity = Settings.Pity
		t.eq(Hooks.pityMult(0), 1)
		t.eq(Hooks.pityMult(pity.AfterHits - 1), 1)
		t.eq(Hooks.pityMult(pity.AfterHits), 2)
		t.eq(Hooks.pityMult(pity.AfterHits + pity.StepHits), 3)
		t.eq(Hooks.pityMult(1e6), pity.MaxMult)
	end)

	t.test("the expected crate seconds match the bands", function()
		t.near(Hooks.crateExpectedSeconds(), 0.80 * 32.5 + 0.15 * 17.5, 1e-9)
	end)
end
