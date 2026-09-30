--!strict
-- Shared geometry for shop ViewportFrames and the equipped pickaxe. Builders
-- return unparented, anchored models; no assets, scripts or physics are needed.
-- Pickaxe shafts follow Y, their heads follow X, and backpack fronts face -Z.

local Config = require(script.Parent.Config)

local EquipmentModels = {}
local DARK = Color3.fromRGB(29, 37, 51)
local STEEL = Color3.fromRGB(133, 156, 177)
local LIGHT = Color3.fromRGB(227, 241, 249)
local GOLD = Color3.fromRGB(255, 201, 92)
local CYAN = Color3.fromRGB(109, 239, 255)
local METAL = Enum.Material.Metal
local NEON = Enum.Material.Neon
local V = Vector3.new

local function part(model: Model, name: string, size: Vector3, frame: CFrame, color: Color3,
	material: Enum.Material?, shape: string?): BasePart
	local made: BasePart
	if shape == "Wedge" then
		made = Instance.new("WedgePart")
	else
		local block = Instance.new("Part")
		if shape == "Ball" then
			block.Shape = Enum.PartType.Ball
		elseif shape == "Cylinder" then
			block.Shape = Enum.PartType.Cylinder
		end
		block.TopSurface = Enum.SurfaceType.Smooth
		block.BottomSurface = Enum.SurfaceType.Smooth
		made = block
	end
	made.Name = name
	made.Size = size
	made.CFrame = frame
	made.Color = color
	made.Material = material or Enum.Material.SmoothPlastic
	made.Anchored = true
	made.CanCollide = false
	made.CanTouch = false
	made.CanQuery = false
	made.CastShadow = false
	made.Massless = true
	made.Parent = model
	return made
end

local function block(model: Model, name: string, size: Vector3, position: Vector3, color: Color3,
	material: Enum.Material?, roll: number?): BasePart
	return part(model, name, size, CFrame.new(position) * CFrame.Angles(0, 0, math.rad(roll or 0)), color, material)
end

local function beam(model: Model, name: string, a: Vector3, b: Vector3, width: number, depth: number,
	color: Color3, material: Enum.Material?)
	part(model, name, V(width, (b - a).Magnitude, depth),
		CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(math.pi / 2, 0, 0), color, material)
end

local function ring(model: Model, name: string, frame: CFrame, radius: number, color: Color3,
	width: number, material: Enum.Material?, count: number?)
	local segments = count or 12
	for i = 1, segments do
		local angle = (i - 0.5) * math.pi * 2 / segments
		part(model, name, V(width, 2 * radius * math.sin(math.pi / segments) + 0.025, width),
			frame * CFrame.new(math.cos(angle) * radius, math.sin(angle) * radius, 0)
				* CFrame.Angles(0, 0, angle), color, material)
	end
end

-- A triangular blade in the XY plane, with its narrow point toward +X.
local function blade(model: Model, name: string, position: Vector3, length: number, height: number,
	depth: number, color: Color3, roll: number?, material: Enum.Material?)
	part(model, name, V(depth, height, length), CFrame.new(position)
		* CFrame.Angles(0, 0, math.rad(roll or 0)) * CFrame.Angles(0, -math.pi / 2, 0), color, material or METAL, "Wedge")
end

local function orb(model: Model, name: string, position: Vector3, size: number, color: Color3, material: Enum.Material?)
	part(model, name, V(size, size, size), CFrame.new(position), color, material, "Ball")
end

local function shaft(model: Model, tier: number, accent: Color3)
	local wood = Color3.fromRGB(113, 75, 47)
	block(model, "Shaft", V(0.3, 4.15, 0.32), V(0, -0.15, 0), if tier == 1 then wood else DARK,
		if tier == 1 then Enum.Material.Wood else METAL)
	for i = 1, 4 do
		block(model, "GripBand", V(0.37, 0.11, 0.4), V(0, -1.1 - i * 0.2, 0), if tier <= 2 then DARK else STEEL)
	end
	block(model, "Pommel", V(0.47, 0.23, 0.47), V(0, -2.15, 0), if tier == 1 then DARK else accent, METAL)
	block(model, "HeadCollar", V(0.58, 0.38, 0.6), V(0, 1.25, 0), STEEL, METAL)
	if tier >= 4 then
		block(model, "PowerSpine", V(0.1, 1.65, 0.04), V(0, 0.18, -0.18), accent, NEON)
	end
end

function EquipmentModels.pickaxe(tier: number): Model
	local item = Config.Pickaxes[tier] or Config.Pickaxes[1]
	tier = item.Tier
	local model = Instance.new("Model")
	model.Name = item.Name
	model:SetAttribute("EquipmentTier", tier)
	local accent = item.Color
	shaft(model, tier, accent)
	if tier == 1 then
		block(model, "ForgedHead", V(2.7, 0.46, 0.55), V(0, 1.65, 0), accent, METAL)
		blade(model, "PickPoint", V(1.75, 1.48, 0), 1.2, 0.44, 0.45, accent, -18)
		block(model, "HammerEnd", V(0.5, 0.72, 0.7), V(-1.35, 1.6, 0), DARK, METAL)
	elseif tier == 2 then
		block(model, "SteelSocket", V(0.8, 0.85, 0.75), V(0, 1.6, 0), DARK, METAL)
		for _, side in { -1, 1 } do
			blade(model, "ForgedWing", V(side * 1.1, 1.65, 0), 1.8, 0.8, 0.55, accent, if side == 1 then -12 else 192)
			beam(model, "CuttingEdge", V(side * 0.45, 2.02, -0.3), V(side * 1.95, 1.45, -0.3), 0.13, 0.09, LIGHT, METAL)
		end
		block(model, "SocketBadge", V(0.34, 0.34, 0.08), V(0, 1.65, -0.42), GOLD, METAL, 45)
	elseif tier == 3 then
		part(model, "DrillMotor", V(1.65, 1.05, 1.05), CFrame.new(-0.25, 1.6, 0), DARK, METAL, "Cylinder")
		part(model, "MotorCasing", V(0.8, 1.22, 1.22), CFrame.new(-0.55, 1.6, 0), accent, METAL, "Cylinder")
		for i = 0, 4 do
			local diameter = 0.94 - i * 0.17
			part(model, "DrillFlute", V(0.37, diameter, diameter), CFrame.new(0.8 + i * 0.32, 1.6, 0)
				* CFrame.Angles(math.rad(i * 26), 0, 0), if i % 2 == 0 then STEEL else LIGHT, METAL, "Cylinder")
		end
		blade(model, "DrillTip", V(2.25, 1.6, 0), 0.6, 0.24, 0.24, LIGHT)
		for i = 1, 3 do
			block(model, "MotorVent", V(0.1, 0.45, 0.05), V(-0.85 + i * 0.22, 1.62, -0.62), DARK)
		end
		beam(model, "Brace", V(-1.2, 1.25, 0), V(-0.25, 0.45, 0), 0.22, 0.22, accent, METAL)
	elseif tier == 4 then
		block(model, "PlasmaReactor", V(1.1, 0.8, 0.9), V(0, 1.65, 0), DARK, METAL)
		orb(model, "PlasmaCore", V(0, 1.7, -0.48), 0.58, accent, NEON)
		for _, side in { -1, 1 } do
			beam(model, "ForkArm", V(side * 0.45, 1.35, 0), V(side * 1.38, 2.1, 0), 0.32, 0.44, STEEL, METAL)
			blade(model, "EnergyProng", V(side * 1.85, 2.1, 0), 1.1, 0.38, 0.24, accent, if side == 1 then 0 else 180, NEON)
			beam(model, "EnergyRail", V(side * 0.6, 1.5, -0.25), V(side * 1.38, 2.1, -0.25), 0.11, 0.08, accent, NEON)
		end
	elseif tier == 5 then
		block(model, "MeteorMass", V(1.8, 1.05, 0.85), V(0, 1.65, 0), DARK, Enum.Material.Slate, 8)
		for i = 1, 4 do
			blade(model, "ObsidianShard", V(-1.7 + i * 0.78, 1.88 + (i % 2) * 0.16, 0), 1.35, 0.8, 0.8,
				Color3.fromRGB(53 + i * 5, 44, 48), if i <= 2 then 165 else -15, Enum.Material.Slate)
		end
		for _, side in { -1, 1 } do
			beam(model, "MoltenFissure", V(side * 0.15, 1.25, -0.46), V(side * 0.8, 2.1, -0.46), 0.14, 0.08, accent, NEON)
		end
		block(model, "HotCore", V(0.5, 0.65, 0.94), V(0, 1.65, 0), accent, NEON, 18)
	elseif tier == 6 then
		for i = 0, 5 do
			local angle = i * math.pi / 3
			local direction = V(math.cos(angle), math.sin(angle), 0)
			beam(model, "NovaSpoke", V(0, 1.65, 0) + direction * 0.36, V(0, 1.65, 0) + direction * 1.28, 0.24, 0.34, GOLD, METAL)
			block(model, "NovaCrystal", V(0.45, 0.65, 0.4), V(0, 1.65, 0) + direction * 1.44, accent, NEON, math.deg(angle) - 45)
		end
		ring(model, "NovaCrown", CFrame.new(0, 1.65, 0), 0.65, LIGHT, 0.14, METAL, 8)
		orb(model, "NovaStar", V(0, 1.65, 0), 0.88, accent, NEON)
	elseif tier == 7 then
		ring(model, "ContainmentRing", CFrame.new(0, 1.65, 0), 1.32, STEEL, 0.2, METAL)
		ring(model, "EventHorizon", CFrame.new(0, 1.65, -0.1), 1.07, Color3.fromRGB(150, 97, 255), 0.11, NEON)
		orb(model, "Singularity", V(0, 1.65, 0), 1.28, accent, Enum.Material.SmoothPlastic)
		for _, side in { -1, 1 } do
			blade(model, "GravityBlade", V(side * 1.7, 1.65, 0), 1.2, 0.58, 0.4, STEEL, if side == 1 then -12 else 168)
			block(model, "FieldEmitter", V(0.3, 0.45, 0.55), V(side * 1.22, 1.65, 0), CYAN, NEON)
		end
	elseif tier == 8 then
		for i = 0, 5 do
			local angle = math.rad(-65 + i * 26)
			local nextAngle = math.rad(-65 + (i + 1) * 26)
			local center = V(-0.2, 1.65, 0)
			beam(model, "CosmicCrescent", center + V(math.cos(angle), math.sin(angle), 0) * 1.55,
				center + V(math.cos(nextAngle), math.sin(nextAngle), 0) * 1.55, 0.38, 0.45, LIGHT, METAL)
			beam(model, "CrescentEdge", center + V(math.cos(angle), math.sin(angle), -0.18) * 1.72,
				center + V(math.cos(nextAngle), math.sin(nextAngle), -0.18) * 1.72, 0.1, 0.1, accent, NEON)
		end
		blade(model, "CometBlade", V(-1.3, 2.4, 0), 2.65, 0.55, 0.38, accent, 198, NEON)
		ring(model, "StellarHalo", CFrame.new(0, 1.65, 0) * CFrame.Angles(0, math.rad(30), math.rad(24)), 0.83, GOLD, 0.1, METAL, 10)
		block(model, "StarVertical", V(0.25, 1.18, 0.35), V(0, 1.65, -0.08), LIGHT, NEON)
		block(model, "StarHorizontal", V(1.18, 0.25, 0.35), V(0, 1.65, -0.08), LIGHT, NEON)
		orb(model, "StellarHeart", V(0, 1.65, -0.12), 0.62, accent, NEON)
	end
	model.WorldPivot = CFrame.identity
	return model
end

local function straps(model: Model, height: number, color: Color3)
	for _, side in { -1, 1 } do
		block(model, "ShoulderStrap", V(0.24, height, 0.18), V(side * 0.57, 0, 0.65), color)
		beam(model, "StrapTop", V(side * 0.57, height / 2, 0.65), V(side * 0.57, height / 2 - 0.3, 1.0), 0.24, 0.16, color)
	end
end

function EquipmentModels.backpack(tier: number): Model
	local item = Config.Backpacks[tier] or Config.Backpacks[1]
	tier = item.Tier
	local model = Instance.new("Model")
	model.Name = item.Name
	model:SetAttribute("EquipmentTier", tier)
	local accent = Config.Pickaxes[tier].Color
	straps(model, 2.3, DARK)
	if tier == 1 then
		block(model, "CanvasBody", V(1.8, 2.1, 1.05), V(0, -0.12, 0), Color3.fromRGB(160, 134, 93), Enum.Material.Fabric)
		block(model, "FoldedFlap", V(1.94, 0.65, 1.16), V(0, 0.84, -0.04), Color3.fromRGB(194, 169, 120), Enum.Material.Fabric, -4)
		block(model, "Tie", V(0.2, 1.1, 0.1), V(0, 0.5, -0.65), DARK)
		block(model, "CanvasPocket", V(1.2, 0.7, 0.22), V(0, -0.53, -0.65), Color3.fromRGB(181, 151, 106), Enum.Material.Fabric)
	elseif tier == 2 then
		block(model, "LeatherBody", V(2.0, 2.5, 1.15), V(0, 0, 0), Color3.fromRGB(117, 66, 42), Enum.Material.Leather)
		block(model, "LeatherFlap", V(2.13, 0.7, 1.3), V(0, 1, -0.04), Color3.fromRGB(159, 99, 55), Enum.Material.Leather)
		for _, side in { -1, 1 } do
			block(model, "LeatherBelt", V(0.22, 2.5, 0.1), V(side * 0.55, 0, -0.65), DARK)
			block(model, "BrassBuckle", V(0.38, 0.35, 0.13), V(side * 0.55, 0.35, -0.75), GOLD, METAL)
		end
	elseif tier == 3 then
		block(model, "MinerBody", V(2.05, 2.55, 1.25), V(0, 0, 0), Color3.fromRGB(75, 90, 91), Enum.Material.Fabric)
		block(model, "FrontPouch", V(1.6, 1.15, 0.45), V(0, -0.5, -0.8), accent)
		block(model, "LampPlate", V(0.8, 0.7, 0.18), V(0, 0.72, -0.71), DARK, METAL)
		orb(model, "WorkLamp", V(0, 0.72, -0.86), 0.47, GOLD, NEON)
		part(model, "Bedroll", V(2.6, 0.65, 0.65), CFrame.new(0, 1.48, 0), Color3.fromRGB(176, 157, 107), Enum.Material.Fabric, "Cylinder")
		block(model, "SidePocket", V(0.55, 1.35, 0.8), V(1.27, -0.25, 0), DARK)
	elseif tier == 4 then
		block(model, "ArmoredCase", V(2.35, 2.75, 1.4), V(0, 0, 0), DARK, METAL)
		block(model, "FrontArmor", V(1.95, 2.1, 0.16), V(0, 0, -0.79), STEEL, METAL)
		for _, side in { -1, 1 } do
			block(model, "CornerRail", V(0.32, 2.95, 1.6), V(side * 1.05, 0, 0), LIGHT, METAL)
		end
		for _, y in { -0.8, 0, 0.8 } do
			block(model, "ArmorRib", V(1.75, 0.16, 0.2), V(0, y, -0.9), DARK, METAL)
		end
		block(model, "StatusLight", V(0.65, 0.17, 0.12), V(0, 0.4, -0.92), accent, NEON)
	elseif tier == 5 then
		block(model, "HaulerBin", V(2.2, 2.7, 1.35), V(0, 0, 0), Color3.fromRGB(98, 68, 49), METAL)
		for _, side in { -1, 1 } do
			block(model, "ExoRail", V(0.24, 3.3, 0.3), V(side * 1.28, 0, -0.6), GOLD, METAL)
			block(model, "SideBin", V(0.65, 1.7, 1.2), V(side * 1.3, -0.45, 0), DARK, METAL)
		end
		for _, y in { -1.3, 0.25, 1.3 } do
			block(model, "HaulerBand", V(2.75, 0.2, 1.55), V(0, y, 0), STEEL, METAL)
		end
		for i = 1, 3 do
			block(model, "OreCargo", V(0.65, 0.8, 0.75), V(-0.75 + i * 0.38, 1.6 + (i % 2) * 0.1, 0), accent, Enum.Material.Slate, i * 24)
		end
	elseif tier == 6 then
		block(model, "CargoFrame", V(2.4, 3.1, 1.4), V(0, 0, 0), DARK, METAL)
		for _, side in { -1, 1 } do
			for _, y in { -0.76, 0.76 } do
				block(model, "CargoModule", V(1.0, 1.22, 1.65), V(side * 0.68, y, -0.12), STEEL, METAL)
				block(model, "ModuleLatch", V(0.6, 0.13, 0.09), V(side * 0.68, y, -1.0), accent, NEON)
			end
			beam(model, "RigLeg", V(side * 1.35, -1.9, 0), V(side * 1.35, 1.75, 0), 0.22, 0.3, GOLD, METAL)
		end
		block(model, "CentralSpine", V(0.24, 3.3, 0.3), V(0, 0, -1.03), DARK, METAL)
	elseif tier == 7 then
		block(model, "GravityHousing", V(1.8, 2.5, 1.05), V(0, 0, 0), DARK, METAL)
		ring(model, "GravityHalo", CFrame.new(0, 0.15, -0.75), 1.18, STEEL, 0.2, METAL)
		ring(model, "GravityField", CFrame.new(0, 0.15, -0.8), 0.93, Color3.fromRGB(169, 126, 255), 0.11, NEON)
		orb(model, "GravityCore", V(0, 0.15, -0.65), 1.25, accent)
		for _, side in { -1, 1 } do
			part(model, "GravityCell", V(2.2, 0.58, 0.58), CFrame.new(side * 1.3, 0, 0) * CFrame.Angles(0, 0, math.pi / 2), STEEL, METAL, "Cylinder")
			block(model, "CellGlow", V(0.62, 0.2, 0.62), V(side * 1.3, -0.75, 0), CYAN, NEON)
		end
	else
		block(model, "VoidHousing", V(1.65, 2.4, 1.1), V(0, 0, 0), DARK, METAL)
		block(model, "VoidDiamond", V(1.55, 1.55, 0.45), V(0, 0.2, -0.74), Color3.fromRGB(76, 44, 107), METAL, 45)
		ring(model, "VoidOrbit", CFrame.new(0, 0.2, -0.92), 0.72, accent, 0.12, NEON, 8)
		orb(model, "VoidHeart", V(0, 0.2, -0.94), 0.67, CYAN, NEON)
		for _, side in { -1, 1 } do
			blade(model, "VoidWing", V(side * 1.22, 0.1, 0), 1.05, 2.4, 0.6, LIGHT, if side == 1 then 8 else 188)
			beam(model, "WingEnergy", V(side * 1.05, -1.12, -0.38), V(side * 1.58, 1.15, -0.38), 0.1, 0.1, accent, NEON)
		end
		block(model, "VoidCrown", V(0.5, 0.5, 0.5), V(0, 1.68, 0), GOLD, METAL, 45)
	end
	model.WorldPivot = CFrame.identity
	return model
end

-- Infer the saved tool's shaft/head axes once. The original MVP handle runs
-- along Z with its head at -Z; preserving this basis also preserves Tool.Grip.
local function mountFrame(tool: Tool, handle: BasePart): CFrame
	local saved = tool:GetAttribute("EquipmentMount")
	if typeof(saved) == "CFrame" then
		return saved
	end
	local size = handle.Size
	local up = if size.Z > size.Y and size.Z > size.X then -Vector3.zAxis
		elseif size.X > size.Y then Vector3.xAxis else Vector3.yAxis
	local right = if math.abs(up.Y) > 0.5 then Vector3.xAxis else Vector3.yAxis
	local head = tool:FindFirstChild("Head", true)
	if head and head:IsA("BasePart") then
		local offset = handle.CFrame:PointToObjectSpace(head.Position)
		if offset:Dot(up) < 0 then
			up = -up
		end
		local headSize = head.Size
		local longAxis = if headSize.X >= headSize.Y and headSize.X >= headSize.Z then head.CFrame.RightVector
			elseif headSize.Y >= headSize.Z then head.CFrame.UpVector else -head.CFrame.LookVector
		local localAxis = handle.CFrame:VectorToObjectSpace(longAxis)
		local across = localAxis - up * localAxis:Dot(up)
		if across.Magnitude > 0.1 then
			right = across.Unit
		end
	end
	local frame = CFrame.fromMatrix(Vector3.zero, right, up, right:Cross(up))
	tool:SetAttribute("EquipmentMount", frame)
	return frame
end

function EquipmentModels.applyToTool(tool: Tool, tier: number)
	local item = Config.Pickaxes[tier] or Config.Pickaxes[1]
	local handle = tool:FindFirstChild("Handle")
	if not (handle and handle:IsA("BasePart")) then
		return
	end
	local previous = tool:FindFirstChild("EquipmentVisual")
	if previous and previous:GetAttribute("EquipmentTier") == item.Tier then
		return
	end
	local frame = handle.CFrame * mountFrame(tool, handle)
	local scale = math.max(handle.Size.X, handle.Size.Y, handle.Size.Z) / 4.2
	local model = EquipmentModels.pickaxe(item.Tier)
	model.Name = "EquipmentVisual"
	model:ScaleTo(scale)
	model:PivotTo(frame)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			local weld = Instance.new("WeldConstraint")
			weld.Name = "EquipmentWeld"
			weld.Part0 = handle
			weld.Part1 = descendant
			weld.Parent = descendant
		end
	end
	if previous then
		previous:Destroy()
	end
	-- Keep the original handle and bindings intact. Only their old appearance
	-- is hidden; all new geometry is massless and welded to that same handle.
	for _, descendant in tool:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Transparency = 1
			descendant.CanCollide = false
			descendant.CanQuery = false
		elseif descendant:IsA("Decal") or descendant:IsA("Texture") then
			descendant.Transparency = 1
		end
	end
	-- Parent last so DescendantAdded observers only ever see a complete model.
	model.Parent = tool
end

return EquipmentModels
