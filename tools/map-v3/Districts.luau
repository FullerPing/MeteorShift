-- Map v3 districts. Load Common, Brick and Toon first; run after Ground, Core and Fields:
--   L("../map-v3/Districts", L("../map-v3/PlanData"), L("../map-v3/Overlap"))
-- Builds every PlanData footprint without a `field`, one Model per footprint, grouped per plan cell under
-- Map_Redesign.Districts.<cell> (ModelStreamingMode Atomic). A footprint's frame faces the crater: lateral u across its
-- width `w`, depth toward the front, standing on its band's Y. A builder is picked by the row's tag, else its label;
-- anything without one gets a labelled box, so nothing is skipped silently. Every built model carries PlanLabel.
-- Skipped on purpose: the plateau (Ground), spawn, Refinery, Gear Hall, Hatchery and Commissary (Core). A footprint whose
-- model cuts into the town Core placed (the plan's two "board" rows are the real leaderboards) or into a district model
-- built before it is dropped and reported in `dropped`; so is one cutting into a field's gate or walls.
-- The Crown's contract (Task 7, CrownService) goes to Map_Redesign.Crown: Lift (SkyLift mesh with a `Prompt` part) at
-- the north avenue's end on T2, LiftTop on the Crown, DivePad at (-30, 475) with the Dive cannon behind it, and the
-- Starfall Beacon.
local A = assert(_G.MapRedesignArt, "Run Common first")
local T = assert(A.toon, "Run Toon first")
local plan, O = ...
assert(plan and O, "Pass the plan and the overlap helpers: L(\"../map-v3/PlanData\"), L(\"../map-v3/Overlap\")")
local G = A.geometry
local R = T.ramp
local BAND_Y = { T0 = G.Tiers[1].y, T1 = G.Tiers[2].y, T2 = G.Tiers[3].y, CROWN = G.Crown.y, ARENA = 0 }
local SKIP = { spawn = true, Refinery = true, ["Gear Hall"] = true, Hatchery = true, Commissary = true }
local art = game:GetService("ServerStorage").MapArt
local rng = Random.new(2026)

local function hex(s: string): Color3 return Color3.fromHex(s) end
local function sign(g: Instance, F: any, u: number, y: number, d: number, w: number, h: number, text: string, color: Color3?)
	T.box(g, "SignBoard", F, u, d - .3, y, w, .6, h, color or R.navy[2], nil, false)
	local gui = T.textBoard(g, "SignText", F, u, y + h / 2, d + .05, w - .6, h - .4, 30)
	T.outlined(gui, text, Enum.Font.FredokaOne, T.white, UDim2.fromScale(1, 1), nil, 3)
end
local function mesh(g: Instance, name: string, F: any, y: number, height: number, fallback: () -> ())
	local at = F.world(0, y, 0)
	return T.mesh(g, name, CFrame.lookAt(at, at + F.forward), height, function() fallback(); return nil end)
end
-- one random piece of the crystal collection, scaled to `height`, standing at (u, d)
local crystalSet = art:FindFirstChild("CRYSTAL.objAA951042-C459-4852-B06B-2C0AB4E18131 (1)")
local function crystal(g: Instance, F: any, u: number, d: number, y: number, height: number)
	local pieces = crystalSet and crystalSet:GetChildren()
	if not pieces or #pieces == 0 then T.box(g, "Crystal", F, u, d, y, height / 3, height / 3, height, R.violet[1], Enum.Material.Glass, false); return end
	local piece = pieces[rng:NextInteger(1, #pieces)]:Clone() :: MeshPart
	local scale = height / piece.Size.Y
	piece.Size *= scale
	piece.Anchored, piece.CanCollide, piece.CanTouch, piece.CanQuery = true, false, false, false
	piece:SetAttribute("MapRedesignOwned", true)
	local p = F.world(u, y + piece.Size.Y / 2, d)
	piece.CFrame = CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	piece.Parent = g
end

local B = {}
-- meshes
B.house = function(g, F, y, row) mesh(g, "House", F, y, 16 + rng:NextNumber(-1, 2), function() T.box(g, "House", F, 0, 0, y, row.w, row.d, 14, R.cream[2]) end) end
B.windmill = function(g, F, y, row) mesh(g, "Windmill", F, y, 28, function() T.cyl(g, "Windmill", F, 0, 0, y, row.w, 24, R.cream[2]) end) end
B.tent = function(g, F, y, row) mesh(g, "Tent", F, y, 8, function() T.box(g, "Tent", F, 0, 0, y, row.w, row.d, 7, R.red[2]) end) end
B.stall = function(g, F, y, row) mesh(g, "MarketStall", F, y, 10, function() T.box(g, "Stall", F, 0, 0, y, row.w, row.d, 9, R.orange[2]) end) end
B.crane = function(g, F, y, row) mesh(g, "Crane", F, y, 30, function() T.box(g, "Crane", F, 0, 0, y, 6, 6, 30, R.gold[2]) end) end
B.lighthouse = function(g, F, y, row) mesh(g, "Lighthouse", F, y, 40, function() T.cyl(g, "Lighthouse", F, 0, 0, y, 12, 40, T.white) end) end
B["surge rock"] = function(g, F, y, row) mesh(g, "Big Stone (Lowpoly)", F, y, 5 + rng:NextNumber(0, 2), function() T.ball(g, "Boulder", F, 0, 0, y + 2.5, 5, R.stone[2]) end) end
B.tree = function(g, F, y, row) mesh(g, "Tree", F, y, 18 + rng:NextNumber(-2, 4), function() T.tree(g, "Tree", F.world(0, 0, 0).X, F.world(0, 0, 0).Z, y, 1.3) end) end
B["orchard tree"] = function(g, F, y, row) mesh(g, "Blosom tree (too big)", F, y, 14 + rng:NextNumber(-1.5, 2), function() T.tree(g, "Tree", F.world(0, 0, 0).X, F.world(0, 0, 0).Z, y, 1, nil, R.pink) end) end
B["crystal spire"] = function(g, F, y, row) crystal(g, F, 0, 0, y, 12 + rng:NextNumber(0, 8)) end
B["giant egg"] = function(g, F, y, row)
	T.cyl(g, "Plinth", F, 0, 0, y, math.min(row.w, row.d), 1.6, R.cream[2])
	mesh(g, "GiantEgg", A.frame(F.world(0, 0, 0).X, F.world(0, 0, 0).Z, F.forward), y + 1.6, 11, function() T.ball(g, "Egg", F, 0, 0, y + 7, 9, R.pink[1]) end)
end
B["egg plinth"] = function(g, F, y, row)
	T.cyl(g, "Plinth", F, 0, 0, y, 7, 3, R.cream[2])
	T.cyl(g, "PlinthCap", F, 0, 0, y + 3, 8, .8, R.gold[2], nil, false)
	local eggs = { "Egg_meteorEgg", "Egg_crystalEgg", "Egg_auroraEgg" }
	mesh(g, eggs[rng:NextInteger(1, 3)], F, y + 3.8, 5, function() T.ball(g, "Egg", F, 0, 0, y + 6.3, 4, R.violet[1]) end)
end
-- landscape
B.hedge = function(g, F, y, row)
	T.box(g, "Hedge", F, 0, 0, y, row.w, row.d, 4, R.green[3])
	T.box(g, "HedgeTop", F, 0, 0, y + 4, row.w - .6, row.d - .6, .8, R.green[2], nil, false)
end
B["lava pool"] = function(g, F, y, row)
	local dia = math.min(row.w, row.d)
	T.cyl(g, "PoolRim", F, 0, 0, y, dia, 1.2, R.stone[3])
	T.cyl(g, "Lava", F, 0, 0, y + .4, dia - 3, 1, R.orange[1], Enum.Material.Neon, false)
end
B["ash cone"] = function(g, F, y, row)
	local dia = math.min(row.w, row.d)
	for i, k in { 1, .72, .46 } do T.cyl(g, "Ash", F, 0, 0, y + (i - 1) * 4, dia * k, 4.2, if i % 2 == 0 then R.stone[2] else R.stone[3]) end
	T.cyl(g, "AshGlow", F, 0, 0, y + 12, dia * .3, .5, R.orange[1], Enum.Material.Neon, false)
end
B["meteor wreck"] = function(g, F, y, row)
	local s = math.min(row.w, row.d)
	T.ball(g, "Wreck", F, 0, 0, y + s * .3, s * .8, Color3.fromRGB(70, 60, 74))
	T.ball(g, "WreckCrack", F, 0, s * .25, y + s * .32, s * .5, R.orange[1], Enum.Material.Neon, false)
	for k = 1, 3 do T.ball(g, "Chunk", F, rng:NextNumber(-s / 2, s / 2), rng:NextNumber(-s / 2, s / 2), y + .8, rng:NextNumber(1.6, 2.6), Color3.fromRGB(70, 60, 74), nil, false) end
end
B.secret = function(g, F, y, row)
	local s = math.min(row.w, row.d)
	T.ball(g, "Geode", F, 0, -s * .1, y + s * .25, s * .7, R.stone[3])
	T.ball(g, "GeodeHollow", F, 0, s * .12, y + s * .25, s * .5, R.violet[3], nil, false)
	crystal(g, F, 0, s * .1, y, s * .45)
end
B.rail = function(g, F, y, row)
	for _, u in { -1.5, 1.5 } do T.box(g, "Rail", F, u, 0, y + .3, .5, row.w + row.d, .5, R.stone[3], nil, false) end
	for k = -2, 2 do T.box(g, "Tie", F, 0, k * (row.w + row.d) / 5, y, 5, 1.2, .3, R.wood[3], nil, false) end
end
B["cart rail"] = B.rail
B.pen = function(g, F, y, row)
	local hw, hd = row.w / 2, row.d / 2
	T.fence(g, F, -hw, -hd, hw, -hd, y, 1); T.fence(g, F, hw, -hd, hw, hd, y, 2)
	T.fence(g, F, hw, hd, 2, hd, y, 3); T.fence(g, F, -2 - 4, hd, -hw, hd, y, 4); T.fence(g, F, -hw, hd, -hw, -hd, y, 5)
end
-- small things
B.chest = function(g, F, y, row)
	local p = F.world(0, 0, 0)
	T.crate(g, "Chest", p.X, p.Z, y, 4, 0, R.gold[2])
end
B.statue = function(g, F, y, row)
	T.box(g, "Plinth", F, 0, 0, y, 5, 5, 4, R.stone[1])
	T.box(g, "Body", F, 0, 0, y + 4, 3, 2, 5, R.stone[2])
	T.ball(g, "Head", F, 0, 0, y + 10.4, 3, R.stone[2])
	T.box(g, "Pickaxe", F, 2, .4, y + 7, .6, .6, 5, R.stone[3], nil, false)
end
B.podium = function(g, F, y, row)
	for k, spec in { { 0, 6, R.gold[2] }, { -6, 4, T.white }, { 6, 2.6, R.orange[2] } } do
		T.box(g, "Podium" .. k, F, spec[1], 0, y, 6, 6, spec[2], spec[3])
	end
	mesh(g, "Trophy", A.frame(F.world(0, 0, 0).X, F.world(0, 0, 0).Z, F.forward), y + 6, 6, function() T.ball(g, "Trophy", F, 0, 0, y + 8, 3, R.gold[1]) end)
end
B["anvil yard"] = function(g, F, y, row)
	T.box(g, "Yard", F, 0, 0, y, row.w, row.d, .3, R.stone[1], nil, false)
	for k = -1, 1 do
		local p = F.world(k * row.w / 3.5, 0, 0)
		local fr = A.frame(p.X, p.Z, F.forward)
		T.box(g, "Stump", fr, 0, 0, y, 3, 3, 2.4, R.wood[2])
		mesh(g, "Anvil", fr, y + 2.4, 2.4, function() T.box(g, "Anvil", fr, 0, 0, y + 2.4, 4, 2, 2, T.ink) end)
	end
end
local function board(g, F, y, row)
	for _, u in { -row.w / 2 + 1, row.w / 2 - 1 } do T.box(g, "Post", F, u, 0, y, 1, 1, 9, R.wood[2]) end
	sign(g, F, 0, y + 4, .6, row.w, 5, row.label:upper())
end
B.board = board; B["stats board"] = board; B.codes = board; B["Quest Board"] = board
-- buildings
local function shop(g, F, y, row)
	local w, d = row.w - 1, row.d - 1
	local body = hex(row.color)
	T.box(g, "Body", F, 0, 0, y, w, d, 11, body)
	T.box(g, "Trim", F, 0, 0, y + 11, w + .6, d + .6, .8, T.white, nil, false)
	T.gable(g, "Roof", F, 0, 0, y + 11.8, w, d, 5, R.red[2], T.white, 1.2)
	T.door(g, "Door", T.onFront(F, 0, d / 2, y + 3.6), 4, 7, T.white)
	for _, u in { -w / 3, w / 3 } do T.window(g, "Window", T.onFront(F, u, d / 2, y + 5.5), 3, 3, T.white, nil, false) end
	A.awning(g, "Awning", F, 0, d / 2 + 1.4, y + 8.2, w - 2, 3, R.red[1], T.white, 6)
	sign(g, F, 0, y + 9.4, d / 2 + .6, math.min(w - 2, 14), 2.4, row.label:upper(), R.navy[2])
end
B.cafe = shop; B.cocoa = shop; B["fish market"] = shop; B["pet shop"] = shop
B["boat shed"] = function(g, F, y, row)
	local w, d = row.w - 1, row.d - 1
	T.box(g, "Shed", F, 0, 0, y, w, d, 9, R.wood[2])
	T.gable(g, "Roof", F, 0, 0, y + 9, w, d, 4, R.blue[2], T.white, 1)
	T.door(g, "Door", T.onFront(F, 0, d / 2, y + 3.5), 6, 7, T.white)
end
local function hall(g, F, y, row)
	local w, d = row.w - 2, row.d - 2
	local body = hex(row.color)
	T.box(g, "Plinth", F, 0, 0, y, w + 2, d + 2, 1.6, R.stone[1])
	T.box(g, "Body", F, 0, -2, y + 1.6, w, d - 4, 16, body)
	T.box(g, "Cornice", F, 0, -2, y + 17.6, w + 1.4, d - 2.6, 1.6, T.white, nil, false)
	T.box(g, "Attic", F, 0, -2, y + 19.2, w - 6, d - 8, 3, body)
	local cols = math.max(3, math.floor(w / 7))
	for k = 0, cols - 1 do T.cyl(g, "Column", F, -w / 2 + 3 + k * (w - 6) / (cols - 1), d / 2 - 2, y + 1.6, 2, 16, T.white) end
	T.door(g, "Door", T.onFront(F, 0, d / 2 - 4, y + 5.6), 6, 8, R.gold[2])
	sign(g, F, 0, y + 14, d / 2 - 3.4, math.min(w - 8, 30), 3.4, row.label:upper(), R.navy[2])
end
B.Museum = hall; B["Hall of Fame"] = hall
B["Frost Rink"] = function(g, F, y, row)
	T.roundPad(g, "Rink", F, row.w, row.d, y, .6, Color3.fromRGB(221, 243, 255))
	T.roundPad(g, "Ice", F, row.w - 3, row.d - 3, y + .6, .2, Color3.fromRGB(190, 232, 255)).Material = Enum.Material.Glacier
	for _, u in { -row.w / 3, 0, row.w / 3 } do T.box(g, "Bench", F, u, -row.d / 2 - 2.5, y, 8, 2, 2, R.blue[2]) end
end
B["Sky Garden"] = function(g, F, y, row)
	T.box(g, "Terrace", F, 0, 0, y, row.w, row.d, 2.4, R.cream[2])
	T.box(g, "Lawn", F, 0, 0, y + 2.4, row.w - 2, row.d - 2, .3, R.green[1], nil, false)
	for k = -1, 1 do
		local p = F.world(k * row.w / 3.2, 0, -row.d / 5)
		local fr = A.frame(p.X, p.Z, F.forward)
		mesh(g, "Blosom tree (too big)", fr, y + 2.7, 14, function() T.tree(g, "Tree", p.X, p.Z, y + 2.7, 1, nil, R.pink) end)
	end
	for k = -2, 2 do T.flower(g, F, k * row.w / 5.5, row.d / 4, y + 2.7, ({ R.pink[2], R.gold[2], T.white, R.violet[1], R.red[1] })[k + 3], k) end
end
B["Sky Obby Tower"] = function(g, F, y, row)
	T.cyl(g, "Core", F, 0, 0, y, 10, 42, R.blue[2])
	T.cyl(g, "Cap", F, 0, 0, y + 42, 14, 1.6, R.gold[2])
	local colors = { R.red[1], R.orange[1], R.gold[1], R.green[1], R.blue[1], R.violet[1], R.pink[1] }
	for k = 0, 13 do
		local a = k * math.pi / 3.5
		T.cyl(g, "Pad", F, math.cos(a) * 11, math.sin(a) * 11, y + 2 + k * 3, 6, 1, colors[k % #colors + 1])
	end
end
B["Waterfall pools"] = function(g, F, y, row)
	local water = Color3.fromRGB(127, 216, 255)
	for k = 0, 2 do
		local d = -row.d / 3 + k * row.d / 3
		local dia = math.min(row.w, row.d / 3) * (1 - k * .15)
		T.cyl(g, "PoolRim", F, 0, d, y, dia, 2 + (2 - k) * 3, R.stone[1])
		T.cyl(g, "Water", F, 0, d, y + 2 + (2 - k) * 3 - .4, dia - 2.4, .5, water, Enum.Material.Glass, false).Transparency = .2
	end
	T.box(g, "Fall", F, 0, -row.d / 6, y + 3, 6, 1, 6, water, Enum.Material.Glass, false).Transparency = .3
	T.box(g, "Fall", F, 0, row.d / 6, y + 2, 6, 1, 4, water, Enum.Material.Glass, false).Transparency = .3
end
local obbyStep = 0
B["obby pad"] = function(g, F, y, row)
	-- stepping stones that climb a little each time (in plan order), a rainbow of pads on navy posts
	local h = 1.5 + (obbyStep % 6) * 2.2
	obbyStep += 1
	local colors = { R.red[1], R.orange[1], R.gold[1], R.green[1], R.blue[1], R.violet[1] }
	T.cyl(g, "Post", F, 0, 0, y, 1.6, h, R.navy[2])
	T.cyl(g, "Pad", F, 0, 0, y + h, math.min(row.w, row.d), 1.2, colors[obbyStep % #colors + 1])
end
B["Ledge Run"] = function(g, F, y, row)
	for k = 0, 5 do T.box(g, "Ledge", F, -row.w / 2 + 2.5 + k * (row.w - 5) / 5, 0, y, 4, row.d, 1.6 + k * 1.8, ({ R.navy[2], R.blue[2] })[k % 2 + 1]) end
end
B["Harbour boardwalk"] = function(g, F, y, row)
	T.box(g, "Deck", F, 0, 0, y, row.w, row.d, 1.2, R.wood[1])
	for k = 0, 9 do T.box(g, "Plank", F, -row.w / 2 + 9.5 + k * (row.w - 19) / 9, 0, y + 1.2, 1, row.d, .1, R.wood[2], nil, false) end
	for k = 0, 6 do
		local u = -row.w / 2 + 6 + k * (row.w - 12) / 6
		T.cyl(g, "Bollard", F, u, row.d / 2 - 1.5, y + 1.2, 1.6, 2.4, T.ink)
		if k % 2 == 0 then local p = F.world(u, 0, -row.d / 2 + 2); T.lamp(g, "Lamp" .. k, p.X, p.Z, y + 1.2, R.gold[1]) end
	end
end
B["egg fountain"] = function(g, F, y, row)
	local dia = math.min(row.w, row.d)
	T.cyl(g, "Basin", F, 0, 0, y, dia, 2.4, R.cream[2])
	T.cyl(g, "Water", F, 0, 0, y + 1.6, dia - 2, 1, Color3.fromRGB(127, 216, 255), Enum.Material.Glass, false).Transparency = .2
	T.cyl(g, "Column", F, 0, 0, y + 2.4, 3, 3, T.white)
	mesh(g, "GiantEgg", A.frame(F.world(0, 0, 0).X, F.world(0, 0, 0).Z, F.forward), y + 5.4, 7, function() T.ball(g, "Egg", F, 0, 0, y + 9, 6, R.pink[1]) end)
end
-- landmarks (each field's showpiece) and scars
B.derrick = function(g, F, y, row)
	for _, su in { -1, 1 } do for _, sd in { -1, 1 } do
		local p0, p1 = F.world(su * 4, y, sd * 3), F.world(su * 1.2, y + 26, sd * 1)
		T.part(g, "Leg", Vector3.new(1, 1, (p1 - p0).Magnitude), CFrame.lookAt((p0 + p1) / 2, p1), R.rust[2])
	end end
	for k = 1, 4 do T.box(g, "Brace", F, 0, 0, y + k * 5.5, 8 - k * 1.3, 6 - k * 1, .6, R.rust[3], nil, false) end
	T.ball(g, "Lamp", F, 0, 0, y + 27, 2, R.orange[1], Enum.Material.Neon, false)
end
B["ice falls"] = function(g, F, y, row)
	local ice = Color3.fromRGB(190, 232, 255)
	for k = 0, 3 do T.box(g, "Ice", F, rng:NextNumber(-3, 3), -k * .6, y, row.w - k * 3, row.d - k, 18 - k * 4, ice, Enum.Material.Glacier) end
	T.box(g, "Pool", F, 0, row.d / 2 + 2, y, row.w, 4, .4, Color3.fromRGB(127, 216, 255), Enum.Material.Glass, false)
end
B.geode = B.secret
B.springs = function(g, F, y, row)
	local dia = math.min(row.w, row.d)
	T.cyl(g, "Rim", F, 0, 0, y, dia, 1.2, R.gold[3])
	T.cyl(g, "Spring", F, 0, 0, y + .5, dia - 3, 1, R.gold[1], Enum.Material.Neon, false)
	for k = 1, 3 do T.ball(g, "Steam", F, rng:NextNumber(-2, 2), rng:NextNumber(-2, 2), y + 3 + k * 2.4, 2.4 + k, T.white, nil, false).Transparency = .4 + k * .12 end
end
B["Ember vent"] = function(g, F, y, row)
	T.blob(g, "Mound", Vector3.new(row.w, 14, row.d), F.cf(0, y + 3, 0), Color3.fromRGB(122, 46, 30))
	T.blob(g, "MoundTop", Vector3.new(row.w * .5, 8, row.d * .5), F.cf(0, y + 8, 0), Color3.fromRGB(90, 34, 24))
	T.cyl(g, "Vent", F, 0, 0, y + 11.5, 8, .6, R.orange[1], Enum.Material.Neon, false)
end
local function scar(g, F, y, row)
	local dia = math.min(row.w, row.d)
	local glass = row.label == "Glass Scar"
	T.cyl(g, "Scorch", F, 0, 0, y, dia, .25, if glass then Color3.fromRGB(63, 184, 200) else hex(row.color), if glass then Enum.Material.Glass else nil, false)
	T.cyl(g, "Pit", F, 0, 0, y + .05, dia * .45, .25, Color3.fromRGB(60, 52, 58), nil, false)
	for k = 1, 6 do
		local a = k * math.pi / 3 + rng:NextNumber(-.3, .3)
		T.ball(g, "Ejecta", F, math.cos(a) * dia * .42, math.sin(a) * dia * .42, y + .6, rng:NextNumber(1.6, 3), if glass then R.teal[1] else Color3.fromRGB(80, 70, 76), if glass then Enum.Material.Glass else nil, false)
	end
end
B["Cinder Scar"] = scar; B["Glass Scar"] = scar; B["old scar"] = scar
B.Lookout = function(g, F, y, row)
	local p = F.world(0, 0, 0)
	T.roundTower(g, p.X, p.Z, y, y + 40, math.min(row.w, row.d) - 6, R.cream, R.blue)
end
B["Rebirth Terrace"] = function(g, F, y, row)
	local monument = game:GetService("ServerStorage").SwapRollback.Map_v8.TownSquare.RebirthMonument:Clone()
	for _, v in monument:GetDescendants() do v:SetAttribute("MapRedesignOwned", true) end
	monument:SetAttribute("MapRedesignOwned", true)
	local at = F.world(0, y + monument:GetPivot().Y, 0)
	monument:PivotTo(CFrame.lookAt(at, at + F.forward))
	monument.Parent = g
end
local function fallback(g, F, y, row)
	T.box(g, "Placeholder", F, 0, 0, y, row.w, row.d, 6, hex(row.color))
	sign(g, F, 0, y + 2, row.d / 2 + .1, math.max(row.w - 1, 4), 2.4, (row.label ~= "" and row.label or row.tag):upper())
end

-- the Crown's contract pieces
local crown = A.group(A.map, "Crown")
local function crownPieces()
	local c = G.Crown
	local liftAt = Vector3.new(0, G.Tiers[3].y, c.z0 - 7)
	local lift = A.group(crown, "Lift")
	T.mesh(lift, "SkyLift", CFrame.lookAt(liftAt, liftAt - Vector3.zAxis), 51.4, function() T.part(lift, "Shaft", Vector3.new(12, 50, 10), CFrame.new(liftAt + Vector3.new(0, 25, 0)), T.white) end)
	local prompt = A.part(lift, "Prompt", Vector3.new(6, 6, 2), CFrame.new(liftAt + Vector3.new(0, 3.5, -7.5)), T.white, nil, false)
	prompt.Transparency = 1
	local top = A.part(crown, "LiftTop", Vector3.new(6, 1, 6), CFrame.lookAt(Vector3.new(0, c.y + .5, c.z0 + 12), Vector3.new(0, c.y + .5, c.z0 + 20)), T.white, nil, false)
	top.Transparency = 1
	-- the dive: a glowing pad and the cannon behind it, pointing at the crater
	local padAt = Vector3.new(-30, c.y, 475)
	local pad = A.part(crown, "DivePad", Vector3.new(1, 10, 10), CFrame.new(padAt + Vector3.new(0, .3, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(240, 65, 142), Enum.Material.Neon, false, Enum.PartType.Cylinder)
	pad.CanTouch = true
	local ring = A.part(crown, "DivePadRing", Vector3.new(.8, 12, 12), CFrame.new(padAt + Vector3.new(0, .2, 0)) * CFrame.Angles(0, 0, math.pi / 2), T.white, nil, false, Enum.PartType.Cylinder)
	ring.CanQuery = false
	local cannonAt = padAt + Vector3.new(0, 0, 12)
	T.mesh(crown, "DiveCannon", CFrame.lookAt(cannonAt, cannonAt - Vector3.zAxis), 6.9, function() T.part(crown, "Cannon", Vector3.new(8, 6, 12), CFrame.new(cannonAt + Vector3.new(0, 3, 0)), R.pink[2]) end)
	local beaconAt = Vector3.new(0, c.y, 505)
	T.mesh(crown, "StarfallBeacon", CFrame.lookAt(beaconAt, beaconAt - Vector3.zAxis), 120, function() T.part(crown, "Beacon", Vector3.new(10, 120, 10), CFrame.new(beaconAt + Vector3.new(0, 60, 0)), R.gold[1]) end)
end
crownPieces()

-- the districts
local districts = A.group(A.map, "Districts")
local cells: { [string]: Model } = {}
local built, labelled, placeholders, wanted, dropped = 0, {}, {}, {}, {}
local solid = O.index(24)
for _, p in A.map.TownSquare:GetDescendants() do
	if p:IsA("BasePart") and p.Transparency < 1 and not p:IsA("SpawnLocation") then solid:add(p, "town") end
end
for _, p in (A.map:FindFirstChild("Gates") and A.map.Gates:GetDescendants() or {}) do
	if p:IsA("BasePart") and p.Transparency < 1 then solid:add(p, "a field gate or wall") end
end
local function visibleParts(g: Instance)
	local parts = {}
	for _, p in g:GetDescendants() do if p:IsA("BasePart") and p.Transparency < 1 then table.insert(parts, p) end end
	return parts
end
for index, row in plan.footprints do
	if row.field or row.kind == "plateau" or row.tag == "crownrock" or SKIP[row.label] then continue end
	local key = if row.tag ~= "" and row.tag ~= "axis" and row.tag ~= "avenue-end" then row.tag else row.label
	local cell = cells[row.cell]
	if not cell then
		cell = A.group(districts, row.cell) :: Model
		cell.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		cells[row.cell] = cell
	end
	local yaw = math.rad(row.yaw)
	local front = -Vector3.new(math.cos(yaw), 0, math.sin(yaw))
	local F = A.frame(row.x, row.z, front)
	local g = A.group(cell, (key ~= "" and key or row.kind):gsub("%s", "") .. index)
	g:SetAttribute("PlanLabel", row.label)
	g:SetAttribute("PlanTag", row.tag)
	local y = BAND_Y[row.band]
	local builder = B[key] or B[row.kind] or fallback
	if builder == fallback then table.insert(placeholders, key ~= "" and key or row.kind) end
	builder(g, F, y, row)
	local parts, clash = visibleParts(g), nil
	for _, p in parts do
		local hit = solid:hits(p, 0.15, g)[1]
		if hit then clash = if typeof(hit.tag) == "string" then hit.tag else hit.tag.Name; break end
	end
	if clash then
		table.insert(dropped, g.Name .. " (into " .. clash .. ")")
		g:Destroy()
		continue
	end
	for _, p in parts do solid:add(p, g) end
	built += 1
	if row.label ~= "" then wanted[row.label] = (wanted[row.label] or 0) + 1 end
	if built % 12 == 0 then task.wait() end
end
for _, g in districts:GetDescendants() do
	local label = g:GetAttribute("PlanLabel")
	if label and label ~= "" then labelled[label] = (labelled[label] or 0) + 1 end
end
local missing = {}
for label, n in wanted do if labelled[label] ~= n then table.insert(missing, label) end end
return { stage = "Districts", built = built, dropped = dropped, cells = #districts:GetChildren(), placeholders = placeholders, missingLabels = missing,
	parts = A.count(districts) + A.count(crown) }
