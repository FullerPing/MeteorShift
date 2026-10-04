--!strict
-- Debris is filler (spec §5.7): every rock drops the default ore whatever its tier or tint.

return function(t: any)
	local DebrisOre = require(t.shared.DebrisOre)

	t.test("every tier of debris drops Iron, cyan rocks included", function()
		for tier = 1, 8 do
			t.eq(DebrisOre.forTier(tier), "iron")
		end
	end)

	t.test("a rock without a sized tier uses the default debris ore", function()
		t.eq(DebrisOre.forTier(nil), "iron")
	end)
end
