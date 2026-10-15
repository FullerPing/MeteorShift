--!strict
-- The offline-production report in the cartoon light look (MenuTheme): a "Welcome back" ribbon, the report on a white
-- card and a gold Nice! button. NativeWelcomeBack binds it by name and fills in the text, layout and visibility.
local Palette = require(game:GetService("ReplicatedStorage").Shared.MenuPalette)
local MenuTheme = require(script.Parent.Parent.MenuTheme)
local NativeUI = require(script.Parent.Parent.NativeUI)
local WelcomeBack = {}
WelcomeBack.LAYOUT = 2 -- bumped when the controls change; NativeWelcomeBack rebuilds an older copy
WelcomeBack.SIZE = Vector2.new(420, 300)

function WelcomeBack.build(): ScreenGui
	local gui, panel = MenuTheme.menu("WelcomeBack", "Welcome back!", "bars", WelcomeBack.SIZE, WelcomeBack.LAYOUT)
	gui.DisplayOrder = 30
	local card = MenuTheme.whiteCard(panel, "Card", 14)
	card.Position, card.Size = UDim2.fromOffset(16, 50), UDim2.new(1, -32, 1, -128)
	local away = MenuTheme.label(card, "Away", "WHILE YOU WERE AWAY", 15, Palette.GOLD_TEXT, MenuTheme.TITLE_FONT)
	away.Position, away.Size = UDim2.fromOffset(14, 6), UDim2.new(1, -28, 0, 22)
	-- the body scrolls inside the card; NativeWelcomeBack sizes it to the panel
	local body = NativeUI.create("ScrollingFrame", {
		Name = "Body", Position = UDim2.fromOffset(30, 82), Size = UDim2.new(1, -60, 1, -164),
		BackgroundTransparency = 1, BorderSizePixel = 0,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 4,
		ScrollBarImageColor3 = Palette.BLUE_BOTTOM, VerticalScrollBarInset = Enum.ScrollBarInset.Always,
		ElasticBehavior = Enum.ElasticBehavior.WhenScrollable, ZIndex = 4,
	}, panel)
	local report = MenuTheme.label(body, "Report", "", 18, Palette.NAVY)
	report.Size, report.AutomaticSize = UDim2.new(1, -8, 0, 0), Enum.AutomaticSize.Y
	report.TextWrapped, report.TextYAlignment = true, Enum.TextYAlignment.Top
	local nice = MenuTheme.button(panel, "Nice", "Nice!", "gold", 22)
	nice.AnchorPoint, nice.Position, nice.Size = Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -14), UDim2.fromOffset(170, 54)
	return gui
end

return WelcomeBack
