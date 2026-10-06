--!strict
return function(t: any)
	local module = t.shared:FindFirstChild("WorldImpact")
	t.test("grounded impact evacuation exists", function() t.ok(module, "WorldImpact missing") end)
	if not module then return end
	local Impact = require(module)
	local function fixture()
		local map = Instance.new("Model"); map.Name = "ImpactTest"; map.Parent = workspace
		local ground = Instance.new("Model"); ground.Name = "Ground"; ground.Parent = map
		local floor = Instance.new("Part"); floor.Anchored = true; floor.Size = Vector3.new(200, 2, 200)
		floor.Position = Vector3.new(20000, -11, 20000); floor.Parent = ground
		return map, Vector3.new(20000, 5.3, 20000)
	end
	t.test("impact moves a central character outside the doubled footprint onto ground", function()
		local map, impact = fixture()
		local result = Impact.destination(map, impact, Vector3.new(20000, -40, 20000), 3.5)
		t.ok(result); t.near(result.X, 20060, 0.01); t.near(result.Y, -6.5, 0.01); t.near(result.Z, 20000, 0.01)
		map:Destroy()
	end)
	t.test("impact does not move characters outside its footprint", function()
		local map, impact = fixture()
		t.eq(Impact.destination(map, impact, impact + Vector3.new(52, 0, 0), 3.5), nil)
		map:Destroy()
	end)
	t.test("impact ignores active meteors when choosing the landing surface", function()
		local map, impact = fixture()
		local crater = Instance.new("Model"); crater.Name = "Crater"; crater.Parent = map
		local active = Instance.new("Folder"); active.Name = "ActiveMeteor"; active.Parent = crater
		local core = Instance.new("Part"); core.Anchored = true; core.Size = Vector3.new(200, 2, 200)
		core.Position = Vector3.new(20000, 80, 20000); core.Parent = active
		local result = Impact.destination(map, impact, impact + Vector3.new(0, 0, -1), 3.5)
		t.ok(result); t.near(result.Z, 19940, 0.01); t.near(result.Y, -6.5, 0.01)
		map:Destroy()
	end)
	t.test("impact rejects an ungrounded destination", function()
		local map, impact = fixture(); map.Ground:Destroy()
		t.eq(Impact.destination(map, impact, impact, 3.5), nil)
		map:Destroy()
	end)
end
