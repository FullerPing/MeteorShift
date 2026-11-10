--!strict
-- Spec for Shared.Income: grant = `seconds` of income, floored to whole cash,
-- clamped between floor and ceiling, with the ceiling (never negative) winning
-- over the floor. DebrisField.spec covers the happy path; this covers the
-- guard rails: negative floors, dead ceilings and the never-negative/never-
-- above-ceiling totality.

return function(t: any)
	local Income = require(t.shared.Income)

	t.test("a negative floor never pays negative cash", function()
		t.eq(Income.grant(0, 1, -50, 1000), 0, "no income with floor -50 pays 0, not -50")
		t.eq(Income.grant(1, 3, -50, 1000), 3, "a negative floor does not lift raw 1*3=3")
	end)

	t.test("a ceiling at or below zero switches the grant off", function()
		t.eq(Income.grant(10, 5, 20, 0), 0, "cap 0 beats floor 20 (ceiling wins)")
		t.eq(Income.grant(10, 5, 20, -100), 0, "negative ceiling clamps to cap 0")
	end)

	t.test("a floor under the ceiling is the guaranteed minimum", function()
		-- raw 1*0.001 = 0.001, floor 25 <= cap 500 -> pays the floor
		t.eq(Income.grant(1, 0.001, 25, 500), 25)
	end)

	t.test("whole cash only, ceiling applied before flooring", function()
		t.eq(Income.grant(1, 1.999, 0, 100), 1, "1.999 pays 1")
		t.eq(Income.grant(4, 0.75, 0, 100), 3, "exact 4*0.75 = 3 pays 3")
		t.eq(Income.grant(7, 2, 0, 12), 12, "raw 14 is capped to 12, not paid")
	end)

	t.test("grant is always between 0 and the ceiling, for any inputs", function()
		for _, seconds in { -3, 0, 2, 40 } do
			for _, perSecond in { -5, 0, 1.5, 1e9 } do
				for _, floor in { -100, 0, 30 } do
					local paid = Income.grant(seconds, perSecond, floor, 60)
					t.ok(paid >= 0 and paid <= 60,
						string.format("s=%s ps=%s floor=%s paid=%s", seconds, perSecond, floor, paid))
				end
			end
		end
	end)
end
