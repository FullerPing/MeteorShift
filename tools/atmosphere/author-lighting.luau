--!strict
-- Edit-time authoring for the place's fog, atmosphere and lighting. Run once in
-- Studio's command bar (or execute_luau in Edit mode), check the look, then save
-- the place. Nothing in the game runs this: the result is saved in the place like
-- the rest of the map, and AtmosphereController only blends the saved values
-- toward Config.Atmosphere's moods during meteor events.
--
-- Safe to re-run: it updates the existing Lighting children by name and rebuilds
-- Workspace.Map.Atmosphere (the mist, ember and dust emitters).

local Lighting = game:GetService("Lighting")

local function child(parent: Instance, className: string, name: string): any
	local existing = parent:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing
	end
	local created = Instance.new(className)
	created.Name = name
	created.Parent = parent
	return created
end

-- Late afternoon over a dusty crater: a low warm sun, cool shadows, haze that
-- swallows the far cliffs and a soft band of glare around the sun.
Lighting.ClockTime = 17.2
Lighting.GeographicLatitude = 0
Lighting.Brightness = 2.2
Lighting.Ambient = Color3.fromRGB(62, 56, 62)
Lighting.OutdoorAmbient = Color3.fromRGB(128, 114, 112)
Lighting.ColorShift_Top = Color3.fromRGB(255, 224, 192)
Lighting.ColorShift_Bottom = Color3.fromRGB(0, 0, 0)
Lighting.EnvironmentDiffuseScale = 1
Lighting.EnvironmentSpecularScale = 1
Lighting.ExposureCompensation = 0
Lighting.GlobalShadows = true
Lighting.ShadowSoftness = 0.25

local atmosphere = child(Lighting, "Atmosphere", "Atmosphere")
atmosphere.Density = 0.38
atmosphere.Offset = 0.12
atmosphere.Color = Color3.fromRGB(206, 170, 140)
atmosphere.Decay = Color3.fromRGB(146, 98, 84)
atmosphere.Glare = 0.8
atmosphere.Haze = 2

local bloom = child(Lighting, "BloomEffect", "Bloom")
bloom.Intensity = 0.7
bloom.Size = 28
bloom.Threshold = 1.35

local grade = child(Lighting, "ColorCorrectionEffect", "Grade")
grade.Brightness = 0
grade.Contrast = 0.1
grade.Saturation = 0.05
grade.TintColor = Color3.fromRGB(255, 238, 222)

local sunRays = child(Lighting, "SunRaysEffect", "SunRays")
sunRays.Intensity = 0.08
sunRays.Spread = 0.55

-- Depth of field stays off: it blurs the crater from town and costs the most on phones.
local dof = Lighting:FindFirstChildOfClass("DepthOfFieldEffect")
if dof then
	dof.Enabled = false
end

-- Slow high clouds; the meteor approach thickens and darkens them
local clouds = child(workspace.Terrain, "Clouds", "Clouds")
clouds.Cover = 0.5
clouds.Density = 0.32
clouds.Color = Color3.fromRGB(255, 236, 222)

-- Local mist, embers and dust, saved under the map
local map = workspace:FindFirstChild("Map")
assert(map, "Workspace.Map is missing")
local old = map:FindFirstChild("Atmosphere")
if old then
	old:Destroy()
end
local folder = Instance.new("Folder")
folder.Name = "Atmosphere"

local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"

local function groundY(x: number, z: number): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain, map:FindFirstChild("Ground") :: Instance, map:FindFirstChild("Crater") :: Instance }
	local hit = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -600, 0), params)
	return if hit then hit.Position.Y else 0
end

local function host(parent: Instance, name: string, cframe: CFrame, size: Vector3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = size
	part.CFrame = cframe
	part.Locked = true
	part.Parent = parent
	return part
end

local function seq(points: { { number } }): NumberSequence
	local keypoints = {}
	for _, point in points do
		table.insert(keypoints, NumberSequenceKeypoint.new(point[1], point[2]))
	end
	return NumberSequence.new(keypoints)
end

-- Ground mist pooling in the crater bowl
local craterMist = Instance.new("Folder")
craterMist.Name = "CraterMist"
craterMist.Parent = folder
for i = 0, 4 do
	local angle = i / 5 * math.pi * 2 + 0.4
	local radius = if i == 0 then 0 else 30
	local x, z = math.cos(angle) * radius, math.sin(angle) * radius
	local y = groundY(x, z)
	local part = host(craterMist, "Mist", CFrame.new(x, y + 2, z), Vector3.new(38, 1, 38))
	local mist = Instance.new("ParticleEmitter")
	mist.Name = "Mist"
	mist.Texture = SMOKE
	mist.Shape = Enum.ParticleEmitterShape.Box
	mist.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	mist.EmissionDirection = Enum.NormalId.Top
	mist.Color = ColorSequence.new(Color3.fromRGB(196, 176, 160), Color3.fromRGB(176, 150, 134))
	mist.LightInfluence = 1
	mist.Size = seq({ { 0, 16 }, { 1, 34 } })
	mist.Transparency = seq({ { 0, 1 }, { 0.25, 0.86 }, { 0.75, 0.9 }, { 1, 1 } })
	mist.Lifetime = NumberRange.new(14, 20)
	mist.Rate = 0.7
	mist.Speed = NumberRange.new(0.4, 1.2)
	mist.SpreadAngle = Vector2.new(80, 80)
	mist.Acceleration = Vector3.new(0.3, 0.05, 0.2)
	mist.Rotation = NumberRange.new(0, 360)
	mist.RotSpeed = NumberRange.new(-4, 4)
	mist.Parent = part
end

-- A soft mist band at the foot of the boundary cliffs, past the plots
local valleyMist = Instance.new("Folder")
valleyMist.Name = "ValleyMist"
valleyMist.Parent = folder
for i = 0, 11 do
	local angle = i / 12 * math.pi * 2
	local x, z = math.cos(angle) * 252, math.sin(angle) * 252
	local y = groundY(x, z)
	local facing = CFrame.lookAt(Vector3.new(x, y + 4, z), Vector3.new(0, y + 4, 0))
	local part = host(valleyMist, "Mist", facing, Vector3.new(120, 2, 24))
	local mist = Instance.new("ParticleEmitter")
	mist.Name = "Mist"
	mist.Texture = SMOKE
	mist.Shape = Enum.ParticleEmitterShape.Box
	mist.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	mist.EmissionDirection = Enum.NormalId.Top
	mist.Color = ColorSequence.new(Color3.fromRGB(214, 190, 170))
	mist.LightInfluence = 1
	mist.Size = seq({ { 0, 30 }, { 1, 54 } })
	mist.Transparency = seq({ { 0, 1 }, { 0.3, 0.8 }, { 0.7, 0.84 }, { 1, 1 } })
	mist.Lifetime = NumberRange.new(18, 24)
	mist.Rate = 0.45
	mist.Speed = NumberRange.new(0.2, 0.8)
	mist.SpreadAngle = Vector2.new(60, 60)
	mist.Acceleration = Vector3.new(0, 0.04, 0)
	mist.Rotation = NumberRange.new(0, 360)
	mist.RotSpeed = NumberRange.new(-2, 2)
	mist.Parent = part
end

-- Embers drifting up out of the scorched crater
do
	local y = groundY(0, 0)
	local part = host(folder, "CraterEmbers", CFrame.new(0, y + 3, 0), Vector3.new(90, 2, 90))
	local embers = Instance.new("ParticleEmitter")
	embers.Name = "Embers"
	embers.Texture = SPARKLE
	embers.Shape = Enum.ParticleEmitterShape.Box
	embers.EmissionDirection = Enum.NormalId.Top
	embers.Color = ColorSequence.new(Color3.fromRGB(255, 186, 96), Color3.fromRGB(255, 96, 40))
	embers.LightEmission = 1
	embers.LightInfluence = 0
	embers.Brightness = 1.5
	embers.Size = seq({ { 0, 0.35 }, { 1, 0.1 } })
	embers.Transparency = seq({ { 0, 1 }, { 0.15, 0.2 }, { 0.8, 0.4 }, { 1, 1 } })
	embers.Lifetime = NumberRange.new(5, 9)
	embers.Rate = 4
	embers.Speed = NumberRange.new(2, 5)
	embers.SpreadAngle = Vector2.new(25, 25)
	embers.Acceleration = Vector3.new(0.8, 1.2, 0.4)
	embers.Drag = 0.4
	embers.Parent = part
end

-- Dust motes catching the low sun over the town square
do
	local square = map:FindFirstChild("TownSquare")
	local center = if square and square:IsA("Model") then square:GetBoundingBox().Position else Vector3.new(0, 8, -95)
	local part = host(folder, "TownDust", CFrame.new(center.X, groundY(center.X, center.Z) + 9, center.Z), Vector3.new(70, 16, 60))
	local dust = Instance.new("ParticleEmitter")
	dust.Name = "Motes"
	dust.Texture = SPARKLE
	dust.Shape = Enum.ParticleEmitterShape.Box
	dust.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	dust.Color = ColorSequence.new(Color3.fromRGB(255, 232, 196))
	dust.LightEmission = 0.3
	dust.LightInfluence = 0.4
	dust.Size = seq({ { 0, 0.12 }, { 0.5, 0.2 }, { 1, 0.1 } })
	dust.Transparency = seq({ { 0, 1 }, { 0.2, 0.6 }, { 0.8, 0.7 }, { 1, 1 } })
	dust.Lifetime = NumberRange.new(8, 12)
	dust.Rate = 2
	dust.Speed = NumberRange.new(0.2, 0.6)
	dust.SpreadAngle = Vector2.new(180, 180)
	dust.Acceleration = Vector3.new(0.15, 0.05, 0.1)
	dust.Parent = part
end

folder.Parent = map

return "Lighting authored; save the place to keep it"
