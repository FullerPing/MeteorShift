--!strict
-- Spec for Shared.CallMeteor (spec §9.2): when the Call a Meteor product can be
-- bought. Limits are read from Config.Monetization.CallMeteor so a retune doesn't
-- break these cases; the rules themselves (phase, time left, cooldown, hourly cap,
-- and a reason whenever it's unavailable) are what is checked.

return function(t: any)
	local CallMeteor = require(t.shared.CallMeteor)
	local Rules = require(t.shared.Config.Monetization).CallMeteor

	local enough = Rules.MinSecondsLeft + 30
	local cooled = Rules.Cooldown + 1

	t.test("available during a long enough countdown after the cooldown", function()
		local ok, reason = CallMeteor.available("Countdown", enough, cooled, 0)
		t.eq(ok, true)
		t.eq(reason, nil)
	end)

	t.test("available before any meteor has ended (no cooldown yet)", function()
		t.eq(CallMeteor.available("Countdown", enough, nil, 0), true)
	end)

	t.test("unavailable outside the countdown, with a reason", function()
		for _, phase in { "Impact", "Active", "CoreCracked", "Cooled", "Cleanup" } do
			local ok, reason = CallMeteor.available(phase, enough, cooled, 0)
			t.eq(ok, false, phase)
			t.ok(typeof(reason) == "string" and #reason > 0, phase .. " has a reason")
		end
	end)

	t.test("needs more than MinSecondsLeft on the countdown", function()
		t.eq(CallMeteor.available("Countdown", Rules.MinSecondsLeft, cooled, 0), false)
		t.eq(CallMeteor.available("Countdown", Rules.MinSecondsLeft - 10, cooled, 0), false)
		t.eq(CallMeteor.available("Countdown", Rules.MinSecondsLeft + 0.5, cooled, 0), true)
	end)

	t.test("waits out the cooldown after the previous event ends", function()
		local ok, reason = CallMeteor.available("Countdown", enough, Rules.Cooldown - 1, 0)
		t.eq(ok, false)
		t.ok(typeof(reason) == "string", "has a reason")
		t.eq(CallMeteor.available("Countdown", enough, Rules.Cooldown, 0), true)
	end)

	t.test("the server can call at most HourlyCap per rolling hour", function()
		t.eq(CallMeteor.available("Countdown", enough, cooled, Rules.HourlyCap - 1), true)
		local ok, reason = CallMeteor.available("Countdown", enough, cooled, Rules.HourlyCap)
		t.eq(ok, false)
		t.ok(typeof(reason) == "string", "has a reason")
		t.eq(CallMeteor.available("Countdown", enough, cooled, Rules.HourlyCap + 2), false)
	end)

	t.test("each blocker gives its own reason", function()
		local _, phase = CallMeteor.available("Active", enough, cooled, 0)
		local _, late = CallMeteor.available("Countdown", Rules.MinSecondsLeft, cooled, 0)
		local _, cooldown = CallMeteor.available("Countdown", enough, 0, 0)
		local _, cap = CallMeteor.available("Countdown", enough, cooled, Rules.HourlyCap)
		t.ok(phase ~= late and late ~= cooldown and cooldown ~= cap and phase ~= cap, "reasons differ")
	end)

	t.test("counts calls inside the rolling window only", function()
		local now = 10000
		local times = { now - Rules.CapWindow - 1, now - Rules.CapWindow + 5, now - 10, now }
		t.eq(CallMeteor.callsInWindow(times, now), 3)
		t.eq(CallMeteor.callsInWindow({}, now), 0)
	end)
end
