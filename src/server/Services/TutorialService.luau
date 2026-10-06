--!strict
-- First-session tutorial (spec §11). The next step lives in the profile
-- (tutorialStep); every step completes on the real action, reported by the
-- services' server signals. An action for a later step completes the steps
-- before it too, so a player who joins mid-event or skips ahead never gets stuck.
-- Each completed step is logged as an onboarding funnel step through
-- TelemetryService (spec §13).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldMap = require(ReplicatedStorage.Shared.WorldMap)
local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local Phase = require(ReplicatedStorage.Shared.Phase)
local RequestGate = require(ReplicatedStorage.Shared.RequestGate)

local Steps = Config.Tutorial.Steps

local TutorialService = Knit.CreateService({
	Name = "TutorialService",
	Client = {
		-- { index, total } for the step to do next, nil when the tutorial is done or skipped
		Step = Knit.CreateProperty(nil),
	},
})

local PlayerStateService
local MeteorService
local TelemetryService
local lastSkipRequest: { [Player]: number } = {}

local indexOf: { [string]: number } = {}
for index, step in Steps do
	indexOf[step.Id] = index
end

function TutorialService:_publish(player: Player)
	local data = PlayerStateService:Get(player)
	if not data then
		return
	end
	if data.flags.tutorialDone then
		self.Client.Step:SetFor(player, nil)
	else
		self.Client.Step:SetFor(player, { index = data.tutorialStep, total = #Steps })
	end
end

-- True while the player still has `stepId` (or an earlier step) to do.
function TutorialService:IsBefore(player: Player, stepId: string): boolean
	local data = PlayerStateService:Get(player)
	return data ~= nil and not data.flags.tutorialDone and data.tutorialStep <= indexOf[stepId]
end

-- The player just did the action of `stepId`: complete it and any step before it.
function TutorialService:Did(player: Player, stepId: string)
	local target = indexOf[stepId]
	if not target or not self:IsBefore(player, stepId) then
		return
	end
	local data = PlayerStateService:Get(player)
	for index = data.tutorialStep, target do
		TelemetryService:funnel(player, index, Steps[index].Id)
	end
	data.tutorialStep = target + 1
	if data.tutorialStep > #Steps then
		data.flags.tutorialDone = true
	end
	self:_publish(player)
end

function TutorialService.Client:Skip(player: Player)
	local allowed, stamp = RequestGate.check(lastSkipRequest[player], os.clock(), 1)
	lastSkipRequest[player] = stamp
	if not allowed then return end
	local data = PlayerStateService:Get(player)
	if data and not data.flags.tutorialDone then
		data.flags.tutorialDone = true
		self.Server:_publish(player)
	end
end

-- "Run to the crater" completes on arrival, so check who is close during an event.
function TutorialService:_watchCrater()
	local spawn = WorldMap.wait():WaitForChild("Crater"):WaitForChild("MeteorSpawn") :: BasePart
	local radius = Config.Tutorial.CraterRadius
	while true do
		task.wait(0.5)
		local phase = MeteorService:GetPhase()
		if phase ~= Phase.Impact and phase ~= Phase.Active then
			continue
		end
		local center = spawn.Position * Vector3.new(1, 0, 1)
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and self:IsBefore(player, "reach_crater") then
				if (root.Position * Vector3.new(1, 0, 1) - center).Magnitude <= radius then
					self:Did(player, "reach_crater")
				end
			end
		end
	end
end

function TutorialService:KnitInit()
	PlayerStateService = Knit.GetService("PlayerStateService")
	MeteorService = Knit.GetService("MeteorService")
	TelemetryService = Knit.GetService("TelemetryService")
end

function TutorialService:KnitStart()
	Players.PlayerRemoving:Connect(function(player)
		lastSkipRequest[player] = nil
	end)
	local DataService = Knit.GetService("DataService")
	local NodeService = Knit.GetService("NodeService")
	local RewardService = Knit.GetService("RewardService")
	local RefineryService = Knit.GetService("RefineryService")
	local EconomyService = Knit.GetService("EconomyService")
	local ShopService = Knit.GetService("ShopService")
	local UpgradeService = Knit.GetService("UpgradeService")

	DataService.ProfileLoaded:Connect(function(player)
		self:_publish(player)
	end)
	for _, player in Players:GetPlayers() do
		self:_publish(player) -- profiles loaded before this service started (no-op without one)
	end

	local hitSteps = { Debris = "mine_debris", Crust = "mine_node", Core = "hit_core" }
	NodeService.Hit:Connect(function(player, kind)
		local stepId = hitSteps[kind]
		if stepId then
			self:Did(player, stepId)
		end
	end)
	MeteorService.Landed:Connect(function()
		for _, player in Players:GetPlayers() do
			self:Did(player, "meteor_lands")
		end
	end)
	RewardService.ShardsAwarded:Connect(function(player)
		self:Did(player, "core_shards")
	end)
	RefineryService.OreDeposited:Connect(function(player)
		self:Did(player, "deposit")
	end)
	-- Auto-Deposit (spec §9.1) skips the hopper prompt: it completes "deposit" only
	-- while that is the step to do, so it never skips the steps before it.
	PlayerStateService.OreAutoDeposited:Connect(function(player)
		local data = PlayerStateService:Get(player)
		if data and not data.flags.tutorialDone and data.tutorialStep == indexOf.deposit then
			self:Did(player, "deposit")
		end
	end)
	RefineryService.BarsCollected:Connect(function(player)
		self:Did(player, "collect_bar")
	end)
	EconomyService.BarsSold:Connect(function(player)
		self:Did(player, "sell")
	end)
	ShopService.ItemBought:Connect(function(player)
		self:Did(player, "buy")
	end)
	ShopService.StatUpgraded:Connect(function(player)
		self:Did(player, "buy")
	end)
	UpgradeService.StationUpgraded:Connect(function(player)
		self:Did(player, "buy")
	end)

	task.spawn(self._watchCrater, self)
end

return TutorialService
