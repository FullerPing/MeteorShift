--!strict
-- Home loop tuning (spec §6): hopper, refineries, offline income, bar prices.

local Home = {}

-- Hopper capacity per level (spec §6.2)
Home.Hoppers = {
	{ Level = 1, Capacity = 2e3, Cost = 0 },
	{ Level = 2, Capacity = 8e3, Cost = 5e3 },
	{ Level = 3, Capacity = 32e3, Cost = 100e3 },
	{ Level = 4, Capacity = 128e3, Cost = 2e6 },
	{ Level = 5, Capacity = 512e3, Cost = 40e6 },
	{ Level = 6, Capacity = 2e6, Cost = 800e6 },
	{ Level = 7, Capacity = 8e6, Cost = 15e9 },
}

-- Refinery throughput per level, 1 ore -> 1 bar (spec §6.3)
Home.Refineries = {
	{ Level = 1, Throughput = 0.25, Cost = 0, Shards = 0 },
	{ Level = 2, Throughput = 0.75, Cost = 1.5e3, Shards = 0 },
	{ Level = 3, Throughput = 2.5, Cost = 20e3, Shards = 0 },
	{ Level = 4, Throughput = 8, Cost = 250e3, Shards = 0 },
	{ Level = 5, Throughput = 25, Cost = 3e6, Shards = 25 },
	{ Level = 6, Throughput = 80, Cost = 40e6, Shards = 60 },
	{ Level = 7, Throughput = 250, Cost = 500e6, Shards = 150 },
	{ Level = 8, Throughput = 800, Cost = 6e9, Shards = 400 },
}

-- Refinery slot prices (spec §7.3). Purchases arrive in Week 3; slot 1 is free.
Home.RefinerySlots = {
	{ Slot = 1, Cost = 0, Shards = 0 },
	{ Slot = 2, Cost = 2e3, Shards = 0 },
	{ Slot = 3, Cost = 25e3, Shards = 0 },
	{ Slot = 4, Cost = 300e3, Shards = 25 },
	{ Slot = 5, Cost = 4e6, Shards = 60 },
	{ Slot = 6, Cost = 50e6, Shards = 120 },
}
Home.MaxRefineryPads = 6 -- a 7th pad comes with the Extra Refinery pass (Week 4)

-- Offline income (spec §6.4)
Home.OfflineCap = 2 * 3600
Home.OfflineCapPass = 8 * 3600

Home.TickInterval = 1 -- online refinery tick, seconds

-- Order in which a refinery pulls ore types from the hopper
Home.OreOrder = { "iron", "frost" }

-- Bar sell prices (spec §6.5)
Home.BarPrices = {
	iron = 5,
	frost = 120,
}

Home.OreNames = {
	iron = "Iron",
	frost = "Frost",
}

return Home
