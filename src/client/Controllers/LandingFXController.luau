--!strict
-- Ice and Crystal landings, client-side: the ground freezes or crystallises around the
-- crater while the meteor is down, then shatters or withers with it. It is all looks, so
-- each client builds its own copy under the camera, where nothing replicates, collides or
-- blocks a mining ray. Everything is driven by MeteorService.State (phase, endsAt, crust
-- progress), never the Impact signal, so a player who joins mid-event sees the scene as it
-- stands at that moment. Motion is TweenService only, with no per-frame stepping, so an
-- event costs nothing per frame once built. Shared.LandingFX holds the layout and timing
-- rules, Config.LandingFX the numbers. Iron meteors get nothing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local Tuning = require(ReplicatedStorage.Shared.Config.LandingFX)
local LandingFX = require(ReplicatedStorage.Shared.LandingFX)
local Sfx = require(script.Parent.Parent.Sfx)

local LandingFXController = Knit.CreateController({
	Name = "LandingFXController",
})

local SPARKLES = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local WHITE = Color3.new(1, 1, 1)
local X_UP = CFrame.Angles(0, 0, math.pi / 2) -- beams bow along their attachments' X axis
local FLOOR_PROBE_HEIGHT = 40
local PAVING_HEIGHT = 0.6 -- town square parts no taller than this lie flat
local GEM_START_SIZE = 0.5
local GEM_FLASH_SIZE = 10
local SMALL_TRANSPARENCY = 0.2 -- satellites and sprouts
local WITHER_BEAM_CUT = 0.5
local WITHER_LIGHTS_OUT = 0.6
local ABORT = {} -- raised to unwind a build that was torn down mid-way

type Props = { [string]: any }

type State = {
	phase: string,
	endsAt: number,
	duration: number?,
	type: string,
	eventId: number,
	crustTotal: number,
	crustBroken: number,
	unlocked: boolean,
}

-- One step of the timeline, replayed from the event clock so a late joiner lands in step
type Track = {
	kind: string, -- "tween" | "linear" | "call"
	start: number,
	seconds: number,
	inst: Instance?,
	from: Props?,
	to: Props?,
	style: Enum.EasingStyle?,
	dir: Enum.EasingDirection?,
	at: ((alpha: number) -> Props)?,
	run: ((live: boolean) -> ())?,
}

-- An upright piece: its parts rise out of the ground along `axis` and sink back into it
type Piece = {
	parts: { BasePart },
	finals: { CFrame },
	axis: Vector3,
	depth: number,
	ripple: number, -- shatter delay
}

type Flow = { beam: Beam, speed: number }
type Burst = { att: Attachment, emitter: ParticleEmitter, mid: Vector3 }
type Sprout = { piece: Piece, base: Vector3 }
type Node = { part: BasePart, fraction: number?, lastRiseAt: number? }
type Rime = {
	hosts: { BasePart },
	emitters: { ParticleEmitter },
	assigned: { [number]: any }, -- host slot -> node TargetId
	nodes: { [BasePart]: Node },
}

type Record = {
	eventId: number,
	typeId: string,
	token: number,
	ready: boolean,
	folder: Folder,
	anchor: BasePart,
	tweens: { Tween },
	conns: { RBXScriptConnection },
	tracks: { Track },
	pieces: { Piece },
	strips: { BasePart },
	fingers: { BasePart },
	flats: { BasePart },
	neon: { BasePart },
	beams: { Flow },
	arcs: { Flow },
	emitters: { ParticleEmitter },
	bursts: { Burst },
	lights: { PointLight },
	gem: BasePart?,
	gemLoop: Tween?,
	sprouts: { Sprout },
	sproutBurst: Burst?,
	shown: number,
	unlocked: boolean,
	rime: Rime?,
	exit: string?,
}

type Obstacle = { [string]: any }

type Scene = {
	center: Vector3,
	floorY: number,
	floorRadius: number,
	openingRadius: number,
	rimY: number,
	probe: (x: number, z: number) -> number,
	obstacles: { Obstacle },
}

type Build = {
	record: Record,
	scene: Scene,
	token: number,
	made: number,
}

type Segment = {
	a: Vector2,
	b: Vector2,
	start: number,
	seconds: number,
	width: number,
	flow: boolean,
}

local MeteorService: any = nil
local mobile = false
local current: Record? = nil
local generation = 0

local function newToken(): number
	generation += 1
	return generation
end

-- Whether work scheduled under `token` still belongs to the live scene
local function alive(record: Record, token: number): boolean
	return current == record and record.token == token
end

local function setProps(inst: Instance, props: Props)
	for key, value in props do
		(inst :: any)[key] = value
	end
end

-- Every effect part: anchored, out of physics, mining rays and touch, and casting no shadow
local function effectPart(className: string, props: Props): BasePart
	local part = Instance.new(className :: any) :: BasePart
	setProps(part, LandingFX.PART_FLAGS)
	setProps(part, props)
	return part
end

local function makeEmitter(parent: Instance, props: Props): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Enabled = false
	setProps(emitter, props)
	emitter.Parent = parent
	return emitter
end

local function play(
	record: Record,
	inst: Instance,
	seconds: number,
	style: Enum.EasingStyle,
	dir: Enum.EasingDirection,
	delay: number,
	goal: Props
): Tween
	local tween = TweenService:Create(inst, TweenInfo.new(seconds, style, dir, 0, false, delay), goal)
	table.insert(record.tweens, tween)
	tween:Play()
	return tween
end

-- A slow back-and-forth that runs until the scene exits
local function loop(record: Record, inst: Instance, seconds: number, goal: Props): Tween
	local tween =
		TweenService:Create(inst, TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), goal)
	table.insert(record.tweens, tween)
	tween:Play()
	return tween
end

-- task.delay that does nothing once the scene is gone or has moved on to its exit
local function later(record: Record, seconds: number, fn: () -> ())
	local token = record.token
	task.delay(seconds, function()
		if alive(record, token) then
			fn()
		end
	end)
end

local function stateClock(state: State): { stage: string, t: number }
	local left = math.max(0, state.endsAt - workspace:GetServerTimeNow())
	return LandingFX.clock(state.phase, left, state.duration, state.type)
end

local function child(parent: Instance?, name: string): Instance?
	return if parent then parent:FindFirstChild(name) else nil
end

-- Where things are, read once per build. A fresh joiner may not have the map streamed in
-- yet, so every lookup falls back to Config.LandingFX.Crater.
local function readScene(): Scene
	local crater = Tuning.Crater
	local map = workspace:FindFirstChild("Map") or workspace:WaitForChild("Map", 5)
	local craterModel = if map then map:FindFirstChild("Crater") or map:WaitForChild("Crater", 5) else nil
	local spawn = child(craterModel, "MeteorSpawn")
	local center = if spawn and spawn:IsA("BasePart") then spawn.Position else crater.Center
	local bowl = child(craterModel, "Bowl")
	local floor = child(bowl, "Floor")
	local floorRadius = if floor and floor:IsA("BasePart")
		then math.max(floor.Size.Y, floor.Size.Z) / 2
		else crater.FloorRadius
	local opening = if map then map:GetAttribute("CraterTerrainOpening") else nil
	local openingRadius = if typeof(opening) == "number" then opening else crater.OpeningRadius

	-- The floor height is the median of a ring of rays that land on level bowl floor
	local floorY = crater.FloorY
	if bowl then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { bowl }
		local heights = {}
		for k = 0, crater.FloorProbes - 1 do
			local angle = math.rad((k + 0.5) * 360 / crater.FloorProbes)
			local origin = center
				+ Vector3.new(
					math.cos(angle) * crater.FloorProbeRadius,
					FLOOR_PROBE_HEIGHT,
					math.sin(angle) * crater.FloorProbeRadius
				)
			local result = workspace:Raycast(origin, Vector3.new(0, -crater.ProbeDepth, 0), params)
			if result and result.Normal.Y >= 0.9 then
				table.insert(heights, result.Position.Y)
			end
		end
		if #heights >= crater.FloorProbesNeeded then
			table.sort(heights)
			local middle = (#heights + 1) / 2
			floorY = (heights[math.floor(middle)] + heights[math.ceil(middle)]) / 2
		end
	end

	-- Effects reach onto the plaza, so its paving counts as ground
	local townSquare = child(map, "TownSquare")
	local plaza = child(townSquare, "Plaza")
	local groundParams = RaycastParams.new()
	groundParams.FilterType = Enum.RaycastFilterType.Include
	local groundParts: { Instance } = { workspace.Terrain }
	for _, item in { bowl, plaza } do
		if item then
			table.insert(groundParts, item)
		end
	end
	groundParams.FilterDescendantsInstances = groundParts
	-- Ground height at an offset from the centre; a hit far from the bowl profile is
	-- something else (or not streamed in), so the profile wins
	local function probe(x: number, z: number): number
		local r = math.sqrt(x * x + z * z)
		local profile = LandingFX.groundY(r, floorY, crater.RimY, floorRadius, openingRadius)
		local origin = Vector3.new(center.X + x, center.Y + crater.ProbeHeight, center.Z + z)
		local result = workspace:Raycast(origin, Vector3.new(0, -crater.ProbeDepth, 0), groundParams)
		if result and math.abs(result.Position.Y - profile) <= crater.ProbeTolerance then
			return result.Position.Y
		end
		return profile
	end

	-- Roads, plots, rocks, landmarks, lamps and what stands on the plaza: upright pieces stay off them
	local obstacles: { Obstacle } = {}
	local function box(cframe: CFrame, size: Vector3)
		local right = Vector2.new(cframe.RightVector.X, cframe.RightVector.Z)
		local unit = if right.Magnitude > 1e-3 then right.Unit else Vector2.xAxis
		table.insert(obstacles, {
			kind = "box",
			cx = cframe.Position.X - center.X,
			cz = cframe.Position.Z - center.Z,
			hx = size.X / 2,
			hz = size.Z / 2,
			ux = unit.X,
			uz = unit.Y,
		})
	end
	local function circle(part: BasePart)
		table.insert(obstacles, {
			kind = "circle",
			cx = part.Position.X - center.X,
			cz = part.Position.Z - center.Z,
			r = math.max(part.Size.X, part.Size.Z) / 2,
		})
	end
	local roads = child(map, "Roads")
	if roads then
		for _, item in roads:GetChildren() do
			if item:IsA("BasePart") then
				box(item.CFrame, item.Size)
			end
		end
	end
	local plots = child(map, "Plots")
	if plots then
		for _, plot in plots:GetChildren() do
			for _, name in { "Pad", "Path" } do
				local item = plot:FindFirstChild(name)
				if item and item:IsA("BasePart") then
					box(item.CFrame, item.Size)
				end
			end
		end
	end
	-- The spawn, the fountain and the planters; flat paving and trim don't count
	if townSquare then
		for _, item in townSquare:GetDescendants() do
			if item:IsA("BasePart") and item ~= plaza and item.Size.Y > PAVING_HEIGHT then
				box(item.CFrame, item.Size)
			end
		end
	end
	local debris = child(map, "Debris")
	if debris then
		for _, rock in debris:GetChildren() do
			if rock:IsA("BasePart") then
				circle(rock)
			end
		end
	end
	local landmarks = child(child(map, "Decor"), "MiningLandmarks")
	if landmarks then
		for _, item in landmarks:GetChildren() do
			if item:IsA("BasePart") then
				box(item.CFrame, item.Size)
			elseif item:IsA("Model") then
				local ok, cframe, size = pcall(item.GetBoundingBox, item)
				if ok then
					box(cframe, size)
				end
			end
		end
	end
	local lamps = child(craterModel, "Lamps")
	if lamps then
		for _, item in lamps:GetDescendants() do
			if item:IsA("BasePart") then
				circle(item)
			end
		end
	end

	return {
		center = center,
		floorY = floorY,
		floorRadius = floorRadius,
		openingRadius = openingRadius,
		rimY = crater.RimY,
		probe = probe,
		obstacles = obstacles,
	}
end

--[[ Building ]]

-- Counts a new instance and yields once BuildPerFrame have been made this frame
local function step(b: Build)
	b.made += 1
	if b.made >= Tuning.BuildPerFrame then
		b.made = 0
		task.wait()
		if not alive(b.record, b.token) then
			error(ABORT)
		end
	end
end

local function addPart(b: Build, className: string, props: Props): BasePart
	local part = effectPart(className, props)
	part.Parent = b.record.folder
	step(b)
	return part
end

-- An attachment on the anchor, which sits at the world origin: Position is world space
local function anchorAttachment(b: Build, position: Vector3): Attachment
	local att = Instance.new("Attachment")
	att.Position = position
	att.Parent = b.record.anchor
	step(b)
	return att
end

local function ground(b: Build, x: number, z: number, lift: number?): Vector3
	local center = b.scene.center
	return Vector3.new(center.X + x, b.scene.probe(x, z) + (lift or 0), center.Z + z)
end

local function outwardOf(x: number, z: number): Vector3
	local flat = Vector3.new(x, 0, z)
	return if flat.Magnitude > 1e-3 then flat.Unit else Vector3.xAxis
end

local function tweenTrack(
	b: Build,
	inst: Instance,
	from: Props,
	to: Props,
	start: number,
	seconds: number,
	style: Enum.EasingStyle,
	dir: Enum.EasingDirection
)
	table.insert(b.record.tracks, {
		kind = "tween",
		inst = inst,
		from = from,
		to = to,
		start = start,
		seconds = seconds,
		style = style,
		dir = dir,
	})
end

local function linearTrack(b: Build, inst: Instance, at: (number) -> Props, start: number, seconds: number)
	table.insert(b.record.tracks, { kind = "linear", inst = inst, at = at, start = start, seconds = seconds })
end

-- `run(true)` on time; `run(false)` for a late joiner, which applies only the lasting
-- part (bursts and sounds are skipped)
local function callTrack(b: Build, start: number, run: (boolean) -> ())
	table.insert(b.record.tracks, { kind = "call", start = start, seconds = 0, run = run })
end

local function burstEmitter(parent: Instance, from: Color3, to: Color3): ParticleEmitter
	return makeEmitter(parent, {
		Texture = SPARKLES,
		Color = ColorSequence.new(from, to),
		Size = NumberSequence.new(0.7, 0),
		Transparency = NumberSequence.new(0, 1),
		LightEmission = 0.8,
		Speed = NumberRange.new(14, 28),
		SpreadAngle = Vector2.new(60, 60),
		Acceleration = Vector3.new(0, -45, 0),
		Lifetime = NumberRange.new(0.7, 1.2),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-200, 200),
	})
end

local function hostPart(b: Build, name: string, area: number, position: Vector3): BasePart
	return addPart(b, "Part", {
		Name = name,
		Size = Vector3.new(area, 1, area),
		Transparency = 1,
		CFrame = CFrame.new(position),
	})
end

-- An ambient emitter switched on at `start`
local function ambient(b: Build, emitter: ParticleEmitter, start: number)
	step(b)
	table.insert(b.record.emitters, emitter)
	callTrack(b, start, function()
		emitter.Enabled = true
	end)
end

local function particleRate(rate: number): number
	return if mobile then rate * Tuning.Mobile.ParticleScale else rate
end

local function flowBeamsOn(): boolean
	return Tuning.FlowBeams.Enabled and not (mobile and not Tuning.Mobile.FlowBeams)
end

-- A layout line as segments; its vertices are XZ offsets from the centre
local function segmentsOf(line: any, width: number): { Segment }
	local segments: { Segment } = {}
	local points = line.points
	for k = 1, #points - 1 do
		local start = line.starts[k]
		local seconds = if type(line.seconds) == "table" then line.seconds[k] else line.seconds
		local flow = false
		if type(line.flow) == "table" then
			flow = line.flow[k] == true or table.find(line.flow, k) ~= nil
		end
		table.insert(segments, {
			a = points[k],
			b = points[k + 1],
			start = start,
			seconds = seconds,
			width = if type(line.widths) == "table" then line.widths[k] else width,
			flow = flow,
		})
	end
	return segments
end

-- Neon strips that grow outward segment by segment, with flow beams on the flat
-- stretches once their segment has finished
local function buildLine(b: Build, line: any, width: number, color: Color3, transparency: number, flow: { Color3 }?, speed: number)
	local record = b.record
	local strip = Tuning.Strip
	local beamsOn = flow ~= nil and flowBeamsOn()
	local vertexAtts: { [Vector2]: Attachment } = {}
	local function vertexAtt(point: Vector2): Attachment
		local att = vertexAtts[point]
		if not att then
			att = anchorAttachment(b, ground(b, point.X, point.Y, Tuning.FlowBeams.Height))
			vertexAtts[point] = att
		end
		return att
	end
	for _, segment in segmentsOf(line, width) do
		local a = ground(b, segment.a.X, segment.a.Y)
		local z = ground(b, segment.b.X, segment.b.Y)
		local fromCFrame, fromSize = LandingFX.stripAt(a, z, 0, segment.width, strip.Thickness, strip.Lift)
		local toCFrame, toSize = LandingFX.stripAt(a, z, 1, segment.width, strip.Thickness, strip.Lift)
		local part = addPart(b, "Part", {
			Name = "Strip",
			Material = Enum.Material.Neon,
			Color = color,
			Transparency = transparency,
			Size = fromSize,
			CFrame = fromCFrame,
		})
		table.insert(record.strips, part)
		table.insert(record.neon, part)
		tweenTrack(
			b,
			part,
			{ CFrame = fromCFrame, Size = fromSize },
			{ CFrame = toCFrame, Size = toSize },
			segment.start,
			segment.seconds,
			Enum.EasingStyle.Linear,
			Enum.EasingDirection.In
		)

		if beamsOn and flow and segment.flow then
			local beam = Instance.new("Beam")
			beam.Attachment0 = vertexAtt(segment.a)
			beam.Attachment1 = vertexAtt(segment.b)
			beam.FaceCamera = true
			beam.Segments = 1
			beam.Width0 = Tuning.FlowBeams.Width
			beam.Width1 = Tuning.FlowBeams.Width
			beam.Texture = SPARKLES
			beam.TextureMode = Enum.TextureMode.Wrap
			beam.TextureLength = Tuning.FlowBeams.TextureLength
			beam.TextureSpeed = speed
			beam.LightEmission = 1
			beam.Transparency = NumberSequence.new(Tuning.FlowBeams.Transparency)
			beam.Color = ColorSequence.new(flow[1], flow[2])
			beam.Enabled = false
			beam.Parent = record.anchor
			step(b)
			table.insert(record.beams, { beam = beam, speed = speed })
			callTrack(b, segment.start + segment.seconds, function()
				beam.Enabled = true
			end)
		end
	end
end

-- Parts of an upright piece, created fully buried along `axis`
local function addPiece(b: Build, parts: { BasePart }, finals: { CFrame }, axis: Vector3, depth: number, ripple: number): Piece
	for index, part in parts do
		part.CFrame = LandingFX.buried(finals[index], axis, depth)
	end
	local piece = { parts = parts, finals = finals, axis = axis, depth = depth, ripple = ripple }
	table.insert(b.record.pieces, piece)
	return piece
end

-- Eruption from fully buried to `emergence` (1 = final pose)
local function riseTrack(b: Build, piece: Piece, emergence: number, start: number, seconds: number)
	for index, part in piece.parts do
		local final = piece.finals[index]
		tweenTrack(
			b,
			part,
			{ CFrame = LandingFX.buried(final, piece.axis, piece.depth) },
			{ CFrame = LandingFX.buried(final, piece.axis, (1 - emergence) * piece.depth) },
			start,
			seconds,
			Enum.EasingStyle.Quint,
			Enum.EasingDirection.Out
		)
	end
end

local function isSoundRank(rank: number): boolean
	return table.find(Tuning.SoundRanks, rank) ~= nil
end

-- One burst emitter per cluster, fired as the hero breaks the ground
local function addBurst(b: Build, base: Vector3, mid: Vector3, colors: { Color3 }, start: number, rank: number, sound: string)
	local att = anchorAttachment(b, base + Vector3.new(0, 1.5, 0))
	local emitter = burstEmitter(att, colors[1], colors[2])
	step(b)
	table.insert(b.record.bursts, { att = att, emitter = emitter, mid = mid })
	callTrack(b, start, function(live: boolean)
		if live then
			emitter:Emit(Tuning.Burst.Eruption)
			if isSoundRank(rank) then
				Sfx.play(sound, att)
			end
		end
	end)
end

local function buildIce(b: Build, layout: any)
	local record = b.record
	local scene = b.scene
	local center = scene.center
	local meteor = Config.Meteor.Types.Ice
	local ice = Tuning.Types.Ice
	local glow, ore, frost = meteor.GlowColor, meteor.OreColor, meteor.CrustColors[3]

	-- I1: the crater floor glazes over
	local sheet = ice.Sheet
	if sheet.Enabled then
		local startSize = Vector3.new(sheet.Thickness, sheet.StartDiameter, sheet.StartDiameter)
		local part = addPart(b, "Part", {
			Name = "Glaze",
			Shape = Enum.PartType.Cylinder,
			Material = Enum.Material.Glacier,
			Color = frost,
			Transparency = 1,
			Size = startSize,
			CFrame = CFrame.new(center.X, scene.floorY + sheet.Lift, center.Z) * CFrame.Angles(0, 0, math.pi / 2),
		})
		table.insert(record.flats, part)
		tweenTrack(
			b,
			part,
			{ Size = startSize, Transparency = 1 },
			{ Size = Vector3.new(sheet.Thickness, sheet.Diameter, sheet.Diameter), Transparency = sheet.Transparency },
			sheet.Start,
			sheet.Seconds,
			Enum.EasingStyle.Quart,
			Enum.EasingDirection.Out
		)
	end

	-- I2: frost cracks, one per spike cluster
	local cracks = ice.Cracks
	for _, crack in layout.cracks do
		buildLine(b, crack, cracks.Width[1], glow, cracks.Transparency, { glow, WHITE }, cracks.FlowSpeed)
	end

	-- I3: ice spike crown on the rim band
	local clusters = ice.Clusters
	local satelliteColor = ore:Lerp(WHITE, clusters.WhiteBlend)
	for rank, cluster in layout.clusters do
		local base = ground(b, cluster.x, cluster.z)
		local outward = outwardOf(cluster.x, cluster.z)
		local frame = LandingFX.pieceFrame(base, outward, cluster.lean, cluster.yaw)
		local parts, finals = {}, {}
		for _, wedge in LandingFX.star(frame, cluster.height, cluster.width, cluster.thickness, Tuning.Sink) do
			table.insert(parts, addPart(b, "WedgePart", {
				Name = "Spike",
				Material = Enum.Material.Ice,
				Color = frost,
				Transparency = clusters.Transparency,
				Size = wedge.size,
			}))
			table.insert(finals, wedge.cf)
		end
		-- A neon core glows through the translucent ice
		local coreLength = clusters.Core.Length * cluster.height
		local core = addPart(b, "Part", {
			Name = "SpikeCore",
			Material = Enum.Material.Neon,
			Color = glow,
			Size = Vector3.new(clusters.Core.Width, coreLength, clusters.Core.Width),
		})
		table.insert(parts, core)
		table.insert(finals, frame * CFrame.new(0, coreLength / 2 - Tuning.Sink, 0))
		table.insert(record.neon, core)
		local hero = addPiece(b, parts, finals, frame.UpVector, cluster.depth, Tuning.Exit.ShatterRipple * rank)
		riseTrack(b, hero, 1, cluster.start, cluster.rise)

		for _, satellite in cluster.satellites do
			local satBase = ground(b, satellite.x, satellite.z)
			local satFrame = LandingFX.pieceFrame(satBase, outward, satellite.lean, satellite.yaw)
			local satParts, satFinals = {}, {}
			for _, wedge in LandingFX.blade(satFrame, satellite.height, satellite.width, satellite.thickness, Tuning.Sink) do
				table.insert(satParts, addPart(b, "WedgePart", {
					Name = "SpikeSatellite",
					Material = Enum.Material.Ice,
					Color = satelliteColor,
					Transparency = SMALL_TRANSPARENCY,
					Size = wedge.size,
				}))
				table.insert(satFinals, wedge.cf)
			end
			local piece =
				addPiece(b, satParts, satFinals, satFrame.UpVector, satellite.depth, Tuning.Exit.ShatterRipple * rank)
			riseTrack(b, piece, 1, satellite.start, satellite.rise)
		end

		local mid = (frame * CFrame.new(0, cluster.height / 2 - Tuning.Sink, 0)).Position
		addBurst(b, base, mid, { WHITE, ore }, cluster.start, rank, ice.Sound)
	end

	-- I4: frost fingers burst out from the rim, then creep with the cooling clock
	local fingers = ice.Fingers
	local creepEnd = Config.Meteor.ImpactDuration + meteor.ActiveDuration
	for _, finger in layout.fingers do
		local angle = math.rad(finger.angle)
		local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
		-- A flat plate rests at the median ground height along its full length, so one
		-- low probe at its root (the bowl slope under a rim rock) doesn't bury it
		local heights = {}
		for k = 0, 4 do
			local r = fingers.Inner + finger.length * k / 4
			table.insert(heights, b.scene.probe(outward.X * r, outward.Z * r))
		end
		table.sort(heights)
		local inner = Vector3.new(
			center.X + outward.X * fingers.Inner,
			heights[3] + Tuning.FlatLift,
			center.Z + outward.Z * fingers.Inner
		)
		local function shape(length: number): { any }
			return LandingFX.flatSpike(inner, outward, math.max(length, Tuning.Strip.StartLength), finger.width, fingers.Thickness)
		end
		local first, burst = shape(0), shape(finger.length * fingers.Burst)
		local burstEnd = finger.start + fingers.BurstSeconds
		for half, piece in first do
			local part = addPart(b, "WedgePart", {
				Name = "FrostFinger",
				Material = Enum.Material.Snow,
				Color = fingers.Color,
				Transparency = 0,
				Size = piece.size,
				CFrame = piece.cf,
			})
			table.insert(record.fingers, part)
			tweenTrack(
				b,
				part,
				{ CFrame = piece.cf, Size = piece.size },
				{ CFrame = burst[half].cf, Size = burst[half].size },
				finger.start,
				fingers.BurstSeconds,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.Out
			)
			linearTrack(b, part, function(alpha: number): Props
				local grown = shape(finger.length * (fingers.Burst + (1 - fingers.Burst) * alpha))[half]
				return { CFrame = grown.cf, Size = grown.size }
			end, burstEnd, creepEnd - burstEnd)
		end
	end

	-- I5: snow over the crater and mist on its floor
	local snow = ice.Snow
	local snowHost = hostPart(b, "Snow", snow.Area, center + Vector3.new(0, snow.Height, 0))
	ambient(b, makeEmitter(snowHost, {
		Texture = SPARKLES,
		Color = ColorSequence.new(WHITE, frost),
		Size = NumberSequence.new(0.35, 0.2),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.1, 0.15),
			NumberSequenceKeypoint.new(0.85, 0.3),
			NumberSequenceKeypoint.new(1, 1),
		}),
		LightEmission = 0.3,
		Rate = particleRate(snow.Rate),
		Lifetime = NumberRange.new(7, 9),
		Speed = NumberRange.new(3, 5),
		EmissionDirection = Enum.NormalId.Bottom,
		Acceleration = Vector3.new(1.2, -1, 0),
		RotSpeed = NumberRange.new(-40, 40),
	}), snow.Start)

	local mist = ice.Mist
	if not (mobile and not Tuning.Mobile.Mist) then
		local mistHost = hostPart(b, "Mist", mist.Area, Vector3.new(center.X, scene.floorY + mist.Lift, center.Z))
		ambient(b, makeEmitter(mistHost, {
			Texture = SMOKE,
			Color = ColorSequence.new(Color3.fromRGB(220, 240, 255)),
			Size = NumberSequence.new(6, 14),
			Transparency = NumberSequence.new(0.82, 1),
			Rate = mist.Rate,
			Lifetime = NumberRange.new(6, 9),
			Speed = NumberRange.new(0.5, 1.5),
			SpreadAngle = Vector2.new(80, 80),
			Drag = 1,
			Acceleration = Vector3.new(0, -0.3, 0),
			EmissionDirection = Enum.NormalId.Top,
		}), mist.Start)
	end

	-- I6: pooled rime hosts, bound to refreezing nodes once the build is up
	local rimeConfig = ice.Rime
	if rimeConfig.Enabled then
		local rime: Rime = { hosts = {}, emitters = {}, assigned = {}, nodes = {} }
		for _ = 1, rimeConfig.Max do
			local host = addPart(b, "Part", {
				Name = "Rime",
				Size = Vector3.one,
				Transparency = 1,
				CFrame = CFrame.new(center),
			})
			local emitter = makeEmitter(host, {
				Shape = Enum.ParticleEmitterShape.Box,
				ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
				ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
				Rate = rimeConfig.Rate,
				Speed = NumberRange.new(2, 4),
				Lifetime = NumberRange.new(0.6, 0.9),
				Size = NumberSequence.new(0.5, 0),
				Texture = SPARKLES,
				Color = ColorSequence.new(WHITE, glow),
				LightEmission = 0.8,
			})
			step(b)
			table.insert(rime.hosts, host)
			table.insert(rime.emitters, emitter)
			table.insert(record.emitters, emitter)
		end
		record.rime = rime
	end
end

-- Parts of one crystal: body and tip, plus a neon spine for a hero
local function crystalParts(
	b: Build,
	shape: any,
	bodyColor: Color3,
	bodyTransparency: number,
	tipColor: Color3,
	withSpine: boolean
): ({ BasePart }, { CFrame }, BasePart, BasePart?)
	local body = addPart(b, "Part", {
		Name = "Crystal",
		Material = Enum.Material.Glass,
		Color = bodyColor,
		Transparency = bodyTransparency,
		Reflectance = if withSpine then 0.1 else 0,
		Size = shape.body.size,
	})
	local tip = addPart(b, "Part", {
		Name = "CrystalTip",
		Material = Enum.Material.Neon,
		Color = tipColor,
		Size = shape.tip.size,
	})
	table.insert(b.record.neon, tip)
	local parts, finals = { body, tip }, { shape.body.cf, shape.tip.cf }
	local spine: BasePart? = nil
	if withSpine then
		local made = addPart(b, "Part", {
			Name = "CrystalSpine",
			Material = Enum.Material.Neon,
			Color = Config.Meteor.Types.Crystal.GlowColor,
			Size = shape.spine.size,
		})
		table.insert(b.record.neon, made)
		table.insert(parts, made)
		table.insert(finals, shape.spine.cf)
		spine = made
	end
	return parts, finals, tip, spine
end

local function arcBeam(b: Build, att0: Attachment, att1: Attachment, curve0: number, curve1: number): Beam
	local arcs = Tuning.Types.Crystal.Arcs
	local meteor = Config.Meteor.Types.Crystal
	local beam = Instance.new("Beam")
	beam.Attachment0 = att0
	beam.Attachment1 = att1
	beam.CurveSize0 = curve0
	beam.CurveSize1 = curve1
	beam.Width0 = 0
	beam.Width1 = 0
	beam.FaceCamera = true
	beam.Segments = arcs.Segments
	beam.LightEmission = 1
	beam.Brightness = arcs.Brightness[1]
	beam.Texture = SPARKLES
	beam.TextureMode = Enum.TextureMode.Wrap
	beam.TextureLength = arcs.TextureLength
	beam.TextureSpeed = arcs.TextureSpeed
	beam.Transparency = NumberSequence.new(arcs.Transparency)
	beam.Color = ColorSequence.new(meteor.OreColor, meteor.GlowColor)
	beam.Parent = b.record.anchor
	step(b)
	table.insert(b.record.arcs, { beam = beam, speed = arcs.TextureSpeed })
	return beam
end

-- An attachment at `position` on `part` whose X axis points up in the part's final pose;
-- parts only translate, so it rides along as the crystal grows
local function upAttachment(b: Build, part: BasePart, final: CFrame, position: Vector3): Attachment
	local att = Instance.new("Attachment")
	att.CFrame = final:ToObjectSpace(CFrame.new(position) * X_UP)
	att.Parent = part
	step(b)
	return att
end

local function startGemLoop(record: Record)
	local gem = record.gem
	if not gem then
		return
	end
	local config = Tuning.Types.Crystal.Gem
	local pulse = if record.unlocked then config.UnlockedPulse else config.Pulse
	if record.gemLoop then
		record.gemLoop:Cancel()
	end
	gem.Size = Vector3.one * pulse[1]
	record.gemLoop = loop(record, gem, config.PulseSeconds, { Size = Vector3.one * pulse[2] })
end

local function buildCrystal(b: Build, layout: any)
	local record = b.record
	local scene = b.scene
	local center = scene.center
	local meteor = Config.Meteor.Types.Crystal
	local crystal = Tuning.Types.Crystal
	local glow, ore = meteor.GlowColor, meteor.OreColor

	-- C1: an energy field spreads over the crater floor, then breathes
	local shimmer = crystal.Shimmer
	if shimmer.Enabled then
		local startSize = Vector3.new(shimmer.Thickness, shimmer.StartDiameter, shimmer.StartDiameter)
		local field = addPart(b, "Part", {
			Name = "Field",
			Shape = Enum.PartType.Cylinder,
			Material = Enum.Material.ForceField,
			Color = glow,
			Transparency = 1,
			Size = startSize,
			CFrame = CFrame.new(center.X, scene.floorY + shimmer.Lift, center.Z) * CFrame.Angles(0, 0, math.pi / 2),
		})
		table.insert(record.flats, field)
		tweenTrack(
			b,
			field,
			{ Size = startSize, Transparency = 1 },
			{
				Size = Vector3.new(shimmer.Thickness, shimmer.Diameter, shimmer.Diameter),
				Transparency = shimmer.Transparency[1],
			},
			shimmer.Start,
			shimmer.Seconds,
			Enum.EasingStyle.Quart,
			Enum.EasingDirection.Out
		)
		callTrack(b, shimmer.Start + shimmer.Seconds, function()
			loop(record, field, shimmer.Breath, { Transparency = shimmer.Transparency[2] })
		end)
	end

	-- C2: the resonance lattice: spokes, the magic circle and rays
	local flowColors = { glow, ore }
	local flowSpeed = crystal.Spokes.FlowSpeed
	for _, spoke in layout.spokes do
		buildLine(b, spoke, crystal.Spokes.Width, glow, 0, flowColors, flowSpeed)
	end
	for _, chord in layout.circle do
		buildLine(b, chord, crystal.Circle.Width, glow, 0, nil, flowSpeed)
	end
	for _, ray in layout.rays do
		buildLine(b, ray, crystal.Rays.Width, glow, 0, flowColors, flowSpeed)
	end

	-- C3: crystal clusters erupt, then keep growing through the event
	local clusters = crystal.Clusters
	local lights = crystal.Lights
	local lightsLeft = if mobile then Tuning.Mobile.Lights else #lights.Ranks
	local satelliteColor = meteor.CrustColors[2]:Lerp(ore, 0.5)
	local tips: { [number]: Attachment } = {}
	for rank, cluster in layout.clusters do
		local base = ground(b, cluster.x, cluster.z)
		local outward = outwardOf(cluster.x, cluster.z)
		local frame = LandingFX.pieceFrame(base, outward, cluster.lean, cluster.yaw)
		local shape = LandingFX.prism(frame, cluster.height, cluster.width, clusters.TipScale, clusters.Spine, Tuning.Sink)
		local parts, finals, tip, spine = crystalParts(b, shape, ore, clusters.Transparency, ore, true)
		local hero = addPiece(b, parts, finals, frame.UpVector, cluster.depth, Tuning.Exit.ShatterRipple * rank)
		riseTrack(b, hero, clusters.EmergeTo, cluster.start, cluster.rise)
		for index, part in parts do
			local final = finals[index]
			linearTrack(b, part, function(alpha: number): Props
				local emergence = clusters.EmergeTo + (1 - clusters.EmergeTo) * alpha
				return { CFrame = LandingFX.buried(final, hero.axis, (1 - emergence) * hero.depth) }
			end, cluster.start + cluster.rise, clusters.GrowSeconds)
		end
		local top = if typeof(shape.top) == "CFrame" then shape.top.Position else shape.top
		tips[rank] = upAttachment(b, tip, shape.tip.cf, top)

		if spine and lightsLeft > 0 and table.find(lights.Ranks, rank) then
			lightsLeft -= 1
			local light = Instance.new("PointLight")
			light.Color = glow
			light.Range = lights.Range
			light.Shadows = false
			light.Brightness = 0
			light.Parent = spine
			step(b)
			table.insert(record.lights, light)
			tweenTrack(
				b,
				light,
				{ Brightness = 0 },
				{ Brightness = lights.Brightness[2] },
				lights.Start,
				lights.FadeIn,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.Out
			)
			callTrack(b, lights.Start + lights.FadeIn, function()
				loop(record, light, lights.Breath, { Brightness = lights.Brightness[1] })
			end)
		end

		for _, satellite in cluster.satellites do
			local satBase = ground(b, satellite.x, satellite.z)
			local satFrame = LandingFX.pieceFrame(satBase, outward, satellite.lean, satellite.yaw)
			local satShape = LandingFX.prism(
				satFrame,
				satellite.height,
				satellite.width,
				clusters.TipScale,
				clusters.Spine,
				Tuning.Sink
			)
			local satParts, satFinals = crystalParts(b, satShape, satelliteColor, SMALL_TRANSPARENCY, ore, false)
			local piece =
				addPiece(b, satParts, satFinals, satFrame.UpVector, satellite.depth, Tuning.Exit.ShatterRipple * rank)
			riseTrack(b, piece, 1, satellite.start, satellite.rise)
		end

		local mid = (frame * CFrame.new(0, cluster.height / 2 - Tuning.Sink, 0)).Position
		addBurst(b, base, mid, { ore, glow }, cluster.start, rank, crystal.Sound)
	end

	-- C4: sprouts that count crust progress; applyState raises them
	for k, sprout in layout.sprouts do
		local base = ground(b, sprout.x, sprout.z)
		local frame = LandingFX.pieceFrame(base, outwardOf(sprout.x, sprout.z), sprout.lean, sprout.yaw)
		local shape = LandingFX.prism(frame, sprout.height, sprout.width, clusters.TipScale, clusters.Spine, Tuning.Sink)
		local parts, finals = crystalParts(b, shape, ore, SMALL_TRANSPARENCY, glow, false)
		local piece = addPiece(b, parts, finals, frame.UpVector, sprout.depth, Tuning.Exit.SproutRipple * k)
		table.insert(record.sprouts, { piece = piece, base = base })
	end
	if #record.sprouts > 0 then
		local att = anchorAttachment(b, center)
		local emitter = burstEmitter(att, ore, glow)
		step(b)
		record.sproutBurst = { att = att, emitter = emitter, mid = center }
	end

	-- C5: the crown gem above the crust and the arcs between the crystals
	local gemConfig = crystal.Gem
	local arcs = crystal.Arcs
	local gemPosition = center + Vector3.new(0, gemConfig.Height, 0)
	local gemCFrame = CFrame.new(gemPosition) * LandingFX.TIP_ROTATION
	local gem = addPart(b, "Part", {
		Name = "CrownGem",
		Material = Enum.Material.Neon,
		Color = glow,
		Transparency = 1,
		Size = Vector3.one * GEM_START_SIZE,
		CFrame = gemCFrame,
	})
	record.gem = gem
	table.insert(record.neon, gem)
	tweenTrack(
		b,
		gem,
		{ Size = Vector3.one * GEM_START_SIZE, Transparency = 1 },
		{ Size = Vector3.one * gemConfig.Size, Transparency = 0 },
		gemConfig.Start,
		gemConfig.Pop,
		Enum.EasingStyle.Back,
		Enum.EasingDirection.Out
	)
	callTrack(b, gemConfig.Start + gemConfig.Pop, function()
		startGemLoop(record)
	end)
	local sparkle = makeEmitter(gem, {
		Texture = SPARKLES,
		Rate = particleRate(gemConfig.Sparkles),
		Lifetime = NumberRange.new(1, 1.5),
		Speed = NumberRange.new(1, 2),
		SpreadAngle = Vector2.new(180, 180),
		Size = NumberSequence.new(0.4, 0),
		Color = ColorSequence.new(glow, WHITE),
		LightEmission = 1,
	})
	ambient(b, sparkle, gemConfig.Start)
	local gemAtt = upAttachment(b, gem, gemCFrame, gemPosition)

	for _, pair in layout.arcs do
		local att0, att1 = tips[pair.i], tips[pair.j]
		if att0 and att1 then
			local beam = arcBeam(b, att0, att1, arcs.RingCurve, -arcs.RingCurve)
			tweenTrack(
				b,
				beam,
				{ Width0 = 0, Width1 = 0 },
				{ Width0 = arcs.RingWidth, Width1 = arcs.RingWidth },
				arcs.RingStart + arcs.RingStep * pair.i,
				arcs.RingIgnite,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.Out
			)
		end
	end
	for rank, tipAtt in tips do
		local beam = arcBeam(b, tipAtt, gemAtt, arcs.CrownCurve[1], arcs.CrownCurve[2])
		tweenTrack(
			b,
			beam,
			{ Width0 = 0, Width1 = 0 },
			{ Width0 = arcs.CrownWidth[1], Width1 = arcs.CrownWidth[2] },
			arcs.CrownStart + arcs.CrownStep * rank,
			arcs.CrownIgnite,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out
		)
	end

	-- C6: motes drifting up off the floor
	local motes = crystal.Motes
	local motesHost = hostPart(b, "Motes", motes.Area, Vector3.new(center.X, scene.floorY + motes.Lift, center.Z))
	ambient(b, makeEmitter(motesHost, {
		Texture = SPARKLES,
		Rate = particleRate(motes.Rate),
		EmissionDirection = Enum.NormalId.Top,
		Speed = NumberRange.new(2, 4),
		Lifetime = NumberRange.new(3, 5),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.2, 0.5),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Color = ColorSequence.new(ore, glow),
		LightEmission = 1,
	}), motes.Start)
end

--[[ Timeline ]]

local function startLinear(record: Record, track: Track, t: number)
	local inst = track.inst :: Instance
	local at = track.at :: (number) -> Props
	local alpha = LandingFX.linearAlpha(track.start, track.seconds, t)
	setProps(inst, at(alpha))
	local remaining = track.start + track.seconds - t
	if alpha < 1 and remaining > 0 then
		play(record, inst, remaining, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, at(1))
	end
end

-- Plays every track from event time `t`: finished steps snap to their end, running and
-- coming ones play (a joiner mid-eruption still sees the whole eruption)
local function runTracks(record: Record, t: number)
	local grace = Tuning.Burst.LateGrace
	for _, track in record.tracks do
		if track.kind == "tween" then
			local inst, from, to = track.inst :: Instance, track.from :: Props, track.to :: Props
			local snap, wait = LandingFX.schedule(track.start, track.seconds, t)
			if snap then
				setProps(inst, to)
			else
				setProps(inst, from)
				play(
					record,
					inst,
					track.seconds,
					track.style or Enum.EasingStyle.Linear,
					track.dir or Enum.EasingDirection.Out,
					wait,
					to
				)
			end
		elseif track.kind == "linear" then
			if track.start > t then
				later(record, track.start - t, function()
					startLinear(record, track, track.start)
				end)
			else
				startLinear(record, track, t)
			end
		else
			local run = track.run :: (boolean) -> ()
			if t >= track.start + grace then
				run(false)
			elseif t >= track.start then
				run(true)
			else
				later(record, track.start - t, function()
					run(true)
				end)
			end
		end
	end
	table.clear(record.tracks)
end

--[[ Live event ]]

-- Raises sprouts `from`..`to`, each with a puff from the shared emitter
local function raiseSprouts(record: Record, from: number, to: number, snap: boolean)
	local rise = Tuning.Types.Crystal.Sprouts.Rise
	local fresh: { Sprout } = {}
	for k = from, to do
		local sprout = record.sprouts[k]
		for index, part in sprout.piece.parts do
			local final = sprout.piece.finals[index]
			if snap then
				part.CFrame = final
			else
				play(record, part, rise, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, 0, { CFrame = final })
			end
		end
		table.insert(fresh, sprout)
	end
	local puff = record.sproutBurst
	if snap or not puff or #fresh == 0 then
		return
	end
	-- The moved attachment only takes effect on the next frame
	local token = record.token
	task.spawn(function()
		for _, sprout in fresh do
			puff.att.Position = sprout.base + Vector3.new(0, 1, 0)
			RunService.Heartbeat:Wait()
			if not alive(record, token) then
				return
			end
			puff.emitter:Emit(Tuning.Types.Crystal.Sprouts.Burst)
		end
	end)
end

-- Follows the live State: unlock, crust charge and sprouts. `snap` while building.
local function applyState(record: Record, state: State, snap: boolean)
	if state.unlocked == true and not record.unlocked then
		record.unlocked = true
		for _, flow in record.beams do
			flow.beam.TextureSpeed = flow.speed * 2
		end
		for _, arc in record.arcs do
			arc.beam.TextureSpeed = arc.speed * 2
		end
		if record.typeId == "Ice" then
			local cracks = Tuning.Types.Ice.Cracks
			local color = Config.Meteor.Types.Ice.GlowColor:Lerp(WHITE, cracks.UnlockWhiten)
			for _, strip in record.strips do
				play(record, strip, cracks.UnlockSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, { Color = color })
			end
		elseif record.gemLoop then
			startGemLoop(record)
		end
	end

	if record.typeId == "Crystal" then
		local brightness = Tuning.Types.Crystal.Arcs.Brightness
		local charge = LandingFX.charge(state.crustBroken, state.crustTotal)
		for _, arc in record.arcs do
			arc.beam.Brightness = brightness[1] + (brightness[2] - brightness[1]) * charge
		end
		local shown = LandingFX.sproutsShown(
			state.crustBroken,
			state.crustTotal,
			#record.sprouts,
			Config.Meteor.CoreUnlockFraction
		)
		if shown > record.shown then
			raiseSprouts(record, record.shown + 1, shown, snap)
			record.shown = shown
		end
	end
end

local function fractionOf(part: BasePart): number?
	local hp, maxHp = part:GetAttribute("Hp"), part:GetAttribute("MaxHp")
	if typeof(hp) ~= "number" or typeof(maxHp) ~= "number" or maxHp <= 0 then
		return nil
	end
	return hp / maxHp
end

-- Moves the pooled rime hosts onto the nodes refreezing right now; a host is only
-- written when its node changes
local function assignRime(rime: Rime)
	local config = Tuning.Types.Ice.Rime
	local candidates = {}
	local byId: { [any]: Node } = {}
	for part, node in rime.nodes do
		local id = part:GetAttribute("TargetId")
		if id ~= nil and node.fraction then
			table.insert(candidates, { id = id, fraction = node.fraction, lastRiseAt = node.lastRiseAt })
			byId[id] = node
		end
	end
	local picked = LandingFX.pickRime(candidates, workspace:GetServerTimeNow(), config.Hold, #rime.hosts)
	local wanted: { [any]: boolean } = {}
	for _, id in picked do
		wanted[id] = true
	end
	for slot = 1, #rime.hosts do
		local id = rime.assigned[slot]
		if id ~= nil then
			if wanted[id] then
				wanted[id] = nil -- already hosted
			else
				rime.assigned[slot] = nil
				rime.emitters[slot].Enabled = false
			end
		end
	end
	for _, id in picked do
		if wanted[id] then
			for slot = 1, #rime.hosts do
				if rime.assigned[slot] == nil then
					local node = byId[id]
					local host = rime.hosts[slot]
					host.CFrame = node.part.CFrame
					host.Size = node.part.Size * config.Scale
					rime.emitters[slot].Enabled = true
					rime.assigned[slot] = id
					break
				end
			end
		end
	end
end

-- Watches node HP for refreezes and runs the rime loop while the scene grows
local function startRime(record: Record, rime: Rime)
	local token = record.token
	local crater = child(workspace:FindFirstChild("Map"), "Crater")
	local holder = if crater then crater:FindFirstChild("ActiveMeteor") or crater:WaitForChild("ActiveMeteor", 5) else nil
	if not holder or not alive(record, token) then
		return
	end

	local function watch(item: Instance)
		if not item:IsA("BasePart") or item:GetAttribute("TargetId") == nil or rime.nodes[item] then
			return
		end
		local node: Node = { part = item, fraction = fractionOf(item), lastRiseAt = nil }
		rime.nodes[item] = node
		table.insert(record.conns, item:GetAttributeChangedSignal("Hp"):Connect(function()
			local fraction = fractionOf(item)
			if not fraction then
				return
			end
			-- A hit lowers the fraction and a rescale keeps it; only a refreeze raises it
			if LandingFX.hpChange(node.fraction, fraction) == "rise" then
				node.lastRiseAt = workspace:GetServerTimeNow()
			end
			node.fraction = fraction
		end))
	end
	for _, item in holder:GetDescendants() do
		watch(item)
	end
	table.insert(record.conns, holder.DescendantAdded:Connect(watch))
	table.insert(record.conns, holder.DescendantRemoving:Connect(function(item: Instance)
		if item:IsA("BasePart") then
			rime.nodes[item] = nil
		end
	end))

	local tick = Tuning.Types.Ice.Rime.Tick
	while alive(record, token) do
		local state = MeteorService.State:Get()
		if state then
			local clock = stateClock(state)
			if clock.stage == "Grow" and clock.t >= Config.Meteor.ImpactDuration then
				assignRime(rime)
			end
		end
		task.wait(tick)
	end
end

--[[ Exits and teardown ]]

local function exit(record: Record, stage: string)
	if record.exit then
		return
	end
	record.exit = stage
	-- A fresh token voids every delay scheduled while growing (and stops the rime loop)
	record.token = newToken()
	for _, tween in record.tweens do
		tween:Cancel()
	end
	table.clear(record.tweens)
	record.gemLoop = nil
	for _, emitter in record.emitters do
		emitter.Enabled = false
	end

	local x = Tuning.Exit
	local quad, out, into = Enum.EasingStyle.Quad, Enum.EasingDirection.Out, Enum.EasingDirection.In
	if stage == "Shatter" then
		for _, burst in record.bursts do
			burst.att.Position = burst.mid
		end
		local token = record.token
		task.spawn(function()
			-- The moved attachments only take effect on the next frame
			RunService.Heartbeat:Wait()
			if alive(record, token) then
				for _, burst in record.bursts do
					burst.emitter:Emit(Tuning.Burst.Shatter)
				end
			end
		end)
		for _, light in record.lights do
			play(record, light, x.LightsOut, quad, out, 0, { Brightness = 0 })
		end
		for _, list in { record.arcs, record.beams } do
			for _, flow in list do
				play(record, flow.beam, x.BeamCut, quad, out, 0, { Width0 = 0, Width1 = 0 })
			end
		end
		if record.gem then
			play(record, record.gem, x.GemFlash, quad, out, 0, { Size = Vector3.one * GEM_FLASH_SIZE, Transparency = 1 })
		end
		for _, piece in record.pieces do
			for _, part in piece.parts do
				play(record, part, x.ShatterSeconds, quad, into, piece.ripple, {
					Size = part.Size * x.ShatterScale,
					Transparency = 1,
				})
			end
		end
		for _, list in { record.strips, record.fingers } do
			for _, part in list do
				play(record, part, x.LineFlash, quad, out, 0, { Color = WHITE })
				play(record, part, x.LineFade, quad, out, x.LineFlash, { Transparency = 1 })
			end
		end
		for _, part in record.flats do
			play(record, part, x.LineFade, quad, out, 0, { Transparency = 1 })
		end
	else
		for _, flow in record.beams do
			play(record, flow.beam, WITHER_BEAM_CUT, quad, out, 0, { Width0 = 0, Width1 = 0 })
		end
		for _, part in record.neon do
			part.Material = Enum.Material.Glass
			play(record, part, x.WitherRecolor, quad, out, 0, {
				Color = part.Color:Lerp(Config.Meteor.InertColor, x.InertBlend),
			})
		end
		for _, light in record.lights do
			play(record, light, WITHER_LIGHTS_OUT, quad, out, 0, { Brightness = 0 })
		end
		-- The arcs flicker out one by one
		for index, arc in record.arcs do
			play(record, arc.beam, x.ArcOut, quad, out, x.ArcStep * index, { Width0 = 0, Width1 = 0 })
		end
		for _, piece in record.pieces do
			for index, part in piece.parts do
				play(record, part, x.SinkSeconds, quad, into, x.SinkDelay, {
					CFrame = LandingFX.buried(piece.finals[index], piece.axis, piece.depth),
				})
			end
		end
		for _, list in { record.strips, record.fingers, record.flats } do
			for _, part in list do
				play(record, part, x.FadeSeconds, quad, out, x.FadeDelay, { Transparency = 1 })
			end
		end
		if record.gem then
			play(record, record.gem, x.FadeSeconds, quad, out, x.FadeDelay, { Transparency = 1 })
		end
	end
end

local function teardown()
	local record = current
	if not record then
		return
	end
	current = nil
	record.token = newToken()
	for _, tween in record.tweens do
		tween:Cancel()
	end
	table.clear(record.tweens)
	for _, connection in record.conns do
		connection:Disconnect()
	end
	table.clear(record.conns)
	record.folder:Destroy()
end

local function build(state: State, typeId: string)
	local token = newToken()
	local folder = Instance.new("Folder")
	folder.Name = "LandingFX"
	local anchor = effectPart("Part", {
		Name = "Anchor",
		Size = Vector3.one,
		Transparency = 1,
		CFrame = CFrame.identity,
	})
	anchor.Parent = folder
	local record: Record = {
		eventId = state.eventId,
		typeId = typeId,
		token = token,
		ready = false,
		folder = folder,
		anchor = anchor,
		tweens = {},
		conns = {},
		tracks = {},
		pieces = {},
		strips = {},
		fingers = {},
		flats = {},
		neon = {},
		beams = {},
		arcs = {},
		emitters = {},
		bursts = {},
		lights = {},
		gem = nil,
		gemLoop = nil,
		sprouts = {},
		sproutBurst = nil,
		shown = 0,
		unlocked = false,
		rime = nil,
		exit = nil,
	}
	current = record

	local ok, err = pcall(function()
		local scene = readScene()
		if not alive(record, token) then
			error(ABORT)
		end
		-- Seeded by the event, so every client lays out the same scene
		local layout = LandingFX.layout(typeId, LandingFX.seed(state.eventId, typeId), scene.obstacles, mobile)
		if not layout then
			error(ABORT)
		end
		local b: Build = { record = record, scene = scene, token = token, made = 0 }
		if typeId == "Ice" then
			buildIce(b, layout)
		else
			buildCrystal(b, layout)
		end
	end)
	if not ok then
		if err ~= ABORT then
			warn("[LandingFXController] build failed:", err)
		end
		if current == record then
			teardown()
		end
		return
	end

	-- The clock moved on while building; start everything from where it is now
	local latest: State? = MeteorService.State:Get()
	if not latest or latest.eventId ~= record.eventId then
		teardown()
		return
	end
	local clock = stateClock(latest)
	if clock.stage ~= "Grow" then
		teardown()
		return
	end
	folder.Parent = workspace.CurrentCamera
	record.ready = true
	runTracks(record, clock.t)
	applyState(record, latest, true)
	if record.rime then
		startRime(record, record.rime)
	end
end

local function blockedInStudio(): boolean
	-- Studio isolation control: ReplicatedStorage.DevLandingFX = false turns these effects off
	return RunService:IsStudio() and ReplicatedStorage:GetAttribute("DevLandingFX") == false
end

local function onState(state: State?)
	if not state or blockedInStudio() then
		teardown()
		return
	end
	local record = current
	if record and (record.eventId ~= state.eventId or record.typeId ~= state.type) then
		teardown()
		record = nil
	end

	local clock = stateClock(state)
	if clock.stage == "Grow" then
		if not record then
			local typeId = LandingFX.style(state.type)
			if typeId then
				task.spawn(build, state, typeId)
			end
		elseif record.ready then
			applyState(record, state, false)
		end
	elseif clock.stage == "Shatter" or clock.stage == "Wither" then
		if record then
			if record.ready then
				exit(record, clock.stage)
			else
				teardown()
			end
		end
	else
		teardown()
	end
end

function LandingFXController:KnitStart()
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end
	MeteorService = Knit.GetService("MeteorService")
	mobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

	MeteorService.State:Observe(onState)
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		local record = current
		local camera = workspace.CurrentCamera
		if record and record.ready and camera then
			record.folder.Parent = camera
		end
	end)
	if RunService:IsStudio() then
		ReplicatedStorage:GetAttributeChangedSignal("DevLandingFX"):Connect(function()
			onState(MeteorService.State:Get())
		end)
	end
end

return LandingFXController
