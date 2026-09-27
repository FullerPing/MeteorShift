--!strict
-- Upgrades for the four plot stations (hopper, conveyor, refinery, collection
-- post). Each station carries an "Upgrade" ProximityPrompt; the server checks
-- ownership, price and max level. Pickaxe and backpack purchases join this in
-- the Week 3 shop.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local UpgradeService = Knit.CreateService({
	Name = "UpgradeService",
	Client = {
		Upgraded = Knit.CreateSignal(), -- (stationId, newLevel)
		Notice = Knit.CreateSignal(), -- (text)
	},
})

local PlayerStateService
local PlotService
local RefineryService

-- Returns true when the upgrade went through.
function UpgradeService:BuyStation(player: Player, stationId: string): boolean
	local stationConfig = Config.Home.Stations[stationId]
	local data = PlayerStateService:Get(player)
	if not stationConfig or not data then
		return false
	end
	local current = data.stations[stationId]
	local nextLevel = stationConfig.Levels[current + 1]
	if not nextLevel then
		self.Client.Notice:Fire(player, stationConfig.Name .. " is already at max level.")
		return false
	end
	if data.cash < nextLevel.Cost then
		self.Client.Notice:Fire(player, string.format(
			"Need %s for %s Lv %d (you have %s).",
			Format.cash(nextLevel.Cost),
			stationConfig.Name,
			current + 1,
			Format.cash(data.cash)
		))
		return false
	end
	if data.shards < nextLevel.Shards then
		self.Client.Notice:Fire(player, string.format(
			"Need %d Core Shards for %s Lv %d. Crack meteor cores to earn them!",
			nextLevel.Shards,
			stationConfig.Name,
			current + 1
		))
		return false
	end

	data.cash -= nextLevel.Cost
	data.shards -= nextLevel.Shards
	data.stations[stationId] = current + 1
	if stationId == "refinery" then
		data.flags.firstRefinery = true -- first_refinery_bought (spec §13)
	end
	self.Client.Upgraded:Fire(player, stationId, current + 1)
	RefineryService:Refresh(player)
	return true
end

function UpgradeService:_connect(player: Player, stations: Model)
	for _, model in stations:GetChildren() do
		local stationId = model:GetAttribute("StationId")
		local prompt = model:FindFirstChild("Upgrade", true)
		if typeof(stationId) == "string" and prompt and prompt:IsA("ProximityPrompt") then
			prompt.Triggered:Connect(function(who)
				if who == player then
					self:BuyStation(player, stationId)
				else
					self.Client.Notice:Fire(who, "That's " .. player.DisplayName .. "'s plot. Yours is Plot " .. tostring(who:GetAttribute("PlotId")) .. ".")
				end
			end)
		end
	end
end

function UpgradeService:KnitInit()
	PlayerStateService = Knit.GetService("PlayerStateService")
	PlotService = Knit.GetService("PlotService")
	RefineryService = Knit.GetService("RefineryService")
end

function UpgradeService:KnitStart()
	PlotService.PlotAssigned:Connect(function(player, _plot)
		local stations = PlotService:GetStations(player)
		if stations then
			self:_connect(player, stations)
		end
	end)
end

return UpgradeService
