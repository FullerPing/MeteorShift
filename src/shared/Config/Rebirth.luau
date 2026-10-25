--!strict
-- Rebirth, "Relocate the Colony" (spec §8.3). Shared.Rebirth turns these into the
-- cost of the next rebirth, the cash multiplier and the overstay shards; RebirthService
-- applies them. The multiplier is the main inflation lever of the economy (spec §16): tune here.

return {
	-- Cash for rebirth 1, 2, ... 34, fitted with Shared.Pacing together with the gear and line prices (gear tiers
	-- kept through a rebirth): laps of about 11, 11, 13 and 14 minutes, then each rank fitted to a lap of about 14-15
	-- (tests/Pacing.spec holds them there). Gear tiers open every 3 ranks from rebirth 10 (Config.Levels.EvolveRebirths),
	-- so the costs follow that cycle: about x3.5 on every third rebirth (12, 15, ... 33), whose lap starts with the new
	-- tier's gear, and x1.6-2 between.
	-- Edit them together with Config.Pickaxes, Config.Backpacks and Config.Home, then re-run the model
	-- (docs/guide/economy.md). Re-fit 2026-10-25 (owner: from rebirth 10 a tier every 3 rebirths, not 2).
	-- From rebirth 26 the player is in Nebula Rift (Config.Worlds), whose ores pay 3x; the fit includes it.
	Costs = { 34e3, 233e3, 778e3, 1.96e6, 7.62e6, 12.2e6, 51.9e6, 83e6, 359e6, 765e6, 1.22e9, 4.73e9, 9.63e9, 15.4e9, 54.5e9,
		112e9, 179e9, 600e9, 1.22e12, 1.95e12, 6.53e12, 14.4e12, 23e12, 78.6e12, 162e12, 394e12, 2.48e15, 5.06e15, 8.1e15,
		26.5e15, 61e15, 97.6e15, 304e15, 652e15 },
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
		[25] = "Nebula Rift, World 2: ores sell for 3x",
		[27] = "the Starlight Shelf field in Nebula Rift",
		[30] = "the Event Horizon field in Nebula Rift",
	},

	ConfirmWindow = 3, -- seconds the panel waits for the second "Are you sure?" press
}
