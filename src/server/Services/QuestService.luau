--!strict
-- The Foreman's quest lines (Config.Quests, Shared.Quests): this world's line only (World 1 profile.quest, Nebula Rift
-- profile.riftQuest, each { step, progress }). Counts the current step's event from the other services' signals, publishes a Summary for the HUD tracker and the Quests
-- menu, and pays a finished step when the player claims it. The Foreman NPC (Workspace.Map ... "Foreman", a model
-- with a part named "Prompt") gets a "Quests" prompt that opens the menu.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Quests = require(ReplicatedStorage.Shared.Quests)
local Rebirth = require(ReplicatedStorage.Shared.Rebirth)
local RequestGate = require(ReplicatedStorage.Shared.RequestGate)
local SafeLoop = require(script.Parent.Parent.Lib.SafeLoop)
local Worlds = require(ReplicatedStorage.Shared.Worlds)

local WORLD = Worlds.here().Id
local KEY = Quests.saveKey(WORLD)

local QuestService = Knit.CreateService({
	Name = "QuestService",
	Client = {
		Summary = Knit.CreateProperty(nil), -- per player: Shared.Quests.Summary, nil once the line is done
		Open = Knit.CreateSignal(), -- the Foreman was talked to: open the Quests menu
	},
})

local PlayerStateService
local EconomyService
local RewardService
local TelemetryService

local PUBLISH_INTERVAL = 1
local lastRequest: { [Player]: number } = {}
local lastKey: { [Player]: string } = {}
local joinedThisMeteor: { [Player]: boolean } = {}

local function context(player: Player): (any, number, number)
	local data = PlayerStateService:Get(player)
	if not data then return nil, 0, 0 end
	local perSecond = EconomyService:ExpectedIncome(player).perSecond
	return data, perSecond, Rebirth.cost(data.rebirths) * Config.Quests.CashCeilingShare
end

-- Sends the summary when it changed (state steps change with the profile, so this also runs on a timer)
function QuestService:Publish(player: Player, force: boolean?)
	local data, perSecond, ceiling = context(player)
	if not data then return end
	data[KEY] = Quests.clean(data[KEY])
	local summary = Quests.summary(data, perSecond, ceiling, WORLD)
	local key = if summary then string.format("%d/%g/%s/%d", summary.step, summary.value, tostring(summary.done), summary.cash) else "done"
	if force or lastKey[player] ~= key then
		lastKey[player] = key
		self.Client.Summary:SetFor(player, summary)
	end
end

local function progress(player: Player, event: string, amount: number, field: string?)
	local data = PlayerStateService:Get(player)
	if not data then return end
	data[KEY] = Quests.clean(data[KEY])
	Quests.addProgress(data[KEY], event, amount, field, WORLD) -- the timer publishes it
end

function QuestService:Claim(player: Player): boolean
	local data, perSecond, ceiling = context(player)
	if not data then return false end
	local state = Quests.clean(data[KEY])
	data[KEY] = state
	local def = Quests.step(state, WORLD)
	if not def or not Quests.done(def, data, state.progress) then return false end
	local reward = Quests.reward(def, perSecond, ceiling)
	Quests.advance(state)
	if reward.cash > 0 then PlayerStateService:AddCash(player, reward.cash) end
	if reward.shards > 0 then PlayerStateService:AddShards(player, reward.shards) end
	TelemetryService:earned(player, "foreman_quest", reward.cash, reward.shards)
	TelemetryService:custom(player, "foreman_quest", state.step - 1, { def.Id })
	local parts = {}
	if reward.cash > 0 then table.insert(parts, "+" .. Format.cash(reward.cash)) end
	if reward.shards > 0 then table.insert(parts, "+" .. reward.shards .. " ◆") end
	RewardService:Bonus(player, "daily", "Quest complete: " .. table.concat(parts, " and "))
	PlayerStateService:ReplicateNow(player)
	self:Publish(player, true)
	return true
end

function QuestService.Client:Claim(player: Player): boolean
	local allowed, stamp = RequestGate.check(lastRequest[player], os.clock(), 0.3)
	lastRequest[player] = stamp
	if not allowed then return false end
	return self.Server:Claim(player)
end

-- The Foreman: any model named Foreman under the map with a part named Prompt gets the talk prompt
function QuestService:_wireForeman(foreman: Instance)
	local part = foreman:FindFirstChild("Prompt", true)
	if not part or not part:IsA("BasePart") or part:FindFirstChild("TalkQuests") then return end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TalkQuests"
	prompt.ActionText = "Quests"
	prompt.ObjectText = "Foreman"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	prompt.Triggered:Connect(function(player) self.Client.Open:Fire(player) end)
end

function QuestService:KnitInit()
	PlayerStateService = Knit.GetService("PlayerStateService")
	EconomyService = Knit.GetService("EconomyService")
	RewardService = Knit.GetService("RewardService")
	TelemetryService = Knit.GetService("TelemetryService")
end

function QuestService:KnitStart()
	local DataService = Knit.GetService("DataService")
	local NodeService = Knit.GetService("NodeService")
	local MeteorService = Knit.GetService("MeteorService")
	local PetService = Knit.GetService("PetService")
	local RefineryService = Knit.GetService("RefineryService")
	local DebrisService = Knit.GetService("DebrisService")

	DataService.ProfileLoaded:Connect(function(player)
		task.defer(function() SafeLoop.step("QuestPublish", function() self:Publish(player, true) end) end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player], lastKey[player], joinedThisMeteor[player] = nil, nil, nil
	end)

	NodeService.Hit:Connect(function(player: Player, kind: string)
		if kind ~= "Crust" and kind ~= "Core" then return end
		if kind == "Crust" then progress(player, "crustHit", 1) end
		if not joinedThisMeteor[player] then
			joinedThisMeteor[player] = true
			progress(player, "meteorJoin", 1)
		end
	end)
	MeteorService.Landed:Connect(function() table.clear(joinedThisMeteor) end)
	Knit.GetService("RewardService").ShardsAwarded:Connect(function(player: Player) progress(player, "coreCrack", 1) end)
	EconomyService.BarsSold:Connect(function(player: Player, bars: number) progress(player, "barsSold", bars) end)
	RefineryService.OreDeposited:Connect(function(player: Player, ore: number) progress(player, "oreDeposited", ore) end)
	PetService.EggHatched:Connect(function(player: Player) progress(player, "hatch", 1) end)
	DebrisService.RockBroken:Connect(function(player: Player, field: string)
		if field ~= "Filler" then progress(player, "fieldRock", 1, field) end
	end)

	local map = workspace:WaitForChild("Map", 30)
	if map then
		for _, d in map:GetDescendants() do
			if d.Name == "Foreman" and d:IsA("Model") then self:_wireForeman(d) end
		end
		map.DescendantAdded:Connect(function(d)
			if d.Name == "Foreman" and d:IsA("Model") then task.defer(function() self:_wireForeman(d) end) end
		end)
	end

	task.spawn(function()
		while true do
			task.wait(PUBLISH_INTERVAL)
			for _, player in Players:GetPlayers() do
				SafeLoop.step("QuestPublish", function() self:Publish(player) end)
			end
		end
	end)
end

return QuestService
