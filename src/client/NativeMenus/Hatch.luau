--!strict
-- Author this once into StarterGui; HatchController binds the editable descendants.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UI = require(script.Parent.Parent.NativeUI)
local Icons = require(ReplicatedStorage.Shared.Config.HudIcons)

local Hatch = {}

function Hatch.build(): ScreenGui
	local gui = UI.menu("PetHatch", "Hatching...", UI.ORANGE, 360, 420)
	gui.DisplayOrder = 100
	local shade = gui:FindFirstChild("Dimmer") :: TextButton
	shade.Name = "DismissBackdrop"
	shade.BackgroundTransparency = 0.2
	shade.Modal, shade.Active, shade.Selectable = false, true, false
	shade.ZIndex = 1
	local panel = gui:FindFirstChild("Panel") :: Frame
	panel.Name = "HatchResult"
	panel.Active = false
	local header = panel:FindFirstChild("Header") :: Frame
	header.Name = "MenuHeader"
	header.Size = UDim2.new(1, 0, 0, 64)
	local title = panel:FindFirstChild("Title") :: TextLabel
	title.Name, title.TextSize, title.TextWrapped = "PetName", 23, true
	title.Position, title.Size = UDim2.fromOffset(12, 10), UDim2.new(1, -76, 0, 32)
	local rarity = UI.text(panel, "Rarity", "", UDim2.fromOffset(12, 42), UDim2.new(1, -76, 0, 20), true)
	rarity.TextSize, rarity.TextColor3, rarity.TextWrapped = 13, UI.MUTED, true
	rarity.TextStrokeTransparency = 0
	local headerClose = panel:FindFirstChild("Close") :: TextButton
	headerClose.Name, headerClose.Text = "HeaderClose", ""
	headerClose.AnchorPoint, headerClose.Position = Vector2.new(1, 0), UDim2.new(1, -12, 0, 8)
	UI.create("ImageLabel", {
		Name = "CloseIcon", Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(20, 20),
		Image = Icons.close, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 5,
	}, headerClose)
	local viewport: ViewportFrame = UI.create("ViewportFrame", {
		Name = "PetPreview", Position = UDim2.fromOffset(12, 66), Size = UDim2.new(1, -24, 0, 158),
		BackgroundTransparency = 1, BorderSizePixel = 0,
		Ambient = Color3.fromRGB(190, 195, 205), LightColor = Color3.fromRGB(255, 236, 210),
		LightDirection = Vector3.new(-1, -1, -2), ZIndex = 2,
	}, panel)
	local camera: Camera = UI.create("Camera", {
		Name = "Camera", Archivable = true, FieldOfView = 38, CFrame = CFrame.lookAt(Vector3.new(0, 0.5, 6.2), Vector3.zero),
	}, viewport)
	viewport.CurrentCamera = camera
	UI.create("WorldModel", { Name = "WorldModel" }, viewport)
	local perks: ScrollingFrame = UI.create("ScrollingFrame", {
		Name = "PetPerks", Position = UDim2.fromOffset(12, 228), Size = UDim2.new(1, -24, 0, 94),
		BackgroundTransparency = 1, BorderSizePixel = 0,
		AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ScrollBarThickness = 4,
		ScrollBarImageColor3 = Color3.fromRGB(255, 219, 100), ScrollingDirection = Enum.ScrollingDirection.Y,
		ClipsDescendants = true, Active = true, ZIndex = 2,
	}, panel)
	local perkText = UI.text(perks, "PerkText", "", UDim2.new(), UDim2.new(1, -8, 0, 0), true)
	perkText.TextSize, perkText.TextColor3, perkText.TextWrapped = 14, UI.MUTED, true
	perkText.AutomaticSize, perkText.TextYAlignment = Enum.AutomaticSize.Y, Enum.TextYAlignment.Top
	local duplicate = UI.text(panel, "Duplicate", "", UDim2.new(0, 12, 1, -90), UDim2.new(1, -24, 0, 28), true)
	duplicate.TextSize, duplicate.TextColor3, duplicate.TextWrapped = 14, Color3.fromRGB(139, 240, 195), true
	local close = UI.button(panel, "Close", "SKIP", UDim2.new(0, 12, 1, -56), UDim2.new(1, -24, 0, 44), Color3.fromRGB(255, 219, 100))
	close.TextSize = 15
	UI.create("Frame", {
		Name = "RarityFlash", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
		BorderSizePixel = 0, ZIndex = 4, Active = false,
	}, gui)
	return gui
end

return Hatch
