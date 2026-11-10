--!strict
return function(t)
	local Speed = require(t.shared.CharacterSpeed)
	local B = Speed.BaseMultiplier

	t.test("everyone starts at the base multiplier", function()
		t.near((Speed.update(16, nil, nil, 0)), 16 * B, 1e-9)
	end)

	t.test("pets add up to 30% of 16, never more", function()
		t.near((Speed.update(16, nil, nil, 0.1)), 17.6 * B, 1e-9)
		t.near((Speed.update(16, nil, nil, 5)), 20.8 * B, 1e-9)
	end)

	t.test("sprint multiplies the whole speed, pets included", function()
		local applied = Speed.update(16, nil, nil, 0.1, true)
		t.near(applied, 17.6 * B * Speed.FastMultiplier, 1e-9)
		t.near((Speed.update(16, nil, nil, 0, true)), 16 * B * Speed.FastMultiplier, 1e-9)
	end)

	t.test("turning it off restores the base speed that was remembered", function()
		local fastApplied, base = Speed.update(16, nil, nil, 0, true)
		local back = Speed.update(fastApplied, fastApplied, base, 0, false)
		t.near(back, 16 * B, 1e-9)
	end)

	t.test("the ring road is a fast lane, and sprint stacks on it", function()
		t.near((Speed.update(16, nil, nil, 0, false, true)), 16 * B * Speed.RoadMultiplier, 1e-9)
		t.near((Speed.update(16, nil, nil, 0, true, true)), 16 * B * Speed.RoadMultiplier * Speed.FastMultiplier, 1e-9)
		local roadApplied, base = Speed.update(16, nil, nil, 0, false, true)
		t.near((Speed.update(roadApplied, roadApplied, base, 0, false, false)), 16 * B, 1e-9)
	end)

	t.test("stepping on and off a road never compounds, though WalkSpeed reads back as a float32", function()
		local function float32(x: number): number return (string.unpack("f", string.pack("f", x))) end
		local applied, base = Speed.update(16, nil, nil, 0.3, true, true)
		for i = 1, 6 do
			applied, base = Speed.update(float32(applied), applied, base, 0.3, true, i % 2 == 1) -- ends off the road
		end
		t.near(applied, 20.8 * B * Speed.FastMultiplier, 1e-6)
		t.near(base, 16, 1e-9)
	end)

	t.test("the ring road, the Express and the avenues are fast lanes", function()
		local G = require(t.shared.WorldGeometry).Settings
		t.eq(Speed.onRoad(G.LoopRadius, 0), true)
		t.eq(Speed.onRoad(0, -G.LoopRadius - G.PathWidth / 2), true)
		t.eq(Speed.onRoad(0, 280), true) -- the Terrace Express
		t.eq(Speed.onRoad(300 * math.cos(math.rad(45)), 300 * math.sin(math.rad(45))), true) -- the NE avenue
		t.eq(Speed.onRoad(-450, 8), true) -- the west avenue, near its edge
		t.eq(Speed.onRoad(0, -250), true) -- the south avenue past the Refinery
	end)

	t.test("everything else is not road", function()
		t.eq(Speed.onRoad(0, 0), false) -- the crater
		t.eq(Speed.onRoad(0, -150), false) -- the spawn plaza
		t.eq(Speed.onRoad(0, -177), false) -- the Refinery
		t.eq(Speed.onRoad(200, 50), false) -- the middle of a T0 slice
		t.eq(Speed.onRoad(0, 450), false) -- on the Crown, past the north avenue's end
		t.eq(Speed.onRoad(-450, 30), false) -- beside the west avenue
	end)

	t.test("the avenues stop where their paving stops", function()
		t.eq(Speed.onRoad(0, -280), true, "south avenue on T1")
		t.eq(Speed.onRoad(0, -320), false, "the Rebirth Terrace is not a lane")
		t.eq(Speed.onRoad(0, -450), false, "nor T2 beyond it")
		t.eq(Speed.onRoad(0, 420), false, "the Crown is not a lane")
	end)

	t.test("a respawn starts from the humanoid default again, not a boosted speed", function()
		local applied, base = Speed.update(16, nil, nil, 0)
		t.near(base, 16, 1e-9)
		t.near((Speed.update(applied, applied, base, 0)), 16 * B, 1e-9)
	end)
end
