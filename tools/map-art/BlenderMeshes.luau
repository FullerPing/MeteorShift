-- Run with Common.luau and a local `geometry` table decoded from stone-geometry.json.
-- Converts Blender convex hulls to persistent CSG solids. Opaque MeshContent is
-- session-only and disappears when an rbxl is reopened; do not use it here.
local library=group(Assets,"ArtMeshes")
local names={"FracturedBasalt","LayeredTalus","WeatheredBoulder"}
local prototypes={}
for _,name in ipairs(names) do
	local data=geometry[name]
	local vertices={}
	for _,v in ipairs(data.vertices) do table.insert(vertices,Vector3.new(unpack(v))*10) end
	local base=Instance.new("Part")
	base.Size=Vector3.new(10,10,10)
	base.Anchored=true
	base.Parent=workspace
	local cutters,seen={},{}
	-- Supporting planes of the point cloud preserve the Blender silhouette while
	-- producing a single convex, low-detail solid with serializable geometry.
	for i=1,#vertices-2 do for j=i+1,#vertices-1 do for k=j+1,#vertices do
		local a,b,c=vertices[i],vertices[j],vertices[k]
		local cross=(b-a):Cross(c-a)
		if cross.Magnitude>0.0001 then
			local n=cross.Unit
			local d=n:Dot(a)
			local lo,hi=math.huge,-math.huge
			for _,v in ipairs(vertices) do local side=n:Dot(v)-d lo=math.min(lo,side) hi=math.max(hi,side) end
			if hi<0.001 or lo>-0.001 then
				if lo>-0.001 then n,d=-n,-d end
				local key=string.format("%.3f:%.3f:%.3f:%.3f",n.X,n.Y,n.Z,d)
				if not seen[key] then
					seen[key]=true
					local cut=Instance.new("Part")
					cut.Size=Vector3.new(50,50,50)
					local pos=n*(d+25)
					cut.CFrame=CFrame.lookAt(pos,pos+n)
					cut.Anchored=true
					cut.Parent=workspace
					table.insert(cutters,cut)
				end
			end
		end
	end end end
	local ok,p=pcall(function() return base:SubtractAsync(cutters,Enum.CollisionFidelity.Box,Enum.RenderFidelity.Precise) end)
	base:Destroy()
	for _,cut in ipairs(cutters) do cut:Destroy() end
	assert(ok,p)
	p.UsePartColor=true
	p:SetAttribute("BlenderHullPlanes",#cutters)
	p.Name=name
	p.Anchored=true
	p.CanCollide,p.CanTouch,p.CanQuery=false,false,false
	p.CastShadow=false
	p:SetAttribute("MapArtOwned",true)
	p:SetAttribute("BlenderTriangles",#data.faces)
	p.Parent=library
	prototypes[name]=p
end
local changed=0
local function replace(old,name)
	local p=prototypes[name]:Clone()
	p.Name=old.Name
	p.Size,p.CFrame=old.Size,old.CFrame
	p.Color,p.Material=old.Color,old.Material
	p.Anchored=old.Anchored
	p.CanCollide,p.CanTouch,p.CanQuery=old.CanCollide,old.CanTouch,old.CanQuery
	p.CastShadow=old.CastShadow
	p.Transparency=old.Transparency
	for k,v in pairs(old:GetAttributes()) do p:SetAttribute(k,v) end
	if not old:GetAttribute("MapArtOwned") then p:SetAttribute("MapArtOwned",nil) end
	p:SetAttribute("BlenderRockVariant",name)
	for _,child in ipairs(old:GetChildren()) do child.Parent=p end
	p.Parent=old.Parent
	old:Destroy()
	changed+=1
end
local index=0
for _,p in ipairs(Map.Crater.Rim:GetChildren()) do
	if p:IsA("BasePart") and p.Name=="RimRock" then
		index+=1
		replace(p,names[(index-1)%#names+1])
	end
end
for _,p in ipairs(Map.Crater.ImpactDetails:GetChildren()) do
	if p:IsA("BasePart") and p.Name=="ScorchedRockShelf" then replace(p,"FracturedBasalt") end
end
for _,p in ipairs(Map.Boundary.TalusDetails:GetChildren()) do
	if p:IsA("BasePart") then replace(p,"LayeredTalus") end
end
for _,p in ipairs(Map.Decor.MiningLandmarks:GetChildren()) do
	if p:IsA("BasePart") and p.Name=="WagonOre" then replace(p,"WeatheredBoulder") end
end
index=0
for _,p in ipairs(Map.Debris:GetChildren()) do
	if p:IsA("BasePart") then
		index+=1
		replace(p,names[(index-1)%#names+1])
	end
end
index=0
for _,p in ipairs(Assets.NodePieces:GetChildren()) do
	if p:IsA("BasePart") then
		index+=1
		replace(p,names[(index-1)%#names+1])
	end
end
Map:SetAttribute("BlenderRockPass",true)
return {stage="BlenderMeshes",replaced=changed,trianglesPerMesh=68,mapParts=count(Map)}
