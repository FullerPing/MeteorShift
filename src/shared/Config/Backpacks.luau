--!strict
-- Backpack tiers (spec §7.2). One backpack for the whole game: ShopService evolves it tier by
-- tier and its Capacity stat levels up inside each tier (Config.Gear, Shared.Gear). A row is
-- the backpack at the first level of its tier; Cost is the price to evolve INTO it and LevelCost what
-- all of its levels cost together (cash only; the same gates as Config.Pickaxes).
-- Capacity tracks ore per hit, so a full load stays about 50 to 90 hits. Tiers 9 to 16 have no models
-- yet (tier 8's model shows instead).

export type Backpack = {
	Tier: number,
	Name: string,
	Capacity: number,
	Cost: number,
	LevelCost: number,
	Shards: number,
}

local Backpacks: { Backpack } = {
	{ Tier = 1, Name = "Canvas Sack", Capacity = 50, Cost = 0, LevelCost = 554, Shards = 0 },
	{ Tier = 2, Name = "Leather Pack", Capacity = 150, Cost = 1300, LevelCost = 1830, Shards = 0 },
	{ Tier = 3, Name = "Miner's Pack", Capacity = 250, Cost = 5000, LevelCost = 5810, Shards = 0 },
	{ Tier = 4, Name = "Reinforced Pack", Capacity = 444, Cost = 24e3, LevelCost = 289e3, Shards = 0 },
	{ Tier = 5, Name = "Ore Hauler", Capacity = 733, Cost = 222e3, LevelCost = 2.32e6, Shards = 0 },
	{ Tier = 6, Name = "Cargo Rig", Capacity = 1.2e3, Cost = 1.71e6, LevelCost = 16e6, Shards = 0 },
	{ Tier = 7, Name = "Gravity Pack", Capacity = 1.88e3, Cost = 12.3e6, LevelCost = 231e6, Shards = 0 },
	{ Tier = 8, Name = "Void Pack", Capacity = 2.8e3, Cost = 173e6, LevelCost = 1.46e9, Shards = 0 },
	{ Tier = 9, Name = "Quantum Pack", Capacity = 3.92e3, Cost = 1.09e9, LevelCost = 8.33e9, Shards = 0 },
	{ Tier = 10, Name = "Nebula Pack", Capacity = 5.42e3, Cost = 6.33e9, LevelCost = 48e9, Shards = 0 },
	{ Tier = 11, Name = "Star Hauler", Capacity = 7.56e3, Cost = 35.6e9, LevelCost = 264e9, Shards = 0 },
	{ Tier = 12, Name = "Warp Rig", Capacity = 10.4e3, Cost = 208e9, LevelCost = 1.54e12, Shards = 0 },
	{ Tier = 13, Name = "Dark Matter Pack", Capacity = 13.4e3, Cost = 1.16e12, LevelCost = 8.2e12, Shards = 0 },
	{ Tier = 14, Name = "Pocket Dimension", Capacity = 17.6e3, Cost = 6.2e12, LevelCost = 44e12, Shards = 0 },
	{ Tier = 15, Name = "Galaxy Vault", Capacity = 22.8e3, Cost = 32e12, LevelCost = 240e12, Shards = 0 },
	{ Tier = 16, Name = "Infinity Pack", Capacity = 29.6e3, Cost = 174e12, LevelCost = 1.3e15, Shards = 0 },
}

return Backpacks
