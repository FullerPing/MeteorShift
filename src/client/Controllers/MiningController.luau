--!strict
-- Pickaxe input and local mining feedback (spec §5.4, §5.8).
-- The server validates every swing; everything here is presentation.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Signal = require(ReplicatedStorage.Packages.Signal)

local player = Players.LocalPlayer

local MiningController = Knit.CreateController({
	Name = "MiningController",
	Hit = Signal.new(), -- (part) after the server accepts one of your swings
})

local NodeService
local PlayerStateService

local recentTargets: { [number]: BasePart } = {}
local holding = false
local swinging = false
local pickaxeTier = 1

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

-- What the player is pointing at, or failing that the nearest target in reach
-- (so tapping on mobile just works).
local function findTarget(root: BasePart): (BasePart?, Vector3?)
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

local function sparks(position: Vector3, color: Color3)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.2
	anchor.Position = position
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color, Color3.fromRGB(255, 220, 140))
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new(0.35, 0)
	emitter.Speed = NumberRange.new(12, 22)
	emitter.SpreadAngle = Vector2.new(70, 70)
	emitter.Lifetime = NumberRange.new(0.25, 0.45)
	emitter.Acceleration = Vector3.new(0, -40, 0)
	emitter.Enabled = false
	emitter.Parent = anchor
	anchor.Parent = workspace.CurrentCamera
	emitter:Emit(14)

	local sound = Instance.new("Sound")
	sound.SoundId = "rbxasset://sounds/collide.wav"
	sound.Volume = 0.5
	sound.PlaybackSpeed = 0.9 + math.random() * 0.3
	sound.Parent = anchor
	sound:Play()

	task.delay(1, function()
		anchor:Destroy()
	end)
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

	TweenService:Create(anchor, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = anchor.Position + Vector3.new(0, 4, 0),
	}):Play()
	TweenService:Create(label, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	task.delay(1, function()
		anchor:Destroy()
	end)
end

-- Ore chunks fly from the node to the player. Only this client sees them (spec §5.4).
local function oreFlyIn(from: Vector3, amount: number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	for i = 1, math.clamp(amount, 1, 5) do
		local chunk = Instance.new("Part")
		chunk.Anchored = true
		chunk.CanCollide = false
		chunk.CanQuery = false
		chunk.Size = Vector3.one * 0.6
		chunk.Material = Enum.Material.Metal
		chunk.Color = Color3.fromRGB(196, 176, 160)
		chunk.Position = from + Vector3.new(math.random() * 3 - 1.5, math.random() * 2, math.random() * 3 - 1.5)
		chunk.Parent = workspace.CurrentCamera
		local tween = TweenService:Create(
			chunk,
			TweenInfo.new(0.35 + i * 0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Position = root.Position, Size = Vector3.one * 0.2 }
		)
		tween.Completed:Once(function()
			chunk:Destroy()
		end)
		tween:Play()
	end
end

function MiningController:_swing(tool: Tool)
	if player:GetAttribute("ShopOpen") then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	playSlash(tool)

	local target, hitPoint = findTarget(root)
	if not target then
		return
	end
	local id = target:GetAttribute("TargetId") :: number
	recentTargets[id] = target
	local position = hitPoint or target.Position
	local isCore = target:GetAttribute("TargetKind") == "Core"
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

function MiningController:_bindTool(tool: Tool)
	tool.Activated:Connect(function()
		if player:GetAttribute("ShopOpen") then return end
		holding = true
		if swinging then
			return
		end
		swinging = true
		-- Holding the button keeps swinging at the pickaxe's speed
		while holding and tool.Parent == player.Character and not player:GetAttribute("ShopOpen") do
			self:_swing(tool)
			task.wait(Config.Pickaxes[pickaxeTier].Swing)
		end
		swinging = false
	end)
	tool.Deactivated:Connect(function()
		holding = false
	end)
	tool.Unequipped:Connect(function()
		holding = false
	end)
end

function MiningController:KnitStart()
	NodeService = Knit.GetService("NodeService")
	PlayerStateService = Knit.GetService("PlayerStateService")

	PlayerStateService.State:Observe(function(state)
		if state then
			pickaxeTier = state.pickaxeTier
		end
	end)

	NodeService.OreGained:Connect(function(id: number, _ore: string, amount: number)
		local part = recentTargets[id]
		recentTargets[id] = nil
		if part then
			oreFlyIn(part.Position, amount)
			floater(part.Position + Vector3.new(0, 2, 0), "+" .. Format.number(amount) .. " ore", Color3.fromRGB(150, 230, 255), 22)
		end
	end)

	local bound: { [Tool]: boolean } = {}
	local function watch(container: Instance)
		local function onChild(child: Instance)
			if child:IsA("Tool") and child:GetAttribute("Pickaxe") and not bound[child] then
				bound[child] = true
				self:_bindTool(child)
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
