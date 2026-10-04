-- Run Common + GeologyCommon + geometry JSON + this stage, in Edit mode.
local minerals=group(Assets,"GeologyMinerals")
local mineralNames={"IronNodule","QuartzPoint","SplitCrystal"}
local mineral={}
for _,name in ipairs(mineralNames) do mineral[name]=solidFromVertices(geometry[name],name,minerals) end
local rocks=Assets.ArtMeshes
local rockNames={"FracturedBasalt","LayeredTalus","WeatheredBoulder"}
local rng=Random.new(100126)
local nodeCount,removed=0,0
local function preserveRoot(new,old)
	new.Name=old.Name new.Size=old.Size new.CFrame=old.CFrame new.Color=old.Color new.Material=old.Material
	new.Anchored=old.Anchored new.CanCollide=old.CanCollide new.CanQuery=old.CanQuery new.CanTouch=old.CanTouch
	new.CastShadow=old.CastShadow new.Transparency=old.Transparency
	for k,v in pairs(old:GetAttributes()) do new:SetAttribute(k,v) end
	new:SetAttribute("MapArtOwned",nil) new:SetAttribute("GeologyRebuilt",true)
end
for index,old in ipairs(Assets.NodePieces:GetChildren()) do
	assert(old:IsA("BasePart"),"NodePieces must contain only mineable roots")
	local root=rocks[rockNames[(index-1)%3+1]]:Clone() root:ClearAllChildren() preserveRoot(root,old)
	local cf,s=root.CFrame,root.Size
	-- One compact fractured mass with partially embedded satellites, never block
	-- stacks or detached square tiles. Names remain compatible with paintCluster.
	for i=1,3 do
		local a=i*math.pi*2/3+index*0.35
		local size=Vector3.new(s.X*.38,s.Y*.48,s.Z*.34)
		local pos=Vector3.new(math.cos(a)*s.X*.36,-s.Y*.08,math.sin(a)*s.Z*.36)
		cloneSolid(rocks[rockNames[i]],root,"Rock",size,cf*CFrame.new(pos)*CFrame.Angles(.13*i,a,.15),root.Color,Enum.Material.Basalt)
	end
	local count=({4,3,5,4})[index] or 4
	for i=1,count do
		local a=i*2.39996+index*.6
		local width=rng:NextNumber(.85,1.45)
		local height=width*rng:NextNumber(1.3,2.5)
		local pos=Vector3.new(math.cos(a)*s.X*.22,s.Y*.48,math.sin(a)*s.Z*.24)
		cloneSolid(mineral[mineralNames[(i+index-2)%3+1]],root,"Ore",Vector3.new(width,height,width*.85),cf*CFrame.new(pos)*CFrame.Angles(rng:NextNumber(-.28,.28),a,rng:NextNumber(-.35,.35)),Color3.fromRGB(194,170,143),Enum.Material.Metal)
	end
	-- Long, tapering mineral seams embedded in the stone read as geological
	-- fractures. A small ember lip gives Iron its heat cue without square glints.
	for i=1,2 do
		local a=i*2.7+index*.65
		local pos=Vector3.new(math.cos(a)*s.X*.20,s.Y*.43,math.sin(a)*s.Z*.20)
		cloneSolid(mineral.IronNodule,root,"Ore",Vector3.new(s.X*.32,.28,.65),cf*CFrame.new(pos)*CFrame.Angles(0,a,.22),Color3.fromRGB(195,169,145),Enum.Material.Metal)
		cloneSolid(mineral.SplitCrystal,root,"Ember",Vector3.new(.28,.12,s.Z*.30),cf*CFrame.new(pos-Vector3.new(0,.15,0))*CFrame.Angles(0,a+.5,0),C.glow,Enum.Material.Neon)
	end
	for _,v in ipairs(old:GetDescendants()) do if v:IsA("BasePart") then removed+=1 end end
	for _,v in ipairs(old:GetChildren()) do if not v:IsA("BasePart") and not v:IsA("Model") then v.Parent=root end end
	root.Parent=Assets.NodePieces old:Destroy() nodeCount+=1
end
local debrisCount=0
for index,root in ipairs(Map.Debris:GetChildren()) do
	if root:IsA("BasePart") then
		for _,v in ipairs(root:GetChildren()) do if v:IsA("BasePart") or v.Name=="OreDetails" then v:Destroy() end end
		local cf,s=root.CFrame,root.Size
		-- Low, embedded nodules visually distinguish debris from meteor crystals.
		for i=1,3 do
			local a=i*2.39996+index*.8
			local size=rng:NextNumber(.65,1.0)
			local pos=Vector3.new(math.cos(a)*s.X*.22,s.Y*.46,math.sin(a)*s.Z*.24)
			cloneSolid(mineral.IronNodule,root,"Fleck",Vector3.new(size,.42,size*.8),cf*CFrame.new(pos)*CFrame.Angles(.12,a,.2),Color3.fromRGB(176,152,112),Enum.Material.Metal)
		end
		root:SetAttribute("GeologyRebuilt",true) debrisCount+=1
	end
end
-- Veins on the core use the same tapered geology, preserving all slot and FX
-- attachments and the core's root/bounds used by the mining service.
local core=Assets.Meteor.Core
local replacedVeins=0
for _,v in ipairs(core:GetDescendants()) do
	if v:IsA("BasePart") and v.Name=="Vein" then
		local p=cloneSolid(mineral.IronNodule,v.Parent,"Vein",v.Size,v.CFrame,v.Color,v.Material)
		p.Transparency=v.Transparency
		for _,child in ipairs(v:GetChildren()) do child.Parent=p end
		v:Destroy() replacedVeins+=1
	end
end
Map:SetAttribute("NaturalOrePass",1)
return {stage="OrePass",nodeTemplates=nodeCount,debris=debrisCount,removedPrimitiveChunks=removed,coreVeins=replacedVeins}
