-- Common, CompactLayout and Routes first. Compact scenery avoids roads and zones.
local A=assert(_G.MapRedesignArt)
local C,G=A.colors,assert(A.geometry)
assert(G.BoundaryHalf==270,"Compact geometry required")
local scenery=A.group(A.map,"Scenery")
local boxes={}
local spawnZone
for _,zone in G.Zones do
	table.insert(boxes,{zone.x-zone.width/2,zone.x+zone.width/2,zone.z-zone.depth/2,zone.z+zone.depth/2})
	if zone.id=="Spawn" then spawnZone=zone end
end
assert(spawnZone,"Spawn geometry missing")
local lamps={{222,-112},{-222,-112},{0,235},{226,6}}
local guidePosition=Vector2.new(spawnZone.x-spawnZone.width/2-19,spawnZone.z+9)
local function distanceBox(x,z,box)
	return Vector2.new(math.max(box[1]-x,0,x-box[2]),math.max(box[3]-z,0,z-box[4])).Magnitude
end
local centres={}
local function clear(x,z)
	if math.abs(x)>G.BoundaryHalf-12 or math.abs(z)>G.BoundaryHalf-12 then return false end
	if Vector2.new(x,z).Magnitude<G.LandingRadius+22 then return false end
	for _,box in boxes do if distanceBox(x,z,box)<22 then return false end end
	for _,road in A.map.Roads:GetChildren() do
		local p=road.CFrame:PointToObjectSpace(Vector3.new(x,0,z)+A.offset)
		local d=Vector2.new(math.max(0,math.abs(p.X)-road.Size.X/2),math.max(0,math.abs(p.Z)-road.Size.Z/2)).Magnitude
		if d<22 then return false end
	end
	for _,p in centres do if (Vector2.new(x,z)-p).Magnitude<30 then return false end end
	for _,p in lamps do if (Vector2.new(x,z)-Vector2.new(p[1],p[2])).Magnitude<18 then return false end end
	if (Vector2.new(x,z)-guidePosition).Magnitude<18 then return false end
	return true
end
local candidates={}
local edge=G.BoundaryHalf-24
-- Interleave the four sides so the first24 valid positions stay distributed.
for index=0,15 do
	local coordinate=-edge+index*(edge*2/15)
	for side=0,3 do
		table.insert(candidates,if side<2 then Vector2.new(if side==0 then -edge else edge,coordinate)
			else Vector2.new(coordinate,if side==2 then -edge else edge))
	end
end
for _,radius in {G.BoundaryHalf-32,G.BoundaryHalf-64,G.BoundaryHalf-48} do
	for k=0,31 do
		local angle=(k+.5)*math.pi*2/32
		table.insert(candidates,Vector2.new(math.cos(angle)*radius,math.sin(angle)*radius))
	end
end
local count=0
for _,position in candidates do
	if count>=24 then break end
	local x,z=position.X,position.Y
	if clear(x,z) then
		count+=1
		table.insert(centres,position)
		local tree=A.group(scenery,"BlockTree"..count)
		local height=12+(count%3)*3
		A.part(tree,"Trunk",Vector3.new(4,height,4),A.cf(x,height/2,z),C.path,Enum.Material.Wood)
		for level=0,2 do
			local width=18-level*4
			A.part(tree,"Crown",Vector3.new(width,6,width),A.cf(x,height+level*4,z),
				if level==1 then Color3.fromRGB(67,185,58) else C.grass,nil,false)
		end
		A.cylinder(tree,"CrownStud",5,1.2,A.cf(x,height+11.6,z),C.grass,nil,false)
	end
end
assert(count==24,"Insufficient clear compact tree positions")
local guide=A.group(scenery,"TownWayfinding")
A.part(guide,"Post",Vector3.new(3,15,3),A.cf(guidePosition.X,7.5,guidePosition.Y),C.navy)
local _,label=A.sign(guide,"Directions","REFINERY  >\nGEAR HALL  >",Vector3.new(24,7,1),
	A.cf(guidePosition.X,16,guidePosition.Y)*CFrame.Angles(0,math.pi,0),C.cyan)
label.TextWrapped=true
for index,data in lamps do
	local x,z=data[1],data[2]
	local lamp=A.group(scenery,"Lamp"..index)
	A.part(lamp,"Pole",Vector3.new(2.5,18,2.5),A.cf(x,9,z),C.navy,Enum.Material.Metal)
	A.cylinder(lamp,"Cap",6,1,A.cf(x,18.5,z),C.cream,nil,false)
	local glow=A.part(lamp,"LampGlow",Vector3.new(4,4,4),A.cf(x,21,z),C.cream,Enum.Material.Neon,false)
	local light=Instance.new("PointLight")
	light.Color=C.cream
	light.Brightness=.5
	light.Range=32
	light.Shadows=false
	light.Parent=glow
end
for _,part in scenery:GetDescendants() do if part:IsA("BasePart") then
	for _,sx in {-1,1} do for _,sy in {-1,1} do for _,sz in {-1,1} do
		local corner=part.CFrame*Vector3.new(sx*part.Size.X/2,sy*part.Size.Y/2,sz*part.Size.Z/2)-A.offset
		assert(math.abs(corner.X)<=G.BoundaryHalf+.001 and math.abs(corner.Z)<=G.BoundaryHalf+.001,"Scenery crossed compact boundary")
	end end end
end end
assert(A.count(scenery)<=160 and A.count(A.map)<=1800,"Scenery/map art budget")
A.map:SetAttribute("SceneryPass",2)
return {stage="Scenery",parts=A.count(scenery),trees=count,lamps=4,totalParts=A.count(A.map),
	treeZoneAndRoadClearance=22,treeSpacing=30,boundaryHalf=G.BoundaryHalf}
