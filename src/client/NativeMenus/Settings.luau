--!strict
-- Build in Edit mode, then edit the named controls directly in StarterGui.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UI = require(script.Parent.Parent.NativeUI)
local Icons = require(ReplicatedStorage.Shared.Config.HudIcons)
local Settings = {}

function Settings.build(): ScreenGui
	local gui = UI.menu("HudSettings", "Settings", UI.CYAN, 360, 350)
	gui.Enabled, gui.DisplayOrder = true, 10
	local backdrop = gui:FindFirstChild("Dimmer") :: TextButton
	backdrop.Name, backdrop.Visible, backdrop.ZIndex = "SettingsBackdrop", false, 2
	backdrop.BackgroundTransparency = 0.3
	local panel = gui:FindFirstChild("Panel") :: Frame
	panel.Name, panel.Visible, panel.ZIndex = "SettingsPanel", false, 3
	panel.AnchorPoint, panel.Position = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 48)
	local title = panel:FindFirstChild("Title") :: TextLabel
	title.Position, title.Size, title.TextSize = UDim2.fromOffset(16, 12), UDim2.new(1, -76, 0, 32), 24
	local close = panel:FindFirstChild("Close") :: TextButton
	close.Text, close.Position = "", UDim2.new(1, -48, 0, 4)
	UI.create("ImageLabel", {
		Name = "Icon", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(20, 20), Image = Icons.close, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 5,
	}, close)
	local preferences: ScrollingFrame = UI.create("ScrollingFrame", {
		Name = "Preferences", Position = UDim2.fromOffset(16, 56), Size = UDim2.new(1, -32, 1, -68),
		BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 3, ScrollBarImageColor3 = UI.MUTED,
		Active = true, ClipsDescendants = true, ZIndex = 4,
	}, panel)
	UI.create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }, preferences)
	for index, preference in {
		{ name = "HudShowGuide", label = "Training guide", enabled = true },
		{ name = "HudShowEventTips", label = "Meteor objective", enabled = true },
		{ name = "ReduceCameraShake", label = "Reduce camera shake", enabled = false },
		{ name = "ReduceEffects", label = "Reduce effects", enabled = false },
	} do
		local row = UI.button(preferences, preference.name, "", UDim2.new(), UDim2.new(1, -6, 0, 44), UI.CARD)
		row.LayoutOrder = index
		local label = UI.text(row, "Label", preference.label, UDim2.fromOffset(12, 0), UDim2.new(1, -80, 1, 0), true)
		label.TextSize, label.TextWrapped = 15, true
		local value = UI.text(row, "State", if preference.enabled then "ON" else "OFF", UDim2.new(1, -56, 0, 0), UDim2.fromOffset(48, 44))
		value.TextSize, value.TextXAlignment, value.BackgroundTransparency = 15, Enum.TextXAlignment.Center, 0
		value.BackgroundColor3 = if preference.enabled then UI.GREEN else Color3.fromRGB(29, 30, 35)
		UI.surface(value)
	end
	local hint = UI.text(preferences, "Hint", "Preferences apply during this session.", UDim2.new(), UDim2.new(1, -6, 0, 40), true)
	hint.LayoutOrder, hint.TextSize, hint.TextColor3, hint.TextWrapped = 5, 14, UI.MUTED, true
	local open: ImageButton = UI.create("ImageButton", {
		Name = "OpenSettings", Size = UDim2.fromOffset(44, 44), Position = UDim2.fromOffset(304, 2),
		Image = "", BackgroundColor3 = UI.CYAN, BorderSizePixel = 0, ZIndex = 1,
	}, gui)
	UI.surface(open)
	UI.create("ImageLabel", {
		Name = "Icon", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(24, 24), Image = Icons.settings, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 2,
	}, open)
	return gui
end

return Settings
