-- Common first. Exactly 48 mineable roots; decoration does not change drops.
local A=assert(_G.MapRedesignArt)
local C=A.colors
local debris=A.group(A.map,"Debris","Folder")
local fields=A.group(A.map,"DebrisFields")
local zones={
	{"RustWorks",-275,270,100,92,C.ember,"RUST WORKS",-275,224},
	{"FrostYard",275,270,100,92,C.frost,"FROST YARD",275,224},
	{"VioletQuarry",-390,55,92,96,C.violet,"VIOLET QUARRY",-341,55},
	{"SulfurRidge",390,55,92,96,C.gold,"SULFUR RIDGE",341,55},
}
local nearest=math.huge
for _,data in zones do
	local name,x,z,w,d,color,title=data[1],data[2],data[3],data[4],data[5],data[6],data[7]
	local field=A.group(fields,name)
	field:SetAttribute("Theme",name)
	field:SetAttribute("Entrance",Vector3.new(data[8],0,data[9]))
	local pad=A.part(field,"FieldFloor",Vector3.new(w,.6,d),A.cf(x,.3,z),C.stone)
	field.PrimaryPart=pad
	local nearX=math.max(0,math.abs(x)-w/2)
	local nearZ=math.max(0,math.abs(z)-d/2)
	local distance=math.sqrt(nearX^2+nearZ^2)
	nearest=math.min(nearest,distance)
	assert(distance>=314,"Field in landing footprint")
	for row=0,2 do for col=0,3 do
		local xx,zz=x-33+col*22,z-22+row*22
		local rock=A.part(debris,name.."Rock"..(row*4+col+1),Vector3.new(8,6,8),A.cf(xx,3.6,zz),C.stone,Enum.Material.Basalt)
		rock:SetAttribute("Field",name)
		-- Root boxes remain eight studs wide: 22 spacing leaves fourteen-stud aisles.
		A.part(rock,"OreFleck",Vector3.new(3,.8,3),A.cf(xx-1.6,6.9,zz-1.6),color,Enum.Material.Neon,false)
		A.part(rock,"OreFleck",Vector3.new(2.3,1.4,2.3),A.cf(xx+1.7,7.2,zz+1.6),color,Enum.Material.Neon,false,"Wedge")
	end end
	-- Four chunky rear columns give the yard a distinct skyline, away from aisles.
	for k=0,3 do
		local xx=x-33+k*22
		local zz=z+d/2-6
		A.part(field,"OreColumn",Vector3.new(8,14+k%2*6,8),
			A.cf(xx,.6+(14+k%2*6)/2,zz),color,nil,true)
		A.cylinder(field,"ColumnStud",4,1,A.cf(xx,15.1+k%2*6,zz),color,nil,false)
	end
	local ex,ez=data[8],data[9]
	local outward=Vector3.new(ex,0,ez).Unit
	local signPosition=Vector3.new(ex,20,ez)+outward*5
	local signFrame=CFrame.lookAt(signPosition+A.offset,Vector3.new(0,20,0)+A.offset)
	A.sign(field,"FieldSign",title,Vector3.new(54,8,2),signFrame,color)
	-- Supports are perpendicular to the entrance, keeping its centre clear.
	local tangent=Vector3.new(-outward.Z,0,outward.X)
	for _,side in {-1,1} do
		local support=signPosition+tangent*side*28
		A.part(field,"SignSupport",Vector3.new(3,18,3),A.cf(support.X,9.6,support.Z),C.navy)
	end
end
assert(#debris:GetChildren()==48,"Exactly forty-eight direct debris roots required")
assert(A.count(debris)+A.count(fields)<=210,"Debris-field art budget")
A.map:SetAttribute("DebrisFieldsPass",1)
return {stage="DebrisFields",roots=48,parts=A.count(debris)+A.count(fields),aisle=14,
	nearestPad=nearest,totalParts=A.count(A.map)}
