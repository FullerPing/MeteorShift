--!strict
-- Pure pet arithmetic: quantity multipliers stay separate from odds and XP sources.

return function(t: any)
	local Pets = require(t.shared.Pets)

	t.test("yield multiplies validated ore after its existing type and pass multipliers", function()
		t.near(Pets.oreYield(10 * 0.5 * 2, 0.25), 12.5, 1e-9)
		t.near(Pets.oreYield(0.2, 0.05), 0.21, 1e-9, "fractional ore is preserved")
		t.near(Pets.oreYield(10, 0), 10, 1e-9)
		t.near(Pets.oreYield(10, 2), 14, 1e-9, "yield cap")
		t.near(Pets.oreYield(10, -1), 10, 1e-9)
		t.eq(Pets.oreYield(0, 0.40), 0)
	end)

	t.test("scholar multiplies every player XP grant and preserves fractions", function()
		t.near(Pets.playerXp(10, 0.15), 11.5, 1e-9)
		t.near(Pets.playerXp(1.5, 0.08), 1.62, 1e-9)
		t.near(Pets.playerXp(20, 1), 32, 1e-9, "scholar cap")
		t.near(Pets.playerXp(20, 0), 20, 1e-9)
		t.near(Pets.playerXp(20, -1), 20, 1e-9)
		t.eq(Pets.playerXp(0, 0.60), 0)
	end)

	t.test("shards rounds down only after multiplying the complete cracked-core payout", function()
		t.eq(Pets.coreShards(7, 0.20), 8)
		t.eq(Pets.coreShards(3, 0.20), 3)
		t.eq(Pets.coreShards(11, 1), 14, "shards cap")
		t.eq(Pets.coreShards(11, 0), 11)
		t.eq(Pets.coreShards(11, -1), 11)
		t.eq(Pets.coreShards(0, 0.30), 0)
	end)

	t.test("vault scales both station capacities by the same capped multiplier", function()
		t.near(Pets.vaultCapacity(200, 0.35), 270, 1e-9, "hopper")
		t.near(Pets.vaultCapacity(75, 0.35), 101.25, 1e-9, "collection post")
		t.eq(Pets.vaultCapacity(200, 0), 200)
		t.eq(Pets.vaultCapacity(200, 5), 400, "vault cap")
		t.eq(Pets.vaultCapacity(200, -1), 200)
		t.eq(Pets.vaultCapacity(0, 1), 0)
	end)

	t.test("invalid amounts grant nothing and non-finite bonuses act as no bonus", function()
		for _, rule in { Pets.oreYield, Pets.playerXp, Pets.coreShards, Pets.vaultCapacity } do
			for _, amount in { 0 / 0, math.huge, -math.huge, -1 } do
				t.eq(rule(amount, 0.20), 0, "invalid amount")
			end
			for _, bonus in { 0 / 0, math.huge, -math.huge } do
				t.eq(rule(10, bonus), 10, "invalid bonus")
			end
			t.eq(rule(1.79e308, 1), 0, "overflow grants nothing")
		end
	end)
end
