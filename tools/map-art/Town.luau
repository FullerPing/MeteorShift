-- Run after Common.luau, as a single edit-time command.
local town = Map.TownSquare
for _,name in ipairs({"PickaxeShop", "TradingPost"}) do
	local building = town:FindFirstChild(name) or (name == "PickaxeShop" and town:FindFirstChild("Shop"))
	assert(building, "Missing town building " .. name)
	building.Name = name
	local body = building.Body
	local cf = body.CFrame * CFrame.new(0,-body.Size.Y/2,0)
	local art = group(building,"Architecture")
	local trade = name == "TradingPost"
	local accent = trade and C.copper or C.blue
	local function b(n,s,x,y,z,col,mat) return block(art,n,s,cf*CFrame.new(x,y,z),col,mat) end
	body.Color = trade and Color3.fromRGB(141,95,60) or Color3.fromRGB(117,91,64)
	building.Door.Color = C.trim
	if name == "PickaxeShop" and not building:FindFirstChildWhichIsA("ProximityPrompt", true) then
		local point = building:FindFirstChild("ShopPoint") or Instance.new("Part")
		point.Name = "ShopPoint"
		point.Size = Vector3.new(1,1,1)
		point.CFrame = cf * CFrame.new(0,3,8)
		point.Anchored, point.CanCollide, point.CanTouch, point.CanQuery = true,false,false,false
		point.Transparency = 1
		point.CastShadow = false
		point.Parent = building
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText, prompt.ObjectText = "Shop", "Pickaxes & Backpacks"
		prompt.HoldDuration, prompt.MaxActivationDistance = 0,12
		prompt.Parent = point
	end
	b("StoneFooting",{19,0.65,13},0,0.25,0,C.stone,M.Cobblestone)
	for _,x in ipairs({-8.65,8.65}) do
		for _,z in ipairs({-5.8,6.12}) do
			b("CornerTimber",{0.6,10.8,0.6},x,5.7,z,C.trim,M.Wood)
		end
		b("PorchPost",{0.55,6.8,0.55},x,3.4,9.1,C.trim,M.Wood)
		b("PostShoe",{0.72,0.8,0.72},x,0.4,9.1,C.metal)
		rod(art,"AwningKneeBrace",(cf*CFrame.new(x,5.2,9.1)).Position,(cf*CFrame.new(x,6.7,7.6)).Position,0.3,C.wood,M.Wood)
	end
	for _,y in ipairs({1.0,10.75}) do b("FacadeBeam",{18.4,0.45,0.4},0,y,6.15,C.trim,M.Wood) end
	b("RoofRidge",{0.6,0.5,14},0,14.5,0,C.metal)
	b("PorchCanopy",{19.6,0.38,5.1},0,6.9,8.15,accent,M.Metal)
	b("CanopyLip",{19.6,0.6,0.25},0,6.6,10.65,C.trim,M.Wood)
	for _,x in ipairs({-5.3,5.3}) do
		b("WindowRecess",{3.65,3.45,0.18},x,5.0,6.14,C.trim,M.Wood)
		b("WindowPane",{3.05,2.85,0.2},x,5.0,6.26,Color3.fromRGB(111,169,176),M.Glass)
		b("WindowSill",{4.05,0.28,0.7},x,3.4,6.43,C.cream,M.Wood)
		b("WindowMullion",{0.18,3.0,0.18},x,5.0,6.42,C.trim,M.Wood)
		b("WindowCrossbar",{3.2,0.18,0.18},x,5.0,6.42,C.trim,M.Wood)
	end
	for _,x in ipairs({-2.25,2.25}) do b("DoorJamb",{0.3,7.3,0.5},x,3.7,6.4,C.cream,M.Wood) end
	b("DoorLintel",{4.8,0.35,0.5},0,7.3,6.4,C.cream,M.Wood)
	b("DoorHandle",{0.12,0.7,0.2},1.2,3.4,6.5,C.copper)
	for _,z in ipairs({-6.1,6.15}) do b("RoofFascia",{19,0.55,0.35},0,11,z,C.trim,M.Wood) end
	-- Wall-mounted trade identity; signage remains the original gameplay hierarchy.
	local badge = b("GuildPlaque",{2.4,2.4,0.25},0,12.15,6.3,accent,M.Metal)
	if trade then
		for i=1,3 do b("DisplayIngot",{1.4,0.45,0.65},-5.3+(i-2)*1.45,1.8,8.4,C.copper) end
		b("TradeDisplayShelf",{5.3,0.25,1.8},-5.3,1.4,8.4,C.wood,M.Wood)
		label(badge,"$",C.cream,Enum.NormalId.Back)
		local counter=building:FindFirstChild("SellPoint")
		if counter then
			local cc=counter.CFrame
			for _,x in ipairs({-2.9,2.9}) do block(art,"CounterCorner",{0.25,2.7,0.25},cc*CFrame.new(x,0,1.2),C.trim,M.Wood) end
			block(art,"CounterBand",{6.7,0.3,0.2},cc*CFrame.new(0,0.3,1.2),C.copper)
		end
	else
		label(badge,"P",C.cream,Enum.NormalId.Back)
		b("ToolDisplayBoard",{3.8,4.7,0.35},11.5,3.1,3.2,C.trim,M.Wood)
		for _,x in ipairs({10.6,12.3}) do
			b("DisplayPickHandle",{0.22,3,0.22},x,3.3,3.5,C.wood,M.Wood)
			b("DisplayPickHead",{1.4,0.35,0.4},x,4.5,3.5,C.copper)
		end
	end
	-- Side wall construction and shuttered windows.
	for _,x in ipairs({-9.15,9.15}) do
		b("SideBrace",{0.25,0.4,11.5},x,2.2,0,C.trim,M.Wood)
		b("SideWindow",{0.2,2.8,3.2},x,6.0,-1,C.blue,M.Glass)
		b("SideWindowFrame",{0.3,0.25,3.6},x,7.55,-1,C.cream,M.Wood)
		b("SideWindowSill",{0.5,0.25,3.6},x,4.45,-1,C.cream,M.Wood)
	end
end
local plaza = group(town,"PlazaDetails")
-- Paved edge bands stay outside the spawn and central walking space.
for _,x in ipairs({-34,34}) do block(plaza,"PlazaEdge",{1.1,0.15,59},CFrame.new(x,0.67,-95),C.stone,M.Cobblestone) end
block(plaza,"PlazaBackEdge",{67,0.15,1.1},CFrame.new(0,0.67,-124),C.stone,M.Cobblestone)
for _,x in ipairs({-29,29}) do
	local cf=CFrame.new(x,0.6,-92)
	block(plaza,"PlanterBox",{4.5,1.4,7},cf*CFrame.new(0,0.7,0),C.stone,M.Cobblestone)
	block(plaza,"PlanterSoil",{3.9,0.15,6.4},cf*CFrame.new(0,1.45,0),C.dark,M.Ground)
	for i=-1,1 do ball(plaza,"PlanterShrub",{3.4,2.1,3},cf*CFrame.new(0,2.2,i*2),C.green,M.Grass) end
end
local fountain=town.Fountain
local f=group(fountain,"StatueDetails")
local center=fountain.MeteorStatue.Position
for i=1,6 do
	local a=i*math.pi/3
	block(f,"MeteorOreSeam",{0.18,1.8,0.25},CFrame.new(center)*CFrame.Angles(0,a,0)*CFrame.new(0,0,1.75)*CFrame.Angles(0,0,0.4),C.copper,M.Metal)
end
cylinder(f,"PedestalCollar",1.25,0.5,CFrame.new(0,4.5,-99),C.copper)
return {stage="Town",mapParts=count(Map)}
