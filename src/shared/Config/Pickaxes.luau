--!strict
-- Pickaxe tiers (spec §7.1). There is one pickaxe for the whole game: ShopService evolves it
-- tier by tier, and its stat levels (Config.Gear, Shared.Gear) grow inside each tier. A row is
-- the pickaxe at the first level of its tier: Damage (for show), Swing and OrePerHit (flat per
-- tier, so veterans mine more per hit, not millions of times more). Cost is the price to evolve
-- INTO the tier and LevelCost what all of the tier's own levels cost together (Shared.Gear spreads
-- it over them, cheapest first); both cash only. A gate decides when you may evolve: a player level
-- for tiers 5 and 6, a rebirth count from tier 7 (Config.Levels).
-- Tiers 9 to 16 (2026-10-22) have no models yet: they show tier 8's model in their own Color.
-- Owner 2026-10-24: from tier 9 the ore (and cash prices) ramp from x1 to x2 at tier 16, +1/8 a tier; Config.Backpacks,
-- Config.Home (line one tier ahead) and Config.Rebirth carry the same ramp, so Shared.Pacing's laps hold.
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
	{ Tier = 1, Name = "Basic Pickaxe", Damage = 5, Swing = 0.6, OrePerHit = 1, Cost = 0, LevelCost = 665, Shards = 0, Color = Color3.fromRGB(150, 150, 155) },
	{ Tier = 2, Name = "Steel Pickaxe", Damage = 12, Swing = 0.55, OrePerHit = 2, Cost = 2000, LevelCost = 2200, Shards = 0, Color = Color3.fromRGB(190, 205, 220) },
	{ Tier = 3, Name = "Drill Pick", Damage = 30, Swing = 0.5, OrePerHit = 3, Cost = 7500, LevelCost = 6970, Shards = 0, Color = Color3.fromRGB(255, 176, 48) },
	{ Tier = 4, Name = "Plasma Pick", Damage = 75, Swing = 0.47, OrePerHit = 5, Cost = 32e3, LevelCost = 390e3, Shards = 0, Color = Color3.fromRGB(80, 220, 255) },
	{ Tier = 5, Name = "Meteorite Pick", Damage = 180, Swing = 0.44, OrePerHit = 7, Cost = 260e3, LevelCost = 2.9e6, Shards = 0, Color = Color3.fromRGB(255, 96, 40) },
	{ Tier = 6, Name = "Nova Pick", Damage = 450, Swing = 0.41, OrePerHit = 10, Cost = 1.9e6, LevelCost = 18e6, Shards = 0, Color = Color3.fromRGB(186, 108, 255) },
	{ Tier = 7, Name = "Singularity Pick", Damage = 1.1e3, Swing = 0.38, OrePerHit = 14, Cost = 12e6, LevelCost = 230e6, Shards = 0, Color = Color3.fromRGB(40, 30, 60) },
	{ Tier = 8, Name = "Cosmic Pick", Damage = 2.8e3, Swing = 0.35, OrePerHit = 20, Cost = 160e6, LevelCost = 1.4e9, Shards = 0, Color = Color3.fromRGB(255, 120, 220) },
	{ Tier = 9, Name = "Quasar Pick", Damage = 7e3, Swing = 0.33, OrePerHit = 29, Cost = 942e6, LevelCost = 8.44e9, Shards = 0, Color = Color3.fromRGB(120, 255, 200) },
	{ Tier = 10, Name = "Pulsar Pick", Damage = 17.5e3, Swing = 0.31, OrePerHit = 42, Cost = 5.62e9, LevelCost = 50e9, Shards = 0, Color = Color3.fromRGB(90, 140, 255) },
	{ Tier = 11, Name = "Nebula Pick", Damage = 44e3, Swing = 0.29, OrePerHit = 60, Cost = 33.7e9, LevelCost = 302e9, Shards = 0, Color = Color3.fromRGB(255, 90, 160) },
	{ Tier = 12, Name = "Supernova Pick", Damage = 110e3, Swing = 0.27, OrePerHit = 86, Cost = 192e9, LevelCost = 1.8e12, Shards = 0, Color = Color3.fromRGB(255, 230, 90) },
	{ Tier = 13, Name = "Dark Matter Pick", Damage = 275e3, Swing = 0.255, OrePerHit = 120, Cost = 1.15e12, LevelCost = 9.91e12, Shards = 0, Color = Color3.fromRGB(70, 40, 120) },
	{ Tier = 14, Name = "Event Horizon Pick", Damage = 690e3, Swing = 0.24, OrePerHit = 168, Cost = 6.67e12, LevelCost = 57.8e12, Shards = 0, Color = Color3.fromRGB(255, 140, 60) },
	{ Tier = 15, Name = "Galaxy Pick", Damage = 1.7e6, Swing = 0.225, OrePerHit = 234, Cost = 38.5e12, LevelCost = 319e12, Shards = 0, Color = Color3.fromRGB(150, 200, 255) },
	{ Tier = 16, Name = "Big Bang Pick", Damage = 4.3e6, Swing = 0.21, OrePerHit = 324, Cost = 225e12, LevelCost = 1.76e15, Shards = 0, Color = Color3.fromRGB(255, 255, 255) },
}

return Pickaxes
