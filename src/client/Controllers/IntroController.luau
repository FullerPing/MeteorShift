--!strict
-- The first-join intro, shown once after the loading screen and before the hands-on tutorial: a few seconds of
-- cinematic instead of pages to read (Config.Intro). The camera opens wide over the crater, a meteor streaks in and
-- crashes into it (flash, shockwave, dust, a shake) as the game's title pops up, then the camera glides back behind
-- the player and hands over. SKIP (or B on a pad) ends it at once. TutorialService says whether it is due
-- (Shared.Intro) and is told when it ends. While it plays the player attribute IntroOpen is true, which keeps the
-- tutorial card and guide hidden and the landing camera off. Everything it makes is local to this client.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local Palette = require(ReplicatedStorage.Shared.MenuPalette)
local Theme = require(script.Parent.Parent.MenuTheme)
local Sfx = require(script.Parent.Parent.Sfx)

local player = Players.LocalPlayer
local Settings = Config.Intro

local IntroController = Knit.CreateController({ Name = "IntroController" })

local FIRE = Color3.fromRGB(255, 140, 40)
local function tween(instance: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?): Tween
	local made = TweenService:Create(instance, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), goal)
	made:Play()
	return made
end

local function part(props: { [string]: any }): Part
	local made = Instance.new("Part")
	made.Anchored, made.CanCollide, made.CanQuery, made.CanTouch, made.CastShadow = true, false, false, false, false
	for key, value in props do (made :: any)[key] = value end
	made.Parent = workspace.CurrentCamera
	return made
end

-- Where the meteor lands: the crater floor under its spawn point (or whatever already sits on it)
local function findSpawn(): Instance?
	local map = workspace:FindFirstChild("Map")
	return map and map:FindFirstChild("Crater") and map.Crater:FindFirstChild("MeteorSpawn")
end
local function craterFloor(): Vector3?
	local spawn = findSpawn()
	if not spawn then
		-- with streaming on, the crater (the map's centre) may not have reached a player who spawned at the edge yet
		pcall(function() player:RequestStreamAroundAsync(Vector3.zero, 4) end)
		spawn = findSpawn()
	end
	if not spawn or not spawn:IsA("BasePart") then return nil end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Instance, spawn }
	local hit = workspace:Raycast(spawn.Position + Vector3.new(0, 60, 0), Vector3.new(0, -500, 0), params)
	return if hit then hit.Position else spawn.Position
end

-- The overlay: letterbox bars, a white flash, the title and tagline (the menus' ink-outlined FredokaOne) and SKIP
type Overlay = { gui: ScreenGui, top: Frame, bottom: Frame, flash: Frame, title: TextLabel, tagline: TextLabel, pop: UIScale, skip: TextButton }
local function overlay(): Overlay
	local gui = Instance.new("ScreenGui")
	gui.Name = "Intro"
	gui.ResetOnSpawn, gui.IgnoreGuiInset, gui.DisplayOrder = false, true, 30
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local function bar(name: string, anchor: number): Frame
		local frame = Instance.new("Frame")
		frame.Name = name
		frame.AnchorPoint = Vector2.new(0, anchor)
		frame.Position = UDim2.fromScale(0, anchor)
		frame.Size = UDim2.fromScale(1, 0)
		frame.BackgroundColor3 = Color3.fromRGB(8, 12, 26)
		frame.BorderSizePixel = 0
		frame.Parent = gui
		return frame
	end
	local top, bottom = bar("Top", 0), bar("Bottom", 1)
	local flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.fromRGB(255, 244, 220)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.ZIndex = 5
	flash.Parent = gui
	-- the title block, tilted like the menus' ribbons, popping in with a UIScale (TextScaled, so FixedTextSize leaves it)
	local block = Instance.new("Frame")
	block.Name = "TitleBlock"
	block.AnchorPoint = Vector2.new(0.5, 0.5)
	block.Position = UDim2.fromScale(0.5, 0.3)
	block.Size = UDim2.fromScale(0.8, 0.22)
	block.BackgroundTransparency = 1
	block.Rotation = -3
	block.ZIndex = 3
	block.Parent = gui
	Instance.new("UISizeConstraint", block).MaxSize = Vector2.new(900, 210)
	local pop = Instance.new("UIScale")
	pop.Scale = 0
	pop.Parent = block
	local title = Theme.label(block, "Title", Settings.Title, 60, Palette.WHITE, Theme.TITLE_FONT, Enum.TextXAlignment.Center)
	title.Size, title.TextScaled, title.ZIndex = UDim2.fromScale(1, 0.62), true, 4
	Theme.ink(title, true, 4)
	local shade = Instance.new("UIGradient")
	shade.Rotation = 90
	shade.Color = ColorSequence.new(Color3.fromRGB(255, 252, 214), Color3.fromRGB(255, 196, 40))
	shade.Parent = title
	local tagline = Theme.label(block, "Tagline", Settings.Tagline, 26, Palette.WHITE, Theme.TITLE_FONT, Enum.TextXAlignment.Center)
	tagline.Position, tagline.Size, tagline.TextScaled, tagline.ZIndex = UDim2.fromScale(0.08, 0.66), UDim2.fromScale(0.84, 0.3), true, 4
	tagline.TextTransparency = 1
	Theme.ink(tagline, true, 3)
	local skip = Theme.button(gui, "Skip", "SKIP", "gold", 20)
	skip.AnchorPoint = Vector2.new(1, 1)
	skip.Position, skip.Size, skip.ZIndex = UDim2.new(1, -20, 1, -20), UDim2.fromOffset(110, 44), 6
	gui.Parent = player:WaitForChild("PlayerGui")
	return { gui = gui, top = top, bottom = bottom, flash = flash, title = title, tagline = tagline, pop = pop, skip = skip }
end

function IntroController:KnitStart()
	local TutorialService = Knit.GetService("TutorialService")
	player:SetAttribute("IntroOpen", false)
	local playing = false

	local function play()
		playing = true
		player:SetAttribute("IntroOpen", true)
		local camera = workspace.CurrentCamera
		local character = player.Character or player.CharacterAdded:Wait()
		local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
		local floor = craterFloor()
		-- where it ends: behind the player, who is turned to face the crater (spawns often face a rock, which hid everything)
		local final: CFrame? = nil
		if root and floor then
			local toward = (floor - root.Position) * Vector3.new(1, 0, 1)
			toward = if toward.Magnitude > 1 then toward.Unit else root.CFrame.LookVector
			root.CFrame = CFrame.lookAt(root.Position, root.Position + toward)
			final = CFrame.lookAt(root.Position - toward * 14 + Vector3.new(0, 7, 0), floor + Vector3.new(0, 6, 0))
		end
		local made: { Instance } = {}
		local ui = overlay()
		table.insert(made, ui.gui)
		local skipped = false
		local connections: { RBXScriptConnection } = {
			ui.skip.Activated:Connect(function() skipped = true end),
			UserInputService.InputBegan:Connect(function(input)
				if input.KeyCode == Enum.KeyCode.ButtonB then skipped = true end
			end),
		}
		-- waits `seconds`, or less when SKIP is pressed; true while the intro should go on
		local function hold(seconds: number): boolean
			local untilTime = os.clock() + seconds
			while not skipped and os.clock() < untilTime do task.wait() end
			return not skipped
		end
		local calm = player:GetAttribute("ReduceEffects") == true
		local still = player:GetAttribute("ReduceCameraShake") == true
		local shake = 0 -- studs of camera shake, decaying
		local shot = camera.CFrame
		local shotSet = false -- only once the wide shot is set up (no crater found: the camera stays the player's)
		-- the shot plays every frame (the push and glide tween `shot`), with the crash's shake on top. Bound after Last: a
		-- RenderStepped handler, or one bound at exactly Last, never reached the drawn frame (players saw their spawn view)
		RunService:BindToRenderStep("IntroCamera", Enum.RenderPriority.Last.Value + 10, function(dt)
			if not shotSet then return end
			if shake > 0.01 and not still then
				camera.CFrame = shot * CFrame.new((math.random() - 0.5) * shake, (math.random() - 0.5) * shake, 0)
				shake *= math.exp(-6 * dt)
			else
				camera.CFrame = shot
			end
		end)

		if root and floor then
			-- the wide shot: back toward the player and up, pushing in slowly while it plays
			local away = (root.Position - floor) * Vector3.new(1, 0, 1)
			away = if away.Magnitude > 1 then away.Unit else Vector3.new(0, 0, 1)
			local look = floor + Vector3.new(0, 8, 0)
			local far = CFrame.lookAt(floor + away * Settings.Distance + Vector3.new(0, Settings.Height, 0), look)
			local near = CFrame.lookAt(floor + away * Settings.Distance * Settings.Push + Vector3.new(0, Settings.Height * Settings.Push, 0), look)
			camera.CameraType = Enum.CameraType.Scriptable
			local push = Instance.new("CFrameValue")
			push.Value = far
			table.insert(made, push)
			table.insert(connections, push.Changed:Connect(function(value) shot = value end))
			shot, shotSet = far, true
			tween(push, Settings.Fall + Settings.Hold, { Value = near }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			tween(ui.top, 0.5, { Size = UDim2.fromScale(1, 0.1) })
			tween(ui.bottom, 0.5, { Size = UDim2.fromScale(1, 0.1) })

			-- the meteor: a glowing ball with a fire trail, streaking in from high behind the crater
			local side = away:Cross(Vector3.yAxis)
			local from = floor - away * 160 + side * 120 + Vector3.new(0, 260, 0)
			local ball = part({ Shape = Enum.PartType.Ball, Size = Vector3.one * 10, Material = Enum.Material.Neon, Color = FIRE, Position = from })
			table.insert(made, ball)
			local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
			a0.Position, a1.Position = Vector3.new(0, 4, 0), Vector3.new(0, -4, 0)
			a0.Parent, a1.Parent = ball, ball
			local trail = Instance.new("Trail")
			trail.Attachment0, trail.Attachment1 = a0, a1
			trail.Lifetime, trail.LightEmission, trail.FaceCamera = 0.6, 1, true
			trail.Color = ColorSequence.new(Color3.fromRGB(255, 230, 140), Color3.fromRGB(255, 70, 20))
			trail.Transparency = NumberSequence.new(0, 1)
			trail.WidthScale = NumberSequence.new(1, 0.2)
			trail.Parent = ball
			local light = Instance.new("PointLight")
			light.Color, light.Brightness, light.Range = FIRE, 4, 40
			light.Parent = ball
			Sfx.play("MeteorRumble")
			tween(ball, Settings.Fall, { Position = floor }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

			if hold(Settings.Fall) then
				-- the crash: a flash, a shockwave ring, dust and sparks, a shake, and the title pops up
				ball.Transparency, light.Enabled = 1, false
				Sfx.play("MeteorImpact")
				ui.flash.BackgroundTransparency = if calm then 0.7 else 0.1
				tween(ui.flash, 0.7, { BackgroundTransparency = 1 })
				shake = 2.2
				local ring = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 6, 6), Material = Enum.Material.Neon, Color = FIRE,
					CFrame = CFrame.new(floor + Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.pi / 2) })
				table.insert(made, ring)
				tween(ring, 1, { Size = Vector3.new(0.6, 120, 120), Transparency = 1 })
				if not calm then
					local burst = part({ Size = Vector3.one, Transparency = 1, Position = floor + Vector3.new(0, 2, 0) })
					table.insert(made, burst)
					for _, spec in {
						{ Color3.fromRGB(150, 118, 92), 4, 0, NumberRange.new(30, 70), 70 }, -- dust and rocks
						{ FIRE, 1.2, 1, NumberRange.new(50, 110), 60 }, -- sparks
					} do
						local emitter = Instance.new("ParticleEmitter")
						emitter.Color = ColorSequence.new(spec[1] :: Color3)
						emitter.Size = NumberSequence.new(spec[2] :: number, 0)
						emitter.LightEmission = spec[3] :: number
						emitter.Speed = spec[4] :: NumberRange
						emitter.SpreadAngle = Vector2.new(75, 75)
						emitter.Lifetime = NumberRange.new(0.8, 1.6)
						emitter.Acceleration = Vector3.new(0, -60, 0)
						emitter.EmissionDirection = Enum.NormalId.Top
						emitter.Enabled = false
						emitter.Parent = burst
						emitter:Emit(spec[5] :: number)
					end
				end
				tween(ui.pop, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
				task.delay(0.35, function() tween(ui.tagline, 0.4, { TextTransparency = 0 }) end)

				if hold(Settings.Hold) then
					-- back to the player: the title and bars go, the camera flies to just behind them
					tween(ui.pop, 0.3, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
					tween(ui.top, 0.6, { Size = UDim2.fromScale(1, 0) })
					tween(ui.bottom, 0.6, { Size = UDim2.fromScale(1, 0) })
					tween(push, Settings.Glide, { Value = final :: CFrame }, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
					hold(Settings.Glide)
				end
			end
		end

		RunService:UnbindFromRenderStep("IntroCamera")
		for _, connection in connections do connection:Disconnect() end
		for _, instance in made do instance:Destroy() end
		-- the follow camera starts from this view, so the player looks at the crater even after SKIP
		if final then camera.CFrame = final end
		camera.CameraType = Enum.CameraType.Custom
		playing = false
		player:SetAttribute("IntroOpen", false)
		task.spawn(function() TutorialService:IntroDone() end)
	end

	TutorialService.Intro:Observe(function(due: boolean)
		if not due or playing then return end
		task.spawn(function()
			-- wait for the loading screen to finish so the intro does not play behind it
			while player:GetAttribute("LoadingDone") ~= true do task.wait(0.25) end
			if TutorialService.Intro:Get() and not playing then play() end
		end)
	end)
end

return IntroController
