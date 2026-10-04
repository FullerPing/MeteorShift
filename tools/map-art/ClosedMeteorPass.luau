-- Run after Common.luau and GeologyCommon.luau in Edit mode.
-- Overlapping mineable hulls close the crust; no permanent covering shell.
local core=Assets.Meteor.Core
assert(not core:GetAttribute("ClosedMeteorPass"),"Meteor already enlarged")
local factor=1.5 local oldCf=core.CFrame
for _,p in core:GetDescendants()do
	if p:IsA("BasePart")then
		local offset=oldCf:ToObjectSpace(p.CFrame)
		p.Size*=factor p.CFrame=oldCf*CFrame.new(offset.Position*factor)*offset.Rotation
	elseif p:IsA("Attachment")then p.CFrame=CFrame.new(p.Position*factor)*p.CFrame.Rotation end
end
core.Size*=factor
-- Spread the same 36 targets down to the bowl floor. The original cap-only
-- distribution left the newly exposed lower skirt uncovered.
local slots={}
for _,a in core:GetChildren()do if a:IsA("Attachment")and a.Name=="NodeSlot"then table.insert(slots,a)end end
for i,a in slots do
	local y=-.70+1.70*(i-.5)/#slots
	local angle=(i-1)*math.pi*(3-math.sqrt(5))
	local r=math.sqrt(1-y*y)
	local up=Vector3.new(math.cos(angle)*r,y,math.sin(angle)*r)
	local right=up:Cross(Vector3.yAxis).Unit
	a.CFrame=CFrame.fromMatrix(up*16.605,right,up,right:Cross(up))
end
local oldPieces=Assets.NodePieces:GetChildren()
table.sort(oldPieces,function(a,b)return a.Name<b.Name end)
for index,old in oldPieces do
	-- Twelve-sided broad basal rings give every random yaw the same coverage.
	-- A smaller, offset crown retains the fractured stone silhouette.
	local vertices={}
	for ring=1,3 do
		local count=ring==3 and 6 or 12
		local radius=({.47,.50,.27})[ring]
		local y=({-.48,-.10,.43})[ring]
		for i=1,count do
			local a=(i-1)*math.pi*2/count+(ring==3 and index*.11 or 0)
			table.insert(vertices,{math.cos(a)*radius+(ring==3 and .025 or 0),y,math.sin(a)*radius+(ring==3 and -.015 or 0)})
		end
	end
	table.insert(vertices,{.025,.50,-.015})
	local root=solidFromVertices({vertices=vertices},old.Name,Assets.NodePieces)
	root.Size=Vector3.new(20,8+index*.2,20)
	root.CFrame=old.CFrame root.Color=old.Color root.Material=old.Material
	root.CanCollide=true root.CanQuery=true root.CanTouch=old.CanTouch root.CastShadow=old.CastShadow
	root.CollisionFidelity=Enum.CollisionFidelity.PreciseConvexDecomposition
	for name,value in old:GetAttributes()do root:SetAttribute(name,value)end
	root:SetAttribute("ClosedCrustHull",true)
	for _,c in old:GetChildren()do
		local clone=c:Clone()
		if clone:IsA("BasePart")then
			local q=old.CFrame:ToObjectSpace(c.CFrame)
			clone.Size*=factor
			-- Scatter the familiar ore and stone across the enlarged upper crown.
			local x,z=q.X*2.1,q.Z*2.1
			local y=3.25+math.min(1.6,clone.Size.Y*.16)
			if clone.Name=="Rock"then y=2.8 clone.Size*=1.15 end
			clone.CFrame=root.CFrame*CFrame.new(x,y,z)*q.Rotation
			clone.CanCollide=false clone.CanQuery=false clone.CanTouch=false
		elseif clone:IsA("Attachment")then clone.Position*=factor end
		clone.Parent=root
	end
	old:Destroy()
end
core:SetAttribute("ClosedMeteorPass",1)
return {stage="ClosedMeteorPass",coreDiameter=core.Size.X,nodeTemplates=#oldPieces}
