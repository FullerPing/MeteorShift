--!strict
-- Rebirth, "Relocate the Colony" (spec §8.3). Shared.Rebirth turns these into the
-- cost of the next rebirth, the cash multiplier and the overstay shards; RebirthService
-- applies them. The multiplier is the main inflation lever of the economy (spec §16): tune here.

return {
	-- Cash for rebirth 1, 2, ... 16, fitted with Shared.Pacing (gear tiers kept through a rebirth) so the laps take
	-- about 15, 16, 20 and 24 minutes and then 22-23 up to rank 16 on the 120 s countdown (tests/Pacing.spec holds
	-- them there). Each cost was searched on its own lap with the earlier ones fixed. Past rank 4 they double like
	-- the multiplier; the early ranks pay for the gear ramp. Edit them together with Config.Levels and Config.Home,
	-- then re-run the model (docs/design/economy-rework.md).
	-- Re-fit 2026-10-22 (owner: a rebirth is a plain x2, not the old x5 sales with x3 prices).
	Costs = { 34e3, 540e3, 2e6, 6.1e6, 14e6, 29e6, 58e6, 130e6, 360e6, 750e6, 1.4e9, 2.9e9, 6e9, 12e9, 24e9, 48e9 },
	CashMult = 2, -- bar sales multiplier gained per rebirth, multiplicative (x2, x4, x8, ...)
	-- Cash price inflation per rebirth (Shared.Rebirth.priceMult). 1 = gear and production prices never rise,
	-- so each rebirth really is worth x2. Shard prices and Robux products never inflate.
	PriceGrowth = 1,

	-- Past the last listed rank ("Legacy"): the cost keeps growing by CostGrowth per rebirth and the
	-- multiplier by MultGrowth. FirstStep is the listed ranks' own ratio, and cost outpaces the multiplier
	-- by 2.05 / 2, so laps stretch about 2.5% a rank.
	Legacy = { FirstStep = 2, CostGrowth = 2.05, MultGrowth = 2, PriceGrowth = 1 },

	-- Overstay shards: bar-sale cash you earned after you could first afford the rebirth is
	-- progress you didn't need. Rebirthing pays min(Cap, round(PerDoubling × log2(1 + r))) shards
	-- for r = that cash / the rebirth's cost. Rebirthing right away pays none, and waiting
	-- never beats the x2 you give up by not rebirthing.
	Overstay = { PerDoubling = 20, Cap = 60 },

	-- What each rank adds, for the rebirth panel (the rules that act on it live where the feature does:
	-- Config.Pets.Slots, Config.Meteor.Boss.MinRebirths, Config.Pets eggs, Config.Debris.Fields unlocks;
	-- tests/Consistency.spec checks the pet slots and fields against them)
	Unlocks = {
		[1] = "Colony Perks panel, +1 pet slot, the Starfall field",
		[2] = "Aurora Egg (Epic or better only), +1 pet slot",
		[3] = "Alien Boss meteor every hour, new Alien ore, the Halo Ledge field",
		[4] = "+1 pet slot",
	},

	ConfirmWindow = 3, -- seconds the panel waits for the second "Are you sure?" press
}
