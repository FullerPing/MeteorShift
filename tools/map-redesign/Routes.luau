-- Common first. Paths terminate at the crater rim and building entrances.
local A=assert(_G.MapRedesignArt)
local C=A.colors
local roads=A.group(A.map,"Roads")
local function road(name,a,b,width)
	a,b=Vector3.new(a[1],.38,a[2]),Vector3.new(b[1],.38,b[2])
	local p=A.slope(roads,name,a,b,width,.4,C.path)
	p:SetAttribute("ClearWidth",width)
	return p
end
for k=0,63 do
	local a,b=k*math.pi*2/64,(k+1)*math.pi*2/64
	road("Loop"..k,{math.cos(a)*320,math.sin(a)*320},{math.cos(b)*320,math.sin(b)*320},18)
end
for k=0,3 do
	local angle=k*math.pi/2
	road("CraterApproach"..k,{math.cos(angle)*160,math.sin(angle)*160},
		{math.cos(angle)*320,math.sin(angle)*320},24)
end
road("TownAvenue",{-230,-326},{230,-326},18)
road("SpawnEgress",{-20,-458},{-65,-435},24)
road("TownSpine",{-65,-435},{-65,-326},24)
road("TradingBranch",{-65,-430},{70,-430},18)
road("HatcheryEntrance",{-155,-340},{-155,-326},18)
road("GearEntrance",{140,-341},{140,-326},18)
road("RebirthEntrance",{-325,-160},{-277,-160},18)
road("MuseumEntrance",{316,-160},{277,-160},18)
road("RustEntrance",{-275,224},{-233,219},18)
road("FrostEntrance",{275,224},{233,219},18)
road("VioletEntrance",{-341,55},{-314,55},18)
road("SulfurEntrance",{341,55},{314,55},18)
local town=A.ensure(A.map,"TownSquare")
local plaza=A.group(town,"SpawnPlaza")
A.part(plaza,"Plaza",Vector3.new(96,.6,64),A.cf(-20,.3,-458),C.cyan)
for index=1,6 do
	local name=if index==1 then "Spawn" else "SpawnPad"..index
	local old=town:FindFirstChild(name)
	if old then assert(old:GetAttribute("MapRedesignOwned"));old:Destroy() end
	local spawn=Instance.new("SpawnLocation")
	spawn.Name=name
	spawn.Size=Vector3.new(12,1,12)
	local x=-46+((index-1)%3)*26
	local z=-472+math.floor((index-1)/3)*28
	spawn.CFrame=A.cf(x,1.1,z)
	-- Isolate staged spawn pads until staged runtime QA explicitly activates them.
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
-- Portal-like welcome monument sits behind the spawn pads.
for _,x in {-65,25} do
	A.part(plaza,"WelcomePillar",Vector3.new(5,20,5),A.cf(x,10,-494),C.navy)
	A.cylinder(plaza,"PillarStud",7,1.4,A.cf(x,20.7,-494),C.gold,nil,false)
end
A.sign(plaza,"WelcomeSign","METEORSHIFT",Vector3.new(94,9,3),
	A.cf(-20,20,-494)*CFrame.Angles(0,math.pi,0),C.cyan)
local boundary=A.group(A.map,"Boundary")
for _,sign in {-1,1} do
	A.part(boundary,"EastWestWall"..sign,Vector3.new(24,80,1068),A.cf(sign*522,36,0),C.stone)
	A.part(boundary,"NorthSouthWall"..sign,Vector3.new(1068,80,24),A.cf(0,36,sign*522),C.stone)
end
for side=0,3 do
	for index=0,15 do
		local coordinate=-490+index*(980/15)
		local x=if side<2 then (if side==0 then -525 else 525) else coordinate
		local z=if side<2 then coordinate else (if side==2 then -525 else 525)
		local height=42+(index%3)*10
		A.part(boundary,"Cliff"..side.."_"..index,Vector3.new(48,height,48),
			A.cf(x,76+height/2,z)*CFrame.Angles(0,math.rad((index%3-1)*9),0),
			if index%3==0 then C.grass else C.stone)
	end
end
local kill=A.part(boundary,"KillPlane",Vector3.new(1200,1,1200),A.cf(0,-70,0),C.navy,nil,false)
kill.Transparency,kill.CanTouch=true and 1,true
kill:SetAttribute("BoundaryKillPlane",true)
A.ensure(A.map,"Atmosphere")
A.map:SetAttribute("RoutesPass",1)
return {stage="Routes",parts=A.count(A.map),roads=A.count(roads),spawns=6,pathMinimum=18,boundaryHeight=80}
