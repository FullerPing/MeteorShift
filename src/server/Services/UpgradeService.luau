--!strict
-- Personal production upgrades purchased at the shared refinery.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local Price = require(ReplicatedStorage.Shared.Price)
local Signal = require(ReplicatedStorage.Packages.Signal)
local RequestGate = require(ReplicatedStorage.Shared.RequestGate)

local UpgradeService = Knit.CreateService({
	Name = "UpgradeService",
	Client = {
		Upgraded = Knit.CreateSignal(), -- (stationId, newLevel)
		Notice = Knit.CreateSignal(), -- (text)
	},
})

UpgradeService.StationUpgraded = Signal.new() -- (player, stationId, newLevel)

local PlayerStateService
local RefineryService
local lastBuyRequest: { [Player]: number } = {}

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
	local shortfall = Price.shortfall(data, nextLevel.Cost, nextLevel.Shards, stationConfig.Name .. " Lv " .. (current + 1))
	if shortfall then
		self.Client.Notice:Fire(player, shortfall)
		return false
	end

	data.cash -= nextLevel.Cost
	data.shards -= nextLevel.Shards
	data.stations[stationId] = current + 1
	-- TelemetryService hears StationUpgraded and sets flags.firstRefinery with
	-- first_refinery_bought (spec §13)
	self.Client.Upgraded:Fire(player, stationId, current + 1)
	RefineryService:Refresh(player, true)
	self.StationUpgraded:Fire(player, stationId, current + 1)
	return true
end

-- Production menu purchases require the shared refinery.
function UpgradeService.Client:BuyStation(player: Player, stationId: string): boolean
	local allowed, stamp = RequestGate.check(lastBuyRequest[player], os.clock(), 0.15)
	lastBuyRequest[player] = stamp
	if not allowed then return false end
	if typeof(stationId) ~= "string" or not Config.Home.Stations[stationId] then
		return false
	end
	if not RefineryService:CanUseMenu(player) then
		self.Server.Client.Notice:Fire(player, "Move closer to the refinery to upgrade production.")
		return false
	end
	return self.Server:BuyStation(player, stationId)
end

function UpgradeService:KnitInit()
	PlayerStateService = Knit.GetService("PlayerStateService")
	RefineryService = Knit.GetService("RefineryService")
end

function UpgradeService:KnitStart()
	Players.PlayerRemoving:Connect(function(player)
		lastBuyRequest[player] = nil
	end)
end

return UpgradeService
