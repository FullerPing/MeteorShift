--!strict
-- Spec for Server.Lib.Rewards, the Core Shard payout when a core cracks (spec §5.6,
-- §8.1). Tuning numbers (floor, shards per hitter, top-three bonus) are read from
-- Config so a retune doesn't break these cases.

return function(t: any)
	local Rewards = require(t.lib.Rewards)
	local Meteor = require(t.shared.Config.Meteor)
	local FLOOR = Meteor.ShardFloor
	local PER_HITTER = Meteor.ShardBonusPerHitter
	local TOP = Meteor.TopBonus

	local function entry(contribution: number, hitCore: boolean)
		return { Contribution = contribution, HitCore = hitCore }
	end

	local function round(n: number): number
		return math.floor(n + 0.5)
	end

	t.test("nobody hit the core: no rewards", function()
		t.eq(next(Rewards.compute({ entry(120, false), entry(40, false) }, 1)), nil, "crust-only lobby")
		t.eq(next(Rewards.compute({}, 1)), nil, "empty lobby")
	end)

	t.test("everyone who hit the core gets the floor; crust-only miners get nothing", function()
		local rewards = Rewards.compute({ entry(500, false), entry(10, true), entry(1, true) }, 1)
		t.eq(rewards[1], nil, "crust-only miner, however big their contribution")
		t.eq(rewards[2].Floor, FLOOR, "core hitter 1")
		t.eq(rewards[3].Floor, FLOOR, "core hitter 2")
	end)

	t.test("the pool is split by contribution share among core hitters", function()
		-- Contribution shares 50% / 30% / 20% / 0%; the crust-only 1000 doesn't dilute them
		local entries = {
			entry(50, true),
			entry(30, true),
			entry(20, true),
			entry(0, true),
			entry(1000, false),
		}
		local rewards = Rewards.compute(entries, 1)
		local pool = PER_HITTER * 4
		t.eq(rewards[1].Bonus, round(pool * 0.5), "50% share")
		t.eq(rewards[2].Bonus, round(pool * 0.3), "30% share")
		t.eq(rewards[3].Bonus, round(pool * 0.2), "20% share")
		t.eq(rewards[4].Bonus, 0, "0% share")
		t.eq(rewards[5], nil, "crust-only miner")
		local paid = rewards[1].Bonus + rewards[2].Bonus + rewards[3].Bonus + rewards[4].Bonus
		t.ok(math.abs(paid - pool) <= 2, string.format("pool %d paid out as %d", pool, paid))
	end)

	t.test("core hitters with no contribution split the pool evenly", function()
		local rewards = Rewards.compute({ entry(0, true), entry(0, true) }, 1)
		t.eq(rewards[1].Bonus, round(PER_HITTER), "hitter 1")
		t.eq(rewards[2].Bonus, round(PER_HITTER), "hitter 2")
	end)

	t.test("top three by contribution get the top bonus, in any input order", function()
		local entries = {
			entry(10, true),
			entry(40, true),
			entry(5, true),
			entry(30, true),
			entry(20, true),
			entry(99, false), -- crust only: never placed
		}
		local rewards = Rewards.compute(entries, 1)
		t.eq(rewards[2].Top, TOP[1], "40 is first")
		t.eq(rewards[4].Top, TOP[2], "30 is second")
		t.eq(rewards[5].Top, TOP[3], "20 is third")
		t.eq(rewards[1].Top, 0, "10 is fourth")
		t.eq(rewards[3].Top, 0, "5 is fifth")
		t.eq(rewards[6], nil, "crust only")
		for index, reward in rewards do
			t.eq(reward.Total, reward.Floor + reward.Bonus + reward.Top, "total of entry " .. index)
		end
	end)

	t.test("fewer than three core hitters: only they are placed", function()
		local rewards = Rewards.compute({ entry(5, true), entry(9, true) }, 1)
		t.eq(rewards[2].Top, TOP[1], "first")
		t.eq(rewards[1].Top, TOP[2], "second")
	end)

	t.test("the pool multiplier scales the bonus pool only", function()
		local single = { entry(10, true) }
		local base = Rewards.compute(single, 1)[1]
		local doubled = Rewards.compute(single, 2)[1]
		t.eq(base.Bonus, round(PER_HITTER), "x1 pool")
		t.eq(doubled.Bonus, round(PER_HITTER * 2), "x2 pool")
		t.eq(doubled.Floor, base.Floor, "floor unchanged")
		t.eq(doubled.Top, base.Top, "top bonus unchanged")

		local pair = Rewards.compute({ entry(10, true), entry(10, true) }, 1.5)
		t.eq(pair[1].Bonus, round(PER_HITTER * 2 * 1.5 / 2), "x1.5 pool, even split")
		t.eq(pair[2].Bonus, round(PER_HITTER * 2 * 1.5 / 2), "x1.5 pool, even split")
	end)
end
