--!strict
-- The Settings screen in the cartoon light look (MenuTheme), laid out as the owner's mockup (Craterworks Menu Redesign,
-- 2026-10-15): the gear button on the HUD (OpenSettings) and a "Settings" panel whose Preferences scroll holds three
-- sections (SOUND, COMFORT, HELP ON SCREEN), each a soft card of rows with the setting's name and a chunky ON / OFF
-- Toggle. Under them, two buttons open Daily rewards (OpenDaily) and Codes (OpenCodes). NativeHudMenus binds the rows by
-- name (each row is a Frame named after its player attribute).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Palette = require(ReplicatedStorage.Shared.MenuPalette)
local MenuTheme = require(script.Parent.Parent.MenuTheme)
local UI = require(script.Parent.Parent.NativeUI)
local Icons = require(ReplicatedStorage.Shared.Config.HudIcons)
local Settings = {}
Settings.LAYOUT = 3 -- bumped when the controls change; NativeHudMenus rebuilds an older copy
Settings.SIZE = Vector2.new(600, 540)
Settings.ROW = 52

-- the sections and their switches (the player attribute each one sets); a row can name one of the owner's icons (`icon`)
Settings.SECTIONS = {
	{ title = "SOUND", rows = {
		{ name = "MusicOn", label = "Music" },
		{ name = "SfxOn", label = "Sound effects" },
	} },
	{ title = "COMFORT", rows = {
		{ name = "ReduceCameraShake", label = "Reduce camera shake" },
		{ name = "ReduceEffects", label = "Reduce effects" },
	} },
	{ title = "HELP ON SCREEN", rows = {
		{ name = "HudShowGuide", label = "Training guide" },
		{ name = "HudShowEventTips", label = "Meteor objective" },
	} },
}

-- One switch row: the icon (if any), the name and a chunky Toggle on the right
local function row(parent: Instance, spec: any, order: number): Frame
	local line = UI.create("Frame", { Name = spec.name, LayoutOrder = order, Size = UDim2.new(1, 0, 0, Settings.ROW), BackgroundTransparency = 1, ZIndex = 4 }, parent)
	local left = 4
	if spec.icon then
		MenuTheme.icon(line, "Icon", spec.icon, UDim2.new(0, 2, 0.5, -14), UDim2.fromOffset(28, 28))
		left = 40
	end
	local text = MenuTheme.label(line, "Label", spec.label, 18, Palette.NAVY, MenuTheme.TITLE_FONT)
	text.Position, text.Size, text.TextTruncate = UDim2.fromOffset(left, 0), UDim2.new(1, -left - 110, 1, 0), Enum.TextTruncate.AtEnd
	local toggle = MenuTheme.button(line, "Toggle", "ON", "lime", 18)
	toggle.AnchorPoint, toggle.Position, toggle.Size = Vector2.new(1, 0.5), UDim2.new(1, 0, 0.5, 0), UDim2.fromOffset(96, 44)
	return line
end

function Settings.build(): ScreenGui
	local gui, panel = MenuTheme.menu("HudSettings", "Settings", "settings", Settings.SIZE, Settings.LAYOUT)
	gui.Enabled, gui.DisplayOrder = true, 10
	local backdrop = gui:FindFirstChild("Dimmer") :: TextButton
	backdrop.Name, backdrop.Visible, backdrop.ZIndex = "SettingsBackdrop", false, 2
	panel.Name, panel.Visible, panel.ZIndex = "SettingsPanel", false, 3
	local preferences: ScrollingFrame = UI.create("ScrollingFrame", {
		Name = "Preferences", Position = UDim2.fromOffset(18, 52), Size = UDim2.new(1, -36, 1, -136),
		BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 4, ScrollBarImageColor3 = Palette.BLUE_BOTTOM,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar, Active = true, ClipsDescendants = true, ZIndex = 4,
	}, panel)
	UI.create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }, preferences)
	UI.create("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }, preferences)
	local order = 0
	for _, section in Settings.SECTIONS do
		order += 1
		local heading = MenuTheme.label(preferences, section.title:gsub(" ", "") .. "Heading", section.title, 14, Palette.SECOND, MenuTheme.TITLE_FONT)
		heading.LayoutOrder, heading.Size = order, UDim2.new(1, 0, 0, 18)
		order += 1
		local count = #section.rows
		local card = MenuTheme.soft(preferences, section.title:gsub(" ", "") .. "Card")
		card.LayoutOrder, card.Size = order, UDim2.new(1, 0, 0, count * Settings.ROW + (count - 1) * 2 + 8)
		UI.create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, card)
		UI.create("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 10) }, card)
		for index, spec in section.rows do
			if index > 1 then MenuTheme.divider(card, "Divider" .. index).LayoutOrder = index * 2 - 1 end
			row(card, spec, index * 2)
		end
	end
	local hint = MenuTheme.label(preferences, "Hint", "Preferences apply during this session.", 13, Palette.SECOND, nil, Enum.TextXAlignment.Center)
	hint.LayoutOrder, hint.Size = 99, UDim2.new(1, 0, 0, 24)

	-- the two shortcuts along the bottom: Daily rewards (shown once the tutorial is over) and Codes
	local daily = MenuTheme.button(panel, "OpenDaily", "DAILY REWARDS", "gold", 18)
	daily.Position, daily.Size = UDim2.new(0, 18, 1, -78), UDim2.new(0.5, -24, 0, 56)
	MenuTheme.withIcon(daily, "daily", 30)
	local codes = MenuTheme.button(panel, "OpenCodes", "ENTER A CODE", "blue", 18)
	codes.Position, codes.Size = UDim2.new(0.5, 6, 1, -78), UDim2.new(0.5, -24, 0, 56)
	MenuTheme.withIcon(codes, "codes", 30)

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
