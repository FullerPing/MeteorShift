-- Common first. Pristine 2x geometry clones; never changes live ServerStorage.Assets.
-- The unparented scaled templates are staging data. The visible preview is removed before Play.
local A=assert(_G.MapRedesignArt)
local Config=require(game.ReplicatedStorage.Shared.Config)
local pristine=(_G.MapRedesignBackup and _G.MapRedesignBackup.assets) or game.ServerStorage.Assets
assert(not pristine.Meteor.Core:GetAttribute("MeteorGeometryScale"),"Reload pristine archive before rescaling final assets")
if _G.MapRedesignScaledAssets then _G.MapRedesignScaledAssets:Destroy() end
local scaled=pristine:Clone()
scaled.Name="Assets_Redesign"
scaled:SetAttribute("MeteorGeometryScale",2)
scaled:SetAttribute("MapRedesignOwned",true)
local oldStations=scaled:FindFirstChild("PlotStations")
if oldStations then oldStations:Destroy() end
local function doubleSequence(sequence)
	local keys={}
	for _,k in sequence.Keypoints do table.insert(keys,NumberSequenceKeypoint.new(k.Time,k.Value*2,k.Envelope*2)) end
	return NumberSequence.new(keys)
end
local function doubleTree(root)
	local pivot=root.CFrame
	local parts={root}
	for _,v in root:GetDescendants() do if v:IsA("BasePart") then table.insert(parts,v) end end
	local offsets={}
	for _,p in parts do offsets[p]=pivot:ToObjectSpace(p.CFrame) end
	for _,p in parts do
		local offset=offsets[p]
		p.Size*=2
		p.CFrame=pivot*CFrame.new(offset.Position*2)*offset.Rotation
		p.Anchored=true
	end
	for _,v in root:GetDescendants() do
		assert(not v:IsA("LuaSourceContainer"),"No scripts allowed in art templates")
		if v:IsA("Attachment") then v.Position*=2
		elseif v:IsA("Light") then v.Range*=2
		elseif v:IsA("ParticleEmitter") then
			v.Size=doubleSequence(v.Size)
			v.Speed=NumberRange.new(v.Speed.Min*2,v.Speed.Max*2)
			v.Acceleration*=2
		elseif v:IsA("Beam") then v.Width0*=2;v.Width1*=2;v.TextureLength*=2
		elseif v:IsA("Trail") then v.WidthScale=doubleSequence(v.WidthScale)
		elseif v:IsA("Smoke") then v.Size*=2;v.RiseVelocity*=2
		elseif v:IsA("Fire") then v.Size*=2
		elseif v:IsA("Sound") then v.RollOffMinDistance*=2;v.RollOffMaxDistance*=2 end
	end
	root:SetAttribute("MeteorGeometryScale",2)
end
doubleTree(scaled.Meteor.Core)
for _,piece in scaled.NodePieces:GetChildren() do
	assert(piece:IsA("BasePart"),"Unexpected NodePieces template")
	doubleTree(piece)
end
assert((scaled.Meteor.Core.Size-pristine.Meteor.Core.Size*2).Magnitude<.001,"Core not exactly doubled")
_G.MapRedesignScaledAssets=scaled
local preview=A.group(A.map.Crater,"GeometryPreview")
preview:SetAttribute("PreviewOnly",true)
local function place(root,frame)
	local offsets={}
	for _,v in root:GetDescendants() do if v:IsA("BasePart") then offsets[v]=root.CFrame:ToObjectSpace(v.CFrame) end end
	root.CFrame=frame
	for p,offset in offsets do p.CFrame=frame*offset end
end
local function quiet(root)
	for _,v in root:GetDescendants() do
		if v:IsA("ParticleEmitter") or v:IsA("Light") then v.Enabled=false end
	end
end
local rng=Random.new(20261005)
local core=scaled.Meteor.Core:Clone()
place(core,A.map.Crater.MeteorSpawn.CFrame*CFrame.Angles(0,rng:NextNumber()*math.pi*2,0))
quiet(core)
core.Parent=preview
preview.PrimaryPart=core
local pieces=scaled.NodePieces:GetChildren()
table.sort(pieces,function(a,b) return a.Name<b.Name end)
local nodes=A.group(preview,"Crust","Folder")
local count=0
for _,slot in core:GetChildren() do
	if slot:IsA("Attachment") and slot.Name=="NodeSlot" then
		count+=1
		local piece=pieces[rng:NextInteger(1,#pieces)]:Clone()
		piece.Name="CrustNode"..count
		place(piece,slot.WorldCFrame*CFrame.Angles(0,rng:NextNumber()*math.pi*2,0))
		quiet(piece)
		piece.Parent=nodes
	end
end
assert(count==36,"Slot count changed")
local box,size=preview:GetBoundingBox()
local minY=box.Position.Y-size.Y/2
local maxY=box.Position.Y+size.Y/2
assert(A.count(preview)<=550,"Meteor preview part budget")
A.map:SetAttribute("MeteorPreviewPass",1)
return {stage="MeteorPreview",coreSize={core.Size.X,core.Size.Y,core.Size.Z},
	parts=A.count(preview),nodes=count,boxSize={size.X,size.Y,size.Z},minY=minY,maxY=maxY,
	previewOnly=true,liveAssetsUnchanged=game.ServerStorage.Assets.Meteor.Core.Size.X}
