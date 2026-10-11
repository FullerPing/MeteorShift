-- Common + Brick + Toon + Roads + the zone stages first. Cartoon trees, bushes, planters, benches and lamps in the open
-- lawn, the town fountain, and the statue and podium either side of the Commissary in the north. Placement is seeded and rejection-sampled: clear of every zone, road, the crater
-- and the cardinal corridors, and inside the boundary. Owns Scenery.
local A = assert(_G.MapRedesignArt)
local C, G = A.colors, assert(A.geometry)
local scenery = A.group(A.map, "Scenery")
local random = Random.new(540)

local boxes = {}
for _, zone in G.Zones do table.insert(boxes, { zone.x - zone.width / 2, zone.x + zone.width / 2, zone.z - zone.depth / 2, zone.z + zone.depth / 2 }) end
local function distanceBox(x, z, box)
	return Vector2.new(math.max(box[1] - x, 0, x - box[2]), math.max(box[3] - z, 0, z - box[4])).Magnitude
end
local roads = {}
for _, road in A.map.Roads:GetChildren() do table.insert(roads, road) end
local taken = {}
local function clear(x, z, margin, spacing)
	if math.abs(x) > G.BoundaryHalf - 14 or math.abs(z) > G.BoundaryHalf - 14 then return false end
	if Vector2.new(x, z).Magnitude < G.LoopRadius + G.PathWidth / 2 + margin then return false end
	-- cardinal crater corridors stay free of upright props
	for _, corridor in A.config.LandingFX.Corridors do
		local angle = math.rad(corridor.Angle)
		local dir = Vector2.new(math.cos(angle), math.sin(angle))
		local along = Vector2.new(x, z):Dot(dir)
		local side = math.abs(Vector2.new(x, z):Dot(Vector2.new(-dir.Y, dir.X)))
		if along > 0 and side < corridor.Half + margin then return false end
	end
	for _, box in boxes do if distanceBox(x, z, box) < margin then return false end end
	for _, road in roads do
		local p = road.CFrame:PointToObjectSpace(Vector3.new(x, 0, z) + A.offset)
		local d = Vector2.new(math.max(0, math.abs(p.X) - road.Size.X / 2), math.max(0, math.abs(p.Z) - road.Size.Z / 2)).Magnitude
		if d < margin then return false end
	end
	for _, p in taken do if (Vector2.new(x, z) - p).Magnitude < (spacing or 26) then return false end end
	return true
end

-- the north landmarks are reserved first so no tree lands on them: the Commissary is its own zone at the
-- end of the north spoke; the meteor statue and the "1" podium stand either side of it
local wx, wz = A.zone("Commissary").x, A.zone("Commissary").z
local sx0, sz0, px, pz = -68, 222, 75, 230
assert(clear(sx0, sz0, 10), "Meteor statue site is not clear")
table.insert(taken, Vector2.new(sx0, sz0))
assert(clear(px, pz, 10), "Podium site is not clear")
table.insert(taken, Vector2.new(px, pz))

local fx, fz = 100, -236 -- the town fountain, beside the spawn plaza
assert(clear(fx, fz, 10), "Fountain site is not clear")
table.insert(taken, Vector2.new(fx, fz))

local T = assert(A.toon, "Run Toon first")
local R = T.ramp
local function smoothAll(root) for _, v in root:GetDescendants() do if v:IsA("BasePart") then T.smooth(v) end end end

-- cartoon trees: round trees and pines, a little size variety
local trees = 0
local attempts = 0
while trees < 18 and attempts < 4000 do
	attempts += 1
	local x, z = random:NextNumber(-G.BoundaryHalf + 16, G.BoundaryHalf - 16), random:NextNumber(-G.BoundaryHalf + 16, G.BoundaryHalf - 16)
	if clear(x, z, 16) then
		trees += 1
		table.insert(taken, Vector2.new(x, z))
		local pine = trees % 3 == 0
		T.tree(scenery, "Tree" .. trees, x, z, 0, 1 + (trees % 4) * .12, if pine then "pine" else "round", if trees % 5 == 1 then R.teal else R.green)
	end
end
assert(trees >= 14, "Too few clear tree positions: " .. trees)

local function bench(parent, frame, color)
	T.part(parent, "Seat", Vector3.new(8, 1, 3), frame * CFrame.new(0, 2.2, 0), color[2])
	T.part(parent, "Back", Vector3.new(8, 2.6, .8), frame * CFrame.new(0, 4, 1.2), color[1], nil, false)
	for _, side in { -1, 1 } do T.part(parent, "Leg", Vector3.new(1, 1.8, 2.6), frame * CFrame.new(side * 3.2, .9, 0), T.ink) end
end

-- the town fountain: a round pool, a two-tier gold centrepiece with a glowing spout and four benches
local fountain = A.group(scenery, "TownFountain")
local FF = A.frame(fx, fz, "N")
T.cyl(fountain, "Plinth", FF, 0, 0, 0, 40, 1, R.cream[3])
T.cyl(fountain, "PoolWall", FF, 0, 0, 1, 30, 3, R.blue[2])
T.cyl(fountain, "PoolRim", FF, 0, 0, 4, 32, .9, T.white, nil, false)
local water = T.cyl(fountain, "Water", FF, 0, 0, 3.4, 28, .6, R.frost[2], Enum.Material.Glass, false)
water.Transparency = .2
T.cyl(fountain, "Column", FF, 0, 0, 4, 5, 8, T.white)
T.cyl(fountain, "Bowl", FF, 0, 0, 11, 15, 1.6, R.gold[2], nil, false)
T.cyl(fountain, "BowlRim", FF, 0, 0, 12.6, 15.6, .6, R.gold[1], nil, false)
T.cyl(fountain, "UpperColumn", FF, 0, 0, 12.6, 2.6, 4, T.white, nil, false)
T.cyl(fountain, "UpperBowl", FF, 0, 0, 16.4, 7, 1.2, R.gold[2], nil, false)
local spout = T.ball(fountain, "Spout", FF, 0, 0, 19.2, 3.4, R.frost[1], Enum.Material.Neon, false)
spout.Transparency = .1
for k = 0, 3 do
	local a = k * math.pi / 2 + math.pi / 4
	local bx, bz = fx + math.cos(a) * 24, fz + math.sin(a) * 24
	bench(fountain, CFrame.lookAt(A.cf(bx, 0, bz).Position, A.cf(fx, 0, fz).Position), R.red)
end

local function place(count, margin, spacing, build)
	local made, tries = 0, 0
	while made < count and tries < 3000 do
		tries += 1
		local x, z = random:NextNumber(-G.BoundaryHalf + 14, G.BoundaryHalf - 14), random:NextNumber(-G.BoundaryHalf + 14, G.BoundaryHalf - 14)
		if clear(x, z, margin, spacing) then
			made += 1
			table.insert(taken, Vector2.new(x, z))
			build(made, x, z)
		end
	end
	return made
end
local props = A.group(scenery, "Props")
-- bushes: two overlapping balls
local bushes = place(16, 8, 11, function(i, x, z)
	local g = A.group(props, "Bush" .. i)
	T.part(g, "Leaves", Vector3.new(6.4, 6.4, 6.4), A.cf(x, 2.4, z), R.green[2], nil, true, Enum.PartType.Ball)
	T.part(g, "Leaves", Vector3.new(4.4, 4.4, 4.4), A.cf(x + 2.6, 1.8, z + 1.2), if i % 3 == 0 then R.pink[2] else R.green[1], nil, false, Enum.PartType.Ball)
end)
-- flower beds
local beds = place(8, 8, 12, function(i, x, z)
	local g = A.group(props, "FlowerBed" .. i)
	T.planter(g, "Planter", x, z, 0, 10, 4.5)
end)
-- boulders: a rounded stone and a lighter cap
place(7, 8, 14, function(i, x, z)
	local g = A.group(props, "Boulder" .. i)
	local yaw = random:NextNumber(0, math.pi)
	T.part(g, "Rock", Vector3.new(8, 4.6, 6), A.cf(x, 2.3, z) * CFrame.Angles(0, yaw, 0), R.stone[2])
	T.part(g, "RockTop", Vector3.new(5, 2, 4), A.cf(x + .6, 5.2, z) * CFrame.Angles(0, yaw + .5, 0), R.stone[1], nil, false)
end)
-- benches along the outside of the ring road, facing the crater
local benches = 0
for k = 0, 7 do
	local a = math.rad(22.5 + k * 45)
	local r = G.LoopRadius + G.PathWidth / 2 + 4.5
	local x, z = math.cos(a) * r, math.sin(a) * r
	if clear(x, z, 4, 6) then
		benches += 1
		table.insert(taken, Vector2.new(x, z))
		local g = A.group(props, "Bench" .. benches)
		bench(g, CFrame.lookAt(A.cf(x, 0, z).Position, A.cf(0, 0, 0).Position), R.blue)
	end
end
-- street lamps along the south plaza: glowing lanterns only, no extra lights (the map keeps <= 12)
local streetLamps = 0
for _, spot in { { 47, -158 }, { -47, -158 }, { 47, -178 }, { -47, -178 }, { 47, -198 }, { -47, -198 }, { 60, -128 }, { -60, -128 } } do
	if clear(spot[1], spot[2], 3, 0) then
		streetLamps += 1
		T.lamp(props, "StreetLamp" .. streetLamps, spot[1], spot[2], 0)
	end
end
-- banners either side of the Refinery and a crate stack by the Trading Post
local flags = 0
for _, spot in { { -30, -166 }, { 30, -166 }, { -30, -188 }, { 30, -188 } } do
	flags += 1
	T.banner(props, "Flag" .. flags, spot[1], spot[2], 0, if flags % 2 == 0 then R.red[2] else R.blue[2], Vector3.new(if spot[1] < 0 then 1 else -1, 0, 0), 18)
end
if clear(-176, -72, 4, 0) then
	local g = A.group(props, "Crates")
	T.crate(g, "CrateA", -176, -72, 0, 4.6, .2)
	T.crate(g, "CrateB", -181.4, -72.6, 0, 4.6, -.15, R.wood[2])
	T.crate(g, "CrateC", -178.6, -72.2, 4.6, 4, .4)
	T.barrel(g, "Barrel", -176, -66.5, 0, R.blue[2])
end

-- lamps: four on the ring road, each with one shadowless light (the map keeps <= 12 enabled lights)
local lamps = {}
for k = 0, 3 do
	local angle = math.rad(45 + k * 90)
	local radius = G.LoopRadius + G.PathWidth / 2 + 3
	table.insert(lamps, Vector2.new(math.cos(angle) * radius, math.sin(angle) * radius))
end
for index, p in lamps do
	local lamp = T.lamp(scenery, "Lamp" .. index, p.X, p.Y, 0)
	local light = Instance.new("PointLight")
	light.Color, light.Brightness, light.Range, light.Shadows = T.glow, .5, 30, false
	light.Parent = lamp:FindFirstChild("Lantern")
end

-- The north end of the spoke: the Commissary building is its own stage (Commissary.luau, TownSquare.Commissary);
-- this group keeps the first-meteor statue to one side of it and the 1-2-3 winners podium to the other.
local watch = A.group(scenery, "MeteorWatch")

-- the first-meteor statue: a dark rock with glowing cracks in a small stone crater, a flame trail behind it
local S = A.frame(sx0, sz0, "S")
T.cyl(watch, "StatueBase", S, 0, 0, 0, 24, 1.2, R.stone[3])
T.cyl(watch, "StatueCrater", S, 0, 0, 1.2, 19, 1.8, R.stone[2])
T.cyl(watch, "StatueCraterFloor", S, 0, 0, 1.2, 15, 2.1, R.rust[3], nil, false)
T.ball(watch, "StatueMeteor", S, 0, 0, 10.6, 15, R.navy[1])
T.ball(watch, "StatueLump", S, 4.6, 2.4, 14.6, 7, R.navy[2], nil, false)
T.ball(watch, "StatueLump", S, -4.4, 1.8, 7.4, 6.6, R.navy[2], nil, false)
local centre = S.world(0, 10.6, 0) + A.offset
for k = 0, 4 do
	local a = k * math.pi * 2 / 5 + .3
	local at = S.world(math.cos(a) * 6.8, 10.6 + math.sin(a * 2) * 3.4, math.sin(a) * 6.8) + A.offset
	T.part(watch, "StatueCrack", Vector3.new(1.4, 1.4, 4.6), CFrame.lookAt(at, at + (at - centre)) * CFrame.Angles(0, 0, a),
		if k % 2 == 0 then R.orange[1] else R.gold[1], Enum.Material.Neon, false)
end
for k = 0, 2 do
	local trail = T.part(watch, "StatueTrail", Vector3.new(5 - k * 1.2, 4.6 - k, 9), S.cf(-3 - k * 3.4, 15 + k * 3.6, -4 - k * 2.6) * CFrame.Angles(math.rad(-25), math.rad(25), 0),
		if k == 0 then R.orange[2] else R.gold[1], Enum.Material.Neon, false, Enum.PartType.Ball)
	trail.Transparency = .25 + k * .15
end
local statueSign = A.signOn(watch, "StatueSign", "THE FIRST METEOR", S, 0, 2.4, 12.2, 15, 2.2, T.ink, .4)
T.smooth(statueSign)

-- the 1-2-3 winners podium with a trophy on the top step
local P = A.frame(px, pz, "S")
T.box(watch, "PodiumBase", P, 0, 0, 0, 28, 13, 1, R.cream[3])
local steps = { { 0, 7.4, R.gold, "1" }, { -8.4, 5, R.stone, "2" }, { 8.4, 3.4, R.orange, "3" } }
for _, step in steps do
	local u, h, ramp, label = step[1], step[2], step[3], step[4]
	T.box(watch, "PodiumBlock", P, u, 0, 1, 8.2, 8, h, ramp[2])
	T.box(watch, "PodiumTop", P, u, 0, 1 + h, 8.6, 8.4, .6, ramp[1], nil, false)
	local board, text = A.signOn(watch, "PodiumNumber", label, P, u, 1 + h / 2 + .2, 4.1, 4, math.min(3.6, h - 1), ramp[3], .2)
	T.smooth(board)
	text.TextColor3 = T.white
end
T.mesh(watch, "Trophy", P.cf(0, 9 + 3.4, 0), 6.8, function()
	T.cyl(watch, "TrophyFoot", P, 0, 0, 9, 3.4, 1, T.ink, nil, false)
	T.cyl(watch, "TrophyStem", P, 0, 0, 10, 1.2, 1.6, R.gold[3], nil, false)
	T.cyl(watch, "TrophyCup", P, 0, 0, 11.6, 4, 3.6, R.gold[2], nil, false)
	for _, side in { -1, 1 } do T.ball(watch, "TrophyHandle", P, side * 2.4, 0, 13.6, 1.6, R.gold[1], nil, false) end
end)
local podiumSign = A.signOn(watch, "PodiumSign", "TOP MINERS", P, 0, 1.2, 6.6, 12, 1.6, R.red[2], .3)
T.smooth(podiumSign)
for _, side in { -1, 1 } do
	local bp = P.world(side * 12.4, 0, -4)
	T.banner(watch, "PodiumBanner", bp.X, bp.Z, 1, if side < 0 then R.gold[2] else R.red[2], -P.right * side, 14)
end
smoothAll(scenery)

for _, part in scenery:GetDescendants() do
	if part:IsA("BasePart") then
		for _, sx in { -1, 1 } do for _, sy in { -1, 1 } do for _, sz in { -1, 1 } do
			local c = part.CFrame * Vector3.new(sx * part.Size.X / 2, sy * part.Size.Y / 2, sz * part.Size.Z / 2) - A.offset
			assert(math.abs(c.X) <= G.BoundaryHalf + .001 and math.abs(c.Z) <= G.BoundaryHalf + .001, "Scenery crossed the boundary")
		end end end
	end
end
assert(A.count(scenery) <= 520 and A.innerCount(A.map) <= 2700, "Scenery/map art budget")
A.map:SetAttribute("SceneryPass", 4)
return { stage = "Scenery", parts = A.count(scenery), trees = trees, lamps = #lamps, bushes = bushes, beds = beds, benches = benches, streetLamps = streetLamps, totalParts = A.count(A.map) }
