--!strict
-- Geometry and limits for the redesigned world; mining and economy rules are separate.
local WorldGeometry = {}
WorldGeometry.Settings = {
	MeteorScale = 2,
	StageOffset = Vector3.zero, -- the map is authored in place
	LandingRadius = 125, -- persistent landing parts; ballistic particles can travel farther
	BoundaryHalf = 540,
	LoopRadius = 134,
	-- The south approach: a cream plaza SouthPlazaHalf wide each side of X = 0 runs from just behind the Refinery to
	-- the ring road. The Refinery faces north (front and UsePoint toward the crater); the six spawn points are
	-- invisible and stand between its front and the ring road, so players spawn in front of it looking at the meteor.
	SouthPlazaHalf = 40,
	SpawnRowsZ = { -153, -148 },
	SpawnColumnsX = { -18, 0, 18 },
	KillPlaneY = -70,
	PathWidth = 18,
	CraterRampWidth = 24,
	-- Map v3 "Caldera Terraces" (docs/design/caldera-map-v3.md): height is progress. Rings of ground by distance from
	-- the crater, cliffs between them, and the Crown plateau on the north side of T2.
	Tiers = {
		{ id = "T0", inner = 0, outer = 250, y = 0 },
		{ id = "T1", inner = 266, outer = 360, y = 16 },
		{ id = "T2", inner = 372, outer = math.huge, y = 32 },
	},
	Crown = { x0 = -150, x1 = 150, z0 = 400, z1 = 540, y = 56 }, -- runs to the north wall: no dead alley behind it
	ExpressRadius = 280, -- the Terrace Express ring on T1, a fast lane like the ring road
	ExpressWidth = 16,
	-- Eight gold avenues every 45 degrees (atan2(z, x)) from the ring road to the wall, also fast lanes. The north one
	-- ends at the Crown; the south one starts behind the Refinery so the spawn plaza stays calm.
	Avenues = { width = 24, from = 143, angles = { 0, 45, 90, 135, 180, 225, 270, 315 }, starts = { [270] = 196 } },
	-- Slides down beside three avenues, `offset` studs off the centre line (side +1 = counter-clockwise of it), from the
	-- tier edge (the Crown for the north one) to the ring road's outer edge
	Slides = { offset = 22, width = 8, list = { { angle = 45, side = -1 }, { angle = 135, side = 1 }, { angle = 90, side = 1 } } },
	-- width/depth are the axis-aligned footprint. Buildings turned toward the crater also carry `facing` (the way their
	-- front looks) and `lat` x `dep` (their own frame: across the front, then front-to-back); width/depth then bound
	-- that rotated rectangle. Ore fields (`field = true`) bound their rocks, gate and chute; `entrance` is just
	-- outside their gate. Positions come from tools/map-v3/plan.py.
	Zones = {
		{ id = "Spawn", x = 0, z = -150.5, width = 48, depth = 13, entrance = Vector3.new(0, 0, -144), pathWidth = 24 },
		{ id = "Refinery", x = 0, z = -177, width = 38, depth = 32, entrance = Vector3.new(0, 3, -158.5), pathWidth = 18 },
		{ id = "GearHall", x = 76.5, z = -184.5, width = 61, depth = 53, lat = 50, dep = 36, facing = Vector3.new(-0.3827, 0, 0.9239), entrance = Vector3.new(68.5, 0, -165.4), pathWidth = 18 },
		{ id = "Hatchery", x = -76.5, z = -184.5, width = 73, depth = 59, lat = 64, dep = 36, facing = Vector3.new(0.3827, 0, 0.9239), entrance = Vector3.new(-68.5, 0, -165.4), pathWidth = 18 },
		{ id = "Commissary", x = 181, z = 75, width = 38, depth = 40, lat = 30, dep = 28, facing = Vector3.new(-0.9239, 0, -0.3827), entrance = Vector3.new(165.4, 0, 68.5), pathWidth = 18 },
		-- the two leaderboards in front of the Gear Hall and the Hatchery, turned toward the crater
		{ id = "LeaderboardEast", x = 33.5, z = -159.5, width = 19, depth = 13, lat = 18, dep = 5, facing = Vector3.new(-0.3827, 0, 0.9239), entrance = Vector3.new(31.4, 0, -154.2), pathWidth = 14 },
		{ id = "LeaderboardWest", x = -33.5, z = -159.5, width = 19, depth = 13, lat = 18, dep = 5, facing = Vector3.new(0.3827, 0, 0.9239), entrance = Vector3.new(-31.4, 0, -154.2), pathWidth = 14 },
		{ id = "Rebirth", x = 0, z = -320, width = 40, depth = 36, entrance = Vector3.new(0, 16, -299), pathWidth = 18 },
		{ id = "RustWorks", x = -180, z = -77, width = 102, depth = 112, entrance = Vector3.new(-144.1, 0, -59.7), pathWidth = 18, field = true },
		{ id = "FrostYard", x = 180, z = -77, width = 102, depth = 112, entrance = Vector3.new(144.1, 0, -59.7), pathWidth = 18, field = true },
		{ id = "VioletQuarry", x = -301.5, z = 112.5, width = 85, depth = 169, entrance = Vector3.new(-269.8, 16, 111.7), pathWidth = 18, field = true },
		{ id = "SulfurRidge", x = 301.5, z = 112.5, width = 85, depth = 169, entrance = Vector3.new(269.8, 16, 111.7), pathWidth = 18, field = true },
		{ id = "EmberShelf", x = -406, z = 148.5, width = 118, depth = 181, entrance = Vector3.new(-351.1, 32, 145.4), pathWidth = 18, field = true },
		{ id = "GlassScar", x = 422.5, z = 171, width = 151, depth = 148, entrance = Vector3.new(351.1, 32, 145.4), pathWidth = 18, field = true },
		{ id = "Starfall", x = -85, z = 452, width = 76, depth = 74, entrance = Vector3.new(-85, 56, 425), pathWidth = 18, field = true },
		{ id = "HaloLedge", x = 82, z = 450.5, width = 96, depth = 71, entrance = Vector3.new(70, 56, 425), pathWidth = 18, field = true },
	},
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

-- The ground a point stands on: "T0", "T1", "T2", "Crown", or "Cliff" in the band between two tiers
function WorldGeometry.tierAt(x: number, z: number): string
	local s = WorldGeometry.Settings
	local c = s.Crown
	if x >= c.x0 and x <= c.x1 and z >= c.z0 and z <= c.z1 then return "Crown" end
	local r = math.sqrt(x * x + z * z)
	for _, tier in s.Tiers do
		if r >= tier.inner and r < tier.outer then return tier.id end
	end
	return "Cliff"
end

-- The ground height of a tier id ("Crown" included)
function WorldGeometry.tierY(id: string): number
	if id == "Crown" then return WorldGeometry.Settings.Crown.y end
	for _, tier in WorldGeometry.Settings.Tiers do
		if tier.id == id then return tier.y end
	end
	error("Unknown tier: " .. id)
end

function WorldGeometry.inside(position: any): boolean
	if typeof(position) ~= "Vector3" then return false end
	for _, value in { position.X, position.Y, position.Z } do
		if value ~= value or math.abs(value) == math.huge then return false end
	end
	local s = WorldGeometry.Settings
	return math.abs(position.X) <= s.BoundaryHalf and math.abs(position.Z) <= s.BoundaryHalf and position.Y >= s.KillPlaneY
end

return WorldGeometry
