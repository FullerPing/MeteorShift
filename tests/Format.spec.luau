--!strict
-- Spec for Shared.Format (spec §7.5): every player-facing number goes through
-- Format.number/Format.cash, and durations through Format.time.

return function(t: any)
	local Format = require(t.shared.Format)

	t.test("numbers under 1000 pass through with no suffix", function()
		t.eq(Format.number(999), "999")
	end)

	t.test("low thousands get a K suffix and two decimals", function()
		t.eq(Format.number(1234), "1.23K")
	end)

	t.test("rounding at the top of a tier rolls into the next suffix", function()
		-- 999950 / 1e3 = 999.95, which rounds to "1000K"; Format.number bumps the
		-- tier instead so this reads as "1M" rather than "1000K".
		t.eq(Format.number(999950), "1M")
	end)

	t.test("tens of millions get an M suffix and one decimal", function()
		t.eq(Format.number(45.6e6), "45.6M")
	end)

	t.test("billions get a B suffix and two decimals", function()
		t.eq(Format.number(1.25e9), "1.25B")
	end)

	t.test("negative numbers keep the sign and the suffix", function()
		t.eq(Format.number(-1234), "-1.23K")
	end)

	t.test("NaN formats as 0", function()
		t.eq(Format.number(0 / 0), "0")
	end)

	t.test("cash prefixes a dollar sign", function()
		t.eq(Format.cash(1234), "$1.23K")
	end)

	t.test("time formats minutes and seconds", function()
		t.eq(Format.time(125), "2:05")
	end)
end
