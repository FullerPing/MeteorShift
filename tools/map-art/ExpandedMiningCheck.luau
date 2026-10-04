-- Read-only Edit checks for the expanded scene, excluding temporary previews.
local map=workspace.Map
local report={grass=0,occupied=0,roadSamples=0,buriedRoads={},groundOpeningFailures={},fernsInside=0,debris=#map.Debris:GetChildren()}
local region=Region3.new(Vector3.new(-164,-8,-164),Vector3.new(164,4,164)):ExpandToGrid(4)
local m,o=workspace.Terrain:ReadVoxels(region,4)
for x=1,#m do for y=1,#m[x] do for z=1,#m[x][y]do
	local xx=-164+(x-.5)*4 local zz=-164+(z-.5)*4
	if xx*xx+zz*zz<160^2 and o[x][y][z]>0 then
		report.occupied+=1
		if m[x][y][z]==Enum.Material.Grass then report.grass+=1 end
	end
end end end
local ray=RaycastParams.new() ray.FilterType=Enum.RaycastFilterType.Include
ray.FilterDescendantsInstances={workspace.Terrain}
local paved={}
for _,p in map.Roads:GetChildren()do if p:IsA("BasePart")then table.insert(paved,p)end end
for _,pl in map.Plots:GetChildren()do table.insert(paved,pl.Pad)table.insert(paved,pl.Path)end
table.insert(paved,map.TownSquare.Plaza)
for _,p in paved do for _,x in {-.85,0,.85}do for _,z in {-.85,0,.85}do
	local pos=p.CFrame:PointToWorldSpace(Vector3.new(x*p.Size.X/2,0,z*p.Size.Z/2))
	local hit=workspace:Raycast(pos+Vector3.new(0,10,0),Vector3.new(0,-40,0),ray)
	report.roadSamples+=1
	if hit and hit.Position.Y>p.Position.Y+p.Size.Y/2+.05 then table.insert(report.buriedRoads,p:GetFullName())end
	if hit and hit.Material==Enum.Material.Grass then report.grass+=1 end
end end end
ray.FilterDescendantsInstances={map.Ground}
for i=1,24 do
	local a=i*math.pi*2/24
	local hit=workspace:Raycast(Vector3.new(math.cos(a)*58,10,math.sin(a)*58),Vector3.new(0,-50,0),ray)
	if hit then table.insert(report.groundOpeningFailures,{hit.Instance.Name,hit.Position.Y})end
end
for _,p in map.Decor.BasinUnderstory:GetChildren()do
	if p.Name=="Fern"and Vector2.new(p.Position.X,p.Position.Z).Magnitude<160 then report.fernsInside+=1 end
end
local ring=0 local minR,maxR=math.huge,0
for _,p in map.Roads:GetChildren()do if p:IsA("BasePart")and p.Name=="Ring"then
	ring+=1 local r=Vector2.new(p.Position.X,p.Position.Z).Magnitude
	minR=math.min(minR,r) maxR=math.max(maxR,r)
end end
report.ring={segments=ring,minRadius=minR,maxRadius=maxR}
report.craterFloorDiameter=map.Crater.Bowl.Floor.Size.Y
report.coreDiameter=game.ServerStorage.Assets.Meteor.Core.Size.X
report.passed=report.grass==0 and #report.buriedRoads==0 and #report.groundOpeningFailures==0 and report.fernsInside==0 and report.debris==60 and ring==56
return game:GetService("HttpService"):JSONEncode(report)
