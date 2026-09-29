--!strict
-- Core Shard payout when a core cracks (spec §5.6, §8.1). Pure, so the rules are
-- covered by tests/Rewards.spec; RewardService pays the result out and announces
-- the top three.
--
--   floor      Config.Meteor.ShardFloor for everyone who hit the core
--   bonusPool  ShardBonusPerHitter × core hitters × the meteor type's pool
--              multiplier (MeteorTypes.shardPoolMult), split by contribution share
--              among the core hitters
--   top three  Config.Meteor.TopBonus by contribution among the core hitters
--
-- Players who only mined crust get no shards; their ore is theirs to keep.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

export type Entry = { Contribution: number, HitCore: boolean }
export type Reward = { Floor: number, Bonus: number, Top: number, Total: number }

local Rewards = {}

-- Rewards by index into `entries`; an entry that didn't hit the core has none.
function Rewards.compute(entries: { Entry }, poolMult: number): { [number]: Reward }
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

	local pool = meteor.ShardBonusPerHitter * #hitters * poolMult
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

return Rewards
