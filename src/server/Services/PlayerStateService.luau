--!strict
-- Gameplay-facing view of a player's saved profile: pickaxe, backpack, currencies,
-- hopper and refineries. Storage is DataService; this service owns the rules and
-- replicates a compact snapshot to the owning client.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Refining = require(script.Parent.Parent.Lib.Refining)

local PlayerStateService = Knit.CreateService({
	Name = "PlayerStateService",
	Client = {
		State = Knit.CreateProperty(nil),
		BackpackFull = Knit.CreateSignal(),
	},
})

local DataService

-- Fractional ore from debris, paid out once it reaches 1. Not saved.
local oreRemainder: { [Player]: { [string]: number } } = {}
local lastFullNotice: { [Player]: number } = {}

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

function PlayerStateService:GetPickaxe(player: Player): typeof(Config.Pickaxes[1])
	local data = self:Get(player)
	return Config.Pickaxes[if data then data.pickaxeTier else 1] or Config.Pickaxes[1]
end

function PlayerStateService:GetCapacity(player: Player): number
	local data = self:Get(player)
	return (Config.Backpacks[if data then data.backpackTier else 1] or Config.Backpacks[1]).Capacity
end

function PlayerStateService:GetHopperCapacity(player: Player): number
	local data = self:Get(player)
	return if data then Refining.hopperCapacity(data) else Config.Home.Stations.hopper.Levels[1].Capacity :: number
end

function PlayerStateService:IsBackpackFull(player: Player): boolean
	local data = self:Get(player)
	return data ~= nil and sum(data.backpack) >= self:GetCapacity(player)
end

-- Value of the bars a player carries, before sale multipliers.
function PlayerStateService:BarValue(bars: { [string]: number }): number
	local value = 0
	for oreType, n in bars do
		value += n * (Config.Home.BarPrices[oreType] or 0)
	end
	return value
end

function PlayerStateService:Replicate(player: Player)
	local data = self:Get(player)
	if not data then
		return
	end

	local line = {
		hopper = { level = data.stations.hopper, amount = sum(data.hopper), capacity = Refining.hopperCapacity(data) },
		conveyor = { level = data.stations.conveyor, rate = Refining.conveyorRate(data) },
		refinery = { level = data.stations.refinery, rate = Refining.refineryRate(data) },
		collector = { level = data.stations.collector, amount = sum(data.bin), capacity = Refining.collectorCapacity(data) },
		rate = Refining.lineRate(data),
	}

	self.Client.State:SetFor(player, {
		pickaxeTier = data.pickaxeTier,
		backpackTier = data.backpackTier,
		backpack = data.backpack,
		carried = sum(data.backpack),
		capacity = self:GetCapacity(player),
		cash = data.cash,
		shards = data.shards,
		bars = sum(data.bars),
		barValue = self:BarValue(data.bars),
		hopper = sum(data.hopper),
		hopperCapacity = self:GetHopperCapacity(player),
		line = line,
		plotId = player:GetAttribute("PlotId"),
	})

	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		(leaderstats:FindFirstChild("Cash") :: StringValue).Value = Format.cash(data.cash);
		(leaderstats:FindFirstChild("Shards") :: IntValue).Value = data.shards
	end
end

-- Adds ore to the backpack up to its capacity. Fractional amounts (debris) are
-- banked until they add up to a whole ore. Returns the whole ore actually added.
function PlayerStateService:AddOre(player: Player, oreType: string, amount: number): number
	local data = self:Get(player)
	local remainders = oreRemainder[player]
	if not data or not remainders or amount <= 0 then
		return 0
	end

	local space = self:GetCapacity(player) - sum(data.backpack)
	if space <= 0 then
		remainders[oreType] = 0
		local now = os.clock()
		if now - (lastFullNotice[player] or 0) > 3 then
			lastFullNotice[player] = now
			self.Client.BackpackFull:Fire(player)
		end
		return 0
	end

	local pending = (remainders[oreType] or 0) + amount
	local whole = math.floor(pending)
	local added = math.min(whole, space)
	remainders[oreType] = pending - whole
	if added > 0 then
		data.backpack[oreType] = (data.backpack[oreType] or 0) + added
		self:Replicate(player)
	end
	return added
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
		self:Replicate(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		oreRemainder[player] = nil
		lastFullNotice[player] = nil
	end)
end

return PlayerStateService
