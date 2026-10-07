-- Common first. Repairs art issues observed in the first partial screenshot set.
local A=assert(_G.MapRedesignArt)
local C=A.colors
local town=A.map.TownSquare
local refinery=town.Refinery
-- Resolve polish from each landmark's actual centre. Re-running this stage
-- after compaction must not send its children back to the earlier large layout.
local refineryCentre=A.localPosition(assert(refinery.PrimaryPart))
local refineryScale=refinery:GetAttribute("LandmarkScale") or 1
local hall=town.GearHall
local hallCentre=A.localPosition(assert(hall.PrimaryPart))
local hallScale=hall:GetAttribute("LandmarkScale") or 1
local function refineryFrame(x,y,z)
	return A.cf(x*refineryScale+refineryCentre.X,y*refineryScale,(z+380)*refineryScale+refineryCentre.Z)
end
local function hallFrame(x,y,z)
	return A.cf((x-140)*hallScale+hallCentre.X,y*hallScale,(z+380)*hallScale+hallCentre.Z)
end
local facade=A.group(refinery,"FrontPolish")
A.part(facade,"FurnaceWindow",Vector3.new(22,18,.6)*refineryScale,refineryFrame(12,21,-352),C.ember,Enum.Material.Neon,false)
for _,x in {-1,25} do
	A.part(facade,"WindowSide",Vector3.new(2.6,22,2.8)*refineryScale,refineryFrame(x,21,-351.8),C.steel,Enum.Material.Metal,false)
end
for _,y in {10,32} do
	A.part(facade,"WindowCrosspiece",Vector3.new(28,2.6,2.8)*refineryScale,refineryFrame(12,y,-351.8),C.steel,Enum.Material.Metal,false)
end
for x=3,23,4 do
	A.part(facade,"FurnaceGrille",Vector3.new(1,18,1.2)*refineryScale,refineryFrame(x,21,-351.5),C.navy,Enum.Material.Metal,false)
end
-- Use the actual bounds of the reused conveyor; expose it without crossing the footprint.
local conveyor=refinery.FeedConveyor
local targetFront=A.offset.Z+refineryCentre.Z+31.6*refineryScale
local currentFront=-math.huge
for _,part in conveyor:GetDescendants() do
	if part:IsA("BasePart") then
		for _,sx in {-1,1} do for _,sy in {-1,1} do for _,sz in {-1,1} do
			local corner=part.CFrame*Vector3.new(sx*part.Size.X/2,sy*part.Size.Y/2,sz*part.Size.Z/2)
			currentFront=math.max(currentFront,corner.Z)
		end end end
	end
end
assert(currentFront>-math.huge,"Conveyor parts missing")
local delta=targetFront-currentFront
conveyor:PivotTo(conveyor:GetPivot()+Vector3.new(0,0,delta))
local service=refinery.ServiceSign
service.Size=Vector3.new(50,5,1)*refineryScale
service.CFrame=refineryFrame(0,7,-351)*CFrame.Angles(0,math.pi,0)
for _,v in refinery:GetChildren() do
	if v.Name=="ServiceBracket" then v.CFrame=A.cf(v.Position.X-A.offset.X,7*refineryScale,refineryCentre.Z+23*refineryScale) end
end
for _,stand in hall.CurrentStands:GetChildren() do
	local board=stand.StatsBoard
	board.Size=Vector3.new(18,4,.6)*hallScale
	board.CFrame=A.cf(stand:GetPivot().Position.X-A.offset.X,2.9*hallScale,hallCentre.Z+23.5*hallScale)*CFrame.Angles(0,math.pi,0)
end
for _,card in hall.TierWalls:GetChildren() do
	local kind,tier=card:GetAttribute("EquipmentKind"),card:GetAttribute("EquipmentTier")
	local x=(if kind=="pickaxe" then 100 else 146)+((tier-1)%4)*11
	local localOffset=card:GetAttribute("DisplayOffset")
	card.Size=Vector3.new(10.5,14.5,.6)*hallScale
	card.CFrame=A.cf((x-140)*hallScale+hallCentre.X,card.Position.Y-A.offset.Y,hallCentre.Z-31.6*hallScale)
	card:SetAttribute("DisplayOffset",localOffset)
end
local fill=A.group(hall,"DisplayLighting")
for _,x in {116,164} do
	local fixture=A.part(fill,"FillFixture",Vector3.new(4,1,4)*hallScale,hallFrame(x,41,-379),C.cream,Enum.Material.Neon,false)
	local light=Instance.new("PointLight")
	light.Color,light.Range,light.Brightness,light.Shadows=C.cream,62*hallScale,1.4,false
	light.Parent=fixture
end
local signs=0
for _,v in A.map:GetDescendants() do
	if v:IsA("SurfaceGui") and v.Name=="Lettering" and v.Parent:IsA("BasePart")
		and v.Parent.Name~="OddsBoard" then
		local size=v.Parent.Size
		v.CanvasSize=Vector2.new(math.max(120,math.round(size.X*10)),math.max(40,math.round(size.Y*10)))
		signs+=1
	end
end
assert(A.count(refinery)<=180,"Refinery budget")
local equipmentPreview=hall:FindFirstChild("EquipmentArtPreview")
local equipmentPreviewParts=if equipmentPreview then A.count(equipmentPreview) else 0
assert(A.count(hall)-equipmentPreviewParts+A.count(town.PickaxeShop)<=100,"Gear Hall authored-art budget")
A.map:SetAttribute("PolishPass1",true)
return {worldSignsAdjusted=signs,refineryParts=A.count(refinery),temporaryPreviewsMayBePresent=true,
	newFillLights=2,gameplayOrGUIControllersChanged=false}
