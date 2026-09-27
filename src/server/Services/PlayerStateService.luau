--!strict
-- Week 1 placeholder for player state: pickaxe, backpack, stored ore and Core Shards.
-- Lives in memory only. Week 2's DataService (ProfileStore) replaces the storage,
-- keeping this service's API so gameplay code doesn't change.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)

export type State = {
	pickaxeTier: number,
	backpackTier: number,
	backpack: { [string]: number }, -- ore carried
	stored: { [string]: number }, -- ore dropped at the town silo (stands in for the Week 2 hopper)
	oreRemainder: { [string]: number }, -- fractional ore from debris, paid out once it reaches 1
	cash: number,
	shards: number,
}

local PlayerStateService = Knit.CreateService({
	Name = "PlayerStateService",
	Client = {
		State = Knit.CreateProperty(nil),
		BackpackFull = Knit.CreateSignal(),
	},
})

local states: { [Player]: State } = {}
local lastFullNotice: { [Player]: number } = {}

local function sum(t: { [string]: number }): number
	local total = 0
	for _, v in t do
		total += v
	end
	return total
end

function PlayerStateService:_replicate(player: Player)
	local state = states[player]
	if not state then
		return
	end
	local capacity = self:GetCapacity(player)
	self.Client.State:SetFor(player, {
		pickaxeTier = state.pickaxeTier,
		backpackTier = state.backpackTier,
		backpack = state.backpack,
		carried = sum(state.backpack),
		capacity = capacity,
		stored = sum(state.stored),
		cash = state.cash,
		shards = state.shards,
	})

	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		(leaderstats:FindFirstChild("Shards") :: IntValue).Value = state.shards;
		(leaderstats:FindFirstChild("Ore") :: IntValue).Value = sum(state.stored) + sum(state.backpack)
	end
end

function PlayerStateService:Get(player: Player): State?
	return states[player]
end

function PlayerStateService:GetPickaxe(player: Player): typeof(Config.Pickaxes[1])
	local state = states[player]
	return Config.Pickaxes[if state then state.pickaxeTier else 1]
end

function PlayerStateService:GetCapacity(player: Player): number
	local state = states[player]
	return Config.Backpacks[if state then state.backpackTier else 1].Capacity
end

function PlayerStateService:IsBackpackFull(player: Player): boolean
	local state = states[player]
	return state ~= nil and sum(state.backpack) >= self:GetCapacity(player)
end

-- Adds ore to the backpack up to its capacity. Fractional amounts (debris) are
-- banked until they add up to a whole ore. Returns the whole ore actually added.
function PlayerStateService:AddOre(player: Player, oreType: string, amount: number): number
	local state = states[player]
	if not state or amount <= 0 then
		return 0
	end

	local pending = (state.oreRemainder[oreType] or 0) + amount
	local whole = math.floor(pending)
	local space = self:GetCapacity(player) - sum(state.backpack)
	local added = math.clamp(whole, 0, math.max(space, 0))

	if space <= 0 then
		state.oreRemainder[oreType] = 0
		local now = os.clock()
		if now - (lastFullNotice[player] or 0) > 3 then
			lastFullNotice[player] = now
			self.Client.BackpackFull:Fire(player)
		end
		return 0
	end

	state.oreRemainder[oreType] = pending - whole
	state.backpack[oreType] = (state.backpack[oreType] or 0) + added
	self:_replicate(player)
	return added
end

-- Placeholder drop-off until the Week 2 hopper exists.
function PlayerStateService:DepositAll(player: Player): number
	local state = states[player]
	if not state then
		return 0
	end
	local moved = 0
	for oreType, amount in state.backpack do
		state.stored[oreType] = (state.stored[oreType] or 0) + amount
		moved += amount
	end
	table.clear(state.backpack)
	if moved > 0 then
		self:_replicate(player)
	end
	return moved
end

function PlayerStateService:AddShards(player: Player, amount: number)
	local state = states[player]
	if not state then
		return
	end
	state.shards += amount
	self:_replicate(player)
end

function PlayerStateService:KnitStart()
	local function onPlayerAdded(player: Player)
		states[player] = {
			pickaxeTier = 1,
			backpackTier = 1,
			backpack = {},
			stored = {},
			oreRemainder = {},
			cash = 0,
			shards = 0,
		}

		local leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		local shards = Instance.new("IntValue")
		shards.Name = "Shards"
		shards.Parent = leaderstats
		local ore = Instance.new("IntValue")
		ore.Name = "Ore"
		ore.Parent = leaderstats
		leaderstats.Parent = player

		self:_replicate(player)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
		lastFullNotice[player] = nil
	end)
end

return PlayerStateService
