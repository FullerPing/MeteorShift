--!strict
-- Placement rules for the crater-floor scenes of SurfaceFXController: spokes (cracks, tendrils) that
-- run between two radii, and hovering rocks. Pure and seeded by the event id, so every client lays
-- out the same scene; the controller turns the polar results into world positions on the ground.
local SurfaceLayout = {}

export type Spoke = { angle: number, from: number, to: number, bend: number }
export type Rock = { angle: number, radius: number, height: number, size: number, period: number, phase: number }

-- A small seeded generator (a 31-bit LCG): same seed, same sequence, on every client
function SurfaceLayout.rng(seed: number): () -> number
	local state = (math.floor(math.abs(seed)) * 2654435761 + 12345) % 2147483647
	if state == 0 then state = 1 end
	return function(): number
		state = (state * 48271) % 2147483647
		return state / 2147483647
	end
end

local function between(random: () -> number, pair: { number }): number
	return pair[1] + (pair[2] - pair[1]) * random()
end

-- `count` spokes spread evenly round the circle with some jitter, each running from radius `from` to
-- `to` and bending sideways by up to `bend` studs.
function SurfaceLayout.spokes(seed: number, count: number, from: number, to: number, bend: number): { Spoke }
	local random = SurfaceLayout.rng(seed)
	local offset = random() * math.pi * 2
	local step = math.pi * 2 / math.max(count, 1)
	local list: { Spoke } = {}
	for index = 1, count do
		table.insert(list, {
			angle = offset + (index - 1) * step + (random() - 0.5) * step * 0.5,
			from = from + (random() - 0.5) * 4,
			to = to + (random() - 0.5) * 6,
			bend = (random() - 0.5) * 2 * bend,
		})
	end
	return list
end

-- The polar points of a spoke, from its outer end inward (`steps` segments, `steps + 1` points). The
-- bend peaks mid-way and the ends stay on the spoke's own angle.
function SurfaceLayout.points(spoke: Spoke, steps: number): { { angle: number, radius: number } }
	local points = {}
	for step = 0, steps do
		local t = step / steps
		local radius = spoke.from + (spoke.to - spoke.from) * t
		local sideways = math.sin(t * math.pi) * spoke.bend
		table.insert(points, { angle = spoke.angle + sideways / math.max(radius, 1), radius = radius })
	end
	return points
end

-- Hovering rocks round the crater: angle, distance, height above the floor, size, bob period and phase.
function SurfaceLayout.rocks(seed: number, count: number, radius: { number }, height: { number }, size: { number }, period: { number }): { Rock }
	local random = SurfaceLayout.rng(seed + 7919)
	local list: { Rock } = {}
	local step = math.pi * 2 / math.max(count, 1)
	for index = 1, count do
		table.insert(list, {
			angle = (index - 1) * step + (random() - 0.5) * step * 0.6,
			radius = between(random, radius),
			height = between(random, height),
			size = between(random, size),
			period = between(random, period),
			phase = random() * math.pi * 2,
		})
	end
	return list
end

return SurfaceLayout
