--!strict
-- A loadout change updates only the pet's contribution, never a continuous speed loop.
local Speed = {}

function Speed.update(current: number, previousApplied: number?, previousBase: number?, bonus: number): (number, number)
	local base = if previousApplied and previousBase and math.abs(current - previousApplied) < 1e-6 then previousBase else current
	return base + 16 * math.clamp(bonus, 0, .3), base
end

return Speed
