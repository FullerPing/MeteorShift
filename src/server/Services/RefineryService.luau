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
local RefineryQueue = require(ReplicatedStorage.Shared.RefineryQueue)
local Refining = require(script.Parent.Parent.Lib.Refining)
local Signal = require(ReplicatedStorage.Packages.Signal)

local RefineryService = Knit.CreateService({
	Name = "RefineryService",
	Client = {
		Deposited = Knit.CreateSignal(), -- (amount, hopperFull)
		Collected = Knit.CreateSignal(), -- (bars)
		WhileAway = Knit.CreateSignal(), -- (report)
		Notice = Knit.CreateSignal(), -- (text)
		Open = Knit.CreateSignal(), -- owner's physical refinery management prompt
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
local priorityCooldown: { [Player]: number } = {}

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

-- Decorative slots and upgrade pieces read these attributes locally. Publish
-- zero for depleted types too, so a previous pile cannot remain visible.
local function publishAppearance(stations: Model, data: any)
	for _, id in Config.Home.StationOrder do
		stations:SetAttribute("StationLevel_" .. id, data.stations[id])
	end
	local types: { [string]: boolean } = {}
	for _, id in Config.Home.OreOrder do types[id] = true end
	for _, source in { Config.Home.OreNames, Config.Home.BarPrices, data.hopper, data.bin } do
		for id in source do
			if type(id) == "string" then types[id] = true end
		end
	end
	for name in stations:GetAttributes() do
		if string.sub(name, 1, 4) == "Ore_" then
			types[string.sub(name, 5)] = true
		elseif string.sub(name, 1, 5) == "Bars_" then
			types[string.sub(name, 6)] = true
		end
	end
	for id in types do
		stations:SetAttribute("Ore_" .. id, data.hopper[id] or 0)
		stations:SetAttribute("Bars_" .. id, data.bin[id] or 0)
	end
	stations:SetAttribute("ActiveOre", RefineryQueue.nextOre(data.hopper, data.refinePriority))
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
	publishAppearance(stations, data)

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

-- The rebirth caller replicates the reset profile after clearing all transient state.
function RefineryService:ResetAfterRebirth(player: Player)
	blockedBy[player] = nil
	touchCooldown[player] = nil
	priorityCooldown[player] = nil
	self:RefreshPlot(player)
end

-- Only the caller's saved line can change. Validation creates a detached,
-- complete preference list; empty requests restore the configured default.
function RefineryService:SetPriority(player: Player, requested: any): boolean
	local data = PlayerStateService:Get(player)
	if not data or not (PlotService:GetStations(player) or PlotService:HasSharedRefinery()) then
		return false
	end
	local priority = RefineryQueue.validate(requested)
	if not priority then
		return false
	end
	data.refinePriority = priority
	self:Refresh(player, true)
	return true
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

	local refinery = station(stations, "refinery")
	if refinery then
		for _, descendant in refinery:GetDescendants() do
			if descendant:IsA("ProximityPrompt") and descendant.Name == "ManageRefinery" then
				descendant:Destroy()
			end
		end
	end
	local anchor: BasePart? = if hopper and hopper:IsA("Model") then hopper.PrimaryPart else nil
	if not anchor and hopper then
		local body = hopper:FindFirstChild("Body", true)
		local part = if body and body:IsA("BasePart") then body else hopper:FindFirstChildWhichIsA("BasePart", true)
		if part and part:IsA("BasePart") then
			anchor = part
		end
	end
	if anchor and hopper and not hopper:FindFirstChild("ManageRefinery", true) then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "ManageRefinery"
		prompt.ActionText = "Refining order"
		prompt.ObjectText = "Hopper"
		prompt.KeyboardKeyCode = Enum.KeyCode.R
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 12
		prompt.UIOffset = Vector2.new(0, 0)
		prompt.Parent = anchor
		prompt.Triggered:Connect(function(who)
			if who == player then
				self.Client.Open:Fire(player)
			end
		end)
	end
end

-- The shared refinery in town (Workspace.Map.TownSquare.Refinery): using it empties your
-- backpack into your hopper, collects your finished bars and opens your refinery panel. It is
-- the same line everywhere; each player works their own saved hopper and bars.
local sharedCooldown: { [Player]: number } = {}

function RefineryService:UseShared(player: Player)
	local now = os.clock()
	if now - (sharedCooldown[player] or 0) < 0.5 then
		return
	end
	sharedCooldown[player] = now
	self.Client.Open:Fire(player)
end

function RefineryService:_connectShared()
	local townSquare = workspace:WaitForChild("Map"):FindFirstChild("TownSquare")
	local refinery = if townSquare then townSquare:FindFirstChild("Refinery") else nil
	if not refinery then
		return
	end
	local point = refinery:FindFirstChild("UsePoint", true)
	if not (point and point:IsA("BasePart")) then
		point = if refinery:IsA("Model") then refinery.PrimaryPart else nil
	end
	if not (point and point:IsA("BasePart")) then
		point = refinery:FindFirstChildWhichIsA("BasePart", true)
	end
	if not (point and point:IsA("BasePart")) then
		warn("[RefineryService] TownSquare.Refinery has no UsePoint part; players can't use it")
		return
	end
	-- not named ManageRefinery: the client hides that one from everyone but a plot's owner
	local existing = point:FindFirstChild("UseRefinery")
	local prompt: ProximityPrompt
	if existing and existing:IsA("ProximityPrompt") then
		prompt = existing
	else
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "UseRefinery"
		prompt.ActionText = "Use refinery"
		prompt.ObjectText = "Town refinery"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 14
		prompt.Parent = point
	end
	prompt.Triggered:Connect(function(who)
		self:UseShared(who)
	end)
end

-- Menu transactions require a living character near the shared building or
-- the caller's own production line. No client supplies inventory or quantities.
function RefineryService:CanUseMenu(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (root and root:IsA("BasePart") and humanoid and humanoid.Health > 0) then return false end
	local map = workspace:FindFirstChild("Map")
	local town = map and map:FindFirstChild("TownSquare")
	local shared = town and town:FindFirstChild("Refinery")
	local point = shared and shared:FindFirstChild("UsePoint", true)
	if point and point:IsA("BasePart") and (root.Position - point.Position).Magnitude <= 18 then return true end
	local stations = PlotService:GetStations(player)
	if stations then
		for _, id in { "hopper", "collector" } do
			local container = station(stations, id)
			local anchor = container and container:FindFirstChildWhichIsA("BasePart", true)
			if anchor and (root.Position - anchor.Position).Magnitude <= 18 then return true end
		end
	end
	return false
end

function RefineryService.Client:Deposit(player: Player): number
	if not self.Server:CanUseMenu(player) then
		self.Server.Client.Notice:Fire(player, "Move closer to the refinery to deposit ore.")
		return 0
	end
	if not touchReady(player, "menuDeposit") then return 0 end
	return self.Server:Deposit(player)
end

function RefineryService.Client:Claim(player: Player): number
	if not self.Server:CanUseMenu(player) then
		self.Server.Client.Notice:Fire(player, "Move closer to the refinery to claim bars.")
		return 0
	end
	if not touchReady(player, "menuClaim") then return 0 end
	return self.Server:Collect(player)
end

function RefineryService.Client:SetPriority(player: Player, requested: any): boolean
	local now = os.clock()
	local previous = priorityCooldown[player]
	if previous and now - previous < 0.15 then
		return false
	end
	priorityCooldown[player] = now
	return self.Server:SetPriority(player, requested)
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
	self:_connectShared()

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
		local rebirths = profile.Data.rebirths or 0
		-- The online tick runs while we wait for the passes, so it already counts
		-- that time: the away time ends at the join, and lastSeen moves up now.
		profile.Data.lastSeen = joinedAt
		MonetizationService:WaitForPasses(player) -- the Offline Hours+ cap
		-- A rebirth while pass ownership loads ends the old life's offline work.
		if lastSeen and lastSeen > 0 and (profile.Data.rebirths or 0) == rebirths then
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
		priorityCooldown[player] = nil
		sharedCooldown[player] = nil
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
					local progressBefore = data.progress
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
					elseif data.progress ~= progressBefore then
						PlayerStateService:Replicate(player)
					end
				end
			end
		end
	end)
end

return RefineryService
