-- Common first. Builds one shared landmark inside staged TownSquare.
local A=assert(_G.MapRedesignArt)
local C=A.colors
local town=A.ensure(A.map,"TownSquare")
local refinery=A.group(town,"Refinery")
refinery:SetAttribute("SharedRefinery",true)
local ray=RaycastParams.new()
ray.FilterType=Enum.RaycastFilterType.Include
ray.FilterDescendantsInstances={A.map.Ground,A.map.Roads}
local ground=workspace:Raycast(Vector3.new(0,180,2620),Vector3.new(0,-300,0),ray)
assert(ground,"No refinery ground")
local y=ground.Position.Y
local function cf(x,height,z) return A.cf(x,y+height,z) end
local base=A.part(refinery,"Foundation",Vector3.new(76,1.6,64),cf(0,.8,-380),C.navy)
refinery.PrimaryPart=base
A.part(refinery,"SmelterHousing",Vector3.new(66,36,42),cf(0,19.6,-384),C.stone,Enum.Material.Metal)
A.part(refinery,"Roof",Vector3.new(72,5,50),cf(0,40,-384),C.ember)
for _,x in {-34,34} do
	for _,z in {-407,-361} do
		A.part(refinery,"CornerStrap",Vector3.new(4,38,4),cf(x,20.6,z),C.cream,Enum.Material.Metal)
	end
end
for _,height in {5,34} do
	A.part(refinery,"FrontBand",Vector3.new(68,2,2),cf(0,height,-361),C.ember,Enum.Material.Metal)
end
local templates=assert((_G.MapRedesignBackup and _G.MapRedesignBackup.assets or game.ServerStorage.Assets):FindFirstChild("PlotStations"))
local function component(sourceName,name,scale,position,keep)
	local original=assert(templates:FindFirstChild(sourceName))
	local copy=original:Clone()
	copy.Name=name
	copy:SetAttribute("StationId",nil)
	for _,v in copy:GetDescendants() do
		if v:IsA("LuaSourceContainer") or v:IsA("ProximityPrompt") or v:IsA("BillboardGui")
			or v:IsA("ParticleEmitter") or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Light") then
			v:Destroy()
		elseif v:IsA("BasePart") then
			if keep and not keep[v.Name] then v:Destroy()
			else
				v.Anchored=true
				v.CanCollide,v.CanTouch,v.CanQuery=false,false,false
				v.CastShadow=false
				if v.Name=="Intake" or v.Name=="Upgrade" or v.Name=="ManageRefinery" then v.Name="FeedDeck" end
			end
		end
	end
	copy:SetAttribute("MapRedesignOwned",true)
	copy:ScaleTo(scale)
	local box=copy:GetBoundingBox()
	local pivot=copy:GetPivot()
	copy:PivotTo(position*box:ToObjectSpace(pivot))
	copy.Parent=refinery
	return copy
end
component("Refinery","FurnaceAssembly",2.8,cf(12,26,-372)*CFrame.Angles(0,math.pi,0))
component("Hopper","OreHopper",2.3,cf(-23,51,-381)*CFrame.Angles(0,math.pi,0),
	{Body=true,Leg=true,Funnel=true,Chute=true,Ore=true})
component("Conveyor","FeedConveyor",1.6,cf(-21,17,-372)*CFrame.Angles(0,math.pi/2,0),
	{Belt=true,Rail=true,Roller=true,Leg=true,BeltDriveMotor=true,MotorBracket=true,SupportRoller=true,BeltCrossBrace=true,FlowStripe=true})
for k=0,5 do
	A.part(refinery,"VisibleOre"..k,Vector3.new(3,2.5,3),
		cf(-34+k*4.2,20,-370)*CFrame.Angles(0,math.rad(k*23),math.rad(12)),
		if k%2==0 then C.gold else C.ember,Enum.Material.Basalt,false)
end
local chimney=A.part(refinery,"Chimney",Vector3.new(10,40,10),cf(24,62,-397),C.navy,Enum.Material.Metal)
for _,height in {45,58,72} do
	A.part(refinery,"ChimneyBand",Vector3.new(12,2.2,12),cf(24,height,-397),C.ember,Enum.Material.Metal)
end
local cap=A.part(refinery,"ChimneyCap",Vector3.new(14,2.5,14),cf(24,83.25,-397),C.steel,Enum.Material.Metal)
local smoke=Instance.new("ParticleEmitter")
smoke.Name="ChimneySmoke"
smoke.Texture="rbxasset://textures/particles/smoke_main.dds"
smoke.Color=ColorSequence.new(Color3.fromRGB(74,89,110))
smoke.Size=NumberSequence.new(3,8)
smoke.Transparency=NumberSequence.new(.7,1)
smoke.Rate,smoke.Lifetime,smoke.Speed=4,NumberRange.new(2,4),NumberRange.new(4,7)
smoke.Acceleration=Vector3.new(2,2,0)
smoke.Parent=cap
for _,x in {9,15} do
	local glow=A.part(refinery,"FurnaceGlow",Vector3.new(3,10,1),cf(x,19,-352),C.ember,Enum.Material.Neon,false)
	local light=Instance.new("PointLight")
	light.Name="WarmGlow"
	light.Color,light.Range,light.Brightness,light.Shadows=C.ember,26,1.2,false
	light.Parent=glow
end
for row=0,2 do
	for column=0,4 do
		A.cylinder(refinery,"RoofStud",3.5,1.2,cf(-24+column*12,43.1,-397+row*13),C.ember,nil,false)
	end
end
A.sign(refinery,"RefinerySign","REFINERY",Vector3.new(62,10,2),
	cf(0,42,-349)*CFrame.Angles(0,math.pi,0),C.navy)
for _,x in {-28,28} do
	A.part(refinery,"SignBracket",Vector3.new(3,3,14),cf(x,42,-355),C.cream,Enum.Material.Metal,false)
end
A.sign(refinery,"ServiceSign","DEPOSIT ORE  •  CLAIM BARS",Vector3.new(48,4,1),
	cf(0,11,-351)*CFrame.Angles(0,math.pi,0),C.ember)
for _,x in {-20,20} do
	A.part(refinery,"ServiceBracket",Vector3.new(3,2,11),cf(x,11,-357),C.cream,Enum.Material.Metal,false)
end
local front=workspace:Raycast(Vector3.new(0,80,2657),Vector3.new(0,-150,0),ray)
assert(front,"No walkable refinery front")
local point=A.part(refinery,"UsePoint",Vector3.new(6,1,6),A.cf(0,front.Position.Y+3,-343),C.gold,nil,false)
point.Transparency=1
point.CanCollide,point.CanTouch,point.CanQuery=false,false,false
local forbidden,points={},0
for _,v in refinery:GetDescendants() do
	if v:IsA("BasePart") then
		assert(v.Anchored,"Unanchored refinery part")
		if v.Name=="UsePoint" then points+=1 end
	end
	if v:IsA("LuaSourceContainer") or v:IsA("ProximityPrompt") or v:IsA("Humanoid")
		or v.Name=="Intake" or v.Name=="Upgrade" or v.Name=="ManageRefinery" then table.insert(forbidden,v:GetFullName()) end
end
assert(points==1 and #forbidden==0,"Refinery contract failed")
assert(A.count(refinery)<=180,"Refinery part budget exceeded")
-- UsePoint intentionally sits in the forecourt. Measure visible geometry separately.
local frontZ=-math.huge
for _,p in refinery:GetDescendants() do
	if p:IsA("BasePart") and p.Transparency<1 then
		for _,sx in {-1,1} do for _,sy in {-1,1} do for _,sz in {-1,1} do
			local corner=p.CFrame*Vector3.new(sx*p.Size.X/2,sy*p.Size.Y/2,sz*p.Size.Z/2)
			frontZ=math.max(frontZ,corner.Z-A.offset.Z)
		end end end
	end
end
local nearest=-frontZ
assert(nearest>=348-.001,"Refinery visible geometry crosses its footprint")
assert((point.Position-A.offset).Magnitude>314,"UsePoint inside effect extent")
A.map:SetAttribute("RefineryPass",1)
return {stage="Refinery",parts=A.count(refinery),groundY=y,usePoint={0,front.Position.Y+3,-343},
	nearestFootprint=nearest,reused={"Hopper","Conveyor","Refinery"},prompts=0,scripts=0,totalParts=A.count(A.map)}
