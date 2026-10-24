--!strict
-- World access and effect clearance are geometric contracts, not mining-rule changes.
return function(t: any)
	t.test("onCrown is the plateau's top, not the T2 ground below its edge", function()
		local G = require(t.shared.WorldGeometry)
		t.eq(G.onCrown(Vector3.new(0, 59, 450)), true)
		t.eq(G.onCrown(Vector3.new(-30, 57, 475)), true)
		t.eq(G.onCrown(Vector3.new(0, 36, 395)), false, "the lift base on T2")
		t.eq(G.onCrown(Vector3.new(200, 59, 450)), false, "beside the Crown")
	end)
	local module = t.shared:FindFirstChild("WorldGeometry")
	t.test("shared world geometry exists", function() t.ok(module, "WorldGeometry missing") end)
	if not module then return end
	local Geometry = require(module)
	local Config = require(t.shared.Config)
	t.test("meteor doubles in every dimension without changing Basic reach", function()
		t.eq(Geometry.Settings.MeteorScale, 2)
		local size = Geometry.scaled(Vector3.new(28.35, 28.35, 28.35))
		for _, dimension in { size.X, size.Y, size.Z } do t.near(dimension, 56.7, 1e-4) end
		t.eq(Config.Meteor.MineRange, 12)
		t.near(Config.Meteor.Knockback.Radius, 90 * 1.3, 1e-6)
		t.near(Config.Tutorial.CraterRadius, 64 * 1.3, 1e-6)
	end)
	t.test("crater geometry agrees with the scene contracts", function()
		local crater = Config.LandingFX.Crater
		t.near(crater.FloorY, -11.35 * 1.3, 1e-6)
		t.near(crater.FloorRadius, 42.5 * 1.3, 1e-6)
		t.near(crater.OpeningRadius, 64 * 1.3, 1e-6)
		t.eq(crater.Center, Vector3.new(0, -1.25, 0), "original meteor landing height")
		t.ok(crater.ProbeDepth >= 160, "floor probe reaches the deep bowl")
	end)
	t.test("enlarged landing geometry fits between mining access and the outer service zones", function()
		local ice, crystal = Config.LandingFX.Types.Ice, Config.LandingFX.Types.Crystal
		t.eq(ice.Sheet.Diameter, 108)
		t.eq(crystal.Shimmer.Diameter, 106)
		for _, diameter in { ice.Sheet.Diameter, crystal.Shimmer.Diameter } do
			t.ok(diameter / 2 > 52 and diameter / 2 < Config.LandingFX.Crater.FloorRadius, "visible collar stays inside crater floor")
		end
		t.eq(ice.Fingers.Inner, 85)
		t.eq(ice.Fingers.Length[2], 38)
		t.ok(ice.Fingers.Inner + ice.Fingers.Length[2] <= Geometry.Settings.LandingRadius)
		for _, fx in { ice, crystal } do
			for _, radius in fx.Clusters.Radii do
				t.ok(radius - fx.Clusters.Footprint >= Config.LandingFX.Crater.OpeningRadius, "upright landmark inside mining opening")
			end
		end
		for _, pathAngle in { 0, 90, 180, 270 } do
			local blocked = false
			for _, corridor in Config.LandingFX.Corridors do if corridor.Angle == pathAngle then blocked = true end end
			t.ok(blocked, "cardinal approach must stay clear of upright effects")
		end
	end)
	t.test("all interactive footprints clear the worst landing effect", function()
		for _, zone in Geometry.Settings.Zones do
			t.ok(Geometry.footprintDistance(zone) >= Geometry.Settings.LandingRadius + 4, zone.id .. " inside FX")
			t.ok(math.abs(zone.x) + zone.width / 2 < Geometry.Settings.BoundaryHalf, zone.id .. " crosses X boundary")
			t.ok(math.abs(zone.z) + zone.depth / 2 < Geometry.Settings.BoundaryHalf, zone.id .. " crosses Z boundary")
		end
		t.near(Geometry.footprintDistance(Geometry.zone("Refinery")), 161, 1e-6)
		t.ok(Geometry.zone("Refinery").entrance.Magnitude > Config.Meteor.Knockback.Radius + 12, "front clearance beyond shockwave")
	end)
	t.test("the 1080 terraced layout keeps every footprint apart", function()
		local s = Geometry.Settings
		t.eq(s.BoundaryHalf, 540)
		t.eq(#s.Tiers, 3)
		t.eq(s.Tiers[1].outer, 250)
		t.eq(s.Tiers[2].inner, 266)
		t.eq(s.Tiers[2].outer, 360)
		t.eq(s.Tiers[3].inner, 372)
		t.eq(s.Crown.y, 56)
		t.eq(s.ExpressRadius, 280)
		t.eq(#s.Avenues.angles, 8)
		-- a zone's real footprint: its rotated lat x dep rectangle when it faces somewhere, else its box
		local function rect(z)
			local f = z.facing or Vector3.zAxis
			local r = Vector3.new(f.Z, 0, -f.X)
			local hu, hd = (if z.facing then z.lat else z.width) / 2, (if z.facing then z.dep else z.depth) / 2
			local c = Vector3.new(z.x, 0, z.z)
			return { c + r * hu + f * hd, c - r * hu + f * hd, c - r * hu - f * hd, c + r * hu - f * hd }, { r, f }
		end
		local function apart(a, b)
			local ca, axesA = rect(a)
			local cb, axesB = rect(b)
			for _, axis in { axesA[1], axesA[2], axesB[1], axesB[2] } do
				local a0, a1, b0, b1 = math.huge, -math.huge, math.huge, -math.huge
				for _, p in ca do a0, a1 = math.min(a0, p:Dot(axis)), math.max(a1, p:Dot(axis)) end
				for _, p in cb do b0, b1 = math.min(b0, p:Dot(axis)), math.max(b1, p:Dot(axis)) end
				if a1 <= b0 + 1e-6 or b1 <= a0 + 1e-6 then return true end
			end
			return false
		end
		local zones = s.Zones
		for i, a in zones do
			for j = i + 1, #zones do
				t.ok(apart(a, zones[j]), a.id .. " overlaps " .. zones[j].id)
			end
		end
	end)
	t.test("rectangular clearance uses the closest corner rather than centre", function()
		t.near(Geometry.footprintDistance({ x = 275, z = 270, width = 100, depth = 92 }), math.sqrt(225^2 + 224^2), 1e-6)
		t.eq(Geometry.footprintDistance({ x = 2, z = 2, width = 10, depth = 10 }), 0)
	end)
	t.test("every zone has a walkable entrance and wide paths", function()
		t.ok(Geometry.Settings.PathWidth >= 14)
		t.ok(Geometry.Settings.Avenues.width >= 14)
		for _, zone in Geometry.Settings.Zones do
			t.eq(typeof(zone.entrance), "Vector3", zone.id .. " entrance")
			t.ok(zone.pathWidth >= 14, zone.id .. " narrow path")
		end
		t.ok(Geometry.Settings.CraterRampWidth >= 14)
		local crater = Config.LandingFX.Crater
		t.ok(Geometry.rampAngle(-crater.FloorY, crater.OpeningRadius-crater.FloorRadius) < 35, "crater ascent remains walkable")
	end)
	t.test("stage translation preserves final coordinates and can be reversed", function()
		local final = Vector3.new(128, 12, -185)
		local staged = Geometry.toStage(final)
		t.eq(staged, final + Geometry.Settings.StageOffset)
		t.eq(Geometry.toFinal(staged), final)
		t.eq(Geometry.Settings.StageOffset, Vector3.zero, "the v2 map is authored at its final position")
	end)
	t.test("the spawn is in front of the Refinery and the shops flank the ring", function()
		local s = Geometry.Settings
		local spawn, refinery = Geometry.zone("Spawn"), Geometry.zone("Refinery")
		t.ok(spawn.z - spawn.depth / 2 > refinery.z + refinery.depth / 2, "spawn points are north of the Refinery")
		t.ok(refinery.entrance.Z > refinery.z + refinery.depth / 2, "the Refinery front (UsePoint) faces north, toward the spawn")
		t.ok(refinery.entrance.Z < spawn.z - spawn.depth / 2, "the UsePoint is between the Refinery and the spawn points")
		t.ok(refinery.width / 2 < s.SouthPlazaHalf, "Refinery sits inside the south plaza")
		t.ok(spawn.width / 2 <= s.SouthPlazaHalf, "spawn points stand on the south plaza")
		t.ok(spawn.z + spawn.depth / 2 < -(s.LoopRadius + s.PathWidth / 2), "spawn points stay south of the ring road")
		-- the angled shops: front looks toward the crater, rotated footprint is bounded by width/depth, door on T0
		for _, id in { "Hatchery", "Commissary", "LeaderboardEast", "LeaderboardRebirths", "LeaderboardPlaytime" } do
			local zone = Geometry.zone(id)
			t.near(zone.facing.Magnitude, 1, 1e-3, id .. " facing is a unit vector")
			local right = Vector3.new(zone.facing.Z, 0, -zone.facing.X)
			local halfX = math.abs(right.X) * zone.lat / 2 + math.abs(zone.facing.X) * zone.dep / 2
			local halfZ = math.abs(right.Z) * zone.lat / 2 + math.abs(zone.facing.Z) * zone.dep / 2
			t.ok(halfX <= zone.width / 2 + 0.5 and halfZ <= zone.depth / 2 + 0.5, id .. " footprint bound too small")
			t.ok(Vector3.new(zone.x, 0, zone.z):Dot(zone.facing) < 0, id .. " does not face the crater")
			t.ok((zone.entrance - Vector3.new(zone.x, 0, zone.z)):Dot(zone.facing) > zone.dep / 2, id .. " entrance is not in front")
			t.eq(Geometry.tierAt(zone.entrance.X, zone.entrance.Z), "T0", id .. " entrance off the town tier")
		end
		t.ok(Geometry.zone("Hatchery").x < 0 and Geometry.zone("LeaderboardEast").x > 0, "the Hatchery and the boards flank the spawn")
	end)
	t.test("the eight ore fields climb the tiers in unlock order", function()
		local tiers = { RustWorks = "T0", FrostYard = "T0", VioletQuarry = "T1", SulfurRidge = "T1", EmberShelf = "T2", GlassScar = "T2", Starfall = "Crown", HaloLedge = "Crown" }
		for id, tier in tiers do
			local zone = Geometry.zone(id)
			t.ok(zone.field, id .. " is not marked a field")
			t.eq(Geometry.tierAt(zone.x, zone.z), tier, id)
			t.eq(Geometry.tierAt(zone.entrance.X, zone.entrance.Z), tier, id .. " entrance")
		end
		t.eq(Geometry.zone("RustWorks").x, -Geometry.zone("FrostYard").x, "the T0 fields mirror")
		t.eq(Geometry.zone("VioletQuarry").x, -Geometry.zone("SulfurRidge").x, "the T1 fields mirror")
	end)
	t.test("tiers by distance, cliffs between them, the Crown on top", function()
		t.eq(Geometry.tierAt(0, -150), "T0")
		t.eq(Geometry.tierAt(0, 258), "Cliff")
		t.eq(Geometry.tierAt(0, 300), "T1")
		t.eq(Geometry.tierAt(366, 0), "Cliff")
		t.eq(Geometry.tierAt(0, -450), "T2")
		t.eq(Geometry.tierAt(0, 465), "Crown")
		t.eq(Geometry.tierAt(200, 465), "T2", "beside the Crown is T2")
		t.eq(Geometry.tierY("T1"), 16)
		t.eq(Geometry.tierY("Crown"), 56)
	end)
	t.test("spawn pads sit inside the spawn zone", function()
		local s, spawn = Geometry.Settings, Geometry.zone("Spawn")
		t.eq(#s.SpawnRowsZ * #s.SpawnColumnsX, 6)
		for _, z in s.SpawnRowsZ do
			t.ok(math.abs(z - spawn.z) <= spawn.depth / 2, "spawn row outside the spawn zone")
		end
		for _, x in s.SpawnColumnsX do
			t.ok(math.abs(x - spawn.x) <= spawn.width / 2, "spawn column outside the spawn zone")
		end
	end)
	t.test("boundary rejects below-map, outside and malformed positions", function()
		t.eq(Geometry.inside(Vector3.new(0, 3, 0)), true)
		t.eq(Geometry.inside(Vector3.new(539, -69, 539)), true)
		for _, point in { Vector3.new(541, 3, 0), Vector3.new(0, 3, -541), Vector3.new(0, -71, 0), Vector3.new(0/0, 3, 0), Vector3.new(math.huge, 3, 0) } do t.eq(Geometry.inside(point), false) end
		t.eq(Geometry.inside(nil), false)
		t.eq(Geometry.inside("position"), false)
	end)
end
