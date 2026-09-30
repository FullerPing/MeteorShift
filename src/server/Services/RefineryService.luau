--!strict
-- The plot production line: hopper -> conveyor -> refinery -> collection post
-- (spec §6, reworked). Handles deposits, the online tick, offline catch-up,
-- collecting bars and keeping the station displays and upgrade prompts current.
--
-- The line is cloned onto a plot by PlotService when someone claims it. Each
-- station is a Model with a StationId attribute ("hopper", "conveyor",
-- "refinery", "collector") containing:
--   Display   BillboardGui with a TextLabel "Text"
--   Upgrade   ProximityPrompt (handled by UpgradeService)
-- plus Hopper.Intake (touch to deposit) and CollectionPost.Bin (touch to collect).
--
-- Passes and products (spec §9, MonetizationService): Offline Hours+ raises the
-- offline cap to Config.Home.OfflineCapPass, and Refinery Overclock speeds the
-- refinery up in the online tick only, counting its time down while you play.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Price = require(ReplicatedStorage.Shared.Price)
local Refining = require(script.Parent.Parent.Lib.Refining)
local Signal = require(ReplicatedStorage.Packages.Signal)

local RefineryService = Knit.CreateService({
	Name = "RefineryService",
	Client = {
		Deposited = Knit.CreateSignal(), -- (amount, hopperFull)
		Collected = Knit.CreateSignal(), -- (bars)
		WhileAway = Knit.CreateSignal(), -- (report)
		Notice = Knit.CreateSignal(), -- (text)
	},
})

RefineryService.OreDeposited = Signal.new() -- (player, ore)
RefineryService.BarsCollected = Signal.new() -- (player, bars)
RefineryService.CaughtUp = Signal.new() -- (player, awaySeconds, bars) after offline catch-up

local DataService
local PlotService
local PlayerStateService
local EconomyService
local MonetizationService

local touchCooldown: { [Player]: { [string]: number } } = {}
local blockedBy: { [Player]: Refining.Blocked } = {}

local sum = Refining.sum

local function formatRate(rate: number): string
	return if rate < 100 then string.format("%g", rate) else Format.number(rate)
end

local function station(stations: Model, id: string): Instance?
	for _, child in stations:GetChildren() do
		if child:GetAttribute("StationId") == id then
			return child
		end
	end
	return nil
end

local function setDisplay(container: Instance?, text: string)
	local display = container and container:FindFirstChild("Display", true)
	local label = display and display:FindFirstChild("Text")
	if label and label:IsA("TextLabel") then
		label.Text = text
	end
end

local function setPrompt(container: Instance?, stationId: string, currentLevel: number)
	local prompt = container and container:FindFirstChild("Upgrade", true)
	if not prompt or not prompt:IsA("ProximityPrompt") then
		return
	end
	local levels = Config.Home.Stations[stationId].Levels
	local nextLevel = levels[currentLevel + 1]
	if nextLevel then
		prompt.ActionText = "Upgrade to Lv " .. (currentLevel + 1)
		prompt.ObjectText = Price.text(nextLevel.Cost, nextLevel.Shards)
		prompt:SetAttribute("Maxed", false)
	else
		prompt.ActionText = "Max level"
		prompt.ObjectText = Config.Home.Stations[stationId].Name
		prompt:SetAttribute("Maxed", true)
	end
end

-- Brings the owner's station displays, prompts and conveyor state up to date.
function RefineryService:RefreshPlot(player: Player)
	local data = PlayerStateService:Get(player)
	local stations = PlotService:GetStations(player)
	if not data or not stations then
		return
	end

	local s = data.stations
	local hopper = station(stations, "hopper")
	local conveyor = station(stations, "conveyor")
	local refinery = station(stations, "refinery")
	local collector = station(stations, "collector")

	setDisplay(hopper, string.format(
		"Hopper · Lv %d\n%s / %s ore",
		s.hopper,
		Format.number(sum(data.hopper)),
		Format.number(Refining.hopperCapacity(data))
	))
	setDisplay(conveyor, string.format("Conveyor · Lv %d\n%s ore/s", s.conveyor, formatRate(Refining.conveyorRate(data))))
	local speedMult = MonetizationService:RefinerySpeedMult(data)
	local refineryText = string.format("Refinery · Lv %d\n%s bars/s", s.refinery, formatRate(Refining.refineryRate(data, speedMult)))
	if speedMult > 1 then
		refineryText ..= "\nOVERCLOCK ×" .. formatRate(speedMult)
	end
	setDisplay(refinery, refineryText)
	local binText = string.format(
		"Collection Post · Lv %d\n%s / %s bars",
		s.collector,
		Format.number(sum(data.bin)),
		Format.number(Refining.collectorCapacity(data))
	)
	if blockedBy[player] == "collector" then
		binText ..= "\nFULL - collect!"
	end
	setDisplay(collector, binText)

	setPrompt(hopper, "hopper", s.hopper)
	setPrompt(conveyor, "conveyor", s.conveyor)
	setPrompt(refinery, "refinery", s.refinery)
	setPrompt(collector, "collector", s.collector)

	-- Clients animate ore on the belt while the line is running
	local running = sum(data.hopper) > 0 and blockedBy[player] ~= "collector"
	stations:SetAttribute("Running", running)
	stations:SetAttribute("LineRate", Refining.lineRate(data, speedMult))
	for _, model in { refinery, conveyor } do
		if model then
			for _, fx in model:GetDescendants() do
				if fx:IsA("Smoke") or fx:IsA("ParticleEmitter") or fx:IsA("Fire") then
					(fx :: any).Enabled = running
				end
			end
		end
	end
end

-- immediate: bypasses the flush accumulator (deposit/collect/purchases). The
-- online tick, which runs for every player far more often, leaves it deferred.
function RefineryService:Refresh(player: Player, immediate: boolean?)
	self:RefreshPlot(player)
	if immediate then
		PlayerStateService:ReplicateNow(player)
	else
		PlayerStateService:Replicate(player)
	end
end

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
	local space = Refining.hopperCapacity(data) - sum(data.hopper)
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
	local leftover = sum(data.backpack)
	if moved > 0 or leftover > 0 then
		self.Client.Deposited:Fire(player, moved, leftover > 0)
	end
	if moved > 0 then
		self:Refresh(player, true)
		self.OreDeposited:Fire(player, moved)
	end
	return moved
end

function RefineryService:Collect(player: Player): number
	local data = PlayerStateService:Get(player)
	if not data then
		return 0
	end
	local collected = 0
	for oreType, n in data.bin do
		if n > 0 then
			data.bars[oreType] = (data.bars[oreType] or 0) + n
			collected += n
		end
	end
	table.clear(data.bin)
	if collected > 0 then
		blockedBy[player] = nil
		self.Client.Collected:Fire(player, collected)
		self:Refresh(player, true)
		self.BarsCollected:Fire(player, collected)
	end
	return collected
end

-- Offline catch-up (spec §6.4): the line keeps running on hopper stock for the
-- time away, capped, and stops when the collection post is full.
function RefineryService:CatchUp(player: Player, awaySeconds: number)
	local data = PlayerStateService:Get(player)
	if not data or awaySeconds <= 0 then
		return
	end
	local cap = MonetizationService:OfflineCap(player) -- Offline Hours+ raises it
	local seconds = math.min(awaySeconds, cap)
	local made, bars, blocked = Refining.run(data, seconds)
	blockedBy[player] = blocked
	-- What the bars sell for at the Trading Post, sale multipliers included
	local value = math.floor(PlayerStateService:BarValue(made) * EconomyService:SaleMultiplier(player))
	self.Client.WhileAway:Fire(player, {
		seconds = seconds,
		away = awaySeconds,
		capped = awaySeconds > cap,
		bars = bars,
		value = value,
		blocked = blocked,
	})
	self.CaughtUp:Fire(player, awaySeconds, bars)
end

function RefineryService:_connectStations(player: Player, stations: Model)
	local function isOwner(hit: BasePart): boolean
		return Players:GetPlayerFromCharacter(hit.Parent) == player
	end

	local hopper = station(stations, "hopper")
	local intake = hopper and hopper:FindFirstChild("Intake", true)
	if intake and intake:IsA("BasePart") then
		intake.Touched:Connect(function(hit)
			if isOwner(hit) and touchReady(player, "hopper") then
				self:Deposit(player)
			end
		end)
	end

	local collector = station(stations, "collector")
	local bin = collector and collector:FindFirstChild("Bin", true)
	if bin and bin:IsA("BasePart") then
		bin.Touched:Connect(function(hit)
			if isOwner(hit) and touchReady(player, "bin") then
				self:Collect(player)
			end
		end)
	end
end

-- Studio-only: pretend the player was away, to test offline income.
function RefineryService.Client:DevSimulateAway(player: Player, seconds: number)
	if RunService:IsStudio() and typeof(seconds) == "number" then
		self.Server:CatchUp(player, math.clamp(seconds, 0, 24 * 3600))
		self.Server:Refresh(player, true)
	end
end

function RefineryService:KnitInit()
	DataService = Knit.GetService("DataService")
	PlotService = Knit.GetService("PlotService")
	PlayerStateService = Knit.GetService("PlayerStateService")
	EconomyService = Knit.GetService("EconomyService")
	MonetizationService = Knit.GetService("MonetizationService")
end

function RefineryService:KnitStart()
	PlotService.PlotAssigned:Connect(function(player, _plot)
		local stations = PlotService:GetStations(player)
		if stations then
			self:_connectStations(player, stations)
		end
		self:RefreshPlot(player)
	end)

	DataService.ProfileLoaded:Connect(function(player, profile)
		local lastSeen = profile.Data.lastSeen
		local joinedAt = os.time()
		-- The online tick runs while we wait for the passes, so it already counts
		-- that time: the away time ends at the join, and lastSeen moves up now.
		profile.Data.lastSeen = joinedAt
		MonetizationService:WaitForPasses(player) -- the Offline Hours+ cap
		if lastSeen and lastSeen > 0 then
			self:CatchUp(player, joinedAt - lastSeen)
		end
		self:Refresh(player, true)
	end)

	PlayerStateService.OreAutoDeposited:Connect(function(player)
		self:RefreshPlot(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		touchCooldown[player] = nil
		blockedBy[player] = nil
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
					local before = blockedBy[player]
					local speedMult = MonetizationService:RefinerySpeedMult(data)
					local _, made, blocked = Refining.run(data, dt, speedMult)
					blockedBy[player] = blocked
					-- Refinery Overclock only counts down while the player is online
					local overclockEnded = false
					if speedMult > 1 then
						data.overclockLeft = math.max((data.overclockLeft or 0) - dt, 0)
						overclockEnded = data.overclockLeft <= 0
					end
					if made > 0 or blocked ~= before or overclockEnded then
						self:Refresh(player)
					end
				end
			end
		end
	end)
end

return RefineryService
