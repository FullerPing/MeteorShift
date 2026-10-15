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

	t.test("only the ring road counts as the road", function()
		local G = require(t.shared.WorldGeometry).Settings
		t.eq(Speed.onRoad(G.LoopRadius, 0), true)
		t.eq(Speed.onRoad(0, -G.LoopRadius - G.PathWidth / 2), true)
		t.eq(Speed.onRoad(0, 0), false) -- the crater
		t.eq(Speed.onRoad(0, -150), false) -- the spawn plaza
		t.eq(Speed.onRoad(G.LoopRadius + 30, 0), false) -- out in a field
	end)

	t.test("a respawn starts from the humanoid default again, not a boosted speed", function()
		local applied, base = Speed.update(16, nil, nil, 0)
		t.near(base, 16, 1e-9)
		t.near((Speed.update(applied, applied, base, 0)), 16 * B, 1e-9)
	end)
end
