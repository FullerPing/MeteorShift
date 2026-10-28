-- Common + Brick first. Roads (ring, crater approaches, the south plaza, the shop forecourts and every entrance spur),
-- the six spawn pads in front of the Refinery. Owns Roads and the six SpawnLocations (and removes the old SpawnPlaza).
local A = assert(_G.MapRedesignArt)
local C, G = A.colors, assert(A.geometry)
local crater = assert(A.crater)
assert(G.BoundaryHalf == 270, "Compact geometry must be synced")
local zone = A.zone
local roads = A.group(A.map, "Roads")
local function road(name, a, b, width, color)
	assert(width >= 14, "Road below fourteen studs")
	local p = A.slope(roads, name, Vector3.new(a[1], .38, a[2]), Vector3.new(b[1], .38, b[2]), width, .4, color or C.path)
	p:SetAttribute("ClearWidth", width)
	return p
end
local function slab(name, cx, cz, w, d, color)
	local p = A.part(roads, name, Vector3.new(w, .4, d), A.cf(cx, .18, cz), color or C.path)
	p:SetAttribute("ClearWidth", math.min(w, d))
	return p
end
local function kerb(name, cx, cz, w, d)
	A.part(roads, name, Vector3.new(w, .5, d), A.cf(cx, .5, cz), C.kerb, nil, false)
end

-- Ring road: LoopRadius is the segment centre/apothem, keeping the inner edge at the landing radius.
local loopRadius = assert(G.LoopRadius)
local vertexRadius = loopRadius / math.cos(math.pi / 64)
for k = 0, 63 do
	local a, b = k * math.pi * 2 / 64, (k + 1) * math.pi * 2 / 64
	road("Loop" .. k, { math.cos(a) * vertexRadius, math.sin(a) * vertexRadius }, { math.cos(b) * vertexRadius, math.sin(b) * vertexRadius }, G.PathWidth)
end
for k = 0, 3 do
	local angle = k * math.pi / 2
	road("CraterApproach" .. k, { math.cos(angle) * crater.OpeningRadius, math.sin(angle) * crater.OpeningRadius },
		{ math.cos(angle) * vertexRadius, math.sin(angle) * vertexRadius }, G.MainPathWidth)
end

-- South plaza: one wide cream apron from behind the Refinery north to the ring road; the Refinery stands at its south
-- end facing north and the spawn pads stand on it in front of the Refinery. White kerbs run along both edges.
local refinery = zone("Refinery")
local half = G.SouthPlazaHalf
local plazaSouth = refinery.z - refinery.depth / 2 - 6
local ringOuter = -(loopRadius + G.PathWidth / 2)
slab("SouthPlaza", 0, (plazaSouth + ringOuter + 6) / 2, half * 2, ringOuter + 6 - plazaSouth)
for _, side in { -1, 1 } do
	kerb("PlazaKerb", side * (half + .75), (plazaSouth + ringOuter) / 2, 1.5, ringOuter - plazaSouth)
end

-- The two angled shops (SW Gear Hall, SE Hatchery) each get a forecourt apron from their front to the ring road
for _, id in { "GearHall", "Hatchery" } do
	local z = zone(id)
	local F = A.frameFor(z)
	local width, from, to = 30, F.dep / 2, Vector3.new(z.x, 0, z.z).Magnitude - (loopRadius + G.PathWidth / 2) + .5 -- front face .. the ring's outer edge
	local depth = to - from
	local p = A.part(roads, id .. "Forecourt", Vector3.new(width, .4, depth), F.cf(0, .18, from + depth / 2), C.path)
	p:SetAttribute("ClearWidth", width)
end

-- Entrance spurs for the rest: a straight road from each entrance to the ring road
local function spur(name, id, toX, toZ)
	local z = zone(id)
	road(name, { z.entrance.X, z.entrance.Z }, { toX, toZ }, z.pathWidth)
end
for _, data in { { "RebirthEntrance", "Rebirth" }, { "TradingEntrance", "TradingPost" } } do
	local target = zone(data[2])
	local x = (if target.entrance.X < 0 then -1 else 1) * math.sqrt(vertexRadius ^ 2 - target.entrance.Z ^ 2)
	spur(data[1], data[2], x, target.entrance.Z)
end
-- each ore field: a straight road out along its quarter's centre line from the ring, through the gate, to the spot
-- ORE travel lands on, where the fan of rocks opens up
for _, data in { { "RustEntrance", "RustWorks" }, { "FrostEntrance", "FrostYard" }, { "VioletEntrance", "VioletQuarry" }, { "SulfurEntrance", "SulfurRidge" } } do
	local out = A.world.quarter(data[2]).out
	local from, to = out * (vertexRadius - 2), out * (G.Fan.Landing + 6)
	road(data[1], { from.X, from.Z }, { to.X, to.Z }, zone(data[2]).pathWidth)
end
-- the Commissary in the north: a short spur from its counter to the ring
spur("CommissaryEntrance", "Commissary", 0, loopRadius)

-- Spawn pads ------------------------------------------------------------------------------------------
-- six invisible, non-colliding spawn points on the south plaza in front of the Refinery (no spawn plaza or pads);
-- each faces north, so players spawn looking at the crater and the meteor
local town = A.ensure(A.map, "TownSquare")
local oldPlaza = town:FindFirstChild("SpawnPlaza")
if oldPlaza then assert(oldPlaza:GetAttribute("MapRedesignOwned"), "SpawnPlaza is not owned"); oldPlaza:Destroy() end
for index = 1, 6 do
	local name = if index == 1 then "Spawn" else "SpawnPad" .. index
	local old = town:FindFirstChild(name)
	if old then assert(old:GetAttribute("MapRedesignOwned")); old:Destroy() end
	local pad = Instance.new("SpawnLocation")
	pad.Name = name
	pad.Size = Vector3.new(6, 1, 6)
	local x = G.SpawnColumnsX[(index - 1) % 3 + 1]
	local z = G.SpawnRowsZ[math.floor((index - 1) / 3) + 1]
	pad.CFrame = A.cf(x, .5, z) * CFrame.Angles(0, math.pi, 0) -- the front (-Z) turned to face north (+Z)
	pad.Anchored, pad.Neutral, pad.Enabled = true, true, true
	pad.Duration = 0
	pad.Transparency = 1
	pad.CanCollide, pad.CanTouch, pad.CanQuery = false, false, false
	pad.CastShadow = false
	for _, child in pad:GetChildren() do child:Destroy() end -- no decal
	pad:SetAttribute("MapRedesignOwned", true)
	pad:SetAttribute("SpawnIndex", index)
	pad.Parent = town
end

local function insideBounds(parent)
	for _, part in parent:GetDescendants() do
		if part:IsA("BasePart") then
			for _, sx in { -1, 1 } do for _, sy in { -1, 1 } do for _, sz in { -1, 1 } do
				local c = part.CFrame * Vector3.new(sx * part.Size.X / 2, sy * part.Size.Y / 2, sz * part.Size.Z / 2) - A.offset
				assert(math.abs(c.X) <= G.BoundaryHalf + .001 and math.abs(c.Z) <= G.BoundaryHalf + .001, parent.Name .. " crossed the boundary")
			end end end
		end
	end
end
insideBounds(roads)
assert(A.innerCount(A.map) <= 2700, "Map budget")
A.map:SetAttribute("RoutesPass", 4)
return { stage = "Roads", parts = A.count(A.map), roads = A.count(roads), loopRadius = loopRadius, vertexRadius = vertexRadius }
