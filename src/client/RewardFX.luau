--!strict
-- Reward effects for the local player (Config.RewardFX): a ground ring with sparkles, a light
-- pillar (with confetti for the big moments), a smoke puff, coins flying to the wallet, a
-- popped word over the head and a small FOV punch. Everything is local, lives under the camera
-- (or the given ScreenGui) and cleans itself up. "Reduce effects" skips all of it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local FXKit = require(script.Parent.FXKit)

local settings = Config.RewardFX
local player = Players.LocalPlayer

local RewardFX = {}

function RewardFX.reduced(): boolean
	return player:GetAttribute("ReduceEffects") == true
end

local function rootPart(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- The point under the character's feet
local function feet(root: BasePart): Vector3
	local humanoid = root.Parent and root.Parent:FindFirstChildOfClass("Humanoid")
	local drop = root.Size.Y / 2 + (if humanoid then humanoid.HipHeight else 2)
	return root.Position - Vector3.new(0, drop - 0.15, 0)
end

local function tween(inst: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?)
	local t = TweenService:Create(inst, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), goal)
	t:Play()
	return t
end

local function sparkles(parent: Instance, color: Color3, count: number, speed: { number }, up: number?)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = settings.Sprites.Sparkle
	emitter.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
	emitter.LightEmission = 0.6
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.25, 1.1), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.7, 0.1), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(0.5, 0.9)
	emitter.Speed = FXKit.range(speed)
	emitter.SpreadAngle = Vector2.new(80, 80)
	emitter.Acceleration = Vector3.new(0, up or -10, 0)
	emitter.Drag = 3
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-120, 120)
	emitter.Enabled = false
	emitter.Parent = parent
	emitter:Emit(count)
	return emitter
end

-- A flat ring that sweeps out across the ground from `position`
local function groundRing(position: Vector3, color: Color3, size: number, seconds: number)
	local part = FXKit.anchor(position, Vector3.new(1, 0.05, 1), seconds + 0.1)
	local decal = Instance.new("Decal")
	decal.Texture = settings.Sprites.Ring
	decal.Face = Enum.NormalId.Top
	decal.Color3 = color
	decal.Transparency = 0.05
	decal.Parent = part
	tween(part, seconds, { Size = Vector3.new(size, 0.05, size) }, Enum.EasingStyle.Quart)
	tween(decal, seconds, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
end

local function flashLight(parent: Instance, color: Color3, range: number, seconds: number)
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness, light.Shadows = color, range, 3, false
	light.Parent = parent
	tween(light, seconds, { Brightness = 0 })
end

-- Ring + sparkles + a flash at the player's feet (upgrades, bonuses, pet moments)
function RewardFX.burst(color: Color3, scale: number?)
	local root = rootPart()
	if RewardFX.reduced() or not root then return end
	local s = scale or 1
	local spec = settings.Burst
	local base = feet(root)
	groundRing(base, color, spec.Ring * s, spec.Seconds)
	local anchor = FXKit.anchor(base + Vector3.new(0, 1.5, 0), Vector3.one, 1.4)
	sparkles(anchor, color, math.floor(spec.Count * s), { 10 * s, 20 * s }, 4)
	flashLight(anchor, color, spec.Light * s, 0.5)
end

-- A column of light that rises around the player (evolve, level up; bigger with confetti for rebirth)
function RewardFX.pillar(color: Color3, scale: number?, confetti: boolean?)
	local root = rootPart()
	if RewardFX.reduced() or not root then return end
	local s = scale or 1
	local spec = settings.Pillar
	local base = feet(root)
	local height = spec.Height * s
	local column = FXKit.glowPart(Enum.PartType.Cylinder, color, spec.Transparency)
	column.Size = Vector3.new(height, 0.4, 0.4)
	column.CFrame = CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	column.Parent = workspace.CurrentCamera
	tween(column, 0.18, { Size = Vector3.new(height, spec.Width * s, spec.Width * s) }, Enum.EasingStyle.Back)
	task.delay(spec.Seconds * 0.55, function()
		tween(column, spec.Seconds * 0.45, { Size = Vector3.new(height, 0.1, 0.1), Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end)
	task.delay(spec.Seconds + 0.1, function() column:Destroy() end)
	local inner = FXKit.glowPart(Enum.PartType.Cylinder, Color3.new(1, 1, 1), spec.Transparency - 0.1)
	inner.Size = Vector3.new(height, 0.2, 0.2)
	inner.CFrame = column.CFrame
	inner.Parent = workspace.CurrentCamera
	tween(inner, 0.18, { Size = Vector3.new(height, spec.Width * s * 0.4, spec.Width * s * 0.4) })
	task.delay(spec.Seconds * 0.4, function()
		tween(inner, spec.Seconds * 0.4, { Size = Vector3.new(height, 0.05, 0.05), Transparency = 1 })
	end)
	task.delay(spec.Seconds + 0.1, function() inner:Destroy() end)

	groundRing(base, color, 20 * s, 0.7)
	local anchor = FXKit.anchor(base + Vector3.new(0, 1, 0), Vector3.new(spec.Width * s, 0.2, spec.Width * s), 2.5)
	local rising = sparkles(anchor, color, 0, { spec.Rise * 0.6 * s, spec.Rise * s }, 0)
	rising.EmissionDirection = Enum.NormalId.Top
	rising.SpreadAngle = Vector2.new(12, 12)
	rising.Lifetime = NumberRange.new(0.6, 1.1)
	rising.Shape = Enum.ParticleEmitterShape.Box
	rising:Emit(math.floor(26 * s))
	flashLight(anchor, color, 16 * s, spec.Seconds)

	if confetti then
		local top = FXKit.anchor(base + Vector3.new(0, 7, 0), Vector3.one, 3.5)
		-- one emitter per colour: a particle takes its emitter's current Color for its whole life
		for _, c in settings.Confetti do
			local emitter = Instance.new("ParticleEmitter")
			emitter.Texture = settings.Sprites.Square
			emitter.Color = ColorSequence.new(c)
			emitter.Size = NumberSequence.new(0.35)
			emitter.Lifetime = NumberRange.new(1.6, 2.6)
			emitter.Speed = NumberRange.new(28, 44)
			emitter.SpreadAngle = Vector2.new(50, 50)
			emitter.Acceleration = Vector3.new(0, -34, 0)
			emitter.Drag = 1.6
			emitter.Rotation = NumberRange.new(0, 360)
			emitter.RotSpeed = NumberRange.new(-400, 400)
			emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.85, 0), NumberSequenceKeypoint.new(1, 1) })
			emitter.Enabled = false
			emitter.Parent = top
			emitter:Emit(14)
		end
	end
end

-- A cartoon smoke puff (teleport departure and arrival)
function RewardFX.poof(position: Vector3, color: Color3?)
	if RewardFX.reduced() then return end
	local anchor = FXKit.anchor(position, Vector3.new(3, 4, 3), 2)
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = settings.Sprites.Smoke
	smoke.Color = ColorSequence.new(Color3.new(1, 1, 1), color or Color3.fromRGB(220, 235, 255))
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 5.5) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) })
	smoke.Lifetime = NumberRange.new(0.5, 0.8)
	smoke.Speed = NumberRange.new(6, 12)
	smoke.SpreadAngle = Vector2.new(180, 180)
	smoke.Drag = 5
	smoke.Rotation = NumberRange.new(0, 360)
	smoke.RotSpeed = NumberRange.new(-60, 60)
	smoke.Shape = Enum.ParticleEmitterShape.Box
	smoke.Enabled = false
	smoke.Parent = anchor
	smoke:Emit(18)
	sparkles(anchor, color or settings.Colors.Teleport, 12, { 8, 16 }, 2)
	groundRing(position - Vector3.new(0, 1.8, 0), color or settings.Colors.Teleport, 12, 0.45)
end

-- The player's own puff, at the feet
function RewardFX.poofHere(color: Color3?)
	local root = rootPart()
	if root then RewardFX.poof(feet(root) + Vector3.new(0, 1.8, 0), color) end
end

-- `count` icons arc from `from` to `to` (screen pixels) inside `gui`; `onArrive` runs as each lands
function RewardFX.coins(gui: Instance, from: Vector2, to: Vector2, count: number, icon: string, onArrive: (() -> ())?)
	if RewardFX.reduced() then
		if onArrive then onArrive() end
		return
	end
	local spec = settings.Coins
	for i = 1, math.clamp(count, 1, spec.Max) do
		task.delay((i - 1) * spec.Stagger, function()
			local image = Instance.new("ImageLabel")
			image.BackgroundTransparency = 1
			image.Image = icon
			image.AnchorPoint = Vector2.new(0.5, 0.5)
			image.Size = UDim2.fromOffset(spec.Size, spec.Size)
			image.ZIndex = 50
			local start = from + Vector2.new(math.random(-40, 40), math.random(-30, 30))
			image.Position = UDim2.fromOffset(start.X, start.Y)
			image.Parent = gui
			-- pop out, then curve in: a quadratic bezier through a lifted midpoint
			local mid = (start + to) / 2 + Vector2.new(math.random(-60, 60), -math.random(60, 140))
			local value = Instance.new("NumberValue")
			value.Changed:Connect(function(t: number)
				local p = (1 - t) ^ 2 * start + 2 * (1 - t) * t * mid + t ^ 2 * to
				image.Position = UDim2.fromOffset(p.X, p.Y)
				image.Size = UDim2.fromOffset(spec.Size * (1 - 0.45 * t), spec.Size * (1 - 0.45 * t))
				image.Rotation = t * 200
			end)
			local flight = tween(value, spec.Seconds, { Value = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			flight.Completed:Once(function()
				image:Destroy()
				value:Destroy()
				if onArrive then onArrive() end
			end)
		end)
	end
end

-- A GuiObject's scale pops up and settles (a counter being hit by coins)
function RewardFX.bump(target: GuiObject)
	local scale = target:FindFirstChild("RewardBump") :: UIScale?
	if not scale then
		local made = Instance.new("UIScale")
		made.Name = "RewardBump"
		made.Parent = target
		scale = made
	end
	local s = scale :: UIScale
	s.Scale = 1.12
	tween(s, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
end

-- A big outlined word that pops over the player's head ("FULL!", "LEVEL UP!")
function RewardFX.popText(text: string, color: Color3)
	local root = rootPart()
	if not root then return end
	local anchor = FXKit.anchor(root.Position + Vector3.new(0, 4, 0), Vector3.one * 0.2, 1.4)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(240, 60)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(0.4, 0.4)
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeColor3 = Color3.fromRGB(31, 22, 19)
	label.TextStrokeTransparency = 0
	label.Parent = gui
	tween(label, 0.25, { Size = UDim2.fromScale(1, 1) }, Enum.EasingStyle.Back)
	if not RewardFX.reduced() then
		tween(anchor, 1.3, { Position = anchor.Position + Vector3.new(0, 3, 0) })
	end
	task.delay(0.9, function()
		tween(label, 0.4, { TextTransparency = 1, TextStrokeTransparency = 1 })
	end)
end

-- A tiny camera kick for crits: a decaying tilt applied after the camera scripts each frame,
-- so it never fights other camera effects or leaves the camera off
local kickUntil = 0
local kickBound = false -- not the clock: a kick that ran out unbinds on its next frame, and a crit in between rebound the name
function RewardFX.critPunch()
	if player:GetAttribute("ReduceCameraShake") == true or RewardFX.reduced() then return end
	local spec = settings.CritPunch
	kickUntil = os.clock() + spec.Seconds
	if kickBound then return end
	kickBound = true
	RunService:BindToRenderStep("RewardCritKick", Enum.RenderPriority.Camera.Value + 1, function()
		local camera = workspace.CurrentCamera
		local left = kickUntil - os.clock()
		if left <= 0 or not camera then
			RunService:UnbindFromRenderStep("RewardCritKick")
			kickBound = false
			return
		end
		local amount = left / spec.Seconds
		local t = os.clock() * 60
		camera.CFrame *= CFrame.Angles(math.rad(spec.Degrees * amount * math.sin(t)), math.rad(spec.Degrees * 0.6 * amount * math.cos(t * 1.3)), 0)
	end)
end

return RewardFX
