-- Map v3 ground (Caldera Terraces). Load Common, Brick and Toon first, and pass the Props builders:
--   L("../map-v3/Ground", L("../map-v3/Props", "lib"))
-- Owns Map_Redesign.Ground:
--   T0: the archived v2 collision ground (crater hole and rim deck) and grass plate, cloned; a fresh checker lawn on
--       T0 only, clear of the crater and the v3 zones.
--   Terraces: T1 and T2 as 5-stud rows clipped to 16-gon tier edges, built per 90-degree wedge so every row crosses
--       an edge at most 45 degrees off square. A row stops short of an edge that faces down to a lower tier (the gap
--       is at most 5 studs; the cliff's core and turf lip, 6.6 deep, cover it) and may run under a higher tier.
--   Cliffs: a rock face on every tier edge (Props.cliff, exact lengths), open where an avenue ramps up.
--   Ramps: a wedge and a landing block where each avenue climbs a cliff (the south avenue stops at the Rebirth terrace).
--   Crown: the plateau on T2's north side, wall to wall in z, with cliff faces on its three open sides.
local A = assert(_G.MapRedesignArt, "Run Common first")
local T = assert(A.toon, "Run Toon first")
local P = assert(..., "Pass the Props builders: L(\"../map-v3/Props\", \"lib\")")
local G = A.geometry
local R = T.ramp
local HALF, ROW = G.BoundaryHalf, 5
local TAN = math.tan(math.rad(11.25))

-- the tier edges: 16-gon apothems (side normals every 22.5 degrees, one on each avenue)
local EDGE_T1, EDGE_T2 = 260, 370
local Y1, Y2, YC = G.Tiers[2].y, G.Tiers[3].y, G.Crown.y
local GREEN_T1, GREEN_T2 = Color3.fromRGB(96, 200, 62), Color3.fromRGB(80, 184, 70)
local CROWN_TOP = Color3.fromRGB(176, 158, 236)
local PAVE = Color3.fromRGB(255, 241, 201)

-- half-width at height z of the 16-gon with apothem `a` (nil when z is outside it)
local function halfWidth(a: number, z: number): number?
	local best = math.huge
	for k = 0, 15 do
		local t = math.rad(k * 22.5)
		local c, s = math.cos(t), math.sin(t)
		if c > 1e-6 then
			best = math.min(best, (a - z * s) / c)
		elseif c > -1e-6 and math.abs(z) * math.abs(s) > a + 1e-6 then
			return nil
		end
	end
	return if best >= 0 then best else nil
end
-- the widest half-width over a row [z0, z1] (nil where the polygon misses the whole row)
local function widest(a: number, z0: number, z1: number): number?
	local best: number? = nil
	for i = 0, 10 do
		local h = halfWidth(a, z0 + (z1 - z0) * i / 10)
		if h and (not best or h > best) then best = h end
	end
	return best
end

local ground = A.group(A.map, "Ground")
local source = game:GetService("ServerStorage").SwapRollback.Map_v8.Ground
for _, name in { "Collision", "GrassPlate1" } do
	local copy = source:FindFirstChild(name):Clone()
	copy:SetAttribute("MapRedesignOwned", true)
	for _, v in copy:GetDescendants() do v:SetAttribute("MapRedesignOwned", true) end
	copy.Parent = ground
end

-- the checker lawn on T0: whole tiles inside the tier, clear of the crater mouth and every zone's bounding box
local lawn = A.group(ground, "Lawn")
local TILE = 24
local lawnCount = 0
for i = -11, 10 do
	for j = -11, 10 do
		local x, z = (i + .5) * TILE, (j + .5) * TILE
		local r = Vector2.new(math.abs(x) + TILE / 2, math.abs(z) + TILE / 2).Magnitude
		local clear = (i + j) % 2 == 0 and r <= EDGE_T1 - 2 and Vector2.new(x, z).Magnitude > A.crater.OpeningRadius + TILE
		for _, zone in G.Zones do
			if clear and math.abs(x - zone.x) < zone.width / 2 + TILE / 2 and math.abs(z - zone.z) < zone.depth / 2 + TILE / 2 then clear = false end
		end
		if clear then
			local plate = A.part(lawn, "LawnTile", Vector3.new(TILE, .2, TILE), A.cf(x, .1, z), A.colors.lawnB, nil, false)
			plate.CanQuery, plate.CastShadow = false, false
			lawnCount += 1
		end
	end
end

-- terrace rows, wedge by wedge: in local coordinates the wedge is x >= |z|, rows run along x; quarter-turns map it
-- onto the north, west and south wedges (the 16-gon and the square walls are both quarter-turn symmetric)
local terraces = A.group(ground, "Terraces")
local rows = 0
local function slab(q: number, x0: number, x1: number, z0: number, z1: number, top: number, color: Color3, name: string)
	if x1 - x0 < .5 then return end
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	local c, s = math.round(math.cos(q * math.pi / 2)), math.round(math.sin(q * math.pi / 2))
	local size = if q % 2 == 0 then Vector3.new(x1 - x0, top, z1 - z0) else Vector3.new(z1 - z0, top, x1 - x0)
	A.part(terraces, name, size, A.cf(cx * c - cz * s, top / 2, cx * s + cz * c), color)
	rows += 1
	if rows % 60 == 0 then task.wait() end
end
for q = 0, 3 do
	for z0 = -HALF, HALF - ROW, ROW do
		local z1 = z0 + ROW
		local wedge = if z0 < 0 and z1 > 0 then 0 else math.min(math.abs(z0), math.abs(z1)) -- x >= |z| (rows overlap the diagonal a little)
		local inner, outer = widest(EDGE_T1, z0, z1), widest(EDGE_T2, z0, z1)
		local t1Start, t2Start = math.max(inner or 0, wedge), math.max(outer or 0, wedge)
		if outer then slab(q, t1Start, t2Start, z0, z1, Y1, GREEN_T1, "T1") end -- runs to the widest T2 edge, under T2
		slab(q, t2Start, HALF, z0, z1, Y2, GREEN_T2, "T2")
	end
end

-- the Crown plateau: a sand body with a lavender meadow top, standing on T2, up to the north wall
local crown = A.group(ground, "Crown")
local c = G.Crown
A.part(crown, "CrownBody", Vector3.new(c.x1 - c.x0, YC - 1 - Y2, c.z1 - c.z0), A.cf((c.x0 + c.x1) / 2, (Y2 + YC - 1) / 2, (c.z0 + c.z1) / 2), Color3.fromRGB(226, 184, 124))
A.part(crown, "CrownTop", Vector3.new(c.x1 - c.x0, 1, c.z1 - c.z0), A.cf((c.x0 + c.x1) / 2, YC - .5, (c.z0 + c.z1) / 2), CROWN_TOP)

-- cliffs: one face per 16-gon side, open where an avenue ramps up; faces run 1.5 studs past each corner
local cliffs = A.group(ground, "Cliffs")
local avenueAngles = {}
for _, angle in G.Avenues.angles do avenueAngles[angle] = true end
local RAMP_GAP = G.Avenues.width / 2 + 1
local SLIDE_GAP = G.Slides.width / 2 + 1
-- [lo, hi] minus the gaps (each { from, to }), as the runs left over
local function cut(lo: number, hi: number, gaps: { { number } }): { { number } }
	table.sort(gaps, function(a, b) return a[1] < b[1] end)
	local runs, at = {}, lo
	for _, gap in gaps do
		if gap[1] > at then table.insert(runs, { at, math.min(gap[1], hi) }) end
		at = math.max(at, gap[2])
	end
	if hi > at then table.insert(runs, { at, hi }) end
	return runs
end
local function edgeFaces(apothem: number, y0: number, h: number, turf: Color3, noRamp: { [number]: boolean })
	local side = 2 * apothem * TAN
	for k = 0, 15 do
		local angle = k * 22.5
		local n = Vector3.new(math.cos(math.rad(angle)), 0, math.sin(math.rad(angle)))
		local tangent = Vector3.new(-n.Z, 0, n.X) -- the counter-clockwise way along the face
		local gaps = {}
		if avenueAngles[angle] and not noRamp[angle] then table.insert(gaps, { -RAMP_GAP, RAMP_GAP }) end
		for _, slide in G.Slides.list do
			if slide.angle == angle then
				local at = slide.side * G.Slides.offset
				table.insert(gaps, { at - SLIDE_GAP, at + SLIDE_GAP })
			end
		end
		for i, run in cut(-side / 2 - 1.5, side / 2 + 1.5, gaps) do
			local at = n * apothem + tangent * (run[1] + run[2]) / 2
			P.cliff(A.group(cliffs, ("Edge%d_%d_%d"):format(apothem, k, i)), A.frame(at.X, at.Z, -n), run[2] - run[1], y0, h, turf, apothem + k * 7 + i)
		end
		task.wait()
	end
end
edgeFaces(EDGE_T1, 0, Y1, GREEN_T1, {})
edgeFaces(EDGE_T2, Y1, Y2 - Y1, GREEN_T2, { [270] = true }) -- the south avenue ends at the Rebirth terrace
-- the Crown's three open sides (the north side is the wall); the north slide leaves through the south face
local northSlideX = 0
for _, slide in G.Slides.list do if slide.angle == 90 then northSlideX = -slide.side * G.Slides.offset end end
for i, run in cut(c.x0 - 1.5, c.x1 + 1.5, { { northSlideX - SLIDE_GAP, northSlideX + SLIDE_GAP } }) do
	P.cliff(A.group(cliffs, "CrownSouth" .. i), A.frame((run[1] + run[2]) / 2, c.z0, -Vector3.zAxis), run[2] - run[1], Y2, YC - Y2, CROWN_TOP, 900 + i)
end
for i, sx in { c.x0, c.x1 } do
	P.cliff(A.group(cliffs, "CrownSide" .. i), A.frame(sx, (c.z0 + c.z1) / 2, Vector3.new(if sx < 0 then -1 else 1, 0, 0)), c.z1 - c.z0, Y2, YC - Y2, CROWN_TOP, 910 + i)
end

-- ramps: a wedge up each opened cliff (low end toward the crater) and a landing block over the cliff's depth
local ramps = A.group(ground, "Ramps")
local RUN = 60 -- 16 up over 60 is 15 degrees
local function ramp(angle: number, apothem: number, y0: number, rise: number)
	local n = Vector3.new(math.cos(math.rad(angle)), 0, math.sin(math.rad(angle)))
	local mid = n * (apothem - RUN / 2)
	local w = G.Avenues.width
	T.wedge(ramps, "Ramp" .. angle, A.frame(mid.X, mid.Z, -n), 0, 0, y0, w, RUN, rise, PAVE, nil, true)
	local landing = n * (apothem + 4)
	A.part(ramps, "Landing" .. angle, Vector3.new(w, y0 + rise, 12), CFrame.lookAt(Vector3.new(landing.X, (y0 + rise) / 2, landing.Z), Vector3.new(landing.X, (y0 + rise) / 2, landing.Z) + n), PAVE)
	for _, s in { -1, 1 } do -- white kerbs along both sides, following the slope
		local side = Vector3.new(-n.Z, 0, n.X) * s * (w / 2 + .5)
		local p0 = mid + side - n * (RUN / 2) + Vector3.new(0, y0 + .6, 0)
		local p1 = mid + side + n * (RUN / 2) + Vector3.new(0, y0 + rise + .6, 0)
		T.part(ramps, "Kerb", Vector3.new(1, 1.2, (p1 - p0).Magnitude), CFrame.lookAt((p0 + p1) / 2, p1), T.white, nil, false)
	end
end
for angle in avenueAngles do
	ramp(angle, EDGE_T1, 0, Y1)
	if angle ~= 270 then ramp(angle, EDGE_T2, Y1, Y2 - Y1) end
end

return { stage = "Ground", lawn = lawnCount, rows = rows, cliffParts = A.count(cliffs), parts = A.count(ground) }
