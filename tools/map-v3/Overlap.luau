-- Map v3 overlap helpers (edit time). L("../map-v3/Overlap") returns:
--   depth(p, q): how far two parts' oriented boxes interpenetrate (0 when apart), by the separating-axis test
--   index(cell): a spatial hash; :add(part, tag), :hits(part, minDepth, skip) -> { { part, tag, depth } }
-- Meshes count as their boxes, so a round shape near a corner can read as touching; callers pick a depth tolerance.
local O = {}

local function axes(c: CFrame) return { c.RightVector, c.UpVector, c.LookVector } end
local function radius(size: Vector3, ax: { Vector3 }, n: Vector3): number
	return math.abs(ax[1]:Dot(n)) * size.X / 2 + math.abs(ax[2]:Dot(n)) * size.Y / 2 + math.abs(ax[3]:Dot(n)) * size.Z / 2
end

function O.depth(p: BasePart, q: BasePart): number
	local a, b = axes(p.CFrame), axes(q.CFrame)
	local d = q.Position - p.Position
	local best = math.huge
	local tests = { a[1], a[2], a[3], b[1], b[2], b[3] }
	for i = 1, 3 do
		for j = 1, 3 do
			local n = a[i]:Cross(b[j])
			if n.Magnitude > 1e-4 then table.insert(tests, n.Unit) end
		end
	end
	for _, n in tests do
		local overlap = radius(p.Size, a, n) + radius(q.Size, b, n) - math.abs(d:Dot(n))
		if overlap <= 0 then return 0 end
		best = math.min(best, overlap)
	end
	return best
end

local function extent(p: BasePart): (Vector3, Vector3)
	local c, s = p.CFrame, p.Size / 2
	local e = Vector3.new(
		math.abs(c.RightVector.X) * s.X + math.abs(c.UpVector.X) * s.Y + math.abs(c.LookVector.X) * s.Z,
		math.abs(c.RightVector.Y) * s.X + math.abs(c.UpVector.Y) * s.Y + math.abs(c.LookVector.Y) * s.Z,
		math.abs(c.RightVector.Z) * s.X + math.abs(c.UpVector.Z) * s.Y + math.abs(c.LookVector.Z) * s.Z)
	return c.Position - e, c.Position + e
end
O.extent = extent

function O.index(cell: number?)
	local size = cell or 24
	local grid: { [string]: { any } } = {}
	local self = {}
	local function each(p: BasePart, fn: (string) -> ())
		local lo, hi = extent(p)
		for gx = math.floor(lo.X / size), math.floor(hi.X / size) do
			for gz = math.floor(lo.Z / size), math.floor(hi.Z / size) do fn(gx .. "," .. gz) end
		end
	end
	function self:add(p: BasePart, tag: any)
		local entry = { part = p, tag = tag }
		each(p, function(k) grid[k] = grid[k] or {}; table.insert(grid[k], entry) end)
	end
	-- parts already indexed that `p` pushes into by more than minDepth (entries whose tag == skip are ignored)
	function self:hits(p: BasePart, minDepth: number, skip: any?)
		local seen, out = {}, {}
		each(p, function(k)
			for _, e in grid[k] or {} do
				if not seen[e] and e.tag ~= skip then
					seen[e] = true
					local d = O.depth(p, e.part)
					if d > minDepth then table.insert(out, { part = e.part, tag = e.tag, depth = d }) end
				end
			end
		end)
		return out
	end
	return self
end

return O
