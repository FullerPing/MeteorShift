--!strict
-- Small helpers shared by the meteor effect controllers (ImpactFXController, SurfaceFXController):
-- invisible anchors, neon parts, ground probing, tweens and particle bursts. Everything they make
-- is parented under the camera by the callers, so nothing replicates, collides or blocks a ray.
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local WorldMap = require(game:GetService("ReplicatedStorage").Shared.WorldMap)

local FXKit = {}

function FXKit.mobile(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

function FXKit.range(pair: { number }): NumberRange
	return NumberRange.new(pair[1], pair[2])
end

function FXKit.gradient(colors: { Color3 }): ColorSequence
	if #colors == 1 then return ColorSequence.new(colors[1]) end
	local keys = {}
	for index, color in colors do
		table.insert(keys, ColorSequenceKeypoint.new((index - 1) / (#colors - 1), color))
	end
	return ColorSequence.new(keys)
end

function FXKit.shrink(sizes: { number }): NumberSequence
	return NumberSequence.new({ NumberSequenceKeypoint.new(0, sizes[1]), NumberSequenceKeypoint.new(1, sizes[2]) })
end

-- An invisible anchored part effects hang off, destroyed after `life` seconds (nil: never; the caller
-- cleans up with its folder). `parent` defaults to the camera.
function FXKit.anchor(position: Vector3, size: Vector3?, life: number?, parent: Instance?): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = size or Vector3.one
	part.Position = position
	part.Parent = parent or workspace.CurrentCamera
	if life then task.delay(life, function() part:Destroy() end) end
	return part
end

function FXKit.glowPart(shape: Enum.PartType, color: Color3, transparency: number): Part
	local part = Instance.new("Part")
	part.Shape = shape
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = transparency
	return part
end

function FXKit.fade(inst: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?): Tween
	local tween = TweenService:Create(inst, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
	tween:Play()
	return tween
end

-- The ground the crater scenes sit on: the town ground, roads, bowl, rim and ramps of the live map
function FXKit.surfaces(): { Instance }
	local list = {}
	local map = WorldMap.find()
	if map then
		for _, name in { "Ground", "Roads" } do
			local surface = map:FindFirstChild(name)
			if surface then table.insert(list, surface) end
		end
		local crater = map:FindFirstChild("Crater")
		if crater then
			for _, name in { "Bowl", "Rim", "AccessRamps" } do
				local surface = crater:FindFirstChild(name)
				if surface then table.insert(list, surface) end
			end
		end
	end
	return list
end

function FXKit.groundParams(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = FXKit.surfaces()
	return params
end

function FXKit.groundAt(x: number, z: number, fallbackY: number, params: RaycastParams?): number
	if params then
		local hit = workspace:Raycast(Vector3.new(x, fallbackY + 60, z), Vector3.new(0, -160, 0), params)
		if hit then return hit.Position.Y end
	end
	return fallbackY
end

-- Emits `spec.Count * scale` particles of a burst spec (Config.ImpactFX.Burst shape) from `parent`
function FXKit.burst(parent: Instance, spec: any, scale: number)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = FXKit.gradient(spec.Colors)
	emitter.Size = FXKit.shrink(spec.Size)
	emitter.Lifetime = FXKit.range(spec.Lifetime)
	emitter.Speed = FXKit.range(spec.Speed)
	emitter.SpreadAngle = Vector2.new(spec.Spread or 70, spec.Spread or 70)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Acceleration = spec.Accel
	emitter.Drag = spec.Drag or 0
	emitter.LightEmission = spec.LightEmission
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-240, 240)
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.8, 0.1), NumberSequenceKeypoint.new(1, 1) })
	emitter.Enabled = false
	emitter.Parent = parent
	emitter:Emit(math.max(1, math.floor(spec.Count * scale)))
end

return FXKit
