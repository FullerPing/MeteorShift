--!strict
return function(t)
	local Layout = require(t.shared.SurfaceLayout)
	local Config = require(t.shared.Config)
	local FX = Config.SurfaceFX

	t.test("the same event lays out the same scene, another event a different one", function()
		local a = Layout.spokes(42, 9, 80, 40, 9)
		local b = Layout.spokes(42, 9, 80, 40, 9)
		local c = Layout.spokes(43, 9, 80, 40, 9)
		t.eq(#a, 9)
		for i = 1, 9 do
			t.eq(a[i].angle, b[i].angle)
			t.eq(a[i].bend, b[i].bend)
		end
		t.ok(a[1].angle ~= c[1].angle)
	end)

	t.test("spokes are spread round the circle, never stacked", function()
		for seed = 1, 20 do
			local spokes = Layout.spokes(seed, 9, 80, 40, 9)
			local angles = {}
			for _, spoke in spokes do table.insert(angles, spoke.angle % (math.pi * 2)) end
			table.sort(angles)
			for i = 1, #angles do
				local nextAngle = if i == #angles then angles[1] + math.pi * 2 else angles[i + 1]
				t.ok(nextAngle - angles[i] > 0.15, "seed " .. seed .. " spoke gap " .. (nextAngle - angles[i]))
			end
		end
	end)

	t.test("a spoke's points run from its outer end to its inner end and stay on the floor and slope", function()
		local spoke = Layout.spokes(7, 9, FX.Alien.Tendrils.From, FX.Alien.Tendrils.To, FX.Alien.Tendrils.Bend)[1]
		local points = Layout.points(spoke, FX.Alien.Tendrils.Steps)
		t.eq(#points, FX.Alien.Tendrils.Steps + 1)
		t.near(points[1].radius, spoke.from, 1e-9)
		t.near(points[#points].radius, spoke.to, 1e-9)
		t.near(points[1].angle, spoke.angle, 1e-9, "ends stay on the spoke's own angle")
		t.near(points[#points].angle, spoke.angle, 1e-6)
		for _, point in points do
			t.ok(point.radius > 30 and point.radius < Config.LandingFX.Crater.OpeningRadius, "radius " .. point.radius)
		end
	end)

	t.test("hovering rocks stay in their radius, height and size ranges", function()
		local rocks = FX.Alien.Rocks
		for _, rock in Layout.rocks(5, rocks.Count, rocks.Radius, rocks.Height, rocks.Size, rocks.Period) do
			t.ok(rock.radius >= rocks.Radius[1] and rock.radius <= rocks.Radius[2])
			t.ok(rock.height >= rocks.Height[1] and rock.height <= rocks.Height[2])
			t.ok(rock.size >= rocks.Size[1] and rock.size <= rocks.Size[2])
			t.ok(rock.period >= rocks.Period[1] and rock.period <= rocks.Period[2])
		end
	end)

	t.test("scenes stay outside the meteor and inside the crater opening", function()
		local opening = Config.LandingFX.Crater.OpeningRadius
		t.ok(FX.Alien.Tendrils.To >= 38 and FX.Alien.Tendrils.From <= opening)
		t.ok(FX.Iron.Cracks.From >= 38 and FX.Iron.Cracks.To <= opening)
		t.ok(FX.Iron.Vents.Radius <= Config.LandingFX.Crater.FloorRadius + 5)
		t.ok(FX.Alien.Rocks.Radius[1] >= 38)
	end)

	t.test("scene sizes stay bounded", function()
		t.ok(FX.Alien.Tendrils.Count * FX.Alien.Tendrils.Steps <= 80, "tendril beams")
		t.ok(FX.Alien.Rocks.Count <= 12)
		t.ok(FX.Iron.Cracks.Count * FX.Iron.Cracks.Steps <= 90, "crack parts")
		t.ok(FX.Mobile.Scale > 0 and FX.Mobile.Scale < 1)
		t.ok(FX.Alien.Pulses.Count <= 4 and FX.Ice.Halo.Count <= 3)
	end)
end
