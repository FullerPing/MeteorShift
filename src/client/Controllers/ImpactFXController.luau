--!strict
-- Extra spectacle for every meteor landing, on top of MeteorFXController's shockwave and
-- LandingFXController's Ice and Crystal ground art: a light pillar, rolling shock rings, dust thrown
-- up around the bowl, a spray of chips and embers, a burst and a falling "rain" in the meteor
-- type's own style (Config.ImpactFX.Types), a pool that glows then cools, a bloom pulse and a small
-- FOV punch. All local, cosmetic and short-lived; skipped when Reduce Effects is on.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local MeteorVisualGeometry = require(ReplicatedStorage.Shared.MeteorVisualGeometry)
local Kit = require(script.Parent.Parent.FXKit)

local player = Players.LocalPlayer
local ImpactFXController = Knit.CreateController({ Name = "ImpactFXController" })

local tuning = Config.ImpactFX
local DUST = Color3.fromRGB(196, 170, 140)
local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"

local mobile, range, gradient, shrink = Kit.mobile, Kit.range, Kit.gradient, Kit.shrink
local anchor, glowPart, fade, groundAt, burst = Kit.anchor, Kit.glowPart, Kit.fade, Kit.groundAt, Kit.burst

local function dustPuff(position: Vector3, count: number, size: number, life: number)
	local spot = anchor(position, nil, life + 1)
	local dust = Instance.new("ParticleEmitter")
	dust.Texture = SMOKE_TEXTURE
	dust.Color = ColorSequence.new(DUST)
	dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size * 0.4), NumberSequenceKeypoint.new(1, size) })
	dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	dust.Lifetime = NumberRange.new(life * 0.6, life)
	dust.Speed = NumberRange.new(8, 18)
	dust.SpreadAngle = Vector2.new(35, 35)
	dust.EmissionDirection = Enum.NormalId.Top
	dust.Drag = 2
	dust.Acceleration = Vector3.new(0, 3, 0)
	dust.Enabled = false
	dust.Parent = spot
	dust:Emit(count)
end

-- A fall (or rise) of particles over the crater for a few seconds
local function rain(position: Vector3, spec: any, scale: number)
	local life = spec.Seconds + spec.Lifetime[2] + 1
	local source = anchor(position + Vector3.new(0, spec.Height, 0), Vector3.new(spec.Area, 1, spec.Area), life)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = gradient(spec.Colors)
	emitter.Size = shrink(spec.Size)
	emitter.Lifetime = range(spec.Lifetime)
	emitter.Speed = NumberRange.new(0, 2)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = spec.Accel
	emitter.LightEmission = spec.LightEmission
	emitter.Rate = spec.Rate * scale
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.1), NumberSequenceKeypoint.new(0.8, 0.2), NumberSequenceKeypoint.new(1, 1) })
	emitter.Parent = source
	task.delay(spec.Seconds, function() emitter.Enabled = false end)
end

local function pulseBloom(strength: number)
	local settings = tuning.Bloom
	local bloom = Instance.new("BloomEffect")
	bloom.Name = "ImpactBloom"
	bloom.Intensity = settings.Intensity * strength
	bloom.Size = settings.Size
	bloom.Threshold = settings.Threshold
	bloom.Parent = Lighting
	local tween = fade(bloom, settings.Seconds, { Intensity = 0 })
	tween.Completed:Once(function() bloom:Destroy() end)
end

local punching = false
local function punchFov(strength: number)
	local camera = workspace.CurrentCamera
	if punching or not camera or player:GetAttribute("ReduceCameraShake") == true then return end
	punching = true
	local settings = tuning.Fov
	local base = camera.FieldOfView
	local out = TweenService:Create(camera, TweenInfo.new(settings.In, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FieldOfView = base + settings.Punch * strength })
	out.Completed:Once(function()
		local back = TweenService:Create(camera, TweenInfo.new(settings.Out, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FieldOfView = base })
		back.Completed:Once(function() punching = false end)
		back:Play()
	end)
	out:Play()
end

function ImpactFXController:_land(position: Vector3, typeId: string?, golden: boolean)
	if player:GetAttribute("ReduceEffects") == true then return end
	local meteorType = Config.Meteor.Types[typeId or "Iron"] or Config.Meteor.Types.Iron
	local glow = meteorType.GlowColor
	local scale = (if mobile() then tuning.Mobile.Scale else 1) * (if golden then tuning.Golden.Scale else 1)
	local crater = Config.LandingFX.Crater
	local params = Kit.groundParams()
	local floorY = groundAt(position.X, position.Z, position.Y + (crater.FloorY - crater.Center.Y), params)

	-- How hard it lands for you: full at the crater, never below a third
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local strength = if root then math.max(0.35, MeteorVisualGeometry.falloff((root.Position - position).Magnitude, 260)) else 0.35

	-- The pillar of light and the flash light
	local pillarSpec = tuning.Pillar
	local pillar = glowPart(Enum.PartType.Cylinder, if golden then Color3.fromRGB(255, 226, 120) else glow, pillarSpec.Transparency)
	pillar.Size = Vector3.new(pillarSpec.Height, pillarSpec.Radius * 2, pillarSpec.Radius * 2)
	pillar.CFrame = CFrame.new(position + Vector3.new(0, pillarSpec.Height / 2 - 6, 0)) * CFrame.Angles(0, 0, math.rad(90))
	pillar.Parent = workspace.CurrentCamera
	fade(pillar, pillarSpec.Seconds, { Size = Vector3.new(pillarSpec.Height, 1, 1), Transparency = 1 })
	task.delay(pillarSpec.Seconds + 0.2, function() pillar:Destroy() end)

	local lightSpec = tuning.Light
	local lamp = anchor(position + Vector3.new(0, lightSpec.Lift, 0), nil, lightSpec.Seconds + 0.5)
	local light = Instance.new("PointLight")
	light.Color = glow
	light.Range = lightSpec.Range
	light.Brightness = lightSpec.Brightness
	light.Shadows = false
	light.Parent = lamp
	fade(light, lightSpec.Seconds, { Brightness = 0 })

	-- Shock rings rolling across the floor
	for _, ring in tuning.Rings do
		task.delay(ring.Delay, function()
			local part = glowPart(Enum.PartType.Cylinder, glow, ring.Transparency)
			part.Size = Vector3.new(ring.Thickness, 6, 6)
			part.CFrame = CFrame.new(position.X, floorY + 0.4, position.Z) * CFrame.Angles(0, 0, math.rad(90))
			part.Parent = workspace.CurrentCamera
			fade(part, ring.Seconds, { Size = Vector3.new(ring.Thickness, ring.ToDiameter, ring.ToDiameter), Transparency = 1 }, Enum.EasingStyle.Quart)
			task.delay(ring.Seconds + 0.2, function() part:Destroy() end)
		end)
	end

	-- The glowing pool that cools with the meteor
	local poolSpec = tuning.Pool
	local pool = glowPart(Enum.PartType.Cylinder, glow, poolSpec.Transparency)
	pool.Size = Vector3.new(poolSpec.Thickness, poolSpec.Diameter, poolSpec.Diameter)
	pool.CFrame = CFrame.new(position.X, floorY + 0.15, position.Z) * CFrame.Angles(0, 0, math.rad(90))
	pool.Parent = workspace.CurrentCamera
	fade(pool, poolSpec.Seconds, { Transparency = 1, Color = Color3.fromRGB(70, 60, 60) }, Enum.EasingStyle.Linear)
	task.delay(poolSpec.Seconds + 0.5, function() pool:Destroy() end)

	-- Dust thrown up around the bowl as the shock arrives
	local rim = tuning.Rim
	local puffs = math.max(2, math.floor(rim.Count * scale))
	for k = 1, puffs do
		local angle = (k / puffs) * math.pi * 2
		local x, z = position.X + math.cos(angle) * rim.Radius, position.Z + math.sin(angle) * rim.Radius
		task.delay(rim.Delay + (k % 3) * 0.04, function()
			dustPuff(Vector3.new(x, groundAt(x, z, floorY, params) + 1, z), math.max(2, math.floor(rim.Puffs * scale)), rim.Height, 2.4)
		end)
	end

	-- Chips and embers from the crater, then the type's own burst and rain
	local source = anchor(position + Vector3.new(0, 6, 0), nil, 6)
	local chips, embers = tuning.Chips, tuning.Embers
	burst(source, {
		Count = chips.Count, Speed = chips.Speed, Size = chips.Size, Lifetime = chips.Lifetime, Accel = Vector3.new(0, chips.Gravity, 0),
		Colors = meteorType.CrustColors, LightEmission = 0.15, Drag = 0,
	}, scale)
	burst(source, {
		Count = embers.Count, Speed = embers.Speed, Size = embers.Size, Lifetime = embers.Lifetime, Accel = Vector3.new(0, embers.Gravity, 0),
		Colors = { Color3.fromRGB(255, 240, 190), glow }, LightEmission = 1, Drag = 0.2, Spread = 55,
	}, scale)
	local flavor = tuning.Types[typeId or "Iron"]
	if flavor and flavor.Burst then burst(source, flavor.Burst, scale) end
	if golden then burst(source, tuning.Golden.Burst, scale) end
	if flavor and flavor.Rain and not mobile() then rain(position, flavor.Rain, scale) end

	pulseBloom(strength)
	punchFov(strength)
end

function ImpactFXController:KnitStart()
	local MeteorService = Knit.GetService("MeteorService")
	MeteorService.Impact:Connect(function(position: Vector3)
		local state = MeteorService.State:Get()
		local golden = state ~= nil and typeof(state.typeName) == "string" and string.sub(state.typeName, 1, 7) == "Golden "
		self:_land(position, state and state.type, golden)
	end)
end

return ImpactFXController
