--!strict
-- Pure refinery simulation, shared by the online tick and the offline catch-up
-- (spec §6.3, §6.4). Refineries pull ore from the hopper, 1 ore -> 1 bar, into
-- their own output bin. Output is limited by both time and ore in the hopper.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

export type Refinery = {
	level: number,
	progress: number?, -- fractional ore of capacity carried between ticks
	bin: { [string]: number },
}

export type HomeData = {
	hopper: { [string]: number },
	refineries: { Refinery },
}

local Refining = {}

function Refining.throughput(refinery: Refinery, speedMult: number?): number
	local level = Config.Home.Refineries[refinery.level] or Config.Home.Refineries[1]
	return level.Throughput * (speedMult or 1)
end

function Refining.totalThroughput(data: HomeData, speedMult: number?): number
	local total = 0
	for _, refinery in data.refineries do
		total += Refining.throughput(refinery, speedMult)
	end
	return total
end

function Refining.hopperTotal(data: HomeData): number
	local total = 0
	for _, amount in data.hopper do
		total += amount
	end
	return total
end

-- Takes up to `amount` ore out of the hopper, in Config.Home.OreOrder.
local function takeOre(hopper: { [string]: number }, amount: number): { [string]: number }
	local taken = {}
	local remaining = amount
	for _, oreType in Config.Home.OreOrder do
		if remaining <= 0 then
			break
		end
		local have = hopper[oreType] or 0
		local n = math.min(have, remaining)
		if n > 0 then
			hopper[oreType] = have - n
			taken[oreType] = n
			remaining -= n
		end
	end
	-- Any ore type not listed in OreOrder still gets processed
	for oreType, have in hopper do
		if remaining <= 0 then
			break
		end
		if not taken[oreType] and have > 0 and not table.find(Config.Home.OreOrder, oreType) then
			local n = math.min(have, remaining)
			hopper[oreType] = have - n
			taken[oreType] = n
			remaining -= n
		end
	end
	return taken
end

-- Runs every refinery for `seconds`. Mutates data. Returns bars made per ore type
-- and the total.
function Refining.run(data: HomeData, seconds: number, speedMult: number?): ({ [string]: number }, number)
	local made: { [string]: number } = {}
	local total = 0
	for _, refinery in data.refineries do
		local capacity = Refining.throughput(refinery, speedMult) * seconds + (refinery.progress or 0)
		local wanted = math.floor(capacity)
		local taken = takeOre(data.hopper, wanted)
		local got = 0
		for oreType, n in taken do
			refinery.bin[oreType] = (refinery.bin[oreType] or 0) + n
			made[oreType] = (made[oreType] or 0) + n
			got += n
		end
		total += got
		-- Carry the fraction forward only while there's ore to work on; an idle
		-- refinery doesn't bank capacity.
		refinery.progress = if got == wanted then capacity - wanted else 0
	end
	return made, total
end

return Refining
