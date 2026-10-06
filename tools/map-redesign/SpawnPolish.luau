-- Common first. Repairs the sparse spawn treatment seen in the partial native review.
local A=assert(_G.MapRedesignArt)
local C=A.colors
local town=A.map.TownSquare
local plaza=town.SpawnPlaza
local polish=A.group(plaza,"SpawnPolish")

-- Thin noncolliding trim stays below the spawn surfaces and keeps all aisles clear.
for _,z in {-489.4,-426.6} do
	A.part(polish,"PlazaRim",Vector3.new(96,.2,1.2),A.cf(-20,.7,z),C.cream,nil,false)
end
for _,x in {-67.4,27.4} do
	A.part(polish,"PlazaRim",Vector3.new(1.2,.2,62.8),A.cf(x,.7,-458),C.cream,nil,false)
end
for index=1,6 do
	local spawn=assert(town:FindFirstChild(if index==1 then "Spawn" else "SpawnPad"..index))
	assert(spawn:IsA("SpawnLocation") and not spawn.Enabled,"Keep staged spawns disabled")
	local p=spawn.Position-A.offset
	A.part(polish,"PadFrame"..index,Vector3.new(16,.22,16),A.cf(p.X,.72,p.Z),C.navy,nil,false)
	for _,dx in {-7.6,7.6} do for _,dz in {-7.6,7.6} do
		A.cylinder(polish,"PadStud",2.2,.5,A.cf(p.X+dx,1.08,p.Z+dz),
			if index%2==0 then C.gold else C.cyan,nil,false)
	end end
end

-- A readable outline and a small original meteor silhouette identify the starting zone.
A.part(polish,"WelcomeBacking",Vector3.new(96,11,1.2),A.cf(-20,20,-496),C.cream,nil,false)
for index=0,5 do
	A.cylinder(polish,"HeaderStud",3,1,A.cf(-55+index*14,25,-494),C.cyan,nil,false)
end
A.part(polish,"CrestSupport",Vector3.new(1.8,4,2),A.cf(-20,26.5,-494),C.navy,nil,false)
A.part(polish,"HeroMeteor",Vector3.new(7,7,7),A.cf(-20,32,-494)*CFrame.Angles(0,math.pi/4,0),C.ember,nil,false)
for _,data in {{-21,-.25},{-19,.25}} do
	A.part(polish,"CrestVein",Vector3.new(.55,6,.45),
		A.cf(data[1],32,-489.6)*CFrame.Angles(0,0,data[2]),C.gold,Enum.Material.Neon,false)
end
for _,data in {{-22,40,-.28,C.gold},{-17.5,39,.2,C.ember}} do
	A.part(polish,"CrestTrail",Vector3.new(2.8,11,3),
		A.cf(data[1],data[2],-494)*CFrame.Angles(0,0,data[3]),data[4],nil,false,"Wedge")
end

local parts=0
for _,v in polish:GetDescendants() do
	assert(not v:IsA("LuaSourceContainer"),"Code in spawn polish")
	if v:IsA("BasePart") then
		parts+=1
		assert(v.Anchored and not v.CanCollide and not v.CanTouch and not v.CanQuery,"Decorative collision changed")
		for _,sx in {-1,1} do for _,sy in {-1,1} do for _,sz in {-1,1} do
			local p=(v.CFrame*Vector3.new(sx*v.Size.X/2,sy*v.Size.Y/2,sz*v.Size.Z/2))-A.offset
			assert(p.X>=-68.001 and p.X<=28.001 and p.Z>=-499.001 and p.Z<=-425.999,"Spawn footprint changed")
		end end end
	end
end
assert(parts==47 and A.count(A.map)<=1800,"Spawn/map art budget")
A.map:SetAttribute("SpawnPolish",true)
return {parts=parts,totalParts=A.count(A.map),spawnLocationsMoved=false,sourceOrGUIChanged=false,
	visualReviewPending=true,allDecorationNoncolliding=true}
