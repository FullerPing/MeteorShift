--!strict
-- Spec for Shared.MiningPower (spec §5.3): the hidden stat node/core HP runs
-- on. Expected values are derived from Config.Meteor and Config.Pickaxes
-- tier 1 (Swing 0.6) and tier 3 (Swing 0.5) as they stand today.

return function(t: any)
	local MiningPower = require(t.shared.MiningPower)

	t.test("tier 1 power is 1", function()
		t.eq(MiningPower.power(1), 1)
	end)

	t.test("tier 4 power is about 1.953 (1.25^3)", function()
		t.near(MiningPower.power(4), 1.953, 0.001)
	end)

	t.test("floorPower is 4 basic pickaxes per second", function()
		-- FloorPlayers = 4, tier 1 power (1) / tier 1 swing (0.6s)
		t.near(MiningPower.floorPower(), 4 * (1 / 0.6), 0.0001)
	end)

	t.test("serverPower floors a tiny lobby", function()
		t.eq(MiningPower.serverPower({ 1 }), MiningPower.floorPower())
	end)

	t.test("serverPower sums tiers once above the floor", function()
		local tiers = {}
		for _ = 1, 20 do
			table.insert(tiers, 3)
		end
		-- tier 3 power (1.25^2 = 1.5625) / tier 3 swing (0.5s) = 3.125/player
		t.near(MiningPower.serverPower(tiers), 20 * 3.125, 0.0001)
	end)

	t.test("size splits crust HP across nodes and scales the core separately", function()
		local crustHp, coreHp = MiningPower.size(10, 36, 1)
		t.near(crustHp, 10 * 70 / 36, 0.0001) -- CrustSeconds = 70
		t.near(coreHp, 10 * 45, 0.0001) -- CoreSeconds = 45
	end)

	t.test("size applies the meteor type's HP multiplier", function()
		local crustHp, coreHp = MiningPower.size(10, 36, 1.2)
		t.near(crustHp, 10 * 70 * 1.2 / 36, 0.0001)
		t.near(coreHp, 10 * 45 * 1.2, 0.0001)
	end)

	t.test("shouldRescale trips once drift passes 15%", function()
		t.ok(MiningPower.shouldRescale(10, 11.6)) -- +16%
		t.ok(not MiningPower.shouldRescale(10, 11.4)) -- +14%
	end)
end
