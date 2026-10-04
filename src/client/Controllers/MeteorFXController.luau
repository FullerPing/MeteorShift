--!strict
-- Meteor spectacle, all client-side (spec §5.8): streak in the sky for the last
-- seconds of the countdown, rumble and camera shake, impact explosion, shockwave
-- ring, dust, knockback on your own character, core glow and crack flash.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local Phase = require(ReplicatedStorage.Shared.Phase)
local Sfx = require(script.Parent.Parent.Sfx)

local player = Players.LocalPlayer

local MeteorFXController = Knit.CreateController({
	Name = "MeteorFXController",
})

local STREAK_OFFSET = Vector3.new(-420, 520, 260) -- where the streak enters the sky, relative to the crater

local shakeTrauma = 0 -- 0..1, decays over time
local rumbleLevel = 0 -- sustained shake while the meteor approaches
local streak: BasePart? = nil
local streakTween: Tween? = nil
local rumble: Sound? = nil

local function spawnPoint(): Vector3?
	local map = workspace:FindFirstChild("Map")
	local crater = map and map:FindFirstChild("Crater")
	local spawn = crater and crater:FindFirstChild("MeteorSpawn")
	return if spawn and spawn:IsA("BasePart") then spawn.Position else nil
end

local function addShake(amount: number)
	shakeTrauma = math.min(1, shakeTrauma + amount)
end

local function distanceScale(position: Vector3, radius: number): number
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return 0
	end
	return math.clamp(1 - (root.Position - position).Magnitude / radius, 0, 1)
end

function MeteorFXController:_clearStreak()
	if streakTween then
		streakTween:Cancel()
		streakTween = nil
	end
	if streak then
		streak:Destroy()
		streak = nil
	end
	if rumble then
		rumble:Stop()
		rumble:Destroy()
		rumble = nil
	end
	rumbleLevel = 0
end

-- The fireball crossing the sky before impact
function MeteorFXController:_startStreak(target: Vector3, secondsLeft: number, color: Color3)
	self:_clearStreak()
	-- Studio isolation control: disables the approach visuals/audio without changing
	-- the event schedule, landing, mining rules or effects in published games.
	if RunService:IsStudio() and ReplicatedStorage:GetAttribute("DevMeteorApproachFX") == false then
		return
	end

	local ball = Instance.new("Part")
	ball.Name = "MeteorStreak"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.one * 16
	ball.Material = Enum.Material.Neon
	ball.Color = color
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CastShadow = false
	ball.Position = target + STREAK_OFFSET

	local fire = Instance.new("Fire")
	fire.Size = 30
	fire.Heat = 25
	fire.Color = color
	fire.SecondaryColor = Color3.fromRGB(255, 230, 120)
	fire.Parent = ball

	local light = Instance.new("PointLight")
	light.Brightness = 6
	light.Range = 60
	light.Color = color
	light.Parent = ball

	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 6, 0)
	a0.Parent = ball
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -6, 0)
	a1.Parent = ball
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 1.6
	trail.LightEmission = 1
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 240, 180), color)
	trail.Transparency = NumberSequence.new(0, 1)
	trail.WidthScale = NumberSequence.new(1, 0.2)
	trail.Parent = ball

	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(90, 80, 75))
	smoke.Size = NumberSequence.new(8, 20)
	smoke.Transparency = NumberSequence.new(0.3, 1)
	smoke.Lifetime = NumberRange.new(2, 3)
	smoke.Rate = 40
	smoke.Speed = NumberRange.new(2, 5)
	smoke.Parent = ball

	ball.Parent = workspace.CurrentCamera
	streak = ball

	streakTween = TweenService:Create(ball, TweenInfo.new(math.max(secondsLeft, 0.2), Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = target,
		Size = Vector3.one * 22,
	})
	streakTween:Play()

	local rumbleEntry = Config.Sounds.MeteorRumble
	local sound = Instance.new("Sound")
	sound.SoundId = rumbleEntry.Id
	sound.Looped = true
	sound.Volume = rumbleEntry.Volume
	sound.PlaybackSpeed = Sfx.pitch(rumbleEntry)
	sound.Parent = workspace.CurrentCamera
	sound:Play()
	rumble = sound
end

function MeteorFXController:_shockwave(position: Vector3, color: Color3)
	local folder = workspace.CurrentCamera

	-- Expanding ring on the ground
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Color = color
	ring.Transparency = 0.2
	ring.Size = Vector3.new(1, 8, 8)
	ring.CFrame = CFrame.new(position - Vector3.new(0, 4, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = folder
	local radius = Config.Meteor.Knockback.Radius * 2
	TweenService:Create(ring, TweenInfo.new(1.1, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Size = Vector3.new(1, radius, radius),
		Transparency = 1,
	}):Play()

	-- Flash sphere
	local flash = Instance.new("Part")
	flash.Shape = Enum.PartType.Ball
	flash.Anchored = true
	flash.CanCollide = false
	flash.CanQuery = false
	flash.CastShadow = false
	flash.Material = Enum.Material.Neon
	flash.Color = Color3.fromRGB(255, 230, 170)
	flash.Size = Vector3.one * 10
	flash.Position = position
	flash.Parent = folder
	TweenService:Create(flash, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.one * 70,
		Transparency = 1,
	}):Play()

	-- Dust cloud
	local dustAnchor = Instance.new("Part")
	dustAnchor.Anchored = true
	dustAnchor.CanCollide = false
	dustAnchor.CanQuery = false
	dustAnchor.Transparency = 1
	dustAnchor.Size = Vector3.new(40, 1, 40)
	dustAnchor.Position = position
	dustAnchor.Parent = folder
	local dust = Instance.new("ParticleEmitter")
	dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
	dust.Color = ColorSequence.new(Color3.fromRGB(150, 130, 110))
	dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 8), NumberSequenceKeypoint.new(1, 26) })
	dust.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	dust.Lifetime = NumberRange.new(3, 5)
	dust.Speed = NumberRange.new(20, 45)
	dust.SpreadAngle = Vector2.new(80, 80)
	dust.Drag = 2
	dust.Enabled = false
	dust.Parent = dustAnchor
	dust:Emit(60)

	local explosion = Instance.new("Explosion")
	explosion.BlastPressure = 0
	explosion.BlastRadius = 0
	explosion.DestroyJointRadiusPercent = 0
	explosion.Position = position
	explosion.Parent = folder

	Sfx.play("MeteorImpact", dustAnchor)

	task.delay(6, function()
		ring:Destroy()
		flash:Destroy()
		dustAnchor:Destroy()
	end)
end

-- Knockback only, no damage. The client owns its character's physics (spec §12.2).
local function knockback(position: Vector3)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return
	end
	local settings = Config.Meteor.Knockback
	local offset = root.Position - position
	local flat = Vector3.new(offset.X, 0, offset.Z)
	local distance = flat.Magnitude
	if distance > settings.Radius then
		return
	end
	local strength = 1 - distance / settings.Radius
	local direction = if distance > 0.1 then flat.Unit else Vector3.xAxis
	humanoid:ChangeState(Enum.HumanoidStateType.FallingDown)
	root.AssemblyLinearVelocity = direction * settings.Speed * (0.4 + strength * 0.6)
		+ Vector3.new(0, settings.Lift * (0.5 + strength * 0.5), 0)
	task.delay(0.8, function()
		if humanoid.Parent then
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)
end

local function flashScreen(brightness: number, duration: number)
	local correction = Instance.new("ColorCorrectionEffect")
	correction.Brightness = brightness
	correction.TintColor = Color3.fromRGB(255, 225, 190)
	correction.Parent = Lighting
	local tween = TweenService:Create(correction, TweenInfo.new(duration), { Brightness = 0 })
	tween.Completed:Once(function()
		correction:Destroy()
	end)
	tween:Play()
end

function MeteorFXController:_onImpact(position: Vector3, typeId: string?)
	self:_clearStreak()
	local meteorType = Config.Meteor.Types[typeId or "Iron"] or Config.Meteor.Types.Iron
	self:_shockwave(position, meteorType.GlowColor)
	knockback(position)
	addShake(0.4 + distanceScale(position, 250) * 0.6)
	flashScreen(0.5, 0.8)
end

function MeteorFXController:_onCoreCracked(position: Vector3)
	flashScreen(0.8, 1.2)
	addShake(0.3 + distanceScale(position, 200) * 0.5)

	local burst = Instance.new("Part")
	burst.Shape = Enum.PartType.Ball
	burst.Anchored = true
	burst.CanCollide = false
	burst.CanQuery = false
	burst.CastShadow = false
	burst.Material = Enum.Material.Neon
	burst.Color = Color3.fromRGB(255, 200, 120)
	burst.Size = Vector3.one * 14
	burst.Position = position
	burst.Parent = workspace.CurrentCamera
	TweenService:Create(burst, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.one * 60,
		Transparency = 1,
	}):Play()

	local shards = Instance.new("ParticleEmitter")
	shards.Color = ColorSequence.new(Color3.fromRGB(120, 220, 255), Color3.fromRGB(200, 120, 255))
	shards.LightEmission = 1
	shards.Size = NumberSequence.new(1.2, 0)
	shards.Speed = NumberRange.new(40, 80)
	shards.SpreadAngle = Vector2.new(180, 180)
	shards.Lifetime = NumberRange.new(1, 1.8)
	shards.Acceleration = Vector3.new(0, -50, 0)
	shards.Enabled = false
	shards.Parent = burst
	shards:Emit(80)

	Sfx.play("CoreCrack", burst)
	Sfx.play("CoreWhoosh", burst)
	Sfx.play("CoreChime", burst)
	task.delay(3, function()
		burst:Destroy()
	end)
end

function MeteorFXController:KnitStart()
	local MeteorService = Knit.GetService("MeteorService")
	if RunService:IsStudio() then
		ReplicatedStorage:GetAttributeChangedSignal("DevMeteorApproachFX"):Connect(function()
			if ReplicatedStorage:GetAttribute("DevMeteorApproachFX") == false then
				self:_clearStreak()
			end
		end)
	end

	MeteorService.Impact:Connect(function(position: Vector3)
		local state = MeteorService.State:Get()
		self:_onImpact(position, state and state.type)
	end)
	MeteorService.CoreCracked:Connect(function(position: Vector3)
		self:_onCoreCracked(position)
	end)

	-- Streak and rumble ramp in the last seconds of the countdown
	local lastEventStreaked = -1
	RunService.Heartbeat:Connect(function()
		local state = MeteorService.State:Get()
		if not state or state.phase ~= Phase.Countdown then
			if streak and state and state.phase ~= Phase.Countdown then
				self:_clearStreak()
			end
			return
		end
		local left = state.endsAt - workspace:GetServerTimeNow()
		if left <= Config.Meteor.StreakLeadTime and left > 0 then
			local target = spawnPoint()
			if target and lastEventStreaked ~= state.eventId then
				lastEventStreaked = state.eventId
				local meteorType = Config.Meteor.Types[state.type] or Config.Meteor.Types.Iron
				self:_startStreak(target, left, meteorType.GlowColor)
			end
			rumbleLevel = if streak then 1 - left / Config.Meteor.StreakLeadTime else 0
			if rumble then
				rumble.Volume = 0.2 + rumbleLevel * 0.8
			end
		elseif streak and left > Config.Meteor.StreakLeadTime then
			-- Countdown was pushed back; hide the streak
			self:_clearStreak()
			lastEventStreaked = -1
		end
	end)

	-- Camera shake, applied after the default camera update
	RunService:BindToRenderStep("MeteorShake", Enum.RenderPriority.Camera.Value + 1, function(dt)
		shakeTrauma = math.max(0, shakeTrauma - dt * 0.9)
		local amount = math.max(shakeTrauma * shakeTrauma, rumbleLevel * rumbleLevel * 0.25)
		if amount <= 0.001 then
			return
		end
		local t = os.clock() * 30
		local camera = workspace.CurrentCamera
		camera.CFrame *= CFrame.Angles(
			math.rad(math.noise(t, 0) * 4 * amount),
			math.rad(math.noise(0, t) * 4 * amount),
			math.rad(math.noise(t, t) * 2 * amount)
		)
	end)
end

return MeteorFXController
