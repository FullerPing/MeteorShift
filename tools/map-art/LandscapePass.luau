-- Run after TerrainPass, with Common.luau. Native terrain is authoritative.
local terrain=workspace.Terrain
local ray=RaycastParams.new()
ray.FilterType=Enum.RaycastFilterType.Include
ray.FilterDescendantsInstances={terrain}
local function ground(x,z)
	local hit=workspace:Raycast(Vector3.new(x,150,z),Vector3.new(0,-250,0),ray)
	return hit and hit.Position.Y
end
local function bottom(p)
	local cf,s=p.CFrame,p.Size
	return p.Position.Y-(math.abs(cf.RightVector.Y)*s.X+math.abs(cf.UpVector.Y)*s.Y+math.abs(cf.LookVector.Y)*s.Z)/2
end
local grounded=0
for _,model in Map.Decor:GetChildren() do
	local trunk=model:FindFirstChild("Trunk")
	if model:IsA("Model") and trunk and trunk:IsA("BasePart") then
		local y=ground(trunk.Position.X,trunk.Position.Z)
		if y then model:PivotTo(model:GetPivot()+Vector3.new(0,y-.18-bottom(trunk),0)) grounded+=1 end
	end
end
local masks={}
for _,p in Map.Roads:GetDescendants() do if p:IsA("BasePart") and p.CanCollide then table.insert(masks,p) end end
for _,p in Map.Plots:GetDescendants() do if p:IsA("BasePart") and (p.Name=="Pad" or p.Name=="Path") then table.insert(masks,p) end end
local function clear(x,z,r)
	local clearRadius=Map:GetAttribute("MiningClearRadius") or 80
	if x*x+z*z<(clearRadius+r)^2 or (math.abs(x)<43 and z>-132 and z<-59) then return false end
	for _,p in masks do
		local q=p.CFrame:PointToObjectSpace(Vector3.new(x,p.Position.Y,z))
		if math.abs(q.X)<p.Size.X/2+r+3 and math.abs(q.Z)<p.Size.Z/2+r+3 then return false end
	end
	for _,p in Map.Debris:GetChildren() do
		if p:IsA("BasePart") and (Vector2.new(p.Position.X-x,p.Position.Z-z)).Magnitude<r+9 then return false end
	end
	return true
end
local landscape=group(Map.Decor,"BasinUnderstory")
local fern=game.ServerStorage.ArtImports:FindFirstChild("Fern_OuterLeaves",true)
assert(fern and fern:IsA("MeshPart"),"Sanitized fern prototype missing")
local rocks=Assets.ArtMeshes
local rockNames={"WeatheredBoulder","LayeredTalus","FracturedBasalt"}
local rng=Random.new(100127)
local fernCount,stoneCount=0,0
local function stone(x,z,size,index)
	if not clear(x,z,size.X/2) then return end
	local y=ground(x,z) if not y then return end
	local p=rocks[rockNames[(index-1)%3+1]]:Clone() p:ClearAllChildren()
	p.Name="ScreeStone" p.Size=size
	p.CFrame=CFrame.new(x,y+size.Y*.26,z)*CFrame.Angles(rng:NextNumber(-.18,.18),rng:NextNumber(0,math.pi*2),rng:NextNumber(-.12,.12))
	p.Color=Color3.fromRGB(102+index%4*4,105+index%3*3,94+index%5*3) p.Material=Enum.Material.Rock
	p.Anchored=true p.CanCollide=false p.CanQuery=false p.CanTouch=false p.CastShadow=false
	p:SetAttribute("MapArtOwned",true) p.Parent=landscape stoneCount+=1
end
local function plant(x,z)
	if not clear(x,z,2.5) then return end
	local y=ground(x,z) if not y then return end
	local p=fern:Clone() p:ClearAllChildren()
	local scale=rng:NextNumber(.12,.19) p.Size=fern.Size*scale
	p.Name="Fern" p.CFrame=CFrame.new(x,y+p.Size.Y/2-.18,z)*CFrame.Angles(0,rng:NextNumber(0,math.pi*2),0)
	p.Anchored=true p.CanCollide=false p.CanQuery=false p.CanTouch=false p.CastShadow=false
	p.Color=Color3.fromRGB(88+rng:NextInteger(0,22),112+rng:NextInteger(0,18),64)
	p:SetAttribute("MapArtOwned",true) p:SetAttribute("SourceAssetId",7979002756) p:SetAttribute("SourceCreator","TheLegoGuy137")
	p.Parent=landscape fernCount+=1
end
-- Irregular clusters at the foothills; smaller pockets between production paths.
for i=1,32 do
	local a=i*math.pi*2/32+rng:NextNumber(-.06,.06)
	local radius=i<=22 and rng:NextNumber(250,268) or rng:NextNumber(146,171)
	local x,z=math.cos(a)*radius,math.sin(a)*radius
	stone(x,z,Vector3.new(rng:NextNumber(3.2,5.8),rng:NextNumber(1.2,2.3),rng:NextNumber(2.3,4.2)),i)
	for j=1,3 do stone(x+rng:NextNumber(-6,6),z+rng:NextNumber(-5,5),Vector3.new(rng:NextNumber(.9,2.5),rng:NextNumber(.4,1.1),rng:NextNumber(.8,2)),i+j) end
	for j=1,3 do plant(x+rng:NextNumber(-8,8),z+rng:NextNumber(-7,7)) end
end
-- Keep fissures as quiet scorched marks rather than bright outlined polygons.
local fissures=Map.Decor.Polish.CraterScorch.Fissures
local softened=0
for _,v in fissures:GetChildren() do
	if v:IsA("BasePart") then v.Material=Enum.Material.Slate v.Color=Color3.fromRGB(89,62,43) softened+=1 end
end
local atmosphere=game.Lighting:FindFirstChildOfClass("Atmosphere")
if atmosphere then
	if atmosphere:GetAttribute("PreGeologyDensity")==nil then atmosphere:SetAttribute("PreGeologyDensity",atmosphere.Density) atmosphere:SetAttribute("PreGeologyHaze",atmosphere.Haze) end
	atmosphere.Density=.28 atmosphere.Haze=1.2
end
Map:SetAttribute("LandscapeGeologyPass",1)
return game:GetService("HttpService"):JSONEncode({stage="LandscapePass",groundedTrees=grounded,ferns=fernCount,stones=stoneCount,softenedFissures=softened})
