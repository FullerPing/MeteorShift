--!strict
-- The force-field walls round a locked ore field block (tools/map-v3/Fields), in the block floor's frame: x across, z
-- along, the wall line `hx` x `hz` from the centre. One side holds the gate: a GAP-wide opening centred `at` along that
-- side, with two short walls running out to the barrier `out` studs from the centre. Walls are 1 thick on their line;
-- the side opposite the gate runs over the corners and the two beside it stop at their inner faces, so no two walls
-- overlap (overlapping faces flicker).
local FieldWalls = {}

FieldWalls.HALF_GAP = 12.5 -- half a stud past each end of the 24-stud barrier

export type Segment = { x0: number, z0: number, x1: number, z1: number, grow: number }

-- `side` is the gate's side: "x+", "x-", "z+" or "z-"
function FieldWalls.segments(hx: number, hz: number, side: string, at: number, out: number): { Segment }
	local axis, sign = side:sub(1, 1), if side:sub(2, 2) == "-" then -1 else 1
	-- work with the gate side as +d (depth) and s across it, then map back
	local A, D = if axis == "x" then hz else hx, if axis == "x" then hx else hz
	assert(math.abs(at) + FieldWalls.HALF_GAP < A, "the gate's opening runs past the block's corner")
	assert(out > D, "the barrier is not outside the walls")
	local g = FieldWalls.HALF_GAP
	local list: { Segment } = {}
	local function wall(s0: number, d0: number, s1: number, d1: number, grow: number)
		d0, d1 = d0 * sign, d1 * sign
		if axis == "x" then
			table.insert(list, { x0 = d0, z0 = s0, x1 = d1, z1 = s1, grow = grow })
		else
			table.insert(list, { x0 = s0, z0 = d0, x1 = s1, z1 = d1, grow = grow })
		end
	end
	wall(-A, -D, A, -D, 1) -- the far side
	wall(-A, -D, -A, D, -1)
	wall(A, -D, A, D, -1)
	wall(-A - .5, D, at - g, D, 0) -- the gate side, open in front of the gate
	wall(at + g, D, A + .5, D, 0)
	wall(at - g, D + .5, at - g, out - .5, 0) -- out to the barrier's ends
	wall(at + g, D + .5, at + g, out - .5, 0)
	return list
end

return FieldWalls
