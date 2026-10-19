-- Map v3 static QA. Load Common first; run last. Prints parts per top-level model, the total, MeshParts, lights and
-- emitters, and fails on:
--   any colliding part in Scenery, Surroundings or Backdrop, or in Boundary other than its walls, kill plane and the
--   Crown's parapet and fence;
--   a chute UsePoint or field Entrance that can't walk straight to its nearest avenue paving on the same tier: the ray
--   at chest height must hit nothing solid and the ground under the line must stay level (no cliff edge in between).
--   anything visible (not ground or road) in the 20 studs in front of a leaderboard's Screen, or inside the board;
--   a locked field's Wall cutting into a road, cliff, ramp, the rampart, a rock, chute, Crown piece or the town, or a
--   chute UsePoint or field Entrance standing inside a walled field (locked players couldn't reach it);
--   any visible pair of flush same-way faces (they flicker; run Dezfight last).
-- Budgets: total parts <= 20,000, lights <= 24, emitters <= 32.
local A = assert(_G.MapRedesignArt, "Run Common first")
local map = A.map
local failures, report = {}, {}
local function fail(text: string) table.insert(failures, text) end

-- counts
local total, meshes, lights, emitters = 0, 0, 0, 0
for _, child in map:GetChildren() do
	local n = if child:IsA("BasePart") then 1 else 0
	for _, v in child:GetDescendants() do
		if v:IsA("BasePart") then
			n += 1
			if v:IsA("MeshPart") then meshes += 1 end
		elseif v:IsA("Light") and v.Enabled then
			lights += 1
		elseif (v:IsA("ParticleEmitter") or v:IsA("Smoke") or v:IsA("Fire")) and v.Enabled then
			emitters += 1
		end
	end
	total += n
	table.insert(report, ("%s %d"):format(child.Name, n))
end
table.sort(report)
if total > 20000 then fail("total parts " .. total .. " > 20,000") end
if lights > 24 then fail("lights " .. lights .. " > 24") end
if emitters > 32 then fail("emitters " .. emitters .. " > 32") end

-- decoration never collides
local SOLID_BOUNDARY = { KillPlane = true, CrownParapet = true, CrownFence = true }
for _, name in { "Scenery", "Surroundings", "Backdrop", "Boundary" } do
	local group = map:FindFirstChild(name)
	for _, v in (group and group:GetDescendants() or {}) do
		if v:IsA("BasePart") and v.CanCollide then
			local allowed = name == "Boundary" and (v.Name:find("Wall$") or SOLID_BOUNDARY[v.Name])
			if not allowed then fail(("%s collides: %s"):format(name, v:GetFullName())) end
		end
	end
end

-- reachability: straight from each point to the nearest avenue paving centre line on its tier
local paving = {}
for _, avenue in map.Roads:GetChildren() do
	if avenue.Name:find("^Avenue_") then
		for _, p in avenue:GetChildren() do
			if p.Name == "Paving" then
				local half = p.Size.Z / 2
				for t = -half, half, 4 do table.insert(paving, (p.CFrame * CFrame.new(0, p.Size.Y / 2, t)).Position) end
			end
		end
	end
end
local ground = RaycastParams.new()
ground.FilterType = Enum.RaycastFilterType.Include
ground.FilterDescendantsInstances = { map.Ground, map.Roads }
local solid = RaycastParams.new()
solid.FilterType = Enum.RaycastFilterType.Exclude
solid.FilterDescendantsInstances = { map.Scenery, map.Backdrop, map.Surroundings }
local function floorAt(p: Vector3): number?
	local hit = workspace:Raycast(Vector3.new(p.X, 200, p.Z), Vector3.new(0, -300, 0), ground)
	return hit and hit.Position.Y
end
-- a walk along `points` at chest height: nothing solid in the way and the ground stays level under it
local function walk(points: { Vector3 }, y: number): string?
	for i = 1, #points - 1 do
		local from, to = Vector3.new(points[i].X, y + 3, points[i].Z), Vector3.new(points[i + 1].X, y + 3, points[i + 1].Z)
		local hit = workspace:Raycast(from, to - from, solid)
		if hit then return ("blocked by %s at %s"):format(hit.Instance:GetFullName(), tostring(hit.Position)) end
		local steps = math.max(1, math.floor((to - from).Magnitude / 4))
		for s = 1, steps do
			local p = from:Lerp(to, s / steps)
			local g = floorAt(p)
			if not g or math.abs(g - y) > 1.5 then return ("ground drops/rises at (%.0f, %.0f): %s vs %.1f"):format(p.X, p.Z, tostring(g), y) end
		end
	end
	return nil
end
local checked = 0
-- straight to the nearest avenue paving on the point's tier (on the Crown: to LiftTop, its only way in); failing that,
-- round the terrace at the point's own distance from the crater to the nearest avenue's centre line
local function reach(label: string, at: Vector3)
	local y = floorAt(at)
	if not y then fail(label .. ": no ground under it"); return end
	checked += 1
	local anchors = {}
	if math.abs(y - A.geometry.Crown.y) < 1.5 then
		anchors = { map.Crown.LiftTop.Position }
	else
		for _, q in paving do if math.abs(q.Y - y) < 1.5 then table.insert(anchors, q) end end
	end
	local best, bd = nil, math.huge
	for _, q in anchors do
		local d = (Vector3.new(q.X, 0, q.Z) - Vector3.new(at.X, 0, at.Z)).Magnitude
		if d < bd then best, bd = q, d end
	end
	if not best then fail(label .. ": no avenue on its tier"); return end
	local straight = walk({ at, best }, y)
	if not straight then return end
	-- stepping round something small (a chute, a lamp): one waypoint beside the midpoint
	local mid, side = (at + best) / 2, (best - at).Unit:Cross(Vector3.yAxis)
	for _, offset in { 10, -10, 18, -18 } do
		if not walk({ at, mid + side * offset, best }, y) then return end
	end
	local r, from = Vector2.new(at.X, at.Z).Magnitude, math.deg(math.atan2(at.Z, at.X))
	local why = straight
	for _, angle in A.geometry.Avenues.angles do
		local delta = (angle - from + 180) % 360 - 180
		if math.abs(delta) <= 45 then
			local points = { at }
			local n = math.ceil(math.abs(delta) / 2)
			for k = 1, n do
				local t = math.rad(from + delta * k / n)
				table.insert(points, Vector3.new(math.cos(t) * r, y, math.sin(t) * r))
			end
			local ring = walk(points, y)
			if not ring then return end
			why = why .. "; round the terrace to " .. angle .. ": " .. ring
		end
	end
	fail(("%s: no walk to an avenue (%s)"):format(label, why))
end
-- a locked field's eject box (its floor +2 studs, as DebrisService reads it) must not reach any avenue paving, or a
-- player walking the avenue's kerb is teleported to the field's entrance
for _, avenue in map.Roads:GetChildren() do
	if avenue.Name:find("^Avenue_") then
		for _, p in avenue:GetChildren() do
			if p.Name == "Paving" then
				for t = -p.Size.Z / 2, p.Size.Z / 2, 2 do
					for _, side in { -1, 0, 1 } do
						local at = (p.CFrame * CFrame.new(side * p.Size.X / 2, 0, t)).Position
						for _, field in map.DebrisFields:GetChildren() do
							local floor = field.FieldFloor
							local l = floor.CFrame:PointToObjectSpace(at)
							if math.abs(l.X) <= floor.Size.X / 2 + 2 and math.abs(l.Z) <= floor.Size.Z / 2 + 2 and l.Y > -2 and l.Y < 40 then
								fail(("%s eject box reaches %s paving at (%.0f, %.0f)"):format(field.Name, avenue.Name, at.X, at.Z))
							end
						end
					end
				end
			end
		end
	end
end
-- leaderboards stay readable: nothing visible in or in front of a board but the board itself
do
	local O = assert(loadstring(game:GetService("HttpService"):GetAsync("http://127.0.0.1:8123/map-v3/Overlap.luau", true)))()
	local others = O.index(24)
	for _, child in map:GetChildren() do
		if child.Name ~= "Ground" and child.Name ~= "Roads" then
			for _, p in child:GetDescendants() do
				if p:IsA("BasePart") and p.Transparency < 1 then others:add(p, p:FindFirstAncestorOfClass("Model")) end
			end
		end
	end
	for _, board in map.TownSquare.Leaderboards:GetChildren() do
		local screen = board:FindFirstChild("Screen", true) :: BasePart
		local gui = screen:FindFirstChildOfClass("SurfaceGui")
		local n = screen.CFrame:VectorToWorldSpace(Vector3.fromNormalId(if gui then gui.Face else Enum.NormalId.Front))
		local probe = Instance.new("Part")
		probe.Size = Vector3.new(screen.Size.X, screen.Size.Y, 20)
		probe.CFrame = CFrame.lookAt(screen.Position + n * 10.5, screen.Position + n * 11)
		for _, h in others:hits(probe, 0.1) do
			if not h.part:IsDescendantOf(board) then fail(("leaderboard %s covered by %s"):format(board.Name, h.part:GetFullName())) end
		end
		probe:Destroy()
	end
end
-- field walls: clear of everything players walk or use
do
	local O = assert(loadstring(game:GetService("HttpService"):GetAsync("http://127.0.0.1:8123/map-v3/Overlap.luau", true)))()
	local blockers = O.index(24)
	local groups = { map.Roads, map.Ground.Cliffs, map.Ground.Ramps, map.Boundary, map.Debris, map.Chutes, map.Crown, map.TownSquare }
	for _, g in groups do
		for _, p in g:GetDescendants() do if p:IsA("BasePart") and p.Transparency < 1 then blockers:add(p, p) end end
	end
	local points = {}
	for _, chute in map.Chutes:GetChildren() do table.insert(points, { "chute " .. chute.Name, chute.UsePoint.Position }) end
	for _, field in map.DebrisFields:GetChildren() do table.insert(points, { "entrance " .. field.Name, field.Entrance.Position }) end
	for _, gate in map.Gates:GetChildren() do
		local walls = {}
		for _, w in gate:GetChildren() do if w.Name == "Wall" then table.insert(walls, w) end end
		for _, w in walls do
			for _, h in blockers:hits(w, 0.2) do
				fail(("%s wall cuts into %s"):format(gate.Name, h.part:GetFullName()))
			end
		end
		if #walls > 0 then
			local floor = map.DebrisFields[gate.Name].FieldFloor
			for _, pt in points do
				local l = floor.CFrame:PointToObjectSpace(pt[2])
				if math.abs(l.X) < floor.Size.X / 2 + 2.5 and math.abs(l.Z) < floor.Size.Z / 2 + 2.5 then
					fail(("%s stands inside %s's walls"):format(pt[1], gate.Name))
				end
			end
		end
	end
end
do
	local H = game:GetService("HttpService")
	local O = assert(loadstring(H:GetAsync("http://127.0.0.1:8123/map-v3/Overlap.luau", true)))()
	local flush = assert(loadstring(H:GetAsync("http://127.0.0.1:8123/map-v3/Coplanar.luau", true)))(O)
	for _, pair in flush.list do
		fail(("flush faces flicker at (%.0f, %.1f, %.0f): %s | %s (run Dezfight)"):format(pair.at.X, pair.at.Y, pair.at.Z, pair.p:GetFullName(), pair.q:GetFullName()))
	end
end
for _, chute in map.Chutes:GetChildren() do reach("chute " .. chute.Name, chute.UsePoint.Position) end
for _, field in map.DebrisFields:GetChildren() do reach("entrance " .. field.Name, field.Entrance.Position) end

return {
	stage = "StaticQA", failures = failures, total = total, meshParts = meshes, lights = lights, emitters = emitters,
	walksChecked = checked, perModel = table.concat(report, ", "),
}
