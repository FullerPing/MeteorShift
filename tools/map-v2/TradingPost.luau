-- Common + Brick + Toon first. The Trading Post: a cartoon market stall west of the ring road, front toward the east
-- (the crater side): a red and white striped roof, a giant gold coin on top, a counter stacked with bars and a pair of
-- scales. Contract: TownSquare.TradingPost.SellPoint with a ProximityPrompt (EconomyService).
local A = assert(_G.MapRedesignArt)
local T = assert(A.toon, "Run Toon first")
local R = T.ramp
local town = A.ensure(A.map, "TownSquare")
local zone = A.zone("TradingPost")
local F = A.frameFor(zone, "E")
local LAT, DEP = F.lat, F.dep -- 28 across, 20 deep
local post = A.group(town, "TradingPost")
local function box(name, u, d, y0, lat, dep, h, color, material, collide) return T.box(post, name, F, u, d, y0, lat, dep, h, color, material, collide) end

local plinth = box("Plinth", 0, 0, 0, LAT, DEP, 1, R.stone[3])
post.PrimaryPart = plinth
box("Deck", 0, 0, 1, LAT - 1.4, DEP - 1.4, .5, R.wood[1])
local y0 = 1.5
-- back wall with shelves of bars, low side rails
box("BackWall", 0, -DEP / 2 + 1.6, y0, LAT - 2, 2.4, 12, R.red[2])
box("BackWallBase", 0, -DEP / 2 + 1.6, y0, LAT - 1.4, 3, 2, R.red[3])
for k = 0, 1 do
	box("Shelf", 0, -DEP / 2 + 3.6, y0 + 4.5 + k * 4, LAT - 6, 2, .6, R.wood[2], nil, false)
	for b = 0, 4 do box("ShelfBar", -8 + b * 4, -DEP / 2 + 3.6, y0 + 5.1 + k * 4, 2.6, 1.4, .9, R.gold[2], nil, false) end
end
-- four striped posts
local postU, postD = LAT / 2 - 1.6, DEP / 2 - 1.6
for _, su in { -1, 1 } do
	for _, sd in { -1, 1 } do
		T.cyl(post, "Post", F, su * postU, sd * postD, y0, 2.2, 14, T.white)
		T.cyl(post, "PostStripe", F, su * postU, sd * postD, y0 + 4, 2.5, 2, R.red[2], nil, false)
		T.cyl(post, "PostStripe", F, su * postU, sd * postD, y0 + 9, 2.5, 2, R.red[2], nil, false)
	end
end
-- striped gable roof: seven stripes, each a front and a back wedge, ridge and eaves; a scalloped valance in front
local eaveY = y0 + 14
local stripes, roofDep, rise = 7, DEP - 1.6, 5.4
local stripeW = (LAT - .4) / stripes
local half = roofDep / 2
for i = 0, stripes - 1 do
	local u = -LAT / 2 + .2 + (i + .5) * stripeW
	local color = if i % 2 == 0 then R.red[2] else T.white
	T.wedge(post, "RoofStripe", F, u, half / 2, eaveY, stripeW, half, rise, color)
	T.wedge(post, "RoofStripe", F, u, -half / 2, eaveY, stripeW, half, rise, color, true)
end
T.cylLat(post, "RoofRidge", F, 0, 0, eaveY + rise, 1.6, LAT - .4, R.gold[2], nil, false)
for i = 0, 5 do
	T.ball(post, "Valance", F, -LAT / 2 + 2.4 + i * (LAT - 4.8) / 5, half - .6, eaveY - .2, 2.6, if i % 2 == 0 then R.red[2] else T.white, nil, false)
end
-- the giant gold coin on the ridge, facing the crater, with a $ on it
local coinY = eaveY + rise + 5.4
T.cylDep(post, "Coin", F, 0, 0, coinY, 9.6, 1.4, R.gold[2], nil, false)
T.cylDep(post, "CoinFace", F, 0, .3, coinY, 7.4, 1.2, R.gold[1], nil, false)
T.cyl(post, "CoinStand", F, 0, 0, eaveY + rise - .2, 1.2, 1.4, R.gold[3], nil, false)
local mark, markLabel = A.sign(post, "CoinMark", "$", Vector3.new(6, 6, .2), F.cf(0, coinY, 1.05), R.gold[1])
mark.Transparency = 1
markLabel.TextColor3 = R.gold[3]
markLabel.TextStrokeTransparency = 1
-- the name board under the valance and the counter with bars and scales
local name = A.signOn(post, "TradingSign", "TRADING POST", F, 0, eaveY - 2.4, half - .2, 18, 2.8, T.ink, .6)
T.smooth(name)
box("Counter", 0, DEP / 2 - 4.4, y0, LAT - 9, 3.4, 4.4, R.wood[2])
box("CounterTop", 0, DEP / 2 - 4.4, y0 + 4.4, LAT - 8, 4.2, .8, R.wood[1])
box("CounterPanel", 0, DEP / 2 - 2.6, y0 + .8, LAT - 11, .3, 3, R.gold[2], nil, false)
local sell = A.signOn(post, "SellSign", "SELL YOUR BARS", F, 0, y0 + 2.3, DEP / 2 - 2.35, 13, 2, T.ink, .3)
T.smooth(sell)
for row = 0, 2 do
	for col = 0, 2 - row do
		box("GoldBar", -6.4 + col * 2.2 + row * 1.1, DEP / 2 - 4.4, y0 + 5.2 + row * .9, 2, 1.6, .9, R.gold[2], nil, false)
	end
end
-- scales: post, beam and two pans
local su = 5
T.cyl(post, "ScaleFoot", F, su, DEP / 2 - 4.4, y0 + 5.2, 2.4, .5, R.gold[3], nil, false)
T.cyl(post, "ScalePost", F, su, DEP / 2 - 4.4, y0 + 5.7, .6, 4.4, R.gold[3], nil, false)
box("ScaleBeam", su, DEP / 2 - 4.4, y0 + 10, 6, .5, .5, R.gold[3], nil, false)
for _, s in { -1, 1 } do T.cyl(post, "ScalePan", F, su + s * 2.8, DEP / 2 - 4.4, y0 + 8.2, 2.6, .4, R.gold[1], nil, false) end
-- sacks and a crate at the front corners
for k, data in { { -12.2, 6 }, { -10.4, 7.8 }, { 12.2, 6.8 } } do
	local p = F.world(data[1], 0, data[2])
	T.part(post, "Sack", Vector3.new(3.4, 3.4, 3.4), A.cf(p.X, y0 + 1.6, p.Z), R.cream[3], nil, false, Enum.PartType.Ball)
	T.part(post, "SackTie", Vector3.new(1.2, 1.2, 1.2), A.cf(p.X, y0 + 3.4, p.Z), R.wood[3], nil, false, Enum.PartType.Ball)
end
for _, v in post:GetDescendants() do if v:IsA("BasePart") then v.TopSurface = Enum.SurfaceType.Smooth end end

A.within(post, zone, 0)
local count = A.count(post)
assert(count <= 100, "Trading Post art budget: " .. count)
-- the sell point stands just outside the front, on the walkway
local point = A.part(post, "SellPoint", Vector3.new(6, 1, 6), A.cf(zone.entrance.X, 3, zone.entrance.Z), A.colors.yellow, nil, false)
point.Transparency = 1
point.CanCollide, point.CanTouch, point.CanQuery = false, false, false
local prompt = Instance.new("ProximityPrompt")
prompt.Name = "SellBars"
prompt.ActionText = "Sell bars"
prompt.ObjectText = "Trading Post"
prompt.MaxActivationDistance = 12
prompt.HoldDuration = 0
prompt.RequiresLineOfSight = false
prompt.Parent = point
A.map:SetAttribute("TradingPostPass", 4)
return { stage = "TradingPost", parts = count + 1, sellPoint = { point.Position.X, point.Position.Y, point.Position.Z }, totalParts = A.count(A.map) }
