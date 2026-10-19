-- Map v3 scenery. Load Common, Brick and Toon first; run after Ground and Roads:
--   L("../map-v3/Scenery", L("../map-v3/PlanData"))
-- Places every PlanData.scenery row under Map_Redesign.Scenery.<band>_<wedge> (eight 45-degree wedges round the crater,
-- Atomic). Pieces stand on the ground found by a ray (so the 16-gon corner slivers are right), use the owner's MapArt
-- scenery meshes where they exist, and are all non-colliding, query-free and untouchable. Lights inside cloned meshes
-- are removed (the lamps glow with Neon instead). Rows are thinned to KEEP of the plan (the owner found the full set too
-- crowded); lamps and watch posts are landmarks and always kept.
local A = assert(_G.MapRedesignArt, "Run Common first")
local T = assert(A.toon, "Run Toon first")
local plan = assert(..., "Pass the plan: L(\"../map-v3/PlanData\")")
local R = T.ramp
local art = game:GetService("ServerStorage").MapArt
local rng = Random.new(1080)
local thin = Random.new(4510) -- its own stream, so the kept set doesn't depend on what the builders draw
local KEEP = 0.55
local ALWAYS = { lamp = true, ["watch post"] = true }

local scenery = A.group(A.map, "Scenery")
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { A.map:FindFirstChild("Ground"), A.map:FindFirstChild("Roads") }
local WEDGES = { "E", "NE", "N", "NW", "W", "SW", "S", "SE" }
local groups: { [string]: Model } = {}
local function groupFor(row): Model
	local wedge = WEDGES[math.floor(((math.deg(math.atan2(row.z, row.x)) + 22.5) % 360) / 45) + 1]
	local key = row.band .. "_" .. wedge
	if not groups[key] then
		local g = A.group(scenery, key) :: Model
		g.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		groups[key] = g
	end
	return groups[key]
end

-- a clone of a MapArt mesh model scaled to `height`, standing at p, turned at random
local function mesh(g: Instance, name: string, p: Vector3, height: number): Model?
	local source = art:FindFirstChild(name)
	if not source then return nil end
	return T.mesh(g, name, CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), height, function() return nil end)
end
local crystalSet = art:FindFirstChild("CRYSTAL.objAA951042-C459-4852-B06B-2C0AB4E18131 (1)")
local function crystal(g: Instance, p: Vector3, height: number)
	local pieces = crystalSet and crystalSet:GetChildren() or {}
	if #pieces == 0 then return end
	local piece = pieces[rng:NextInteger(1, #pieces)]:Clone() :: BasePart
	piece.Size *= height / piece.Size.Y
	piece.CFrame = CFrame.new(p + Vector3.new(0, piece.Size.Y / 2 - .3, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	piece.Anchored = true
	piece:SetAttribute("MapRedesignOwned", true)
	piece.Parent = g
end
local function part(g: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?)
	return T.part(g, name, size, cf, color, material, false, shape)
end
local function upright(p: Vector3, h: number): CFrame return CFrame.new(p + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2) end

local ASH = Color3.fromRGB(120, 112, 118)
local PETALS = { R.pink[1], R.gold[1], T.white, R.violet[1], R.red[1], R.orange[1] }
local B = {}
B.bush = function(g, p, w) mesh(g, "LowPolyBushes", p, w * .7 + 1) end
B.tree = function(g, p, w) mesh(g, "Tree", p, w * 1.9 + rng:NextNumber(-1, 3)) end
B.pine = function(g, p, w) mesh(g, "Pine tree", p, w * 2.6 + rng:NextNumber(-1, 3)) end
B["blossom tree"] = function(g, p, w) mesh(g, "Blosom tree (too big)", p, w * 1.4 + rng:NextNumber(-1, 2)) end
B["ash tree"] = function(g, p, w)
	local m = mesh(g, "Tree", p, w * 2 + rng:NextNumber(-1, 2))
	if not m then return end
	for _, v in m:GetDescendants() do -- leaves (the greenish parts) go ash grey, trunks a darker wood
		if v:IsA("BasePart") then
			local c = v.Color
			v.Color = if c.G > c.R and c.G > c.B then ASH:Lerp(Color3.new(c.G, c.G, c.G), .25) else Color3.fromRGB(70, 52, 44)
		end
	end
end
B.boulder = function(g, p, w) mesh(g, "Big Stone (Lowpoly)", p, w * .6 + rng:NextNumber(0, 1)) end
B.crystal = function(g, p, w) crystal(g, p, w * 1.6 + rng:NextNumber(0, 2)) end
B.lamp = function(g, p, w)
	part(g, "LampPole", Vector3.new(9, .8, .8), upright(p, 9), T.ink, nil, Enum.PartType.Cylinder)
	part(g, "Lantern", Vector3.new(2.4, 2.4, 2.4), CFrame.new(p + Vector3.new(0, 10, 0)), R.gold[1], Enum.Material.Neon, Enum.PartType.Ball)
end
B.flowers = function(g, p, w)
	local F = A.frame(p.X, p.Z, "N")
	T.flower(g, F, 0, 0, p.Y, PETALS[rng:NextInteger(1, #PETALS)], rng:NextNumber(0, 6))
end
B.ice = function(g, p, w)
	part(g, "Ice", Vector3.new(w * .8, w * 1.3, w * .7), CFrame.new(p + Vector3.new(0, w * .55, 0)) * CFrame.Angles(rng:NextNumber(-.2, .2), rng:NextNumber(0, 6), rng:NextNumber(-.2, .2)), Color3.fromRGB(190, 232, 255), Enum.Material.Glacier)
end
B["snow mound"] = function(g, p, w) T.blob(g, "SnowMound", Vector3.new(w * 1.4, w * .7, w * 1.2), CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), Color3.fromRGB(245, 250, 255)) end
B.ember = function(g, p, w)
	part(g, "EmberRock", Vector3.new(w, w * .7, w * .9), CFrame.new(p + Vector3.new(0, w * .2, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), Color3.fromRGB(70, 44, 40), nil, Enum.PartType.Ball)
	part(g, "Ember", Vector3.new(w * .4, w * .4, w * .4), CFrame.new(p + Vector3.new(w * .2, w * .45, 0)), R.orange[1], Enum.Material.Neon, Enum.PartType.Ball)
end
B.scrap = function(g, p, w)
	part(g, "ScrapPlate", Vector3.new(w * .7, .4, w * .5), CFrame.new(p + Vector3.new(0, .3, 0)) * CFrame.Angles(.15, rng:NextNumber(0, 6), 0), R.rust[2])
	part(g, "ScrapPipe", Vector3.new(w * .8, .9, .9), CFrame.new(p + Vector3.new(0, 1, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6), .3), R.rust[3], nil, Enum.PartType.Cylinder)
end
B.vent = function(g, p, w)
	part(g, "Vent", Vector3.new(1.6, w, w), upright(p, 1.6), Color3.fromRGB(80, 60, 56), nil, Enum.PartType.Cylinder)
	part(g, "VentGlow", Vector3.new(.3, w * .55, w * .55), upright(p + Vector3.new(0, 1.5, 0), .3), R.orange[1], Enum.Material.Neon, Enum.PartType.Cylinder)
end
B.mesa = function(g, p, w)
	for i, k in { 1, .78, .55 } do part(g, "Mesa", Vector3.new(3, w * k, w * k), upright(p + Vector3.new(0, (i - 1) * 3, 0), 3), if i % 2 == 0 then R.rust[1] else R.rust[2], nil, Enum.PartType.Cylinder) end
end
B["watch post"] = function(g, p, w)
	part(g, "PostBase", Vector3.new(10, w * .6, w * .6), upright(p, 10), R.cream[2], nil, Enum.PartType.Cylinder)
	part(g, "PostDeck", Vector3.new(1, w * .8, w * .8), upright(p + Vector3.new(0, 10, 0), 1), R.wood[2], nil, Enum.PartType.Cylinder)
	part(g, "PostRoof", Vector3.new(2.4, w * .7, w * .7), upright(p + Vector3.new(0, 15, 0), 2.4), R.red[2], nil, Enum.PartType.Cylinder)
	part(g, "PostKnob", Vector3.new(2, 2, 2), CFrame.new(p + Vector3.new(0, 18.4, 0)), R.gold[2], nil, Enum.PartType.Ball)
end

local placed, skipped, thinned, unknown = 0, 0, 0, {}
for i, row in plan.scenery do
	local key = row.tag
	local builder = B[key]
	if thin:NextNumber() >= KEEP and not ALWAYS[key] then
		thinned += 1
	elseif not builder then
		unknown[key] = (unknown[key] or 0) + 1
	else
		local hit = workspace:Raycast(Vector3.new(row.x, 200, row.z), Vector3.new(0, -300, 0), params)
		if hit then
			builder(groupFor(row), hit.Position, math.max(row.w, row.d))
			placed += 1
		else
			skipped += 1
		end
	end
	if i % 200 == 0 then task.wait() end
end

-- everything non-colliding, query-free and untouchable; no lights
local parts, meshes = 0, 0
for _, v in scenery:GetDescendants() do
	if v:IsA("BasePart") then
		v.CanCollide, v.CanQuery, v.CanTouch = false, false, false
		parts += 1
		if v:IsA("MeshPart") then meshes += 1 end
	elseif v:IsA("Light") or v:IsA("LuaSourceContainer") then
		v:Destroy()
	end
end
return { stage = "Scenery", placed = placed, thinned = thinned, skippedNoGround = skipped, unknown = unknown, groups = #scenery:GetChildren(), parts = parts, meshParts = meshes }
