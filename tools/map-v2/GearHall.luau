-- Common + Brick + Toon first. The Gear Hall: an open-air gear plaza southeast of the ring road, the mirror of the
-- egg garden across the spawn. A big GEAR title floats over a two-step stone display that shows every tier
-- (pickaxes in front, backpacks behind), your current pickaxe and backpack turn on two big pedestals at the front
-- corners, and a gold pad in front is the shop. World art only; the local equipment models and live stats come from
-- GearHallController / Shared.WorldEquipmentDisplay, which read:
--   TierWalls: 16 BaseParts "<kind><tier>" with attrs EquipmentKind, EquipmentTier, DisplayOffset (relative),
--   DisplayScale and a SurfaceGui whose labels Name/Tier/Status exist; CurrentStands: a Model per kind with a
--   PrimaryPart, DisplayOffset, DisplayBottomOffset, DisplayScale and a descendant TextLabel named "Stats".
-- PickaxeShop is a direct TownSquare child with a ShopPoint (ShopService / TutorialController).
local A = assert(_G.MapRedesignArt)
local T = assert(A.toon, "Run Toon first")
local R = T.ramp
local Config = A.config
local town = A.ensure(A.map, "TownSquare")
local zone = A.zone("GearHall")
local F = A.frameFor(zone) -- turned toward the crater (zone.facing)
local hall = A.group(town, "GearHall")
local floorY = 1.8
-- the plaza is a little larger than the zone's 50 x 36 rectangle; 54 x 40 still fits the rotated zone bounds
local PLAZA_LAT, PLAZA_DEP = 54, 40

hall.PrimaryPart = T.roundPad(hall, "Plinth", F, PLAZA_LAT, PLAZA_DEP, 0, 1.2, T.sand[2])
T.roundPad(hall, "Sand", F, PLAZA_LAT - 2, PLAZA_DEP - 2, 1.2, .6, T.sand[1])

-- the display: two long stone steps across the back, light caps on top
local stepLat, stepDep = 42, 6
local steps = {
	{ kind = "pickaxe", d = -5, top = floorY + 3 },
	{ kind = "backpack", d = -5 - stepDep, top = floorY + 12 }, -- clears the pickaxes standing in front
}
for _, step in steps do
	T.box(hall, "DisplayStep", F, 0, step.d, floorY, stepLat, stepDep, step.top - floorY - .6, R.stone[2])
	T.box(hall, "DisplayCap", F, 0, step.d, step.top - .6, stepLat + .4, stepDep + .4, .6, R.stone[1])
end
T.box(hall, "DisplayFoot", F, 0, -5 - stepDep / 2, floorY, stepLat + 1.2, stepDep * 2 + 1.2, .5, R.stone[3])

-- one plaque per tier on the step's front face; the local model stands on the step above it, facing the road
local walls = A.group(hall, "TierWalls")
local pitch = 5.1
for _, step in steps do
	local kind = step.kind
	local catalog = if kind == "pickaxe" then Config.Pickaxes else Config.Backpacks
	assert(#catalog == 8, "Tier display requires all eight Config tiers")
	local faceD = step.d + stepDep / 2
	local plaqueY = if kind == "pickaxe" then floorY + 1.5 else step.top - 1.6
	for tier, item in catalog do
		local u = (tier - 4.5) * pitch
		local card = T.part(walls, kind .. tier, Vector3.new(4.8, 2.3, .3), F.cf(u, plaqueY, faceD + .2), T.ink, nil, false)
		card:SetAttribute("EquipmentKind", kind)
		card:SetAttribute("EquipmentTier", tier)
		local scale = if kind == "pickaxe" then 1.2 else 1.5
		local shownAt = F.world(u, step.top + (if kind == "pickaxe" then 3.4 else 3), step.d) + A.offset
		card:SetAttribute("DisplayOffset", card.CFrame:ToObjectSpace(CFrame.lookAt(shownAt, shownAt + F.forward)))
		card:SetAttribute("DisplayScale", scale)
		local gui = Instance.new("SurfaceGui")
		gui.Name, gui.Face, gui.LightInfluence = "TierLabel", Enum.NormalId.Front, 0
		gui.CanvasSize = Vector2.new(225, 100)
		gui.Parent = card
		local tierLabel = T.outlined(gui, "T" .. tier, Enum.Font.LuckiestGuy, item.Color or R.gold[1], UDim2.fromScale(.26, .8), UDim2.fromScale(.02, .1), 2)
		tierLabel.Name = "Tier"
		local name = T.outlined(gui, item.Name, Enum.Font.FredokaOne, T.white, UDim2.fromScale(.7, .44), UDim2.fromScale(.29, .06), 1.5)
		name.Name, name.TextXAlignment = "Name", Enum.TextXAlignment.Left
		local status = T.outlined(gui, "", Enum.Font.FredokaOne, R.gold[1], UDim2.fromScale(.7, .4), UDim2.fromScale(.29, .54), 1.5)
		status.Name, status.TextXAlignment = "Status", Enum.TextXAlignment.Left
	end
end

-- the big title over the display, with the how-to underneath
local title = T.textBoard(hall, "Title", F, 0, 29.5, -17, 40, 17, 4)
T.outlined(title, "GEAR", Enum.Font.LuckiestGuy, T.white, UDim2.fromScale(1, .76), nil, 3.5)
T.outlined(title, "UPGRADE YOUR PICKAXE & BACKPACK", Enum.Font.LuckiestGuy, R.gold[1], UDim2.fromScale(.94, .18), UDim2.fromScale(.03, .79), 1.5)

-- your current pickaxe and backpack on big pedestals at the front corners, live stats on the front
local stands = A.group(hall, "CurrentStands")
for _, data in { { "pickaxe", 1, R.gold[2] }, { "backpack", -1, R.violet[2] } } do
	local kind, side, rim = data[1], data[2], data[3]
	local u, d = side * 16, 8
	local stand = A.group(stands, kind)
	stand:SetAttribute("EquipmentKind", kind)
	stand:SetAttribute("DisplayScale", 2)
	stand.PrimaryPart = T.cyl(stand, "Foot", F, u, d, floorY, 13.4, 1.2, R.stone[3])
	T.cyl(stand, "Pedestal", F, u, d, floorY + 1.2, 11.6, 4.4, R.stone[2])
	local topY = floorY + 5.6
	T.cyl(stand, "Top", F, u, d, topY, 12.4, .9, rim)
	stand:SetAttribute("DisplayOffset", stand:GetPivot():ToObjectSpace(F.cf(u, topY + 6, d)))
	stand:SetAttribute("DisplayBottomOffset", stand:GetPivot():PointToObjectSpace(F.world(u, topY + 1.2, d) + A.offset))
	-- the heading and live stats float over the turning model (a flat board would sink into the round pedestal)
	local board = T.textBoard(stand, "StatsBoard", F, u, topY + 12.5, d, 11, 5, 25)
	T.outlined(board, "YOUR " .. string.upper(kind), Enum.Font.LuckiestGuy, rim, UDim2.fromScale(1, .36), nil, 3)
	local stats = T.outlined(board, "", Enum.Font.FredokaOne, T.white, UDim2.fromScale(1, .62), UDim2.fromScale(0, .38), 2)
	stats.Name = "Stats"
end

-- PickaxeShop: a direct TownSquare child, a glowing gold pad at the front; its ShopPoint carries the prompt
local shop = A.group(town, "PickaxeShop")
local pad = T.cyl(shop, "ShopPad", F, 0, 12.5, floorY, 9, .3, R.gold[2])
shop.PrimaryPart = pad
pad.CFrame *= CFrame.Angles(math.pi / 2, 0, 0) -- spin round its upright axis so the lettering reads from the road
local padGui = Instance.new("SurfaceGui") -- the cylinder's axis points up, so its top is the Right face
padGui.Name, padGui.Face, padGui.LightInfluence, padGui.CanvasSize = "Lettering", Enum.NormalId.Right, 0, Vector2.new(180, 180)
padGui.Parent = pad
T.outlined(padGui, "SHOP", Enum.Font.LuckiestGuy, T.white, UDim2.fromScale(.8, .4), UDim2.fromScale(.1, .3), 3)
T.cyl(shop, "ShopRing", F, 0, 12.5, floorY, 10.4, .2, R.gold[1], Enum.Material.Neon, false)
local point = A.box(shop, "ShopPoint", F, 0, 12.5, 4.2, 6, 6, 1, R.gold[1], nil, false)
point.Transparency = 1
point.CanCollide, point.CanTouch, point.CanQuery = false, false, false

-- fences on the flanks, pines and bushes round the back, an anvil (hero mesh if stored), a crate and a barrel
for k, run in { { -25, -8, -25, 4 }, { 25, -8, 25, 4 } } do T.fence(hall, F, run[1], run[2], run[3], run[4], floorY, k) end
for _, side in { -1, 1 } do
	local p = F.world(side * 23, 0, -14)
	T.tree(hall, "Pine", p.X, p.Z, floorY, .85, "pine")
	local b = F.world(side * 22.5, 0, -5)
	T.part(hall, "Bush", Vector3.one * 5.5, A.cf(b.X, floorY + 2, b.Z), R.green[2], nil, false, Enum.PartType.Ball)
end
T.flower(hall, F, -22, 8, floorY, R.red[2], 1)
T.flower(hall, F, 22, 8, floorY, R.pink[2], 2)
local function propAt(u, d) local p = F.world(u, 0, d) return p.X, p.Z end
local ax, az = propAt(-21, 15)
T.mesh(hall, "Anvil", A.cf(ax, floorY, az) * CFrame.Angles(0, math.atan2(-F.forward.X, -F.forward.Z) + math.pi / 2, 0), 5, function()
	local g = A.group(hall, "Anvil")
	local cf = A.cf(ax, floorY, az) * CFrame.lookAt(Vector3.zero, F.right)
	T.part(g, "Block", Vector3.new(3, 2.6, 3.6), cf * CFrame.new(0, 1.3, 0), R.stone[3])
	T.part(g, "Waist", Vector3.new(2, 1.6, 2.4), cf * CFrame.new(0, 3.4, 0), T.ink)
	T.part(g, "Face", Vector3.new(3.2, 1.6, 6), cf * CFrame.new(0, 4.9, 0), R.stone[2])
	return g
end)
local cx, cz = propAt(21, 15)
T.crate(hall, "Crate", cx, cz, floorY, 4, .3)
local bx, bz = propAt(23.5, 11)
T.barrel(hall, "Barrel", bx, bz, floorY, R.blue[2], 4.4)

for _, v in hall:GetDescendants() do if v:IsA("BasePart") then v.TopSurface = Enum.SurfaceType.Smooth end end
assert(#walls:GetChildren() == 16, "Missing tier cards")
assert(#stands:GetChildren() == 2, "Missing current stands")
A.within(hall, zone, 0)
A.within(shop, zone, 0)
local count = A.count(hall) + A.count(shop)
assert(count <= 160, "Gear Hall art budget: " .. count)
A.map:SetAttribute("GearHallPass", 5)
return { stage = "GearHall", artParts = count, tierCards = 16, currentStands = 2, shopPoint = { point.Position.X, point.Position.Y, point.Position.Z }, totalParts = A.count(A.map) }
