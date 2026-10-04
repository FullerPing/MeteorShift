--!strict
-- Spec for Shared.Pets: perks by level, XP, slots and the saved-data checks.

return function(t: any)
	local Pets = require(t.shared.Pets)
	local Config = require(t.shared.Config).Pets

	t.test("the Drillbot is a 199 Robux pass pet whose pass exists", function()
		local def = Pets.def("drillbot") :: any
		t.eq(def.Robux, 199)
		t.eq(def.Cost, 0)
		t.ok(require(t.shared.Config).Monetization.Passes[def.Pass] ~= nil)
	end)

	t.test("the Drillbot mines at 25% at level 1 and 40% at the max level", function()
		t.near(Pets.perk("miner", 1), 0.25, 1e-9)
		t.near(Pets.perk("miner", Config.MaxLevel), 0.40, 1e-9)
		t.ok(Pets.perk("miner", 5) > 0.25 and Pets.perk("miner", 5) < 0.40)
	end)

	t.test("every role's perk rises with the level and stays between its Min and Max", function()
		for role, def in Config.Roles do
			local last = 0
			for level = 1, Config.MaxLevel do
				local perk = Pets.perk(role, level)
				t.ok(perk > last, role .. " rises at level " .. level)
				t.ok(perk >= def.Min - 1e-9 and perk <= def.Max + 1e-9, role .. " range")
				last = perk
			end
		end
		t.eq(Pets.perk("nonsense", 3), 0)
	end)

	t.test("hauler 1% of the backpack a second, pack 30% at the max, as designed", function()
		t.near(Pets.perk("hauler", 1), 0.01, 1e-9)
		t.near(Pets.perk("pack", Config.MaxLevel), 0.30, 1e-9)
	end)

	t.test("slots start at 1 and grow with rebirths up to the max", function()
		t.eq(Pets.slots(0), 1)
		t.eq(Pets.slots(1), 2)
		t.eq(Pets.slots(2), 3)
		t.eq(Pets.slots(50), Config.Slots.Max)
		t.eq(Pets.slots(nil), 1)
	end)

	t.test("XP levels a pet up, carries the overflow and stops at the max", function()
		local pet = { level = 1, xp = 0 }
		local needed = Pets.xpToNext(1) :: number
		t.eq(Pets.addXp(pet, needed - 1), 0)
		t.eq(pet.level, 1)
		t.eq(Pets.addXp(pet, 1), 1)
		t.eq(pet.level, 2)
		t.eq(pet.xp, 0)
		-- a big gain levels several times and keeps the remainder
		local big = { level = 1, xp = 0 }
		local first, second = Pets.xpToNext(1) :: number, Pets.xpToNext(2) :: number
		t.eq(Pets.addXp(big, first + second + 5), 2)
		t.eq(big.level, 3)
		t.eq(big.xp, 5)
		-- the max level takes no more XP
		local top = { level = Config.MaxLevel, xp = 0 }
		t.eq(Pets.addXp(top, 1e9), 0)
		t.eq(Pets.xpToNext(Config.MaxLevel), nil)
		local nearTop = { level = Config.MaxLevel - 1, xp = 0 }
		Pets.addXp(nearTop, 1e9)
		t.eq(nearTop.level, Config.MaxLevel)
		t.eq(nearTop.xp, 0)
	end)

	t.test("the XP to max a pet is a few sessions of hits, not minutes", function()
		local total = 0
		for level = 1, Config.MaxLevel - 1 do
			total += Pets.xpToNext(level) :: number
		end
		t.ok(total > 8000 and total < 30000, "total XP " .. total)
	end)

	t.test("bonuses add the equipped pets' perks per role and ignore the rest", function()
		local saved = {
			owned = { drillbot = { level = 1, xp = 0 }, packMule = { level = 10, xp = 0 }, coinMagpie = { level = 1, xp = 0 } },
			equipped = { "drillbot", "packMule" },
		}
		local bonuses = Pets.bonuses(saved)
		t.near(bonuses.miner, 0.25, 1e-9)
		t.near(bonuses.pack, 0.30, 1e-9)
		t.eq(bonuses.merchant, 0, "owned but not equipped")
		t.eq(bonuses.hauler, 0)
		saved.equipped = { "drillbot", "drillbot", "ghost" }
		t.near(Pets.bonuses(saved).miner, 0.25, 1e-9, "a pet only counts once, unknown ones never")
	end)

	t.test("clean starts a new profile with no pets, drops unknown pets and fixes levels and the loadout", function()
		local fresh = Pets.clean(nil, 0)
		t.ok(next(fresh.owned) == nil, "the Drillbot is a pass pet, not a starter")
		t.eq(#fresh.equipped, 0)
		local cleaned = Pets.clean({
			owned = { packMule = { level = 99, xp = 5 }, ghost = { level = 3, xp = 0 }, jetWisp = { level = -2 } },
			equipped = { "packMule", "jetWisp", "ghost", "packMule", "coinMagpie" },
		}, 1) -- two slots
		t.ok(cleaned.owned.ghost == nil)
		t.ok(cleaned.owned.drillbot == nil, "no pet is invented")
		t.eq(cleaned.owned.packMule.level, Config.MaxLevel)
		t.eq(cleaned.owned.packMule.xp, 0)
		t.eq(cleaned.owned.jetWisp.level, 1)
		t.eq(#cleaned.equipped, 2, "limited to the slots")
		t.eq(cleaned.equipped[1], "packMule")
		t.eq(cleaned.equipped[2], "jetWisp")
	end)

	t.test("every pet in the catalog has a known role and unique id", function()
		local seen = {}
		for _, pet in Config.List do
			t.ok(Config.Roles[pet.Role] ~= nil, pet.Id .. " role")
			t.ok(not seen[pet.Id], pet.Id .. " duplicated")
			seen[pet.Id] = true
			t.ok(pet.Cost >= 0)
		end
		for _, petId in Config.Starter do
			t.ok(seen[petId], "starter " .. petId)
		end
	end)
end
