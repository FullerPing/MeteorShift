--!strict
-- Daily streak, quests and badges (Config.Daily, Shared.Daily, Config.Badges). The rules are pure; this service owns
-- profile.daily: it rolls the quests over on join and at each UTC midnight, counts progress from the other services'
-- server signals, pays claims, awards Roblox Badges and publishes a Summary the Daily menu draws.
-- Studio only: ServerStorage attribute DevDayOffset (a number of days) moves this service's clock for testing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local Daily = require(ReplicatedStorage.Shared.Daily)
local Format = require(ReplicatedStorage.Shared.Format)
local Pets = require(ReplicatedStorage.Shared.Pets)
local Rebirth = require(ReplicatedStorage.Shared.Rebirth)
local Worlds = require(ReplicatedStorage.Shared.Worlds)
local RequestGate = require(ReplicatedStorage.Shared.RequestGate)
local Badges = require(script.Parent.Parent.Lib.Badges)
local SafeLoop = require(script.Parent.Parent.Lib.SafeLoop)

local DailyService = Knit.CreateService({
	Name = "DailyService",
	Client = {
		Summary = Knit.CreateProperty(nil), -- per player: Shared.Daily.Summary
		Notice = Knit.CreateSignal(), -- (text)
		-- true once the first-session tutorial is finished or skipped: the Daily Rewards button and menu wait for it
		TutorialDone = Knit.CreateProperty(false),
	},
})

local PlayerStateService
local EconomyService
local RewardService
local TelemetryService

local PUBLISH_INTERVAL = 1 -- seconds between summary sends; hits arrive many times a second
local dirty: { [Player]: boolean } = {}
local lastRequest: { [Player]: number } = {}
local joinedThisMeteor: { [Player]: boolean } = {}
local tutorialSent: { [Player]: boolean } = {}

local function now(): number
	local offset = if RunService:IsStudio() then ServerStorage:GetAttribute("DevDayOffset") else nil
	return os.time() + (if type(offset) == "number" then offset * 86400 else 0)
end

local function context(player: Player): (any, number, number)
	local data = PlayerStateService:Get(player)
	if not data then return nil, 0, 0 end
	local perSecond = EconomyService:ExpectedIncome(player).perSecond
	local ceiling = Rebirth.cost(data.rebirths) * Config.Daily.CashCeilingShare
	return data, perSecond, ceiling
end

function DailyService:Publish(player: Player)
	local data, perSecond, ceiling = context(player)
	if not data then return end
	dirty[player] = nil
	-- worlds past the first have no tutorial (TutorialService), so nothing there waits for it
	local tutorialDone = data.flags.tutorialDone == true or Worlds.here().Id ~= 1
	if tutorialSent[player] ~= tutorialDone then
		tutorialSent[player] = tutorialDone
		self.Client.TutorialDone:SetFor(player, tutorialDone)
	end
	Daily.rollover(data.daily, Daily.dayKey(now()), data.level, data.rebirths, player.UserId)
	self.Client.Summary:SetFor(player, Daily.summary(data.daily, now(), perSecond, ceiling))
end

local function markDirty(player: Player)
	dirty[player] = true
end

-- Adds cash, shards and pet XP, then says so in the reward feed (and to analytics as `sku`)
local function pay(player: Player, data: any, sku: string, label: string, cash: number, shards: number, petXp: number?)
	if cash > 0 then PlayerStateService:AddCash(player, cash) end
	if shards > 0 then PlayerStateService:AddShards(player, shards) end
	TelemetryService:earned(player, sku, cash, shards)
	if petXp and petXp > 0 then
		local seen: { [string]: boolean } = {}
		for _, petId in data.pets.equipped do
			local entry = data.pets.owned[petId]
			if entry and not seen[petId] then
				seen[petId] = true
				Pets.addXp(entry, petXp)
			end
		end
	end
	local parts = {}
	if cash > 0 then table.insert(parts, "+" .. Format.cash(cash)) end
	if shards > 0 then table.insert(parts, "+" .. shards .. " ◆") end
	if petXp and petXp > 0 then table.insert(parts, "+" .. petXp .. " pet XP") end
	RewardService:Bonus(player, "daily", label .. ": " .. table.concat(parts, " and "))
end

local function gate(player: Player): boolean
	local allowed, stamp = RequestGate.check(lastRequest[player], os.clock(), 0.3)
	lastRequest[player] = stamp
	return allowed
end

function DailyService:ClaimLogin(player: Player): boolean
	local data, perSecond, ceiling = context(player)
	if not data then return false end
	Daily.rollover(data.daily, Daily.dayKey(now()), data.level, data.rebirths, player.UserId)
	local result = Daily.claimLogin(data.daily, Daily.dayKey(now()))
	if result.status ~= "claimable" then return false end
	local cycleDay = Daily.cycleDay(result.streak)
	local reward = Daily.reward(cycleDay, perSecond, ceiling)
	Daily.addFreeShield(data.daily, reward.shield)
	pay(player, data, "daily_login", "Day " .. cycleDay .. " streak", reward.cash, reward.shards, reward.petXp)
	if result.shieldsUsed > 0 then
		self.Client.Notice:Fire(player, string.format("A streak shield covered %d missed day%s.", result.shieldsUsed, if result.shieldsUsed == 1 then "" else "s"))
	elseif result.reset then
		self.Client.Notice:Fire(player, "Your streak started over. Claim every day to build it back up!")
	end
	TelemetryService:custom(player, "daily_claimed", result.streak, { if result.reset then "reset" elseif result.shieldsUsed > 0 then "shield" else "kept" })
	if cycleDay == Config.Daily.CycleLength then Badges.award(player, "streak7") end
	PlayerStateService:ReplicateNow(player)
	self:Publish(player)
	return true
end

function DailyService:ClaimQuest(player: Player, slot: string): boolean
	local data, perSecond, ceiling = context(player)
	if not data then return false end
	local id = Daily.claimQuest(data.daily, slot)
	if not id then return false end
	local reward = Daily.questReward(id, perSecond, ceiling) :: { cash: number, shards: number }
	pay(player, data, if slot == "w" then "weekly_quest" else "daily_quest", "Quest complete", reward.cash, reward.shards)
	TelemetryService:custom(player, "quest_claimed", 1, { if slot == "w" then "weekly" else "daily", id })
	PlayerStateService:ReplicateNow(player)
	self:Publish(player)
	return true
end

function DailyService:ClaimBonus(player: Player): boolean
	local data, perSecond, ceiling = context(player)
	if not data or not Daily.claimBonus(data.daily) then return false end
	local reward = Daily.bonusReward(perSecond, ceiling)
	pay(player, data, "quest_bonus", "All daily quests done", reward.cash, reward.shards)
	TelemetryService:custom(player, "quest_claimed", 1, { "bonus", "all" })
	PlayerStateService:ReplicateNow(player)
	self:Publish(player)
	return true
end

function DailyService.Client:ClaimLogin(player: Player): boolean
	if not gate(player) then return false end
	return self.Server:ClaimLogin(player)
end

function DailyService.Client:ClaimQuest(player: Player, slot: any): boolean
	if not gate(player) or type(slot) ~= "string" or #slot > 8 then return false end
	return self.Server:ClaimQuest(player, slot)
end

function DailyService.Client:ClaimBonus(player: Player): boolean
	if not gate(player) then return false end
	return self.Server:ClaimBonus(player)
end

-- Counts `amount` of `event` toward the player's quests; the summary follows within PUBLISH_INTERVAL
local function progress(player: Player, event: string, amount: number)
	local data = PlayerStateService:Get(player)
	if data and Daily.addProgress(data.daily, event, amount) then
		markDirty(player)
	end
end

function DailyService:KnitInit()
	PlayerStateService = Knit.GetService("PlayerStateService")
	EconomyService = Knit.GetService("EconomyService")
	RewardService = Knit.GetService("RewardService")
	TelemetryService = Knit.GetService("TelemetryService")
end

function DailyService:KnitStart()
	local DataService = Knit.GetService("DataService")
	local NodeService = Knit.GetService("NodeService")
	local MeteorService = Knit.GetService("MeteorService")
	local LevelService = Knit.GetService("LevelService")
	local IndexService = Knit.GetService("IndexService")
	local PetService = Knit.GetService("PetService")
	local RebirthService = Knit.GetService("RebirthService")
	local RefineryService = Knit.GetService("RefineryService")

	local function publish(player: Player)
		local ok, err = pcall(function() self:Publish(player) end)
		if not ok then warn("[DailyService] could not publish for " .. player.Name .. ": " .. tostring(err)) end
	end
	DataService.ProfileLoaded:Connect(function(player)
		Badges.award(player, "welcome")
		task.defer(publish, player)
	end)
	for _, player in Players:GetPlayers() do
		if PlayerStateService:Get(player) then task.defer(publish, player) end
	end
	Players.PlayerRemoving:Connect(function(player)
		dirty[player], lastRequest[player], joinedThisMeteor[player], tutorialSent[player] = nil, nil, nil, nil
	end)

	-- Quest progress. Hits are validated by NodeService before the signal fires.
	NodeService.Hit:Connect(function(player: Player, kind: string)
		if kind ~= "Crust" and kind ~= "Core" then return end
		if kind == "Crust" then progress(player, "crustHit", 1) end
		if not joinedThisMeteor[player] then
			joinedThisMeteor[player] = true
			progress(player, "meteorJoin", 1)
			Badges.award(player, "firstMeteor")
		end
	end)
	MeteorService.Landed:Connect(function()
		table.clear(joinedThisMeteor)
	end)
	RewardService.ShardsAwarded:Connect(function(player: Player)
		progress(player, "coreCrack", 1)
		Badges.award(player, "firstCore")
	end)
	EconomyService.BarsSold:Connect(function(player: Player, bars: number)
		progress(player, "barsSold", bars)
	end)
	RefineryService.OreDeposited:Connect(function(player: Player, ore: number)
		progress(player, "oreDeposited", ore)
	end)
	PetService.EggHatched:Connect(function(player: Player)
		progress(player, "hatch", 1)
	end)

	-- Badges
	RebirthService.Reborn:Connect(function(player: Player, rebirths: number)
		if rebirths >= 1 then Badges.award(player, "firstRebirth") end
		if rebirths >= 10 then Badges.award(player, "rebirth10") end
	end)
	LevelService.LeveledUp:Connect(function(player: Player, level: number)
		if level >= 25 then Badges.award(player, "level25") end
		if level >= 50 then Badges.award(player, "level50") end
	end)
	IndexService.PageCompleted:Connect(function(player: Player, pageId: string)
		Badges.award(player, "page" .. pageId)
	end)
	PetService.PetBought:Connect(function(player: Player, petId: string)
		local def = Pets.def(petId)
		if def and def.Rarity == "legendary" then Badges.award(player, "legendaryPet") end
	end)

	-- One loop sends dirty summaries and notices a new UTC day for players who stay online past midnight
	task.spawn(function()
		while true do
			task.wait(PUBLISH_INTERVAL)
			local today = Daily.dayKey(now())
			for _, player in Players:GetPlayers() do
				-- per player, so one bad profile doesn't stop everyone else's summaries
				SafeLoop.step("DailyPublish", function()
					local data = PlayerStateService:Get(player)
					if data and (dirty[player] or data.daily.day ~= today or tutorialSent[player] ~= (data.flags.tutorialDone == true)) then
						publish(player)
					end
				end)
			end
		end
	end)
end

return DailyService
