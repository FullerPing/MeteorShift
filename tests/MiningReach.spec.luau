--!strict
-- Spec for Shared.MiningReach: the swing distance to a target's box, and the upward reach that lets a player on the
-- crater floor hit the meteor's crown.

return function(t: any)
	local MiningReach = require(t.shared.MiningReach)

	local size = Vector3.new(4, 4, 4)
	local box = CFrame.new(0, 0, 0)

	t.test("a point inside the box is at distance 0", function()
		t.eq(MiningReach.distance(box, size, Vector3.new(1, 1, 1), 0), 0)
	end)

	t.test("distance is to the nearest face, edge or corner", function()
		t.near(MiningReach.distance(box, size, Vector3.new(5, 0, 0), 0), 3, 1e-6)
		t.near(MiningReach.distance(box, size, Vector3.new(5, 5, 0), 0), math.sqrt(18), 1e-6)
	end)

	t.test("the box's rotation is respected", function()
		local turned = CFrame.Angles(0, math.rad(45), 0)
		t.near(MiningReach.distance(turned, size, Vector3.new(5, 0, 0), 0), 5 - math.sqrt(8), 1e-6)
	end)

	t.test("upward reach counts the swing from up to `lift` studs higher", function()
		local high = CFrame.new(0, 20, 0) -- box spans Y 18..22
		t.near(MiningReach.distance(high, size, Vector3.new(0, 0, 0), 0), 18, 1e-6)
		t.near(MiningReach.distance(high, size, Vector3.new(0, 0, 0), 12), 6, 1e-6)
		t.near(MiningReach.distance(high, size, Vector3.new(0, 0, 0), 30), 0, 1e-6)
	end)

	t.test("upward reach never helps a target below the player", function()
		local low = CFrame.new(0, -10, 0)
		t.near(MiningReach.distance(low, size, Vector3.new(0, 0, 0), 20), 8, 1e-6)
	end)

	t.test("only meteor targets reach upward", function()
		t.eq(MiningReach.lift("Crust", 18), 18)
		t.eq(MiningReach.lift("Core", 18), 18)
		t.eq(MiningReach.lift("Debris", 18), 0)
		t.eq(MiningReach.lift(nil, 18), 0)
	end)
end
