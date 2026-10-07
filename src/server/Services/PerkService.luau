--!strict
-- Colony Perks (Config.Perks, Shared.Perks): the permanent things Core Shards buy besides pets.
-- A perk is bought one level at a time and kept through every rebirth. The panel opens at rebirth
-- Config.Perks.UnlockRebirths. The effects live where they act: Efficient Line in Refining, Station
-- Memory and Head Start in RebirthReset, Offline Training in MonetizationService:OfflineCap and Pet
-- Bond in Pets.slots. Nothing here touches mineral or egg odds.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Config = require(ReplicatedStorage.Shared.Config)
local Perks = require(ReplicatedStorage.Shared.Perks)
local RequestGate = require(ReplicatedStorage.Shared.RequestGate)

local PerkService = Knit.CreateService({
	Name = "PerkService",
	Client = {
		Notice = Knit.CreateSignal(), -- (text)
		Bought = Knit.CreateSignal(), -- (perkId, level)
	},
})

PerkService.PerkBought = Signal.new() -- (player, perkId, level, shards)

local PlayerStateService
local lastBuyRequest: { [Player]: number } = {}

-- Buys the next level of a perk with shards. Returns true when it went through.
function PerkService:Buy(player: Player, perkId: string): boolean
	local data = PlayerStateService:Get(player)
	local perk = Config.Perks.List[perkId]
	if not data or not perk then
		return false
	end
	if not Perks.unlocked(data.rebirths) then
		self.Client.Notice:Fire(player, string.format("Colony Perks open at rebirth %d.", Config.Perks.UnlockRebirths))
		return false
	end
	local cost = Perks.nextCost(data.perks, perkId)
	if not cost then
		self.Client.Notice:Fire(player, perk.Name .. " is fully upgraded.")
		return false
	end
	if data.shards < cost then
		self.Client.Notice:Fire(player, string.format("Need %d Core Shards for %s. Crack meteor cores to earn them!", cost, perk.Name))
		return false
	end
	data.shards -= cost
	data.perks[perkId] = Perks.level(data.perks, perkId) + 1
	PlayerStateService:ReplicateNow(player)
	self.Client.Bought:Fire(player, perkId, data.perks[perkId])
	self.PerkBought:Fire(player, perkId, data.perks[perkId], cost)
	return true
end

function PerkService.Client:Buy(player: Player, perkId: string): boolean
	local allowed, stamp = RequestGate.check(lastBuyRequest[player], os.clock(), 0.25)
	lastBuyRequest[player] = stamp
	if not allowed or typeof(perkId) ~= "string" then
		return false
	end
	return self.Server:Buy(player, perkId)
end

function PerkService:KnitInit()
	PlayerStateService = Knit.GetService("PlayerStateService")
end

function PerkService:KnitStart()
	Players.PlayerRemoving:Connect(function(player)
		lastBuyRequest[player] = nil
	end)
end

return PerkService
