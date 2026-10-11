-- Common + Brick + Toon first. Crater Isle, the far scenery: a middle range of rounded teal mountains, a far range of
-- violet-blue snow-capped peaks, Meteor Peak (a glowing volcano straight behind the north gate, on the line from the
-- spawn past the crater), fallen meteor rocks in the lagoon, three floating sky islands with crystals and a waterfall and
-- soft clouds. All non-colliding and query-free; marked Persistent so it streams in for every player (the far peaks are
-- beyond the default streaming radius). The sky islands and the peaks are the only things the ore-field players see
-- over the rampart. Owns Backdrop. Colours are pre-hazed so they read through the fog.
local A = assert(_G.MapRedesignArt)
local T = assert(A.toon, "Run Toon first")
local R = T.ramp
local bd = A.group(A.map, "Backdrop")
T.persistent(bd)
local random = Random.new(2028)
local seaTop = -16
local function yawToCentre(x, z) return math.atan2(-x, -z) end

-- the middle range: 12 rounded teal mountains (three blobs and a green foothill each), none right behind Meteor Peak
local midBody, midShade = Color3.fromRGB(72, 164, 176), Color3.fromRGB(58, 142, 164)
local mids = 0
for _, p in T.polar(14, 1, 0, nil, 0) do
	local angle = p.angle + random:NextNumber(-.07, .07)
	local gap = math.abs(math.deg(angle) % 360 - 90)
	if gap > 13 then
		local radius = random:NextNumber(700, 900)
		local x, z = math.cos(angle) * radius, math.sin(angle) * radius
		local w, v = random:NextNumber(220, 300), random:NextNumber(120, 200)
		T.peak(bd, "MidPeak", x, z, seaTop, w, v, yawToCentre(x, z), midBody, midShade, nil)
		local inward = -Vector3.new(math.cos(angle), 0, math.sin(angle))
		local deg = math.deg(angle) % 360
		-- the foothill stays out of the lighthouses' sight lines (south-east and south-west)
		if math.abs(deg - 236) > 30 and math.abs(deg - 304) > 30 then
			T.blob(bd, "MidHill", Vector3.new(w * .7, v * .6, w * .45), A.cf(x + inward.X * w * .45, seaTop, z + inward.Z * w * .45) * CFrame.Angles(0, yawToCentre(x, z), 0), R.green[3])
		else
			T.blob(bd, "MidShoulder", Vector3.new(w * .5, v * .7, w * .4), A.cf(x + inward.X * w * .1, seaTop, z + inward.Z * w * .1 + w * .25) * CFrame.Angles(0, yawToCentre(x, z), 0), midShade)
		end
		mids += 1
	end
end

-- the far range: 18 big pre-hazed peaks (a body, two shoulders, a snow cap and two drips each)
local farBody, farShade = Color3.fromRGB(122, 140, 206), Color3.fromRGB(100, 118, 182)
for _, p in T.polar(18, 1, 0, nil, .5) do
	local angle = p.angle + random:NextNumber(-.05, .05)
	local radius = random:NextNumber(950, 1300)
	local x, z = math.cos(angle) * radius, math.sin(angle) * radius
	local w, v = random:NextNumber(300, 460), random:NextNumber(250, 450)
	T.peak(bd, "FarPeak", x, z, seaTop, w, v, yawToCentre(x, z), if _ % 3 == 0 then farShade else farBody, farShade, T.white)
end

-- Meteor Peak, straight north behind the gate: stacked rounded cones, a rim with a glowing lava lake, neon crystals and a
-- lazy plume of smoke
local px, pz = 0, 800
local slate, light, dark = Color3.fromRGB(78, 70, 116), Color3.fromRGB(104, 92, 146), Color3.fromRGB(58, 52, 92)
T.blob(bd, "PeakBase", Vector3.new(580, 400, 500), A.cf(px, seaTop, pz), slate)
T.blob(bd, "PeakMid", Vector3.new(410, 640, 350), A.cf(px, seaTop, pz), light)
T.blob(bd, "PeakTop", Vector3.new(250, 820, 250), A.cf(px, seaTop, pz), slate)
for _, side in { -1, 1 } do
	T.blob(bd, "PeakShoulder", Vector3.new(300, 440, 260), A.cf(px + side * 185, seaTop, pz - 30), dark)
end
local rimY = seaTop + 404
local rim = T.far(bd, "PeakRim", Vector3.new(16, 140, 140), A.cf(px, rimY + 5, pz) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(130, 116, 170), nil, Enum.PartType.Cylinder)
T.far(bd, "PeakLava", Vector3.new(2, 108, 108), A.cf(px, rimY + 11.4, pz) * CFrame.Angles(0, 0, math.pi / 2), R.orange[2], Enum.Material.Neon, Enum.PartType.Cylinder)
for k = 0, 7 do
	local a = k * math.pi / 4 + .2
	local cx, cz = px + math.cos(a) * 60, pz + math.sin(a) * 60
	local tilt = CFrame.Angles(math.cos(a) * -.35, 0, math.sin(a) * .35)
	local tall = 64 + (k % 3) * 16
	T.blob(bd, "PeakCrystal", Vector3.new(16, tall, 16), A.cf(cx, rimY + 10 + tall / 2, cz) * tilt, if k % 2 == 0 then R.violet[1] else R.teal[1]).Material = Enum.Material.Neon
end
for k = 0, 3 do
	local a = k * math.pi / 2 + .8
	local r = 82
	local y = seaTop + 410 * math.sqrt(1 - (r / 125) ^ 2) + 2
	T.blob(bd, "PeakLavaFlow", Vector3.new(34, 9, 20), A.cf(px + math.cos(a) * r, y, pz + math.sin(a) * r) * CFrame.Angles(0, -a, 0), R.orange[2]).Material = Enum.Material.Neon
end
local vent = T.far(bd, "SmokeVent", Vector3.new(6, 1, 6), A.cf(px, rimY + 16, pz), T.white)
vent.Transparency = 1
local smoke = Instance.new("ParticleEmitter")
smoke.Name = "Smoke"
smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
smoke.Color = ColorSequence.new(Color3.fromRGB(170, 160, 190))
smoke.Rate, smoke.Lifetime, smoke.Speed = 3, NumberRange.new(7, 8), NumberRange.new(10, 14)
smoke.SpreadAngle = Vector2.new(8, 8)
smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 36), NumberSequenceKeypoint.new(1, 130) })
smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, .5), NumberSequenceKeypoint.new(.7, .75), NumberSequenceKeypoint.new(1, 1) })
smoke.LightEmission, smoke.Rotation, smoke.RotSpeed = 0, NumberRange.new(0, 360), NumberRange.new(-8, 8)
smoke.Parent = vent

-- fallen meteor rocks in the lagoon, north-east and north-west: dark boulders with glowing cracks
for _, cluster in { { 390, 560 }, { -400, 540 } } do
	for k = 0, 2 do
		local x, z = cluster[1] + (k - 1) * 34 + random:NextNumber(-6, 6), cluster[2] + random:NextNumber(-22, 22)
		local s = random:NextNumber(18, 30)
		T.blob(bd, "MeteorRock", Vector3.new(s, s * .8, s * .9), A.cf(x, seaTop + s * .2, z) * CFrame.Angles(0, random:NextNumber(0, 6), 0), if k % 2 == 0 then R.navy[2] else R.navy[3])
		T.far(bd, "MeteorEmber", Vector3.new(s * .32, s * .32, s * .32), A.cf(x + s * .2, seaTop + s * .5, z - s * .15), R.orange[1], Enum.Material.Neon, Enum.PartType.Ball)
	end
end

-- floating sky islands: a grass top on a rock underside and spike, crystals, a tree and a waterfall into a puff of mist
local function skyIsland(x, y, z, yaw, k)
	local at = A.cf(x, y, z) * CFrame.Angles(0, yaw, 0)
	local function o(px_, py_, pz_) return at * CFrame.new(px_ * k, py_ * k, pz_ * k) end
	T.blob(bd, "SkyGrass", Vector3.new(120, 22, 110) * k, o(0, -4, 0), R.green[2])
	T.blob(bd, "SkyLip", Vector3.new(126, 12, 116) * k, o(0, -9, 0), R.cream[3])
	T.blob(bd, "SkyRock", Vector3.new(100, 80, 92) * k, o(0, -30, 0), R.rust[3])
	T.blob(bd, "SkySpike", Vector3.new(46, 76, 42) * k, o(2, -66, 0), R.rust[3])
	for i, spot in { { -22, 8, .3 }, { 16, 20, -.25 }, { 30, -12, .15 } } do
		local tall = (30 + i * 6) * k
		T.blob(bd, "SkyCrystal", Vector3.new(8 * k, tall, 8 * k), o(spot[1], 6, spot[2]) * CFrame.new(0, tall / 2, 0) * CFrame.Angles(spot[3], 0, spot[3] * .8), if i % 2 == 0 then R.violet[1] else R.teal[1]).Material = Enum.Material.Neon
	end
	local tree = o(-4, 7, -20)
	T.lollipop(bd, tree.X, tree.Z, tree.Y - 1, 1.3 * k, R.green)
	local fall = o(0, -38, 54)
	T.far(bd, "SkyWaterfall", Vector3.new(7, 74, 2.4) * k, fall, R.frost[2]).Transparency = .2
	T.blob(bd, "SkyMist", Vector3.new(24, 12, 24) * k, fall * CFrame.new(0, -38 * k, 2), T.white)
end
skyIsland(-480, 230, 690, .4, 1.3)
skyIsland(490, 270, 760, -.5, 1.3)
skyIsland(-700, 200, -40, 1.2, 1.2)

-- clouds, well away from the play area
for k, p in T.polar(16, 1, 0, nil, .25) do
	local angle = p.angle + random:NextNumber(-.12, .12)
	if math.abs(math.deg(angle) % 360 - 90) < 18 then angle += math.rad(30) end -- keep Meteor Peak's rim clear
	local radius = random:NextNumber(560, 1100)
	T.cloud(bd, math.cos(angle) * radius, random:NextNumber(160, 280), math.sin(angle) * radius, random:NextNumber(120, 200), if k % 3 == 0 then Color3.fromRGB(238, 236, 252) else T.white)
end

assert(A.count(bd) <= 320, "Backdrop art budget: " .. A.count(bd))
local outer = A.count(A.map:FindFirstChild("Boundary")) + A.count(A.map:FindFirstChild("Surroundings")) + A.count(bd)
assert(outer <= 1400, "Outer scenery budget: " .. outer)
return { stage = "Backdrop", parts = A.count(bd), middleRange = mids, outerParts = outer, totalParts = A.count(A.map) }
