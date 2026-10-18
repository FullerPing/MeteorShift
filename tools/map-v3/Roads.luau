-- Map v3 roads (Caldera Terraces). Load Common, Brick and Toon first; run after Ground (the avenue ramps are Ground's).
-- Owns Map_Redesign.Roads:
--   Ring: the archived v2 ring road, crater approaches and south plaza, cloned (same radius, same spawn plaza).
--   Express: the Terrace Express ring on T1 (ExpressRadius, ExpressWidth).
--   Avenue_<angle>: pale paving with navy edges and a gold FastStrip on every flat run, and the strip up each ramp.
--   Slide_<angle>: a chute from the tier edge (the Crown for the north one) to the ring road's outer edge. Its deck is
--     a conveyor (an anchored part's AssemblyLinearVelocity carries whoever stands on it) with friction 0. A walker on
--     the tier below needs about 8 studs under it, so the T2 slides start on a tower 16 above T2, reached by a 15
--     degree ramp along the edge; the Crown is high enough already.
local A = assert(_G.MapRedesignArt, "Run Common first")
local T = assert(A.toon, "Run Toon first")
local G = A.geometry
local R = T.ramp
local HALF = G.BoundaryHalf
local Y1, Y2, YC = G.Tiers[2].y, G.Tiers[3].y, G.Crown.y
local EDGE_T1, EDGE_T2, RUN = 260, 370, 60 -- must match Ground
local PAVE, NAVY, GOLD = Color3.fromRGB(255, 241, 201), R.navy[2], Color3.fromRGB(255, 201, 60)
local SLIDE_BLUE = Color3.fromRGB(127, 216, 255)
local SLIDE_SPEED = 40

local roads = A.group(A.map, "Roads")
local count = 0
local function breathe() count += 1; if count % 80 == 0 then task.wait() end end

-- the ring road, its crater approaches and the south plaza, as they were
local ring = A.group(roads, "Ring")
for _, part in game:GetService("ServerStorage").SwapRollback.Map_v8.Roads:GetChildren() do
	if part.Name:find("^Loop") or part.Name:find("^CraterApproach") or part.Name == "SouthPlaza" or part.Name == "PlazaKerb" then
		local copy = part:Clone()
		copy:SetAttribute("MapRedesignOwned", true)
		copy.Parent = ring
	end
end

-- the Terrace Express: segments cut to meet on the outer edge
local express = A.group(roads, "Express")
local SEGMENTS = 72
local loopColor = ring:FindFirstChild("Loop1").Color
for k = 0, SEGMENTS - 1 do
	local t = (k + .5) / SEGMENTS * math.pi * 2
	local p = Vector3.new(math.cos(t), 0, math.sin(t)) * G.ExpressRadius
	local chord = 2 * (G.ExpressRadius + G.ExpressWidth / 2) * math.tan(math.pi / SEGMENTS) + .1
	A.part(express, "Express", Vector3.new(chord, .4, G.ExpressWidth), CFrame.lookAt(Vector3.new(p.X, Y1 + .18, p.Z), Vector3.new(0, Y1 + .18, 0)), loopColor)
	breathe()
end

-- avenues: in each avenue's frame `a` runs outward from the crater along its centre line
local function along(angle: number, a: number, c: number, y: number): Vector3
	local n = Vector3.new(math.cos(math.rad(angle)), 0, math.sin(math.rad(angle)))
	return n * a + Vector3.new(-n.Z, 0, n.X) * c + Vector3.new(0, y, 0)
end
-- a flat strip from a0 to a1 at lateral offset c, `w` wide, top at y
local function strip(parent: Instance, name: string, angle: number, a0: number, a1: number, c: number, w: number, top: number, thick: number, color: Color3, collide: boolean?)
	local p0, p1 = along(angle, a0, c, top - thick / 2), along(angle, a1, c, top - thick / 2)
	local p = A.part(parent, name, Vector3.new(w, thick, a1 - a0), CFrame.lookAt((p0 + p1) / 2, p1), color, nil, collide)
	breathe()
	return p
end
-- a strip lying on a slope from (a0, y0) to (a1, y1)
local function sloped(parent: Instance, name: string, angle: number, a0: number, y0: number, a1: number, y1: number, c: number, w: number, thick: number, color: Color3, collide: boolean?)
	local p0, p1 = along(angle, a0, c, y0), along(angle, a1, c, y1)
	local up = (p1 - p0).Unit:Cross(along(angle, 0, 1, 0) - along(angle, 0, 0, 0)).Unit
	if up.Y < 0 then up = -up end
	local mid = (p0 + p1) / 2 - up * thick / 2
	local p = A.part(parent, name, Vector3.new(w, thick, (p1 - p0).Magnitude), CFrame.lookAt(mid, mid + (p1 - p0), up), color, nil, collide)
	breathe()
	return p
end

local W = G.Avenues.width
for _, angle in G.Avenues.angles do
	local avenue = A.group(roads, "Avenue_" .. angle)
	local c, s = math.cos(math.rad(angle)), math.sin(math.rad(angle))
	local wall = HALF / math.max(math.abs(c), math.abs(s)) - W / 2
	local runs = { { G.Avenues.starts[angle] or G.Avenues.from, EDGE_T1 - RUN, 0 } }
	if angle == 270 then
		table.insert(runs, { EDGE_T1 + 4, 302, Y1 }) -- ends at the Rebirth terrace's front
	else
		table.insert(runs, { EDGE_T1 + 4, EDGE_T2 - RUN, Y1 })
		table.insert(runs, { EDGE_T2 + 4, if angle == 90 then G.Crown.z0 - 8 else wall, Y2 })
	end
	for _, run in runs do
		local a0, a1, y = run[1], run[2], run[3]
		strip(avenue, "Paving", angle, a0, a1, 0, W, y + .43, .4, PAVE)
		for _, side in { -1, 1 } do strip(avenue, "Edge", angle, a0, a1, side * (W / 2 - .4), .8, y + .48, .1, NAVY, false) end
		strip(avenue, "FastStrip", angle, a0, a1, 0, 4, y + .5, .1, GOLD, false)
	end
	-- the strip continues up the ramps (Ground's wedges)
	sloped(avenue, "FastStrip", angle, EDGE_T1 - RUN, .05, EDGE_T1, Y1 + .05, 0, 4, .1, GOLD, false)
	if angle ~= 270 then sloped(avenue, "FastStrip", angle, EDGE_T2 - RUN, Y1 + .05, EDGE_T2, Y2 + .05, 0, 4, .1, GOLD, false) end
end

-- slides
local function groundAt(angle: number, a: number): number
	if angle == 90 and a >= G.Crown.z0 then return YC end
	return if a >= EDGE_T2 then Y2 elseif a >= EDGE_T1 then Y1 else 0
end
local friction = PhysicalProperties.new(.7, 0, .5, 100, 1)
for _, slide in G.Slides.list do
	local angle, side = slide.angle, slide.side
	local group = A.group(roads, "Slide_" .. angle)
	local cs = side * G.Slides.offset -- the slide's centre line, across its avenue
	local bottom = G.LoopRadius + G.PathWidth / 2
	local top, topY
	if angle == 90 then
		top, topY = G.Crown.z0, YC
	else
		-- the start tower on T2 just past the edge, and a ramp up to it along the edge, away from the avenue
		top, topY = EDGE_T2 + 2, Y2 + 16
		local towerA = top + 6
		local base = along(angle, towerA, cs, Y2)
		local face = CFrame.lookAt(base, base + along(angle, 1, 0, 0) - along(angle, 0, 0, 0))
		T.part(group, "Tower", Vector3.new(12, 16, 12), face * CFrame.new(0, 8, 0), R.cream[2])
		T.part(group, "TowerTrim", Vector3.new(12.6, 1, 12.6), face * CFrame.new(0, 15.5, 0), NAVY)
		for _, u in { -5.6, 5.6 } do -- corner posts and a gold-knobbed arch over the slide mouth
			local post = along(angle, top + .5, cs + u, topY)
			T.part(group, "ArchPost", Vector3.new(1, 7, 1), CFrame.new(post + Vector3.new(0, 3.5, 0)), R.red[2])
		end
		local mid = along(angle, top + .5, cs, topY + 7.5)
		T.part(group, "ArchBeam", Vector3.new(12.2, 1.2, 1.2), CFrame.lookAt(mid, mid + along(angle, 1, 0, 0) - along(angle, 0, 0, 0)), R.red[2])
		T.part(group, "ArchKnob", Vector3.new(2.2, 2.2, 2.2), CFrame.new(mid + Vector3.new(0, 1.6, 0)), GOLD, nil, false, Enum.PartType.Ball)
		-- the ramp: 60 long, 16 up, high end against the tower
		local rampMid = along(angle, towerA, cs + side * (6 + RUN / 2), Y2)
		local outward = (along(angle, 0, side, 0) - along(angle, 0, 0, 0)).Unit
		T.wedge(group, "TowerRamp", A.frame(rampMid.X, rampMid.Z, outward), 0, 0, Y2, 8, RUN, 16, PAVE, nil, true)
	end
	local p0, p1 = along(angle, top, cs, topY + .2), along(angle, bottom, cs, .2)
	local downhill = (p1 - p0).Unit
	local lateral = (along(angle, 0, 1, 0) - along(angle, 0, 0, 0)).Unit
	local up = downhill:Cross(lateral).Unit
	if up.Y < 0 then up = -up end
	local length = (p1 - p0).Magnitude
	local mid = (p0 + p1) / 2
	local deck = A.part(group, "Deck", Vector3.new(G.Slides.width, 1, length), CFrame.lookAt(mid - up * .5, mid - up * .5 + downhill, up), SLIDE_BLUE)
	deck.CustomPhysicalProperties = friction
	deck.AssemblyLinearVelocity = downhill * SLIDE_SPEED
	deck.TopSurface = Enum.SurfaceType.Smooth
	for _, u in { -1, 1 } do
		local rail = A.part(group, "Rail", Vector3.new(1, 2.4, length), CFrame.lookAt(mid + lateral * u * (G.Slides.width / 2 + .5) + up * .7, mid + lateral * u * (G.Slides.width / 2 + .5) + up * .7 + downhill, up), T.white)
		rail.TopSurface = Enum.SurfaceType.Smooth
	end
	-- stilts down to whatever ground is under the deck, clear of the cliff faces and the Express
	for a = bottom + 16, top - 8, 22 do
		local nearFace = math.abs(a - EDGE_T1) < 9 or math.abs(a - EDGE_T2) < 9 or math.abs(a - G.ExpressRadius) < G.ExpressWidth / 2 + 3
		local deckY = .2 + (topY + .2 - .2) * (a - bottom) / (top - bottom) - 1.2
		local g = groundAt(angle, a)
		if not nearFace and deckY - g > 2 then
			for _, u in { -1, 1 } do
				local foot = along(angle, a, cs + u * (G.Slides.width / 2 - .6), g)
				T.part(group, "Stilt", Vector3.new(1, deckY - g, 1), CFrame.new(foot + Vector3.new(0, (deckY - g) / 2, 0)), NAVY)
			end
		end
	end
end

return { stage = "Roads", parts = A.count(roads), express = A.count(express), ring = A.count(ring) }
