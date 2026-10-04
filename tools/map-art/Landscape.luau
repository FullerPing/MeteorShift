-- Saved-instance landscape pass. All additions are deterministic and nonphysical.
local rng=Random.new(8102026)
local roads=group(Map.Roads,"RoadDetails")
for _,p in ipairs(Map.Roads:GetChildren()) do
	if p:IsA("BasePart") then
		p.Color=Color3.fromRGB(133,132,120)
		for _,side in ipairs({-1,1}) do
			block(roads,"StoneVerge",{0.5,0.16,p.Size.Z-0.12},p.CFrame*CFrame.new(side*(p.Size.X/2-0.25),p.Size.Y/2+0.08,0),C.stone,M.Cobblestone)
		end
	end
end
for _,plot in ipairs(Map.Plots:GetChildren()) do
	local pad=plot:FindFirstChild("Pad")
	if pad then
		local art=group(plot,"ColonyDetails")
		local cf=pad.CFrame*CFrame.new(0,pad.Size.Y/2,0)
		local function b(n,s,x,y,z,col,mat) return block(art,n,s,cf*CFrame.new(x,y,z),col,mat) end
		for _,x in ipairs({-6.4,6.4}) do
			b("EntryPillar",{0.8,5.2,0.8},x,2.6,-26.2,C.trim,M.Wood)
			b("EntryFooting",{1.1,0.8,1.1},x,0.4,-26.2,C.stone,M.Cobblestone)
			b("EntryCap",{1.25,0.25,1.25},x,5.3,-26.2,C.copper)
			rod(art,"GateKneeBrace",(cf*CFrame.new(x,4.0,-26.2)).Position,(cf*CFrame.new(x-math.sign(x)*1.6,5.4,-26.2)).Position,0.22,C.wood,M.Wood)
		end
		b("EntryHeader",{14.0,0.6,0.65},0,5.65,-26.2,C.trim,M.Wood)
		local id=plot:GetAttribute("PlotId")
		local number=b("PlotNumberPlate",{2.8,1.25,0.2},0,5.65,-26.57,C.metal)
		label(number,string.format("%02d",id),C.cream)
		for _,x in ipairs({-25.8,25.8}) do
			b("BackFenceRail",{0.22,0.25,50},x,2.0,0,C.wood,M.Wood)
		end
		local sign=plot:FindFirstChild("Sign")
		if sign then
			for _,x in ipairs({-5.15,5.15}) do block(art,"SignFrameSide",{0.28,3.8,0.35},sign.CFrame*CFrame.new(x,0,0),C.copper) end
			block(art,"SignFrameTop",{10.6,0.25,0.35},sign.CFrame*CFrame.new(0,1.85,0),C.copper)
		end
		local path=plot:FindFirstChild("Path")
		if path then
			for _,x in ipairs({-4.4,4.4}) do block(art,"ColonyPathVerge",{0.25,0.12,path.Size.Z},path.CFrame*CFrame.new(x,path.Size.Y/2+0.06,0),C.stone,M.Cobblestone) end
		end
	end
end
-- Rework existing canopy proportions; no duplicate forest or additional lights.
local colors={Color3.fromRGB(93,121,66),Color3.fromRGB(117,139,74),Color3.fromRGB(76,109,67),Color3.fromRGB(130,142,80)}
for i,tree in ipairs(Map.Decor:GetChildren()) do
	if tree:IsA("Model") and tree:FindFirstChild("Trunk") and tree:FindFirstChild("Leaves") then
		local trunk=tree.Trunk
		local leaves=tree.Leaves
		local tip=tree:FindFirstChild("Leaves2")
		local art=group(tree,"TreeDetails")
		local diameter=trunk.Size.Y
		trunk.Color=C.wood
		local base=trunk.Position-Vector3.new(0,trunk.Size.X/2,0)
		local width=leaves.Size.X
		-- Stored base dimensions make repeated authoring runs stable.
		if not leaves:GetAttribute("ArtOriginalSize") then leaves:SetAttribute("ArtOriginalSize",leaves.Size) end
		width=leaves:GetAttribute("ArtOriginalSize").X
		leaves.Size=Vector3.new(width*1.12,width*0.78,width*1.06)
		leaves.Color=colors[(i-1)%#colors+1]
		leaves.Material=M.Grass
		leaves.CastShadow=false
		if tip then
			if not tip:GetAttribute("ArtOriginalSize") then tip:SetAttribute("ArtOriginalSize",tip.Size) end
			local s=tip:GetAttribute("ArtOriginalSize")
			tip.Size=Vector3.new(s.X*1.18,s.Y*0.82,s.Z*1.1)
			tip.Color=leaves.Color:Lerp(C.cream,0.08)
			tip.Material=M.Grass
			tip.CastShadow=false
		end
		local angle=rng:NextNumber(0,math.pi*2)
		local offset=Vector3.new(math.cos(angle)*width*0.31,width*0.08,math.sin(angle)*width*0.31)
		ball(art,"CanopyLobe",{width*0.68,width*0.5,width*0.7},CFrame.new(leaves.Position+offset),leaves.Color:Lerp(C.trim,0.12),M.Grass)
		rod(art,"VisibleBranch",base+Vector3.new(0,trunk.Size.X*0.65,0),leaves.Position+offset*0.75,diameter*0.36,C.wood,M.Wood)
	end
end
local crater=group(Map.Crater,"ImpactDetails")
-- Fractured stone shelves occupy existing rim sectors; five entry corridors stay clear.
for i=0,47 do
	local a=i*math.pi*2/48
	local corridor=false
	for _,entryAngle in ipairs({math.pi/4,3*math.pi/4,5*math.pi/4,7*math.pi/4,3*math.pi/2}) do
		local delta=math.atan2(math.sin(a-entryAngle),math.cos(a-entryAngle))
		if math.abs(delta)<0.14 then corridor=true end
	end
	if not corridor then
		local cf=CFrame.new(math.cos(a)*52.5,0.45,math.sin(a)*52.5)*CFrame.Angles(0,-a,0)
		block(crater,"ScorchedRockShelf",{rng:NextNumber(4.5,7),rng:NextNumber(0.6,1.4),rng:NextNumber(2.8,4.8)},cf*CFrame.Angles(rng:NextNumber(-0.12,0.12),0,rng:NextNumber(-0.15,0.15)),C.dark:Lerp(C.stone,rng:NextNumber(0.05,0.25)),M.Basalt)
		if i%3==0 then block(crater,"CopperImpactSeam",{2.6,0.1,0.25},cf*CFrame.new(0,0.9,0)*CFrame.Angles(0,0.4,0),C.copper,M.Metal) end
	end
end
-- Boundary talus uses existing cliff bases, away from town and plots.
local boundary=group(Map.Boundary,"TalusDetails")
local index=0
for _,cliff in ipairs(Map.Boundary:GetChildren()) do
	if cliff:IsA("BasePart") and cliff.Name=="Cliff" then
		index+=1
		if index%2==0 then
			local dir=Vector3.new(cliff.Position.X,0,cliff.Position.Z).Unit
			local center=cliff.Position-dir*cliff.Size.Z*0.48-Vector3.new(0,cliff.Size.Y*0.35,0)
			block(boundary,"BrokenCliffFoot",{rng:NextNumber(7,12),rng:NextNumber(4,7),rng:NextNumber(5,9)},CFrame.new(center)*CFrame.Angles(0,rng:NextNumber(0,6.28),0.18),C.stone:Lerp(C.trim,0.3),M.Rock)
		end
	end
end
-- Ore splinters are parented under their mineable root so break/respawn hides them.
for _,rock in ipairs(Map.Debris:GetChildren()) do
	if rock:IsA("BasePart") then
		local art=group(rock,"OreDetails")
		for i=1,2 do
			local a=i*2.3
			block(art,"OreSplinter",{0.42,1.05,0.5},rock.CFrame*CFrame.new(math.cos(a)*rock.Size.X*0.28,rock.Size.Y*0.28,math.sin(a)*rock.Size.Z*0.28)*CFrame.Angles(0,a,0.45),C.copper,M.Metal)
		end
	end
end
Map:SetAttribute("MapArtVersion",1)
return {stage="Landscape",mapParts=count(Map),assetsParts=count(Assets)}
