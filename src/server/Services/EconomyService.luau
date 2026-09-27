--!strict
-- Selling bars at the Trading Post (spec §6.5). Raw ore can't be sold.
--
--   sale = base price × rebirth multiplier × index bonus × VIP bonus
--
-- Rebirth, index and VIP arrive in Week 4; their multipliers are 1 until then
-- except rebirths, which already read from the profile.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)

local EconomyService = Knit.CreateService({
	Name = "EconomyService",
	Client = {
		Sold = Knit.CreateSignal(), -- (bars, cash)
		Notice = Knit.CreateSignal(), -- (text)
	},
})

EconomyService.BarsSold = Signal.new() -- (player, bars, cash)

local PlayerStateService

function EconomyService:SaleMultiplier(player: Player): number
	local data = PlayerStateService:Get(player)
	if not data then
		return 1
	end
	local rebirth = 2 ^ (data.rebirths or 0)
	local index = 1
	local vip = 1
	return rebirth * index * vip
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
	self.Client.Sold:Fire(player, bars, cash)
	self.BarsSold:Fire(player, bars, cash)
	return cash
end

function EconomyService:KnitInit()
	PlayerStateService = Knit.GetService("PlayerStateService")
end

function EconomyService:KnitStart()
	local tradingPost = workspace:WaitForChild("Map"):WaitForChild("TownSquare"):WaitForChild("TradingPost")
	local sellPoint = tradingPost:WaitForChild("SellPoint")
	local prompt = sellPoint:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt then
		prompt.Triggered:Connect(function(player)
			self:SellAll(player)
		end)
	else
		warn("[EconomyService] TradingPost.SellPoint has no ProximityPrompt")
	end
end

return EconomyService
