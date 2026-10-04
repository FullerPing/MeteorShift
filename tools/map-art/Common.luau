-- Edit-time authoring helpers. Run with a stage file in Studio Edit mode.
-- These files are deliberately outside the Rojo tree: no runtime world builder.
assert(game:GetService("RunService"):IsStudio(), "Studio authoring only")
assert(not game:GetService("RunService"):IsRunning(), "Stop Play before authoring")
local Map = workspace:WaitForChild("Map")
local Assets = game.ServerStorage:WaitForChild("Assets")
local C = {
	wood = Color3.fromRGB(106, 68, 43), trim = Color3.fromRGB(58, 43, 34),
	metal = Color3.fromRGB(47, 58, 63), copper = Color3.fromRGB(188, 113, 59),
	stone = Color3.fromRGB(113, 111, 101), dark = Color3.fromRGB(49, 48, 48),
	cream = Color3.fromRGB(224, 203, 155), blue = Color3.fromRGB(66, 119, 131),
	green = Color3.fromRGB(100, 131, 72), glow = Color3.fromRGB(255, 170, 68),
}
local M = Enum.Material
local function group(parent, name)
	local old = parent:FindFirstChild(name)
	if old then
		assert(old:GetAttribute("MapArtOwned"), "Refusing to replace non-art model " .. old:GetFullName())
		old:Destroy()
	end
	local model = Instance.new("Model")
	model.Name = name
	model:SetAttribute("MapArtOwned", true)
	model.Parent = parent
	return model
end
local function part(parent, name, size, cf, color, material, shape)
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame = name, size, cf
	p.Color, p.Material = color or C.metal, material or M.Metal
	if shape then p.Shape = shape end
	p.Anchored = true
	p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
	p.CastShadow = false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p:SetAttribute("MapArtOwned", true)
	p.Parent = parent
	return p
end
local function block(parent, name, size, cf, color, material)
	return part(parent, name, Vector3.new(unpack(size)), cf, color, material)
end
local function rod(parent, name, a, b, width, color, material)
	local mid = (a+b)/2
	return part(parent, name, Vector3.new(width, width, (b-a).Magnitude), CFrame.lookAt(mid,b), color, material)
end
local function cylinder(parent, name, radius, height, cf, color, material)
	return part(parent,name,Vector3.new(height,radius*2,radius*2),cf*CFrame.Angles(0,0,math.pi/2),color,material,Enum.PartType.Cylinder)
end
local function ball(parent, name, size, cf, color, material)
	return part(parent,name,Vector3.new(unpack(size)),cf,color,material,Enum.PartType.Ball)
end
local function label(facePart, text, color, face)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "ArtLettering"
	gui.Face = face or Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(500,180)
	gui.LightInfluence = 1
	gui.Parent = facePart
	local txt = Instance.new("TextLabel")
	txt.Size = UDim2.fromScale(1,1)
	txt.BackgroundTransparency = 1
	txt.Font = Enum.Font.GothamBold
	txt.TextColor3 = color or C.cream
	txt.TextScaled = true
	txt.Text = text
	txt.Parent = gui
end
local function count(root)
	local n = 0
	for _,p in ipairs(root:GetDescendants()) do if p:IsA("BasePart") then n += 1 end end
	return n
end
