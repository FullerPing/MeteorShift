-- Common first. Continuous 18-wide ascent; mining reach and HP stay unchanged.
local A=assert(_G.MapRedesignArt)
local C=A.colors
local access=A.group(A.map.Crater,"MiningAccess")
local startY,endY=-44,60
local startR,endR=70,36
local segments=96
local maxSlope=0
local function helix(t)
	local theta=t*math.pi*3
	local radius=startR+(endR-startR)*t
	return Vector3.new(math.cos(theta)*radius,startY+(endY-startY)*t,math.sin(theta)*radius)
end
for k=0,segments-1 do
	local a,b=helix(k/segments),helix((k+1)/segments)
	local horizontal=Vector2.new(b.X-a.X,b.Z-a.Z).Magnitude
	local slope=math.deg(math.atan2(b.Y-a.Y,horizontal))
	maxSlope=math.max(maxSlope,slope)
	assert(slope<=30,"Mining ascent exceeds thirty degrees")
	local p=A.slope(access,"Ascent"..k,a,b,18,1.2,C.path)
	p:SetAttribute("WalkSurface",true)
	p:SetAttribute("ClearWidth",18)
	p:SetAttribute("SlopeDegrees",slope)
end
local terraces={{"Lower",65,-30},{"Middle",60,0},{"Upper",44,32},{"Crown",28,60}}
for _,data in terraces do
	local name,radius,y=data[1],data[2],data[3]
	local level=A.group(access,name.."Terrace")
	for k=0,31 do
		local a,b=k*math.pi*2/32,(k+1)*math.pi*2/32
		local p=A.slope(level,"Deck"..k,Vector3.new(math.cos(a)*radius,y,math.sin(a)*radius),
			Vector3.new(math.cos(b)*radius,y,math.sin(b)*radius),18,1.2,
			if name=="Crown" then C.gold else C.path)
		p:SetAttribute("WalkSurface",true)
		p:SetAttribute("ClearWidth",18)
	end
	local t=(y-startY)/(endY-startY)
	local join=helix(t)
	local radial=Vector3.new(join.X,0,join.Z).Unit
	local target=radial*radius+Vector3.new(0,y,0)
	local connection=A.slope(level,"AscentJoin",join,target,18,1.2,C.gold)
	connection:SetAttribute("WalkSurface",true)
end
-- Four level cantilevers make the exposed core reachable after crust is mined.
for k=0,3 do
	local direction=Vector3.new(math.cos(k*math.pi/2),0,math.sin(k*math.pi/2))
	local bridge=A.slope(access,"CoreBridge"..k,direction*60,direction*34,18,1.2,C.path)
	bridge:SetAttribute("WalkSurface",true)
	bridge:SetAttribute("ClearWidth",18)
end
for k=0,1 do
	local direction=Vector3.new(if k==0 then 1 else -1,0,0)
	local bridge=A.slope(access,"LowerCoreBridge"..k,direction*65+Vector3.new(0,-30,0),
		direction*32+Vector3.new(0,-30,0),18,1.2,C.path)
	bridge:SetAttribute("WalkSurface",true)
	bridge:SetAttribute("ClearWidth",18)
end
local start=helix(0)
A.part(access,"StartLanding",Vector3.new(24,.3,24),A.cf(start.X,-43.85,start.Z),C.gold)
A.sign(access,"AscentSign","MINING TERRACES",Vector3.new(24,5,1),
	A.cf(78,-34,-15)*CFrame.Angles(0,math.pi/2,0),C.navy)
assert(A.count(access)<=240,"Mining access art budget")
A.map:SetAttribute("MiningAccessPass",1)
return {stage="MiningAccess",parts=A.count(access),terraces=4,ascentSegments=96,
	clearWidth=18,maxSlope=maxSlope,topY=60,totalParts=A.count(A.map)}
