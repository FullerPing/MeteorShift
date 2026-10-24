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
	{ Tier = 4, Name = "Reinforced Pack", Capacity = 400, Cost = 24e3, LevelCost = 260e3, Shards = 0 },
	{ Tier = 5, Name = "Ore Hauler", Capacity = 600, Cost = 200e3, LevelCost = 1.9e6, Shards = 0 },
	{ Tier = 6, Name = "Cargo Rig", Capacity = 900, Cost = 1.4e6, LevelCost = 12e6, Shards = 0 },
	{ Tier = 7, Name = "Gravity Pack", Capacity = 1.3e3, Cost = 9.2e6, LevelCost = 160e6, Shards = 0 },
	{ Tier = 8, Name = "Void Pack", Capacity = 1.8e3, Cost = 120e6, LevelCost = 940e6, Shards = 0 },
	{ Tier = 9, Name = "Quantum Pack", Capacity = 2.35e3, Cost = 700e6, LevelCost = 5e9, Shards = 0 },
	{ Tier = 10, Name = "Nebula Pack", Capacity = 3.05e3, Cost = 3.8e9, LevelCost = 27e9, Shards = 0 },
	{ Tier = 11, Name = "Star Hauler", Capacity = 4e3, Cost = 20e9, LevelCost = 140e9, Shards = 0 },
	{ Tier = 12, Name = "Warp Rig", Capacity = 5.2e3, Cost = 110e9, LevelCost = 770e9, Shards = 0 },
	{ Tier = 13, Name = "Dark Matter Pack", Capacity = 6.7e3, Cost = 580e9, LevelCost = 4.1e12, Shards = 0 },
	{ Tier = 14, Name = "Pocket Dimension", Capacity = 8.8e3, Cost = 3.1e12, LevelCost = 22e12, Shards = 0 },
	{ Tier = 15, Name = "Galaxy Vault", Capacity = 11.4e3, Cost = 16e12, LevelCost = 120e12, Shards = 0 },
	{ Tier = 16, Name = "Infinity Pack", Capacity = 14.8e3, Cost = 87e12, LevelCost = 650e12, Shards = 0 },
}

return Backpacks
