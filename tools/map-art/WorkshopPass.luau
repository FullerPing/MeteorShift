-- Run after Common.luau in Studio Edit. Saved art only; economy stays unchanged.
local original = Assets:FindFirstChild("PlotStations")
assert(original and original:IsA("Model"), "Missing production template")
local imports = game.ServerStorage:FindFirstChild("ArtImports")
if not imports then imports = Instance.new("Folder"); imports.Name = "ArtImports"; imports.Parent = game.ServerStorage end
local backup = imports:FindFirstChild("WorkshopSourceBackup")
if not backup then
	assert(not original:GetAttribute("WorkshopVersion"), "Original workshop backup is missing")
	backup = original:Clone(); backup.Name = "WorkshopSourceBackup"; backup:SetAttribute("MapArtOwned", true); backup.Parent = imports
end
local t = backup:Clone()
t.Name = "PlotStations"
t:SetAttribute("MapArtOwned", nil)
t:SetAttribute("WorkshopVersion", 1)
for _, node in t:GetDescendants() do
	if node:IsA("ProximityPrompt") and (node.Name == "Upgrade" or node.Name == "ManageRefinery") then node:Destroy() end
end
local transforms = {
	hopper = CFrame.new(16, 0, 13) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.new(17, 0, 6),
	refinery = CFrame.new(16, 0, -15) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.new(-6.5, 0, 6),
	collector = CFrame.new(-9, 0, -15) * CFrame.Angles(0, math.pi, 0) * CFrame.new(-18, 0, 6),
}
local stationModels = { hopper = t.Hopper, conveyor = t.Conveyor, refinery = t.Refinery, collector = t.CollectionPost }
local details = {}
for id, model in stationModels do
	details[id] = group(model, "WorkshopDetails")
end
local input = Instance.new("Model"); input.Name = "InputConveyor"
for _, child in t.Conveyor:GetChildren() do if child ~= details.conveyor then child.Parent = input end end
details.conveyor.Parent = input
input.Parent = t.Conveyor
-- Move earlier foundry detail with its machine, rather than leaving it behind.
for _, node in t.FoundryDetails:GetChildren() do
	local name, id = node.Name, nil
	if name:find("Hopper") or name:find("Intake") then id = "hopper"
	elseif name:find("Belt") or name:find("Roller") or name:find("Motor") then id = "conveyor"
	elseif name:find("Collector") or name:find("Collection") or name:find("Pickup") then id = "collector"
	else id = "refinery" end
	node.Parent = details[id]
end
t.FoundryDetails:Destroy()
for id, delta in transforms do local model = stationModels[id]; model:PivotTo(delta * model:GetPivot()) end
t.Refinery.OutChute.CFrame = CFrame.new(11.3, 1.8, -15) * CFrame.Angles(0, 0, math.rad(15))
t.Hopper.Ore.Transparency = 1
t.Hopper.Ore.CanCollide, t.Hopper.Ore.CanQuery, t.Hopper.Ore.CanTouch = false, false, false
for _, node in t.CollectionPost:GetChildren() do if node.Name == "Bar" then node:Destroy() end end
local output = input:Clone(); output.Name = "OutputConveyor"; output.Parent = t.Conveyor
for _, node in output:GetDescendants() do if node:IsA("ProximityPrompt") or node:IsA("BillboardGui") then node:Destroy() end end
local function beltShape(model, from, to, payload)
	local length, centre = (to - from).Magnitude, (from + to) / 2
	local target = CFrame.lookAt(Vector3.new(centre.X, 0, centre.Z), Vector3.new(to.X, 0, to.Z)) * CFrame.Angles(0, math.pi / 2, 0)
	local source = CFrame.new(-5.5, 0, -6)
	for _, node in model:GetDescendants() do
		if node:IsA("BasePart") then
			local cf = source:ToObjectSpace(node.CFrame)
			node.CFrame = target * CFrame.new(cf.X * length / 14, cf.Y, cf.Z) * cf.Rotation
			if node.Name == "Belt" or node.Name == "Rail" then node.Size = Vector3.new(length, node.Size.Y, node.Size.Z) end
		end
	end
	local belt = model.Belt
	belt:SetAttribute("Payload", payload)
	belt.From.Position = Vector3.new(-length / 2 + 0.7, 0.55, 0)
	belt.To.Position = Vector3.new(length / 2 - 0.7, 0.55, 0)
	model.PrimaryPart = belt
	for i = 1, 3 do
		local x = -length / 2 + i * length / 4
		block(details.conveyor, "FlowStripe", { 0.16, 0.04, 2.4 }, target * CFrame.new(x, 2.62, 0), payload == "ore" and C.cream or C.copper, M.SmoothPlastic)
	end
	return target
end
local inputCf = beltShape(input, Vector3.new(16, 2.4, 8), Vector3.new(16, 2.4, -11), "ore")
local outputCf = beltShape(output, Vector3.new(11.8, 2.4, -15), Vector3.new(-4.8, 2.4, -15), "bar")
t.Conveyor.PrimaryPart = input.Belt
local function visual(parent, name, size, cf, colour, material)
	local p = block(parent, name, size, cf, colour, material)
	p:SetAttribute("BaseTransparency", 0)
	p.Transparency = 1
	return p
end
local function tier(id, level)
	local model = group(stationModels[id], "Tier" .. level)
	model:SetAttribute("UpgradeStation", id)
	model:SetAttribute("MinLevel", level)
	return model
end
-- Each purchased level adds silhouette detail without enlarging collision.
for level = 2, 7 do
	local g = tier("hopper", level)
	local height = 1.1 + (level - 2) * 1.25
	for _, x in { 11.35, 20.65 } do visual(g, "ReinforcedShell", { 0.22, 0.26, 8.2 }, CFrame.new(x, height, 13), if level >= 5 then C.copper else C.metal, M.Metal) end
	if level >= 4 then visual(g, "CapacityHousing", { 2, 0.7, 6.8 }, CFrame.new(16, height, 17.7), C.blue, M.Metal) end
end
for level = 2, 8 do
	local g = tier("conveyor", level)
	for _, cf in { inputCf, outputCf } do
		local x = (level - 5) * 1.7
		visual(g, "DriveHousing", { 1.25, 0.65, 0.95 }, cf * CFrame.new(x, 1.25, 2.25), if level >= 6 then C.copper else C.blue, M.Metal)
		visual(g, "DriveBrace", { 0.2, 1.45, 0.95 }, cf * CFrame.new(x, 1.1, 2.25), C.metal, M.Metal)
	end
end
for level = 2, 8 do
	local g = tier("refinery", level)
	if level <= 4 then
		for _, z in { -18.65, -11.35 } do visual(g, "FurnaceRib", { 7.2, 0.36, 0.28 }, CFrame.new(16, 1.5 + (level - 2) * 2.2, z), C.copper, M.Metal) end
	elseif level <= 6 then
		local x = 20 + (level - 5) * 1.25
		visual(g, "CoolingTank", { 0.85, 5, 0.85 }, CFrame.new(x, 4.5, -15), C.blue, M.Metal)
		visual(g, "PipeBridge", { x - 18.5, 0.28, 0.28 }, CFrame.new((x + 18.5) / 2, 6.7, -15), C.copper, M.Metal)
	else
		visual(g, "TallChimney", { 1.5, 2.8, 1.5 }, CFrame.new(18, 13.7 + (level - 7) * 2.8, -17), C.metal, M.Metal)
		visual(g, "ChimneyBand", { 1.85, 0.3, 1.85 }, CFrame.new(18, 15 + (level - 7) * 2.8, -17), C.copper, M.Metal)
	end
end
for level = 2, 7 do
	local g = tier("collector", level)
	local y = 0.7 + (level - 2) * 1.15
	for _, x in { -13.15, -4.85 } do visual(g, "StorageBrace", { 0.25, 0.25, 7.4 }, CFrame.new(x, y, -15), if level >= 5 then C.copper else C.metal, M.Metal) end
	if level >= 4 then visual(g, "StorageTrim", { 8.4, 0.25, 0.25 }, CFrame.new(-9, y, -18.85), C.blue, M.Metal) end
end
local function stockGroup(parent, kind, id, name)
	local model = group(parent, name)
	model:SetAttribute("StockKind", kind)
	model:SetAttribute("StockType", id)
	return model
end
local function stockLabel(parent, cf)
	local plate = block(parent, "StockPlate", { 2.8, 1.1, 0.1 }, cf, C.dark, M.Metal)
	local gui = Instance.new("SurfaceGui"); gui.Name = "StockReadout"; gui.Face = Enum.NormalId.Front; gui.CanvasSize = Vector2.new(360, 150); gui.LightInfluence = 0; gui.MaxDistance = 70; gui.Parent = plate
	local label = Instance.new("TextLabel"); label.Name = "StockLabel"; label.BackgroundTransparency = 1; label.Size = UDim2.fromScale(1, 1); label.Font = Enum.Font.GothamBold; label.TextSize = 36; label.TextWrapped = true; label.TextColor3 = C.cream; label.Text = "Empty"; label.Parent = gui
end
local function contents(model, kind, centre, step)
	local col, row = (step - 1) % 2, math.floor(((step - 1) % 4) / 2)
	local level = math.floor((step - 1) / 4)
	local p = visual(model, if kind == "ore" then "OreSample" else "BarStack", if kind == "ore" then { 1, 0.65, 1 } else { 1.1, 0.45, 0.85 },
		CFrame.new(centre + Vector3.new((col - 0.5) * 1.2, level * 0.6, (row - 0.5) * 1.1)) * CFrame.Angles(0, if kind == "ore" then step * 0.35 else 0, 0), if kind == "ore" then C.stone else C.copper, if kind == "ore" then M.Slate else M.Metal)
	p:SetAttribute("FillStep", step)
end
local oreProps = group(t.Hopper, "OreCrates")
local barProps = group(t.CollectionPost, "BarRacks")
for index, id in { "iron", "frost", "crystal" } do
	local z = 7.5 + (index - 1) * 4.8
	local crate = stockGroup(oreProps, "ore", id, id .. "Crate")
	block(crate, "CrateFloor", { 3.2, 0.3, 3.2 }, CFrame.new(23, 0.35, z), C.wood, M.WoodPlanks)
	for _, side in { -1, 1 } do
		block(crate, "CrateWall", { 0.22, 1.8, 3.2 }, CFrame.new(23 + side * 1.5, 1.4, z), C.wood, M.WoodPlanks)
		block(crate, "CrateWall", { 2.9, 1.8, 0.22 }, CFrame.new(23, 1.4, z + side * 1.5), C.wood, M.WoodPlanks)
		for _, endSide in { -1, 1 } do block(crate, "CrateCorner", { 0.28, 2, 0.28 }, CFrame.new(23 + side * 1.5, 1.45, z + endSide * 1.5), C.metal, M.Metal) end
	end
	stockLabel(crate, CFrame.new(21.32, 1.4, z) * CFrame.Angles(0, math.pi / 2, 0))
	for step = 1, 8 do contents(crate, "ore", Vector3.new(23, 1.9, z), step) end
	local hopperStock = stockGroup(oreProps, "ore", id, id .. "HopperContents")
	for step = 1, 8 do
		local p = visual(hopperStock, "HopperOre", { 0.65, 0.4, 0.65 }, CFrame.new(14.5 + (index - 1) * 1.5, 6.2 + math.floor((step - 1) / 4) * 0.3, 11.7 + ((step - 1) % 4) * 0.85) * CFrame.Angles(0, step * 0.4, 0), C.stone, M.Slate)
		p:SetAttribute("FillStep", step)
	end
	local rackZ = -19 + (index - 1) * 4.8
	local rack = stockGroup(barProps, "bar", id, id .. "Rack")
	for _, y in { 0.5, 2.7 } do block(rack, "RackShelf", { 3.2, 0.25, 3.2 }, CFrame.new(-20.7, y, rackZ), C.metal, M.Metal) end
	for _, x in { -22.15, -19.25 } do for _, endZ in { rackZ - 1.45, rackZ + 1.45 } do block(rack, "RackUpright", { 0.18, 4.2, 0.18 }, CFrame.new(x, 2.2, endZ), C.blue, M.Metal) end end
	stockLabel(rack, CFrame.new(-18.95, 1.5, rackZ) * CFrame.Angles(0, -math.pi / 2, 0))
	for step = 1, 8 do contents(rack, "bar", Vector3.new(-20.7, 2.95, rackZ), step) end
end
t.WorldPivot = CFrame.new()
-- User's final orientation: 180 degrees total from the original design.
t:PivotTo(CFrame.Angles(0, math.pi, 0))
t.WorldPivot = CFrame.new()
t:SetAttribute("WorkshopYawDegrees", 180)
original:Destroy()
t.Parent = Assets
return { stage = "Workshop", parts = count(t), pivot = tostring(t:GetPivot()), backup = backup:GetFullName() }
