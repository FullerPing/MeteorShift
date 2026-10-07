--!strict
-- Dimensional outcomes for the meteor spectacle. Fixtures are hand-derived from
-- the original spectacle and the requested world scale, not from helper output.
return function(t: any)
	local module = t.shared:FindFirstChild("MeteorVisualGeometry")
	t.test("shared meteor spectacle geometry exists", function()
		t.ok(module, "MeteorVisualGeometry missing")
	end)
	if not module then return end
	local Geometry = require(module)

	t.test("a doubled approach reaches its target with a doubled silhouette and trail span", function()
		local fx = Geometry.build(2, 180)
		local target = Vector3.new(10, 30, -20)
		t.eq(target + fx.Streak.Offset, Vector3.new(-830, 1070, 500), "approach enters the enlarged sky")
		t.eq(fx.Streak.StartSize, Vector3.new(32, 32, 32))
		t.eq(fx.Streak.EndSize, Vector3.new(44, 44, 44))
		t.near((fx.Streak.TrailTop - fx.Streak.TrailBottom).Magnitude, 24, 1e-6, "trail spans the doubled fireball")
		t.eq(target + fx.Streak.TrailTop, Vector3.new(10, 42, -20))
		t.eq(target + fx.Streak.TrailBottom, Vector3.new(10, 18, -20))
		t.near(fx.Streak.LightRange, 120, 1e-6, "illumination reaches the doubled distance")
	end)

	t.test("approach flame and smoke retain their shape over twice the travel distance", function()
		local fx = Geometry.build(2, 180).Streak
		local flame, smoke = fx.FlameSize.Keypoints, fx.SmokeSize.Keypoints
		t.near(flame[1].Value, 60, 1e-6, "full flame width")
		t.near(flame[#flame].Value, 12, 1e-6, "dying flame width")
		t.near(smoke[1].Value, 16, 1e-6)
		t.near(smoke[#smoke].Value, 40, 1e-6)
		-- At half a second, the fastest flame has moved 25 studs; smoke 5.
		t.near(fx.FlameSpeed.Max * 0.5, 25, 1e-6)
		t.near(fx.FlameSpeed.Min * 0.5, 12, 1e-6)
		t.near(fx.SmokeSpeed.Max * 0.5, 5, 1e-6)
		t.near(fx.SmokeSpeed.Min * 0.5, 2, 1e-6)
	end)

	t.test("impact fills the doubled ground and dust volume around the same world position", function()
		local fx = Geometry.build(2, 117).Impact
		local position = Vector3.new(10, 30, -20)
		local crater = {FloorY=-14.755,FloorRadius=55.25,OpeningRadius=83.2,RimY=0}
		local ring = Geometry.groundRingPosition(position, 8, fx.RingStartSize.X, crater)
		t.near(ring.Y, -13.715, 1e-4, "raised core does not raise the ground shockfront")
		t.eq(Vector2.new(ring.X, ring.Z), Vector2.new(10, -20))
		t.eq(fx.RingStartSize, Vector3.new(2, 16, 16))
		t.eq(fx.RingEndSize, Vector3.new(2, 234, 234))
		t.eq(fx.FlashStartSize, Vector3.new(20, 20, 20))
		t.eq(fx.FlashEndSize, Vector3.new(140, 140, 140))
		t.eq(fx.DustAnchorSize, Vector3.new(80, 2, 80))
		local dust = fx.DustSize.Keypoints
		t.near(dust[1].Value, 16, 1e-6)
		t.near(dust[#dust].Value, 52, 1e-6)
		-- Same lifetime, twice the outward distance: fastest dust covers 450 in 5s.
		t.near(fx.DustSpeed.Max * 5, 450, 1e-6)
		t.near(fx.DustSpeed.Min * 3, 120, 1e-6)
	end)

	t.test("the shockwave edge follows the configured radius without scaling it a second time", function()
		local fx = Geometry.build(3, 80).Impact
		t.near(fx.RingEndSize.Y / 2, 80, 1e-6)
		t.near(fx.RingEndSize.Z / 2, 80, 1e-6)
		t.near(fx.RingEndSize.X, 3, 1e-6, "thickness still follows visual scale")
	end)
	t.test("shockfront follows floor bowl and streamed ground independently of meteor height", function()
		local crater = {FloorY=-14.755,FloorRadius=55.25,OpeningRadius=83.2,RimY=0}
		local impact = Vector3.new(0,35.4,3000)
		t.near(Geometry.groundRingPosition(impact, 117, 2, crater).Y, 1.04, 1e-4)
		t.near(Geometry.groundRingPosition(impact, 69.225, 2, crater).Y, -6.3375, 1e-4)
		local samples = {{radius=0,y=-15},{radius=60,y=-10},{radius=100,y=0}}
		t.near(Geometry.groundRingPosition(impact, 80, 2, crater, samples).Y, -3.96, 1e-4)
		t.near(Geometry.groundRingPosition(impact, 120, 2, crater, samples).Y, 1.04, 1e-4)
	end)
	t.test("missing outer streamed ground falls back to the crater rim", function()
		local crater = {FloorY=-14.755,FloorRadius=55.25,OpeningRadius=83.2,RimY=0}
		local floorOnly = {{radius=8,y=-14.755},{radius=52,y=-14.755}}
		t.near(Geometry.groundRingPosition(Vector3.new(0,35.4,3000),117,2,crater,floorOnly).Y,1.04,1e-4)
	end)

	t.test("core shards preserve their ballistic shape at double scale", function()
		local fx = Geometry.build(2, 180).Core
		t.eq(fx.StartSize, Vector3.new(28, 28, 28))
		t.eq(fx.EndSize, Vector3.new(120, 120, 120))
		local shard = fx.ShardsSize.Keypoints
		t.near(shard[1].Value, 2.4, 1e-6)
		t.near(shard[#shard].Value, 0, 1e-6)
		-- A horizontal shard, one second later, travels 160 and drops 50 studs.
		local displacement = Vector3.xAxis * fx.ShardsSpeed.Max + fx.ShardsAcceleration * 0.5
		t.eq(displacement, Vector3.new(160, -50, 0))
		t.near(fx.ShardsSpeed.Min, 80, 1e-6)
	end)

	t.test("shake falls off over doubled distance while remaining clamped at both ends", function()
		local fx = Geometry.build(2, 180).Shake
		t.near(Geometry.falloff(125, fx.ImpactRadius), 0.75, 1e-6)
		t.near(Geometry.falloff(250, fx.ImpactRadius), 0.5, 1e-6)
		t.near(Geometry.falloff(200, fx.CoreRadius), 0.5, 1e-6)
		t.eq(Geometry.falloff(0, fx.ImpactRadius), 1)
		t.eq(Geometry.falloff(500, fx.ImpactRadius), 0)
		t.eq(Geometry.falloff(1000, fx.ImpactRadius), 0)
	end)

	t.test("meteor sound reach scales independently of shockwave range", function()
		local full = Geometry.build(2, 180).Sound
		local small = Geometry.build(0.5, 80).Sound
		t.near(full.minDistance, 20, 1e-6)
		t.near(full.maxDistance, 2000, 1e-6)
		t.near(small.minDistance, 5, 1e-6)
		t.near(small.maxDistance, 500, 1e-6)
	end)

	t.test("fractional scaling also transforms travel, width and acceleration", function()
		local fx = Geometry.build(0.5, 45)
		t.eq(fx.Streak.Offset, Vector3.new(-210, 260, 130))
		t.eq(fx.Streak.StartSize, Vector3.new(8, 8, 8))
		t.eq(fx.Impact.DustAnchorSize, Vector3.new(20, 0.5, 20))
		t.eq(fx.Core.ShardsAcceleration, Vector3.new(0, -25, 0))
		t.near(Geometry.falloff(62.5, fx.Shake.ImpactRadius), 0.5, 1e-6)
	end)
end
