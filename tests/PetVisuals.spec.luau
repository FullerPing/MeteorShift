--!strict
-- The client bounds work and input blocking even when replicated attributes arrive apart.
return function(t: any)
	local module = t.shared:FindFirstChild("PetVisuals")
	t.test("pet visual rules are available", function()
		t.ok(module ~= nil, "Shared.PetVisuals is present")
	end)
	if not module then return end
	local Visuals = require(module)

	t.test("loadout ignores unknown and repeated ids and clamps levels", function()
		local loadout = Visuals.loadout("pebblePup,unknown,pebblePup,jetWisp,cargoMole,drillbot", "0,4,5,99,bad,10", 4)
		t.eq(#loadout, 4)
		t.eq(loadout[1].id, "pebblePup")
		t.eq(loadout[1].level, 1)
		t.eq(loadout[2].id, "jetWisp")
		t.eq(loadout[2].level, 10)
		t.eq(loadout[3].id, "cargoMole")
		t.eq(loadout[3].level, 1)
		t.eq(loadout[4].slot, 4)
	end)

	t.test("ordinary loadouts never exceed three and the extra slot never exceeds four", function()
		local ids = "pebblePup,scrapSparrow,packMule,sparkHare,jetWisp"
		t.eq(#Visuals.loadout(ids, nil, nil), 3)
		t.eq(#Visuals.loadout(ids, nil, 3), 3)
		t.eq(#Visuals.loadout(ids, nil, 4), 4)
		t.eq(#Visuals.loadout(ids, nil, 99), 4)
		t.eq(#Visuals.loadout(ids, nil, 1), 1)
		t.eq(#Visuals.loadout(nil, "1", 4), 0)
	end)

	t.test("selection culls beyond 150 studs and prioritizes the local player then distance", function()
		local picked = Visuals.select({
			{ userId = 3, distance = 150.01, count = 3 },
			{ userId = 4, distance = 150, count = 3 },
			{ userId = 5, distance = 2, count = 3 },
			{ userId = 1, distance = 8, count = 4 },
		}, 1, 8)
		t.eq(#picked, 8)
		t.eq(picked[1].userId, 1)
		t.eq(picked[4].slot, 4)
		t.eq(picked[5].userId, 5)
		t.eq(picked[8].userId, 4)
		for _, entry in picked do t.ok(entry.userId ~= 3, "far player is culled") end
	end)

	t.test("the global model budget is forty even when all players own four slots", function()
		local candidates = {}
		for id = 1, 30 do table.insert(candidates, { userId = id, distance = id, count = 4 }) end
		local picked = Visuals.select(candidates, 30, 999)
		t.eq(#picked, 40)
		t.eq(picked[1].userId, 30)
		t.eq(#Visuals.select(candidates, 30, 39), 39, "hatch preview can reserve a model")
		t.eq(#Visuals.select(candidates, 30, 0), 0)
	end)

	t.test("equal-distance selection is deterministic and never mutates candidates", function()
		local candidates = {
			{ userId = 9, distance = 10, count = 3 },
			{ userId = 4, distance = 10, count = 3 },
		}
		local picked = Visuals.select(candidates, 99, 3)
		t.eq(picked[1].userId, 4)
		t.eq(candidates[1].userId, 9)
	end)

	t.test("hatch wobbles for 1.5 seconds and releases input by two seconds", function()
		t.eq(Visuals.hatchStage(0, false), "wobble")
		t.eq(Visuals.hatchStage(1.49, false), "wobble")
		t.eq(Visuals.hatchStage(1.5, false), "reveal")
		t.eq(Visuals.hatchStage(2, false), "settled")
		t.ok(Visuals.hatchBlocking(1.99))
		t.ok(not Visuals.hatchBlocking(2))
		t.eq(Visuals.hatchStage(0, true), "reveal", "reduced effects skips motion")
	end)
end
