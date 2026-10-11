-- Common + Brick + Toon first. Crater Isle, the near scenery: the town island's cliff skirt and sand beach, a belt of
-- tree-topped hills just behind the rampart (their crowns peek over the merlons), a turquoise lagoon with palm islands,
-- two lighthouses and a few sailboats. All of it is non-colliding, query-free and out of reach (the walls and the server
-- bounds keep players inside). It is marked Persistent so it streams in however far a player stands. Owns Surroundings.
-- The far ranges, Meteor Peak, sky islands and clouds are in Backdrop.
local A = assert(_G.MapRedesignArt)
local C, G = A.colors, assert(A.geometry)
local half = G.BoundaryHalf
local T = assert(A.toon, "Run Toon first")
local R = T.ramp
local sur = A.group(A.map, "Surroundings")
T.persistent(sur)
local random = Random.new(2027)
local function deco(name, size, frame, color, material, shape)
	return T.far(sur, name, size, frame, color, material, shape)
end
local function blob(name, size, frame, color) return T.blob(sur, name, size, frame, color) end
local function disc(name, diameter, topY, color)
	local p = T.deco(T.smooth(A.cylinder(sur, name, diameter, .2, A.cf(0, topY - .1, 0), color, nil, false)))
	return p
end

-- the sea: a big plate, a darker one under it so the horizon never shows a seam. Its surface must stay below the crater
-- floor (Y -14.755) or it shows through the crater as a lake; the lagoon, foam and sand discs stack just above it.
local seaTop = -16
deco("Sea", Vector3.new(2600, 2, 2600), A.cf(0, seaTop - 1, 0), C.sea).TopSurface = Enum.SurfaceType.Smooth
deco("SeaDeep", Vector3.new(4000, 2, 4000), A.cf(0, seaTop - 6, 0), C.seaDeep)
disc("Lagoon", 1500, seaTop + .1, Color3.fromRGB(86, 218, 226))
disc("Foam", 960, seaTop + .2, Color3.fromRGB(238, 250, 255))
disc("Beach", 900, seaTop + .4, T.sand[1])

-- the cliff skirt under the rampart: rust rock, a tan band and a green cap, six overlapping sites per side
local walls = { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis }
for _, n in walls do
	local t = Vector3.new(-n.Z, 0, n.X)
	local yaw = math.atan2(n.X, n.Z)
	for k = 0, 5 do
		local u = -250 + k * 100
		local c = n * 302 + t * u
		local wob = random:NextNumber(-3, 3)
		blob("Cliff", Vector3.new(132, 46, 64), A.cf(c.X, -16, c.Z) * CFrame.Angles(0, yaw, 0), R.rust[2])
		blob("CliffBand", Vector3.new(120, 30, 56), A.cf(c.X + n.X * 3, -7 + wob, c.Z + n.Z * 3) * CFrame.Angles(0, yaw, 0), R.cream[3])
		blob("CliffCap", Vector3.new(112, 16, 52), A.cf(c.X + n.X * 4, 4, c.Z + n.Z * 4) * CFrame.Angles(0, yaw, 0), R.green[2])
	end
end

-- the tree belt: seven green hills per side just behind the cliffs with two trees each. Crowns reach Y 45-60 so a lively
-- fringe shows above the merlons (Y 35) from anywhere inside.
for _, n in walls do
	local t = Vector3.new(-n.Z, 0, n.X)
	local yaw = math.atan2(n.X, n.Z)
	for k = 0, 6 do
		local u = -231 + k * 77 + random:NextNumber(-8, 8)
		local out = random:NextNumber(336, 366)
		local w = random:NextNumber(72, 100)
		local top = random:NextNumber(14, 26)
		local cy = -10
		local depth = w * .8
		local c = n * out + t * u
		blob("Hill", Vector3.new(w, (top - cy) * 2, depth), A.cf(c.X, cy, c.Z) * CFrame.Angles(0, yaw, 0), R.green[(k % 2) + 1 + (if k % 3 == 0 then 1 else 0)])
		for i = 1, 2 do
			local du = (i == 1 and -1 or 1) * w * random:NextNumber(.12, .24)
			local dn = random:NextNumber(-.12, .12) * w
			local qx, qn = du / (w / 2), dn / (depth / 2)
			local surface = cy + (top - cy) * math.sqrt(math.max(0, 1 - qx * qx - qn * qn))
			local p = c + t * du + n * dn
			T.lollipop(sur, p.X, p.Z, surface - 1.5, random:NextNumber(1.6, 2.2), R.green, (k + i) % 3 == 0)
		end
	end
end

-- islands: a sand mound with a foam ring, a grass cap, two palms with round leaf crowns, a rock and a beach umbrella
local function island(x, z, size, k)
	T.deco(T.smooth(A.cylinder(sur, "IslandFoam", size * 1.18, .3, A.cf(x, seaTop + .1, z), Color3.fromRGB(238, 250, 255), nil, false)))
	blob("IslandSand", Vector3.new(size, 14, size), A.cf(x, seaTop, z), R.cream[2])
	blob("IslandGrass", Vector3.new(size * .7, 10, size * .7), A.cf(x, seaTop + 3, z), R.green[2])
	local top = seaTop + 7.5
	blob("IslandRock", Vector3.new(size * .22, size * .16, size * .2), A.cf(x + size * .36, seaTop + 1, z - size * .12), R.stone[3])
	for i, side in { -1, 1 } do
		local height = 17 + random:NextInteger(0, 2) * 3
		local px, pz = x + side * size * .16, z + (i == 1 and .1 or -.12) * size
		local lean = math.rad(random:NextInteger(-10, 10))
		local trunk = deco("PalmTrunk", Vector3.new(height, 2.6, 2.6), A.cf(px, top + height / 2, pz) * CFrame.Angles(lean, 0, math.pi / 2), R.wood[2], nil, Enum.PartType.Cylinder)
		local tip = trunk.CFrame * CFrame.new(height / 2, 0, 0)
		blob("PalmCrown", Vector3.new(17, 4, 17), CFrame.new(tip.Position), R.green[1])
		blob("PalmCrown", Vector3.new(14, 3.4, 14), CFrame.new(tip.Position + Vector3.new(0, 1.4, 0)) * CFrame.Angles(0, math.rad(45), 0), R.green[2])
	end
	local ux, uz = x - size * .24, z + size * .14
	deco("UmbrellaPole", Vector3.new(7, .5, .5), A.cf(ux, top + 3.5, uz) * CFrame.Angles(0, 0, math.pi / 2), T.white, nil, Enum.PartType.Cylinder)
	blob("UmbrellaTop", Vector3.new(7.5, 2.6, 7.5), A.cf(ux, top + 7.2, uz), if k % 2 == 0 then R.red[2] else R.blue[2])
end

-- a lighthouse on a rocky island: a banded tower, a gallery, a glowing lamp room (no real light) and a red cap
local function lighthouse(x, z)
	island(x, z, 96, 0)
	local base = seaTop + 8
	local F = A.frame(x, z, "N")
	local k = 1.7
	deco("LighthouseRock", Vector3.new(34, 9, 30), A.cf(x - 6, base + 1, z + 4), R.stone[3], nil, Enum.PartType.Ball)
	local y = base
	for _, spec in { { 13, 16, T.white }, { 11.2, 16, R.red[2] }, { 9.6, 16, T.white } } do
		T.deco(T.cyl(sur, "LighthouseTower", F, 0, 0, y, spec[1] * k, spec[2] * k, spec[3], nil, false))
		y += (spec[2] - .4) * k
	end
	T.deco(T.cyl(sur, "LighthouseGallery", F, 0, 0, y, 14 * k, 1.8 * k, R.navy[2], nil, false))
	T.deco(T.cyl(sur, "LighthouseLamp", F, 0, 0, y + 1.6 * k, 6.4 * k, 6.4 * k, R.gold[1], Enum.Material.Neon, false))
	T.deco(T.cyl(sur, "LighthouseRoof", F, 0, 0, y + 7.6 * k, 10 * k, 2.6 * k, R.red[2], nil, false))
	T.far(sur, "LighthouseKnob", Vector3.new(4, 4, 4) * k, F.cf(0, y + 11.6 * k, 0), R.gold[2], nil, Enum.PartType.Ball)
	T.far(sur, "LighthouseDoor", Vector3.new(3.6, 6, 1) * k, F.cf(0, base + 3 * k, -6.3 * k), R.navy[3])
	T.far(sur, "LighthouseDoorStep", Vector3.new(5.2, .8, 2) * k, F.cf(0, base + .4, -6.9 * k), R.stone[1])
end
local lighthouses = { { 380, -560 }, { -380, -560 } }
for _, spot in lighthouses do lighthouse(spot[1], spot[2]) end

local slots = 10
local placed = 0
for k = 0, slots - 1 do
	local angle = math.rad(k * 360 / slots + 18 + random:NextNumber(-8, 8))
	local radius = random:NextNumber(500, 640)
	local x, z = math.cos(angle) * radius, math.sin(angle) * radius
	local clear = true
	for _, spot in lighthouses do if (Vector2.new(x, z) - Vector2.new(spot[1], spot[2])).Magnitude < 190 then clear = false end end
	if clear then
		island(x, z, random:NextNumber(46, 70), k)
		placed += 1
	end
end

-- sailboats on the lagoon: a wooden hull, a mast, a white and a cream sail and a pennant
for _, spot in { { 250, -430, 20 }, { -300, -380, -35 }, { 70, 520, 95 } } do
	local x, z, yaw = spot[1], spot[2], math.rad(spot[3])
	local at = A.cf(x, seaTop, z) * CFrame.Angles(0, yaw, 0)
	blob("BoatHull", Vector3.new(26, 8, 9), at * CFrame.new(0, 1, 0), R.wood[2])
	T.far(sur, "BoatMast", Vector3.new(24, .8, .8), at * CFrame.new(0, 13, 0) * CFrame.Angles(0, 0, math.pi / 2), T.ink, nil, Enum.PartType.Cylinder)
	blob("BoatSail", Vector3.new(11, 17, .5), at * CFrame.new(-1, 12, 0), T.white)
	blob("BoatSail", Vector3.new(7, 11, .5), at * CFrame.new(7, 10, 0), R.cream[2])
	T.far(sur, "BoatPennant", Vector3.new(4.4, 2.2, .3), at * CFrame.new(2.2, 24, 0), R.red[2])
end

assert(A.count(sur) <= 470, "Surroundings art budget: " .. A.count(sur))
return { stage = "Surroundings", parts = A.count(sur), islands = placed, totalParts = A.count(A.map) }
