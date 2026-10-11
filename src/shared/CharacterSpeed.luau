--!strict
-- A loadout change updates only the pet's contribution, never a continuous speed loop.
-- Everyone walks at BaseMultiplier times the Roblox default (the old fast-walk speed).
-- The SPRINT toggle is the player's own: it multiplies the whole speed again (pets included).
local Speed = {}

Speed.BaseMultiplier = 1.5
Speed.FastMultiplier = 1.5

function Speed.update(current: number, previousApplied: number?, previousBase: number?, bonus: number, fast: boolean?): (number, number)
	local base = if previousApplied and previousBase and math.abs(current - previousApplied) < 1e-6 then previousBase else current
	local applied = (base + 16 * math.clamp(bonus, 0, .3)) * Speed.BaseMultiplier
	return if fast then applied * Speed.FastMultiplier else applied, base
end

return Speed
