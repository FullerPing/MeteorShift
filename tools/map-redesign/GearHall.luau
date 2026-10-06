-- Common first. World art only; local equipment and live stats are a later controller.
local A=assert(_G.MapRedesignArt)
local C=A.colors
local Config=require(game.ReplicatedStorage.Shared.Config)
local town=A.ensure(A.map,"TownSquare")
local hall=A.group(town,"GearHall")
local floor=A.part(hall,"Floor",Vector3.new(100,1.2,72),A.cf(140,.6,-380),C.navy)
hall.PrimaryPart=floor
A.part(hall,"RearWall",Vector3.new(100,42,4),A.cf(140,22.2,-414),C.cyan)
for _,x in {92,188} do
	A.part(hall,"SideWall",Vector3.new(4,42,72),A.cf(x,22.2,-380),C.cyan)
	A.part(hall,"FrontPillar",Vector3.new(7,44,7),A.cf(x,23.2,-346),C.cream)
end
A.part(hall,"Roof",Vector3.new(100,4,72),A.cf(140,45.2,-380),C.cyan)
A.part(hall,"FrontBeam",Vector3.new(100,5,4),A.cf(140,40,-345),C.cream)
A.sign(hall,"HallSign","GEAR HALL",Vector3.new(72,11,2),
	A.cf(140,42,-343)*CFrame.Angles(0,math.pi,0),C.navy)
-- The two categories share a stable, Config-generated display contract.
local walls=A.group(hall,"TierWalls")
local rowPositions={12,28}
for _,kind in {"pickaxe","backpack"} do
	local catalog=if kind=="pickaxe" then Config.Pickaxes else Config.Backpacks
	local firstX=if kind=="pickaxe" then 100 else 146
	assert(#catalog==8,"Tier wall requires all eight Config tiers")
	for tier,item in catalog do
		local row=math.floor((tier-1)/4)+1
		local x=firstX+((tier-1)%4)*11
		local card=A.part(walls,kind..tier,Vector3.new(10.5,14.5,.6),
			A.cf(x,rowPositions[row],-411.6),C.navy,nil,false)
		card:SetAttribute("EquipmentKind",kind)
		card:SetAttribute("EquipmentTier",tier)
		card:SetAttribute("DisplayOffset",card.CFrame:ToObjectSpace(
			A.cf(x,rowPositions[row]+1,-407.7)*CFrame.Angles(0,math.pi,0)))
		card:SetAttribute("DisplayScale",1.5)
		local gui=Instance.new("SurfaceGui")
		gui.Name="TierLabel"
		gui.Face=Enum.NormalId.Back
		gui.CanvasSize=Vector2.new(440,580)
		gui.LightInfluence=0
		gui.Parent=card
		for _,data in {
			{"Name",item.Name,.74,.14,C.white},
			{"Tier","TIER "..tier,.02,.10,item.Color or C.violet},
			{"Status","",.89,.09,C.gold},
		} do
			local label=Instance.new("TextLabel")
			label.Name=data[1]
			label.Text=data[2]
			label.Position=UDim2.fromScale(.03,data[3])
			label.Size=UDim2.fromScale(.94,data[4])
			label.BackgroundTransparency=1
			label.Font=Enum.Font.FredokaOne
			label.TextScaled=true
			label.TextColor3=data[5]
			label.TextStrokeColor3=C.navy
			label.TextStrokeTransparency=0
			label.Parent=gui
		end
	end
end
A.sign(hall,"PickaxeWallTitle","PICKAXES",Vector3.new(46,4,1),
	A.cf(116,40,-411)*CFrame.Angles(0,math.pi,0),C.navy)
A.sign(hall,"BackpackWallTitle","BACKPACKS",Vector3.new(46,4,1),
	A.cf(164,40,-411)*CFrame.Angles(0,math.pi,0),C.navy)
local stands=A.group(hall,"CurrentStands")
for _,data in {{"pickaxe",116,C.gold},{"backpack",164,C.violet}} do
	local stand=A.group(stands,data[1])
	stand:SetAttribute("EquipmentKind",data[1])
	stand:SetAttribute("DisplayScale",2.2)
	local foot=A.cylinder(stand,"Foot",16,1,A.cf(data[2],1.7,-365),C.cream)
	stand.PrimaryPart=foot
	stand:SetAttribute("DisplayOffset",stand:GetPivot():ToObjectSpace(
		A.cf(data[2],12.5,-365)*CFrame.Angles(0,math.pi,0)))
	stand:SetAttribute("DisplayBottomOffset",stand:GetPivot():PointToObjectSpace(A.cf(data[2],6,-365).Position))
	A.cylinder(stand,"Pedestal",12,3,A.cf(data[2],3.7,-365),C.navy)
	A.cylinder(stand,"Top",14,.8,A.cf(data[2],5.6,-365),data[3])
	local _,label=A.sign(stand,"StatsBoard","YOUR "..string.upper(data[1]),Vector3.new(18,4,.6),
		A.cf(data[2],2.9,-356.5)*CFrame.Angles(0,math.pi,0),C.navy)
	label.Name="Stats"
	label.TextWrapped=true
end
-- Direct TownSquare child matches the existing server's lookup.
local counter=A.group(town,"PickaxeShop")
local top=A.part(counter,"Counter",Vector3.new(24,5,7),A.cf(140,3.7,-394),C.cream)
counter.PrimaryPart=top
A.part(counter,"CounterTop",Vector3.new(26,1,9),A.cf(140,6.7,-394),C.gold)
A.sign(counter,"CounterSign","UPGRADE YOUR GEAR",Vector3.new(22,4,.6),
	A.cf(140,4,-390.3)*CFrame.Angles(0,math.pi,0),C.navy)
local point=A.part(counter,"ShopPoint",Vector3.new(6,1,6),A.cf(140,4.2,-384),C.gold,nil,false)
point.Transparency=1
for row=0,2 do for col=0,6 do
	A.cylinder(hall,"RoofStud",4,1.2,A.cf(104+col*12,47.8,-400+row*20),C.cyan,nil,false)
end end
-- A simple oversized pickaxe silhouette identifies the building from the loop.
A.part(hall,"LandmarkHandle",Vector3.new(5,34,5),
	A.cf(140,62,-382)*CFrame.Angles(0,0,math.rad(-24)),C.cream,nil,false)
A.part(hall,"LandmarkHead",Vector3.new(38,7,8),
	A.cf(147,77,-382)*CFrame.Angles(0,0,math.rad(-24)),C.gold,nil,false)
for _,x in {130,164} do
	A.part(hall,"LandmarkPoint",Vector3.new(8,14,8),
		A.cf(x,74,-382)*CFrame.Angles(0,0,math.rad(if x==130 then -60 else 60)),C.gold,nil,false,"Wedge")
end
assert(#walls:GetChildren()==16,"Missing tier cards")
assert(#stands:GetChildren()==2,"Missing current stands")
assert(A.count(hall)+A.count(counter)<=100,"Gear Hall art budget")
A.map:SetAttribute("GearHallPass",1)
return {stage="GearHall",artParts=A.count(hall)+A.count(counter),tierCards=16,currentStands=2,
	localModelsPending=true,shopPoint={140,4.2,-384},totalParts=A.count(A.map)}
