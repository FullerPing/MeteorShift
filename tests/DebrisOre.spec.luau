--!strict
-- Cyan debris represents Frost ore. Other debris keeps its existing ore rule.

return function(t: any)
	local DebrisOre = require(t.shared.DebrisOre)

	t.test("cyan tiers mine Frost ore", function()
		t.eq(DebrisOre.forTier(3), "frost")
		t.eq(DebrisOre.forTier(4), "frost")
	end)

	t.test("other coloured debris keeps Iron ore", function()
		for _, tier in { 1, 2, 5, 6, 7, 8 } do
			t.eq(DebrisOre.forTier(tier), "iron")
		end
	end)

	t.test("a rock without a sized tier uses the default debris ore", function()
		t.eq(DebrisOre.forTier(nil), "iron")
	end)
end
