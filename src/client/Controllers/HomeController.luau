--!strict
-- Marks your own plot with a "YOUR PLOT" beacon you can see from anywhere in
-- town, so the walk home with a full backpack is obvious.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local player = Players.LocalPlayer

local HomeController = Knit.CreateController({
	Name = "HomeController",
})

local beacon: BillboardGui? = nil

local function findPlot(plotId: number): Model?
	local plots = workspace:WaitForChild("Map"):WaitForChild("Plots")
	for _, plot in plots:GetChildren() do
		if plot:GetAttribute("PlotId") == plotId then
			return plot :: Model
		end
	end
	return nil
end

local function showBeacon(plotId: number?)
	if beacon then
		beacon:Destroy()
		beacon = nil
	end
	if not plotId then
		return
	end
	local plot = findPlot(plotId)
	local pad = plot and plot:FindFirstChild("Pad")
	if not pad or not pad:IsA("BasePart") then
		return
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = "YourPlotBeacon"
	gui.Adornee = pad
	gui.Size = UDim2.fromOffset(160, 44)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 22, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 1000

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(24, 22, 30)
	label.BackgroundTransparency = 0.3
	label.Font = Enum.Font.FredokaOne
	label.Text = "⌂ YOUR PLOT"
	label.TextColor3 = Color3.fromRGB(120, 235, 120)
	label.TextSize = 22
	label.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = label

	gui.Parent = player:WaitForChild("PlayerGui")
	beacon = gui
end

function HomeController:KnitStart()
	showBeacon(player:GetAttribute("PlotId") :: number?)
	player:GetAttributeChangedSignal("PlotId"):Connect(function()
		showBeacon(player:GetAttribute("PlotId") :: number?)
	end)
end

return HomeController
