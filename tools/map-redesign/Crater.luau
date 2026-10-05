-- Run Common.luau first. Owns Ground, Crater and their collision only.
local A = assert(_G.MapRedesignArt)
local C = A.colors
local groundGroup = A.group(A.map,"Ground")
local slab = A.part(groundGroup,"Slab",Vector3.new(1020,4,1020),A.cf(0,-2,0),C.grass)
local cutter = A.part(groundGroup,"TemporaryCutter",Vector3.new(120,320,320),
	A.cf(0,-25,0)*CFrame.Angles(0,0,math.pi/2),C.stone,nil,false,Enum.PartType.Cylinder)
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
	local z0,z1 = -510+row*(1020/64), -510+(row+1)*(1020/64)
	local near = if z0<=0 and z1>=0 then 0 else math.min(math.abs(z0),math.abs(z1))
	local gap = if near<160 then math.sqrt(160^2-near^2) else 0
	if gap==0 then
		proxy("FullRow"..row,Vector3.new(1020,4,z1-z0+.03),A.cf(0,-2,(z0+z1)/2))
	else
		local width=510-gap
		for _,sign in {-1,1} do
			proxy("SideRow"..row.."_"..sign,Vector3.new(width,4,z1-z0+.03),
				A.cf(sign*(gap+width/2),-2,(z0+z1)/2))
		end
	end
end
-- This flat annulus fills the row tiles' conservative gaps at the rim.
for k=0,47 do
	local angle=k*math.pi*2/48
	proxy("RimDeck"..k,Vector3.new(27,4,34),
		A.cf(math.cos(angle)*176,-2,math.sin(angle)*176)*CFrame.Angles(0,-angle+math.pi/2,0))
end
local crater = A.group(A.map,"Crater")
local bowl = A.group(crater,"Bowl")
local floor = A.cylinder(bowl,"Floor",180,2,A.cf(0,-45,0),C.stone)
floor:SetAttribute("WalkSurface",true)
local n = 48
local fanWidth = 320*math.tan(math.pi/n)+.4
for k=0,n-1 do
	local angle = k*math.pi*2/n
	local direction = Vector3.new(math.cos(angle),0,math.sin(angle))
	A.slope(bowl,"Slope"..k, direction*90+Vector3.new(0,-44,0),
		direction*160,fanWidth,2,C.stone)
end
local ramps = A.group(crater,"AccessRamps")
for k=0,3 do
	local angle = k*math.pi/2
	local direction = Vector3.new(math.cos(angle),0,math.sin(angle))
	local ramp = A.slope(ramps,"Ramp"..(k+1),direction*89+Vector3.new(0,-43.72,0),
		direction*161+Vector3.new(0,.28,0),24,1.4,C.path)
	ramp:SetAttribute("ClearWidth",24)
	ramp:SetAttribute("Rise",44)
	ramp:SetAttribute("Run",72)
	A.part(ramps,"FloorLanding"..k,Vector3.new(26,.25,26),
		A.cf(direction.X*82,-43.87,direction.Z*82),C.path)
end
local rim = A.group(crater,"Rim")
for k=0,47 do
	local angle = (k+.5)*math.pi*2/48
	-- Leave all four cardinal approaches entirely open.
	local degrees = math.deg(angle)%90
	if degrees>7 and degrees<83 then
		A.part(rim,"StuddedRim"..k,Vector3.new(16,3,7),
			A.cf(math.cos(angle)*166,1.5,math.sin(angle)*166)*CFrame.Angles(0,-angle+math.pi/2,0),C.gold)
	end
end
-- 3,456 slot/piece/yaw bounds need Y5.3 to stay above the Y-44 floor.
local point = A.part(crater,"MeteorSpawn",Vector3.new(1,1,1),A.cf(0,5.3,0),C.ember,nil,false)
point.Transparency = 1
local active = A.group(crater,"ActiveMeteor","Folder")
local timer = A.part(crater,"SkyTimer",Vector3.new(1,1,1),A.cf(0,65,0),C.navy,nil,false)
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
for _,radius in {0,35,85,125,145} do
	for k=0,7 do
		local angle=k*math.pi/4
		local origin=Vector3.new(math.cos(angle)*radius,20,math.sin(angle)*radius)+A.offset
		local hit=workspace:Raycast(origin,Vector3.new(0,-45,0),ray)
		if hit then table.insert(holeFailures,{radius=radius,angle=k,part=hit.Instance.Name}) end
	end
end
assert(#holeFailures==0,"Ground collision obstructs crater hole")
A.map:SetAttribute("CraterPass",1)
return {stage="Crater",parts=A.count(A.map),floorY=A.localPosition(floor).Y+1,
	opening=160,ramps=4,rampWidth=24,holeRayChecks=40,holeFailures=holeFailures}
