-- Three small mining landmarks fill open sectors without adding gameplay promises.
local art=group(Map.Decor,"MiningLandmarks")
local function at(cf)
	return function(n,s,x,y,z,col,mat) return block(art,n,s,cf*CFrame.new(x,y,z),col,mat) end
end
-- Ore derrick south of the crater. Its small footprint leaves the diagonal roads clear.
local cf=CFrame.new(8,0,89)*CFrame.Angles(0,0.3,0)
local b=at(cf)
b("DerrickFooting",{9,0.35,8},0,0.18,0,C.stone,M.Cobblestone)
for _,x in ipairs({-3.3,3.3}) do
	b("DerrickUpright",{0.8,12,0.8},x,6,0,C.trim,M.Wood)
	rod(art,"DerrickDiagonal",(cf*CFrame.new(x,0.6,0)).Position,(cf*CFrame.new(-x,11.5,0)).Position,0.35,C.wood,M.Wood)
	b("DerrickIronShoe",{1.05,1.6,1.05},x,0.8,0,C.metal)
end
b("DerrickCrown",{8.5,0.9,1.3},0,12,0,C.wood,M.Wood)
b("CraneBoom",{0.65,0.65,11},0,11.7,-2.5,C.trim,M.Wood)
rod(art,"BoomStay",(cf*CFrame.new(0,12,2)).Position,(cf*CFrame.new(0,11.7,-7.5)).Position,0.1,C.metal)
cylinder(art,"CranePulley",0.8,0.45,cf*CFrame.new(0,11,-6.8)*CFrame.Angles(0,0,math.pi/2),C.copper)
rod(art,"HoistCable",(cf*CFrame.new(0,10.8,-6.8)).Position,(cf*CFrame.new(0,3.2,-6.8)).Position,0.07,C.metal)
b("HoistBucket",{2.4,1.6,2.4},0,2.6,-6.8,C.metal)
b("WinchBase",{3.5,0.35,2.7},0,0.5,2,C.metal)
cylinder(art,"WinchDrum",0.65,2.2,cf*CFrame.new(0,1.3,2)*CFrame.Angles(0,0,math.pi/2),C.copper)
-- East survey shelter: sloped panel, instrument, and restrained ore samples.
cf=CFrame.new(99,0,16)*CFrame.Angles(0,-math.pi/2,0)
b=at(cf)
b("SurveyDeck",{11,0.3,8},0,0.15,0,C.wood,M.WoodPlanks)
for _,x in ipairs({-4.5,4.5}) do
	b("SurveyPost",{0.45,7.2,0.45},x,3.6,2.8,C.trim,M.Wood)
	rod(art,"SurveyRoofSupport",(cf*CFrame.new(x,6.5,2.8)).Position,(cf*CFrame.new(x,7.3,-2.7)).Position,0.25,C.wood,M.Wood)
end
block(art,"SurveyRoof",{12,0.3,7.2},cf*CFrame.new(0,7.05,0)*CFrame.Angles(-0.1,0,0),C.blue,M.Metal)
b("SampleDesk",{7,0.4,2.5},0,2.6,1.2,C.wood,M.WoodPlanks)
for _,x in ipairs({-2.8,2.8}) do b("SampleDeskLeg",{0.3,2.4,0.3},x,1.2,1.2,C.trim,M.Wood) end
for i=1,3 do block(art,"MineralSample",{0.55,1.0,0.6},cf*CFrame.new((i-2)*1.8,3.3,1.2)*CFrame.Angles(0,i,0.3),({C.copper,C.blue,C.cream})[i],M.Metal) end
local board=block(art,"SurveyChart",{4.2,2.5,0.2},cf*CFrame.new(0,5.0,2.9),C.metal)
label(board,"ORE SURVEY",C.cream)
-- West cargo siding: a compact parked wagon with restrained rail detail.
cf=CFrame.new(-97,0,6)*CFrame.Angles(0,0.25,0)
b=at(cf)
for _,x in ipairs({-1.7,1.7}) do b("SidingRail",{0.2,0.2,15},x,0.32,0,C.metal) end
for i=-3,3 do b("SidingSleeper",{4.8,0.22,0.55},0,0.11,i*2,C.trim,M.Wood) end
b("OreWagonFloor",{4.2,0.35,5.5},0,1.3,0,C.metal)
for _,x in ipairs({-2.1,2.1}) do b("OreWagonSide",{0.3,2.3,5.5},x,2.6,0,C.copper) end
for _,z in ipairs({-2.7,2.7}) do b("OreWagonEnd",{4.2,2.3,0.3},0,2.6,z,C.copper) end
for _,x in ipairs({-2.1,2.1}) do
	for _,z in ipairs({-1.8,1.8}) do cylinder(art,"WagonWheel",0.65,0.35,cf*CFrame.new(x,0.8,z)*CFrame.Angles(0,0,math.pi/2),C.metal) end
end
for i=1,3 do block(art,"WagonOre",{1.5,1.4,1.5},cf*CFrame.new((i-2)*1.1,3.0,0)*CFrame.Angles(0,i,0.25),C.stone,M.Rock) end
return {stage="Landmarks",mapParts=count(Map)}
