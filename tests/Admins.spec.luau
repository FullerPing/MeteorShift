--!strict
return function(t: any)
	local Admins = require(t.lib.Admins)
	local list = { [111] = "Owner" }

	t.test("a live server allows only listed user ids", function()
		t.eq(Admins.can(111, false, list), true)
		t.eq(Admins.can(222, false, list), false)
		t.eq(Admins.can(0, false, list), false)
	end)

	t.test("Studio allows everyone", function()
		t.eq(Admins.can(222, true, list), true)
	end)

	t.test("the shipped list is non-empty and keyed by user id", function()
		local count = 0
		for userId, name in Admins.List do
			t.ok(type(userId) == "number" and userId > 0, "bad id")
			t.ok(type(name) == "string" and name ~= "", "bad name")
			count += 1
		end
		t.ok(count >= 1)
	end)
end
