--!strict
-- Spec for Shared.Pets: perks by level, XP, slots and the saved-data checks.

return function(t: any)
	local Pets = require(t.shared.Pets)
	local Config = require(t.shared.Config).Pets

	local expected = {
		pebblePup = { { "yield", 0.05, 0.10 } },
		scrapSparrow = { { "scholar", 0.08, 0.16 } },
		packMule = { { "pack", 0.15, 0.30 } },
		sparkHare = { { "swift", 0.05, 0.12 } },
		jetWisp = { { "swift", 0.08, 0.18 }, { "sprint", 0.06, 0.15 } },
		cargoMole = { { "hauler", 0.006, 0.015 }, { "pack", 0.08, 0.18 } },
		coinMagpie = { { "merchant", 0.08, 0.20 } },
		graniteGolem = { { "pack", 0.20, 0.38 }, { "vault", 0.25, 0.60 } },
		crystalStag = { { "crit", 0.04, 0.10 }, { "miner", 0.12, 0.25 } },
		auroraOwl = { { "merchant", 0.12, 0.28 }, { "shards", 0.06, 0.15 } },
		lodeWyrm = { { "hauler", 0.008, 0.02 }, { "vault", 0.35, 0.80 } },
		meteorDrake = { { "miner", 0.22, 0.36 }, { "yield", 0.08, 0.18 }, { "shards", 0.08, 0.20 } },
		cometFox = { { "swift", 0.06, 0.14 }, { "sprint", 0.05, 0.12 } },
		drillbot = { { "miner", 0.25, 0.40 }, { "swift", 0.08, 0.20 }, { "yield", 0.10, 0.20 } },
		solarPhoenix = { { "miner", 0.50, 1.00 }, { "merchant", 0.15, 0.35 }, { "scholar", 0.15, 0.35 } },
	} :: { [string]: { { any } } }

	for petId, perks in expected do
		t.test(petId .. " has the exact level 1 and level 10 perks", function()
			local def = Pets.def(petId) :: any
			t.ok(def and type(def.Perks) == "table", petId .. " has explicit perks")
			t.eq(#def.Perks, #perks)
			local first, last = Pets.perksOf(def, 1), Pets.perksOf(def, 10)
			t.eq(#first, #perks)
			t.eq(#last, #perks)
			for index, perk in perks do
				t.eq(def.Perks[index].Role, perk[1])
				t.near(def.Perks[index].Min, perk[2], 1e-9)
				t.near(def.Perks[index].Max, perk[3], 1e-9)
				t.eq(first[index].role, perk[1])
				t.eq(last[index].role, perk[1])
				t.near(first[index].value, perk[2], 1e-9)
				t.near(last[index].value, perk[3], 1e-9)
			end
		end)
	end

	t.test("the 11 roles carry their display text and caps without shared ranges", function()
		local caps = { miner = 1.5, hauler = 0.03, pack = 0.60, swift = 0.30, merchant = 0.45,
			yield = 0.40, sprint = 0.30, vault = 1, crit = 0.15, scholar = 0.60, shards = 0.30 }
		t.eq(#Config.RoleOrder, 11)
		local seen = {}
		for _, role in Config.RoleOrder do
			local def = Config.Roles[role]
			t.ok(not seen[role], "unique role " .. role)
			seen[role] = true
			t.ok(caps[role] ~= nil and def ~= nil, "known role " .. role)
			t.near(def.Cap, caps[role], 1e-9, role .. " cap")
			t.ok(#def.Name > 0 and string.find(def.Text, "%s", 1, true) ~= nil, role .. " display")
			t.eq(def.Min, nil)
			t.eq(def.Max, nil)
		end
	end)

	t.test("every perk interpolates linearly and clamps outside pet levels", function()
		for _, def in Config.List do
			local first, last = Pets.perksOf(def, -10), Pets.perksOf(def, 99)
			local middle = Pets.perksOf(def, 5.5)
			for index, perk in def.Perks do
				t.near(first[index].value, perk.Min, 1e-9)
				t.near(last[index].value, perk.Max, 1e-9)
				t.near(middle[index].value, (perk.Min + perk.Max) / 2, 1e-9)
				local previous = 0
				for level = 1, Config.MaxLevel do
					local value = Pets.perksOf(def, level)[index].value
					t.ok(value > previous, def.Id .. " " .. perk.Role .. " rises")
					previous = value
				end
			end
		end
	end)

	t.test("premium pets retain fixed passes priced by Config.Monetization", function()
		-- the shop reads the price from Config.Monetization via the pet's Pass key (PetsController), so no number is hard-coded here
		for _, petId in { "drillbot", "solarPhoenix" } do
			local def = Pets.def(petId) :: any
			t.eq(def.Rarity, "premium")
			local pass = require(t.shared.Config).Monetization.Passes[def.Pass]
			t.ok(pass ~= nil, petId .. " pass exists in Config.Monetization")
			t.ok(pass ~= nil and (pass.Robux or 0) > 0, petId .. " price comes from Config.Monetization")
		end
	end)

	t.test("slots start at 1 and grow with rebirths up to the max", function()
		t.eq(Pets.slots(0), 1)
		t.eq(Pets.slots(1), 2)
		t.eq(Pets.slots(2), 3)
		t.eq(Pets.slots(Config.Slots.ExtraAtRebirth - 1), Config.Slots.Max)
		t.eq(Pets.slots(Config.Slots.ExtraAtRebirth), Config.Slots.Max + 1, "one more slot at rebirth 4")
		t.eq(Pets.slots(50), Config.Slots.Max + 1)
		t.eq(Pets.slots(nil), 1)
	end)

	t.test("Pet Bond adds its slots on top", function()
		t.eq(Pets.slots(0, false, 2), 3)
		t.eq(Pets.slots(50, true, 2), Config.Slots.Max + 1 + 1 + 2)
		t.eq(Pets.slots(0, false, -3), 1)
	end)

	t.test("ExtraPetSlot adds one permanent slot after the rebirth cap", function()
		t.eq(Pets.slots(nil, true), 2)
		t.eq(Pets.slots(1, true), 3)
		t.eq(Pets.slots(2, true), 4)
		t.eq(Pets.slots(50, true), 5)
		t.eq(Pets.slots(-5, true), 2)
		t.eq(Pets.slots(2, false), 3)
	end)

	t.test("miner activity requires a real validated swing inside its recent window", function()
		t.ok(type(Pets.minerActive) == "function", "miner activity validates timestamps")
		t.eq(Pets.minerActive(nil, 5), false, "fresh server without a swing")
		t.eq(Pets.minerActive(-math.huge, 5), false, "missing Node timestamp")
		t.eq(Pets.minerActive(math.huge, 5), false)
		t.eq(Pets.minerActive(0 / 0, 5), false)
		t.eq(Pets.minerActive(10, 9), false, "future swing")
		t.eq(Pets.minerActive(10, math.huge), false)
		t.eq(Pets.minerActive(10, -math.huge), false)
		t.eq(Pets.minerActive(10, 0 / 0), false)
		t.eq(Pets.minerActive(10, 24.999), true, "just inside 15 seconds")
		t.eq(Pets.minerActive(10, 25), true, "window boundary stays inclusive")
		t.eq(Pets.minerActive(10, 25.001), false, "just outside 15 seconds")
		t.eq(Pets.minerActive(10, 10), true, "the validated swing itself")
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
		t.near(bonuses.swift, 0.08, 1e-9)
		t.near(bonuses.yield, 0.10, 1e-9)
		t.eq(bonuses.sprint, 0)
		t.eq(bonuses.vault, 0)
		t.eq(bonuses.crit, 0)
		t.eq(bonuses.scholar, 0)
		t.eq(bonuses.shards, 0)
		saved.equipped = { "drillbot", "drillbot", "ghost" }
		t.near(Pets.bonuses(saved).miner, 0.25, 1e-9, "one copy only counts once, unknown pets never")
		saved.owned.drillbot.copies = 2
		t.near(Pets.bonuses(saved).miner, 0.50, 1e-9, "two copies out count twice")
		saved.equipped = { "coinMagpie", "jetWisp" }
		t.eq(Pets.bonuses(saved).swift, 0, "unowned pets do not count")
	end)

	t.test("equipped perks add independently and stop at every reachable cap", function()
		local saved = { owned = {}, equipped = {} }
		for _, def in Config.List do
			saved.owned[def.Id] = { level = 10, xp = 0 }
			table.insert(saved.equipped, def.Id)
		end
		local bonuses = Pets.bonuses(saved)
		-- every pet at level 10: each role is its pets' sum, stopped at the role's cap
		local sums = {}
		for _, def in Config.List do
			for _, perk in def.Perks do sums[perk.Role] = (sums[perk.Role] or 0) + perk.Max end
		end
		for _, role in Config.RoleOrder do
			t.near(bonuses[role], math.min(sums[role] or 0, Config.Roles[role].Cap), 1e-9, role)
		end
		t.near(bonuses.miner, 1.5, 1e-9, "miner reaches its cap")
		local empty = Pets.bonuses(Pets.fresh())
		for _, role in Config.RoleOrder do
			t.eq(empty[role], 0, "empty " .. role)
		end
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

	t.test("copies: duplicates are extra copies, and no more are out than owned", function()
		t.eq(Pets.copies(nil), 0)
		t.eq(Pets.copies({ level = 1, xp = 0 }), 1)
		t.eq(Pets.copies({ level = 1, xp = 0, copies = 3.7 }), 3)
		t.eq(Pets.copies({ level = 1, xp = 0, copies = 0 / 0 }), 1)
		local cleaned = Pets.clean({
			owned = { packMule = { level = 4, xp = 0, copies = 2 }, jetWisp = { level = 1, xp = 0, copies = -5 } },
			equipped = { "packMule", "packMule", "packMule", "jetWisp", "jetWisp" },
		}, 4)
		t.eq(cleaned.owned.packMule.copies, 2)
		t.eq(cleaned.owned.jetWisp.copies, nil, "a single copy saves as nil")
		t.eq(Pets.outCount(cleaned.equipped, "packMule"), 2)
		t.eq(Pets.outCount(cleaned.equipped, "jetWisp"), 1)
		t.eq(Pets.cloneOwned(cleaned.owned).packMule.copies, 2)
	end)

	t.test("clean preserves a fourth owned pet when ExtraPetSlot is validated", function()
		local saved = { owned = {}, equipped = { "packMule", "jetWisp", "coinMagpie", "cargoMole", "graniteGolem" } }
		for _, petId in saved.equipped do
			saved.owned[petId] = { level = 1, xp = 0 }
		end
		local paid = Pets.clean(saved, 2, true)
		t.eq(#paid.equipped, 4)
		t.eq(paid.equipped[4], "cargoMole")
		t.eq(#Pets.clean(saved, 2, false).equipped, 3)
	end)

	t.test("clean repairs egg pity counts without retaining unknown eggs", function()
		local cleaned = Pets.clean({
			owned = {}, equipped = {},
			hatches = { meteorEgg = 4.8, crystalEgg = -3, ghostEgg = 9 },
		}, 0)
		t.eq(cleaned.hatches.meteorEgg, 4)
		t.eq(cleaned.hatches.crystalEgg, 0)
		t.eq(cleaned.hatches.ghostEgg, nil)
	end)

	t.test("every pet in the catalog has a known role and unique id", function()
		local seen = {}
		for _, pet in Config.List do
			for _, perk in pet.Perks do
				t.ok(Config.Roles[perk.Role] ~= nil, pet.Id .. " role")
			end
			t.ok(not seen[pet.Id], pet.Id .. " duplicated")
			seen[pet.Id] = true
		end
		for _, petId in Config.Starter do
			t.ok(seen[petId], "starter " .. petId)
		end
	end)

	t.test("the group reward is a Rare no egg drops, and points at the owner's group", function()
		local reward = Config.GroupReward
		local def = Pets.def(reward.Pet) :: any
		t.ok(def ~= nil and def.Group == true, "the reward pet is marked Group")
		t.eq(def.Rarity, "rare")
		t.eq(table.find(Pets.eggPets("rare"), def), nil, "never hatches")
		t.eq(reward.GroupId, 526085770, "the owner's group")
	end)

	t.test("the 24 pets have the perk counts required by their rarity", function()
		t.eq(#Config.List, 24)
		for _, pet in Config.List do
			t.ok(Config.Rarities[pet.Rarity] ~= nil, pet.Id .. " rarity")
			local count = #pet.Perks
			if pet.Rarity == "rare" then
				t.ok(count == 1 or count == 2, pet.Id .. " rare count")
			else
				local counts = { common = 1, uncommon = 1, epic = 2, legendary = 3, premium = 3 }
				t.eq(count, counts[pet.Rarity], pet.Id .. " count")
			end
			t.eq(pet.Role, nil)
			t.eq(pet.Power, nil)
			t.eq(pet.Range, nil)
		end
	end)

	t.test("eggs: odds add up to 100 and every rarity they name has pets to hatch", function()
		for _, egg in Config.Eggs do
			local total = 0
			for rarity, odds in egg.Odds do
				total += odds
				t.ok(#Pets.eggPets(rarity, egg) > 0, egg.Id .. " has no " .. rarity .. " pets")
			end
			t.near(total, 100, 1e-9, egg.Id)
			t.ok(egg.Cost > 0 and egg.Pity > 0)
		end
	end)

	t.test("the paid pets are never in an egg and match or beat free pets at both endpoints", function()
		for _, pet in Config.List do
			if pet.Pass then
				t.eq(pet.Rarity, "premium")
				for _, other in Config.List do
					if not other.Pass then
						for _, paidPerk in pet.Perks do
							for _, freePerk in other.Perks do
								if paidPerk.Role == freePerk.Role then
									t.ok(paidPerk.Min >= freePerk.Min and paidPerk.Max > freePerk.Max, pet.Id .. " " .. paidPerk.Role .. " vs " .. other.Id)
								end
							end
						end
					end
				end
			end
		end
		for rarity in Config.Rarities do
			for _, pet in Pets.eggPets(rarity) do
				t.ok(pet.Pass == nil)
			end
		end
		t.ok(Pets.perksOf(Pets.def("solarPhoenix") :: any, 1)[1].value > Pets.perksOf(Pets.def("drillbot") :: any, 1)[1].value)
	end)

	t.test("the strongest level 10 perk never falls as rarity rises where that role exists", function()
		for _, role in Config.RoleOrder do
			local previous = 0
			for _, rarity in Config.RarityOrder do
				local strongest = 0
				for _, pet in Config.List do
					if pet.Rarity == rarity then
						for _, perk in pet.Perks do
							if perk.Role == role then strongest = math.max(strongest, perk.Max) end
						end
					end
				end
				if strongest > 0 then
					t.ok(strongest >= previous, rarity .. " " .. role .. " should not fall")
					previous = strongest
				end
			end
		end
	end)

	t.test("roll follows the odds bands and picks inside the rarity", function()
		local egg = Config.Eggs[1]
		local id = Pets.roll(egg, 0, 0, 0)
		t.eq(Pets.def(id).Rarity, "common")
		local legendary = Pets.roll(egg, 0.9999, 0, 0)
		t.eq(Pets.def(legendary).Rarity, "legendary")
		local first = Pets.roll(egg, 0, 0, 0)
		local last = Pets.roll(egg, 0, 0, 0.9999)
		t.ok(first ~= last, "pick moves through the rarity's pets")
	end)

	t.test("both eggs retain their costs, odds, pity and deterministic catalog picks", function()
		local meteor, crystal = Pets.egg("meteorEgg"), Pets.egg("crystalEgg")
		t.eq(meteor.Cost, 15)
		t.eq(meteor.Pity, 40)
		t.eq(crystal.Cost, 60)
		t.eq(crystal.Pity, 15)
		t.eq(meteor.PityFrom, "epic")
		t.eq(crystal.PityFrom, "epic")
		for rarity, odds in { common = 60, uncommon = 28, rare = 9.5, epic = 2.25, legendary = 0.25 } do
			t.eq(meteor.Odds[rarity], odds)
		end
		for rarity, odds in { uncommon = 40, rare = 42, epic = 15.5, legendary = 2.5 } do
			t.eq(crystal.Odds[rarity], odds)
		end
		t.eq(crystal.Odds.common, nil)
		t.eq(meteor.Odds.premium, nil)
		t.eq(crystal.Odds.premium, nil)
		for _, case in { { 0, "pebblePup" }, { 0.61, "packMule" }, { 0.89, "jetWisp" }, { 0.98, "crystalStag" }, { 0.999, "meteorDrake" } } do
			t.eq(Pets.roll(meteor, case[1], 0, 0), case[2])
		end
		t.eq(Pets.roll(meteor, 0.89, 0, 0.999), "nebulaJelly")
		t.eq(Pets.roll(meteor, 0.98, 0, 0.999), "auroraOwl")
		for _, case in { { 0, "packMule" }, { 0.41, "jetWisp" }, { 0.83, "crystalStag" }, { 0.99, "meteorDrake" } } do
			t.eq(Pets.roll(crystal, case[1], 0, 0), case[2])
		end
	end)

	t.test("pity: the Pity-th hatch is Epic or better and the count resets on one", function()
		local egg = Config.Eggs[1]
		local _, afterCommon = Pets.roll(egg, 0, 0, 0)
		t.eq(afterCommon, 1)
		local id, reset = Pets.roll(egg, 0, egg.Pity - 1, 0)
		local rarity = Pets.def(id).Rarity
		t.ok(rarity == "epic" or rarity == "legendary", "pity gave " .. rarity)
		t.eq(reset, 0)
		local _, epicReset = Pets.roll(egg, 0.98, 3, 0) -- an Epic by luck resets too
		t.eq(epicReset, 0)
	end)

	t.test("simulated hatching never goes past the pity count without an Epic and matches the odds", function()
		local egg = Config.Eggs[1]
		local seed, pity, drought, longest = 12345, 0, 0, 0
		local counts = { common = 0 }
		local function rand()
			seed = (seed * 1103515245 + 12345) % 2147483648
			return seed / 2147483648
		end
		local n = 20000
		for _ = 1, n do
			local id, nextPity = Pets.roll(egg, rand(), pity, rand())
			pity = nextPity
			local rarity = Pets.def(id).Rarity
			counts[rarity] = (counts[rarity] or 0) + 1
			drought = if rarity == "epic" or rarity == "legendary" then 0 else drought + 1
			longest = math.max(longest, drought)
		end
		t.ok(longest < egg.Pity, "longest drought " .. longest)
		t.ok(math.abs(counts.common / n - 0.60) < 0.03, "common share " .. counts.common / n)
	end)

	t.test("the Solar Phoenix keeps its exact 50% to 100% miner perk", function()
		local saved = { owned = { solarPhoenix = { level = 1, xp = 0 } }, equipped = { "solarPhoenix" } }
		t.near(Pets.bonuses(saved).miner, 0.5, 1e-9)
		saved.owned.solarPhoenix.level = Config.MaxLevel
		t.near(Pets.bonuses(saved).miner, 1.0, 1e-9)
	end)

	t.test("egg exclusives hatch only from their own eggs, and own eggs hatch only exclusives", function()
		for _, egg in Config.Eggs do
			for rarity in egg.Odds do
				for _, pet in Pets.eggPets(rarity, egg) do
					if egg.Own then
						t.ok(pet.Eggs ~= nil and table.find(pet.Eggs, egg.Id) ~= nil, pet.Id .. " in " .. egg.Id)
					else
						t.eq(pet.Eggs, nil, pet.Id .. " is exclusive but hatches from " .. egg.Id)
					end
				end
			end
		end
		-- every exclusive pet can hatch from an egg that lists it, at its rarity
		for _, pet in Config.List do
			if pet.Eggs then
				for _, eggId in pet.Eggs do
					local egg = Pets.egg(eggId)
					t.ok(egg ~= nil and (egg.Odds[pet.Rarity] or 0) > 0, pet.Id .. " has no way to hatch from " .. eggId)
				end
			end
		end
		local magma = Pets.egg("magmaEgg") :: any
		local id = Pets.roll(magma, 0.99, 0, 0)
		t.eq(id, "galaxyGriffin")
	end)
end
