--!strict
-- Pickaxe input and local mining feedback (spec §5.4, §5.8).
-- The server validates every swing; everything here is presentation.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Aim = require(ReplicatedStorage.Shared.Aim)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Sfx = require(script.Parent.Parent.Sfx)

local player = Players.LocalPlayer

local MiningController = Knit.CreateController({
	Name = "MiningController",
	Hit = Signal.new(), -- (part) after the server accepts one of your swings
})

local NodeService
local PlayerStateService

local recentTargets: { [number]: BasePart } = {}
-- Two ways to hold a swing: the pickaxe's own button (tool.Activated, aims at the pointer)
-- and the touch MINE button (aims at the nearest target in front). One loop serves both.
local pointerHolding = false
local touchHolding = false
local swinging = false
local pickaxeTier = 1
-- Each swing at a target turns the character toward it for a moment (Config.Hud.Mine)
local facePoint: Vector3? = nil
local faceUntil = 0

-- Hit effects stay bounded however long the button is held (spec §12.3): spark
-- emitters come from a small pool reused round-robin, and live floaters and ore
-- chunks are capped (Config.Net), the oldest removed first.
type SparkSlot = { anchor: BasePart, emitter: ParticleEmitter, sound: Sound }
local sparkPool: { SparkSlot } = {}
local nextSparkSlot = 1
local hitVariant = false -- alternates the two hit sounds
local watchedNodes: { [BasePart]: boolean } = {} -- nodes already listening for their Hp to reach 0

local floaters: { BasePart } = {} -- oldest first
local oreChunks: { BasePart } = {} -- oldest first

local function distanceToPart(part: BasePart, point: Vector3): number
	local localPoint = part.CFrame:PointToObjectSpace(point)
	local half = part.Size / 2
	local clamped = Vector3.new(
		math.clamp(localPoint.X, -half.X, half.X),
		math.clamp(localPoint.Y, -half.Y, half.Y),
		math.clamp(localPoint.Z, -half.Z, half.Z)
	)
	return (localPoint - clamped).Magnitude
end

local function isMineable(part: Instance?): boolean
	if not part or not part:IsA("BasePart") then
		return false
	end
	local hp = part:GetAttribute("Hp")
	if part:GetAttribute("TargetId") == nil or typeof(hp) ~= "number" or hp <= 0 then
		return false
	end
	if part:GetAttribute("TargetKind") == "Core" and not part:GetAttribute("Unlocked") then
		return false
	end
	return true
end

local function candidates(): { BasePart }
	local list = {}
	local map = workspace:FindFirstChild("Map")
	if not map then
		return list
	end
	local debris = map:FindFirstChild("Debris")
	if debris then
		for _, rock in debris:GetChildren() do
			if isMineable(rock) then
				table.insert(list, rock :: BasePart)
			end
		end
	end
	local active = map:FindFirstChild("Crater") and map.Crater:FindFirstChild("ActiveMeteor")
	if active then
		for _, part in active:GetDescendants() do
			if isMineable(part) then
				table.insert(list, part :: BasePart)
			end
		end
	end
	return list
end

-- The nearest mineable target in reach and in front of the character (Shared.Aim). Used
-- when there is no pointer to aim with (the touch MINE button). The server still checks
-- range on every swing.
local function nearestTarget(root: BasePart): BasePart?
	local parts = candidates()
	local entries: { Aim.Candidate } = {}
	local look = root.CFrame.LookVector
	look = Vector3.new(look.X, 0, look.Z)
	for i, part in parts do
		local toPart = part.Position - root.Position
		toPart = Vector3.new(toPart.X, 0, toPart.Z)
		local dot = 1
		if toPart.Magnitude > 0.01 and look.Magnitude > 0.01 then
			dot = look.Unit:Dot(toPart.Unit)
		end
		entries[i] = {
			distance = distanceToPart(part, root.Position),
			dot = dot,
			core = part:GetAttribute("TargetKind") == "Core",
		}
	end
	local index = Aim.nearest(entries, Config.Meteor.MineRange, Config.Hud.Mine.FrontDot, Config.Hud.Mine.CoreBonus)
	return if index then parts[index] else nil
end

-- What the player is pointing at, or failing that the nearest target in reach
-- (so tapping on mobile just works). "nearest" mode skips the pointer.
local function findTarget(root: BasePart, mode: "pointer" | "nearest"): (BasePart?, Vector3?)
	if mode == "nearest" then
		return nearestTarget(root), nil
	end
	local camera = workspace.CurrentCamera
	local mouse = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { player.Character :: Instance }
	params.FilterType = Enum.RaycastFilterType.Exclude
	local result = workspace:Raycast(ray.Origin, ray.Direction * 250, params)
	if result and isMineable(result.Instance) then
		local part = result.Instance :: BasePart
		if distanceToPart(part, root.Position) <= Config.Meteor.MineRange then
			return part, result.Position
		end
	end

	local best, bestDistance = nil, math.huge
	for _, part in candidates() do
		local distance = distanceToPart(part, root.Position)
		-- Prefer an exposed core over crust when both are in reach
		if part:GetAttribute("TargetKind") == "Core" then
			distance -= 4
		end
		if distance < bestDistance then
			best, bestDistance = part, distance
		end
	end
	if best and distanceToPart(best, root.Position) <= Config.Meteor.MineRange then
		return best, nil
	end
	return nil, nil
end

local function playSlash(tool: Tool)
	-- The default Animate script plays a slash when it sees a "toolanim" value
	local value = Instance.new("StringValue")
	value.Name = "toolanim"
	value.Value = "Slash"
	value.Parent = tool
end

-- Adds an effect part to a capped list, destroying the oldest past the cap.
local function track(list: { BasePart }, part: BasePart, cap: number)
	table.insert(list, part)
	if #list > cap then
		(table.remove(list, 1) :: BasePart):Destroy()
	end
end

-- Destroys an effect part at the end of its life and drops it from its list.
local function untrack(list: { BasePart }, part: BasePart)
	part:Destroy()
	local index = table.find(list, part)
	if index then
		table.remove(list, index)
	end
end

-- The next spark anchor (part, emitter and sound) from the pool. A slot is
-- built on first use, or rebuilt if its anchor is no longer under the current
-- camera (the camera was replaced or destroyed).
local function sparkSlot(): SparkSlot
	local slot = sparkPool[nextSparkSlot]
	if not slot or slot.anchor.Parent ~= workspace.CurrentCamera then
		if slot then
			slot.anchor:Destroy()
		end
		local anchor = Instance.new("Part")
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.Transparency = 1
		anchor.Size = Vector3.one * 0.2

		local emitter = Instance.new("ParticleEmitter")
		emitter.LightEmission = 1
		emitter.Size = NumberSequence.new(0.35, 0)
		emitter.Speed = NumberRange.new(12, 22)
		emitter.SpreadAngle = Vector2.new(70, 70)
		emitter.Lifetime = NumberRange.new(0.25, 0.45)
		emitter.Acceleration = Vector3.new(0, -40, 0)
		emitter.Enabled = false
		emitter.Parent = anchor

		local sound = Instance.new("Sound")
		sound.SoundId = Config.Sounds.HitA.Id
		sound.Volume = Config.Sounds.HitA.Volume
		sound.Parent = anchor
		anchor.Parent = workspace.CurrentCamera

		slot = { anchor = anchor, emitter = emitter, sound = sound }
		sparkPool[nextSparkSlot] = slot
	end
	nextSparkSlot = nextSparkSlot % Config.Net.SparkPoolSize + 1
	return slot :: SparkSlot
end

local function sparks(position: Vector3, color: Color3)
	local slot = sparkSlot()
	slot.anchor.Position = position
	slot.emitter.Color = ColorSequence.new(color, Color3.fromRGB(255, 220, 140))
	slot.emitter:Emit(14)
	hitVariant = not hitVariant
	local entry = if hitVariant then Config.Sounds.HitA else Config.Sounds.HitB
	slot.sound.SoundId = entry.Id
	slot.sound.Volume = entry.Volume
	slot.sound.PlaybackSpeed = Sfx.pitch(entry)
	slot.sound:Play()
end

local function floater(position: Vector3, text: string, color: Color3, size: number)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.2
	anchor.Position = position + Vector3.new(math.random() * 2 - 1, 1, math.random() * 2 - 1)

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(160, 50)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextColor3 = color
	label.TextSize = size
	label.TextStrokeColor3 = Color3.fromRGB(31, 22, 19)
	label.TextStrokeTransparency = 0
	label.Parent = gui
	anchor.Parent = workspace.CurrentCamera
	track(floaters, anchor, Config.Net.MaxFloaters)

	TweenService:Create(anchor, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = anchor.Position + Vector3.new(0, 4, 0),
	}):Play()
	TweenService:Create(label, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	task.delay(1, function()
		untrack(floaters, anchor)
	end)
end

-- Ore chunks fly from the node to the player. Only this client sees them (spec §5.4).
local DEFAULT_CHUNK_COLOR = Color3.fromRGB(196, 176, 160)

-- The chunk colour for an ore: the OreColor of the meteor type that drops it.
local function chunkColor(oreType: string): Color3
	for _, meteorType in Config.Meteor.Types do
		if meteorType.Ore == oreType then
			return meteorType.OreColor
		end
	end
	return DEFAULT_CHUNK_COLOR
end

local function oreFlyIn(from: Vector3, amount: number, oreType: string)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local color = chunkColor(oreType)
	for i = 1, math.clamp(amount, 1, 5) do
		local chunk = Instance.new("Part")
		chunk.Anchored = true
		chunk.CanCollide = false
		chunk.CanQuery = false
		chunk.Size = Vector3.one * 0.6
		chunk.Material = Enum.Material.Metal
		chunk.Color = color
		chunk.Position = from + Vector3.new(math.random() * 3 - 1.5, math.random() * 2, math.random() * 3 - 1.5)
		chunk.Parent = workspace.CurrentCamera
		track(oreChunks, chunk, Config.Net.MaxOreChunks)

		local tween = TweenService:Create(
			chunk,
			TweenInfo.new(0.35 + i * 0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Position = root.Position, Size = Vector3.one * 0.2 }
		)
		tween.Completed:Once(function()
			untrack(oreChunks, chunk)
		end)
		tween:Play()
	end
end

-- States where something else owns the character's rotation (knockback, seats, death)
local NO_TURN_STATES = {
	[Enum.HumanoidStateType.FallingDown] = true,
	[Enum.HumanoidStateType.Ragdoll] = true,
	[Enum.HumanoidStateType.GettingUp] = true,
	[Enum.HumanoidStateType.Physics] = true,
	[Enum.HumanoidStateType.PlatformStanding] = true,
	[Enum.HumanoidStateType.Seated] = true,
	[Enum.HumanoidStateType.Dead] = true,
}

-- Turns the character toward the last swing's target for FaceHold seconds after it. The
-- client owns its character (spec §12.2). Walking steers as usual, and with the mouse
-- locked (shift lock, first person) the camera already decides where you face.
local function turnTowardTarget(dt: number)
	local point = facePoint
	if not point or os.clock() > faceUntil then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or NO_TURN_STATES[humanoid:GetState()] then
		return
	end
	if humanoid.MoveDirection.Magnitude > 0.1 or UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
		return
	end
	local flat = Vector3.new(point.X - root.Position.X, 0, point.Z - root.Position.Z)
	if flat.Magnitude < 0.5 then
		return
	end
	local goal = CFrame.lookAt(root.Position, root.Position + flat)
	if root.CFrame.LookVector:Dot(goal.LookVector) > 0.9995 then
		facePoint = nil
		return
	end
	root.CFrame = root.CFrame:Lerp(goal, 1 - math.exp(-Config.Hud.Mine.FaceTurnRate * dt))
end

function MiningController:_swing(tool: Tool, mode: "pointer" | "nearest")
	if player:GetAttribute("ShopOpen") or player:GetAttribute("SettingsOpen") or player:GetAttribute("RefineryOpen") then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	playSlash(tool)

	local target, hitPoint = findTarget(root, mode)
	if not target then
		return
	end
	local id = target:GetAttribute("TargetId") :: number
	recentTargets[id] = target
	local position = hitPoint or target.Position
	facePoint = position
	faceUntil = os.clock() + Config.Hud.Mine.FaceHold
	local isCore = target:GetAttribute("TargetKind") == "Core"
	if not isCore and not watchedNodes[target] then
		-- Node break: the replicated Hp reaching 0 (the core has its own crack sound)
		watchedNodes[target] = true
		local connection: RBXScriptConnection
		connection = target:GetAttributeChangedSignal("Hp"):Connect(function()
			local hp = target:GetAttribute("Hp")
			if typeof(hp) == "number" and hp <= 0 then
				connection:Disconnect()
				watchedNodes[target] = nil
				Sfx.play("NodeBreak", target)
			end
		end)
		target.Destroying:Once(function()
			watchedNodes[target] = nil
		end)
	end
	sparks(position, if isCore then Color3.fromRGB(255, 140, 50) else Color3.fromRGB(255, 230, 190))

	task.spawn(function()
		local ok, damage = NodeService:Swing(id)
		if ok and damage then
			MiningController.Hit:Fire(target)
			floater(
				position,
				Format.number(damage),
				if isCore then Color3.fromRGB(255, 170, 60) else Color3.fromRGB(255, 255, 255),
				if isCore then 34 else 28
			)
		end
	end)
end

function MiningController:_holdLoop(tool: Tool)
	if swinging then
		return
	end
	swinging = true
	-- Holding the button keeps swinging at the pickaxe's speed
	while (pointerHolding or touchHolding) and tool.Parent == player.Character and not player:GetAttribute("ShopOpen") and not player:GetAttribute("SettingsOpen") and not player:GetAttribute("RefineryOpen") do
		self:_swing(tool, if touchHolding then "nearest" else "pointer")
		task.wait(Config.Pickaxes[pickaxeTier].Swing)
	end
	swinging = false
end

-- The pickaxe in the character's hands, if any
function MiningController:GetEquippedPickaxe(): Tool?
	local character = player.Character
	if not character then
		return nil
	end
	for _, child in character:GetChildren() do
		if child:IsA("Tool") and child:GetAttribute("Pickaxe") then
			return child
		end
	end
	return nil
end

-- The touch MINE button (MobileControlsController): while held, swings at the pickaxe's
-- speed at the nearest target in front. Releasing, or the pickaxe leaving your hands, stops it.
function MiningController:SetTouchHold(on: boolean)
	touchHolding = on
	if on then
		local tool = self:GetEquippedPickaxe()
		if tool and not player:GetAttribute("ShopOpen") and not player:GetAttribute("SettingsOpen") and not player:GetAttribute("RefineryOpen") then
			self:_holdLoop(tool)
		else
			touchHolding = false
		end
	end
end

function MiningController:_bindTool(tool: Tool)
	tool.Activated:Connect(function()
		if player:GetAttribute("ShopOpen") or player:GetAttribute("SettingsOpen") or player:GetAttribute("RefineryOpen") then return end
		pointerHolding = true
		self:_holdLoop(tool)
	end)
	tool.Deactivated:Connect(function()
		pointerHolding = false
	end)
	tool.Unequipped:Connect(function()
		pointerHolding = false
		touchHolding = false
	end)
end

function MiningController:KnitStart()
	NodeService = Knit.GetService("NodeService")
	PlayerStateService = Knit.GetService("PlayerStateService")
	-- Mining uses one permanent pickaxe. Equip it directly so Roblox's tool slot
	-- does not cover the foundry summary at the bottom of the HUD.
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)

	PlayerStateService.State:Observe(function(state)
		if state then
			pickaxeTier = state.pickaxeTier
		end
	end)

	RunService.PreSimulation:Connect(turnTowardTarget)

	NodeService.OreGained:Connect(function(id: number, oreType: string, amount: number)
		local part = recentTargets[id]
		recentTargets[id] = nil
		if part then
			oreFlyIn(part.Position, amount, oreType)
			floater(part.Position + Vector3.new(0, 2, 0), "+" .. Format.number(amount) .. " ore", Color3.fromRGB(150, 230, 255), 22)
		end
	end)

	local bound: { [Tool]: boolean } = {}
	local function watch(container: Instance)
		local function onChild(child: Instance)
			if child:IsA("Tool") and child:GetAttribute("Pickaxe") and not bound[child] then
				bound[child] = true
				self:_bindTool(child)
				if container:IsA("Backpack") then
					task.defer(function()
						local character = player.Character
						local humanoid = character and character:FindFirstChildOfClass("Humanoid")
						if humanoid and child.Parent == container then humanoid:EquipTool(child :: Tool) end
					end)
				end
			end
		end
		for _, child in container:GetChildren() do
			onChild(child)
		end
		container.ChildAdded:Connect(onChild)
	end

	local function onCharacter(character: Model)
		watch(character)
		watch(player:WaitForChild("Backpack"))
	end
	if player.Character then
		onCharacter(player.Character)
	end
	player.CharacterAdded:Connect(onCharacter)
end

return MiningController
