--!strict
-- Ice and Crystal landing effects, tuned in Config.LandingFX:
--
--   clock     which stage the effects are in and how far along, worked out from the
--             meteor State alone, so a late joiner lands on the same moment as everyone
--   layout    where every cluster, line, finger and sprout goes and when it moves,
--             seeded by the event so every client builds the same scene
--   rules     sprouts per broken crust node, arc charge, and which nodes show rime
--   geometry  the poses LandingFXController tweens between
--
-- Pure functions, covered by tests/LandingFX.spec; LandingFXController owns the
-- parts. Layout XZ values are offsets from the crater centre; angles are degrees,
-- bearing = atan2(z, x).

local Tuning = require(script.Parent.Config.LandingFX)
local MeteorConfig = require(script.Parent.Config.Meteor)

export type Stage = "None" | "Grow" | "Shatter" | "Wither" | "Gone"
export type Clock = { stage: Stage, t: number }
export type Corridor = { Angle: number, Half: number }
-- (ux, uz) is the unit XZ of the box's RightVector
export type Obstacle =
	{ kind: "circle", cx: number, cz: number, r: number }
	| { kind: "box", cx: number, cz: number, hx: number, hz: number, ux: number, uz: number }
export type Piece = { cf: CFrame, size: Vector3 }
export type Prism = { body: Piece, tip: Piece, spine: Piece?, top: Vector3 }

-- Every upright piece erupts at `start` over `rise` seconds, from `depth` studs down its own axis
export type Satellite = {
	x: number,
	z: number,
	height: number,
	width: number,
	thickness: number,
	lean: number,
	yaw: number,
	start: number,
	rise: number,
	depth: number,
}
export type Cluster = {
	rank: number,
	angle: number,
	radius: number,
	x: number,
	z: number,
	height: number,
	width: number,
	thickness: number,
	lean: number,
	yaw: number,
	start: number,
	rise: number,
	depth: number,
	satellites: { Satellite },
}
-- A strip polyline drawn outward: segment k runs points[k] to points[k + 1], growing
-- from starts[k] over seconds[k]; flow lists the segments that carry a flow beam
export type Line = {
	points: { Vector2 },
	starts: { number },
	seconds: { number },
	widths: { number },
	flow: { number },
}
export type Finger = { angle: number, length: number, width: number, start: number }
export type Sprout = {
	angle: number,
	radius: number,
	x: number,
	z: number,
	height: number,
	width: number,
	lean: number,
	yaw: number,
	depth: number,
}
export type Arc = { i: number, j: number, start: number, seconds: number }
export type Crown = { i: number, start: number, seconds: number }
-- Lists that don't belong to the type are empty. cracks, spokes and rays line up with clusters.
export type Layout = {
	typeId: string,
	clusters: { Cluster },
	cracks: { Line },
	fingers: { Finger },
	spokes: { Line },
	circle: { Line },
	rays: { Line },
	sprouts: { Sprout },
	arcs: { Arc },
	crowns: { Crown },
}
export type RimeCandidate = { id: any, fraction: number, lastRiseAt: number? }

type Slot = { angle: number, radius: number, x: number, z: number }

local LandingFX = {}

-- Turns a cube onto its corner: its (1, 1, 1) diagonal points straight up
LandingFX.TIP_ROTATION = CFrame.Angles(-math.atan(1 / math.sqrt(2)), 0, math.pi / 4)

-- Effect parts must never block the mining raycast, the player or the light
LandingFX.PART_FLAGS = {
	Anchored = true,
	CanCollide = false,
	CanQuery = false,
	CanTouch = false,
	CastShadow = false,
}

local RANK_FROM = 90 -- ranks run counter-clockwise from the side opposite the town
local BURY_MARGIN = 1 -- a buried piece sits this far deeper, so no edge pokes through
local SEED_SALT: { [string]: number } = { Ice = 1, Crystal = 2 }

local function toXZ(angle: number, radius: number): (number, number)
	local rad = math.rad(angle)
	return radius * math.cos(rad), radius * math.sin(rad)
end

local function angularGap(a: number, b: number): number
	return math.abs((a - b + 180) % 360 - 180)
end

local function rankKey(angle: number): number
	return (angle - RANK_FROM) % 360
end

local function between(rng: Random, range: { number }): number
	return rng:NextNumber(range[1], range[2])
end

-- How far a cube tip of side tipScale * width reaches above its centre (half its diagonal)
local function tipHeight(width: number, tipScale: number): number
	return tipScale * width * math.sqrt(3) / 2
end

-- Type and timing ----------------------------------------------------------

function LandingFX.style(typeId: string?): string?
	if typeId and (Tuning.Types :: any)[typeId] then
		return typeId
	end
	return nil
end

function LandingFX.seed(eventId: number, typeId: string): number
	return eventId * 7919 + (SEED_SALT[typeId] or 0)
end

-- phase: the meteor phase; secondsLeft / phaseLength: time left in it and its full
-- length (nil: the configured length). Grow's t counts from impact through Active.
function LandingFX.clock(
	phase: string?,
	secondsLeft: number,
	phaseLength: number?,
	typeId: string?,
	_tuning: any?
): Clock
	local function elapsed(length: number): number
		length = math.max(length, 0)
		return math.clamp(length - secondsLeft, 0, length)
	end
	if phase == "Impact" then
		return { stage = "Grow", t = elapsed(phaseLength or MeteorConfig.ImpactDuration) }
	elseif phase == "Active" then
		local meteorType = if typeId then MeteorConfig.Types[typeId] else nil
		local length = phaseLength or (if meteorType then meteorType.ActiveDuration else 0)
		return { stage = "Grow", t = MeteorConfig.ImpactDuration + elapsed(length) }
	elseif phase == "CoreCracked" then
		return { stage = "Shatter", t = elapsed(phaseLength or MeteorConfig.CrackedDuration) }
	elseif phase == "Cooled" then
		return { stage = "Wither", t = elapsed(phaseLength or MeteorConfig.CooledDuration) }
	elseif phase == "Cleanup" then
		return { stage = "Gone", t = 0 }
	end
	return { stage = "None", t = 0 }
end

-- A one-shot tween joined at t: snap to its end once it is over, otherwise play it
-- after `wait` seconds (0 while it is already running, so the joiner sees all of it)
function LandingFX.schedule(start: number, seconds: number, t: number): (boolean, number)
	if t >= start + seconds then
		return true, 0
	end
	return false, math.max(0, start - t)
end

function LandingFX.linearAlpha(start: number, seconds: number, t: number): number
	if seconds <= 0 then
		return if t >= start then 1 else 0
	end
	return math.clamp((t - start) / seconds, 0, 1)
end

-- The radius an easing-out line front has reached at t
function LandingFX.front(t: number, delay: number, seconds: number, r0: number, r1: number): number
	local u = LandingFX.linearAlpha(delay, seconds, t)
	if u >= 1 then
		return r1
	end
	return r0 + (r1 - r0) * (1 - (1 - u) ^ 2)
end

-- When that front reaches radius r (the inverse of front)
function LandingFX.reach(r: number, delay: number, seconds: number, r0: number, r1: number): number
	if r <= r0 then
		return delay
	elseif r > r1 then
		return math.huge
	end
	local p = (r - r0) / (r1 - r0)
	return delay + seconds * (1 - math.sqrt(math.max(0, 1 - p)))
end

-- The slow linear stage after a burst: frost creep and crystal growth
function LandingFX.creep(t: number, burstEnd: number, burstTo: number, endT: number): number
	return burstTo + (1 - burstTo) * LandingFX.linearAlpha(burstEnd, endT - burstEnd, t)
end

-- Bearings, obstacles and layout -------------------------------------------

function LandingFX.inCorridor(angle: number, corridors: { Corridor }): boolean
	for _, corridor in corridors do
		if angularGap(angle, corridor.Angle) < corridor.Half then
			return true
		end
	end
	return false
end

-- `count` bearings spaced evenly along the free arc (the circle minus the corridors),
-- the first offset01 of one slot in from bearing 0
function LandingFX.spread(count: number, corridors: { Corridor }, offset01: number): { number }
	local bearings = {}
	if count <= 0 then
		return bearings
	end
	local covered: { { number } } = {}
	for _, corridor in corridors do
		local half = corridor.Half
		if half >= 180 then
			return bearings
		elseif half > 0 then
			local from = (corridor.Angle - half) % 360
			local to = from + 2 * half
			if to > 360 then
				table.insert(covered, { from, 360 })
				table.insert(covered, { 0, to - 360 })
			else
				table.insert(covered, { from, to })
			end
		end
	end
	table.sort(covered, function(a, b)
		return a[1] < b[1]
	end)

	local free: { { from: number, length: number } } = {}
	local cursor = 0
	for _, span in covered do
		if span[1] > cursor then
			table.insert(free, { from = cursor, length = span[1] - cursor })
		end
		cursor = math.max(cursor, span[2])
	end
	if cursor < 360 then
		table.insert(free, { from = cursor, length = 360 - cursor })
	end
	local total = 0
	for _, arc in free do
		total += arc.length
	end
	if total <= 0 then
		return bearings
	end

	local step = total / count
	for k = 1, count do
		local along = (k - 1 + offset01) * step
		local last = free[#free]
		local bearing = last.from + last.length
		for _, arc in free do
			if along < arc.length then
				bearing = arc.from + along
				break
			end
			along -= arc.length
		end
		table.insert(bearings, bearing % 360)
	end
	return bearings
end

function LandingFX.blocked(x: number, z: number, obstacles: { Obstacle }?, pad: number): boolean
	if not obstacles then
		return false
	end
	for _, obstacle in obstacles do
		local dx, dz = x - obstacle.cx, z - obstacle.cz
		if obstacle.kind == "circle" then
			local reach = obstacle.r + pad
			if dx * dx + dz * dz <= reach * reach then
				return true
			end
		else
			local lx = dx * obstacle.ux + dz * obstacle.uz
			local lz = -dx * obstacle.uz + dz * obstacle.ux
			if math.abs(lx) <= obstacle.hx + pad and math.abs(lz) <= obstacle.hz + pad then
				return true
			end
		end
	end
	return false
end

local function spaced(placed: { Slot }, x: number, z: number, spacing: number): boolean
	for _, other in placed do
		local dx, dz = other.x - x, other.z - z
		if dx * dx + dz * dz < spacing * spacing then
			return false
		end
	end
	return true
end

-- The first spot near `bearing` (each retry offset, then each radius) that is out of
-- the corridors, clear of the obstacles and MinSpacing from everything placed
local function place(
	bearing: number,
	radii: { number },
	pad: number,
	spacing: number,
	placed: { Slot },
	obstacles: { Obstacle }?,
	config: any
): Slot?
	for _, offset in config.Obstacles.RetryDegrees do
		local angle = (bearing + offset) % 360
		if LandingFX.inCorridor(angle, config.Corridors) then
			continue
		end
		for _, radius in radii do
			local x, z = toXZ(angle, radius)
			if not LandingFX.blocked(x, z, obstacles, pad) and spaced(placed, x, z, spacing) then
				return { angle = angle, radius = radius, x = x, z = z }
			end
		end
	end
	return nil
end

local function placeAll(
	count: number,
	radiiFor: (number) -> { number },
	pad: number,
	spacing: number,
	placed: { Slot },
	obstacles: { Obstacle }?,
	rng: Random,
	config: any
): { Slot }
	local slots: { Slot } = {}
	for k, bearing in LandingFX.spread(count, config.Corridors, rng:NextNumber()) do
		local slot = place(bearing, radiiFor(k), pad, spacing, placed, obstacles, config)
		if slot then
			table.insert(slots, slot)
			table.insert(placed, slot)
		end
	end
	table.sort(slots, function(a, b)
		return rankKey(a.angle) < rankKey(b.angle)
	end)
	return slots
end

-- One line out along `angle` with vertices at `radii` (turned by kinks[v] degrees), drawn
-- by a front that eases out from the first radius to the last over delay..delay+seconds
local function line(
	angle: number,
	radii: { number },
	kinks: { number }?,
	delay: number,
	seconds: number,
	widths: { number },
	flow: { number }
): Line
	local first, last = radii[1], radii[#radii]
	local points, starts, durations = {}, {}, {}
	for v, radius in radii do
		local x, z = toXZ(angle + (if kinks then kinks[v] else 0), radius)
		points[v] = Vector2.new(x, z)
	end
	for k = 1, #radii - 1 do
		local from = LandingFX.reach(radii[k], delay, seconds, first, last)
		starts[k] = from
		durations[k] = LandingFX.reach(radii[k + 1], delay, seconds, first, last) - from
	end
	return { points = points, starts = starts, seconds = durations, widths = widths, flow = flow }
end

-- A satellite's base: `out` studs further out and `across` studs counter-clockwise
local function beside(slot: Slot, out: number, across: number): (number, number)
	local rad = math.rad(slot.angle)
	local ox, oz = math.cos(rad), math.sin(rad)
	return slot.x + ox * out - oz * across, slot.z + oz * out + ox * across
end

local function iceLayout(layout: Layout, slots: { Slot }, rng: Random, fx: any, keep: number, flowOn: boolean)
	local spec, cracks, fingers = fx.Clusters, fx.Cracks, fx.Fingers
	for rank, slot in slots do
		-- The crack runs through the cluster's base, so the spike erupts as the frost arrives
		local radii = table.clone(cracks.Radii)
		table.insert(radii, slot.radius)
		local baseVertex = #radii
		for _, beyond in cracks.Beyond do
			table.insert(radii, slot.radius + beyond)
		end
		local kinks = {}
		local sign = if rng:NextInteger(0, 1) == 0 then 1 else -1
		for v = 1, #radii do
			kinks[v] = if v == 1 or v == baseVertex then 0 else sign * between(rng, cracks.Kink)
			sign = -sign
		end
		local segments = #radii - 1
		local widths = {}
		for k = 1, segments do
			local alpha = if segments > 1 then (k - 1) / (segments - 1) else 0
			widths[k] = cracks.Width[1] + (cracks.Width[2] - cracks.Width[1]) * alpha
		end
		local flow = if flowOn then table.clone(cracks.FlowSegments) else {}
		table.insert(layout.cracks, line(slot.angle, radii, kinks, cracks.Delay, cracks.Seconds, widths, flow))

		local height, width = between(rng, spec.Height), between(rng, spec.Width)
		local thickness = between(rng, spec.Thickness)
		local lean, yaw = between(rng, spec.Lean), between(rng, spec.Yaw)
		local start = LandingFX.reach(slot.radius, cracks.Delay, cracks.Seconds, radii[1], radii[#radii]) + spec.After
		local satellites = {}
		for j = 1, spec.Satellites do
			local side = if j % 2 == 1 then 1 else -1
			local satHeight = between(rng, spec.SatelliteHeight) * height
			local satWidth = spec.SatelliteWidth * width
			local satThickness = between(rng, spec.SatelliteThickness)
			local satLean = lean + between(rng, spec.SatelliteLean)
			local satYaw = yaw + side * between(rng, spec.SatelliteYaw)
			local out, across = between(rng, spec.Out), side * between(rng, spec.Side)
			-- Draw every satellite, so phones get the same scene minus the extras
			if j <= keep then
				local x, z = beside(slot, out, across)
				table.insert(satellites, {
					x = x,
					z = z,
					height = satHeight,
					width = satWidth,
					thickness = satThickness,
					lean = satLean,
					yaw = satYaw,
					start = start + spec.SatelliteDelay * j,
					rise = spec.SatelliteRise,
					depth = satHeight + satWidth + BURY_MARGIN,
				})
			end
		end
		table.insert(layout.clusters, {
			rank = rank,
			angle = slot.angle,
			radius = slot.radius,
			x = slot.x,
			z = slot.z,
			height = height,
			width = width,
			thickness = thickness,
			lean = lean,
			yaw = yaw,
			start = start,
			rise = spec.Rise,
			depth = height + width + BURY_MARGIN,
			satellites = satellites,
		})
	end

	local offset = rng:NextNumber(0, 360)
	local spacing = 360 / fingers.Count
	for i = 1, fingers.Count do
		local angle = (offset + spacing * (i - 1) + rng:NextNumber(-fingers.Jitter, fingers.Jitter)) % 360
		local length, width = between(rng, fingers.Length), between(rng, fingers.Width)
		table.insert(layout.fingers, {
			angle = angle,
			length = length,
			width = width,
			start = fingers.Start + fingers.Stagger * (i - 1),
		})
	end
end

local function crystalLayout(
	layout: Layout,
	slots: { Slot },
	rng: Random,
	fx: any,
	keep: number,
	flowOn: boolean,
	obstacles: { Obstacle }?,
	config: any
)
	local spec, spokes, circle, rays = fx.Clusters, fx.Spokes, fx.Circle, fx.Rays
	local spokeRadii = table.clone(spokes.Radii)
	table.insert(spokeRadii, circle.Radius)
	local spokeWidths = table.create(#spokeRadii - 1, spokes.Width)
	-- Heroes erupt where the spokes meet the circle
	local arrive = LandingFX.reach(circle.Radius, spokes.Delay, spokes.Seconds, spokeRadii[1], circle.Radius)

	for rank, slot in slots do
		table.insert(
			layout.spokes,
			line(slot.angle, spokeRadii, nil, spokes.Delay, spokes.Seconds, spokeWidths, if flowOn then { 1 } else {})
		)
		local rayFrom, rayTo = slot.radius + rays.Gap, rays.To
		table.insert(
			layout.rays,
			line(slot.angle, { rayFrom, rayTo }, nil, 0, 0, { rays.Width }, if flowOn then { 1 } else {})
		)
		local ray = layout.rays[#layout.rays]
		ray.starts[1] = rays.Start + rays.Stagger * (rank - 1)
		ray.seconds[1] = rays.Seconds

		local height, width = between(rng, spec.Height), between(rng, spec.Width)
		local lean, yaw = between(rng, spec.Lean), between(rng, spec.Yaw)
		local start = arrive + spec.Stagger * (rank - 1)
		local satellites = {}
		for j = 1, spec.Satellites do
			local side = if j % 2 == 1 then 1 else -1
			local satHeight, satWidth = between(rng, spec.SatelliteHeight), between(rng, spec.SatelliteWidth)
			local satLean, satYaw = between(rng, spec.SatelliteLean), rng:NextNumber(0, 360)
			local out, across = between(rng, spec.Out), side * between(rng, spec.Side)
			if j <= keep then
				local x, z = beside(slot, out, across)
				table.insert(satellites, {
					x = x,
					z = z,
					height = satHeight,
					width = satWidth,
					thickness = satWidth,
					lean = satLean,
					yaw = satYaw,
					start = start + spec.SatelliteDelay * j,
					rise = spec.SatelliteRise,
					depth = satHeight + tipHeight(satWidth, spec.TipScale) + satWidth + BURY_MARGIN,
				})
			end
		end
		table.insert(layout.clusters, {
			rank = rank,
			angle = slot.angle,
			radius = slot.radius,
			x = slot.x,
			z = slot.z,
			height = height,
			width = width,
			thickness = width,
			lean = lean,
			yaw = yaw,
			start = start,
			rise = spec.Rise,
			depth = height + tipHeight(width, spec.TipScale) + width + BURY_MARGIN,
			satellites = satellites,
		})
	end

	local count = #layout.clusters
	if count > 0 then
		-- The circle draws outward both ways from the chord nearest From
		local sides = circle.Sides
		local step = 360 / sides
		local first = layout.clusters[1].angle
		local nearest, nearestGap = 0, math.huge
		for c = 0, sides - 1 do
			local gap = angularGap(first + step * (c + 0.5), circle.From)
			if gap < nearestGap then
				nearest, nearestGap = c, gap
			end
		end
		for c = 0, sides - 1 do
			local around = (c - nearest) % sides
			local forward = around <= sides // 2
			local stepsOut = if forward then around else sides - around
			local ax, az = toXZ(first + step * c, circle.Radius)
			local bx, bz = toXZ(first + step * (c + 1), circle.Radius)
			local a, b = Vector2.new(ax, az), Vector2.new(bx, bz)
			table.insert(layout.circle, {
				points = if forward then { a, b } else { b, a },
				starts = { circle.Start + circle.Step * stepsOut },
				seconds = { circle.Grow },
				widths = { circle.Width },
				flow = {},
			})
		end
	end

	-- Ring arcs only bridge rank neighbours that are close enough; crown arcs reach the gem
	local arcs = fx.Arcs
	if count >= 2 then
		for i = 1, count do
			local j = i % count + 1
			if (layout.clusters[j].angle - layout.clusters[i].angle) % 360 <= arcs.MaxGap then
				table.insert(layout.arcs, {
					i = i,
					j = j,
					start = arcs.RingStart + arcs.RingStep * (i - 1),
					seconds = arcs.RingIgnite,
				})
			end
		end
	end
	for i = 1, count do
		table.insert(layout.crowns, { i = i, start = arcs.CrownStart + arcs.CrownStep * (i - 1), seconds = arcs.CrownIgnite })
	end

	-- Sprouts keep their spacing from the heroes as well as each other
	local sprouts = fx.Sprouts
	local placed = table.clone(slots)
	local sproutSlots = placeAll(sprouts.Count, function(k: number): { number }
		return sprouts.Radii[(k - 1) % #sprouts.Radii + 1]
	end, sprouts.Footprint + config.Obstacles.Padding, sprouts.MinSpacing, placed, obstacles, rng, config)
	for _, slot in sproutSlots do
		local height, width = between(rng, sprouts.Height), between(rng, sprouts.Width)
		local lean, yaw = between(rng, sprouts.Lean), between(rng, spec.Yaw)
		table.insert(layout.sprouts, {
			angle = slot.angle,
			radius = slot.radius,
			x = slot.x,
			z = slot.z,
			height = height,
			width = width,
			lean = lean,
			yaw = yaw,
			depth = height + tipHeight(width, spec.TipScale) + width + BURY_MARGIN,
		})
	end
end

-- The seeded scene for one event, or nil for a type without landing effects. Clusters
-- and sprouts are in rank order (counter-clockwise from bearing 90).
function LandingFX.layout(
	typeId: string,
	seed: number,
	obstacles: { Obstacle }?,
	mobile: boolean,
	tuning: any?
): Layout?
	local config = tuning or Tuning
	local fx = config.Types[typeId]
	if not fx then
		return nil
	end
	local rng = Random.new(seed)
	local spec = fx.Clusters
	local keep = if mobile then math.min(spec.Satellites, config.Mobile.Satellites) else spec.Satellites
	local flowOn = config.FlowBeams.Enabled and not (mobile and not config.Mobile.FlowBeams)

	local slots = placeAll(spec.Count, function(): { number }
		return spec.Radii
	end, spec.Footprint + config.Obstacles.Padding, spec.MinSpacing, {}, obstacles, rng, config)

	local layout: Layout = {
		typeId = typeId,
		clusters = {},
		cracks = {},
		fingers = {},
		spokes = {},
		circle = {},
		rays = {},
		sprouts = {},
		arcs = {},
		crowns = {},
	}
	if typeId == "Ice" then
		iceLayout(layout, slots, rng, fx, keep, flowOn)
	else
		crystalLayout(layout, slots, rng, fx, keep, flowOn, obstacles, config)
	end
	return layout
end

-- The ground height profile: the crater floor, a smooth slope, then the flat rim
function LandingFX.groundY(r: number, floorY: number, rimY: number, floorR: number, openR: number): number
	if r <= floorR then
		return floorY
	elseif r >= openR then
		return rimY
	end
	local u = (r - floorR) / (openR - floorR)
	return floorY + (rimY - floorY) * u * u * (3 - 2 * u)
end

-- Live-event rules ---------------------------------------------------------

-- Sprouts up for `broken` of `total` crust nodes: all of them by the time the core unlocks
function LandingFX.sproutsShown(broken: number, total: number, count: number, unlockFraction: number): number
	if total <= 0 or count <= 0 then
		return 0
	end
	local need = math.max(1, math.ceil(total * unlockFraction))
	return math.min(count, math.floor(count * math.clamp(broken, 0, need) / need))
end

function LandingFX.charge(broken: number, total: number): number
	if total <= 0 then
		return 0
	end
	return math.clamp(broken / total, 0, 1)
end

-- Fractions compare, not raw Hp, so a rescale (Hp and MaxHp together) counts as "same"
function LandingFX.hpChange(previous: number?, now: number, eps: number?): "rise" | "drop" | "same"
	if previous == nil then
		return "same"
	end
	local tolerance = eps or 1e-4
	if now > previous + tolerance then
		return "rise"
	elseif now < previous - tolerance then
		return "drop"
	end
	return "same"
end

-- The nodes refreezing right now (rose within `hold` seconds, neither broken nor full),
-- most damaged first, at most `max`
function LandingFX.pickRime(candidates: { RimeCandidate }, now: number, hold: number, max: number): { any }
	local keep: { RimeCandidate } = {}
	for _, candidate in candidates do
		local rose = candidate.lastRiseAt
		if candidate.fraction > 0 and candidate.fraction < 1 and rose and now - rose <= hold then
			table.insert(keep, candidate)
		end
	end
	table.sort(keep, function(a, b)
		if a.fraction ~= b.fraction then
			return a.fraction < b.fraction
		end
		return tostring(a.id) < tostring(b.id)
	end)
	local ids = {}
	for k = 1, math.min(max, #keep) do
		ids[k] = keep[k].id
	end
	return ids
end

-- Geometry -----------------------------------------------------------------

-- A flat strip from a toward b, alpha of the way grown, resting on the a-b line
function LandingFX.stripAt(
	a: Vector3,
	b: Vector3,
	alpha: number,
	width: number,
	thickness: number,
	lift: number
): (CFrame, Vector3)
	local span = b - a
	local full = span.Magnitude
	local size = Vector3.new(width, thickness, math.max(Tuning.Strip.StartLength, alpha * full))
	local raise = thickness / 2 + lift
	if full < 1e-6 then
		return CFrame.new(a + Vector3.yAxis * raise), size
	end
	local middle = a + span.Unit * (alpha * full / 2)
	local frame = CFrame.lookAt(middle, b)
	return frame + frame.UpVector * raise, size
end

-- A flat tapered plate from two WedgeParts lying on their sides: full width at
-- `inner`, a point `length` studs along `outward`, straight edges on the centreline
function LandingFX.flatSpike(
	inner: Vector3,
	outward: Vector3,
	length: number,
	width: number,
	thickness: number
): { Piece }
	local side = Vector3.yAxis:Cross(outward)
	local middle = inner + outward * (length / 2)
	local size = Vector3.new(thickness, width / 2, length)
	return {
		{ cf = CFrame.fromMatrix(middle + side * (width / 4), Vector3.yAxis, side), size = size },
		{ cf = CFrame.fromMatrix(middle - side * (width / 4), -Vector3.yAxis, -side), size = size },
	}
end

-- An upright piece's pose: its UpVector leans `leanDeg` away from the centre, then
-- it turns `yawDeg` about that axis
function LandingFX.pieceFrame(base: Vector3, outward: Vector3, leanDeg: number, yawDeg: number): CFrame
	return CFrame.lookAt(base, base + outward)
		* CFrame.Angles(-math.rad(leanDeg), 0, 0)
		* CFrame.Angles(0, math.rad(yawDeg), 0)
end

-- A pointed blade from two WedgeParts back to back, its base `sink` studs underground
function LandingFX.blade(frame: CFrame, h: number, w: number, t: number, sink: number): { Piece }
	local middle = frame * CFrame.new(0, h / 2 - sink, 0)
	local size = Vector3.new(t, h, w / 2)
	return {
		{ cf = middle * CFrame.new(0, 0, -w / 4), size = size },
		{ cf = middle * CFrame.new(0, 0, w / 4) * CFrame.Angles(0, math.pi, 0), size = size },
	}
end

-- Two blades crossed at right angles
function LandingFX.star(frame: CFrame, h: number, w: number, t: number, sink: number): { Piece }
	local pieces = LandingFX.blade(frame, h, w, t, sink)
	for _, piece in LandingFX.blade(frame * CFrame.Angles(0, math.pi / 2, 0), h, w, t, sink) do
		table.insert(pieces, piece)
	end
	return pieces
end

-- A crystal: a square body, a cube tip on its corner at the body top, an optional glowing
-- spine inside, and `top`, the tip's highest point
function LandingFX.prism(
	frame: CFrame,
	h: number,
	w: number,
	tipScale: number,
	spine: { Width: number, Length: number }?,
	sink: number
): Prism
	local s = tipScale * w
	local body = frame * CFrame.new(0, h / 2 - sink, 0)
	return {
		body = { cf = body, size = Vector3.new(w, h, w) },
		tip = { cf = frame * CFrame.new(0, h - sink, 0) * LandingFX.TIP_ROTATION, size = Vector3.new(s, s, s) },
		spine = if spine
			then { cf = body, size = Vector3.new(spine.Width * w, spine.Length * h, spine.Width * w) }
			else nil,
		top = frame * Vector3.new(0, h - sink + s * math.sqrt(3) / 2, 0),
	}
end

function LandingFX.buried(cf: CFrame, axis: Vector3, depth: number): CFrame
	return cf - axis * depth
end

-- Budget -------------------------------------------------------------------

-- BaseParts one event builds at most (every slot placed)
function LandingFX.budget(typeId: string, mobile: boolean, tuning: any?): number
	local config = tuning or Tuning
	local fx = config.Types[typeId]
	if not fx then
		return 0
	end
	local clusters = fx.Clusters
	local satellites = if mobile then math.min(clusters.Satellites, config.Mobile.Satellites) else clusters.Satellites
	local parts = 1 -- the anchor that holds every beam and burst attachment
	if fx.Sheet and fx.Sheet.Enabled then
		parts += 1
	end
	if fx.Shimmer and fx.Shimmer.Enabled then
		parts += 1
	end
	if typeId == "Ice" then
		parts += clusters.Count * (#fx.Cracks.Radii + #fx.Cracks.Beyond) -- crack strips
		parts += clusters.Count * (4 + 1 + 2 * satellites) -- star, core, satellite blades
		parts += fx.Fingers.Count * 2
		parts += 1 -- snow host
		if not mobile or config.Mobile.Mist then
			parts += 1 -- mist host
		end
		if fx.Rime.Enabled then
			parts += fx.Rime.Max
		end
	else
		parts += clusters.Count * #fx.Spokes.Radii + fx.Circle.Sides + clusters.Count -- spokes, circle, rays
		parts += clusters.Count * (3 + 2 * satellites) -- body, tip, spine; satellite body and tip
		parts += fx.Sprouts.Count * 2
		parts += 2 -- gem, motes host
	end
	return parts
end

return LandingFX
