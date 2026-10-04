--!strict
-- Core Shard rewards and the top-three announcement (spec §5.6). The payout math
-- (floor, contribution share of the bonus pool, top three, the meteor type's pool
-- multiplier) is the pure Server.Lib.Rewards.
--
-- Each participant's results also say which ore they mined from this meteor and how
-- fast their refinery handles it (clearance, 1 = full speed; Shared.Levels).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Config = require(ReplicatedStorage.Shared.Config)
local Levels = require(ReplicatedStorage.Shared.Levels)
local Rewards = require(script.Parent.Parent.Lib.Rewards)

local RewardService = Knit.CreateService({
	Name = "RewardService",
	Client = {
		-- To each participant: { cracked, ore, oreType, contribution, rank, hitCore, floor,
		-- bonus, top, shards, leaders, clearance }. oreType is the meteor's ore id; clearance
		-- is the refining speed for it at their level, 0 to 1.
		Results = Knit.CreateSignal(),
		-- To everyone: { kind, text }
		Announcement = Knit.CreateSignal(),
	},
})

RewardService.ShardsAwarded = Signal.new() -- (player, shards) when a cracked core pays out

local ContributionService
local PlayerStateService
local LevelService

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
			-- Player level (Shared.Levels): hits already paid XP as they landed; a cracked core adds a bonus
			if cracked and entry.HitCore then
				LevelService:AddXp(entry.Player, Levels.crackXp(meteorType.Ore))
			end
		end
		if reward then
			PlayerStateService:AddShards(entry.Player, reward.Total)
			self.ShardsAwarded:Fire(entry.Player, reward.Total)
		end
		self.Client.Results:Fire(entry.Player, {
			cracked = cracked,
			ore = entry.Ore,
			oreType = meteorType.Ore,
			clearance = Levels.clearance(if data then data.level else 1, meteorType.Ore),
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
	LevelService = Knit.GetService("LevelService")
end

return RewardService
