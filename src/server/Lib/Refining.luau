--!strict
-- Pure production-line simulation, shared by the online tick and the offline
-- catch-up. Ore moves hopper -> conveyor -> refinery -> collection post at the
-- slower of the conveyor and refinery rates, 1 ore -> 1 bar. Output is limited
-- by time, by ore in the hopper and by room in the collection post.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Queue = require(ReplicatedStorage.Shared.RefineryQueue)

local Stations = Config.Home.Stations

export type StationLevels = {
	hopper: number,
	conveyor: number,
	refinery: number,
	collector: number,
}

export type HomeData = {
	stations: StationLevels,
	hopper: { [string]: number }, -- ore waiting
	bin: { [string]: number }, -- bars waiting at the collection post
	progress: number?, -- fractional ore carried between ticks
	refinePriority: { string }?, -- preferred ore types, falling through when empty
}

local Refining = {}

local function level(stationId: string, lvl: number): Config.Level
	local levels = Stations[stationId].Levels
	return levels[math.clamp(lvl, 1, #levels)]
end

function Refining.hopperCapacity(data: HomeData, capacityMult: number?): number
	return (level("hopper", data.stations.hopper).Capacity :: number) * (capacityMult or 1)
end

function Refining.collectorCapacity(data: HomeData, capacityMult: number?): number
	return (level("collector", data.stations.collector).Capacity :: number) * (capacityMult or 1)
end

function Refining.conveyorRate(data: HomeData): number
	return level("conveyor", data.stations.conveyor).Rate :: number
end

function Refining.refineryRate(data: HomeData, speedMult: number?): number
	return (level("refinery", data.stations.refinery).Rate :: number) * (speedMult or 1)
end

-- Bars per second the line can make right now (ignoring stock and room). `lineMult` is the
-- Efficient Line perk (Shared.Perks.lineMult) and scales the whole line.
function Refining.lineRate(data: HomeData, speedMult: number?, lineMult: number?): number
	return math.min(Refining.conveyorRate(data), Refining.refineryRate(data, speedMult)) * (lineMult or 1)
end

local function sum(t: { [string]: number }): number
	local total = 0
	for _, v in t do
		total += v
	end
	return total
end
Refining.sum = sum

-- Takes ore in the saved order, then deterministic defaults, until `budget` line units or
-- `limit` ore are used up. Every ore refines at full speed, so a unit is an ore (what a hit
-- yields by player level is decided when the ore is mined, Shared.Levels.oreYield). Returns the
-- ore taken and the units left.
local function takeOre(hopper: { [string]: number }, limit: number, budget: number, priority: { string }?): ({ [string]: number }, number)
	local taken = {}
	local remaining = limit
	for _, oreType in Queue.order(priority, hopper) do
		if remaining <= 0 or budget < 1 then
			break
		end
		local have = hopper[oreType] or 0
		local n = math.min(have, remaining, math.floor(budget + 1e-9))
		if n > 0 then
			hopper[oreType] = have - n
			taken[oreType] = (taken[oreType] or 0) + n
			remaining -= n
			budget -= n
		end
	end
	for oreType, have in hopper do
		if have <= 0 then
			hopper[oreType] = nil
		end
	end
	return taken, budget
end

-- Why the line isn't running at full speed, for the UI
export type Blocked = "hopper" | "collector" | nil

-- Runs the line for `seconds`. Mutates data. Returns bars made per ore type,
-- the total, and what limited it (empty hopper or full collection post).
function Refining.run(data: HomeData, seconds: number, speedMult: number?, capacityMult: number?, lineMult: number?): ({ [string]: number }, number, Blocked)
	local capacity = Refining.lineRate(data, speedMult, lineMult) * seconds + (data.progress or 0)
	local room = math.max(Refining.collectorCapacity(data, capacityMult) - sum(data.bin), 0)
	local stock = sum(data.hopper)

	local made, left = takeOre(data.hopper, room, capacity, data.refinePriority)
	local n = 0
	for oreType, amount in made do
		data.bin[oreType] = (data.bin[oreType] or 0) + amount
		n += amount
	end

	-- Unused line time because the post is full or the hopper is dry.
	local blocked: Blocked = nil
	if left >= 1 and (room - n <= 0 or sum(data.hopper) <= 0) then
		blocked = if room <= stock then "collector" else "hopper"
	end
	-- An idle or blocked line doesn't bank capacity
	data.progress = if blocked then 0 else left
	return made, n, blocked
end

return Refining
