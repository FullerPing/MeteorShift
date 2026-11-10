--!strict
-- The Meteor Dive: a ballistic launch from the Crown that peaks a set height above the pad and lands on a target
return function(t)
	local DiveArc = require(t.shared.DiveArc)
	local Config = require(t.shared.Config)

	-- step the launch at 240 Hz and report the highest point and where it comes back down to the target's height
	local function fly(from: Vector3, velocity: Vector3, gravity: number, floorY: number): (number, Vector3)
		local p, v, top = from, velocity, from.Y
		for _ = 1, 240 * 20 do
			local dt = 1 / 240
			v -= Vector3.new(0, gravity * dt, 0)
			p += v * dt
			top = math.max(top, p.Y)
			if v.Y < 0 and p.Y <= floorY then return top, p end
		end
		return top, p
	end

	t.test("the Crown dive peaks its apex above the pad and lands on the crater's north rim", function()
		local from, to = Vector3.new(-30, 60, 475), Vector3.new(0, 4, 96)
		local velocity = DiveArc.velocity(from, to, 60, 196.2)
		local top, landed = fly(from, velocity, 196.2, to.Y)
		t.ok(top >= from.Y + 59.5 and top <= from.Y + 60.5, "apex " .. top)
		t.ok(math.abs(landed.X - to.X) <= 3 and math.abs(landed.Z - to.Z) <= 3, ("landed %.1f, %.1f"):format(landed.X, landed.Z))
	end)

	t.test("a launch from below the target still clears it", function()
		local from, to = Vector3.new(0, 0, 0), Vector3.new(50, 20, 0)
		local top, landed = fly(from, DiveArc.velocity(from, to, 40, 196.2), 196.2, to.Y)
		t.ok(top >= 39.5, "apex")
		t.ok(math.abs(landed.X - 50) <= 2, "landed " .. landed.X)
	end)

	t.test("the dive lands outside the crater mouth and inside the ring road", function()
		local target = Config.Crown.DiveTarget
		local r = Vector3.new(target.X, 0, target.Z).Magnitude
		t.ok(r > Config.LandingFX.Crater.OpeningRadius + 6, "lands in the crater")
		t.ok(r < 134 - 9, "lands on the ring road")
		t.eq(Config.Crown.LiftRebirths, 1)
	end)
end
