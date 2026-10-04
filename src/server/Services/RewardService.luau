--!strict
-- Core Shard rewards and the top-three announcement (spec §5.6). The payout math
-- (floor, contribution share of the bonus pool, top three, the meteor type's pool
-- multiplier) is the pure Server.Lib.Rewards.
--
-- Each participant's results also say which ore their pickaxe mined from this
-- meteor and, when it was under the meteor's tier, what they missed (spec §8.1).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Config = require(ReplicatedStorage.Shared.Config)
local MeteorTypes = require(ReplicatedStorage.Shared.MeteorTypes)
local Levels = require(ReplicatedStorage.Shared.Levels)
local Rewards = require(script.Parent.Parent.Lib.Rewards)

local RewardService = Knit.CreateService({
	Name = "RewardService",
	Client = {
		-- To each participant: { cracked, ore, oreType, contribution, rank, hitCore, floor,
		-- bonus, top, shards, leaders, missed? }. oreType is the meteor's ore id; missed is
		-- MeteorTypes.missed, nil when their pickaxe met its tier.
		Results = Knit.CreateSignal(),
		-- To everyone: { kind, text }
		Announcement = Knit.CreateSignal(),
		-- To the player who levelled up: (level)
		LevelUp = Knit.CreateSignal(),
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
function RewardService:Finish(cracked: boolean, meteorType: Config.MeteorType, poolMult: number)
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
			-- flags.firstMeteor and flags.firstCoreReward are TelemetryService's
			-- (first validated hit, first shards received; spec §13)
			data.stats.meteorsJoined += 1
			if reward then
				data.stats.coresCracked += 1
			end
			-- Player level (Shared.Levels): XP only for a meteor you hit, by effort against the top player
			if entry.Contribution > 0 then
				local top = ranked[1].Contribution
				local xp = Levels.meteorXp(meteorType.Ore, if top > 0 then entry.Contribution / top else 0, cracked)
				if Levels.addXp(data, xp) > 0 then
					self.Client.LevelUp:Fire(entry.Player, data.level)
				end
			end
		end
		if reward then
			PlayerStateService:AddShards(entry.Player, reward.Total)
			self.ShardsAwarded:Fire(entry.Player, reward.Total)
		end
		local pickaxeTier = PlayerStateService:GetPickaxe(entry.Player).Tier
		self.Client.Results:Fire(entry.Player, {
			cracked = cracked,
			ore = entry.Ore,
			oreType = meteorType.Ore,
			missed = MeteorTypes.missed(pickaxeTier, meteorType),
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
