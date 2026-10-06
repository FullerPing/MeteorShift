--!strict
-- World access and effect clearance are geometric contracts, not mining-rule changes.
return function(t: any)
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
		t.eq(Config.Meteor.Knockback.Radius, 180)
		t.eq(Config.Tutorial.CraterRadius, 160)
	end)
	t.test("crater geometry agrees with the scene contracts", function()
		local crater = Config.LandingFX.Crater
		t.eq(crater.FloorY, -44)
		t.eq(crater.FloorRadius, 90)
		t.eq(crater.OpeningRadius, 160)
		t.eq(crater.Center, Vector3.new(0, 5.3, 0))
		t.ok(crater.ProbeDepth >= 160, "floor probe reaches the deep bowl")
	end)
	t.test("enlarged landing geometry fits between mining access and the outer service zones", function()
		local ice, crystal = Config.LandingFX.Types.Ice, Config.LandingFX.Types.Crystal
		t.eq(ice.Sheet.Diameter, 164)
		t.eq(crystal.Shimmer.Diameter, 156)
		t.eq(ice.Fingers.Inner, 170)
		t.eq(ice.Fingers.Length[2], 140)
		t.ok(ice.Fingers.Inner + ice.Fingers.Length[2] <= Geometry.Settings.LandingRadius)
		for _, fx in { ice, crystal } do
			for _, radius in fx.Clusters.Radii do
				t.ok(radius - fx.Clusters.Footprint >= 160, "upright landmark inside mining opening")
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
		t.near(Geometry.footprintDistance(Geometry.zone("Refinery")), 348, 1e-6)
	end)
	t.test("rectangular clearance uses the closest corner rather than centre", function()
		t.near(Geometry.footprintDistance({ x = 275, z = 270, width = 100, depth = 92 }), math.sqrt(225^2 + 224^2), 1e-6)
		t.eq(Geometry.footprintDistance({ x = 2, z = 2, width = 10, depth = 10 }), 0)
	end)
	t.test("every zone has a walkable entrance and wide paths", function()
		t.ok(Geometry.Settings.PathWidth >= 14)
		t.ok(Geometry.Settings.MainPathWidth >= 14)
		for _, zone in Geometry.Settings.Zones do
			t.eq(typeof(zone.entrance), "Vector3", zone.id .. " entrance")
			t.ok(zone.pathWidth >= 14, zone.id .. " narrow path")
		end
		t.ok(Geometry.Settings.CraterRampWidth >= 14)
		t.ok(Geometry.rampAngle(44, 70) < 35, "crater ascent remains walkable")
	end)
	t.test("stage translation preserves final coordinates and can be reversed", function()
		local final = Vector3.new(140, 12, -380)
		local staged = Geometry.toStage(final)
		t.eq(staged, Vector3.new(140, 12, 2620))
		t.eq(Geometry.toFinal(staged), final)
	end)
	t.test("boundary rejects below-map, outside and malformed positions", function()
		t.eq(Geometry.inside(Vector3.new(0, 3, 0)), true)
		t.eq(Geometry.inside(Vector3.new(509, -69, 509)), true)
		for _, point in { Vector3.new(511, 3, 0), Vector3.new(0, 3, -511), Vector3.new(0, -71, 0), Vector3.new(0/0, 3, 0), Vector3.new(math.huge, 3, 0) } do t.eq(Geometry.inside(point), false) end
		t.eq(Geometry.inside(nil), false)
		t.eq(Geometry.inside("position"), false)
	end)
end
