--!strict
-- Rebirth, "Relocate the Colony" (spec §8.3). Shared.Rebirth turns these into the
-- cost of the next rebirth, the cash multiplier and the overstay shards; RebirthService
-- applies them. The multiplier is the main inflation lever of the economy (spec §16): tune here.

return {
	-- Cash for rebirth 1, 2, ... 30, fitted with Shared.Pacing together with the gear and line prices (gear tiers
	-- kept through a rebirth): laps of about 12, 12, 14 and 15 minutes, then x2.35 a rank, which alternates a long
	-- lap that buys a newly opened gear tier (Config.Levels.EvolveRebirths) with a short one after it, about 13 on
	-- average (tests/Pacing.spec holds them there). Edit them together with Config.Pickaxes, Config.Backpacks and
	-- Config.Home, then re-run the model (docs/guide/economy.md).
	-- Re-fit 2026-10-24 (owner: tier 4 opens at rebirth 1 and tier 8 at rebirth 10, then a tier every 2 rebirths).
	Costs = { 34e3, 210e3, 700e3, 1.6e6, 3.8e6, 8.8e6, 21e6, 49e6, 110e6, 270e6, 630e6, 1.5e9, 3.94e9, 9.22e9, 23.8e9,
		56.2e9, 151e9, 344e9, 885e9, 2.1e12, 5.36e12, 12.4e12, 31.5e12, 73.5e12, 186e12, 431e12, 1.1e15, 2.6e15, 6e15, 14.2e15 },
	CashMult = 2, -- bar sales multiplier gained per rebirth, multiplicative (x2, x4, x8, ...)
	-- Cash price inflation per rebirth (Shared.Rebirth.priceMult). 1 = gear and production prices never rise,
	-- so each rebirth really is worth x2. Shard prices and Robux products never inflate.
	PriceGrowth = 1,

	-- Past the last listed rank ("Legacy"): the cost keeps growing by CostGrowth per rebirth and the
	-- multiplier by MultGrowth. FirstStep is the listed ranks' own ratio; no gear tier opens past them, and
	-- cost outpaces the multiplier by 2.05 / 2, so laps stretch about 2.5% a rank.
	Legacy = { FirstStep = 2.35, CostGrowth = 2.05, MultGrowth = 2, PriceGrowth = 1 },

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
