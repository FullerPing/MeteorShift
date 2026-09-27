--!strict
-- First-session tutorial on the client (spec §11): a step card under the timer,
-- a marker over what to do next and a beam from your character to it. The
-- server decides when a step is done (TutorialService); this only shows the way.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Phase = require(ReplicatedStorage.Shared.Phase)
local UI = require(script.Parent.Parent.UI)

local Children = Fusion.Children
local OnEvent = Fusion.OnEvent

local player = Players.LocalPlayer
local Steps = Config.Tutorial.Steps

local TutorialController = Knit.CreateController({
	Name = "TutorialController",
})

local GUIDE_COLOR = Color3.fromRGB(255, 223, 98)
local HIDE_BEAM_WITHIN = 14 -- studs; close enough to see the marker

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

-- A named part inside one of the player's own plot stations (Intake, Bin).
local function plotPart(stationId: string, name: string): BasePart?
	local plotId = player:GetAttribute("PlotId")
	local map = workspace:FindFirstChild("Map")
	local plots = map and map:FindFirstChild("Plots")
	if not plots or not plotId then
		return nil
	end
	for _, plot in plots:GetChildren() do
		if plot:GetAttribute("PlotId") == plotId then
			local stations = plot:FindFirstChild("Stations")
			for _, station in if stations then stations:GetChildren() else {} do
				if station:GetAttribute("StationId") == stationId then
					local part = station:FindFirstChild(name, true)
					return if part and part:IsA("BasePart") then part else nil
				end
			end
		end
	end
	return nil
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
		return nearest(debrisRocks(), from)
	elseif stepId == "mine_node" then
		return nearest(meteorParts("Crust"), from) or crater()
	elseif stepId == "hit_core" or stepId == "core_shards" then
		return meteorParts("Core")[1] or crater()
	elseif stepId == "meteor_lands" or stepId == "reach_crater" then
		return crater()
	elseif stepId == "deposit" then
		return plotPart("hopper", "Intake")
	elseif stepId == "collect_bar" then
		return plotPart("collector", "Bin")
	elseif stepId == "sell" then
		return townPart({ "TownSquare", "TradingPost", "SellPoint" })
	elseif stepId == "buy" then
		return townPart({ "TownSquare", "PickaxeShop" })
	end
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

-- The marker and beam, made once and moved between targets.
local function makeGuide(): (BillboardGui, Beam)
	local marker = Instance.new("BillboardGui")
	marker.Name = "TutorialMarker"
	marker.Size = UDim2.fromOffset(60, 60)
	marker.AlwaysOnTop = true
	marker.LightInfluence = 0
	marker.MaxDistance = 2000
	marker.Enabled = false
	local arrow = Instance.new("TextLabel")
	arrow.BackgroundTransparency = 1
	arrow.Size = UDim2.fromScale(1, 1)
	arrow.Font = UI.FONT
	arrow.Text = "▼"
	arrow.TextSize = 44
	arrow.TextColor3 = GUIDE_COLOR
	arrow.TextStrokeColor3 = UI.OUTLINE
	arrow.TextStrokeTransparency = 0
	arrow.Parent = marker
	TweenService:Create(
		arrow,
		TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Position = UDim2.fromOffset(0, -12) }
	):Play()
	marker.Parent = player:WaitForChild("PlayerGui")

	local beam = Instance.new("Beam")
	beam.Name = "TutorialBeam"
	beam.Color = ColorSequence.new(GUIDE_COLOR)
	beam.Transparency = NumberSequence.new(0.2, 0.7)
	beam.LightEmission = 1
	beam.FaceCamera = true
	beam.Width0 = 0.5
	beam.Width1 = 0.5
	beam.Segments = 1
	beam.Enabled = false
	beam.Parent = workspace.CurrentCamera
	return marker, beam
end

function TutorialController:KnitStart()
	local TutorialService = Knit.GetService("TutorialService")
	local MeteorService = Knit.GetService("MeteorService")
	local ShopController = Knit.GetController("ShopController")

	local scope = Fusion.scoped(Fusion)
	local viewport = scope:Value(Vector2.new(1280, 720))
	local viewportConnection: RBXScriptConnection? = nil
	local function observeCamera()
		if viewportConnection then viewportConnection:Disconnect() end
		local camera = workspace.CurrentCamera
		if camera then
			local function updateViewport()
				viewport:set(camera.ViewportSize)
			end
			updateViewport()
			viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateViewport)
		end
	end
	observeCamera()
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(observeCamera)
	local hudScale = scope:Computed(function(use)
		local size = use(viewport)
		return math.clamp(math.min(size.X / 1050, size.Y / 760), 0.45, 1)
	end)
	local compact = scope:Computed(function(use)
		return use(viewport).X < 1000
	end)
	local step = scope:Value(nil :: any)
	local meteorState = scope:Value(nil :: any)
	local serverNow = scope:Value(workspace:GetServerTimeNow())
	local finished = scope:Value(false)

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
		ShopController:SetHighlight(value ~= nil and Steps[value.index].Id == "buy")
	end)
	MeteorService.State:Observe(function(value)
		meteorState:set(value)
	end)

	local current = scope:Computed(function(use)
		local s = use(step)
		return if s then Steps[s.index] else nil
	end)

	local hint = scope:Computed(function(use)
		local info = use(current)
		if not info then
			return ""
		end
		local meteor = use(meteorState)
		local waiting = meteor and (meteor.phase == Phase.Countdown or meteor.phase == Phase.Cleanup)
		local left = if meteor then Format.time(meteor.endsAt - use(serverNow)) else ""
		if info.Id == "meteor_lands" and meteor and meteor.phase == Phase.Countdown then
			return "It lands in the crater in " .. left .. ". Mine debris while you wait!"
		end
		local meteorStep = info.Id == "reach_crater" or info.Id == "mine_node" or info.Id == "hit_core" or info.Id == "core_shards"
		if meteorStep and waiting then
			return "The next meteor lands in " .. left .. ". Mine debris while you wait!"
		end
		return info.Hint
	end)

	scope:New("ScreenGui")({
		Name = "Tutorial",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 1,
		Parent = player:WaitForChild("PlayerGui"),
		[Children] = {
			scope:New("Frame")({
				Name = "Card",
				AnchorPoint = scope:Computed(function(use)
					return if use(compact) then Vector2.new(1, 0) else Vector2.new(0.5, 0)
				end),
				Position = scope:Computed(function(use)
					return if use(compact)
						then UDim2.new(1, -18, 0, 354 * use(hudScale))
						else UDim2.new(0.5, 0, 0, 138 * use(hudScale))
				end),
				Size = UDim2.fromOffset(380, 116),
				BackgroundColor3 = UI.PANEL_DARK,
				BackgroundTransparency = 0.04,
				Visible = scope:Computed(function(use)
					return use(step) ~= nil or use(finished)
				end),
				[Children] = {
					scope:New("UIScale")({ Scale = hudScale }),
					UI.cardFill(scope),
					UI.body(scope, {
						Position = UDim2.fromOffset(14, 10),
						Size = UDim2.new(1, -90, 0, 18),
						Text = scope:Computed(function(use)
							local s = use(step)
							return if s then string.format("MINER TRAINING  ·  %d / %d", s.index, s.total) else "TRAINING COMPLETE"
						end),
						TextSize = 12,
						TextColor3 = UI.ORANGE,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
					UI.label(scope, {
						Position = UDim2.fromOffset(14, 31),
						Size = UDim2.new(1, -28, 0, 30),
						Text = scope:Computed(function(use)
							local info = use(current)
							return if info then info.Text else "You're all set. Have fun, miner!"
						end),
						TextSize = 23,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
					UI.body(scope, {
						Position = UDim2.fromOffset(14, 65),
						Size = UDim2.new(1, -28, 0, 35),
						Text = hint,
						TextSize = 14,
						TextColor3 = UI.SUBTEXT,
						TextWrapped = true,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Top,
					}),
					UI.button(scope, {
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.new(1, -10, 0, 7),
						Size = UDim2.fromOffset(58, 25),
						Text = "Skip",
						TextSize = 15,
						BackgroundColor3 = UI.CARD,
						TextColor3 = UI.WHITE,
						Visible = scope:Computed(function(use)
							return use(step) ~= nil
						end),
						[OnEvent("Activated")] = function()
							task.spawn(function()
								TutorialService:Skip()
							end)
						end,
					}),
					scope:New("Frame")({
						Position = UDim2.new(0, 14, 1, -9),
						Size = UDim2.new(1, -28, 0, 4),
						BorderSizePixel = 0,
						BackgroundColor3 = UI.OUTLINE,
						[Children] = {
							UI.corner(scope, 2),
							scope:New("Frame")({
								Size = scope:Computed(function(use)
									local s = use(step)
									return UDim2.fromScale(if s then (s.index - 1) / math.max(s.total, 1) else 1, 1)
								end),
								BorderSizePixel = 0,
								BackgroundColor3 = GUIDE_COLOR,
								[Children] = { UI.corner(scope, 2) },
							}),
						},
					}),
				},
			}),
		},
	})

	-- World guide: follow the current step's target a few times a second
	local marker, beam = makeGuide()
	local from: Attachment? = nil
	local to: Attachment? = nil
	task.spawn(function()
		while true do
			task.wait(0.25)
			serverNow:set(workspace:GetServerTimeNow())
			local info = Fusion.peek(current)
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local target = if info and root then targetFor(info.Id, root.Position) else nil
			if not target or not root then
				marker.Enabled = false
				beam.Enabled = false
				continue
			end
			from = attach(from, root, "TutorialFrom")
			to = attach(to, target, "TutorialTo")
			beam.Attachment0 = from
			beam.Attachment1 = to
			if marker.Adornee ~= target then
				marker.Adornee = target
				marker.StudsOffsetWorldSpace = Vector3.new(0, target.Size.Y / 2 + 3, 0)
			end
			marker.Enabled = true
			beam.Enabled = (target.Position - root.Position).Magnitude > HIDE_BEAM_WITHIN
		end
	end)
end

return TutorialController
