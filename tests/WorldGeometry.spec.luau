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
	t.test("compact layout reduces travel while preserving usable full-size landmarks", function()
		t.eq(Geometry.Settings.BoundaryHalf, 270)
		t.ok(Geometry.Settings.BoundaryHalf / 510 <= 0.54, "about half the previous playable width")
		t.eq(Geometry.Settings.BuildingScale, 0.5)
		t.eq(Geometry.zone("GearHall").width, 50)
		t.eq(Geometry.zone("Hatchery").width, 64)
		local zones = Geometry.Settings.Zones
		for i, a in zones do
			for j = i + 1, #zones do
				local b = zones[j]
				t.ok(math.abs(a.x-b.x) >= (a.width+b.width)/2 or math.abs(a.z-b.z) >= (a.depth+b.depth)/2, a.id .. " overlaps " .. b.id)
			end
		end
	end)
	t.test("Crystal crown remains visible above the doubled crust at its largest flash", function()
		local crater = Config.LandingFX.Crater
		local gem = Config.LandingFX.Types.Crystal.Gem
		local largestCube = math.max(10, gem.Size, gem.Pulse[2], gem.UnlockedPulse[2])
		local lowestCorner = crater.Center.Y + gem.Height - largestCube * math.sqrt(3) / 2
		local measuredCrustTop = 52.642014 + crater.Center.Y - 2
		t.ok(lowestCorner > measuredCrustTop + 1, "crown gem is buried in the double-sized crust")
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
		local crater = Config.LandingFX.Crater
		t.ok(Geometry.rampAngle(-crater.FloorY, crater.OpeningRadius-crater.FloorRadius) < 35, "crater ascent remains walkable")
	end)
	t.test("stage translation preserves final coordinates and can be reversed", function()
		local final = Vector3.new(128, 12, -185)
		local staged = Geometry.toStage(final)
		t.eq(staged, Vector3.new(128, 12, 2815))
		t.eq(Geometry.toFinal(staged), final)
	end)
	t.test("boundary rejects below-map, outside and malformed positions", function()
		t.eq(Geometry.inside(Vector3.new(0, 3, 0)), true)
		t.eq(Geometry.inside(Vector3.new(269, -69, 269)), true)
		for _, point in { Vector3.new(271, 3, 0), Vector3.new(0, 3, -271), Vector3.new(0, -71, 0), Vector3.new(0/0, 3, 0), Vector3.new(math.huge, 3, 0) } do t.eq(Geometry.inside(point), false) end
		t.eq(Geometry.inside(nil), false)
		t.eq(Geometry.inside("position"), false)
	end)
end
