--!strict
return function(t: any)
	local Refining = require(t.lib.Refining)
	local function line(): any
		return { stations = { hopper = 1, conveyor = 1, refinery = 1, collector = 1 }, hopper = {}, bin = {}, progress = 0 }
	end
	t.test("vault multiplies both station capacities while defaults stay unchanged", function()
		local data = line()
		t.eq(Refining.hopperCapacity(data), 2000)
		t.eq(Refining.collectorCapacity(data), 2000)
		t.eq(Refining.hopperCapacity(data, 1.6), 3200)
		t.eq(Refining.collectorCapacity(data, 2), 4000)
	end)
	t.test("offline and online runs use the same vault storage limit", function()
		local offline, online = line(), line()
		offline.hopper.iron, online.hopper.iron = 5000, 5000
		local _, made = Refining.run(offline, 20000, nil, 2)
		for _ = 1, 200 do Refining.run(online, 100, nil, 2) end
		t.eq(made, 4000)
		t.eq(online.bin.iron, offline.bin.iron)
		t.eq(online.hopper.iron, offline.hopper.iron)
	end)
	t.test("sprint restores its own bonus and adopts externally changed speed", function()
		local module = t.shared:FindFirstChild("CharacterSpeed")
		t.ok(module, "Shared.CharacterSpeed exists")
		local Speed = require(module)
		local speed, base = Speed.update(16, nil, nil, .15)
		t.near(speed, 18.4, 1e-9)
		t.eq(base, 16)
		local restored = Speed.update(speed, speed, base, 0)
		t.eq(restored, 16)
		local adopted, newBase = Speed.update(24, speed, base, .3)
		t.near(adopted, 28.8, 1e-9)
		t.eq(newBase, 24)
		t.eq(Speed.update(adopted, adopted, newBase, 0), 24)
	end)
end
