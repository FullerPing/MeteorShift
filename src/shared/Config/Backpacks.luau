--!strict
-- Backpack tiers (spec §7.2), bought one after another in the shop (ShopService).

export type Backpack = {
	Tier: number,
	Name: string,
	Capacity: number,
	Cost: number,
	Shards: number,
}

local Backpacks: { Backpack } = {
	{ Tier = 1, Name = "Canvas Sack", Capacity = 50, Cost = 0, Shards = 0 },
	{ Tier = 2, Name = "Leather Pack", Capacity = 150, Cost = 500, Shards = 0 },
	{ Tier = 3, Name = "Miner's Pack", Capacity = 400, Cost = 6e3, Shards = 0 },
	{ Tier = 4, Name = "Reinforced Pack", Capacity = 1e3, Cost = 70e3, Shards = 0 },
	{ Tier = 5, Name = "Ore Hauler", Capacity = 2.5e3, Cost = 900e3, Shards = 0 },
	{ Tier = 6, Name = "Cargo Rig", Capacity = 6e3, Cost = 12e6, Shards = 40 },
	{ Tier = 7, Name = "Gravity Pack", Capacity = 15e3, Cost = 150e6, Shards = 120 },
	{ Tier = 8, Name = "Void Pack", Capacity = 40e3, Cost = 2e9, Shards = 300 },
}

return Backpacks
