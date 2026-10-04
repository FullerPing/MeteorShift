--!strict
-- Selling bars at the Trading Post (spec §6.5). Raw ore can't be sold.
--
--   sale = base price × rebirth multiplier × index bonus × VIP bonus × Merchant pet bonus
--
-- The rebirth multiplier is Shared.Rebirth.multiplier of the profile's rebirths
-- (×2 per rebirth, multiplicative, spec §8.3). The index bonus adds each completed
-- mineral index page's CashBonus, additive across pages (spec §8.2,
-- Shared.MineralIndex.cashBonus). The VIP pass adds Config.Monetization.VIPBarBonus
-- (+10%, spec §9.1) as its own factor (MonetizationService:VIPMult).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local MineralIndex = require(ReplicatedStorage.Shared.MineralIndex)
local Rebirth = require(ReplicatedStorage.Shared.Rebirth)
local Pets = require(ReplicatedStorage.Shared.Pets)

local EconomyService = Knit.CreateService({
	Name = "EconomyService",
	Client = {
		Sold = Knit.CreateSignal(), -- (bars, cash)
		Notice = Knit.CreateSignal(), -- (text)
	},
})

EconomyService.BarsSold = Signal.new() -- (player, bars, cash)

local PlayerStateService
local MonetizationService

function EconomyService:SaleMultiplier(player: Player): number
	local data = PlayerStateService:Get(player)
	if not data then
		return 1
	end
	local rebirth = Rebirth.multiplier(data.rebirths)
	local index = MineralIndex.cashBonus(data.index)
	local vip = MonetizationService:VIPMult(player)
	local merchant = 1 + Pets.bonuses(data.pets).merchant -- a Merchant pet
	return rebirth * index * vip * merchant
end

function EconomyService:SellAll(player: Player): number
	local data = PlayerStateService:Get(player)
	if not data then
		return 0
	end
	local bars = 0
	for _, n in data.bars do
		bars += n
	end
	if bars <= 0 then
		self.Client.Notice:Fire(player, "No bars to sell. Collect them from your refineries first.")
		return 0
	end
	local cash = math.floor(PlayerStateService:BarValue(data.bars) * self:SaleMultiplier(player))
	table.clear(data.bars)
	data.stats.barsSold = (data.stats.barsSold or 0) + bars
	PlayerStateService:AddCash(player, cash)
	PlayerStateService:ReplicateNow(player)
	self.Client.Sold:Fire(player, bars, cash)
	self.BarsSold:Fire(player, bars, cash)
	return cash
end

-- The foundry menu sells only this caller's carried bars. Quantities and value
-- come from the saved server profile, using the Trading Post's existing rules.
function EconomyService.Client:SellAll(player: Player): number
	return self.Server:SellAll(player)
end

function EconomyService:KnitInit()
	PlayerStateService = Knit.GetService("PlayerStateService")
	MonetizationService = Knit.GetService("MonetizationService")
end

-- Bars sell from the HUD. A Trading Post saved in the town square sells them too
-- (TownSquare.TradingPost.SellPoint's ProximityPrompt); the current map has none.
function EconomyService:KnitStart()
	local townSquare = workspace:WaitForChild("Map"):FindFirstChild("TownSquare")
	local tradingPost = if townSquare then townSquare:FindFirstChild("TradingPost") else nil
	if not tradingPost then
		return
	end
	local sellPoint = tradingPost:FindFirstChild("SellPoint")
	local prompt = if sellPoint then sellPoint:FindFirstChildWhichIsA("ProximityPrompt", true) else nil
	if prompt then
		prompt.Triggered:Connect(function(player)
			self:SellAll(player)
		end)
	else
		warn("[EconomyService] TradingPost.SellPoint has no ProximityPrompt")
	end
end

return EconomyService
