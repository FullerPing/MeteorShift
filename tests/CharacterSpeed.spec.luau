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

	t.test("a respawn starts from the humanoid default again, not a boosted speed", function()
		local applied, base = Speed.update(16, nil, nil, 0)
		t.near(base, 16, 1e-9)
		t.near((Speed.update(applied, applied, base, 0)), 16 * B, 1e-9)
	end)
end
