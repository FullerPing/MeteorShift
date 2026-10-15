--!strict
-- The egg hatch reveal in the cartoon light look (MenuTheme), laid out as the owner's mockup (Craterworks Menu Redesign,
-- 2026-10-15): a "You hatched!" ribbon and Close on the corner, the 3D preview on a big well tinted by the pet's rarity
-- (the rarity rays turn behind it) with a NEW! tag, the pet's name, a rarity pill, its blurb, a strip of perk pills, then
-- EQUIP and AGAIN (hatch the same egg again for its shards). While the egg wobbles one gold SKIP stands in for them.
-- The panel is drawn whole (NativeUI.fitWhole). HatchController binds the named controls.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Palette = require(ReplicatedStorage.Shared.MenuPalette)
local MenuTheme = require(script.Parent.Parent.MenuTheme)
local UI = require(script.Parent.Parent.NativeUI)

local Hatch = {}
Hatch.LAYOUT = 3 -- bumped when the controls change; HatchController rebuilds an older copy
Hatch.SIZE = Vector2.new(540, 520)
Hatch.WELL = { x = 22, y = 56, h = 200 } -- the preview well; the rays centre on it

-- a centred rounded tag with a Label (the rarity, NEW!, a perk)
local function tag(parent: Instance, name: string, fill: Color3, size: number): Frame
	local pill = MenuTheme.pill(parent, name, fill, Palette.NAVY, Palette.NAVY, size)
	pill.AutomaticSize = Enum.AutomaticSize.X
	local label = pill:FindFirstChild("Label") :: TextLabel
	label.TextScaled, label.AutomaticSize, label.Size = false, Enum.AutomaticSize.X, UDim2.fromScale(0, 1)
	label.TextSize = size
	return pill
end

function Hatch.build(): ScreenGui
	local gui, panel = MenuTheme.menu("PetHatch", "You hatched!", "pets", Hatch.SIZE, Hatch.LAYOUT)
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

	-- the well behind the pet (HatchController tints it by rarity and puts the rays between it and the pet)
	local w = Hatch.WELL
	local well = MenuTheme.card(panel, "PreviewWell", Palette.WELL_TOP, Palette.WELL_BOTTOM, 14)
	well.ZIndex = 2
	MenuTheme.stroke(well, Palette.WELL_EDGE, 2.5)
	well.Position, well.Size = UDim2.fromOffset(w.x, w.y), UDim2.new(1, -w.x * 2, 0, w.h)
	local viewport: ViewportFrame = UI.create("ViewportFrame", {
		Name = "PetPreview", Position = well.Position, Size = well.Size,
		BackgroundTransparency = 1, BorderSizePixel = 0,
		Ambient = Color3.fromRGB(190, 195, 205), LightColor = Color3.fromRGB(255, 236, 210),
		LightDirection = Vector3.new(-1, -1, -2), ZIndex = 4,
	}, panel)
	local camera: Camera = UI.create("Camera", {
		Name = "Camera", Archivable = true, FieldOfView = 38, CFrame = CFrame.lookAt(Vector3.new(0, 0.5, 6.2), Vector3.zero),
	}, viewport)
	viewport.CurrentCamera = camera
	UI.create("WorldModel", { Name = "WorldModel" }, viewport)
	local new = tag(panel, "NewTag", Palette.LIME_TOP, 14)
	new.AnchorPoint, new.Position, new.Size, new.ZIndex = Vector2.new(1, 0), UDim2.new(1, -w.x - 10, 0, w.y + 10), UDim2.fromOffset(0, 26), 6
	;(new:FindFirstChild("Label") :: TextLabel).Text = "NEW!"

	local title = MenuTheme.label(panel, "PetName", "Hatching...", 34, Palette.NAVY, MenuTheme.TITLE_FONT, Enum.TextXAlignment.Center)
	title.Position, title.Size, title.TextScaled = UDim2.fromOffset(22, 266), UDim2.new(1, -44, 0, 38), true
	UI.create("UITextSizeConstraint", { MinTextSize = 16, MaxTextSize = 34 }, title)
	local rarity = tag(panel, "RarityTag", Palette.WHITE, 14)
	rarity.AnchorPoint, rarity.Position, rarity.Size = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 308), UDim2.fromOffset(0, 26)
	local rarityLabel = rarity:FindFirstChild("Label") :: TextLabel
	rarityLabel.Name = "Rarity"
	local blurb = MenuTheme.label(panel, "Duplicate", "", 14, Palette.SECOND, nil, Enum.TextXAlignment.Center)
	blurb.Position, blurb.Size, blurb.TextWrapped = UDim2.fromOffset(22, 340), UDim2.new(1, -44, 0, 20), true

	-- the perks: one pill each, on a soft strip
	local strip = MenuTheme.soft(panel, "PetPerks")
	strip.Position, strip.Size = UDim2.fromOffset(22, 368), UDim2.new(1, -44, 0, 46)
	UI.create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, strip)
	local template = tag(panel, "PerkTemplate", Palette.SHARD_CHIP, 14)
	template.Visible, template.Size = false, UDim2.fromOffset(0, 28)

	-- the actions: SKIP while the egg wobbles, then EQUIP and AGAIN
	local close = MenuTheme.button(panel, "Close", "SKIP", "gold", 20)
	close.Position, close.Size = UDim2.new(0, 22, 1, -86), UDim2.new(1, -44, 0, 60)
	local equip = MenuTheme.button(panel, "Equip", "EQUIP", "lime", 22)
	equip.Position, equip.Size, equip.Visible = UDim2.new(0, 22, 1, -86), UDim2.new(0.5, -28, 0, 60), false
	local again = MenuTheme.button(panel, "Again", "AGAIN", "blue", 20)
	again.Position, again.Size, again.Visible = UDim2.new(0.5, 6, 1, -86), UDim2.new(0.5, -28, 0, 60), false
	MenuTheme.withIcon(again, "crystal", 26)
	UI.create("Frame", {
		Name = "RarityFlash", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
		BorderSizePixel = 0, ZIndex = 4, Active = false,
	}, gui)
	return gui
end

return Hatch
