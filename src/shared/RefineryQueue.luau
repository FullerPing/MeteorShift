--!strict
-- Saved refinery preference, request validation, and live station contents.
-- Empty or depleted choices fall through; unknown saved stock is never lost.

local Home = require(script.Parent.Config.Home)

export type Row = {
	id: string,
	name: string,
	ore: number,
	bars: number,
}

local Queue = {}

local function dictionary(value: any): any
	return if type(value) == "table" then value else {}
end

local function positive(value: any): number
	return if type(value) == "number" and value == value and value > 0 and value < math.huge then value else 0
end

local function validId(id: any): boolean
	return type(id) == "string" and id ~= ""
end

local function configured(): { [string]: boolean }
	local known: { [string]: boolean } = {}
	for _, id in Home.OreOrder do
		if validId(id) then known[id] = true end
	end
	for _, source in { Home.OreNames, Home.BarPrices } do
		for id in source do
			if validId(id) then known[id] = true end
		end
	end
	return known
end

-- Saved data may predate new ore types or contain malformed preferences. Keep
-- valid configured preferences, then the default order, then stable extras.
function Queue.order(priority: any, stock: any?): { string }
	local known = configured()
	local ordered: { string } = {}
	local seen: { [string]: boolean } = {}
	local function add(id: any)
		if validId(id) and not seen[id] then
			seen[id] = true
			table.insert(ordered, id)
		end
	end
	for _, id in ipairs(dictionary(priority)) do
		if known[id] then add(id) end
	end
	for _, id in Home.OreOrder do add(id) end
	local extras: { string } = {}
	for id in known do
		if not seen[id] then
			seen[id] = true
			table.insert(extras, id)
		end
	end
	for id, amount in dictionary(stock) do
		if validId(id) and positive(amount) > 0 and not seen[id] then
			seen[id] = true
			table.insert(extras, id)
		end
	end
	table.sort(extras)
	for _, id in extras do table.insert(ordered, id) end
	return ordered
end

-- Remote requests must be a bounded dense array of unique configured IDs.
-- A partial array promotes those choices; an empty array restores defaults.
function Queue.validate(priority: any): { string }?
	if type(priority) ~= "table" then return nil end
	local known = configured()
	local limit = 0
	for _ in known do limit += 1 end
	local count = 0
	local seen: { [string]: boolean } = {}
	for index, id in priority do
		if type(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > limit then return nil end
		if not validId(id) or not known[id] or seen[id] then return nil end
		seen[id] = true
		count += 1
	end
	for index = 1, count do
		if priority[index] == nil then return nil end
	end
	return Queue.order(priority)
end

-- Contents describe actual waiting ore and collection-post bars. Empty types
-- stay hidden, and the rows cannot mutate either saved inventory dictionary.
function Queue.rows(hopper: any, bin: any, priority: any): { Row }
	local ore = dictionary(hopper)
	local bars = dictionary(bin)
	local stock: { [string]: number } = {}
	for _, source in { ore, bars } do
		for id, amount in source do
			if validId(id) and positive(amount) > 0 then stock[id] = 1 end
		end
	end
	local rows: { Row } = {}
	for _, id in Queue.order(priority, stock) do
		local oreAmount, barAmount = positive(ore[id]), positive(bars[id])
		if oreAmount > 0 or barAmount > 0 then
			local name = Home.OreNames[id]
			table.insert(rows, {
				id = id,
				name = if validId(name) then name else id,
				ore = oreAmount,
				bars = barAmount,
			})
		end
	end
	return rows
end

function Queue.nextOre(hopper: any, priority: any): string?
	local stock = dictionary(hopper)
	for _, id in Queue.order(priority, stock) do
		if positive(stock[id]) > 0 then return id end
	end
	return nil
end

return Queue
