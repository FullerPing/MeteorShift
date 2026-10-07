--!strict
return function(t)
	local Speed = require(t.shared.CharacterSpeed)

	t.test("pets add up to 30% of 16, never more", function()
		t.near((Speed.update(16, nil, nil, 0.1)), 17.6, 1e-9)
		t.near((Speed.update(16, nil, nil, 5)), 20.8, 1e-9)
	end)

	t.test("fast-walk multiplies the whole speed, pets included", function()
		local applied = Speed.update(16, nil, nil, 0.1, true)
		t.near(applied, 17.6 * Speed.FastMultiplier, 1e-9)
		t.near((Speed.update(16, nil, nil, 0, true)), 16 * Speed.FastMultiplier, 1e-9)
	end)

	t.test("turning it off restores the base speed that was remembered", function()
		local fastApplied, base = Speed.update(16, nil, nil, 0, true)
		local back = Speed.update(fastApplied, fastApplied, base, 0, false)
		t.near(back, 16, 1e-9)
	end)
end
