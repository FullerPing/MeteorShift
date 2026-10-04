-- Run in Edit mode after Common.luau. Preserves gameplay scripts and plot pads.
assert(not Map:GetAttribute("ExpandedMiningPass"), "This place already has the expansion")
local scale, ringRadius, holeRadius = 1.25, 150, 64
local function scaleAround(root, factor)
	for _, p in root:GetDescendants() do
		if p:IsA("BasePart") then p.CFrame=CFrame.new(p.Position*factor)*p.CFrame.Rotation p.Size*=factor end
	end
end
for _,name in {"Bowl","Rim","ImpactDetails"} do scaleAround(Map.Crater[name],scale) end
for _,p in Map.Crater.Lamps:GetDescendants() do
	if p:IsA("BasePart") then p.Position=Vector3.new(p.Position.X*scale,p.Position.Y,p.Position.Z*scale) end
end
Map.Crater.MeteorSpawn.Position=Vector3.new(0,-1.25,0)
local scorch=Map.Decor.Polish:FindFirstChild("CraterScorch")
if scorch then scaleAround(scorch,scale) end
-- Expand the saved safety collider's opening along with the visible bowl.
local cutter=Instance.new("Part") cutter.Shape=Enum.PartType.Cylinder
cutter.Size=Vector3.new(100,holeRadius*2,holeRadius*2)
cutter.CFrame=CFrame.new(0,-12,0)*CFrame.Angles(0,0,math.pi/2)
cutter.Anchored=true cutter.Parent=workspace
local ground=Map.Ground
local ok,replacement=pcall(function()return ground:SubtractAsync({cutter},Enum.CollisionFidelity.Default,Enum.RenderFidelity.Precise)end)
cutter:Destroy() assert(ok,replacement)
replacement.Name="Ground" replacement.Anchored=true replacement.Transparency=1
-- The large legacy CSG's physics hull spans its cutout even at precise fidelity.
-- Native terrain and the bowl now provide collision; keep the old art inactive.
replacement.CanCollide=false replacement.CanQuery=false replacement.CanTouch=false replacement.CastShadow=false
replacement.Parent=Map ground:Destroy()
for _,p in Map.Roads:GetChildren() do
	if p:IsA("BasePart") then
		if p.Name=="Ring" then
			p.Position=Vector3.new(p.Position.X*ringRadius/128,p.Position.Y,p.Position.Z*ringRadius/128)
			p.Size=Vector3.new(p.Size.X,p.Size.Y,p.Size.Z*ringRadius/128)
		elseif p.Name=="Path" then
			local direction=Vector3.new(p.Position.X,0,p.Position.Z).Unit
			local a,b=63,145
			if math.abs(direction.X)<.01 and direction.Z<0 then a,b=63,68 end
			p.Position=direction*((a+b)/2)+Vector3.new(0,p.Position.Y,0)
			p.Size=Vector3.new(p.Size.X,p.Size.Y,b-a)
		end
	end
end
-- The plaza remains fixed; connect its outside edge to the relocated ring.
local oldConnector=Map.Roads:FindFirstChild("TownConnector")
if oldConnector then oldConnector:Destroy() end
local reference=Map.Roads:FindFirstChild("Path")
local connector=reference:Clone() connector:ClearAllChildren() connector.Name="TownConnector"
connector.Size=Vector3.new(10,.32,22) connector.CFrame=CFrame.new(0,.16,-135)
connector.Parent=Map.Roads
local verges=group(Map.Roads,"RoadDetails")
for _,p in Map.Roads:GetChildren() do if p:IsA("BasePart") then
	for _,side in {-1,1} do
		block(verges,"StoneVerge",{.5,.16,p.Size.Z-.12},p.CFrame*CFrame.new(side*(p.Size.X/2-.25),p.Size.Y/2+.08,0),C.stone,M.Cobblestone)
	end
end end
for _,plot in Map.Plots:GetChildren() do
	local p=plot:FindFirstChild("Path")
	if p then
		local direction=Vector3.new(p.Position.X,0,p.Position.Z).Unit
		local outer=Vector3.new(p.Position.X,0,p.Position.Z).Magnitude+p.Size.Z/2
		p.Position=direction*((153+outer)/2)+Vector3.new(0,p.Position.Y,0)
		p.Size=Vector3.new(p.Size.X,p.Size.Y,outer-153)
		local trim=plot:FindFirstChild("ColonyDetails")
		if trim then
			for _,v in trim:GetChildren() do if v.Name=="ColonyPathVerge" then v:Destroy() end end
			for _,side in {-1,1} do block(trim,"ColonyPathVerge",{.25,.12,p.Size.Z},p.CFrame*CFrame.new(side*4.4,.22,0),C.stone,M.Cobblestone) end
		end
	end
end
Map:SetAttribute("CraterTerrainOpening",holeRadius)
Map:SetAttribute("MiningClearRadius",160)
Map:SetAttribute("MiningRingRadius",ringRadius)
-- Remove decorative plants/stones from the mining field and paving margins.
local masks={}
for _,p in Map.Roads:GetChildren()do if p:IsA("BasePart")then table.insert(masks,p)end end
for _,p in Map.Plots:GetDescendants()do if p:IsA("BasePart")and(p.Name=="Pad"or p.Name=="Path")then table.insert(masks,p)end end
table.insert(masks,Map.TownSquare.Plaza)
local function paved(pos,padding)
	for _,p in masks do local q=p.CFrame:PointToObjectSpace(pos) if math.abs(q.X)<p.Size.X/2+padding and math.abs(q.Z)<p.Size.Z/2+padding then return true end end
	return false
end
local removed=0
for _,p in Map.Decor.BasinUnderstory:GetChildren() do
	if p:IsA("BasePart") and(Vector2.new(p.Position.X,p.Position.Z).Magnitude<160+p.Size.Magnitude/2 or paved(p.Position,5+p.Size.X/2))then p:Destroy() removed+=1 end
end
-- Reuse the existing persistent ore solids and flecks; every rock is a real target.
local originals=Map.Debris:GetChildren()
local copies={}
for i=1,60 do table.insert(copies,originals[(i-1)%#originals+1]:Clone()) end
for _,p in originals do p:Destroy() end
local rng=Random.new(20261002) local positions={}
local landmark=Map.Decor.MiningLandmarks
local function valid(pos)
	if paved(pos,6) then return false end
	for _,p in landmark:GetDescendants() do if p:IsA("BasePart") then
		local q=p.CFrame:PointToObjectSpace(pos)
		if math.abs(q.X)<p.Size.X/2+5 and math.abs(q.Z)<p.Size.Z/2+5 then return false end
	end end
	for _,v in positions do if (v-pos).Magnitude<9 then return false end end
	return true
end
for i,p in copies do
	local pos
	for attempt=1,2000 do
		local a=rng:NextNumber(0,math.pi*2)
		local r=math.sqrt(rng:NextNumber(78^2,135^2))
		local candidate=Vector3.new(math.cos(a)*r,0,math.sin(a)*r)
		if valid(candidate)then pos=candidate break end
	end
	assert(pos,"Could not place ore "..i)
	table.insert(positions,pos)
	local cf=p.CFrame local offsets={}
	for _,c in p:GetDescendants() do if c:IsA("BasePart")then offsets[c]=cf:ToObjectSpace(c.CFrame)end end
	local rotation=CFrame.Angles(rng:NextNumber(-.1,.1),rng:NextNumber(0,math.pi*2),rng:NextNumber(-.1,.1))
	local bottom=(math.abs(rotation.RightVector.Y)*p.Size.X+math.abs(rotation.UpVector.Y)*p.Size.Y+math.abs(rotation.LookVector.Y)*p.Size.Z)/2
	p.CFrame=CFrame.new(pos.X,-.22+bottom-.18,pos.Z)*rotation
	for c,offset in offsets do c.CFrame=p.CFrame*offset end
	p.Name="DebrisRock" p.Anchored=true p.CanCollide=true p.CanQuery=true
	p:SetAttribute("TargetId",nil) p:SetAttribute("ExpandedOreIndex",i) p.Parent=Map.Debris
end
Map:SetAttribute("ExpandedMiningPass",1)
return {stage="ExpandedMiningPass",debris=#copies,removedUnderstory=removed,ringRadius=ringRadius,holeRadius=holeRadius}
