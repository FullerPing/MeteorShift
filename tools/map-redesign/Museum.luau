-- Common first. Original world exhibits generated from Config.Index.
local A=assert(_G.MapRedesignArt)
local C=A.colors
local Config=require(game.ReplicatedStorage.Shared.Config)
local town=A.ensure(A.map,"TownSquare")
local zone=A.group(town,"IndexMuseum")
local floor=A.part(zone,"Floor",Vector3.new(84,1.2,76),A.cf(360,.6,-160),C.navy)
zone.PrimaryPart=floor
A.part(zone,"BackWall",Vector3.new(4,32,76),A.cf(400,17.2,-160),C.cyan)
for _,z in {-196,-124} do
	A.part(zone,"SideWall",Vector3.new(84,32,4),A.cf(360,17.2,z),C.cyan)
	A.part(zone,"FrontPillar",Vector3.new(6,36,6),A.cf(320,19.2,z),C.cream)
end
-- Skylight: only a perimeter canopy so the exhibits remain bright.
for _,z in {-191,-129} do
	A.part(zone,"CanopySide",Vector3.new(84,4,14),A.cf(360,36.2,z),C.cream)
end
A.part(zone,"CanopyFront",Vector3.new(12,4,52),A.cf(324,36.2,-160),C.cyan)
A.part(zone,"CanopyBack",Vector3.new(12,4,52),A.cf(396,36.2,-160),C.cyan)
A.sign(zone,"MuseumSign","MINERAL INDEX",Vector3.new(68,10,2),
	A.cf(316,35,-160)*CFrame.Angles(0,math.pi/2,0),C.navy)
local displays=A.group(zone,"Exhibits")
local mineralCount=0
for row,pageId in Config.Index.PageOrder do
	local page=Config.Index.Pages[pageId]
	assert(#page.Minerals==4,"Revisit museum layout for changed collection")
	local z=-184+(row-1)*24
	for pair=1,2 do
		local x=352+(pair-1)*34
		local exhibit=A.group(displays,pageId..pair)
		exhibit:SetAttribute("IndexPage",pageId)
		A.part(exhibit,"Table",Vector3.new(11,4,10),A.cf(x,3.2,z),C.cream)
		A.part(exhibit,"Rim",Vector3.new(12,.8,11),A.cf(x,5.6,z),C.cyan,nil,false)
		local names={page.Name}
		for j=1,2 do
			local mineral=page.Minerals[(pair-1)*2+j]
			local zz=z+(if j==1 then -2.8 else 2.8)
			local frame=A.cf(x,9,zz)*CFrame.Angles(0,math.rad(j*30),math.rad(-10))
			A.part(exhibit,mineral.Id,Vector3.new(3.5,6,3.5),frame,mineral.Color,Enum.Material.Glass,false)
			A.part(exhibit,"Facet",Vector3.new(3.5,2.5,3.5),frame*CFrame.new(0,3.8,0),
				mineral.Color,Enum.Material.Glass,false,"Wedge")
			table.insert(names,mineral.Name)
			mineralCount+=1
		end
		local board,label=A.sign(exhibit,"CollectionLabel",table.concat(names,"\n"),Vector3.new(14,5,.6),
			A.cf(x-6.4,10,z)*CFrame.Angles(0,math.pi/2,0),C.navy)
		board.Lettering.CanvasSize=Vector2.new(700,250)
		label.TextWrapped=true
		A.part(exhibit,"LabelMount",Vector3.new(1.6,6,2),A.cf(x-6.4,7.8,z),C.cream,nil,false)
	end
end
for _,z in {-186,-134} do
	for i=0,5 do
		A.cylinder(zone,"CanopyStud",4,1.1,A.cf(326+i*14,38.8,z),C.cyan,nil,false)
	end
end
A.part(zone,"LandmarkPlinth",Vector3.new(28,2,26),A.cf(338,39.2,-157),C.cream,nil,false)
for i=0,4 do
	A.part(zone,"LandmarkCrystal",Vector3.new(6,18+i*3,6),
		A.cf(329+i*4,48+i*1.5,-160+(i%2)*6)*CFrame.Angles(0,math.rad(i*30),math.rad((i-2)*12)),
		if i%2==0 then C.frost else C.violet,Enum.Material.Glass,false)
end
local point=A.part(zone,"IndexPoint",Vector3.new(6,1,6),A.cf(316,3,-160),C.cyan,nil,false)
point.Transparency=1
assert(mineralCount==12,"Missing museum minerals")
assert(A.count(zone)<=85,"Museum art budget")
A.map:SetAttribute("MuseumPass",1)
return {stage="Museum",parts=A.count(zone),exhibits=6,minerals=mineralCount,entrance={316,-160},totalParts=A.count(A.map)}
