--!strict
-- Geometry and limits for the redesigned world; mining and economy rules are separate.
local WorldGeometry = {}
WorldGeometry.Settings = {
	MeteorScale = 2,
	StageOffset = Vector3.new(0, 0, 3000),
	LandingRadius = 310,
	BoundaryHalf = 510,
	KillPlaneY = -70,
	PathWidth = 18,
	MainPathWidth = 24,
	CraterRampWidth = 24,
	Zones = {
		{ id = "Refinery", x = 0, z = -380, width = 76, depth = 64, entrance = Vector3.new(0, 3, -343), pathWidth = 18 },
		{ id = "GearHall", x = 140, z = -380, width = 100, depth = 72, entrance = Vector3.new(140, 0, -341), pathWidth = 18 },
		{ id = "Hatchery", x = -155, z = -380, width = 128, depth = 72, entrance = Vector3.new(-155, 0, -340), pathWidth = 18 },
		{ id = "TradingPost", x = 70, z = -460, width = 56, depth = 40, entrance = Vector3.new(70, 0, -434), pathWidth = 18 },
		{ id = "Spawn", x = -20, z = -458, width = 96, depth = 64, entrance = Vector3.new(-65, 0, -435), pathWidth = 24 },
		{ id = "Rebirth", x = -360, z = -160, width = 72, depth = 72, entrance = Vector3.new(-325, 0, -160), pathWidth = 18 },
		{ id = "Museum", x = 360, z = -160, width = 84, depth = 76, entrance = Vector3.new(316, 0, -160), pathWidth = 18 },
		{ id = "RustWorks", x = -275, z = 270, width = 100, depth = 92, entrance = Vector3.new(-240, 0, 224), pathWidth = 18 },
		{ id = "FrostYard", x = 275, z = 270, width = 100, depth = 92, entrance = Vector3.new(240, 0, 224), pathWidth = 18 },
		{ id = "VioletQuarry", x = -390, z = 55, width = 92, depth = 96, entrance = Vector3.new(-344, 0, 55), pathWidth = 18 },
		{ id = "SulfurRidge", x = 390, z = 55, width = 92, depth = 96, entrance = Vector3.new(344, 0, 55), pathWidth = 18 },
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
