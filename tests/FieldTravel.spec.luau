--!strict
return function(t)
	local FieldTravel = require(t.shared.FieldTravel)
	local StudSkin = require(t.shared.StudSkin)
	local Config = require(t.shared.Config)

	t.test("the four ore fields are valid travel targets and nothing else is", function()
		t.eq(#Config.Debris.Fields, 4)
		for _, field in Config.Debris.Fields do
			t.ok(FieldTravel.find(field.Id), field.Id)
		end
		t.eq(FieldTravel.find("Refinery"), nil)
		t.eq(FieldTravel.find(42), nil)
		t.eq(FieldTravel.find(nil), nil)
	end)

	t.test("the field ids match the world zones", function()
		local Geometry = require(t.shared.WorldGeometry)
		for _, field in Config.Debris.Fields do
			t.ok(Geometry.zone(field.Id), field.Id)
		end
	end)

	t.test("landing prefers the centre and walks to the next clear aisle spot", function()
		local dx, dz = FieldTravel.pick(function() return true end)
		t.eq(dx, 0)
		t.eq(dz, 0)
		local x, z = FieldTravel.pick(function(a, b) return not (a == 0 and b == 0) end)
		t.eq(x, 11)
		t.eq(z, 11)
	end)

	t.test("a field with no clear spot falls back to the centre", function()
		local x, z = FieldTravel.pick(function() return false end)
		t.eq(x, 0)
		t.eq(z, 0)
	end)

	t.test("only big plain block parts take the stud texture", function()
		t.eq(StudSkin.eligible("Part", true, 8, 8), true)
		t.eq(StudSkin.eligible("Part", false, 8, 8), false)
		t.eq(StudSkin.eligible("UnionOperation", true, 8, 8), false)
		t.eq(StudSkin.eligible("MeshPart", true, 8, 8), false)
		t.eq(StudSkin.eligible("Part", true, 3, 3), false)
	end)
end
