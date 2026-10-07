-- Run Common.luau first. Owns Ground, Crater and their collision only.
local A = assert(_G.MapRedesignArt)
local C = A.colors
local G = assert(A.geometry, "Run current Common first")
local K = assert(A.crater, "Run current Common first")
local half, opening, floorRadius = G.BoundaryHalf, K.OpeningRadius, K.FloorRadius
local floorY, rimY, rampWidth = K.FloorY, K.RimY, G.CraterRampWidth
local span, groundThickness = half*2, 4
local groundGroup = A.group(A.map,"Ground")
local slab = A.part(groundGroup,"Slab",Vector3.new(span,groundThickness,span),
	A.cf(0,rimY-groundThickness/2,0),C.grass)
local cutter = A.part(groundGroup,"TemporaryCutter",Vector3.new(120,opening*2,opening*2),
	A.cf(0,rimY-25,0)*CFrame.Angles(0,0,math.pi/2),C.stone,nil,false,Enum.PartType.Cylinder)
local ok, result = pcall(function()
	return game:GetService("GeometryService"):SubtractAsync(slab,{cutter},{
		CollisionFidelity = Enum.CollisionFidelity.PreciseConvexDecomposition,
		RenderFidelity = Enum.RenderFidelity.Precise, SplitApart = false,
	})
end)
assert(ok and #result>0, "Ground subtraction failed: "..tostring(result))
for index, p in result do
	p.Name = "GrassPlate"..index
	p.Color, p.Material = C.grass, Enum.Material.SmoothPlastic
	-- Large concave CSG collision closes the hole. This is visual geometry only.
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true,false,false,false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Studs, Enum.SurfaceType.Smooth
	p:SetAttribute("MapRedesignOwned",true)
	p.Parent = groundGroup
end
slab:Destroy(); cutter:Destroy()
local collision = A.group(groundGroup,"Collision")
local function proxy(name,size,frame)
	local p = A.part(collision,name,size,frame,C.grass)
	p.Transparency,p.CastShadow = 1,false
	p.TopSurface = Enum.SurfaceType.Smooth
	return p
end
-- Conservative row tiles leave the entire circular opening empty.
for row=0,63 do
	local z0,z1 = -half+row*(span/64), -half+(row+1)*(span/64)
	-- Include tile overlap when choosing the empty gap; it must not enter the hole.
	local expanded0,expanded1 = z0-.015,z1+.015
	local near = if expanded0<=0 and expanded1>=0 then 0
		else math.min(math.abs(expanded0),math.abs(expanded1))
	local gap = if near<opening then math.sqrt(opening^2-near^2) else 0
	if gap==0 then
		proxy("FullRow"..row,Vector3.new(span,groundThickness,z1-z0+.03),
			A.cf(0,rimY-groundThickness/2,(z0+z1)/2))
	else
		local width=half-gap
		for _,sign in {-1,1} do
			proxy("SideRow"..row.."_"..sign,Vector3.new(width,groundThickness,z1-z0+.03),
				A.cf(sign*(gap+width/2),rimY-groundThickness/2,(z0+z1)/2))
		end
	end
end
-- This flat annulus fills the row tiles' conservative gaps at the rim.
-- Its inner faces are tangent to the opening, so no rectangle closes the hole.
local rimDepth = 18
local rimProxyRadius = opening+rimDepth/2
local rimProxyWidth = 2*(opening+rimDepth)*math.tan(math.pi/48)+.4
for k=0,47 do
	local angle=k*math.pi*2/48
	proxy("RimDeck"..k,Vector3.new(rimProxyWidth,groundThickness,rimDepth),
		A.cf(math.cos(angle)*rimProxyRadius,rimY-groundThickness/2,math.sin(angle)*rimProxyRadius)
			*CFrame.Angles(0,-angle+math.pi/2,0))
end
local crater = A.group(A.map,"Crater")
local bowl = A.group(crater,"Bowl")
local floor = A.cylinder(bowl,"Floor",floorRadius*2,2,A.cf(0,floorY-1,0),C.stone)
floor:SetAttribute("WalkSurface",true)
local n = 48
local fanWidth = opening*2*math.tan(math.pi/n)+.4
for k=0,n-1 do
	local angle = k*math.pi*2/n
	local direction = Vector3.new(math.cos(angle),0,math.sin(angle))
	local slope = A.slope(bowl,"Slope"..k, direction*floorRadius+Vector3.new(0,floorY,0),
		direction*opening+Vector3.new(0,rimY,0),fanWidth,2,C.stone)
	slope:SetAttribute("WalkSurface",true)
end
local ramps = A.group(crater,"AccessRamps")
local rampStart, rampEnd = floorRadius-1, opening+1
local rampRise, rampRun = rimY-floorY, rampEnd-rampStart
local landingWidth = rampWidth+2
-- Keep each square landing entirely above the circular flat floor.
local landingRadius = math.sqrt(floorRadius^2-(landingWidth/2)^2)-landingWidth/2-.25
for k=0,3 do
	local angle = k*math.pi/2
	local direction = Vector3.new(math.cos(angle),0,math.sin(angle))
	local ramp = A.slope(ramps,"Ramp"..(k+1),direction*rampStart+Vector3.new(0,floorY+.28,0),
		direction*rampEnd+Vector3.new(0,rimY+.28,0),rampWidth,1.4,C.path)
	ramp:SetAttribute("WalkSurface",true)
	ramp:SetAttribute("ClearWidth",rampWidth)
	ramp:SetAttribute("Rise",rampRise)
	ramp:SetAttribute("Run",rampRun)
	local landing = A.part(ramps,"FloorLanding"..k,Vector3.new(landingWidth,.25,landingWidth),
		A.cf(direction.X*landingRadius,floorY+.155,direction.Z*landingRadius),C.path)
	landing:SetAttribute("WalkSurface",true)
end
local rim = A.group(crater,"Rim")
local rimRadius = opening+6
for k=0,47 do
	local angle = (k+.5)*math.pi*2/48
	-- Protect the full cardinal ramp width using the rectangles' projected corners.
	local x,z = math.cos(angle)*rimRadius,math.sin(angle)*rimRadius
	local extentX = math.abs(math.sin(angle))*8+math.abs(math.cos(angle))*3.5
	local extentZ = math.abs(math.cos(angle))*8+math.abs(math.sin(angle))*3.5
	if math.min(math.abs(x)-extentX,math.abs(z)-extentZ)>rampWidth/2+1 then
		A.part(rim,"StuddedRim"..k,Vector3.new(16,3,7),
			A.cf(x,rimY+1.5,z)*CFrame.Angles(0,-angle+math.pi/2,0),C.gold)
	end
end
-- The double-sized meteor's sampled minimum is above the compact crater floor.
local point = A.part(crater,"MeteorSpawn",Vector3.new(1,1,1),
	CFrame.new(K.Center+A.offset),C.ember,nil,false)
point.Transparency = 1
local active = A.group(crater,"ActiveMeteor","Folder")
local timer = A.part(crater,"SkyTimer",Vector3.new(1,1,1),
	A.cf(K.Center.X,K.Center.Y+59.7,K.Center.Z),C.navy,nil,false)
timer.Transparency = 1
local board = Instance.new("BillboardGui")
board.Name,board.Size,board.AlwaysOnTop = "Board",UDim2.fromOffset(410,110),true
board.StudsOffsetWorldSpace = Vector3.new(0,4,0)
board.MaxDistance = 1200
board.Parent = timer
for _,data in { {"Title","METEOR CRATER",0,.45,C.gold}, {"Time","GET READY",.48,.5,C.white} } do
	local text = Instance.new("TextLabel")
	text.Name,text.Text = data[1],data[2]
	text.BackgroundTransparency = 1
	text.Position,text.Size = UDim2.fromScale(0,data[3]),UDim2.fromScale(1,data[4])
	text.Font,text.TextScaled = Enum.Font.FredokaOne,true
	text.TextColor3,text.TextStrokeColor3,text.TextStrokeTransparency = data[5],C.navy,0
	text.Parent = board
end
crater.PrimaryPart = point
local ray = RaycastParams.new()
ray.FilterType = Enum.RaycastFilterType.Include
ray.FilterDescendantsInstances = {groundGroup}
local holeFailures = {}
for _,radius in {0,opening*.2,opening*.5,opening*.75,opening-.5} do
	for k=0,7 do
		local angle=k*math.pi/4
		local origin=Vector3.new(math.cos(angle)*radius,rimY+20,math.sin(angle)*radius)+A.offset
		local hit=workspace:Raycast(origin,Vector3.new(0,floorY-rimY-30,0),ray)
		if hit then table.insert(holeFailures,{radius=radius,angle=k,part=hit.Instance.Name}) end
	end
end
assert(#holeFailures==0,"Ground collision obstructs crater hole")
A.map:SetAttribute("CraterPass",2)
return {stage="Crater",parts=A.count(A.map),floorY=A.localPosition(floor).Y+1,
	opening=opening,floorRadius=floorRadius,groundSpan=span,meteorCenterY=K.Center.Y,
	ramps=4,rampWidth=rampWidth,rampRise=rampRise,rampRun=rampRun,
	holeRayChecks=40,holeFailures=holeFailures}
