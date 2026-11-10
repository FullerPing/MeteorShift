--!strict
-- Which spawn pad a new character takes (SpawnService): the free pad nearest the target (the WorldPortal), so
-- everyone lands in the middle by the portal unless someone is already standing there. Pure: flat { x, z } points.
local SpawnPick = {}

export type Point = { x: number, z: number }

local function distance(a: Point, b: Point): number
	return math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
end

-- The index in `pads` to spawn on: the nearest to `target` with no one in `others` within `radius`; if every pad is
-- taken, the nearest one anyway. nil only when there are no pads.
function SpawnPick.choose(pads: { Point }, target: Point, others: { Point }, radius: number): number?
	local order = {}
	for index in pads do table.insert(order, index) end
	table.sort(order, function(a, b) return distance(pads[a], target) < distance(pads[b], target) end)
	for _, index in order do
		local free = true
		for _, other in others do
			if distance(pads[index], other) <= radius then free = false; break end
		end
		if free then return index end
	end
	return order[1]
end

return SpawnPick
