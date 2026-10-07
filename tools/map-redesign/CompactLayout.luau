-- Common first. Translates existing landmark art; never scales or replaces it.
local A=assert(_G.MapRedesignArt)
local G=assert(A.geometry,"Run the geometry-aware Common first")
assert(G.BoundaryHalf==270,"Compact WorldGeometry must be synced before migration")
local town=assert(A.map:FindFirstChild("TownSquare"))
local fields=assert(A.map:FindFirstChild("DebrisFields"))
local debris=assert(A.map:FindFirstChild("Debris"))
local function zone(id)
	for _,value in G.Zones do if value.id==id then return value end end
	error("Missing compact zone "..id)
end
local names={
	{"Refinery","Refinery"},{"GearHall","GearHall"},{"Hatchery","Hatchery"},
	{"TradingPost","TradingPost"},{"RebirthMonument","Rebirth"},{"IndexMuseum","Museum"},
}
local models,originalSizes={},{}
local function remember(model)
	assert(model and model:IsA("Model") and model.PrimaryPart,"Missing landmark primary part")
	assert(model:GetAttribute("MapRedesignOwned"),"Unowned landmark")
	for _,part in model:GetDescendants() do
		if part:IsA("BasePart") then
			assert(part.Anchored,"Unanchored landmark art")
			originalSizes[part]=part.Size
		end
	end
	return model
end
for _,data in names do table.insert(models,{remember(town:FindFirstChild(data[1])),zone(data[2])}) end
local shop=remember(town:FindFirstChild("PickaxeShop"))
local fieldModels,rocks={},{}
for _,field in fields:GetChildren() do
	local target=zone(field.Name)
	fieldModels[field.Name]=remember(field)
	assert(typeof(target.entrance)=="Vector3","Missing field entrance")
	rocks[field.Name]={}
end
for _,rock in debris:GetChildren() do
	assert(rock:IsA("BasePart") and rock.Anchored,"Invalid direct debris root")
	local list=assert(rocks[rock:GetAttribute("Field")],"Unknown debris field")
	table.insert(list,rock)
	originalSizes[rock]=rock.Size
	for _,part in rock:GetDescendants() do if part:IsA("BasePart") then originalSizes[part]=part.Size end end
end
for _,list in rocks do assert(#list==12,"Every field must retain twelve rocks") end
local beforeParts=A.count(A.map)
local moved={}
local function deltaTo(model,target)
	local position=A.localPosition(model.PrimaryPart)
	return Vector3.new(target.x-position.X,0,target.z-position.Z)
end
local function translate(model,delta)
	if delta.Magnitude>1e-5 then model:PivotTo(model:GetPivot()+delta) end
end
for _,data in models do
	local model,target=data[1],data[2]
	local delta=deltaTo(model,target)
	translate(model,delta)
	if target.id=="GearHall" then
		-- Counter is a separate direct TownSquare child, not inside GearHall.
		local point=assert(shop:FindFirstChild("ShopPoint"))
		local position=A.localPosition(point)
		local scale=model:GetAttribute("LandmarkScale") or 1
		translate(shop,Vector3.new(target.x-position.X,0,target.z-4*scale-position.Z))
	end
	table.insert(moved,{zone=target.id,delta={delta.X,delta.Y,delta.Z}})
end
for name,field in fieldModels do
	local target=zone(name)
	translate(field,deltaTo(field,target))
	field:SetAttribute("Entrance",target.entrance)
	-- Loose rocks are direct Debris children. Their measured centre makes reruns
	-- safe even if a prior interrupted migration already moved the field model.
	local centre=Vector3.zero
	for _,rock in rocks[name] do centre+=A.localPosition(rock) end
	centre/=#rocks[name]
	local delta=Vector3.new(target.x-centre.X,0,target.z-centre.Z)
	for _,rock in rocks[name] do
		if delta.Magnitude>1e-5 then
			rock.CFrame+=delta
			for _,part in rock:GetDescendants() do if part:IsA("BasePart") then part.CFrame+=delta end end
		end
	end
	-- Absolute sign frames must face the new crater bearing after translation.
	local entrance=target.entrance
	local outward=Vector3.new(entrance.X,0,entrance.Z).Unit
	local signPosition=Vector3.new(entrance.X,20,entrance.Z)+outward*5
	local sign=assert(field:FindFirstChild("FieldSign"))
	sign.CFrame=CFrame.lookAt(signPosition+A.offset,Vector3.new(0,20,0)+A.offset)
	local supports={}
	for _,part in field:GetChildren() do if part.Name=="SignSupport" then table.insert(supports,part) end end
	assert(#supports==2,"Field sign supports changed")
	table.sort(supports,function(a,b) return a.Position.X<b.Position.X end)
	local tangent=Vector3.new(-outward.Z,0,outward.X)
	for index,part in supports do
		local position=signPosition+tangent*(if index==1 then 28 else -28)
		part.CFrame=A.cf(position.X,9.6,position.Z)
	end
	table.insert(moved,{zone=name,debrisDelta={delta.X,delta.Y,delta.Z},entrance={entrance.X,entrance.Y,entrance.Z}})
end
for part,size in originalSizes do assert(part.Size==size,"Landmark art was resized") end
assert(A.count(A.map)==beforeParts and beforeParts<=1800,"Migration changed the authored part count")
local use=A.localPosition(town.Refinery.UsePoint)
local entrance=zone("Refinery").entrance
assert(math.abs(use.X-entrance.X)<.001 and math.abs(use.Z-entrance.Z)<.001,"Refinery entrance mismatch")
A.map:SetAttribute("CompactLayoutPass",1)
A.map:SetAttribute("LayoutVersion",2)
return {stage="CompactLayout",translations=moved,parts=beforeParts,allArtSizesPreserved=true,
	fieldEntrancesRefreshed=true,relativeEquipmentMountsPreserved=true,rerunnable=true}
