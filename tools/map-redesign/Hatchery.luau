-- Common first. Decorative eggs; odds and prices read from existing Config.
local A=assert(_G.MapRedesignArt)
local C=A.colors
local Config=require(game.ReplicatedStorage.Shared.Config)
local town=A.ensure(A.map,"TownSquare")
local hatch=A.group(town,"Hatchery")
local base=A.part(hatch,"Floor",Vector3.new(128,1.2,72),A.cf(-155,.6,-380),C.violet)
hatch.PrimaryPart=base
A.part(hatch,"RearWall",Vector3.new(128,28,4),A.cf(-155,15.2,-414),C.navy)
for _,x in {-215,-95} do
	A.part(hatch,"Pillar",Vector3.new(6,34,6),A.cf(x,18.2,-382),C.cream)
end
A.part(hatch,"Canopy",Vector3.new(128,4,72),A.cf(-155,36.2,-380),C.violet)
A.sign(hatch,"HatcherySign","PET HATCHERY",Vector3.new(84,11,2),
	A.cf(-155,33,-344)*CFrame.Angles(0,math.pi,0),C.navy)
for row=0,2 do for col=0,7 do
	A.cylinder(hatch,"CanopyStud",4.5,1.2,A.cf(-211+col*16,38.8,-402+row*22),C.violet,nil,false)
end end
local count=#Config.Pets.Eggs
assert(count==2,"Revisit pedestal layout if egg catalog changes")
local oddsBoards=0
for i,egg in Config.Pets.Eggs do
	local x=-198+(i-1)*56
	local boardX=x+28
	local color=if i==1 then C.ember else C.frost
	local pedestal=A.group(hatch,egg.Id)
	pedestal:SetAttribute("EggId",egg.Id)
	A.cylinder(pedestal,"Base",24,1.2,A.cf(x,1.8,-378),C.cream)
	A.cylinder(pedestal,"Plinth",20,4,A.cf(x,4.4,-378),C.navy)
	A.cylinder(pedestal,"Rim",22,1,A.cf(x,6.9,-378),color)
	A.part(pedestal,"Egg",Vector3.new(14,18,14),A.cf(x,16.4,-378),color,nil,false,Enum.PartType.Ball)
	A.part(pedestal,"EggCap",Vector3.new(9,10,9),A.cf(x,22,-378),C.cream,nil,false,Enum.PartType.Ball)
	for k=0,3 do
		local angle=k*math.pi/2
		A.part(pedestal,"Spark",Vector3.new(1.6,4,1.6),
			A.cf(x+math.cos(angle)*6,16.4,-378+math.sin(angle)*6)*CFrame.Angles(0,0,math.rad(30)),
			C.gold,Enum.Material.Neon,false)
	end
	local lines={egg.Name,string.format("%s CORE SHARDS",egg.Cost)}
	local sum=0
	for _,rarity in Config.Pets.RarityOrder do
		local chance=egg.Odds[rarity]
		if chance then
			sum+=chance
			table.insert(lines,string.format("%s  %s%%",Config.Pets.Rarities[rarity].Name,chance))
		end
	end
	assert(math.abs(sum-100)<.001,"Config odds no longer sum to 100")
	table.insert(lines,string.format("Epic+ guaranteed after %s misses",egg.Pity))
	local backing,label=A.sign(pedestal,"OddsBoard",table.concat(lines,"\n"),Vector3.new(26,21,1),
		A.cf(boardX,13,-378)*CFrame.Angles(0,math.pi,0),C.navy)
	backing.Lettering.CanvasSize=Vector2.new(624,504)
	label.Font=Enum.Font.GothamBold
	label.TextWrapped=true
	label.TextScaled=false
	label.TextSize=44
	local canvas=backing.Lettering.CanvasSize
	local available=Vector2.new(canvas.X*.94,canvas.Y*.88)
	local bounds=game:GetService("TextService"):GetTextSize(label.Text,label.TextSize,label.Font,
		Vector2.new(available.X,10000))
	assert(bounds.Y<=available.Y,"Config odds text exceeds the board")
	for _,side in {-1,1} do
		A.part(pedestal,"BoardPost",Vector3.new(2,12,2),A.cf(boardX+side*10,7.2,-378.7),C.cream,nil,false)
	end
	oddsBoards+=1
end
A.sign(hatch,"ShopHint","HATCH PETS IN GEAR  >  PETS",Vector3.new(64,4,1),
	A.cf(-155,26,-346)*CFrame.Angles(0,math.pi,0),C.cream)
-- Oversized roof egg, still original primitive art.
A.cylinder(hatch,"LandmarkPlinth",23,1.6,A.cf(-155,39,-385),C.cream,nil,false)
A.part(hatch,"LandmarkEgg",Vector3.new(20,25,20),A.cf(-155,52,-385),C.gold,nil,false,Enum.PartType.Ball)
A.part(hatch,"LandmarkStripe",Vector3.new(21,6,21),A.cf(-155,52,-385),C.violet,nil,false,Enum.PartType.Ball)
assert(A.count(hatch)<=70,"Hatchery art budget")
A.map:SetAttribute("HatcheryPass",1)
return {stage="Hatchery",parts=A.count(hatch),eggs=count,oddsBoards=oddsBoards,decorOnly=true,totalParts=A.count(A.map)}
