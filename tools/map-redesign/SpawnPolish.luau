-- Common and Routes first. Noncolliding trim for the compact six-pad plaza.
local A=assert(_G.MapRedesignArt)
local C,G=A.colors,assert(A.geometry)
local spawnZone
for _,value in G.Zones do if value.id=="Spawn" then spawnZone=value;break end end
assert(spawnZone and G.BoundaryHalf==270,"Compact spawn geometry required")
local town=A.map.TownSquare
local plaza=town.SpawnPlaza
local polish=A.group(plaza,"SpawnPolish")
local x,z,w,d=spawnZone.x,spawnZone.z,spawnZone.width,spawnZone.depth
local welcomeZ=G.WelcomeZ

-- Thin noncolliding trim stays below the pads and keeps the aisles clear.
for _,edgeZ in {z-d/2+.6,z+d/2-.6} do
	A.part(polish,"PlazaRim",Vector3.new(w,.2,1.2),A.cf(x,.7,edgeZ),C.cream,nil,false)
end
for _,edgeX in {x-w/2+.6,x+w/2-.6} do
	A.part(polish,"PlazaRim",Vector3.new(1.2,.2,d-1.2),A.cf(edgeX,.7,z),C.cream,nil,false)
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

A.part(polish,"WelcomeBacking",Vector3.new(96,11,1.2),A.cf(x,20,welcomeZ-2),C.cream,nil,false)
for index=0,5 do
	A.cylinder(polish,"HeaderStud",3,1,A.cf(x-35+index*14,25,welcomeZ),C.cyan,nil,false)
end
A.part(polish,"CrestSupport",Vector3.new(1.8,4,2),A.cf(x,26.5,welcomeZ),C.navy,nil,false)
A.part(polish,"HeroMeteor",Vector3.new(7,7,7),A.cf(x,32,welcomeZ)*CFrame.Angles(0,math.pi/4,0),C.ember,nil,false)
for _,data in {{-1,-.25},{1,.25}} do
	A.part(polish,"CrestVein",Vector3.new(.55,6,.45),
		A.cf(x+data[1],32,welcomeZ+4.4)*CFrame.Angles(0,0,data[2]),C.gold,Enum.Material.Neon,false)
end
for _,data in {{-2,40,-.28,C.gold},{2.5,39,.2,C.ember}} do
	A.part(polish,"CrestTrail",Vector3.new(2.8,11,3),
		A.cf(x+data[1],data[2],welcomeZ)*CFrame.Angles(0,0,data[3]),data[4],nil,false,"Wedge")
end

local parts=0
for _,v in polish:GetDescendants() do
	assert(not v:IsA("LuaSourceContainer"),"Code in spawn polish")
	if v:IsA("BasePart") then
		parts+=1
		assert(v.Anchored and not v.CanCollide and not v.CanTouch and not v.CanQuery,"Decorative collision changed")
		for _,sx in {-1,1} do for _,sy in {-1,1} do for _,sz in {-1,1} do
			local p=v.CFrame*Vector3.new(sx*v.Size.X/2,sy*v.Size.Y/2,sz*v.Size.Z/2)-A.offset
			assert(p.X>=x-w/2-.001 and p.X<=x+w/2+.001
				and p.Z>=-G.BoundaryHalf-.001 and p.Z<=z+d/2+.001,"Spawn decoration crossed its compact bounds")
		end end end
	end
end
assert(parts==47 and A.count(A.map)<=1800,"Spawn/map art budget")
A.map:SetAttribute("SpawnPolish",true)
return {parts=parts,totalParts=A.count(A.map),spawnLocationsMoved=false,sourceOrGUIChanged=false,
	visualReviewPending=true,allDecorationNoncolliding=true,welcomeZ=welcomeZ}
