--!strict
-- Core Shard rewards and the top-three announcement (spec §5.6). The payout math
-- (floor, contribution share of the bonus pool, top three, the meteor type's pool
-- multiplier) is the pure Server.Lib.Rewards.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Rewards = require(script.Parent.Parent.Lib.Rewards)

local RewardService = Knit.CreateService({
	Name = "RewardService",
	Client = {
		-- To each participant: { cracked, ore, contribution, rank, floor, bonus, top, shards, leaders }
		Results = Knit.CreateSignal(),
		-- To everyone: { kind, text }
		Announcement = Knit.CreateSignal(),
	},
})

RewardService.ShardsAwarded = Signal.new() -- (player, shards) when a cracked core pays out

local ContributionService
local PlayerStateService

function RewardService:Announce(kind: string, text: string)
	self.Client.Announcement:FireAll({ kind = kind, text = text })
end

-- Called when the event ends, cracked or cooled. `poolMult` scales the shard bonus
-- pool (MeteorTypes.shardPoolMult for the meteor that ended).
function RewardService:Finish(cracked: boolean, poolMult: number)
	local ranked = ContributionService:GetRanked()
	local rewards = if cracked then Rewards.compute(ranked, poolMult) else {}

	local leaders = {}
	for index, entry in ranked do
		local reward = rewards[index]
		if reward and reward.Top > 0 then
			table.insert(leaders, { name = entry.Player.DisplayName, shards = reward.Total, place = #leaders + 1 })
		end
	end

	for index, entry in ranked do
		local reward = rewards[index]
		local data = PlayerStateService:Get(entry.Player)
		if data then
			data.stats.meteorsJoined += 1
			data.flags.firstMeteor = true
			if reward then
				data.stats.coresCracked += 1
				data.flags.firstCoreReward = true
			end
		end
		if reward then
			PlayerStateService:AddShards(entry.Player, reward.Total)
			self.ShardsAwarded:Fire(entry.Player, reward.Total)
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
