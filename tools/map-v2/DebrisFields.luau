-- Common + Brick + Toon first; Scenery before it, Biomes after it. The four ore fields, one in each biome quarter
-- (WorldGeometry.Settings.Quarters): a gate on the quarter's centre line just past the ring road, a fan of twenty
-- rocks opening from it toward the wall and the field's landmark at the far end. Drops, odds and HP never read colour
-- or art. Contracts: Map.Debris holds 80 BasePart roots with attr Field (DebrisService tints only OreFleck children);
-- DebrisFields.<Id> is a Model whose PrimaryPart "FieldFloor" (invisible, walk-through, on the field road inside the
-- gate) is where ORE travel lands (DebrisService:_fieldSpot) and carries attr Entrance and a FieldSign.
-- Before a rerun remove Map.Biomes (its solid props would crowd the rock slots), then rerun Biomes.
local A = assert(_G.MapRedesignArt)
local T = assert(A.toon, "Run Toon first")
local R = T.ramp
local debris = A.group(A.map, "Debris", "Folder")
local fields = A.group(A.map, "DebrisFields")
local random = Random.new(4812)

-- facing = the way the field's entrance looks from its centre; each biome's landmark stands at the rear.
local biomes = {
	{ id = "RustWorks", title = "RUST WORKS", facing = "S", ore = R.orange[1], floor = R.rust[2], patch = R.rust[3], trim = R.orange[2], rock = R.rust, post = R.wood[2] },
	{ id = "FrostYard", title = "FROST YARD", facing = "S", ore = R.frost[2], floor = R.frost[1], patch = T.white, trim = R.blue[1], rock = R.frost, post = R.frost[3] },
	{ id = "VioletQuarry", title = "VIOLET QUARRY", facing = "E", ore = R.violet[1], floor = R.violet[3], patch = R.navy[1], trim = R.pink[2], rock = R.navy, post = R.violet[2] },
	{ id = "SulfurRidge", title = "SULFUR RIDGE", facing = "W", ore = R.gold[1], floor = R.sulfur[3], patch = R.sulfur[2], trim = R.orange[2], rock = R.stone, post = T.ink },
}

local function smoke(parent, color, rate)
	local e = Instance.new("ParticleEmitter")
	e.Name = "Smoke"
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(color)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 6) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, .5), NumberSequenceKeypoint.new(1, 1) })
	e.Rate, e.Lifetime, e.Speed = rate or 3, NumberRange.new(2, 4), NumberRange.new(3, 6)
	e.EmissionDirection = Enum.NormalId.Top
	e.Parent = parent
end

local function landmark(b, field, F)
	local function box(name, u, d, y0, lat, dep, h, c, material, collide) return T.box(field, name, F, u, d, y0, lat, dep, h, c, material, collide) end
	local rear = -F.dep / 2 + 9 -- rear-strip centre (depth coordinate)
	local id = b.id
	if id == "RustWorks" then
		-- an orange gantry crane over a mine-cart track, with a hanging ore bucket and rusty barrels
		for _, side in { -1, 1 } do
			T.cyl(field, "CraneLeg", F, side * 24, rear, .6, 3.6, 26, R.orange[2])
			T.cyl(field, "CraneFoot", F, side * 24, rear, .6, 6, 1.6, R.orange[3])
			T.ball(field, "CraneKnob", F, side * 24, rear, 27.2, 4, R.gold[2], nil, false)
		end
		box("CraneBeam", 0, rear, 24, 52, 4.4, 3.6, R.orange[1])
		box("CraneTrolley", 7, rear, 20.6, 6, 6, 3.4, T.ink)
		T.cyl(field, "CraneCable", F, 7, rear, 12.6, .5, 8, T.ink, nil, false)
		T.cyl(field, "OreBucket", F, 7, rear, 9, 5, 3.6, R.stone[2], nil, false)
		for k = 0, 2 do T.ball(field, "BucketOre", F, 5.8 + k * 1.2, rear + (k % 2) * 1, 12.8, 2.4, b.ore, nil, false) end
		-- the track runs across the rear strip, two carts on it
		for _, s in { -1, 1 } do box("TrackRail", 0, rear + 4.6 + s * 1.6, .6, F.lat - 12, .5, .5, T.ink, nil, false) end
		for k = 0, 6 do box("TrackTie", -33 + k * 11, rear + 4.6, .6, 1.2, 5, .3, R.wood[3], nil, false) end
		for _, cu in { -18, 17 } do
			box("MineCart", cu, rear + 4.6, 1.4, 6, 4.4, 3.4, R.stone[3])
			box("MineCartRim", cu, rear + 4.6, 4.8, 6.4, 4.8, .6, R.orange[2], nil, false)
			for k = 0, 1 do T.ball(field, "CartOre", F, cu - 1.4 + k * 2.6, rear + 4.6, 5.6, 2.6, b.ore, nil, false) end
		end
		for k = 0, 2 do
			local p = F.world(-36 + k * 5, 0, rear - 2 + (k % 2) * 3)
			T.barrel(field, "RustBarrel", p.X, p.Z, .6, if k % 2 == 0 then R.rust[1] else R.orange[3], 5)
		end
	elseif id == "FrostYard" then
		-- an ice cave arch with icicles, snow heaps and a snowman
		for _, side in { -1, 1 } do
			box("IcePillar", side * 13, rear, .6, 8, 8, 16, R.frost[2])
			box("IcePillarCap", side * 13, rear, 16.6, 9, 9, 2, T.white)
		end
		box("IceLintel", 0, rear, 18.6, 36, 9, 6, R.frost[1])
		box("SnowCap", 0, rear, 24.6, 37, 10, 1.6, T.white)
		box("CaveMouth", 0, rear - 3.6, .6, 18, 1, 16, R.frost[3], nil, false)
		for k = 0, 4 do
			local u = -8 + k * 4
			local p = A.part(field, "Icicle", Vector3.new(2, 4 + (k % 2) * 2, 2), F.cf(u, 18.6 - (2 + (k % 2)), rear + 3.6) * CFrame.Angles(0, 0, math.rad(45)), R.frost[2], Enum.Material.Glass, false)
			T.smooth(p)
		end
		for k, data in { { -32, 9 }, { -24, 7 }, { 28, 10 }, { 35, 6.6 } } do
			local p = F.world(data[1], 0, rear + (k % 2) * 3)
			T.part(field, "SnowHeap", Vector3.new(data[2], data[2], data[2]), A.cf(p.X, .6, p.Z), T.white, nil, false, Enum.PartType.Ball)
		end
		-- the snowman
		local sp = F.world(24, 0, rear + 2)
		T.part(field, "SnowmanBase", Vector3.new(7, 7, 7), A.cf(sp.X, 3.6, sp.Z), T.white, nil, true, Enum.PartType.Ball)
		T.part(field, "SnowmanBody", Vector3.new(5.4, 5.4, 5.4), A.cf(sp.X, 8.6, sp.Z), T.white, nil, false, Enum.PartType.Ball)
		T.part(field, "SnowmanHead", Vector3.new(4, 4, 4), A.cf(sp.X, 12.6, sp.Z), T.white, nil, false, Enum.PartType.Ball)
		local nose = A.cf(sp.X, 12.6, sp.Z).Position + F.forward * 2
		T.part(field, "SnowmanNose", Vector3.new(.8, .8, 2.4), CFrame.lookAt(nose, nose + F.forward), R.orange[2], nil, false)
		T.part(field, "SnowmanHat", Vector3.new(2.4, 3.6, 3.6), A.cf(sp.X, 15, sp.Z) * CFrame.Angles(0, 0, math.pi / 2), T.ink, nil, false, Enum.PartType.Cylinder)
		T.part(field, "SnowmanScarf", Vector3.new(1.2, 5, 5), A.cf(sp.X, 10.8, sp.Z) * CFrame.Angles(0, 0, math.pi / 2), R.red[2], nil, false, Enum.PartType.Cylinder)
	elseif id == "VioletQuarry" then
		-- a giant crystal cluster on a dark plinth, with smaller shards and a quarry cart
		box("CrystalPlinth", 0, rear, .6, 30, 12, 2.4, R.navy[2])
		local heights = { 14, 22, 30, 20, 12 }
		for k, h in heights do
			local u = -12 + (k - 1) * 6
			local at = F.world(u, 3 + h / 2, rear + ((k % 2) * 2 - 1)) + A.offset
			local p = T.part(field, "Crystal", Vector3.new(4.6, h, 4.6), CFrame.new(at) * CFrame.Angles(0, math.rad(45), math.rad((k - 3) * 9)),
				if k % 2 == 0 then R.violet[1] else R.violet[2], Enum.Material.Glass, false)
			p.Transparency = .1
			T.part(field, "CrystalTip", Vector3.new(3.2, 3.2, 3.2), CFrame.new(at) * CFrame.Angles(0, math.rad(45), math.rad((k - 3) * 9)) * CFrame.new(0, h / 2, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
				R.pink[1], Enum.Material.Neon, false)
		end
		for k = 0, 3 do
			local p = F.world(-36 + k * 24 + (if k >= 2 then 6 else 0), 0, rear + 3)
			if math.abs(-36 + k * 24) > 16 then
				T.part(field, "Shard", Vector3.new(3, 9, 3), A.cf(p.X, 4.6, p.Z) * CFrame.Angles(math.rad(12), math.rad(k * 40), math.rad(-10)), R.violet[2], Enum.Material.Glass, false)
			end
		end
		box("QuarryCart", 24, rear + 4, 1.4, 6, 4.4, 3.4, R.stone[3])
		for k = 0, 1 do T.ball(field, "CartCrystal", F, 23 + k * 2.4, rear + 4, 5.6, 2.6, b.ore, Enum.Material.Neon, false) end
	else
		-- sulfur ridge: three steaming vent cones with glowing tops, hazard barrels and a warning sign
		for k = 0, 2 do
			local u = -16 + k * 16
			local h = 8 + k % 2 * 4
			T.cyl(field, "VentCone", F, u, rear, .6, 12 - k % 2 * 2, 2.4, R.sulfur[3])
			T.cyl(field, "Vent", F, u, rear, 3, 8, h, R.sulfur[2])
			T.cyl(field, "VentLip", F, u, rear, 3 + h, 9, 1.2, R.sulfur[3])
			local top = T.cyl(field, "VentGlow", F, u, rear, 4.2 + h, 6, .4, R.gold[1], Enum.Material.Neon, false)
			if k ~= 1 then smoke(top, Color3.fromRGB(240, 226, 140), 3) end
		end
		box("HazardStripe", 0, rear + 8, .6, 44, 2.4, .5, R.gold[2], nil, false)
		for k = 0, 4 do box("HazardMark", -16 + k * 8, rear + 8, 1.1, 3.6, 2.5, .3, T.ink, nil, false) end
		for k = 0, 1 do
			local p = F.world(30 + k * 5, 0, rear + (k % 2) * 3)
			T.barrel(field, "HazardBarrel", p.X, p.Z, .6, R.gold[2], 5)
		end
		local warn = A.signOn(field, "WarningSign", "HOT VENTS", F, -32, 6, rear + 2, 9, 3, R.gold[2], .4)
		T.smooth(warn)
		T.cyl(field, "WarningPost", F, -32, rear + 1.4, .6, .8, 4.6, T.ink)
	end
end

-- Twenty rocks per field in a fan that opens from the field's gate on the ring road out toward its landmark (the
-- quarter's centre line; WorldGeometry.Settings.Fan). Slots sit in rows 16 apart, 20 apart along a row and offset by
-- half a slot row to row, each jittered a little; twenty of the slots get rocks, a few of the rest a small
-- walk-through prop. Rocks are never rotated and at most 7 wide (aisles of 9+). Each biome has its own rock: a root
-- you mine (its colour is pulled toward its flecks by DebrisService) with RockChunk shapes (never tinted) and
-- OreFleck crystals (tinted by tier at runtime).
local W = A.world
local FAN = A.geometry.Fan
local ROCKS = 20
local ROWS = { 170, 186, 202, 218, 234 }
local LANDING_CLEAR = 15 -- no rock this close to where ORE travel lands
local ROAD_HALF = 9

local function themedRock(b, index, x, z)
	local w = 6 + random:NextNumber(0, .6)
	local h = 4.4 + random:NextNumber(0, 1.8)
	local base = .2
	local rock = T.part(debris, b.id .. "Rock" .. index, Vector3.new(w, h, w), A.cf(x, base + h / 2, z), b.rock[2], Enum.Material.SmoothPlastic)
	rock:SetAttribute("Field", b.id)
	local function chunk(size, cf, color, material)
		local p = T.part(rock, "RockChunk", size, cf, color, material, false)
		p.CanQuery = false
		return p
	end
	local top = base + h
	if b.id == "FrostYard" then
		-- an ice block under a lumpy snow cap, an icicle on one side
		chunk(Vector3.new(w + .6, 1.4, w + .6), A.cf(x, top + .5, z), T.white)
		chunk(Vector3.new(w * .6, 1.2, w * .5), A.cf(x + .6, top + 1.5, z - .4), T.white)
		chunk(Vector3.new(1.4, 3, 1.4), A.cf(x + w / 2 - .3, top - 2, z) * CFrame.Angles(0, 0, math.rad(8)), R.frost[1], Enum.Material.Glass)
	elseif b.id == "RustWorks" then
		-- a rust boulder with a lighter shoulder and a bent steel scrap plate
		chunk(Vector3.new(w * .7, h * .5, w * .7), A.cf(x - .6, top - h * .15, z + .5), b.rock[1])
		chunk(Vector3.new(4.4, .5, 2.4), A.cf(x + 1, top + .3, z - 1) * CFrame.Angles(0, math.rad(index * 37), math.rad(12)), R.stone[3])
	elseif b.id == "VioletQuarry" then
		-- a dark rock with two amethyst spikes (shape only, the glowing flecks show the tier)
		for k = 0, 1 do
			local a = index + k * 2.6
			chunk(Vector3.new(1.6, 4.6 - k, 1.6), A.cf(x + math.cos(a) * w * .3, top + 1.2, z + math.sin(a) * w * .3) * CFrame.Angles(math.rad(20), a, math.rad(-15)), R.violet[1 + k], Enum.Material.Glass)
		end
		chunk(Vector3.new(w * .6, 1.2, w * .6), A.cf(x, top + .4, z), b.rock[1])
	else
		-- sandstone with a crusty sulfur cap and a little vent lump
		chunk(Vector3.new(w * .8, 1.2, w * .8), A.cf(x - .3, top + .4, z + .3), R.sulfur[1])
		chunk(Vector3.new(2.6, h * .6, 2.6), A.cf(x + (w / 2 - 1.2), base + h * .3, z - (w / 2 - 1.2)), b.rock[3])
	end
	local flecks = 2 + (index % 2)
	for k = 0, flecks - 1 do
		local a = (k / flecks) * math.pi * 2 + index
		local fx, fz = x + math.cos(a) * w * .22, z + math.sin(a) * w * .22
		local size = 1.6 + (k % 2) * .8
		T.part(rock, "OreFleck", Vector3.new(size, size * 1.6, size), A.cf(fx, top + 1.4 + size * .45, fz) * CFrame.Angles(math.rad(15), a, math.rad(15)), b.ore, Enum.Material.Neon, false)
	end
	return rock
end
-- the slots of one field's fan, in world x/z, with their row
local function fanSlots(id)
	local q = W.quarter(id)
	local landing = q.out * FAN.Landing
	local slots = {}
	for row, d in ROWS do
		local half = W.fanHalf(d) - 5
		local offset = if row % 2 == 1 then 10 else 0
		for lat = offset, half, 20 do
			for _, side in (if lat == 0 then { 1 } else { -1, 1 }) do
				local jd, jl = random:NextNumber(-1, 1), random:NextNumber(-2, 2)
				local l = side * lat + jl
				local p = q.out * (d + jd) + q.right * l
				local onRoad = d < FAN.Landing + 11 and math.abs(l) < ROAD_HALF + 5
				if (p - landing).Magnitude >= LANDING_CLEAR and not onRoad then
					table.insert(slots, { x = p.X, z = p.Z, row = row })
				end
			end
		end
	end
	return slots
end

-- small walk-through props among the rocks (no collision, no queries: they never block a swing or a footstep)
local function smallProp(field, id, x, z)
	local function bit(name, size, cf, color, material, shape)
		local p = T.part(field, name, size, cf, color, material, false, shape)
		p.CanQuery, p.CanTouch = false, false
		return p
	end
	if id == "FrostYard" then
		bit("SnowLump", Vector3.new(4, 2.4, 3.4), A.cf(x, .9, z), T.white, nil, Enum.PartType.Ball)
		bit("SnowLump", Vector3.new(2.6, 1.8, 2.6), A.cf(x + 2, .7, z + 1), T.white, nil, Enum.PartType.Ball)
	elseif id == "RustWorks" then
		bit("ScrapPlate", Vector3.new(3.6, .4, 2.4), A.cf(x, .5, z) * CFrame.Angles(0, random:NextNumber(0, 3), math.rad(10)), R.stone[3])
		bit("OreLump", Vector3.new(2.2, 2.2, 2.2), A.cf(x + 1.6, .9, z + .6), R.orange[1], nil, Enum.PartType.Ball)
	elseif id == "VioletQuarry" then
		bit("Shard", Vector3.new(1.4, 3.6, 1.4), A.cf(x, 1.6, z) * CFrame.Angles(math.rad(14), random:NextNumber(0, 3), math.rad(-12)), R.violet[2], Enum.Material.Glass)
		bit("Shard", Vector3.new(1, 2.4, 1), A.cf(x + 1.4, 1.1, z + .8) * CFrame.Angles(math.rad(-16), 1, math.rad(14)), R.violet[1], Enum.Material.Glass)
	else
		bit("VentPuddle", Vector3.new(.3, 4.4, 4.4), A.cf(x, .3, z) * CFrame.Angles(0, 0, math.pi / 2), R.gold[1], Enum.Material.Neon, Enum.PartType.Cylinder).CastShadow = false
		bit("SulfurLump", Vector3.new(2, 1.6, 2), A.cf(x + 2.4, .7, z - .6), R.sulfur[3], nil, Enum.PartType.Ball)
	end
end

local function fillFan(b, field)
	local slots = fanSlots(b.id)
	assert(#slots >= ROCKS, b.id .. ": only " .. #slots .. " slots for " .. ROCKS .. " rocks")
	-- spare slots are dropped mostly from the outer rows, so the fan stays fullest from the gate onward
	while #slots > ROCKS + 4 do
		local pick, best = 1, -math.huge
		for k, slot in slots do
			local score = slot.row + random:NextNumber(0, 2.5)
			if score > best then pick, best = k, score end
		end
		table.remove(slots, pick)
	end
	local spare = {}
	while #slots > ROCKS do table.insert(spare, table.remove(slots, random:NextInteger(1, #slots))) end
	for index, slot in slots do themedRock(b, index, slot.x, slot.z) end
	for _, slot in spare do smallProp(field, b.id, slot.x, slot.z) end
end

-- scenery (trees, lamps, benches, bushes ...) standing on a fan, a landmark or a field road goes: the biomes decorate
-- round the fans instead. Rerunning Scenery brings it back, so rerun this stage (and Biomes) after Scenery.
local function reserved(x, z, margin)
	for _, q in A.geometry.Quarters do
		if W.inFan(q.id, x, z, margin) or W.onLandmark(q.id, x, z, margin) then return true end
		local d, lat = W.fanCoords(q.id, x, z)
		if d > A.geometry.LoopRadius and d < FAN.Landing + 6 + margin and math.abs(lat) < ROAD_HALF + margin then return true end
	end
	return false
end
local cleared = 0
local scenery = A.map:FindFirstChild("Scenery")
if scenery then
	local candidates = {}
	for _, c in scenery:GetChildren() do if c.Name ~= "Props" then table.insert(candidates, c) end end
	local props = scenery:FindFirstChild("Props")
	if props then for _, c in props:GetChildren() do table.insert(candidates, c) end end
	for _, c in candidates do
		if c.Name ~= "MeteorWatch" and c.Name ~= "TownFountain" then
			local at = if c:IsA("Model") then c:GetPivot().Position elseif c:IsA("BasePart") then c.Position else nil
			if at and reserved(at.X, at.Z, 8) then c:Destroy(); cleared += 1 end
		end
	end
end

for _, b in biomes do
	local zone = A.zone(b.id)
	local q = W.quarter(b.id)
	local field = A.group(fields, b.id)
	field:SetAttribute("Theme", b.id)
	field:SetAttribute("Entrance", Vector3.new(zone.entrance.X, 0, zone.entrance.Z))
	-- the floor plate (PrimaryPart): only the ORE-teleport anchor (DebrisService:_fieldSpot reads its centre and top),
	-- on the field road just inside the gate. Invisible and walk-through.
	local landing = q.out * FAN.Landing
	local pad = T.part(field, "FieldFloor", Vector3.new(24, .2, 24), A.cf(landing.X, .3, landing.Z), b.floor)
	pad.Transparency, pad.CanCollide, pad.CanQuery, pad.CastShadow = 1, false, false, false
	field.PrimaryPart = pad
	assert(FAN.Gate - 3 >= A.geometry.LandingRadius + 4, "Field inside the landing footprint")
	-- the landmark at the fan's far end, facing the crater
	local at = q.out * FAN.Landmark
	local L = A.frame(at.X, at.Z, -q.out)
	L.lat, L.dep = FAN.LandmarkLat - 4, 18
	landmark(b, field, L)
	-- the gate: two round posts with knobs and the rounded field sign across the field road, facing the ring
	local g = q.out * FAN.Gate
	local G = A.frame(g.X, g.Z, -q.out)
	for _, side in { -1, 1 } do
		T.cyl(field, "SignPost", G, side * 20, 0, .6, 2.6, 15, b.post)
		T.ball(field, "SignPostKnob", G, side * 20, 0, 16.2, 3.4, b.trim, nil, false)
	end
	local sign = A.signOn(field, "FieldSign", b.title, G, 0, 13, 0, 36, 5.6, T.ink, 1.2)
	T.smooth(sign)
	for _, side in { -1, 1 } do T.cylDep(field, "SignEnd", G, side * 18, 0, 13, 5.6, 1.2, T.ink, nil, false) end
	T.box(field, "SignTrim", G, 0, 0, 9.6, 38, 1.4, .8, b.trim, nil, false)
	fillFan(b, field)
	for _, v in field:GetDescendants() do if v:IsA("BasePart") then v.TopSurface = Enum.SurfaceType.Smooth end end
	A.within(field, zone, 0)
	-- every rock stands inside its own quarter and fan
	for _, rock in debris:GetChildren() do
		if rock:GetAttribute("Field") == b.id then
			assert(W.quarterAt(rock.Position.X, rock.Position.Z) == b.id, rock.Name .. " left its quarter")
			assert(W.inFan(b.id, rock.Position.X, rock.Position.Z, 1), rock.Name .. " left its fan")
		end
	end
end
assert(#debris:GetChildren() == ROCKS * 4, "Exactly " .. ROCKS * 4 .. " direct debris roots required")
assert(A.count(debris) + A.count(fields) <= 900, "Debris-field art budget: " .. (A.count(debris) + A.count(fields)))
A.map:SetAttribute("DebrisFieldsPass", 6)
return { stage = "DebrisFields", roots = #debris:GetChildren(), parts = A.count(debris) + A.count(fields), clearedScenery = cleared, totalParts = A.count(A.map) }
