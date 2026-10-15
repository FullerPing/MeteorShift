--!strict
-- The egg hatch reveal in the cartoon light look (MenuTheme): a "New Pet!" ribbon and Close on the corner, the pet's
-- name and rarity, the 3D preview on a pale blue well (the rarity rays turn behind it), the perks, a duplicate line and
-- a gold CONTINUE button. HatchController binds the named controls and lays them out.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Palette = require(ReplicatedStorage.Shared.MenuPalette)
local MenuTheme = require(script.Parent.Parent.MenuTheme)
local UI = require(script.Parent.Parent.NativeUI)

local Hatch = {}
Hatch.LAYOUT = 2 -- bumped when the controls change; HatchController rebuilds an older copy

function Hatch.build(): ScreenGui
	local gui, panel = MenuTheme.menu("PetHatch", "New Pet!", "pets", Vector2.new(380, 470), Hatch.LAYOUT)
	gui.DisplayOrder = 100
	local shade = gui:FindFirstChild("Dimmer") :: TextButton
	shade.Name = "DismissBackdrop"
	shade.BackgroundTransparency = 0.45
	shade.Modal, shade.Active, shade.Selectable = false, true, false
	shade.ZIndex = 1
	panel.Name = "HatchResult"
	panel.Active = false
	local headerClose = panel:FindFirstChild("Close") :: TextButton
	headerClose.Name = "HeaderClose"

	local title = MenuTheme.label(panel, "PetName", "Hatching...", 28, Palette.NAVY, MenuTheme.TITLE_FONT, Enum.TextXAlignment.Center)
	title.Position, title.Size, title.TextScaled = UDim2.fromOffset(16, 46), UDim2.new(1, -32, 0, 32), true
	UI.create("UITextSizeConstraint", { MinTextSize = 14, MaxTextSize = 28 }, title)
	local rarity = MenuTheme.label(panel, "Rarity", "", 17, Palette.SECOND, MenuTheme.TITLE_FONT, Enum.TextXAlignment.Center)
	rarity.Position, rarity.Size = UDim2.fromOffset(16, 78), UDim2.new(1, -32, 0, 22)
	MenuTheme.ink(rarity, true, 1.5) -- the rarity colours are light: the ink keeps them readable on the white body

	-- the well behind the pet (and behind the rays, which the controller adds between the two)
	local well = MenuTheme.card(panel, "PreviewWell", Palette.WELL_TOP, Palette.WELL_BOTTOM, 14)
	well.ZIndex = 2
	MenuTheme.stroke(well, Palette.WELL_EDGE, 2.5)
	well.Position, well.Size = UDim2.fromOffset(16, 104), UDim2.new(1, -32, 0, 170)
	local viewport: ViewportFrame = UI.create("ViewportFrame", {
		Name = "PetPreview", Position = UDim2.fromOffset(16, 104), Size = UDim2.new(1, -32, 0, 170),
		BackgroundTransparency = 1, BorderSizePixel = 0,
		Ambient = Color3.fromRGB(190, 195, 205), LightColor = Color3.fromRGB(255, 236, 210),
		LightDirection = Vector3.new(-1, -1, -2), ZIndex = 4,
	}, panel)
	local camera: Camera = UI.create("Camera", {
		Name = "Camera", Archivable = true, FieldOfView = 38, CFrame = CFrame.lookAt(Vector3.new(0, 0.5, 6.2), Vector3.zero),
	}, viewport)
	viewport.CurrentCamera = camera
	UI.create("WorldModel", { Name = "WorldModel" }, viewport)

	local perks: ScrollingFrame = UI.create("ScrollingFrame", {
		Name = "PetPerks", Position = UDim2.fromOffset(16, 282), Size = UDim2.new(1, -32, 0, 80),
		BackgroundTransparency = 1, BorderSizePixel = 0,
		AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ScrollBarThickness = 4,
		ScrollBarImageColor3 = Palette.BLUE_BOTTOM, ScrollingDirection = Enum.ScrollingDirection.Y,
		ClipsDescendants = true, Active = true, ZIndex = 4,
	}, panel)
	local perkText = MenuTheme.label(perks, "PerkText", "", 15, Palette.NAVY)
	perkText.Size, perkText.AutomaticSize = UDim2.new(1, -8, 0, 0), Enum.AutomaticSize.Y
	perkText.TextWrapped, perkText.TextYAlignment = true, Enum.TextYAlignment.Top
	local duplicate = MenuTheme.label(panel, "Duplicate", "", 15, Palette.UP, MenuTheme.TITLE_FONT, Enum.TextXAlignment.Center)
	duplicate.Position, duplicate.Size, duplicate.TextWrapped = UDim2.new(0, 16, 1, -96), UDim2.new(1, -32, 0, 28), true
	local close = MenuTheme.button(panel, "Close", "SKIP", "gold", 18)
	close.Position, close.Size = UDim2.new(0, 16, 1, -66), UDim2.new(1, -32, 0, 52)
	UI.create("Frame", {
		Name = "RarityFlash", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
		BorderSizePixel = 0, ZIndex = 4, Active = false,
	}, gui)
	return gui
end

return Hatch
