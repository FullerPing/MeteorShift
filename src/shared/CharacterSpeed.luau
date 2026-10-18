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

-- Whether a ground point is on a fast lane: the ring road (LoopRadius, PathWidth wide), the Terrace Express
-- (ExpressRadius, ExpressWidth wide) or an avenue between its start and its stop (Avenues.stops, else the wall)
function Speed.onRoad(x: number, z: number): boolean
	local settings = WorldGeometry.Settings
	local offset = settings.StageOffset
	local dx, dz = x - offset.X, z - offset.Z
	local radius = math.sqrt(dx * dx + dz * dz)
	if math.abs(radius - settings.LoopRadius) <= settings.PathWidth / 2 + Speed.RoadMargin
		or math.abs(radius - settings.ExpressRadius) <= settings.ExpressWidth / 2 + Speed.RoadMargin then
		return true
	end
	local avenues = settings.Avenues
	for _, angle in avenues.angles do
		local c, s = math.cos(math.rad(angle)), math.sin(math.rad(angle))
		local along, across = dx * c + dz * s, math.abs(dz * c - dx * s)
		local stop = avenues.stops[angle] or settings.BoundaryHalf / math.max(math.abs(c), math.abs(s))
		if across <= avenues.width / 2 + Speed.RoadMargin and along >= (avenues.starts[angle] or avenues.from) and along <= stop then
			return true
		end
	end
	return false
end

function Speed.update(current: number, previousApplied: number?, previousBase: number?, bonus: number, fast: boolean?, road: boolean?): (number, number)
	local base = if previousApplied and previousBase and math.abs(current - previousApplied) < 1e-6 then previousBase else current
	local applied = (base + 16 * math.clamp(bonus, 0, .3)) * Speed.BaseMultiplier
	if road then applied *= Speed.RoadMultiplier end
	return if fast then applied * Speed.FastMultiplier else applied, base
end

return Speed
