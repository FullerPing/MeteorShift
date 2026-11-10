--!strict
-- Profile v13 to v14: saved cash is divided by the old x3-per-rebirth price multiplier; the rebirth count stays.
return function(t: any)
	local Migration = require(t.lib.CashMigration)

	t.test("the old price multiplier was x3 a rank for 16 ranks, then x1.2", function()
		t.eq(Migration.oldPriceMult(0), 1)
		t.eq(Migration.oldPriceMult(8), 3 ^ 8)
		t.near(Migration.oldPriceMult(20), 3 ^ 16 * 1.2 ^ 4, 1e-3)
		for _, bad in { nil, -2, 0 / 0, "5" } do t.eq(Migration.oldPriceMult(bad), 1) end
	end)

	t.test("cash buys what it did: divided by the old multiplier, never negative", function()
		t.eq(Migration.convert(1000, 0), 1000)
		t.eq(Migration.convert(6561e6, 8), 1e6)
		t.eq(Migration.convert(10, 8), 0)
		for _, bad in { nil, -50, 0 / 0, "100" } do t.eq(Migration.convert(bad, 3), 0) end
	end)
end
