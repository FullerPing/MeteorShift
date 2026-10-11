-- Common + Brick + Toon first; after Scenery. The Commissary: a little outpost of the Foundry at the north end of the
-- ring (the old Meteor Watch site), facing the crater. Ore can be deposited and bars claimed here as at the Foundry:
-- WorldMap.commissaryPoint finds TownSquare.Commissary.UsePoint, the server hangs the same "Use refinery" prompt on it
-- and WorldMap.canUseRefinery accepts either point. Owns TownSquare.Commissary; on its first run it also removes the
-- old observatory from Scenery.MeteorWatch (the statue and the podium beside it stay).
local A = assert(_G.MapRedesignArt)
local T = assert(A.toon, "Run Toon first")
local R = T.ramp
local zone = A.zone("Commissary")
local town = A.ensure(A.map, "TownSquare")
local g = A.group(town, "Commissary")
local F = A.frameFor(zone, "S")

-- the observatory that stood here (Scenery still owns the statue and podium either side of it)
local removed = 0
local watch = A.map:FindFirstChild("Scenery") and A.map.Scenery:FindFirstChild("MeteorWatch")
if watch then
	for _, p in watch:GetDescendants() do
		if p:IsA("BasePart") and math.abs(p.Position.X - zone.x) <= zone.width / 2 + 2 and math.abs(p.Position.Z - zone.z) <= zone.depth / 2 + 2 then
			p:Destroy()
			removed += 1
		end
	end
end

local function box(name, u, d, y0, lat, dep, h, c, material, collide) return T.box(g, name, F, u, d, y0, lat, dep, h, c, material, collide) end

-- the yard: a stone pad with a cream kerb
box("Pad", 0, 0, 0, zone.width - 2, zone.depth - 2, .6, R.stone[1])
box("Kerb", 0, 0, 0, zone.width, zone.depth, .4, R.cream[2], nil, false)

-- the workshop: an orange brick body on a dark skirt under a navy gable roof
local bodyD, bodyDep, bodyLat, wallH = -3, 14, 20, 10
local body = box("Body", 0, bodyD, .6, bodyLat, bodyDep, wallH, R.orange[2])
box("Skirt", 0, bodyD, .6, bodyLat + .6, bodyDep + .6, 1.4, R.rust[3], nil, false)
box("Band", 0, bodyD, .6 + wallH - 1, bodyLat + .6, bodyDep + .6, 1, R.cream[1], nil, false)
local roofY = .6 + wallH
T.gable(g, "Roof", F, 0, bodyD, roofY, bodyLat, bodyDep, 5, R.navy[2], T.white, 1.5)
for _, side in { -1, 1 } do T.gableEnd(g, "RoofEnd", F, side * (bodyLat / 2 - .4), bodyD, roofY, bodyDep, 5, R.orange[1]) end

-- the furnace: a stone arch with a glowing mouth on the left of the front, and a tall chimney with a glowing top
local front = bodyD + bodyDep / 2
box("FurnaceArch", -5.5, front + .3, 1.6, 6.4, .6, 5.4, R.stone[3])
local glow = box("FurnaceGlow", -5.5, front + .55, 2.1, 4.4, .4, 3.6, Color3.fromRGB(255, 104, 30), Enum.Material.Neon, false)
local light = Instance.new("PointLight")
light.Color, light.Brightness, light.Range, light.Shadows = Color3.fromRGB(255, 160, 70), 1.2, 14, false
light.Parent = glow
T.cyl(g, "Chimney", F, 6, bodyD - 3.5, roofY, 4, 11, R.stone[2])
T.cyl(g, "ChimneyCap", F, 6, bodyD - 3.5, roofY + 11, 5, 1, T.ink, nil, false)
local top = T.cyl(g, "ChimneyGlow", F, 6, bodyD - 3.5, roofY + 12, 3.2, .3, Color3.fromRGB(255, 104, 30), Enum.Material.Neon, false)
local smoke = Instance.new("ParticleEmitter")
smoke.Name = "Smoke"
smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
smoke.Color = ColorSequence.new(Color3.fromRGB(220, 214, 206))
smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 6) })
smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, .5), NumberSequenceKeypoint.new(1, 1) })
smoke.Rate, smoke.Lifetime, smoke.Speed = 3, NumberRange.new(2, 4), NumberRange.new(3, 6)
smoke.EmissionDirection = Enum.NormalId.Top
smoke.Parent = top

-- the counter on the right of the front: a dark hatch, a wooden counter with a cream top, a striped awning and a
-- little stack of gold bars on it
box("Hatch", 5, front + .25, 3.4, 7, .5, 3.8, T.ink, nil, false)
box("CounterBase", 5, front + 1, .6, 7.6, 2, 2.8, R.wood[2])
box("CounterTop", 5, front + 1.2, 3.4, 8.4, 2.8, .7, R.cream[1], nil, false)
for k, at in { { 3.6, 0 }, { 5, 0 }, { 4.3, .7 } } do
	box("GoldBar" .. k, at[1], front + 1.4, 4.1 + at[2], 1.2, 2, .7, R.gold[2], nil, false)
end
A.awning(g, "Awning", F, 5, front + 2.2, 7.4, 9, 3.4, R.orange[1], T.white, 5)
local sign = A.signOn(g, "CommissarySign", "COMMISSARY", F, 0, roofY + 1.6, front + 2, 18, 2.8, T.ink, .5) -- standing on the eave
T.smooth(sign)

-- props: an ore cart by the furnace, crates and a barrel on the right
box("OreCart", -10, front + 5, .6, 4.4, 5.6, 3, R.stone[3])
box("OreCartRim", -10, front + 5, 3.6, 4.8, 6, .5, R.orange[2], nil, false)
for k = 0, 2 do T.ball(g, "CartOre", F, -10 + (k - 1) * 1.2, front + 4.4 + (k % 2) * 1.4, 4.2, 2.2, R.orange[1], nil, false) end
local c1 = F.world(10.5, 0, front + 5)
T.crate(g, "Crate", c1.X, c1.Z, .6, 4, .3)
local c2 = F.world(11, 0, front + 1)
T.barrel(g, "Barrel", c2.X, c2.Z, .6, R.rust[2], 4.6)

-- where the menu works: in front of the counter (invisible, walk-through, like the Foundry's)
local point = T.part(g, "UsePoint", Vector3.new(6, 1, 6), F.cf(5, 3, front + 6), R.orange[1], nil, false)
point.Transparency, point.CanQuery, point.CastShadow = 1, false, false

for _, p in g:GetDescendants() do if p:IsA("BasePart") then p.TopSurface = Enum.SurfaceType.Smooth end end
g.PrimaryPart = body
A.within(g, zone, 0)
assert(A.innerCount(A.map) <= 2700, "Map budget")
A.map:SetAttribute("CommissaryPass", 1)
return { stage = "Commissary", parts = A.count(g), removedObservatory = removed, innerParts = A.innerCount(A.map) }
