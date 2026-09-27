--!strict
-- Backpack tiers (spec §7.2). Week 1 uses tier 1 as the placeholder backpack.

export type Backpack = {
	Tier: number,
	Capacity: number,
	Cost: number,
	Shards: number,
}

local Backpacks: { Backpack } = {
	{ Tier = 1, Capacity = 50, Cost = 0, Shards = 0 },
	{ Tier = 2, Capacity = 150, Cost = 500, Shards = 0 },
	{ Tier = 3, Capacity = 400, Cost = 6e3, Shards = 0 },
	{ Tier = 4, Capacity = 1e3, Cost = 70e3, Shards = 0 },
	{ Tier = 5, Capacity = 2.5e3, Cost = 900e3, Shards = 0 },
	{ Tier = 6, Capacity = 6e3, Cost = 12e6, Shards = 40 },
	{ Tier = 7, Capacity = 15e3, Cost = 150e6, Shards = 120 },
	{ Tier = 8, Capacity = 40e3, Cost = 2e9, Shards = 300 },
}

return Backpacks
