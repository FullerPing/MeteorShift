--!strict
-- Geometry and limits for the redesigned world; mining and economy rules are separate.
local WorldGeometry = {}
WorldGeometry.Settings = {
	MeteorScale = 2,
	BuildingScale = 0.5,
	StageOffset = Vector3.new(0, 0, 3000),
	LandingRadius = 125, -- persistent landing parts; ballistic particles can travel farther
	BoundaryHalf = 270,
	LoopRadius = 134,
	TownAvenueZ = -130,
	TownSpineX = -55,
	TradingBranchZ = -215,
	SpawnRowsZ = { -257, -229 },
	WelcomeZ = -265,
	KillPlaneY = -70,
	PathWidth = 18,
	MainPathWidth = 24,
	CraterRampWidth = 24,
	Zones = {
		{ id = "Refinery", x = 0, z = -177, width = 38, depth = 32, entrance = Vector3.new(0, 3, -158.5), pathWidth = 18 },
		{ id = "GearHall", x = 128, z = -185, width = 50, depth = 36, entrance = Vector3.new(128, 0, -165.5), pathWidth = 18 },
		{ id = "Hatchery", x = -135, z = -185, width = 64, depth = 36, entrance = Vector3.new(-135, 0, -165), pathWidth = 18 },
		{ id = "TradingPost", x = 60, z = -245, width = 28, depth = 20, entrance = Vector3.new(60, 0, -232), pathWidth = 14 },
		{ id = "Spawn", x = -20, z = -241, width = 96, depth = 54, entrance = Vector3.new(-55, 0, -215), pathWidth = 24 },
		{ id = "Rebirth", x = -214, z = -55, width = 36, depth = 36, entrance = Vector3.new(-196.5, 0, -55), pathWidth = 18 },
		{ id = "Museum", x = 214, z = -55, width = 42, depth = 38, entrance = Vector3.new(192, 0, -55), pathWidth = 18 },
		{ id = "RustWorks", x = -130, z = 185, width = 100, depth = 92, entrance = Vector3.new(-130, 0, 139), pathWidth = 18 },
		{ id = "FrostYard", x = 130, z = 185, width = 100, depth = 92, entrance = Vector3.new(130, 0, 139), pathWidth = 18 },
		{ id = "VioletQuarry", x = -214, z = 77, width = 92, depth = 96, entrance = Vector3.new(-168, 0, 77), pathWidth = 18 },
		{ id = "SulfurRidge", x = 214, z = 77, width = 92, depth = 96, entrance = Vector3.new(168, 0, 77), pathWidth = 18 },
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

function WorldGeometry.inside(position: any): boolean
	if typeof(position) ~= "Vector3" then return false end
	for _, value in { position.X, position.Y, position.Z } do
		if value ~= value or math.abs(value) == math.huge then return false end
	end
	local s = WorldGeometry.Settings
	return math.abs(position.X) <= s.BoundaryHalf and math.abs(position.Z) <= s.BoundaryHalf and position.Y >= s.KillPlaneY
end

return WorldGeometry
