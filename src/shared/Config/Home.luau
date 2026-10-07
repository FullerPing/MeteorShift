--!strict
-- Home loop tuning (spec §6, reworked): every plot runs one production line
--
--   hopper -> conveyor -> refinery -> collection post
--
-- and each of the four stations upgrades on its own. Ore flows at the slower of
-- the conveyor and the refinery; the hopper caps how much ore waits, the
-- collection post caps how many bars wait to be picked up (and so how much
-- offline income piles up). Conveyor and refinery rates are ore per second and track what a
-- player mines at that stage (docs/balance.md); their prices climb roughly ×3.5 per level.

local Home = {}

export type Level = {
	Cost: number,
	Shards: number, -- kept at 0: shards buy Colony Perks, not production
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
	-- { stat, cash cost }. Shards no longer buy production (economy rework, S1): the
	-- levels 5 to 8 of the conveyor and refinery are gated by player level instead
	-- (Config.Levels.EvolveLevel), and Colony Perks (Config.Perks) are what shards are for.
	hopper = {
		Id = "hopper",
		Name = "Hopper",
		Levels = levels({
			{ 2e3, 0 },
			{ 8e3, 3e3 },
			{ 32e3, 36e3 },
			{ 128e3, 430e3 },
			{ 512e3, 5.2e6 },
			{ 2e6, 62e6 },
			{ 8e6, 690e6 },
		}, "Capacity"),
	} :: Station,
	conveyor = {
		Id = "conveyor",
		Name = "Conveyor",
		Levels = levels({
			{ 0.3, 0 },
			{ 0.8, 360 },
			{ 1.6, 1.4e3 },
			{ 3, 5.4e3 },
			{ 5, 19e3 },
			{ 8, 77e3 },
			{ 12, 275e3 },
			{ 18, 1.1e6 },
		}, "Rate"),
	} :: Station,
	refinery = {
		Id = "refinery",
		Name = "Refinery",
		Levels = levels({
			{ 0.25, 0 },
			{ 0.7, 480 },
			{ 1.4, 1.8e3 },
			{ 2.6, 6.5e3 },
			{ 4.5, 26e3 },
			{ 7, 100e3 },
			{ 11, 370e3 },
			{ 16, 1.4e6 },
		}, "Rate"),
	} :: Station,
	collector = {
		Id = "collector",
		Name = "Collection Post",
		Levels = levels({
			{ 2e3, 0 },
			{ 8e3, 2.4e3 },
			{ 32e3, 29e3 },
			{ 128e3, 324e3 },
			{ 512e3, 3.9e6 },
			{ 2e6, 46e6 },
			{ 8e6, 552e6 },
		}, "Capacity"),
	} :: Station,
}

Home.StationOrder = { "hopper", "conveyor", "refinery", "collector" }

-- Offline income (spec §6.4). Offline Training (Config.Perks) adds up to 2 more hours to the
-- free cap; the pass is the 8-hour step.
Home.OfflineCap = 2 * 3600
Home.OfflineCapPass = 8 * 3600

Home.TickInterval = 1 -- online production tick, seconds

-- Order in which the conveyor pulls ore types from the hopper
Home.OreOrder = { "iron", "frost", "crystal", "alien" }

-- Bar sell prices (spec §6.5, §8.1): 3x steps, the Alien boss ore 4x (economy rework). A
-- meteor's ore is worth about 3x the one below it, so no meteor type is filler for a veteran.
Home.BarPrices = {
	iron = 50,
	frost = 150,
	crystal = 450,
	alien = 1800,
}

Home.OreNames = {
	iron = "Iron",
	frost = "Frost",
	crystal = "Crystal",
	alien = "Alien",
}

return Home
