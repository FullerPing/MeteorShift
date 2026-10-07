--!strict
-- Crater-floor scenes that live as long as a meteor is down, all client-side: a glowing,
-- gravity-defying showpiece for the Alien meteor (pillar, pulsing rings, tendrils crawling in from
-- the rim, floating rocks, spore vortex), molten cracks and vents for Iron, and lighter extras for Ice
-- and Crystal on top of LandingFXController's ground art. A cracked core sets off a finale. Like
-- LandingFXController it is driven by MeteorService.State (so a late joiner sees the scene as it
-- stands) and builds under the camera, where nothing replicates, collides or blocks a mining ray.
-- Loops are TweenService tweens; the only per-frame work is turning the Alien vortex.
-- Numbers: Config.SurfaceFX; placement: Shared.SurfaceLayout.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local Phase = require(ReplicatedStorage.Shared.Phase)
local WorldMap = require(ReplicatedStorage.Shared.WorldMap)
local SurfaceLayout = require(ReplicatedStorage.Shared.SurfaceLayout)
local Kit = require(script.Parent.Parent.FXKit)

local player = Players.LocalPlayer
local SurfaceFXController = Knit.CreateController({ Name = "SurfaceFXController" })

local tuning = Config.SurfaceFX
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local X_UP = CFrame.Angles(0, 0, math.pi / 2) -- cylinders stand along their X axis

type Rock = { part: BasePart, home: CFrame }

type Record = {
	eventId: number,
	typeId: string,
	folder: Folder,
	center: Vector3,
	floorY: number,
	glow: Color3,
	params: RaycastParams,
	scale: number,
	fresh: boolean,
	tweens: { Tween },
	conns: { RBXScriptConnection },
	neon: { BasePart }, -- looks that fade out when the meteor cools
	lights: { PointLight },
	emitters: { ParticleEmitter }, -- continuous ones, switched off when it cools
	beams: { Beam },
	rocks: { Rock },
	pillars: { BasePart },
	cracked: boolean,
	exiting: boolean,
}

local MeteorService: any = nil
local current: Record? = nil

local function count(record: Record, n: number): number
	return math.max(1, math.floor(n * record.scale))
end

-- A build step that waits a little on a fresh landing (so the scene grows in) and runs at once for a
-- player joining mid-event
local function after(record: Record, seconds: number, run: () -> ())
	if not record.fresh then
		run()
		return
	end
	task.delay(seconds, function()
		if current == record and not record.exiting then run() end
	end)
end

local function loop(record: Record, inst: Instance, seconds: number, goal: { [string]: any }, delay: number?, style: Enum.EasingStyle?)
	local info = TweenInfo.new(seconds, style or Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true, delay or 0)
	local tween = TweenService:Create(inst, info, goal)
	table.insert(record.tweens, tween)
	tween:Play()
end

local function ground(record: Record, x: number, z: number): number
	return Kit.groundAt(x, z, record.floorY, record.params)
end

local function polar(record: Record, angle: number, radius: number): Vector3
	local x, z = record.center.X + math.cos(angle) * radius, record.center.Z + math.sin(angle) * radius
	return Vector3.new(x, ground(record, x, z), z)
end

local function neon(record: Record, shape: Enum.PartType, color: Color3, transparency: number, size: Vector3, cframe: CFrame): Part
	local part = Kit.glowPart(shape, color, transparency)
	part.Size = size
	part.CFrame = cframe
	part.Parent = record.folder
	table.insert(record.neon, part)
	return part
end

local function emitter(record: Record, parent: Instance, props: { [string]: any }): ParticleEmitter
	local made = Instance.new("ParticleEmitter")
	for key, value in props do (made :: any)[key] = value end
	made.Parent = parent
	table.insert(record.emitters, made)
	return made
end

local function light(record: Record, position: Vector3, color: Color3, spec: any)
	local lamp = Kit.anchor(position, nil, nil, record.folder)
	local point = Instance.new("PointLight")
	point.Color = color
	point.Range = spec.Range
	point.Brightness = spec.Brightness[1]
	point.Shadows = false
	point.Parent = lamp
	table.insert(record.lights, point)
	loop(record, point, spec.Period, { Brightness = spec.Brightness[2] })
end

-- Rings that swell out of the meteor and fade, again and again
local function pulses(record: Record, color: Color3, spec: any)
	for index = 1, count(record, spec.Count) do
		local ring = neon(record, Enum.PartType.Cylinder, color, 0.4, Vector3.new(spec.Thickness, spec.From, spec.From),
			CFrame.new(record.center.X, record.floorY + tuning.Lift, record.center.Z) * X_UP)
		local info = TweenInfo.new(spec.Seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, -1, false, (index - 1) * spec.Gap)
		local tween = TweenService:Create(ring, info, { Size = Vector3.new(spec.Thickness, spec.To, spec.To), Transparency = 1 })
		table.insert(record.tweens, tween)
		tween:Play()
	end
end

local function updraft(record: Record, colors: { Color3 }, spec: any, y: number?)
	local area = Kit.anchor(Vector3.new(record.center.X, y or (record.floorY + 2), record.center.Z), Vector3.new(spec.Area, 1, spec.Area), nil, record.folder)
	emitter(record, area, {
		Color = Kit.gradient(colors), LightEmission = 1, Rate = spec.Rate * record.scale, Lifetime = Kit.range(spec.Lifetime),
		Speed = Kit.range(spec.Speed), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(25, 25),
		Acceleration = Vector3.new(0, 2, 0), Size = Kit.shrink({ 1.5, 0 }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.1), NumberSequenceKeypoint.new(0.8, 0.2), NumberSequenceKeypoint.new(1, 1) }),
	})
end

-- ==== Alien ====

local function buildAlien(record: Record)
	local spec = tuning.Alien
	local glow = record.glow
	local seed = record.eventId
	local coreTop = record.center + Vector3.new(0, 30, 0)

	-- the column and its halo
	after(record, 0, function()
		local pillarSpec = spec.Pillar
		local column = neon(record, Enum.PartType.Cylinder, glow, pillarSpec.Transparency[1],
			Vector3.new(pillarSpec.Height, pillarSpec.Radius * 2, pillarSpec.Radius * 2),
			CFrame.new(coreTop + Vector3.new(0, pillarSpec.Height / 2, 0)) * X_UP)
		neon(record, Enum.PartType.Cylinder, spec.Spore, 0.9,
			Vector3.new(pillarSpec.Height, pillarSpec.Halo * 2, pillarSpec.Halo * 2),
			CFrame.new(coreTop + Vector3.new(0, pillarSpec.Height / 2, 0)) * X_UP)
		table.insert(record.pillars, column)
		loop(record, column, pillarSpec.Period / 2, { Transparency = pillarSpec.Transparency[2] })
		light(record, coreTop, glow, spec.Light)
	end)

	after(record, 0.5, function() pulses(record, glow, spec.Pulses) end)

	-- tendrils: a chain of beams per spoke with a throb that travels inward
	after(record, 1, function()
		local tendrils = spec.Tendrils
		local host = Kit.anchor(Vector3.zero, nil, nil, record.folder)
		for _, spoke in SurfaceLayout.spokes(seed, count(record, tendrils.Count), tendrils.From, tendrils.To, tendrils.Bend) do
			local points = SurfaceLayout.points(spoke, tendrils.Steps)
			local attachments = {}
			for _, point in points do
				local at = polar(record, point.angle, point.radius) + Vector3.new(0, tendrils.Lift, 0)
				local attachment = Instance.new("Attachment")
				attachment.Position = at
				attachment.Parent = host
				table.insert(attachments, attachment)
			end
			for step = 1, #attachments - 1 do
				local beam = Instance.new("Beam")
				beam.Attachment0, beam.Attachment1 = attachments[step], attachments[step + 1]
				beam.Color = ColorSequence.new(spec.Spore, glow)
				beam.LightEmission = 1
				beam.LightInfluence = 0
				beam.FaceCamera = true
				beam.Segments = 6
				beam.CurveSize0, beam.CurveSize1 = 1.5, -1.5
				beam.Width0, beam.Width1 = tendrils.Width[1], tendrils.Width[1]
				beam.Transparency = NumberSequence.new(0.1)
				beam.Parent = host
				table.insert(record.beams, beam)
				local delay = (step - 1) * tendrils.Period / tendrils.Steps
				loop(record, beam, tendrils.Period / 2, { Width0 = tendrils.Width[2], Width1 = tendrils.Width[2] }, delay)
			end
		end
	end)

	-- rocks that have lost their weight
	after(record, 1.5, function()
		local rocks = spec.Rocks
		for _, rock in SurfaceLayout.rocks(seed, count(record, rocks.Count), rocks.Radius, rocks.Height, rocks.Size, rocks.Period) do
			local base = polar(record, rock.angle, rock.radius)
			local home = CFrame.new(base + Vector3.new(0, rock.height, 0)) * CFrame.Angles(rock.phase, rock.phase * 0.7, 0)
			local part = Instance.new("Part")
			part.Name = "FloatingRock"
			part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = true, false, false, false, false
			part.Material = Enum.Material.Slate
			part.Color = spec.Deep
			part.Size = Vector3.new(rock.size, rock.size * 0.7, rock.size * 0.9)
			part.CFrame = home
			part.Parent = record.folder
			table.insert(record.rocks, { part = part, home = home })
			local underglow = emitter(record, part, {
				Color = ColorSequence.new(spec.Spore, glow), LightEmission = 1, Rate = 4, Lifetime = NumberRange.new(1.5, 2.5),
				Speed = NumberRange.new(0.5, 1.5), EmissionDirection = Enum.NormalId.Bottom, SpreadAngle = Vector2.new(40, 40),
				Size = Kit.shrink({ 0.9, 0 }),
			})
			underglow.Name = "Underglow"
			loop(record, part, rock.period / 2, { CFrame = home * CFrame.new(0, rocks.Bob, 0) * CFrame.Angles(0, 0.9, 0.15) })
		end
	end)

	after(record, 2, function() updraft(record, { spec.Spore, glow }, spec.Updraft) end)

	-- spore arms spiralling up round the meteor: attachments on a turning host, so each leaves a helix
	after(record, 2.5, function()
		local vortex = spec.Vortex
		local host = Kit.anchor(Vector3.new(record.center.X, record.floorY, record.center.Z), nil, nil, record.folder)
		for arm = 1, count(record, vortex.Arms) do
			local angle = (arm - 1) * math.pi * 2 / vortex.Arms
			local attachment = Instance.new("Attachment")
			attachment.Position = Vector3.new(math.cos(angle) * vortex.Radius, vortex.Height[1] + (vortex.Height[2] - vortex.Height[1]) * (arm - 1) / math.max(vortex.Arms - 1, 1), math.sin(angle) * vortex.Radius)
			attachment.Parent = host
			emitter(record, attachment, {
				Color = ColorSequence.new(spec.Spore, glow), LightEmission = 1, Rate = vortex.Rate * record.scale / vortex.Arms,
				Lifetime = NumberRange.new(3, 4.5), Speed = NumberRange.new(0, 1), Acceleration = Vector3.new(0, vortex.Rise, 0),
				Size = Kit.shrink({ 1.6, 0 }), SpreadAngle = Vector2.new(15, 15),
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.1), NumberSequenceKeypoint.new(0.85, 0.3), NumberSequenceKeypoint.new(1, 1) }),
			})
		end
		local turn = 0
		table.insert(record.conns, RunService.Heartbeat:Connect(function(dt)
			turn += dt * math.pi * 2 / vortex.Seconds
			host.CFrame = CFrame.new(host.Position) * CFrame.Angles(0, turn, 0)
		end))
	end)
end

-- the core cracks: a dome, quick rings, the rocks fall, the column and tendrils die
local function finaleAlien(record: Record, position: Vector3)
	local spec = tuning.Alien
	local finale = spec.Finale
	local glow = record.glow
	local dome = Kit.glowPart(Enum.PartType.Ball, glow, 0.35)
	dome.Size = Vector3.one * finale.Dome.From
	dome.Position = position
	dome.Parent = record.folder
	Kit.fade(dome, finale.Dome.Seconds, { Size = Vector3.one * finale.Dome.To, Transparency = 1 }, Enum.EasingStyle.Quart)
	for index = 1, count(record, finale.Rings) do
		task.delay((index - 1) * finale.RingGap, function()
			if current ~= record then return end
			local ring = Kit.glowPart(Enum.PartType.Cylinder, if index % 2 == 0 then spec.Spore else glow, 0.2)
			ring.Size = Vector3.new(0.4, 20, 20)
			ring.CFrame = CFrame.new(record.center.X, record.floorY + tuning.Lift, record.center.Z) * X_UP
			ring.Parent = record.folder
			Kit.fade(ring, 1.1, { Size = Vector3.new(0.4, 150 + index * 8, 150 + index * 8), Transparency = 1 }, Enum.EasingStyle.Quart)
		end)
	end
	local source = Kit.anchor(position, nil, 6, record.folder)
	Kit.burst(source, Config.ImpactFX.Types.Alien.Burst, 1.6 * record.scale)
	-- the rocks drop and the glow goes out of them
	for _, rock in record.rocks do
		TweenService:Create(rock.part, TweenInfo.new(finale.Fall, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = Vector3.new(rock.part.Position.X, ground(record, rock.part.Position.X, rock.part.Position.Z) + 1, rock.part.Position.Z),
			Transparency = 1,
		}):Play()
		local glowEmitter = rock.part:FindFirstChild("Underglow") :: ParticleEmitter?
		if glowEmitter then glowEmitter.Enabled = false end
	end
	for _, pillar in record.pillars do
		for _, tween in record.tweens do if tween.Instance == pillar then tween:Cancel() end end
		Kit.fade(pillar, 0.8, { Transparency = 1 })
	end
	for _, beam in record.beams do
		for _, tween in record.tweens do if tween.Instance == beam then tween:Cancel() end end
		Kit.fade(beam, 0.6, { Width0 = 0, Width1 = 0 })
	end
end

-- ==== Iron ====

local function buildIron(record: Record)
	local spec = tuning.Iron
	local seed = record.eventId
	local cracks = spec.Cracks
	local random = SurfaceLayout.rng(seed + 31)

	after(record, 0.2, function()
		for _, spoke in SurfaceLayout.spokes(seed, count(record, cracks.Count), cracks.From, cracks.To, cracks.Bend) do
			local points = SurfaceLayout.points(spoke, cracks.Steps)
			local previous = polar(record, points[1].angle, points[1].radius) + Vector3.new(0, 0.25, 0)
			for step = 2, #points do
				local nextPoint = polar(record, points[step].angle, points[step].radius) + Vector3.new(0, 0.25, 0)
				local length = (nextPoint - previous).Magnitude
				local segment = neon(record, Enum.PartType.Block, if step % 2 == 0 then spec.Lava else spec.Hot, cracks.Flicker[1],
					Vector3.new(cracks.Width * (1.3 - step / (#points + 1)), 0.2, length + 0.3), CFrame.lookAt((previous + nextPoint) / 2, nextPoint))
				loop(record, segment, cracks.Period[1] + (cracks.Period[2] - cracks.Period[1]) * random(), { Transparency = cracks.Flicker[2] }, random())
				previous = nextPoint
			end
		end
	end)

	-- vents on the floor
	after(record, 1, function()
		local vents = spec.Vents
		local total = count(record, vents.Count)
		local offset = random() * math.pi * 2
		for index = 1, total do
			local at = polar(record, offset + (index - 1) * math.pi * 2 / total, vents.Radius)
			neon(record, Enum.PartType.Cylinder, spec.Lava, 0.3, Vector3.new(0.3, 6, 6), CFrame.new(at + Vector3.new(0, 0.3, 0)) * X_UP)
			local vent = Kit.anchor(at + Vector3.new(0, 0.5, 0), nil, nil, record.folder)
			emitter(record, vent, {
				Texture = SMOKE, Color = ColorSequence.new(Color3.fromRGB(70, 62, 60)), Rate = vents.Smoke * record.scale,
				Lifetime = NumberRange.new(3, 4.5), Speed = NumberRange.new(5, 9), EmissionDirection = Enum.NormalId.Top,
				SpreadAngle = Vector2.new(12, 12), Size = Kit.shrink({ 4, 15 }),
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) }),
			})
			emitter(record, vent, {
				Color = ColorSequence.new(spec.Hot, spec.Lava), LightEmission = 1, Rate = vents.Sparks * record.scale,
				Lifetime = NumberRange.new(0.8, 1.4), Speed = NumberRange.new(18, 30), EmissionDirection = Enum.NormalId.Top,
				SpreadAngle = Vector2.new(25, 25), Acceleration = Vector3.new(0, -40, 0), Size = Kit.shrink({ 0.8, 0 }),
			})
		end
	end)

	after(record, 1.5, function() updraft(record, { spec.Hot, spec.Lava }, spec.Updraft) end)
	after(record, 0, function() light(record, record.center + Vector3.new(0, spec.Light.Lift, 0), record.glow, spec.Light) end)
end

local function finaleIron(record: Record, position: Vector3)
	local finale = tuning.Iron.Finale
	local source = Kit.anchor(position + Vector3.new(0, 10, 0), nil, 6, record.folder)
	Kit.burst(source, {
		Count = finale.Geyser, Speed = { 60, 130 }, Size = { 2.2, 0 }, Lifetime = { 1.4, 2.6 }, Accel = Vector3.new(0, -90, 0),
		Colors = { tuning.Iron.Hot, tuning.Iron.Lava, tuning.Iron.Dark }, LightEmission = 1, Spread = 30,
	}, record.scale)
	local ring = Kit.glowPart(Enum.PartType.Cylinder, tuning.Iron.Hot, 0.1)
	ring.Size = Vector3.new(0.5, finale.Ring.From, finale.Ring.From)
	ring.CFrame = CFrame.new(record.center.X, record.floorY + tuning.Lift, record.center.Z) * X_UP
	ring.Parent = record.folder
	Kit.fade(ring, finale.Ring.Seconds, { Size = Vector3.new(0.5, finale.Ring.To, finale.Ring.To), Transparency = 1 }, Enum.EasingStyle.Quart)
	-- the cracks flare once, then settle dark
	for _, part in record.neon do
		if part.Shape == Enum.PartType.Block and part.Size.Y < 0.3 then
			part.Color = tuning.Iron.Hot
			TweenService:Create(part, TweenInfo.new(2.5), { Color = tuning.Iron.Dark }):Play()
		end
	end
end

-- ==== Ice and Crystal ====

local function buildIce(record: Record)
	local spec = tuning.Ice
	after(record, 0.5, function() pulses(record, record.glow, spec.Halo) end)
	after(record, 1, function() updraft(record, { Color3.new(1, 1, 1), record.glow }, spec.Glints, record.floorY + 18) end)
end

local function buildCrystal(record: Record)
	local spec = tuning.Crystal.Shafts
	after(record, 0.5, function()
		local total = count(record, spec.Count)
		local random = SurfaceLayout.rng(record.eventId + 5)
		local offset = random() * math.pi * 2
		for index = 1, total do
			local at = polar(record, offset + (index - 1) * math.pi * 2 / total, spec.Radius)
			local shaft = neon(record, Enum.PartType.Cylinder, spec.Colors[(index - 1) % #spec.Colors + 1], spec.Transparency[2],
				Vector3.new(spec.Height, spec.Width * 2, spec.Width * 2), CFrame.new(at + Vector3.new(0, spec.Height / 2, 0)) * X_UP)
			loop(record, shaft, spec.Period[1] + (spec.Period[2] - spec.Period[1]) * random(), { Transparency = spec.Transparency[1] }, random() * 2)
		end
	end)
end

-- ==== life cycle ====

local function teardown()
	local record = current
	if not record then return end
	current = nil
	for _, tween in record.tweens do tween:Cancel() end
	for _, connection in record.conns do connection:Disconnect() end
	record.folder:Destroy()
end

-- The meteor cooled: everything fades, then the folder goes
local function fadeOut(record: Record)
	if record.exiting then return end
	record.exiting = true
	for _, tween in record.tweens do tween:Cancel() end
	table.clear(record.tweens)
	for _, connection in record.conns do connection:Disconnect() end
	table.clear(record.conns)
	local seconds = tuning.FadeOut
	for _, part in record.neon do Kit.fade(part, seconds, { Transparency = 1 }) end
	for _, rock in record.rocks do Kit.fade(rock.part, seconds, { Transparency = 1 }) end
	for _, lamp in record.lights do Kit.fade(lamp, seconds, { Brightness = 0 }) end
	for _, made in record.emitters do made.Enabled = false end
	for _, beam in record.beams do Kit.fade(beam, seconds, { Width0 = 0, Width1 = 0 }) end
	task.delay(seconds + 5, function()
		if current == record then current = nil end
		record.folder:Destroy()
	end)
end

local function floorOf(center: Vector3, params: RaycastParams): number
	local crater = Config.LandingFX.Crater
	return Kit.groundAt(center.X, center.Z, center.Y + (crater.FloorY - crater.Center.Y), params)
end

local function build(state: any)
	local map = WorldMap.find()
	local spawn = map and map:FindFirstChild("Crater") and map.Crater:FindFirstChild("MeteorSpawn")
	if not (spawn and spawn:IsA("BasePart")) then return end
	local meteorType = Config.Meteor.Types[state.type]
	if not meteorType then return end
	local params = Kit.groundParams()
	local folder = Instance.new("Folder")
	folder.Name = "SurfaceFX"
	local record: Record = {
		eventId = state.eventId,
		typeId = state.type,
		folder = folder,
		center = spawn.Position,
		floorY = floorOf(spawn.Position, params),
		glow = meteorType.GlowColor,
		params = params,
		scale = if Kit.mobile() then tuning.Mobile.Scale else 1,
		fresh = state.phase == Phase.Impact,
		tweens = {}, conns = {}, neon = {}, lights = {}, emitters = {}, beams = {}, rocks = {}, pillars = {},
		cracked = false,
		exiting = false,
	}
	current = record
	folder.Parent = workspace.CurrentCamera
	local ok, err = pcall(function()
		if state.type == "Alien" then buildAlien(record)
		elseif state.type == "Iron" then buildIron(record)
		elseif state.type == "Ice" then buildIce(record)
		elseif state.type == "Crystal" then buildCrystal(record) end
	end)
	if not ok then
		warn("[SurfaceFXController] build failed:", err)
		if current == record then teardown() end
	end
end

local function onState(state: any)
	if player:GetAttribute("ReduceEffects") == true then
		teardown()
		return
	end
	local record = current
	if record and state and (record.eventId ~= state.eventId or record.typeId ~= state.type) then
		teardown()
		record = nil
	end
	if not state then
		teardown()
		return
	end
	local phase = state.phase
	if phase == Phase.Impact or phase == Phase.Active then
		if not record then build(state) end
	elseif phase == Phase.Cooled then
		if record then fadeOut(record) end
	elseif phase == Phase.CoreCracked then
		-- the finale plays on the CoreCracked signal; joining after it, there is nothing to show
		return
	else
		teardown()
	end
end

function SurfaceFXController:KnitStart()
	if not game:IsLoaded() then game.Loaded:Wait() end
	MeteorService = Knit.GetService("MeteorService")
	MeteorService.State:Observe(onState)
	MeteorService.CoreCracked:Connect(function(position: Vector3)
		local record = current
		if not record or record.exiting or record.cracked then return end
		record.cracked = true
		if record.typeId == "Alien" then
			finaleAlien(record, position)
		elseif record.typeId == "Iron" then
			finaleIron(record, position)
		else
			Kit.burst(Kit.anchor(position, nil, 6, record.folder), Config.ImpactFX.Types[record.typeId].Burst, 1.4 * record.scale)
		end
	end)
	player:GetAttributeChangedSignal("ReduceEffects"):Connect(function()
		if player:GetAttribute("ReduceEffects") == true then teardown() end
	end)
end

return SurfaceFXController
