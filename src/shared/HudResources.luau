--!strict
-- Resource rows for the backpack and expanded foundry. Raw ore comes only from
-- the backpack; carried bars share the sale value, separate from stored stock.

local Home = require(script.Parent.Config.Home)

export type OreRow = {
	id: string,
	name: string,
	amount: number,
}

export type BarRow = {
	id: string,
	name: string,
	amount: number,
	value: number,
}

local HudResources = {}

local function nonnegative(value: any): number
	if type(value) ~= "number" or value ~= value or value < 0 or value == math.huge then
		return 0
	end
	return value
end

local function dictionary(value: any): any
	return if type(value) == "table" then value else {}
end

-- Home-shaped configuration is optional so new ore types can be previewed
-- without changing the live config. New configured or carried ids join the
-- OreOrder entries alphabetically; configured empty types keep their rows.
function HudResources.bars(state: any, homeConfig: any?): { BarRow }
	local snapshot = dictionary(state)
	local config = dictionary(homeConfig or Home)
	local inventory = dictionary(snapshot.barInventory)
	local prices = dictionary(config.BarPrices)
	local names = dictionary(config.OreNames)
	local ids: { string } = {}
	local seen: { [string]: boolean } = {}

	local function add(id: any)
		if type(id) == "string" and id ~= "" and not seen[id] then
			seen[id] = true
			table.insert(ids, id)
		end
	end
	for _, id in dictionary(config.OreOrder) do
		add(id)
	end
	local extras: { string } = {}
	for _, source in { prices, names, inventory } do
		for id in source do
			if type(id) == "string" and id ~= "" and not seen[id] then
				seen[id] = true
				table.insert(extras, id)
			end
		end
	end
	table.sort(extras)
	for _, id in extras do
		table.insert(ids, id)
	end

	local rows: { BarRow } = {}
	local weights: { number } = {}
	local baseTotal = 0
	for _, id in ids do
		local amount = nonnegative(inventory[id])
		local name = names[id]
		local weight = nonnegative(amount * nonnegative(prices[id]))
		table.insert(rows, {
			id = id,
			name = if type(name) == "string" and name ~= "" then name else id,
			amount = amount,
			value = 0,
		})
		table.insert(weights, weight)
		baseTotal += weight
	end
	if baseTotal <= 0 or baseTotal == math.huge then
		return rows
	end

	local total = math.floor(if snapshot.barValue == nil then baseTotal else nonnegative(snapshot.barValue))
	local allocated = 0
	local remainders: { { index: number, fraction: number } } = {}
	for index, row in rows do
		if weights[index] > 0 then
			local share = (weights[index] / baseTotal) * total
			row.value = math.floor(share)
			allocated += row.value
			table.insert(remainders, { index = index, fraction = share - row.value })
		end
	end

	-- Largest remainder allocation preserves the integer sale total instead of
	-- independently rounding every type and losing the final dollars. Ties use
	-- display order so the same snapshot always shows the same values.
	table.sort(remainders, function(a, b)
		return if a.fraction == b.fraction then a.index < b.index else a.fraction > b.fraction
	end)
	local remaining = total - allocated
	-- At large integer totals a share can round upward before floor runs.
	-- Undo that excess from the smallest remainders before adding missing dollars.
	if remaining < 0 then
		for index = #remainders, 1, -1 do
			local row = rows[remainders[index].index]
			if row.value > 0 then
				row.value -= 1
				remaining += 1
			end
			if remaining >= 0 then
				break
			end
		end
	end
	for index = 1, math.clamp(remaining, 0, #remainders) do
		rows[remainders[index].index].value += 1
	end
	return rows
end

-- Reuse configured ordering, future type discovery and amount sanitization.
-- The synthetic inventory contains only carried raw ore; sale calculations and
-- other resource stores cannot enter the backpack's name/count-only result.
-- Configured types appear only while the player carries a positive valid count.
function HudResources.ores(state: any, homeConfig: any?): { OreRow }
	local snapshot = dictionary(state)
	local rows: { OreRow } = {}
	for _, row in HudResources.bars({ barInventory = snapshot.backpack, barValue = 0 }, homeConfig) do
		if row.amount > 0 then
			table.insert(rows, { id = row.id, name = row.name, amount = row.amount })
		end
	end
	return rows
end

return HudResources
