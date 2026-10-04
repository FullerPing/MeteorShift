--!strict
-- Gameplay-facing view of a player's saved profile: pickaxe, backpack, currencies,
-- hopper and refineries. Storage is DataService; this service owns the rules and
-- replicates a compact snapshot to the owning client.
--
-- Game passes (spec §9.1, MonetizationService) reach in here twice: Bigger Backpack
-- multiplies the backpack capacity, and Auto-Deposit sends mined ore straight into
-- the hopper (up to its capacity, the rest into the backpack).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Gear = require(ReplicatedStorage.Shared.Gear)
local Pets = require(ReplicatedStorage.Shared.Pets)
local Levels = require(ReplicatedStorage.Shared.Levels)
local RefineryQueue = require(ReplicatedStorage.Shared.RefineryQueue)
local Refining = require(script.Parent.Parent.Lib.Refining)
local Signal = require(ReplicatedStorage.Packages.Signal)

local PlayerStateService = Knit.CreateService({
	Name = "PlayerStateService",
	Client = {
		State = Knit.CreateProperty(nil),
		BackpackFull = Knit.CreateSignal(),
	},
})

-- (player, amount) when Auto-Deposit put mined ore into the hopper, so
-- RefineryService can refresh the plot displays
PlayerStateService.OreAutoDeposited = Signal.new()

local DataService
local MonetizationService
local EconomyService

-- Fractional ore from debris, paid out once it reaches 1. Not saved.
local oreRemainder: { [Player]: { [string]: number } } = {}
local lastFullNotice: { [Player]: number } = {}

-- State replication (spec §12.3). Replicate() only marks the player; a Heartbeat
-- accumulator sends each marked player's snapshot once per
-- Config.Net.StateFlushInterval, so a held pickaxe no longer rebuilds and sends
-- the whole table on every hit. ReplicateNow() sends at once where the player is
-- waiting on the result. Leaderstats are only written in the flush.
local stateDirty: { [Player]: true } = {}
local leaderstatsDirty: { [Player]: true } = {}
local stateSends = 0 -- every State snapshot sent since the server started
local warnedNoStations = false

local function sum(t: { [string]: number }): number
	local total = 0
	for _, v in t do
		total += v
	end
	return total
end

function PlayerStateService:Get(player: Player): any
	local profile = DataService:GetProfile(player)
	return if profile then profile.Data else nil
end

-- Fractional mined ore belongs to the current life, alongside the saved inventory.
function PlayerStateService:ResetTransientInventory(player: Player)
	local remainders = oreRemainder[player]
	if remainders then
		table.clear(remainders)
	else
		oreRemainder[player] = {}
	end
	lastFullNotice[player] = nil
end

-- The equipped pets' perks (Shared.Pets): miner, hauler, pack, swift, merchant
function PlayerStateService:GetPetBonuses(player: Player): Pets.Bonuses
	local data = self:Get(player)
	return Pets.bonuses(if data then data.pets else Pets.fresh())
end

-- The pickaxe as it plays right now (Shared.Gear): the tier's name and ore per hit with
-- the leveled Power, swing, reach and crit, and a Swift pet's shorter swing. Tier is the
-- evolution tier.
function PlayerStateService:GetPickaxe(player: Player): any
	local data = self:Get(player)
	if not data then
		return Gear.pickaxe(1, Gear.freshPickaxeStats(1))
	end
	local pickaxe = Gear.pickaxe(data.pickaxeTier, data.pickaxeStats)
	local swift = Pets.bonuses(data.pets).swift
	if swift > 0 then
		pickaxe.Swing *= 1 - swift
	end
	return pickaxe
end

-- Backpack capacity: the leveled Capacity, the Bigger Backpack pass and a Pack pet
function PlayerStateService:GetCapacity(player: Player): number
	local data = self:Get(player)
	local base = if data then Gear.capacity(data.backpackTier, data.backpackStats) else Gear.capacity(1, Gear.freshBackpackStats(1))
	local pack = if data then Pets.bonuses(data.pets).pack else 0
	return base * MonetizationService:BackpackMult(player) * (1 + pack)
end

function PlayerStateService:GetHopperCapacity(player: Player): number
	local data = self:Get(player)
	return if data then Refining.hopperCapacity(data) else Config.Home.Stations.hopper.Levels[1].Capacity :: number
end

-- Value of the bars a player carries, before sale multipliers.
function PlayerStateService:BarValue(bars: { [string]: number }): number
	local value = 0
	for oreType, n in bars do
		value += n * (Config.Home.BarPrices[oreType] or 0)
	end
	return value
end

-- Queues the player's State for the next flush. Call it after any change.
function PlayerStateService:Replicate(player: Player)
	stateDirty[player] = true
end

-- Sends the player's State right away, for purchases, rebirths, sells and
-- deposits where the player waits on the result. Leaderstats follow in the
-- next flush.
function PlayerStateService:ReplicateNow(player: Player)
	stateDirty[player] = nil
	leaderstatsDirty[player] = true
	self:_sendState(player)
end

-- How many State snapshots have been sent since the server started. The Studio
-- DevBench hook reads it to measure the ore hot path.
function PlayerStateService:StateSendCount(): number
	return stateSends
end

function PlayerStateService:_sendState(player: Player)
	local data = self:Get(player)
	if not data then
		return
	end
	if data.stations == nil then
		if not warnedNoStations then
			warnedNoStations = true
			warn("[PlayerStateService] profile has no stations table; State not sent")
		end
		return
	end
	stateSends += 1

	local speedMult = MonetizationService:RefinerySpeedMult(data) -- Refinery Overclock
	local refineryBlocked: Refining.Blocked = nil
	if sum(data.bin) >= Refining.collectorCapacity(data) then
		refineryBlocked = "collector"
	elseif sum(data.hopper) <= 0 then
		refineryBlocked = "hopper"
	end
	local line = {
		hopper = { level = data.stations.hopper, amount = sum(data.hopper), capacity = Refining.hopperCapacity(data) },
		conveyor = { level = data.stations.conveyor, rate = Refining.conveyorRate(data) },
		refinery = {
			level = data.stations.refinery,
			rate = Refining.refineryRate(data, speedMult),
			activeOre = RefineryQueue.nextOre(data.hopper, data.refinePriority),
			progress = math.clamp(data.progress or 0, 0, 1),
			blocked = refineryBlocked,
		},
		collector = { level = data.stations.collector, amount = sum(data.bin), capacity = Refining.collectorCapacity(data) },
		rate = Refining.lineRate(data, speedMult),
	}

	local pickaxe = self:GetPickaxe(player)
	self.Client.State:SetFor(player, {
		level = data.level, -- player level (Shared.Levels)
		xp = data.xp,
		xpNeeded = Levels.xpToNext(data.level) or 0, -- 0 at the max level
		pickaxeTier = data.pickaxeTier,
		backpackTier = data.backpackTier,
		pickaxeStats = table.clone(data.pickaxeStats), -- stat levels (Shared.Gear)
		backpackStats = table.clone(data.backpackStats),
		swing = pickaxe.Swing, -- seconds between swings, as leveled and with a Swift pet
		reach = pickaxe.Reach, -- studs
		pets = { -- Shared.Pets: owned with level and XP, the ones out, the slots and their perks
			owned = Pets.cloneOwned(data.pets.owned),
			equipped = table.clone(data.pets.equipped),
			slots = Pets.slots(data.rebirths),
			bonuses = Pets.bonuses(data.pets),
		},
		backpack = data.backpack,
		carried = sum(data.backpack),
		capacity = self:GetCapacity(player),
		cash = data.cash,
		shards = data.shards,
		bars = sum(data.bars),
		barInventory = table.clone(data.bars), -- carried bars, detached from the saved profile
		collectorInventory = table.clone(data.bin), -- stored bars stay separate from the sale total
		-- what a sale would pay: the bars' base value times rebirth, index and VIP
		barValue = math.floor(self:BarValue(data.bars) * EconomyService:SaleMultiplier(player)),
		hopper = sum(data.hopper),
		hopperInventory = table.clone(data.hopper), -- waiting ore, detached from the saved profile
		refinePriority = RefineryQueue.order(data.refinePriority, data.hopper),
		hopperCapacity = self:GetHopperCapacity(player),
		line = line,
		rebirths = data.rebirths, -- sets the cash multiplier (spec §8.3)
		index = data.index, -- mineral index: mineral id -> count found (spec §8.2)
		credits = data.credits, -- unused Call a Meteor credits (spec §9.2)
		overclockLeft = data.overclockLeft, -- seconds of Refinery Overclock left
		plotId = player:GetAttribute("PlotId"),
	})
end

-- Writes leaderstats only when the shown value changed, so small cash gains
-- that format the same don't replicate to every client.
function PlayerStateService:_updateLeaderstats(player: Player)
	local data = self:Get(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not data or not leaderstats then
		return
	end
	local cash = leaderstats:FindFirstChild("Cash") :: StringValue
	local shards = leaderstats:FindFirstChild("Shards") :: IntValue
	local cashText = Format.cash(data.cash)
	if cash.Value ~= cashText then
		cash.Value = cashText
	end
	if shards.Value ~= data.shards then
		shards.Value = data.shards
	end
end

-- Sends State to every player marked since the last flush, then brings their
-- leaderstats (and those of players sent through ReplicateNow) up to date.
-- Each player runs in its own thread, so an error for one player can't drop
-- the rest of the batch.
function PlayerStateService:_flush()
	local toSend = stateDirty
	stateDirty = {}
	for player in toSend do
		if player.Parent then
			leaderstatsDirty[player] = true
			task.spawn(self._sendState, self, player)
		end
	end

	local toUpdate = leaderstatsDirty
	leaderstatsDirty = {}
	for player in toUpdate do
		if player.Parent then
			task.spawn(self._updateLeaderstats, self, player)
		end
	end
end

-- Adds ore to the backpack up to its capacity. Fractional amounts (debris) are
-- banked until they add up to a whole ore. With Auto-Deposit the ore goes into the
-- hopper first and only what doesn't fit goes to the backpack. Returns the whole
-- ore actually added, hopper and backpack together.
function PlayerStateService:AddOre(player: Player, oreType: string, amount: number): number
	local data = self:Get(player)
	local remainders = oreRemainder[player]
	if not data or not remainders or amount <= 0 then
		return 0
	end

	local space = self:GetCapacity(player) - sum(data.backpack)
	local hopperSpace = if MonetizationService:HasAutoDeposit(player)
		then math.max(Refining.hopperCapacity(data) - sum(data.hopper), 0)
		else 0
	if space <= 0 and hopperSpace <= 0 then
		-- This hit's ore is lost; the fraction banked from earlier hits (an under-tier
		-- meteor's Crystal can be most of one ore) is kept
		local now = os.clock()
		if now - (lastFullNotice[player] or 0) > 3 then
			lastFullNotice[player] = now
			self.Client.BackpackFull:Fire(player)
		end
		return 0
	end

	local pending = (remainders[oreType] or 0) + amount
	local whole = math.floor(pending)
	remainders[oreType] = pending - whole
	local deposited = math.min(whole, hopperSpace)
	local added = math.min(whole - deposited, math.max(space, 0))
	if deposited > 0 then
		data.hopper[oreType] = (data.hopper[oreType] or 0) + deposited
		self.OreAutoDeposited:Fire(player, deposited)
	end
	if added > 0 then
		data.backpack[oreType] = (data.backpack[oreType] or 0) + added
	end
	if deposited + added > 0 then
		self:Replicate(player)
	end
	return deposited + added
end

-- True when mined ore would find room right now: in the backpack, or in the hopper with
-- Auto-Deposit. Callers that spend a per-meteor allowance on each hit check it first, so a
-- full backpack doesn't burn the allowance on ore that is dropped.
function PlayerStateService:HasOreRoom(player: Player): boolean
	local data = self:Get(player)
	if not data then
		return false
	end
	if self:GetCapacity(player) - sum(data.backpack) > 0 then
		return true
	end
	return MonetizationService:HasAutoDeposit(player) and Refining.hopperCapacity(data) - sum(data.hopper) > 0
end

-- Adds mined ore straight to the hopper (a miner pet's ore), up to its capacity. Fractions
-- are banked like AddOre's. Returns the whole ore added.
function PlayerStateService:AddOreToHopper(player: Player, oreType: string, amount: number): number
	local data = self:Get(player)
	local remainders = oreRemainder[player]
	if not data or not remainders or amount <= 0 then
		return 0
	end
	local room = Refining.hopperCapacity(data) - sum(data.hopper)
	if room <= 0 then
		return 0
	end
	local pending = (remainders[oreType] or 0) + amount
	local whole = math.floor(pending)
	remainders[oreType] = pending - whole
	local added = math.min(whole, room)
	if added > 0 then
		data.hopper[oreType] = (data.hopper[oreType] or 0) + added
		self.OreAutoDeposited:Fire(player, added)
		self:Replicate(player)
	end
	return added
end

-- Moves up to `amount` whole ore from the backpack to the hopper (a Hauler pet), in the
-- player's refining order, as far as the hopper has room. Returns the ore moved.
function PlayerStateService:MoveBackpackToHopper(player: Player, amount: number): number
	local data = self:Get(player)
	if not data then
		return 0
	end
	local room = Refining.hopperCapacity(data) - sum(data.hopper)
	local budget = math.min(math.floor(amount), room)
	local moved = 0
	if budget <= 0 then
		return 0
	end
	for _, oreType in RefineryQueue.order(data.refinePriority, data.backpack) do
		local have = data.backpack[oreType] or 0
		local n = math.min(have, budget - moved)
		if n > 0 then
			data.backpack[oreType] = have - n
			if data.backpack[oreType] <= 0 then
				data.backpack[oreType] = nil
			end
			data.hopper[oreType] = (data.hopper[oreType] or 0) + n
			moved += n
		end
	end
	if moved > 0 then
		self.OreAutoDeposited:Fire(player, moved)
		self:Replicate(player)
	end
	return moved
end

function PlayerStateService:AddShards(player: Player, amount: number)
	local data = self:Get(player)
	if not data then
		return
	end
	data.shards += amount
	self:Replicate(player)
end

function PlayerStateService:AddCash(player: Player, amount: number)
	local data = self:Get(player)
	if not data then
		return
	end
	data.cash += amount
	self:Replicate(player)
end

function PlayerStateService:KnitInit()
	DataService = Knit.GetService("DataService")
	MonetizationService = Knit.GetService("MonetizationService")
	EconomyService = Knit.GetService("EconomyService")
end

function PlayerStateService:KnitStart()
	local function addLeaderstats(player: Player)
		local leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		local cash = Instance.new("StringValue")
		cash.Name = "Cash"
		cash.Parent = leaderstats
		local shards = Instance.new("IntValue")
		shards.Name = "Shards"
		shards.Parent = leaderstats
		leaderstats.Parent = player
	end

	Players.PlayerAdded:Connect(addLeaderstats)
	for _, player in Players:GetPlayers() do
		addLeaderstats(player)
	end

	DataService.ProfileLoaded:Connect(function(player)
		oreRemainder[player] = {}
		self:ReplicateNow(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		oreRemainder[player] = nil
		lastFullNotice[player] = nil
		stateDirty[player] = nil
		leaderstatsDirty[player] = nil
	end)

	local sinceFlush = 0
	RunService.Heartbeat:Connect(function(dt)
		sinceFlush += dt
		if sinceFlush >= Config.Net.StateFlushInterval then
			sinceFlush = 0
			self:_flush()
		end
	end)
end

return PlayerStateService
