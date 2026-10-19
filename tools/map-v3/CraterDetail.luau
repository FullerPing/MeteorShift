-- Map v3 crater detail (visual only). Load Common, Brick and Toon first; run after Core and Roads, then Dezfight:
--   L("../map-v3/CraterDetail")
-- Owns Map_Redesign.CraterDetail. The ring road's 64 Loop boxes and the crater's 48 StuddedRim chords stay where they are
-- (the loops are the walkable surface, the rim is in the FX ground rays) but are hidden, and seamless pieces are drawn:
--   RingRoad: one CSG annulus over the loops with the ring's stud skin, white kerbs on both edges (open at the four
--     crater approaches inside, at the eight avenues and the south plaza outside) and a gold dashed centre line.
--   Rim: four gold CSG arcs between the ramps with a navy lip on the crater side.
--   Fissures: glowing cracks on the bowl floor (between the ramp landings) and on bowl slopes away from the ramps.
--   Boulders: Big Stone meshes on the apron between the approaches.
-- Every piece is anchored, non-colliding and CanQuery false, so gameplay rays (landing FX, impact spots, floor probes)
-- see exactly the surfaces they saw before.
local A = assert(_G.MapRedesignArt, "Run Common first")
local T = assert(A.toon, "Run Toon first")
local G = A.geometry
local Geometry = game:GetService("GeometryService")
local map = A.map
local ring, crater = map.Roads.Ring, map.Crater
local rng = Random.new(134)

local LOOP_R, LOOP_HALF = G.LoopRadius or 134, 9 -- the ring road: r 125..143
local RIM_IN, RIM_OUT = 83.2, 89.2
local GOLD, NAVY, KERB = Color3.fromHex("ffd736"), Color3.fromHex("1b2a4a"), Color3.fromHex("faf8f0")
local MAGMA = Color3.fromRGB(255, 122, 46)

local detail = A.group(map, "CraterDetail")
local function quiet(p: BasePart, shadow: boolean?)
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.CastShadow = shadow == true
	p:SetAttribute("MapRedesignOwned", true)
	return p
end
-- a vertical cylinder (Roblox cylinders run along X)
local function disc(parent: Instance, name: string, radius: number, y0: number, y1: number, color: Color3): Part
	local p = A.part(parent, name, Vector3.new(y1 - y0, radius * 2, radius * 2), CFrame.new(0, (y0 + y1) / 2, 0) * CFrame.Angles(0, 0, math.pi / 2), color, nil, false, Enum.PartType.Cylinder)
	return quiet(p) :: Part
end
-- a box across the annulus at `angle` degrees, `width` across the ray, to cut an opening
local function cutter(parent: Instance, angle: number, width: number, r0: number, r1: number, y0: number, y1: number): Part
	local t = math.rad(angle)
	local mid = Vector3.new(math.cos(t), 0, math.sin(t)) * (r0 + r1) / 2 + Vector3.new(0, (y0 + y1) / 2, 0)
	local p = A.part(parent, "Cut", Vector3.new(width, y1 - y0, r1 - r0), CFrame.lookAt(mid, mid + Vector3.new(math.cos(t), 0, math.sin(t))), KERB, nil, false)
	return quiet(p) :: Part
end
-- outer disc minus inner disc minus cutters, as one PartOperation named `name`
local function annulus(name: string, rIn: number, rOut: number, y0: number, y1: number, color: Color3, cuts: { { number } }?): BasePart
	local outer = disc(detail, name, rOut, y0, y1, color)
	local subtract: { BasePart } = { disc(detail, "Hole", rIn, y0 - 1, y1 + 1, color) }
	for _, c in cuts or {} do table.insert(subtract, cutter(detail, c[1], c[2], rIn - 2, rOut + 2, y0 - 1, y1 + 1)) end
	local result = Geometry:SubtractAsync(outer, subtract, { CollisionFidelity = Enum.CollisionFidelity.Box, RenderFidelity = Enum.RenderFidelity.Precise, SplitApart = false })
	outer:Destroy()
	for _, s in subtract do s:Destroy() end
	local union = result[1] :: BasePart
	union.Name, union.Color, union.Material = name, color, Enum.Material.SmoothPlastic
	union.UsePartColor = true
	quiet(union)
	union.Parent = detail
	return union
end
local function hide(p: BasePart)
	p.Transparency = 1
	for _, t in p:GetChildren() do if t:IsA("Texture") or t:IsA("Decal") then t.Transparency = 1 end end
end

-- ring road: its top just over the highest loop top (Dezfight leaves the loops at a few heights), so feet meet it
local RING_TOP = 0
for _, p in ring:GetChildren() do
	if p:IsA("BasePart") and p.Name:match("^Loop%d+$") then RING_TOP = math.max(RING_TOP, p.Position.Y + p.Size.Y / 2 + .04) end
end
local skin = (ring:FindFirstChild("Loop1") :: BasePart):FindFirstChildOfClass("Texture")
local road = annulus("RingRoad", LOOP_R - LOOP_HALF, LOOP_R + LOOP_HALF, RING_TOP - .4, RING_TOP, Color3.fromHex("ecdcb2"))
if skin then
	local s = skin:Clone()
	s.Face = Enum.NormalId.Top
	s.Parent = road
end
for _, p in ring:GetChildren() do if p:IsA("BasePart") and p.Name:match("^Loop%d+$") then hide(p) end end
local avenueCuts = {}
for _, angle in G.Avenues.angles do table.insert(avenueCuts, { angle, G.Avenues.width + 2 }) end
table.insert(avenueCuts, { 270, 82 }) -- the south plaza
annulus("RingKerbOuter", LOOP_R + LOOP_HALF, LOOP_R + LOOP_HALF + 1.2, RING_TOP - .4, RING_TOP + .36, KERB, avenueCuts)
annulus("RingKerbInner", LOOP_R - LOOP_HALF - 1.2, LOOP_R - LOOP_HALF, RING_TOP - .4, RING_TOP + .36, KERB, { { 0, 26 }, { 90, 26 }, { 180, 26 }, { 270, 26 } })
for k = 0, 71 do
	local t = math.rad(k * 5 + 2.5)
	local at = Vector3.new(math.cos(t), 0, math.sin(t)) * LOOP_R + Vector3.new(0, RING_TOP + .05, 0)
	quiet(A.part(detail, "Dash", Vector3.new(.7, .2, 5), CFrame.lookAt(at, at + Vector3.new(-math.sin(t), 0, math.cos(t))), GOLD, nil, false))
end
task.wait()

-- rim: the 48 chords become four arcs; the gaps match the ramps (the chords stop 14.5 degrees either side of each axis)
local rimCut = 2 * RIM_OUT * math.sin(math.rad(14.5))
local cuts = { { 0, rimCut }, { 90, rimCut }, { 180, rimCut }, { 270, rimCut } }
local rimSkin: Texture? = nil
for _, p in crater.Rim:GetDescendants() do
	if p:IsA("BasePart") then
		rimSkin = rimSkin or p:FindFirstChildOfClass("Texture")
		hide(p)
	end
end
local rim = annulus("RimArcs", RIM_IN, RIM_OUT, 0, 1.6, GOLD, cuts)
if rimSkin then
	local s = rimSkin:Clone()
	s.Transparency = 0
	s.Face = Enum.NormalId.Top
	s.Parent = rim
end
annulus("RimLip", RIM_IN - .4, RIM_IN + .8, 0, 1.75, NAVY, cuts)
task.wait()

-- fissures: zig-zag cracks on the floor between the landings, then strips on some slopes away from the ramps
local floor = crater.Bowl.Floor :: BasePart
local floorTop = floor.Position.Y + floor.Size.X / 2
for k = 0, 7 do
	local angle = math.rad(22.5 + k * 45 + rng:NextNumber(-8, 8))
	local from = Vector3.new(math.cos(angle), 0, math.sin(angle)) * rng:NextNumber(10, 16)
	local reach = rng:NextNumber(38, floor.Size.Y / 2 - 3)
	for _ = 1, 4 do
		local bend = angle + rng:NextNumber(-.35, .35)
		local to = from + Vector3.new(math.cos(bend), 0, math.sin(bend)) * reach / 4
		local mid = (from + to) / 2 + Vector3.new(0, floorTop + .05, 0)
		quiet(A.part(detail, "Fissure", Vector3.new(rng:NextNumber(.5, 1.1), .16, (to - from).Magnitude + .4), CFrame.lookAt(mid, mid + (to - from)), MAGMA, Enum.Material.Neon, false))
		from = to
	end
end
local slopes = {}
for _, s in crater.Bowl:GetChildren() do
	if s:IsA("BasePart") and s.Name:match("^Slope") then
		local a = math.deg(math.atan2(s.Position.Z, s.Position.X)) % 90
		if a > 22 and a < 68 then table.insert(slopes, s) end
	end
end
for k = 1, math.min(16, #slopes) do
	local s = table.remove(slopes, rng:NextInteger(1, #slopes)) :: BasePart
	local length = rng:NextNumber(8, s.Size.Z * .7)
	local cf = s.CFrame * CFrame.new(rng:NextNumber(-1, 1), s.Size.Y / 2 + .06, rng:NextNumber(-3, 3)) * CFrame.Angles(0, rng:NextNumber(-.3, .3), 0)
	local strip = quiet(A.part(detail, "SlopeFissure", Vector3.new(rng:NextNumber(.4, .8), .14, length), cf, MAGMA, Enum.Material.Neon, false))
	strip:SetAttribute("Slope", s.Name)
	if k % 4 == 0 then task.wait() end
end

-- boulders on the apron between the approaches, sat on whatever is under them
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { map:FindFirstChild("CraterApron"), map.Ground }
local boulders = A.group(detail, "Boulders")
for k = 0, 15 do
	local angle = 11.25 + k * 22.5 + rng:NextNumber(-4, 4)
	if (angle % 90) < 18 or (angle % 90) > 72 then continue end
	local t = math.rad(angle)
	local r = rng:NextNumber(96, 117)
	local x, z = math.cos(t) * r, math.sin(t) * r
	local hit = workspace:Raycast(Vector3.new(x, 40, z), Vector3.new(0, -80, 0), params)
	local y = if hit then hit.Position.Y else 0
	local height = rng:NextNumber(3, 6)
	local m = T.mesh(boulders, "Big Stone (Lowpoly)", CFrame.new(x, y - .3, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), height,
		function() T.ball(boulders, "Boulder", A.frame(x, z, Vector3.zAxis), 0, 0, y + height / 2, height, A.colors.stone) end)
	if m then
		for _, p in (if m:IsA("BasePart") then { m } else m:GetDescendants()) do
			if p:IsA("BasePart") then quiet(p, true) end
		end
	end
end

return { stage = "CraterDetail", parts = A.count(detail), hiddenLoops = 64, hiddenRim = #crater.Rim:GetDescendants() }
