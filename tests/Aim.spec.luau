--!strict
-- Spec for Shared.Aim: which target the MINE button asks to swing at. Aim only
-- chooses; the server re-checks range on every swing (NodeService). These
-- cases pin the observable gates: reach and front are inclusive, the core
-- bonus only changes the score, never the gates, and ties keep the first pick.

return function(t: any)
	local Aim = require(t.shared.Aim)

	t.test("reach and front are inclusive boundaries", function()
		t.eq(Aim.nearest({ { distance = 12, dot = 0, core = false } }, 12, 0, 4), 1, "distance == range is in reach")
		t.eq(Aim.nearest({ { distance = 12.001, dot = 0, core = false } }, 12, 0, 4), nil, "a hair past the range is not")
		t.eq(Aim.nearest({ { distance = 5, dot = 0.5, core = false } }, 12, 0.5, 4), 1, "dot == frontDot is in front")
	end)

	t.test("a nearer target behind frontDot loses to a farther one in front", function()
		-- 2 studs away but dot 0.49 < frontDot 0.5; the 10-stud target has dot == 0.5 and wins alone
		local candidates = {
			{ distance = 2, dot = 0.49, core = false },
			{ distance = 10, dot = 0.5, core = false },
		}
		t.eq(Aim.nearest(candidates, 12, 0.5, 0), 2)
	end)

	t.test("coreBonus lets a farther core beat nearer crust, and 0 changes nothing", function()
		-- bonus 4: crust scores 5, core scores 8 - 4 = 4 -> index 2; bonus 0: 5 < 8 -> index 1
		local candidates = {
			{ distance = 5, dot = 0.9, core = false },
			{ distance = 8, dot = 0.9, core = true },
		}
		t.eq(Aim.nearest(candidates, 12, 0, 4), 2)
		t.eq(Aim.nearest(candidates, 12, 0, 0), 1)
	end)

	t.test("coreBonus never widens reach", function()
		-- distance 13 > range 12 gates the core out before any bonus is applied
		t.eq(Aim.nearest({ { distance = 13, dot = 1, core = true } }, 12, 0, 10), nil)
		t.eq(Aim.nearest({ { distance = 12, dot = 1, core = true } }, 12, 0, 10), 1, "in reach it is picked")
	end)

	t.test("equal scores keep the earliest index", function()
		-- both score 5: crust 5 - 0, core 9 - 4; the strict "<" never replaces the first pick
		local candidates = {
			{ distance = 5, dot = 1, core = false },
			{ distance = 9, dot = 1, core = true },
		}
		t.eq(Aim.nearest(candidates, 12, 0, 4), 1)
	end)

	t.test("empty or fully rejected lists pick nothing", function()
		t.eq(Aim.nearest({}, 12, 0, 4), nil)
		-- one behind (dot -0.01 < frontDot 0), one past the range (20 > 12)
		t.eq(Aim.nearest({
			{ distance = 3, dot = -0.01, core = false },
			{ distance = 20, dot = 1, core = false },
		}, 12, 0, 4), nil)
	end)
end
