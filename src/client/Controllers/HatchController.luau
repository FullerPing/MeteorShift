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

	local function layout()
		local current = workspace.CurrentCamera
		local size = if current then current.ViewportSize else Vector2.new(390, 844)
		local inset = GuiService:GetGuiInset().Y
		local short = size.Y - inset < 430
		local width = math.min(if short then 600 else 360, size.X - 24)
		local height = math.min(if short then 260 else 420, size.Y - inset - 24)
		panel.Size = UDim2.fromOffset(width, height)
		panel.Position = UDim2.fromOffset(size.X / 2, inset + (size.Y - inset) / 2)
		title.Position, title.Size = UDim2.fromOffset(12, 10), UDim2.fromOffset(width - 76, 32)
		rarity.Position, rarity.Size = UDim2.fromOffset(12, 42), UDim2.fromOffset(width - 76, 20)
		local previewWidth = if short then 170 else width - 24
		local previewHeight = if short then height - 124 else math.min(158, height - 230)
		viewport.Position, viewport.Size = UDim2.fromOffset(12, 66), UDim2.fromOffset(previewWidth, previewHeight)
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
		Sfx.play("Purchase")
		if not reduced then
			flash.BackgroundColor3, flash.BackgroundTransparency = rarityDef.Color, 0.55
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
		egg = create("Model", world, { Name = "HatchEgg" })
		local shell: Part = create("Part", egg, {
			Name = "Shell", Shape = Enum.PartType.Ball, Size = Vector3.new(1.8, 2.4, 1.8),
			Color = Color3.fromRGB(213, 207, 195), Material = Enum.Material.SmoothPlastic,
			Anchored = true, CanCollide = false, CanTouch = false, CanQuery = false,
		})
		egg.PrimaryPart = shell
		for index = 1, 5 do
			create("Part", egg, {
				Name = "OreFleck", Shape = Enum.PartType.Ball, Size = Vector3.new(0.18, 0.26, 0.08),
				CFrame = CFrame.new(math.sin(index * 1.7) * 0.55, (index - 3) * 0.28, -0.76),
				Color = UI.CYAN, Material = Enum.Material.SmoothPlastic,
				Anchored = true, CanCollide = false, CanTouch = false, CanQuery = false,
			})
		end
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
		if elapsed >= 4.5 then dismiss() end
	end)
	player:SetAttribute("HatchOpen", false)
	player:SetAttribute("HatchVisible", false)
end

return HatchController
