--!strict
-- Backpack tiers (spec §7.2). One backpack for the whole game: ShopService evolves it tier by
-- tier and its Capacity stat levels up inside each tier (Config.Gear, Shared.Gear). A row is
-- the backpack at the first level of its tier; Cost and Shards are the price to evolve INTO it.
-- Capacity tracks ore per hit, so a full load stays about 50 to 90 hits.

export type Backpack = {
	Tier: number,
	Name: string,
	Capacity: number,
	Cost: number,
	Shards: number,
}

local Backpacks: { Backpack } = {
	{ Tier = 1, Name = "Canvas Sack", Capacity = 50, Cost = 0, Shards = 0 },
	{ Tier = 2, Name = "Leather Pack", Capacity = 150, Cost = 300, Shards = 0 },
	{ Tier = 3, Name = "Miner's Pack", Capacity = 250, Cost = 1.2e3, Shards = 0 },
	{ Tier = 4, Name = "Reinforced Pack", Capacity = 400, Cost = 6e3, Shards = 0 },
	{ Tier = 5, Name = "Ore Hauler", Capacity = 600, Cost = 30e3, Shards = 0 },
	{ Tier = 6, Name = "Cargo Rig", Capacity = 900, Cost = 150e3, Shards = 20 },
	{ Tier = 7, Name = "Gravity Pack", Capacity = 1.3e3, Cost = 700e3, Shards = 50 },
	{ Tier = 8, Name = "Void Pack", Capacity = 1.8e3, Cost = 3.5e6, Shards = 120 },
}

return Backpacks
