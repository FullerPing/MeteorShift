--!strict
return function(t)
	local SafeLoop = require(t.lib.SafeLoop) :: any

	t.test("a passing step returns true and passes its arguments", function()
		local seen = nil
		t.eq(SafeLoop.step("spec", function(a) seen = a end, 7), true)
		t.eq(seen, 7)
	end)

	t.test("a throwing step returns false instead of raising", function()
		t.eq(SafeLoop.step("spec-throw", function() error("boom") end), false)
		t.eq(SafeLoop.step("spec-throw", function() error("boom again") end), false, "the second failure is quiet but still false")
	end)
end
