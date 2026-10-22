--!strict
-- Rebirth, "Relocate the Colony" (spec §8.3). Shared.Rebirth turns these into the
-- cost of the next rebirth, the cash multiplier and the overstay shards; RebirthService
-- applies them. The multiplier is the main inflation lever of the economy (spec §16): tune here.

return {
	-- Cash for rebirth 1, 2, ... 16, fitted with Shared.Pacing (gear tiers kept through a rebirth and cash
	-- prices x PriceGrowth per rebirth, 2026-10-10) so the laps take about 13, 18, 23 and 24 minutes and then
	-- about 25 up to rank 16 (tests/Pacing.spec holds them there). Each cost was searched on its own lap
	-- with the earlier ones fixed, so lap 2 and 3 settle a little above the 16 and 20 minutes aimed at.
	-- They are not a clean x5: lap 1 pays for the gear ramp, and the tiers and ores that player
	-- level opens keep arriving for the first hours. Edit them together with Config.Levels and
	-- Config.Home, then re-run the model (docs/design/economy-rework.md).
	-- Re-fit 2026-10-19 (owner: the first meteor cycle got you straight to tier 3): tiers 2-4 and line levels 2-4
	-- cost several times more, so the Drill Pick lands at about 8 minutes; ranks 1 and 4 were re-searched so the
	-- laps run about 15, 16, 20, 24 and then 21-23 minutes on the 120 s countdown.
	Costs = { 30e3, 1.2e6, 12e6, 90e6, 530e6, 2.9e9, 14e9, 69e9, 380e9, 2.6e12, 13e12, 64e12, 340e12, 1.6e15, 8.5e15, 40e15 },
	CashMult = 5, -- bar sales multiplier gained per rebirth for the listed ranks, multiplicative (x5, x25, x125, ...)
	-- Cash price inflation per rebirth: gear and production upgrades cost this much more for every rebirth
	-- (Shared.Rebirth.priceMult). Income grows x5 and prices x3, so a rebirth is worth 5/3 in real terms
	-- while both sides of the economy read as big numbers. Shard prices and Robux products do not inflate.
	PriceGrowth = 3,

	-- Past the last listed rank ("Legacy"): the cost keeps growing by CostGrowth per rebirth and the
	-- multiplier by MultGrowth. Both are far below the x5 of the early ranks so the numbers stop
	-- racing toward the suffix limit. The last listed rank still multiplies sales x5, so the first Legacy
	-- cost steps up by FirstStep (about the listed ranks' own ratio) and the lap after it stays as long as
	-- the one before (it used to halve). After that cost outpaces the multiplier by 2.05 / 2, so laps stretch
	-- about 2.5% a rank (Shared.Pacing: about 21 min at rank 17 to about 35 at rank 40; 2.3 compounded to 3 hours).
	Legacy = { FirstStep = 4.7, CostGrowth = 2.05, MultGrowth = 2, PriceGrowth = 1.2 }, -- 2 / 1.2 keeps the 5/3 price ratio

	-- Overstay shards: bar-sale cash you earned after you could first afford the rebirth is
	-- progress you didn't need. Rebirthing pays min(Cap, round(PerDoubling × log2(1 + r))) shards
	-- for r = that cash / the rebirth's cost. Rebirthing right away pays none, and waiting
	-- never beats the x5 you give up by not rebirthing.
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
