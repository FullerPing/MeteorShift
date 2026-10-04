-- Persistent convex solids from original Blender vertex clouds.
local function solidFromVertices(data,name,parent)
	local vertices={}
	for _,v in ipairs(data.vertices) do table.insert(vertices,Vector3.new(unpack(v))*10) end
	local base=Instance.new("Part") base.Size=Vector3.new(10,10,10) base.Anchored=true base.Parent=workspace
	local cutters,seen={},{}
	for i=1,#vertices-2 do for j=i+1,#vertices-1 do for k=j+1,#vertices do
		local a,b,c=vertices[i],vertices[j],vertices[k]
		local cross=(b-a):Cross(c-a)
		if cross.Magnitude>0.0001 then
			local n=cross.Unit local d=n:Dot(a)
			local lo,hi=math.huge,-math.huge
			for _,v in ipairs(vertices) do local side=n:Dot(v)-d lo=math.min(lo,side) hi=math.max(hi,side) end
			if hi<0.001 or lo>-0.001 then
				if lo>-0.001 then n,d=-n,-d end
				local key=string.format("%.3f:%.3f:%.3f:%.3f",n.X,n.Y,n.Z,d)
				if not seen[key] then
					seen[key]=true
					local cut=Instance.new("Part") cut.Size=Vector3.new(50,50,50)
					local pos=n*(d+25) cut.CFrame=CFrame.lookAt(pos,pos+n) cut.Anchored=true cut.Parent=workspace
					table.insert(cutters,cut)
				end
			end
		end
	end end end
	local ok,p=pcall(function() return base:SubtractAsync(cutters,Enum.CollisionFidelity.Box,Enum.RenderFidelity.Precise) end)
	base:Destroy() for _,cut in ipairs(cutters) do cut:Destroy() end assert(ok,p)
	p.Name=name p.UsePartColor=true p.Anchored=true p.CanCollide=false p.CanQuery=false p.CanTouch=false p.CastShadow=false
	p:SetAttribute("MapArtOwned",true) p:SetAttribute("GeologySolid",name) p:SetAttribute("HullPlanes",#cutters)
	p.Parent=parent return p
end
local function cloneSolid(prototype,parent,name,size,cf,color,material)
	local p=prototype:Clone() p:ClearAllChildren()
	p.Name=name p.Size=size p.CFrame=cf p.Color=color p.Material=material or Enum.Material.Rock
	p.UsePartColor=true p.Anchored=true p.CanCollide=false p.CanQuery=false p.CanTouch=false p.CastShadow=false
	p:SetAttribute("MapArtOwned",true) p.Parent=parent return p
end
