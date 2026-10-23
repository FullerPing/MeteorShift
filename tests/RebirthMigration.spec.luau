--!strict
-- Profile v13 to v14: old x5 rebirths become as many x2 rebirths as keep the sale multiplier at least as high.
return function(t: any)
	local Migration = require(t.lib.RebirthMigration)
	local Rebirth = require(t.shared.Rebirth)

	t.test("no rebirths and broken counts stay at 0", function()
		for _, saved in { 0, nil, -3, 0 / 0, "5" } do
			t.eq(Migration.rank(saved), 0)
		end
	end)

	t.test("every old rank becomes the smallest new rank that sells bars for at least as much", function()
		for old = 1, 30 do
			local new = Migration.rank(old)
			local was = Migration.oldMultiplier(old)
			t.ok(Rebirth.multiplier(new) >= was * (1 - 1e-9), "rank " .. old .. " -> " .. new .. " sells for less")
			t.ok(Rebirth.multiplier(new - 1) < was, "rank " .. old .. " -> " .. new .. " is not the smallest")
			t.ok(new >= old, "nobody loses a rank")
		end
		t.eq(Migration.rank(1), 3) -- x5 -> x8
		t.eq(Migration.rank(11), 26)
	end)
end
