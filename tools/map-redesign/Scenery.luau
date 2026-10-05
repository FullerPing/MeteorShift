-- Common first. Small original block-tree clusters; measured road/zone clearance.
local A=assert(_G.MapRedesignArt)
local C=A.colors
local scenery=A.group(A.map,"Scenery")
local boxes={
	{-68,28,-499,-426},{-38,38,-412,-348},{90,190,-416,-342},
	{-205,-105,-416,-342},{42,98,-480,-438},{-396,-324,-196,-124},
	{314,402,-198,-122},{-325,-225,224,316},{225,325,224,316},
	{-436,-344,7,103},{344,436,7,103},
}
local function distanceBox(x,z,box)
	return Vector2.new(math.max(box[1]-x,0,x-box[2]),math.max(box[3]-z,0,z-box[4])).Magnitude
end
local centres={}
local function clear(x,z)
	if math.abs(x)>490 or math.abs(z)>490 then return false end
	if Vector2.new(x,z).Magnitude<350 then return false end
	for _,box in boxes do if distanceBox(x,z,box)<22 then return false end end
	for _,road in A.map.Roads:GetChildren() do
		local p=road.CFrame:PointToObjectSpace(Vector3.new(x,0,z)+A.offset)
		local d=Vector2.new(math.max(0,math.abs(p.X)-road.Size.X/2),math.max(0,math.abs(p.Z)-road.Size.Z/2)).Magnitude
		if d<22 then return false end
	end
	for _,p in centres do if (Vector2.new(x,z)-p).Magnitude<30 then return false end end
	return true
end
local count=0
for _,radius in {466,408,440} do
	for k=0,31 do
		if count>=24 then break end
		local angle=(k+.5)*math.pi*2/32
		local x,z=math.cos(angle)*radius,math.sin(angle)*radius
		if clear(x,z) then
			count+=1
			table.insert(centres,Vector2.new(x,z))
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
end
assert(count==24,"Insufficient clear tree positions")
local guide=A.group(scenery,"TownWayfinding")
A.part(guide,"Post",Vector3.new(3,15,3),A.cf(-89,7.5,-420),C.navy)
local board,label=A.sign(guide,"Directions","REFINERY  >\nGEAR HALL  >",Vector3.new(24,7,1),
	A.cf(-89,16,-420)*CFrame.Angles(0,math.pi,0),C.cyan)
label.TextWrapped=true
for _,data in {{258,-258},{-258,-258},{0,365},{365,-60}} do
	local x,z=data[1],data[2]
	local lamp=A.group(scenery,"Lamp"..x.."_"..z)
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
assert(A.count(scenery)<=160,"Scenery art budget")
A.map:SetAttribute("SceneryPass",1)
return {stage="Scenery",parts=A.count(scenery),trees=count,lamps=4,totalParts=A.count(A.map)}
