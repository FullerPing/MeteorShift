--!strict
-- Hopper deposits, refineries (online ticking + offline catch-up) and bar
-- collection on each player's plot (spec §6.2 - §6.4).
--
-- Every plot in Workspace.Map.Plots has, saved in the place:
--   Hopper            Model with an Intake part (touch to deposit) and a Display
--   Refineries        Refinery1..Refinery6, each with a Machine model, an
--                     OutputBin part (touch to collect) and a Display
-- Displays are BillboardGuis named "Display" holding a TextLabel named "Text".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Refining = require(script.Parent.Parent.Lib.Refining)

local LOCKED_TRANSPARENCY = 0.8

local RefineryService = Knit.CreateService({
	Name = "RefineryService",
	Client = {
		Deposited = Knit.CreateSignal(), -- (amount, hopperFull)
		Collected = Knit.CreateSignal(), -- (bars)
		-- (report { seconds, capped, bars, oreLeft })
		WhileAway = Knit.CreateSignal(),
		Notice = Knit.CreateSignal(), -- (text)
	},
})

local DataService
local PlotService
local PlayerStateService

local touchCooldown: { [Player]: { [string]: number } } = {}

local function sum(t: { [string]: number }): number
	local total = 0
	for _, v in t do
		total += v
	end
	return total
end

local function formatRate(rate: number): string
	return if rate < 100 then string.format("%g", rate) else Format.number(rate)
end

local function setDisplay(container: Instance?, text: string)
	local display = container and container:FindFirstChild("Display", true)
	local label = display and display:FindFirstChild("Text")
	if label and label:IsA("TextLabel") then
		label.Text = text
	end
end

local function setLocked(machine: Instance, locked: boolean)
	for _, part in machine:GetDescendants() do
		if part:IsA("BasePart") then
			local base = part:GetAttribute("BaseTransparency")
			if base == nil then
				base = part.Transparency
				part:SetAttribute("BaseTransparency", base)
			end
			part.Transparency = if locked then math.max(base :: number, LOCKED_TRANSPARENCY) else base :: number
		elseif part:IsA("Light") or part:IsA("ParticleEmitter") or part:IsA("Fire") or part:IsA("Smoke") then
			(part :: any).Enabled = not locked
		end
	end
end

local function refineryModels(plot: Model): { Instance }
	local list = {}
	local folder = plot:FindFirstChild("Refineries")
	if folder then
		for index = 1, Config.Home.MaxRefineryPads + 1 do
			local model = folder:FindFirstChild("Refinery" .. index)
			if model then
				list[index] = model
			end
		end
	end
	return list
end

-- Brings the plot's hopper and refinery machines in line with the owner's data.
function RefineryService:RefreshPlot(player: Player?, plot: Model)
	local data = if player then PlayerStateService:Get(player) else nil
	local hopper = plot:FindFirstChild("Hopper")

	if not data then
		setDisplay(hopper, "Hopper")
		for index, model in refineryModels(plot) do
			local machine = model:FindFirstChild("Machine")
			if machine then
				setLocked(machine, index > 1)
			end
			setDisplay(model, if index == 1 then "Refinery" else "Locked")
		end
		return
	end

	local capacity = PlayerStateService:GetHopperCapacity(player :: Player)
	setDisplay(hopper, string.format("Hopper\n%s / %s ore", Format.number(sum(data.hopper)), Format.number(capacity)))

	for index, model in refineryModels(plot) do
		local refinery = data.refineries[index]
		local machine = model:FindFirstChild("Machine")
		if machine then
			setLocked(machine, refinery == nil)
		end
		if refinery then
			setDisplay(
				model,
				string.format(
					"Refinery Lv %d · %s/s\n%s bars ready",
					refinery.level,
					formatRate(Refining.throughput(refinery)),
					Format.number(sum(refinery.bin))
				)
			)
		else
			local slot = Config.Home.RefinerySlots[index]
			local price = if slot then Format.cash(slot.Cost) else "Pass"
			if slot and slot.Shards > 0 then
				price ..= " + " .. slot.Shards .. " shards"
			end
			setDisplay(model, "Locked\nslot " .. index .. ": " .. price)
		end
	end
end

function RefineryService:_refresh(player: Player)
	local plot = PlotService:GetPlot(player)
	if plot then
		self:RefreshPlot(player, plot)
	end
	PlayerStateService:Replicate(player)
end

-- Throttle touch handlers per player and per pad
local function touchReady(player: Player, key: string): boolean
	local entry = touchCooldown[player]
	if not entry then
		entry = {}
		touchCooldown[player] = entry
	end
	local now = os.clock()
	if now - (entry[key] or 0) < 1 then
		return false
	end
	entry[key] = now
	return true
end

function RefineryService:Deposit(player: Player): number
	local data = PlayerStateService:Get(player)
	if not data then
		return 0
	end
	local space = PlayerStateService:GetHopperCapacity(player) - sum(data.hopper)
	local moved = 0
	for oreType, amount in data.backpack do
		local n = math.min(amount, space - moved)
		if n > 0 then
			data.backpack[oreType] = amount - n
			data.hopper[oreType] = (data.hopper[oreType] or 0) + n
			moved += n
		end
	end
	for oreType, amount in data.backpack do
		if amount <= 0 then
			data.backpack[oreType] = nil
		end
	end
	if moved > 0 or sum(data.backpack) > 0 then
		self.Client.Deposited:Fire(player, moved, sum(data.backpack) > 0)
	end
	if moved > 0 then
		self:_refresh(player)
	end
	return moved
end

function RefineryService:Collect(player: Player): number
	local data = PlayerStateService:Get(player)
	if not data then
		return 0
	end
	local collected = 0
	for _, refinery in data.refineries do
		for oreType, n in refinery.bin do
			if n > 0 then
				data.bars[oreType] = (data.bars[oreType] or 0) + n
				collected += n
			end
		end
		table.clear(refinery.bin)
	end
	if collected > 0 then
		self.Client.Collected:Fire(player, collected)
		self:_refresh(player)
	end
	return collected
end

-- Offline catch-up (spec §6.4): refineries keep consuming hopper stock for the
-- time away, capped.
function RefineryService:CatchUp(player: Player, awaySeconds: number)
	local data = PlayerStateService:Get(player)
	if not data or awaySeconds <= 0 then
		return
	end
	local cap = Config.Home.OfflineCap -- Offline Hours+ pass raises this in Week 4
	local seconds = math.min(awaySeconds, cap)
	local _, bars = Refining.run(data, seconds)
	self.Client.WhileAway:Fire(player, {
		seconds = seconds,
		away = awaySeconds,
		capped = awaySeconds > cap,
		bars = bars,
		value = bars * (Config.Home.BarPrices.iron or 0),
		oreLeft = sum(data.hopper),
	})
end

function RefineryService:_connectPlot(plot: Model)
	local function ownerFromHit(hit: BasePart): Player?
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player then
			return nil
		end
		if PlotService:GetOwner(plot) ~= player then
			if touchReady(player, "notOwner") then
				self.Client.Notice:Fire(player, "This is someone else's plot. Yours is Plot " .. tostring(player:GetAttribute("PlotId")) .. ".")
			end
			return nil
		end
		return player
	end

	local hopper = plot:FindFirstChild("Hopper")
	local intake = hopper and hopper:FindFirstChild("Intake", true)
	if intake and intake:IsA("BasePart") then
		intake.Touched:Connect(function(hit)
			local player = ownerFromHit(hit)
			if player and touchReady(player, "hopper") then
				self:Deposit(player)
			end
		end)
	end

	for _, model in refineryModels(plot) do
		local bin = model:FindFirstChild("OutputBin", true)
		if bin and bin:IsA("BasePart") then
			bin.Touched:Connect(function(hit)
				local player = ownerFromHit(hit)
				if player and touchReady(player, "bin") then
					self:Collect(player)
				end
			end)
		end
	end
end

-- Studio-only: pretend the player was away, to test offline income.
function RefineryService.Client:DevSimulateAway(player: Player, seconds: number)
	if RunService:IsStudio() and typeof(seconds) == "number" then
		self.Server:CatchUp(player, math.clamp(seconds, 0, 24 * 3600))
		self.Server:_refresh(player)
	end
end

function RefineryService:KnitInit()
	DataService = Knit.GetService("DataService")
	PlotService = Knit.GetService("PlotService")
	PlayerStateService = Knit.GetService("PlayerStateService")
end

function RefineryService:KnitStart()
	for _, plot in workspace:WaitForChild("Map"):WaitForChild("Plots"):GetChildren() do
		if plot:IsA("Model") then
			self:_connectPlot(plot)
			self:RefreshPlot(nil, plot)
		end
	end

	PlotService.PlotAssigned:Connect(function(player, plot)
		self:RefreshPlot(player, plot)
	end)
	PlotService.PlotReleased:Connect(function(_player, plot)
		task.defer(function()
			self:RefreshPlot(nil, plot)
		end)
	end)

	DataService.ProfileLoaded:Connect(function(player, profile)
		local lastSeen = profile.Data.lastSeen
		if lastSeen and lastSeen > 0 then
			self:CatchUp(player, os.time() - lastSeen)
		end
		profile.Data.lastSeen = os.time()
		self:_refresh(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		touchCooldown[player] = nil
	end)

	-- Online tick
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(Config.Home.TickInterval)
			local now = os.clock()
			local dt = now - last
			last = now
			for _, player in Players:GetPlayers() do
				local data = PlayerStateService:Get(player)
				if data then
					local _, made = Refining.run(data, dt)
					if made > 0 then
						self:_refresh(player)
					end
				end
			end
		end
	end)
end

return RefineryService
