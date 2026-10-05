--!strict
-- Pure remote admission: callers retain one timestamp per player and action,
-- check before payload/work validation, and clear their timestamps on leave.
-- Only admitted attempts advance the clock, including invalid payload attempts.

local RequestGate = {}

local function finite(value: number): boolean
	return value == value and math.abs(value) < math.huge
end

function RequestGate.check(previous: number?, now: number, cooldown: number): (boolean, number?)
	if not finite(now) or now < 0 or not finite(cooldown) or cooldown <= 0 then
		return false, previous
	end
	if previous ~= nil then
		if not finite(previous) or previous < 0 or now < previous then
			return false, previous
		end
		-- Avoid rejecting an exact decimal boundary because of subtraction precision.
		if now - previous + 1e-9 < cooldown then
			return false, previous
		end
	end
	return true, now
end

return RequestGate
