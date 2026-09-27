--!strict
-- Plot presentation on the client:
--   * a "YOUR PLOT" beacon you can see from anywhere in town
--   * ore chunks riding the conveyor while a line is running
--   * upgrade prompts only on your own stations

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local UI = require(script.Parent.Parent.UI)

local player = Players.LocalPlayer

local HomeController = Knit.CreateController({
	Name = "HomeController",
})

local FX_DISTANCE = 220 -- only animate belts near the camera
local BELT_TRAVEL_TIME = 2.2

local beacon: BillboardGui? = nil

local function plotsFolder(): Instance
	return workspace:WaitForChild("Map"):WaitForChild("Plots")
end

local function findPlot(plotId: number): Model?
	for _, plot in plotsFolder():GetChildren() do
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
	gui.Size = UDim2.fromOffset(174, 38)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 26, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 1000

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = UI.PANEL_DARK
	label.BackgroundTransparency = 0.12
	label.BorderSizePixel = 0
	label.Font = UI.FONT
	label.Text = "⌂ YOUR PLOT"
	label.TextColor3 = UI.CASH
	label.TextSize = 19
	label.TextStrokeColor3 = UI.OUTLINE
	label.TextStrokeTransparency = 0
	label.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = label
	local border = Instance.new("UIStroke")
	border.Color = UI.OUTLINE
	border.Thickness = 2
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	border.Parent = label
	gui.Parent = player:WaitForChild("PlayerGui")
	beacon = gui
end

-- Upgrade prompts on other players' plots are hidden locally
local function isMine(prompt: Instance): boolean
	local node: Instance? = prompt
	while node and node ~= workspace do
		if node:GetAttribute("PlotId") ~= nil then
			return node:GetAttribute("OwnerUserId") == player.UserId
		end
		node = node.Parent
	end
	return false
end

local function applyPrompt(prompt: Instance)
	if prompt:IsA("ProximityPrompt") and prompt.Name == "Upgrade" then
		prompt.Enabled = isMine(prompt)
	end
end

local function spawnChunk(from: Attachment, to: Attachment)
	local chunk = Instance.new("Part")
	chunk.Anchored = true
	chunk.CanCollide = false
	chunk.CanQuery = false
	chunk.CanTouch = false
	chunk.CastShadow = false
	chunk.Size = Vector3.new(0.8, 0.6, 0.8)
	chunk.Material = Enum.Material.Slate
	chunk.Color = Color3.fromRGB(150, 128, 110):Lerp(Color3.fromRGB(196, 176, 160), math.random())
	chunk.CFrame = from.WorldCFrame * CFrame.Angles(0, math.random() * 6.28, 0)
	chunk.Parent = workspace.CurrentCamera
	local tween = TweenService:Create(chunk, TweenInfo.new(BELT_TRAVEL_TIME, Enum.EasingStyle.Linear), {
		CFrame = to.WorldCFrame * CFrame.Angles(0, math.random() * 6.28, 0),
	})
	tween.Completed:Once(function()
		chunk:Destroy()
	end)
	tween:Play()
end

function HomeController:KnitStart()
	showBeacon(player:GetAttribute("PlotId") :: number?)
	player:GetAttributeChangedSignal("PlotId"):Connect(function()
		showBeacon(player:GetAttribute("PlotId") :: number?)
	end)

	local plots = plotsFolder()
	for _, descendant in plots:GetDescendants() do
		applyPrompt(descendant)
	end
	plots.DescendantAdded:Connect(applyPrompt)

	-- Conveyor ore, spaced by the line's rate (visual only)
	task.spawn(function()
		local nextSpawn: { [Instance]: number } = {}
		while true do
			task.wait(0.1)
			local camera = workspace.CurrentCamera
			local now = os.clock()
			for _, plot in plots:GetChildren() do
				local stations = plot:FindFirstChild("Stations")
				if not stations or not stations:GetAttribute("Running") then
					continue
				end
				local belt = stations:FindFirstChild("Belt", true)
				if not belt or not belt:IsA("BasePart") then
					continue
				end
				if (belt.Position - camera.CFrame.Position).Magnitude > FX_DISTANCE then
					continue
				end
				local from = belt:FindFirstChild("From")
				local to = belt:FindFirstChild("To")
				if not (from and to and from:IsA("Attachment") and to:IsA("Attachment")) then
					continue
				end
				if now >= (nextSpawn[stations] or 0) then
					local rate = (stations:GetAttribute("LineRate") :: number?) or 0.25
					nextSpawn[stations] = now + math.clamp(1 / math.max(rate, 0.01), 0.35, 3)
					spawnChunk(from, to)
				end
			end
		end
	end)
end

return HomeController
