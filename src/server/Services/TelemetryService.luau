--!strict
-- Analytics (spec §13) over Roblox AnalyticsService. Named TelemetryService so it
-- doesn't clash with the engine service. Every AnalyticsService call is pcall'd so
-- analytics can never break gameplay; a failing method warns once per server.
-- In Studio each event also prints one compact line so the output log proves it
-- fired (Server.Lib.Telemetry.line).
--
-- What it logs, all from the other services' server signals:
-- * Lifetime milestones, once per player, guarded by profile flags that this
--   service sets when it logs them:
--     first_meteor_joined     first validated hit on a crust node or the core (flags.firstMeteor)
--     first_core_reward       first Core Shards received, value = shards (flags.firstCoreReward)
--     first_refinery_bought   first refinery station upgrade (flags.firstRefinery)
-- * returned_offline_income on every join whose offline catch-up made bars (spec §13),
--   value = bars, field = hours away (Lib.Telemetry.hoursAway bucket).
-- * Per meteor event: the summary rows of Lib.Telemetry.eventSummary, logged against
--   one player in the server since custom events need a player.
-- * Economy: cash from selling bars and shards from core rewards are sources; pickaxe,
--   backpack and station purchases are cash and shard sinks; a rebirth sinks the cash
--   it resets. Rebirths also log a "rebirth" custom event, value = rebirth count.
-- * active_actions_per_minute every Config.Telemetry.ActionsInterval seconds per player:
--   swings, deposits, collects, sells and purchases. Players with none log nothing.
-- * Tutorial funnel steps, which TutorialService sends through :funnel.

local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local Telemetry = require(script.Parent.Parent.Lib.Telemetry)

local TelemetryService = Knit.CreateService({
	Name = "TelemetryService",
	Client = {},
})

local CASH = "Cash"
local SHARDS = "Shards"
local SHOP = Enum.AnalyticsEconomyTransactionType.Shop.Name
local GAMEPLAY = Enum.AnalyticsEconomyTransactionType.Gameplay.Name
local SOURCE = Enum.AnalyticsEconomyFlowType.Source
local SINK = Enum.AnalyticsEconomyFlowType.Sink

local IS_STUDIO = RunService:IsStudio()

local PlayerStateService

local warned: { [string]: boolean } = {}
local actions: { [Player]: number } = {}
-- Who hit a crust node / the core during the current meteor event, by UserId so
-- players who left still count. Reset when a meteor lands.
local nodeHitters: { [number]: boolean } = {}
local coreHitters: { [number]: boolean } = {}

local function call(method: string, fn: () -> ())
	local ok, err = pcall(fn)
	if not ok and not warned[method] then
		warned[method] = true
		warn("[TelemetryService] " .. method .. " failed (further failures are silent):", err)
	end
end

local function count(set: { [number]: boolean }): number
	local n = 0
	for _ in set do
		n += 1
	end
	return n
end

-- A custom event. `fields` is up to three low-cardinality strings (CustomField01..03).
function TelemetryService:custom(player: Player, name: string, value: number?, fields: { string }?)
	if IS_STUDIO then
		print(Telemetry.line("custom", name, player.Name, value, fields))
	end
	call("LogCustomEvent", function()
		AnalyticsService:LogCustomEvent(player, name, value or 1, Telemetry.fields(fields))
	end)
end

-- An economy event. `amount` is what moved (positive), `endingBalance` what the
-- player holds of `currency` afterwards, `transactionType` an
-- Enum.AnalyticsEconomyTransactionType name, `sku` what it was for.
function TelemetryService:economy(
	player: Player,
	flowType: Enum.AnalyticsEconomyFlowType,
	currency: string,
	amount: number,
	endingBalance: number,
	transactionType: string,
	sku: string
)
	if amount <= 0 then
		return
	end
	if IS_STUDIO then
		print(Telemetry.line("economy", flowType.Name .. " " .. currency, player.Name, amount, { transactionType, sku }))
	end
	call("LogEconomyEvent", function()
		-- Documented order: (player, flowType, currencyType, amount, endingBalance, transactionType, itemSku, customFields?)
		-- https://create.roblox.com/docs/reference/engine/classes/AnalyticsService#LogEconomyEvent
		AnalyticsService:LogEconomyEvent(player, flowType, currency, amount, endingBalance, transactionType, sku)
	end)
end

-- An onboarding funnel step (the tutorial, spec §11).
function TelemetryService:funnel(player: Player, step: number, stepName: string)
	if IS_STUDIO then
		print(Telemetry.line("funnel", step .. " " .. stepName, player.Name))
	end
	call("LogOnboardingFunnelStepEvent", function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step, stepName)
	end)
end

-- Logs a lifetime milestone the first time only: sets profile flag `flag` and
-- logs custom event `name`. Returns true when it logged.
function TelemetryService:milestone(player: Player, flag: string, name: string, value: number?, fields: { string }?): boolean
	local data = PlayerStateService:Get(player)
	local flags: { [string]: boolean }? = if data then data.flags :: any else nil
	if not flags or flags[flag] then
		return false
	end
	flags[flag] = true
	self:custom(player, name, value, fields)
	return true
end

local function act(player: Player)
	Telemetry.countAction(actions, player)
end

-- The cash and shard sinks of a purchase priced `item` ({ Cost, Shards }).
function TelemetryService:_purchase(player: Player, item: { Cost: number, Shards: number }, sku: string)
	local data = PlayerStateService:Get(player)
	if not data then
		return
	end
	self:economy(player, SINK, CASH, item.Cost, data.cash, SHOP, sku)
	self:economy(player, SINK, SHARDS, item.Shards, data.shards, SHOP, sku)
end

function TelemetryService:_eventEnded(meteorType: string, cracked: boolean, secondsToCrack: number?)
	local players = Players:GetPlayers()
	local reporter = players[1]
	if reporter then
		local rows = Telemetry.eventSummary({
			MeteorType = meteorType,
			Cracked = cracked,
			Players = #players,
			NodeHitters = count(nodeHitters),
			CoreHitters = count(coreHitters),
			SecondsToCrack = secondsToCrack,
		})
		for _, row in rows do
			self:custom(reporter, row.Name, row.Value, row.Fields)
		end
	end
	table.clear(nodeHitters)
	table.clear(coreHitters)
end

function TelemetryService:_logActions()
	for player, n in Telemetry.drainActions(actions) do
		if player.Parent then
			self:custom(player, "active_actions_per_minute", n)
		end
	end
end

function TelemetryService:KnitInit()
	PlayerStateService = Knit.GetService("PlayerStateService")
end

function TelemetryService:KnitStart()
	local NodeService = Knit.GetService("NodeService")
	local MeteorService = Knit.GetService("MeteorService")
	local RewardService = Knit.GetService("RewardService")
	local RefineryService = Knit.GetService("RefineryService")
	local EconomyService = Knit.GetService("EconomyService")
	local ShopService = Knit.GetService("ShopService")
	local UpgradeService = Knit.GetService("UpgradeService")
	local RebirthService = Knit.GetService("RebirthService")

	NodeService.Hit:Connect(function(player: Player, kind: string)
		act(player)
		if kind == "Crust" or kind == "Core" then
			local set = if kind == "Core" then coreHitters else nodeHitters
			set[player.UserId] = true
			self:milestone(player, "firstMeteor", "first_meteor_joined")
		end
	end)
	MeteorService.Landed:Connect(function()
		table.clear(nodeHitters)
		table.clear(coreHitters)
	end)
	MeteorService.Ended:Connect(function(meteorType: string, cracked: boolean, secondsToCrack: number?)
		self:_eventEnded(meteorType, cracked, secondsToCrack)
	end)

	RewardService.ShardsAwarded:Connect(function(player: Player, shards: number)
		self:milestone(player, "firstCoreReward", "first_core_reward", shards)
		local data = PlayerStateService:Get(player)
		if data then
			self:economy(player, SOURCE, SHARDS, shards, data.shards, GAMEPLAY, "core_reward")
		end
	end)

	RefineryService.OreDeposited:Connect(act)
	RefineryService.BarsCollected:Connect(act)
	RefineryService.CaughtUp:Connect(function(player: Player, awaySeconds: number, bars: number)
		if bars > 0 then
			local hours = Telemetry.hoursAway(awaySeconds, Config.Telemetry.HoursAwayCap)
			self:custom(player, "returned_offline_income", bars, { hours })
		end
	end)

	EconomyService.BarsSold:Connect(function(player: Player, _bars: number, cash: number)
		act(player)
		local data = PlayerStateService:Get(player)
		if data then
			self:economy(player, SOURCE, CASH, cash, data.cash, GAMEPLAY, "sell_bars")
		end
	end)

	ShopService.ItemBought:Connect(function(player: Player, kind: string, tier: number)
		act(player)
		local list: { any } = if kind == "pickaxe" then Config.Pickaxes else Config.Backpacks
		local item = list[tier]
		if item then
			self:_purchase(player, item, kind .. "_" .. tier)
		end
	end)

	UpgradeService.StationUpgraded:Connect(function(player: Player, stationId: string, level: number)
		act(player)
		local station = Config.Home.Stations[stationId]
		local item = station and station.Levels[level]
		if item then
			self:_purchase(player, item, stationId .. "_" .. level)
		end
		if stationId == "refinery" then
			self:milestone(player, "firstRefinery", "first_refinery_bought", level)
		end
	end)

	RebirthService.Reborn:Connect(function(player: Player, rebirths: number, cashSpent: number)
		self:custom(player, "rebirth", rebirths)
		self:economy(player, SINK, CASH, cashSpent, 0, GAMEPLAY, "rebirth")
	end)

	Players.PlayerRemoving:Connect(function(player)
		actions[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(Config.Telemetry.ActionsInterval)
			self:_logActions()
		end
	end)
end

return TelemetryService
