-- Map v3 mesh dressing (visual swap, 2026-10-21). Run after Fields, Scenery, Rampart and Surroundings, before Dezfight:
--   L("../map-v3/MeshDress")
-- Swaps part-built pieces for the Blender meshes in ServerStorage.MapArt.Dress (tools/blender-assets/ImportDress.luau):
--   Debris rocks: each field rock becomes one of its field's three rock meshes, on the same spot and footprint. The new
--     Root MeshPart keeps the old rock's name, attributes and tags, so DebrisService's contract holds (Root collides and
--     takes hits, OreFleck children are tinted by tier).
--   Scenery lamps: pole + ball becomes the street lamp, Boundary lantern posts become the rampart lantern.
--   Surroundings trees: trunk + ball crowns become a broadleaf, trunk + needle cones a pine, palms a palm; each sized to
--     the height of the tree it replaces.
-- Reruns are no-ops for what is already swapped (nothing part-built is left to match).
local A = _G.MapRedesignArt
local map = if A and A.map then A.map else (workspace:FindFirstChild("Map_Redesign") or workspace:FindFirstChild("Map"))
assert(map, "no map")
local dress = game:GetService("ServerStorage"):WaitForChild("MapArt"):WaitForChild("Dress")
local CS = game:GetService("CollectionService")
local rng = Random.new(2110)
local Config = if A and A.config then A.config else require(game:GetService("ReplicatedStorage").Shared.Config:Clone() :: ModuleScript)
local FIELD_COLOR = {}
for _, f in Config.Debris.Fields do FIELD_COLOR[f.Id] = f.Color end

local FIELD_KIND = { RustWorks = "rust", FrostYard = "frost", VioletQuarry = "violet", SulfurRidge = "sulfur",
	EmberShelf = "ember", GlassScar = "glass", Starfall = "star", HaloLedge = "halo" }

-- a clone of a dress mesh scaled by `s`, its base at `at`, turned `yaw` radians; children move and scale with the Root
local function put(name: string, at: Vector3, yaw: number, s: number): MeshPart
	local template = assert(dress:FindFirstChild(name), "MapArt.Dress." .. name .. " is missing; run ImportDress") :: MeshPart
	local root = template:Clone()
	local base = template.CFrame
	local pose = CFrame.new(at + Vector3.new(0, (root:GetAttribute("Ground") :: number) * s, 0)) * CFrame.Angles(0, yaw, 0) * base.Rotation
	for _, p in root:GetDescendants() do
		if p:IsA("BasePart") then
			local rel = base:ToObjectSpace((template:FindFirstChild(p.Name, true) :: BasePart).CFrame)
			p.Size *= s
			p.CFrame = pose * (rel - rel.Position + rel.Position * s)
		end
	end
	root.Size *= s
	root.CFrame = pose
	root:SetAttribute("Ground", nil)
	root:SetAttribute("MapRedesignOwned", true)
	root.CanCollide = false -- decoration never collides (StaticQA); rocks turn it back on
	return root
end

-- the base (lowest point) and horizontal extent of a part and its part descendants
local function extent(parts: { BasePart }): (number, number, Vector3)
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, p in parts do
		local cf, size = p.CFrame, p.Size / 2
		for _, c in { Vector3.new(1, 1, 1), Vector3.new(-1, 1, 1), Vector3.new(1, -1, 1), Vector3.new(1, 1, -1), Vector3.new(-1, -1, 1), Vector3.new(-1, 1, -1), Vector3.new(1, -1, -1), Vector3.new(-1, -1, -1) } do
			local w = cf * (size * c)
			lo, hi = lo:Min(w), hi:Max(w)
		end
	end
	return lo.Y, hi.Y, (lo + hi) / 2
end

local counts = { rocks = 0, lamps = 0, lanterns = 0, trees = 0, pines = 0, palms = 0 }

-- rocks ------------------------------------------------------------------------------------------------------------------
for _, old in map.Debris:GetChildren() do
	local kind = FIELD_KIND[old:GetAttribute("Field") :: string]
	if not (old:IsA("Part") and kind) then continue end
	local footprint = math.max(old.Size.X, old.Size.Z)
	local variant = rng:NextInteger(0, 2)
	local name = ("rocks_%s_%d"):format(kind, variant)
	-- the meshes are ~4.5 studs of stone under their crystals; 1.35x stands them as tall as the old block rocks
	local s = 1.35 * math.clamp(footprint / 6, .85, 1.2)
	local rock = put(name, Vector3.new(old.Position.X, old.Position.Y - old.Size.Y / 2, old.Position.Z), rng:NextNumber(0, math.pi * 2), s)
	rock.Name = old.Name
	rock.CanCollide = true
	for _, fleck in rock:GetChildren() do
		if fleck.Name == "OreFleck" then (fleck :: BasePart).Color = FIELD_COLOR[old:GetAttribute("Field")] end -- the colour DebrisService falls back to
	end
	for k, v in old:GetAttributes() do rock:SetAttribute(k, v) end
	for _, tag in old:GetTags() do rock:AddTag(tag) end
	for _, c in old:GetChildren() do
		if not c:IsA("BasePart") then c.Parent = rock end -- lights, attachments
	end
	rock.Parent = old.Parent
	old:Destroy()
	counts.rocks += 1
end
task.wait()

-- street lamps -----------------------------------------------------------------------------------------------------------
-- The plan's lamps were scattered (rows thinned at random), so they are replaced by lamp rows that follow the roads: pairs
-- facing each other across every avenue, and a ring on the outer kerbs of the ring road and the Terrace Express. A spot is
-- kept only on flat grass (not paving, not a ramp) with nothing but small scenery in the way; that scenery is cleared.
local World = if A and A.geometry then A.geometry else require(game:GetService("ReplicatedStorage").Shared.WorldGeometry:Clone() :: ModuleScript).Settings
local LAMP_EVERY, KERB = 34, 3
local ground = RaycastParams.new()
ground.FilterType = Enum.RaycastFilterType.Include
ground.FilterDescendantsInstances = { map.Ground, map.Roads }
local SMALL = { bush = true, flowers = true, boulder = true, ["snow mound"] = true, scrap = true, ember = true, ice = true, crystal = true }
for _, zone in map.Scenery:GetChildren() do
	for _, m in zone:GetChildren() do
		if m.Name == "lamp" then m:Destroy() end
	end
end
local lamps = map.Scenery:FindFirstChild("StreetLamps") or Instance.new("Model")
lamps.Name, lamps.Parent = "StreetLamps", map.Scenery
lamps:ClearAllChildren()
local placed = {}
local function scenery(p: Instance): Instance?
	while p.Parent and p.Parent.Parent ~= map.Scenery do p = p.Parent end
	return if p.Parent and p.Parent.Parent == map.Scenery then p else nil
end
local function lampAt(x: number, z: number, yaw: number): boolean
	local hit = workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -400, 0), ground)
	if not (hit and hit.Normal.Y > .985 and hit.Instance:IsDescendantOf(map.Ground)) then return false end
	for _, q in placed do if (q - hit.Position).Magnitude < 12 then return false end end
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { map.Ground, map.Roads, lamps }
	local clear = {}
	for _, p in workspace:GetPartBoundsInBox(CFrame.new(hit.Position + Vector3.new(0, 6, 0)), Vector3.new(4, 11, 4), overlap) do
		local piece = p:IsDescendantOf(map.Scenery) and scenery(p)
		if piece and SMALL[piece.Name] then clear[piece] = true
		elseif p.Transparency < 1 or p.CanCollide then return false end
	end
	for piece in clear do piece:Destroy() end
	local lamp = put("props_street_lamp", hit.Position, yaw, 1.1)
	lamp.Name = "Lamp"
	lamp.Parent = lamps
	table.insert(placed, hit.Position)
	counts.lamps += 1
	return true
end
local half = World.Avenues.width / 2 + KERB
for _, angle in World.Avenues.angles do
	local t = math.rad(angle)
	local along, across = Vector3.new(math.cos(t), 0, math.sin(t)), Vector3.new(-math.sin(t), 0, math.cos(t))
	local r0 = (World.Avenues.starts[angle] or World.Avenues.from) + 16
	local r1 = World.Avenues.stops[angle] or 560
	for r = r0, r1, LAMP_EVERY do
		for _, side in { -1, 1 } do
			local p = along * r + across * side * half
			lampAt(p.X, p.Z, t + (if side > 0 then 0 else math.pi))
		end
	end
end
local function ringLamps(radius: number, step: number)
	for deg = step / 2, 360, step do
		local t = math.rad(deg)
		lampAt(math.cos(t) * radius, math.sin(t) * radius, t)
	end
end
ringLamps(World.LoopRadius + 9 + KERB, 15)
ringLamps(World.ExpressRadius + World.ExpressWidth / 2 + KERB, 10)
-- scenery that ended up standing on paving (or hanging over it) goes
counts.offRoad = 0
for _, zone in map.Scenery:GetChildren() do
	if zone == lamps then continue end
	for _, piece in zone:GetChildren() do
		if not piece:IsA("PVInstance") then continue end
		local at = piece:GetPivot().Position
		local hit = workspace:Raycast(Vector3.new(at.X, 200, at.Z), Vector3.new(0, -400, 0), ground)
		if hit and hit.Instance:IsDescendantOf(map.Roads) then
			piece:Destroy()
			counts.offRoad += 1
		end
	end
end
task.wait()

-- lamps ------------------------------------------------------------------------------------------------------------------
for _, pole in map.Scenery:GetDescendants() do
	if pole.Name ~= "LampPole" or not pole:IsA("BasePart") then continue end
	local model = pole.Parent :: Instance
	local ball = model:FindFirstChild("Lantern") :: BasePart?
	local bottom, top = extent({ pole, ball :: BasePart })
	local lamp = put("props_street_lamp", Vector3.new(pole.Position.X, bottom, pole.Position.Z), rng:NextInteger(0, 3) * math.pi / 2, (top - bottom) / 10)
	lamp.Name = "Lamp"
	if ball then
		for _, c in ball:GetChildren() do c.Parent = lamp:FindFirstChild("Glow") or lamp end
		ball:Destroy()
	end
	pole:Destroy()
	lamp.Parent = model
	counts.lamps += 1
end
local lanterns = {}
for _, p in map.Boundary:GetChildren() do if p.Name == "Lantern" and p:IsA("BasePart") then table.insert(lanterns, p) end end
for _, post in map.Boundary:GetChildren() do
	if post.Name ~= "LanternPost" or not post:IsA("BasePart") then continue end
	local ball
	for _, l in lanterns do
		if l.Parent and Vector2.new(l.Position.X - post.Position.X, l.Position.Z - post.Position.Z).Magnitude < 2 then ball = l end
	end
	local bottom, top = extent({ post, ball })
	local d = Vector3.new(post.Position.X, 0, post.Position.Z)
	local yaw = math.atan2(d.X, d.Z) -- a face toward the map's centre
	local lantern = put("props_wall_lantern", Vector3.new(post.Position.X, bottom, post.Position.Z), yaw, (top - bottom) / 6.3)
	lantern.Name = "Lantern"
	if ball then
		for _, c in ball:GetChildren() do c.Parent = lantern:FindFirstChild("Glow") or lantern end
		ball:Destroy()
	end
	post:Destroy()
	lantern.Parent = map.Boundary
	counts.lanterns += 1
end
task.wait()

-- outer trees ------------------------------------------------------------------------------------------------------------
local surroundings = map:FindFirstChild("Surroundings")
if surroundings then
	local leaves = {}
	for _, p in surroundings:GetChildren() do
		if p:IsA("BasePart") and (p.Name == "Crown" or p.Name == "Needles" or p.Name == "PalmCrown") then table.insert(leaves, p) end
	end
	local trunks = {}
	for _, trunk in surroundings:GetChildren() do
		if trunk:IsA("BasePart") and (trunk.Name == "Trunk" or trunk.Name == "PalmTrunk") then
			table.insert(trunks, { trunk = trunk, own = { trunk }, palm = trunk.Name == "PalmTrunk", pine = false })
		end
	end
	-- each crown belongs to the nearest trunk below it
	for _, leaf in leaves do
		local best, bestD = nil, math.huge
		for _, t in trunks do
			local d = Vector2.new(leaf.Position.X - t.trunk.Position.X, leaf.Position.Z - t.trunk.Position.Z).Magnitude
			if d < bestD and leaf.Position.Y > t.trunk.Position.Y then best, bestD = t, d end
		end
		if best and bestD < 14 then
			table.insert(best.own, leaf)
			best.pine = best.pine or leaf.Name == "Needles"
		end
	end
	local trees = trunks
	for i, t in trees do
		local bottom, top = extent(t.own)
		local base = Vector3.new(t.trunk.Position.X, bottom, t.trunk.Position.Z)
		local name, height
		if t.palm then
			name, height = ("trees_palm_%d"):format(i % 2), 21.3
			counts.palms += 1
		elseif t.pine then
			name, height = ("trees_pine_%d"):format(i % 2), 23.7
			counts.pines += 1
		else
			name = ("trees_round_%d"):format(i % 3)
			height = ({ 24.4, 27.1, 28.8 })[i % 3 + 1]
			counts.trees += 1
		end
		local tree = put(name, base, rng:NextNumber(0, math.pi * 2), (top - bottom) / height)
		tree.Name = "Tree"
		tree.Parent = surroundings
		for _, p in t.own do p:Destroy() end
		if i % 20 == 0 then task.wait() end
	end
end

return { stage = "MeshDress", counts = counts }
