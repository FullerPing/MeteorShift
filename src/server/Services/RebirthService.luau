--!strict
-- Rebirth, "Relocate the Colony" (spec §8.3). The client asks from the HUD's
-- REBIRTH panel; the server re-checks the price (Shared.Rebirth.cost) against the
-- player's cash.
--
-- A rebirth resets cash to 0, the pickaxe and backpack to tier 1 and empties the
-- backpack. Everything else is kept (spec §8.3 defaults): plot stations, hopper,
-- collection bin, carried bars, Core Shards, the mineral index, décor and flags.
-- In return the rebirth count goes up by one, and with it the permanent bar sale
-- multiplier (Shared.Rebirth.multiplier, read by EconomyService:SaleMultiplier).
-- The server hears about it: "<name> relocated the colony! (Rebirth N, ×M cash)".

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Format = require(ReplicatedStorage.Shared.Format)
local Rebirth = require(ReplicatedStorage.Shared.Rebirth)

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
	data.cash = 0
	data.pickaxeTier = 1
	data.backpackTier = 1
	table.clear(data.backpack)
	rebirths += 1
	data.rebirths = rebirths

	ShopService:ApplyPickaxe(player)
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
	return self.Server:Rebirth(player)
end

function RebirthService:KnitInit()
	PlayerStateService = Knit.GetService("PlayerStateService")
	ShopService = Knit.GetService("ShopService")
	RewardService = Knit.GetService("RewardService")
end

return RebirthService
