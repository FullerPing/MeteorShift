-- Map v2 ("Main Street", toy-brick playset). Edit-time art helpers, outside the Rojo tree: they create
-- anchored art and world SurfaceGuis, never saved scripts. Run through Studio MCP execute_luau with
-- datamodel_type "Edit", loading each file from the local tools server, e.g.
--   local H=game:GetService("HttpService")
--   local function L(n,...) return assert(loadstring(H:GetAsync("http://127.0.0.1:8123/map-v2/"..n..".luau",true),n))(...) end
--   L("Common"); L("Brick"); return L("Roads")
-- The world is authored in place as Workspace.Map_Redesign at offset zero (renamed Map at the swap), so
-- nothing is shifted and no WorldPivot can drift. Stages own only their named groups and are rerunnable.
assert(game:GetService("RunService"):IsStudio(), "Studio only")
assert(not game:GetService("RunService"):IsRunning(), "Stop Play before authoring")
local shared = game:GetService("ReplicatedStorage").Shared
local function fresh(module)
	local clone = module:Clone()
	local ok, value = pcall(require, clone)
	clone:Destroy()
	assert(ok, "Cannot load current " .. module.Name .. ": " .. tostring(value))
	return value
end
local worldGeometry = fresh(shared.WorldGeometry) -- also the quarter and fan helpers (quarterAt, inFan, ...)
local geometry = worldGeometry.Settings
local config = fresh(shared.Config)
local crater = config.LandingFX.Crater
assert(geometry.BoundaryHalf > crater.OpeningRadius and crater.FloorRadius < crater.OpeningRadius, "Invalid ground/crater dimensions")
assert(geometry.StageOffset == Vector3.zero, "v2 is authored in place; WorldGeometry.StageOffset must be zero")
local root = workspace:FindFirstChild("Map_Redesign")
if root then
	assert(root:IsA("Model") and root:GetAttribute("MapRedesignOwned"), "Unowned staged map")
else
	root = Instance.new("Model")
	root.Name = "Map_Redesign"
	root:SetAttribute("MapRedesignOwned", true)
	root.Parent = workspace
end
root:SetAttribute("LayoutVersion", 3)
root:SetAttribute("CraterTerrainOpening", crater.OpeningRadius)
root:SetAttribute("MiningClearRadius", config.Meteor.Knockback.Radius)
root.WorldPivot = CFrame.new(Vector3.zero)
local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
local A = {
	map = root, offset = geometry.StageOffset, geometry = geometry, world = worldGeometry, crater = crater, config = config,
	colors = {
		-- ground and paths
		grass = rgb(104, 214, 65), lawnA = rgb(104, 214, 65), lawnB = rgb(88, 196, 58),
		path = rgb(236, 220, 178), kerb = rgb(250, 248, 240), plaza = rgb(66, 198, 236),
		-- toy-brick primaries
		red = rgb(238, 66, 60), blue = rgb(38, 132, 255), yellow = rgb(255, 208, 40), green = rgb(70, 190, 70),
		orange = rgb(255, 140, 40), pink = rgb(255, 110, 200), violet = rgb(176, 96, 255), teal = rgb(40, 200, 190),
		-- neutrals
		navy = rgb(24, 37, 61), stone = rgb(72, 82, 100), steel = rgb(147, 169, 194), cream = rgb(255, 242, 207),
		white = rgb(250, 253, 255), dark = rgb(44, 54, 78),
		-- the old names, kept so the carried-over stages read the same
		cyan = rgb(41, 201, 255), ember = rgb(255, 130, 35), gold = rgb(255, 215, 54), frost = rgb(130, 232, 255),
		-- surroundings
		sea = rgb(52, 150, 232), seaDeep = rgb(34, 110, 200), sand = rgb(240, 214, 150),
		hillA = rgb(120, 190, 90), hillB = rgb(92, 160, 78), hillC = rgb(70, 130, 70), rockA = rgb(150, 160, 178), rockB = rgb(110, 122, 142),
	},
}
function A.cf(x, y, z) return CFrame.new(Vector3.new(x, y, z) + A.offset) end
function A.localPosition(part) return part.Position - A.offset end
function A.group(parent, name, class)
	assert(parent == root or parent:IsDescendantOf(root), "Art outside staged map")
	local old = parent:FindFirstChild(name)
	if old then
		assert(old:GetAttribute("MapRedesignOwned"), "Refusing to replace unowned " .. name)
		old:Destroy()
	end
	local group = Instance.new(class or "Model")
	group.Name = name
	group:SetAttribute("MapRedesignOwned", true)
	group.Parent = parent
	return group
end
function A.ensure(parent, name, class)
	local existing = parent:FindFirstChild(name)
	if existing then
		assert(existing:GetAttribute("MapRedesignOwned"), "Unowned container " .. name)
		return existing
	end
	return A.group(parent, name, class)
end
function A.part(parent, name, size, frame, color, material, collide, shape)
	assert(parent == root or parent:IsDescendantOf(root), "Part outside staged map")
	local p = Instance.new(if shape == "Wedge" then "WedgePart" else "Part")
	p.Name, p.Size, p.CFrame = name, size, frame
	if p:IsA("Part") and shape and shape ~= "Wedge" then p.Shape = shape end
	p.Color = color or A.colors.stone
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = collide ~= false
	p.CanTouch = false
	p.CanQuery = p.CanCollide
	p.CastShadow = true
	p.TopSurface = Enum.SurfaceType.Studs
	p.BottomSurface = Enum.SurfaceType.Smooth
	p:SetAttribute("MapRedesignOwned", true)
	p.Parent = parent
	return p
end
function A.cylinder(parent, name, diameter, height, frame, color, material, collide)
	return A.part(parent, name, Vector3.new(height, diameter, diameter),
		frame * CFrame.Angles(0, 0, math.pi / 2), color, material, collide, Enum.PartType.Cylinder)
end
function A.slope(parent, name, a, b, width, thickness, color)
	local mid = (a + b) / 2 + A.offset
	local cf = CFrame.lookAt(mid, b + A.offset)
	return A.part(parent, name, Vector3.new(width, thickness, (b - a).Magnitude + .25), cf * CFrame.new(0, -thickness / 2, 0), color)
end
function A.sign(parent, name, text, size, frame, color)
	local p = A.part(parent, name, size, frame, color or A.colors.navy, nil, false)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Lettering"
	gui.Face = Enum.NormalId.Front
	-- Match the physical face ratio and keep TextScaled below its font-size cap.
	gui.CanvasSize = Vector2.new(math.max(120, math.round(size.X * 10)), math.max(40, math.round(size.Y * 10)))
	gui.LightInfluence = 0
	gui.Parent = p
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(.94, .88)
	label.Position = UDim2.fromScale(.03, .06)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = A.colors.white
	label.TextStrokeColor3 = A.colors.navy
	label.TextStrokeTransparency = 0
	label.TextScaled = true
	label.Text = text
	label.Parent = gui
	return p, label
end
function A.count(parent)
	local n = 0
	for _, v in parent:GetDescendants() do if v:IsA("BasePart") then n += 1 end end
	return n
end
-- The outer scenery (everything beyond the playable area) has its own part budget; the inner map keeps its 2,700 (raised from 2,200 by the owner, 10 Oct 2026).
A.outerGroups = { Boundary = true, Surroundings = true, Backdrop = true }
function A.innerCount(parent)
	local n = 0
	for _, child in parent:GetChildren() do
		if not A.outerGroups[child.Name] then
			if child:IsA("BasePart") then n += 1 end
			n += A.count(child)
		end
	end
	return n
end
function A.zone(id)
	for _, value in geometry.Zones do if value.id == id then return value end end
	error("Unknown zone " .. id)
end
-- Every corner of every part under `parent` must lie inside the zone footprint grown by `margin`.
function A.within(parent, zone, margin)
	margin = margin or 0
	for _, part in parent:GetDescendants() do
		if part:IsA("BasePart") then
			for _, sx in { -1, 1 } do for _, sy in { -1, 1 } do for _, sz in { -1, 1 } do
				local c = part.CFrame * Vector3.new(sx * part.Size.X / 2, sy * part.Size.Y / 2, sz * part.Size.Z / 2) - A.offset
				assert(math.abs(c.X - zone.x) <= zone.width / 2 + margin + .001 and math.abs(c.Z - zone.z) <= zone.depth / 2 + margin + .001,
					part:GetFullName() .. " leaves the " .. zone.id .. " footprint")
			end end end
		end
	end
end
_G.MapRedesignArt = A
