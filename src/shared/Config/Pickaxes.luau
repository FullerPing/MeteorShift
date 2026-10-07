--!strict
-- Pickaxe tiers (spec §7.1). There is one pickaxe for the whole game: ShopService evolves it
-- tier by tier, and its stat levels (Config.Gear, Shared.Gear) grow inside each tier. A row is
-- the pickaxe at the first level of its tier: Damage (for show), Swing and OrePerHit (flat per
-- tier, 1 to 20, so veterans mine a little more per hit, not hundreds of times more). Cost is
-- the price to evolve INTO the tier (cash only; a level gate, Config.Levels.EvolveLevel, decides when).
-- Color tints the parts of the Pickaxe tool marked with a Tint attribute, so
-- higher tiers can be recolors of the same model.

export type Pickaxe = {
	Tier: number,
	Name: string,
	Damage: number,
	Swing: number,
	OrePerHit: number,
	Cost: number,
	Shards: number,
	Color: Color3,
}

local Pickaxes: { Pickaxe } = {
	{ Tier = 1, Name = "Basic Pickaxe", Damage = 5, Swing = 0.6, OrePerHit = 1, Cost = 0, Shards = 0, Color = Color3.fromRGB(150, 150, 155) },
	{ Tier = 2, Name = "Steel Pickaxe", Damage = 12, Swing = 0.55, OrePerHit = 2, Cost = 250, Shards = 0, Color = Color3.fromRGB(190, 205, 220) },
	{ Tier = 3, Name = "Drill Pick", Damage = 30, Swing = 0.5, OrePerHit = 3, Cost = 650, Shards = 0, Color = Color3.fromRGB(255, 176, 48) },
	{ Tier = 4, Name = "Plasma Pick", Damage = 75, Swing = 0.47, OrePerHit = 5, Cost = 1900, Shards = 0, Color = Color3.fromRGB(80, 220, 255) },
	{ Tier = 5, Name = "Meteorite Pick", Damage = 180, Swing = 0.44, OrePerHit = 7, Cost = 6500, Shards = 0, Color = Color3.fromRGB(255, 96, 40) },
	{ Tier = 6, Name = "Nova Pick", Damage = 450, Swing = 0.41, OrePerHit = 10, Cost = 19e3, Shards = 0, Color = Color3.fromRGB(186, 108, 255) },
	{ Tier = 7, Name = "Singularity Pick", Damage = 1.1e3, Swing = 0.38, OrePerHit = 14, Cost = 55e3, Shards = 0, Color = Color3.fromRGB(40, 30, 60) },
	{ Tier = 8, Name = "Cosmic Pick", Damage = 2.8e3, Swing = 0.35, OrePerHit = 20, Cost = 170e3, Shards = 0, Color = Color3.fromRGB(255, 120, 220) },
}

return Pickaxes
