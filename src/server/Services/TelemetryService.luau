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
--     first_core_reward       first Core Shards received (flags.firstCoreReward)
--     first_refinery_bought   first production line upgrade (flags.firstRefinery)
--   Every milestone, session, leave, level-up and rebirth logs value 1: the dashboards sum values (Lib.Telemetry).
-- * returned_offline_income on every join whose offline catch-up made bars (spec §13),
--   value = bars, field = hours away (Lib.Telemetry.hoursAway bucket).
-- * Per meteor event: the summary rows of Lib.Telemetry.eventSummary, logged against
--   one player in the server since custom events need a player.
-- * Economy: cash from selling bars and shards from core rewards are sources; pickaxe,
--   backpack and station purchases are cash and shard sinks; a rebirth sinks the cash
--   it resets. Rebirths also log a "rebirth" custom event, field = the new rebirth stage.
-- * active_actions_per_minute every Config.Telemetry.ActionsInterval seconds per player:
--   swings, deposits, collects, sells and purchases. Players with none log nothing.
--   On the same timer, field_rocks_mined per player and field (value = rocks broken, field = the ore field
--   id or "Filler"), so we can see which fields people use between meteors.
-- * player_left on every leave (Lib.Telemetry.playerLeft): fields = the meteor
--   cycle phase (countdown, meteor, aftermath), a session-length bucket and the tutorial state.
-- * Tutorial funnel steps, which TutorialService sends through :funnel.
-- * Monetization (spec §9): "pass_bought" when a game pass is bought in game
--   (field = pass key) and "product_bought" per granted developer product receipt
--   (fields = product key, outcome: "called", "credited" or "granted"). "purchase_prompt" every time a
--   pass or product prompt closes (fields = key, "pass"/"product", "bought"/"closed"): prompts vs buys is
--   the conversion rate of each offer.
-- * session_start on every profile load (Lib.Telemetry.sessionStart): fields = days-away bucket ("new" for a first join), rebirth stage, tutorial state. With player_left this
--   gives D1/D7 return and how long each stage plays.
-- * meteor_participation per player in the server when a meteor event ends: value = their hits on it,
--   fields = meteor type, outcome and role (core, crust or none). meteor_event_seconds_to_core joins the summary.
-- * Progression: level_up (fields = rebirth stage, level), egg_hatched (fields = egg, rarity,
--   new/duplicate), perk_bought (value = perk level, field = perk), index_page_completed (field = page),
--   field_travel (field = ore field, from DebrisService). Egg and perk shards are logged as sinks.
-- * Reward sources through :earned: daily streak, quests, codes and field rocks' cash (their services call it).
-- * menu_opened per player and menu every ActionsInterval (value = opens), reported by the client's
--   TelemetryController through Client.MenuOpened, checked against Config.Telemetry.Menus and capped.

local AnalyticsService = game:GetService("AnalyticsService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local Pets = require(ReplicatedStorage.Shared.Pets)
local Price = require(ReplicatedStorage.Shared.Price)
local Rebirth = require(ReplicatedStorage.Shared.Rebirth)
local Telemetry = require(script.Parent.Parent.Lib.Telemetry)
local SafeLoop = require(script.Parent.Parent.Lib.SafeLoop)

local TelemetryService = Knit.CreateService({
	Name = "TelemetryService",
	Client = {
		MenuOpened = Knit.CreateSignal(), -- client -> server: (menuName) a menu in Config.Telemetry.Menus opened
	},
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
local rocksMined: { [Player]: { [string]: number } } = {}
local joinedAt: { [Player]: number } = {}
-- Who hit a crust node / the core during the current meteor event, by UserId so
-- players who left still count. Reset when a meteor lands.
local nodeHitters: { [number]: boolean } = {}
local coreHitters: { [number]: boolean } = {}
-- Each player's hits on the current meteor (crust and core), for meteor_participation
local participation: { [Player]: Telemetry.Participation } = {}
local landedAt: number? = nil
local coreOpenedAfter: number? = nil -- seconds from the landing to the core opening, this event
-- Menu opens this window: per player and menu, plus each player's total for the cap
local menuOpens: { [Player]: { [string]: number } } = {}
local menuTotals: { [Player]: number } = {}

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

-- Cash and shards a reward handed out (daily streak, quests, codes, field cash), as economy sources.
-- Call after the currency was added so the ending balance includes it.
function TelemetryService:earned(player: Player, sku: string, cash: number, shards: number)
	local data = PlayerStateService:Get(player)
	if not data then
		return
	end
	self:economy(player, SOURCE, CASH, cash, data.cash, GAMEPLAY, sku)
	self:economy(player, SOURCE, SHARDS, shards, data.shards, GAMEPLAY, sku)
end

local function act(player: Player)
	Telemetry.countAction(actions, player)
end

-- The cash and shard sinks of a purchase priced `item` ({ Cost, Shards }). A table price
-- (`inflate`) is what the player paid after their rebirths' price inflation.
function TelemetryService:_purchase(player: Player, item: { Cost: number, Shards: number }, sku: string, inflate: boolean?)
	local data = PlayerStateService:Get(player)
	if not data then
		return
	end
	local cost = if inflate then Price.scaled(item.Cost, Rebirth.priceMult(data.rebirths)) else item.Cost
	self:economy(player, SINK, CASH, cost, data.cash, SHOP, sku)
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
			SecondsToCore = coreOpenedAfter,
		})
		for _, row in rows do
			self:custom(reporter, row.Name, row.Value, row.Fields)
		end
	end
	for _, player in players do
		local row = Telemetry.participation(meteorType, cracked, participation[player])
		self:custom(player, row.Name, row.Value, row.Fields)
	end
	table.clear(nodeHitters)
	table.clear(coreHitters)
	table.clear(participation)
	coreOpenedAfter = nil
end

function TelemetryService:_logActions()
	for player, n in Telemetry.drainActions(actions) do
		if player.Parent then
			self:custom(player, "active_actions_per_minute", n)
		end
	end
	for player, fields in rocksMined do
		if player.Parent then
			for field, n in fields do
				self:custom(player, "field_rocks_mined", n, { field })
			end
		end
	end
	table.clear(rocksMined)
	for player, menus in menuOpens do
		if player.Parent then
			for menu, n in menus do
				self:custom(player, "menu_opened", n, { menu })
			end
		end
	end
	table.clear(menuOpens)
	table.clear(menuTotals)
end

-- A purchase prompt closed: logs which offer it was and whether it sold
function TelemetryService:_prompt(player: Player?, kind: "pass" | "product", id: number, purchased: boolean)
	local list: any = if kind == "pass" then Config.Monetization.Passes else Config.Monetization.Products
	local key = Telemetry.keyForId(list, id)
	if player and key then
		self:custom(player, "purchase_prompt", 1, { key, kind, if purchased then "bought" else "closed" })
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
	local MonetizationService = Knit.GetService("MonetizationService")
	local DebrisService = Knit.GetService("DebrisService")
	local DataService = Knit.GetService("DataService")
	local LevelService = Knit.GetService("LevelService")
	local PetService = Knit.GetService("PetService")
	local PerkService = Knit.GetService("PerkService")
	local IndexService = Knit.GetService("IndexService")

	NodeService.Hit:Connect(function(player: Player, kind: string)
		act(player)
		if kind == "Crust" or kind == "Core" then
			local set = if kind == "Core" then coreHitters else nodeHitters
			set[player.UserId] = true
			local part = participation[player] or { Hits = 0, Core = false }
			participation[player] = part
			part.Hits += 1
			part.Core = part.Core or kind == "Core"
			self:milestone(player, "firstMeteor", "first_meteor_joined")
		end
	end)
	MeteorService.Landed:Connect(function()
		table.clear(nodeHitters)
		table.clear(coreHitters)
		table.clear(participation)
		landedAt = os.clock()
		coreOpenedAfter = nil
	end)
	MeteorService.CoreUnlocked:Connect(function()
		if landedAt then
			coreOpenedAfter = os.clock() - landedAt
		end
	end)
	MeteorService.Ended:Connect(function(meteorType: string, cracked: boolean, secondsToCrack: number?)
		self:_eventEnded(meteorType, cracked, secondsToCrack)
	end)

	RewardService.ShardsAwarded:Connect(function(player: Player, shards: number)
		self:milestone(player, "firstCoreReward", "first_core_reward")
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
			self:_purchase(player, item, kind .. "_" .. tier, true)
		end
	end)

	ShopService.StatUpgraded:Connect(function(player: Player, kind: string, level: number, cash: number)
		act(player)
		self:_purchase(player, { Cost = cash, Shards = 0 }, kind .. "_level_" .. level)
	end)

	UpgradeService.LineUpgraded:Connect(function(player: Player, level: number, cash: number)
		act(player)
		self:_purchase(player, { Cost = cash, Shards = 0 }, "line_" .. level)
		self:milestone(player, "firstRefinery", "first_refinery_bought", level)
	end)

	RebirthService.Reborn:Connect(function(player: Player, rebirths: number, cashSpent: number)
		self:custom(player, "rebirth", 1, { Telemetry.stage(rebirths) })
		self:economy(player, SINK, CASH, cashSpent, 0, GAMEPLAY, "rebirth")
	end)

	MonetizationService.PassBought:Connect(function(player: Player, passKey: string)
		act(player)
		self:custom(player, "pass_bought", 1, { passKey })
	end)
	MonetizationService.ProductBought:Connect(function(player: Player, productKey: string, outcome: string)
		act(player)
		self:custom(player, "product_bought", 1, { productKey, outcome })
	end)

	local function sessionStart(player: Player, profile: any)
		local data = profile.Data
		local row = Telemetry.sessionStart(profile.SeenBefore or 0, os.time(), data.rebirths, data.flags.tutorialDone == true)
		self:custom(player, row.Name, row.Value, row.Fields)
	end
	DataService.ProfileLoaded:Connect(sessionStart)
	-- (a profile can load before this service starts: the in-memory store doesn't yield)
	for _, player in Players:GetPlayers() do
		local profile = DataService:GetProfile(player)
		if profile then sessionStart(player, profile) end
	end

	LevelService.LeveledUp:Connect(function(player: Player, level: number)
		local data = PlayerStateService:Get(player)
		self:custom(player, "level_up", 1, { Telemetry.stage(if data then data.rebirths else 0), tostring(level) })
	end)

	PetService.EggHatched:Connect(function(player: Player, eggId: string, petId: string, duplicate: boolean)
		act(player)
		local pet = Pets.def(petId)
		self:custom(player, "egg_hatched", 1, { eggId, if pet then pet.Rarity else "unknown", if duplicate then "duplicate" else "new" })
		local egg = Pets.egg(eggId)
		if egg then
			self:_purchase(player, { Cost = 0, Shards = egg.Cost }, "egg_" .. eggId)
		end
	end)

	PerkService.PerkBought:Connect(function(player: Player, perkId: string, level: number, shards: number)
		act(player)
		self:custom(player, "perk_bought", level, { perkId })
		self:_purchase(player, { Cost = 0, Shards = shards }, "perk_" .. perkId)
	end)

	IndexService.PageCompleted:Connect(function(player: Player, pageId: string)
		self:custom(player, "index_page_completed", 1, { pageId })
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, purchased: boolean)
		self:_prompt(player, "pass", passId, purchased)
	end)
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId: number, productId: number, purchased: boolean)
		self:_prompt(Players:GetPlayerByUserId(userId), "product", productId, purchased)
	end)

	self.Client.MenuOpened:Connect(function(player: Player, name: any)
		if not Telemetry.knownMenu(Config.Telemetry.Menus, name) then
			return
		end
		local total = (menuTotals[player] or 0) + 1
		if total > Config.Telemetry.MenuOpensCap then
			return
		end
		menuTotals[player] = total
		local menus = menuOpens[player] or {}
		menuOpens[player] = menus
		Telemetry.countAction(menus, name :: string)
	end)

	DebrisService.RockBroken:Connect(function(player: Player, field: string)
		local fields = rocksMined[player] or {}
		rocksMined[player] = fields
		Telemetry.countAction(fields, field)
	end)

	local function joined(player: Player)
		joinedAt[player] = os.clock()
	end
	Players.PlayerAdded:Connect(joined)
	for _, player in Players:GetPlayers() do
		joined(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		actions[player] = nil
		rocksMined[player] = nil
		menuOpens[player] = nil
		menuTotals[player] = nil
		participation[player] = nil
		local started = joinedAt[player]
		joinedAt[player] = nil
		if started then
			local data = PlayerStateService:Get(player)
			local tutorialDone: boolean? = if data and data.flags then data.flags.tutorialDone == true else nil
			local row = Telemetry.playerLeft(os.clock() - started, MeteorService:GetPhase(), tutorialDone)
			self:custom(player, row.Name, row.Value, row.Fields)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(Config.Telemetry.ActionsInterval)
			SafeLoop.step("TelemetryActions", function()
				self:_logActions()
			end)
		end
	end)
end

return TelemetryService
