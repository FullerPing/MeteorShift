-- Common + Brick + Toon first. The two leaderboards on the south plaza either side of the Refinery, turned a little
-- toward the spawn so players see them as they load in and every time they come back to deposit. Owns
-- TownSquare.Leaderboards: one Model per board (named after its Config.Leaderboards id) with a part "Screen" whose
-- Front face takes the rows; LeaderboardService builds and fills that SurfaceGui at runtime.
local A = assert(_G.MapRedesignArt)
local T = assert(A.toon, "Run Toon first")
local R = T.ramp
local town = A.ensure(A.map, "TownSquare")
local root = A.group(town, "Leaderboards")

local boards = {
	{ id = "BarsSold", title = "TOP MINERS", zone = "LeaderboardEast", accent = R.gold, star = R.gold[1] },
	{ id = "Rebirths", title = "TOP REBIRTHS", zone = "LeaderboardWest", accent = R.violet, star = R.pink[1] },
}

-- scenery placed before the boards had zones (flags, lamps, benches) goes when it stands on or right next to a board;
-- a Scenery rerun avoids the zones by itself
local cleared = 0
local scenery = A.map:FindFirstChild("Scenery")
if scenery then
	local candidates = {}
	for _, c in scenery:GetChildren() do table.insert(candidates, c) end
	local props = scenery:FindFirstChild("Props")
	if props then for _, c in props:GetChildren() do table.insert(candidates, c) end end
	for _, c in candidates do
		local at = if c:IsA("Model") then c:GetPivot().Position elseif c:IsA("BasePart") then c.Position else nil
		for _, b in boards do
			local zone = A.zone(b.zone)
			if c ~= props and at and math.abs(at.X - zone.x) <= zone.width / 2 + 4 and math.abs(at.Z - zone.z) <= zone.depth / 2 + 4 then
				c:Destroy()
				cleared += 1
				break
			end
		end
	end
end

for _, b in boards do
	local zone = A.zone(b.zone)
	local g = A.group(root, b.id)
	-- facing north, turned 25 degrees toward the plaza's centre line
	local inward = if zone.x > 0 then -1 else 1
	local F = A.frame(zone.x, zone.z, Vector3.new(inward * math.sin(math.rad(25)), 0, math.cos(math.rad(25))))
	T.box(g, "Base", F, 0, 0, 0, 15, 3.2, 1, R.stone[2])
	T.box(g, "BaseTrim", F, 0, 0, 1, 15.4, 3.6, .4, R.cream[1], nil, false)
	for _, side in { -1, 1 } do
		T.cyl(g, "Post", F, side * 7, 0, 1.4, 1.8, 15.6, R.navy[2])
		T.ball(g, "PostKnob", F, side * 7, 0, 17.4, 2.6, b.accent[2], nil, false)
	end
	T.box(g, "Frame", F, 0, -.3, 2.8, 13.4, .8, 11.2, b.accent[2])
	T.box(g, "FrameBack", F, 0, -.9, 2.4, 13.8, .6, 12, R.navy[3], nil, false)
	local screen = T.part(g, "Screen", Vector3.new(12, 9.8, .3), F.cf(0, 8.4, .2), Color3.fromRGB(24, 34, 70), nil, false)
	screen.CastShadow = false
	local title = A.signOn(g, "Title", b.title, F, 0, 15.3, .1, 14, 2.8, b.accent[3], .8)
	T.smooth(title)
	local star = T.ball(g, "Star", F, 0, 0, 18.4, 2.6, b.star, Enum.Material.Neon, false)
	star.CastShadow = false
	for _, p in g:GetDescendants() do if p:IsA("BasePart") then p.TopSurface = Enum.SurfaceType.Smooth end end
	g.PrimaryPart = screen
	A.within(g, zone, 0)
end
assert(A.innerCount(A.map) <= 2700, "Map budget")
A.map:SetAttribute("LeaderboardsPass", 1)
return { stage = "Leaderboards", parts = A.count(root), clearedScenery = cleared, innerParts = A.innerCount(A.map) }
