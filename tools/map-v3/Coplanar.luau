-- Map v3 z-fight finder (edit time, read-only). L("../map-v3/Coplanar", L("../map-v3/Overlap"), groups?) returns
-- { list = { { p, q, normal, at, area } }, byGroup = { ["A x B"] = { n, examples } } }: every pair of visible block
-- parts with a face pointing the same way in the same plane (within EPS) whose rectangles share more than MIN_AREA
-- square studs, where the shared patch can be seen (not facing down, not buried in another part). Those flicker in game
-- (z-fighting). `p` is the part with the smaller face. Wedges count only their bottom and back; meshes, cylinders and
-- balls are skipped as candidates but still hide what they cover.
local A = assert(_G.MapRedesignArt, "Run Common first")
local O, groups = ...
assert(O, "Pass the overlap helpers")
local EPS, MIN_AREA = 0.06, 1
local map = A.map
groups = groups or { "Ground", "Roads", "Boundary", "Gates", "Crown", "Districts", "TownSquare", "Chutes" }

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

-- the shared area of two coplanar rectangles, sampled 6x6 over a's face, and one shared point
local function shared(a, b): (number, Vector3?)
	local function inside(pt: Vector3, f): boolean
		local d = pt - f.c
		return math.abs(d:Dot(f.u)) <= f.hu + 1e-3 and math.abs(d:Dot(f.v)) <= f.hv + 1e-3
	end
	local hits, N, at = 0, 6, nil
	for i = 0, N - 1 do
		for j = 0, N - 1 do
			local pt = a.c + a.u * (((i + .5) / N) * 2 - 1) * a.hu + a.v * (((j + .5) / N) * 2 - 1) * a.hv
			if inside(pt, b) then hits += 1; at = at or pt end
		end
	end
	return hits / (N * N) * (4 * a.hu * a.hv), at
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
	if not p:IsA("MeshPart") and (not p:IsA("Part") or (p :: Part).Shape == Enum.PartType.Block) then
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
