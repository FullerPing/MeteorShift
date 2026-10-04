local template=Assets.PlotStations
local pivot=template:GetPivot()
local art=group(template,"FoundryDetails")
local function b(n,s,x,y,z,col,mat) return block(art,n,s,CFrame.new(x,y,z),col,mat) end
-- Hopper: strapped shell, braced feet, intake framing.
for _,z in ipairs({-9.6,-2.4}) do
	b("HopperLowerBand",{7.2,0.3,0.22},-17,1.6,z,C.copper)
	b("HopperUpperBand",{7.2,0.3,0.22},-17,5.4,z,C.copper)
	for _,x in ipairs({-19.7,-14.3}) do b("HopperShellRib",{0.3,3.5,0.25},x,3.5,z,C.metal) end
end
for _,x in ipairs({-20,-14}) do rod(art,"HopperLegBrace",Vector3.new(x,0.3,-9),Vector3.new(x,1.1,-3),0.18,C.metal) end
b("IntakeLeftRim",{0.3,0.32,7},-19.7,0.3,-13.5,C.metal)
b("IntakeRightRim",{0.3,0.32,7},-14.3,0.3,-13.5,C.metal)
-- Conveyor: drive motor, rollers and visible support cross-bracing.
cylinder(art,"BeltDriveMotor",0.8,2,CFrame.new(-10,1.5,-8.9)*CFrame.Angles(math.pi/2,0,0),C.blue)
b("MotorBracket",{3.4,0.3,1.6},-10,0.9,-8.7,C.metal)
for _,x in ipairs({-11,-7,-3,1}) do
	cylinder(art,"SupportRoller",0.22,3.1,CFrame.new(x,2.05,-6)*CFrame.Angles(math.pi/2,0,0),C.copper)
end
for _,z in ipairs({-7.6,-4.4}) do rod(art,"BeltCrossBrace",Vector3.new(-10.9,0.3,z),Vector3.new(-3,1.9,z),0.18,C.metal) end
-- Refinery: framed firebox, straps, chimney cap, external pipe and pressure dial.
for _,x in ipairs({3.05,9.95}) do
	b("FurnaceCornerStrap",{0.25,5.9,0.25},x,3.8,-9.57,C.metal)
	b("FurnaceRearStrap",{0.25,5.9,0.25},x,3.8,-2.43,C.metal)
end
for _,y in ipairs({1.4,6.4}) do b("FurnaceFaceBand",{7.2,0.28,0.23},6.5,y,-9.62,C.metal) end
for _,x in ipairs({4.6,8.4}) do b("FireboxFrameSide",{0.25,2.35,0.3},x,3.2,-9.8,C.copper) end
for _,y in ipairs({2.05,4.35}) do b("FireboxFrameTop",{4.05,0.25,0.3},6.5,y,-9.8,C.copper) end
for _,x in ipairs({5.25,6.5,7.75}) do b("FireboxGrille",{0.12,1.8,0.24},x,3.2,-9.8,C.metal) end
cylinder(art,"ChimneyCollar",1.02,0.38,CFrame.new(8.5,8.3,-4),C.copper)
cylinder(art,"ChimneyCap",1.15,0.25,CFrame.new(8.5,12.55,-4),C.metal)
cylinder(art,"PressurePipe",0.21,4.2,CFrame.new(10.3,4.5,-3.7),C.copper)
cylinder(art,"PressurePipeElbow",0.22,1.5,CFrame.new(9.65,6.6,-3.7)*CFrame.Angles(0,0,math.pi/2),C.copper)
cylinder(art,"GaugeHousing",0.7,0.3,CFrame.new(10.3,4.9,-4.15)*CFrame.Angles(math.pi/2,0,0),C.metal)
cylinder(art,"GaugeFace",0.58,0.05,CFrame.new(10.3,4.9,-4.34)*CFrame.Angles(math.pi/2,0,0),C.cream,M.SmoothPlastic)
block(art,"GaugeNeedle",{0.08,0.45,0.06},CFrame.new(10.3,5.02,-4.39)*CFrame.Angles(0,0,-0.6),C.trim,M.SmoothPlastic)
-- Collector: canopy trim, crate straps, separate pickup-pad edging.
for _,z in ipairs({-10,-2}) do b("CollectorRoofTrim",{9.1,0.25,0.25},18,6.9,z,C.copper) end
for _,x in ipairs({16,20}) do b("CollectionCrateStrap",{0.24,2.5,4.15},x,1.8,-5.5,C.metal) end
b("CollectionFrontBand",{5.1,0.22,0.22},18,2.4,-7.55,C.copper)
for _,x in ipairs({15.3,20.7}) do b("PickupPadRim",{0.3,0.32,7},x,0.3,-13.5,C.metal) end
for _,x in ipairs({14.5,21.5}) do rod(art,"CollectorRoofBrace",Vector3.new(x,4.9,-3),Vector3.new(x,6.6,-4.8),0.18,C.trim,M.Wood) end
-- Keep the placement contract even after expanding the bounding box.
template.WorldPivot=pivot
return {stage="Stations",templateParts=count(template),pivot=tostring(template:GetPivot())}
