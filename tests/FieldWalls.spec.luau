--!strict
-- The walls round a locked field block: closed but for one gap in front of the gate, which can be on any side
return function(t)
	local FieldWalls = require(t.shared.FieldWalls)

	local function length(s: any): number
		return Vector2.new(s.x1 - s.x0, s.z1 - s.z0).Magnitude + s.grow
	end

	t.test("a gate on the near side leaves one GAP-wide opening centred on it", function()
		local list = FieldWalls.segments(30, 20, "z+", 4, 26)
		t.eq(#list, 7)
		local near = {}
		for _, s in list do if s.z0 == 20 and s.z1 == 20 then table.insert(near, s) end end
		t.eq(#near, 2)
		table.sort(near, function(a, b) return a.x0 < b.x0 end)
		t.near(near[2].x0 - near[1].x1, FieldWalls.HALF_GAP * 2, 1e-9, "opening width")
		t.near((near[1].x1 + near[2].x0) / 2, 4, 1e-9, "opening centred on the gate")
	end)

	t.test("the ring is closed: total wall length is the perimeter minus the opening plus the connectors", function()
		for _, side in { "z+", "z-", "x+", "x-" } do
			local D = if side:sub(1, 1) == "x" then 30 else 20
			local total = 0
			for _, s in FieldWalls.segments(30, 20, side, 0, D + 6) do total += length(s) end
			local connectors = 2 * ((D + 6 - .5) - (D + .5))
			t.near(total, 2 * (2 * 30) + 2 * (2 * 20) - 2 * FieldWalls.HALF_GAP + connectors, 1e-9, side)
		end
	end)

	t.test("a side gate opens the x side and runs its connectors out along x", function()
		local list = FieldWalls.segments(30, 50, "x-", -10, 36)
		local connectors = 0
		for _, s in list do
			if s.z0 == s.z1 and math.abs(s.x0) > 30 and math.abs(s.x1) > 30 then
				connectors += 1
				t.near(s.x1, -35.5, 1e-9, "reaches the barrier")
				t.near(math.abs(s.z0 + 10), FieldWalls.HALF_GAP, 1e-9, "at the opening's ends")
			end
		end
		t.eq(connectors, 2)
	end)

	t.test("refuses an opening past the corner or a barrier inside the walls", function()
		t.ok(not pcall(FieldWalls.segments, 30, 20, "z+", 20, 26))
		t.ok(not pcall(FieldWalls.segments, 30, 20, "z+", 0, 19))
	end)
end
