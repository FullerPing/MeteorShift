-- Cartoon-simulator grammar on top of Common + Brick (load after both). Smooth, rounded, chunky shapes in
-- three-tone colour ramps; no studs (the ground, roads and walls keep theirs). Everything goes through A.part so the
-- ownership and staged-map checks still apply. Frames come from Brick's A.frame / A.frameFor:
--   u = lateral (right of a viewer facing the front), d = toward the front, y = absolute height.
local A = assert(_G.MapRedesignArt, "Run Common first")
assert(A.frame, "Run Brick first")
local T = {}
A.toon = T

local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
-- three-tone ramps: [1] light (tops, highlights), [2] body, [3] dark (bases, outlines)
T.ramp = {
	orange = { rgb(255, 178, 74), rgb(250, 128, 40), rgb(186, 78, 26) },
	red = { rgb(255, 112, 104), rgb(232, 64, 58), rgb(160, 34, 40) },
	blue = { rgb(108, 184, 255), rgb(46, 128, 240), rgb(28, 74, 168) },
	navy = { rgb(70, 88, 130), rgb(40, 52, 86), rgb(22, 30, 54) },
	pink = { rgb(255, 176, 226), rgb(250, 120, 200), rgb(196, 70, 150) },
	violet = { rgb(206, 156, 255), rgb(164, 98, 246), rgb(108, 56, 186) },
	gold = { rgb(255, 230, 110), rgb(255, 196, 40), rgb(206, 140, 20) },
	green = { rgb(140, 226, 98), rgb(88, 196, 64), rgb(48, 140, 52) },
	teal = { rgb(120, 236, 222), rgb(44, 200, 190), rgb(20, 138, 140) },
	frost = { rgb(220, 248, 255), rgb(150, 222, 255), rgb(84, 168, 222) },
	stone = { rgb(200, 206, 220), rgb(150, 160, 180), rgb(98, 108, 132) },
	wood = { rgb(214, 152, 92), rgb(168, 108, 62), rgb(112, 70, 42) },
	cream = { rgb(255, 250, 232), rgb(255, 236, 196), rgb(222, 196, 150) },
	sulfur = { rgb(250, 240, 120), rgb(222, 200, 60), rgb(150, 128, 34) },
	rust = { rgb(214, 124, 84), rgb(170, 86, 56), rgb(112, 54, 38) },
}
T.white = rgb(252, 252, 255)
T.ink = rgb(28, 32, 52) -- outline/detail colour
T.glass = rgb(168, 226, 255)
T.glow = rgb(255, 214, 120)

-- every toon part is smooth, no studs
function T.smooth(p)
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = if p.Material == Enum.Material.SmoothPlastic or p.Material == Enum.Material.Plastic then Enum.Material.SmoothPlastic else p.Material
	return p
end
function T.part(parent, name, size, cf, color, material, collide, shape)
	return T.smooth(A.part(parent, name, size, cf, color, material, collide, shape))
end
-- a box in a building frame (Brick's A.box signature)
function T.box(parent, name, F, u, d, y0, lat, dep, h, color, material, collide)
	return T.smooth(A.box(parent, name, F, u, d, y0, lat, dep, h, color, material, collide))
end
-- an upright cylinder in a frame, bottom at y0
function T.cyl(parent, name, F, u, d, y0, diameter, h, color, material, collide)
	return T.smooth(A.cylinder(parent, name, diameter, h, F.cf(u, y0 + h / 2, d), color, material, collide))
end
-- a cylinder lying along the frame's lateral axis (u), centred at (u, y, d)
function T.cylLat(parent, name, F, u, d, y, diameter, length, color, material, collide)
	return T.part(parent, name, Vector3.new(length, diameter, diameter), F.cf(u, y, d), color, material, collide, Enum.PartType.Cylinder)
end
-- a cylinder lying along the frame's depth axis (d)
function T.cylDep(parent, name, F, u, d, y, diameter, length, color, material, collide)
	return T.part(parent, name, Vector3.new(length, diameter, diameter), F.cf(u, y, d, CFrame.Angles(0, math.pi / 2, 0)), color, material, collide, Enum.PartType.Cylinder)
end
function T.ball(parent, name, F, u, d, y, diameter, color, material, collide)
	return T.part(parent, name, Vector3.new(diameter, diameter, diameter), F.cf(u, y, d), color, material, collide, Enum.PartType.Ball)
end
-- a wedge in a frame: full height at the BACK (toward -d) side, sloping down toward +d, unless `flip`
function T.wedge(parent, name, F, u, d, y0, lat, dep, h, color, flip, collide)
	local cf = F.cf(u, y0 + h / 2, d, if flip then CFrame.Angles(0, math.pi, 0) else nil)
	-- WedgePart: vertical face is local +Z (Back), slope faces local -Z (Front) = the frame's forward
	local p = A.part(parent, name, Vector3.new(lat, h, dep), cf, color, nil, collide, "Wedge")
	return T.smooth(p)
end

-- A gable roof: ridge along the lateral axis at depth d, eaves overhanging by `over`, ridge cap and eave trims.
-- Returns the ridge height. 5 parts. The triangular gable ends are the caller's (T.gableEnd).
function T.gable(parent, name, F, u, d, y0, lat, dep, rise, color, trim, over)
	over = over or 2
	local half = dep / 2 + over
	T.wedge(parent, name, F, u, d + half / 2, y0, lat + over * 2, half, rise, color) -- front slope
	T.wedge(parent, name, F, u, d - half / 2, y0, lat + over * 2, half, rise, color, true) -- back slope
	T.cylLat(parent, name .. "Ridge", F, u, d, y0 + rise, 2.2, lat + over * 2 + 1, trim)
	T.box(parent, name .. "Eave", F, u, d + half - .5, y0 - .6, lat + over * 2 + .4, 1.2, 1.2, trim, nil, false)
	T.box(parent, name .. "Eave", F, u, d - half + .5, y0 - .6, lat + over * 2 + .4, 1.2, 1.2, trim, nil, false)
	return y0 + rise
end

-- The triangle under a gable roof on one side wall (sign -1/+1 = left/right side): two wedges back to back. 2 parts.
function T.gableEnd(parent, name, F, u, d, y0, dep, rise, color)
	local half = dep / 2
	local p1 = A.part(parent, name, Vector3.new(.8, rise, half), F.cf(u, y0 + rise / 2, d + half / 2), color, nil, false, "Wedge")
	local p2 = A.part(parent, name, Vector3.new(.8, rise, half), F.cf(u, y0 + rise / 2, d - half / 2, CFrame.Angles(0, math.pi, 0)), color, nil, false, "Wedge")
	T.smooth(p1); T.smooth(p2)
end

-- A dome: a ball whose lower half sits inside the roof slab at y, plus a rim ring and a top knob. 3 parts.
function T.dome(parent, name, F, u, d, y, diameter, color, rim, knob)
	T.ball(parent, name, F, u, d, y, diameter, color)
	T.cyl(parent, name .. "Rim", F, u, d, y - .6, diameter + 1.6, 1.4, rim or T.white, nil, false)
	if knob then T.ball(parent, name .. "Knob", F, u, d, y + diameter / 2 + .8, 2.6, knob, nil, false) end
end

-- A window on a wall face. `cf` is a CFrame on the wall surface whose LookVector points outward.
-- Frame (border), glass in front of it, a mullion and a sill: 4 parts.
function T.window(parent, name, cf, w, h, frameColor, glassColor, glowing)
	T.part(parent, name .. "Frame", Vector3.new(w + 1.4, h + 1.4, .5), cf * CFrame.new(0, 0, -.25), frameColor or T.white, nil, false)
	local glass = T.part(parent, name .. "Glass", Vector3.new(w, h, .3), cf * CFrame.new(0, 0, -.55), glassColor or T.glass,
		if glowing then Enum.Material.Neon else Enum.Material.SmoothPlastic, false)
	glass.Reflectance = if glowing then 0 else .15
	T.part(parent, name .. "Mullion", Vector3.new(.35, h, .2), cf * CFrame.new(0, 0, -.8), frameColor or T.white, nil, false)
	T.part(parent, name .. "Sill", Vector3.new(w + 2.2, .6, 1.2), cf * CFrame.new(0, -h / 2 - .9, -.6), frameColor or T.white, nil, false)
end
-- the wall-surface CFrame for a frame's front (d), back (-d) or a side (u) face, at height y
function T.onFront(F, u, d, y) return F.cf(u, y, d) end
function T.onBack(F, u, d, y) local p = F.world(u, y, d) + A.offset return CFrame.lookAt(p, p - F.forward) end
function T.onSide(F, u, d, y, sign) local p = F.world(u, y, d) + A.offset return CFrame.lookAt(p, p + F.right * sign) end

-- A doorway on a wall face (`cf` as for windows): dark inset, a coloured frame (lintel and posts) and a step. 5 parts.
function T.door(parent, name, cf, w, h, frameColor, inset)
	T.part(parent, name .. "Inset", Vector3.new(w, h, .3), cf * CFrame.new(0, 0, -.1), inset or T.ink, nil, false)
	T.part(parent, name .. "Jamb", Vector3.new(w + 2, 1.4, .8), cf * CFrame.new(0, h / 2 + .7, -.3), frameColor, nil, false)
	for _, side in { -1, 1 } do
		T.part(parent, name .. "Post", Vector3.new(1, h, .8), cf * CFrame.new(side * (w / 2 + .5), 0, -.3), frameColor, nil, false)
	end
	T.part(parent, name .. "Step", Vector3.new(w + 3, .8, 2.4), cf * CFrame.new(0, -h / 2 + .4, -1.2), T.ramp.stone[1], nil, true)
end

-- Steps rising toward the frame's back, starting at depth d (front edge), each `rise` high and `run` deep.
function T.steps(parent, name, F, u, d, y0, lat, count, rise, run, color)
	for i = 0, count - 1 do
		T.box(parent, name, F, u, d - run / 2 - i * run, y0, lat, run, rise * (i + 1), color)
	end
end

-- Props (world-axis, x/z centre on the ground at y0). Small part counts each.
function T.lamp(parent, name, x, z, y0, color)
	local g = A.group(parent, name)
	T.part(g, "Base", Vector3.new(1.2, 3, 3), A.cf(x, y0 + .6, z) * CFrame.Angles(0, 0, math.pi / 2), T.ink, nil, true, Enum.PartType.Cylinder)
	T.part(g, "Pole", Vector3.new(11, 1, 1), A.cf(x, y0 + 6.5, z) * CFrame.Angles(0, 0, math.pi / 2), T.ink, nil, true, Enum.PartType.Cylinder)
	T.part(g, "Lantern", Vector3.new(3, 3, 3), A.cf(x, y0 + 12.6, z), color or T.glow, Enum.Material.Neon, false, Enum.PartType.Ball)
	return g
end
function T.crate(parent, name, x, z, y0, size, yaw, color)
	size = size or 4.5
	local cf = A.cf(x, y0 + size / 2, z) * CFrame.Angles(0, yaw or 0, 0)
	T.part(parent, name, Vector3.new(size, size, size), cf, color or T.ramp.wood[1])
	T.part(parent, name .. "Band", Vector3.new(size + .3, .8, size + .3), cf, T.ramp.wood[3], nil, false)
	T.part(parent, name .. "Band", Vector3.new(.8, size + .3, size + .3), cf, T.ramp.wood[3], nil, false)
end
function T.barrel(parent, name, x, z, y0, color, h)
	h = h or 5
	T.part(parent, name, Vector3.new(h, 4.2, 4.2), A.cf(x, y0 + h / 2, z) * CFrame.Angles(0, 0, math.pi / 2), color or T.ramp.red[2], nil, true, Enum.PartType.Cylinder)
	T.part(parent, name .. "Lid", Vector3.new(.5, 4.5, 4.5), A.cf(x, y0 + h, z) * CFrame.Angles(0, 0, math.pi / 2), T.ink, nil, false, Enum.PartType.Cylinder)
	T.part(parent, name .. "Band", Vector3.new(.7, 4.5, 4.5), A.cf(x, y0 + h * .3, z) * CFrame.Angles(0, 0, math.pi / 2), T.ink, nil, false, Enum.PartType.Cylinder)
end
function T.banner(parent, name, x, z, y0, color, facing, h)
	h = h or 16
	local g = A.group(parent, name)
	local p = Vector3.new(x, 0, z)
	T.part(g, "Pole", Vector3.new(h, .9, .9), A.cf(x, y0 + h / 2, z) * CFrame.Angles(0, 0, math.pi / 2), T.ink, nil, true, Enum.PartType.Cylinder)
	T.part(g, "Tip", Vector3.new(1.8, 1.8, 1.8), A.cf(x, y0 + h + .6, z), T.ramp.gold[2], nil, false, Enum.PartType.Ball)
	local dir = (facing or Vector3.xAxis).Unit
	local at = A.cf(x, y0 + h - 4.4, z).Position + dir * 2.6
	T.part(g, "Cloth", Vector3.new(4.4, 7, .3), CFrame.lookAt(at, at + dir:Cross(Vector3.yAxis)), color, nil, false)
	return g, p
end
function T.planter(parent, name, x, z, y0, w, d, flowerColors)
	w, d = w or 10, d or 4.5
	T.part(parent, name, Vector3.new(w, 2.4, d), A.cf(x, y0 + 1.2, z), T.ramp.cream[2])
	T.part(parent, name .. "Lip", Vector3.new(w + .8, .6, d + .8), A.cf(x, y0 + 2.5, z), T.white, nil, false)
	local colors = flowerColors or { T.ramp.pink[2], T.ramp.gold[2], T.ramp.red[2], T.white }
	local n = math.max(2, math.floor(w / 3))
	for k = 0, n - 1 do
		T.part(parent, name .. "Flower", Vector3.new(2.2, 2.2, 2.2), A.cf(x - w / 2 + 1.5 + k * (w - 3) / math.max(1, n - 1), y0 + 3.3, z), colors[k % #colors + 1], nil, false, Enum.PartType.Ball)
	end
end
-- a round cartoon tree (trunk + three overlapping canopy balls) or a pine (trunk + three stacked cones as cylinders)
function T.tree(parent, name, x, z, y0, scale, kind, palette)
	scale = scale or 1
	local g = A.group(parent, name)
	local trunkH = 7 * scale
	T.part(g, "Trunk", Vector3.new(trunkH, 2.6 * scale, 2.6 * scale), A.cf(x, y0 + trunkH / 2, z) * CFrame.Angles(0, 0, math.pi / 2), T.ramp.wood[2], nil, true, Enum.PartType.Cylinder)
	local leaf = palette or T.ramp.green
	if kind == "pine" then
		for i = 0, 2 do
			local dia = (12 - i * 3.4) * scale
			T.part(g, "Needles", Vector3.new(4 * scale, dia, dia), A.cf(x, y0 + trunkH - 1 + i * 3.6 * scale, z) * CFrame.Angles(0, 0, math.pi / 2), leaf[3 - i % 2], nil, false, Enum.PartType.Cylinder)
		end
		T.part(g, "Top", Vector3.new(2.6 * scale, 2.6 * scale, 2.6 * scale), A.cf(x, y0 + trunkH + 10.4 * scale, z), leaf[1], nil, false, Enum.PartType.Ball)
	else
		T.part(g, "Canopy", Vector3.new(11, 11, 11) * scale, A.cf(x, y0 + trunkH + 3.5 * scale, z), leaf[2], nil, false, Enum.PartType.Ball)
		T.part(g, "Canopy", Vector3.new(7.5, 7.5, 7.5) * scale, A.cf(x + 3.4 * scale, y0 + trunkH + 1.6 * scale, z + 1.5 * scale), leaf[3], nil, false, Enum.PartType.Ball)
		T.part(g, "Canopy", Vector3.new(7, 7, 7) * scale, A.cf(x - 2.2 * scale, y0 + trunkH + 6.6 * scale, z - 1.4 * scale), leaf[1], nil, false, Enum.PartType.Ball)
	end
	return g
end

-- A stretched ellipsoid (a Part with a Sphere SpecialMesh fills its whole box): soft hills, mountains and clouds
-- for one part each. Non-colliding scenery only.
function T.blob(parent, name, size, cf, color)
	local p = T.part(parent, name, size, cf, color, nil, false)
	p.CanQuery, p.CastShadow = false, false
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

-- Open-air "pet sim" shop pieces, shared by the egg garden and the Gear Hall
T.sand = { Color3.fromRGB(240, 202, 134), Color3.fromRGB(206, 160, 98) } -- plaza top, rim
T.stroke = Color3.fromRGB(20, 20, 28)

-- Outlined cartoon lettering: a TextLabel with a thick round-joined dark stroke
function T.outlined(parent, text, font, color, size, position, thickness)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency, l.Text, l.Font, l.TextColor3, l.TextScaled = 1, text, font, color, true
	l.Size, l.Position = size, position or UDim2.new()
	local s = Instance.new("UIStroke")
	s.Color, s.Thickness, s.LineJoinMode = T.stroke, thickness, Enum.LineJoinMode.Round
	s.Parent = l
	l.Parent = parent
	return l
end

-- An invisible board in frame F whose front face carries a SurfaceGui (returned). `ppu` pixels per stud, 20 by
-- default; big lettering uses fewer, since TextScaled stops growing at 100 px.
function T.textBoard(parent, name, F, u, y, d, w, h, ppu)
	local p = T.part(parent, name, Vector3.new(w, h, .2), F.cf(u, y, d), T.white, nil, false)
	p.Transparency, p.CanQuery, p.CastShadow = 1, false, false
	local gui = Instance.new("SurfaceGui")
	gui.Name, gui.Face, gui.LightInfluence = "Lettering", Enum.NormalId.Front, 0
	gui.CanvasSize = Vector2.new(w, h) * (ppu or 20)
	gui.Parent = p
	return gui
end

-- A rounded pad in frame F (a long middle and two round ends), bottom at y0; returns the middle part
function T.roundPad(parent, name, F, lat, dep, y0, h, color)
	local ends = math.max(lat / 2 - dep / 2, 0)
	local mid = T.box(parent, name, F, 0, 0, y0, math.max(ends * 2, .2), dep, h, color)
	for _, side in { -1, 1 } do T.cyl(parent, name .. "End", F, side * ends, 0, y0, dep, h, color) end
	return mid
end

-- A rustic fence run from (u1, d1) to (u2, d2) standing on y0: chunky posts with two slightly crooked planks
function T.fence(parent, F, u1, d1, u2, d2, y0, seed)
	local a, b = F.world(u1, 0, d1), F.world(u2, 0, d2)
	for k, p in { a, b } do
		local tilt = CFrame.Angles(math.rad((seed + k) % 3 - 1) * 3, 0, math.rad(((seed * 7 + k) % 3) - 1) * 3)
		T.part(parent, "FencePost", Vector3.new(1.8, 6, 1.8), A.cf(p.X, y0 + 3, p.Z) * tilt, T.ramp.rust[2])
		T.part(parent, "PostCap", Vector3.new(2.2, .6, 2.2), A.cf(p.X, y0 + 6.2, p.Z) * tilt, T.ramp.wood[1], nil, false)
	end
	local mid, length = (a + b) / 2, (b - a).Magnitude
	local look = CFrame.lookAt(Vector3.new(mid.X, 0, mid.Z), Vector3.new(b.X, 0, b.Z)).Rotation
	for k, y in { 2.4, 4.4 } do
		local crooked = CFrame.Angles(0, 0, math.rad(if (seed + k) % 2 == 0 then 4 else -3))
		T.part(parent, "FencePlank", Vector3.new(.7, 1.3, length + 1.4), A.cf(mid.X, y0 + y, mid.Z) * look * crooked, if k == 1 then T.ramp.wood[1] else T.ramp.orange[1])
	end
end

-- A big cartoon flower: stem, a tilted petal disc and a gold middle
function T.flower(parent, F, u, d, y0, petals, seed)
	local p = F.world(u, 0, d)
	T.part(parent, "FlowerStem", Vector3.new(4, .5, .5), A.cf(p.X, y0 + 2, p.Z) * CFrame.Angles(0, 0, math.pi / 2), T.ramp.green[3], nil, false, Enum.PartType.Cylinder)
	T.part(parent, "FlowerPetals", Vector3.new(.6, 3.2, 3.2), A.cf(p.X, y0 + 4.2, p.Z) * CFrame.Angles(0, seed, math.rad(70)), petals, nil, false, Enum.PartType.Cylinder)
	T.part(parent, "FlowerMiddle", Vector3.new(1.2, 1.2, 1.2), A.cf(p.X, y0 + 4.4, p.Z), T.ramp.gold[2], nil, false, Enum.PartType.Ball)
end

-- Hero meshes: clone ServerStorage.MapArt[name] (a Model or MeshPart authored once in Studio) and pivot it to `cf`
-- scaled to `height`; otherwise run `fallback()` (parts). Keeps every stage rerunnable without the mesh store.
function T.mesh(parent, name, cf, height, fallback)
	local store = game:GetService("ServerStorage"):FindFirstChild("MapArt")
	local source = store and store:FindFirstChild(name)
	if not source then return fallback() end
	local copy = source:Clone()
	local model = copy
	if not copy:IsA("Model") then
		model = Instance.new("Model")
		model.Name = name
		copy.Parent = model
	end
	for _, v in model:GetDescendants() do
		if v:IsA("BasePart") then
			v.Anchored = true
			v.CanTouch = false
			v.CanQuery = v.CanCollide
			v:SetAttribute("MapRedesignOwned", true)
		elseif v:IsA("LuaSourceContainer") then
			v:Destroy()
		end
	end
	model:SetAttribute("MapRedesignOwned", true)
	model:SetAttribute("HeroMesh", name)
	local _, size = model:GetBoundingBox()
	if size.Y > 0 then model:ScaleTo(model:GetScale() * height / size.Y) end
	model:PivotTo(cf)
	-- rest it on the ground: shift so its lowest point is at cf's height
	local box, extents = model:GetBoundingBox()
	model:PivotTo(model:GetPivot() + Vector3.new(0, cf.Position.Y - (box.Position.Y - extents.Y / 2), 0))
	model.Parent = parent
	return model
end

-- Outer-scenery helpers (beyond the wall). Everything built with them is decoration: no collision, no queries, no shadow.
function T.deco(p)
	p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = false, false, false, false
	return p
end
function T.far(parent, name, size, cf, color, material, shape) return T.deco(T.part(parent, name, size, cf, color, material, false, shape)) end
-- stream the model in for every player however far they stand (far backdrops are otherwise outside the streaming radius)
function T.persistent(model)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	return model
end
-- `n` evenly spaced angles round a circle: returns { { angle, x, z } } at radius r, with a little jitter
function T.polar(n, r, jitter, random, phase)
	local list = {}
	for k = 0, n - 1 do
		local angle = (k + (phase or 0) + (random and random:NextNumber(-jitter or 0, jitter or 0) or 0)) * math.pi * 2 / n
		list[#list + 1] = { angle = angle, x = math.cos(angle) * r, z = math.sin(angle) * r }
	end
	return list
end
-- A round "lollipop" tree for far scenery: a trunk and two crown balls (3 parts), or `pine`: trunk and two needle tiers
function T.lollipop(parent, x, z, y0, scale, leaf, pine)
	scale = scale or 1
	local trunkH = 9 * scale
	T.far(parent, "Trunk", Vector3.new(trunkH, 2.4 * scale, 2.4 * scale), A.cf(x, y0 + trunkH / 2, z) * CFrame.Angles(0, 0, math.pi / 2), T.ramp.wood[3], nil, Enum.PartType.Cylinder)
	if pine then
		for i, tier in { { 18, 8 }, { 13, 7 }, { 8, 6 } } do
			T.far(parent, "Needles", Vector3.new(tier[2] * scale, tier[1] * scale, tier[1] * scale), A.cf(x, y0 + trunkH + (i - 1) * 6 * scale, z) * CFrame.Angles(0, 0, math.pi / 2), leaf[4 - i], nil, Enum.PartType.Cylinder)
		end
	else
		T.far(parent, "Crown", Vector3.new(15, 15, 15) * scale, A.cf(x, y0 + trunkH + 4 * scale, z), leaf[2], nil, Enum.PartType.Ball)
		T.far(parent, "Crown", Vector3.new(9, 9, 9) * scale, A.cf(x + 3.5 * scale, y0 + trunkH + 9 * scale, z + 1 * scale), leaf[1], nil, Enum.PartType.Ball)
	end
end
-- A rounded peak made of overlapping ellipsoids: the main body, two shoulders, a snow cap and two snow drips (6 parts).
-- `v` is the visible height above y0 (the base is hidden in the sea), `w` the width, `angle` turns it to face the centre.
function T.peak(parent, name, x, z, y0, w, v, angle, body, shade, snow)
	local base = A.cf(x, y0, z) * CFrame.Angles(0, angle, 0)
	T.blob(parent, name, Vector3.new(w, v * 2, w * .8), base, body)
	T.blob(parent, name .. "Shoulder", Vector3.new(w * .7, v * 1.2, w * .6), base * CFrame.new(-w * .36, 0, w * .05), shade)
	T.blob(parent, name .. "Shoulder", Vector3.new(w * .6, v * 1.0, w * .55), base * CFrame.new(w * .38, 0, -w * .04), shade)
	if snow then
		T.blob(parent, name .. "Snow", Vector3.new(w * .44, v * .56, w * .38), base * CFrame.new(0, v * .72, 0), snow)
		T.blob(parent, name .. "Drip", Vector3.new(w * .14, v * .34, w * .12), base * CFrame.new(-w * .12, v * .5, -w * .2), snow)
		T.blob(parent, name .. "Drip", Vector3.new(w * .12, v * .28, w * .1), base * CFrame.new(w * .13, v * .48, -w * .18), snow)
	end
end
-- A fluffy cloud: four overlapping white blobs
function T.cloud(parent, x, y, z, size, tint)
	local c = tint or T.white
	local layout = { { 0, 0, 0, 1, .5 }, { -.34, -.06, .06, .66, .42 }, { .36, -.04, -.05, .72, .44 }, { .05, .16, .02, .55, .42 } }
	for _, b in layout do
		T.blob(parent, "Cloud", Vector3.new(size * b[4], size * b[5], size * b[4] * .8), A.cf(x + b[1] * size, y + b[2] * size, z + b[3] * size), c)
	end
end
-- A round tower for the castle wall: plinth, body, three bands, ring of ball-topped crenels, four roof tiers, knob and
-- a swallowtail flag. Centre (x, z), diameter d, body from y0 to y1. About 34 parts.
function T.roundTower(parent, x, z, y0, y1, d, body, roof)
	local F = A.frame(x, z, "N")
	local function dec(p) p.CanQuery = false return p end
	dec(T.cyl(parent, "TowerPlinth", F, 0, 0, y0, d + 4, 6, T.ramp.navy[2], nil, false))
	dec(T.cyl(parent, "TowerBody", F, 0, 0, y0 + 6, d, y1 - y0 - 6, body[2], nil, false))
	for _, y in { y0 + 12, (y0 + y1) / 2 + 3, y1 - 6 } do
		dec(T.cyl(parent, "TowerBand", F, 0, 0, y, d + 1.4, 2.2, T.white, nil, false))
	end
	dec(T.cyl(parent, "TowerLip", F, 0, 0, y1 - 2, d + 5, 2.4, T.ramp.stone[1], nil, false))
	for k = 0, 7 do
		local a = k * math.pi / 4 + math.pi / 8
		local cx, cz = math.cos(a) * (d / 2 + .6), math.sin(a) * (d / 2 + .6)
		dec(T.cyl(parent, "Crenel", F, cx, cz, y1 + .4, 4.4, 3.4, T.ramp.stone[1], nil, false))
		T.far(parent, "CrenelTop", Vector3.new(4.4, 4.4, 4.4), F.cf(cx, y1 + 3.8, cz), T.ramp.stone[1], nil, Enum.PartType.Ball)
	end
	local tiers = { { d * .86, 7 }, { d * .66, 7 }, { d * .44, 7 }, { d * .22, 6 } }
	local y = y1 + .4
	for i, t in tiers do
		dec(T.cyl(parent, "TowerRoof", F, 0, 0, y, t[1], t[2], roof[(i % 2) + 1], nil, false))
		y += t[2] - 1
	end
	T.far(parent, "TowerKnob", Vector3.new(4.6, 4.6, 4.6), F.cf(0, y + 1.6, 0), T.ramp.gold[2], nil, Enum.PartType.Ball)
	T.far(parent, "TowerPole", Vector3.new(11, .8, .8), F.cf(0, y + 8, 0, CFrame.Angles(0, 0, math.pi / 2)), T.ink, nil, Enum.PartType.Cylinder)
	T.far(parent, "TowerFlag", Vector3.new(.3, 4.4, 8), F.cf(0, y + 11.4, 4.6), T.ramp.gold[2])
	T.far(parent, "TowerFlag", Vector3.new(.3, 2.2, 3.6), F.cf(0, y + 11.4, 10), T.ramp.gold[3])
end

return T
