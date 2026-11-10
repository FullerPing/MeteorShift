--!strict
-- The Meteor Dive's launch: a ballistic arc that rises `apex` studs above where it starts, then falls onto `to`.
-- Returns the launch velocity and the seconds the flight takes.
local DiveArc = {}

function DiveArc.velocity(from: Vector3, to: Vector3, apex: number, gravity: number): (Vector3, number)
	local up = math.sqrt(2 * gravity * apex)
	local rise = up / gravity
	local fall = math.sqrt(2 * math.max(from.Y + apex - to.Y, 0) / gravity)
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	return flat / (rise + fall) + Vector3.new(0, up, 0), rise + fall
end

return DiveArc
