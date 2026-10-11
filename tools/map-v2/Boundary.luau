-- Common + Brick + Toon first. The boundary as a castle rampart (Crater Isle): solid walls with a dark base course, pillar
-- strips with banners, a two-tier cap, rounded merlons and lanterns, four big round corner towers and four decorative
-- closed gatehouses; plus the checkerboard lawn. Owns Boundary and Ground.Lawn. The solid walls keep the closed
-- 540 x 540 play area: inner faces at +-270, 28 high, bottom Y-4, top Y24 (the server enforces bounds by position; the
-- walls just stop people walking out). Every other piece is visual and non-colliding and stays within 0.8 studs of the
-- inner wall face below Y24. The kill plane stays. The hills, mountains and sea live in Surroundings and Backdrop.
local A = assert(_G.MapRedesignArt)
local C, G = A.colors, assert(A.geometry)
local half = G.BoundaryHalf
local boundary = A.group(A.map, "Boundary")
local wallH, wallT, wallBottom = 28, 16, -4
local wallTop = wallBottom + wallH

local T = assert(A.toon, "Run Toon first")
local R = T.ramp

-- solid walls, one continuous part per side (studded by StudStyle)
local wallNames = { [-1] = { "WestWall", "SouthWall" }, [1] = { "EastWall", "NorthWall" } }
for _, sign in { -1, 1 } do
	A.part(boundary, wallNames[sign][1], Vector3.new(wallT, wallH, half * 2 + wallT * 2), A.cf(sign * (half + wallT / 2), wallBottom + wallH / 2, 0), C.rockB)
	A.part(boundary, wallNames[sign][2], Vector3.new(half * 2 + wallT * 2, wallH, wallT), A.cf(0, wallBottom + wallH / 2, sign * (half + wallT / 2)), C.rockB)
end

-- one frame per wall: forward = toward the play area, so d = -270 is the inner face and d = -278 the wall's middle; u runs
-- along the wall. (Names must not end in "Wall": StudStyle studs only the four solid walls.)
local inward = { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } -- west, east, south, north walls
local banners = { R.violet, R.gold, R.red, R.blue }
local pillarPitch, pillarCount = 45, 12
local FACE = -half
for side, dir in inward do
	local F = A.frame(0, 0, dir)
	local function deco(p) return T.deco(p) end
	-- the dark base course and the light top band, a hair proud of the studded face
	deco(T.box(boundary, "WallBase", F, 0, FACE, wallBottom, half * 2, .8, 7, R.navy[2], nil, false))
	deco(T.box(boundary, "WallTopBand", F, 0, FACE, 18, half * 2, .8, wallTop - 18, R.cream[2], nil, false))
	-- two-tier cap: a navy drip band under a light stone cap
	deco(T.box(boundary, "WallDrip", F, 0, -half - wallT / 2 + .4, wallTop, half * 2 + wallT * 2 + 2, wallT + 3.6, .8, R.navy[2], nil, false))
	deco(T.box(boundary, "WallCap", F, 0, -half - wallT / 2 + .4, wallTop + .8, half * 2 + wallT * 2 + 2, wallT + 2.4, 1.6, R.stone[1], nil, false))
	local top = wallTop + 2.4
	-- pillar strips down the face
	for k = 0, pillarCount - 1 do
		local u = (k - (pillarCount - 1) / 2) * pillarPitch
		deco(T.box(boundary, "Pillar", F, u, FACE, wallBottom, 4, .8, wallH, R.stone[1], nil, false))
		-- a gold lantern on every third pillar
		if k % 3 == 1 then
			deco(T.cyl(boundary, "LanternPost", F, u, -half - 3, top, 1.2, 5, R.navy[2], nil, false))
			deco(T.ball(boundary, "Lantern", F, u, -half - 3, top + 6, 3.2, R.gold[1], Enum.Material.Neon, false))
		end
	end
	-- rounded merlons: a block with an arch top (16 per side, gap left for the gatehouse)
	for k = 0, 17 do
		local u = -255 + k * 30
		if math.abs(u) > 22 then
			deco(T.box(boundary, "Merlon", F, u, -half - wallT / 2, top, 10, 9, 3.5, R.stone[1], nil, false))
			deco(T.cylDep(boundary, "MerlonTop", F, u, -half - wallT / 2, top + 3.5, 10, 9, R.stone[1], nil, false))
		end
	end
	-- four banners hang between the pillars, coloured for the side
	local ramp = banners[side]
	for k, u in { -180, -90, 90, 180 } do
		deco(T.cylLat(boundary, "BannerRod", F, u, FACE + .2, 21.4, .7, 10, T.ink, nil, false))
		deco(T.box(boundary, "BannerCloth", F, u, FACE + .15, 8, 8, .3, 13, ramp[2], nil, false))
		deco(T.cylDep(boundary, "BannerEmblem", F, u, FACE + .5, 14.6, 4.8, .3, if k % 2 == 0 then T.white else R.gold[1], nil, false))
	end
	-- the closed gatehouse in the middle: an arched frame and a barred navy door set into the face, two torches, a
	-- keystone, and a little gate house with two round turrets on the wall top
	deco(T.box(boundary, "GateFrame", F, 0, FACE - .1, 0, 18, .6, 12, R.cream[2], nil, false))
	deco(T.cylDep(boundary, "GateFrameArch", F, 0, FACE - .1, 12, 18, .6, R.cream[2], nil, false))
	deco(T.box(boundary, "GateDoor", F, 0, FACE + .2, 0, 14, .4, 12, R.navy[3], nil, false))
	deco(T.cylDep(boundary, "GateDoorArch", F, 0, FACE + .2, 12, 14, .4, R.navy[3], nil, false))
	for _, u in { -4.5, -1.5, 1.5, 4.5 } do deco(T.box(boundary, "GateBar", F, u, FACE + .5, 0, .5, .3, 16.4, R.navy[1], nil, false)) end
	for _, y in { 5, 11 } do deco(T.box(boundary, "GateBar", F, 0, FACE + .5, y, 14, .3, .5, R.navy[1], nil, false)) end
	deco(T.box(boundary, "GateKeystone", F, 0, FACE - .1, 18.4, 2.6, .7, 2.8, R.gold[2], nil, false))
	for _, u in { -11.5, 11.5 } do
		deco(T.cyl(boundary, "TorchPost", F, u, FACE + .6, 5, .8, 4.5, T.ink, nil, false))
		deco(T.ball(boundary, "Torch", F, u, FACE + .6, 10.4, 2.4, R.orange[1], Enum.Material.Neon, false))
	end
	for _, u in { -13, 13 } do
		local d = -half - wallT / 2
		deco(T.cyl(boundary, "GateTurret", F, u, d, top, 12, 11, R.cream[2], nil, false))
		deco(T.cyl(boundary, "GateTurretBand", F, u, d, top + 8, 13.4, 1.8, R.red[2], nil, false))
		deco(T.cyl(boundary, "GateTurretRoof", F, u, d, top + 11, 13, 4, R.navy[2], nil, false))
		deco(T.cyl(boundary, "GateTurretRoof", F, u, d, top + 15, 8, 4, R.navy[1], nil, false))
		deco(T.ball(boundary, "GateTurretKnob", F, u, d, top + 19.4, 3, R.gold[2], nil, false))
	end
	deco(T.box(boundary, "GateHouse", F, 0, -half - wallT / 2, top, 14, 12, 8, R.cream[1], nil, false))
	T.gable(boundary, "GateRoof", F, 0, -half - wallT / 2, top + 8, 14, 12, 6, R.red[2], R.cream[1], 1.6)
end

-- the four round corner towers: the body just touches the inner wall faces and stands on a plinth that reaches the sea
for _, sx in { -1, 1 } do
	for _, sz in { -1, 1 } do
		T.roundTower(boundary, sx * (half + 18), sz * (half + 18), -16, 40, 36, R.red, R.navy)
	end
end

-- only the four walls collide (the gate roofs come from the shared gable helper, which builds solid parts)
for _, v in boundary:GetDescendants() do
	if v:IsA("BasePart") and not v.Name:find("Wall$") then T.deco(v) end
end
local kill = A.part(boundary, "KillPlane", Vector3.new(half * 2 + 1400, 1, half * 2 + 1400), A.cf(0, G.KillPlaneY, 0), C.navy, nil, false)
kill.Transparency, kill.CanTouch = 1, true
kill:SetAttribute("BoundaryKillPlane", true)
boundary:SetAttribute("WallHeight", wallH)
A.map:SetAttribute("BoundaryVersion", 5)
assert(A.count(boundary) <= 620, "Boundary art budget: " .. A.count(boundary))

-- the lawn: two-tone checker plates over the grass, skipping the crater, the zones and the roads (parts budget)
local ground = A.map:FindFirstChild("Ground")
assert(ground and ground:GetAttribute("MapRedesignOwned"), "Run Crater first")
local lawn = A.group(ground, "Lawn")
local tile = 24
local count = 0
local function blocked(x, z)
	if Vector2.new(x, z).Magnitude < A.crater.OpeningRadius + 24 then return true end
	-- skip any tile that overlaps a zone footprint (the buildings and fields sit on their own floors)
	for _, zone in G.Zones do
		if math.abs(x - zone.x) < zone.width / 2 + tile / 2 and math.abs(z - zone.z) < zone.depth / 2 + tile / 2 then return true end
	end
	-- the ring road
	local r = Vector2.new(x, z).Magnitude
	if math.abs(r - G.LoopRadius) < tile * .55 + G.PathWidth / 2 then return true end
	-- the south plaza from behind the Refinery to the ring
	local refinery = A.zone("Refinery")
	if math.abs(x) < tile / 2 + G.SouthPlazaHalf and z < -G.LoopRadius + 10 and z > refinery.z - refinery.depth / 2 - 6 - tile / 2 then return true end
	return false
end
local cells = math.floor(half * 2 / tile)
for i = 0, cells - 1 do
	for j = 0, cells - 1 do
		if (i + j) % 2 == 0 then
			local x, z = -half + tile / 2 + i * tile + (half * 2 - cells * tile) / 2, -half + tile / 2 + j * tile + (half * 2 - cells * tile) / 2
			if not blocked(x, z) then
				count += 1
				local plate = A.part(lawn, "LawnTile", Vector3.new(tile, .2, tile), A.cf(x, .1, z), C.lawnB, nil, false)
				plate.CanQuery = false
				plate.CastShadow = false
			end
		end
	end
end
assert(A.innerCount(A.map) <= 2700, "Map budget")
return { stage = "Boundary", boundaryParts = A.count(boundary), lawnTiles = count, totalParts = A.count(A.map) }
