--!strict
-- The popup and its raw-ore row template are editable StarterGui objects.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UI = require(script.Parent.Parent.NativeUI)
local Icons = require(ReplicatedStorage.Shared.Config.HudIcons)
local Backpack = {}

function Backpack.build(): ScreenGui
	local gui = UI.menu("BackpackMenu", "Backpack", UI.CYAN, 230, 128)
	gui.DisplayOrder = 9
	local dimmer = gui:FindFirstChild("Dimmer") :: TextButton
	dimmer:Destroy()
	local panel = gui:FindFirstChild("Panel") :: Frame
	panel.Active, panel.AnchorPoint, panel.Position = false, Vector2.zero, UDim2.fromOffset(1186, 570)
	local header = panel:FindFirstChild("Header") :: Frame
	header.Size = UDim2.new(1, 0, 0, 40)
	local title = panel:FindFirstChild("Title") :: TextLabel
	title.Position, title.Size, title.TextSize = UDim2.fromOffset(8, 6), UDim2.new(1, -52, 0, 28), 16
	local close = panel:FindFirstChild("Close") :: TextButton
	close.Text, close.Position = "", UDim2.new(1, -44, 0, 0)
	UI.create("ImageLabel", {
		Name = "Icon", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(20, 20), Image = Icons.close, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 5,
	}, close)
	UI.create("ScrollingFrame", {
		Name = "OreInventory", Position = UDim2.fromOffset(8, 40), Size = UDim2.new(1, -16, 1, -44),
		BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 3, ScrollBarImageColor3 = UI.MUTED, ScrollingDirection = Enum.ScrollingDirection.Y,
		Active = false, ScrollingEnabled = false, ClipsDescendants = true, ZIndex = 3,
	}, panel)
	local empty = UI.text(panel, "Empty", "Empty", UDim2.fromOffset(8, 40), UDim2.new(1, -16, 0, 28), true)
	empty.TextSize, empty.TextColor3 = 14, UI.MUTED
	local inventory = panel:FindFirstChild("OreInventory") :: ScrollingFrame
	UI.create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, inventory)
	local templates = UI.create("Folder", { Name = "Templates" }, gui)
	local row: Frame = UI.create("Frame", {
		Name = "OreRow", Size = UDim2.new(1, -4, 0, 28), BackgroundTransparency = 1, Visible = false, ZIndex = 3,
	}, templates)
	UI.create("ImageLabel", {
		Name = "Icon", Position = UDim2.fromOffset(0, 4), Size = UDim2.fromOffset(20, 20),
		Image = Icons.ore, ImageColor3 = UI.HUD_GOLD, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 4,
	}, row)
	local kind = UI.text(row, "Type", "Iron", UDim2.fromOffset(26, 2), UDim2.new(1, -76, 0, 24), true)
	kind.Font, kind.TextSize, kind.TextColor3, kind.TextTruncate = Enum.Font.GothamBold, 14, UI.HUD_GOLD, Enum.TextTruncate.AtEnd
	local amount = UI.text(row, "Amount", "0", UDim2.new(1, -4, 0, 2), UDim2.fromOffset(44, 24), true)
	amount.AnchorPoint, amount.Font, amount.TextSize, amount.TextXAlignment = Vector2.new(1, 0), Enum.Font.GothamBold, 16, Enum.TextXAlignment.Right
	return gui
end

return Backpack
