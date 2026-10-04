--!strict
-- Home loop tuning (spec §6, reworked): every plot runs one production line
--
--   hopper -> conveyor -> refinery -> collection post
--
-- and each of the four stations upgrades on its own. Ore flows at the slower of
-- the conveyor and the refinery; the hopper caps how much ore waits, the
-- collection post caps how many bars wait to be picked up (and so how much
-- offline income piles up). Conveyor and refinery rates are ore per second and track what a
-- player mines at that stage (docs/balance.md); their prices climb roughly ×6 per level.

local Home = {}

export type Level = {
	Cost: number,
	Shards: number,
	Capacity: number?, -- hopper (ore), collector (bars)
	Rate: number?, -- conveyor and refinery (ore per second)
}

export type Station = {
	Id: string,
	Name: string,
	Levels: { Level },
}

local function levels(list: { { number } }, key: string): { Level }
	local out = {}
	for index, row in list do
		local level: any = { Cost = row[2], Shards = row[3] or 0 }
		level[key] = row[1]
		out[index] = level
	end
	return out
end

Home.Stations = {
	-- { stat, cash cost, shards }
	hopper = {
		Id = "hopper",
		Name = "Hopper",
		Levels = levels({
			{ 2e3, 0 },
			{ 8e3, 5e3 },
			{ 32e3, 100e3 },
			{ 128e3, 2e6 },
			{ 512e3, 40e6 },
			{ 2e6, 800e6 },
			{ 8e6, 15e9 },
		}, "Capacity"),
	} :: Station,
	conveyor = {
		Id = "conveyor",
		Name = "Conveyor",
		Levels = levels({
			{ 0.3, 0 },
			{ 0.8, 600 },
			{ 1.6, 4e3 },
			{ 3, 25e3 },
			{ 5, 150e3, 10 },
			{ 8, 1e6, 25 },
			{ 12, 6e6, 60 },
			{ 18, 40e6, 150 },
		}, "Rate"),
	} :: Station,
	refinery = {
		Id = "refinery",
		Name = "Refinery",
		Levels = levels({
			{ 0.25, 0 },
			{ 0.7, 800 },
			{ 1.4, 5e3 },
			{ 2.6, 30e3 },
			{ 4.5, 200e3, 15 },
			{ 7, 1.3e6, 35 },
			{ 11, 8e6, 80 },
			{ 16, 50e6, 200 },
		}, "Rate"),
	} :: Station,
	collector = {
		Id = "collector",
		Name = "Collection Post",
		Levels = levels({
			{ 2e3, 0 },
			{ 8e3, 4e3 },
			{ 32e3, 80e3 },
			{ 128e3, 1.5e6 },
			{ 512e3, 30e6 },
			{ 2e6, 600e6 },
			{ 8e6, 12e9 },
		}, "Capacity"),
	} :: Station,
}

Home.StationOrder = { "hopper", "conveyor", "refinery", "collector" }

-- Offline income (spec §6.4)
Home.OfflineCap = 2 * 3600
Home.OfflineCapPass = 8 * 3600

Home.TickInterval = 1 -- online production tick, seconds

-- Order in which the conveyor pulls ore types from the hopper
Home.OreOrder = { "iron", "frost", "crystal" }

-- Bar sell prices (spec §6.5, §8.1)
Home.BarPrices = {
	iron = 50,
	frost = 1200,
	crystal = 30000,
}

Home.OreNames = {
	iron = "Iron",
	frost = "Frost",
	crystal = "Crystal",
}

return Home
