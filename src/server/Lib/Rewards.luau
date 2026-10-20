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
--
-- Consolation: a meteor that cools with its core far enough down (Config.Hooks.Consolation)
-- still pays the floor to everyone who hit the core, so a near miss isn't nothing.
--
-- "Core hitter" means a player with at least MIN_CORE_SHARE of all core contribution (Entry.Core),
-- so one tap from an alt or a last-second joiner earns no floor and doesn't grow the pool. A lone
-- core hitter always qualifies (share 1).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

export type Entry = { Contribution: number, HitCore: boolean, Core: number }
export type Reward = { Floor: number, Bonus: number, Top: number, Total: number }

local Rewards = {}

-- Minimum share of the meteor's total core contribution to count as a core hitter (audit A3).
-- Lives here rather than Config.Meteor until it needs tuning.
local MIN_CORE_SHARE = 0.02

-- Indices of the entries that count as core hitters (see header)
local function coreHitters(entries: { Entry }): { number }
	local tapped = {}
	local totalCore = 0
	for index, entry in entries do
		if entry.HitCore then
			table.insert(tapped, index)
			totalCore += entry.Core
		end
	end
	if #tapped <= 1 or totalCore <= 0 then
		return tapped
	end
	local hitters = {}
	for _, index in tapped do
		if entries[index].Core / totalCore >= MIN_CORE_SHARE then
			table.insert(hitters, index)
		end
	end
	return hitters
end

-- Rewards by index into `entries`; an entry that didn't hit the core has none.
function Rewards.compute(entries: { Entry }, poolMult: number): { [number]: Reward }
	local meteor = Config.Meteor
	local hitters = coreHitters(entries)
	local total = 0
	for _, index in hitters do
		total += entries[index].Contribution
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

-- The floor for every core hitter, for a meteor that cooled with its core mostly down.
-- `coreRemaining` is the core's HP as a share of its max (0 to 1). Same shape as compute.
function Rewards.consolation(entries: { Entry }, coreRemaining: number): { [number]: Reward }
	local rewards: { [number]: Reward } = {}
	if coreRemaining > 1 - Config.Hooks.Consolation.CoreDownFraction then
		return rewards
	end
	local floor = Config.Meteor.ShardFloor
	for _, index in coreHitters(entries) do
		rewards[index] = { Floor = floor, Bonus = 0, Top = 0, Total = floor }
	end
	return rewards
end

return Rewards
