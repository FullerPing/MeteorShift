-- Run Common first (after Crater and Roads). Owns Map.CraterApron: detail on the lawn ring between the crater's gold lip
-- and the ring road, which was bare grass (owner, 15 Oct 2026: "looks really choppy"). Impact scorch splashes with a
-- glowing ember crack run out from the rim, and meteor fragments (a rock, a crystal, a pebble) lie between them.
-- Everything is flat or knee-high, kept out of the four cardinal ramp corridors, and neither collides nor takes queries,
-- so walking, mining reach, the landing FX probes and the ORE/ring routes are unchanged. Seeded, so re-runs match.
local A = assert(_G.MapRedesignArt)
local C, G = A.colors, assert(A.geometry)
local K = assert(A.crater, "Run current Common first")
local apron = A.group(A.map, "CraterApron")
local rimY, opening = K.RimY, K.OpeningRadius
local innerRadius = opening + 6 -- the gold lip's outer edge
local outerRadius = G.LoopRadius - G.PathWidth / 2 - 3 -- clear of the ring road
local corridorHalf = G.CraterRampWidth / 2 + 4 -- the approaches stay clean
local random = Random.new(20261015)

-- burnt grass: olive greens darker than the lawn, so the marks read as scorch and not as planks lying on it
local scorch = Color3.fromRGB(70, 104, 46)
local scorchMid = Color3.fromRGB(82, 128, 50)
local scorchEdge = Color3.fromRGB(92, 154, 56)
local crystals = { Color3.fromRGB(176, 96, 255), Color3.fromRGB(41, 201, 255), Color3.fromRGB(255, 140, 40) }
local rock = Color3.fromRGB(98, 92, 122)

-- True when a point (x, z) is clear of the cardinal corridors by `pad` studs
local function clear(x, z, pad)
	return math.abs(x) > corridorHalf + pad and math.abs(z) > corridorHalf + pad
end

local function flat(parent, name, size, x, y, z, angle, color, material)
	local p = A.part(parent, name, size, A.cf(x, y, z) * CFrame.Angles(0, -angle + math.pi / 2, 0), color, material, false)
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	return p
end

-- Scorch splashes: twelve, 15 degrees off every 30, so none points down a ramp corridor
local rays = A.group(apron, "ScorchRays", "Folder")
local placedRays = 0
for k = 0, 11 do
	local angle = math.rad(15 + k * 30 + random:NextNumber(-4, 4))
	local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local length = math.min(random:NextNumber(20, 32), outerRadius - innerRadius)
	-- a splash that tapers in three steps from the rim outward, the widest under the others
	local start = innerRadius - 2
	local a = dir * (start + length * .22)
	local b = dir * (start + length * .5)
	local c = dir * (start + length * .78)
	if clear(a.X, a.Z, 8) and clear(c.X, c.Z, 3) then
		placedRays += 1
		local ray = A.group(rays, "Ray" .. k)
		local width = random:NextNumber(11, 15)
		flat(ray, "Base", Vector3.new(width, .1, length * .46), a.X, rimY + .05, a.Z, angle, scorch)
		flat(ray, "Mid", Vector3.new(width * .6, .1, length * .4), b.X, rimY + .04, b.Z, angle, scorchMid)
		flat(ray, "Tip", Vector3.new(width * .3, .1, length * .38), c.X, rimY + .03, c.Z, angle, scorchEdge)
		local crackMid = dir * (start + length * .42)
		flat(ray, "EmberCrack", Vector3.new(.9, .14, length * .7), crackMid.X, rimY + .07, crackMid.Z,
			angle + random:NextNumber(-.06, .06), C.ember, Enum.Material.Neon)
	end
end

-- Meteor fragments: sixteen clusters in the gaps between the splashes
local fragments = A.group(apron, "Fragments", "Folder")
local placedFragments = 0
for k = 0, 15 do
	local angle = math.rad(k * 22.5 + 11.25 + random:NextNumber(-5, 5))
	local radius = random:NextNumber(innerRadius + 8, outerRadius - 5)
	local x, z = math.cos(angle) * radius, math.sin(angle) * radius
	if clear(x, z, 6) then
		placedFragments += 1
		local cluster = A.group(fragments, "Fragment" .. k)
		local size = random:NextNumber(4, 5.8)
		local spin = random:NextNumber(0, math.pi * 2)
		local stone = A.part(cluster, "Rock", Vector3.new(size, size * .7, size * .85),
			A.cf(x, rimY + size * .3, z) * CFrame.Angles(random:NextNumber(-.3, .3), spin, random:NextNumber(-.3, .3)), rock, nil, false)
		stone.TopSurface = Enum.SurfaceType.Smooth
		local glow = crystals[k % #crystals + 1]
		local crystal = A.part(cluster, "Crystal", Vector3.new(1.2, size * .9, 1.2),
			A.cf(x + math.cos(spin) * size * .45, rimY + size * .45, z + math.sin(spin) * size * .45)
				* CFrame.Angles(random:NextNumber(.25, .5), spin, random:NextNumber(-.3, .3)), glow, Enum.Material.Neon, false)
		crystal.CastShadow = false
		local pebble = A.part(cluster, "Pebble", Vector3.new(size * .45, size * .35, size * .4),
			A.cf(x - math.cos(spin) * size * .7, rimY + size * .15, z - math.sin(spin) * size * .7)
				* CFrame.Angles(0, spin + 1, .2), rock, nil, false)
		pebble.TopSurface = Enum.SurfaceType.Smooth
	end
end

local parts = A.count(apron)
assert(parts <= 110, "CraterApron over its 110-part budget: " .. parts)
for _, v in apron:GetDescendants() do
	if v:IsA("BasePart") then
		assert(not v.CanCollide and not v.CanQuery, v:GetFullName() .. " must not collide or take queries")
		local flatDistance = Vector3.new(v.Position.X, 0, v.Position.Z).Magnitude
		assert(flatDistance > opening and flatDistance < G.LoopRadius - G.PathWidth / 2, v:GetFullName() .. " outside the apron ring")
	end
end
return { stage = "CraterApron", parts = parts, rays = placedRays, fragments = placedFragments, inner = A.innerCount(A.map) }
