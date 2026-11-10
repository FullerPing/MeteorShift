-- Common + Brick + Toon first. The egg garden: an open-air sandy plaza southwest of the ring road, turned toward the
-- crater. Three stone pedestals carry the eggs with their shard price on the front, a big EGGS title floats behind
-- them, rustic fences and trees frame it. Walking up to an egg shows its odds (read from Config.Pets, so they never
-- drift from the real odds and prices). Contract: one pedestal Model per egg with attr EggId.
local A = assert(_G.MapRedesignArt)
local T = assert(A.toon, "Run Toon first")
local R = T.ramp
local Config = A.config
local town = A.ensure(A.map, "TownSquare")
local zone = A.zone("Hatchery")
local F = A.frameFor(zone) -- turned toward the crater (zone.facing)
local LAT, DEP = F.lat, F.dep -- 64 across, 36 deep
local hatch = A.group(town, "Hatchery")
local floorY = 1.8
local SHARD_ICON = "rbxassetid://1436430600"
local label = T.outlined
local function board(parent, name, u, y, d, w, h, ppu) return T.textBoard(parent, name, F, u, y, d, w, h, ppu) end

-- the plaza: a rounded sand pad on a darker rim
hatch.PrimaryPart = T.roundPad(hatch, "Plinth", F, LAT, DEP, 0, 1.2, T.sand[2])
T.roundPad(hatch, "Sand", F, LAT - 2, DEP - 2, 1.2, .6, T.sand[1])

-- one pedestal per egg: grey stone steps, the egg (a stored Blender mesh, else parts) and the price on the front
local eggs = Config.Pets.Eggs
assert(#eggs == 3, "Revisit the pedestal layout if the egg catalog changes")
local pitch = 19
local accents = { R.orange[1], R.frost[2], R.pink[1] }
for i, egg in eggs do
	local u, d = (i - (#eggs + 1) / 2) * pitch, 1
	local accent = accents[i]
	local pedestal = A.group(hatch, egg.Id)
	pedestal:SetAttribute("EggId", egg.Id)
	T.cyl(pedestal, "Base", F, u, d, floorY, 13.4, 1.2, R.stone[3])
	T.cyl(pedestal, "Plinth", F, u, d, floorY + 1.2, 11.6, 3.8, R.stone[2])
	local top = T.cyl(pedestal, "Top", F, u, d, floorY + 5, 12.4, .9, R.stone[1])
	local eggY = floorY + 5.9
	T.mesh(pedestal, "Egg_" .. egg.Id, F.cf(u, eggY, d), 10.5, function()
		T.part(pedestal, "Egg", Vector3.new(8.4, 10.5, 8.4), F.cf(u, eggY + 4.6, d), accent, nil, false, Enum.PartType.Ball)
		T.part(pedestal, "EggTop", Vector3.new(6.4, 6.4, 6.4), F.cf(u, eggY + 7.4, d), accent, nil, false, Enum.PartType.Ball)
	end)
	-- the price, big and outlined like the reference: shard icon + cost
	local price = board(pedestal, "Price", u, floorY + 3.1, d + 5.9, 10, 3.6)
	local row = Instance.new("Frame")
	row.BackgroundTransparency, row.Size = 1, UDim2.fromScale(1, 1)
	row.Parent = price
	local layout = Instance.new("UIListLayout")
	layout.FillDirection, layout.HorizontalAlignment, layout.VerticalAlignment = Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 6)
	layout.Parent = row
	local icon = Instance.new("ImageLabel")
	icon.BackgroundTransparency, icon.Image, icon.Size, icon.LayoutOrder = 1, SHARD_ICON, UDim2.fromOffset(62, 62), 1
	icon.Parent = row
	local cost = label(row, tostring(egg.Cost), Enum.Font.LuckiestGuy, T.white, UDim2.fromOffset(110, 66), nil, 5)
	cost.TextXAlignment, cost.LayoutOrder = Enum.TextXAlignment.Left, 2
	-- soft sparkles round the egg in its accent colour
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Name = "Sparkle"
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Color = ColorSequence.new(accent)
	sparkle.LightEmission, sparkle.Rate, sparkle.Lifetime = .6, 3, NumberRange.new(1.2, 2)
	sparkle.Speed, sparkle.SpreadAngle = NumberRange.new(1, 2.5), Vector2.new(180, 180)
	sparkle.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, .5), NumberSequenceKeypoint.new(1, 0) })
	sparkle.Parent = top

	-- the odds card appears over the egg when a player walks up (Config-driven, checked to sum to 100)
	local rows = {}
	local sum = 0
	for _, rarity in Config.Pets.RarityOrder do
		local chance = egg.Odds[rarity]
		if chance then
			sum += chance
			table.insert(rows, { Config.Pets.Rarities[rarity], chance })
		end
	end
	assert(math.abs(sum - 100) < .001, "Config odds no longer sum to 100")
	local card = Instance.new("BillboardGui")
	card.Name = "OddsCard"
	card.Adornee, card.Size, card.StudsOffset = top, UDim2.fromScale(10.5, 8.5), Vector3.new(0, 15, 0) -- camera space: straight up on screen
	card.MaxDistance, card.LightInfluence, card.ResetOnSpawn = 34, 0, false -- from the road the title reads alone
	card.Parent = top
	local panel = Instance.new("Frame")
	panel.Size, panel.BackgroundColor3, panel.BackgroundTransparency = UDim2.fromScale(1, 1), Color3.fromRGB(30, 34, 58), .2
	Instance.new("UICorner", panel).CornerRadius = UDim.new(.1, 0)
	local edge = Instance.new("UIStroke")
	edge.Color, edge.Thickness, edge.ApplyStrokeMode = accent, 3, Enum.ApplyStrokeMode.Border
	edge.Parent = panel
	panel.Parent = card
	local lineH = .62 / 5 -- every card keeps the same row size, however many rarities the egg has
	label(panel, string.upper(egg.Name), Enum.Font.LuckiestGuy, accent, UDim2.fromScale(.92, .2), UDim2.fromScale(.04, .04), 2)
	for k, entry in rows do
		local y = .25 + (k - 1) * lineH
		local name = label(panel, entry[1].Name, Enum.Font.FredokaOne, entry[1].Color, UDim2.fromScale(.6, lineH * .9), UDim2.fromScale(.06, y), 1.5)
		name.TextXAlignment = Enum.TextXAlignment.Left
		local pct = label(panel, entry[2] .. "%", Enum.Font.FredokaOne, T.white, UDim2.fromScale(.32, lineH * .9), UDim2.fromScale(.62, y), 1.5)
		pct.TextXAlignment = Enum.TextXAlignment.Right
	end
	local footer = if egg.MinRebirths then string.format("Unlocks at Rebirth %d", egg.MinRebirths)
		else string.format("%s+ guaranteed in %d", Config.Pets.Rarities[egg.PityFrom].Name, egg.Pity)
	label(panel, footer, Enum.Font.FredokaOne, R.gold[1], UDim2.fromScale(.92, .1), UDim2.fromScale(.04, .88), 1.5)
end

-- the big title behind the eggs, with the how-to underneath
local title = board(hatch, "Title", 0, 31, -11, 50, 22, 4)
label(title, "EGGS", Enum.Font.LuckiestGuy, T.white, UDim2.fromScale(1, .76), nil, 3.5)
label(title, "OPEN PETS TO HATCH", Enum.Font.LuckiestGuy, R.gold[1], UDim2.fromScale(.84, .2), UDim2.fromScale(.08, .78), 1.5)

-- rustic fences round the edge, open at the front: chunky posts with two slightly crooked planks
-- only the flanks, so nothing stands between the road and the prices
for k, run in { { -31, 7, -27, 14 }, { -31, -7, -31, 7 }, { 27, 14, 31, 7 }, { 31, -7, 31, 7 } } do
	T.fence(hatch, F, run[1], run[2], run[3], run[4], floorY, k)
end

-- greenery: two round trees and two pines at the back corners, bushes along the rear, a few big red flowers
local function at(u, d) return F.world(u, 0, d) end
for _, side in { -1, 1 } do
	local p = at(side * 23, -10)
	T.tree(hatch, "Tree", p.X, p.Z, floorY, 1.35)
	local q = at(side * 31, -14)
	T.tree(hatch, "Pine", q.X, q.Z, floorY, 1.1, "pine")
end
for k, u in { -13, -6, 0, 6, 13 } do
	local p = at(u, -15 + (k % 2))
	T.part(hatch, "Bush", Vector3.one * (if k % 2 == 0 then 6.5 else 7.5), A.cf(p.X, floorY + 2.4, p.Z), R.green[(k % 2) + 1], nil, false, Enum.PartType.Ball)
end
for k, spot in { { -27, 9 }, { 27, 9 }, { -18, -9 }, { 18, -9 } } do
	T.flower(hatch, F, spot[1], spot[2], floorY, if k % 2 == 0 then R.red[2] else R.pink[2], k)
end

for _, v in hatch:GetDescendants() do if v:IsA("BasePart") then v.TopSurface = Enum.SurfaceType.Smooth end end
A.within(hatch, zone, 0)
local count = A.count(hatch)
assert(count <= 160, "Hatchery art budget: " .. count)
A.map:SetAttribute("HatcheryPass", 5)
return { stage = "Hatchery", parts = count, eggs = #eggs, oddsCards = #eggs, totalParts = A.count(A.map) }
