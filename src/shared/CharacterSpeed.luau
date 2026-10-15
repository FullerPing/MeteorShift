--!strict
-- A loadout change updates only the pet's contribution, never a continuous speed loop.
-- Everyone walks at BaseMultiplier times the Roblox default (the old fast-walk speed).
-- The SPRINT toggle is the player's own: it multiplies the whole speed again (pets included).
-- The ring road round the crater is a fast lane for everyone (RoadMultiplier); SPRINT stacks on top of it.
local WorldGeometry = require(script.Parent.WorldGeometry)
local Speed = {}

Speed.BaseMultiplier = 1.5
Speed.FastMultiplier = 1.5
Speed.RoadMultiplier = 1.5
Speed.RoadMargin = 2 -- studs past the road's kerbs that still count as on it

-- Whether a ground point is on the ring road (its centre line is LoopRadius, PathWidth wide)
function Speed.onRoad(x: number, z: number): boolean
	local settings = WorldGeometry.Settings
	local offset = settings.StageOffset
	local dx, dz = x - offset.X, z - offset.Z
	local radius = math.sqrt(dx * dx + dz * dz)
	return math.abs(radius - settings.LoopRadius) <= settings.PathWidth / 2 + Speed.RoadMargin
end

function Speed.update(current: number, previousApplied: number?, previousBase: number?, bonus: number, fast: boolean?, road: boolean?): (number, number)
	local base = if previousApplied and previousBase and math.abs(current - previousApplied) < 1e-6 then previousBase else current
	local applied = (base + 16 * math.clamp(bonus, 0, .3)) * Speed.BaseMultiplier
	if road then applied *= Speed.RoadMultiplier end
	return if fast then applied * Speed.FastMultiplier else applied, base
end

return Speed
