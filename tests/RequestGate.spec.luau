--!strict
-- Remote admission happens before payload validation; internal gameplay calls bypass it.

return function(t: any)
	local RequestGate = require(t.shared.RequestGate)

	t.test("the first request is admitted even at the start of a fresh server", function()
		local allowed, stamp = RequestGate.check(nil, 0, 0.10)
		t.eq(allowed, true)
		t.eq(stamp, 0)
	end)

	t.test("requests inside the cooldown keep the last admitted timestamp", function()
		local allowed, stamp = RequestGate.check(10, 10.09, 0.10)
		t.eq(allowed, false)
		t.eq(stamp, 10)
		allowed, stamp = RequestGate.check(10, 10.25, 0.50)
		t.eq(allowed, false)
		t.eq(stamp, 10)
	end)

	t.test("the exact cooldown boundary admits the next request", function()
		local allowed, stamp = RequestGate.check(0, 0.10, 0.10)
		t.eq(allowed, true)
		t.eq(stamp, 0.10)
		allowed, stamp = RequestGate.check(10, 11, 1)
		t.eq(allowed, true)
		t.eq(stamp, 11)
		allowed, stamp = RequestGate.check(10, 10.10, 0.10)
		t.eq(allowed, true, "decimal boundary is inclusive despite floating-point subtraction")
		t.eq(stamp, 10.10)
	end)

	t.test("invalid and backwards clocks reject without consuming an allowance", function()
		for _, now in { 0 / 0, math.huge, -math.huge, -1, 9 } do
			local allowed, stamp = RequestGate.check(10, now, 0.10)
			t.eq(allowed, false)
			t.eq(stamp, 10)
		end
		for _, previous in { 0 / 0, math.huge, -math.huge, -1 } do
			local allowed, stamp = RequestGate.check(previous, 10, 0.10)
			t.eq(allowed, false)
			t.ok(stamp == previous or (stamp ~= stamp and previous ~= previous))
		end
	end)

	t.test("an invalid cooldown fails closed", function()
		for _, cooldown in { 0 / 0, math.huge, -math.huge, 0, -1 } do
			local allowed, stamp = RequestGate.check(nil, 10, cooldown)
			t.eq(allowed, false)
			t.eq(stamp, nil)
		end
	end)

	t.test("rejected spam does not extend cooldown and separate players remain independent", function()
		local stamps: { [string]: number } = {}
		local function request(id: string, now: number): boolean
			local allowed, stamp = RequestGate.check(stamps[id], now, 0.50)
			stamps[id] = stamp
			return allowed
		end
		t.eq(request("first", 0), true)
		t.eq(request("first", 0.10), false)
		t.eq(request("first", 0.49), false)
		t.eq(request("second", 0.49), true)
		t.eq(request("first", 0.50), true)
		stamps.first = nil -- PlayerRemoving clears the owning service's timestamps.
		t.eq(request("first", 0.51), true)
	end)

	t.test("invalid payload attempts consume the same allowance before expensive validation", function()
		local previous: number? = nil
		local expensiveChecks = 0
		local function remote(now: number, valid: boolean): boolean
			local allowed, stamp = RequestGate.check(previous, now, 0.10)
			previous = stamp
			if not allowed then return false end
			expensiveChecks += 1
			return valid
		end
		t.eq(remote(0, false), false)
		t.eq(remote(0.05, true), false)
		t.eq(expensiveChecks, 1)
		t.eq(remote(0.10, true), true)
		t.eq(expensiveChecks, 2)
	end)

	t.test("pace: one early swing passes, but steady early swings can't beat the rate", function()
		-- interval 1 s, up to 20% early
		local ok, due = RequestGate.pace(nil, 0, 1, 0.2)
		t.eq(ok, true)
		t.eq(due, 1)
		ok, due = RequestGate.pace(1, 0.85, 1, 0.2)
		t.eq(ok, true, "one swing 15% early")
		t.eq(due, 2)
		ok = RequestGate.pace(2, 1.7, 1, 0.2)
		t.eq(ok, false, "the next one 15% early again is too soon")

		-- a client swinging every 0.8 s: admitted swings average no faster than 1 per second
		local stored: number? = nil
		local admitted = 0
		for i = 0, 100 do
			local allowed, nextDue = RequestGate.pace(stored, i * 0.8, 1, 0.2)
			if allowed then
				admitted += 1
				stored = nextDue
			end
		end
		t.ok(admitted <= 82, "admitted " .. admitted .. " swings in 80 s")
	end)

	t.test("pace: a late swing builds no credit", function()
		local ok, due = RequestGate.pace(1, 5, 1, 0.2)
		t.eq(ok, true)
		t.eq(due, 6)
	end)
end
