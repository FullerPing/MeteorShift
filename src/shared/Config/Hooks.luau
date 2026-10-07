--!strict
-- Engagement hooks (docs/economy-rework.md): small random rewards on a variable-ratio
-- schedule, plus the rules that keep them fair. Shared.Hooks holds the math; NodeService,
-- MeteorService, LevelService and RefineryService run them.
--
-- House rules:
--   - Nothing here is sold for Robux, and nothing changes mineral or egg odds.
--   - Ore jackpots are EV-neutral: Shared.Hooks.oreBase scales every normal hit down by exactly
--     what the jackpots add on average (Rich Vein, Super Vein and Golden Meteor), so the
--     average ore per hit is what Config.Pickaxes says.
--   - Every random reward has a floor or pity (the core's shard floor, the consolation payout,
--     egg pity, the mineral soft pity).

return {
	-- Per validated swing on a crust node or debris: usually the base amount, sometimes a multiple
	RichVein = { Chance = 0.04, Mult = 8 },
	SuperVein = { Chance = 0.002, Mult = 40 },

	-- One random crust node per meteor glows gold. The player who lands the breaking hit gets
	-- Breaker hits' worth of ore, everyone else who hit it gets Contributor hits' worth.
	GoldenNode = { Breaker = 20, Contributor = 4 },

	-- A meteor of the scheduled type turns golden with this chance: its ore pays PayMult times
	GoldenMeteor = { Chance = 0.02, PayMult = 5 },

	-- A crust node that breaks may drop a shard crumb for the player who broke it
	ShardCrumb = { Chance = 0.06, Min = 1, Max = 3 },

	-- Consolation payout: a meteor that cools with its core at least this far down still pays
	-- its shard floor to everyone who hit the core
	Consolation = { CoreDownFraction = 0.5 },

	-- Supply Crate: one per level gained. A crate is a roll over these bands, in order; its cash is a
	-- stretch of your current line income (line rate x average bar price x sale multiplier),
	-- drawn from a range of seconds. Sized from the line, not the wallet, so it is as big as
	-- the level you are at; kept small enough that the first laps still take their planned time.
	SupplyCrate = {
		{ Chance = 0.80, Kind = "cash", MinSeconds = 15, MaxSeconds = 50 },
		{ Chance = 0.15, Kind = "cashShards", MinSeconds = 10, MaxSeconds = 25, Shards = { 1, 5 } },
		{ Chance = 0.045, Kind = "shards", Shards = { 5, 15 } },
		{ Chance = 0.005, Kind = "shards", Shards = { 30, 30 } }, -- one Meteor Egg's worth
	},
	-- A crate's cash is never below Floor nor above this share of the next rebirth's cost
	CrateFloor = 100,
	CrateCeilingShare = 0.05,

	-- Welcome back: the offline catch-up rolls a bonus on the bars it made. Bands of { chance, multiplier }.
	WelcomeBack = { { 0.80, 1 }, { 0.17, 1.5 }, { 0.03, 3 } },

	-- Mineral index soft pity: after this many hits without any mineral, every hit's odds rise by
	-- the same amount again, up to MaxMult times (docs/economy-rework.md; Shared.MineralIndex)
	Pity = { AfterHits = 400, StepHits = 100, MaxMult = 3 },
}
