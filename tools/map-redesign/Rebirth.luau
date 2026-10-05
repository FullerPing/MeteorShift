-- Common first. Original reward monument, open toward the west loop.
local A=assert(_G.MapRedesignArt)
local C=A.colors
local town=A.ensure(A.map,"TownSquare")
local zone=A.group(town,"RebirthMonument")
local base=A.part(zone,"Plaza",Vector3.new(72,.8,72),A.cf(-360,.4,-160),C.gold)
zone.PrimaryPart=base
local ring=A.cf(-369,27,-160)*CFrame.Angles(0,-math.pi/2,0)
for i=0,15 do
	local angle=(i+.5)*math.pi*2/16
	A.part(zone,"RebirthLoop"..i,Vector3.new(5,2*22*math.sin(math.pi/16)+.15,5),
		ring*CFrame.new(math.cos(angle)*22,math.sin(angle)*22,0)*CFrame.Angles(0,0,angle),
		if i%4==0 then C.cream else C.gold)
end
for _,data in {{0,47,15},{0,7,-15}} do
	A.part(zone,"ArrowTip",Vector3.new(8,10,8),A.cf(-369,data[2],-160+data[3])
		*CFrame.Angles(0,math.pi/2,math.rad(if data[3]>0 then 180 else 0)),C.grass,nil,false,"Wedge")
end
for _,z in {-189,-131} do
	A.part(zone,"Column",Vector3.new(6,27,6),A.cf(-369,14.3,z),C.cream)
	A.cylinder(zone,"ColumnCap",10,2,A.cf(-369,28.8,z),C.gold,nil,false)
end
A.cylinder(zone,"CentrePlinth",18,2,A.cf(-369,1.8,-160),C.navy)
A.cylinder(zone,"CentreTop",14,1,A.cf(-369,3.3,-160),C.grass)
A.part(zone,"RewardStar",Vector3.new(9,9,3),A.cf(-369,22,-160)*CFrame.Angles(0,math.pi/2,math.pi/4),C.gold,nil,false)
A.part(zone,"StarCross",Vector3.new(3,15,3),A.cf(-369,22,-160)*CFrame.Angles(0,math.pi/2,0),C.gold,nil,false)
A.sign(zone,"RebirthSign","REBIRTH",Vector3.new(52,10,2),
	A.cf(-328,35,-160)*CFrame.Angles(0,-math.pi/2,0),C.navy)
A.sign(zone,"RewardSign","RETURN STRONGER",Vector3.new(40,4,1),
	A.cf(-328,27,-160)*CFrame.Angles(0,-math.pi/2,0),C.grass)
for _,z in {-191,-129} do
	A.part(zone,"SignSupport",Vector3.new(4,30,4),A.cf(-330,15.8,z),C.navy)
end
A.part(zone,"SignCrossbar",Vector3.new(3,3,66),A.cf(-330,31.8,-160),C.cream,nil,false)
for i=0,7 do
	local angle=i*math.pi*2/8
	A.cylinder(zone,"PlazaStud",4,1,A.cf(-360+math.cos(angle)*29,1.3,-160+math.sin(angle)*29),C.gold,nil,false)
end
local point=A.part(zone,"RebirthPoint",Vector3.new(6,1,6),A.cf(-325,3,-160),C.gold,nil,false)
point.Transparency=1
assert(A.count(zone)<=55,"Rebirth art budget")
A.map:SetAttribute("RebirthPass",1)
return {stage="Rebirth",parts=A.count(zone),entrance={-325,-160},totalParts=A.count(A.map)}
