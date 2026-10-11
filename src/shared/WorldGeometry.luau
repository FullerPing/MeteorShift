--!strict
-- Geometry and limits for the redesigned world; mining and economy rules are separate.
local WorldGeometry = {}
WorldGeometry.Settings = {
	MeteorScale = 2,
	BuildingScale = 0.5,
	StageOffset = Vector3.zero, -- the v2 map is authored in place; the staged v1 map sat at Z+3000
	LandingRadius = 125, -- persistent landing parts; ballistic particles can travel farther
	BoundaryHalf = 270,
	LoopRadius = 134,
	-- The south approach: a cream plaza SouthPlazaHalf wide each side of X = 0 runs from just behind the Refinery to
	-- the ring road. The Refinery faces north (front and UsePoint toward the crater); the six spawn points are
	-- invisible and stand between its front and the ring road, so players spawn in front of it looking at the meteor.
	SouthPlazaHalf = 40,
	SpawnRowsZ = { -153, -148 },
	SpawnColumnsX = { -18, 0, 18 },
	KillPlaneY = -70,
	PathWidth = 18,
	MainPathWidth = 24,
	CraterRampWidth = 24,
	-- width/depth are the axis-aligned footprint. Buildings turned toward the crater also carry `facing` (the way their
	-- front looks) and `lat` x `dep` (their own frame: across the front, then front-to-back); width/depth then bound
	-- that rotated rectangle.
	Zones = {
		{ id = "Spawn", x = 0, z = -150.5, width = 48, depth = 13, entrance = Vector3.new(0, 0, -144), pathWidth = 24 },
		{ id = "Refinery", x = 0, z = -177, width = 38, depth = 32, entrance = Vector3.new(0, 3, -158.5), pathWidth = 18 },
		{ id = "GearHall", x = 112, z = -145, width = 70, depth = 68, lat = 50, dep = 36, facing = Vector3.new(-0.6113, 0, 0.7914), entrance = Vector3.new(93.7, 0, -121.3), pathWidth = 18 },
		{ id = "Hatchery", x = -112, z = -145, width = 80, depth = 74, lat = 64, dep = 36, facing = Vector3.new(0.6113, 0, 0.7914), entrance = Vector3.new(-93.7, 0, -121.3), pathWidth = 18 },
		{ id = "Rebirth", x = 176, z = -100, width = 36, depth = 36, entrance = Vector3.new(158, 0, -100), pathWidth = 18 },
		{ id = "TradingPost", x = -176, z = -100, width = 20, depth = 28, entrance = Vector3.new(-166, 0, -100), pathWidth = 14 },
		-- the two leaderboards on the south plaza either side of the Refinery, turned a little toward the spawn
		{ id = "LeaderboardEast", x = 31, z = -170, width = 18, depth = 12, entrance = Vector3.new(27, 0, -163), pathWidth = 14 },
		{ id = "LeaderboardWest", x = -31, z = -170, width = 18, depth = 12, entrance = Vector3.new(-27, 0, -163), pathWidth = 14 },
		{ id = "Commissary", x = 0, z = 172, width = 28, depth = 28, entrance = Vector3.new(0, 0, 152), pathWidth = 18 },
		-- the four ore fields are appended below, worked out from their fans
	},
	-- The four biome quarters: slices of the circle beyond the ring road (angles in degrees, atan2(z, x); the town
	-- fills the south). Each slice holds one ore field: a fan of rocks opening from a gate on its centre line just
	-- past the ring road out toward the wall, with the field's landmark at the far end. The rest of the slice is
	-- biome decoration.
	Quarters = {
		{ id = "SulfurRidge", from = -20, to = 36 },
		{ id = "FrostYard", from = 36, to = 90 },
		{ id = "RustWorks", from = 90, to = 144 },
		{ id = "VioletQuarry", from = 144, to = 200 },
	},
	-- Distances along a quarter's centre line from the crater (studs). The fan is HalfStart wide each side at Start and
	-- grows by Spread per stud outward; Landing is where ORE travel puts you; the landmark is a LandmarkLat x
	-- LandmarkDep rectangle centred at Landmark.
	Fan = { Gate = 160, Start = 160, End = 238, HalfStart = 31, Spread = 0.97, Landing = 172, Landmark = 250, LandmarkLat = 88, LandmarkDep = 26, GateHalf = 23 },
}

function WorldGeometry.scaled(size: Vector3): Vector3
	return size * WorldGeometry.Settings.MeteorScale
end

function WorldGeometry.footprintDistance(zone: any): number
	local x = math.max(math.abs(zone.x) - zone.width / 2, 0)
	local z = math.max(math.abs(zone.z) - zone.depth / 2, 0)
	return math.sqrt(x * x + z * z)
end

function WorldGeometry.zone(id: string): any
	for _, zone in WorldGeometry.Settings.Zones do
		if zone.id == id then return zone end
	end
	error("Unknown world zone: " .. id)
end

function WorldGeometry.rampAngle(rise: number, run: number): number
	return math.deg(math.atan2(rise, run))
end

function WorldGeometry.toStage(position: Vector3): Vector3
	return position + WorldGeometry.Settings.StageOffset
end

function WorldGeometry.toFinal(position: Vector3): Vector3
	return position - WorldGeometry.Settings.StageOffset
end

-- A quarter's centre line: `out` points from the crater along it, `right` across it (both flat unit vectors)
function WorldGeometry.quarter(id: string): any
	for _, q in WorldGeometry.Settings.Quarters do
		if q.id == id then
			-- the west quarters mirror the east ones exactly, so mirrored fields come out with mirrored numbers
			local mid = (q.from + q.to) / 2
			local east = if mid > 90 then 180 - mid else mid
			local c, s = math.cos(math.rad(east)), math.sin(math.rad(east))
			if mid > 90 then c = -c end
			return { id = id, from = q.from, to = q.to, out = Vector3.new(c, 0, s), right = Vector3.new(-s, 0, c) }
		end
	end
	error("Unknown quarter: " .. id)
end

-- The quarter a ground point beyond the ring road's centre line belongs to, or nil (the plaza and the town)
function WorldGeometry.quarterAt(x: number, z: number): string?
	if x * x + z * z < WorldGeometry.Settings.LoopRadius ^ 2 then return nil end
	local angle = math.deg(math.atan2(z, x))
	if angle < -90 then angle += 360 end
	for _, q in WorldGeometry.Settings.Quarters do
		if angle >= q.from and angle < q.to then return q.id end
	end
	return nil
end

-- A point in a quarter's own terms: distance out along its centre line and sideways from it
function WorldGeometry.fanCoords(id: string, x: number, z: number): (number, number)
	local q = WorldGeometry.quarter(id)
	local p = Vector3.new(x, 0, z)
	return p:Dot(q.out), p:Dot(q.right)
end

-- How far each side of the centre line the fan reaches at a distance `d` out
function WorldGeometry.fanHalf(d: number): number
	local f = WorldGeometry.Settings.Fan
	return f.HalfStart + (d - f.Start) * f.Spread
end

-- Is (x, z) inside the field's fan of rocks, grown by `margin`?
function WorldGeometry.inFan(id: string, x: number, z: number, margin: number?): boolean
	local f, m = WorldGeometry.Settings.Fan, margin or 0
	local d, lat = WorldGeometry.fanCoords(id, x, z)
	return d >= f.Start - m and d <= f.End + m and math.abs(lat) <= WorldGeometry.fanHalf(math.clamp(d, f.Start, f.End)) + m
end

-- Is (x, z) on the field's landmark rectangle (or its gate), grown by `margin`?
function WorldGeometry.onLandmark(id: string, x: number, z: number, margin: number?): boolean
	local f, m = WorldGeometry.Settings.Fan, margin or 0
	local d, lat = WorldGeometry.fanCoords(id, x, z)
	return (math.abs(d - f.Landmark) <= f.LandmarkDep / 2 + m and math.abs(lat) <= f.LandmarkLat / 2 + m)
		or (math.abs(d - f.Gate) <= 3 + m and math.abs(lat) <= f.GateHalf + m)
end

-- The field's zone: the axis-aligned box round its gate, fan and landmark
local function fieldZone(id: string): any
	local f, q = WorldGeometry.Settings.Fan, WorldGeometry.quarter(id)
	local corners = {}
	local function add(d, lat) table.insert(corners, q.out * d + q.right * lat) end
	for _, lat in { -f.GateHalf, f.GateHalf } do add(f.Gate - 2, lat); add(f.Gate + 2, lat) end
	for _, d in { f.Start, f.End } do add(d, -WorldGeometry.fanHalf(d)); add(d, WorldGeometry.fanHalf(d)) end
	for _, dd in { -f.LandmarkDep / 2, f.LandmarkDep / 2 } do
		for _, lat in { -f.LandmarkLat / 2, f.LandmarkLat / 2 } do add(f.Landmark + dd, lat) end
	end
	local x0, x1, z0, z1 = math.huge, -math.huge, math.huge, -math.huge
	for _, c in corners do
		x0, x1, z0, z1 = math.min(x0, c.X), math.max(x1, c.X), math.min(z0, c.Z), math.max(z1, c.Z)
	end
	x0, x1, z0, z1 = math.floor(x0), math.ceil(x1), math.floor(z0), math.ceil(z1)
	local entrance = q.out * f.Gate
	return { id = id, x = (x0 + x1) / 2, z = (z0 + z1) / 2, width = x1 - x0, depth = z1 - z0, entrance = Vector3.new(entrance.X, 0, entrance.Z), pathWidth = 18, quarter = true }
end
for _, q in WorldGeometry.Settings.Quarters do table.insert(WorldGeometry.Settings.Zones, fieldZone(q.id)) end

function WorldGeometry.inside(position: any): boolean
	if typeof(position) ~= "Vector3" then return false end
	for _, value in { position.X, position.Y, position.Z } do
		if value ~= value or math.abs(value) == math.huge then return false end
	end
	local s = WorldGeometry.Settings
	return math.abs(position.X) <= s.BoundaryHalf and math.abs(position.Z) <= s.BoundaryHalf and position.Y >= s.KillPlaneY
end

return WorldGeometry
