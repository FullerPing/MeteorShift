--!strict
-- Home loop tuning (spec §6, reworked): every plot runs one production line
--
--   hopper -> conveyor -> refinery -> collection post
--
-- and the whole line upgrades as one: a line level (Home.Line, Shared.Line) sets every station's
-- row below. Ore flows at the slower of the conveyor and the refinery; the hopper caps how much
-- ore waits, the collection post caps how many bars wait to be picked up (and so how much
-- offline income piles up). Conveyor and refinery rates are ore per second and track what a
-- player mines at that stage (docs/guide/balance.md). Hopper and collection post capacity run
-- 2,000 to 1,250,000 (about ×2.5 per level). Level 1 holds two hours of the first line and any
-- backpack; level 7 already holds the 8-hour pass at the fastest line.

local Home = {}

export type Level = {
	Capacity: number?, -- hopper (ore), collector (bars)
	Rate: number?, -- conveyor and refinery (ore per second)
}

export type Station = {
	Id: string,
	Name: string,
	Levels: { Level },
}

local function levels(list: { number }, key: string): { Level }
	local out = {}
	for index, value in list do
		out[index] = { [key] = value } :: any
	end
	return out
end

-- The one production upgrade. Costs[n] is the cash to raise the line to level n (times the
-- rebirth price inflation, Shared.Rebirth.priceMult); level n also needs player level
-- Config.Levels.EvolveLevel[n] (levels 5 to 8). A level costs what the conveyor and refinery
-- levels used to cost together, since those two set the line's speed; the hopper and collection
-- post capacity come with it. Shards buy Colony Perks (Config.Perks), not production.
Home.Line = {
	Name = "Production Line",
	Costs = { 0, 840, 3.2e3, 11.9e3, 45e3, 177e3, 645e3, 2.5e6 },
}

-- What each station does at each line level (index = line level)
Home.Stations = {
	hopper = {
		Id = "hopper",
		Name = "Hopper",
		Levels = levels({ 2e3, 5e3, 12e3, 30e3, 75e3, 190e3, 500e3, 1.25e6 }, "Capacity"),
	} :: Station,
	conveyor = {
		Id = "conveyor",
		Name = "Conveyor",
		Levels = levels({ 0.3, 0.8, 1.6, 3, 5, 8, 12, 18 }, "Rate"),
	} :: Station,
	refinery = {
		Id = "refinery",
		Name = "Refinery",
		Levels = levels({ 0.25, 0.7, 1.4, 2.6, 4.5, 7, 11, 16 }, "Rate"),
	} :: Station,
	collector = {
		Id = "collector",
		Name = "Collection Post",
		Levels = levels({ 2e3, 5e3, 12e3, 30e3, 75e3, 190e3, 500e3, 1.25e6 }, "Capacity"),
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
