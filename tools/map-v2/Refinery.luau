-- Common + Brick + Toon first. The shared Refinery: a cartoon ore smelter in the south plaza, its front, furnace mouth
-- and UsePoint facing north toward the spawn points and the crater, a name board on its back. Contract (WorldMap.refineryPoint / canUseRefinery, StaticQA): TownSquare.Refinery is a Model with a
-- PrimaryPart, attr SharedRefinery, exactly one UsePoint part, <=180 parts, no scripts, prompts or humanoids. The
-- forecourt in front of the UsePoint (12 studs either side, 12 out) stays free of colliding parts.
local A = assert(_G.MapRedesignArt)
local T = assert(A.toon, "Run Toon first")
local R = T.ramp
local town = A.ensure(A.map, "TownSquare")
local zone = A.zone("Refinery")
local F = A.frame(zone.x, zone.z, "N")
local refinery = A.group(town, "Refinery")
refinery:SetAttribute("SharedRefinery", true)
local function box(name, u, d, y0, lat, dep, h, color, material, collide) return T.box(refinery, name, F, u, d, y0, lat, dep, h, color, material, collide) end
local LAT, DEP = zone.width, zone.depth -- 38 x 32 (the front faces north, so lateral spans X)

-- foundation: a dark stone plinth with a light kerb top
local foundation = box("Foundation", 0, 0, 0, LAT, DEP, 1, R.stone[3])
refinery.PrimaryPart = foundation
box("Pad", 0, 0, 1, LAT - 1.5, DEP - 1.5, .4, R.stone[1])

-- the hall: dark base course, orange body, light top course and a white cornice
local hu, hd, hLat, hDep, hH = 0, -2, 28, 24, 15 -- centre lateral/depth, size, wall height above the pad
local base = 1.4
box("HallBase", hu, hd, base, hLat + 1, hDep + 1, 2.4, R.orange[3])
box("HallBody", hu, hd, base + 2.4, hLat, hDep, hH - 4.4, R.orange[2])
box("HallBand", hu, hd, base + hH - 2, hLat + .6, hDep + .6, 2, R.orange[1])
box("Cornice", hu, hd, base + hH, hLat + 2.4, hDep + 2.4, 1.2, T.white)
local roofY = base + hH + 1.2
-- corner pillars in the darker tone, rounded caps
for _, su in { -1, 1 } do
	for _, sd in { -1, 1 } do
		local u, d = hu + su * (hLat / 2), hd + sd * (hDep / 2)
		T.cyl(refinery, "CornerPillar", F, u, d, base, 3.4, hH, R.red[2])
		T.ball(refinery, "PillarCap", F, u, d, roofY + .6, 3.6, R.gold[2], nil, false)
	end
end

-- sawtooth roof: three red teeth, each with a glowing skylight on its steep face (the steep face looks back, north)
local teeth = 3
local toothDep = hDep / teeth
for i = 0, teeth - 1 do
	local d = hd - hDep / 2 + toothDep / 2 + i * toothDep
	T.wedge(refinery, "RoofTooth", F, hu, d, roofY, hLat, toothDep, 5, R.red[2], true)
	box("Skylight", hu, d + toothDep / 2 - .45, roofY + .4, hLat - 4, .5, 4, T.glow, Enum.Material.Neon, false)
end

-- the big striped chimney at the back right, a dark cap and the smoke
local cu, cd = hu + 9, hd - 7
local stackBase = roofY
for level = 0, 4 do
	T.cyl(refinery, "ChimneyRing", F, cu, cd, stackBase + level * 3.6, 6.2 - level * .2, 3.6, if level % 2 == 0 then R.red[2] else T.white)
end
local capTop = stackBase + 18
T.cyl(refinery, "ChimneyLip", F, cu, cd, capTop, 7.6, 1.4, T.ink)
local cap = T.cyl(refinery, "ChimneyTop", F, cu, cd, capTop + 1.4, 6, .6, R.orange[3], nil, false)
local smoke = Instance.new("ParticleEmitter")
smoke.Name = "ChimneySmoke"
smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
smoke.Color = ColorSequence.new(Color3.fromRGB(235, 235, 245))
smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.4), NumberSequenceKeypoint.new(1, 7) })
smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, .35), NumberSequenceKeypoint.new(1, 1) })
smoke.Rate, smoke.Lifetime, smoke.Speed = 4, NumberRange.new(2.5, 4), NumberRange.new(5, 8)
smoke.Acceleration = Vector3.new(1.5, 1, 0)
smoke.EmissionDirection = Enum.NormalId.Top
smoke.Parent = cap
-- a second, shorter stack on the left
T.cyl(refinery, "SmallStack", F, hu - 9, hd - 8, roofY, 3.6, 7, R.stone[2])
T.cyl(refinery, "SmallStackLip", F, hu - 9, hd - 8, roofY + 7, 4.6, 1, T.ink)

-- the ore hopper on the roof (left front) with ore heaped in it
local pu, pd = hu - 8, hd + 6
T.cyl(refinery, "HopperLeg", F, pu, pd, roofY, 2.4, 3, T.ink)
T.cyl(refinery, "Hopper", F, pu, pd, roofY + 3, 8.4, 4, R.gold[2])
T.cyl(refinery, "HopperRim", F, pu, pd, roofY + 7, 9.2, .8, R.gold[3], nil, false)
for k = 0, 2 do
	local a = k * math.pi * 2 / 3
	T.ball(refinery, "HopperOre", F, pu + math.cos(a) * 1.8, pd + math.sin(a) * 1.8, roofY + 7.6, 3, if k == 1 then R.violet[2] else R.orange[1], nil, false)
end

-- pipes along both side walls with elbows into the hall
for _, su in { -1, 1 } do
	local u = hu + su * (hLat / 2 + 1.4)
	T.cylDep(refinery, "SidePipe", F, u, hd, base + hH - 5, 1.8, hDep - 4, R.stone[1], nil, false)
	for _, sd in { -1, 1 } do
		T.ball(refinery, "PipeElbow", F, u, hd + sd * (hDep / 2 - 2), base + hH - 5, 2.4, R.gold[2], nil, false)
	end
end

-- side windows glowing with the furnace light, two per side
for _, su in { -1, 1 } do
	for k = 0, 1 do
		local d = hd - 5 + k * 10
		T.window(refinery, "SideWindow", T.onSide(F, hu + su * hLat / 2, d, base + 8, su), 4.4, 4.4, T.white, T.glow, true)
	end
end

-- the front (south): the furnace mouth on the left, the bar hatch on the right, a striped awning over the UsePoint
local front = hd + hDep / 2 -- the hall's front face, as d
T.door(refinery, "FurnaceMouth", T.onFront(F, hu - 6.5, front, base + 5.4), 9, 8, R.stone[2], R.orange[3])
local glow = box("FurnaceGlow", hu - 6.5, front + .15, base + 1.8, 5.4, .4, 3.2, R.orange[2], Enum.Material.Neon, false)
local lamp = Instance.new("PointLight")
lamp.Name, lamp.Color, lamp.Range, lamp.Brightness, lamp.Shadows = "WarmGlow", R.orange[1], 16, .9, false
lamp.Parent = glow
T.window(refinery, "BarHatch", T.onFront(F, hu + 6.5, front, base + 6), 7, 5, T.white, T.glass, false)
-- awning: four orange/white stripes sloping toward the spawn
local awnY, awnDep = base + 11, 5
for i = 0, 3 do
	local u = hu - 9 + (i + .5) * 4.5
	T.wedge(refinery, "Awning", F, u, front + awnDep / 2, awnY, 4.5, awnDep, 2.2, if i % 2 == 0 then R.orange[2] else T.white, false, false)
end
T.cylLat(refinery, "AwningEdge", F, hu, front + awnDep, awnY + .2, 1.2, 18.4, R.orange[3], nil, false)

-- signs: a big rounded name board on the cornice, a service board over the door, and the back board
local signY = roofY + 3.2
local nameBoard = A.signOn(refinery, "RefinerySign", "REFINERY", F, hu, signY, front + .9, 22, 5, T.ink, 1.2)
T.smooth(nameBoard)
for _, su in { -1, 1 } do
	T.cylDep(refinery, "SignEnd", F, hu + su * 11, front + .9, signY, 5, 1.2, T.ink, nil, false)
end
box("SignTrim", hu, front + .9, signY - 3.1, 24, 1.4, .6, R.gold[2], nil, false)
local service = A.signOn(refinery, "ServiceSign", "DEPOSIT ORE  •  CLAIM BARS", F, hu, awnY - 1.4, front + 5.3, 17, 2.2, R.orange[3], .5)
T.smooth(service)
local back = A.signOn(refinery, "RefinerySignBack", "REFINERY", F, hu, base + 9, hd - hDep / 2 - .8, 20, 4.4, T.ink, 1, -F.forward)
T.smooth(back)

-- an ore cart on a short rail at the front left, and crates, barrels and a stack of gold bars at the front right
local cartU, cartD = hu - 16.4, front + 2
for _, su in { -1, 1 } do box("Rail", cartU + su * 1.6, cartD, base, .5, 7, .4, T.ink, nil, false) end
box("Cart", cartU, cartD, base + 1.2, 4.4, 4.6, 3.2, R.stone[2], nil, false)
box("CartRim", cartU, cartD, base + 4.4, 4.8, 5, .6, R.stone[3], nil, false)
for _, su in { -1, 1 } do for _, sd in { -1, 1 } do
	T.cylLat(refinery, "CartWheel", F, cartU + su * 2.2, cartD + sd * 1.4, base + 1.2, 2, .6, T.ink, nil, false)
end end
for k = 0, 2 do T.ball(refinery, "CartOre", F, cartU - 1.2 + k * 1.2, cartD - .8 + (k % 2) * 1.6, base + 5.4, 2.4, if k == 1 then R.teal[2] else R.orange[1], nil, false) end
local propU = hu + 15.2
local cratePos = F.world(propU, 0, front + 1.8)
T.crate(refinery, "Crate", cratePos.X, cratePos.Z, base, 4, .2)
local barrelPos = F.world(propU - .4, 0, front - 4)
T.barrel(refinery, "Barrel", barrelPos.X, barrelPos.Z, base, R.red[2], 4.6)
-- the bar table beside the hatch
local tableU = hu + 11
box("BarTable", tableU, front + 2.6, base, 5, 3.4, 3, R.wood[2], nil, false)
for row = 0, 1 do
	for col = 0, 2 - row do
		box("GoldBar", tableU - 1.5 + col * 1.5 + row * .75, front + 2.6, base + 3 + row * .8, 1.3, 2.4, .8, R.gold[2], Enum.Material.SmoothPlastic, false)
	end
end

for _, v in refinery:GetDescendants() do
	if v:IsA("BasePart") then v.TopSurface = Enum.SurfaceType.Smooth end
end
A.within(refinery, zone, 0)
local point = A.part(refinery, "UsePoint", Vector3.new(6, 1, 6), A.cf(zone.entrance.X, zone.entrance.Y, zone.entrance.Z), A.colors.gold, nil, false)
point.Transparency = 1
point.CanCollide, point.CanTouch, point.CanQuery = false, false, false
local forbidden, points = {}, 0
for _, v in refinery:GetDescendants() do
	if v:IsA("BasePart") then
		assert(v.Anchored, "Unanchored refinery part")
		if v.Name == "UsePoint" then points += 1 end
	end
	if v:IsA("LuaSourceContainer") or v:IsA("ProximityPrompt") or v:IsA("Humanoid") or v.Name == "Intake" or v.Name == "Upgrade" or v.Name == "ManageRefinery" then
		table.insert(forbidden, v:GetFullName())
	end
end
assert(points == 1 and #forbidden == 0, "Refinery contract failed")
local count = A.count(refinery)
assert(count <= 180, "Refinery part budget exceeded: " .. count)
assert(Vector3.new(zone.entrance.X, 0, zone.entrance.Z).Magnitude > A.geometry.LandingRadius, "UsePoint inside effect extent")
A.map:SetAttribute("RefineryPass", 4)
return { stage = "Refinery", parts = count, usePoint = { zone.entrance.X, zone.entrance.Y, zone.entrance.Z }, totalParts = A.count(A.map) }
