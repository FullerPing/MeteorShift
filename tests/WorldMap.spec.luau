--!strict
return function(t: any)
	local module = t.shared:FindFirstChild("WorldMap")
	t.test("world root selection exists", function() t.ok(module, "WorldMap missing") end)
	if not module then return end
	local WorldMap = require(module)
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
