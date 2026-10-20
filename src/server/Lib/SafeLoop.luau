--!strict
-- One pass of a background loop, protected: an error is warned (at most once per WARN_EVERY seconds per
-- loop name) and the loop carries on. A bare `while true do` coroutine dies forever on its first error,
-- which used to stop refining, the Crown and locked-field ejects and the boundary kill for the whole server.
--
--   while true do
--   	task.wait(interval)
--   	SafeLoop.step("RefineryTick", function() ... end)
--   end

local SafeLoop = {}

local WARN_EVERY = 30
local lastWarn: { [string]: number } = {}

function SafeLoop.step(name: string, fn: (...any) -> (), ...: any): boolean
	local ok, err = pcall(fn, ...)
	if not ok then
		local now = os.clock()
		if now - (lastWarn[name] or -math.huge) >= WARN_EVERY then
			lastWarn[name] = now
			warn(string.format("[SafeLoop] %s failed (the loop keeps running): %s", name, tostring(err)))
		end
	end
	return ok
end

return SafeLoop
