-- Common first. Compact roads terminate at the crater rim and full-size landmarks.
local A=assert(_G.MapRedesignArt)
local C,G=A.colors,assert(A.geometry)
local crater=assert(A.crater)
assert(G.BoundaryHalf==270,"Compact geometry must be synced")
local function zone(id)
	for _,value in G.Zones do if value.id==id then return value end end
	error("Unknown zone "..id)
end
local roads=A.group(A.map,"Roads")
local function road(name,a,b,width)
	assert(width>=14,"Road below fourteen studs")
	a,b=Vector3.new(a[1],.38,a[2]),Vector3.new(b[1],.38,b[2])
	local p=A.slope(roads,name,a,b,width,.4,C.path)
	p:SetAttribute("ClearWidth",width)
	return p
end
local loopRadius=assert(G.LoopRadius)
local segments=64
-- LoopRadius is the segment centre/apothem, keeping its inner edge at125.
local vertexRadius=loopRadius/math.cos(math.pi/segments)
for k=0,segments-1 do
	local a,b=k*math.pi*2/segments,(k+1)*math.pi*2/segments
	road("Loop"..k,{math.cos(a)*vertexRadius,math.sin(a)*vertexRadius},
		{math.cos(b)*vertexRadius,math.sin(b)*vertexRadius},G.PathWidth)
end
for k=0,3 do
	local angle=k*math.pi/2
	road("CraterApproach"..k,{math.cos(angle)*crater.OpeningRadius,math.sin(angle)*crater.OpeningRadius},
		{math.cos(angle)*vertexRadius,math.sin(angle)*vertexRadius},G.MainPathWidth)
end
local spawnZone,trading=zone("Spawn"),zone("TradingPost")
local avenueZ,spineX,branchZ=G.TownAvenueZ,G.TownSpineX,G.TradingBranchZ
local avenueHalf=G.BoundaryHalf-55
road("TownAvenue",{-avenueHalf,avenueZ},{avenueHalf,avenueZ},G.PathWidth)
road("SpawnEgress",{spawnZone.x,spawnZone.z},{spineX,spawnZone.entrance.Z},G.MainPathWidth)
road("TownSpine",{spineX,spawnZone.entrance.Z},{spineX,avenueZ},G.MainPathWidth)
road("TradingBranch",{spineX,branchZ},{trading.entrance.X,branchZ},trading.pathWidth)
road("TradingEntrance",{trading.entrance.X,branchZ},{trading.entrance.X,trading.entrance.Z},trading.pathWidth)
for _,data in {{"HatcheryEntrance","Hatchery"},{"GearEntrance","GearHall"},{"RefineryEntrance","Refinery"}} do
	local target=zone(data[2])
	road(data[1],{target.entrance.X,target.entrance.Z},{target.entrance.X,avenueZ},target.pathWidth)
end
for _,data in {{"RebirthEntrance","Rebirth"},{"MuseumEntrance","Museum"},
	{"VioletEntrance","VioletQuarry"},{"SulfurEntrance","SulfurRidge"}} do
	local target=zone(data[2])
	local x=(if target.entrance.X<0 then -1 else 1)*math.sqrt(vertexRadius^2-target.entrance.Z^2)
	road(data[1],{target.entrance.X,target.entrance.Z},{x,target.entrance.Z},target.pathWidth)
end
for _,data in {{"RustEntrance","RustWorks"},{"FrostEntrance","FrostYard"}} do
	local target=zone(data[2])
	local direction=Vector2.new(target.entrance.X,target.entrance.Z).Unit
	road(data[1],{target.entrance.X,target.entrance.Z},{direction.X*vertexRadius,direction.Y*vertexRadius},target.pathWidth)
end
local town=A.ensure(A.map,"TownSquare")
local plaza=A.group(town,"SpawnPlaza")
A.part(plaza,"Plaza",Vector3.new(spawnZone.width,.6,spawnZone.depth),A.cf(spawnZone.x,.3,spawnZone.z),C.cyan)
for index=1,6 do
	local name=if index==1 then "Spawn" else "SpawnPad"..index
	local old=town:FindFirstChild(name)
	if old then assert(old:GetAttribute("MapRedesignOwned"));old:Destroy() end
	local spawn=Instance.new("SpawnLocation")
	spawn.Name=name
	spawn.Size=Vector3.new(12,1,12)
	local x=spawnZone.x-26+((index-1)%3)*26
	local z=G.SpawnRowsZ[math.floor((index-1)/3)+1]
	spawn.CFrame=A.cf(x,1.1,z)
	spawn.Anchored,spawn.Neutral,spawn.Enabled=true,true,false
	spawn:SetAttribute("StagedSpawn",true)
	spawn.Duration=0
	spawn.Color=C.cream
	spawn.Material=Enum.Material.SmoothPlastic
	spawn.TopSurface=Enum.SurfaceType.Studs
	spawn.CanTouch=false
	spawn:SetAttribute("MapRedesignOwned",true)
	spawn:SetAttribute("SpawnIndex",index)
	spawn.Parent=town
end
local welcomeZ=G.WelcomeZ
for _,x in {spawnZone.x-45,spawnZone.x+45} do
	A.part(plaza,"WelcomePillar",Vector3.new(5,20,5),A.cf(x,10,welcomeZ),C.navy)
	A.cylinder(plaza,"PillarStud",7,1.4,A.cf(x,20.7,welcomeZ),C.gold,nil,false)
end
A.sign(plaza,"WelcomeSign","METEORSHIFT",Vector3.new(94,9,3),
	A.cf(spawnZone.x,20,welcomeZ)*CFrame.Angles(0,math.pi,0),C.cyan)
local function insideBounds(parent)
	for _,part in parent:GetDescendants() do if part:IsA("BasePart") then
		for _,sx in {-1,1} do for _,sy in {-1,1} do for _,sz in {-1,1} do
			local corner=part.CFrame*Vector3.new(sx*part.Size.X/2,sy*part.Size.Y/2,sz*part.Size.Z/2)-A.offset
			assert(math.abs(corner.X)<=G.BoundaryHalf+.001 and math.abs(corner.Z)<=G.BoundaryHalf+.001,"Path/spawn crossed boundary")
		end end end
	end end
end
insideBounds(roads);insideBounds(plaza)
local boundary=A.group(A.map,"Boundary")
local half=G.BoundaryHalf
local wallHeight,wallThickness,wallBottom=28,16,-4
local wallTop=wallBottom+wallHeight
for _,sign in {-1,1} do
	A.part(boundary,"EastWestWall"..sign,Vector3.new(wallThickness,wallHeight,half*2+wallThickness*2),
		A.cf(sign*(half+wallThickness/2),wallBottom+wallHeight/2,0),C.stone)
	A.part(boundary,"NorthSouthWall"..sign,Vector3.new(half*2+wallThickness*2,wallHeight,wallThickness),
		A.cf(0,wallBottom+wallHeight/2,sign*(half+wallThickness/2)),C.stone)
end
for side=0,3 do
	for index=0,15 do
		local coordinate=-half+20+index*((half*2-40)/15)
		local x=if side<2 then (if side==0 then -half-30 else half+30) else coordinate
		local z=if side<2 then coordinate else (if side==2 then -half-30 else half+30)
		local height=14+(index%3)*4
		local cliff=A.part(boundary,"Cliff"..side.."_"..index,Vector3.new(32,height,32),
			A.cf(x,wallTop+height/2,z)*CFrame.Angles(0,math.rad((index%3-1)*9),0),
			if index%3==0 then C.grass else C.stone)
		for _,sx in {-1,1} do for _,sz in {-1,1} do
			local corner=cliff.CFrame*Vector3.new(sx*16,0,sz*16)-A.offset
			assert((if side<2 then math.abs(corner.X) else math.abs(corner.Z))>=half,"Cliff intrudes into compact play area")
		end end
	end
end
local kill=A.part(boundary,"KillPlane",Vector3.new(half*2+180,1,half*2+180),A.cf(0,G.KillPlaneY,0),C.navy,nil,false)
kill.Transparency,kill.CanTouch=1,true
kill:SetAttribute("BoundaryKillPlane",true)
boundary:SetAttribute("WallHeight",wallHeight)
boundary:SetAttribute("CliffMaximumY",wallTop+22)
A.map:SetAttribute("SmallBoundaryVersion",1)
A.ensure(A.map,"Atmosphere")
assert(A.count(A.map)<=1800,"Map budget")
A.map:SetAttribute("RoutesPass",2)
return {stage="Routes",parts=A.count(A.map),roads=A.count(roads),spawns=6,pathMinimum=14,
	loopRadius=loopRadius,loopInnerRadius=loopRadius-G.PathWidth/2,boundaryHalf=half,boundaryHeight=wallHeight}
