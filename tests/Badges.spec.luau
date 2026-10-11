--!strict
return function(t: any)
	local module = t.lib:FindFirstChild("Badges")
	t.test("badge library exists", function() t.ok(module, "Lib.Badges missing") end)
	if not module then return end
	local Badges = require(module)
	local Config = require(t.shared.Config)

	t.test("pick returns an id only when it is on and not yet given", function()
		local ids = { firstMeteor = 123, off = 0, bad = -4, fraction = 1.5 }
		t.eq(Badges.pick(ids, "firstMeteor", {}), 123)
		t.eq(Badges.pick(ids, "firstMeteor", { firstMeteor = true }), nil, "given this session")
		t.eq(Badges.pick(ids, "off", {}), nil, "id 0 is off")
		t.eq(Badges.pick(ids, "bad", {}), nil)
		t.eq(Badges.pick(ids, "fraction", {}), nil)
		t.eq(Badges.pick(ids, "missing", {}), nil)
	end)

	t.test("every shipped badge key is a known one with a whole, non-negative id", function()
		local keys = { "firstMeteor", "firstCore", "firstRebirth", "rebirth10", "level25", "level50", "pageIron", "pageIce",
			"pageCrystal", "legendaryPet", "streak7" }
		for _, key in keys do t.ok(Config.Badges[key] ~= nil, key .. " missing from Config.Badges") end
		for key, id in Config.Badges do
			t.ok(table.find(keys, key), key .. " is not a known badge key")
			t.ok(type(id) == "number" and id >= 0 and id == math.floor(id), key .. " id")
		end
	end)
end
