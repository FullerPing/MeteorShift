--!strict
-- One shared world refinery; each player retains their own saved production line.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local WorldMap = require(ReplicatedStorage.Shared.WorldMap)
local Hooks = require(ReplicatedStorage.Shared.Hooks)
local Perks = require(ReplicatedStorage.Shared.Perks)
local Format = require(ReplicatedStorage.Shared.Format)
local Income = require(ReplicatedStorage.Shared.Income)
local Rebirth = require(ReplicatedStorage.Shared.Rebirth)
local SafeLoop = require(script.Parent.Parent.Lib.SafeLoop)
local RefineryQueue = require(ReplicatedStorage.Shared.RefineryQueue)
local RequestGate = require(ReplicatedStorage.Shared.RequestGate)
local Refining = require(script.Parent.Parent.Lib.Refining)
local Signal = require(ReplicatedStorage.Packages.Signal)

local RefineryService = Knit.CreateService({
	Name = "RefineryService",
	Client = {
		Deposited = Knit.CreateSignal(), -- (amount, hopperFull)
		Collected = Knit.CreateSignal(), -- (bars)
		WhileAway = Knit.CreateSignal(), -- (report)
		Notice = Knit.CreateSignal(), -- (text)
		Open = Knit.CreateSignal(), -- shared refinery prompt
	},
})

RefineryService.OreDeposited = Signal.new() -- (player, ore)
RefineryService.BarsCollected = Signal.new() -- (player, bars)
RefineryService.CaughtUp = Signal.new() -- (player, awaySeconds, bars) after offline catch-up

local DataService
local PlayerStateService
local EconomyService
local MonetizationService
local RewardService

local blockedBy: { [Player]: Refining.Blocked } = {}
local remoteTimes: { [Player]: { [string]: number } } = {}
local lastVault: { [Player]: number } = {}

local sum = Refining.sum

-- This gate belongs to client handlers only. Physical touches and internal grants
-- keep their existing rules and never consume the remote allowance.
local function remoteReady(player: Player, action: string, cooldown: number): boolean
	local times = remoteTimes[player]
	if not times then
		times = {}
		remoteTimes[player] = times
	end
	local allowed, stamp = RequestGate.check(times[action], os.clock(), cooldown)
	times[action] = stamp
	return allowed
end

-- Only aggregate activity is replicated to the world, never a player's inventory.
function RefineryService:RefreshWorld()
	local point = WorldMap.refineryPoint(WorldMap.find())
	if not point then return end
	local running = false
	for _, player in Players:GetPlayers() do
		local data = PlayerStateService:Get(player)
		if data and sum(data.hopper) > 0 and blockedBy[player] ~= "collector" then
			running = true
			break
		end
	end
	point.Parent:SetAttribute("Running", running)
end

-- immediate: bypasses the flush accumulator (deposit/collect/purchases). The
-- online tick, which runs for every player far more often, leaves it deferred.
function RefineryService:Refresh(player: Player, immediate: boolean?)
	self:RefreshWorld()
	if immediate then
		PlayerStateService:ReplicateNow(player)
	else
		PlayerStateService:Replicate(player)
	end
end

-- The rebirth caller replicates the reset profile after clearing all transient state.
function RefineryService:ResetAfterRebirth(player: Player)
	blockedBy[player] = nil
	self:RefreshWorld()
end

-- Only the caller's saved line can change. Validation creates a detached,
-- complete preference list; empty requests restore the configured default.
function RefineryService:SetPriority(player: Player, requested: any): boolean
	local data = PlayerStateService:Get(player)
	if not data or not self:CanUseMenu(player) then
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

function RefineryService:Deposit(player: Player): number
	local data = PlayerStateService:Get(player)
	if not data then
		return 0
	end
	local space = Refining.hopperCapacity(data, PlayerStateService:GetVaultMultiplier(player)) - sum(data.hopper)
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
-- time away, capped, and stops when the collection post is full. After Home.OfflineMinAway the colony
-- crew also earns cash for the capped time (Config.Home.OfflineCrewShare).
function RefineryService:CatchUp(player: Player, awaySeconds: number)
	local data = PlayerStateService:Get(player)
	if not data or awaySeconds <= 0 then
		return
	end
	local cap = MonetizationService:OfflineCap(player) -- Offline Hours+ raises it
	local seconds = math.min(awaySeconds, cap)
	local made, bars, blocked = Refining.run(data, seconds, nil, PlayerStateService:GetVaultMultiplier(player), Perks.lineMult(data.perks))
	blockedBy[player] = blocked
	local longAway = awaySeconds >= Config.Home.OfflineMinAway
	local crewCash = if longAway then Income.grant(
		seconds * Config.Home.OfflineCrewShare,
		EconomyService:ExpectedIncome(player).perSecond,
		0,
		Rebirth.cost(data.rebirths) * Config.Home.OfflineCeilingShare
	) else 0
	-- Welcome back (Config.Hooks.WelcomeBack): the catch-up sometimes finds extra bars and crew cash
	local bonus = if longAway and (bars > 0 or crewCash > 0) then Hooks.welcomeBack(math.random()) else 1
	if bonus > 1 and crewCash > 0 then
		crewCash = math.floor(crewCash * bonus)
	end
	local bonusBars = 0
	if bonus > 1 then
		local room = math.max(Refining.collectorCapacity(data, PlayerStateService:GetVaultMultiplier(player)) - sum(data.bin), 0)
		for oreType, amount in made do
			local extra = math.min(math.floor(amount * (bonus - 1) + 0.5), room)
			if extra > 0 then
				room -= extra
				data.bin[oreType] = (data.bin[oreType] or 0) + extra
				made[oreType] = amount + extra
				bonusBars += extra
			end
		end
		bars += bonusBars
		if bonusBars <= 0 and crewCash <= 0 then
			bonus = 1
		end
	end
	if bonus > 1 then
		RewardService:Bonus(player, "welcomeBack", string.format("Lucky find! Your colony made ×%s while you were away.", Format.number(bonus)))
	end
	if crewCash > 0 then
		PlayerStateService:AddCash(player, crewCash)
	end
	-- What the bars sell for, sale multipliers included, plus the crew's cash (already paid)
	local value = math.floor(PlayerStateService:BarValue(made) * EconomyService:SaleMultiplier(player, true)) + crewCash
	self.Client.WhileAway:Fire(player, {
		seconds = seconds,
		away = awaySeconds,
		capped = awaySeconds > cap,
		bars = bars,
		bonus = bonus,
		value = value,
		crew = crewCash,
		blocked = blocked,
	})
	self.CaughtUp:Fire(player, awaySeconds, bars)
end

local sharedCooldown: { [Player]: number } = {}

function RefineryService:UseShared(player: Player)
	if not self:CanUseMenu(player) then return end
	local now = os.clock()
	if now - (sharedCooldown[player] or 0) < 0.5 then
		return
	end
	sharedCooldown[player] = now
	self.Client.Open:Fire(player)
end

function RefineryService:_connectShared()
	local map = WorldMap.wait()
	if not WorldMap.refineryPoint(map) then
		warn("[RefineryService] TownSquare.Refinery requires its exact UsePoint part")
		return
	end
	-- the Foundry, the Commissary and every ore chute on the map: all open the same menu
	for _, point in WorldMap.refineryPoints(map) do
		local existing = point:FindFirstChild("UseRefinery")
		local prompt: ProximityPrompt
		if existing and existing:IsA("ProximityPrompt") then
			prompt = existing
		else
			prompt = Instance.new("ProximityPrompt")
			prompt.Name = "UseRefinery"
			prompt.ActionText = "Use refinery"
			prompt.ObjectText = if point == WorldMap.refineryPoint(map) then "Town refinery"
				elseif point == WorldMap.commissaryPoint(map) then "Foundry commissary" else "Ore chute"
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = 14
			prompt.Parent = point
		end
		prompt.Triggered:Connect(function(who)
			self:UseShared(who)
		end)
	end
end

-- Transactions require a living character near the shared UsePoint.
function RefineryService:CanUseMenu(player: Player): boolean
	return WorldMap.canUseRefinery(WorldMap.find(), player.Character)
end

function RefineryService.Client:Deposit(player: Player): number
	if not remoteReady(player, "deposit", 1) then return 0 end
	if not self.Server:CanUseMenu(player) then
		self.Server.Client.Notice:Fire(player, "Move closer to the Foundry, the Commissary or an ore chute to deposit ore.")
		return 0
	end
	return self.Server:Deposit(player)
end

function RefineryService.Client:Claim(player: Player): number
	if not remoteReady(player, "claim", 1) then return 0 end
	if not self.Server:CanUseMenu(player) then
		self.Server.Client.Notice:Fire(player, "Move closer to the Foundry, the Commissary or an ore chute to claim bars.")
		return 0
	end
	return self.Server:Collect(player)
end

function RefineryService.Client:SetPriority(player: Player, requested: any): boolean
	if not remoteReady(player, "priority", 0.15) or typeof(requested) ~= "table" then return false end
	return self.Server:SetPriority(player, requested)
end

-- Studio-only: pretend the player was away, to test offline income.
function RefineryService.Client:DevSimulateAway(player: Player, seconds: number)
	if not remoteReady(player, "simulateAway", 1) then return end
	if not RunService:IsStudio() or typeof(seconds) ~= "number" or seconds ~= seconds or math.abs(seconds) == math.huge then return end
	self.Server:CatchUp(player, math.clamp(seconds, 0, 24 * 3600))
	self.Server:Refresh(player, true)
end

function RefineryService:KnitInit()
	DataService = Knit.GetService("DataService")
	PlayerStateService = Knit.GetService("PlayerStateService")
	EconomyService = Knit.GetService("EconomyService")
	MonetizationService = Knit.GetService("MonetizationService")
	RewardService = Knit.GetService("RewardService")
end

function RefineryService:KnitStart()
	self:_connectShared()

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
		self:RefreshWorld()
	end)

	Players.PlayerRemoving:Connect(function(player)
		task.defer(function() self:RefreshWorld() end)
		blockedBy[player] = nil
		remoteTimes[player] = nil
		sharedCooldown[player] = nil
		lastVault[player] = nil
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
				-- One player's broken profile must not stop everyone's line and Overclock countdown (SafeLoop)
				SafeLoop.step("RefineryTick", function()
					local data = PlayerStateService:Get(player)
					if data then
						local before = blockedBy[player]
						local progressBefore = data.progress
						local speedMult = MonetizationService:RefinerySpeedMult(data)
						local vaultMult = PlayerStateService:GetVaultMultiplier(player)
						local vaultChanged = lastVault[player] ~= vaultMult
						lastVault[player] = vaultMult
						local _, made, blocked = Refining.run(data, dt, speedMult, PlayerStateService:GetVaultMultiplier(player), Perks.lineMult(data.perks))
						blockedBy[player] = blocked
						-- Refinery Overclock only counts down while the player is online
						local oreBoostBefore = data.oreBoostLeft or 0
						data.oreBoostLeft = math.max(oreBoostBefore - dt, 0)
						local oreBoostEnded = oreBoostBefore > 0 and data.oreBoostLeft <= 0
						local overclockEnded = false
						if speedMult > 1 then
							data.overclockLeft = math.max((data.overclockLeft or 0) - dt, 0)
							overclockEnded = data.overclockLeft <= 0
						end
						if made > 0 or blocked ~= before or overclockEnded or oreBoostEnded or vaultChanged then
							self:Refresh(player)
						elseif data.progress ~= progressBefore or oreBoostBefore > 0 then
							PlayerStateService:Replicate(player)
						end
					end
				end)
			end
		end
	end)
end

return RefineryService
