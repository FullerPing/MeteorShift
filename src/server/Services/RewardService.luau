--!strict
-- Core Shard rewards and the top-three announcement (spec §5.6).
--
--   floor      = 5 shards for everyone who hit the core
--   bonusPool  = 8 × numberOfCoreHitters, split by contribution share
--   top three  = +10 / +6 / +3

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)

local RewardService = Knit.CreateService({
	Name = "RewardService",
	Client = {
		-- To each participant: { cracked, ore, contribution, rank, floor, bonus, top, shards, leaders }
		Results = Knit.CreateSignal(),
		-- To everyone: { kind, text }
		Announcement = Knit.CreateSignal(),
	},
})

local ContributionService
local PlayerStateService

export type Reward = { Floor: number, Bonus: number, Top: number, Total: number }

-- Pure reward math, kept separate so it can be unit tested.
function RewardService.Compute(entries: { { Contribution: number, HitCore: boolean } }): { [number]: Reward }
	local meteor = Config.Meteor
	local hitters = {}
	local total = 0
	for index, entry in entries do
		if entry.HitCore then
			table.insert(hitters, index)
			total += entry.Contribution
		end
	end

	local rewards: { [number]: Reward } = {}
	if #hitters == 0 then
		return rewards
	end

	local pool = meteor.ShardBonusPerHitter * #hitters
	for _, index in hitters do
		local share = if total > 0 then entries[index].Contribution / total else 1 / #hitters
		local bonus = math.floor(pool * share + 0.5)
		rewards[index] = { Floor = meteor.ShardFloor, Bonus = bonus, Top = 0, Total = meteor.ShardFloor + bonus }
	end

	-- Top three by contribution among core hitters
	table.sort(hitters, function(a, b)
		return entries[a].Contribution > entries[b].Contribution
	end)
	for place = 1, math.min(#meteor.TopBonus, #hitters) do
		local reward = rewards[hitters[place]]
		reward.Top = meteor.TopBonus[place]
		reward.Total += reward.Top
	end

	return rewards
end

function RewardService:Announce(kind: string, text: string)
	self.Client.Announcement:FireAll({ kind = kind, text = text })
end

-- Called when the event ends, cracked or cooled.
function RewardService:Finish(cracked: boolean)
	local ranked = ContributionService:GetRanked()
	local rewards = if cracked then RewardService.Compute(ranked) else {}

	local leaders = {}
	for index, entry in ranked do
		local reward = rewards[index]
		if reward and reward.Top > 0 then
			table.insert(leaders, { name = entry.Player.DisplayName, shards = reward.Total, place = #leaders + 1 })
		end
	end

	for index, entry in ranked do
		local reward = rewards[index]
		if reward then
			PlayerStateService:AddShards(entry.Player, reward.Total)
		end
		self.Client.Results:Fire(entry.Player, {
			cracked = cracked,
			ore = entry.Ore,
			contribution = entry.Contribution,
			rank = index,
			hitCore = entry.HitCore,
			floor = if reward then reward.Floor else 0,
			bonus = if reward then reward.Bonus else 0,
			top = if reward then reward.Top else 0,
			shards = if reward then reward.Total else 0,
			leaders = leaders,
		})
	end

	if cracked and #leaders > 0 then
		local names = {}
		for _, leader in leaders do
			table.insert(names, string.format("#%d %s", leader.place, leader.name))
		end
		self:Announce("Top", "Core cracked! " .. table.concat(names, "   "))
	elseif cracked then
		self:Announce("Top", "Core cracked!")
	else
		self:Announce("Cooled", "The meteor cooled. Ore you mined is yours to keep.")
	end
end

function RewardService:KnitInit()
	ContributionService = Knit.GetService("ContributionService")
	PlayerStateService = Knit.GetService("PlayerStateService")
end

return RewardService
