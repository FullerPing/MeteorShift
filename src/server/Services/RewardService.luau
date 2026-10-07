--!strict
-- Core Shard rewards and the top-three announcement (spec §5.6). The payout math
-- (floor, contribution share of the bonus pool, top three, the meteor type's pool
-- multiplier) is the pure Server.Lib.Rewards.
--
-- Each participant's results also say which ore they mined from this meteor and how much of
-- a full hit it yielded at their level (yield, 1 = full; Shared.Levels.oreYield).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Config = require(ReplicatedStorage.Shared.Config)
local Levels = require(ReplicatedStorage.Shared.Levels)
local Pets = require(ReplicatedStorage.Shared.Pets)
local Rewards = require(script.Parent.Parent.Lib.Rewards)

local RewardService = Knit.CreateService({
	Name = "RewardService",
	Client = {
		-- To each participant: { cracked, ore, oreType, contribution, rank, hitCore, floor,
		-- bonus, top, shards, xp, leaders, yield, consolation }. xp includes the actual scholar-adjusted
		-- hit and crack awards. oreType is the meteor's ore id; yield is the share of each hit's
		-- ore their level collects from it, 0 to 1; consolation is true when the floor was paid for a
		-- core that was mostly down but not cracked.
		Results = Knit.CreateSignal(),
		-- To everyone: { kind, text }
		Announcement = Knit.CreateSignal(),
		-- To one player: { kind, text }, a small personal reward (shard crumb, Golden Node lump,
		-- supply crate, welcome-back bonus) the HUD shows as a notice
		Bonus = Knit.CreateSignal(),
	},
})

RewardService.ShardsAwarded = Signal.new() -- (player, shards) when a cracked core pays out

local ContributionService
local PlayerStateService
local LevelService

function RewardService:Announce(kind: string, text: string)
	self.Client.Announcement:FireAll({ kind = kind, text = text })
end

-- A personal notice for one player (see Client.Bonus)
function RewardService:Bonus(player: Player, kind: string, text: string)
	self.Client.Bonus:Fire(player, { kind = kind, text = text })
end

-- Called when the event ends, cracked or cooled. `poolMult` scales the shard bonus
-- pool (MeteorTypes.shardPoolMult for the meteor that ended). `coreRemaining` is the core's
-- HP as a share of its max, which decides the consolation for a meteor that cooled.
function RewardService:Finish(cracked: boolean, meteorType: Config.MeteorType, poolMult: number, coreRemaining: number?)
	local ranked = ContributionService:GetRanked()
	local rewards = if cracked then Rewards.compute(ranked, poolMult) else Rewards.consolation(ranked, coreRemaining or 1)
	local consolation = not cracked and next(rewards) ~= nil
	for index, reward in rewards do
		reward.Total = Pets.coreShards(reward.Total, PlayerStateService:GetPetBonuses(ranked[index].Player).shards)
	end

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
		local awardedShards = 0
		if data then
			-- flags.firstMeteor and flags.firstCoreReward are TelemetryService's
			-- (first validated hit, first shards received; spec §13)
			data.stats.meteorsJoined += 1
			if reward then
				data.stats.coresCracked += 1
			end
			-- Player level (Shared.Levels): hits already paid XP as they landed; a cracked core adds a bonus
			if cracked and entry.HitCore then
				local awarded = LevelService:AddXp(entry.Player, Levels.crackXp(meteorType.Ore))
				ContributionService:AddXp(entry.Player, awarded)
			end
		end
		if reward then
			PlayerStateService:AddShards(entry.Player, reward.Total)
			if data then awardedShards = reward.Total end
			Knit.GetService("PetService"):Work(entry.Player, "shards")
			self.ShardsAwarded:Fire(entry.Player, reward.Total)
		end
		self.Client.Results:Fire(entry.Player, {
			cracked = cracked,
			ore = entry.Ore,
			oreType = meteorType.Ore,
			yield = Levels.oreYield(if data then data.level else 1, meteorType.Ore),
			consolation = consolation and reward ~= nil,
			contribution = entry.Contribution,
			rank = index,
			hitCore = entry.HitCore,
			floor = if reward then reward.Floor else 0,
			bonus = if reward then reward.Bonus else 0,
			top = if reward then reward.Top else 0,
			shards = awardedShards,
			xp = entry.Xp,
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
	elseif consolation then
		self:Announce("Cooled", "The meteor cooled, but the core was nearly down. Core hitters keep a consolation shard payout.")
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
