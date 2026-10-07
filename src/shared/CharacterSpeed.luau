--!strict
-- A loadout change updates only the pet's contribution, never a continuous speed loop.
-- Fast-walk is the player's own toggle: it multiplies the whole speed (pets included).
local Speed = {}

Speed.FastMultiplier = 1.5

function Speed.update(current: number, previousApplied: number?, previousBase: number?, bonus: number, fast: boolean?): (number, number)
	local base = if previousApplied and previousBase and math.abs(current - previousApplied) < 1e-6 then previousBase else current
	local applied = base + 16 * math.clamp(bonus, 0, .3)
	return if fast then applied * Speed.FastMultiplier else applied, base
end

return Speed
