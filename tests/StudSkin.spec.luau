--!strict
-- Spec for Shared.StudSkin: which runtime parts take the stud texture. Only
-- the pure surface (constants + eligible) is specced; `apply` mutates real
-- BaseParts (find/destroy a Texture child) and stays out of headless specs --
-- it is verified in Studio.

return function(t: any)
	local StudSkin = require(t.shared.StudSkin)

	t.test("the constants are usable", function()
		t.eq(type(StudSkin.Texture), "string")
		t.ok(string.find(StudSkin.Texture, "^rbxassetid:") == 1, "a Roblox asset reference")
		t.eq(StudSkin.Name, "SkinStuds", "apply and its removal share this child name")
		t.eq(type(StudSkin.MinArea), "number")
		t.ok(StudSkin.MinArea > 0, "the area threshold is positive")
	end)

	t.test("the area boundary is inclusive at MinArea", function()
		-- MinArea x 1 qualifies, one stud squared less does not
		local area = StudSkin.MinArea
		t.eq(StudSkin.eligible("Part", true, area, 1), true)
		t.eq(StudSkin.eligible("Part", true, area - 1, 1), false)
	end)

	t.test("all three conditions are required", function()
		t.eq(StudSkin.eligible("Part", true, 8, 8), true, "plain block Part, area 64")
		t.eq(StudSkin.eligible("Part", false, 8, 8), false, "a non-block shape can't carry a stud tile")
		t.eq(StudSkin.eligible("UnionOperation", true, 8, 8), false, "unions are skipped")
		t.eq(StudSkin.eligible("MeshPart", true, 8, 8), false, "meshes are skipped")
		t.eq(StudSkin.eligible("Part", true, 1, 3), false, "area 3 is below MinArea")
	end)

	t.test("area decides, not shape: a thin strip at the threshold qualifies", function()
		-- 1 x MinArea is the same area as MinArea x 1 and must agree with it
		local area = StudSkin.MinArea
		t.eq(StudSkin.eligible("Part", true, 1, area), true)
		t.eq(StudSkin.eligible("Part", true, 1, area - 1), false)
	end)
end
