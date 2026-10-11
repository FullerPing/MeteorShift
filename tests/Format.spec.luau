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

	t.test("numbers past a decillion keep counting in named suffixes", function()
		t.eq(Format.number(1e33), "1Dc")
		t.eq(Format.number(1.5e36), "1.5Ud")
		t.eq(Format.number(9.99e39), "9.99Dd")
		t.eq(Format.number(1e63), "1Vg")
		t.eq(Format.cash(2.5e45), "$2.5Qad")
	end)

	t.test("rounding at the top of a new suffix rolls into the next one", function()
		t.eq(Format.number(999.96e36), "1Dd")
	end)

	t.test("the largest suffix never prints four digits and huge or infinite values do not error", function()
		t.eq(Format.number(1e200), "999Vg")
		t.eq(Format.number(math.huge), "999Vg")
		t.eq(Format.number(-math.huge), "-999Vg")
		t.eq(Format.number(9.99e65), "999Vg")
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

	t.test("rates keep a decimal below ten so 0.5 per second never reads as 0", function()
		t.eq(Format.rate(0.5), "0.5")
		t.eq(Format.rate(2), "2")
		t.eq(Format.rate(1.26), "1.3")
		t.eq(Format.rate(12.4), "12")
		t.eq(Format.rate(0), "0")
	end)
end
