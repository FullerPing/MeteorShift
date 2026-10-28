-- Common + Brick + Toon + DebrisFields first. The four biome quarters (the owner's 10 October picture): slices of the
-- circle beyond the ring road (WorldGeometry.Settings.Quarters), each round one ore field's fan of rocks. Each gets
-- its own striped ground and the same set of themed props (big ones along the walls, medium and small ones, trees,
-- boulders), placed round the fan, its landmark and its road, never on them. Pure decoration: nothing here is mined,
-- tinted or registered, and every spot is checked against the zones, the landing radius and every queryable map part
-- (roads, buildings, rocks, trees, lamps), so paths stay clear. Existing scenery inside a quarter takes its leaf
-- colours. Owns Map.Biomes only.
--
-- The live world is Workspace.Map; Common authors Workspace.Map_Redesign, so rename Map to Map_Redesign for the
-- run and back afterwards (the caller does this; see README).
local A = assert(_G.MapRedesignArt)
local T = assert(A.toon, "Run Toon first")
local R = T.ramp
local biomesRoot = A.group(A.map, "Biomes")
local random = Random.new(10102026)
local LANDING_CLEAR = 150 -- props stay outside this radius round the crater (landing parts reach 125)

local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
local palettes = {
	snow = { rgb(250, 253, 255), rgb(214, 238, 252), rgb(160, 206, 236) },
	autumn = { rgb(255, 196, 92), rgb(240, 128, 52), rgb(184, 72, 40) },
	amethyst = { rgb(222, 170, 255), rgb(170, 104, 240), rgb(112, 60, 190) },
	golden = { rgb(255, 236, 120), rgb(236, 196, 60), rgb(190, 140, 40) },
}

-- `ground` and `tile` are the two tones of the quarter's striped ground, `leaves` the trees inside it
local W = A.world
local FAN = A.geometry.Fan
local RING = A.geometry.LoopRadius -- the ring road's centre line: inside it the plaza lawn stays green
local WALL = 270
local biomes = {
	{ id = "RustWorks", ground = rgb(216, 148, 104), tile = rgb(196, 124, 84), leaves = palettes.autumn },
	{ id = "FrostYard", ground = rgb(238, 247, 255), tile = rgb(212, 234, 250), leaves = palettes.snow },
	{ id = "VioletQuarry", ground = rgb(154, 112, 204), tile = rgb(132, 92, 184), leaves = palettes.amethyst },
	{ id = "SulfurRidge", ground = rgb(246, 222, 122), tile = rgb(232, 200, 96), leaves = palettes.golden },
}
for index, b in biomes do
	local q = W.quarter(b.id)
	b.index, b.from, b.to = index, q.from, q.to
end
local function inBiome(b, x, z) return math.abs(x) <= WALL and math.abs(z) <= WALL and W.quarterAt(x, z) == b.id end
-- how far from the crater the wall is along a direction (degrees)
local function wallDistance(deg)
	local c, s = math.abs(math.cos(math.rad(deg))), math.abs(math.sin(math.rad(deg)))
	return math.min(if c > 1e-6 then WALL / c else math.huge, if s > 1e-6 then WALL / s else math.huge)
end

-- decoration flags: never in the way of a query, a raycast or a footstep unless `solid`
local function deco(p, solid)
	p.CanCollide, p.CanQuery, p.CanTouch = solid == true, solid == true, false
	return p
end
local function partAt(parent, name, size, cf, color, material, solid, shape)
	return deco(T.part(parent, name, size, cf, color, material, solid, shape), solid)
end

-- ground: thin spokes from the ring road out to the walls, about 2.5 degrees each, alternating the quarter's two tones,
-- so every quarter is a striped slice pointing at the crater. Neighbouring spokes overlap toward the crater, so no
-- two neighbours (in a quarter or across a quarter's edge) share a height: four levels .07 apart, tops .07 to .28,
-- on the grass (top 0) and under the roads (.38). Coplanar overlaps flicker as the camera moves. The lawn tiles (24-stud checker, top .2) that touch a quarter are hidden, keeping their original look in
-- attributes so a rerun (or a revert) starts from it.
local function ground(b, g)
	local n = math.ceil((b.to - b.from) / 2.5)
	local step = (b.to - b.from) / n
	local inner = RING + 2
	for k = 0, n - 1 do
		local deg = b.from + (k + .5) * step
		local outer = wallDistance(deg)
		local width = 2 * outer * math.tan(math.rad(step / 2)) + .4
		local mid = (inner + outer) / 2
		local top = .07 * (1 + k % 2 + 2 * (b.index % 2))
		local cf = A.cf(math.cos(math.rad(deg)) * mid, top - .05, math.sin(math.rad(deg)) * mid) * CFrame.Angles(0, -math.rad(deg), 0)
		local spoke = partAt(g, "Ground", Vector3.new(outer - inner, .1, width), cf, if k % 2 == 0 then b.ground else b.tile)
		spoke.CastShadow = false
	end
end
local function tintLawn()
	local count = 0
	local lawn = A.map:FindFirstChild("Ground")
	for _, tile in (if lawn then lawn:GetDescendants() else {}) do
		if tile:IsA("BasePart") and tile.Name:match("^LawnTile") then
			-- back to its original look first (colour from the first biome pass, transparency from this one)
			local color, clear = tile:GetAttribute("BiomeOriginalColor"), tile:GetAttribute("BiomeOriginalTransparency")
			if color ~= nil then tile.Color = color end
			if clear == nil then tile:SetAttribute("BiomeOriginalTransparency", tile.Transparency); clear = tile.Transparency end
			tile.Transparency = clear
			local texture = tile:FindFirstChildWhichIsA("Texture")
			local touches = false
			for _, c in { { 0, 0 }, { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } } do
				local x, z = tile.Position.X + c[1] * tile.Size.X / 2, tile.Position.Z + c[2] * tile.Size.Z / 2
				if W.quarterAt(x, z) then touches = true end
			end
			if touches then
				tile.Transparency = 1
				if texture then
					if texture:GetAttribute("BiomeOriginalTransparency") == nil then texture:SetAttribute("BiomeOriginalTransparency", texture.Transparency) end
					texture.Transparency = 1
				end
				count += 1
			elseif texture and texture:GetAttribute("BiomeOriginalTransparency") ~= nil then
				texture.Transparency = texture:GetAttribute("BiomeOriginalTransparency")
			end
		end
	end
	return count
end

-- Is a prop of radius r at (x, z) on open grass inside its quarter?
local blockers = OverlapParams.new()
blockers.FilterType = Enum.RaycastFilterType.Exclude
local spots: { { x: number, z: number, r: number } } = {} -- props placed so far: they never overlap each other
local function open(b, x, z, r)
	-- the whole footprint inside its own quarter, off the fan, the landmark, the gate and the field road
	for _, c in { { 0, 0 }, { r, 0 }, { -r, 0 }, { 0, r }, { 0, -r } } do
		if not inBiome(b, x + c[1], z + c[2]) then return false end
	end
	if W.inFan(b.id, x, z, r + 5) or W.onLandmark(b.id, x, z, r + 4) then return false end
	local d, lat = W.fanCoords(b.id, x, z)
	if d < FAN.Landing + 12 + r and math.abs(lat) < 9 + r + 6 then return false end
	for _, s in spots do
		if (Vector2.new(x, z) - Vector2.new(s.x, s.z)).Magnitude < r + s.r + 3 then return false end
	end
	if math.abs(x) + r > 262 or math.abs(z) + r > 262 then return false end
	if Vector2.new(x, z).Magnitude < LANDING_CLEAR + r then return false end
	for _, zone in A.geometry.Zones do
		if not zone.quarter and math.abs(x - zone.x) < zone.width / 2 + r + 6 and math.abs(z - zone.z) < zone.depth / 2 + r + 6 then return false end
	end
	blockers.FilterDescendantsInstances = { A.map:FindFirstChild("Ground"), biomesRoot }
	local hits = workspace:GetPartBoundsInBox(A.cf(x, 6, z), Vector3.new(r * 2 + 6, 10, r * 2 + 6), blockers)
	for _, hit in hits do
		if hit:IsDescendantOf(A.map) then return false end
	end
	return true
end
-- a random point in the quarter (even over its area)
local function somewhere(b)
	local deg = random:NextNumber(b.from, b.to)
	local d = math.sqrt(random:NextNumber(LANDING_CLEAR ^ 2, wallDistance(deg) ^ 2))
	return math.cos(math.rad(deg)) * d, math.sin(math.rad(deg)) * d
end
-- up to `count` spots of radius r; calls build(x, z, index) for each
local function scatter(b, count, r, build)
	local placed, tries = 0, 0
	while placed < count and tries < count * 400 do
		tries += 1
		local x, z = somewhere(b)
		if open(b, x, z, r) then
			placed += 1
			table.insert(spots, { x = x, z = z, r = r })
			build(x, z, placed)
		end
	end
	return placed
end

-- the same, but hugging the walls (a strip `band` deep inside them): big cliffs and clusters frame each quarter
local function scatterEdge(b, count, r, band, build)
	local placed, tries = 0, 0
	while placed < count and tries < count * 600 do
		tries += 1
		local x, z = somewhere(b)
		local nearWall = math.abs(x) > 262 - r - band or math.abs(z) > 262 - r - band
		if nearWall and open(b, x, z, r) then
			placed += 1
			table.insert(spots, { x = x, z = z, r = r })
			build(x, z, placed)
		end
	end
	return placed
end

-- props ------------------------------------------------------------------------------------------------------------
local function crystalCluster(g, x, z, scale, colors, tip)
	local m = Instance.new("Model")
	m.Name = "CrystalCluster"
	m.Parent = g
	partAt(m, "Base", Vector3.new(6, 2.4, 6) * scale, A.cf(x, 1.2 * scale, z) * CFrame.Angles(0, random:NextNumber(0, 6), 0), R.stone[3], nil, true)
	for k = 1, 4 do
		local h = (if k == 1 then 16 else random:NextNumber(7, 12)) * scale
		local yaw = (k / 4) * math.pi * 2 + random:NextNumber(-.4, .4)
		local lean = if k == 1 then random:NextNumber(-.08, .08) else random:NextNumber(.3, .55)
		local at = A.cf(x, 1.6 * scale, z) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(lean, 0, 0) * CFrame.new(0, h / 2, 0)
		local p = partAt(m, "Crystal", Vector3.new(3.2 * scale, h, 3.2 * scale), at * CFrame.Angles(0, math.rad(45), 0), colors[(k % 2) + 1], Enum.Material.Glass)
		p.Transparency = .12
		if k == 1 and tip then partAt(m, "CrystalTip", Vector3.new(2.2, 2.2, 2.2) * scale, at * CFrame.new(0, h / 2, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)), tip, Enum.Material.Neon) end
	end
	return m
end

local function mesa(g, x, z, w, h, ramp)
	local m = Instance.new("Model")
	m.Name = "Mesa"
	m.Parent = g
	local yaw = CFrame.Angles(0, random:NextNumber(0, math.pi), 0)
	local base = A.cf(x, 0, z) * yaw
	partAt(m, "Body", Vector3.new(w, h * .6, w * .8), base * CFrame.new(0, h * .3, 0), ramp[2], nil, true)
	partAt(m, "Step", Vector3.new(w * .74, h * .3, w * .6), base * CFrame.new(w * .06, h * .75, -w * .04), ramp[2], nil, true)
	partAt(m, "Cap", Vector3.new(w * .56, h * .14, w * .46), base * CFrame.new(w * .1, h * .97, -w * .06), ramp[1], nil, true)
	partAt(m, "Shade", Vector3.new(w * .5, h * .42, w * .3), base * CFrame.new(-w * .32, h * .21, w * .32), ramp[3], nil, true)
	return m
end

local function blob(g, name, x, z, size, color, sink)
	local p = T.blob(g, name, size, A.cf(x, size.Y / 2 - (sink or size.Y * .2), z) * CFrame.Angles(0, random:NextNumber(0, 6), 0), color)
	return p
end

local function pool(g, x, z, d)
	partAt(g, "PoolRim", Vector3.new(.8, d + 3, d + 3), A.cf(x, .4, z) * CFrame.Angles(0, 0, math.pi / 2), R.sulfur[3], nil, true, Enum.PartType.Cylinder)
	local glow = partAt(g, "PoolGlow", Vector3.new(.3, d, d), A.cf(x, .72, z) * CFrame.Angles(0, 0, math.pi / 2), rgb(255, 226, 80), Enum.Material.Neon, false, Enum.PartType.Cylinder)
	glow.CastShadow = false
end

local function derrick(g, x, z)
	local m = Instance.new("Model")
	m.Name = "Derrick"
	m.Parent = g
	local h = 22
	local yaw = A.cf(x, 0, z) * CFrame.Angles(0, random:NextNumber(0, math.pi), 0)
	for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		local foot = (yaw * CFrame.new(c[1] * 5, 0, c[2] * 5)).Position
		local top = (yaw * CFrame.new(c[1] * 1.4, h, c[2] * 1.4)).Position
		local mid = (foot + top) / 2
		partAt(m, "Leg", Vector3.new(1.2, 1.2, (top - foot).Magnitude), CFrame.lookAt(mid, top), R.wood[2], nil, true)
	end
	partAt(m, "Deck", Vector3.new(6, 1, 6), yaw * CFrame.new(0, h * .5, 0), R.wood[3], nil, false)
	partAt(m, "Head", Vector3.new(4.4, 1.6, 4.4), yaw * CFrame.new(0, h + .8, 0), R.orange[2], nil, false)
	partAt(m, "Wheel", Vector3.new(.8, 5, 5), yaw * CFrame.new(0, h + 3.6, 0) * CFrame.Angles(0, math.pi / 2, 0), T.ink, nil, false, Enum.PartType.Cylinder)
	return m
end

local function orePile(g, x, z, color)
	for k = 0, 2 do
		local s = 3.4 - k * .6
		partAt(g, "OrePile", Vector3.new(s, s, s), A.cf(x + (k - 1) * 1.6, s * .4 + (if k == 1 then 1 else 0), z + (k % 2) * 1.2), if k == 1 then color else R.rust[3], nil, false, Enum.PartType.Ball)
	end
end

local function spire(g, x, z, h)
	local yaw = CFrame.Angles(0, random:NextNumber(0, math.pi), 0)
	partAt(g, "Spire", Vector3.new(5, h, 5), A.cf(x, h / 2, z) * yaw * CFrame.Angles(random:NextNumber(-.08, .08), 0, random:NextNumber(-.08, .08)), R.navy[2], nil, true)
	partAt(g, "SpireCap", Vector3.new(3.4, 3.4, 3.4), A.cf(x, h + .6, z) * yaw * CFrame.Angles(math.rad(45), 0, math.rad(45)), R.violet[1], Enum.Material.Neon, false)
end

local function tree(g, x, z, index, kind, palette, scale)
	local t = T.tree(g, "BiomeTree" .. index, x, z, 0, scale, kind, palette)
	for _, p in t:GetDescendants() do if p:IsA("BasePart") and p.Name ~= "Trunk" then deco(p) end end
	return t
end

-- build ------------------------------------------------------------------------------------------------------------
local report = {}
for _, b in biomes do
	local g = A.group(biomesRoot, b.id)
	ground(b, g)
	local made = {}
	-- the same set in every quarter, biggest first so they find room: 6 big props near the walls, 8 trees, 10 medium,
	-- 10 small, 5 boulders (the side quarters are smaller than the corner ones, so they may fit a few less)
	if b.id == "FrostYard" then
		made.big = scatterEdge(b, 6, 12, 30, function(x, z)
			blob(g, "IceCliff", x, z, Vector3.new(random:NextNumber(20, 28), random:NextNumber(16, 24), random:NextNumber(16, 22)), R.frost[2], 3)
			blob(g, "IceCliffSnow", x, z, Vector3.new(16, 6, 13), T.white, -10)
		end)
		made.trees = scatter(b, 8, 7, function(x, z, i) tree(g, x, z, i, "pine", palettes.snow, random:NextNumber(1, 1.4)) end)
		made.medium = scatter(b, 10, 7, function(x, z) crystalCluster(g, x, z, random:NextNumber(.9, 1.4), { R.frost[2], R.frost[1] }, nil) end)
		made.small = scatter(b, 10, 6, function(x, z) blob(g, "SnowMound", x, z, Vector3.new(random:NextNumber(9, 14), random:NextNumber(4, 6), random:NextNumber(8, 12)), T.white) end)
		made.boulders = scatter(b, 5, 5, function(x, z) blob(g, "IceBoulder", x, z, Vector3.new(8, 7, 7), R.frost[3], 1) end)
	elseif b.id == "RustWorks" then
		made.big = scatterEdge(b, 6, 13, 30, function(x, z) mesa(g, x, z, random:NextNumber(22, 28), random:NextNumber(20, 28), R.rust) end)
		made.trees = scatter(b, 8, 7, function(x, z, i) tree(g, x, z, i, nil, palettes.autumn, random:NextNumber(.9, 1.2)) end)
		made.medium = scatter(b, 6, 11, function(x, z) mesa(g, x, z, random:NextNumber(14, 22), random:NextNumber(10, 18), R.rust) end)
			+ scatter(b, 4, 8, function(x, z) derrick(g, x, z) end)
		made.small = scatter(b, 10, 4, function(x, z) orePile(g, x, z, R.orange[1]) end)
		made.boulders = scatter(b, 5, 5, function(x, z) blob(g, "Boulder", x, z, Vector3.new(8, 6, 7), R.rust[3], 1) end)
	elseif b.id == "VioletQuarry" then
		made.big = scatterEdge(b, 6, 11, 30, function(x, z) crystalCluster(g, x, z, random:NextNumber(1.8, 2.2), { R.violet[2], R.violet[3] }, R.pink[1]) end)
		made.trees = scatter(b, 8, 7, function(x, z, i) tree(g, x, z, i, nil, palettes.amethyst, random:NextNumber(.9, 1.2)) end)
		made.medium = scatter(b, 10, 7, function(x, z) crystalCluster(g, x, z, random:NextNumber(1, 1.5), { R.violet[2], R.violet[1] }, R.pink[1]) end)
		made.small = scatter(b, 10, 4, function(x, z) spire(g, x, z, random:NextNumber(12, 20)) end)
		made.boulders = scatter(b, 5, 5, function(x, z) blob(g, "Boulder", x, z, Vector3.new(8, 6, 7), R.navy[1], 1) end)
	else
		made.big = scatterEdge(b, 6, 13, 30, function(x, z) mesa(g, x, z, random:NextNumber(22, 28), random:NextNumber(20, 30), R.gold) end)
		made.trees = scatter(b, 8, 7, function(x, z, i) tree(g, x, z, i, nil, palettes.golden, random:NextNumber(.9, 1.2)) end)
		made.medium = scatter(b, 10, 9, function(x, z) mesa(g, x, z, random:NextNumber(12, 18), random:NextNumber(10, 18), R.gold) end)
		made.small = scatter(b, 10, 6, function(x, z) pool(g, x, z, random:NextNumber(7, 10)) end)
		made.boulders = scatter(b, 5, 5, function(x, z) blob(g, "Boulder", x, z, Vector3.new(8, 6, 7), R.sulfur[3], 1) end)
	end
	for _, v in g:GetDescendants() do if v:IsA("BasePart") then v:SetAttribute("MapRedesignOwned", true) end end
	made.parts = A.count(g)
	report[b.id] = made
end

-- existing scenery inside a quarter takes its leaf colours (green leaves only; trunks, lamps and stone stay)
local tinted = 0
local scenery = A.map:FindFirstChild("Scenery")
if scenery then
	for _, p in scenery:GetDescendants() do
		if p:IsA("BasePart") and p.Name ~= "Trunk" then
			local c = p.Color
			if c.G > c.R + .08 and c.G > c.B + .08 then
				for _, b in biomes do
					if inBiome(b, p.Position.X, p.Position.Z) then
						local _, _, v = c:ToHSV()
						p.Color = if v > .82 then b.leaves[1] elseif v > .66 then b.leaves[2] else b.leaves[3]
						tinted += 1
					end
				end
			end
		end
	end
end

local lawnTinted = tintLawn()
local inner = A.innerCount(A.map)
assert(inner <= 2700, "Inner map over its 2,700-part budget: " .. inner)
A.map:SetAttribute("BiomesPass", 3)
return { stage = "Biomes", biomes = report, biomeParts = A.count(biomesRoot), tintedScenery = tinted, lawnTiles = lawnTinted, innerParts = inner }
