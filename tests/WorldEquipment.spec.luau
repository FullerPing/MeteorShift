--!strict
-- World displays derive identity from Config and effective numbers from State.
return function(t: any)
	local module = t.shared:FindFirstChild("WorldEquipment")
	t.test("world equipment presentation exists", function() t.ok(module, "WorldEquipment missing") end)
	if not module then return end
	local Equipment = require(module)
	local Config = require(t.shared.Config)
	t.test("both walls include all configured tiers and identify current, unlocked and locked", function()
		for _, kind in { "pickaxe", "backpack" } do
			local rows = Equipment.wall(kind, 4)
			local configured = if kind == "pickaxe" then Config.Pickaxes else Config.Backpacks
			t.eq(#rows, #configured)
			t.eq(#rows, 8)
			for index, row in rows do
				t.eq(row.tier, configured[index].Tier)
				t.eq(row.name, configured[index].Name)
				t.eq(row.status, if index == 4 then "CURRENT" elseif index < 4 then "UNLOCKED" else "LOCKED")
			end
		end
	end)
	t.test("first and final tiers mark only one item current", function()
		for _, kind in { "pickaxe", "backpack" } do
			for _, tier in { 1, 8 } do
				local current = 0
				for _, row in Equipment.wall(kind, tier) do if row.status == "CURRENT" then current += 1; t.eq(row.tier, tier) end end
				t.eq(current, 1)
			end
		end
	end)
	t.test("malformed state safely displays basic equipment", function()
		for _, state in { false, true, "state", 17, { pickaxeTier = 0/0, backpackTier = math.huge }, { pickaxeTier = -1, backpackTier = "8" } } do
			t.eq(Equipment.current("pickaxe", state).tier, 1)
			t.eq(Equipment.current("backpack", state).tier, 1)
		end
		t.eq(Equipment.current("pickaxe", nil).tier, 1)
		t.eq(Equipment.current("backpack", nil).stats.capacity, 50)
	end)
	t.test("effective State swing, reach and capacity include owned bonuses", function()
		local state = { pickaxeTier = 4, backpackTier = 3, pickaxeStats = { power = 40, speed = 40, reach = 40, crit = 40 }, swing = 0.33, reach = 19, capacity = 864 }
		local pick = Equipment.current("pickaxe", state)
		local bag = Equipment.current("backpack", state)
		t.eq(pick.name, Config.Pickaxes[4].Name)
		t.eq(pick.stats.swing, 0.33)
		t.eq(pick.stats.reach, 19)
		t.eq(bag.stats.capacity, 864)
		t.ok(pick.stats.power > 1)
	end)
	t.test("new State changes both display identity and derived numbers immediately", function()
		local old = Equipment.current("backpack", { backpackTier = 1, capacity = 50 })
		local new = Equipment.current("backpack", { backpackTier = 8, capacity = 2400 })
		t.eq(old.tier, 1); t.eq(new.tier, 8)
		t.eq(new.name, Config.Backpacks[8].Name)
		t.eq(new.stats.capacity, 2400)
	end)
	t.test("world crit reflects equipped pet State and updates with the loadout", function()
		local state = { pickaxeTier = 1, pets = { bonuses = { crit = 0.12 } } }
		t.near(Equipment.current("pickaxe", state).stats.critChance, 0.12, 1e-6)
		state.pets.bonuses.crit = 0.04
		t.near(Equipment.current("pickaxe", state).stats.critChance, 0.04, 1e-6)
		state.pets.bonuses.crit = 2
		t.eq(Equipment.current("pickaxe", state).stats.critChance, 1)
		for _, pets in { false, { bonuses = false }, { bonuses = { crit = "high" } }, { bonuses = { crit = math.huge } } } do
			t.eq(Equipment.current("pickaxe", { pets = pets }).stats.critChance, 0)
		end
	end)
	t.test("presentation does not mutate State and clamps out-of-range tiers", function()
		local state = { pickaxeTier = 999, pickaxeStats = { power = 2 } }
		local row = Equipment.current("pickaxe", state)
		t.eq(row.tier, #Config.Pickaxes)
		t.eq(state.pickaxeTier, 999)
		t.eq(state.pickaxeStats.power, 2)
		t.eq(state.pickaxeStats.speed, nil)
	end)
	t.test("invalid effective numbers and stat levels never reach world signs", function()
		local pick = Equipment.current("pickaxe", { pickaxeTier = 1, swing = math.huge, reach = -5,
			pickaxeStats = { power = 0/0, speed = "fast", reach = math.huge, crit = -1 } })
		t.eq(pick.stats.power, 1)
		t.eq(pick.stats.swing, 0.6)
		t.eq(pick.stats.reach, 12)
		t.eq(pick.stats.critChance, 0)
		t.eq(Equipment.current("backpack", { backpackTier = 1, capacity = 0/0, backpackStats = false }).stats.capacity, 50)
	end)
end
