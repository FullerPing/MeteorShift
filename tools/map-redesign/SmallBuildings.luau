-- Common first. Half-size buildings, grounded foundations and proportional mounts.
-- Baselines make reruns safe, including a partially interrupted first pass.
local A=assert(_G.MapRedesignArt)
local G=assert(A.geometry)
local target=assert(G.BuildingScale)
assert(target==.5,"Approved building scale is one half")
local town=A.map.TownSquare
local function zone(id)
	for _,v in G.Zones do if v.id==id then return v end end
	error("Missing zone "..id)
end
local entries={{"Refinery","Refinery"},{"GearHall","GearHall"},{"Hatchery","Hatchery"},
	{"TradingPost","TradingPost"},{"RebirthMonument","Rebirth"},{"IndexMuseum","Museum"}}
local shop=assert(town:FindFirstChild("PickaxeShop"))
local hall=assert(town:FindFirstChild("GearHall"))
local function baseline(model)
	assert(model:IsA("Model") and model.PrimaryPart and model:GetAttribute("MapRedesignOwned"),"Unowned landmark")
	if model:GetAttribute("BaseLandmarkModelScale")==nil then
		model:SetAttribute("BaseLandmarkModelScale",model:GetScale())
	end
	for _,mount in model:GetDescendants() do
		for _,name in {"DisplayOffset","DisplayBottomOffset","DisplayScale"} do
			local value=mount:GetAttribute(name)
			if value~=nil then
				local kind=typeof(value)
				assert((name=="DisplayOffset" and kind=="CFrame") or
					(name=="DisplayBottomOffset" and kind=="Vector3") or
					(name=="DisplayScale" and kind=="number"),"Invalid display mount")
				if mount:GetAttribute("Base"..name)==nil then mount:SetAttribute("Base"..name,value) end
			end
		end
	end
end
for _,data in entries do baseline(assert(town:FindFirstChild(data[1]))) end
baseline(shop)
if shop:GetAttribute("BaseHallRelativePivot")==nil then
	shop:SetAttribute("BaseHallRelativePivot",hall:GetPivot():ToObjectSpace(shop:GetPivot()))
end
local function scaledFrame(frame)
	return CFrame.new(frame.Position*target)*frame.Rotation
end
local function mounts(model)
	for _,v in model:GetDescendants() do
		local frame=v:GetAttribute("BaseDisplayOffset")
		local bottom=v:GetAttribute("BaseDisplayBottomOffset")
		local scale=v:GetAttribute("BaseDisplayScale")
		if frame then v:SetAttribute("DisplayOffset",scaledFrame(frame)) end
		if bottom then v:SetAttribute("DisplayBottomOffset",bottom*target) end
		if scale then v:SetAttribute("DisplayScale",scale*target) end
	end
end
local ray=RaycastParams.new()
ray.FilterType=Enum.RaycastFilterType.Include
ray.FilterDescendantsInstances={A.map.Ground,A.map.Roads}
ray.RespectCanCollide=true
local records={}
for _,data in entries do
	local model=town[data[1]]
	local z=zone(data[2])
	local hit=workspace:Raycast(Vector3.new(z.x,100,z.z)+A.offset,Vector3.new(0,-200,0),ray)
	assert(hit,"Missing landmark ground "..model.Name)
	model:ScaleTo(model:GetAttribute("BaseLandmarkModelScale")*target)
	model:PivotTo(CFrame.new(z.x,hit.Position.Y+model.PrimaryPart.Size.Y/2,z.z+A.offset.Z)*model:GetPivot().Rotation)
	mounts(model)
	model:SetAttribute("LandmarkScale",target)
	local box,size=model:GetBoundingBox()
	table.insert(records,{name=model.Name,scale=model:GetScale(),pivot=model:GetPivot().Position,
		footprint={model.PrimaryPart.Size.X,model.PrimaryPart.Size.Z},bottomY=hit.Position.Y})
end
shop:ScaleTo(shop:GetAttribute("BaseLandmarkModelScale")*target)
shop:PivotTo(hall:GetPivot()*scaledFrame(shop:GetAttribute("BaseHallRelativePivot")))
shop:SetAttribute("LandmarkScale",target)
mounts(shop)
for _,data in {{town.Refinery,"UsePoint"},{shop,"ShopPoint"},{town.TradingPost,"SellPoint"},
	{town.RebirthMonument,"RebirthPoint"},{town.IndexMuseum,"IndexPoint"}} do
	local point=assert(data[1]:FindFirstChild(data[2],true))
	assert(point:IsA("BasePart") and point.Anchored,"Missing interaction point")
	point.CFrame=CFrame.new(point.Position.X,3,point.Position.Z)*point.CFrame.Rotation
end
local use=town.Refinery.UsePoint
use.Size=Vector3.new(6,1,6)
use.Transparency,use.CanCollide,use.CanTouch,use.CanQuery=1,false,false,false
-- Spawn pads/aisles stay roomy. Resize the welcome monument and crest only.
local plaza=town.SpawnPlaza
local spawn=zone("Spawn")
local origin=A.cf(spawn.x,0,G.WelcomeZ)
local welcomeNames={WelcomePillar=true,PillarStud=true,WelcomeSign=true,WelcomeBacking=true,
	HeaderStud=true,CrestSupport=true,HeroMeteor=true,CrestVein=true,CrestTrail=true}
for _,p in plaza:GetDescendants() do
	if p:IsA("BasePart") and welcomeNames[p.Name] then
		if p:GetAttribute("BaseWelcomeSize")==nil then
			p:SetAttribute("BaseWelcomeSize",p.Size)
			p:SetAttribute("BaseWelcomeFrame",origin:ToObjectSpace(p.CFrame))
		end
		p.Size=p:GetAttribute("BaseWelcomeSize")*target
		p.CFrame=origin*scaledFrame(p:GetAttribute("BaseWelcomeFrame"))
	end
end
plaza:SetAttribute("WelcomeScale",target)
A.map:SetAttribute("SmallBuildingsPass",1)
assert(A.count(A.map)<=1800,"Map budget")
return{stage="SmallBuildings",buildings=records,shopScale=shop:GetScale(),welcomeScale=target,
	usePoint=use.Position,usePointSize=use.Size,mountAttributesScaled=true,spawnsUnchanged=true,
	parts=A.count(A.map),rerunnable=true}
