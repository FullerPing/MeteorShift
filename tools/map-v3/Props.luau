-- Map v3 hero props, authored once into ServerStorage.MapArt for T.mesh to clone. Load after map-v2 Common, Brick
-- and Toon. Each prop is built on a workbench floating at y 400 (Map_Redesign.Workbench), front toward -Z (the
-- camera side), pivoted at the middle of its footprint on the ground with LookVector = its front, then copied to
-- MapArt. Copies carry PropBuilder = true; anything in MapArt without it (the owner's own art) is never replaced.
--   L("Common"); L("Brick"); L("Toon"); return L("../map-v3/Props")          -- every prop
--   ...; return L("../map-v3/Props", "OreChute")                              -- one prop
local A = assert(_G.MapRedesignArt, "Run Common first")
local T = assert(A.toon, "Run Toon first")
local only = ...
local R, ink, white = T.ramp, T.ink, T.white
local NEON = Enum.Material.Neon
local Y = 400

local bench = A.ensure(A.map, "Workbench", "Model")
local props = {}

-- hollow open half-pipe section along d: floor, two 45-degree flanks, vertical lips and a rail on each rim
local function halfPipe(g, F, d, y0, length, color, stripe)
	T.box(g, "Floor", F, 0, d, y0, 4.4, length, 1, color)
	for _, s in { -1, 1 } do
		T.part(g, "Flank", Vector3.new(3.4, 1, length), F.cf(s * 3.2, y0 + 1.6, d, CFrame.Angles(0, 0, s * math.rad(45))), color)
		T.box(g, "Lip", F, s * 4.6, d, y0 + 2.2, 1, length, 2.4, color)
		T.cylDep(g, "Rail", F, s * 4.6, d, y0 + 4.8, 1.3, length, white, nil, false)
	end
	T.box(g, "Stripe", F, 0, d, y0 + 1, 1.2, length, .08, stripe, nil, false)
end

props.SlideTube = function(g, F)
	halfPipe(g, F, 0, Y, 40, R.blue[2], R.gold[2])
	for _, d in { -14, 14 } do -- feet, so a tile on a slope reads as supported
		T.box(g, "Foot", F, 0, d, Y - 2, 6, 2, 2, R.navy[2], nil, false)
	end
end

props.SlideEnd = function(g, F)
	-- run-out bowl: slide mouth on the back (-d), round pool of soft foam you stop in
	T.cyl(g, "Base", F, 0, 2, Y, 20, 1.4, R.navy[2])
	T.cyl(g, "Foam", F, 0, 2, Y + 1.4, 16.5, .6, R.teal[1])
	local n = 14
	for k = 0, n - 1 do
		local a = (k + .5) / n * math.pi * 2
		if math.abs(math.cos(a) + 1) < .12 then continue end -- the gap the slide comes in through
		local u, d = math.sin(a) * 9, 2 + math.cos(a) * 9
		T.part(g, "Rim", Vector3.new(4.4, 2.6, 1.6), F.cf(u, Y + 2.7, d, CFrame.Angles(0, a, 0)), if k % 2 == 0 then R.blue[2] else white)
	end
	halfPipe(g, F, -10, Y, 6, R.blue[2], R.gold[2])
end

props.OreChute = function(g, F)
	T.box(g, "Plinth", F, 0, 0, Y, 10, 10, 1, R.navy[2])
	T.box(g, "PlinthTrim", F, 0, 0, Y + 1, 10.6, 10.6, .4, R.gold[2], nil, false)
	T.box(g, "Body", F, 0, -.5, Y + 1.4, 7.4, 7, 6, R.orange[2])
	T.box(g, "Band", F, 0, -.5, Y + 4, 7.8, 7.4, .9, R.teal[2], NEON, false)
	T.box(g, "Cap", F, 0, -.5, Y + 7.4, 8.2, 7.8, .8, R.orange[3])
	-- hopper: a gold bin with a lip and a dark mouth
	local top = Y + 8.2
	T.box(g, "Hopper", F, 0, -.5, top, 8.8, 8.4, 2.6, R.gold[2])
	T.box(g, "HopperLip", F, 0, -.5, top + 2.6, 9.6, 9.2, .7, R.gold[1], nil, false)
	T.box(g, "Mouth", F, 0, -.5, top + 3.3, 6.6, 6.2, .1, ink, nil, false)
	-- the chute: a sloped tray out of the front with a dark opening above it
	T.box(g, "Opening", F, 0, 3.05, Y + 2.2, 4.4, .2, 3, ink, nil, false)
	T.part(g, "Tray", Vector3.new(5, .8, 4), F.cf(0, Y + 2.1, 4.4, CFrame.Angles(math.rad(18), 0, 0)), R.stone[1])
	for _, s in { -1, 1 } do
		T.part(g, "TrayLip", Vector3.new(.6, 1.4, 4), F.cf(s * 2.7, Y + 2.5, 4.4, CFrame.Angles(math.rad(18), 0, 0)), R.orange[3], nil, false)
	end
	local gui = T.textBoard(g, "Lettering", F, 0, Y + 5.6, 3.06, 6.4, 1.6, 30)
	T.outlined(gui, "DEPOSIT", Enum.Font.FredokaOne, white, UDim2.fromScale(1, 1), nil, 3)
end

props.FieldGate = function(g, F)
	-- a 30-wide arch: two emitter pillars and a crossbeam carrying a blank name panel (the Fields stage writes it)
	for _, s in { -1, 1 } do
		local u = s * 13
		T.box(g, "PillarBase", F, u, 0, Y, 5.6, 5.6, 2, R.navy[3])
		T.box(g, "Pillar", F, u, 0, Y + 2, 4, 4, 16, R.navy[2])
		T.box(g, "PillarTrim", F, u, 0, Y + 6, 4.4, 4.4, .8, R.gold[2], nil, false)
		T.box(g, "PillarTrim", F, u, 0, Y + 14, 4.4, 4.4, .8, R.gold[2], nil, false)
		T.ball(g, "Cap", F, u, 0, Y + 23.6, 3.2, R.gold[2], nil, false)
		T.box(g, "Emitter", F, u - s * 2.05, 0, Y + 2.6, .4, 1.4, 15, R.teal[1], NEON, false) -- force-field strip on the inner face
	end
	T.box(g, "Beam", F, 0, 0, Y + 18, 31, 4.6, 3.2, R.navy[2])
	T.box(g, "BeamTrim", F, 0, 0, Y + 21.2, 31.6, 5, .6, R.gold[2], nil, false)
	T.box(g, "Panel", F, 0, 2.5, Y + 17.2, 16, .5, 4.6, white, nil, false)
	T.box(g, "PanelEdge", F, 0, 2.35, Y + 16.8, 17, .3, 5.4, R.blue[2], nil, false)
end

-- A terrace face of any length and height, front = downhill (+d), standing on y0 with its top at y0 + h: three strata
-- stepping back as they rise, each cut into blocks with jittered fronts and tops so the face reads as rock, not a wall,
-- boulders at the foot and a grass lip on top. The ends are flush so faces tile. The Ground stage calls this directly
-- (L("../map-v3/Props", "lib").cliff) to fit every tier edge exactly; the CliffSegment prop is a 60 x 16 sample.
function props.cliff(g, F, L, y0, h, turf, seed)
	local sand = { Color3.fromRGB(246, 214, 158), Color3.fromRGB(226, 184, 124), Color3.fromRGB(196, 148, 96) }
	local rng = Random.new(seed or 16)
	local k = (h - 1) / 15 -- strata heights were drawn for a 16-tall face
	T.box(g, "Core", F, 0, -3.5, y0, L, 7, h - 1, sand[2])
	for band, spec in { { y = 0, h = 5.5, front = 2.2, color = sand[3] }, { y = 5.5, h = 5, front = 1.2, color = sand[2] }, { y = 10.5, h = 4.5, front = .4, color = sand[1] } } do
		local count = math.max(1, math.round(L / 12))
		local cuts = { -L / 2 }
		for c = 1, count - 1 do table.insert(cuts, -L / 2 + c * L / count + rng:NextNumber(-3, 3)) end
		table.insert(cuts, L / 2)
		for c = 1, #cuts - 1 do
			local w, jitter = cuts[c + 1] - cuts[c], rng:NextNumber(-.7, .7)
			local top = if band == 3 then 0 else rng:NextNumber(-.6, .6)
			T.box(g, "Stratum", F, (cuts[c] + cuts[c + 1]) / 2, spec.front / 2 - 1 + jitter / 2, y0 + spec.y * k, w + .05, spec.front + 2 + jitter, spec.h * k + top, spec.color)
		end
	end
	for u = -L / 2 + 8, L / 2 - 8, 20 do -- boulders at the foot
		local s = rng:NextNumber(3.2, 4.6)
		T.part(g, "Boulder", Vector3.new(s * 1.3, s, s), F.cf(u + rng:NextNumber(-4, 4), y0 + s / 2 - .4, 3.4, CFrame.Angles(0, rng:NextNumber(-.4, .4), rng:NextNumber(-.15, .15))), sand[3])
	end
	T.box(g, "Turf", F, 0, -2.6, y0 + h - 1, L, 8, 1.6, turf or R.green[2])
	T.box(g, "TurfLip", F, 0, 1.4, y0 + h - 1.4, L, 1.6, 1.2, R.green[3], nil, false)
end

props.CliffSegment = function(g, F)
	props.cliff(g, F, 60, Y, 16)
end

props.SkyLift = function(g, F)
	-- an open glass shaft 44 tall: four white posts, gold braces, a blue cabin at the bottom, a red machine house on top
	local H = 44
	T.box(g, "Base", F, 0, 0, Y, 14, 10, 1.2, R.navy[2])
	for _, su in { -1, 1 } do
		for _, sd in { -1, 1 } do
			T.box(g, "Post", F, su * 6, sd * 4, Y + 1.2, 1.6, 1.6, H, white)
		end
	end
	for y = 12, H - 4, 10 do
		for _, sd in { -1, 1 } do T.box(g, "Brace", F, 0, sd * 4, Y + y, 12, .6, .6, R.gold[2], nil, false) end
		for _, su in { -1, 1 } do T.box(g, "Brace", F, su * 6, 0, Y + y, .6, 8, .6, R.gold[2], nil, false) end
	end
	local glass = T.box(g, "Shaft", F, 0, 0, Y + 1.2, 11, 7, H - 2, T.glass, Enum.Material.Glass, false)
	glass.Transparency = .75
	T.box(g, "Cabin", F, 0, 0, Y + 1.2, 9, 6, 1, R.blue[3])
	T.box(g, "CabinBack", F, 0, -2.6, Y + 2.2, 9, .8, 8, R.blue[2])
	T.box(g, "CabinRoof", F, 0, 0, Y + 10.2, 9.6, 6.6, 1, R.blue[2])
	T.box(g, "CabinStripe", F, 0, 0, Y + 9.4, 9.4, 6.4, .6, R.gold[2], NEON, false)
	local top = Y + 1.2 + H
	T.box(g, "Machine", F, 0, 0, top, 15, 11, 5, R.red[2])
	T.box(g, "MachineTrim", F, 0, 0, top, 15.6, 11.6, .8, white, nil, false)
	T.box(g, "Roof", F, 0, 0, top + 5, 16, 12, 1.2, R.red[3])
	T.cylLat(g, "Wheel", F, 0, 5.6, top + 2.6, 4, .8, ink, nil, false)
	local gui = T.textBoard(g, "Lettering", F, 0, top + 2.6, 5.62, 9, 2.6, 30)
	T.outlined(gui, "SKY LIFT", Enum.Font.FredokaOne, white, UDim2.fromScale(1, 1), nil, 3)
end

props.DiveCannon = function(g, F)
	-- round launch pad: drum, red/white target rings, three chevrons pointing out the front, four bulb posts
	T.cyl(g, "Drum", F, 0, 0, Y, 14, 2, R.navy[2])
	T.cyl(g, "DrumTrim", F, 0, 0, Y + 2, 14.6, .5, R.gold[2], nil, false)
	T.cyl(g, "Ring", F, 0, 0, Y + 2.5, 11, .3, R.red[2], nil, false)
	T.cyl(g, "Ring", F, 0, 0, Y + 2.8, 8, .3, white, nil, false)
	T.cyl(g, "Ring", F, 0, 0, Y + 3.1, 5, .3, R.red[2], NEON, false)
	for k = 0, 2 do
		for _, s in { -1, 1 } do
			T.part(g, "Chevron", Vector3.new(3.4, .3, .9), F.cf(s * 1.1, Y + 3.5, 2.4 + k * 2.6, CFrame.Angles(0, s * math.rad(40), 0)), R.gold[1], NEON, false)
		end
	end
	for k = 0, 3 do
		local a = (k + .5) * math.pi / 2
		local u, d = math.sin(a) * 7.6, math.cos(a) * 7.6
		T.cyl(g, "Post", F, u, d, Y, 1, 5.5, ink, nil, false)
		T.ball(g, "Bulb", F, u, d, Y + 6, 1.8, R.gold[1], NEON, false)
	end
	local gui = T.textBoard(g, "Lettering", F, 0, Y + 1, 7.05, 7, 1.6, 30)
	T.outlined(gui, "METEOR DIVE", Enum.Font.FredokaOne, white, UDim2.fromScale(1, 1), nil, 3)
end

props.StarfallBeacon = function(g, F)
	-- 120-stud skyline anchor: stepped plinth, a tapering white tower in blue-banded drums, gold cage, glowing star
	T.cyl(g, "Step", F, 0, 0, Y, 36, 2, R.stone[2])
	T.cyl(g, "Step", F, 0, 0, Y + 2, 30, 2, R.stone[1])
	T.cyl(g, "Step", F, 0, 0, Y + 4, 25, 2, white)
	local y, d = Y + 6, 21
	for k = 1, 7 do
		local h = 12
		T.cyl(g, "Drum", F, 0, 0, y, d, h, white)
		T.cyl(g, "Band", F, 0, 0, y + h - 1.2, d + .8, 1.2, if k % 2 == 0 then R.gold[2] else R.blue[2], nil, false)
		y += h; d -= 1.6
	end
	for k = 0, 3 do -- fins up the lower tower
		T.part(g, "Fin", Vector3.new(1.6, 32, 8), F.cf(0, Y + 22, 0, CFrame.Angles(0, k * math.pi / 2 + math.pi / 4, 0) * CFrame.new(0, 0, 12)), R.blue[2])
	end
	T.cyl(g, "Gallery", F, 0, 0, y, d + 6, 1.4, R.gold[2])
	for k = 0, 7 do
		local a = k * math.pi / 4
		T.part(g, "Cage", Vector3.new(.9, 14, .9), F.cf(math.sin(a) * 6.6, y + 8, math.cos(a) * 6.6, CFrame.Angles(0, a, math.rad(-8))), R.gold[2], nil, false)
	end
	T.cyl(g, "Crown", F, 0, 0, y + 14.6, 11, 1.2, R.gold[2], nil, false)
	local star = T.part(g, "Star", Vector3.new(8.4, 8.4, 8.4), F.cf(0, y + 8, 0, CFrame.Angles(math.rad(45), math.rad(45), 0)), R.pink[1], NEON, false)
	T.part(g, "StarCore", Vector3.new(6, 6, 6), F.cf(0, y + 8, 0, CFrame.Angles(0, math.rad(45), math.rad(45))), R.gold[1], NEON, false)
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = R.pink[1], 40, 2
	light.Parent = star
	T.ball(g, "Tip", F, 0, 0, y + 16.6, 2.8, R.gold[1], NEON, false)
end

props.Windmill = function(g, F)
	-- cream stone tower in shrinking drums, red dome roof, four sails on a hub facing front
	local y, d = Y, 13
	for k = 1, 4 do
		T.cyl(g, "Tower", F, 0, 0, y, d, 5.5, if k % 2 == 1 then R.cream[2] else R.cream[1])
		y += 5.5; d -= 1.2
	end
	T.cyl(g, "Ledge", F, 0, 0, y, d + 2.4, .8, R.wood[3], nil, false)
	T.ball(g, "Roof", F, 0, 0, y + .8, d + 1.6, R.red[2])
	T.ball(g, "Finial", F, 0, 0, y + .8 + (d + 1.6) / 2 + .6, 1.8, R.gold[2], nil, false)
	T.door(g, "Door", T.onFront(F, 0, 6.5, Y + 3), 3.2, 5, R.wood[2])
	T.window(g, "Window", T.onFront(F, 0, 5.4, Y + 11), 2.2, 2.6, white)
	local hub = Y + 19
	T.cylDep(g, "Axle", F, 0, 5.2, hub, 1.4, 3, ink, nil, false)
	T.ball(g, "Hub", F, 0, 6.8, hub, 2.4, R.red[3], nil, false)
	for k = 0, 3 do
		local turn = CFrame.Angles(0, 0, k * math.pi / 2 + math.rad(20))
		local base = F.cf(0, hub, 7.2) * turn
		T.part(g, "Spar", Vector3.new(.6, 12, .5), base * CFrame.new(0, 6, 0), R.wood[3], nil, false)
		T.part(g, "Sail", Vector3.new(3, 8.5, .3), base * CFrame.new(1.8, 7.2, .2), R.cream[1], nil, false)
	end
end

props.Lighthouse = function(g, F)
	-- red/white striped tapering tower, gallery with railing, glowing lamp room, red dome
	T.cyl(g, "Base", F, 0, 0, Y, 16, 2, R.stone[2])
	local y, d = Y + 2, 12
	for k = 1, 6 do
		T.cyl(g, "Tower", F, 0, 0, y, d, 5, if k % 2 == 1 then white else R.red[2])
		y += 5; d -= .8
	end
	T.door(g, "Door", T.onFront(F, 0, 6.05, Y + 4.6), 2.6, 4.6, R.navy[2])
	T.cyl(g, "Gallery", F, 0, 0, y, d + 5, 1, R.navy[2])
	for k = 0, 11 do
		local a = k * math.pi / 6
		T.cyl(g, "Rail", F, math.sin(a) * (d / 2 + 2), math.cos(a) * (d / 2 + 2), y + 1, .5, 2.4, white, nil, false)
	end
	T.cyl(g, "RailTop", F, 0, 0, y + 3.2, d + 4.6, .4, white, nil, false)
	local lamp = T.cyl(g, "Lamp", F, 0, 0, y + 1, d - 2, 4.6, R.gold[1], NEON, false)
	T.cyl(g, "LampCage", F, 0, 0, y + 5.6, d - 1, .6, R.navy[2], nil, false)
	T.ball(g, "Dome", F, 0, 0, y + 6.2, d - 1.4, R.red[2], nil, false)
	T.ball(g, "Finial", F, 0, 0, y + 6.2 + (d - 1.4) / 2, 1.2, R.gold[2], nil, false)
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = R.gold[1], 30, 1.5
	light.Parent = lamp
end

props.House = function(g, F)
	-- cottage: cream walls on a stone footing, gable roof, door and two windows on the front, chimney
	T.box(g, "Footing", F, 0, 0, Y, 17, 13, 1.2, R.stone[2])
	T.box(g, "Walls", F, 0, 0, Y + 1.2, 15, 11, 9, R.cream[2])
	T.box(g, "Trim", F, 0, 0, Y + 9.6, 15.6, 11.6, .8, R.wood[2], nil, false)
	for _, s in { -1, 1 } do T.gableEnd(g, "GableEnd", F, s * 7.1, 0, Y + 10.2, 11, 5.4, R.cream[2]) end
	T.gable(g, "Roof", F, 0, 0, Y + 10.2, 15, 11, 5.4, R.blue[2], white, 1.6)
	T.box(g, "Chimney", F, 4.6, -2.2, Y + 11, 2.4, 2.4, 6.6, R.red[3])
	T.box(g, "ChimneyCap", F, 4.6, -2.2, Y + 17.6, 3, 3, .6, ink, nil, false)
	T.door(g, "Door", T.onFront(F, 0, 5.55, Y + 3.9), 3, 5.4, R.wood[2])
	for _, s in { -1, 1 } do T.window(g, "Window", T.onFront(F, s * 4.6, 5.55, Y + 6.2), 2.6, 2.6, white, nil, true) end
end

props.MarketStall = function(g, F)
	-- wooden counter with fruit, four posts, a striped awning sloping to the front
	T.box(g, "Counter", F, 0, 1.2, Y, 12, 3.6, 3.4, R.wood[2])
	T.box(g, "CounterTop", F, 0, 1.4, Y + 3.4, 12.6, 4.2, .5, R.wood[1], nil, false)
	T.box(g, "Back", F, 0, -3.6, Y, 12, 1, 7, R.wood[3])
	for _, su in { -1, 1 } do
		for _, sd in { -1, 1 } do T.box(g, "Post", F, su * 5.8, sd * 3.2 - .4, Y, .8, .8, 9, R.wood[3], nil, false) end
	end
	A.awning(g, "Awning", F, 0, 0, Y + 9, 14, 9, R.red[2], white, 7)
	local fruit = { R.red[2], R.orange[2], R.gold[2], R.green[2] }
	for k = 0, 7 do
		T.ball(g, "Fruit", F, -4.9 + k * 1.4, 1.4 + (k % 2) * .6, Y + 4.3, 1.3, fruit[k % 4 + 1], nil, false)
	end
	T.crate(g, "Crate", F.world(4.2, 0, 4.4).X, F.world(4.2, 0, 4.4).Z, Y, 2.6, .3)
end

props.Crane = function(g, F)
	-- yellow lattice tower (four legs + braces), cab, jib to the front, counter-jib with a weight, hook on a cable
	local H, legs = 36, 2.4
	T.box(g, "Footing", F, 0, 0, Y, 8, 8, 1.2, R.stone[2])
	for _, su in { -1, 1 } do
		for _, sd in { -1, 1 } do T.box(g, "Leg", F, su * legs, sd * legs, Y + 1.2, .8, .8, H, R.gold[2]) end
	end
	for y = 4, H, 6 do
		for _, s in { -1, 1 } do
			T.part(g, "Brace", Vector3.new(.4, 7.6, .4), F.cf(0, Y + y, s * legs, CFrame.Angles(0, 0, math.rad(if y % 12 == 4 then 40 else -40))), R.gold[3], nil, false)
			T.part(g, "Brace", Vector3.new(.4, 7.6, .4), F.cf(s * legs, Y + y, 0, CFrame.Angles(math.rad(if y % 12 == 4 then 40 else -40), 0, 0)), R.gold[3], nil, false)
		end
	end
	local top = Y + 1.2 + H
	T.box(g, "Cab", F, 0, 3.4, top - 4, 4.4, 3.6, 4, R.blue[2])
	T.box(g, "CabGlass", F, 0, 5.25, top - 2.8, 3.6, .2, 2, T.glass, nil, false)
	T.box(g, "Jib", F, 0, 13, top, 2.4, 30, 2, R.gold[2])
	T.box(g, "CounterJib", F, 0, -6, top, 2.4, 10, 2, R.gold[2])
	T.box(g, "Weight", F, 0, -9, top - 3, 3.4, 3.4, 4, R.stone[3])
	T.box(g, "Mast", F, 0, 0, top, 1.4, 1.4, 6, R.gold[3])
	for _, d in { 14, -6 } do
		local a, b = F.world(0, top + 6, 0), F.world(0, top + 2, d)
		local mid = (a + b) / 2
		T.part(g, "Pendant", Vector3.new(.3, .3, (b - a).Magnitude), CFrame.lookAt(mid, b), ink, nil, false)
	end
	T.box(g, "Trolley", F, 0, 22, top - 1, 2, 2, 1, R.red[2], nil, false)
	T.box(g, "Cable", F, 0, 22, top - 15, .3, .3, 14, ink, nil, false)
	T.box(g, "Hook", F, 0, 22, top - 17, 1.6, 1.6, 2, R.red[2], nil, false)
	T.box(g, "Stripe", F, 0, 27.4, top + .1, 2.6, 2, 1.9, R.red[2], nil, false)
end

props.Tent = function(g, F)
	-- A-frame camp tent (ridge front to back) with a dark doorway, ground cloth and a pennant
	T.box(g, "Cloth", F, 0, 0, Y, 11, 12, .3, R.wood[1], nil, false)
	for _, s in { -1, 1 } do
		local p = T.part(g, "Side", Vector3.new(4.6, 7, 10), F.cf(s * 2.3, Y + 3.8, 0), if s < 0 then R.orange[2] else R.orange[1], nil, true, "Wedge")
		p.CFrame = F.cf(s * 2.3, Y + 3.8, 0, CFrame.Angles(0, s * math.pi / 2, 0))
		p.Size = Vector3.new(10, 7, 4.6)
	end
	T.box(g, "Door", F, 0, 5.02, Y + .3, 2.6, .2, 4.4, ink, nil, false)
	T.cylDep(g, "Ridge", F, 0, 0, Y + 7.4, .5, 11, R.wood[3], nil, false)
	T.cyl(g, "Pole", F, 0, 5.6, Y + .3, .4, 9.6, R.wood[3], nil, false)
	T.part(g, "Pennant", Vector3.new(.2, 1.4, 2.4), F.cf(0, Y + 9.2, 6.8), R.red[2], nil, false, "Wedge")
end

if only == "lib" then return props end -- the builders, for other stages; nothing is built

-- build, pivot and copy each prop
local names = {}
for name in props do if name ~= "cliff" and (not only or name == only) then table.insert(names, name) end end
table.sort(names)
local store = game:GetService("ServerStorage"):FindFirstChild("MapArt") or Instance.new("Folder")
store.Name, store.Parent = "MapArt", game:GetService("ServerStorage")
local report = {}
for i, name in names do
	local ordered = {}
	for n in props do if n ~= "cliff" then table.insert(ordered, n) end end
	table.sort(ordered)
	local slot = table.find(ordered, name) :: number
	local cx, cz = 6000 + (slot - 1) % 5 * 70 - 140, -math.floor((slot - 1) / 5) * 90 -- far from the live map, for clean previews
	local F = A.frame(cx, cz, "S")
	local g = A.group(bench, name)
	props[name](g, F)
	g.WorldPivot = CFrame.lookAt(Vector3.new(cx, Y, cz) + A.offset, Vector3.new(cx, Y, cz) + A.offset + F.forward)
	local old = store:FindFirstChild(name)
	if old then
		assert(old:GetAttribute("PropBuilder"), "MapArt." .. name .. " is the owner's; not replacing it")
		old:Destroy()
	end
	local copy = g:Clone()
	copy:SetAttribute("PropBuilder", true)
	copy.Parent = store
	table.insert(report, ("%s %d parts"):format(name, A.count(g)))
end
return table.concat(report, "\n")
