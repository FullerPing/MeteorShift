--!strict
-- Backpack tiers (spec §7.2). One backpack for the whole game: ShopService evolves it tier by
-- tier and its Capacity stat levels up inside each tier (Config.Gear, Shared.Gear). A row is
-- the backpack at the first level of its tier; Cost (cash only) is the price to evolve INTO it.
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
	{ Tier = 2, Name = "Leather Pack", Capacity = 150, Cost = 180, Shards = 0 },
	{ Tier = 3, Name = "Miner's Pack", Capacity = 250, Cost = 430, Shards = 0 },
	{ Tier = 4, Name = "Reinforced Pack", Capacity = 400, Cost = 1300, Shards = 0 },
	{ Tier = 5, Name = "Ore Hauler", Capacity = 600, Cost = 3900, Shards = 0 },
	{ Tier = 6, Name = "Cargo Rig", Capacity = 900, Cost = 11500, Shards = 0 },
	{ Tier = 7, Name = "Gravity Pack", Capacity = 1.3e3, Cost = 32e3, Shards = 0 },
	{ Tier = 8, Name = "Void Pack", Capacity = 1.8e3, Cost = 100e3, Shards = 0 },
}

return Backpacks
