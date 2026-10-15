--!strict
-- The offline-production report in the cartoon light look (MenuTheme), laid out as the owner's mockup (Craterworks Menu
-- Redesign, 2026-10-15): a "Welcome back!" ribbon, a line with how long you were away, a gold card with what the line
-- made (bars, and what they are worth), the offline time with a bar when it hit the cap, a note and a big lime NICE!.
-- The panel is drawn whole (NativeUI.fitWhole). NativeWelcomeBack binds it by name and fills it in.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Palette = require(ReplicatedStorage.Shared.MenuPalette)
local MenuTheme = require(script.Parent.Parent.MenuTheme)
local NativeUI = require(script.Parent.Parent.NativeUI)
local WelcomeBack = {}
WelcomeBack.LAYOUT = 3 -- bumped when the controls change; NativeWelcomeBack rebuilds an older copy
WelcomeBack.SIZE = Vector2.new(560, 470)

-- one line of the report: the owner's icon, what it is and the amount on the right
local function row(card: Instance, name: string, y: number, icon: string, label: string, valueSize: number, valueColor: Color3)
	local line = NativeUI.create("Frame", { Name = name, Position = UDim2.fromOffset(16, y), Size = UDim2.new(1, -32, 0, 40), BackgroundTransparency = 1, ZIndex = 3 }, card)
	MenuTheme.icon(line, "Icon", icon, UDim2.fromOffset(0, 2), UDim2.fromOffset(36, 36))
	local text = MenuTheme.label(line, "Label", label, 17, Palette.NAVY)
	text.Position, text.Size = UDim2.fromOffset(48, 0), UDim2.new(0.6, -48, 1, 0)
	local value = MenuTheme.label(line, "Value", "", valueSize, valueColor, MenuTheme.TITLE_FONT, Enum.TextXAlignment.Right)
	value.Position, value.Size, value.TextScaled = UDim2.fromScale(0.6, 0), UDim2.fromScale(0.4, 1), true
	NativeUI.create("UITextSizeConstraint", { MinTextSize = 12, MaxTextSize = valueSize }, value)
end

function WelcomeBack.build(): ScreenGui
	local gui, panel = MenuTheme.menu("WelcomeBack", "Welcome back!", "foundry", WelcomeBack.SIZE, WelcomeBack.LAYOUT)
	gui.DisplayOrder = 30
	local intro = MenuTheme.label(panel, "Intro", "", 17, Palette.NAVY)
	intro.Position, intro.Size, intro.TextWrapped, intro.RichText = UDim2.fromOffset(24, 56), UDim2.new(1, -48, 0, 46), true, true
	intro.TextYAlignment = Enum.TextYAlignment.Top

	local card = MenuTheme.goldCard(panel, "Report")
	card.Position, card.Size = UDim2.fromOffset(24, 110), UDim2.new(1, -48, 0, 124)
	row(card, "Bars", 14, "bars", "Bars waiting at the Foundry", 22, Palette.NAVY)
	local divider = MenuTheme.divider(card, "Divider")
	divider.Position, divider.Size, divider.BackgroundColor3 = UDim2.fromOffset(16, 61), UDim2.new(1, -32, 0, 2), Palette.GOLD_DIVIDER
	row(card, "Worth", 70, "coin", "Worth when sold", 26, Palette.UP)

	-- the offline time: a label, how much was used and a bar (shown when it hit the cap), and a note under it
	local time = NativeUI.create("Frame", { Name = "Time", Position = UDim2.fromOffset(24, 248), Size = UDim2.new(1, -48, 0, 40), BackgroundTransparency = 1, ZIndex = 3 }, panel)
	local timeLabel = MenuTheme.label(time, "Label", "Offline time used", 14, Palette.SECOND, MenuTheme.TITLE_FONT)
	timeLabel.Size = UDim2.new(0.5, 0, 0, 20)
	local used = MenuTheme.label(time, "Used", "", 14, Palette.UNMET, MenuTheme.TITLE_FONT, Enum.TextXAlignment.Right)
	used.Position, used.Size = UDim2.fromScale(0.5, 0), UDim2.new(0.5, 0, 0, 20)
	local bar = MenuTheme.bar(time, "Bar", Palette.ORANGE_FILL)
	bar.Position, bar.Size = UDim2.fromOffset(0, 26), UDim2.new(1, 0, 0, 12)
	local note = MenuTheme.label(panel, "Note", "", 14, Palette.SECOND)
	note.Position, note.Size, note.TextWrapped = UDim2.fromOffset(24, 296), UDim2.new(1, -48, 0, 40), true
	note.TextYAlignment = Enum.TextYAlignment.Top

	local nice = MenuTheme.button(panel, "Nice", "NICE!", "lime", 26)
	nice.Position, nice.Size = UDim2.new(0, 24, 1, -90), UDim2.new(1, -48, 0, 62)
	return gui
end

return WelcomeBack
