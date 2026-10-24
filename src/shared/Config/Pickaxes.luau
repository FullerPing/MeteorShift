--!strict
-- Pickaxe tiers (spec §7.1). There is one pickaxe for the whole game: ShopService evolves it
-- tier by tier, and its stat levels (Config.Gear, Shared.Gear) grow inside each tier. A row is
-- the pickaxe at the first level of its tier: Damage (for show), Swing and OrePerHit (flat per
-- tier, so veterans mine more per hit, not millions of times more). Cost is the price to evolve
-- INTO the tier and LevelCost what all of the tier's own levels cost together (Shared.Gear spreads
-- it over them, cheapest first); both cash only. A gate decides when you may evolve: a player level
-- for tiers 5 and 6, a rebirth count from tier 7 (Config.Levels).
-- Tiers 9 to 16 (2026-10-22) have no models yet: they show tier 8's model in their own Color.
-- Color tints the parts of the Pickaxe tool marked with a Tint attribute, so
-- higher tiers can be recolors of the same model.

export type Pickaxe = {
	Tier: number,
	Name: string,
	Damage: number,
	Swing: number,
	OrePerHit: number,
	Cost: number,
	LevelCost: number,
	Shards: number,
	Color: Color3,
}

local Pickaxes: { Pickaxe } = {
	{ Tier = 1, Name = "Basic Pickaxe", Damage = 5, Swing = 0.6, OrePerHit = 2, Cost = 0, LevelCost = 1.33e3, Shards = 0, Color = Color3.fromRGB(150, 150, 155) },
	{ Tier = 2, Name = "Steel Pickaxe", Damage = 12, Swing = 0.55, OrePerHit = 4, Cost = 4e3, LevelCost = 4.4e3, Shards = 0, Color = Color3.fromRGB(190, 205, 220) },
	{ Tier = 3, Name = "Drill Pick", Damage = 30, Swing = 0.5, OrePerHit = 6, Cost = 15e3, LevelCost = 13.94e3, Shards = 0, Color = Color3.fromRGB(255, 176, 48) },
	{ Tier = 4, Name = "Plasma Pick", Damage = 75, Swing = 0.47, OrePerHit = 10, Cost = 64e3, LevelCost = 780e3, Shards = 0, Color = Color3.fromRGB(80, 220, 255) },
	{ Tier = 5, Name = "Meteorite Pick", Damage = 180, Swing = 0.44, OrePerHit = 14, Cost = 520e3, LevelCost = 5.8e6, Shards = 0, Color = Color3.fromRGB(255, 96, 40) },
	{ Tier = 6, Name = "Nova Pick", Damage = 450, Swing = 0.41, OrePerHit = 20, Cost = 3.8e6, LevelCost = 36e6, Shards = 0, Color = Color3.fromRGB(186, 108, 255) },
	{ Tier = 7, Name = "Singularity Pick", Damage = 1.1e3, Swing = 0.38, OrePerHit = 28, Cost = 24e6, LevelCost = 460e6, Shards = 0, Color = Color3.fromRGB(40, 30, 60) },
	{ Tier = 8, Name = "Cosmic Pick", Damage = 2.8e3, Swing = 0.35, OrePerHit = 40, Cost = 320e6, LevelCost = 2.8e9, Shards = 0, Color = Color3.fromRGB(255, 120, 220) },
	{ Tier = 9, Name = "Quasar Pick", Damage = 7e3, Swing = 0.33, OrePerHit = 52, Cost = 1.88e9, LevelCost = 15e9, Shards = 0, Color = Color3.fromRGB(120, 255, 200) },
	{ Tier = 10, Name = "Pulsar Pick", Damage = 17.5e3, Swing = 0.31, OrePerHit = 68, Cost = 10e9, LevelCost = 80e9, Shards = 0, Color = Color3.fromRGB(90, 140, 255) },
	{ Tier = 11, Name = "Nebula Pick", Damage = 44e3, Swing = 0.29, OrePerHit = 88, Cost = 54e9, LevelCost = 440e9, Shards = 0, Color = Color3.fromRGB(255, 90, 160) },
	{ Tier = 12, Name = "Supernova Pick", Damage = 110e3, Swing = 0.27, OrePerHit = 114, Cost = 280e9, LevelCost = 2.4e12, Shards = 0, Color = Color3.fromRGB(255, 230, 90) },
	{ Tier = 13, Name = "Dark Matter Pick", Damage = 275e3, Swing = 0.255, OrePerHit = 148, Cost = 1.54e12, LevelCost = 12.2e12, Shards = 0, Color = Color3.fromRGB(70, 40, 120) },
	{ Tier = 14, Name = "Event Horizon Pick", Damage = 690e3, Swing = 0.24, OrePerHit = 192, Cost = 8.2e12, LevelCost = 66e12, Shards = 0, Color = Color3.fromRGB(255, 140, 60) },
	{ Tier = 15, Name = "Galaxy Pick", Damage = 1.7e6, Swing = 0.225, OrePerHit = 250, Cost = 44e12, LevelCost = 340e12, Shards = 0, Color = Color3.fromRGB(150, 200, 255) },
	{ Tier = 16, Name = "Big Bang Pick", Damage = 4.3e6, Swing = 0.21, OrePerHit = 324, Cost = 240e12, LevelCost = 1.76e15, Shards = 0, Color = Color3.fromRGB(255, 255, 255) },
}

return Pickaxes
