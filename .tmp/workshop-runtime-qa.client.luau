-- Temporary client inspector of the real HomeController and replicated fixture.
local R = game.ReplicatedStorage
local H = game:GetService("HttpService")
local Presentation = require(R.Shared.PlotPresentation)
local player = game.Players.LocalPlayer
local plot = workspace.Map.Plots:WaitForChild("WorkshopQAPlot", 20)
assert(plot, "Fixture plot missing")
local stations = plot:WaitForChild("Stations")
local pad = plot:WaitForChild("Pad", 20)
assert(pad, "Fixture pad not replicated")
local deadline = os.clock() + 20
repeat task.wait(0.1); local count = 0; for _, n in stations:GetDescendants() do if n:IsA("BasePart") then count += 1 end end until count >= 303 or os.clock() > deadline
local result = { success = true, assertions = 0, stages = {} }
local function check(condition, message) result.assertions += 1; assert(condition, message) end
local function sameColour(a, b) return math.abs(a.R - b.R) < 1 / 255 and math.abs(a.G - b.G) < 1 / 255 and math.abs(a.B - b.B) < 1 / 255 end
local function inspect(stage)
	local counts = { ore = 0, bar = 0, tiers = 0, chunks = 0 }
	for _, model in stations:GetDescendants() do
		if model:IsA("Model") and model:GetAttribute("UpgradeStation") then
			local visible = Presentation.levelVisible(stations:GetAttribute("StationLevel_" .. model:GetAttribute("UpgradeStation")), model:GetAttribute("MinLevel"))
			for _, part in model:GetDescendants() do if part:IsA("BasePart") then check((part.Transparency < 1) == visible, "upgrade tier visibility"); counts.tiers += if visible then 1 else 0 end end
		elseif model:IsA("Model") and model:GetAttribute("StockKind") then
			local kind, id = model:GetAttribute("StockKind"), model:GetAttribute("StockType")
			local amount = stations:GetAttribute((if kind == "ore" then "Ore_" else "Bars_") .. id) or 0
			for _, node in model:GetDescendants() do
				if node:IsA("BasePart") then
					local step = node:GetAttribute("FillStep")
					if step then
						local visible = step <= Presentation.fillCount(amount)
						check((node.Transparency < 1) == visible, "stock fill visibility")
						if visible then counts[kind] += 1; check(sameColour(node.Color, Presentation.color(id, kind)), "stock colour") end
					else check(node.Transparency < 1, "empty frame or label plate disappeared") end
				elseif node:IsA("TextLabel") and node.Name == "StockLabel" then
					check(if amount == 0 then node.Text == "Empty" else node.Text:find(tostring(amount), 1, true) ~= nil, "stock label wrong")
				end
			end
		end
	end
	for _, node in workspace.CurrentCamera:GetChildren() do if node:IsA("BasePart") and (node.Name == "ConveyorOre" or node.Name == "ConveyorBar") then counts.chunks += 1 end end
	check(counts.chunks <= 48, "global chunk cap exceeded")
	result.stages[stage] = counts
	R:SetAttribute("WorkshopClientQAResult", H:JSONEncode(result))
	return counts
end
local camera = workspace.CurrentCamera
local originalType, originalCf = camera.CameraType, camera.CFrame
camera.CameraType = Enum.CameraType.Scriptable
camera.CFrame = CFrame.lookAt(pad.CFrame:PointToWorldSpace(Vector3.new(-42, 39, 42)), pad.CFrame:PointToWorldSpace(Vector3.new(0, 4, 0)))
local command = Instance.new("BindableFunction"); command.Name = "WorkshopClientQACommand"; command.Parent = R
command.OnInvoke = function(stage)
	if stage == "cleanup" then
		camera.CameraType, camera.CFrame = originalType, originalCf
		check(not workspace.Map.Plots:FindFirstChild("WorkshopQAPlot"), "fixture plot removal failed")
		for _, node in camera:GetChildren() do if node:IsA("BasePart") then check(node:GetAttribute("PlotId") ~= 9999, "chunk left behind after removal") end end
		R:SetAttribute("WorkshopClientQAResult", H:JSONEncode(result))
		return result
	end
	return inspect(stage)
end
task.wait(0.5)
local remote = R:WaitForChild("WorkshopQAAction", 20)
local ok, problem = xpcall(function()
	inspect("mixed")
	task.wait(1)
	local ore, bars = false, false
	for _, node in camera:GetChildren() do
		if node:GetAttribute("PlotId") == 9999 then ore = ore or node.Name == "ConveyorOre"; bars = bars or node.Name == "ConveyorBar" end
	end
	check(ore and bars, "both belt payloads must animate")
	remote:InvokeServer("max"); task.wait(0.25); inspect("max")
	remote:InvokeServer("empty"); task.wait(2.5)
	local empty = inspect("empty")
	check(empty.ore == 0 and empty.bar == 0 and empty.chunks == 0, "empty line kept stock or belt chunks")
	remote:InvokeServer("remove"); task.wait(0.2)
	command:Invoke("cleanup")
end, debug.traceback)
camera.CameraType, camera.CFrame = originalType, originalCf
result.success, result.error = ok, not ok and tostring(problem) or nil
R:SetAttribute("WorkshopClientQAResult", H:JSONEncode(result))
assert(ok, problem)
