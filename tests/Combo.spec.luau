--!strict
-- Spec for Shared.Combo: the mining combo. Values come from Config.Hooks.Combo.

return function(t: any)
	local Combo = require(t.shared.Combo)
	local Config = require(t.shared.Config)
	local Settings = Config.Hooks.Combo

	t.test("hits inside the window build the count, a pause starts it again", function()
		t.eq(Combo.next(0, nil, 10), 1)
		t.eq(Combo.next(4, 10, 10 + Settings.Window), 5)
		t.eq(Combo.next(4, 10, 10 + Settings.Window + 0.01), 1)
	end)

	t.test("every Step hits add Bonus, up to MaxSteps", function()
		t.eq(Combo.mult(1), 1)
		t.near(Combo.mult(Settings.Step), 1 + Settings.Bonus, 1e-9)
		local top = 1 + Settings.MaxSteps * Settings.Bonus
		t.near(Combo.mult(Settings.Step * Settings.MaxSteps), top, 1e-9)
		t.near(Combo.mult(1000), top, 1e-9)
	end)

	t.test("a fill takes fewer hits than without the combo, and never fewer than at the top multiplier", function()
		local top = 1 + Settings.MaxSteps * Settings.Bonus
		t.eq(Combo.fillHits(3, 1), 3, "too short to climb")
		for _, capacity in { 40, 400, 1e6 } do
			local hits = Combo.fillHits(capacity, 2)
			t.ok(hits < capacity / 2 and hits >= capacity / 2 / top, capacity .. " ore took " .. hits .. " hits")
		end
	end)
end
