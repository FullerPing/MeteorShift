-- Common + Brick + Toon first. The Rebirth shrine: a cartoon portal on a round stepped plinth east of the ring road,
-- front toward the west (the crater side): a gold ring with a glowing violet portal, gold-capped columns, a name
-- arch, a floating star and crystals. Contract: RebirthMonument.RebirthPoint.
local A = assert(_G.MapRedesignArt)
local T = assert(A.toon, "Run Toon first")
local R = T.ramp
local town = A.ensure(A.map, "TownSquare")
local zone = A.zone("Rebirth")
local F = A.frameFor(zone, "W")
local LAT, DEP = F.lat, F.dep -- 36 x 36
local mon = A.group(town, "RebirthMonument")
local function box(name, u, d, y0, lat, dep, h, color, material, collide) return T.box(mon, name, F, u, d, y0, lat, dep, h, color, material, collide) end

-- the square base, then three round steps
local plaza = box("Plaza", 0, 0, 0, LAT, DEP, .8, R.cream[3])
mon.PrimaryPart = plaza
local stepColors = { R.cream[2], R.gold[2], R.cream[1] }
local diameters = { 34, 28, 22 }
for i = 1, 3 do T.cyl(mon, "Step" .. i, F, 0, -1, .8 + (i - 1) * 1, diameters[i], 1, stepColors[i]) end
local top = 3.8
-- front stairs up to the portal
T.steps(mon, "Stair", F, 0, 17.6, .8, 10, 3, 1, 1.4, R.cream[1])

-- the portal: a gold ring of twenty segments with cream accents, a glowing violet disc and a pink swirl inside
local ringR, centreY, ringD = 11, top + 13, -1
local up = Vector3.yAxis
local n = 20
for i = 0, n - 1 do
	local theta = (i + .5) * math.pi * 2 / n
	local centre = F.world(math.cos(theta) * ringR, centreY + math.sin(theta) * ringR, ringD) + A.offset
	local tangent = (F.right * -math.sin(theta) + up * math.cos(theta)).Unit
	local chord = 2 * ringR * math.sin(math.pi / n) + .5
	-- cylinder axis is local X, so align X with the tangent
	local frame = CFrame.fromMatrix(centre, tangent, F.forward:Cross(tangent))
	T.part(mon, "PortalRing", Vector3.new(chord, 3.6, 3.6), frame, if i % 5 == 0 then T.white else R.gold[2], nil, true, Enum.PartType.Cylinder)
end
local disc = T.cylDep(mon, "PortalGlow", F, 0, ringD, centreY, ringR * 2 - 1.5, .4, R.violet[3], Enum.Material.Neon, false)
disc.Transparency = .15
local swirl = T.cylDep(mon, "PortalSwirl", F, 0, ringD + .3, centreY, 11, .3, R.pink[3], Enum.Material.Neon, false)
swirl.Transparency = .25
local core = T.cylDep(mon, "PortalCore", F, 0, ringD + .5, centreY, 4.6, .3, R.violet[2], Enum.Material.Neon, false)
core.Transparency = .1
local glow = Instance.new("PointLight")
glow.Name, glow.Color, glow.Range, glow.Brightness, glow.Shadows = "PortalLight", R.violet[1], 20, 1, false
glow.Parent = disc
-- the portal's foot on the top step
T.cyl(mon, "PortalFoot", F, 0, ringD, top, 8, 1.6, R.gold[3])

-- columns either side, gold caps, and the name arch across them
for _, side in { -1, 1 } do
	local u = side * 15
	T.cyl(mon, "ColumnFoot", F, u, 4, .8, 6, 1.6, R.gold[3])
	T.cyl(mon, "Column", F, u, 4, 2.4, 4, 24, R.cream[1])
	T.cyl(mon, "ColumnRing", F, u, 4, 13, 4.6, 1.2, R.gold[2], nil, false)
	T.ball(mon, "ColumnCap", F, u, 4, 27.4, 5.6, R.gold[2], nil, false)
end
box("ArchBeam", 0, 4, 24.4, 30, 3, 2.4, R.gold[2], nil, false)
local sign = A.signOn(mon, "RebirthSign", "REBIRTH", F, 0, 29.4, 4, 20, 5, T.ink, 1.2)
T.smooth(sign)
for _, side in { -1, 1 } do T.cylDep(mon, "SignEnd", F, side * 10, 4, 29.4, 5, 1.2, T.ink, nil, false) end
local reward = A.signOn(mon, "RewardSign", "RETURN STRONGER", F, 0, top + .9, ringD + 4.2, 12, 1.6, R.violet[3], .4)
T.smooth(reward)

-- a floating gold star above the ring and four neon crystals hovering round it
local starAt = F.cf(0, centreY + ringR + 6, ringD)
T.part(mon, "Star", Vector3.new(7, 7, 1.6), starAt * CFrame.Angles(0, 0, math.pi / 4), R.gold[1], nil, false)
T.part(mon, "Star", Vector3.new(7, 7, 1.6), starAt, R.gold[1], nil, false)
T.part(mon, "StarCore", Vector3.new(4, 4, 4), starAt, R.gold[2], nil, false, Enum.PartType.Ball)
for k = 0, 3 do
	local a = k * math.pi / 2 + math.pi / 4
	local p = F.cf(math.cos(a) * 15.5, centreY + math.sin(a) * 6, ringD - 4)
	T.part(mon, "Crystal", Vector3.new(2.2, 2.2, 2.2), p * CFrame.Angles(math.rad(45), math.rad(45), 0), if k % 2 == 0 then R.teal[1] else R.pink[1], Enum.Material.Neon, false)
end

for _, v in mon:GetDescendants() do if v:IsA("BasePart") then v.TopSurface = Enum.SurfaceType.Smooth end end
A.within(mon, zone, 0)
local count = A.count(mon)
assert(count <= 100, "Rebirth art budget: " .. count)
local point = A.part(mon, "RebirthPoint", Vector3.new(6, 1, 6), A.cf(zone.entrance.X, 3, zone.entrance.Z), A.colors.yellow, nil, false)
point.Transparency = 1
point.CanCollide, point.CanTouch, point.CanQuery = false, false, false
A.map:SetAttribute("RebirthPass", 4)
return { stage = "Rebirth", parts = count + 1, entrance = { zone.entrance.X, zone.entrance.Z }, totalParts = A.count(A.map) }
