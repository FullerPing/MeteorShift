-- Map v2 read-only geometry audit apart from a temporary collision probe, always cleaned up.
-- Edit evidence only. This does not replace Play/gameplay/walking/performance QA.
assert(not game:GetService("RunService"):IsRunning(),"Edit mode required")
local map=assert(workspace:FindFirstChild("Map_Redesign"))
assert(map:GetAttribute("MapRedesignOwned"),"Unowned staged map")
local geometryModule=game:GetService("ReplicatedStorage").Shared.WorldGeometry:Clone()
local geometryOk,WorldGeometry=pcall(require,geometryModule)
geometryModule:Destroy()
assert(geometryOk,"Cannot load current WorldGeometry: "..tostring(WorldGeometry))
local geometry=WorldGeometry.Settings
local offset=geometry.StageOffset
assert(offset==Vector3.zero,"v2 is authored in place")
local authored,previewParts,scripts,meshes,unanchored,lights,emitters,rate,particles=0,0,0,0,0,0,0,0,0
local outer,colliding,intruding=0,{},{}
local outerGroups={Boundary=true,Surroundings=true,Backdrop=true}
local playHalf=geometry.BoundaryHalf-1.2
local function rootName(v)
	while v.Parent and v.Parent~=map do v=v.Parent end
	return v.Name
end
local function isPreview(v)
	while v and v~=map do
		if v:GetAttribute("PreviewOnly") then return true end
		v=v.Parent
	end
	return false
end
for _,v in map:GetDescendants() do
	if v:IsA("BasePart") then
		if isPreview(v) then previewParts+=1 elseif outerGroups[rootName(v)] then
			outer+=1
			-- the outer scenery never collides apart from the four walls and the kill plane, and never pokes into the play area
			local solid=v.Name:find("Wall$") or v.Name=="KillPlane"
			if v.CanCollide and not solid then table.insert(colliding,v:GetFullName()) end
			if not solid then
				local inside=true
				for sx=-1,1,2 do for sy=-1,1,2 do for sz=-1,1,2 do
					local c=v.CFrame*Vector3.new(sx*v.Size.X/2,sy*v.Size.Y/2,sz*v.Size.Z/2)
					if not(math.abs(c.X)<playHalf and math.abs(c.Z)<playHalf and c.Y<24) then inside=false end
				end end end
				if inside then table.insert(intruding,v:GetFullName()) end
			end
		else authored+=1 end
		if not v.Anchored then unanchored+=1 end
		if v:IsA("MeshPart") then meshes+=1 end
	elseif v:IsA("LuaSourceContainer") then scripts+=1
	elseif v:IsA("Light") and v.Enabled and not isPreview(v) then
		lights+=1
		assert(not v.Shadows,"Decorative shadow light")
	elseif v:IsA("ParticleEmitter") and v.Enabled and not isPreview(v) then
		emitters+=1;rate+=v.Rate;particles+=v.Rate*v.Lifetime.Max
	end
end
assert(authored<=2700 and outer<=1400 and meshes<=24 and unanchored==0 and scripts==0,"Authored map budget/contract")
assert(#colliding==0,"Outer scenery collides: "..tostring(colliding[1]))
assert(#intruding==0,"Outer scenery inside the play area: "..tostring(intruding[1]))
for _,name in {"Surroundings","Backdrop"} do
	assert(map[name].ModelStreamingMode==Enum.ModelStreamingMode.Persistent,name.." must be Persistent so far scenery streams in")
end
assert(lights<=12 and emitters<=16 and rate<=65 and particles<=260,"Effect budget")
local ref=map.TownSquare.Refinery
assert(ref.PrimaryPart and ref:GetAttribute("SharedRefinery"),"Refinery metadata")
local usePoints,refParts=0,0
for _,v in ref:GetDescendants() do
	if v:IsA("BasePart") then refParts+=1;if v.Name=="UsePoint" then usePoints+=1 end end
	assert(not v:IsA("LuaSourceContainer") and not v:IsA("ProximityPrompt") and not v:IsA("Humanoid"),"Forbidden refinery descendant")
end
assert(usePoints==1 and refParts<=180,"Refinery parts")
local point=ref.UsePoint
assert(point.Anchored and point.Transparency==1 and not point.CanCollide and not point.CanTouch,"UsePoint flags")
assert(map.Crater.MeteorSpawn and map.Crater.ActiveMeteor and map.Crater.SkyTimer.Board.Title and map.Crater.SkyTimer.Board.Time,"Crater/HUD world contract")
assert(not map.Crater:FindFirstChild("MiningAccess"),"Owner's ground-only revision requires elevated MiningAccess absent")
assert(map.TownSquare.PickaxeShop.ShopPoint and map.TownSquare.TradingPost.SellPoint:FindFirstChildWhichIsA("ProximityPrompt"),"Shop/selling contract")
assert(map.Atmosphere and not map:FindFirstChild("Plots") and not map:FindFirstChild("PlotStations",true),"Final world containers")
assert(#map.Debris:GetChildren()==80,"Debris roots (20 per field)")
local spawns={}
for _,s in map.TownSquare:GetChildren() do
	if s:IsA("SpawnLocation") then assert(s.Enabled and s.Anchored);table.insert(spawns,s) end
end
assert(#spawns==6,"Six enabled spawns required")
table.sort(spawns,function(a,b) return a.Name<b.Name end)
local targets={
	{"Refinery",ref.UsePoint.Position},
	{"GearCounter",map.TownSquare.PickaxeShop.ShopPoint.Position},
	{"SellBars",map.TownSquare.TradingPost.SellPoint.Position},
	{"HatcheryEntrance",WorldGeometry.zone("Hatchery").entrance+offset+Vector3.new(0,3,0)},
	{"GearHallEntrance",WorldGeometry.zone("GearHall").entrance+offset+Vector3.new(0,3,0)},
	{"RebirthEntrance",map.TownSquare.RebirthMonument.RebirthPoint.Position},
	{"Commissary",map.TownSquare.Commissary.UsePoint.Position},
}
for _,field in map.DebrisFields:GetChildren() do
	local entrance=field:GetAttribute("Entrance")
	assert(typeof(entrance)=="Vector3",field.Name.." Entrance attribute missing")
	table.insert(targets,{field.Name.."Entrance",entrance+offset+Vector3.new(0,3,0)})
end
for _,landing in map.Crater.AccessRamps:GetChildren() do
	if landing.Name:find("FloorLanding") then
		table.insert(targets,{landing.Name,landing.Position+Vector3.new(0,landing.Size.Y/2+3,0)})
	end
end
assert(#targets==15,"Fifteen route destinations required")
local paths,failures,jumps=0,{},0
local path=game:GetService("PathfindingService"):CreatePath({AgentRadius=3,AgentHeight=6,AgentCanJump=true,WaypointSpacing=8})
for _,spawn in spawns do
	for _,target in targets do
		path:ComputeAsync(spawn.Position+Vector3.new(0,spawn.Size.Y/2+3,0),target[2])
		paths+=1
		if path.Status~=Enum.PathStatus.Success then
			table.insert(failures,spawn.Name.." -> "..target[1]..": "..path.Status.Name)
		else
			for _,w in path:GetWaypoints() do if w.Action==Enum.PathWaypointAction.Jump then jumps+=1 end end
		end
	end
end
path:Destroy()
assert(paths==90,"All six spawns must be checked against fifteen destinations")
local overlap=OverlapParams.new()
overlap.FilterType=Enum.RaycastFilterType.Include
overlap.FilterDescendantsInstances={map}
overlap.RespectCanCollide=true
local probe=Instance.new("Part")
probe.Name="TemporaryGeometryProbe"
probe.Size=Vector3.new(4,5.8,4)
probe.Anchored=true
probe.Transparency=1
probe.CanCollide,probe.CanTouch,probe.CanQuery=false,false,false
probe.Parent=map
local frontFailures={}
local groundRay=RaycastParams.new()
groundRay.FilterType=Enum.RaycastFilterType.Include
groundRay.FilterDescendantsInstances={map.Ground,map.Roads}
local ok,err=pcall(function()
	local refineryZone=WorldGeometry.zone("Refinery")
		local entrance=refineryZone.entrance
		local outward=if entrance.Z<refineryZone.z then -1 else 1 -- the front faces the spawn pads (north)
		for _,forward in {0,12*outward} do
		for _,side in {-12,0,12} do
			local origin=Vector3.new(entrance.X+side,30,entrance.Z+forward)+offset
			local ground=workspace:Raycast(origin,Vector3.new(0,-60,0),groundRay)
			assert(ground,"Missing forecourt ground")
			probe.CFrame=CFrame.new(ground.Position+Vector3.new(0,3,0))
			local touching=workspace:GetPartsInPart(probe,overlap)
			for _,v in touching do table.insert(frontFailures,v:GetFullName()) end
		end
	end
end)
probe:Destroy()
assert(ok,err)
-- The owner removed the ascent and terraces. Their 96-sample diagnostic is retired,
-- rather than recorded as passing mining reach. Ground paths and Play gates remain.
local headroom={retired=true,reason="Owner removed elevated MiningAccess",formerAscentSamples=96}
_G.CompactHeadroomDiagnostics=headroom
return {editGeometryOnly=true,authoredParts=authored,outerParts=outer,previewParts=previewParts,refineryParts=refParts,
	scripts=scripts,meshParts=meshes,unanchored=unanchored,lights=lights,emitters=emitters,
	steadyRate=rate,steadyParticles=particles,spawns=#spawns,debrisRoots=#map.Debris:GetChildren(),computedPaths=paths,
	pathFailures=failures,pathJumpWaypoints=jumps,frontCollisionFailures=frontFailures,
	miningAccessAbsent=true,miningHeadroom=headroom,
	passed=(#failures==0 and #frontFailures==0),playWalkingStillPending=true,miningReachStillPending=true}
