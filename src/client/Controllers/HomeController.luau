--!strict
-- Plot presentation on the client:
--   * a "YOUR PLOT" beacon you can see from anywhere in town
--   * ore and bars riding the input/output belts
--   * saved levels and real stock revealed on the workshop
--   * station prompts only on your own plot

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Home = require(ReplicatedStorage.Shared.Config.Home)
local Format = require(ReplicatedStorage.Shared.Format)
local Presentation = require(ReplicatedStorage.Shared.PlotPresentation)
local UI = require(script.Parent.Parent.UI)

local player = Players.LocalPlayer

local HomeController = Knit.CreateController({
	Name = "HomeController",
})

local FX_DISTANCE = 220 -- only animate belts near the camera
local BELT_TRAVEL_TIME = 2.2
local MAX_CHUNKS = 48
local MAX_PLOT_CHUNKS = 8

type StationBinding = {
	model: Model,
	connections: { RBXScriptConnection },
	chunks: { [BasePart]: () -> () },
	chunkCount: number,
	nextSpawn: { [BasePart]: number },
	belts: { BasePart },
	refreshQueued: boolean,
	stopped: boolean,
}

type PlotBinding = {
	connections: { RBXScriptConnection },
	station: StationBinding?,
}

local stationBindings: { [Model]: StationBinding } = {}
local plotBindings: { [Model]: PlotBinding } = {}
local baseTransparency: { [BasePart]: number } = setmetatable({}, { __mode = "k" }) :: any
local chunkCount = 0

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

-- Station prompts on other players' plots are hidden locally.
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
	if prompt:IsA("ProximityPrompt") and (prompt.Name == "Upgrade" or prompt.Name == "ManageRefinery") then
		prompt.Enabled = isMine(prompt)
	end
end

local function stockAmount(stations: Model, kind: string, id: string): number
	local value = stations:GetAttribute((if kind == "ore" then "Ore_" else "Bars_") .. id)
	return if type(value) == "number" and value == value and value > 0 and value < math.huge then value else 0
end

local function stockAncestor(instance: Instance, stations: Model): (string?, string?)
	local node: Instance? = instance.Parent
	while node and node ~= stations do
		local kind = node:GetAttribute("StockKind")
		local id = node:GetAttribute("StockType")
		if (kind == "ore" or kind == "bar") and type(id) == "string" then
			return kind, id
		end
		node = node.Parent
	end
	return nil, nil
end

local function namedLabel(label: TextLabel, name: string): boolean
	if label.Name == name then return true end
	local node = label.Parent
	while node and not node:IsA("BasePart") and not node:IsA("Model") do
		if node:IsA("SurfaceGui") and node.Name == name then return true end
		node = node.Parent
	end
	return false
end

local function applyAppearance(binding: StationBinding)
	local stations = binding.model
	local belts: { BasePart } = {}
	for _, descendant in stations:GetDescendants() do
		applyPrompt(descendant)
		if descendant:IsA("BasePart") then
			if descendant.Name == "Belt" then table.insert(belts, descendant) end
			local decorated, visible = false, true
			local node: Instance? = descendant.Parent
			while node and node ~= stations do
				local stationId = node:GetAttribute("UpgradeStation")
				local minLevel = node:GetAttribute("MinLevel")
				if type(stationId) == "string" and minLevel ~= nil then
					decorated = true
					visible = visible and Presentation.levelVisible(stations:GetAttribute("StationLevel_" .. stationId), minLevel)
				end
				node = node.Parent
			end
			local kind, id = stockAncestor(descendant, stations)
			local step = descendant:GetAttribute("FillStep")
			if kind and id and type(step) == "number" then
				decorated = true
				local amount = stockAmount(stations, kind, id)
				visible = visible and step >= 1 and step <= Presentation.fillCount(amount)
				descendant.Color = Presentation.color(id, kind :: "ore" | "bar")
			end
			if decorated then
				local transparency = descendant:GetAttribute("BaseTransparency")
				if type(transparency) ~= "number" then
					transparency = baseTransparency[descendant]
					if transparency == nil then
						transparency = descendant.Transparency
						baseTransparency[descendant] = transparency
					end
				end
				descendant.Transparency = if visible then math.clamp(transparency :: number, 0, 1) else 1
			end
		elseif descendant:IsA("TextLabel") then
			if namedLabel(descendant, "StockLabel") then
				local kind, id = stockAncestor(descendant, stations)
				if kind and id then
					local amount = stockAmount(stations, kind, id)
					descendant.Text = if amount > 0 then (Home.OreNames[id] or id) .. " · " .. Format.number(amount) else "Empty"
				end
			elseif namedLabel(descendant, "ActiveOre") then
				local id = stations:GetAttribute("ActiveOre")
				descendant.Text = if type(id) == "string" then Home.OreNames[id] or id else "Empty"
				descendant.TextColor3 = Presentation.color(if type(id) == "string" then id else "", "ore")
			end
		end
	end
	binding.belts = belts
	for belt in binding.nextSpawn do
		if not belt:IsDescendantOf(stations) then binding.nextSpawn[belt] = nil end
	end
end

local function refreshAppearance(binding: StationBinding)
	if binding.stopped or binding.refreshQueued then return end
	binding.refreshQueued = true
	task.defer(function()
		binding.refreshQueued = false
		if not binding.stopped then applyAppearance(binding) end
	end)
end

local function stopStations(binding: StationBinding)
	if binding.stopped then return end
	binding.stopped = true
	stationBindings[binding.model] = nil
	for _, connection in binding.connections do connection:Disconnect() end
	for _, destroy in binding.chunks do destroy() end
	table.clear(binding.connections)
	table.clear(binding.nextSpawn)
	table.clear(binding.belts)
end

local function watchStations(stations: Model): StationBinding
	local binding: StationBinding = {
		model = stations, connections = {}, chunks = {}, chunkCount = 0,
		nextSpawn = {}, belts = {}, refreshQueued = false, stopped = false,
	}
	stationBindings[stations] = binding
	table.insert(binding.connections, stations.AttributeChanged:Connect(function()
		refreshAppearance(binding)
	end))
	table.insert(binding.connections, stations.DescendantAdded:Connect(function(descendant)
		applyPrompt(descendant)
		refreshAppearance(binding)
	end))
	table.insert(binding.connections, stations.DescendantRemoving:Connect(function()
		refreshAppearance(binding)
	end))
	table.insert(binding.connections, stations.Destroying:Connect(function()
		stopStations(binding)
	end))
	applyAppearance(binding)
	return binding
end

local function stopPlot(plot: Model)
	local binding = plotBindings[plot]
	if not binding then return end
	plotBindings[plot] = nil
	if binding.station then stopStations(binding.station) end
	for _, connection in binding.connections do connection:Disconnect() end
end

local function watchPlot(plot: Instance)
	if not plot:IsA("Model") or plotBindings[plot] then return end
	local binding: PlotBinding = { connections = {} }
	plotBindings[plot] = binding
	local function stationsChanged()
		local stations = plot:FindFirstChild("Stations")
		if binding.station and binding.station.model == stations then return end
		if binding.station then stopStations(binding.station); binding.station = nil end
		if stations and stations:IsA("Model") then binding.station = watchStations(stations) end
	end
	table.insert(binding.connections, plot.ChildAdded:Connect(stationsChanged))
	table.insert(binding.connections, plot.ChildRemoved:Connect(stationsChanged))
	table.insert(binding.connections, plot:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
		for _, descendant in plot:GetDescendants() do applyPrompt(descendant) end
	end))
	table.insert(binding.connections, plot.Destroying:Connect(function() stopPlot(plot) end))
	stationsChanged()
end

local function spawnChunk(binding: StationBinding, from: Attachment, to: Attachment, payload: "ore" | "bar", oreId: string)
	if binding.stopped or chunkCount >= MAX_CHUNKS or binding.chunkCount >= MAX_PLOT_CHUNKS then return end
	local camera = workspace.CurrentCamera
	if not camera then return end
	local chunk = Instance.new("Part")
	chunk.Name = if payload == "bar" then "ConveyorBar" else "ConveyorOre"
	chunk.Anchored = true
	chunk.CanCollide = false
	chunk.CanQuery = false
	chunk.CanTouch = false
	chunk.CastShadow = false
	chunk.Size = if payload == "bar" then Vector3.new(1.05, 0.28, 0.65) else Vector3.new(0.8, 0.65, 0.8)
	chunk.Shape = if payload == "bar" then Enum.PartType.Block else Enum.PartType.Ball
	chunk.Material = if payload == "bar" then Enum.Material.Metal else Enum.Material.Slate
	chunk.Color = Presentation.color(oreId, payload)
	local yaw = if payload == "bar" then 0 else math.random() * math.pi * 2
	chunk.CFrame = from.WorldCFrame * CFrame.Angles(0, yaw, 0)
	chunk:SetAttribute("Payload", payload)
	local plot = binding.model.Parent
	if plot then chunk:SetAttribute("PlotId", plot:GetAttribute("PlotId")) end
	chunk.Parent = camera
	local tween = TweenService:Create(chunk, TweenInfo.new(BELT_TRAVEL_TIME, Enum.EasingStyle.Linear), {
		CFrame = to.WorldCFrame * CFrame.Angles(0, yaw, 0),
	})
	local completed: RBXScriptConnection? = nil
	local removed: RBXScriptConnection? = nil
	local destroyed = false
	local function destroy()
		if destroyed then return end
		destroyed = true
		binding.chunks[chunk] = nil
		binding.chunkCount -= 1
		chunkCount -= 1
		if completed then completed:Disconnect() end
		if removed then removed:Disconnect() end
		tween:Cancel()
		chunk:Destroy()
	end
	binding.chunks[chunk] = destroy
	binding.chunkCount += 1
	chunkCount += 1
	completed = tween.Completed:Once(destroy)
	removed = chunk.AncestryChanged:Connect(function()
		if not chunk:IsDescendantOf(workspace) then destroy() end
	end)
	tween:Play()
end

function HomeController:KnitStart()
	showBeacon(player:GetAttribute("PlotId") :: number?)
	player:GetAttributeChangedSignal("PlotId"):Connect(function()
		showBeacon(player:GetAttribute("PlotId") :: number?)
	end)

	local plots = plotsFolder()
	for _, plot in plots:GetChildren() do watchPlot(plot) end
	plots.ChildAdded:Connect(watchPlot)
	plots.ChildRemoved:Connect(function(plot)
		if plot:IsA("Model") then stopPlot(plot) end
	end)

	-- Input ore and output ingots share the upgraded line's rate. Cosmetic parts
	-- stay bounded across every plot and are removed with their station models.
	task.spawn(function()
		while true do
			task.wait(0.1)
			local camera = workspace.CurrentCamera
			if not camera then continue end
			local now = os.clock()
			for stations, binding in stationBindings do
				if stations:GetAttribute("Running") ~= true then continue end
				local oreId = stations:GetAttribute("ActiveOre")
				if type(oreId) ~= "string" then continue end
				for _, belt in binding.belts do
					local payload = belt:GetAttribute("Payload")
					local kind: "ore" | "bar" = if payload == "bar" then "bar" else "ore"
					if (belt.Position - camera.CFrame.Position).Magnitude > FX_DISTANCE then continue end
					local from, to = belt:FindFirstChild("From"), belt:FindFirstChild("To")
					if not (from and to and from:IsA("Attachment") and to:IsA("Attachment")) then continue end
					if now >= (binding.nextSpawn[belt] or 0) then
						local rate = (stations:GetAttribute("LineRate") :: number?) or 0.25
						binding.nextSpawn[belt] = now + math.clamp(1 / math.max(rate, 0.01), 0.35, 3)
						spawnChunk(binding, from, to, kind, oreId)
					end
				end
			end
		end
	end)
end

return HomeController
