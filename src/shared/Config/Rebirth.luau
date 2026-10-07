--!strict
-- Rebirth, "Relocate the Colony" (spec §8.3). Shared.Rebirth turns these into the
-- cost of the next rebirth, the cash multiplier and the overstay shards; RebirthService
-- applies them. The multiplier is the main inflation lever of the economy (spec §16): tune here.

return {
	-- Cash for rebirth 1, 2, ... 16, tuned by running Shared.Pacing so the laps take about 13, 16,
	-- 20 and 24 minutes and then about 25 up to rank 16 (tests/Pacing.spec holds them there).
	-- They are not a clean x5: lap 1 pays for the gear ramp, and the tiers and ores that player
	-- level opens keep arriving for the first hours. Edit them together with Config.Levels and
	-- Config.Home, then re-run the model (docs/economy-rework.md).
	Costs = { 88e3, 1.2e6, 9.6e6, 58e6, 500e6, 2.6e9, 14e9, 67e9, 350e9, 2.2e12, 13e12, 65e12, 300e12, 1.6e15, 7.5e15, 38e15 },
	CashMult = 5, -- bar sales multiplier gained per rebirth for the listed ranks, multiplicative (x5, x25, x125, ...)

	-- Past the last listed rank ("Legacy"): the cost keeps growing by CostGrowth per rebirth and the
	-- multiplier by MultGrowth. Both are far below the x5 of the early ranks so the numbers stop
	-- racing toward the suffix limit, and cost outpaces the multiplier a little, so laps stretch
	-- gently instead of the treadmill staying flat forever.
	Legacy = { CostGrowth = 2.3, MultGrowth = 2 },

	-- Overstay shards: bar-sale cash you earned after you could first afford the rebirth is
	-- progress you didn't need. Rebirthing pays min(Cap, round(PerDoubling × log2(1 + r))) shards
	-- for r = that cash / the rebirth's cost. Rebirthing right away pays none, and waiting
	-- never beats the x5 you give up by not rebirthing.
	Overstay = { PerDoubling = 20, Cap = 60 },

	-- What each rank adds, for the rebirth panel (the rules that act on it live where the feature does:
	-- Config.Pets.Slots, Config.Meteor.Types.Alien.MinRebirths, Config.Pets eggs)
	Unlocks = {
		[1] = "Colony Perks panel, +1 pet slot",
		[2] = "Aurora Egg (Epic or better only)",
		[3] = "Alien Boss meteor every hour, new Alien ore",
		[4] = "+1 pet slot",
	},

	ConfirmWindow = 3, -- seconds the panel waits for the second "Are you sure?" press
}
