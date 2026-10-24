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
	-- ends at the Crown; the south one starts behind the Refinery so the spawn plaza stays calm and ends at the Rebirth
	-- Terrace's front. `stops` is where the paving (and the fast lane) ends; the others run to the wall.
	Avenues = { width = 24, from = 143, angles = { 0, 45, 90, 135, 180, 225, 270, 315 }, starts = { [270] = 196 }, stops = { [90] = 392, [270] = 302 } },
	-- Slides down beside three avenues, `offset` studs off the centre line (side +1 = counter-clockwise of it), from the
	-- tier edge (the Crown for the north one) to the ring road's outer edge
	Slides = { offset = 22, width = 8, list = { { angle = 45, side = -1 }, { angle = 135, side = 1 }, { angle = 90, side = 1 } } },
	-- width/depth are the axis-aligned footprint. Buildings turned toward the crater also carry `facing` (the way their
	-- front looks) and `lat` x `dep` (their own frame: across the front, then front-to-back); width/depth then bound
	-- that rotated rectangle. Ore fields (`field = true`) bound their rocks, gates and chute; `entrance` is on the
	-- avenue in front of their gate (Rust and Frost: between their two blocks). Positions come from tools/map-v3/plan.py.
	Zones = {
		{ id = "Spawn", x = 0, z = -150.5, width = 48, depth = 13, entrance = Vector3.new(0, 0, -144), pathWidth = 24 },
		{ id = "Refinery", x = 0, z = -177, width = 38, depth = 32, entrance = Vector3.new(0, 3, -158.5), pathWidth = 18 },
		-- the Hatchery's five egg stands stand in an arc facing the crater (rebuilt in Studio, owner 2026-10-24), slid 8 studs
		-- west of the old spot to stay off the south plaza (it used to mirror the Gear Hall, removed the same day)
		{ id = "Hatchery", x = -83.9, z = -181.4, width = 112, depth = 84, lat = 100, dep = 49, facing = Vector3.new(0.3827, 0, 0.9239), entrance = Vector3.new(-73.6, 0, -156.5), pathWidth = 18 },
		{ id = "Commissary", x = 95.1, z = 151.1, width = 39, depth = 38, lat = 30, dep = 28, facing = Vector3.new(-0.3827, 0, -0.9239), entrance = Vector3.new(88.6, 0, 135.5), pathWidth = 18 },
		-- the three leaderboards in one row east of the spawn, 24 studs apart, each turned to face the crater and its ring
		-- road (owner, 2026-10-24): Top Miners, Top Rebirths, Top Playtime, where the Gear Hall stood (removed the same
		-- day: the gear shop opens from the HUD)
		{ id = "LeaderboardEast", x = 33.5, z = -159.5, width = 19, depth = 19, lat = 18, dep = 5, facing = Vector3.new(-0.2055, 0, 0.9786), entrance = Vector3.new(32.3, 0, -153.9), pathWidth = 14 },
		{ id = "LeaderboardRebirths", x = 55.7, z = -150.3, width = 19, depth = 19, lat = 18, dep = 5, facing = Vector3.new(-0.3473, 0, 0.9377), entrance = Vector3.new(53.7, 0, -145.0), pathWidth = 14 },
		{ id = "LeaderboardPlaytime", x = 77.8, z = -141.1, width = 19, depth = 19, lat = 18, dep = 5, facing = Vector3.new(-0.4830, 0, 0.8756), entrance = Vector3.new(75.1, 0, -136.1), pathWidth = 14 },
		{ id = "Rebirth", x = 0, z = -320, width = 40, depth = 36, entrance = Vector3.new(0, 16, -299), pathWidth = 18 },
		{ id = "RustWorks", x = -189, z = 0, width = 54, depth = 218, entrance = Vector3.new(-189, 0, 0), pathWidth = 18, field = true },
		{ id = "FrostYard", x = 189, z = 0, width = 54, depth = 218, entrance = Vector3.new(189, 0, 0), pathWidth = 18, field = true },
		{ id = "VioletQuarry", x = -311.25, z = 73.25, width = 37.5, depth = 115.5, entrance = Vector3.new(-306, 16, 10), pathWidth = 18, field = true },
		{ id = "SulfurRidge", x = 311.25, z = 73.25, width = 37.5, depth = 115.5, entrance = Vector3.new(306, 16, 10), pathWidth = 18, field = true },
		{ id = "EmberShelf", x = -422, z = 84.25, width = 76, depth = 137.5, entrance = Vector3.new(-422, 32, 10), pathWidth = 18, field = true },
		{ id = "GlassScar", x = 455, z = 87.25, width = 123.1, depth = 143.5, entrance = Vector3.new(455, 32, 10), pathWidth = 18, field = true },
		{ id = "Starfall", x = -91, z = 452, width = 88, depth = 74, entrance = Vector3.new(-85, 56, 425), pathWidth = 18, field = true },
		{ id = "HaloLedge", x = 82, z = 450.5, width = 96, depth = 71, entrance = Vector3.new(70, 56, 425), pathWidth = 18, field = true },
		-- the XP Mine on T2 straight behind the south avenue, reached by a ramp up the cliff where the Rebirth shrine stood:
		-- 12 rocks across by 6 deep with uneven gaps (11 to 27 studs, seeded 20261024; placed in Studio, not by tools/map-v3;
		-- the entrance is on its crater side)
		{ id = "XpMine", x = 0, z = -444, width = 208, depth = 110, entrance = Vector3.new(0, 32, -382), pathWidth = 18, field = true },
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

-- Whether a position stands on the Crown plateau's top (not on T2 below its edge)
function WorldGeometry.onCrown(position: Vector3): boolean
	local c = WorldGeometry.Settings.Crown
	return WorldGeometry.tierAt(position.X, position.Z) == "Crown" and position.Y > c.y - 6
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
