-- Edit-time soil and landscape reconstruction. Run after Common.luau.
-- Rewrites only the bounded basin region; distant mountains remain intact.
local terrain=workspace.Terrain
local clearRadius=Map:GetAttribute("MiningClearRadius") or 82
local holeRadius=Map:GetAttribute("CraterTerrainOpening") or 57
local masks={}
local function mask(p,padding)
	table.insert(masks,{cf=p.CFrame,x=p.Size.X/2+padding,z=p.Size.Z/2+padding})
end
for _,p in ipairs(Map.Plots:GetChildren()) do mask(p.Pad,4) if p:FindFirstChild("Path") then mask(p.Path,4) end end
for _,p in ipairs(Map.Roads:GetChildren()) do if p:IsA("BasePart") then mask(p,4) end end
mask(Map.TownSquare.Plaza,3)
local function protected(x,z)
	local pos=Vector3.new(x,0,z)
	for _,m in ipairs(masks) do local v=m.cf:PointToObjectSpace(pos) if math.abs(v.X)<m.x and math.abs(v.Z)<m.z then return true end end
	return false
end
local function smooth(a,b,t)
	t=math.clamp((t-a)/(b-a),0,1)
	return t*t*(3-2*t)
end
local function height(x,z)
	local r=math.sqrt(x*x+z*z)
	local a=math.atan2(z,x)
	local n=math.noise(x/63,z/63,19)*2
	if r<242 then
		if protected(x,z) or r<clearRadius then return -0.22,r end
		return -0.15+math.max(0,n)*1.8,r
	end
	local wave=6*math.sin(a*3+0.6)+4*math.sin(a*7-1.2)+n*7
	local shoulder=0.5+smooth(241,280,r)*(30+wave)
	local crest=13*math.exp(-((r-(298+4*math.sin(a*4)))/22)^2)
	local ridge=(shoulder+crest)*(1-smooth(323,364,r))+1.8*smooth(323,364,r)
	return ridge,r
end
local regions=0
for x0=-368,336,32 do
	local region=Region3.new(Vector3.new(x0,-40,-368),Vector3.new(x0+32,112,368)):ExpandToGrid(4)
	local materials,occupancy=terrain:ReadVoxels(region,4)
	for ix=1,#materials do
		local x=x0+(ix-0.5)*4
		for iz=1,#materials[ix][1] do
			local z=-368+(iz-0.5)*4
			local h,r=height(x,z)
			if r<362 then
				local angle=math.atan2(z,x)
				local field=math.noise(x/37,z/37,7)
				local surface=Enum.Material.Grass
				if r<clearRadius then surface=Enum.Material.Ground
				elseif r<242 then
					if protected(x,z) or field>0.10 then surface=Enum.Material.Ground end
				elseif r>273 and r<322 then
					surface=Enum.Material.Rock
					if math.sin(angle*4+1)>0.55 and field<0.10 then surface=Enum.Material.Grass end
				elseif r>342 then surface=Enum.Material.Sand
				elseif field>0.15 then surface=Enum.Material.Ground end
				for iy=1,#materials[ix] do
					local bottom=-40+(iy-1)*4
					-- Occupancy's geometric boundary lies at the voxel centre;
					-- subtract half a cell so surface height agrees with h.
					local fill=math.clamp((h-2-bottom)/4,0,1)
					if bottom<-28 then fill=0 end
					if r<holeRadius then fill=0 end
					occupancy[ix][iy][iz]=fill
					materials[ix][iy][iz]=fill>0 and (bottom<h-8 and Enum.Material.Rock or surface) or Enum.Material.Air
				end
			end
		end
	end
	terrain:WriteVoxels(region,4,materials,occupancy)
	regions+=1
	task.wait()
end
-- Smooth terrain supplies visible ground and collision. The large old union's
-- simplified physics hull can span its cutout, so disable that legacy collider.
Map.Ground.Transparency=1
Map.Ground.CastShadow=false
Map.Ground.CanCollide=false
Map.Ground.CanQuery=false
Map.Ground.CanTouch=false
terrain:SetMaterialColor(Enum.Material.Grass,Color3.fromRGB(103,121,76))
terrain:SetMaterialColor(Enum.Material.Ground,Color3.fromRGB(124,111,85))
terrain:SetMaterialColor(Enum.Material.Rock,Color3.fromRGB(108,104,95))
terrain:SetMaterialColor(Enum.Material.Sand,Color3.fromRGB(158,140,109))
-- The old geometric cliff ring sits inside the reconstructed ridge and creates
-- clipping shards. Hide its visible shells; terrain now provides the silhouette.
for _,p in ipairs(Map.Boundary:GetChildren()) do
	if p:IsA("BasePart") and p.Name=="Cliff" then p.Transparency=1 p.CanCollide=false p.CanQuery=false p.CastShadow=false end
end
Map:SetAttribute("TerrainGeologyPass",1)
return {stage="TerrainPass",voxelRegions=regions,terrainCells=terrain:CountCells()}
