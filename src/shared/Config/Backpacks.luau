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
	{ Tier = 1, Name = "Canvas Sack", Capacity = 100, Cost = 0, LevelCost = 1.108e3, Shards = 0 },
	{ Tier = 2, Name = "Leather Pack", Capacity = 300, Cost = 2.6e3, LevelCost = 3.66e3, Shards = 0 },
	{ Tier = 3, Name = "Miner's Pack", Capacity = 500, Cost = 10e3, LevelCost = 11.62e3, Shards = 0 },
	{ Tier = 4, Name = "Reinforced Pack", Capacity = 800, Cost = 48e3, LevelCost = 520e3, Shards = 0 },
	{ Tier = 5, Name = "Ore Hauler", Capacity = 1.2e3, Cost = 400e3, LevelCost = 3.8e6, Shards = 0 },
	{ Tier = 6, Name = "Cargo Rig", Capacity = 1.8e3, Cost = 2.8e6, LevelCost = 24e6, Shards = 0 },
	{ Tier = 7, Name = "Gravity Pack", Capacity = 2.6e3, Cost = 18.4e6, LevelCost = 320e6, Shards = 0 },
	{ Tier = 8, Name = "Void Pack", Capacity = 3.6e3, Cost = 240e6, LevelCost = 1.88e9, Shards = 0 },
	{ Tier = 9, Name = "Quantum Pack", Capacity = 4.7e3, Cost = 1.4e9, LevelCost = 10e9, Shards = 0 },
	{ Tier = 10, Name = "Nebula Pack", Capacity = 6.1e3, Cost = 7.6e9, LevelCost = 54e9, Shards = 0 },
	{ Tier = 11, Name = "Star Hauler", Capacity = 8e3, Cost = 40e9, LevelCost = 280e9, Shards = 0 },
	{ Tier = 12, Name = "Warp Rig", Capacity = 10.4e3, Cost = 220e9, LevelCost = 1.54e12, Shards = 0 },
	{ Tier = 13, Name = "Dark Matter Pack", Capacity = 13.4e3, Cost = 1.16e12, LevelCost = 8.2e12, Shards = 0 },
	{ Tier = 14, Name = "Pocket Dimension", Capacity = 17.6e3, Cost = 6.2e12, LevelCost = 44e12, Shards = 0 },
	{ Tier = 15, Name = "Galaxy Vault", Capacity = 22.8e3, Cost = 32e12, LevelCost = 240e12, Shards = 0 },
	{ Tier = 16, Name = "Infinity Pack", Capacity = 29.6e3, Cost = 174e12, LevelCost = 1.3e15, Shards = 0 },
}

return Backpacks
