--!strict
-- The production line's single level (Config.Home.Line). One upgrade raises the hopper, conveyor,
-- refinery and collection post together; each station's stats at a line level are its row in
-- Config.Home.Stations. Pure functions over the saved level, covered by tests/Line.spec; the
-- server (UpgradeService, Lib.Refining, Lib.RebirthReset), the refinery menu and Shared.Pacing
-- all read them.
--
--   max()                       the top line level
--   clean(saved)                a saved level made legal (1 to max)
--   station(id, level)          a station's Config.Home.Stations row at a line level
--   cost(level, priceMult?)     cash to reach `level` from the one below, nil past the top
--   levelNeeded(level)          player level that line level needs (Config.Levels.EvolveLevel)
--   rebirthsNeeded(level)       rebirths that line level needs (Config.Levels.EvolveRebirths)
--   plan(level, wanted, cash, playerLevel, priceMult?, rebirths?)
--                               how many of the next `wanted` levels the wallet, the player
--                               level and the rebirths allow, their total price, and why it stopped
--   fromStations(stations)      a pre-v11 profile's four station levels as one line level

local Config = require(script.Parent.Config)
local Levels = require(script.Parent.Levels)
local Price = require(script.Parent.Price)

local Line = {}

local Costs = Config.Home.Line.Costs

function Line.max(): number
	return #Costs
end

function Line.clean(saved: any): number
	local value = if type(saved) == "number" and saved == saved and math.abs(saved) < math.huge then saved else 1
	return math.clamp(math.floor(value), 1, Line.max())
end

function Line.station(id: string, level: number): Config.Level
	local levels = Config.Home.Stations[id].Levels
	return levels[math.clamp(level, 1, #levels)]
end

function Line.cost(level: number, priceMult: number?): number?
	local base = Costs[level]
	if level < 2 or not base then
		return nil
	end
	return Price.scaled(base, priceMult or 1)
end

function Line.levelNeeded(level: number): number
	return Levels.evolveLevel(level)
end

function Line.rebirthsNeeded(level: number): number
	return Levels.evolveRebirths(level)
end

export type Stop = "max" | "level" | "rebirth" | "cash" | nil

-- Buys up the line one level at a time from `level`, at most `wanted` levels. Returns the count
-- the cash and the player level cover, their total price, and what stopped it ("max" at the top,
-- "level" at a player-level gate, "rebirth" at a rebirth gate, "cash" when the next one is out of reach,
-- nil when `wanted` ran out).
function Line.plan(level: number, wanted: number, cash: number, playerLevel: number, priceMult: number?, rebirths: number?): (number, number, Stop)
	local count, total = 0, 0
	while count < wanted do
		local target = level + count + 1
		local price = Line.cost(target, priceMult)
		if not price then
			return count, total, "max"
		end
		if playerLevel < Line.levelNeeded(target) then
			return count, total, "level"
		end
		if (rebirths or 0) < Line.rebirthsNeeded(target) then
			return count, total, "rebirth"
		end
		if total + price > cash then
			return count, total, "cash"
		end
		count, total = count + 1, total + price
	end
	return count, total, nil
end

-- The v11 migration: the best of the four old station levels, so no one loses a level they paid for.
function Line.fromStations(stations: any): number
	local best = 1
	if type(stations) == "table" then
		for _, id in Config.Home.StationOrder do
			local value = stations[id]
			if type(value) == "number" and value == value then
				best = math.max(best, value)
			end
		end
	end
	return Line.clean(best)
end

return Line
