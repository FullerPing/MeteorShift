-- Read-only geometry audit apart from a temporary collision probe, always cleaned up.
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
local authored,previewParts,scripts,meshes,unanchored,lights,emitters,rate,particles=0,0,0,0,0,0,0,0,0
local function isPreview(v)
	while v and v~=map do
		if v:GetAttribute("PreviewOnly") then return true end
		v=v.Parent
	end
	return false
end
for _,v in map:GetDescendants() do
	if v:IsA("BasePart") then
		if isPreview(v) then previewParts+=1 else authored+=1 end
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
assert(authored<=1800 and meshes==0 and unanchored==0 and scripts==0,"Authored map budget/contract")
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
assert(#map.Debris:GetChildren()==48,"Debris roots")
local spawns={}
for _,s in map.TownSquare:GetChildren() do
	if s:IsA("SpawnLocation") then assert(not s.Enabled and s.Anchored and s:GetAttribute("StagedSpawn"));table.insert(spawns,s) end
end
assert(#spawns==6,"Six isolated staging spawns required")
table.sort(spawns,function(a,b) return a.Name<b.Name end)
local targets={
	{"Refinery",ref.UsePoint.Position},
	{"GearCounter",map.TownSquare.PickaxeShop.ShopPoint.Position},
	{"SellBars",map.TownSquare.TradingPost.SellPoint.Position},
	{"HatcheryEntrance",WorldGeometry.zone("Hatchery").entrance+offset+Vector3.new(0,3,0)},
	{"RebirthEntrance",map.TownSquare.RebirthMonument.RebirthPoint.Position},
	{"MuseumEntrance",map.TownSquare.IndexMuseum.IndexPoint.Position},
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
assert(#targets==14,"Fourteen original route destinations required")
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
assert(paths==84,"All six spawns must be checked against fourteen destinations")
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
	local entrance=WorldGeometry.zone("Refinery").entrance
	for _,forward in {0,12} do
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
local oldParts=0
for _,v in workspace.Map:GetDescendants() do if v:IsA("BasePart") then oldParts+=1 end end
return {editGeometryOnly=true,authoredParts=authored,previewParts=previewParts,refineryParts=refParts,
	scripts=scripts,meshParts=meshes,unanchored=unanchored,lights=lights,emitters=emitters,
	steadyRate=rate,steadyParticles=particles,spawns=#spawns,stagedSpawnsDisabled=true,debrisRoots=48,computedPaths=paths,
	pathFailures=failures,pathJumpWaypoints=jumps,frontCollisionFailures=frontFailures,
	miningAccessAbsent=true,miningHeadroom=headroom,oldMapParts=oldParts,
	passed=(#failures==0 and #frontFailures==0),playWalkingStillPending=true,miningReachStillPending=true}
