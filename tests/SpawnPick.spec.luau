--!strict
-- Spec for Shared.SpawnPick: the free pad nearest the portal.
return function(t: any)
	local SpawnPick = require(t.shared.SpawnPick)
	-- Nebula Rift's six pads and its portal
	local pads = { { x = 0, z = -212 }, { x = -18, z = -226 }, { x = 18, z = -212 }, { x = 18, z = -226 }, { x = 0, z = -226 }, { x = -18, z = -212 } }
	local portal = { x = 0, z = -269 }

	t.test("an empty plaza: the middle pad by the portal", function()
		t.eq(SpawnPick.choose(pads, portal, {}, 4), 5)
	end)

	t.test("someone on it: the next nearest free pad", function()
		local next = SpawnPick.choose(pads, portal, { { x = 1, z = -225 } }, 4) :: number
		t.ok(next == 2 or next == 4, "a side pad on the portal row, got " .. next)
		t.eq(SpawnPick.choose(pads, portal, { { x = 0, z = -226 }, { x = -18, z = -226 }, { x = 18, z = -226 } }, 4), 1)
	end)

	t.test("all taken: the nearest anyway; no pads: nil", function()
		local everyone = {}
		for _, pad in pads do table.insert(everyone, pad) end
		t.eq(SpawnPick.choose(pads, portal, everyone, 4), 5)
		t.eq(SpawnPick.choose({}, portal, {}, 4), nil)
	end)
end
