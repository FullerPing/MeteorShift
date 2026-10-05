--!strict
-- Deterministic Edit-time authoring. Execute the entire file in Studio's command bar;
-- inspect ReplicatedStorage.PetModels, save the place, and export the folder as .rbxm.
-- The result is saved geometry only: this tool is outside the Rojo runtime tree.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
assert(RunService:IsStudio() and not RunService:IsRunning(), "Build pet models in Studio Edit mode")
local Config = require(ReplicatedStorage.Shared.Config.Pets)

local M = Enum.Material
local V = Vector3.new
local RGB = Color3.fromRGB
local white, dark, steel, gold = RGB(255, 248, 223), RGB(35, 37, 42), RGB(182, 197, 211), RGB(255, 202, 74)
local copper, amber, mint, violet = RGB(191, 111, 60), RGB(255, 173, 57), RGB(115, 255, 205), RGB(183, 108, 255)

type Builder = { parent: Instance, scale: number, upgraded: boolean, def: any }
local staged = Instance.new("Folder")
staged.Name = "PetModels"
staged:SetAttribute("PetModelsAuthorVersion", 1)

local function part(b: Builder, name: string, size: Vector3, position: Vector3, color: Color3, material: Enum.Material?, shape: Enum.PartType?, rotation: CFrame?): Part
	local p = Instance.new("Part")
	p.Name, p.Size = name, size * b.scale
	p.CFrame = CFrame.new(position * b.scale) * (rotation or CFrame.identity)
	p.Color, p.Material = color, material or M.SmoothPlastic
	p.Shape = shape or Enum.PartType.Block
	p.Anchored, p.Massless = false, true
	p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
	p.CastShadow = false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = b.parent
	return p
end

local function ball(b: Builder, name: string, size: Vector3, position: Vector3, color: Color3, material: Enum.Material?): Part
	return part(b, name, size, position, color, material, Enum.PartType.Ball)
end

local function wedge(b: Builder, name: string, size: Vector3, position: Vector3, color: Color3, material: Enum.Material?, rotation: CFrame?): WedgePart
	local p = Instance.new("WedgePart")
	p.Name, p.Size = name, size * b.scale
	p.CFrame = CFrame.new(position * b.scale) * (rotation or CFrame.identity)
	p.Color, p.Material = color, material or M.SmoothPlastic
	p.Anchored, p.Massless = false, true
	p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = false, false, false, false
	p.Parent = b.parent
	return p
end

local function rod(b: Builder, name: string, from: Vector3, to: Vector3, width: number, color: Color3, material: Enum.Material?): Part
	return part(b, name, V(width, width, (to - from).Magnitude), (from + to) / 2, color, material, nil, CFrame.lookAt(Vector3.zero, to - from).Rotation)
end

local function cylinder(b: Builder, name: string, radius: number, length: number, position: Vector3, color: Color3, material: Enum.Material?, rotation: CFrame?): Part
	return part(b, name, V(length, radius * 2, radius * 2), position, color, material, Enum.PartType.Cylinder, rotation)
end

local function animated(b: Builder, p: BasePart, group: string, pivot: Vector3): BasePart
	p:SetAttribute("AnimationGroup", group)
	p:SetAttribute("AnimationPivot", pivot * b.scale)
	return p
end

local function eye(b: Builder, position: Vector3, size: number, color: Color3, glow: boolean?, group: string?, pivot: Vector3?): BasePart
	return animated(b, ball(b, "Eye", V(size, size, size * 0.45), position, color, if glow then M.Neon else M.SmoothPlastic), group or "Head", pivot or V(0, 0.7, -0.8))
end

local function light(host: BasePart, color: Color3, brightness: number, range: number)
	local item = Instance.new("PointLight")
	item.Name, item.Color, item.Brightness, item.Range = "PetGlow", color, brightness, range
	item.Shadows = false
	item.Parent = host
end

local function particles(host: BasePart, color: Color3, rate: number, burst: boolean?)
	local attachment = Instance.new("Attachment")
	attachment.Name = "SparkOrigin"
	attachment.Parent = host
	local item = Instance.new("ParticleEmitter")
	item.Name = if burst then "WorkingSparks" else "AmbientSparks"
	item.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	item.Color = ColorSequence.new(color, white)
	item.LightEmission = 0.8
	item.Lifetime = NumberRange.new(0.3, 0.7)
	item.Speed = NumberRange.new(0.5, 1.6)
	item.SpreadAngle = Vector2.new(80, 80)
	item.Size = NumberSequence.new(0.09, 0)
	item.Transparency = NumberSequence.new(0.15, 1)
	item.Rate = if burst then 0 else rate
	item:SetAttribute("WorkingBurst", burst == true)
	item.Parent = attachment
end

local function trail(host: BasePart, color: Color3, width: number)
	local a, z = Instance.new("Attachment"), Instance.new("Attachment")
	a.Name, z.Name = "TrailLeft", "TrailRight"
	a.Position, z.Position = V(-width / 2, 0, 0), V(width / 2, 0, 0)
	a.Parent, z.Parent = host, host
	local item = Instance.new("Trail")
	item.Name, item.Attachment0, item.Attachment1 = "PetTrail", a, z
	item.Lifetime, item.MinLength = 0.35, 0.08
	item.Color = ColorSequence.new(color, white)
	item.Transparency = NumberSequence.new(0.55, 1)
	item.WidthScale = NumberSequence.new(1, 0)
	item.LightEmission = 0.7
	item.FaceCamera = true
	item.Parent = host
end

local function ring(b: Builder, name: string, position: Vector3, radius: number, count: number, color: Color3, material: Enum.Material, group: string?)
	for i = 1, count do
		local a = (i - 1) * math.pi * 2 / count
		local z = i * math.pi * 2 / count
		local p = rod(b, name, position + V(math.cos(a) * radius, 0, math.sin(a) * radius), position + V(math.cos(z) * radius, 0, math.sin(z) * radius), 0.07, color, material)
		if group then animated(b, p, group, position) end
	end
end

local function feet(b: Builder, legs: { Vector3 }, color: Color3, material: Enum.Material, long: boolean?)
	for index, position in legs do
		local group = if position.Z < 0 then "FrontLeg" else "BackLeg"
		local height = if long then 1.1 else 0.52
		local pivot = position + V(0, height / 2, 0)
		animated(b, ball(b, "Leg" .. tostring(index), V(0.34, height, 0.38), position, color, material), group, pivot)
		animated(b, ball(b, "Paw" .. tostring(index), V(0.43, 0.22, 0.55), position - V(0, height / 2 - 0.04, 0.1), color, material), group, pivot)
	end
end

local function buildPup(b: Builder)
	ball(b, "Body", V(1.65, 1.2, 2), Vector3.zero, b.def.Color, M.Slate)
	local head = V(0, 0.6, -1.05)
	animated(b, ball(b, "Head", V(1.04, 0.92, 0.95), head, RGB(159, 159, 160), M.Slate), "Head", head)
	animated(b, ball(b, "Muzzle", V(0.62, 0.45, 0.4), head + V(0, -0.18, -0.43), RGB(190, 190, 189), M.Slate), "Head", head)
	for _, side in { -1, 1 } do
		animated(b, ball(b, "Ear", V(0.32, 0.56, 0.34), head + V(side * 0.46, 0.31, 0), RGB(125, 125, 127), M.Slate), "Head", head)
		eye(b, head + V(side * 0.22, 0.07, -0.43), 0.16, dark, false, "Head", head)
	end
	animated(b, ball(b, "Nose", V(0.19, 0.14, 0.14), head + V(0, -0.14, -0.67), dark, M.Slate), "Head", head)
	feet(b, { V(-0.54, -0.58, -0.56), V(0.54, -0.58, -0.56), V(-0.54, -0.58, 0.56), V(0.54, -0.58, 0.56) }, RGB(138, 138, 140), M.Slate)
	for i = 1, 3 do animated(b, ball(b, "Tail", V(0.33, 0.32, 0.36), V(0, 0.2 + i * 0.2, 0.82 + i * 0.2), RGB(138 + i * 8, 138 + i * 8, 140 + i * 8), M.Slate), "Tail", V(0, 0, 0.9)) end
	for i = 1, 4 do
		local chip = ball(b, "DigChip", V(0.07, 0.08, 0.09), V((i - 2.5) * 0.2, -0.5, -0.85), RGB(155, 155, 155), M.Slate)
		chip:SetAttribute("AnimationGroup", "GreyChip")
		chip:SetAttribute("WorkIndex", i)
	end
	if b.upgraded then
		for _, side in { -1, 1 } do ball(b, "StoneAccent", V(0.2, 0.25, 0.25), V(side * 0.8, 0.18, -0.3), RGB(205, 205, 205), M.Slate) end
	end
end

local function buildSparrow(b: Builder)
	ball(b, "Body", V(0.85, 0.83, 1.02), Vector3.zero, b.def.Color, M.Metal)
	local head = V(0, 0.45, -0.49)
	animated(b, ball(b, "Head", V(0.6, 0.58, 0.6), head, RGB(192, 163, 119), M.Metal), "Head", head)
	animated(b, wedge(b, "Beak", V(0.23, 0.2, 0.39), head + V(0, -0.05, -0.42), RGB(151, 86, 52), M.CorrodedMetal, CFrame.Angles(0, math.pi, 0)), "Head", head)
	eye(b, head + V(-0.19, 0.1, -0.25), 0.13, dark, false, "Head", head)
	animated(b, cylinder(b, "BoltEye", 0.09, 0.04, head + V(0.2, 0.1, -0.26), RGB(88, 78, 66), M.Metal, CFrame.Angles(0, math.pi / 2, 0)), "Head", head)
	for _, side in { -1, 1 } do
		for i = 1, 4 do
			local p = part(b, "ScrapPlate", V(0.08, 0.25, 0.48), V(side * (0.39 + i * 0.035), 0.13 - i * 0.09, 0.12 + i * 0.08), RGB(180 + i * 6, 139 + i * 5, 87 + i * 3), M.Metal, nil, CFrame.Angles(0.16, side * 0.14, side * 0.12))
			animated(b, p, if side < 0 then "WingsLeft" else "WingsRight", V(side * 0.34, 0.2, 0))
		end
		rod(b, "Foot", V(side * 0.17, -0.43, 0), V(side * 0.17, -0.62, -0.13), 0.05, copper, M.CorrodedMetal)
	end
	for i = -1, 1 do
		animated(b, part(b, "Tail", V(0.18, 0.07, 0.63), V(i * 0.2, 0.09, 0.74), RGB(133, 106, 76), M.Metal, nil, CFrame.Angles(-0.25, i * 0.15, 0)), "Tail", V(0, 0, 0.4))
		for j = 1, 3 do cylinder(b, "TailSpring", 0.055, 0.03, V(i * 0.2, 0.1, 0.4 + j * 0.05), steel, M.Metal, CFrame.Angles(0, 0, math.pi / 2)) end
	end
	for i = 1, 5 do ball(b, "PlateRivet", V(0.055, 0.055, 0.055), V(math.cos(i) * 0.36, math.sin(i) * 0.28, -0.24), RGB(88, 75, 62), M.Metal) end
	if b.upgraded then part(b, "CopperTrim", V(0.68, 0.055, 0.05), V(0, 0.1, -0.47), copper, M.Metal) end
end

local function buildMule(b: Builder)
	part(b, "Body", V(1.1, 0.92, 1.5), Vector3.zero, b.def.Color, M.Metal)
	local head = V(0, 0.53, -0.9)
	animated(b, ball(b, "Head", V(0.75, 0.64, 1.05), head, RGB(125, 136, 141), M.Metal), "Head", head)
	for _, side in { -1, 1 } do
		eye(b, head + V(side * 0.26, 0.12, -0.39), 0.13, dark, false, "Head", head)
		animated(b, part(b, "Ear", V(0.18, 0.65, 0.28), head + V(side * 0.26, 0.5, 0.06), RGB(120, 128, 133), M.Metal, nil, CFrame.Angles(0, 0, if side < 0 then -0.12 else -0.65)), "Ears", head + V(side * 0.26, 0.2, 0))
		local bag = part(b, "Pannier", V(if b.upgraded then 0.82 else 0.68, if b.upgraded then 0.94 else 0.76, 1.12), V(side * 0.75, -0.05, 0.12), RGB(132, 103, 67), M.Fabric)
		bag:SetAttribute("Pannier", true)
		part(b, "PannierFlap", V(0.07, 0.26, 1.2), V(side * 1.09, 0.29, 0.12), RGB(215, 187, 137), M.Fabric):SetAttribute("Pannier", true)
		part(b, "Buckle", V(0.09, 0.19, 0.24), V(side * 1.12, 0.08, -0.09), if b.upgraded then gold else steel, M.Metal):SetAttribute("Pannier", true)
	end
	feet(b, { V(-0.35, -0.67, -0.48), V(0.35, -0.67, -0.48), V(-0.35, -0.67, 0.48), V(0.35, -0.67, 0.48) }, RGB(88, 100, 107), M.Metal)
	for i = 1, 7 do part(b, "ManeBristle", V(0.13, 0.23, 0.055), V(0, 0.63, -0.73 + i * 0.09), RGB(53, 59, 65), M.Metal) end
	animated(b, rod(b, "Tail", V(0, 0.12, 0.76), V(0, -0.14, 1.12), 0.13, RGB(78, 84, 89), M.Metal), "Tail", V(0, 0.12, 0.76))
	for _, side in { -1, 1 } do part(b, "PanelTrim", V(0.05, 0.06, 0.94), V(side * 0.56, 0.38, 0), if b.upgraded then gold else copper, M.Metal) end
end

local function buildHare(b: Builder)
	ball(b, "Body", V(0.85, 0.97, 1.15), Vector3.zero, b.def.Color, M.Fabric)
	ball(b, "CreamBelly", V(0.64, 0.75, 0.52), V(0, -0.1, -0.36), RGB(255, 238, 197), M.Fabric)
	local head = V(0, 0.54, -0.51)
	animated(b, ball(b, "Head", V(0.77, 0.71, 0.7), head, RGB(255, 219, 104), M.Fabric), "Head", head)
	for _, side in { -1, 1 } do
		eye(b, head + V(side * 0.22, 0.07, -0.31), 0.22, dark, false, "Head", head)
		local pivot = head + V(side * 0.2, 0.2, 0)
		animated(b, ball(b, "Ear", V(0.25, 1.13, 0.23), head + V(side * 0.23, 0.78, 0), b.def.Color, M.Fabric), "Ears", pivot)
		animated(b, ball(b, "EarInner", V(0.12, 0.77, 0.07), head + V(side * 0.23, 0.79, -0.1), RGB(255, 244, 210), M.Fabric), "Ears", pivot)
		for i = 1, if b.upgraded then 4 else 2 do
			animated(b, rod(b, "StaticSpark", head + V(side * 0.23 + i * 0.035, 1.12 + i * 0.07, 0), head + V(side * 0.23 - i * 0.025, 1.19 + i * 0.07, 0), 0.035, RGB(197, 235, 255), M.Neon), "Ears", pivot)
		end
		ball(b, "Haunch", V(0.48, 0.66, 0.63), V(side * 0.33, -0.28, 0.38), b.def.Color, M.Fabric)
		animated(b, ball(b, "Paw", V(0.28, 0.23, 0.52), V(side * 0.25, -0.47, -0.48), RGB(255, 238, 197), M.Fabric), "FrontLeg", V(side * 0.25, -0.24, -0.38))
		animated(b, ball(b, "PawSpark", V(0.08, 0.07, 0.11), V(side * 0.25, -0.52, -0.69), RGB(197, 235, 255), M.Neon), "FrontLeg", V(side * 0.25, -0.24, -0.38))
	end
	ball(b, "Nose", V(0.14, 0.11, 0.1), head + V(0, -0.09, -0.37), RGB(210, 137, 120), M.SmoothPlastic)
	ball(b, "Tail", V(0.34, 0.34, 0.34), V(0, 0.03, 0.65), white, M.Fabric)
	part(b, "SwingSpark", V(0.035, 0.035, 0.7), V(0, 0.7, -0.5), RGB(197, 235, 255), M.Neon):SetAttribute("AnimationGroup", "SparkLink")
	if b.upgraded then part(b, "EarCuff", V(0.31, 0.075, 0.29), head + V(-0.23, 0.5, 0), gold, M.Metal) end
end

local function buildWisp(b: Builder)
	local body = ball(b, "Body", V(0.94, 1.14, 0.84), Vector3.zero, b.def.Color, M.Neon)
	body.Transparency = 0.22
	ball(b, "WhiteCore", V(0.45, 0.7, 0.46), V(0, -0.02, -0.25), white, M.Neon)
	for i = 1, 4 do ball(b, "SpiritTip", V(0.73 - i * 0.13, 0.31, 0.64 - i * 0.11), V(0, 0.5 + i * 0.15, 0), b.def.Color, M.Neon).Transparency = 0.2 end
	for _, side in { -1, 1 } do
		eye(b, V(side * 0.18, 0.07, -0.43), 0.12, RGB(70, 112, 153), false, "Head", Vector3.zero)
		for i = 1, if b.upgraded then 9 else 7 do
			local tail = animated(b, ball(b, "Tail", V(0.27 - i * 0.022, 0.25, 0.29 - i * 0.023), V(side * (0.24 + i * 0.045), -0.35 - i * 0.14, i * 0.035), RGB(141, 236, 255), M.Neon), "Tail", V(side * 0.25, -0.3, 0))
			tail.Transparency = 0.2 + i * 0.08
			if i == 7 then trail(tail, b.def.Color, 0.15) end
		end
	end
	for i = 1, if b.upgraded then 12 else 9 do
		local angle = i * math.pi * 2 / 12
		local plume = ball(b, "SpiritPlume", V(0.08, 0.31, 0.09), V(math.cos(angle) * 0.38, 0.33 + math.sin(angle) * 0.17, math.sin(angle) * 0.32), RGB(162, 244, 255), M.Neon)
		plume.Transparency = 0.45
	end
	light(body, b.def.Color, if b.upgraded then 0.65 else 0.35, 5)
	particles(body, b.def.Color, 1, true)
end

local function buildMagpie(b: Builder)
	ball(b, "Body", V(0.61, 0.6, 0.68), V(0, -0.06, -0.2), b.def.Color, M.Metal)
	ball(b, "BlackBody", V(0.87, 0.97, 1.24), Vector3.zero, RGB(28, 38, 45), M.SmoothPlastic)
	ball(b, "WhiteBreast", V(0.65, 0.73, 0.32), V(0, -0.1, -0.55), white, M.SmoothPlastic)
	local head = V(0, 0.58, -0.55)
	animated(b, ball(b, "Head", V(0.64, 0.63, 0.62), head, RGB(25, 32, 40), M.SmoothPlastic), "Head", head)
	animated(b, wedge(b, "Beak", V(0.18, 0.15, 0.38), head + V(0, -0.04, -0.43), RGB(56, 55, 47), M.Metal, CFrame.Angles(0, math.pi, 0)), "Head", head)
	for _, side in { -1, 1 } do
		eye(b, head + V(side * 0.2, 0.07, -0.24), 0.11, white, false, "Head", head)
		for i = 1, if b.upgraded then 12 else 10 do
			animated(b, part(b, "WingFeather", V(0.08, 0.22, 0.52), V(side * (0.37 + i * 0.018), 0.29 - i * 0.064, 0.07 + i * 0.044), if i <= 4 then white else RGB(66 + i * 7, 104 + i * 8, 74), M.Metal, nil, CFrame.Angles(0.15, side * 0.16, side * 0.14)), if side < 0 then "WingsLeft" else "WingsRight", V(side * 0.35, 0.27, 0))
		end
		rod(b, "Foot", V(side * 0.2, -0.5, 0.12), V(side * 0.2, -0.73, -0.04), 0.06, dark, M.SmoothPlastic)
		for i = 1, 3 do rod(b, "Toe", V(side * 0.2, -0.73, -0.04), V(side * 0.2 + (i - 2) * 0.075, -0.73, -0.19), 0.035, dark, M.SmoothPlastic) end
	end
	for i = -1, 1 do animated(b, part(b, "Tail", V(0.2, 0.1, 1.24), V(i * 0.14, 0.05, 1.08), RGB(40, 71, 66), M.Metal, nil, CFrame.Angles(-0.2, i * 0.13, 0)), "Tail", V(0, 0.04, 0.4)) end
	local coin = animated(b, cylinder(b, "Coin", if b.upgraded then 0.26 else 0.21, 0.05, head + V(0, -0.22, -0.59), gold, M.Metal, CFrame.Angles(0, math.pi / 2, 0)), "Head", head)
	particles(coin, gold, 0, true)
	for i = 1, 4 do
		local glint = rod(b, "CoinGlint", head + V(0, -0.22, -0.64), head + V(math.cos(i * math.pi / 2) * 0.32, -0.22 + math.sin(i * math.pi / 2) * 0.32, -0.64), 0.035, white, M.Neon)
		glint:SetAttribute("AnimationGroup", "CoinGlint")
	end
	if b.upgraded then ring(b, "CoinRim", head + V(0, -0.22, -0.59), 0.25, 8, white, M.Neon) end
end

local function buildMole(b: Builder)
	ball(b, "Body", V(1.27, 1.08, 1.58), Vector3.zero, b.def.Color, M.SmoothPlastic)
	local head = V(0, 0.15, -0.71)
	animated(b, ball(b, "Head", V(1.08, 0.84, 0.95), head, RGB(102, 77, 65), M.SmoothPlastic), "Head", head)
	animated(b, ball(b, "Nose", V(0.37, 0.24, 0.28), head + V(0, -0.04, -0.5), RGB(231, 154, 159), M.SmoothPlastic), "Head", head)
	for _, side in { -1, 1 } do
		animated(b, part(b, "SleepyEye", V(0.18, 0.045, 0.05), head + V(side * 0.26, 0.17, -0.43), dark), "Head", head)
		animated(b, ball(b, "Paw", V(0.38, 0.3, 0.47), V(side * 0.62, -0.34, -0.5), RGB(218, 147, 152)), "FrontLeg", V(side * 0.48, -0.12, -0.4))
		for i = 1, 3 do animated(b, wedge(b, "Claw", V(0.055, 0.1, 0.2), V(side * 0.61 + (i - 2) * 0.1, -0.44, -0.71), RGB(255, 198, 195), M.SmoothPlastic), "FrontLeg", V(side * 0.48, -0.12, -0.4)) end
		ball(b, "BackFoot", V(0.34, 0.26, 0.45), V(side * 0.4, -0.53, 0.44), RGB(218, 147, 152))
	end
	ball(b, "HardHat", V(1.18, 0.49, 0.98), head + V(0, 0.52, 0), RGB(251, 210, 69), M.SmoothPlastic)
	part(b, "HatBrim", V(1.29, 0.09, 1.1), head + V(0, 0.33, -0.02), RGB(235, 181, 40), M.SmoothPlastic)
	local lamp = ball(b, "HatLamp", V(0.22, 0.22, 0.1), head + V(0, 0.54, -0.48), white, M.Neon)
	light(lamp, white, if b.upgraded then 0.5 else 0.25, 4)
	local satchel = part(b, "Satchel", V(0.82, 0.66, 0.58), V(0, 0.33, 0.51), RGB(174, 152, 109), M.Fabric)
	part(b, "SatchelFlap", V(0.86, 0.14, 0.62), V(0, 0.7, 0.52), RGB(203, 180, 133), M.Fabric)
	part(b, "SatchelBuckle", V(0.19, 0.2, 0.07), V(0, 0.43, 0.83), if b.upgraded then gold else steel, M.Metal)
	ball(b, "OreChunk", V(0.21, 0.22, 0.24), V(0.18, 0.8, 0.5), RGB(128, 133, 138), M.Slate):SetAttribute("AnimationGroup", "OreChunk")
	for i = 1, 8 do
		part(b, "SatchelStitch", V(0.055, 0.035, 0.025), V(-0.32 + (i - 1) * 0.09, 0.16, 0.814), RGB(227, 209, 171), M.Fabric)
		part(b, "HatRib", V(0.025, 0.035, 0.58), head + V(-0.42 + (i - 1) * 0.12, 0.68 - math.abs(i - 4.5) * 0.027, 0), RGB(255, 221, 100), M.SmoothPlastic)
	end
	particles(satchel, RGB(173, 175, 178), 0, true)
	if b.upgraded then part(b, "HatStripe", V(0.12, 0.07, 0.85), head + V(0, 0.77, 0), gold, M.Metal) end
end

local function buildGolem(b: Builder)
	part(b, "Body", V(1.15, 1.23, 0.92), Vector3.zero, b.def.Color, M.Granite)
	part(b, "LeftShoulder", V(0.47, 0.48, 0.84), V(-0.75, 0.28, 0), RGB(77, 83, 87), M.Granite)
	part(b, "RightShoulder", V(0.47, 0.48, 0.84), V(0.75, 0.28, 0), RGB(77, 83, 87), M.Granite)
	local head = V(0, 0.93, -0.05)
	animated(b, part(b, "Head", V(0.72, 0.58, 0.73), head, RGB(72, 78, 82), M.Granite), "Head", head)
	for _, side in { -1, 1 } do
		animated(b, part(b, "EyeSlit", V(0.2, 0.06, 0.04), head + V(side * 0.2, 0.02, -0.38), amber, M.Neon), "Head", head)
		animated(b, part(b, "Forearm", V(0.45, 0.68, 0.47), V(side * 0.83, -0.25, -0.05), RGB(76, 82, 87), M.Granite), "FrontLeg", V(side * 0.72, 0.29, 0))
		animated(b, part(b, "Fist", V(0.65, 0.59, 0.66), V(side * 0.84, -0.6, -0.18), RGB(83, 90, 96), M.Granite), "FrontLeg", V(side * 0.72, 0.29, 0))
		animated(b, part(b, "Foot", V(0.46, 0.54, 0.67), V(side * 0.31, -0.85, -0.05), RGB(81, 88, 92), M.Granite), "BackLeg", V(side * 0.31, -0.49, 0))
		part(b, "ChestTrim", V(0.055, 0.68, 0.08), V(side * 0.37, 0.02, -0.49), if b.upgraded then gold else RGB(89, 96, 99), M.Metal)
	end
	part(b, "ChestHatch", V(0.67, 0.67, 0.07), V(0, 0.02, -0.5), RGB(54, 58, 61), M.Metal)
	local glow = part(b, "ChestGlow", V(0.36, 0.045, 0.025), V(0, -0.2, -0.55), amber, M.Neon)
	glow:SetAttribute("CapacityGlow", true)
	particles(glow, amber, 0, true)
	for _, side in { -1, 1 } do
		for i = 1, 8 do
			part(b, "GraniteFacet", V(0.2, 0.22, 0.12), V(side * (0.21 + (i % 2) * 0.26), 0.48 - math.floor((i - 1) / 2) * 0.27, 0.48), RGB(79 + i * 3, 86 + i * 3, 91 + i * 3), M.Granite, nil, CFrame.Angles(0, 0, side * 0.15))
		end
	end
	for i = 1, if b.upgraded then 9 else 5 do ball(b, "Moss", V(0.16, 0.08, 0.15), V(-0.87 + (i % 3) * 0.15, 0.55, -0.28 + math.floor(i / 3) * 0.13), RGB(83 + i * 3, 116 + i * 2, 66), M.Grass) end
	if b.upgraded then light(glow, amber, 0.4, 4) end
end

local function buildStag(b: Builder)
	local body = ball(b, "Body", V(0.84, 0.88, 1.75), Vector3.zero, b.def.Color, M.Glass)
	body.Transparency = 0.15
	ball(b, "PearlUnderbelly", V(0.56, 0.42, 1.49), V(0, -0.32, 0), RGB(244, 229, 255), M.SmoothPlastic)
	rod(b, "Neck", V(0, 0.11, -0.65), V(0, 1.01, -0.98), 0.38, violet, M.Glass)
	local head = V(0, 1.11, -1.04)
	animated(b, ball(b, "Head", V(0.53, 0.5, 0.8), head, RGB(190, 137, 234), M.Glass), "Head", head)
	for _, side in { -1, 1 } do
		eye(b, head + V(side * 0.17, 0.07, -0.35), 0.12, white, true, "Head", head)
		animated(b, wedge(b, "Ear", V(0.22, 0.3, 0.38), head + V(side * 0.33, 0.2, 0.04), RGB(226, 207, 247), M.Glass, CFrame.Angles(0, 0, side * 0.65)), "Head", head)
		local antlerBase = head + V(side * 0.18, 0.2, 0.14)
		local antlerTop = antlerBase + V(side * 0.3, 0.92, 0.18)
		animated(b, rod(b, "Antler", antlerBase, antlerTop, 0.085, violet, M.Neon), "Head", head)
		for branch = 1, if b.upgraded then 5 else 3 do
			local base = antlerBase:Lerp(antlerTop, branch / 6)
			animated(b, rod(b, "AntlerBranch", base, base + V(side * (0.2 + branch * 0.03), 0.28, if branch % 2 == 0 then -0.23 else 0.18), 0.06, violet, M.Neon), "Head", head)
		end
	end
	for index, position in { V(-0.3, -0.9, -0.5), V(0.3, -0.9, -0.5), V(-0.3, -0.9, 0.52), V(0.3, -0.9, 0.52) } do
		local leg = animated(b, part(b, "CrystalLeg" .. tostring(index), V(0.19, 1.35, 0.2), position, violet, M.Glass), if position.Z < 0 then "FrontLeg" else "BackLeg", position + V(0, 0.57, 0))
		leg.Transparency = 0.35
		part(b, "Hoof", V(0.22, 0.17, 0.28), position - V(0, 0.69, 0), RGB(224, 200, 255), M.Glass)
	end
	local tail = ball(b, "Tail", V(0.24, 0.25, 0.44), V(0, 0.13, 0.91), RGB(222, 197, 251), M.Glass)
	trail(tail, violet, 0.2)
	particles(body, violet, if b.upgraded then 3 else 2)
	particles(body, violet, 0, true)
	light(body, violet, if b.upgraded then 0.65 else 0.4, 5)
	for i = 1, 6 do
		local shard = wedge(b, "TargetCrystalShard", V(0.11, 0.23, 0.13), V(0, 0, -1), violet, M.Neon)
		shard:SetAttribute("AnimationGroup", "TargetShard")
		shard:SetAttribute("WorkIndex", i)
	end
	if b.upgraded then ring(b, "CrystalBelt", V(0, 0.05, 0), 0.46, 10, RGB(232, 207, 255), M.Neon) end
end

local function buildWyrm(b: Builder)
	local body = ball(b, "Body", V(1.03, 0.94, 0.82), Vector3.zero, b.def.Color, M.Metal)
	for i = 1, if b.upgraded then 10 else 8 do
		local z = i * 0.29
		local x = math.sin(i * 0.52) * 0.36
		local size = math.max(0.28, 0.98 - i * 0.057)
		animated(b, ball(b, "CopperSegment", V(size, size * 0.88, 0.4), V(x, -i * 0.012, z), copper:Lerp(gold, i * 0.022), M.Metal), "Tail", V(0, 0, 0.3))
		animated(b, ball(b, "AmberSeam", V(size * 0.86, size * 0.77, 0.07), V(x, -i * 0.012, z + 0.21), amber, M.Neon), "Tail", V(0, 0, 0.3))
	end
	local head = V(0, 0.08, -0.63)
	animated(b, ball(b, "Head", V(1.05, 0.89, 0.88), head, RGB(144, 80, 48), M.Metal), "Head", head)
	animated(b, cylinder(b, "DrillMouth", 0.34, 0.2, head + V(0, -0.07, -0.43), dark, M.Metal, CFrame.Angles(0, math.pi / 2, 0)), "Head", head)
	for i = 1, 12 do
		local angle = i * math.pi * 2 / 12
		animated(b, wedge(b, "DrillTooth", V(0.1, 0.13, 0.15), head + V(math.cos(angle) * 0.28, -0.07 + math.sin(angle) * 0.28, -0.57), steel, M.Metal, CFrame.Angles(0, 0, angle)), "Head", head)
	end
	for _, side in { -1, 1 } do eye(b, head + V(side * 0.32, 0.21, -0.35), 0.14, amber, true, "Head", head) end
	trail(body, amber, 0.3)
	particles(body, amber, if b.upgraded then 3 else 2)
	particles(body, amber, 0, true)
	light(body, amber, if b.upgraded then 0.6 else 0.35, 5)
	local tunnel = part(b, "OreTunnel", V(0.035, 0.035, 0.8), Vector3.zero, amber, M.Neon)
	tunnel:SetAttribute("AnimationGroup", "TunnelLight")
	for i = 1, 5 do
		local chunk = ball(b, "TunnelOre", V(0.14, 0.14, 0.2), Vector3.zero, amber, M.Neon)
		chunk:SetAttribute("AnimationGroup", "TunnelOre")
		chunk:SetAttribute("WorkIndex", i)
	end
	if b.upgraded then for i = 1, 6 do part(b, "GoldArmourTrim", V(0.67, 0.055, 0.09), V(math.sin(i * 0.52) * 0.36, 0.4, i * 0.29), gold, M.Metal) end end
end

local function buildOwl(b: Builder)
	local body = ball(b, "Body", V(1.15, 1.37, 0.95), Vector3.zero, b.def.Color, M.SmoothPlastic)
	local head = V(0, 0.72, -0.15)
	animated(b, ball(b, "Head", V(1.18, 0.85, 0.91), head, RGB(71, 167, 158), M.SmoothPlastic), "Head", head)
	for _, side in { -1, 1 } do
		animated(b, ball(b, "FaceDisk", V(0.52, 0.58, 0.12), head + V(side * 0.28, -0.01, -0.44), RGB(194, 255, 220), M.SmoothPlastic), "Head", head)
		eye(b, head + V(side * 0.28, 0.02, -0.53), 0.34, gold, true, "Head", head)
		eye(b, head + V(side * 0.28, 0.02, -0.61), 0.15, dark, false, "Head", head)
		for i = 1, if b.upgraded then 10 else 8 do
			local feather = animated(b, ball(b, "WingFeather", V(0.26, 0.18, 0.86), V(side * (0.62 + i * 0.09), 0.15 - i * 0.065, i * 0.05), RGB(64 + i * 7, 164 + i * 8, 165 + i * 5), M.Metal), if side < 0 then "WingsLeft" else "WingsRight", V(side * 0.5, 0.3, 0))
			feather:SetAttribute("Aurora", true)
			if i == 8 then trail(feather, mint, 0.22) end
		end
		animated(b, wedge(b, "EarTuft", V(0.18, 0.31, 0.24), head + V(side * 0.42, 0.48, 0.02), RGB(93, 230, 186), M.Metal, CFrame.Angles(0, 0, side * 0.4)), "Head", head)
	end
	animated(b, wedge(b, "Beak", V(0.2, 0.28, 0.19), head + V(0, -0.17, -0.53), gold, M.Metal), "Head", head)
	for i = 1, 12 do
		local feather = ball(b, "BreastFeather", V(0.24, 0.27, 0.09), V(((i - 1) % 3 - 1) * 0.27, 0.33 - math.floor((i - 1) / 3) * 0.22, -0.44), RGB(114 + i * 3, 214 + i * 2, 185 + i * 3), M.SmoothPlastic)
		feather:SetAttribute("Aurora", true)
	end
	particles(body, mint, 0, true)
	light(body, mint, if b.upgraded then 0.5 else 0.25, 4)
	if b.upgraded then for i = -1, 1 do rod(b, "AuroraCrown", head + V(i * 0.23, 0.4, 0), head + V(i * 0.32, 0.77, 0), 0.045, mint, M.Neon) end end
end

local function buildDrake(b: Builder)
	local body = ball(b, "Body", V(1.21, 0.98, 1.77), Vector3.zero, b.def.Color, M.Neon)
	ball(b, "CharcoalShell", V(1.29, 1.04, 1.85), Vector3.zero, RGB(51, 47, 45), M.Slate)
	local head = V(0, 0.59, -1.02)
	animated(b, ball(b, "Head", V(0.85, 0.74, 1.06), head, RGB(46, 43, 43), M.Slate), "Head", head)
	animated(b, ball(b, "Muzzle", V(0.59, 0.36, 0.51), head + V(0, -0.15, -0.56), RGB(57, 50, 46), M.Slate), "Head", head)
	for _, side in { -1, 1 } do
		eye(b, head + V(side * 0.24, 0.05, -0.49), 0.18, white, true, "Head", head)
		animated(b, rod(b, "Horn", head + V(side * 0.25, 0.25, 0.17), head + V(side * 0.39, 0.69, 0.35), 0.14, RGB(103, 77, 61), M.Slate), "Head", head)
		animated(b, ball(b, "EmberHornTip", V(0.15, 0.15, 0.2), head + V(side * 0.39, 0.69, 0.35), amber, M.Neon), "Head", head)
		for i = 1, if b.upgraded then 8 else 6 do
			local p = animated(b, wedge(b, "Wings", V(0.17, 0.61 - i * 0.035, 0.58), V(side * (0.69 + i * 0.09), 0.38 - i * 0.025, 0.01 + i * 0.055), RGB(78, 55, 44), M.Slate, CFrame.Angles(0, side * 0.13, side * -0.6)), if side < 0 then "WingsLeft" else "WingsRight", V(side * 0.48, 0.4, 0))
			if i == 6 then particles(p, amber, 1) end
		end
		for i = 1, 8 do rod(b, "LavaCrack", V(side * 0.62, 0.34 - i * 0.07, -0.72 + i * 0.18), V(side * 0.63, 0.28 - i * 0.07, -0.59 + i * 0.18), 0.035, amber, M.Neon) end
	end
	feet(b, { V(-0.47, -0.62, -0.53), V(0.47, -0.62, -0.53), V(-0.47, -0.62, 0.53), V(0.47, -0.62, 0.53) }, RGB(51, 47, 45), M.Slate)
	local tailTip: BasePart = body
	for i = 1, if b.upgraded then 8 else 6 do
		tailTip = animated(b, ball(b, "Tail", V(0.51 - i * 0.045, 0.4 - i * 0.035, 0.52), V(math.sin(i * 0.45) * 0.22, -0.15 - i * 0.08, 0.65 + i * 0.28), RGB(61, 51, 46), M.Slate), "Tail", V(0, -0.13, 0.74))
		animated(b, ball(b, "TailEmber", V(0.1, 0.08, 0.2), V(math.sin(i * 0.45) * 0.22, 0.06 - i * 0.08, 0.65 + i * 0.28), amber, M.Neon), "Tail", V(0, -0.13, 0.74))
	end
	for row = 1, 4 do
		for column = 1, if b.upgraded then 8 else 6 do
			local z = -0.7 + column * 0.2
			local x = (row - 2.5) * 0.23
			part(b, "Scale", V(0.22, 0.09, 0.27), V(x, 0.48 - math.abs(x) * 0.15, z), RGB(60 + row * 3, 51 + row * 2, 46), M.Slate, nil, CFrame.Angles(0.15, 0, 0))
		end
	end
	trail(tailTip, amber, 0.16)
	particles(tailTip, amber, if b.upgraded then 4 else 3)
	particles(body, amber, 0, true)
	light(body, RGB(255, 142, 62), if b.upgraded then 1.2 else 0.8, 8)
	for i = 1, 4 do
		local flame = ball(b, "FlameBreath", V(0.11 + i * 0.09, 0.1 + i * 0.08, 0.48), head + V(0, -0.15, -0.65), if i == 1 then white else amber:Lerp(RGB(255, 98, 34), i / 4), M.Neon)
		flame:SetAttribute("AnimationGroup", "FlameBreath")
		flame:SetAttribute("WorkIndex", i)
	end
	local streak = rod(b, "MeteorArrivalStreak", V(0, 0, 0), V(-0.5, 2, 0.6), 0.09, amber, M.Neon)
	streak:SetAttribute("AnimationGroup", "ArrivalStreak")
	if b.upgraded then for i = 1, 5 do wedge(b, "DorsalEmber", V(0.14, 0.35, 0.28), V(0, 0.66, -0.56 + i * 0.27), amber, M.Neon) end end
end

local function buildDrillbot(b: Builder)
	local body = ball(b, "Body", V(1.14, 0.85, 1.12), Vector3.zero, b.def.Color, M.Metal)
	ball(b, "SteelShell", V(1.22, 0.93, 1.2), Vector3.zero, steel, M.Metal)
	for i = -2, 2 do part(b, "HazardStripe", V(0.13, 0.04, 0.65), V(i * 0.17, 0.47, 0), RGB(255, 152, 34), M.Metal, nil, CFrame.Angles(0, -0.38, 0)) end
	local eyeLens = cylinder(b, "Head", 0.19, 0.08, V(0, 0.22, -0.59), amber, M.Neon, CFrame.Angles(0, math.pi / 2, 0))
	light(eyeLens, amber, 0.9, 6)
	local drillBase = V(0, -0.15, -0.52)
	for i = 1, if b.upgraded then 9 else 7 do
		local radius = math.max(0.055, 0.38 - i * 0.036)
		animated(b, cylinder(b, "Drill", radius, 0.13, drillBase - V(0, 0, i * 0.105), if b.upgraded and i % 2 == 0 then gold else RGB(116 + i * 8, 129 + i * 8, 146 + i * 8), M.Metal, CFrame.Angles(0, math.pi / 2, i * 0.47)), "Drill", drillBase)
		for blade = 1, 3 do
			local a = blade * math.pi * 2 / 3 + i * 0.45
			animated(b, wedge(b, "DrillEdge", V(0.055, 0.08, 0.13), drillBase + V(math.cos(a) * radius, math.sin(a) * radius, -i * 0.105), RGB(233, 237, 244), M.Metal, CFrame.Angles(0, 0, a)), "Drill", drillBase)
		end
	end
	for _, side in { -1, 1 } do
		rod(b, "RotorArm", V(side * 0.4, 0.1, 0.2), V(side * 1.04, 0.4, 0.23), 0.1, steel, M.Metal)
		local center = V(side * 1.07, 0.46, 0.24)
		cylinder(b, "RotorHub", 0.14, 0.17, center, if b.upgraded then gold else steel, M.Metal, CFrame.Angles(0, 0, math.pi / 2))
		ring(b, "RotorGuard", center + V(0, 0.08, 0), if b.upgraded then 0.63 else 0.55, 16, if b.upgraded then gold else steel, M.Metal)
		for blade = 1, 4 do
			local a = blade * math.pi / 2
			local p = part(b, "Wings", V(if b.upgraded then 0.72 else 0.59, 0.045, 0.13), center + V(math.cos(a) * 0.23, 0.1, math.sin(a) * 0.23), dark, M.Metal, nil, CFrame.Angles(0, -a, 0))
			animated(b, p, if side < 0 then "WingsLeft" else "WingsRight", center)
		end
		for i = 1, 5 do part(b, "HeatVent", V(0.025, 0.055, 0.22), V(side * 0.58, -0.18 + i * 0.083, 0.08), dark, M.Metal) end
	end
	for i = 1, 12 do
		local a = i * math.pi * 2 / 12
		ball(b, "ShellBolt", V(0.075, 0.075, 0.075), V(math.cos(a) * 0.52, math.sin(a) * 0.34, -0.47), RGB(114, 129, 149), M.Metal)
	end
	local engineColor = if b.upgraded then RGB(99, 203, 255) else amber
	local engine = cylinder(b, "Engine", 0.26, 0.12, V(0, 0, 0.58), engineColor, M.Neon, CFrame.Angles(0, math.pi / 2, 0))
	particles(engine, engineColor, 4)
	particles(eyeLens, amber, 0, true)
	trail(engine, engineColor, 0.28)
	light(engine, engineColor, 0.8, 6)
	for i = 1, 3 do
		local heat = ball(b, "HeatShimmer", V(0.4 + i * 0.12, 0.035, 0.38), V(0, 0.24 + i * 0.14, -0.73), RGB(255, 199, 95), M.Glass)
		heat:SetAttribute("AnimationGroup", "HeatWave")
		heat:SetAttribute("WorkIndex", i)
	end
	if b.upgraded then
		for _, side in { -1, 1 } do part(b, "GoldTrim", V(0.04, 0.5, 0.75), V(side * 0.61, 0.03, 0), gold, M.Metal) end
	end
end

local function buildPhoenix(b: Builder)
	local body = ball(b, "Body", V(0.91, 1.09, 1.04), Vector3.zero, b.def.Color, M.Neon)
	ball(b, "MoltenGoldBreast", V(0.96, 1.05, 0.8), V(0, 0.05, -0.22), gold, M.Metal)
	ball(b, "WhiteFireCore", V(0.53, 0.85, 0.22), V(0, 0.08, -0.59), white, M.Neon)
	local head = V(0, 0.85, -0.46)
	animated(b, ball(b, "Head", V(0.58, 0.62, 0.68), head, gold, M.Metal), "Head", head)
	animated(b, wedge(b, "Beak", V(0.19, 0.2, 0.37), head + V(0, -0.06, -0.41), white, M.Neon, CFrame.Angles(0, math.pi, 0)), "Head", head)
	for _, side in { -1, 1 } do
		eye(b, head + V(side * 0.18, 0.06, -0.29), 0.15, white, true, "Head", head)
		for layer = 1, 2 do
			for i = 1, if b.upgraded then 12 else 10 do
				local feather = animated(b, wedge(b, "Wings", V(0.2, 0.43 + i * 0.025, 0.8 - layer * 0.1), V(side * (0.51 + i * 0.1), 0.25 - i * 0.038 + layer * 0.075, 0.06 + i * 0.06), if layer == 1 then gold else white, if layer == 1 then M.Metal else M.Neon, CFrame.Angles(0.22, side * -0.12, side * -0.72)), if side < 0 then "WingsLeft" else "WingsRight", V(side * 0.43, 0.36, 0))
				if i == 10 and layer == 1 then trail(feather, gold, 0.23) end
			end
		end
	end
	for layer = 1, 3 do
		for i = 1, if b.upgraded then 9 else 7 do
			animated(b, wedge(b, "Tail", V(0.31 - layer * 0.035, 0.15, 0.69), V((layer - 2) * (0.18 + i * 0.026), -0.24 - i * 0.11, 0.5 + i * 0.22), if layer == 2 then white else gold:Lerp(amber, i * 0.06), if layer == 2 then M.Neon else M.Metal, CFrame.Angles(-0.32, (layer - 2) * 0.06, 0)), "Tail", V(0, -0.14, 0.4))
		end
	end
	for i = -3, 3 do
		animated(b, rod(b, "CrownRay", head + V(i * 0.055, 0.24, 0.06), head + V(i * 0.13, 0.71 - math.abs(i) * 0.045, 0.11), 0.055, gold, M.Neon), "Head", head)
	end
	ring(b, "Halo", V(0, 1.68, -0.18), if b.upgraded then 0.78 else 0.65, 24, gold, M.Neon, "Halo")
	for i = 1, 12 do
		local a = i * math.pi * 2 / 12
		animated(b, ball(b, "HaloSpark", V(0.055, 0.055, 0.055), V(math.cos(a) * 0.65, 1.68, -0.18 + math.sin(a) * 0.65), white, M.Neon), "Halo", V(0, 1.68, -0.18))
	end
	light(body, RGB(255, 200, 100), if b.upgraded then 1.5 else 1.2, 9)
	particles(body, gold, if b.upgraded then 5 else 4)
	particles(body, white, 0, true)
	trail(body, gold, 0.32)
	ring(b, "SunlightBurst", V(0, -0.2, 0), 1.35, 24, white, M.Neon, "WorkingRing")
	local scorch = cylinder(b, "ScorchGlow", 0.65, 0.025, V(0, -0.3, 0), amber, M.Neon, CFrame.Angles(0, 0, math.pi / 2))
	scorch:SetAttribute("AnimationGroup", "ScorchGlow")
	if b.upgraded then for i = -2, 2 do part(b, "GoldBreastTrim", V(0.08, 0.52, 0.035), V(i * 0.12, 0, -0.65), gold, M.Metal, nil, CFrame.Angles(0, 0, i * 0.14)) end end
end

local builders: { [string]: (Builder) -> () } = {
	pebblePup = buildPup, scrapSparrow = buildSparrow, packMule = buildMule, sparkHare = buildHare,
	jetWisp = buildWisp, coinMagpie = buildMagpie, cargoMole = buildMole, graniteGolem = buildGolem,
	crystalStag = buildStag, lodeWyrm = buildWyrm, auroraOwl = buildOwl, meteorDrake = buildDrake,
	drillbot = buildDrillbot, solarPhoenix = buildPhoenix,
}
local flying: { [string]: boolean } = { scrapSparrow = true, jetWisp = true, coinMagpie = true, auroraOwl = true, drillbot = true, solarPhoenix = true }
local styles = { scrapSparrow = "chirp", coinMagpie = "chirp", auroraOwl = "chirp", cargoMole = "haul", lodeWyrm = "haul", jetWisp = "flash", sparkHare = "flash", drillbot = "drill", solarPhoenix = "dive" }
local report = {}

local ok, failure = pcall(function()
	for _, def in Config.List do
		local make = builders[def.Id]
		assert(make, "No pet builder for " .. def.Id)
		local model = Instance.new("Model")
		model.Name = def.Id
		model:SetAttribute("PetColor", def.Color)
		model:SetAttribute("PetName", def.Name)
		model:SetAttribute("Rarity", def.Rarity)
		model:SetAttribute("Flying", flying[def.Id] == true)
		model:SetAttribute("WorkingStyle", styles[def.Id] or "dig")
		model.Parent = staged
		make({ parent = model, scale = 1, upgraded = false, def = def })
		local body = model:FindFirstChild("Body")
		assert(body and body:IsA("BasePart"), "Body is required for " .. def.Id)
		model.PrimaryPart = body
		local upgraded = Instance.new("Folder")
		upgraded.Name, upgraded.Parent = "Level10", model
		make({ parent = upgraded, scale = 1.06, upgraded = true, def = def })
		local upgradedBody = upgraded:FindFirstChild("Body")
		assert(upgradedBody and upgradedBody:IsA("BasePart"), "Level10 Body is required for " .. def.Id)
		local count = 0
		for _, item in model:GetDescendants() do
			assert(not item:IsA("LuaSourceContainer"), "Pet model may not contain scripts")
			if item:IsA("BasePart") then
				count += 1
				assert(not item.Anchored and not item.CanCollide and not item.CanTouch and not item.CanQuery, "Pet geometry must be unanchored and inert")
			end
			if def.Rarity == "common" or def.Rarity == "uncommon" then
				assert(not item:IsA("Light") and not item:IsA("ParticleEmitter"), "Lights and particles start at Rare")
			end
			if def.Id ~= "solarPhoenix" then assert(item.Name ~= "Halo", "Only Solar Phoenix has a halo") end
		end
		local cap = if def.Rarity == "legendary" or def.Rarity == "premium" then 400 else 299
		assert(count <= cap, string.format("%s has %d parts, cap %d", def.Id, count, cap))
		model:SetAttribute("PartCount", count)
		table.insert(report, string.format("%s: %d parts (both looks)", def.Id, count))
	end
	assert(#staged:GetChildren() == 14, "Pet roster must contain fourteen models")
end)

if not ok then staged:Destroy() error(tostring(failure), 0) end
local old = ReplicatedStorage:FindFirstChild("PetModels")
if old then old:Destroy() end
staged.Parent = ReplicatedStorage
print("PetModels built; save the place and export this folder to assets/PetModels.rbxm\n" .. table.concat(report, "\n"))
return staged
