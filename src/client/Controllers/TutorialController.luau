--!strict
-- First-session tutorial on the client (spec §11), show-don't-tell: a small card
-- with the step's icon and a one-word verb, and the world shows the rest: a glowing
-- trail from your character to the target, an outline on it, a tapping hand (hit
-- it) or bouncing arrow (go there) over it, and a pointing hand on HUD buttons. The
-- server decides when a step is done (TutorialService); this only shows the way.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Phase = require(ReplicatedStorage.Shared.Phase)
local HudLayout = require(ReplicatedStorage.Shared.HudLayout)
local HudIcons = require(ReplicatedStorage.Shared.Config.HudIcons)
local UI = require(script.Parent.Parent.UI)
local MenuFlags = require(script.Parent.Parent.MenuFlags)
local Theme = require(script.Parent.Parent.MenuTheme)
local Palette = require(ReplicatedStorage.Shared.MenuPalette)

local Children = Fusion.Children
local OnEvent = Fusion.OnEvent

local player = Players.LocalPlayer
local Steps = Config.Tutorial.Steps

local TutorialController = Knit.CreateController({
	Name = "TutorialController",
})

local GUIDE_COLOR = Color3.fromRGB(255, 223, 98)
local HIDE_BEAM_WITHIN = 14 -- studs; close enough to see the marker
local TRAIL_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local METEOR_STEPS = { reach_crater = true, mine_node = true, hit_core = true, core_shards = true }

local function isAlive(part: Instance): boolean
	local hp = part:GetAttribute("Hp")
	return part:IsA("BasePart") and part:GetAttribute("TargetId") ~= nil and typeof(hp) == "number" and hp > 0
end

local function nearest(parts: { BasePart }, from: Vector3): BasePart?
	local best, bestDistance = nil, math.huge
	for _, part in parts do
		local distance = (part.Position - from).Magnitude
		if distance < bestDistance then
			best, bestDistance = part, distance
		end
	end
	return best
end

local function crater(): BasePart?
	local map = workspace:FindFirstChild("Map")
	local found = map and map:FindFirstChild("Crater") and map.Crater:FindFirstChild("MeteorSpawn")
	return if found and found:IsA("BasePart") then found else nil
end

local function meteorParts(kind: string): { BasePart }
	local list = {}
	local map = workspace:FindFirstChild("Map")
	local active = map and map:FindFirstChild("Crater") and map.Crater:FindFirstChild("ActiveMeteor")
	if active then
		for _, part in active:GetDescendants() do
			if isAlive(part) and part:GetAttribute("TargetKind") == kind then
				table.insert(list, part :: BasePart)
			end
		end
	end
	return list
end

local function debrisRocks(): { BasePart }
	local list = {}
	local map = workspace:FindFirstChild("Map")
	local debris = map and map:FindFirstChild("Debris")
	if debris then
		for _, rock in debris:GetChildren() do
			if isAlive(rock) then
				table.insert(list, rock :: BasePart)
			end
		end
	end
	return list
end

-- The rock to mine: the starter field's soft rocks first (Config.Tutorial.StarterField), any rock if none is standing
local function starterRock(from: Vector3): BasePart?
	local all, starter = debrisRocks(), {}
	for _, rock in all do
		if rock:GetAttribute("Field") == Config.Tutorial.StarterField then table.insert(starter, rock) end
	end
	return nearest(if #starter > 0 then starter else all, from)
end

-- Deposit and collect use the one shared refinery in town.
local function refineryPoint(): BasePart?
	local map = workspace:FindFirstChild("Map")
	local town = map and map:FindFirstChild("TownSquare")
	local refinery = town and town:FindFirstChild("Refinery")
	local point = refinery and refinery:FindFirstChild("UsePoint", true)
	return if point and point:IsA("BasePart") then point else nil
end

local function townPart(path: { string }): BasePart?
	local node: Instance? = workspace:FindFirstChild("Map")
	for _, name in path do
		node = node and node:FindFirstChild(name)
	end
	if not node then
		return nil
	end
	if node:IsA("BasePart") then
		return node
	end
	local model = node :: Model
	local point = model:FindFirstChild("ShopPoint", true)
	if point and point:IsA("BasePart") then
		return point
	end
	return if model:IsA("Model") and model.PrimaryPart then model.PrimaryPart else model:FindFirstChildWhichIsA("BasePart", true)
end

-- Where the current step wants you to go.
local function targetFor(stepId: string, from: Vector3): BasePart?
	if stepId == "mine_debris" then
		return starterRock(from)
	elseif stepId == "mine_node" then
		return nearest(meteorParts("Crust"), from) or crater()
	elseif stepId == "hit_core" or stepId == "core_shards" then
		return meteorParts("Core")[1] or crater()
	elseif stepId == "reach_crater" then
		return crater()
	elseif stepId == "deposit" or stepId == "collect_bar" then
		return refineryPoint()
	elseif stepId == "sell" then
		return townPart({ "TownSquare", "TradingPost", "SellPoint" })
	end
	-- "buy" has no world target on purpose: only the hand on the HUD Gear button (the gear shop has no place on the
	-- map), and nothing shows while the shop menu is open
	return nil
end

-- Attachments live on the character and on the target, and die with them
-- (respawn, meteor cleanup), so make a fresh one whenever the parent changes.
local function attach(existing: Attachment?, parent: BasePart, name: string): Attachment
	if existing and existing.Parent == parent then
		return existing
	end
	if existing then
		existing:Destroy()
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.Parent = parent
	return attachment
end

-- The guide, made once and moved between targets: a billboard over the target
-- (a bouncing arrow, or a hand tapping with a ripple), a sparkling trail from the
-- character to it and an outline on the target itself.
type Guide = { marker: BillboardGui, arrow: TextLabel, hand: TextLabel, ripple: Frame, timer: TextLabel, beam: Beam, outline: Highlight }

local function loop(instance: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?)
	TweenService:Create(instance, TweenInfo.new(seconds, style or Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), goal):Play()
end

local function makeGuide(): Guide
	local marker = Instance.new("BillboardGui")
	marker.Name = "TutorialMarker"
	marker.Size = UDim2.fromOffset(110, 110)
	marker.AlwaysOnTop = true
	marker.LightInfluence = 0
	marker.MaxDistance = 2000
	marker.Enabled = false
	local function label(name: string, text: string, size: number): TextLabel
		local l = Instance.new("TextLabel")
		l.Name = name
		l.BackgroundTransparency = 1
		l.AnchorPoint = Vector2.new(0.5, 0.5)
		l.Position = UDim2.fromScale(0.5, 0.5)
		l.Size = UDim2.fromScale(1, 1)
		l.Font = UI.FONT
		l.Text = text
		l.TextSize = size
		l.TextColor3 = GUIDE_COLOR
		l.TextStrokeColor3 = UI.OUTLINE
		l.TextStrokeTransparency = 0
		l.ZIndex = 2
		l.Parent = marker
		return l
	end
	local arrow = label("Arrow", "▼", 56)
	loop(arrow, 0.5, { Position = UDim2.new(0.5, 0, 0.5, -14) })
	-- tap: the hand presses down while a ring ripples out under the fingertip
	local ripple = Instance.new("Frame")
	ripple.Name = "Ripple"
	ripple.AnchorPoint = Vector2.new(0.5, 0.5)
	ripple.Position = UDim2.fromScale(0.5, 0.78)
	ripple.Size = UDim2.fromOffset(20, 20)
	ripple.BackgroundTransparency = 1
	local ring = Instance.new("UIStroke")
	ring.Color = GUIDE_COLOR
	ring.Thickness = 4
	ring.Parent = ripple
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = ripple
	ripple.Parent = marker
	TweenService:Create(ripple, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, -1), { Size = UDim2.fromOffset(70, 70) }):Play()
	TweenService:Create(ring, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, -1), { Transparency = 1 }):Play()
	local hand = label("Hand", "👆", 72)
	hand.Position = UDim2.fromScale(0.62, 0.95)
	loop(hand, 0.35, { Position = UDim2.fromScale(0.6, 0.82), Rotation = -8 }, Enum.EasingStyle.Quad)
	-- the "watch" step shows the time left over the crater
	local timer = label("Timer", "", 34)
	timer.Position = UDim2.new(0.5, 0, 0, -22)
	timer.TextColor3 = Color3.new(1, 1, 1)
	marker.Parent = player:WaitForChild("PlayerGui")

	local beam = Instance.new("Beam")
	beam.Name = "TutorialBeam"
	beam.Color = ColorSequence.new(GUIDE_COLOR)
	beam.Transparency = NumberSequence.new(0, 0.4)
	beam.LightEmission = 1
	beam.FaceCamera = true
	beam.Width0 = 1.6
	beam.Width1 = 1.6
	beam.Segments = 1
	beam.Texture = TRAIL_TEXTURE
	beam.TextureMode = Enum.TextureMode.Static
	beam.TextureLength = 4
	beam.TextureSpeed = 1.5 -- the sparkles flow toward the target
	beam.Enabled = false
	beam.Parent = workspace.CurrentCamera

	local outline = Instance.new("Highlight")
	outline.Name = "TutorialOutline"
	outline.FillColor = GUIDE_COLOR
	outline.OutlineColor = GUIDE_COLOR
	outline.FillTransparency = 0.8
	outline.DepthMode = Enum.HighlightDepthMode.Occluded
	outline.Enabled = false
	outline.Parent = workspace.CurrentCamera
	loop(outline, 0.6, { FillTransparency = 0.55, OutlineTransparency = 0.3 })
	return { marker = marker, arrow = arrow, hand = hand, ripple = ripple, timer = timer, beam = beam, outline = outline }
end

-- What the outline should wrap: the whole building for town targets, the part itself otherwise
local function outlineFor(target: BasePart): Instance
	local model = target:FindFirstAncestorWhichIsA("Model")
	if model and model.Parent and model.Parent.Name == "TownSquare" then
		return model
	end
	return target
end

-- A screen-space hand that points down at a HUD button, and a gold ring that pulses round the button
local function makePointer(): (ScreenGui, TextLabel, Frame)
	local gui = Instance.new("ScreenGui")
	gui.Name = "TutorialPointer"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 30
	gui.Enabled = false
	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.BackgroundColor3 = GUIDE_COLOR
	ring.BackgroundTransparency = 0.75
	ring.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.3, 0)
	corner.Parent = ring
	local stroke = Instance.new("UIStroke")
	stroke.Color, stroke.Thickness = GUIDE_COLOR, 4
	stroke.Parent = ring
	local pulse = Instance.new("UIScale")
	pulse.Parent = ring
	TweenService:Create(pulse, TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.18 }):Play()
	TweenService:Create(stroke, TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.6 }):Play()
	ring.Parent = gui
	local hand = Instance.new("TextLabel")
	hand.Name = "Hand"
	hand.BackgroundTransparency = 1
	hand.AnchorPoint = Vector2.new(0.5, 1)
	hand.Size = UDim2.fromOffset(64, 64)
	hand.Font = UI.FONT
	hand.Text = "👇"
	hand.TextSize = 72
	hand.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")
	return gui, hand, ring
end

-- the steps point at HUD buttons, so the hand hides while a menu covers the HUD or the button takes no taps
local POINTER_BLOCKERS = MenuFlags.except("BackpackOpen")
local function findButton(name: string): GuiObject?
	if MenuFlags.anyOpen(POINTER_BLOCKERS) then return nil end
	local found = player:WaitForChild("PlayerGui"):FindFirstChild(name, true)
	return if found and found:IsA("GuiObject") and found.Visible and found.Interactable then found else nil
end

function TutorialController:KnitStart()
	local TutorialService = Knit.GetService("TutorialService")
	local MeteorService = Knit.GetService("MeteorService")
	local ShopController = Knit.GetController("ShopController")

	local scope = Fusion.scoped(Fusion)
	local hud = UI.hud(scope)
	local showGuide = scope:Value(player:GetAttribute("HudShowGuide") ~= false)
	table.insert(scope, player:GetAttributeChangedSignal("HudShowGuide"):Connect(function()
		showGuide:set(player:GetAttribute("HudShowGuide") ~= false)
	end))
	local cardScale = scope:Computed(function(use)
		return use(hud).tutorial.w / Config.Hud.Training.Width
	end)
	local step = scope:Value(nil :: any)
	local meteorState = scope:Value(nil :: any)
	local serverNow = scope:Value(workspace:GetServerTimeNow())
	local finished = scope:Value(false)
	local shown = scope:Computed(function(use)
		return use(step) ~= nil or use(finished)
	end)
	player:SetAttribute("TutorialCardInColumn", false)
	-- the first-join intro (IntroController) covers the screen: no card or guide behind it
	local introOpen = scope:Value(player:GetAttribute("IntroOpen") == true)
	table.insert(scope, player:GetAttributeChangedSignal("IntroOpen"):Connect(function()
		introOpen:set(player:GetAttribute("IntroOpen") == true)
	end))

	local popped = scope:Value(false)
	local lastIndex = 0
	TutorialService.Step:Observe(function(value)
		if value == nil and lastIndex == #Steps then
			finished:set(true)
			task.delay(5, function()
				finished:set(false)
			end)
		end
		lastIndex = if value then value.index else 0
		step:set(value)
		-- the new step's icon pops (a spring back from a bigger size)
		popped:set(true)
		task.delay(0.12, function() popped:set(false) end)
		ShopController:SetHighlight(value ~= nil and Steps[value.index].Id == "buy")
	end)
	MeteorService.State:Observe(function(value)
		meteorState:set(value)
	end)

	local current = scope:Computed(function(use)
		local s = use(step)
		return if s then Steps[s.index] else nil
	end)

	-- Mostly no instructions to read: a meteor step that is waiting for the meteor shows only the time left,
	-- and steps with a Sub add one small line under the verb
	local function waitingFor(info: any, meteor: any): boolean
		return info ~= nil and METEOR_STEPS[info.Id] == true and meteor ~= nil
			and (meteor.phase == Phase.Countdown or meteor.phase == Phase.Cleanup)
	end
	local hint = scope:Computed(function(use)
		local info, meteor = use(current), use(meteorState)
		if not waitingFor(info, meteor) then
			return if info and info.Sub then info.Sub else ""
		end
		return "⏱ " .. Format.time(meteor.endsAt - use(serverNow))
	end)

	-- No card: the step is a caption across the screen in the game's title look (the intro's gold FredokaOne with an ink
	-- outline): the step's icon and a big verb, the hint under it, and a small SKIP TUTORIAL button. It sits where the HUD keeps the
	-- tutorial (hud.tutorial), centred on that spot and free to run wider than it.
	local function ink(thickness: number)
		return scope:New("UIStroke")({ Color = Palette.INK, Thickness = thickness, LineJoinMode = Enum.LineJoinMode.Round })
	end
	local caption = scope:New("Frame")({
		Name = "Card", AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(Config.Hud.Training.Width, Config.Hud.Training.Height),
		BackgroundTransparency = 1,
		Position = scope:Computed(function(use)
			local rect = use(hud).tutorial
			return UDim2.fromOffset(rect.x + rect.w / 2, rect.y)
		end),
		Visible = scope:Computed(function(use)
			return use(shown) and use(showGuide) and not use(introOpen) and use(hud).tutorialVisible
		end),
		[Children] = {
			scope:New("UIScale")({ Scale = cardScale }),
			scope:New("Frame")({
				Name = "Line", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.fromOffset(0, 64),
				AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1,
				[Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center,
						HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					-- the owner's art (Config.HudIcons), popping on each new step
					scope:New("Frame")({
						Name = "IconSlot", LayoutOrder = 1, Size = UDim2.fromOffset(60, 60), BackgroundTransparency = 1,
						[Children] = {
							UI.hudIcon(scope, "ore", {
								Name = "StepIcon", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
								Size = scope:Spring(scope:Computed(function(use)
									return if use(popped) then UDim2.fromOffset(72, 72) else UDim2.fromOffset(56, 56)
								end), 30, 0.45),
								Image = scope:Computed(function(use)
									local info = use(current)
									return HudIcons[if info then info.Icon else "premium"] or ""
								end),
							}),
						},
					}),
					scope:New("TextLabel")({
						Name = "Verb", LayoutOrder = 2, Size = UDim2.fromOffset(0, 60), AutomaticSize = Enum.AutomaticSize.X,
						BackgroundTransparency = 1, Font = Theme.TITLE_FONT, TextColor3 = Palette.WHITE, Rotation = -2,
						TextSize = scope:Computed(function(use) return math.max(46, 30 / use(cardScale)) end),
						Text = scope:Computed(function(use)
							local info = use(current)
							return if info then info.Text else "ALL SET!"
						end),
						[Children] = {
							scope:New("UIGradient")({ Rotation = 90, Color = ColorSequence.new(Palette.GOLD_TOP, Palette.GOLD_BOTTOM) }),
							ink(4),
						},
					}),
				},
			}),
			scope:New("TextLabel")({
				Name = "Hint", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 64), Size = UDim2.fromOffset(520, 28),
				BackgroundTransparency = 1, Font = Theme.TITLE_FONT, TextColor3 = Palette.WHITE, Text = hint, TextScaled = true,
				[Children] = {
					scope:New("UITextSizeConstraint")({ MinTextSize = 8, MaxTextSize = scope:Computed(function(use) return math.max(24, 16 / use(cardScale)) end) }),
					ink(2.5),
				},
			}),
		},
	})
	scope:New("ScreenGui")({
		Name = "Tutorial", ResetOnSpawn = false, IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 1,
		Parent = player:WaitForChild("PlayerGui"),
		[Children] = { caption },
	})

	-- SKIP TUTORIAL: a small button of its own under the hint, out of the instruction's way
	local skip = Theme.button(caption, "SkipTraining", "SKIP TUTORIAL", "blue", 14)
	skip.AnchorPoint, skip.Position = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 96)
	skip.Activated:Connect(function() task.spawn(function() TutorialService:Skip() end) end)
	scope:Observer(step):onBind(function()
		skip.Visible = Fusion.peek(step) ~= nil
	end)
	scope:Observer(cardScale):onBind(function()
		-- never smaller than a comfortable tap once the caption is scaled down
		local height = HudLayout.closeSize(30, Fusion.peek(cardScale))
		skip.Size = UDim2.fromOffset(height * 4.6, height)
	end)

	-- World guide: follow the current step's target a few times a second. While a
	-- meteor step waits for the meteor, the guide shows debris to mine instead; the
	-- "watch" step keeps pointing at the crater with the time left over it.
	local guide = makeGuide()
	local pointerGui, pointerHand, pointerRing = makePointer()
	loop(pointerHand, 0.4, { Rotation = 6 })
	local from: Attachment? = nil
	local to: Attachment? = nil
	task.spawn(function()
		while true do
			task.wait(0.25)
			serverNow:set(workspace:GetServerTimeNow())
			local info = Fusion.peek(current)
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local visible = info ~= nil and root ~= nil and Fusion.peek(showGuide) and not Fusion.peek(introOpen)
			local action = if info then info.Action else "go"
			local target: BasePart? = nil
			local waiting = visible and waitingFor(info, Fusion.peek(meteorState))
			if visible and root and info then
				if waiting then
					target, action = starterRock(root.Position), "tap"
				else
					target = targetFor(info.Id, root.Position)
				end
			end
			-- HUD steps: a hand points at the button
			local button = if visible and info and info.Action == "ui" and info.Button then findButton(info.Button) else nil
			if button then
				-- AbsolutePosition is measured from below the top bar; the pointer's own gui starts above it, so take its origin off
				local at = button.AbsolutePosition - pointerGui.AbsolutePosition
				pointerHand.Position = UDim2.fromOffset(at.X + button.AbsoluteSize.X / 2, at.Y + 8)
				pointerRing.Position = UDim2.fromOffset(at.X + button.AbsoluteSize.X / 2, at.Y + button.AbsoluteSize.Y / 2)
				pointerRing.Size = UDim2.fromOffset(button.AbsoluteSize.X + 10, button.AbsoluteSize.Y + 10)
			end
			pointerGui.Enabled = button ~= nil
			if not target or not root or button then
				guide.marker.Enabled = false
				guide.beam.Enabled = false
				guide.outline.Enabled = false
				continue
			end
			from = attach(from, root, "TutorialFrom")
			to = attach(to, target, "TutorialTo")
			guide.beam.Attachment0 = from
			guide.beam.Attachment1 = to
			if guide.marker.Adornee ~= target then
				guide.marker.Adornee = target
				guide.marker.StudsOffsetWorldSpace = Vector3.new(0, target.Size.Y / 2 + 4, 0)
			end
			local tapping = action == "tap"
			guide.arrow.Visible = not tapping
			guide.hand.Visible = tapping
			guide.ripple.Visible = tapping
			guide.timer.Text = ""
			guide.marker.Enabled = true
			guide.outline.Adornee = outlineFor(target)
			guide.outline.Enabled = true
			guide.beam.Enabled = (target.Position - root.Position).Magnitude > HIDE_BEAM_WITHIN
		end
	end)
end

return TutorialController
