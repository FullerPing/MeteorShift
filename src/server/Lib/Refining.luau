--!strict
-- Pure production-line simulation, shared by the online tick and the offline
-- catch-up. Ore moves hopper -> conveyor -> refinery -> collection post at the
-- slower of the conveyor and refinery rates, 1 ore -> 1 bar. Output is limited
-- by time, by ore in the hopper and by room in the collection post.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Queue = require(ReplicatedStorage.Shared.RefineryQueue)
local Levels = require(ReplicatedStorage.Shared.Levels)

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
	level: number?, -- player level: sets each ore's refining speed (Shared.Levels.clearance); nil = full speed
}

local Refining = {}

local function level(stationId: string, lvl: number): Config.Level
	local levels = Stations[stationId].Levels
	return levels[math.clamp(lvl, 1, #levels)]
end

function Refining.hopperCapacity(data: HomeData): number
	return level("hopper", data.stations.hopper).Capacity :: number
end

function Refining.collectorCapacity(data: HomeData): number
	return level("collector", data.stations.collector).Capacity :: number
end

function Refining.conveyorRate(data: HomeData): number
	return level("conveyor", data.stations.conveyor).Rate :: number
end

function Refining.refineryRate(data: HomeData, speedMult: number?): number
	return (level("refinery", data.stations.refinery).Rate :: number) * (speedMult or 1)
end

-- Bars per second the line can make right now (ignoring stock and room)
function Refining.lineRate(data: HomeData, speedMult: number?): number
	return math.min(Refining.conveyorRate(data), Refining.refineryRate(data, speedMult))
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
-- `limit` ore are used up. An ore refined at speed e costs 1/e units (Levels.clearance), so
-- with full speed everywhere a unit is an ore. Returns the ore taken and the units left.
local function takeOre(hopper: { [string]: number }, limit: number, budget: number, priority: { string }?, level: number?): ({ [string]: number }, number)
	local taken = {}
	local remaining = limit
	for _, oreType in Queue.order(priority, hopper) do
		if remaining <= 0 or budget < 1 then
			break
		end
		local have = hopper[oreType] or 0
		local cost = 1 / (if level then Levels.clearance(level, oreType) else 1)
		local n = math.min(have, remaining, math.floor(budget / cost + 1e-9))
		if n > 0 then
			hopper[oreType] = have - n
			taken[oreType] = (taken[oreType] or 0) + n
			remaining -= n
			budget -= n * cost
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
function Refining.run(data: HomeData, seconds: number, speedMult: number?): ({ [string]: number }, number, Blocked)
	local capacity = Refining.lineRate(data, speedMult) * seconds + (data.progress or 0)
	local room = math.max(Refining.collectorCapacity(data) - sum(data.bin), 0)
	local stock = sum(data.hopper)

	local made, left = takeOre(data.hopper, room, capacity, data.refinePriority, data.level)
	local n = 0
	for oreType, amount in made do
		data.bin[oreType] = (data.bin[oreType] or 0) + amount
		n += amount
	end

	-- Unused line time because the post is full or the hopper is dry. Ore that is still
	-- waiting but costs more than what is left (a slow ore) keeps its progress banked.
	local blocked: Blocked = nil
	if left >= 1 and (room - n <= 0 or sum(data.hopper) <= 0) then
		blocked = if room <= stock then "collector" else "hopper"
	end
	-- An idle or blocked line doesn't bank capacity
	data.progress = if blocked then 0 else left
	return made, n, blocked
end

return Refining
