-- Read-only saved workshop contract. Run in Studio Edit after WorkshopPass.
local t = game.ServerStorage.Assets.PlotStations
local checks = 0
local function check(condition, message) checks += 1; assert(condition, message) end
check(t:GetAttribute("WorkshopVersion") == 1, "L-shaped workshop has not been authored")
local stationIds = {}
for _, node in t:GetChildren() do
	local id = node:GetAttribute("StationId")
	if id then check(not stationIds[id], "duplicate station upgrade"); stationIds[id] = node end
end
for _, id in { "hopper", "conveyor", "refinery", "collector" } do check(stationIds[id] ~= nil, "missing " .. id) end
local pivot = t:GetPivot()
check(t:GetAttribute("WorkshopYawDegrees") == 180, "workshop must rotate 180 degrees in total")
local designFrame = pivot * CFrame.Angles(0, math.pi, 0)
local hopper = designFrame:PointToObjectSpace(t.Hopper.Body.Position)
local furnace = designFrame:PointToObjectSpace(t.Refinery.Furnace.Position)
local collector = designFrame:PointToObjectSpace(t.CollectionPost.Crate.Position)
check(math.abs(hopper.X - furnace.X) < 0.01 and hopper.Z > furnace.Z + 20, "input is not vertical")
check(collector.X < furnace.X - 20 and math.abs(collector.Z - furnace.Z) < 1, "output is not leftward")
for _, spec in { { "InputConveyor", "ore" }, { "OutputConveyor", "bar" } } do
	local model = t.Conveyor:FindFirstChild(spec[1])
	check(model and model:IsA("Model"), "missing " .. spec[1])
	local belt = model:FindFirstChild("Belt")
	check(belt and belt:IsA("BasePart") and belt:GetAttribute("Payload") == spec[2], "belt payload contract")
	check(belt:FindFirstChild("From") and belt:FindFirstChild("To"), "missing belt endpoints")
	local delta = designFrame:VectorToObjectSpace(belt.To.WorldPosition - belt.From.WorldPosition)
	check(if spec[2] == "ore" then delta.Z < -10 and math.abs(delta.X) < 0.1 else delta.X < -10 and math.abs(delta.Z) < 0.1, "belt flows in wrong direction")
end
check(t.Hopper.Intake.CanTouch and t.CollectionPost.Bin.CanTouch, "working pads lost touch")
local upgrades, stock, labels, parts = {}, {}, 0, 0
for _, node in t:GetDescendants() do
	if node:IsA("ProximityPrompt") then check(node.Name ~= "Upgrade", "station upgrade prompt remains") end
	if node:IsA("Model") and node:GetAttribute("UpgradeStation") then
		upgrades[node:GetAttribute("UpgradeStation")] = (upgrades[node:GetAttribute("UpgradeStation")] or 0) + 1
	end
	if node:IsA("Model") and node:GetAttribute("StockKind") then
		local key = node:GetAttribute("StockKind") .. ":" .. node:GetAttribute("StockType")
		stock[key] = true
		local steps = {}
		for _, item in node:GetDescendants() do if item:IsA("BasePart") and item:GetAttribute("FillStep") then steps[item:GetAttribute("FillStep")] = true end end
		for i = 1, 8 do check(steps[i], "stock has no fill step " .. i) end
	end
	if node:IsA("TextLabel") and node.Name == "StockLabel" then labels += 1 end
	if node:IsA("BasePart") then
		parts += 1
		local localCf = pivot:ToObjectSpace(node.CFrame)
		local half = node.Size / 2
		for _, x in { -half.X, half.X } do for _, z in { -half.Z, half.Z } do
			local p = localCf:PointToWorldSpace(Vector3.new(x, 0, z))
			check(math.abs(p.X) <= 25.6 and math.abs(p.Z) <= 25.6, "workshop exceeds pad: " .. node:GetFullName())
		end end
		if node:GetAttribute("FillStep") or node:GetAttribute("BaseTransparency") ~= nil then
			check(not node.CanCollide and not node.CanTouch and not node.CanQuery and node.Anchored, "decorative part has gameplay collision")
		end
	end
end
for _, id in { "hopper", "conveyor", "refinery", "collector" } do check((upgrades[id] or 0) >= 6, "missing upgrade silhouettes for " .. id) end
for _, kind in { "ore", "bar" } do for _, id in { "iron", "frost", "crystal" } do check(stock[kind .. ":" .. id], "missing stock display") end end
check(labels >= 6, "stock labels missing")
check(parts <= 450, "workshop part budget exceeded")
check(t:GetPivot() == CFrame.new(), "plot placement pivot changed")
return { success = true, checks = checks, parts = parts, stockLabels = labels }
