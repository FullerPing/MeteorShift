-- Edit-time art helpers. Outside the Rojo tree; creates no saved scripts.
assert(game:GetService("RunService"):IsStudio(), "Studio only")
assert(not game:GetService("RunService"):IsRunning(), "Stop Play before authoring")
local root = workspace:FindFirstChild("Map_Redesign")
if root then
	assert(root:IsA("Model") and root:GetAttribute("MapRedesignOwned"), "Unowned staged map")
else
	root = Instance.new("Model")
	root.Name = "Map_Redesign"
	root:SetAttribute("MapRedesignOwned", true)
	root:SetAttribute("LayoutVersion", 1)
	root.Parent = workspace
end
root:SetAttribute("StageOffset", Vector3.new(0, 0, 3000))
root.WorldPivot = CFrame.new(0,0,3000)
root:SetAttribute("CraterTerrainOpening", 160)
root:SetAttribute("MiningClearRadius", 180)
local A = {
	map = root, offset = Vector3.new(0, 0, 3000),
	colors = {
		grass = Color3.fromRGB(104,214,65), navy = Color3.fromRGB(24,37,61),
		stone = Color3.fromRGB(72,82,100), cyan = Color3.fromRGB(41,201,255),
		ember = Color3.fromRGB(255,130,35), gold = Color3.fromRGB(255,215,54),
		violet = Color3.fromRGB(190,99,255), frost = Color3.fromRGB(130,232,255),
		cream = Color3.fromRGB(255,242,207), steel = Color3.fromRGB(147,169,194),
		path = Color3.fromRGB(235,218,176), white = Color3.fromRGB(250,253,255),
	},
}
function A.cf(x, y, z)
	return CFrame.new(Vector3.new(x, y, z) + A.offset)
end
function A.localPosition(part)
	return part.Position - A.offset
end
function A.group(parent, name, class)
	assert(parent == root or parent:IsDescendantOf(root), "Art outside staged map")
	local old = parent:FindFirstChild(name)
	if old then
		assert(old:GetAttribute("MapRedesignOwned"), "Refusing to replace unowned " .. name)
		old:Destroy()
	end
	local group = Instance.new(class or "Model")
	group.Name = name
	group:SetAttribute("MapRedesignOwned", true)
	group.Parent = parent
	return group
end
function A.ensure(parent,name,class)
	local existing = parent:FindFirstChild(name)
	if existing then
		assert(existing:GetAttribute("MapRedesignOwned"),"Unowned container "..name)
		return existing
	end
	return A.group(parent,name,class)
end
function A.part(parent, name, size, frame, color, material, collide, shape)
	assert(parent == root or parent:IsDescendantOf(root), "Part outside staged map")
	local p = Instance.new(if shape == "Wedge" then "WedgePart" else "Part")
	p.Name, p.Size, p.CFrame = name, size, frame
	if p:IsA("Part") and shape and shape ~= "Wedge" then p.Shape = shape end
	p.Color = color or A.colors.stone
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = collide ~= false
	p.CanTouch = false
	p.CanQuery = p.CanCollide
	p.CastShadow = true
	p.TopSurface = Enum.SurfaceType.Studs
	p.BottomSurface = Enum.SurfaceType.Smooth
	p:SetAttribute("MapRedesignOwned", true)
	p.Parent = parent
	return p
end
function A.cylinder(parent, name, diameter, height, frame, color, material, collide)
	return A.part(parent, name, Vector3.new(height,diameter,diameter),
		frame*CFrame.Angles(0,0,math.pi/2), color, material, collide, Enum.PartType.Cylinder)
end
function A.slope(parent, name, a, b, width, thickness, color)
	local mid = (a+b)/2 + A.offset
	local cf = CFrame.lookAt(mid,b+A.offset)
	return A.part(parent, name, Vector3.new(width,thickness,(b-a).Magnitude+.25),
		cf*CFrame.new(0,-thickness/2,0), color)
end
function A.sign(parent, name, text, size, frame, color)
	local p = A.part(parent,name,size,frame,color or A.colors.navy,nil,false)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Lettering"
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(1000,240)
	gui.LightInfluence = 0
	gui.Parent = p
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(.94,.88)
	label.Position = UDim2.fromScale(.03,.06)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = A.colors.white
	label.TextStrokeColor3 = A.colors.navy
	label.TextStrokeTransparency = 0
	label.TextScaled = true
	label.Text = text
	label.Parent = gui
	return p, label
end
function A.count(parent)
	local n = 0
	for _,v in parent:GetDescendants() do if v:IsA("BasePart") then n+=1 end end
	return n
end
_G.MapRedesignArt = A
