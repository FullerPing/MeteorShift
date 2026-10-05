-- Common first. Physical selling landmark with the existing SellPoint contract.
local A=assert(_G.MapRedesignArt)
local C=A.colors
local town=A.ensure(A.map,"TownSquare")
local post=A.group(town,"TradingPost")
local base=A.part(post,"Floor",Vector3.new(56,1.2,40),A.cf(70,.6,-460),C.navy)
post.PrimaryPart=base
A.part(post,"RearWall",Vector3.new(56,24,3),A.cf(70,13.2,-478.5),C.gold)
for _,x in {44,96} do
	A.part(post,"Post",Vector3.new(4,29,4),A.cf(x,15.7,-442),C.cream)
end
A.part(post,"Canopy",Vector3.new(56,3,40),A.cf(70,31.7,-460),C.gold)
for col=0,4 do for row=0,1 do
	A.cylinder(post,"RoofStud",4,1,A.cf(48+col*11,33.7,-470+row*20),C.gold,nil,false)
end end
A.part(post,"Counter",Vector3.new(42,5,6),A.cf(70,3.7,-446),C.cream)
A.part(post,"CounterTop",Vector3.new(44,1,8),A.cf(70,6.7,-446),C.gold)
for row=0,2 do for col=0,2-row do
	A.part(post,"GoldBar",Vector3.new(9,3,5),A.cf(60+col*10+row*5,9+row*3,-447),C.gold,Enum.Material.Metal,false)
end end
A.sign(post,"TradingSign","SELL YOUR BARS",Vector3.new(50,9,2),
	A.cf(70,27,-438.8)*CFrame.Angles(0,math.pi,0),C.navy)
local point=A.part(post,"SellPoint",Vector3.new(6,1,6),A.cf(70,3,-434),C.gold,nil,false)
point.Transparency=1
local prompt=Instance.new("ProximityPrompt")
prompt.Name="SellBars"
prompt.ActionText="Sell bars"
prompt.ObjectText="Trading Post"
prompt.MaxActivationDistance=12
prompt.HoldDuration=0
prompt.RequiresLineOfSight=false
prompt.Parent=point
assert(A.count(post)<=40,"Trading Post art budget")
A.map:SetAttribute("TradingPostPass",1)
return {stage="TradingPost",parts=A.count(post),sellPoint={70,3,-434},totalParts=A.count(A.map)}
