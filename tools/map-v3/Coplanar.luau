-- Map v3 z-fight finder (edit time, read-only). L("../map-v3/Coplanar", L("../map-v3/Overlap"), groups?) returns
-- { list = { { p, q, normal, at, area } }, byGroup = { ["A x B"] = { n, examples } } }: every pair of visible block
-- parts with a face pointing the same way in the same plane (within EPS) whose rectangles share more than MIN_AREA
-- square studs, where the shared patch can be seen (not facing down, not buried in another part). Those flicker in game
-- (z-fighting). `p` is the part with the smaller face. Wedges count only their bottom and back; meshes, unions, cylinders
-- and balls are skipped as candidates but still hide what they cover.
local A = assert(_G.MapRedesignArt, "Run Common first")
local O, groups = ...
assert(O, "Pass the overlap helpers")
local EPS, MIN_AREA = 0.06, 1
local map = A.map
groups = groups or { "Ground", "Roads", "Boundary", "Gates", "Crown", "Districts", "TownSquare", "Chutes", "Crater", "CraterApron", "Scenery", "CraterDetail" }

local function faces(p: BasePart)
	local c, s = p.CFrame, p.Size / 2
	local ax = { { c.RightVector, s.X }, { c.UpVector, s.Y }, { c.LookVector, s.Z } }
	local out = {}
	for i = 1, 3 do
		for _, sign in { 1, -1 } do
			local real = true
			if p:IsA("WedgePart") then real = (i == 2 and sign == -1) or (i == 3 and sign == 1) end
			local n = ax[i][1] * sign
			if real and n.Y > -0.5 then -- a face looking down is never seen on this map
				local u, v = ax[i % 3 + 1], ax[(i + 1) % 3 + 1]
				table.insert(out, { n = n, c = c.Position + ax[i][1] * ax[i][2] * sign, u = u[1], hu = u[2], v = v[1], hv = v[2] })
			end
		end
	end
	return out
end

-- the exact shared area of two coplanar rectangles (a's corners clipped by b's four edges, in a's plane) and the
-- centroid of the shared patch. Sampling missed small overlaps on long faces, such as cliff turf past a 16-gon corner.
local function shared(a, b): (number, Vector3?)
	local function uv(pt: Vector3): Vector2 local d = pt - a.c return Vector2.new(d:Dot(a.u), d:Dot(a.v)) end
	local poly = { Vector2.new(-a.hu, -a.hv), Vector2.new(a.hu, -a.hv), Vector2.new(a.hu, a.hv), Vector2.new(-a.hu, a.hv) }
	local bc = uv(b.c)
	local bu, bv = Vector2.new(b.u:Dot(a.u), b.u:Dot(a.v)), Vector2.new(b.v:Dot(a.u), b.v:Dot(a.v))
	for _, edge in { { bu, b.hu }, { -bu, b.hu }, { bv, b.hv }, { -bv, b.hv } } do
		local n, h = edge[1], edge[2]
		local function keep(q: Vector2): number return h - (q - bc):Dot(n) end -- >= 0 inside this edge
		local out = {}
		for i, q in poly do
			local r = poly[i % #poly + 1]
			local kq, kr = keep(q), keep(r)
			if kq >= 0 then table.insert(out, q) end
			if (kq >= 0) ~= (kr >= 0) then table.insert(out, q + (r - q) * (kq / (kq - kr))) end
		end
		poly = out
		if #poly < 3 then return 0, nil end
	end
	local area, cx, cy = 0, 0, 0
	for i, q in poly do
		local r = poly[i % #poly + 1]
		local cross = q.X * r.Y - r.X * q.Y
		area += cross
		cx += (q.X + r.X) * cross
		cy += (q.Y + r.Y) * cross
	end
	if math.abs(area) < 1e-9 then return 0, nil end
	cx, cy = cx / (3 * area), cy / (3 * area)
	return math.abs(area) / 2, a.c + a.u * cx + a.v * cy
end

local function tagOf(p: BasePart): string
	local path = p:GetFullName():gsub("^Workspace%.Map_Redesign%.", ""):gsub("^Workspace%.Map%.", "")
	local top, second = path:match("^([^%.]+)%.?([^%.]*)")
	if top == "Ground" or top == "Roads" then return top .. "." .. (second:gsub("[%d_%-]+$", "")) end
	return top
end

local candidates, cover = O.index(24), O.index(24)
local all = {}
for _, name in groups do
	local group = map:FindFirstChild(name)
	for _, p in (group and group:GetDescendants() or {}) do
		if p:IsA("BasePart") and p.Transparency < 1 then
			cover:add(p, p)
			table.insert(all, p)
		end
	end
end
local probe = Instance.new("Part")
probe.Size = Vector3.new(.3, .3, .3)
local function hidden(at: Vector3, n: Vector3, p: BasePart, q: BasePart): boolean
	probe.CFrame = CFrame.new(at + n * .3)
	for _, h in cover:hits(probe, 0) do
		if h.part ~= p and h.part ~= q then return true end
	end
	return false
end

local result = { list = {}, byGroup = {} }
for i, p in all do
	-- unions (the ring road, the rim) are not boxes: their bounding box would read as a solid slab
	if not p:IsA("MeshPart") and not p:IsA("PartOperation") and (not p:IsA("Part") or (p :: Part).Shape == Enum.PartType.Block) then
		local fp = faces(p)
		for _, h in candidates:hits(p, 0) do -- same-way faces can only share area when the parts interpenetrate
			local q, fq = h.part, h.tag
			for _, a in fp do
				for _, b in fq do
					if a.n:Dot(b.n) > 0.999 and math.abs((b.c - a.c):Dot(a.n)) < EPS then
						local area, at = shared(a, b)
						if area > MIN_AREA and at and not hidden(at, a.n, p, q) then
							local small = if 4 * a.hu * a.hv <= 4 * b.hu * b.hv then p else q
							table.insert(result.list, { p = small, q = if small == p then q else p, normal = a.n, at = at, area = area })
							local k1, k2 = tagOf(p), tagOf(q)
							local key = if k1 < k2 then k1 .. " x " .. k2 else k2 .. " x " .. k1
							local g = result.byGroup[key] or { n = 0, examples = {} }
							g.n += 1
							if #g.examples < 3 then table.insert(g.examples, ("(%.0f,%.1f,%.0f) %s | %s"):format(at.X, at.Y, at.Z, p.Name, q.Name)) end
							result.byGroup[key] = g
						end
					end
				end
			end
		end
		candidates:add(p, fp)
	end
	if i % 400 == 0 then task.wait() end
end
probe:Destroy()
return result
