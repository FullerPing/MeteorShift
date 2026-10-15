--!strict
-- The Settings screen in the cartoon light look (MenuTheme): the gear button on the HUD (OpenSettings) and a "Settings"
-- panel with one white row per switch, its name on the left and an ON / OFF pill on the right. NativeHudMenus binds the
-- rows by name and adds the Daily rewards and Enter a code rows by copying the first one.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Palette = require(ReplicatedStorage.Shared.MenuPalette)
local MenuTheme = require(script.Parent.Parent.MenuTheme)
local UI = require(script.Parent.Parent.NativeUI)
local Icons = require(ReplicatedStorage.Shared.Config.HudIcons)
local Settings = {}
Settings.LAYOUT = 2 -- bumped when the controls change; NativeHudMenus rebuilds an older copy
Settings.SIZE = Vector2.new(400, 480)

-- An ON / OFF / OPEN switch row: the whole row is the button
function Settings.row(parent: Instance, name: string, label: string, enabled: boolean, order: number): TextButton
	local row = UI.create("TextButton", { Name = name, Text = "", LayoutOrder = order, Size = UDim2.new(1, -10, 0, 50), BackgroundColor3 = Palette.WHITE,
		BorderSizePixel = 0, AutoButtonColor = false, ZIndex = 4 }, parent)
	MenuTheme.round(row, 12)
	MenuTheme.stroke(row, Palette.NAVY, 2.5)
	local text = MenuTheme.label(row, "Label", label, 17, Palette.NAVY, MenuTheme.TITLE_FONT)
	text.Position, text.Size, text.TextWrapped = UDim2.fromOffset(14, 0), UDim2.new(1, -100, 1, 0), true
	local state = MenuTheme.label(row, "State", if enabled then "ON" else "OFF", 16, Palette.NAVY, MenuTheme.TITLE_FONT, Enum.TextXAlignment.Center)
	state.AnchorPoint, state.Position, state.Size = Vector2.new(1, 0.5), UDim2.new(1, -10, 0.5, 0), UDim2.fromOffset(70, 32)
	state.BackgroundTransparency, state.BackgroundColor3 = 0, if enabled then Palette.LIME else Palette.GREY_TOP
	MenuTheme.round(state, 10)
	MenuTheme.stroke(state, Palette.NAVY, 2)
	return row
end

function Settings.build(): ScreenGui
	local gui, panel = MenuTheme.menu("HudSettings", "Settings", "settings", Settings.SIZE, Settings.LAYOUT)
	gui.Enabled, gui.DisplayOrder = true, 10
	local backdrop = gui:FindFirstChild("Dimmer") :: TextButton
	backdrop.Name, backdrop.Visible, backdrop.ZIndex = "SettingsBackdrop", false, 2
	panel.Name, panel.Visible, panel.ZIndex = "SettingsPanel", false, 3
	local preferences: ScrollingFrame = UI.create("ScrollingFrame", {
		Name = "Preferences", Position = UDim2.fromOffset(16, 50), Size = UDim2.new(1, -32, 1, -64),
		BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 4, ScrollBarImageColor3 = Palette.BLUE_BOTTOM,
		Active = true, ClipsDescendants = true, ZIndex = 4,
	}, panel)
	UI.create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }, preferences)
	UI.create("UIPadding", { PaddingTop = UDim.new(0, 3), PaddingLeft = UDim.new(0, 3) }, preferences)
	for index, preference in {
		{ name = "HudShowGuide", label = "Training guide", enabled = true },
		{ name = "HudShowEventTips", label = "Meteor objective", enabled = true },
		{ name = "ReduceCameraShake", label = "Reduce camera shake", enabled = false },
		{ name = "ReduceEffects", label = "Reduce effects", enabled = false },
		{ name = "MusicOn", label = "Music", enabled = true },
		{ name = "SfxOn", label = "Sound effects", enabled = true },
	} do
		Settings.row(preferences, preference.name, preference.label, preference.enabled, index)
	end
	local hint = MenuTheme.label(preferences, "Hint", "Preferences apply during this session.", 14, Palette.SECOND, nil, Enum.TextXAlignment.Center)
	hint.LayoutOrder, hint.Size, hint.TextWrapped = 99, UDim2.new(1, -10, 0, 32), true
	-- the gear on the HUD (HudLayout places it); MenuSkin styles it like the other HUD buttons
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
