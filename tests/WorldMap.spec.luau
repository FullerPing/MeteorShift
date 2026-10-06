--!strict
return function(t: any)
	local module = t.shared:FindFirstChild("WorldMap")
	t.test("world root selection exists", function() t.ok(module, "WorldMap missing") end)
	if not module then return end
	local WorldMap = require(module)
	local function fixture()
		local map = Instance.new("Folder")
		local town = Instance.new("Folder"); town.Name = "TownSquare"; town.Parent = map
		local building = Instance.new("Model"); building.Name = "Refinery"; building.Parent = town
		local point = Instance.new("Part"); point.Name = "UsePoint"; point.Position = Vector3.new(0, 3, 2620); point.Parent = building
		local character = Instance.new("Model")
		local root = Instance.new("Part"); root.Name = "HumanoidRootPart"; root.Position = point.Position; root.Parent = character
		local humanoid = Instance.new("Humanoid"); humanoid.Parent = character
		return map, character, root, humanoid, point
	end
	t.test("refinery menu permits a living character through the 18 stud boundary", function()
		local map, character, root, _, point = fixture()
		t.ok(WorldMap.canUseRefinery(map, character))
		root.Position = point.Position + Vector3.new(18, 0, 0)
		t.ok(WorldMap.canUseRefinery(map, character))
		root.Position = point.Position + Vector3.new(18.01, 0, 0)
		t.eq(WorldMap.canUseRefinery(map, character), false)
		root.Position = point.Position + Vector3.new(0, 19, 0)
		t.eq(WorldMap.canUseRefinery(map, character), false)
		map:Destroy(); character:Destroy()
	end)
	t.test("refinery menu rejects missing and dead characters", function()
		local map, character, root, humanoid = fixture()
		t.eq(WorldMap.canUseRefinery(map, nil), false)
		humanoid.Health = 0
		t.eq(WorldMap.canUseRefinery(map, character), false)
		humanoid.Health = 100; root:Destroy()
		t.eq(WorldMap.canUseRefinery(map, character), false)
		map:Destroy(); character:Destroy()
	end)
	t.test("refinery menu never authorizes an unrelated or missing world point", function()
		local map, character, _, _, point = fixture()
		t.eq(WorldMap.canUseRefinery(nil, character), false)
		point.Name = "Body"
		t.eq(WorldMap.canUseRefinery(map, character), false)
		map:Destroy(); character:Destroy()
	end)
	t.test("production ignores the development map override", function()
		t.eq(WorldMap.name(false, "Map_Redesign"), "Map")
		t.eq(WorldMap.name(true, "Map_Redesign"), "Map_Redesign")
		for _, value in { true, false, 1, "", "Map_Old", "Other" } do t.eq(WorldMap.name(true, value), "Map") end
		t.eq(WorldMap.name(true, nil), "Map")
	end)
	t.test("shared refinery requires its exact UsePoint with no part fallback", function()
		local root = Instance.new("Folder")
		local town = Instance.new("Folder"); town.Name = "TownSquare"; town.Parent = root
		local refinery = Instance.new("Model"); refinery.Name = "Refinery"; refinery.Parent = town
		local body = Instance.new("Part"); body.Name = "Body"; body.Parent = refinery; refinery.PrimaryPart = body
		t.eq(WorldMap.refineryPoint(root), nil)
		local point = Instance.new("Part"); point.Name = "UsePoint"; point.Parent = refinery
		t.eq(WorldMap.refineryPoint(root), point)
		root:Destroy()
	end)
end
