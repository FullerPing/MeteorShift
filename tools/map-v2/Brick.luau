-- Toy-brick grammar on top of Common. Load after Common. Buildings are built in a local frame so each
-- one can face the boulevard, the crater or a field entrance:
--   F = A.frame(cx, cz, facing)   facing = the world direction the building's front looks toward
--   u = lateral offset (to the right of the centre as seen from outside), d = offset toward the front (outward)
-- A.box sizes are (lateral, height, depth) whatever the facing; y is absolute (ground top = 0).
local A = assert(_G.MapRedesignArt, "Run Common first")
local C = A.colors

function A.frame(cx, cz, facing)
	local f = { cx = cx, cz = cz }
	f.forward = if typeof(facing) == "Vector3" then facing.Unit else ({ N = Vector3.zAxis, S = -Vector3.zAxis, E = Vector3.xAxis, W = -Vector3.xAxis })[facing]
	assert(f.forward, "Bad facing")
	-- CFrame.lookAt aims -Z (the Front face and its SurfaceGuis) along `forward`. Lateral u is measured to the
	-- RIGHT of a viewer standing in front of the building and looking at it.
	local up = Vector3.yAxis
	f.right = up:Cross(f.forward)
	function f.world(u, y, d)
		return Vector3.new(cx, y, cz) + f.right * u + f.forward * d
	end
	function f.cf(u, y, d, extra)
		local p = f.world(u, y, d) + A.offset
		return CFrame.lookAt(p, p + f.forward) * (extra or CFrame.identity)
	end
	return f
end

-- A box in the building's frame: lateral width, depth toward the front, from y0 up by h
function A.box(parent, name, F, u, d, y0, lateral, depth, h, color, material, collide)
	return A.part(parent, name, Vector3.new(lateral, h, depth), F.cf(u, y0 + h / 2, d), color, material, collide)
end

-- A cylinder stud standing on a surface at height y (axis up), diameter 2.4 by default
function A.stud(parent, name, F, u, y, d, color, diameter, height)
	diameter, height = diameter or 2.4, height or 1
	return A.cylinder(parent, name, diameter, height, F.cf(u, y + height / 2, d), color, nil, false)
end

-- A grid of studs filling a roof, `pitch` apart, at most `limit` of them
function A.studGrid(parent, name, F, u0, d0, lateral, depth, y, color, pitch, limit, diameter)
	pitch = pitch or 8
	local cols, rows = math.max(1, math.floor(lateral / pitch)), math.max(1, math.floor(depth / pitch))
	local made = 0
	for row = 0, rows - 1 do
		for col = 0, cols - 1 do
			if limit and made >= limit then return made end
			local u = u0 - lateral / 2 + (col + .5) * lateral / cols
			local d = d0 - depth / 2 + (row + .5) * depth / rows
			A.stud(parent, name, F, u, y, d, color, diameter)
			made += 1
		end
	end
	return made
end

-- A sign whose lettering faces along the frame's forward direction (or `facing`) at (u, y, d)
function A.signOn(parent, name, text, F, u, y, d, lateral, h, color, thick, facing)
	local frame = F.cf(u, y, d)
	if facing then
		local p = F.world(u, y, d) + A.offset
		frame = CFrame.lookAt(p, p + facing)
	end
	return A.sign(parent, name, text, Vector3.new(lateral, h, thick or 1.5), frame, color)
end

-- Four corner pillars with a stud on top, for a footprint of lateral x depth
function A.pillars(parent, name, F, lateral, depth, y0, h, color, capColor, width)
	width = width or 4
	for _, su in { -1, 1 } do
		for _, sd in { -1, 1 } do
			local u, d = su * (lateral / 2 - width / 2), sd * (depth / 2 - width / 2)
			A.box(parent, name, F, u, d, y0, width, width, h, color)
			A.stud(parent, name .. "Stud", F, u, y0 + h, d, capColor or color, width * .6)
		end
	end
end

-- A striped awning (alternating colours) over the front edge
function A.awning(parent, name, F, u, d, y, lateral, depth, colorA, colorB, stripes)
	stripes = stripes or 6
	local w = lateral / stripes
	for i = 0, stripes - 1 do
		local part = A.box(parent, name, F, u - lateral / 2 + (i + .5) * w, d, y, w, depth, 1.2, if i % 2 == 0 then colorA else colorB, nil, false)
		part.CFrame = part.CFrame * CFrame.Angles(math.rad(-10), 0, 0)
	end
end

-- Ring of studs around a circle (plaza and monument trim)
function A.studRing(parent, name, cx, y, cz, radius, count, color, diameter)
	for k = 0, count - 1 do
		local a = k * math.pi * 2 / count
		A.cylinder(parent, name, diameter or 2.4, 1, A.cf(cx + math.cos(a) * radius, y + .5, cz + math.sin(a) * radius), color, nil, false)
	end
end

-- A plate seen from above: footprint centred on (cx, cz), world-axis aligned
function A.plate(parent, name, cx, cz, w, d, y0, h, color, material, collide)
	return A.part(parent, name, Vector3.new(w, h, d), A.cf(cx, y0 + h / 2, cz), color, material, collide)
end

-- The frame for a WorldGeometry zone: lat/dep are the footprint extents along the building's own axes
-- (a building facing east or west is `depth` wide across its front and `width` deep). A zone with its own `facing`
-- (the angled shops) uses its `lat` x `dep` instead.
function A.frameFor(zone, facing)
	local F = A.frame(zone.x, zone.z, facing or zone.facing)
	if zone.facing and not facing then
		F.lat, F.dep = zone.lat, zone.dep -- a building turned toward the crater: its own rectangle inside width x depth
	else
		local across = math.abs(F.forward.Z) > .5 -- facing north or south: the front spans X
		F.lat, F.dep = if across then zone.width else zone.depth, if across then zone.depth else zone.width
	end
	F.zone = zone
	return F
end

-- A standard building plinth (white kerb plate under the coloured floor) for the zone's footprint
function A.plinth(parent, zone, color, inset)
	inset = inset or 0
	A.plate(parent, "Plinth", zone.x, zone.z, zone.width - inset * 2, zone.depth - inset * 2, 0, 1.2, C.kerb)
	return A.plate(parent, "Floor", zone.x, zone.z, zone.width - inset * 2 - 2, zone.depth - inset * 2 - 2, 1.2, .6, color)
end
