--!strict
-- Home loop tuning (spec §6, reworked): every plot runs one production line
--
--   hopper -> conveyor -> refinery -> collection post
--
-- and the whole line upgrades as one: a line level (Home.Line, Shared.Line) sets every station's
-- row below. Ore flows at the slower of the conveyor and the refinery; the hopper caps how much
-- ore waits, the collection post caps how many bars wait to be picked up (and so how much
-- offline income piles up). Conveyor and refinery rates are ore per second and track what a
-- player mines at that stage (docs/guide/balance.md). Hopper and collection post capacity hold about
-- two hours of that level's refinery (2,000 to 1.7M); the old ×2.5 per level reached 1.9 billion, weeks of refining.
-- Ore or bars stored above a lowered cap are kept: a full hopper only refuses new deposits.

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
-- rebirth price inflation, Shared.Rebirth.priceMult); level n also needs what gear tier n needs
-- (Config.Levels: a player level for 5 and 6, a rebirth count from 7). A level costs what the conveyor and refinery
-- levels used to cost together, since those two set the line's speed; the hopper and collection
-- post capacity come with it. Shards buy Colony Perks (Config.Perks), not production.
Home.Line = {
	Name = "Production Line",
	Costs = { 0, 2.8e3, 8.5e3, 24e3, 222e3, 1.71e6, 12.3e6, 173e6, 1.09e9, 6.33e9, 35.6e9, 208e9, 1.16e12, 6.2e12, 32e12, 174e12 },
}

-- What each station does at each line level (index = line level)
Home.Stations = {
	hopper = {
		Id = "hopper",
		Name = "Hopper",
		Levels = levels({ 2e3, 5e3, 10e3, 21.1e3, 39.1e3, 66.7e3, 114e3, 187e3, 267e3, 409e3, 604e3, 900e3, 1.24e6, 1.72e6, 2.4e6, 3.4e6 }, "Capacity"),
	} :: Station,
	conveyor = {
		Id = "conveyor",
		Name = "Conveyor",
		Levels = levels({ 0.3, 0.8, 1.78, 3.67, 6.67, 11.56, 18.67, 30, 44.44, 66.11, 98, 136, 190, 266, 372, 520 }, "Rate"),
	} :: Station,
	refinery = {
		Id = "refinery",
		Name = "Refinery",
		Levels = levels({ 0.25, 0.7, 1.56, 3.18, 6, 10.11, 17.11, 26.67, 40, 59.5, 88, 124, 172, 240, 336, 470 }, "Rate"),
	} :: Station,
	collector = {
		Id = "collector",
		Name = "Collection Post",
		Levels = levels({ 2e3, 5e3, 10e3, 21.1e3, 39.1e3, 66.7e3, 114e3, 187e3, 267e3, 409e3, 604e3, 900e3, 1.24e6, 1.72e6, 2.4e6, 3.4e6 }, "Capacity"),
	} :: Station,
}

Home.StationOrder = { "hopper", "conveyor", "refinery", "collector" }

-- Offline income (spec §6.4). Offline Training (Config.Perks) adds up to 2 more hours to the
-- free cap; the pass is the 8-hour step.
Home.OfflineCap = 2 * 3600
Home.OfflineCapPass = 8 * 3600
-- The line only refines what was left in the hopper, which is next to nothing when a player logs out after
-- depositing, so the colony crew also earns cash while you're away: OfflineCrewShare of your expected income
-- (Shared.Pacing.expectedIncome, passes but no timed boosts) for the capped time away, at most
-- OfflineCeilingShare of the next rebirth's cost so time away never buys a rebirth outright.
Home.OfflineCrewShare = 0.25
Home.OfflineCeilingShare = 0.5
-- The crew and the Welcome Back roll need this long away, so a rejoin or a server hop earns nothing extra
Home.OfflineMinAway = 15 * 60

Home.TickInterval = 1 -- online production tick, seconds

-- Order in which the conveyor pulls ore types from the hopper
Home.OreOrder = { "iron", "frost", "crystal", "alien", "quartz", "nebula", "solar", "eclipse" }

-- Bar sell prices (spec §6.5, §8.1): 3x steps, the Alien boss ore 4x (economy rework). A
-- meteor's ore is worth about 3x the one below it, so no meteor type is filler for a veteran.
Home.BarPrices = {
	iron = 50,
	frost = 150,
	crystal = 450,
	alien = 1800,
	quartz = 900, -- the hourly meteor's ore, open to everyone (Config.Meteor.Hourly)
	-- Nebula Rift's ores: 3x iron, frost and crystal (Config.Meteor.WorldTypeOrder)
	nebula = 150,
	solar = 450,
	eclipse = 1350,
}

Home.OreNames = {
	iron = "Iron",
	frost = "Frost",
	crystal = "Crystal",
	alien = "Alien",
	quartz = "Quartz",
	nebula = "Nebulite",
	solar = "Solarite",
	eclipse = "Eclipse",
}

return Home
