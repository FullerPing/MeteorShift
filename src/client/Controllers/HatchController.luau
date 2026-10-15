--!strict
-- Hatches queue locally; the reveal cannot hold gameplay input for more than two seconds.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local Pets = require(ReplicatedStorage.Shared.Pets)
local Visuals = require(ReplicatedStorage.Shared.PetVisuals)
local UI = require(script.Parent.Parent.NativeUI)
local Sfx = require(script.Parent.Parent.Sfx)
local PetModel = require(script.Parent.Parent.PetModel)

local player = Players.LocalPlayer
local HatchController = Knit.CreateController({ Name = "HatchController" })
type Hatch = { eggId: string, petId: string, duplicate: boolean }

local function create(className: string, parent: Instance?, props: { [string]: any }): any
	local object: any = Instance.new(className)
	for property, value in props do object[property] = value end
	object.Parent = parent
	return object
end

-- The Blender egg (ReplicatedStorage.MeshArt.eggs, see tools/blender-assets) when present, else a plain shell.
-- Either way the egg is 2.4 studs tall and centred on the origin, where the preview camera looks.
local EGG_HEIGHT = 2.4
-- The reveal sound by rarity
local REVEAL_SOUNDS = {
	common = "RevealCommon", uncommon = "RevealCommon", rare = "RevealRare",
	epic = "RevealEpic", legendary = "RevealLegendary", premium = "RevealLegendary",
}
local BIG_RARITIES = { epic = true, legendary = true, premium = true }

-- Shell pieces burst off the egg inside the preview (particles do not render in a ViewportFrame)
local function shellBurst(world: Instance, color: Color3)
	for index = 1, 9 do
		local angle = index / 9 * math.pi * 2
		local shard = create("Part", world, {
			Name = "Shard", Size = Vector3.new(0.42, 0.3, 0.12), Color = color, Material = Enum.Material.SmoothPlastic,
			CFrame = CFrame.new(math.cos(angle) * 0.4, math.sin(angle) * 0.6, 0) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6),
			Anchored = true, CanCollide = false, CanTouch = false, CanQuery = false,
		})
		local goal = CFrame.new(math.cos(angle) * 2.6, math.sin(angle) * 1.8 - 0.6, 0.8) * CFrame.Angles(math.random() * 9, math.random() * 9, math.random() * 9)
		TweenService:Create(shard, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = goal, Transparency = 1, Size = shard.Size * 0.5 }):Play()
		task.delay(0.6, function() shard:Destroy() end)
	end
end

local function eggModel(eggId: string): Model
	local art = ReplicatedStorage:FindFirstChild("MeshArt")
	local eggs = art and art:FindFirstChild("eggs")
	local source = eggs and eggs:FindFirstChild("egg_" .. (eggId:gsub("Egg$", "")))
	if source and source:IsA("Model") then
		local model = source:Clone()
		model.Name = "HatchEgg"
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false end
		end
		local _, size = model:GetBoundingBox()
		model:ScaleTo(model:GetScale() * EGG_HEIGHT / size.Y)
		-- pivot at the egg's centre so the wobble rocks it in place, turned so its front (-Z) faces the camera at +Z
		model:PivotTo(CFrame.identity)
		local box = model:GetBoundingBox()
		local primary = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart") :: BasePart
		model.PrimaryPart = primary
		primary.PivotOffset = primary.CFrame:ToObjectSpace(CFrame.new(box.Position) * CFrame.Angles(0, math.pi, 0))
		model:PivotTo(CFrame.identity)
		return model
	end
	local model = create("Model", nil, { Name = "HatchEgg" })
	local shell: Part = create("Part", model, {
		Name = "Shell", Shape = Enum.PartType.Ball, Size = Vector3.new(1.8, EGG_HEIGHT, 1.8),
		Color = Color3.fromRGB(213, 207, 195), Material = Enum.Material.SmoothPlastic,
		Anchored = true, CanCollide = false, CanTouch = false, CanQuery = false,
	})
	model.PrimaryPart = shell
	for index = 1, 5 do
		create("Part", model, {
			Name = "OreFleck", Shape = Enum.PartType.Ball, Size = Vector3.new(0.18, 0.26, 0.08),
			CFrame = CFrame.new(math.sin(index * 1.7) * 0.55, (index - 3) * 0.28, -0.76),
			Color = UI.CYAN, Material = Enum.Material.SmoothPlastic,
			Anchored = true, CanCollide = false, CanTouch = false, CanQuery = false,
		})
	end
	return model
end

function HatchController:KnitStart()
	local PetService = Knit.GetService("PetService")
	local PlayerStateService = Knit.GetService("PlayerStateService")
	local PetVisualController = Knit.GetController("PetVisualController")
	local state: any = nil
	PlayerStateService.State:Observe(function(value) state = value end)
	local queue: { Hatch } = {}
	local active: Hatch? = nil
	local startedAt = 0
	local revealed = false
	local reduced = player:GetAttribute("ReduceEffects") == true
	local preview: PetModel.Visual? = nil
	local egg: Model? = nil
	local nextAt = 0
	local gui = UI.get("PetHatch")
	local shade = gui:WaitForChild("DismissBackdrop") :: TextButton
	local panel = gui:WaitForChild("HatchResult") :: Frame
	local title = panel:WaitForChild("PetName") :: TextLabel
	local rarity = panel:WaitForChild("Rarity") :: TextLabel
	local headerClose = panel:WaitForChild("HeaderClose") :: TextButton
	local viewport = panel:WaitForChild("PetPreview") :: ViewportFrame
	-- Cameras may be excluded from StarterGui replication; keep this local to the preview.
	local camera: Camera = (viewport:FindFirstChild("Camera") or create("Camera", viewport, {
		Name = "Camera", FieldOfView = 38,
		CFrame = CFrame.lookAt(Vector3.new(0, 0.5, 6.2), Vector3.zero),
	})) :: Camera
	local world = viewport:WaitForChild("WorldModel") :: WorldModel
	local perks = panel:WaitForChild("PetPerks") :: ScrollingFrame
	local perkText = perks:WaitForChild("PerkText") :: TextLabel
	local duplicate = panel:WaitForChild("Duplicate") :: TextLabel
	local close = panel:WaitForChild("Close") :: TextButton
	local flash = gui:WaitForChild("RarityFlash") :: Frame
	viewport.CurrentCamera = camera
	gui.Enabled = false
	local flashTween: Tween? = nil
	-- Rarity-coloured rays turn slowly behind the revealed pet
	local rays = create("ImageLabel", panel, {
		Name = "RevealRays", Image = Config.RewardFX.Sprites.Rays, BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = math.max(1, viewport.ZIndex - 1), Visible = false, ImageTransparency = 0.2,
	}) :: ImageLabel
	local raysScale = create("UIScale", rays, {}) :: UIScale
	local nextTick = 0

	local function layout()
		local view = UI.menuView(UI.hudLayout())
		local size, inset = view.viewport, view.inset
		local short = size.Y - inset < 430
		local width = math.min(if short then 600 else 360, size.X - 24)
		local height = math.min(if short then 260 else 420, size.Y - inset - 24)
		UI.place(panel, { x = (size.X - width) / 2, y = inset + (size.Y - inset - height) / 2, w = width, h = height }, view)
		title.Position, title.Size = UDim2.fromOffset(12, 10), UDim2.fromOffset(width - 76, 32)
		rarity.Position, rarity.Size = UDim2.fromOffset(12, 42), UDim2.fromOffset(width - 76, 20)
		local previewWidth = if short then 170 else width - 24
		local previewHeight = if short then height - 124 else math.min(158, height - 230)
		viewport.Position, viewport.Size = UDim2.fromOffset(12, 66), UDim2.fromOffset(previewWidth, previewHeight)
		local raySize = math.min(previewWidth, previewHeight * 1.5)
		rays.Position, rays.Size = UDim2.fromOffset(12 + previewWidth / 2, 66 + previewHeight / 2), UDim2.fromOffset(raySize, raySize)
		local textX = if short then 194 else 12
		local textY = if short then 66 else 66 + previewHeight + 4
		perks.Position, perks.Size = UDim2.fromOffset(textX, textY), UDim2.fromOffset(width - textX - 12, math.max(36, height - textY - 98))
		duplicate.Position, duplicate.Size = UDim2.fromOffset(12, height - 90), UDim2.fromOffset(width - 24, 28)
		close.Position = UDim2.fromOffset(12, height - 56)
	end

	local function clearPreview()
		if preview then preview.model:Destroy() preview = nil end
		if egg then egg:Destroy() egg = nil end
	end

	local function dismiss()
		if not active then return end
		active = nil
		clearPreview()
		rays.Visible = false
		PetVisualController:ReserveHatchPreview(false)
		gui.Enabled = false
		player:SetAttribute("HatchOpen", false)
		player:SetAttribute("HatchVisible", false)
		nextAt = os.clock() + 0.12
	end

	local function reveal()
		local hatch = active
		if not hatch or revealed then return end
		revealed = true
		local shellColor = if egg and egg.PrimaryPart then egg.PrimaryPart.Color else Color3.fromRGB(213, 207, 195)
		clearPreview()
		local def = Pets.def(hatch.petId)
		if not def then dismiss() return end
		local owned = state and state.pets and state.pets.owned and state.pets.owned[hatch.petId]
		local level = if owned then owned.level else 1
		local rarityDef = Config.Pets.Rarities[def.Rarity]
		rarity.TextColor3 = rarityDef.Color
		title.Text, rarity.Text = def.Name, rarityDef.Name .. "  ·  Level " .. tostring(level)
		local lines = {}
		for _, perk in Pets.perksOf(def, level) do
			local role = Config.Pets.Roles[perk.role]
			local percent = string.format("%.2f", perk.value * 100):gsub("0+$", ""):gsub("%.$", "") .. "%"
			table.insert(lines, role.Name .. ": " .. string.format(role.Text, percent))
		end
		perkText.Text = table.concat(lines, "\n\n")
		duplicate.Text = if hatch.duplicate then "Duplicate: +" .. tostring(Config.Pets.DuplicateXp) .. " XP" else "Added to your collection"
		close.Text = "CONTINUE  ·  TAP OR ESC"
		preview = PetModel.clone(hatch.petId, level)
		if preview then
			PetModel.reduce(preview, reduced)
			preview.model.Parent = world
			preview.model:PivotTo(CFrame.Angles(0, math.rad(155), 0))
			local bounds, size = preview.model:GetBoundingBox()
			camera.CFrame = CFrame.lookAt(bounds.Position + Vector3.new(0.2, 0.25, 1).Unit * math.max(size.X, size.Y, size.Z) * 1.9, bounds.Position)
		else
			-- The name and perks still reveal while an optional model is missing.
			viewport.Visible = false
		end
		Sfx.play("HatchCrack")
		Sfx.play(REVEAL_SOUNDS[def.Rarity] or "RevealCommon")
		rays.ImageColor3 = rarityDef.Color
		rays.Visible = not reduced
		if not reduced then
			shellBurst(world, shellColor)
			raysScale.Scale = 0.2
			TweenService:Create(raysScale, TweenInfo.new(0.45, Enum.EasingStyle.Back), { Scale = 1 }):Play()
			flash.BackgroundColor3, flash.BackgroundTransparency = rarityDef.Color, if BIG_RARITIES[def.Rarity] then 0.3 else 0.55
			flashTween = TweenService:Create(flash, TweenInfo.new(0.22), { BackgroundTransparency = 1 })
			flashTween:Play()
		end
	end

	local function start(hatch: Hatch)
		PetVisualController:ReserveHatchPreview(true)
		active, startedAt, revealed = hatch, os.clock(), false
		layout()
		title.Text, rarity.Text = "Hatching...", (Pets.egg(hatch.eggId) or { Name = "Pet" }).Name
		perkText.Text, duplicate.Text, close.Text = "", "Tap or Escape to skip", "SKIP"
		shade.Visible, shade.Active, viewport.Visible = true, true, true
		flash.BackgroundTransparency = 1
		gui.Enabled = true
		player:SetAttribute("HatchOpen", true)
		player:SetAttribute("HatchVisible", true)
		egg = eggModel(hatch.eggId)
		egg.Parent = world
		camera.CFrame = CFrame.lookAt(Vector3.new(0, 0.3, 5.5), Vector3.zero)
		if reduced then reveal() end
	end

	shade.Activated:Connect(dismiss)
	close.Activated:Connect(dismiss)
	headerClose.Activated:Connect(dismiss)
	UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then dismiss() end
	end)
	player:GetAttributeChangedSignal("ReduceEffects"):Connect(function()
		reduced = player:GetAttribute("ReduceEffects") == true
		if preview then PetModel.reduce(preview, reduced) end
		if reduced then
			if flashTween then flashTween:Cancel() end
			flash.BackgroundTransparency = 1
			if active then reveal() end
		end
	end)
	PetService.Hatched:Connect(function(eggId: string, petId: string, isDuplicate: boolean)
		if Pets.def(petId) then table.insert(queue, { eggId = eggId, petId = petId, duplicate = isDuplicate }) end
	end)
	local lastViewport = Vector2.zero
	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		if not active and #queue > 0 and now >= nextAt then start(table.remove(queue, 1)) end
		if not active then return end
		local current = workspace.CurrentCamera
		if current and current.ViewportSize ~= lastViewport then lastViewport = current.ViewportSize layout() end
		local elapsed = now - startedAt
		if not Visuals.hatchBlocking(elapsed) then
			player:SetAttribute("HatchOpen", false)
			shade.Visible, shade.Active = false, false
		end
		if not revealed and Visuals.hatchStage(elapsed, reduced) ~= "wobble" then reveal() end
		if egg and not reduced then
			local wobble = math.sin(elapsed * (8 + elapsed * 6)) * (0.08 + elapsed * 0.08)
			egg:PivotTo(CFrame.Angles(0, 0, wobble))
		end
		-- the shell ticks faster and higher as the wobble builds
		if egg and not revealed and now >= nextTick then
			nextTick = now + math.max(0.14, 0.5 - elapsed * 0.25)
			Sfx.play("HatchTick", nil, nil, 1 + elapsed * 0.15)
		end
		if rays.Visible then rays.Rotation = (elapsed * 25) % 360 end
		if elapsed >= 4.5 then dismiss() end
	end)
	player:SetAttribute("HatchOpen", false)
	player:SetAttribute("HatchVisible", false)
end

return HatchController
