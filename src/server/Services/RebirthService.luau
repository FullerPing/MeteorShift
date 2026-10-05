--!strict
-- Rebirth, "Relocate the Colony" (spec §8.3). The client asks from the HUD's
-- REBIRTH panel; the server re-checks the price (Shared.Rebirth.cost) against the
-- player's cash.
--
-- Rebirth resets cash, gear, all ore/bars, other production upgrades and décor.
-- Refinery level, Core Shards and mineral-index rewards survive. Purchased value,
-- preferences and lifetime history are retained independently of gameplay resets.
-- In return the rebirth count goes up by one, and with it the permanent bar sale
-- multiplier (Shared.Rebirth.multiplier, read by EconomyService:SaleMultiplier).
-- The server hears about it: "<name> relocated the colony! (Rebirth N, ×M cash)".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Format = require(ReplicatedStorage.Shared.Format)
local Rebirth = require(ReplicatedStorage.Shared.Rebirth)
local RequestGate = require(ReplicatedStorage.Shared.RequestGate)
local RebirthReset = require(script.Parent.Parent.Lib.RebirthReset)

local RebirthService = Knit.CreateService({
	Name = "RebirthService",
	Client = {
		Notice = Knit.CreateSignal(), -- (text) why a rebirth was refused
	},
})

RebirthService.Reborn = Signal.new() -- (player, rebirths, cashSpent) for analytics

local PlayerStateService
local ShopService
local RewardService
local RefineryService
local lastRebirthRequest: { [Player]: number } = {}

-- Rebirths the player if they can pay for it. Returns true when it went through.
function RebirthService:Rebirth(player: Player): boolean
	local data = PlayerStateService:Get(player)
	if not data then
		return false
	end
	local rebirths = data.rebirths or 0
	local cost = Rebirth.cost(rebirths)
	if data.cash < cost then
		self.Client.Notice:Fire(player, "You need " .. Format.cash(cost) .. " to relocate the colony.")
		return false
	end

	local cashSpent = data.cash
	RebirthReset.apply(data, os.time())
	rebirths += 1
	data.rebirths = rebirths

	PlayerStateService:ResetTransientInventory(player)
	ShopService:ApplyPickaxe(player)
	RefineryService:ResetAfterRebirth(player)
	PlayerStateService:ReplicateNow(player)
	RewardService:Announce(
		"Rebirth",
		string.format(
			"%s relocated the colony! (Rebirth %s, ×%s cash)",
			player.DisplayName,
			Format.number(rebirths),
			Format.number(Rebirth.multiplier(rebirths))
		)
	)
	self.Reborn:Fire(player, rebirths, cashSpent)
	return true
end

function RebirthService.Client:Rebirth(player: Player): boolean
	local allowed, stamp = RequestGate.check(lastRebirthRequest[player], os.clock(), 1)
	lastRebirthRequest[player] = stamp
	if not allowed then return false end
	return self.Server:Rebirth(player)
end

function RebirthService:KnitInit()
	PlayerStateService = Knit.GetService("PlayerStateService")
	ShopService = Knit.GetService("ShopService")
	RewardService = Knit.GetService("RewardService")
	RefineryService = Knit.GetService("RefineryService")
end

function RebirthService:KnitStart()
	Players.PlayerRemoving:Connect(function(player)
		lastRebirthRequest[player] = nil
	end)
end

return RebirthService
