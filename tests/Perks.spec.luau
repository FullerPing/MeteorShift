--!strict
-- Spec for Shared.Perks: Colony Perk levels, prices and effects. Values come from Config.Perks.

return function(t: any)
	local Perks = require(t.shared.Perks)
	local Config = require(t.shared.Config)
	local Settings = Config.Perks

	t.test("a fresh table has every perk at level 0 and clean repairs bad saves", function()
		local fresh = Perks.fresh()
		for _, id in Settings.Order do t.eq(fresh[id], 0, id) end
		local cleaned = Perks.clean({ headStart = 99, efficientLine = -4, stationMemory = 1.7, junk = 5, petBond = "x" })
		t.eq(cleaned.headStart, #Settings.List.headStart.Costs)
		t.eq(cleaned.efficientLine, 0)
		t.eq(cleaned.stationMemory, 1)
		t.eq(cleaned.petBond, 0)
		t.eq((cleaned :: any).junk, nil)
		t.eq(Perks.clean(nil).headStart, 0)
	end)

	t.test("every perk has rising costs and effects, one effect per level", function()
		for _, id in Settings.Order do
			local def = Settings.List[id]
			t.eq(#def.Effect, #def.Costs, id)
			for level = 2, #def.Costs do
				t.ok(def.Costs[level] > def.Costs[level - 1], id .. " level " .. level)
				t.ok(def.Effect[level] > def.Effect[level - 1], id .. " effect " .. level)
			end
		end
	end)

	t.test("nextCost walks the list and ends at nil", function()
		local owned = Perks.fresh()
		t.eq(Perks.nextCost(owned, "petBond"), Settings.List.petBond.Costs[1])
		owned.petBond = 2
		t.eq(Perks.nextCost(owned, "petBond"), nil)
		t.eq(Perks.maxLevel("petBond"), 2)
	end)

	t.test("the panel opens at the configured rebirth", function()
		t.eq(Perks.unlocked(Settings.UnlockRebirths - 1), false)
		t.eq(Perks.unlocked(Settings.UnlockRebirths), true)
		t.eq(Perks.unlocked(nil), false)
	end)

	t.test("effects read zero when not bought and the level value when bought", function()
		local owned = Perks.fresh()
		t.eq(Perks.lineMult(owned), 1)
		t.eq(Perks.offlineBonus(owned), 0)
		t.eq(Perks.petSlots(owned), 0)
		owned.efficientLine, owned.offlineTraining, owned.petBond = 5, 2, 1
		t.near(Perks.lineMult(owned), 1.2, 1e-9)
		t.eq(Perks.offlineBonus(owned), 80 * 60)
		t.eq(Perks.petSlots(owned), 1)
		t.eq(Perks.lineMult(nil), 1)
	end)

	t.test("Station Memory keeps a share of the levels and never drops below 1", function()
		local owned = Perks.fresh()
		t.eq(Perks.keptStation(owned, 9), 1)
		owned.stationMemory = 2 -- 50%
		t.eq(Perks.keptStation(owned, 9), 5)
		owned.stationMemory = 4 -- 100%
		t.eq(Perks.keptStation(owned, 9), 9)
		t.eq(Perks.keptStation(owned, 0), 1)
	end)

	t.test("Head Start raises the start tier but holds it to the player level", function()
		local owned = Perks.fresh()
		local function gate(tier: number): number return ({ 1, 1, 1, 1, 10, 16, 24, 34 })[tier] end
		t.eq(Perks.startTier(owned, 50, 8, gate), 1)
		owned.headStart = 3
		t.eq(Perks.startTier(owned, 50, 8, gate), 4)
		owned.headStart = 4
		t.eq(Perks.startTier(owned, 50, 8, gate), 5)
		t.eq(Perks.startTier(owned, 5, 8, gate), 4, "level 5 cannot wield tier 5 yet")
		t.eq(Perks.startTier(owned, 50, 3, gate), 3, "capped by the highest tier")
	end)
end
