--!strict
-- Shared.Relics: finds, duplicates and the boosts relics add
return function(t)
	local Relics = require(t.shared.Relics)
	local Config = require(t.shared.Config)

	t.test("every relic boosts a real role that has no pet visual", function()
		local seen = {}
		for _, relic in Config.Relics.List do
			t.ok(not seen[relic.Id], "duplicate " .. relic.Id)
			seen[relic.Id] = true
			t.ok(Config.Pets.Roles[relic.Role] ~= nil, relic.Id .. " role")
			t.ok(relic.Role ~= "miner" and relic.Role ~= "hauler", relic.Id .. " has no body to work with")
			t.ok(relic.Value > 0 and relic.Value <= Config.Pets.Roles[relic.Role].Cap / 2, relic.Id .. " stays small")
		end
	end)

	t.test("roll finds a relic only under the chance, and pick covers the list", function()
		t.eq(Relics.roll(0.03, 0.5, 0), nil)
		t.eq(Relics.roll(0.03, 0.01, 0), Config.Relics.List[1].Id)
		t.eq(Relics.roll(0.03, 0.01, 0.9999), Config.Relics.List[#Config.Relics.List].Id)
		t.eq(Relics.roll(0, 0, 0), nil)
	end)

	t.test("a new relic is kept and a duplicate becomes fragments", function()
		local saved = Relics.clean(nil)
		local id = Config.Relics.List[1].Id
		t.ok(Relics.add(saved, id))
		t.eq(Relics.count(saved), 1)
		t.ok(not Relics.add(saved, id))
		t.eq(saved.fragments, Config.Relics.DuplicateFragments)
		t.ok(not Relics.add(saved, "nonsense"))
		t.eq(saved.fragments, Config.Relics.DuplicateFragments)
	end)

	t.test("clean drops unknown relics and bad fragment counts", function()
		local saved = Relics.clean({ owned = { ghost = true, [Config.Relics.List[2].Id] = true, [Config.Relics.List[3].Id] = 1 }, fragments = -4 })
		t.eq(Relics.count(saved), 1)
		t.eq(saved.fragments, 0)
	end)

	t.test("addTo puts relic boosts on top of the (capped) pet totals without touching them", function()
		local relic = Config.Relics.List[1]
		local base = { [relic.Role] = 0.1 }
		local saved = Relics.clean({ owned = { [relic.Id] = true } })
		local out = Relics.addTo(base, saved)
		t.near(out[relic.Role], 0.1 + relic.Value, 1e-9)
		t.eq(base[relic.Role], 0.1, "the input is not changed")
	end)
end
